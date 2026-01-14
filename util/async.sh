#!/bin/bash

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1
check_is_sourced

summon sheldritch/data/random.sh

ASYNC_TMP=$SHELDRITCH_TMP/async
SEMS=$ASYNC_TMP/semaphores
mkdir -p $SEMS

function flock {
	@help "
	This is Sheldritch's poor fellow's flock implementation.
	You really should install a real one instead.

	Usage:
	flock FILE COMMAND
	flock FILE -c 'COMMAND'
	" && return

	local Bin
	if Bin="$(which flock 2>/dev/null)"; then
		"$Bin" "$@"
	else

		if [[ $# -lt 2 || "$1" != *[^0-9]* || "$1" == -* ]]; then
			error -p 1 "flock: only supported usages are:
			flock FILE COMMAND
			flock FILE -c 'COMMAND'

			Note: You are using Sheldritch's poor person's flock fallback
			You should probably install a real flock alternative.
			"
			return 9
		fi

		local Path Lock
		Path="$(realpath -m "$1")" || return
		shift
		Lock="$ASYNC_TMP/flock/$Path/LOCK"

		while true; do
			if ! [[ -d "$Lock" ]]; then
				if [[ "$(mkdir -v -p "$Lock")" ]]; then
					(
					trap 'rmdir "$Lock"' EXIT
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
	@help '
	Initialise a semaphore with a given number of tokens in its queue.

	Usage: async_sem QUEUE_SIZE
	Returns: the semaphore ID (also in REPLY variable)
	' && return

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
	@help '
	Close the given semaphore
	Usage: async_close SEMAPHORE_ID
	' && return
	rm "$SEMS/$1"{,-read,-write}
}

function async_wait {
	@help '
	Wait for the given semaphore to be freed.
	Usage: async_wait SEMAPHORE_ID
	' && return

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
	@help '
	Release a semaphore lock.
	Usage: async_done SEMAPHORE_ID
	' && return
	local Sem="${1:-$SEM}" Exit=${2:-$?} Fifo
	Fifo="$SEMS/$Sem"
	(
	flock $Fifo-write -c "echo $Exit >>$Fifo" >/dev/null 2>&1 &
	disown
	)
	_trace "async: released semaphore $Sem"
}

function _async_batch_args {
	Usage+=(
		'COMMAND ELEMENTS...'
		'--file=COMMAND_FILE ELEMENTS...'
		'--for=VAR COMMAND_CONTAINING_$VAR ELEMENTS...'
	)
	Options+=(
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
}

function async_batch {
	@func_info
	About='run a command asyncronously for each given element, ensuring that only a certain number
			of commands are running at any given time'
	_async_batch_args
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
	@func_info
	About='Safely concatenate the output of asyncronous tasks'
	# see for further documentation
	_async_batch_args
	Options+=(
		-o --preserve-order --ordered "produce output in order of job dispatch"
		--json "output is a stream of json objects (one per line)"
	)
	opts_parse

	local Tmp=$ASYNC_TMP/cat Dir
	mkdir -p $Tmp
	Dir="$(mktemp -d -p $Tmp)"
	debug "Temp dir is '$Dir'"

	function __cleanup {
		rm -f $CatQueue
		if ! isTrue $DEBUG; then
			rm -r $Dir
		fi
	}

	if [[ -n "$File" ]]; then
		Command="$(cat "$File")"
	else
		Command="$1"
		shift
	fi

	local CatQueue="$(:+ $QueueId $Tmp/$QueueId $Dir/lock)"

	File="$Dir/\$ASYNC_BATCH_INDEX"
	(
	async_batch $(arg_bool exit verbose) -t "$Threads" --for "$Variable" -q "$QueueId" "
		Command=$(args_quoted "$Command")

		if isTrue $Json; then
			{ $Command; } | jq -sc 'flatten | .[]'
			exit $?
		fi

		{ $Command; } >$File

		ASYNC_CAT_EXIT=$?
		if ! isTrue $Ordered; then
			_trace async_cat: ${QueueId:-$Dir} awaiting lock for i=$File
			flock $CatQueue cat $File
			_trace async_cat: ${QueueId:-$Dir} freed by i=$File
		fi
		(exit \$ASYNC_CAT_EXIT)
	" "$@"

	wait
	)
	local ExitCode="$?"

	(
	cd $Dir
	if isTrue $Ordered; then
		seq 1 $# | xargs cat
	fi
	)

	__cleanup
	return "$ExitCode"
}
