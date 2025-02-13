#j!/bin/bash
#
# Base script utilities
#

# base.sh is frequently re-run, so enforcing performance is important
# shellcheck enable=require-double-brackets

if [[ -n "${SHELDRITCH_SUBSHELL:-}" && -z "${SHELDRITCH_CLEAN:-}" && "$1" != "--force" ]]
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

# KSH is stupid and can't run aliases after defining them
eval "
alias zsh_run=':'
alias bash_run=':'
alias ksh_run=':'
alias _trace='[[ -n "\${TRACE+ }" || \$- = *x* ]] && echo >&2 '
"

if [[ -n "${ZSH_VERSION:-}" ]]; then
	zmodload zsh/parameter
	alias zsh_run='false ||'
	THIS_SHELL='zsh'
elif [[ -n "${KSH_VERSION:-}" ]]; then
	eval "alias ksh_run='false ||'"
	THIS_SHELL='ksh'
elif [[ -n "${BASH_VERSION:-}" ]]; then
	alias bash_run='false ||'
	THIS_SHELL='bash'
else
	THIS_SHELL="$(ps -p "$$" | grep -m 1 -o '\b[a-z]*sh\b')"
fi

function self_file {
	typeset Level="$((${1:-0} + 1))"

	if [[ -v BASH_VERSION ]]; then
		REPLY="${BASH_SOURCE[$Level]}"
	elif [[ -v ZSH_VERSION ]]; then
		REPLY="${funcfiletrace[$Level]%%:*}"
	fi
	echo "$REPLY"
}

function self_dir {
	self_file 1 >/dev/null
	dirname "$REPLY"
}

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

# Dependency for logging
# shellcheck disable=SC2154
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

	ParentLevel="$((ParentLevel + FUNC_PASSTHROUGH + 1))"

	typeset Parent=''
	if funcname -p $ParentLevel -q 2>/dev/null; then
		Parent="$(funcname -p $ParentLevel)"
	else
		Parent="$(self_file "$ParentLevel")"
	fi
'

function _genfunc_log {
	eval "$1"'() {
		typeset Trace="${STACKTRACE:-$DEBUG}" Set
		if [[ $- = *x* ]]; then
			set +x
			Set=x
		fi
		@func_use_parent
		echo '"$2"'": ${Parent:+$Parent: }$*" >&2

		if [[ "$(lowercase "$Trace")" = true || "$Trace" = 1 || -n "$Set" ]]; then

			if [[ -v BASH_VERSION ]]; then
				typeset I=$((ParentLevel - 1)) Caller
				read Line Fu File < <(caller $I)
				sed -n "${Line}s/^/\\t/p" "$File"
				while Caller="$(caller $I)"; do printf "\\t%s\\n" "$Caller"; ((++I)); done
				printf \\n
			elif [[ -v ZSH_VERSION ]]; then
				args_quoted "${funcstack[@]}" >&2
			fi
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
function debug {
	typeset x
	for x in "$DEBUG" "$TRACE"; do
		quiet lowercase "$x"
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

function ecode { return "$1"; }
