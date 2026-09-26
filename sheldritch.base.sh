#!/bin/bash
#
# Base script utilities
#

# base.sh is frequently re-run, so enforcing performance is important
# shellcheck enable=require-double-brackets

if [[ -n "${SHELDRITCH_SUBSHELL:-}" ]]; then
	# NOTE: This doesn't work for ksh because there's no file stack
	# There is an alias version in check_is_sourced in lib.sh that ksh
	# can fall back on, though
	source_cache_update
	if [[ -z "${SHELDRITCH_CLEAN:-}" && "${1-}" != "--force" ]]; then
		return
	fi
fi

#
# Core Initialisation
#

# Ensure the aliases created by this script are available
if [[ -n "${BASH_VERSION-}" ]]; then
	shopt -s expand_aliases
elif [[ -n "${ZSH_VERSION-}" ]]; then
	setopt aliases
fi

# A few Sheldritch constructs must be global.
# Check if in global scope (i.e. outside a function) or `typeset -g` can be used
{
__SHELDRITCH_SCOPE=1
# in a func, this clears just the local var
typeset __SHELDRITCH_SCOPE=2 && unset __SHELDRITCH_SCOPE

if [[ -n "${__SHELDRITCH_SCOPE+ }" ]] \
	&& ! typeset -g __SHELDRITCH_SCOPE
then
	echo "Error: Sheldritch was sourced inside a function without 'typeset -g' to define global variables."
	echo "  You must source sheldritch.base.sh from top-level or upgrade your shell."
	unset __SHELDRITCH_SCOPE
	return 9
fi
} >&2 2>/dev/null


# trailing '||' handles complex structures like for loops.
#
# 'true' and '||' are used here instead of 'false' and '&&' so the expression
# evaluates to true even if the shell does not match. This is important so
# that functions ending with x_run don't randomly report failure based on the
# shell you're using.
#
# NOTE: KSH is stupid and can't run aliases after defining them
# So don't use the following aliases in this file.
alias zsh_run="true  '(not zsh, skipping command)' ||"
alias bash_run="true '(not bash, skipping command)' ||"
alias ksh_run="true  '(not ksh, skipping command)' ||"
alias _trace='[[ -n "${TRACE+ }" || $- = *x* ]] && echo >&2 '

if [[ -n "${ZSH_VERSION:-}" ]]; then
	zmodload zsh/parameter
	alias zsh_run=''
	THIS_SHELL='zsh'
elif [[ -n "${KSH_VERSION:-}" ]]; then
	eval alias "ksh_run=''"
	THIS_SHELL='ksh'
elif [[ -n "${BASH_VERSION:-}" ]]; then
	alias bash_run=''
	THIS_SHELL='bash'
else
	THIS_SHELL="$(ps -p "$$" | grep -m 1 -o '\b[a-z]*sh\b')"
fi

if [[ -z "${SHELDRITCH_HAS_ASSOC_ARRAYS+ }" ]]; then
	SHELDRITCH_HAS_ASSOC_ARRAYS=''

	if [[ -n "${ZSH_VERSION:-}" ]]; then
		SHELDRITCH_HAS_ASSOC_ARRAYS=1
	elif [[ -n "${BASH_VERSION:-}" ]]; then
		(( BASH_VERSINFO[0] >= 4 )) && SHELDRITCH_HAS_ASSOC_ARRAYS=1
	else
		typeset -A __SHELDRITCH_ASSOC_TEST && SHELDRITCH_HAS_ASSOC_ARRAYS=1
		unset __SHELDRITCH_ASSOC_TEST || :
	fi

	# Prefer global readonly where supported.
	typeset -g -r SHELDRITCH_HAS_ASSOC_ARRAYS || readonly SHELDRITCH_HAS_ASSOC_ARRAYS
fi 2>/dev/null


# print the currently executing file
function self_file {
	if [[ -n "${KSH_VERSION-}" ]]; then
		if [[ "${2:-0}" = 0 ]]; then
			REPLY="$1"
			echo "$1"
			return
		fi
		return 1
	fi

	if [[ "${1-}" = -* ]]; then
		typeset Level="$1"
	else
		typeset Level="$((${1:-0} + 1))"
	fi

	if [[ -n "${BASH_VERSION-}" ]]; then
		REPLY="${BASH_SOURCE[$Level]}"
	elif [[ -n "${ZSH_VERSION-}" ]]; then
		REPLY="${funcfiletrace[$Level]%%:*}"
	fi
	echo "$REPLY"
}

# print the currently executing file's directory
function self_dir {
	if [[ -n "${KSH_VERSION-}" ]]; then
		if [[ "${2:-0}" = 0 ]]; then
			dirname "$1"
			return
		fi
		return 1
	fi
	>/dev/null self_file 1
	dirname "$REPLY"
}
if [[ -n "${KSH_VERSION-}" ]]; then
	alias self_file='self_file "${.sh.file}"'
	alias self_dir='self_dir "${.sh.file}"'
fi

if ! [[ $SHELDRITCH == /* && -f "$SHELDRITCH/sheldritch.base.sh" ]]; then
	export SHELDRITCH
	SHELDRITCH="$(realpath -s "$(self_dir)")" || return 1
fi
SHELDRITCH_SUBSHELL="${BASH_SUBSHELL:-}${ZSH_SUBSHELL:-}"
SHELDRITCH_SUBSHELL="${SHELDRITCH_SUBSHELL:--1}"

# stub out complete if shell does not support autocompletion
if ! command -v complete >/dev/null 2>/dev/null; then
	function complete { return; }
fi

#
# Logging helpers
#

if ! is_function deindent 2>/dev/null; then
	# placeholder before the real deindent func is defined
	function deindent {
		typeset Space="${*#*\n}"; Space="${Space%%[^[:space:]]*}" NL=$'\n'
		REPLY="${*//"$NL$Space"/$NL}"
		printf '%s\n' "$REPLY"
	}
fi

# shellcheck disable=SC2154,SC2142
alias @help='[[ "$#" -eq 1 && "$1" = --help ]] && deindent'

# Dependency for logging
# shellcheck disable=SC2154,SC2142
alias @func_use_parent='
	typeset Parent ParentLevel=0
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

	ParentLevel="$((ParentLevel + ${FUNC_PASSTHROUGH:-0} + 1))"

	typeset Parent=''
	if funcname -p $ParentLevel -q 2>/dev/null; then
		Parent="$(funcname -p $ParentLevel)"
	else
		Parent="$(self_file "$ParentLevel")"
	fi
'

function stacktrace {
	@func_use_parent
	typeset Set="${-//[^x]/}"
	${Set:+set +$_ArgsSet}

	typeset I=$((ParentLevel - 1)) Caller Line Func File

	if command -v caller >/dev/null 2>/dev/null \
		&& Caller="$(caller $I)" 2>/dev/null
	then

		read Line Func File < <(caller $I)
		printf "%s:%s: %s:" "$File" "$Line" "$Func"
		sed -n "${Line}s/^/\\t/p" "$File"

		while Caller="$(caller $I)"; do
			printf '\t%s\n' "$Caller"
			((++I))
		done

	elif [[ -n ${ZSH_VERSION-} ]] && ((${#funcstack[@]})); then
		while ((I < ${#funcstack[@]})); do
			printf '\t%s\n' "${funcstack[I]}"
			((++I))
		done

	elif ((${#FUNCNAME[@]})); then
		while ((I < ${#FUNCNAME[@]})); do
			printf >&2 '\t%s\n' "${FUNCNAME[I]}"
			((++I))
		done

	elif [[ -n "${KSH_VERSION-}" ]]; then
		printf >&2 '\t%s\n' "${.sh.fun}"
	fi

	printf \\n
	${Set:+ set -$Set }
}

function _genfunc_log {
	eval "$1"'() {
		typeset Trace="${STACKTRACE:-${DEBUG-}}" Set Line Func File Last="$_" REPLY
		zsh_run setopt SH_WORD_SPLIT
		Set="${-//[^x]/}"
		${Set:+ set +$Set }

		@func_use_parent
		Line='"$2"'": ${Parent:+$Parent: }$*"
		Line="$(deindent "$Line")"

		echo "$Line" >&2

		if [[ "$(lowercase "$Trace")" = true || "$Trace" = 1 || -n "$Set" ]]; then
			printf "%s\n" "$Last"
			stacktrace -p "$ParentLevel" >&2
		fi >&2
	}
	'
}
_genfunc_log log    Info
_genfunc_log error  Error
_genfunc_log warn   Warning
_genfunc_log _debug Debug

# Echo debug line to stderr if debug turned on
function debug {
	typeset x
	for x in "${DEBUG-}" "${TRACE-}"; do
		lowercase "$x" >/dev/null 2>&1
		if [[ -n "$x" && "$REPLY" =~ ^(1|true)$ ]]; then
			STACKTRACE=false _debug -p 1 "$@"
		fi
	done
}

#
# Other base helpers and variables
#

source "$SHELDRITCH/core/lib.sh"
summon sheldritch/core/compat

function tmp_dir {
	xdg runtime
}
SHELDRITCH_TMP="${SHELDRITCH_TMP:-$(tmp_dir)/${USER:-$user}/sheldritch}"
! [[ -d $SHELDRITCH_TMP ]] && mkdir -p "$SHELDRITCH_TMP"


alias var_is_local='local >/dev/null 2>&1 -p'
alias var_is_declared='declare >/dev/null 2>&1 -p'

alias safe_quit='{ declare E=$?; return "$E" 2>/dev/null || exit "$E"; }'

alias quiet='>/dev/null 2>/dev/null'
alias stderr='>&2'

# so you can do $(comment: <write your comment here!>)
alias comment:='true COMMENT:'

# set the most recent error code
function ecode { return "$1"; }
