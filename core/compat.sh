#!/bin/bash
# shellcheck disable=SC2064

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function _trap_cmd { Command="${3:-true}"; }

function trap_return_add {
	@func_use_parent

	typeset OldTrap Command NewCommand="$1"
	shift || return 9
	OldTrap="$(trap -p RETURN)"

	eval "_trap_cmd $OldTrap"
	trap -- "$Command; $NewCommand; $OldTrap" RETURN

	for ((I = 0; I <= ParentLevel; I++)); do
		trap "$(trap -p RETURN)" RETURN
	done
}
typeset -f -t trap_return_add

# appends a command to a trap
#
# - 1st arg:  code to add
# - remaining args:  names of traps to modify
#
function trap_add {
    typeset NewCommand="$1" Signal Command
	shift || return 9

    for Signal in "$@"; do
		eval "__trap_cmd $(trap -p "$Signal")"
        trap -- "$Command; $NewCommand" "$Signal"
    done
}
typeset -f -t trap_add

function shopt_temp {
	trap_return_add -p 1 "$(shopt -p "$@")"
	shopt -s "$@"
}
function shopt_temp_unset {
	trap "$(shopt -p "$@")" RETURN
	shopt -u "$@"
}


# help code for various compatibility shells

alias _help_deref='
	if [[ "$1" = --help ]]; then
		echo "deref: Return the value of a variable, given its name"
		echo "Usage: deref VARIABLE_NAME"
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
		echo "rematch: Return a capture group from the last tested regex pattern"
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
	if [[ -z "${string+ }" || "$string" = --help ]]; then
		echo >&2 "stdin:"
		echo >&2 "Usage: stdin VARIABLE COMMAND..."
		return 0
	fi

	"$@" <<SHELDRITCH_STDIN_COMPAT
$string
SHELDRITCH_STDIN_COMPAT
}
