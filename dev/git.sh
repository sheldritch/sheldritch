#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1;
check_is_sourced

summon sheldritch/core/args.sh

# TODO: document these functions effectively.

function git_stash_safe {
	@help "Perform a git stash, only if there is anything to stash.
	Otherwise, fail with return code 1." && return

	if git diff-index --quiet HEAD "$@"; then
		return 1
	fi
	git stash "$@"
}

function git_root {
	@func_info
	About='Print the directory containing the git root for the given (or current) directory.'
	Usage='[PATH]'
	Legend=(
		DIRECTORY "Defaults to '.'. The directory to find the git root for."
	)
	parse_args

	local Dir Cwd OldWd
	Cwd="${PWD:-$(pwd)}" || return
	OldWd="$OLDPWD"

	if ! [[ -e "$Path" ]]; then
		error "nothing exists at path '$Path'"
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
			OLDPWD="$OldWd"
			return 1
		fi
	done
	REPLY="${PWD:-$(pwd)}"
	echo "$REPLY"
	cd "$Cwd" || error "REALLY BAD ERROR: could not swap back to '$Cwd'!!!"
	OLDPWD="$OldWd"
}

function git_root_cd {
	@func_info
	About='Change the current directory to the git root for the given directory.'
	Usage='[PATH]'
	Legend=(
		DIRECTORY "Defaults to '.'. The directory to find the git root for."
	)
	parse_args
	git_root "$@" >/dev/null
	cd "$REPLY"
}
