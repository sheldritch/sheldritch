#!/bin/bash
#
# Random generation utilities
#

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function random_word {
	@func_info
	Options=(
		-c --count=COUNT "integer, defaults to 1. the number of words to generate"
	)
	args_parse

	if ! [ -f /usr/share/dict/words ]; then
		sudo apt-get install wbritish
	fi

	grep -v "[A-Z']" /usr/share/dict/words \
		| shuf --random-source=/dev/random --repeat --head-count=$Count \
		| tr '\n' ' ' | sed 's/ $//'
}

function random_hex {
	@func_info
	Options=(
		-c --count=COUNT
			"integer, defaults to 1. the number of hexadecimal characters to generate"
	)
	args_parse


	openssl rand -hex $((Count / 2 + 1)) | head -c "$Count"
}

function random_char {
	@func_info
	Usage='[ALLOWED_CHARACTERS]'
	Options=(
		-c --count=COUNT
			"integer, defaults to 1. the number of characters to generate"
		--safe "Use a safe subset of the allowed characters (based on URL escaping currently)"
	)
	args_parse
	if [[ "$AllowedCharacters" = \[[^:]*] ]]; then
		warn 'square brackes are not needed around character range. They will be interpreted as raw characters.'
		warn "If you want to use a character class, use the format '[:class:]' (1 pair of [])"
	fi

	tr -dc "${AllowedCharacters:-[:print:]}" </dev/random | {
		isTrue $Safe && tr -dc '[:alnum:]$_.+!*()-' || cat
	} | head -c "$Count"
}

function random_symbol {
	@func_info
	Options=(
		-c --count=COUNT "integer, defaults to 1. the number of words to generate"
	)
	args_parse
	tr -dc '!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/random | head -c "$Count"
}

function random_digit {
	local count
	@func_info
	Options=(
		-c --count=COUNT "integer, defaults to 1. the number of words to generate"
	)
	args_parse

	tr -dc '0-9' </dev/random | head -c "$Count"
}

# A bit of a hacky way to get a random port.
function random_port {
	@func_info
	About='print a random port'
	opts_parse

	local port
	while true; do
		# 10# means in base 10
		port=$(( 10#$RANDOM + 32000 ))
		command -v netstat >/dev/null || break
		netstat --listening | grep -q $port || break
	done
	echo $port
}

# insert a character at a random position
function random_insert_char {

	@func_info
	Usage=(
		'insert_rand_char CHARACTER [STRING]'
		'insert_rand_char symbol [STRING]'
		'insert_rand_char digit [STRING]'
	)
	opts_parse

	local string char length pos
	char="$1"

	if (($# > 1)); then
		string="$2"
	else
		string="$(cat)"
	fi
	length="$(echo -n "$string" | wc -c)"

	if [ "$char" = "symbol" ]; then
		char="$(random_symbol)"
	elif [ "$char" = "digit" ]; then
		char="$(random_digit)"
	fi
	pos=$(shuf -i 1-$length -n 1)
	echo "${string:0:$pos}$char${string:$pos}"
}
