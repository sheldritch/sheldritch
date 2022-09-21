# Common helpers for handling documentation

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/common.sh
use_tool services/bitwarden/common.sh

use_tool workflow/repos.sh

# Create or modify a documentation article
doc() {
	path="$*"

	title="$(basename "$path")"
	file="$path/$title.md"

	if echo "$title" | grep -q '\^'; then
		echo >&2 "Error: article cannot have '^' in its name."
		return 1
	fi

	(
	cd "$(repo_dir knowledge)"
	if ! [ -d "$path" ]; then
		mkdir -p "$path"
		cp '! Article Template.md' "$file"
		sed -i "s^Article Title$^$title^" "$file"
	fi
	$EDITOR "$file"
	)
}

doc_matches() {

	path="$*"

	local IFS=$'\n'
	(
	cd "$(repo_dir knowledge)"
	if command -v fzf >/dev/null; then
		# Weird hack: fzf wants escaped spaces (during tab-completion), but these don't work in later command.
		# So, we're adding them in `-q $path` and removing them again in `--preview`
		find * -type d | fzf --sync -q "$(echo $path | sed 's/ /\ /')" --preview 'cat "$(echo {}"/$(basename {}).md" | sed s/\\\\//)"'
	else
		find * -type d -path "$path*"
	fi
	)
}

_complete_doc() {

	query="${COMP_WORDS[@]:1}"
	COMP_WORDS=("${COMP_WORDS[0]}" "$query")

	local IFS=$'\n'
	COMPREPLY=($(doc_matches "$query"))

	# if ! [ "${#COMPREPLY[@]}" -eq 1 -a -f "${COMPREPLY[0]}" ]; then
	# 	compopt -o nospace
	# fi
}
complete -F _complete_knowledge_articles doc
