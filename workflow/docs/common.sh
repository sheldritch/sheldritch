# Common helpers for handling documentation

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/common.sh
use_tool services/bitwarden/common.sh

use_tool workflow/repos.sh

# Create or modify a documentation article
doc() {
	@ARGS
		-c | --category ) category="$1"
			shift
			shift
	@ENDARGS

	article="$*"

	dir="$category/$article"
	file="$dir/$article.md"

	pushd "%$(repo_dir knowledge)" >/dev/null
	if ! [ -d "$dir" ]; then
		mkdir "$dir"
		cp '! Article Template.md' "$file"
	fi
	$EDITOR "$path/article.md"

	popd >/dev/null
}

_complete_knowledge_articles() {

	local IFS=$'\n'
	COMPREPLY=($(complete_file_path $(repo_dir knowledge) ${COMP_WORDS[COMP_CWORD]}))

	if ! [ "${#COMPREPLY[@]}" -eq 1 -a -f "${COMPREPLY[0]}" ]; then
		compopt -o nospace
	fi
}
complete -F _complete_knowledge_articles doc
