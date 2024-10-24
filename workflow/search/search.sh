source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

# Use FZF to search a JSON array for a particular field match
fzf_json() {
	@func_info
	options=(
		-k --key=KEY "The key of the JSON field to search within"
		-i --id=ID "a json field which identifies each object in the array"
		-q --jq --query=QUERY "A pre-processing query of the JSON"
	)
	args_parse

	if [ -z "$key" ]; then
		echo >&2 "Error: fzf_json: key required"
		print_doc
		return 1
	fi
	if [ -z "$id" ]; then
		error "id required"
		print_doc
		return 1
	fi

	local input

	if [ $# -ge 1 ]; then
		input="$*"
	else 
		input="$(cat)"
	fi

	mkdir -p /tmp/tools
	file="$(mktemp tools/fzf_jzon.XXXXX --tmpdir)"
	jqj "$input" -sc "flatten | .[] | ${query:-.}" > "$file"

	# shellcheck disable=SC2016
	lineTest='select(.id as $id | $line | test("\($id)"))'
	match="$(
		jq -r '"\('".$id) \\(.$key)\"" "$file" |
			fzf --sync --preview 'cat "'"$file"'" | jq --arg line {} '"'$lineTest'"
	)"

	jq --arg line "$match" "$lineTest" "$file"
	rm "$file"
}
