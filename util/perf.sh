
function timer_start { TOOLS_TIMER="${EPOCHREALTIME/./}" TOOLS_TIMER_LAP=''; }

function timer_lap {
	local now="${EPOCHREALTIME/./}"
	echo "${*:+$*: }$((now - ${TOOLS_TIMER_LAP:-$TOOLS_TIMER}))" >/dev/tty
	TOOLS_TIMER_LAP="$now"
}

function timer_total {
	local now="${EPOCHREALTIME/./}"
	echo "${*:+$*: }$((now - TOOLS_TIMER))µs" >/dev/tty
	TOOLS_TIMER_LAP="$now"
}
