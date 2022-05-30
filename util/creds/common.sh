# Helpers for credential management

source "$TOOLS"/util/shell/base.sh || return 1
use_tool util/shell/common.sh

KEYCTL_SESSION=@u

# A shared frontend for secret management
keyset() {

    local timeout 
    @ARGS
        # Time before creds expire in seconds
        -t | --timeout ) timeout="$2"
            shift
            shift
    @ENDARGS

    if [ $# -eq 0 -o "$HELP" = true ]; then
        echo >&2 "Usage: keyset key secret"
        return 0
    fi

    if [ $# -ne  "2" ]; then
        echo >&2 "Usage: keyset key secret"
        return 1
    fi

    if command -v keyctl >/dev/null; then
        keyctl add user "$1" "$2" $KEYCTL_SESSION >/dev/null

        timeout="${timeout:-$((60 * 60 * 2))}"
        keyctl timeout "%user:$1" "$timeout"

    else
        echo >&2 "Error: system unsupported"
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
        keyctl print "%user:$1"
    else
        echo >&2 "Error: system unsupported"
        return 1
    fi
}
