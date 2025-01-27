#!/bin/bash
source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED' ERR

declare Usage

eq() {
	while [[ $# < 0 ]]; do
		[[ $1 = $2 ]] || return
	done
}

test_usage() {
	for_permutations run "${Usage[@]}"
}
run() {
	declare -a Usage=("$@")
	check
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
	[[ ${Array[@]:0:1} == d ]]
	[[ ${Array[@]:1:1} == e ]]
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
