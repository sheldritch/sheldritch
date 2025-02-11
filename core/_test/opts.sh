#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

declare _ARGS_NO_CACHE=1

declare Usage
STACKTRACE=1

alias safe_quite='warn "QUIT $?"; return'
function eq {
	local STACKTRACE=1
	while [[ $# -gt 0 ]]; do
		if [[ "$1" != "$2" ]]; then
			error "arguments do not match -- '$1' and '$2' ($*)
			$(for v in "${_ARGS_VARS[@]//=/}"; do
			# TODO: update to _ARGS_OPTS and _ARGS_OPTS_BOOL
				eval "printf \"$v: \$$v, \""
			done
			#declare -p -f f
			)
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


@func_info

set -e
parse_args

Options=(
	--one ""
)
_args_build_parser_opts
eval "f() {
	declare _ARGS_COUNT=0
	$Builder
}" || ecode 9 || safe_quit

set -- --one
args_parse
eq "$One" true

set -- --one=true
args_parse
eq "$One" true

set -- --one=false
args_parse
eq "$One" false

set -- --no-one
args_parse
eq "$One" false

Options=(
	--string=TEXT ""
	--second=ARG  "doc"
)
_args_build_parser_opts
eval "f() {
	$Builder
}"

set -- --string words
args_parse
eq "$String" words

set -- --string ''
args_parse
eq "$String" ''

set -- --string=words
args_parse
eq "$String" words

set -- --string=
args_parse
eq "$String" ''

set -- --second arg
args_parse
eq "$Second" 'arg'

set -- --string=words --second arg
args_parse
eq "$String" words "$Second" 'arg'

set -- --string words --second arg
args_parse
eq "$String" words "$Second" 'arg'

set -- --string words --second=arg
args_parse
eq "$String" words "$Second" 'arg'

set -- --string=words --second=arg
args_parse
eq "$String" words "$Second" 'arg'

set +e


ecode "${Fail:-0}" || safe_quit
