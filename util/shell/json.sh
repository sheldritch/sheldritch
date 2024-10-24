# Utils for transforming JSON

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# NOTE: common imports this file, but use_tool prevents infinite loop
use_tool util/shell/shell.sh

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

	if [[ ! "$json" =~ ^[{\"[]|^([-+0-9.Ee]+|true|false|null|)$ ]]; then
		error -p 1 "jqj: expected JSON as first argument, instead got '$json'."
		return 9
	fi

	jq "$@" <<<"$json"
}

json_obj() {

	local key value query
	while key="$1" value="$2" && shift 2; do
		if ! jq -n "$value" >/dev/null 2>&1; then
			value="\"$value\""
		fi
		query+=".[\"$key\"] = $value | "
	done
	jq -n "$query ."
}

json_field() {
	jqj "$1" -re ".$2 // empty"
}
jf() {
	json_field "$@"
}

jbool() {
	isTrue "$(jqj "$1" "($2) == true")"
}

jtype() {
	if [[ $# -eq 2 ]]; then
		isTrue "$(jqj "$1" "type == \"$2\"")"
	else
		jqj "$1" -r type
	fi
}

# Iterate over given JSON values
# eg for i in $(json_it "$json"); do
#    	elem="$(jqj "$json" .[$i])"'
#    	...
json_it() {
	local json length
	usage() {
		echo >&2 "Iterate over given JSON values"
		echo >&2 "For example:"
		echo >&2 "for i in $(json_it "$json"); do"
		echo >&2 "    	elem="$(jqj "$json" .[$i])"'"
		echo >&2 "    	..."
	}

	json="$(args_or_stdin "$@")"

	case $(jqj "$json" -r type) in

		array )
			length="$(jqj "$1" length)"
			seq 0 $(( $length - 1 ))
			;;

		object )
			jqj "$json" keys[]
			;;

		* )
			echo >&2 "Error: json_it: unhandled type for '$json'."
			echo >&2 "If you think you have sensible behaviour for this type, please add it to this function."
			return 1
	esac
}

alias jq_extract_match=json_extract_match
# For each object in a JSON array (STDIN),
#    Find a substring in value of SOURCE_FIELD matching REGEX,
#    and set DESTINATION_FIELD to that found value.
json_extract_match() {

	usage() {
		print_usage "SOURCE_FIELD REGEX DESTINATION_FIELD"
	}

	sourceField="$1"
	regex="$2"
	destField="$3"

	for arg in sourceField regex destField; do
		if [ -z "${!arg}" ]; then
			usage
			return 1
		fi
	done

	jq "map((.$sourceField | sub(\".*(?<m>$regex).*\"; .m)) as \$match | if (\$match | test(\"$regex\")) then .$destField=\$match else . end )"
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
		echo >&2 "	   If you do this, you will not be able to retrieve the resulting values."
	fi

	local force
	@ARGS
		-h | help | --help ) local HELP="true"
			shift
			;;
		# Don't error if a field isn't found
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
		echo >&2 "	   Please specify with the -j flag"
		return 1
	fi

	# Keep JSON internal if another var is specified
	if [ -n "$outputVar" ]; then
		local JSON
	fi

	JSON="$json"

	returnCode=0
	for var in "$@"; do

		if [ "$var" = 0 ]; then
			echo >&2 "Deprecated: do not use json_pop for general array iteration."
			echo >&2 "please replace usage in $(funcname -p 1) with 'json_it':"
			echo >&2
			echo >&2 'for i in $(json_it "$json"); do'
			echo >&2 '	elem="$(jqj "$json" .[$i])"'
			echo >&2 '	..."'
		fi

		local match="$var"

		if echo "$var" | grep -q =; then
			match="$(value "$var")"
			var="$(key "$var")"
		fi

		if grep -q '[^0-9]' <<<"$match"; then
			match="\"$match\""
		fi

		if grep -q '^[0-9]' <<<"$var"; then
			var=arr$var
		fi

		result="$(echo "$JSON" | jq -r ".[$match]")"
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

		JSON="$(echo "$JSON" | jq "del(.[$match])")"
	done

	if [ -n "$outputVar" ]; then
		declare -g $outputVar="$JSON"

		if [ "$JSON" != "${!outputVar}" ]; then
			echo >&2 "ERROR: json_pop: \$$outputVar is set as a local variable in the scope above it."
			echo >&2 "		   This means that json_pop cannot modify the value of this variable."
			return 9
		fi
	fi

	return $returnCode
}
