#
# Base script utilities
#

# base.sh is frequently re-run, so enforcing performance is important
# shellcheck enable=require-double-brackets

# Init

# Ensure the aliases created by this script are available
if [[ "$BASH_VERSION" ]]; then
	shopt -s expand_aliases
elif [[ "$ZSH_VERSION" ]]; then
	setopt aliases
fi

if [[ "$TOOLS_SOURCES" =~ "base.sh" && -z "$TOOLS_RESET" && "$1" != "--force" ]]
then
	return
else
	TOOLS_SOURCES+="$(echo -e "\nbase.sh")"
fi

alias zsh_run='[[ -z "$ZSH_VERSION" ]] || '
alias bash_run='[[ -z "$BASH_VERSION" ]] || '
alias _tools_trace='[[ -v TOOLS_TRACE && "$TOOLS_TRACE" ]] && echo >&2 '

# shellcheck disable=SC2142
alias script_is_sourced='{ [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; }'

# shellcheck disable=SC2139
alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${0}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

check_is_sourced_func() {
	if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; then
		echo "You aren't sourcing ${0}. Make sure you are to have its libs available to you."
		exit 1
	fi
}

if ! command -v complete >/dev/null 2>/dev/null; then
	complete() { return; }
fi

# Sourcing & Tools Library Access

add_to_path() {
	for Path in "$@"; do
		if ! [[ "$PATH" =~ "$Path" ]]; then
			export PATH="$PATH:$Path"
		fi
	done
}

source_once() {
	local Path="$1"
	if ! [[ "$Path" =~ ^/ ]]; then
		Path="$(realpath -s "$1")"
	fi

	if [[ "$TOOLS_SOURCES" =~ "$Path" ]]; then
		_tools_trace "source_once: skipping export '$Path': Already sourced"
		return
	fi

	if [[ -x "$Path" ]]; then
		echo >&2 "Error: $Path is an executable, presumably not a sourced file."
		return 1
	fi

	TOOLS_SOURCES+="$(echo -e "\n$Path")" # before source to prevent dependency loops
	_tools_trace "source_once: sourcing '$Path'"
	_tools_trace ""
	_tools_trace "sources currently:"
	_tools_trace "$TOOLS_SOURCES"
	source "$1"
}

use_tool() {
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

	TOOLS_RESET="$FORCE"

	if [[ "$HELP" = true ]]; then
		echo >&2 "use_tool -- imports the given tool (relative to the tools repo)"
		echo >&2 "Usage: use_tool [--force] <tool>"
	fi

	for tool in "$@"; do
		tool="$TOOLS/$tool"

		if [[ "$TOOLS_SOURCES" =~ "$tool" ]]; then
			continue
		fi

		if [[ -d "$tool" ]]; then
			if in_tools_root_context; then
				echo >&2 "Error: refusing to mutate PATH for a sourced script"
				return 1
			fi
			_tools_trace "Importing tools in directory '$tool'"
			export PATH="$(find "$tool" -type d -printf "%p:")$PATH"
			source_once "$tool"/*
		elif [[ -x "$tool" ]]; then
			if in_tools_root_context; then
				echo >&2 "Error: refusing to mutate aliases for a sourced script"
				return 1
			fi
			_tools_trace "Importing executable tool '$tool'"
			# shellcheck disable=SC2139
			alias "$(basename "$tool")=$tool"
		else 
			if [[ "$TOOLS_RESET" = true ]]; then
				_tools_trace "Force source tool '$tool'"
				source "$tool"
			else 
				source_once "$tool"
			fi
		fi
	done

	if [[ "$FORCE" ]]; then
		TOOLS_RESET=""
	fi

}

# temporarily unset aliases, so they don't interfere with a helper script
disable_previous_aliases() {
	PRE_UTIL_ALIASES="$(alias)"
	for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
		unalias "$alias"
	done
}

# Must be run at the end of a script that disabled previous aliases
enable_previous_aliases() {
	eval "$PRE_UTIL_ALIASES"
}


# Directories/Environment

zsh_run zmodload zsh/parameter

self_file() {
	local level
	level="${1:-0}"
	bash_run caller "$level" | awk '{print $3; exit}'
	# shellcheck disable=all
	zsh_run echo ${funcfiletrace[$(($level + 1 ))]} | cut -d : -f 1
}

self_dir() {
	dirname "$(self_file 1)"
}

if [[ -z "$TOOLS" ]]; then
	export TOOLS="$(realpath -s $(self_dir)/../../)"
fi

# /tmp/tools for tool-related temporary files
! [[ -d /tmp/tools ]] && mkdir -p /tmp/tools

# Directories storing repos
if [[ -z "$REPOS" ]]; then
	# sensibly set REPO_DIR based on the first existing directory
	# Feel free to add your own repo here
	for dir in "$HOME/repos" /g/; do
		if [[ -d "$dir" ]]; then
			[[ -z "$REPOS" ]] && REPOS="$dir" || REPOS="$REPOS:$dir"
		fi
	done
fi

# Store the current process, to compare when running certain functions
export TOOLS_BASE_PID="$BASHPID"
# The root shell process for the given session
if [[ -z "$TOOLS_ROOT_PID" ]] || [[ $- == *i* ]]; then
	export TOOLS_ROOT_PID="$BASHPID"
fi

in_tools_base_context() {
	debug "tools base process: $TOOLS_BASE_PID, current process: $BASHPID"
	test "$BASHPID" -eq "$TOOLS_BASE_PID"
}

in_tools_root_context() {
	debug "tools root process: $TOOLS_BASE_PID, current process: $BASHPID"
	test "$BASHPID" -eq "$TOOLS_ROOT_PID"
}


# Base Helpers

alias safe_quit="return 2> /dev/null || exit"

quiet() { "$@" >/dev/null 2>/dev/null; }
stderr() { "$@" >&2; }

alias @func_use_parent='
	local parent
	while [[ -n "$1" ]]; do
		case "$1" in
			-p | --parent ) parent="$2"
				shift
				shift
				;;
			*) break
				;;
		esac
	done

	parent="$((${parent:-0} + 1))"

	local func
	if funcname -p $parent -q 2>/dev/null; then
		func="$(funcname -p $parent)"
	fi
'

_genfunc_log() {
	eval "$1"'() {
		@func_use_parent
		echo '"$2"'": ${func:+$func: }$*" >&2

		local trace="${STACKTRACE:-$DEBUG}"
		if [[ "${trace,,}" =~ ^true|1$ || $- =~ x ]]; then
			local i=0; while caller $i; do ((i++)); done
		fi
	}
	'
}
_genfunc_log log    Info
_genfunc_log error  Error
_genfunc_log warn   Warning
_genfunc_log _debug Debug

# Echo stderr debug line if turned on
debug() {
	if [[ "${DEBUG,,}" =~ ^true|1$ ]]; then
		STACKTRACE=false _debug -p 1 "$@"
	fi
}

alias var_is_local='local >/dev/null 2>&1 -p'
alias var_is_declared='declare >/dev/null 2>&1 -p'
