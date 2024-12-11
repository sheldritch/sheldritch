#!/bin/bash
# shellcheck disable=SC2064

source "$TOOLS/util/shell/base.sh" || return 1
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
}

zsh_run
{
	alias extglob='setopt KSH_GLOB'
}
