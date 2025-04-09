#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1;
check_is_sourced

summon sheldritch/core/args.sh

function dirstack_get {
	@help '
		dirstack_get: get a directory at the given index in the directory stack
		Indexed from 0.
		Usage:
		dirstack_get INDEX [COUNT]
		# get all directories from INDEX
		dirstack_get INDEX -1
	' && return
	REPLY=''
	local LineRe=$'([^\n]+(\n|$))' Index="${1:-0}" Length="${2:-1}"
	if ((Length == 0)); then
		return
	elif ((Length < 0)); then
		[[ "$(dirs -p)" =~ $LineRe{$Index}($LineRe*)$LineRe{$((-Length - 1))} ]]
	else
		[[ "$(dirs -p)" =~ $LineRe{$Index}($LineRe{$Length}) ]]
	fi || return
	recapture 3 >/dev/null || return 2
	REPLY="${REPLY%$'\n'}"
	REPLY="${REPLY/#\~/$HOME}"
	((Length == 1)) || REPLY="${REPLY/#$'\n~'/$'\n'$HOME}"
	REPLY
}
