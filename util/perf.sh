
timer_start() { _TIMER="$(now)"; }

timer_lap() {
	local now="$(now)"
	echo "$(echo $now - ${_TIMER_LAP:$_TIMER} | bc)" >&2
	_TIMER_LAP="$now"
}
