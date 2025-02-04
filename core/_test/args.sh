#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

declare _ARGS_NO_CACHE=1

declare Usage
STACKTRACE=1

eq() {
	local STACKTRACE=1
	while [[ $# -gt 0 ]]; do
		if [[ "$1" != "$2" ]]; then
			error "arguments do not match -- '$1' and '$2' ($*)"
			local -p >&2
			return 1
		fi
		shift; shift
	done
}

array_eq() {
	local STACKTRACE=1
	local actual expected
	actual="$(args_quoted "${Array[@]}")"
	expected="$(args_quoted "$@")"
	if [[ "$actual" != "$expected" ]]; then
		error -p 1 "value of array does not match expected
		expected: $expected
		actual:   $actual
		"
		return 2
	fi
}

__parse() {
	parse_args
} 2>&1
parsing_fails() {
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

test_usage() {
	for_permutations run "${Usage[@]}"
}
run() {
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
set +e

# Strict Arity: find the exact match

Usage=(
	'A B C'
	'D E'
	'F'
	'G H I J'
)
check() {
	set -- a b c
	parse_args
	eq $A a $B b $C c

	set -- d e
	parse_args
	eq $D d $E e

	parsing_fails 'Arguments did not match any usage strings.' 1 2 3 4 5
	parsing_fails 'Arguments did not match any usage strings.'
}
test_usage

# an exact number of matches will be selected over an array
# _4 > _+
Usage=(
	'A B C'
	'ARRAY...'
)
check() {
	set -- a b c
	parse_args
	eq $A a $B b $C c

	set -- d e
	parse_args
	eq $A '' $B '' $C ''
	array_eq d e

	set --
	parsing_fails 'Arguments did not match any usage strings.'

	set -- 1 2 3 4
	parse_args
	eq $A '' $B '' $C ''
	array_eq 1 2 3 4
}
test_usage


#
# Literals take precedence
# _3 literal _1 > _5
Usage=(
	'A B C literal E'
	'A B C D E'
)
check() {
	set -- a b c literal e
	parse_args
	eq $D ''

	set -- a b c d e
	parse_args
	eq $D 'd'
}
# TODO: not yet implemented
# if test_usage; then
# 	false
# fi

# two variadic not supported
FORMAT="_3 _+"
FORMAT="_+"
# TODO: write and implement

# Unless literal or other distinguishing feature
# Literals also distinguish variadics (allowed together)
FORMAT="_+ literal _+"
FORMAT="_+"
FORMAT="--flag _+"
# TODO: write and implement

ecode "${Fail:-0}" || safe_quit
