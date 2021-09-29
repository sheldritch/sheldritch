#! /bin/bash

usage() {
	printf "Usage:\n\n"
	printf "\x1B[31mwormhole_receive <prefix> <wormhole-code>\x1B[0m\n\n"
	printf "Will output file in the current directory as '<prefix>_(date)_(time).txt'\n"
}

receive() {
	# $1: Will be appended to the beginning of the filename (usually beta or prod)
	# $2: The wormhole code
	fileName="$1_$(date +'%d-%m-%y_%H:%M').txt"
	wormhole receive -o "$fileName" "$2"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

receive "$@"