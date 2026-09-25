#!/bin/bash
# shellcheck disable=SC2064

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function _trap_cmd { Command="${3:-true}"; }

function trap_get {
	bash_run trap -p "$1"
	zsh_run trap | grep "$1\$"
	ksh_run error 'not supported'
}

function trap_return_add {
	@help "
	trap_return_add:
	The behaviour of return traps are really wacky, this function tries to provide a standard behaviour that's useful in certain cases.

	Be warned, this function needs FAR more testing and documentation (like, standard behaviour? Are you gonna tell us what that is?),
	especially when shell behaviour is fairly unique, plus there are a bunch of flags and options that change shell behaviour.
	" && return

	@func_use_parent

	typeset OldTrap Command NewCommand="$1" Trap=EXIT
	shift || return 9

	if [[ -n "${BASH_VERSION-}" ]]; then
		Trap=RETURN
		if [[ $- = *T* ]]; then
			warn "
			You have the -T shell flag set, which automatically inherits RETURN traps.

			It is not confirmed that Sheldritch's trap_return_add compatibility function
			provides the same behaviour as the -T flag, so please report if there are any bugs related to this"
			return 0
		fi
	fi
	OldTrap="$(trap_get $Trap)"

	eval "_trap_cmd $OldTrap"
	trap -- "$Command; $NewCommand; $OldTrap" $Trap

	for ((I = 0; I <= ParentLevel; I++)); do
		trap "$(trap_get $Trap)" $Trap
	done
}
typeset -f -t trap_return_add

function trap_add {
	@help '
	trap_add: appends a command to a trap, while keeping the previous trap commands.

	- 1st arg:  code to add
	- remaining args:  names of traps to modify
	' && return

    typeset NewCommand="$1" Signal Command
	shift || return 9

    for Signal in "$@"; do
		eval "__trap_cmd $(trap_get "$Signal")"
        trap -- "$Command; $NewCommand" "$Signal"
    done
}
typeset -f -t trap_add

function shopt_temp {
	@help '
	shopt_temp: same as `shopt -s`, but only applies changes within the given function.
	' && return
	trap_return_add -p 1 "$(shopt -p "$@")"
	shopt -s "$@"
}
function shopt_temp_unset {
	@help '
	shopt_temp_unset: same as `shopt -u`, but only applies changes within the given function.
	' && return
	trap "$(shopt -p "$@")" RETURN
	shopt -u "$@"
}

function set_temp {
	@help '
	set_temp: same as `set`, but only applies changes within the given function.
	' && return

	if [[ "$1" = *o* ]]; then
		error -p 1 'set_temp: -o not supported'
		return 9
	fi
	typeset CurrentlySet=${-//[^$1]/} CurrentlyUnset

	if [[ "$1" = +* ]]; then
		[[ -n "$CurrentlySet" ]] || return 0
		# temp unset
		trap_return_add -p 1 "set -${-//[^$1]/}"
		set "$1"
		return
	fi
	CurrentlyUnset="${1//[-$CurrentlySet]/}"
	[[ -n "$CurrentlyUnset" ]] || return 0
	trap_return_add -p 1 "set +$CurrentlyUnset)"
	set "$1"
}

# help code for various compatibility shells

alias _help_deref='
	if [[ "$1" = --help ]]; then
		echo "deref: Return the value of a variable, given its name"
		echo "Usage: deref VARIABLE_NAME"
		return 0
	fi'
alias _help_keys='
	if [[ "$1" = --help ]]; then
		echo "keys: populate the RETURN value with a list of keys for the given associative array"
		echo "Usage: keys ARRAY_NAME"
		return 0
	fi'
alias _help_regex='
	if [[ "$#" -eq 1 && "$1" = --help ]]; then
		echo "regex: Test a string against a given regex pattern"
		echo "Usage: STRING REGEX_PATTERN"
		return 0
	fi'
alias _help_rematch='
	if [[ "$#" -eq 1 && "$1" = --help ]]; then
		echo "rematch: Test a string against a given regex pattern and return its full match"
		echo "Usage: STRING REGEX_PATTERN"
		return 0
	fi'
alias _help_recapture='
	if [[ "$#" -eq 1 && "$1" = --help ]]; then
		echo "recapture: Return a capture group from the last tested regex pattern"
		echo "Usage: CAPTURE_GROUP"
		echo "Usage: { 1-9 }"
		return 0
	fi'

# shell defaults
# these are overwritten with more performant shell-specific implementations
#

REPLY() {
	if [[ $# -gt 0 ]]; then
		REPLY="$1"
	fi
	printf '%s\n' "$REPLY"
	[[ -n "$REPLY" ]]
}

deref() {
	_help_deref
	typeset -p "$1" >/dev/null && eval "REPLY=\"\$$1\"" && REPLY
}
function lowercase { REPLY "$(stdin "$1" tr '[:upper:]' '[:lower:]')"; }
function uppercase { REPLY "$(stdin "$1" tr '[:lower:]' '[:upper:]')"; }

function vars_with_prefix {
	REPLY=''
	REPLY "$(for arg in "$@"; do
		typeset -p | sed -n 's/^[a-z]\+ [^ ]\+ \('"$1"'[^=]*\).*/\1/p'
	done)"
}
function funcs_with_prefix {
	REPLY=''
	REPLY "$(for arg in "$@"; do
		typeset -p ${BASH_VERSION:+-F} -f | sed -n 's/^[a-z]\+ [^ ]\+ \('"$1"'[^=]*\).*/\1/p'
	done)"
}

function stdin {
	typeset string="$1"
	shift
	if [[ $# -eq 0 && "$string" = --help ]]; then
		echo "stdin:"
		echo "Usage: stdin VARIABLE COMMAND..."
		return 0
	fi

	"$@" <<SHELDRITCH_STDIN_COMPAT
$string
SHELDRITCH_STDIN_COMPAT
}

# Source the appropriate shell file, preventing infinite loops
if [[ -z "$SHELDRITCH_COMPAT_EXEC" ]]; then
	self_file >/dev/null
	if [[ -f "${REPLY%.sh}".$THIS_SHELL ]]; then
		SHELDRITCH_COMPAT_EXEC=1 source "${REPLY%.sh}".$THIS_SHELL
	fi
fi
