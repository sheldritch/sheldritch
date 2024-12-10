#!/bin/bash
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
	local level="$((${1:-0} + 1))"

	if [[ "$BASH_VERSION" ]]; then
		echo "${BASH_SOURCE[$level]}"
	elif [[ "$ZSH_VERSION" ]]; then
		echo "${funcfiletrace[$level]%%:*}"
	fi
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
	local parent parentLevel=0
	while [[ -n "$1" ]]; do
		case "$1" in
			-p | --parent ) parentLevel="$2"
				shift
				shift
				;;
			*) break
				;;
		esac
	done

	parentLevel="$((parentLevel + FUNC_PASSTHROUGH + 1))"

	local parent=''
	if funcname -p $parentLevel -q 2>/dev/null; then
		parent="$(funcname -p $parentLevel)"
	else
		parent="$(self_file "$parentLevel")"
	fi
'

lowercase() {
	 zsh_run printf %s "${1:l}"
	bash_run printf %s "${1,,}"
}

_genfunc_log() {
	eval "$1"'() {
		local trace="${STACKTRACE:-$DEBUG}" set
		if [[ $- = *x* ]]; then
			set +x
			set=x
		fi
		@func_use_parent
		echo '"$2"'": ${parent:+$parent: }$*" >&2

		if [[ "$(lowercase "$trace")" = true || "$trace" = 1 || -n "$set" ]]; then
			local i=$((parentLevel - 1)) Caller
			read line fu file < <(caller $i)
			sed -n "${line}s/^/\\t/p" "$file"
			while Caller="$(caller $i)"; do printf "\\t%s\\n" "$Caller"; ((i++)); done
			printf \\n
			set -$set
		fi >&2
	}
	'
}
_genfunc_log log    Info
_genfunc_log error  Error
_genfunc_log warn   Warning
_genfunc_log _debug Debug

# Echo stderr debug line if turned on
debug() {
	case "$(lowercase "$debug")" in
		true | 1 ) STACKTRACE=false _debug -p 1 "$@"
	esac
}

alias var_is_local='local >/dev/null 2>&1 -p'
alias var_is_declared='declare >/dev/null 2>&1 -p'

source "$SHELDRITCH/core/lib.sh"
