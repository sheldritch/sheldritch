#!/bin/bash

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1

summon sheldritch/util/test
summon sheldritch/system/files

test_init

function test_abspath {
	[[ "$(abspath "$1")" == "$2" ]]
}

(
test_init
dir="$(mktemp -d)"
trap 'rm -r "$dir"' EXIT

cd "$dir"

# assume inside /parent/cur
# (C) CC BY-SA 3.0
# modified from https://stackoverflow.com/a/23002317/29892672
test_abspath file.txt        $dir/file.txt
test_abspath .               $dir
test_abspath ..              /tmp
test_abspath ../dir/file.txt /tmp/dir/file.txt
test_abspath ../dir/../dir   /tmp/dir # anything cd can handle
test_abspath /file.txt       /file.txt   # handle absolute path input
# TODO:
# test_abspath blah "" does not give good errors
)
