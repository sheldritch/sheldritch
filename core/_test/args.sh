#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

declare _ARGS_NO_CACHE=1

declare -a Usage=()
STACKTRACE=1

function eq {
	local STACKTRACE=1
	while [[ $# -gt 0 ]]; do
		if [[ "$1" != "$2" ]]; then
			error "arguments do not match -- '$1' and '$2' ($(args_quoted "$@"))
			$(for v in "${_ARGS_VARS[@]//=/}"; do
				eval "printf \"$v: \$$v, \""
			done)
			USAGE: $(args_quoted "${Usage[@]}")
			Matched: ${Usage[_ARGS_USAGE_NUM]}
			ARGS_FORMAT_INFO: $(args_quoted "${_ARGS_FORMAT_INFO[@]}")
			"
			return 1
		fi
		shift; shift
	done
}

function vars_eq {
	declare -a Vars Values
	while (($#)); do
		Vars+=("$1")
		Values+=("$2")
		shift 2 || error 'TESTING ERROR: bad number args'
	done

	for ((i = 0; i < ${#Vars[@]}; i++)); do
		deref "${Vars[i]}" >/dev/null
		if [[ "$REPLY" != "${Values[i]}" ]]; then
			error "Argument did not match expected value:
			expected \"${Values[i]}\", got \"$REPLY\"
			USAGE: $(args_quoted "${Usage[@]}")
			Matched: ${Usage[_ARGS_USAGE_NUM]}
			"
			return 1
		fi
	done
}

function array_eq {
	local STACKTRACE=1
	local actual expected
	actual="$(eval args_quoted "\"\${$1[@]}\"")"
	expected="$(args_quoted "${@:2:$#}")"
	if [[ "$actual" != "$expected" ]]; then
		error -p 1 "value of array does not match expected
		expected: $expected
		actual:   $actual
		"
		return 2
	fi
}

function __parse {
	parse_args
} 2>&1
function parsing_fails {
	local STACKTRACE=1 error match
	match="$1"
	shift

	if error="$(__parse "$@")"; then
		error "Expected to fail, but succeeded -- $(args_quoted "$@")"
		return 2
	elif ! [[ "$error" =~ $match ]]; then
		error "Given error not expected for args -- $(args_quoted "$@")
			 expected: '$match'
			 actual:   '$error'
		"
		return 3
	fi
}

function test_usage {
	for_permutations --fail-early run "${Usage[@]}"
	echo "Passed: $(args_quoted "${Usage[@]}")"
}
function run {
	declare -a Usage=("$@") Options=()
	_trace "Testing permutation
	USAGE: $(args_quoted "${Usage[@]}")
	"
	unset _Args_check _Opts_check
	if ! check; then
		# error "Failed checks for Usage:"
		# array_for Usage echo >&2
		return 1
	fi
}

function test_token {
	local Token="$1" Arg="$2"
	shift 2

	declare -a Checks=("$@")

	Usage="$Token"
	set -- "$Arg"
	args_parse

	vars_eq "${Checks[@]}"

}



@func_info

set -e
parse_args

Usage=(
	'A B C'
)
set -- a b c
parse_args
#declare -p | grep _ARG
eq "$A" a "$B" b "$C" c
#array_eq _ARGS_FORMATS R3
#array_eq _ARGS_FORMAT_INFO "3 3 3 0  "
echo 'passed single usage'

Usage=(
	'A ARRAY... B'
)
set -- a b c
parse_args
eq "$A" a "$B" c
array_eq Array b
echo 'passed middle array'

Usage=(
	'A ARRAY...'
)
set -- a b c
parse_args
eq "$A" a
array_eq Array b c
echo 'passed basic array'

Usage=(
	'A B C'
	'F'
	'D E'
)
set -- d e
parse_args
eq "$D" d "$E" e

echo 'passed initial tests.'

# Strict Arity: find the exact match

function check {
	set -- a b c
	parse_args
	eq "$A" a "$B" b "$C" c

	set -- d e
	parse_args
	eq "$D" d "$E" e

	parsing_fails 'Arguments did not match any usage strings.' 1 2 3 4 5
	parsing_fails 'Arguments did not match any usage strings.'
}
test_usage

# an exact number of matches will be selected over an array
# R4 > R+
Usage=(
	'A B C'
	'ARRAY...'
)
function check {
	set -- a b c
	parse_args
	eq "$A" a "$B" b "$C" c

	set -- d e
	parse_args
	eq "$A" '' "$B" '' "$C" ''
	array_eq Array d e

	# set --
	# parsing_fails 'Arguments did not match any usage strings.'

	set -- 1 2 3 4
	parse_args
	eq "$A" '' "$B" '' "$C" ''
	array_eq Array 1 2 3 4
}
test_usage

# an exact number of matches will be selected over an array
# R4 > R3 O1
# R4 > O3 R1
Usage=(
	'A B C [O]'
	'D E F G'
	'H [I]'
)
function check {
	set -- d e f g
	parse_args
	eq "$A" '' "$B" '' "$C" '' "$O" ''
	eq "$D" d "$E" e "$F" f "$G" g

	set -- h
	parse_args
	eq "$H" h "$I" ''

	set -- a b c
	parse_args
	eq "$A" a "$B" b "$C" c "$O" ''
	eq "$D" '' "$E" '' "$F" '' "$G" ''
	eq "$H" '' "$I" '' "$J" ''
}
test_usage


#
# Literals take precedence
# R3 literal R1 > R5
Usage=(
	'A B C literal E'
	'A B C D E'
)
function check {
	set -- a b c literal e
	parse_args
	eq "$D" ''

	set -- a b c d e
	parse_args
	eq "$D" 'd'
}
test_usage

# compound tokens
test_token 'A[=B]'     a=b   A a B b
test_token 'A[=B][+C]' a=b+c A a B b C c
test_token 'A[=B[+C]]' a=b+c A a B b C c

#
# Optional Runs work
Usage=(
	'A [B C] D'
)
function check {
	set -- a b c d
	parse_args
	vars_eq A a B b C c D d

	set -- a d
	parse_args
	vars_eq A a B '' C '' D d
}
test_usage

# TODO: write and implement
FORMAT="R+ literal R+"
FORMAT="--flag R+"

ecode "${Fail:-0}" || safe_quit
