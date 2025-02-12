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
			error "arguments do not match -- '$1' and '$2' ($*)
			$(for v in "${_ARGS_VARS[@]//=/}"; do
				eval "printf \"$v: \$$v, \""
			done)
			_ARGS_FORMAT_INFO $(args_quoted "${_ARGS_FORMAT_INFO[@]}")
			"
			return 1
		fi
		shift; shift
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
	for_permutations run "${Usage[@]}"
}
function run {
	declare -a Usage=("$@") Options=()
	unset _Args_check _Opts_check
	if ! check; then
		# error "Failed checks for Usage:"
		# array_for Usage echo >&2
		return 1
	fi
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
array_eq _ARGS_FORMATS R3
array_eq _ARGS_FORMAT_INFO "3 3 3 0  "

Usage=(
	'A B C'
	'D E'
	'F'
	'G H I J'
)
set -- d e
parse_args
eq "$D" d "$E" e

set +e

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
	set +x 

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
# TODO: not yet implemented
# if test_usage; then
# 	false
# fi

# two variadic not supported
FORMAT="R3 R+"
FORMAT="R+"
# TODO: write and implement

# Unless literal or other distinguishing feature
# Literals also distinguish variadics (allowed together)
FORMAT="R+ literal R+"
FORMAT="R+"
FORMAT="--flag R+"
# TODO: write and implement

ecode "${Fail:-0}" || safe_quit
