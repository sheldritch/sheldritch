#!/bin/zsh
# shellcheck disable=SC2296
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

[[ "$THIS_SHELL" = zsh ]] || return 0

# Safely source the base shell file, preventing infinite loops
if [[ -z "$SHELDRITCH_COMPAT_EXEC" ]]; then
	self_file >/dev/null
	SHELDRITCH_COMPAT_EXEC=1 source "${REPLY%.zsh}".sh
fi

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

function keys {
	REPLY=("${(@k)${(P)1}}")
}

unalias \
	_help_deref \
	_help_regex \
	_help_rematch \
	_help_recapture \

# needs \n
