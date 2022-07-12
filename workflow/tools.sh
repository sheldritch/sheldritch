# meta-utilities for dealing with the tools repo

# Completion for files in $TOOLS
# TODO: make a generic helper to list files in this format
_completion_tool_list() {
	local IFS=$'\n'

	declare -a files=("$TOOLS/${COMP_WORDS[COMP_CWORD]}"*)
	if ! [ "${#files[@]}" -eq 1 -a -f "${files[0]}" ]; then
		compopt -o nospace
	fi

	COMPREPLY=($(
		cd "$TOOLS"

		for file in "${COMP_WORDS[COMP_CWORD]}"*; do
			if [ -d "$file" ]; then
				echo "$file/" 
			elif [ -f "$file" ]; then
				echo "$file"
			fi
		done
	))
}

complete -F _completion_tool_list use_tool

tool_cd() {
	cd "$TOOLS/$1"
}
complete -F _completion_tool_list tool_cd

tool_edit() {
	declare -a files
	while [ $# -ne 0 ]; do
		case "$1" in
			--help ) local HELP=true
				shift
				break
				;;
			-- )
				shift
				break
				;;
			* ) files+=("$TOOLS/$1")
				shift
				;;
		esac
	done 

	$EDITOR "$@" "${files[@]}"

	for file in "${files[@]}"; do
		if ! [ -x "$file" ] \
			&& grep -q check_is_sourced "$file" \
			&& echo "$file" | grep -q "\.sh$"
		then
			source "$file"
		fi
	done
}
complete -F _completion_tool_list tool_edit

if [ "$EDITOR" ]; then
	alias "tool_$EDITOR"=tool_edit
	complete -F _completion_tool_list "tool_$EDITOR"
fi

tool_diff() {
	(
		cd "$TOOLS"
		git diff "$1"
	)
}
complete -F _completion_tool_list tool_diff

tool_commit() {
	if [ $# -lt 2 ]; then
		echo >&2 "Usage: tool_commit: <tool> <commit message>"
	fi

	file="$1"
	message="$2"
	shift 2

	name="$(basename "$file")"
	if [ $(find "$TOOLS" -name "$name" | wc -l) -gt 1 ]; then
		name="$file"
	fi

	git commit -m "$name: $message" "$TOOLS/$file" "$@"
}
complete -F _completion_tool_list tool_commit
