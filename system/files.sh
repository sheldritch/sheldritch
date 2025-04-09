[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
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

# (C) CC BY-SA 3.0
# modified from https://stackoverflow.com/a/23002317/29892672
function abspath {
	# shellcheck disable=SC2016
	@help '
    generate absolute path from relative path
	Usage: abspath RELATIVE_PATH
	' && return

	# Optimised for speed, reducing subshells where possible
	# shellcheck disable=SC2164
	if [[ $1 = /* ]]; then
		REPLY "$1"

	elif ! [[ $1 == */* || $1 =~ /|(/|^)\.\.?(/|$) ]]; then
		REPLY "$PWD/$1"

    elif [[ -d "$1" ]]; then
        REPLY "$(cd "$1"; pwd)"

    elif [[ -f "$1" ]]; then
		# TODO: test if subshell is faster than the following
		# local Dir="$PWD" Old="$OLDPWD" Exit=0
		# cd "${1%/*}" || Exit=1
		# REPLY "$PWD/${1##*/}"
		# cd $Old
		# cd $Dir
		# return $Exit
		REPLY "$(cd "${1%/*}"; pwd)/${1##*/}"
	else
		REPLY "$(realpath -m "$1")"
    fi
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

