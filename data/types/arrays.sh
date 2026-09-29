#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args

# Return true if the first argument is equal to any of the remaining arguments
function contains {
	local Match="$1"
	shift

	for Element in "$@"; do
		if [[ "$Element" = "$Match" ]]; then
			return 0
		fi
	done
	return 1
}

# Return true iff the first argument matches any of the remaining arguments as a glob.
function contains_glob {
	local Match="$1"
	shift

	for Element in "$@"; do
		# shellcheck disable=SC2053
		if [[ "$Element" = $Match ]]; then
			return 0
		fi
	done
	return 1
}


function item {
	@func_info
	About="perform a check or operation of a single value against a given list"
	Usage=(
		"ITEM not OPERATOR ELEMENTS..."
		"ITEM in ELEMENTS..."
	)
	if [[ $# -eq 1 && "$1" =~ (-h|--help) ]]; then
		print_doc 2>&1
	fi

	if (($# < 2)); then
		print_doc
		return 1
	fi
	local item="$1" operator="$2"
	shift 2

	case "$operator" in
		not)
			item "$item" "$@"
			local exit="$?"
			case $exit in
				9) return 9;;
				0) return 1;;
				*) return 0;;
			esac
			;;
		in)
			for element in "$@"; do
				if [[ "$element" = "$item" ]]; then
					return 0
				fi
			done
			;;
		glob_in)
			for element in "$@"; do
				if [[ "$element" = $item ]]; then
					return 0
				fi
			done
			;;
		*)
			error "operator '$operator' not supported"
			echo >&2 "  Inside function '$(funcname -p 1 )'"
			return 9
	esac
	return 1 # If ya wanted tuh succeed ya shoulda done it earlia!!
}

# Join ELEMENTS into a string, with each element seperated by DELIMITER
# Usage: join_by DELIMITER ELEMENTS...
function join_by {
	local Delimiter="${1-}" First="${2-}"
	(($# > 1)) || return 0
	shift 2
	printf %s "$First" "${@/#/$Delimiter}"
}


# TODO
#function array_pop {

function _array_weight_compare {
	(( ${1%% *} < ${2%% *} ))
}

# function array_sort_weight {
# 	declare -a Weights REPLY_ARRAY
# 	eval 'Weights=("${'"$2"'[@]}")

# 	'"$1"'=("${REPLY_ARRAY[@]}")'
# }

function _array_compare_int {
	(( ${1:-0} < ${2:-0} ))
}
function _array_compare_string {
	[[ "$1" < "$2" ]]
}

# (C) CC BY-SA 4.0
# modified from https://stackoverflow.com/a/30576368
array_sort() {
	if [[ "$1" = --help ]]; then
		echo >&2  "sort positional arguments
		First argument is a function name that takes two arguments and compares them
		return value in REPLY_ARRAY
		"
		return 0
	fi

	(($# <= 1)) && return 0

	zsh_run setopt KSH_ARRAYS
	local CompareFn=$1
	shift
	case "$CompareFn" in
		string | strings )
			CompareFn=_array_compare_string;;
		int | ints | integer | integers )
			CompareFn=_array_compare_int
			for x in "$@"; do
				if [[ "$x" = *[^[:digit:]]* ]]; then
					error "Arguments include '$x' which is not an integer!"
					sleep 3
					return 9
				fi
			done
			;;
	esac

	local stack=( 0 $(($# - 1)) ) start end i pivot smaller larger
	REPLY_ARRAY=("$@")
	while ((${#stack[@]})); do
		start=${stack[0]}
	end=${stack[1]}
	stack=( "${stack[@]:2}" )
	smaller=() larger=()
	pivot=${REPLY_ARRAY[$start]}
	# Note: iterative, NOT recursive! :)
	for ((i=start+1;i<=end;++i)); do
		if "$CompareFn" "${REPLY_ARRAY[$i]}" "$pivot"; then
			smaller+=( "${REPLY_ARRAY[$i]}" )
		else
			larger+=( "${REPLY_ARRAY[$i]}" )
		fi
	done
	REPLY_ARRAY=( "${REPLY_ARRAY[@]: 0: $start}" "${smaller[@]}" "$pivot" "${larger[@]}" "${REPLY_ARRAY[@]: $end + 1}" )
	if ((${#smaller[@]}>=2)); then stack+=( "$start" "$((start+${#smaller[@]}-1))" ); fi
	if ((${#larger[@]}>=2)); then stack+=( "$((end-${#larger[@]}+1))" "$end" ); fi
done
}

function array_map {
	@func_info
	Usage='ARRAY_NAME FILTER...'
	@opts_before_args
	Options=(
		--stdin "FILTER takes element via standard input instead of an argument"
	)
	opts_parse

	if ! declare -a -p "$1" >/dev/null; then
		error "'$1' is not an array"
		return 1
	fi

	zsh_run setopt KSH_ARRAYS

	local i
	# shellcheck disable=SC2086
	eval 'for (( i = 0; i < ${#'$1'[@]}; i++ )); do
		if isTrue $Stdin; then
			'$1'[$i]="$("${@:2:$# - 1}" <<<"${'$1'[$i]}")"
		else
			'$1'[$i]="$("${@:2:$# - 1}" "${'$1'[$i]}")"
		fi
	done
	'
}

function array_for {
	@func_info
	Usage='ARRAY_NAME ACTION...'
	@opts_before_args
	Options=(
		--stdin "ACTION takes element via standard input instead of an argument"
	)
	opts_parse

	if ! declare -a -p "$1" >/dev/null; then
		error "'$1' is not an array"
		return 1
	fi

	zsh_run setopt KSH_ARRAYS

	local i
	# shellcheck disable=SC2086
	eval 'for (( i = 0; i < ${#'$1'[@]}; i++ )); do
		if isTrue $Stdin; then
			"${@:2:$# - 1}" <<<"${'$1'[$i]}"
		else
			"${@:2:$# - 1}" "${'$1'[$i]}"
		fi
	done
	'
}

# TODO
#function array_filter {

# Run the given function once for every permutation of the given array.
function for_permutations {
	@func_info
	Usage='FUNCTION ARRAY...'
	@opts_before_args
	Options=(
		--fail-early "Fail as soon as FUNCTION returns a failure."
	)
	args_parse

	local Exit=0 Catch=true
	if isTrue $FailEarly; then
		Catch='return 1'
	fi

	_for_permutations_next 0 || return 1
	return "$Exit"
}
function _for_permutations_next {
	zsh_run setopt KSH_ARRAYS
	if (( $1 == ${#Array[@]} - 1 )); then
		"$Function" "${Array[@]}" || { $Catch; ((Exit < 127 && Exit++)); }
		return
	fi

	local i=$1 temp=''
	declare -a Copy
	Copy=("${Array[@]}")

	for (( ; i < ${#Array[@]}; i++ )) ; do
		Array=("${Copy[@]}")
		temp="${Array[$i]}"
		Array[$i]="${Array[$1]}"
		Array[$1]="$temp"
		_for_permutations_next $(($1 + 1)) || return 1
	done
}


