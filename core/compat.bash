#!/bin/bash
# shellcheck disable=SC2296
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

[[ "$THIS_SHELL" = bash ]] || return 0

self_file >/dev/null
# directly source
# If added to SHELDRITCH_SOURCES, re-syncing may clobber bash overrides
source "${REPLY%.bash}".sh

alias extglob='shopt_temp extglob'
function lowercase { REPLY="${1,,}"; printf '%s\n' "$REPLY"; }
function uppercase { REPLY="${1^^}"; printf '%s\n' "$REPLY"; }
function deref     { _help_deref; REPLY="${!1}";  printf '%s\n' "$REPLY"; }

function regex {
	_help_regex
	[[ "$1" =~ $2 ]]
	MATCHES=( "${BASH_REMATCH[@]}" )
	((${#MATCHES[@]}))
}
function rematch {
	_help_rematch
	if [[ "$#" -ne 0 ]]; then
		regex "$@" || return $?
	fi
	recapture 0
}
function recapture {
	_help_recapture
	REPLY="${BASH_REMATCH[$1]}"
	printf '%s\n' "$REPLY"
	[[ "${BASH_REMATCH[$1]+ }" ]]
}

function keys {
	_help_keys
	eval 'REPLY=("${!'"$1"'[@]}")'
}

unalias \
	_help_deref \
	_help_keys \
	_help_regex \
	_help_rematch \
	_help_recapture \

# needs \n
