#!/bin/bash
# shellcheck disable=SC2034,SC1003,SC2016,SC1083,SC2154
#
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args
summon sheldritch/core/compat
summon sheldritch/data/types

function deindent {
	@func_info
	About="prints lines from stdin, deindented from the given first line"
	args_parse

	local REPLY

	if [[ "$*" =~ $'\n'($'\t'| )+ ]]; then
		rematch >/dev/null
		if [[ -n "${ZSH_VERSION-}" ]]; then
			REPLY=${*//"$REPLY"/$'\n'}
		else
			REPLY="${*//"$REPLY"/$'\n'}"
		fi
		printf "%s\n" "$REPLY"
	else
		printf "%s\n" "$*"
	fi
}

function lines {
	@help '
	Print the number of lines in the given input. Any text past the final newline counts as a line, unlike raw `wc -l`
	Usage: lines [LINES...]
	' && return
	opts_parse

	local Newline=$'\n' Arg Count=0
	for Arg in "$@"; do
		[[ -n "$Arg" ]] || continue
		Arg="${Arg//[^"${Newline#$}"]/}"
		((Count += ${#Arg} + 1))
	done

	if [[ -n "$Equals" ]]; then
		(( Count == Newline ))
		return $?
	fi

	REPLY="$Count"
	echo "$REPLY"
}

function lines_eq {
	@help '
	Exits with a success if and only if EXPECTED_COUNT matches the number of lines, according to `lines`
	Usage: lines_eq EXPECTED_COUNT [LINES...]
	' && return

	if [[ "$1" = *[^0-9]* ]]; then
		error -p 1 'First argument must be an integer!!!'
		sleep 3
		return 9
	fi
	lines "${@:2:$#}" >/dev/null || return
	(( REPLY == $1 ))
}

function lines_gt {
	@help '
	Exits with a success if and only if the number of given lines is greater than MINIMUM
	Usage: lines_gt MINIMUM [LINES...]
	' && return

	if [[ "$1" = *[^0-9]* ]]; then
		error -p 1 'First argument must be an integer!!!'
		sleep 3
		return 9
	fi
	lines "${@:2:$#}" >/dev/null || return
	((REPLY > $1))
}

function lines_lt {
	@help '
	Exits with a success if and only if the number of given lines is less than MAXIMUM
	Usage: lines_lt MINIMUM [LINES...]
	' && return

	if [[ "$1" = *[^0-9]* ]]; then
		error -p 1 'First argument must be an integer!!!'
		sleep 3
		return 9
	fi
	lines "${@:2:$#}" >/dev/null || return
	((REPLY < $1))
}

function lines_one {
	@help '
	Exits with a success if and only if one line is provided.
	Usage: lines_one [LINES...]
	' && return
	lines_eq 1 "$@"
}

function lines_none {
	@help '
	Exits with a success if and only if one line is provided.
	Usage: lines_none [LINES...]
	' && return
	lines_eq 0 "$@"
}

function lines_multi {
	@help '
	Exits with a success if and only if the number of given lines is greater than 1
	Usage: lines_multi [LINES...]
	' && return
	lines_gt 1 "$@"
}

function tgrep {
	@help
	'Grep but it always keeps the first line of content.
	' && return 0
	local input
	input="$(cat)" || return $?

	echo "$input" | head -1
	echo "$input" | sed 1d | grep "$@"
}

# A regex find and replace, optimised for short strings in the pure shell.
# Usage: replace STRING [PATTERN REPLACEMENT]...
#
# This function is very optimised for short, frequent runs
# so excuse the weird structure
function replace {


	local in="$1" Set=''
	shift

	if [[ $- = *x* ]]; then
		Set=1
		set +x
	fi

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
		local Match="$1" replacement="$2"

		if rematch "$replacement" '\\[0-9].*' >/dev/null; then
			# filter out non-capture characters to speed up '=~' check below
			# non-escaped digits are left in (faster to do so), but since we only handle 0-9 those are fine
			local escapes="${REPLY//\\[^0-9]/}"
			escapes="${escapes//[^\\0-9]/}"

			for x in {0..9}; do
				if [[ "$replacement" == *\\$x* ]]; then
					captures+=" $x"
				fi
			done
		fi


		while ((${#in})) && rematch "$in" "$Match" >/dev/null; do
			local capture="$REPLY" sub="$replacement"

			if [[ -z "$capture" ]]; then
				error -p 1 "replace: pattern /$Match/: cannot support matches of zero length!"
				return 9
			fi

			for x in $captures; do
				recapture "$x" >/dev/null
				sub="${sub//\\$x/$REPLY}"
			done

			out+="${in%%"$capture"*}$sub"
			in="${in#*"$capture"}"
		done
		in="$out$in"
		shift 2
	done
	printf '%s\n' "$in"
	REPLY="$in"
	[[ -n "$Set" ]] && set -x
}
function s { @func_passthrough; replace "$@"; }

function case_sep {
	local sep="$1"
	shift || return 9
	local x="${*//[-_., ]/$sep}"

	if [[ "$x" =~ ([a-z][A-Z]|[A-Z][A-Z]+[a-z]) ]]; then
		echo "$x" | sed -E \
			-e 's/([A-Z])([A-Z]+)([A-Z])/\1\L\2\U\3/g; # to handle "printURLName" style' \
			-e "s/[A-Z]/$sep\L&/g"
	else
		lowercase "$x"
	fi
}

function case_snake {
	case_sep _ "$*"
}

function case_big_snake {
	local x
	x="$(case_sep _ "$*")"
	uppercase "$x"
}

function case_kebab {
	case_sep - "$*"
}

function case_camel {
	case_sep _ "$*" | sed "s/_\(.\)/\U\1/g"
}

function case_pascal {
	case_camel "$@" | sed 's/^\(.\)/\U\1/'
}


# URL-encode a string
function url_encode {
	if [[ -t 1 ]]; then
		@func_info
		Usage='TEXT_TO_ENCODE...'
		opts_parse
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

	function __encode {
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

# Decode a URL-encoded string.
function url_decode {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote('$*'))"
}

function glob {
	@func_info
	About="Matches wildcards against the paths supplied by STDIN. * matches 1 level, and ** matches any number of levels.
		Will print paths in the order of input, and will not print a line twice if two globs match.

		For paths containing newlines, use 'glob_args', which creates a REPLY array.
		For many globs, this func is much faster though.
	"
	Usage='GLOBS...'
	Options=(
		-i --insensitive --case-insensitive --no-case "allow globs to match case-insensitively"
	)
	opts_parse

	extglob
	local MatchPrefix
	if isTrue $NoCase; then
		bash_run shopt_temp nocasematch
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

function glob_array {
	@func_info
	About="Uses the first argument as a wildcard to test against all other arguments. * matches 1 level, and ** matches any number of levels.
		The result is returned in the REPLY variable. Will print paths in the order of input. Duplicate arguments will result in duplicfate matches.
	"
	Usage='GLOB PATHS...'
	opts_parse

	extglob
	local MatchPrefix
	if isTrue $NoCase; then
		bash_run shopt_temp nocasematch
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

# TODO: Improve this function with https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream
function ansi2txt {
	 perl -pe 's/\e\[[0-9;]*m(?:\e\[K)?//g'
}
