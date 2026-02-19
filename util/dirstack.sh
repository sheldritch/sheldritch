#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1;
check_is_sourced

summon sheldritch/core/args
summon sheldritch/system/files

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

# shellcheck disable=SC2164
function dirstack_replace {
	@help '
		dirstack_replace: replace a given index in the directory stack with DIR
	' && return

	abspath "$1" >/dev/null || return 2
	local Dir="$REPLY" Index="${2:-1}"

	if [[ "$Index" == 0 ]]; then
		cd "$Dir"
	elif ! [[ -v ZSH_VERSION ]]; then
		DIRSTACK[Index]="$Dir"
	else
		declare -a Stack=()
		local i

		for (( i = 1; i < Index; ++i)); do
			dirstack_get "$i" >/dev/null
			Stack+=("$REPLY")
		done
		Stack+=("$Dir")
		while dirstack_get "$i" >/dev/null; do
			Stack+=("$REPLY")
		done

		dirs "${Stack[@]}"
	fi
}

function dirstack_swap {
	@help '
		dirstack_swap: replace a given index in the directory stack with DIR,
		and change directory to the value in that index previously
	' && return
	local Dir="$REPLY" Index="${2:-1}"
	error 'Not yet implemented'
	return 9
}
