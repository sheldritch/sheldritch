#!/bin/bash
# shellcheck disable=SC2317,SC2199,SC2154,SC2086,SC1091
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args
summon sheldritch/data/types
trap 'STACKTRACE=1; error FAILED; Fail=1' ERR

zsh_run setopt KSH_ARRAYS

declare _ARGS_NO_CACHE=1

STACKTRACE=1

function try {
	local STACKTRACE=
	Token="$1"
	Arg="$2"
	Expected="$3"

	_args_parse_compound "$Token" "$Arg" || :

	if [[ "$REPLY" != "$Expected" ]]; then
		Error="$REPLY"
		error "Expected '$Expected', got '$Error'.
		Token: '$Token'
		Arg: '$Arg'"
		return 1
	fi
}

try A   a    1
try =A  =a  =1
try A=  a=  1=
# I thought about variable values needing to have some length to be valid
# But if you have A[=B], and the user enters a=, you don't want the value of A to be a=.
# It should just be `a`.
# If not required, they must be isolated with an optional group.
try =A = =1
try A= = 1=
try =A a
try A= a  
try =A= =a  
try =A= a=  
try =A= =a= =1=

try '=[A]' = =1
try '=[A]' a
try '[A]=' '=' '1='
try '[A]=' a
try '=[A]=' =a  
try '=[A]=' =a= =1=
try 'A[+B]=C' '=C' '1=3'

try 'A=B'   a=b 1=2
try 'A=B'   a+b ''
try 'A[=B]' a=b 1=2
try 'A[=B]' a   1

try '[=]A[=]' =a= =1=
try '[=]A[=]' a 1
try '[=]A[=]' =a =1
try '[=]A[=]' a= 1=

# These are all illegal formats
# TODO: We should check them early so an error is always thrown no matter the function input
# A[A]
# A[[A]] Navigate down the group stack until a bounding symbol exists inside the group
# If A[.*][A]]
#fail 'A[=]B' 'aa' ''
#fail 'A[=ABC]B' 'aa' ''

# How to code validation?
# A[[=[[A]]]] Navigate down the group stack until a bounding symbol exists inside the group
# A[[=[[ ]]]] invalid
# A[[=[   ]]] invalid
# A[[=     ]] valid
# A[        ] can ignore all shallower groups
#
# Can turn upside down -- record the deepest current bounding symbol, only 
# A=[A[=     ]] record the deepest group *without* a bounding symbol?

# if unsafe, need to check for inner bounding symbol. If none, illegal
# A=[ # safe
# A=[[ # safe
# A=[[A[ # unsafe
# A=[[A[[ # unsafe
#
# A[=A[ # unsafe, newly found bounding variable
# A[=[A[ # unsafe, newly found bounding variable
# A[=A[=[ # safe
# A[=A[=[A=] # safe
# A[=A[=[A=]] # unsafe, back on level 1, which is unsafe.

# basic test of nested groups
try 'A[=B][+C]' a=b+c 1=2+3
try 'A[=B][+C]' a=b   1=2
try 'A[=B][+C]' a+c   1+3
try 'A[=B[+C]]' a=b+c 1=2+3
try 'A[=B[+C]]' a+c   1

# the first match is always used
