#
# Base script utilities
#

if [ -z "$BASH_VERSION" ]; then
	echo >&2 "Error: utils/base.sh: base currently requires Bash to execute."
	echo >&2 "Sorry for the inconvenience."

    if [ "$1" != '--force' ]; then
		return 1
	fi
fi

# Ensure the aliases created by this script are available
shopt -s expand_aliases


alias script_is_sourced='[[ "${BASH_SOURCE[0]}" != "${0}" ]]'

alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${BASH_SOURCE[0]}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

export TOOLS_SOURCES
source_once() {
	path="$(realpath "$1")"
	if ! grep -q "$path" <<<"$TOOLS_SOURCES"; then
		TOOLS_SOURCES+="$(echo -e "\n$path")"
		source "$1"
	fi
}

use_tool() {
	source_once "$TOOLS"/"$1"
}

# temporarily unset aliases, so they don't interfere with this script
disable_previous_aliases() {
	PRE_UTIL_ALIASES="$(alias)"
	for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
		unalias "$alias"
	done
}

enable_previous_aliases() {
	eval "$PRE_UTIL_ALIASES"
}

# The directory of the file currently being executed (or viewed, if looking at code)
alias 'self_dir=( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )'
SELF_DIR="$(self_dir)"

if [ -z "$TOOLS" ]; then
	export TOOLS="$(realpath $SELF_DIR/../../)"
fi

# Store the current process, to compare when running certain functions
UTIL_PID="$BASHPID"

alias safe_quit="return 2> /dev/null || exit"

# Echo stderr debug line if turned on
debug() {
	if [ "$DEBUG" = true ]; then
		echo >&2 -e "DEBUG:" "$@"
	fi
}

enable_debug() {
	set -u
	export DEBUG=true
}
