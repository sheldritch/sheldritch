source "$SHELDRITCH/sheldritch.sh" || return 1
check_is_sourced

summon sheldritch/data/random.sh

ASYNC_TMP=$SHELDRITCH_TMP/async
SEMS=$ASYNC_TMP/semaphores
mkdir -p $SEMS

flock() {
	if command flock --version >/dev/null 2>&1; then
		command flock "$@"
	else
		local path lock
		path="$(realpath -m "$1")"
		shift
		lock="$ASYNC_TMP/flock/$path/LOCK"

		if [[ "$1" =~ [0-9]+ ]]; then
			error -p 1 "flock: file descriptors unsupported"
			return 9
		fi

		while true; do
			if ! [[ -d "$lock" ]]; then
				if [[ "$(mkdir -v -p "$lock")" ]]; then
					(
					trap 'rmdir "$lock"' EXIT
					if [[ "$1" = "-c" ]]; then
						set -- sh "$@"
					fi
					"$@"
					return
					)
					break
				fi
			fi
		done
	fi
}

# modified from https://unix.stackexchange.com/a/216475

# initialize a semaphore with a given number of tokens
async_sem() {
	
	local _sem
	_sem="$(random_char -c 8 'A-Za-z0-9')"

	if [[ -n "$2" ]]; then
		safe_set "$2" _sem || return $?
	fi

	local fifo="$SEMS/$_sem"
	mkfifo $fifo

	(
	local i=$1
	for ((;i>0;i--)); do
		flock $fifo printf '%s' 000 >>$fifo &
	done
	disown
	)

	if [[ -z "$2" ]]; then
		printf '%s\n' "$_sem"
	fi
}

async_close() {
	rm "$SEMS/$1"
}

async_wait() {
	if ! [[ -p "$SEMS/$1" ]]; then
		error "could not find async id $1"
		return 9
	fi

	_trace "Awaiting sem '$1' to be freed"
	flock "$SEMS/$1" true
	read -N 3 <"$SEMS/$1"
	local exit=$?
	if [[ $exit -ne 0 ]]; then
		error "read returned error '$exit'"
		return 9
	fi

	return $REPLY
}

async_done() {
	local exit=${2:-$?}
	local sem="${1:-$SEM}"
	(
	flock "$SEMS/$sem" printf '%.3d' $exit >>"$SEMS/$sem" &
	disown
	)
	_trace "async: released semaphore $sem"
}

async_batch() {
	usage() {
		echo >&2 'Usage: async_batch [options] COMMAND ELEMENTS...'
		echo >&2 'Usage: async_batch [options] -f COMMAND_FILE ELEMENTS...'
		print_usage '[options] --for VAR "COMMAND CONTAINING $VAR" ELEMENTS...'
	}

	local threads variable indexVar exit verbose file queueId
	@ARGS
		-n | -t | --threads ) threads="$2"
			shift
			shift
			;;

		-v | --for | --variable ) variable="$2"
			shift
			shift
			;;

		-i | --index) indexVar="$2"
			shift
			shift
			;;

		# read commands to run out of the given file
		-f | --file) file="$2"
			shift
			shift
			;;

		# exit as soon as an error occurs.
		-e | --exit ) exit=true
			shift
			;;

		# Use an existing semaphore queue, specified by its id
		-q | --queue | --semaphore ) queueId="$2"
			shift
			shift
			;;

		-V | --verbose ) verbose=true
			shift
	@ENDARGS

	if [[ "$TRACE" ]]; then
		verbose=true
	fi

	threads="${threads:-$(lscpu 2>/dev/null | awk '/^CPU\(s):/ {print $2}')}"
	threads="${threads:-8}"

	if [[ -n "$file" ]]; then
		command="$(cat "$file")"
	else
		command="$1"
		shift
	fi

	if [[ $# -eq 0 ]]; then
		error "No arguments provided"
		return 1
	fi

	debug "command is '''$command'''"

	if [[ "$command" =~ "ASYNC_BATCH_INDEX=" ]]; then
		error ASYNC_BATCH_INDEX must not be modified!!!
		return 9
	fi

	local ASYNC_BATCH_SEM=$queueId
	if [[ -z "$queueId" && $# > $threads ]]; then
		async_sem $threads ASYNC_BATCH_SEM || return 9
	fi
	declare -r ASYNC_BATCH_SEM

	local ASYNC_BATCH_INDEX=0 ASYNC_BATCH_ELEMENT
	for ASYNC_BATCH_ELEMENT in "$@"; do
		((ASYNC_BATCH_INDEX++))

		local vars=''
		if [[ -n "$variable" ]]; then

			if ! [[ "$command" =~ "$"\{?"$variable" ]]; then
				error "parameter '$variable' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$command"
				echo >&2 '```'
				return 1
			fi

			vars+=" $variable=$(args_quoted "$ASYNC_BATCH_ELEMENT")"
		fi

		if [[ "$indexVar" ]]; then

			if ! [[ "$command" =~ \${?$indexVar ]]; then
				error "parameter '$indexVar' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$command"
				echo >&2 '```'
				return 1
			fi

			vars+=" $indexVar=$(args_quoted "$ASYNC_BATCH_INDEX")"

		fi

		debug "variables are $vars"

		if [[ -z "$ASYNC_BATCH_SEM" ]]; then
			# no queue, just run
			eval "(${vars:+ $vars &&} $command) &"
			continue
		fi

		if ! async_wait $ASYNC_BATCH_SEM; then
			local code=$?
			if isTrue $exit; then
				async_done $ASYNC_BATCH_SEM $code
				return $code
			fi
		fi

		if isTrue $verbose; then
			echo >&2 Batching item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
		fi

		_batch_done() {
			local exit=$?
			async_done $ASYNC_BATCH_SEM
			
			if isTrue $verbose; then
				echo >&2 Done item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
			fi
			return $exit
		}
		eval "{ (${vars:+ $vars &&} $command); _batch_done; } &"
	done 

	if [[ -z "$queueId" && $ASYNC_BATCH_SEM ]]; then
		async_close $ASYNC_BATCH_SEM
	fi

}

async_cat() {
	local tmp=$ASYNC_TMP/cat dir
	mkdir -p $tmp
	dir="$(mktemp -d -p $tmp)"
	debug "Temp dir is '$dir'"

	__cleanup() {
		rm -f $catQueue
		if ! isTrue $DEBUG; then
			rm -r $dir
		fi
	}

	local ordered
	local threads variable exit verbose file
	@ARGS

		-o | --preserve-order ) ordered=true
			shift
			;;

		# output is a stream of json objects (one per line)
		--json ) json=true
			shift
			;;

		# async_batch args
		
		-n | -t | --threads ) threads="$2"
			shift
			shift
			;;

		-v | --for | --variable ) variable="$2"
			shift
			shift
			;;

		-f | --file) file="$2"
			shift
			shift
			;;

		-e | --exit ) exit=true
			shift
			;;

		# Use an existing semaphore queue, specified by its id
		-q | --queue | --semaphore ) queueId="$2"
			shift
			shift
			;;

		-V | --verbose ) verbose=true
			shift
	@ENDARGS

	if [[ -n "$file" ]]; then
		command="$(cat "$file")"
	else
		command="$1"
		shift
	fi

	local catQueue="$(:+ $queueId $tmp/$queueId $dir/lock)"

	file="$dir/\$ASYNC_BATCH_INDEX"
	(
	async_batch $(arg_bool exit verbose) -t "$threads" --for "$variable" -q "$queueId" "
		command=$(args_quoted "$command")
		
		if isTrue $json; then
			{ $command; } | jq -sc 'flatten | .[]'
			exit $?
		fi

		{ $command; } >$file

		ASYNC_CAT_EXIT=$?
		if ! isTrue $ordered; then
			_trace async_cat: ${queueId:-$dir} awaiting lock for i=$file
			flock $catQueue cat $file
			_trace async_cat: ${queueId:-$dir} freed by i=$file
		fi
		(exit \$ASYNC_CAT_EXIT)
	" "$@"

	wait
	)
	local exitCode="$?"

	(
	cd $dir
	if isTrue $ordered; then
		seq 1 $# | xargs cat
	fi
	)

	__cleanup
	return "$exitCode"
}
