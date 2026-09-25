#!/bin/bash
#
# Utils for video, images, and the like

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function ffmpeg_concat {
	@func_info
	About='Concatenate video files into a single file'
	Usage='INPUT_FILES... OUTPUT_FILE'
	args_parse
	ffmpeg -f concat -safe 0 -loglevel warning \
		-i <(printf "file '$PWD/%s'\n" "${InputFiles[@]}") \
		-c copy "$OutputFile"
}
