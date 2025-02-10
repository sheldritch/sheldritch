#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

declare _ARGS_NO_CACHE=1

declare Usage
STACKTRACE=1

pass() {
	if ! _args_parse_usage "$@"; then
		error "unexpected failure for args
		Usage: $(args_quoted ${Usage[@]})
		Args:  $(args_quoted "$@")
		"
		return 1
	fi
}

fail() {
	if _args_parse_usage "$@"; then
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
fail a b d
pass a b d asf=asdf
pass a b asf=asdf
