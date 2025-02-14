#!/bin/ksh
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

[[ "$THIS_SHELL" = ksh ]] || return 0

summon sheldritch/core/compat.sh

alias extglob=':'
alias local=typeset
alias declare=typeset

function lowercase { typeset -l Val="$1"; Reply="$Val"; printf '%s\n' "$REPLY"; }
function uppercase { typeset -u Val="$1"; Reply="$Val"; printf '%s\n' "$REPLY"; }
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

function keys {
	eval 'REPLY=("${!'"$1"'[@]}")'
}

unalias \
	_help_deref \
	_help_regex \
	_help_rematch \
	_help_recapture \

