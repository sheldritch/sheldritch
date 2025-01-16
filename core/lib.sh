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

__main() {
	source_once "$SHELDRITCH/sheldritch.base.sh"
	source_once "$SHELDRITCH/system/xdg.sh"
}

alias glob_args='
    declare _IFS_OLD
	[[ -z "${IFS+x}" ]] || _IFS_OLD=${IFS}
	IFS=''
    set -- $@
    IFS=${_IFS_OLD}
	[[ -n "${_IFS_OLD+x}" ]] || unset IFS
    unset _IFS_OLD
'

check_is_sourced_func() {
	if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; then
		echo "You aren't sourcing ${0}. Make sure you are to have its libs available to you."
		exit 1
	fi
}

path_search() {
	local Dir Path Delim='\n' First
	case "$1" in
		-0 | --zero ) Delim='\0'
			shift 1 || return 1
			;;
		-d | --delimiter ) Delim="$2"
			shift 2 || return 1
			;;
		-1 | --first ) First=1
			shift 2 || return 1
	esac

	Path="$1" 
	shift
	while read -rd : Dir; do
		for Path in "$@"; do
			if [[ -e "$Dir/$Path" ]]; then
				printf "%s$Delim" "$Dir/$Path"
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

source_once() {
	local Path='' Exit=''

	for Path in "$@"; do
		if ! [[ "$Path" = /* ]]; then
			Path="$(realpath -s "$Path")"
		fi

		# TODO: test performance of array and hash in large tools context
		if [[ "${SHELDRITCH_SOURCES:-}" = *"$Path"* ]]; then
			_trace "source_once: skipping export '$Path': Already sourced"
			return 0
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

		source "$1" || Exit=1
	done
	return $Exit
}


# TODO: If we use .local/lib, there might be stuff in .local/share we also want to use
# We need to be careful about assuming that .local/lib is the best place for stuff, if
# .local/share is already being used but ./lib is not.
find_lib() {

	if [[ "$1" = sheldritch/* && -d "$SHELDRITCH" ]]; then
		printf "%s" "$SHELDRITCH/${1#sheldritch/}"
		return 0
	fi

	local Libs
	if [[ -n "$LIBS" ]]; then
		Libs="$LIBS"
	else
		Libs="$HOME/.local/lib:$(xdg data-dirs)"
		Libs="${SHELDON_DATA_DIR}:${LIBS//:/\/shell:}"
	fi

	while read -rd : Dir; do
		if [[ -e "$Dir/$1" ]]; then
			printf "%s" "$Dir/$1"
			return 0
		fi
	done <<<"$Libs"
	return 1
}


lib_use() {
	local Help='' Force=''
	while [[ $# -ne 0 ]]; do
		case "$1" in
			-f | --force ) Force=true
				shift
				;;
			-h | --help ) Help=true
				shift
				break
				;;
			* ) break
				;;
		esac
	done

	zsh_run setopt GLOB globsubst
	local SHELDRITCH_CLEAN="$Force"

	if [[ "$Help" = true ]]; then
		echo >&2 "lib_use -- imports the library/file by absolute paths (or relative to working dir)"
		echo >&2 "Usage: lib_use [--force] <lib>/<file>.sh"
		echo >&2 "       lib_use [--force] <lib>"
		echo >&2 "       lib_use [--force] <lib>/*"
		return 0
	fi

	local Arg Lib
	for Arg in "$@"; do

		local Globs="${Arg##*[^*]}"
		Globs="${Globs:+[^_]$Globs}"

		local Shopt=''
		if Shopt="$(shopt -p globstar 2>/dev/null)"; then
			shopt -s globstar
		fi

		for Lib in "$Arg"$Globs; do

			if [[ "$SHELDRITCH_SOURCES" = *"$Lib"* ]]; then
				continue
			fi

			if [[ -d "$Lib" && -z "$Globs" ]]; then
				_trace "Importing module '$Lib'"
				#export PATH="$(find "$lib" -type d -printf "%p:")$PATH"
				source_once "$Lib/$(basename "$Lib").sh"
			elif [[ -x "$Lib" ]]; then
				_trace "Importing executable lib '$Lib'"
				# shellcheck disable=SC2139
				alias "$(basename "$Lib")=$Lib"
			elif [[ "$Lib" =~ \.(bash|fish|ksh|sh|zsh)$ ]]; then
				if [[ "$SHELDRITCH_CLEAN" = true ]]; then
					_trace "Force source lib '$Lib'"
					source "$Lib"
				else
					source_once "$Lib"
				fi
				[[ $? = 0 ]] || error -p 1 "failed sourcing lib '$Lib'"

			elif [[ -z "$Globs" ]]; then
				error "Library '$Lib' could not be interpreted."
			fi

		done

	done
	$Shopt
}

# imports the given library/file (relative to the library dir)
summon() {
	local Help='' Force=''
	while [[ $# -ne 0 ]]; do
		case "$1" in
			-f | --force ) Force=true
				shift
				;;
			-h | --help ) Help=true
				shift
				break
				;;
			* ) break
				;;
		esac
	done

	local SHELDRITCH_CLEAN="$Force"
	zsh_run setopt GLOB globsubst

	if [[ "$Help" = true ]]; then
		echo >&2 "summon -- imports the library/file (relative to the library dir)"
		echo >&2 "Usage: summon [--force] <lib>/<file>.sh"
		echo >&2 "       summon [--force] <lib>"
		echo >&2 "       summon [--force] <lib>/*"
		return 0
	fi

	for Arg in "$@"; do
		if ! Lib="$(find_lib "${Arg%%\*}")"; then
			error -p 1 "Library '$Lib' could not be found."
			continue
		fi

		local Globs="${Arg##*[^*]}"

		set -- "$@" "$Lib$Globs"
		shift
	done

	lib_use "$@"
}

__main "$@"
