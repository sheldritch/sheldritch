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

if [[ -n "$SHELDRITCH_SUBSHELL" && -z "$SHELDRITCH_CLEAN" && "$1" != "--force" ]]
then
	return
fi

alias zsh_run='[[ -z "$ZSH_VERSION" ]] || '
alias bash_run='[[ -z "$BASH_VERSION" ]] || '
alias _trace='[[ -v TRACE && "$TRACE" ]] && echo >&2 '

# Directories/Environment

zsh_run zmodload zsh/parameter

self_file() {
	local level="${1:-0}"
	# TODO: remove pipes here
	# FIXME: fails if called outside of function
	bash_run caller "$level" | awk '{print $3; exit}'
	# shellcheck disable=all
	zsh_run echo ${funcfiletrace[$(($level + 1 ))]} | cut -d : -f 1
}

self_dir() {
	dirname "$(self_file 1)"
}

if [[ -z "$SHELDRITCH" ]]; then
	export SHELDRITCH="$(realpath -s $(self_dir))"
fi
SHELDRITCH_SUBSHELL="$BASH_SUBSHELL$ZSH_SUBSHELL"

# /tmp/tools for tool-related temporary files
! [[ -d /tmp/tools ]] && mkdir -p /tmp/tools
tmp_dir() {
	xdg_tmp
}

# Base Helpers

if ! command -v complete >/dev/null 2>/dev/null; then
	complete() { return; }
fi

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

source "$SHELDRITCH/util/lib.sh"
