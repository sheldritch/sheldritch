#!/bin/bash

alias test_init='
trap "STACKTRACE=1; error FAILED" ERR
'

function expect_fail {
	expect_error ".*" "$@"
}

function expect_error {
	@func_passthrough
	local STACKTRACE=1 error match
	match="$1"
	shift

	if error="$("$@" 2>&1)"; then
		error "Expected to fail, but succeeded -- $(args_quoted "$@")"
		return 2
	elif ! [[ "$error" =~ $match ]]; then
		error "Given error not expected for command -- $(args_quoted "$@")
			 expected: '$match'
			 actual:   '$error'
		"
		return 3
	fi
	return 0
}

