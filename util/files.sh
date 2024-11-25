source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

fopen() {

	local _sem="16" # Leave small fds for safety
	while [ -e /dev/fd/$_sem ]; do
		_sem=$((_sem + 1))
	done

	safe_set "$2" _sem || return $?

	eval "exec ${_sem}<>$SEMS/$1"
}

su_write() {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null "$1"
}

su_append() {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null -a "$1"
}

