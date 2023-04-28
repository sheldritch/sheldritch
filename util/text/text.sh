source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool services/bitwarden/bitwarden.sh

lines_one() {
	lines="$(echo -n "$*" | wc -l)"
	debug "line_count: $lines"
	! test -z "$*" -o $lines -gt 1
}

lines_multi() {
	test "$(echo -n "$1" | wc -l)" -gt 1
}
