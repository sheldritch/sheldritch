#!/bin/bash

alias test_init='
EXIT=0
trap "STACKTRACE=1; error FAILED; EXIT=1" ERR
trap "
Code=\$?
trap - EXIT
if (( \${EXIT:-0} != 0 )); then
	exit \"\$EXIT\"
fi
exit \"\$Code\"
" EXIT
'

function expect_fail {
	@help "
	Succeed if COMMAND fails, otherwise exit with status code 2.

	Usage: expect_fail COMMAND...
	" && return

	@func_passthrough
	expect_error ".*" "$@"
}

function expect_error {
	@help "
	Check if COMMAND fails and outputs text matching the given regex pattern.

	If COMMAND succeeds, print an error and exit with status code 2.
	If COMMAND's output does not match PATTERN succeeds, print an error and exit with status code 3.
	Otherwise return status code 0.

	Usage: expect_error PATTERN COMMAND...
	" && return
	@func_passthrough
	local STACKTRACE=1 error Match
	Match="$1"
	shift

	if error="$("$@" 2>&1)"; then
		error "Expected to fail, but succeeded -- $(args_quoted "$@")"
		return 2
	elif ! [[ "$error" =~ $Match ]]; then
		error "Given error not expected for command -- $(args_quoted "$@")
			 expected: '$Match'
			 actual:   '$error'
		"
		return 3
	fi
	return 0
}

function expect_return {
	@help "
	Run COMMAND and ensure its exit code matches the given value.
	Otherwise, print an error and fail with status code 2.

	Usage: expect_return EXIT_CODE COMMAND...
	" && return
	local STACKTRACE=1 ActualExit ExpectedExit
	ExpectedExit="$1"
	shift

	# Use an `if` guard so shells that trap on failed commands (e.g. zsh TRAPERR)
	# don't treat an expected non-zero exit as a test failure.
	if "$@"; then
		ActualExit=0
	else
		ActualExit=$?
	fi

	case "$ExpectedExit" in
		'' | *[^[:digit:]]* )
			error "Expected exit code must be an integer, got '$ExpectedExit' -- $(args_quoted "$@")"
			return 2
			;;
	esac

	if (( ActualExit != ExpectedExit )); then
		error "Expected exit code $ExpectedExit, but got $ActualExit instead -- $(args_quoted "$@")"
		return 2
	fi
}

function expect_array_eq {
	@help '
	Given an array variable name, compare its elements with ELEMENTS
	Usage: expect_array_eq ARRAY ELEMENTS...
	' && return

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
