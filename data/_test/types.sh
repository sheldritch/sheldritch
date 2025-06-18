#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/types.sh
summon sheldritch/util/test.sh

test_init

eq 0 0 0 0 0 0 0
expect_fail eq 1 0 0 0 0 0 0
expect_fail eq 0 1 0 0 0 0 0
expect_fail eq 0 0 0 0 0 0 1
