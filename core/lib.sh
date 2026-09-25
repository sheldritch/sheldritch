#!/bin/bash
#
# Functions for importing and handling shell scripts like libraries
#
# This file is sourced very early by sheldritch.base.sh, so keep dependencies
# minimal and avoid summoning other Tomes from here.

# DESIGN:
#
# There are a few library management tools out there. Most have a custom dir containing libs, and
# their own way for accessing them. For instance, `sheldon` uses '$XDG_DATA_HOME/sheldon', and by
# default matches `<plugin-dir>.<shell>`, `<plugin-dir>.sh` and `*.sh` in order.
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

if [[ -n ${BASH_VERSION-} ]]; then
	shopt -s expand_aliases
elif [[ -n ${ZSH_VERSION-} ]]; then
	setopt aliases
fi

if [[ -z "${SHELDRITCH_SUBSHELL:-}" ]]; then
	source "$SHELDRITCH/sheldritch.base.sh" "" # block argument passthrough
fi

# SHELDRITCH_SOURCES tracks which files are sourced, including order.
{ typeset -g -a SHELDRITCH_SOURCES || typeset -a SHELDRITCH_SOURCES; } 2>/dev/null || :

# `${Arr[*]+ }` is a cheap "non-empty" proxy despite shell differences
if [[ -z "${SHELDRITCH_SOURCES[*]+ }" ]]; then
	SHELDRITCH_SOURCES=()
fi

# Given an absolute path, return true iff the path has previously been sourced via `source_once`.
function source_is_cached { :; }

# If supported, create SHELDRITCH_SOURCES_LOOKUP associative array for performance
if [[ -n "${SHELDRITCH_HAS_ASSOC_ARRAYS:-}" ]]; then
	# Fallback: O(n) member check on array
	function source_is_cached {
		typeset Cached=''
		for Cached in "${SHELDRITCH_SOURCES[@]}"; do
			[[ "$Cached" = "$1" ]] && return 0
		done
		return 1
	}
	function _source_cache_mark {
		SHELDRITCH_SOURCES+=("$1")
	}
else
	typeset -g -A SHELDRITCH_SOURCES_LOOKUP 2>/dev/null \
		|| typeset -A SHELDRITCH_SOURCES_LOOKUP

	if [[ -n "${ZSH_VERSION:-}" ]]; then
		# zsh treats quotes inside `Assoc["key"]` as literal key chars
		function source_is_cached {
			[[ -n "${SHELDRITCH_SOURCES_LOOKUP[$1]+ }" ]]
		}
		function _source_cache_mark {
			SHELDRITCH_SOURCES+=("$1")
			SHELDRITCH_SOURCES_LOOKUP[$1]=1
		}
	else
		# bash/ksh treat `Assoc["key"]` as quoting
		function source_is_cached {
			[[ -n "${SHELDRITCH_SOURCES_LOOKUP["$1"]+ }" ]]
		}
		function _source_cache_mark {
			SHELDRITCH_SOURCES+=("$1")
			SHELDRITCH_SOURCES_LOOKUP["$1"]=1
		}
	fi

	# Invariant: when lookup is enabled, the ordered list and lookup must be kept in sync.
	# If they ever diverge (bug or user meddling), alert and reset the cache
	if (( ${#SHELDRITCH_SOURCES[@]} != ${#SHELDRITCH_SOURCES_LOOKUP[@]} )); then
		echo >&2 "Warning: sheldritch: source cache is inconsistent; resetting SHELDRITCH_SOURCES and SHELDRITCH_SOURCES_LOOKUP."
		SHELDRITCH_SOURCES=()
		SHELDRITCH_SOURCES_LOOKUP=()
	fi
fi
unset __SHELDRITCH_HAS_LOOKUP 2>/dev/null || :

# If a file is re-sourced, clear args.sh's generated _ARGS_* functions so they get rebuilt.
# (Keeps @func_info metadata in sync for live editing / re-sourcing.)
alias source_cache_update='
	self_file >/dev/null
	if [[ -z "${_ARGS_NO_CACHE:-}" && -n "${_ARGS_CACHE:-}" ]]; then
		[[ "$REPLY" = /* ]] || REPLY="$PWD/$REPLY"
		if source_is_cached "$REPLY"; then
			funcs_with_prefix _ARGS
			unset _ARGS_CACHE $REPLY
		fi
	fi
'

# shellcheck disable=SC2142
alias script_is_sourced='{
	if [[ -n "${BASH_VERSION-}" ]]; then
		[[ "${BASH_SOURCE[0]}" != "${0}" ]]

	elif [[ -n ${ZSH_VERSION-} ]]; then
		# In zsh, executed scripts have `ZSH_EVAL_CONTEXT=toplevel`, while
		# sourced files include a `:file` suffix (e.g. `cmdarg:file` or
		# `toplevel:file`).
		[[ "${ZSH_EVAL_CONTEXT-}" = *:file ]] || [[ "${ZSH_EVAL_CONTEXT-}" = file ]]

	elif [[ -n ${KSH_VERSION-} ]]; then
		# In ksh, when a file is sourced, $0 remains the shell (e.g. "ksh"),
		# while .sh.file is the sourced path. When executed, $0 matches .sh.file.
		[[ "${.sh.file-}" != "${0-}" ]]

	else
		false
	fi
}'

# shellcheck disable=SC2139,SC2154
alias check_is_sourced='
if ! script_is_sourced; then
	# TODO: this might need to be computed at alias compile time???
	echo "You are not sourcing ${0}. Make sure you are to have its libs available to you."
	exit 1
fi
source_cache_update
'

if [[ -z ${KSH_VERSION-} ]]; then
	# ksh cannot reliably run aliases immediately after defining them.
	check_is_sourced
fi

if [[ -z "$SHELDRITCH" ]]; then
	echo >&2 "Error: sheldritch lib.sh: SHELDRITCH must be set to its directory"
	return 1
fi

function __last {
	# Late init: make sure base + minimal system helpers are available and cached.
	_source_cache_mark "$SHELDRITCH/sheldritch.base.sh"
	# allow resource so args.sh et al can be fetched in the meantime
	source "$SHELDRITCH/system/files.sh"
	source "$SHELDRITCH/system/xdg.sh"
}

# Re-evaluate "$@" to expand globs, without whitespace splitting.
alias glob_args='
    typeset _IFS_OLD
	[[ -z "${IFS+x}" ]] || _IFS_OLD=${IFS}
	IFS=''
    set -- $@
    IFS=${_IFS_OLD}
	[[ -n "${_IFS_OLD+x}" ]] || unset IFS
    unset _IFS_OLD
'

# TODO: consider renaming to bin_path_search or PATH_search
function path_search {
	typeset Dir Path Delim='\n' First
	case "$1" in
		-0 | --zero ) Delim='\0'
			shift 1
			;;
		-d | --delimiter ) Delim="$2"
			if [[ -z "$Delim" ]]; then
				echo >&2 "Error: path_search: no delimiter passed to -d"
				return 1
			fi
			shift 2 || return 1
			;;
		-1 | --first ) First=1
			shift
			;;

		--help | -h )
			@help '
			path_search: for each path in PATHS, search the
			directories in PATH_STRING and print any matches.
			Usage: path_search [option] PATH_STRING PATHS...
			Legend:
				PATH_STRING: a colon-separated list of paths.
			Options:
				-0 --zero
					output zero-delimited matches
				-d --delimiter=DELIMITER
					specify the delimiter used in output
				-1 --first
					Only print the first match (with no
					delimiter)
			' && return
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

function find_bin {
	@help '
	Search all directories in $PATH for the given file.
	' && return
	for x in ${PATH//://*${1}* }*${1}*; do
		[ -f "$x" ] && echo $x
	done
}

function path_add {
	@help "
	Idempotently add each given path to the start of PATH
	Usage: path_add PATHS
	" && return
	for Path in "$@"; do
		if ! [[ "$PATH" = *"$Path"* ]]; then
			export PATH="$Path:$PATH"
		fi
	done
}

function path_add_end {
	@help "
	Idempotently add each given path to the end of PATH
	Usage: path_add_end PATHS
	" && return
	for Path in "$@"; do
		if ! [[ "$PATH" = *"$Path"* ]]; then
			export PATH="$Path:$PATH"
		fi
	done
}


# Re-source all cached paths in their original source order.
function sources_sync {
	typeset Key Fail=0
	for Key in "${SHELDRITCH_SOURCES[@]}"; do
		source "$Key" || Fail=1
	done
	return $Fail
}

# Source the given file if it has not already sourced via source_once
function source_once {
	typeset Path='' Exit=''

	for Path in "$@"; do
		if ! [[ "$Path" = /* ]]; then
			# Canonicalise relative paths so the cache doesn't get duplicates.
			Path="$(realpath -s "$Path")"
		fi

		# TODO: test performance of array and hash in large tools context
		# NOTE: source_once returns early if a path is already cached.
		# Call source_once separately per path if you need "source all".
		if source_is_cached "$Path"; then
			_trace "source_once: skipping export '$Path': Already sourced"
			return 0
		fi

		if [[ -x "$Path" ]]; then
			echo >&2 "Error: $Path is an executable, presumably not a sourced file."
			return 1
		fi

		# Mark before sourcing to prevent dependency loops.
		_source_cache_mark "$Path"
		_trace "source_once: sourcing '$Path'"
		_trace ""
		_trace "sources currently:"
		_trace "$(typeset -p SHELDRITCH_SOURCES)"

		if ! source "$Path"; then
			typeset STACKTRACE=1
			error "failed to source file '$Path'
			If you aren't seeing an error above, it's likely the last run sourced command failed silently."
			Exit=1
		fi
	done
	return $Exit
}

#
# TODO: If we use .local/lib, there might be stuff in .local/share we also want to use
# We need to be careful about assuming that .local/lib is the best place for stuff, if
# .local/share is already being used but ./lib is not.
function tome_find {
	@help '
	Print the absolute path for a given tome.
	Usage: tome_find TOME
	' && return

	if [[ "$1" = sheldritch/* && -d "$SHELDRITCH" ]]; then
		# Fast-path: resolve sheldritch/* directly from $SHELDRITCH.
		REPLY="$SHELDRITCH/${1#sheldritch/}"
		printf '%s\n' "$REPLY"
		return 0
	fi

	lib_paths >/dev/null
	typeset IFS=:
	for Dir in $REPLY; do
		if [[ -e "$Dir/$1" ]]; then
			REPLY="$Dir/$1"
			printf '%s\n' "$REPLY"
			return 0
		fi
	done
	REPLY=''
	return 1
}

function lib_paths {

	@help '
	Print a colon-separated list of paths considered by SHELDRITCH for use.
	Usage: lib_paths
	' && return

	if [[ -n "$LIBS" ]]; then
		REPLY="$LIBS"
	else
		REPLY="$HOME/.local/lib:$(xdg data-dirs)"
		REPLY="${REPLY//:/\/shell:}"
		[[ -n "$SHELDON_DATA_DIR" ]] && REPLY="$SHELDON_DATA_DIR:$REPLY"
	fi
	REPLY="${REPLY//::/:}"
	REPLY="${REPLY#:}"
	REPLY="${REPLY%:}"
	printf '%s\n' "$REPLY"
}

function tome_use {
	typeset Help='' Force='' Parent=0
	while [[ $# -ne 0 ]]; do
		case "$1" in
			-p | --parent ) Parent="$2"
				shift
				shift
				;;
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

	zsh_run setopt GLOB globsubst extendedglob
	typeset SHELDRITCH_CLEAN="$Force"

	if [[ "$Help" = true ]]; then
		echo >&2 "tome_use -- imports a tome by absolute paths (or relative to working dir)"
		echo >&2 "Usage: tome_use [--force] PATH_TO_TOME"
		return 0
	fi

	typeset Arg Tome Globs='' Prefix='' Extglob=''
	for Arg in "$@"; do

		# Fetch any wildcards (globs) if they exist
		if [[ "$Arg" = *\** ]]; then
			Globs="*${Arg#*\*}"

			if [[ "$Globs" = *\*\* ]]; then
				# Handle '**' recursive wildcards
				# Exclude files starting with '_' from the wildcard.

				# extglob wildcards are very slow, but this is the only option for bash available
				bash_run ! shopt -pq extglob && Extglob="shopt -u extglob" && shopt -s extglob
				# *(*/) doesn't work in direct patterns, but it does work in GLOBIGNORE
				bash_run local GLOBIGNORE="*(*/)@(_*|.*)*(/*)"

				# ([^_]*/)# is a recursive glob, allowing any number of repeating occurrences of the
				# pattern inside the brackets
				zsh_run Globs="${Globs//\*\*/([^_]*/)#}" &&
					Globs="[^_]${Globs//\/\*//[^_]*}"

				Globs="${Globs//\*\//[^._]*/}"
				Globs="$Globs/[^._]*"
			else
				Globs="[^._]${Globs//\/\*//[^._]*}"
			fi
		fi


		# Ensure globstar is enabled so "**" expands (restore at end of tome_use).
		typeset Globstar=''
		bash_run shopt -pq globstar || { Globstar="shopt -u globstar" && shopt -s globstar; }
		ksh_run [[ -o globstar ]] || { Globstar="set +o globstar" && set -o globstar; }

		Prefix="${Arg%%\**}"
		for Tome in "$Prefix"$Globs; do
			[[ $Extglob ]] && unset GLOBIGNORE && Extglob=""

			Prefix="${Arg%%\**}"
			if [[ "${Tome#$Prefix}" = */_* ]]; then
				_trace "Ignoring tome '$Tome' due to underscore"
				continue
			fi

			# NOTE: if foo/* was specified, don't import contents of subfolders
			if [[ -d "$Tome" && -z "$Globs" ]]; then
				_trace "Importing module '$Tome'"
				# If a directory is given, import its "default" file (dir/dir.{sh,...}).
				if [[ "$Tome" != *\\* ]]; then
					Tome="${Tome%/}"
					Tome="$Tome/${Tome##*/}"
				else
					Tome="$Tome/$(basename "$Tome")"
				fi
			fi

			if ! [[ -e "$Tome" ]]; then
				# Select the best matching implementation for the current shell.
				file_first "$Tome".{${THIS_SHELL},sh,ksh,bash,fish,zsh,*} >/dev/null
				Tome="${REPLY:-$Tome}"
			fi

			# Without associative arrays, source_is_cached is O(n); avoid checking twice.
			if [[ "$Force" != true && -n "${SHELDRITCH_HAS_ASSOC_ARRAYS:-}" ]] && source_is_cached "$Tome"; then
				continue
			fi

			if [[ -x "$Tome" ]]; then
				_trace "Importing executable tome '$Tome'"
				# shellcheck disable=SC2139
				alias "$(basename "$Tome")=$Tome"
			elif [[ "$Tome" =~ \.(bash|fish|ksh|sh|zsh)$ ]]; then

				if [[ "$THIS_SHELL" = ksh && "$Tome" =~ \.(bash|fish|zsh)$ ]]; then
					if [[ "$Tome" != "$SHELDRITCH"* ]]; then
						warn "not sourcing '$Tome' due to ksh syntax checking."
					fi
					continue
				fi

				if [[ "$SHELDRITCH_CLEAN" = true ]]; then
					# Force means "source even if already cached".
					_trace "Force source tome '$Tome'"
					source "$Tome"
				else
					source_once "$Tome"
				fi
				[[ $? = 0 ]] || error -p $((Parent + 1)) "failed sourcing tome '$Tome'"

			elif [[ -z "$Globs" ]]; then
				error "Tome '$Tome' could not be interpreted."
			fi

		done

	done
	# Restore shell globstar to its original state.
	$Globstar
}

# imports the given tome/file (relative to the library dir)
function summon {
	typeset Help='' Force=''
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

	typeset SHELDRITCH_CLEAN="$Force"
	zsh_run setopt GLOB globsubst

	if [[ "$Help" = true ]]; then
		echo >&2 "summon -- imports the given tome/file (relative to the library dir)"
		echo >&2 '    see `docs/libs.md` for more information.'
		echo >&2 "Usage: summon [--force] LIB/PATH_TO_TOME    COMMAND..."
		echo >&2 "       summon [--force] LIB/PATH_TO_FILE.sh COMMAND..."
		echo >&2 "       summon [--force] LIB/[PATH/]*        COMMAND..."
		echo >&2 "       summon [--force] LIB/[PATH/]**       COMMAND..."
		return 0
	fi


	typeset Globs=''
	for Arg in "$@"; do
		# find the absolute path to the library
		if ! Tome="$(tome_find "${Arg%%\**}")"; then
			error -p 1 "Tome '$Tome' could not be found."
			continue
		fi

		# Re-attach globs to absolute path.

		Globs=''
		if [[ "$Arg" = *\** ]]; then
			Globs="*${Arg#*\*}"
		fi
		# Build a new argument list without needing a subshell.
		set -- "$@" "$Tome$Globs"
		shift
	done

	# perform import
	tome_use "$@"
}

function conjure {
	typeset Help='' Force=''
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

	typeset SHELDRITCH_CLEAN="$Force"
	zsh_run setopt GLOB globsubst

	if [[ "$Help" = true ]]; then
		echo >&2 "conjure -- invoke a function a single time, without altering the regular environment (relative to the library dir)"
		echo >&2 "Usage: conjure [--force] LIB COMMAND..."
		echo >&2 "       conjure [--force] LIB/FILE.sh COMMAND..."
		echo >&2 "       conjure [--force] LIB/* COMMAND..."
		echo >&2 "       conjure [--force] LIB/** COMMAND..."
		return 0
	fi

	(
		# Subshell keeps any side-effects (variables, options, cwd) contained.
		summon "$1"
		"${@:2:$#}"
	)

}

__last "$@"
