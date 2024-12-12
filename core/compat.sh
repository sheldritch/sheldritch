#!/bin/bash
# shellcheck disable=SC2064

source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

_trap_cmd() { Command="${3:-true}"; }

trap_return_add() {
	@func_use_parent

	local OldTrap Command NewCommand="$1"
	shift || return 9
	OldTrap="$(trap -p RETURN)"

	eval "_trap_cmd $OldTrap"
	trap -- "$Command; $NewCommand; $OldTrap" RETURN

	for ((I = 0; I <= ParentLevel; I++)); do
		trap "$(trap -p RETURN)" RETURN
	done
}
declare -f -t trap_return_add

# appends a command to a trap
#
# - 1st arg:  code to add
# - remaining args:  names of traps to modify
#
trap_add() {
    local NewCommand="$1" Signal Command
	shift || return 9

    for Signal in "$@"; do
		eval "__trap_cmd $(trap -p $Signal)"
        trap -- "$Command; $NewCommand" "$Signal"
    done
}
declare -f -t trap_add

shopt_temp() {
	trap_return_add -p 1 "$(shopt -p "$@")"
	shopt -s "$@"
}
shopt_temp_unset() {
	trap "$(shopt -p "$@")" RETURN
	shopt -u "$@"
}

bash_run
{
	alias extglob='shopt_temp extglob'
	lowercase() { printf %s "${1,,}"; }
	uppercase() { printf %s "${1^^}"; }

	regex() {
		if (($#)); then
			[[ "$1" =~ $2 ]] || return $?
		fi
		MATCHES=( "${BASH_REMATCH[@]}" )
	}
	rematch() {
		regex "$@" || return $?
		recapture 0
	}
	recapture() {
		REPLY="${BASH_REMATCH[$1]}"
		printf "%s" "$REPLY"
	}
}

ksh_run
{
	alias extglob=':'
	lowercase() { declare -l Val="$1"; printf %s "$Val"; }
	uppercase() { declare -u Val="$1"; printf %s "$Val"; }

	regex() {
		if (($#)); then
			[[ "$1" =~ $2 ]] || return $?
		fi
		MATCHES=( "${.sh.match[@]}" )
	}
	rematch() {
		regex "$@" || return $?
		recapture 0
	}
	recapture() {
		REPLY="${.sh.match[$1]}"
		printf "%s" "$REPLY"
	}
}

zsh_run
{
	alias extglob='setopt KSH_GLOB'
	lowercase() { printf %s "${1:l}"; }
	uppercase() { printf %s "${1:u}"; }

	regex() {
		if (($#)); then
			[[ "$1" =~ $2 ]] || return $?
		fi
		MATCHES=( "$MATCH" "${match[@]}" )
	}
	rematch() {
		regex "$@" || return $?
		REPLY="$MATCH"
		printf "%s" "$REPLY"
	}
	recapture() {
		REPLY="${match[@]:$(($1 - 1)):1}"
		printf "%s" "$REPLY"
	}

}

return 0
