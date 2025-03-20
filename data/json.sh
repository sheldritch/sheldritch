#!/bin/bash
#
# Utils for transforming JSON
# shellcheck disable=SC2016

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
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
function jqj {
	if [[ "$1" = - ]]; then
		jq "${@:2}"
		return
	fi

	# separated because ksh complains
	local Regex='(^[{\"[]|^([-+0-9.Ee]+|true|false|null|)$)'
	if [[ ! "$1" =~ $Regex ]]; then
		error -p 1 "jqj: expected JSON as first argument, instead got '$1'."
		return 9
	fi

	stdin "$1" jq "${@:2}"
}

function json_obj {

	local key value query
	while (($# > 1)); do
		key="$1" value="$2"
		if ! jq -n "$value" >/dev/null 2>&1; then
			value="\"$value\""
		fi
		query+=".[\"$key\"] = $value | "
		shift 2
	done

	if (($# == 1)); then
		error 'odd number of arguments'
		return 1
	fi

	jq -n "$query ."
}

function json_field {
	@help 'json_field: return the value for the given JSON object and key.
		   Usage: json_field JSON FIELD' && return

	[[ "$#" -eq 1 ]] && set -- "-" "$@"
	[[ -z "$1" ]] && return 2

	local query="$(replace "$2"   \" '\"'   '(([^.]|\\.)+)' '["\1"]'   '\\\.' .  )"
	jqj "$1" -re ".$query // empty"
}
alias jfield=json_field
alias jf=json_field

function jbool {
	@help "jbool: compute the truthiness of the given expression on the given JSON
		   Usage: jbool JSON FILTER
	" && return
	isTrue "$(jqj "$1" "(${2:-.}) and true")"
}

function json_check {
	@help 'json_check: throw error if FILTER is not truthy
		   Usage: jbool JSON FILTER' && return
	@func_passthrough
	@func_passthrough # return errors on behalf of the parent function
	[[ "$#" -eq 1 ]] && set -- "-" "$@"
	[[ -z "$1" ]] && return 2

	if ! jbool "$@"; then
		error "failed check '$2':
			$(echo "$1" | head -n 10)
			...
		"
		return 1
	fi
}
alias jcheck=json_check

function jtype {
	if [[ $# -eq 2 ]]; then
		isTrue "$(jqj "$1" "type == \"$2\"")"
	else
		jqj "$1" -r type
	fi
}

# Iterate over given JSON values
# eg for i in $(json_keys "$json"); do
#    	elem="$(jqj "$json" .[$i])"'
#    	...
function json_keys {
	local json length
	@help 'Iterate over given JSON values
		For example:
		for i in $(json_keys "$json"); do
			elem="$(jqj "$json" .[$i])"
			...
	' && return

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
			error "json_keys: unhandled type for '$json'.
			If you think you have sensible behaviour for this type, please add it to this function."
			return 1
	esac
}

function json2vars {
	zsh_run setopt KSH_ARRAYS

	@func_info
	About='Extract values from the given JSON object into the specified versions.

	Arguments of form A=B will access the value of JSON key B and assign it to A.
	Arguments of form A will use A both as the JSON key name and the assigned variable name.
	'
	@args_double_underscore
	Usage='JSON [VAR_NAME=]JSON_KEY...'
	Options=(
		-A --dict=DICT       "Save variables into an associative array"
		-E --export          "Export the variables created"
		-f --filter=FILTER   "jq to apply to the JSON before retrieving values"
		-c --check           "ensure that each variable is set"
	)
	opts_parse

	declare __Json="$1"
	shift

	if [[ -z "${__Json}" ]]; then
		error "No JSON supplied."
		print_doc
		return 1
	fi

	if [[ -n "$__Dict" ]]; then
		error 'associative array support not currently implemented. Sorry!'
		return 9
	fi

	local __Directive=''
	isTrue $__Export && __Directive="export"

	if [[ -z "$__Directive" ]] && ! var_is_declared "${@//=*/}"; then
		error "variables must be declared beforehand"
		error "please call 'local $*' above this function call."
		return 9
	elif [[ -n "$__Directive" ]]; then
		$__Directive "${@//=*/}"
	fi

	local __Var __Field REPLY MATCHES __Values __I=1 __Exit
	# shellcheck disable=SC2016
	__Filter="${__Filter:-.}"' | if . then . else
		("Failed filter '"'${__Filter}'"'\n"
		| halt_error(-1) ) end
			| {in: ., out: [], errors: 0 }
			|'

	for __Var in "${@//=*/}"; do
		__Var=".$(replace "$__Var"   \" '\"'   '(([^.]|\\.)+)' '["\1"]'   '\\\.' .  )"
		__Filter+=$'\nif .in'"$__Var"' == null then .errors += '"$__I"' | .out += [""] else .out += [.in'"$__Var"'] end |'
		((__I *= 2))
	done
	isTrue "$__Check" && __Filter+=$'\n.out[], .errors as $errors | "" | halt_error($errors)'
	__Filter="${__Filter%|}"

	for __Var in "$@"; do
		if regex "$__Var" '([^=]+)=(.+)'; then
			__Var="${MATCHES[1]}"
			__Field="${MATCHES[2]}"
		else
			__Field="$__Var"
		fi
		read -r -d $'\0' "$__Var"
	done < <(jqj "$__Json" --raw-output0 "$__Filter")

	# return the error code of jq process substitution
	wait $!
}

function json_stream {
	local Json
	@func_info
	Usage=(
		"# If JSON is '-', read from standard input"
		'JSON [ELEMENT_FILTER]'
	)
	if (($#)); then
		args_parse
	fi

	jqj "${Json--}" -r --compact-output '
		if (. | type == "array") then
			# flatten any top level arrays
			. | flatten | .[]
		else
			.
		end
		| ['"${ElementFilter:-.}"']
		# allow any nested arrays within element filter to be flattened as well
		| flatten | .[]
		'
}

function json_array_flat {
	@func_passthrough
	json_stream "$@" | jq --slurp .
}
alias jstream=json_stream

# TODO: with the new json2vars format, we might be able to combine all jq calls
# into a single one, and simply read NUL separated values. This would greatly improve performance
function json_read {
	local __item
	read -r __item

	if [[ "$__item" != \{* ]]; then
		if [[ $# -gt 1 ]]; then
			error -p 1 "json_read: Expected object because of multiple keys, but instead got $__item"
			return 9
		fi
		__item="$(jqj "$__item" -re .)" || return 1
		stdin "$__item" read -r -d '' "$1" || true
		return 0
	fi

	json2vars "$__item" "$@"
}
alias jread=json_read

function json_extract_match {
	@func_info
	About='
	For each object in a JSON array (STDIN):
	   - Find a substring in value of SOURCE_FIELD matching REGEX
	   - Set DESTINATION_FIELD to that found value
	'
	Usage='SOURCE_FIELD REGEX DESTINATION_FIELD'
	args_parse

	jq "map((.$SourceField | sub(\".*(?<m>$Regex).*\"; .m)) as \$match | if (\$match | test(\"$Regex\")) then .$DestinationField=\$match else . end )"
}
alias jq_extract_match=json_extract_match


# Pops an attribute/index from JSON and create a matching variable.
#
# Check if the given JSON contains attributes matching the args passed in.
# If the value exists, create a variable matching the atribute key with that values.
# If the argument is an integer, treat the JSON as an array, and create a
# variable arrN (where N is the int)
#
# Does not set or modify dynamic variables if no attribute is found, unless -f is set. outputVar is always set.
function json_pop {

	@func_info
	Usage='-j json keys...'
	Options=(
		-j --json "Required. The input JSON structure to pop content from"
		-o --output --output-var "The variable to contain the input JSON with the popped attributes removed.
			Defaults to $JSON.
			Must not be a local variable in the scope json_pop is called from."
		-n --no-clobber "keep existing values"
		-f --force "Don't error if a field isn't found"
	)
	opts_parse

	# Keep JSON internal if another var is specified
	if [ -n "$OutputVar" ]; then
		local JSON
	fi

	JSON="$Json"

	local ReturnCode=0 Var
	for Var in "$@"; do

		if [ "$Var" = 0 ]; then
			# shellcheck disable=SC2016
			warn '
			Deprecated: do not use json_pop for general array iteration.
			please replace usage in '"$(funcname -p 1)"' with one of the following constructs:

			while json_read fieldA fieldB fieldC=another_name; do
				...
			done < <(json_stream "$Json")

			for i in $(json_keys "$Json"); do
				Elem="$(jqj "$Json" .[$i])"
				...
			done
			'
		fi

		local Match="$Var"

		if [[ "$Var" == *=* ]]; then
			Match="$(value "$Var")"
			Var="$(key "$Var")"
		fi

		if [[ "$Match" == *[^0-9]* ]]; then
			Match="\"$Match\""
		fi

		if [[ "$Var" == *[^0-9]* ]]; then
			Var=arr$Var
		fi

		if ! var_is_declared "$Var"; then
			error "variables must be declared beforehand"
			error "please call 'local $*' above this function call."
			return 9
		fi

		Result="$(jqj "$JSON" -r ".[$Match]")" ||
		if ! anyTrue $Force $NoClobber; then
			error "$Var not found"
			ReturnCode=2
			continue
		elif isTrue $NoClobber; then
			continue
		else
			unset Result
		fi

		stdin "$Result" read  -d '' -r $Var || true
		debug "var '$Var' set to '${!Var}'"

		JSON="$(echo "$JSON" | jq "del(.[$Match])")"
	done

	if [ -n "$OutputVar" ]; then
		stdin "$JSON" read -d '' -r $OutputVar || true

		if [ "$JSON" != "${!OutputVar}" ]; then
			error "\$$OutputVar is set as a local variable in the scope above it.
			This means that json_pop cannot modify the value of this variable."
			return 9
		fi
	fi

	return $ReturnCode
}

function json_audit {
	local ExcludeFields SearchCreds SearchFields
	while [ $# -ne 0 ]; do
		case "$1" in
			-f | --fields | --search-fields ) SearchFields+=" $2"
				shift
				shift
				;;

			-e | --exclude-fields ) ExcludeFields+=" $2"
				shift
				shift
				;;

			* ) break
				;;
		esac
	done

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

	function __audit_help {
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

	function __process_item {

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

			read -r -N 1 -p "Add to audit list? [y/n/c/u/q/?]: " Choice </dev/tty
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
					read -r -p "Comment: " Comment </dev/tty
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
