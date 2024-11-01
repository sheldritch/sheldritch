source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/args.sh

deindent() {
	@func_info
	about="prints lines from stdin, deindented from the given first line"
	args_parse

	if [[ "$*" =~ $'\n'($'\t'| )+ ]]; then
		printf "%s\n" "${*//"${BASH_REMATCH[0]}"/$'\n'}"
	else
		printf "%s\n" "$*"
	fi
}

lines() {
	local about='Count lines. Any text past the final newline counts as a line, unlike raw `wc -l`'
	@DEFAULT_ARGS
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

# This function is very optimised for short, frequent runs
# so excuse the weird structure
replace() {

	local in="$1"
	shift

	# Okay, I know I just said 'very optimised', but like, it does not scale in the slightest.
	# For long strings, just use sed...
	if [[ "${#in}" -gt 500 ]]; then
		declare -a args=()
		while [[ $# -gt 1 ]]; do
			args+=(-e "s/$1/$2/g")
		done
		sed -E "${args[@]}" <<<"$in"
		return $?
	fi

	while [[ $# -gt 1 ]]; do
		local out="" captures=""
		local match="$1" replacement="$2"

		if [[ "$replacement" =~ \\[0-9].* ]]; then
			# filter out non-capture characters to speed up '=~' check below
			# non-escaped digits are left in (faster to do so), but since we only handle 0-9 those are fine
			local escapes="${BASH_REMATCH[0]//\\[^0-9]/}"
			escapes="${escapes//[^\\0-9]/}"

			for x in {0..9}; do
				if [[ "$replacement" =~ \\$x ]]; then
					captures+=" $x"
				fi
			done
		fi


		while [[ "$in" =~ $match ]]; do
			local capture="${BASH_REMATCH[0]}" sub="$replacement"

			for x in $captures; do
				sub="${sub//\\$x/${BASH_REMATCH[$x]}}"
			done

			out+="${in%%"$capture"*}$sub"
			in="${in#*"$capture"}"
		done
		in="$out$in"
		shift 2
	done
	printf '%s\n' "$in"
}
s() { replace "$@"; }

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

