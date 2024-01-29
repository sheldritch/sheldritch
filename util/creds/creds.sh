# Helpers for credential management

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced
use_tool util/shell/shell.sh

TOOLS_KEYSTORE="/tmp/tools/keystore-$(whoami)"

# A shared frontend for secret management
keyset() {
	usage() {
		echo >&2 "A shared frontend for secret management"
		echo >&2 "Usage: keyset KEY SECRET"
	}

	local timeout 
	@ARGS
		# Time before creds expire in seconds
		-t | --timeout ) timeout="$2"
			shift
			shift
	@ENDARGS

	if [ $# -eq 0 -o "$HELP" = true ]; then
		return 0
	fi

	if [ $# -ne  "2" ]; then
		echo >&2 "Usage: keyset key secret"
		return 1
	fi

	if command -v keyctl >/dev/null; then
		keyctl add user "$1" "$2" @u >/dev/null

		timeout="${timeout:-$((60 * 60 * 2))}"
		keyctl timeout "%user:$1" "$timeout"

	elif command -v keyring >/dev/null; then
		echo "$2" | keyring set "$1" $USER

	elif command -v security >/dev/null; then
		security add-generic-password -a $LOGNAME -s "$1" -w "$2"

	elif command -v pwsh >/dev/null; then
		debug "keyset: using powershell"
		pwsh -CommandWithArgs '

		$keystore = $env:TMP ?? "'$TOOLS_KEYSTORE'"
		if (Test-Path $keystore) {
			$data = Import-Clixml $keystore
		} else {
			$data = @{}
		}

		$data[$args[0]] = $args[1]
		$data | Export-Clixml -Path $keystore

		' "$1" "$2"
		chmod 600 $TOOLS_KEYSTORE

	else
		echo >&2 "keyset failed: system unsupported for auto credential management."
		return 1
	fi
}

# A shared frontend for secret management
keyget() {
	if [ $# -eq 0 -o "$1" = --help ]; then
		echo >&2 "Usage: keyget key"
		return 0
	fi

	if command -v keyctl >/dev/null; then
		keyctl print "%user:$1" 2>/dev/null

	elif command -v keyring >/dev/null; then
		keyring get "$1" $USER

	elif command -v security >/dev/null; then
		security find-generic-password -w -a $LOGNAME -s "$1"

	elif command -v pwsh >/dev/null; then
		pwsh -nologo -noprofileloadtime -noprofile -noninteractive -CommandWithArgs '

		$keystore = $env:TMP ?? "'$TOOLS_KEYSTORE'"
		if (Test-Path $keystore) {
			$data = Import-Clixml $keystore
		} else {
			$data = @{}
		}

		echo $data[$args[0]]

		' "$1"

	else
		echo >&2 "keyget failed: system unsupported for auto credential management."
		return 1
	fi
}
