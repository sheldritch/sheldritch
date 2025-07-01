#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
summon sheldritch/util/test
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

declare _ARGS_NO_CACHE=1

declare Usage
STACKTRACE=1

function pass {
	declare _ARGS=("$@")
	if ! _args_parse_dynamic "$@"; then
		error "unexpected failure for args
		Usage: $(args_quoted ${Usage[@]})
		Args:  $(args_quoted "$@")
		"
		return 1
	fi
}

function fail {
	declare _ARGS=("$@")
	if _args_parse_dynamic "$@"; then
		error "expected invalid args, got valid
		Usage: $(args_quoted ${Usage[@]})
		Args:  $(args_quoted "$@")
		"
		return 1
	fi
}
set -e

Usage=('a b c')
pass a b c
fail a b j
fail a b c d
fail a b cc

Usage=('a b A')
pass a b c
pass a b j
fail a b
fail a b c d

Usage=('a b A...')
pass a b c d

Usage=('a b A... d')
pass a b c d
pass a b j d
pass a b c c d
fail a b d
fail a b c j
fail a j c d

Usage=('a b [A]... C=B')
fail a b A
pass a b A c=b
pass a b c=b

Usage=('a b [A].. C=B')
fail a b A
pass a b A asf=asdf
fail a b asf=asdf b
pass a b A=A A end=real
expect_array_eq _ARGS_BOUNDS 0 1 2 4 5

Usage=('a b [A].. C=B D...')
fail a b j end=real
pass a b c=b d d=d # Empty A
expect_array_eq _ARGS_BOUNDS 0 1 2 2 3 5

Usage=('a b [A].. [C=B]... D..')
pass a b end=fake j end=real


Usage=('a b [literal..] [D...]')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 2 4

# In A.. D..., A must be exactly 1 arg long
Usage=('a b A.. D...')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 3 4

Usage=('a b A.. [D...]')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 3 4

# If optional, A is ignored entirely here
# probably should throw an error if this happens
Usage=('a b [A..] D...')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 2 4

Usage=('a b [A].. [D]...')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 2 4
Usage=('a b [A..] [D...]')
pass a b A D
expect_array_eq _ARGS_BOUNDS 0 1 2 2 4
