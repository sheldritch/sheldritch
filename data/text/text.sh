#!/bin/bash
# shellcheck disable=SC2034,SC1003,SC2016,SC1083,SC2154
#
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh
summon sheldritch/core/compat.sh
summon sheldritch/data/types.sh

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
	local input
	input="$(cat)" || return $?

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

	if [[ "$x" =~ ([a-z][A-Z]|[A-Z][A-Z]+[a-z]) ]]; then
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
	if [[ -t 1 ]]; then
		@func_info
		usage='TEXT_TO_ENCODE...'
		args_parse
	fi

	declare -a EncodeIfEscaped IgnoreIfEscaped OnlyEncode

	while [[ $# -ne 0 ]]; do case "$1" in
		# If specified, only encode the characters that appear in this argument.
		#
		# Each argument may contain either multiple non-whitespace characters separated by whitespace,
		# or a single whitespace character.
		#
		# May work in conjunction with --only-if-escaped or --ignore-escaped.
		-o | --only | --only-encode )
			if ((${#2} == 1)); then
				OnlyEncode+=("$2")
			else
				OnlyEncode+=($2)
			fi
			shift
			shift
			;;

		# Only encode the given character if it's escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--only-if-escaped) EncodeIfEscaped+=($2)
			shift
			shift
			;;

		# Only encode the given character if it's NOT escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--ignore-escaped) IgnoreIfEscaped+=($2)
			shift
			shift
			;;

		-- )
			shift
			break
			;;

		* ) break
			;;

	esac; done

	args_or_stdin "$@" >/dev/null
	local String="$REPLY"
	local StrLen=${#String}
	local Encoded=""
	local Pos In Out Escaped

	__encode() {
		if (( ${#OnlyEncode[@]} )) && ! contains "$1" "${OnlyEncode[@]}"; then
			Encoded+="$1"
		else
			printf -v Out '%%%02x' "'$1"
			Encoded+="${Out}"
		fi
	}

	for (( Pos=0 ; Pos < StrLen ; Pos++ )); do
		In=${String:$Pos:1}
		case "$In" in
			[-_.~a-zA-Z0-9] ) Encoded+="$In" ;;
			* )
				if [[ "$Escaped" = 1 ]]; then
					if contains "$In" "${EncodeIfEscaped[@]}"; then
						__encode "$In"
					elif contains "$In" "${IgnoreIfEscaped[@]}"; then
						Encoded+="$In"
					else
						__encode '\'
						__encode "$In"
					fi

				elif [[ "$In" = '\' ]]; then
					Escaped=1

				elif contains "$In" "${EncodeIfEscaped[@]}"; then
					Encoded+="$In"
				else
					__encode "$In"
				fi
				;;
		esac
	done
	echo "${Encoded}"  # You can either set a return variable (FASTER)
	REPLY="${Encoded}" #+or echo the result (EASIER)... or both... :p
}

url_decode() {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote('$*'))"
}

glob() {
	@func_info
	about="Matches wildcards against the paths supplied by STDIN. * matches 1 level, and ** matches any number of levels.
		Will print paths in the order of input, and will not print a line twice if two globs match.

		For paths containing newlines, use 'glob_args', which creates a REPLY array.
		For many globs, this func is much faster though.
	"
	usage='GLOBS...'
	options=(
		-i --insensitive --case-insensitive --no-case "allow globs to match case-insensitively"
	)
	args_parse

	local MatchPrefix
	if isTrue $noCase; then
		bash_run shopt_temp nocasematch extglob
		zsh_run setopt KSH_GLOB
		zsh_run MatchPrefix='(#i)'
	fi

	set -- "${@//'*'/+([^/])}"
	set -- "${@//'+([^/])+([^/])'/*}"

	local Path Glob
	while read -r Path; do
		for Glob in "$@"; do
			# shellcheck disable=SC2053
			[[ "$Path" = $MatchPrefix$Glob ]] && printf '%s\n' "$Path"
		done
	done
}

glob_array() {
	@func_info
	about="Uses the first argument as a wildcard to test against all other arguments. * matches 1 level, and ** matches any number of levels.
		The result is returned in the REPLY variable. Will print paths in the order of input. Duplicate arguments will result in duplicfate matches.
	"
	usage='GLOB PATHS...'
	args_parse

	local MatchPrefix
	if isTrue $noCase; then
		bash_run shopt_temp nocasematch extglob
		zsh_run setopt KSH_GLOB
		zsh_run MatchPrefix='(#i)'
	fi

	local Glob="$1" Path
	shift
	Glob="${Glob//'*'/*/*}"
	Glob="${Glob//'*/**/*'/*}"

	REPLY=()

	for Path in "$@"; do
		# shellcheck disable=SC2053
		[[ "$Path" = $MatchPrefix$Glob ]] && REPLY+=("$PATH")
	done
}
