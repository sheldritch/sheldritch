source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool util/shell/random.sh

SEMS=/tmp/tools/async/semaphores
mkdir -p $SEMS

# modified from https://unix.stackexchange.com/a/216475

# initialize a semaphore with a given number of tokens
async_sem() {

	if ! declare -p $2 >/dev/null; then
		error "variable '$2' must be declared beforehand"
		echo >&2 "Please call 'local $2' above this function call, and 'declare -r $2' afterwards."
		return 9

	elif [[ -n "${!2}" ]]; then
		error "'$2' Must be a fresh variable, do not set it to some initial value."
		return 9

	elif [ "$2" = _sem ]; then
		error variable cannot be _sem
		return 9
	fi

	local _sem="16" # Leave small fds for safety
 	while [ -e /dev/fd/$_sem ]; do
 		_sem=$(($_sem + 1))
 	done

	id="$(random_digit -c 8)"
    mkfifo $SEMS/$id
    eval "exec ${_sem}<>$SEMS/$id"
    rm $SEMS/$id
    local i=$1
    for ((;i>0;i--)); do
        printf %s 000 >&"${_sem}"
    done

	eval $2="$_sem"
}

async_close() {
	eval "exec ${1}>&-"
}

async_wait() {
	local sem="${1:-$SEM}"
	_tools_trace "Awaiting sem '$sem' to be freed"
	if ! read -u "$sem" -N 3 ASYNC_LAST_EXIT; then
		error "read returned error '$?'"
		return 9
	fi

	return $ASYNC_LAST_EXIT
}

async_done() {
	exit=${2:-$?}
	local sem="${1:-$SEM}"
	printf '%.3d' $exit >&"$sem" || return $?
	_tools_trace "async: released semaphore $sem"
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

	if [ "$TOOLS_TRACE" ]; then
		verbose=true
	fi

	threads="${threads:-$(lscpu | awk '/^CPU\(s):/ {print $2}')}"

	if [ -n "$file" ]; then
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
	if [[ -z "$queueId" ]]; then
		async_sem $threads ASYNC_BATCH_SEM || return 9
	fi
	declare -r ASYNC_BATCH_SEM

	local ASYNC_BATCH_INDEX=1 ASYNC_BATCH_ELEMENT
	for ASYNC_BATCH_ELEMENT in "$@"; do

		if [ -n "$variable" ]; then

			if ! [[ "$command" =~ "$"\{?"$variable" ]]; then
				error "parameter '$variable' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$command"
				echo >&2 '```'
				return 1
			fi

			local "$variable=$ASYNC_BATCH_ELEMENT" || return 1
			debug "variable '$variable' is ${!variable}"
		fi

		if [ "$indexVar" ]; then

			if ! [[ "$command" =~ \${?$indexVar ]]; then
				error "parameter '$indexVar' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$command"
				echo >&2 '```'
				return 1
			fi

			local "$indexVar=$ASYNC_BATCH_INDEX" || return 1

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
			async_done $ASYNC_BATCH_SEM
			
			if isTrue $verbose; then
				echo >&2 Done item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
			fi
		}
		eval "{ ($command); _batch_done; } &"
		((ASYNC_BATCH_INDEX++))
	done 

	if [[ -z "$queueId" ]]; then
		async_close $ASYNC_BATCH_SEM
	fi

}

async_cat() {
	local tmp=/tmp/tools/async/ dir
	mkdir -p $tmp
	dir="$(mktemp -d -p $tmp)"
	debug "Temp dir is '$dir'"

	__cleanup() {
		async_close $cat
		eval "exec $cat>&-"
		if ! isTrue $DEBUG; then
			rm -r $dir
		fi
	}

	local ordered
	local threads variable indexVar exit verbose file
	@ARGS

		-o | --preserve-order ) ordered=true
			shift
			;;

		# output is a stream of json objects (one per line)
		--json ) ordered=true
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

	if [ -n "$file" ]; then
		command="$(cat "$file")"
	else
		command="$1"
		shift
	fi

	local cat
	async_sem 1 cat || return 9
	declare -r cat

	file="$dir/\$ASYNC_BATCH_INDEX"
	(
	async_batch $(arg_bool exit verbose) -t "$threads" --for "$variable" -q "$queueId" "
		
		if isTrue $json; then
			{ $command; } | jq -s 'flatten | .[]'
			exit $?
		fi

		{ $command; } >$file

		ASYNC_CAT_EXIT=$?
		if ! isTrue $ordered; then
			async_wait $cat
			_tools_trace async_cat: fd $cat locked for i=$file
			cat $file
			async_done $cat
			_tools_trace async_cat: fd $cat freed by i=$file
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
