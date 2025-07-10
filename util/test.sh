#!/bin/bash

alias test_init='
EXIT=0
trap "STACKTRACE=1; error FAILED; EXIT=1" ERR
trap "[[ \"\$EXIT\" != \$? ]] && error \"



WARNING!!!!!! EXIT set as error, but not exiting with said error code!
\"
" EXIT
'

function expect_fail {
	expect_error ".*" "$@"
}

function expect_error {
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
	local STACKTRACE=1 exit Match
	Match="$1"
	shift

	"$@" && :
	exit=$?

	if [[ $exit -ne "$Match" ]]; then
		error "Expected exit code $Match, but got $exit instead -- $(args_quoted "$@")"
		return 2
	fi
}

function expect_array_eq {
	@help 'Usage: expect_array_eq ARRAY ELEMENTS...' && return
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

