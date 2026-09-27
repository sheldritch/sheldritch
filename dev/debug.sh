#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1;
check_is_sourced

function debug_enable {
	@help 'Enable debug messages' && return 1
	DEBUG=1
}

function debug_disable {
	@help 'Disable debug messages' && return 1
	DEBUG=0
}

function trace_enable {
	@help '
	When executing, print function names and arguments if they use the @func_info construct.

	This mimics set -x functionality, but reduces output to high-level function calls, making it more readable.
	' && return 1
	TRACE=1
}

function trace_disable {
	@help 'Disable Sheldritch trace functionality.' && return
	unset TRACE
}

# Run arguments as a command, with the `set -x` flag temporarily set.
function step_through {
	trap 'set +x' INT
	local Fail=0
	set -x
	"$@" || Fail=$?
	set +x
	return $Fail
}
