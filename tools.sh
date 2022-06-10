#
# Makes all the shell scripts in `tools` available to the shell
#

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

# source all non-executable shell scripts
for file in $(find "$TOOLS" -name '*.sh' ! -perm /0111); do
	[ "$file" = "$TOOLS/tools.sh" ] && continue
	source_once "$file"
done

add_tools_to_bin() {
	ln -sf $(find "$TOOLS" -perm /0111) "$TOOLS/.bin"
}
(add_tools_to_bin &)
PATH="$TOOLS/.bin:$PATH"
