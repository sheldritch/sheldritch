#!/bin/bash
# shellcheck disable=SC2064

source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function _trap_cmd { Command="${3:-true}"; }

function trap_return_add {
	@func_use_parent

	local OldTrap Command NewCommand="$1"
	shift || return 9
	OldTrap="$(trap -p RETURN)"

	eval "_trap_cmd $OldTrap"
	trap -- "$Command; $NewCommand; $OldTrap" RETURN

	for ((I = 0; I <= ParentLevel; I++)); do
		trap "$(trap -p RETURN)" RETURN
	done
}
declare -f -t trap_return_add

# appends a command to a trap
#
# - 1st arg:  code to add
# - remaining args:  names of traps to modify
#
function trap_add {
    local NewCommand="$1" Signal Command
	shift || return 9

    for Signal in "$@"; do
		eval "__trap_cmd $(trap -p "$Signal")"
        trap -- "$Command; $NewCommand" "$Signal"
    done
}
declare -f -t trap_add

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

REPLY()     { [[ $# -gt 0 ]] && REPLY="$1" || printf '%s\n' "$REPLY"; }

deref() {
	_help_deref
	declare -p "$1" >/dev/null && eval "REPLY=\"\$$1\"" && REPLY
}
function lowercase { REPLY "$(stdin "$1" tr '[:upper:]' '[:lower:]')"; }
function uppercase { REPLY "$(stdin "$1" tr '[:lower:]' '[:upper:]')"; }

function stdin {
	local string="$1"
	shift
	if [[ -z "$string" || "$string" = --help ]]; then
		echo "stdin:"
		echo "Usage: stdin VARIABLE COMMAND..."
		return 0
	fi

	"$@" <<SHELDRITCH_STDIN_COMPAT
		$string
SHELDRITCH_STDIN_COMPAT
}

if [[ -v BASH_VERSION ]]; then
	alias extglob='shopt_temp extglob'
	function lowercase { REPLY="${1,,}"; printf '%s\n' "$REPLY"; }
	function uppercase { REPLY="${1^^}"; printf '%s\n' "$REPLY"; }
	function deref     { _help_deref; REPLY="${!1}";  printf '%s\n' "$REPLY"; }

	function regex {
		_help_regex
		if (($#)); then
			[[ "$1" =~ $2 ]] || return $?
		fi
		MATCHES=( "${BASH_REMATCH[@]}" )
	}
	function rematch {
		_help_rematch
		regex "$@" || return $?
		recapture 0
	}
	function recapture {
		_help_recapture
		REPLY="${BASH_REMATCH[$1]}"
		printf "%s" "$REPLY"
	}

# shellcheck disable=SC2296
elif [[ -v KSH_VERSION ]]; then
	alias extglob=':'
	alias local=typeset
	alias declare=typeset
	function lowercase { declare -l Val="$1"; Reply="$Val"; printf '%s\n' "$REPLY"; }
	function uppercase { declare -u Val="$1"; Reply="$Val"; printf '%s\n' "$REPLY"; }
	function regex {
		_help_regex
		if (($#)); then
			[[ "$1" =~ $2 ]] || return
		fi
		MATCHES=( "${.sh.match[@]}" )
	}
	function rematch {
		_help_rematch
		regex "$@" || return $?
		recapture 0
	}
	function recapture {
		_help_recapture
		REPLY="${.sh.match[$1]}"
		printf "%s" "$REPLY"
	}

# shellcheck disable=SC2296
elif [[ -v ZSH_VERSION ]]; then
	alias extglob='setopt KSH_GLOB'
	function lowercase { REPLY="${1:l}";  printf '%s\n' "$REPLY"; }
	function uppercase { REPLY="${1:u}";  printf '%s\n' "$REPLY"; }
	deref()     { REPLY="${(P)1}"; printf '%s\n' "$REPLY"; }

	function regex {
		_help_regex
		if (($#)); then
			[[ "$1" =~ $2 ]] || return
		fi
		MATCHES=( "$MATCH" "${match[@]}" )
	}
	function rematch {
		_help_rematch
		regex "$@" || return $?
		REPLY="$MATCH"
		printf "%s" "$REPLY"
	}
	function recapture {
		_help_recapture
		setopt KSH_ARRAYS
		# shellcheck disable=SC2124
		REPLY="${match[$1 - 1]}"
		printf "%s" "$REPLY"
	}

fi

unalias \
	_help_deref \
	_help_regex \
	_help_rematch \
	_help_recapture \

return 0
