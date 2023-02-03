#
# Makes all the shell scripts in `tools` available to the shell
#

unset TOOLS_SOURCES

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

if find "$TOOLS/tools.sh" -not -perm /111 -quit; then
	exec=/111
else
	exec=+111
fi

# source all non-executable shell scripts
for file in $(find "$TOOLS" -type f -not -perm $exec -name '*.sh' -not -path "*/.bin/*" ); do
	grep -q check_is_sourced "$file" || continue
	[ "$file" = "$TOOLS/tools.sh" ] && continue

	source_once "$file"
done

add_tools_to_bin() {
	(
	cd "$TOOLS"
	for file in $(find . \
		\( -path '*/.*' -o -path '*/_*' \) -prune `# skip files/directories starting with '.' or '_' `\
			-o -type f -print `# print all other files `\
		)
	do
		[ -x "$file" ] || continue
		ln -sf ".$file" "$TOOLS/.bin" # `find` adds `./` to each $file already
	done
	)
}

if [ "$1" = "--sync" ]; then
	add_tools_to_bin
else
	(add_tools_to_bin &)
fi

PATH="$TOOLS/.bin:$PATH"
