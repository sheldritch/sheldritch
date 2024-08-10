source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool util/shell/random.sh

SEMS=/tmp/tools/async/semaphores
mkdir -p $SEMS

# modified from https://unix.stackexchange.com/a/216475

# initialize a semaphore with a given number of tokens
async_sem(){
	SEM="16" # Leave small fds for safety
 	while [ -e /dev/fd/$SEM ]; do
 		SEM=$(($SEM + 1))
 	done

	id="$(random_digit -c 8)"
    mkfifo $SEMS/$id
    eval "exec ${SEM}<>$SEMS/$id"
    rm $SEMS/$id
    local i=$1
    for ((;i>0;i--)); do
        printf %s 000 >&"${SEM}"
    done

	if [ "$2" ]; then
		declare -g "$2"="$SEM"
	fi
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
	exit=$?
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

	local threads variable indexVar exit verbose file
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

		-f | --file) file="$2"
			shift
			shift
			;;

		-e | --exit ) exit=true
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
	for var in ASYNC_BATCH_INDEX ASYNC_BATCH_ELEMENT; do
		if [ "${!var}" ]; then
			error "$var must not be set!!"
			return 9
		fi
	done

	debug "command is '''$command'''"

	async_sem $threads ASYNC_BATCH_SEM || return 9
	local ASYNC_BATCH_INDEX=1 ASYNC_BATCH_ELEMENT
	for ASYNC_BATCH_ELEMENT in "$@"; do

		if [ -n "$variable" ]; then
			local "$variable=$ASYNC_BATCH_ELEMENT" || return 1
			debug "variable '$variable' is ${!variable}"
		fi

		if [ "$indexVar" ]; then
			local "$indexVar=$ASYNC_BATCH_INDEX" || return 1
		fi
		if ! async_wait $ASYNC_BATCH_SEM; then
			local code=$?
			if isTrue $exit; then
				return $code
			fi
		fi


		if isTrue $verbose; then
			echo >&2 Batching item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
		fi

		eval "{
			DEBUG=$DEBUG
			$command
			async_done $ASYNC_BATCH_SEM
			
			if isTrue $verbose; then
				echo >&2 Done item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
			fi
		} &"
		((ASYNC_BATCH_INDEX++))
	done 

	eval "exec ${ASYNC_BATCH_SEM}>&-"
}

async_cat() {
	local tmp=/tmp/tools/async/ dir
	mkdir -p $tmp
	dir="$(mktemp -d -p $tmp)"
	debug "Temp dir is '$dir'"

	__cleanup() {
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

		-V | --verbose ) verbose=true
			shift
	@ENDARGS

	if [ -n "$file" ]; then
		command="$(cat "$file")"
	else
		command="$1"
		shift
	fi

	async_sem 1 cat || return 9
	file="$dir/\$ASYNC_BATCH_INDEX"
	(
	async_batch $(arg_bool exit verbose) -t "$threads" --for "$variable" "
		
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

	cd $dir
	if isTrue $ordered; then
		seq 1 $# | xargs cat
	fi
	)
	wait
	__cleanup
}
