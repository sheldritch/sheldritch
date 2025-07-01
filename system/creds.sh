#!/bin/bash
# Helpers for credential management

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

KEYSTORE="$SHELDRITCH_TMP/keystore"

# A shared frontend for secret management
function keyset {
	@func_info
	About='A shared frontend for secret management'
	Usage='KEY SECRET'
	Options=(
		-t --timeout "Time before creds expire in seconds"
	)
	opts_parse

	if [ $# -eq 0 -o "$HELP" = true ]; then
		return 0
	fi

	if [ $# -ne  "2" ]; then
		echo >&2 "Usage: keyset key secret"
		return 1
	fi

	if command -v keyctl >/dev/null; then
		if [ -z "$2" ]; then
			keyctl purge user "$1" >/dev/null || return 1
			return
		fi

		keyctl add user "$1" "$2" @u >/dev/null

		timeout="${timeout:-$((60 * 60 * 2))}"
		keyctl timeout "%user:$1" "$timeout"

	elif command -v keyring >/dev/null; then
		echo "$2" | keyring set "$1" $USER

	elif command -v security >/dev/null; then
		security add-generic-password -a $LOGNAME -s "$1" -w "$2"

	elif [ "$OS" = windows ] && command -v pwsh >/dev/null; then
		debug "keyset: using powershell"
		pwsh -CommandWithArgs '

		$keystore = $env:TMP ?? "'$KEYSTORE'"
		if (Test-Path $keystore) {
			$data = Import-Clixml $keystore
		} else {
			$data = @{}
		}

		$data[$args[0]] = $args[1]
		$data | Export-Clixml -Path $keystore

		' "$1" "$2"
		chmod 600 "$KEYSTORE"

	else
		if [ -z "$KEYSTORE" ]; then
			error "KEYSTORE var missing"
			return 1
		fi

		touch "$KEYSTORE"
		chmod 600 "$KEYSTORE"

		local keys
		keys="$(cat "$KEYSTORE")"

		echo "${keys:-"{}"}" \
			| jq --arg key "$1" --arg value "$2" '.[$key] = $value' \
			> "$KEYSTORE"
	fi

	if [ -n "$2" -a -n "$timeout" ]; then
		(
		nohup bash -c "
			source '$(self_dir)/creds.sh'
			sleep '$timeout'
			keyset -t 1 '$1' ''
		" 2>/dev/null >/dev/null </dev/null &
		disown
		) & disown
	fi

}

# A shared frontend for secret management
function keyget {
	if [[ $# -eq 0 || "$1" = --help ]]; then
		echo >&2 "Usage: keyget key"
		return 0
	fi

	if command -v keyctl >/dev/null; then
		keyctl print "%user:$1" 2>/dev/null

	elif command -v keyring >/dev/null; then
		keyring get "$1" $USER

	elif command -v security >/dev/null; then
		security find-generic-password -w -a $LOGNAME -s "$1"

	elif [ "$OS" = windows ] && command -v pwsh >/dev/null; then
		pwsh -nologo -noprofileloadtime -noprofile -noninteractive -CommandWithArgs '

		$keystore = "'"$KEYSTORE"'"
		if (Test-Path $keystore) {
			$data = Import-Clixml $keystore
		} else {
			$data = @{}
		}

		echo $data[$args[0]]

		' "$1"

	else
		cat "$KEYSTORE" 2>/dev/null | jq --arg key "$1" -r '.[$key] // ""'
	fi
}
