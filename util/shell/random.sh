#!/bin/bash
#
# Random generation utilities
#

random_word() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"
	
	grep -v "[A-Z']" /usr/share/dict/words \
		| shuf --random-source=/dev/urandom --repeat --head-count=$count \
		| tr '\n' ' '
}

random_symbol() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"

	echo $(tr -dc '!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c "$count")
}

random_digit() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"

	echo $(tr -dc '0-9' </dev/urandom | head -c "$count")
}

# insert a character at a random position
random_insert_char() {
	usage() {
		print_usage "insert_rand_char CHARACTER [STRING]"
		print_usage "insert_rand_char symbol [STRING]"
		print_usage "insert_rand_char digit [STRING]"
	}
	@ARGS
		@ARGS_ONLY_DEFAULT_ARGS )
	@ENDARGS

	local string char pos
	char="$1"

	if [ "$#" -ge 2 ]; then
		string="$2"
	else
		string="$(cat)"
	fi

	if [ "$char" = "symbol" ]; then
		char=$(random_symbol)
	elif [ "$char" = "digit" ]; then
		char=$(random_digit)
	fi
	pos=$(shuf -i 1-$length -n 1)
	password="${password:0:$pos}$char${password:$pos}"
	echo "$password"
}
