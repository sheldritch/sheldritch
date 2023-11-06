source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool services/bitwarden/bitwarden.sh

curl_json() {
	curl -X POST -H 'Content-Type: application/json' "$@"
}
