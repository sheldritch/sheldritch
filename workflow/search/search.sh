[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1
check_is_sourced

# Use FZF to search a JSON array for a particular field match
function fzf_json {
	@func_info
	Usage=(
		'# allows - or no argument to read stdin'
		"[JSON...]"
	)
	Options=(
		-k --key=KEY "The key of the JSON field to search within"
		-i --id=ID "a json field which identifies each object in the array"
		-q --jq --query=QUERY "A pre-processing query of the JSON"
	)
	args_parse

	if [[ -z "$Key" ]]; then
		echo >&2 "Error: fzf_json: key required"
		print_doc
		return 1
	fi
	if [[ -z "$Id" ]]; then
		error "id required"
		print_doc
		return 1
	fi

	local File
	File="$(mktemp $SHELDRITCH_TMP/fzf_jzon.XXXXX --tmpdir)"
	jqj "${Json[*]--}" -sc "flatten | .[] | ${Query:-.}" > "$File"

	# shellcheck disable=SC2016
	LineTest='select(.id as $id | $line | test("\($id)"))'
	Match="$(
		jq -r '"\('".$Id) \\(.$Key)\"" "$File" |
			fzf --sync --preview 'cat "'"$File"'" | jq --arg line {} '"'$LineTest'"
	)"

	jq --arg line "$Match" "$LineTest" "$File"
	rm "$File"
}
