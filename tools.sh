#
# Makes all the shell scripts in `tools` available to the shell
#

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

# source all non-executable shell scripts
for file in $(find "$TOOLS" -name '*.sh'); do
	echo "$file" | grep -q .bin && continue
	grep -q check_is_sourced "$file" || continue
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
		ln -sf "$TOOLS/$file" "$TOOLS/.bin"
	done
	)
}

if [ "$1" = "--sync" ]; then
	add_tools_to_bin
else 
	(add_tools_to_bin &)
fi

PATH="$TOOLS/.bin:$PATH"
