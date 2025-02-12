#!/bin/bash
source "$SHELDRITCH/sheldritch.full.sh" || exit 1
declare -F -f +ft -p | {
	while read declare type function; do
		[[ $function = _* ]] && continue
		echo $function
		$function --help
	done
}
