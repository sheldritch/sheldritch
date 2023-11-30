#
# Base script utilities
#

# Init

# Ensure the aliases created by this script are available
if [ "$BASH_VERSION" ]; then
	shopt -s expand_aliases
elif [ "$ZSH_VERSION" ]; then
	setopt aliases
fi


alias script_is_sourced='[ "${BASH_SOURCE[0]}" != "${0}" -o "$ZSH_EVAL_CONTEXT" = toplevel ]'

alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${0}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

if ! command -v complete >/dev/null 2>/dev/null; then
	complete() { return; }
fi

# Sourcing & Tools Library Access

add_to_path() {
	for Path in "$@"; do
		if ! echo "$PATH" | grep -qF "$Path"; then
			export PATH="$PATH:$Path"
		fi
	done
}

source_once() {
	local Path
	Path="$(realpath "$1")"

	if [ -x "$Path" ]; then
		echo >&2 "Error: $Path is an executable, presumably not a sourced file."
		return 1
	fi

	if ! [[ "$TOOLS_SOURCES" =~ "$Path" ]]; then
		TOOLS_SOURCES+="$(echo -e "\n$Path")" # before source to prevent dependency loops
		source "$1"
	fi
}

use_tool() {
	local HELP FORCE
	while [ $# -ne 0 ]; do
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

	if [ "$HELP" = true ]; then
		echo >&2 "use_tool -- imports the given tool (relative to the tools repo)"
		echo >&2 "Usage: use_tool [--force] <tool>"
	fi

	for tool in $TOOLS/$@; do
		if [ -d "$tool" ]; then
			if in_tools_root_context; then
				echo >&2 "Error: refusing to mutate PATH for a sourced script"
				return 1
			fi
			export PATH="$(find "$tool" -type d -printf "%p:")$PATH"
		elif [ -x "$tool" ]; then
			if in_tools_root_context; then
				echo >&2 "Error: refusing to mutate aliases for a sourced script"
				return 1
			fi
			alias "$(basename "$tool")=$tool"
		else 
			if [ "$FORCE" = true ]; then
				source "$tool"
			else 
				source_once "$tool"
			fi
		fi
	done
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


# The directory of the file currently being executed (or viewed, if looking at code)
alias 'self_dir=( cd "$(dirname $(realpath "${BASH_VERSION:+${BASH_SOURCE[0]}}${ZSH_VERSION:+${0:a}}"))" >/dev/null 2>&1 && pwd )'

if [ -z "$TOOLS" ]; then
	export TOOLS="$(realpath $(self_dir)/../../)"
fi

# /tmp/tools for tool-related temporary files
mkdir -p /tmp/tools

# Directories storing repos
if [ -z "$REPOS" ]; then
	# sensibly set REPO_DIR based on the first existing directory
	# Feel free to add your own repo here
	for dir in "$HOME/repos" /g/; do
		if [ -d "$dir" ]; then
			[ -z "$REPOS" ] && REPOS="$dir" || REPOS="$REPOS:$dir"
		fi
	done
fi

# Store the current process, to compare when running certain functions
export TOOLS_BASE_PID="$BASHPID"
# The root shell process for the given session
if [ -z "$TOOLS_ROOT_PID" ] || [[ $- == *i* ]]; then
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

# Echo stderr debug line if turned on
debug() {
	if [ "$DEBUG" = true ]; then
		echo >&2 -e "DEBUG:" "$@"
	fi
}

debug_enable() {
	set -u
	export DEBUG=true
}
alias enable_debug=debug_enable
