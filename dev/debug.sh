#!/bin/bash

[[ -n ${SHELDRITCH_SOURCES:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1;
check_is_sourced

function step_through {
	set -x
	"$@"
	set +x
}
