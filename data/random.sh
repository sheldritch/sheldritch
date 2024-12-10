#
# Random generation utilities
#

source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

random_word() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"

	if ! [ -f /usr/share/dict/words ]; then
		sudo apt-get install wbritish
	fi

	grep -v "[A-Z']" /usr/share/dict/words \
		| shuf --random-source=/dev/random --repeat --head-count=$count \
		| tr '\n' ' ' | sed 's/ $//'
}

random_hex() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	openssl rand -hex $((count / 2 + 1)) | head -c "$count"
}

random_char() {
	@func_info
	usage='[ALLOWED_CHARACTERS]'
	options=(
		-c --count=COUNT "the number of random characters to output."
		--safe "Use a safe subset of the allowed characters (based on URL escaping currently)"
	)
	args_parse
	if [[ "$1" = \[[^:]*] ]]; then
		warn 'square brackes are not needed around character range. They will be interpreted as raw characters.'
		warn "If you want to use a character class, use the format '[:class:]' (1 pair of [])"
	fi

	tr -dc "${1:-[:print:]}" </dev/random | {
		isTrue $safe && tr -dc '[:alnum:]$_.+!*()-' || cat
	} | head -c "${count:-1}"
}

random_symbol() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"

	tr -dc '!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/random | head -c "$count"
}

random_digit() {
	local count
	@ARGS
	  -c | --count ) count="$2"
		shift
		shift
	@ENDARGS

	count="${count:-1}"

	echo "$(tr -dc '0-9' </dev/random | head -c "$count")"
}

# A bit of a hacky way to get a random port.
random_port() {
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
random_insert_char() {
	usage() {
		print_usage "insert_rand_char CHARACTER [STRING]"
		print_usage "insert_rand_char symbol [STRING]"
		print_usage "insert_rand_char digit [STRING]"
	}
	@ARGS
		@ARGS_ONLY_DEFAULT_ARGS )
	@ENDARGS

	local string char length pos
	char="$1"

	if [ "$#" -gt 1 ]; then
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
