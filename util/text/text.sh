source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

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

case_sep() {
	local sep="$1"
	shift || return 9
	local x="${*//[-_.]/$sep}"

	if [[ "$x" =~ [a-z][A-Z]|[A-Z][A-Z]+[a-z] ]]; then
		echo "$x" | sed -E \
			-e 's/([A-Z])([A-Z]+)([A-Z])/\1\L\2\U\3/g; # to handle "printURLName" style' \
			-e "s/[A-Z]/$sep\L&/g"
	else
		echo "${x,,}"
	fi
}

case_snake() {
	case_sep _ "$*"
}

case_big_snake() {
	local x
	x="$(case_sep _ "$*")"
	echo "${x^^}"
}

case_kebab() {
	case_sep - "$*"
}

case_camel() {
	local x
	x="$(case_sep _ "$*")"
	echo "$x" | sed "s/_\(.\)/\U\1/g"
}
