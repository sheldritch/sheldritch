#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args

function is_type {
	local TypeName='' Val='' OrNull=''
	if [[ "$1" = --or-null ]]; then
		shift
		OrNull=1
	fi

	if (($# < 2)); then
		error -p 1 'is_type: missing values to check type of. Usage: is_type TYPE VALUES...'
	fi

	TypeName="${1-}"
	case "$TypeName" in
		bool | boolean | int | integer | decimal ) ;;
		string | str ) [[ -n "$OrNull" ]] || return 0;;
		* )
			error -p 1 "is_type: unknown type '$TypeName'"
			return 9 ;;
	esac

	for Val in "${@:2}"; do
		if [[ -n "$OrNull" && -z "$Val" ]]; then
			continue
		fi
		case "$TypeName" in
			bool | boolean )
				[[ "$Val" == true || "$Val" == false ]] || return 2
				;;

			int | integer )
				[[ "${Val#[+-]}" != *[^[:digit:]]* ]] || return 2
				;;

			decimal )
				[[ "$Val" =~ ^[+-]?[0-9]+([.,][0-9]+)?$ ]] || return 2
				;;

			string | str ) ;;
		esac

	done
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

bool2int() {
	case "$1" in
		true ) echo 1;;
		false ) echo 0;;
		* ) return 9;;
	esac
}

#
# Numbers
#

function range_intersects {
	@help "
	range_intersects: given two ranges (A and B), return true if and only if
	some integer x appears in both ranges.

	Usage: range_intersects MIN_A MAX_A MIN_B MAX_B
	" && return

	local MinA="$1" MaxA="$2" MinB="$3" MaxB="$4"
	(( ($MinB <= $MinA && $MinA <= $MaxB)
	|| ($MinB <= $MaxA && $MaxA <= $MaxB) ))
}

#
# Misc
#

function eq {
	local i
	for ((i = 2; i <= $#; i++)); do
		[[ "$1" = "${@: i: 1}" ]] || return 1
	done
	return 0
}

# Returns the key for a given key value pair
function key {
	local Delimiter='='
	if [[ "${1-}" = '-d' ]]; then
		Delimiter="$2"
		(($# > 1)) && shift 2 || return 9
		[[ -n "$Delimiter" ]] || return 9
	fi

	local Pair
	if (($#)); then
		Pair="$1"
	else
		Pair="$(cat)"
	fi
	printf '%s\n' "${Pair%%"$Delimiter"*}"
}

# Returns the value for a given key value pair
function value {
	local Delimiter='='
	if [[ "${1-}" = '-d' ]]; then
		Delimiter="$2"
		(($# > 1)) && shift 2 || return 9
		[[ -n "$Delimiter" ]] || return 9
	fi

	local Value Pair
	if (($#)); then
		Pair="$1"
	else
		Pair="$(cat)"
	fi
	[[ "$Pair" = *"$Delimiter"* ]] || return 2
	[[ "$Pair" =~ "$Delimiter"(.*)$ ]] || return 2
	printf '%s\n' "${Pair##*"$Delimiter"}"
}

function ternary {
	@help 'Evaluate $1. If true, echo $2, otherwise echo $3' && return
	eval "$1" && echo "$2" || echo "$3"
}
function iif { ternary "$@"; }
if [[ -n "${ZSH_VERSION-}" ]]; then
	alias '?:=ternary'
else
	function ?: { @func_passthrough; ternary "$@"; }
fi

function ifdef {
	if [[ $# -gt 3 ]]; then
		error -p 2 "wrong argument count to ifdef (:+)"
		return 9
	fi
	[[ -n "$1" ]] && echo "$2" || echo "$3"
}
function :+ { ifdef "$@"; }

function safe_set {
	@help "
	Given a variable and a value, assign VALUE to VARIABLE_NAME, but only after checking that the following hold true:
		- the variable has previously been scoped using local, declare, typeset, etc.
		- the variable does not currently have another value
		- VARIABLE_NAME is not in the given list of reserved variabled names.

	This function is intended to help construct shell APIs where a variable is
	passed in and set by another variable. It's kind of a goofy concept, and
	it's not a secure way to ensure variable scope is enforced. I'd probably
	avoid using it and just stick to using REPLY like we do throughout this
	project.

	Usage: safe_set VARIABLE_NAME VALUE [RESERVED_VARIABLE_NAMES...]
	" && return

	# SEC: A parent function could just declare a heap of different variable
	# names to try and catch you out if you forget to declare yourself.
	if ! declare -p $1 >/dev/null; then
		error "variable '$1' must be declared beforehand"
		echo >&2 "Please call 'local $1' above this function call, and 'declare -r $1' afterwards."
		return 9

	elif deref "$1" >/dev/null && [[ -n "${REPLY}" ]]; then
		error "'$1' Must be a fresh variable, do not set it to some initial value."
		return 9

	elif contains "$1" "${@:3}"; then
		error "Variable name '$1' is reserved and cannot be used."
		return 9
	fi

	stdin "$2" read -r "$1"
}

function filter_if {
	@help "
	pipe stdin through EVAL_IF_TRUE or EVAL_IF_FALSE, depending on the truthe value of EVAL_EXPRESSION.
	Usage: filter_if EVAL_EXPRESSION [EVAL_IF_TRUE] [EVAL_IF_FALSE]" && return
	if eval "$1"; then
		eval "${2:-cat}"
	else
		eval "${3:-cat}"
	fi
}

summon sheldritch/data/types/'*'
