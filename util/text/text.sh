source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/args.sh

# Count lines.
# Any text past the final newline counts as a line, unlike raw `wc -l`
lines() {
	echo -n "$*" | awk '{print}' | wc -l
}

lines_one() {
	test "$*" -a $(lines "$*") -eq 1
}

lines_none() {
	test "$*" -a $(lines "$*") -eq 0
}

lines_multi() {
	test "$(lines "$*")" -gt 1
}

tgrep() {
	local input="$(cat)"

	echo "$input" | head -1
	echo "$input" | sed 1d | grep "$@"
}

case_sep() {
	local sep="$1"
	shift || return 9
	local x="${*//[-_.]/$sep}"

	if [[ "$x" =~ [a-z][A-Z]|[A-Z][A-Z]+[a-z] ]]; then
		echo "$x" | sed -E \
			-e 's/([A-Z])([A-Z]+)([A-Z])/\1\L\2\U\3/g; # to handle "printURLName" style' \
			-e "s/[A-Z]/$sep\L&/g"
	else
		echo "${x,,}"
	fi
}

case_snake() {
	case_sep _ "$*"
}

case_big_snake() {
	local x
	x="$(case_sep _ "$*")"
	echo "${x^^}"
}

case_kebab() {
	case_sep - "$*"
}

case_camel() {
	local x
	x="$(case_sep _ "$*")"
	echo "$x" | sed "s/_\(.\)/\U\1/g"
}

url_encode() {
	usage() {
		print_usage "[options] [TEXT_TO_ENCODE...]"
	}

	declare -a encodeIfEscaped ignoreIfEscaped onlyEncode
	@ARGS
		# If specified, only encode the characters that appear in this argument.
		#
		# Each argument may contain either multiple non-whitespace characters separated by whitespace,
		# or a single whitespace character.
		#
		# May work in conjunction with --only-if-escaped or --ignore-escaped.
		-o | --only | --only-encode )
			if [ $(echo -n "$2" | wc -c) -eq 1 ]; then
				onlyEncode+=("$2")
			else
				onlyEncode+=($2)
			fi
			shift
			shift
			;;

		# Only encode the given character if it's escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--only-if-escaped) encodeIfEscaped+=($2)
			shift
			shift
			;;

		# Only encode the given character if it's NOT escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--ignore-escaped) ignoreIfEscaped+=($2)
			shift
			shift

	@ARGS_END

	local args="$(args_or_stdin "$@")"

	if [ "$onlyEncode" ]; then
		local encodeChars

		# Find and replace individual characters with their encoded form
		for char in "${onlyEncode[@]}"; do
			local encoded matchPrefix replacePrefix
			encoded="$(url_encode "$char")"

			if contains "$char" "${encodeIfEscaped[@]}"; then
				matchPrefix='\\'

			elif contains "$char" "${ignoreIfEscaped[@]}"; then
				matchPrefix='([^\\])'
				replacePrefix='$1'
			fi

			encodeChars+="s/$matchPrefix\\Q$char\\E/$replacePrefix$encoded/g; "
			# remove leading slash from any remaining non-encoded instances
			encodeChars+='s/\Q\'"$char"'\E/'"$char"'/g; '
		done

		echo "$args" | perl -pe "$encodeChars"
		return $?
	fi

	# pre/post-processing
	local preProc postProc

	# escape single quotes, because we use them inside python.
	preProc+='s/\\'\''/'\\\''/g; '

	for i in $(seq ${#ignoreIfEscaped[@]}); do
		# prevent escaped characters from being encoded
		preProc+='s/\\'${ignoreIfEscaped[@]:$i:1}'/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/g; '

		postProc+='s/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/\'${ignoreIfEscaped[@]}'/g; '
	done

	for i in $(seq ${#ignoreIfEscaped[@]}); do
		# _prevent_ un-escaped characters from being encoded
		preProc+='s/([^\\])'${encodeIfEscaped[@]:$i:1}'/\1~URL_ENCODE_ESCAPED_CHAR_'$i'~/g; '
		# remove extra escape from chars to be encoded
		preProc+='s/\\('${encodeIfEscaped[@]:$i:1}')/\1/g; '

		postProc+='s/~URL_ENCODE_ESCAPED_CHAR_'$i'~/\'${encodeIfEscaped[@]:$i:1}'/g; '
	done

	echo "'$args'" \
		| perl -pe "$preProc" \
		| xargs -I {} python3 -c "import sys, urllib.parse as ul; print (ul.quote('{}'))" \
		| perl -pe "$postProc"
}

url_decode() {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote('$*'))"
}

