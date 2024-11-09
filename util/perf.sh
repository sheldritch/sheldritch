
timer_start() { TOOLS_TIMER="$(now)"; }

timer_lap() {
	local now="$(now)"
	echo "$(echo $now - ${TOOLS_TIMER_LAP:$TOOLS_TIMER} | bc)" >&2
	TOOLS_TIMER_LAP="$now"
}
