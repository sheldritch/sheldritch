#
# Base script utilities
#

# base.sh is frequently re-run, so enforcing performance is important
# shellcheck enable=require-double-brackets

# Ensure the aliases created by this script are available
if [[ "$BASH_VERSION" ]]; then
	shopt -s expand_aliases
elif [[ "$ZSH_VERSION" ]]; then
	setopt aliases
fi

if [[ "$TOOLS_SOURCES" = *base.sh* && -z "$TOOLS_RESET" && "$1" != "--force" ]]
then
	return
else
	TOOLS_SOURCES+="$(echo -e "\nbase.sh")"
fi

alias zsh_run='[[ -z "$ZSH_VERSION" ]] || '
alias bash_run='[[ -z "$BASH_VERSION" ]] || '
alias _tools_trace='[[ -v TOOLS_TRACE && "$TOOLS_TRACE" ]] && echo >&2 '

if ! command -v complete >/dev/null 2>/dev/null; then
	complete() { return; }
fi

add_to_path() {
	for Path in "$@"; do
		if ! [[ "$PATH" = *"$Path"* ]]; then
			export PATH="$PATH:$Path"
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

if [[ -z "$SHELDRITCH" ]]; then
	export SHELDRITCH="$(realpath -s $(self_dir)/../../)"
fi

# /tmp/tools for tool-related temporary files
! [[ -d /tmp/tools ]] && mkdir -p /tmp/tools

# Directories storing repos
if [[ -z "$REPOS" ]]; then
	# sensibly set REPO_DIR based on the first existing directory
	# Feel free to add your own repo here
	for dir in "$HOME"/{repos,git,code,projects}; do
		if [[ -d "$dir" ]]; then
			[[ -z "$REPOS" ]] && REPOS="$dir" || REPOS="$REPOS:$dir"
		fi
	done
fi

SHELDRITCH_SUBSHELL=$BASH_SUBSHELL

# Base Helpers

alias safe_quit="return 2> /dev/null || exit"

quiet() { "$@" >/dev/null 2>/dev/null; }
stderr() { "$@" >&2; }

# shellcheck disable=SC2154
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
		local trace="${STACKTRACE:-$DEBUG}" set
		if [[ $- = *x* ]]; then
			set +x
			set=x
		fi
		@func_use_parent
		echo '"$2"'": ${func:+$func: }$*" >&2

		if [[ "${trace,,}" = true || "$trace" = 1 || -n "$set" ]]; then
			local i=0; while caller $i >&2; do ((i++)); done
			set -$set
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
	case "${DEBUG,,}" in
		true | 1 ) STACKTRACE=false _debug -p 1 "$@"
	esac
}

alias var_is_local='local >/dev/null 2>&1 -p'
alias var_is_declared='declare >/dev/null 2>&1 -p'
