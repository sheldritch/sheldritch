#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function is_type {
	local Val='' Null=''
	if [[ "$1" = --or-null ]]; then
		shift
		Null=1
	fi

	for Val in "${@:2}"; do
		if [[ -n "$Null" && -z "$Val" ]]; then
			continue
		fi
		case "$1" in
			bool | boolean )
				[[ "$Val" == true || "$Val" == false ]] || return 2
				;;

			int | integer )
				[[ "${Val#[+-]}" != *[^[:digit:]]* ]] || return 2
				;;

			decimal )
				Type=decimal
				Test="[[ \"\$$Name\" =~ [+-]?[0-9]+([.,][0-9]+)? ]]"
				Error='Flag "$__Flag" must be a decimal.'
				;;
		esac

	done
}

#
# Functions
#

function is_function {
	declare -p ${BASH_VERSION:+-F} -f "$1" >/dev/null 2>&1
}

function funcs {
	if [[ "$ZSH_VERSION" ]]; then
		# shellcheck disable=SC2296
		print -l ${(ok)functions}
	else
		declare -F | awk '{print $3}'
	fi
}

# WARNING!
# `funcname` should not use any other helper functions to avoid recursion
# except where explicitly commented
function funcname {
	zsh_run setopt KSH_ARRAYS
	local quiet parent=0
	while [[ $# -gt 0 ]]; do case "$1" in
		-q | --quiet) quiet=true
			shift
			;;
		# The number of parents above this function you want to reference
		# The function you call `funcname` from is -p 0, its caller is -p 1, etc
		-p | --parent) parent="$2"
			shift
			shift
			;;
		-h | --help )
			# other utils are okay here
			# do you really expect another util to call `funcname --help`?
			echo >&2 "funcname - print the function name of the caller, or a given parent function"
			echo >&2 "Usage: funcname [options]"
			print_args -f funcname
			return 0
	esac; done

	parent="$((parent + 1))" # this function, `funcname`, counts as an additional layer

	local parentFunc="${FUNCNAME[$parent]}${funcstack[$parent]}"
	if [[ -z "$parentFunc" || "$parentFunc" = source ]] ||
		# Happens when run in shell script
		[[ "$parentFunc" = main && -z "${FUNCNAME[parent + 1]}${funcstack[parent + 1]}" ]]
	then
		[[ "$quiet" = true ]] || echo >&2 "Error: funcname: no shell function found."
		return 1
	fi
	[[ "$quiet" = true ]] || echo "$parentFunc"
	REPLY="$parentFunc"
}
ksh_run alias funcname='REPLY "${.sh.fun}"'

# for all defined functions, create an alias replacing the given extended regex
# with the given match
function alias_funcs {
	functionMatch="$1"
	replacement="$2"

	alias $(funcs | sed -E -n "s/.*/&=&/; s/$functionMatch/$replacement/p")
}

# Print the contents of a given alias. Used for nested aliases.
function alias_print {
	eval "alias=$(alias $1 | sed -E 's/^(alias )?'"$1"'=//' )"
	echo "$alias"
}

# temporarily unset aliases, so they don't interfere with a helper script
function disable_previous_aliases {
	PRE_UTIL_ALIASES="$(alias)"
	for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
		unalias "$alias"
	done
}

# Must be run at the end of a script that disabled previous aliases
function enable_previous_aliases {
	eval "$PRE_UTIL_ALIASES"
}

#
# Booleans
#

isTrue() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for bool in "$@"; do
		if [[ -z "$bool" || "$bool" = false ]]; then
			return 1
		fi

		if [[ "$bool" != true ]]; then
			warn -p 1 "isTrue argument '$bool' is not 'true', 'false' or ''!"
			echo >&2 "!!!"
			sleep 1
			return 9
		fi
	done
}

anyTrue() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for bool in "$@"; do
		[[ "$bool" = "true" ]] && return 0
	done
}

isNull() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for val in "$@"; do
		[[ "$val" = "null" ]] || return 1
	done
}

yesNoToBool() {
	lowercase "$1" >/dev/null
	case "$REPLY" in
		y | yes | true | correct) echo "true"
			;;
		n | no | false | incorrect) echo "false"
			;;
		*)
			echo "null"
			return 1
			;;
	esac
}

#
# Lists/Arrays(/Vectors, I guess)
#

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

function join_by {
	local d=${1-} f=${2-}
	(($# > 1)) || return 0
	shift 2
	printf %s "$f" "${@/#/$d}"
}


function _array_weight_compare (( ${1%% *} < ${2%% *} ))

# function array_sort_weight {
# 	declare -a Weights REPLY_ARRAY
# 	eval 'Weights=("${'"$2"'[@]}")

# 	'"$1"'=("${REPLY_ARRAY[@]}")'
# }

_array_compare_int()    (( $1 < $2 ))
_array_compare_string() [[ $1 < $2 ]]

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

	(($#<=1)) && return 0

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

	local stack=( 0 $(($#-1)) ) start end i pivot smaller larger
	REPLY_ARRAY=("$@")
	while ((${#stack[@]})); do
		start=${stack[0]}
	end=${stack[1]}
	stack=( "${stack[@]:2}" )
	smaller=() larger=()
	pivot=${REPLY_ARRAY[start]}
	# Note: iterative, NOT recursive! :)
	for ((i=start+1;i<=end;++i)); do
		if "$CompareFn" "${REPLY_ARRAY[i]}" "$pivot"; then
			smaller+=( "${REPLY_ARRAY[i]}" )
		else
			larger+=( "${REPLY_ARRAY[i]}" )
		fi
	done
	REPLY_ARRAY=( "${REPLY_ARRAY[@]:0:start}" "${smaller[@]}" "$pivot" "${larger[@]}" "${REPLY_ARRAY[@]:end+1}" )
	if ((${#smaller[@]}>=2)); then stack+=( "$start" "$((start+${#smaller[@]}-1))" ); fi
	if ((${#larger[@]}>=2)); then stack+=( "$((end-${#larger[@]}+1))" "$end" ); fi
done
}

function array_map {
	@func_info
	Usage='ARRAY_NAME FILTER...'
	@options_before_args
	Options=(
		--stdin "filter takes element via standard input instead of an argument"
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
	@options_before_args
	Options=(
		--stdin "action takes element via standard input instead of an argument"
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

function for_permutations {
	@func_info
	Usage='FUNCTION ARRAY...'
	@options_before_args
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
		temp="${Array[i]}"
		Array[i]="${Array[$1]}"
		Array[$1]="$temp"
		_for_permutations_next $(($1 + 1)) || return 1
	done
}


#
# Misc
#

# Returns the key for a given key value pair
function key {
	local delimiter='='
	if [[ "$1" = '-d' ]]; then
		delimiter="$2"
		shift
		shift
	fi

	local pair="$([[ $# -eq 0 ]] && cat || echo $1)"
	printf '%s\n' "${pair%%=*}"
}

# Returns the value for a given key value pair
function value {
	local delimiter='='
	if [[ "$1" = '-d' ]]; then
		delimiter="$2"
		(($# > 1)) && shift 2 || return 9
	fi

	local value pair
	if (($#)); then
		pair="$1"
	else
		pair="$(cat)"
	fi
	[[ "$pair" = *"$delimiter"* ]] || return 2
	[[ "$pair" =~ "$delimiter"(.*)$ ]] || return 2
	printf '%s\n' "${pair##*"$delimiter"}"
}

function ternary {
	eval "$1" && echo "$2" || echo "$3"
}
#function ?: { ternary "$@"; }
#zsh_run \?: { ternary "$@"; }

function ifdef {
	if [[ $# -gt 3 ]]; then
		error -p 2 "wrong argument count to ifdef (:+)"
		return 9
	fi
	[[ -n "$1" ]] && echo "$2" || echo "$3"
}
#function :+ { ifdef "$@"; }

function safe_set {
	if ! declare -p $1 >/dev/null; then
		error "variable '$1' must be declared beforehand"
		echo >&2 "Please call 'local $1' above this function call, and 'declare -r $1' afterwards."
		return 9

	elif deref "$1" >/dev/null && [[ -n "${REPLY}" ]]; then
		error "'$1' Must be a fresh variable, do not set it to some initial value."
		return 9

	elif [[ "$1" = "$2" ]]; then
		error variable cannot be "$2"
		return 9
	fi

	deref "$2" >/dev/null
	eval $1='"$REPLY"'
}

function filter_if {
	if eval "$1"; then
		eval "${2:-cat}"
	else
		eval "${3:-cat}"
	fi
}
