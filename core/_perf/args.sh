#!/bin/bash

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.sh" || return 1 || exit 1


args=(k a 2 b)
for ((x=1; x < ${1:-20}; x += 2)); do
	args+=($x$x)
	if [[ "$EXTRA_ARGS" ]]; then
		args+=(potato)
	fi
done

time eval "$($SHELDRITCH/core/_perf/gen-args.sh "${1:-20}")" || exit 1
time for x in {1..1000}; do
	perf_baseline "${args[@]}" end end || exit 1
done | tail
time for x in {1..1000}; do
	perf_func_info "${args[@]}" end end || exit 1
done | tail
