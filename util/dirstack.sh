#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1;
check_is_sourced

summon sheldritch/core/args.sh

function dirstack_get {
	REPLY=''
	local LineRe=$'([^\n]+(\n|$))' Index="${1:-0}" Length="${2:-1}"
	if ((Length == 0)); then
		return
	elif ((Length < 0)); then
		[[ "$(dirs -p)" =~ $LineRe{$Index}($LineRe*)$LineRe{$((0 - Length))} ]]
	else
		[[ "$(dirs -p)" =~ $LineRe{$Index}($LineRe{$Length}) ]]
	fi || return
	recapture 3 >/dev/null || return 2
	REPLY="${REPLY%$'\n'}"
	REPLY
}
