#!/bin/bash

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1
check_is_sourced

summon sheldritch/data/random.sh

ASYNC_TMP=$SHELDRITCH_TMP/async
SEMS=$ASYNC_TMP/semaphores
mkdir -p $SEMS

function flock {
	local Bin
	if Bin="$(which flock 2>/dev/null)"; then
		"$Bin" "$@"
	else

		if [[ $# < 2 || "$1" != *[^0-9]* || "$1" == -* ]]; then
			error -p 1 "flock: only supported usages are:
			flock FILE COMMAND
			flock FILE -c 'COMMAND'

			note you are using Sheldritch's poor person's flock fallback
			you should probably install a real flock alternative.
			"
			return 9
		fi

		local path lock
		path="$(realpath -m "$1")" || return
		shift
		lock="$ASYNC_TMP/flock/$path/LOCK"

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
function async_sem {

	local Sem Fifo
	Sem="$(random_char -c 12 'A-Za-z0-9')" || return
	Fifo="$SEMS/$Sem"
	mknod $Fifo p || mkfifo $Fifo || return

	(
	local i=$1
	for ((;i>0;i--)); do
		flock $Fifo-write -c "echo 0 >>$Fifo" >/dev/null 2>&1 &
		disown
	done
	)

	REPLY "$Sem"
}

function async_close {
	rm "$SEMS/$1"{,-read,-write}
}

function async_wait {
	local Fifo="$SEMS/$1" Exit
	if ! [[ -p "$Fifo" ]]; then
		error "could not find async id $1"
		return 9
	fi

	_trace "Awaiting sem '$1' to be freed"
	if ! Exit="$(flock "$Fifo-read" head -1 "$Fifo")"; then
		error -p 1 "async_wait failed to retrieve a valid exit code"
	fi
	return "$Exit"
}

function async_done {
	local Sem="${1:-$SEM}" Exit=${2:-$?} Fifo
	Fifo="$SEMS/$Sem"
	(
	flock $Fifo-write -c "echo $Exit >>$Fifo" >/dev/null 2>&1 &
	disown
	)
	_trace "async: released semaphore $Sem"
}

function async_batch {
	@func_info
	About='run a command asyncronously for each given element, ensuring that only a certain number
			of commands are running at any given time'
	Usage=(
		'COMMAND ELEMENTS...'
		'--file=COMMAND_FILE ELEMENTS...'
		'--for=VAR COMMAND_CONTAINING_$VAR ELEMENTS...'
	)
	Options=(
		-n -t --threads=THREADS "The max number of commands to run in parallel"

		-v --for --variable=VARIABLE "The variable name to assign to the given element"
		# TODO: I don't think this works with shared queue IDs?
		-i --index=INDEX_VARIABLE
			"The variable name to assign the index of the given execution.

			Note that this only indexes the parameters of this command, not every
			item in the queue."

		-f --file=COMMAND_FILE       "read commands to run out of the given file"

		-e --exit "Exit as soon as possible after any command execution fails"
		-q --queue --semaphore=QUEUE_ID "Use an existing semaphore queue, specified by its ID."
		-v --verbose "produce verbose output"
	)
	opts_parse

	if [[ "$TRACE" ]]; then
		Verbose=true
	fi

	Threads="${Threads:-$(lscpu 2>/dev/null | awk '/^CPU\(s):/ {print $2}')}"
	Threads="${Threads:-8}"

	if [[ -n "$CommandFile" ]]; then
		Command="$(cat "$CommandFile")"
	else
		Command="$1"
		shift
	fi

	if [[ $# -eq 0 ]]; then
		error "No arguments provided"
		return 1
	fi

	debug "command is '''$Command'''"

	if [[ "$Command" =~ "ASYNC_BATCH_INDEX=" ]]; then
		error 'ASYNC_BATCH_INDEX must not be modified!!!'
		return 9
	fi

	local ASYNC_BATCH_SEM=$QueueId
	if [[ -z "$QueueId" && $# > $Threads ]]; then
		ASYNC_BATCH_SEM="$(async_sem $Threads)" || return 9
	fi
	declare -r ASYNC_BATCH_SEM

	local ASYNC_BATCH_INDEX=0 ASYNC_BATCH_ELEMENT
	for ASYNC_BATCH_ELEMENT in "$@"; do
		((ASYNC_BATCH_INDEX++))

		local Vars=''
		if [[ -n "$Variable" ]]; then

			if ! [[ "$Command" =~ "$"\{?"$Variable" ]]; then
				error "parameter '$Variable' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$Command"
				echo >&2 '```'
				return 1
			fi

			Vars+=" $Variable=$(args_quoted "$ASYNC_BATCH_ELEMENT")"
		fi

		if [[ "$IndexVariable" ]]; then

			if ! [[ "$Command" =~ \${?$IndexVariable ]]; then
				error "parameter '$IndexVariable' requested, but not found in given command."
				echo >&2 "Did you appropriately escape the dollar sign? Command as evaluated was:"
				echo >&2 '```'
				echo >&2 "$Command"
				echo >&2 '```'
				return 1
			fi

			Vars+=" $IndexVariable=$(args_quoted "$ASYNC_BATCH_INDEX")"

		fi

		debug "variables are $Vars"

		if [[ -z "$ASYNC_BATCH_SEM" ]]; then
			# no queue, just run
			eval "(${Vars:+ $Vars &&} $Command) &"
			continue
		fi

		if ! async_wait $ASYNC_BATCH_SEM; then
			local Code=$?
			if isTrue $Exit; then
				async_done $ASYNC_BATCH_SEM $Code
				return $Code
			fi
		fi

		if isTrue $Verbose; then
			echo >&2 Batching item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
		fi

		function _batch_done {
			local Exit=$?
			async_done $ASYNC_BATCH_SEM

			if isTrue $Verbose; then
				echo >&2 Done item '$ASYNC_BATCH_INDEX', value '$ASYNC_BATCH_ELEMENT'
			fi
			return $Exit
		}
		eval "{ (${Vars:+ $Vars &&} $Command); _batch_done; } &"
	done

	if [[ -z "$QueueId" && $ASYNC_BATCH_SEM ]]; then
		async_close $ASYNC_BATCH_SEM
	fi

}

function async_cat {
	local Tmp=$ASYNC_TMP/cat dir
	mkdir -p $Tmp
	dir="$(mktemp -d -p $Tmp)"
	debug "Temp dir is '$dir'"

	function __cleanup {
		rm -f $catQueue
		if ! isTrue $DEBUG; then
			rm -r $dir
		fi
	}

	local ordered
	local threads variable exit verbose file Command
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
		Command="$(cat "$file")"
	else
		Command="$1"
		shift
	fi

	local catQueue="$(:+ $queueId $Tmp/$queueId $dir/lock)"

	file="$dir/\$ASYNC_BATCH_INDEX"
	(
	async_batch $(arg_bool exit verbose) -t "$threads" --for "$variable" -q "$queueId" "
		Command=$(args_quoted "$Command")

		if isTrue $json; then
			{ $Command; } | jq -sc 'flatten | .[]'
			exit $?
		fi

		{ $Command; } >$file

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
