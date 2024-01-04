source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool util/shell/random.sh

SEMS=/tmp/tools/async/semaphores
mkdir -p $SEMS

# modified from https://unix.stackexchange.com/a/216475

# initialize a semaphore with a given number of tokens
# async_sem(){
# 	SEM="3"
# 	while [ -e /dev/fd/$SEM ]; do
# 		SEM=$(($SEM + 1))
# 	done

# 	id="$(random_digit -c 8)"
#     mkfifo $SEMS/$id
#     eval "exec ${SEM}<>$SEMS/$id"
#     rm $SEMS/$id
#     local i=$1
#     for((;i>0;i--)); do
#         printf %s 000 >&"${SEM}"
#     done
# }

async_wait() {
	local x
	read -u "${SEM}" -n 3 x && ((0==x)) || return $x
}

async_done() {
	printf '%.3d' $? >&"${SEM}"
}

async_batch() {
	usage() {
		echo >&2 'Usage: async_batch [options] COMMAND ELEMENTS...'
		print_usage '[options] --for VAR "COMMAND CONTAINING $VAR" ELEMENTS...'
	}

	local threads
	@ARGS
		-n | -t | --threads ) threads="$2"
			shift
			shift
			;;

		-v | --for | --variable ) variable="$2"
			shift
			shift
	@ENDARGS

	threads="${threads:-$(lscpu | awk '/^CPU\(s):/ {print $2}')}"
	command="$1"
	shift

	async_sem $threads || return 1
	for ASYNC_BATCH_ITERATOR in "$@"; do
		if [ "$variable" ]; then
			local "$variable=$ASYNC_BATCH_ITERATOR"
		fi
		async_wait
		eval "{ $command; async_done; } &"
	done 
}
