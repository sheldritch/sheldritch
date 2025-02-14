#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

repl_start() {
	local ReplDir="$SHELDRITCH_TMP/repl"
	mkdir -p "$ReplDir"
	REPL_ID="$1"
	[[ -z "$REPL_ID" ]] && for _ in "$ReplDir"/*; do
		((++REPL_ID))
	done
	export REPL_FILE="$REPL_DIR/$REPL_ID.sh"
}

alias repl_last="history -p '!!'"

repl_save() {
	if [ $# -ne 1 ]; then
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
	[ $# -ne 1 ] && { echo >&2 "Usage: repl_save_var VARIABLE_NAME"; return 1; }
	repl_save "$1"
}

repl_open() {
	$EDITOR "$REPL_FILE"
}

repl_run() {
	. "$REPL_FILE"
}

repl_export() {
	cp "$REPL_FILE" "$1"
}

repl_clear() {
	true > "$REPL_FILE"
}
