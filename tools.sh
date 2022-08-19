#
# Makes all the shell scripts in `tools` available to the shell
#

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

# source all non-executable shell scripts
for file in $(find "$TOOLS" -name '*.sh'); do
	echo "$file" | grep -q .bin && continue
	[ -x "$file" ] && continue
	[ "$file" = "$TOOLS/tools.sh" ] && continue
	source_once "$file"
done

add_tools_to_bin() {
	(
	cd "$TOOLS"
	for file in $(find . -type f); do
		echo "$file" | grep -q .bin && continue
		[ -x "$file" ] || continue
		ln -sf "$file" "$TOOLS/.bin"
	done
	)
}
(add_tools_to_bin &)
PATH="$TOOLS/.bin:$PATH"
