#!/bin/bash
#
# Base script utilities
#

# base.sh is frequently re-run, so enforcing performance is important
# shellcheck enable=require-double-brackets

if [[ -n "${SHELDRITCH_SUBSHELL+ }" && -z "${SHELDRITCH_CLEAN+ }" && "$1" != "--force" ]]
then
	return
fi

#
# Core Initialisation
#

# Ensure the aliases created by this script are available
if [[ -v BASH_VERSION ]]; then
	shopt -s expand_aliases
elif [[ -v ZSH_VERSION ]]; then
	setopt aliases
fi

alias zsh_run='[[ -z ${ZSH_VERSION:-} ]] || '
alias bash_run='[[ -z ${BASH_VERSION:-} ]] || '
alias ksh_run='[[ -z ${KSH_VERSION:-} ]] || '
alias _trace='[[ -n "${TRACE+ }" ]] && echo >&2 '

zsh_run zmodload zsh/parameter

self_file() {
	local Level="$((${1:-0} + 1))"

	if [[ -v BASH_VERSION ]]; then
		echo "${BASH_SOURCE[$Level]}"
	elif [[ -v ZSH_VERSION ]]; then
		echo "${funcfiletrace[$Level]%%:*}"
	fi
}

self_dir() {
	dirname "$(self_file 1)"
}

if [[ -z "${SHELDRITCH+ }" ]]; then
	export SHELDRITCH="$(realpath -s $(self_dir))"
fi
SHELDRITCH_SUBSHELL="${BASH_SUBSHELL:-}${ZSH_SUBSHELL:-}"

# stub out complete if shell does not support autocompletion
if ! command -v complete >/dev/null 2>/dev/null; then
	complete() { return; }
fi

#
# Logging helpers
#

# Dependency for logging
# shellcheck disable=SC2154
alias @func_use_parent='
	local Parent ParentLevel=0
	while [[ -n "$1" ]]; do
		case "$1" in
			-p | --parent ) ParentLevel="$2"
				shift
				shift
				;;
			*) break
				;;
		esac
	done

	ParentLevel="$((ParentLevel + FUNC_PASSTHROUGH + 1))"

	local Parent=''
	if funcname -p $ParentLevel -q 2>/dev/null; then
		Parent="$(funcname -p $ParentLevel)"
	else
		Parent="$(self_file "$ParentLevel")"
	fi
'

_genfunc_log() {
	eval "$1"'() {
		local Trace="${STACKTRACE:-$DEBUG}" Set
		if [[ $- = *x* ]]; then
			set +x
			Set=x
		fi
		@func_use_parent
		echo '"$2"'": ${Parent:+$Parent: }$*" >&2

		if [[ "$(lowercase "$Trace")" = true || "$Trace" = 1 || -n "$Set" ]]; then
			local I=$((ParentLevel - 1)) Caller
			read Line Fu File < <(caller $I)
			sed -n "${Line}s/^/\\t/p" "$File"
			while Caller="$(caller $I)"; do printf "\\t%s\\n" "$Caller"; ((I++)); done
			printf \\n
			set -$Set
		fi >&2
	}
	'
}
_genfunc_log log    Info
_genfunc_log error  Error
_genfunc_log warn   Warning
_genfunc_log _debug Debug

# Echo debug line to stderr if debug turned on
debug() {
	case "$(lowercase "$DEBUG")" in
		true | 1 ) STACKTRACE=false _debug -p 1 "$@"
	esac
}

#
# Other base helpers and variables
#

source "$SHELDRITCH/core/lib.sh"
source_once "$SHELDRITCH/core/compat.sh"

tmp_dir() {
	xdg runtime
}
SHELDRITCH_TMP="${SHELDRITCH_TMP:-$(tmp_dir)/${USER:-$user}/sheldritch}"
! [[ -d $SHELDRITCH_TMP ]] && mkdir -p "$SHELDRITCH_TMP"


alias var_is_local='local >/dev/null 2>&1 -p'
alias var_is_declared='declare >/dev/null 2>&1 -p'

alias safe_quit='declare E=$?; return "$E" 2>/dev/null || exit "$E"'

alias quiet='>/dev/null 2>/dev/null'
alias stderr='>&2'

ecode() { return "$1"; }
