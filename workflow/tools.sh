# meta-utilities for dealing with the tools repo


source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

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
	local workspace
	declare -a paths
	declare -a files
	while [ $# -ne 0 ]; do
		case "$1" in
			# Select a directory to run the editor from. Defaults to $TOOLS
			-w | --workspace ) workspace="$2"
				shift
				shift
				;;
			--help ) local HELP=true
				shift
				break
				;;
			-- )
				shift
				break
				;;
			* ) paths+=("$1")
				shift
				;;
		esac
	done 

	for path in "${paths[@]}"; do
		matches="$(find "$TOOLS" -path "*$path*")"

		if [ "$(echo "$matches" | wc -l)" -eq 1 ]; then
			files+=("$matches")
		else
			files+=("$TOOLS/$path")
		fi
	done

	(
	cd "${workspace:-$TOOLS}"

	$EDITOR "$@" "${files[@]}"
	)


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
	usage() {
		print_usage "<tool> <commit message> [git_options...]"
	}

	@ARGS
		-p | --push) push=true
			shift
	@ENDARGS

	if [ $# -lt 2 ]; then
		usage
		return 1
	fi

	file="$1"
	message="$2"
	shift 2

	(
	cd "$TOOLS"
	name="$(basename "$file")"
	head="$(dirname "$file")"
	# try and find the shortest unique path to use as a name
	while [ $(find . -path "*/$name" | wc -l) -gt 1 ]; do
		name="$(basename "$head")/$name"
		head="$(dirname "$head")"
	done

	# TODO: Infer a ticket name from the branch and include as '[TIC-100]' at the start
	if git diff --cached --exit-code >/dev/null; then
		git add -i "$file"
	fi
	git commit -m "$name: $message" "$file" "$@"

	if isTrue $push; then
		git push
	fi

	)

}
complete -F _completion_tool_list tool_commit

tool_push() {
	( cd "$TOOLS"; git push )
}
