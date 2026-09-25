#!/bin/bash
#
# Commands for building scripts from commands run on the shell.
#
# To begin, look at repl_start, repl_save and repl_save_var

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

repl_start() {
	@help '
	Begin a REPL session, creating a script file which can have lines added to it directly from the REPL.
	' && return
	local ReplDir="$SHELDRITCH_TMP/repl"
	mkdir -p "$ReplDir"
	REPL_ID="$1"
	[[ -z "$REPL_ID" ]] && for _ in "$ReplDir"/*; do
		((++REPL_ID))
	done
	export REPL_FILE="$ReplDir/$REPL_ID.sh"
}

alias repl_last="history -p '!!'"

repl_save() {
	@help "
	Add the last-executed shell command to your REPL session's script.
	If an argument is provided, save the command's output to the variable, both in your shell and in the script.
	" && return

	if [[ $# -ne 1 ]]; then
		repl_last | tee -a "$REPL_FILE"
		return
	fi

	local var
	# shellcheck disable=all
	var="$(repl_last | sed 's/.*/'"$1"'="$(&)"/')"
	echo "$var" | tee -a "$REPL_FILE"
	eval "$var"
	history -s "$var"
}

repl_save_var() {
	@help "
	Same as repl_save, but the variable argument is required.
	" && return
	[ $# -ne 1 ] && { echo >&2 "Usage: repl_save_var VARIABLE_NAME"; return 1; }
	repl_save "$1"
}

repl_open() {
	@help "
	Open your REPL session's script file in an editor, set by the EDITOR environment variable.
	" && return
	${EDITOR:-open} "$REPL_FILE"
}

repl_run() {
	@help "
	Execute your REPL session's script file in your current shell.
	" && return
	. "$REPL_FILE"
}

repl_export() {
	@help "
	Save a copy of your REPL session's script file at the given path.
	" && return
	cp -n "$REPL_FILE" "$1"
}

repl_clear() {
	@help "Clear your REPL session's script." && return
	true > "$REPL_FILE"
}
