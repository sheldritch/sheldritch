source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function file_first {
	# dependencyless func
	typeset File=''
	REPLY=
	for File in "$@"; do
		[[ -f "$File" ]] && REPLY="$File" && break
	done
	[[ -n "$REPLY" ]] && echo "$REPLY"
}

function fopen {

	local _sem="16" # Leave small fds for safety
	while [ -e /dev/fd/$_sem ]; do
		_sem=$((_sem + 1))
	done

	safe_set "$2" _sem || return $?

	eval "exec ${_sem}<>$SEMS/$1"
}

function su_write {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null "$1"
}

function su_append {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null -a "$1"
}

