#!/bin/bash
# shellcheck disable=SC2296
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

[[ "$THIS_SHELL" = bash ]] || return 0

summon sheldritch/core/compat.sh

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

