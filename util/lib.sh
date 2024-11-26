#!/bin/bash
#
# Functions for importing and handling shell scripts like libraries
#
# This file does not depend on base.

# DESIGN:
#
# There are a few library management tools out there. Most have a custom dir containing libs, and
# their own way for accessing them. For instance, `sheldon` uses '$XDG_DATA_HOME/sheldon', and by
# default matches `<plugin-dir>.<shell`, `<plugin-dir>.sh` and `*.sh` in order.
#
# Because Sheldritch is more of a dev tool, you specify the exact module you want (usually by
# filename, sometimes by directory). But for general purpose plugin tools, we should be okay to make
# their directories available, which means we can piggyback off their own package management utils.
#
# The main thing for us to be careful about is re-sourcing these tools if we don't need to. If
# possible, we should detect what other plugin tools have already sourced, and not duplicate them if
# we can avoid it.
#
# Other tools we want to support:
# - sheldon https://github.com/rossmacarthur/sheldon?tab=readme-ov-file#plugin-options
# - basher https://github.com/basherpm/basher
#
# Tools which don't fit our format
# - bpkg www.bpkg.sh -- installs direct to bin

if [[ "$BASH_VERSION" ]]; then
	shopt -s expand_aliases
elif [[ "$ZSH_VERSION" ]]; then
	setopt aliases
fi

# shellcheck disable=SC2142
alias script_is_sourced='{ [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; }'

# shellcheck disable=SC2139
alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${0}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

if [[ -z "$SHELDRITCH" ]]; then
	echo >&2 "Error: sheldritch lib.sh: SHELDRITCH must be set to its directory"
	return 1
fi

main() {
	source_once "$SHELDRITCH/sheldritch.base.sh"
	source_once "$SHELDRITCH/system/xdg.sh"
}

check_is_sourced_func() {
	if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; then
		echo "You aren't sourcing ${0}. Make sure you are to have its libs available to you."
		exit 1
	fi
}

path_search() {
	local dir Path delim='\n'
	case "$1" in
		-0 | --zero ) delim='\0'
			shift 1 || return 1
			;;
		-d | --delimiter ) delim="$2"
			shift 2 || return 1
			;;
		-1 | --first ) first=1
			shift 2 || return 1
	esac

	Path="$1" 
	shift
	while read -rd : dir; do
		for Path in "$@"; do
			if [[ -e "$dir/$Path" ]]; then
				printf "%s$delim" "$dir/$Path"
			fi
		done
	done <<<"$Path"
}

find_bin() {
	for x in ${PATH//://*${1}* }*${1}*; do
		[ -f "$x" ] && echo $x
	done
}

path_add() {
	for Path in "$@"; do
		if ! [[ "$PATH" = *"$Path"* ]]; then
			export PATH="$PATH:$Path"
		fi
	done
}



# TODO: If we use .local/lib, there might be stuff in .local/share we also want to use
# We need to be careful about assuming that .local/lib is the best place for stuff, if
# .local/share is already being used but ./lib is not.
find_lib() {
	local libs
	if [[ -n "$LIBS" ]]; then
		libs="$LIBS"
	else
		libs="$HOME/.local/lib:$(xdg data-dirs)"
		libs="${SHELDON_DATA_DIR}:${LIBS//:/\/shell:}"
	fi

	while read -rd : dir; do
		if [[ -e "$dir/$1" ]]; then
			printf "%s" "$dir/$1"
			return
		fi
	done <<<"$libs"
	return 1
}

source_once() {
	local Path="$1"
	if ! [[ "$Path" = /* ]]; then
		Path="$(realpath -s "$1")"
	fi

	# TODO: test performance of array and hash in large tools context
	if [[ "$SHELDRITCH_SOURCES" = *"$Path"* ]]; then
		_trace "source_once: skipping export '$Path': Already sourced"
		return
	fi

	if [[ -x "$Path" ]]; then
		echo >&2 "Error: $Path is an executable, presumably not a sourced file."
		return 1
	fi

	SHELDRITCH_SOURCES+=$'\n'"$Path" # before source to prevent dependency loops
	_trace "source_once: sourcing '$Path'"
	_trace ""
	_trace "sources currently:"
	_trace "$SHELDRITCH_SOURCES"
	source "$1"
}

# imports the given library/file (relative to the library dir)
summon() {
	local HELP FORCE
	while [[ $# -ne 0 ]]; do
		case "$1" in
			-f | --force ) FORCE=true
				shift
				;;
			-h | --help ) HELP=true
				shift
				break
				;;
			* ) break
				;;
		esac
	done

	SHELDRITCH_CLEAN="$FORCE"

	if [[ "$HELP" = true ]]; then
		echo >&2 "summon -- imports the library/file (relative to the library dir)"
		echo >&2 "Usage: summon [--force] <lib>"
		return
	fi

	for lib in "$@"; do
		lib="$(find_lib "$lib")"

		if [[ "$SHELDRITCH_SOURCES" = *"$lib"* ]]; then
			continue
		fi

		if [[ -d "$lib" ]]; then
			_trace "Importing tools in directory '$lib'"
			export PATH="$(find "$lib" -type d -printf "%p:")$PATH"
			source_once "$lib"/*
		elif [[ -x "$lib" ]]; then
			_trace "Importing executable lib '$lib'"
			# shellcheck disable=SC2139
			alias "$(basename "$lib")=$lib"
		else
			if [[ "$SHELDRITCH_CLEAN" = true ]]; then
				_trace "Force source lib '$lib'"
				source "$lib"
			else
				source_once "$lib"
			fi
		fi
	done

	if [[ "$FORCE" ]]; then
		SHELDRITCH_CLEAN=""
	fi

}

main "$@"
