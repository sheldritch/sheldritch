# Utils for transforming JSON

source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

if ! command -v jq >/dev/null; then
	echo >&2 "Error: sheldritch/util/json.sh: jq not installed."
	return
fi

# jq, but the first arg is JSON input
# 
# Slightly shorter than echoing yourself
jqj() {
	if [[ ! "$1" =~ (^[{\"[]|^([-+0-9.Ee]+|true|false|null|)$) ]]; then
		error -p 1 "jqj: expected JSON as first argument, instead got '$1'."
		return 9
	fi

	jq "${@:2}" <<<"$1"
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
	local query="$(replace "$2"  \" '\"'  '(([^.]|\\.)+)' '["\1"]'  '\\\.' .)"
	jqj "$1" -re ".$query // empty"
}
alias jfield=json_field
alias jf=json_field

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

json2vars() {
	@func_info
	about='Extract values from the given JSON object into the specified versions.
	Arguments of form A=B will access the value of JSON key B and assign it to A.
	Arguments of form A will use A both as the JSON key name and the assigned variable name.
	'
	usage='JSON [VAR_NAME=]JSON_KEY...'
	options=(
		-A --dict=DICT       "Save variables into an associative array"
		-E --export          "Export the variables created"
		-f --filter=FILTER   "jq to apply to the JSON before retrieving values"
		-c --check           "ensure that each variable is set"
	)
	args_req='__json'
	args_parse

	if [[ -n "$dict" ]]; then
		error 'associative array support not currently impelemented. Sorry!'
		return 9
	fi

	local __directive='' x
	for x in export; do
		if isTrue ${!x}; then
			__directive=$x
			break
		fi
	done

	if [[ -z "$__directive" ]] && ! var_is_declared "${@//=*/}"; then
		error "variables must be declared beforehand"
		error "please call 'local $*' above this function call."
		return 9
	fi

	local __var __exit=0
	__json="$(jqj "$__json" "${filter:-.}")" || return 1
	for __var in "$@"; do
		if [[ "$__var" =~ ([^=]+)=(.+) ]]; then
			eval "$__directive ${BASH_REMATCH[1]}="'"$(json_field "$__json" ${BASH_REMATCH[2]})"' || __exit=$?
		else
			eval "$__directive $__var="'"$(json_field "$__json" $__var)"' || __exit=$?
		fi
	done
	if isTrue $check; then
		return $__exit
	fi
}

json_stream() {
	# the dual 'flatten | .[]' supports complex filtering scenarios and flexible array inputs
	jqj "$1" --slurp --compact-output "flatten | .[] | [${2:-.}] | flatten | .[]"
}
alias jstream=json_stream

json_read() {
	local __item
	read -r __item
	__item="$(jqj "$__item" -re .)" || return 1
	json2vars "$__item" "$@"
}
alias jread=json_read

alias jq_extract_match=json_extract_match
json_extract_match() {
	@func_info
	about='
	For each object in a JSON array (STDIN):
	   - Find a substring in value of SOURCE_FIELD matching REGEX
	   - Set DESTINATION_FIELD to that found value
	'
	usage='SOURCE_FIELD REGEX DESTINATION_FIELD'
	args_req='sourceField regex destField'
	args_parse

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

		if ! var_is_declared "$var"; then
			error "variables must be declared beforehand"
			error "please call 'local $*' above this function call."
			return 9
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

		eval $var='"$result"'
		debug "var '$var' set to '${!var}'"

		JSON="$(echo "$JSON" | jq "del(.[$match])")"
	done

	if [ -n "$outputVar" ]; then
		eval $outputVar='"$JSON"'

		if [ "$JSON" != "${!outputVar}" ]; then
			echo >&2 "ERROR: json_pop: \$$outputVar is set as a local variable in the scope above it."
			echo >&2 "		   This means that json_pop cannot modify the value of this variable."
			return 9
		fi
	fi

	return $returnCode
}

json_audit() {
	local ExcludeFields SearchCreds SearchFields
	@ARGS

		-f | --fields | --search-fields ) SearchFields+=" $2"
			shift
			shift
			;;

		-e | --exclude-fields ) ExcludeFields+=" $2"
			shift
			shift

	@ENDARGS

	local Input="$(cat)"
	local SearchTerm="$(echo "$*" | sed 's/\\/\\\\/g')"

	local Field
	for Field in $SearchFields; do
		if ! jqj "$Input" -s 'flatten | .[] | .'$Field | grep -qv ^null$; then
			error "field '$Field' not found in any Bitwarden item."
			return 1
		fi
	done

	ExcludeFields+=" EXCLUDE_TERM_PLACEHOLDER"
	ExcludeFields="$(echo "$ExcludeFields" | sed -e 's/\S\+/.&,/g' -e 's/,\s*$//g')"

	# Map each items into a nice readable list
	Items="$(jqj "$Input" -rsc 'flatten | .[]
			| . as $item
			| select(.
				'"${searchFields:+" | {} "}"'
				'"$(for field in $SearchFields; do echo '|' .$Field = '$item'.$Field; done)"'
				| '"del( $ExcludeFields)"' 
				| "\(.)" 
				| test("'"$SearchTerm"'"; "i")
			)
		')" || return 1

	__audit_help() {
		echo >&2 ""
		echo >&2 "Note: Pressing a key will _immediately_ move to the next option (for peak efficiency)"
		echo >&2 ""
		echo >&2 "y -- yes, add to audit results list"
		echo >&2 "n -- no, exclude from audit results list"
		echo >&2 "c -- Add to audit results list with comment"
		echo >&2 "u -- undo previous decision"
		echo >&2 "q -- quit, outputting results"
		echo >&2 "? -- print this output"
		echo >&2 ""
	}

	local Results LastOption Undo

	__process_item() {

		local I=$1
		local Item="$(echo "$Items" | awk "NR == $I + 1")"

		echo >&2
		echo >&2
		echo >&2 ---
		echo >&2
		echo >&2
		echo "$Item" | { yq -P . || jq .; } | sed -e 's/\\n/\n/g' -e 's/notes: /&\n/g' >&2
		echo >&2 

		local Option Comment CommentConfirm
		while true; do

			read -N 1 -p "Add to audit list? [y/n/c/u/q/?]: " Choice </dev/tty
			echo >&2
			Option="$Choice"

			case "$Choice" in

				n) break
					;;

				q) return 1
					;;

				y)
					Results+="$Item\n"
					break
					;;

				c)
					read -p "Comment: " Comment </dev/tty
					if [[ "$Comment" = "" ]]; then
						Item="$(jqj "$Item" -c 'del(._comment)')"
					else
						Item="$(jqj "$Item" -c --arg comment "$Comment" '._comment = $comment')"
					fi
					continue
					;;

				u)
					if [ "$I" = "0" ]; then
						echo >&2 "Uhhh, no"
						echo >&2 "Error: cannot go back beyond the first option."
						continue
					fi

					if isTrue $Undo; then
						echo >&2 "Error: cannot undo twice."
						continue
					fi

					if echo "$LastOption" | grep -q [yc]; then
						Results="$(echo "$Results" \
							| sed -E 's/\tComment:[^\\]*\\n$//g' \
							| sed -E 's/(\\n|^)[^\\]*\\n$/\\n/g'
						)"
					fi

					Undo=true
					__process_item "$((i - 1))"
					Undo=false
					continue
					;;

				*) 
					__audit_help
					continue
					;;

			esac


		done

		LastOption="$Option"
	}

	__audit_help
	for ((I = 0 ; I < $(lines "$Items"); I++ )); do
		__process_item $I || break
	done

	echo -e -n "$Results"
}
