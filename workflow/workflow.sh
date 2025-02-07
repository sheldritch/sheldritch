#!/bin/bash
# move around between certain repos

source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/util/complete
summon sheldritch/data/text

history_delve() {

	if [[ "$1" = --force ]]; then
		rm "$File" 2>/dev/null
	fi

	local Shell=${SHELL##*/}
	local File="$SHELDRITCH_TMP/history_delve.$Shell" Hist="${HISTFILE:-~/.${Shell}_history}"
	trap 'rm "$File" 2>/dev/null' RETURN

	if [[ -e "$File" ]]; then
		error "File '$File' already exists."
		return 1
	fi
	cp -a "$Hist" "$File" || return 1

	trap 'rm "$File" 2>/dev/null' RETURN
	$EDITOR "$File" || return 2
	if [[ "$(wc -l --total=only "$File")" -gt 10 ]]; then
		error "saved history is longer than 10 lines, not executing it"
		cp "$File" "$File.2.$Shell"
		error "File backed up at '$File.2.$Shell' if you still need the changes."
		return 3
	fi
	source "$File"
}
hdelv() { @func_passthrough; history_delve "$@"; }
