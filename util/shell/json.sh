# Utils for transforming JSON

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# NOTE: common imports this file, but use_tool prevents infinite loop
use_tool util/shell/common.sh

if ! command -v jq >/dev/null; then
	echo >&2 "Error: util/json.sh: jq not installed."
	return
fi

# jq, but the first arg is JSON input
# 
# Slightly shorter than echoing yourself
jqj() {
	local json="$1"
	shift
	echo "$json" | jq "$@"
}

# Pops an attribute/index from JSON and create a matching variable.
#
# Check if the given JSON contains attributes matching the args passed in.
# If the value exists, create a variable matching the atribute key with that values.
# If the argument is an integer, treat the JSON as an array, and create a
# variable arrN (where N is the int)
#
# Does not set or modify dynamic variables if no attribute is found, unless -f is set. outputVar is always set.
json_pop() {
	if ! in_tools_base_context; then
		echo >&2 "Warning: json_pop must not be run in a subshell or a pipe."
		echo >&2 "       If you do this, you will not be able to retrieve the resulting values."
	fi

	local force
	@ARGS
		-h | help | --help ) local HELP="true"
			shift
			;;
		-f | --force ) force="true"
			shift
			;;
		# The input JSON structure to pop content from
		-j | --json ) local json="$2"
			shift
			shift
			;;
		# The variable to contain the input JSON with the popped attributes removed.
		# Defaults to $JSON.
		# Must not be a local variable in the scope json_pop is called from.
		-o | --output | --output-var ) local outputVar="$2"
			shift
			shift
	@ENDARGS

	if [ "$HELP" = true ]; then
		echo >&2 "Usage: json_pop -j json [-o outputJson] attributes..."
		print_args
		return
	fi

	if [ -z "$json" ]; then
		echo >&2 "Error: 'json_pop $*': No JSON provided."
		echo >&2 "       Please specify with the -j flag"
		return 1
	fi

	# Keep JSON internal if another var is specified
	if [ -n "$outputVar" ]; then
		local JSON
	fi

	JSON="$json"

	returnCode=0
	for var in "$@"; do

		local match="$var"
		if grep -q '^[0-9]\+$' <<<"$var"; then
			match="[$var]"
			var=arr$var
		fi

		result="$(echo "$JSON" | jq -r ".$match")"
		if [ "$result" == null ] && [ "$force" != true ]; then
			echo >&2 "json_pop: $var not found"
			returnCode=2
			continue
		fi

		if [ "$result" = null ]; then
			unset result
		fi

		declare -g $var="$result"
		debug "var '$var' set to '${!var}'"

		JSON="$(echo "$JSON" | jq "del(.$match)")"
	done

	if [ -n "$outputVar" ]; then
		declare -g $outputVar="$JSON"

		if [ "$JSON" != "${!outputVar}" ]; then
			echo >&2 "ERROR: json_pop: \$$outputVar is set as a local variable in the scope above it."
			echo >&2 "           This means that json_pop cannot modify the value of this variable."
			return 9
		fi
	fi

	return $returnCode
}
