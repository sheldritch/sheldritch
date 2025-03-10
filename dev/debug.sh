#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1;
check_is_sourced

function step_through {
	local Fail=0
	set -x
	"$@" || Fail=$?
	set +x
	return $Fail
}
