source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

# Use FZF to search a JSON array for a particular field match
fzf_json() {
	local key
	@ARGS
		# The key of the  JSON field to search within
		-k | --key ) key="$2"
			shift
			shift
			;;
		# A pre-processing query of the JSON
		-q | --jq | --query ) query="$2"
			shift
			shift
	@ENDARGS

	if [ -z "$key" ]; then
		echo >&2 "Error: fzf_json: key required"
		usage
		return 1
	fi

	if [ $# -ge 1 ]; then
		input="$*"
	else 
		input="$(cat)"
	fi

	if [ "$query" ]; then
		input="$(jqj "$input" "$query")"
	fi

	mkdir -p /tmp/tools
	file="$(mktemp tools/fzf_jzon.XXXXX --tmpdir)"
	echo "$input" > "$file"

	match="$(
		jqj "$input" -r '.[].title' |
			fzf --sync --preview 'cat '"$file"' | jq ".[] | select(.'$key' == \""{}"\")"'
	)"

	jqj "$input" ".[] | select(.$key == \"$match\")"
	rm "$file"
}
