source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool services/bitwarden/bitwarden.sh

# Count lines.
# Any text past the final newline counts as a line, unlike raw `wc -l`
lines() {
	echo -n "$*" | awk '{print}' | wc -l
}

lines_one() {
	test "$*" -a $(lines "$*") -eq 1
}

lines_none() {
	test "$*" -a $(lines "$*") -eq 0
}

lines_multi() {
	test "$(lines "$*")" -gt 1
}

tgrep() {
	local input="$(cat)"

	echo "$input" | head -1
	echo "$input" | sed 1d | grep "$@"
}
