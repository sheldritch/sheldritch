#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1;
check_is_sourced

summon sheldritch/core/args.sh

# TODO: document these functions effectively.

function git_stash_safe {
	if git diff-index --quiet HEAD "$@"; then
		return 1
	fi
	git stash "$@"
}

function git_dir {
	local Path Dir Cwd
	Cwd="${PWD:-$(pwd)}"
	Path="${1:-.}"
	if ! [[ -e "$Path" ]]; then
		error nothing exists at "'$Path'"
		return 1
	elif [[ -d "$Path" ]]; then
		Dir="$Path"
	else
		Dir="$(dirname "$Path")"
	fi

	cd "$Dir" || return 1
	while ! [[ -e ".git" ]]; do
		if ! cd .. 2>/dev/null; then
			error "No .git dir found in any parent dirs"
			cd "$Cwd" || error "REALLY BAD ERROR: could not swap back to '$Cwd'!!!"
			return 1
		fi
	done
	REPLY="${PWD:-$(pwd)}"
	echo "$REPLY"
}
