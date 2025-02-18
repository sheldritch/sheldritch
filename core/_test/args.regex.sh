#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

zsh_run setopt KSH_ARRAYS

declare _ARGS_NO_CACHE=1

declare Usage
STACKTRACE=1

function re {
	usage "^${1//[A-Z]/.*}\$" "${@:2}"
}

function usage {
	Token="$1"
	Arg="$2"
	shift 2
	declare -a Vars Values

	while (($#)); do
		Vars+=("$1")
		Values+=("$2")
		shift 2 || error 'TESTING ERROR: bad number args'
	done


	typeset "${Vars[@]}"
	regex "$Arg" "$Token"
	_args_regex_parser "$Token" "${Vars[@]}"
	eval "$REPLY"

	for ((i = 0; i < ${#Vars[@]}; i++)); do
		deref "${Vars[i]}" >/dev/null
		if [[ "$REPLY" != "${Values[i]}" ]]; then
			error "Argument did not match expected value."
		fi
	done

}

#re    '(A)=(B)\+(C)' a=b+c A a B b C c
usage 'A[=B]'    a=b A a B b
#usage 'A[=B][+C]'    a=b+c A a B b C c
#usage 'A[=B[+C]]'    a=b+c A a B b C c
