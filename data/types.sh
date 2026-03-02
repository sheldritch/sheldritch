#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function is_type {
	local Val='' Null=''
	if [[ "$1" = --or-null ]]; then
		shift
		Null=1
	fi

	for Val in "${@:2}"; do
		if [[ -n "$Null" && -z "$Val" ]]; then
			continue
		fi
		case "$1" in
			bool | boolean )
				[[ "$Val" == true || "$Val" == false ]] || return 2
				;;

			int | integer )
				[[ "${Val#[+-]}" != *[^[:digit:]]* ]] || return 2
				;;

			decimal )
				Type=decimal
				Test="[[ \"\$$Name\" =~ [+-]?[0-9]+([.,][0-9]+)? ]]"
				Error='Flag "$__Flag" must be a decimal.'
				;;
		esac

	done
}

#
# Functions
#

function is_function {
	declare -p ${BASH_VERSION:+-F} -f "$1" >/dev/null 2>&1
}

function funcs {
	@help '
	Print all declared functions.
	Usage: funcs
	' && return
	if [[ -n "${ZSH_VERSION-}" ]]; then
		# shellcheck disable=SC2296
		print -l ${(ok)functions}
	else
		declare -F | awk '{print $3}'
	fi
}

function func_source_file {
	@func_info
	About='Print the source file that most recently defined FUNCTION.'
	Usage='FUNCTION'
	zsh_run setopt KSH_ARRAYS
	args_parse

	local Path
	if ! is_function "$Function"; then
		error "function '$Function' not found"
		return 1
	fi

	if [[ -n "$BASH_VERSION" ]]; then
		Path="$(shopt -s extdebug; declare -F "$Function" | awk '{print $3}')"
		if [[ -n "$Path" ]]; then
			REPLY "$Path"
			return
		fi
	elif [[ -n ${ZSH_VERSION-} ]]; then
		zmodload zsh/parameter >/dev/null 2>&1 || :
		Path="${functions_source[$Function]}"
		if [[ -n "$Path" ]]; then
			REPLY "$Path"
			return
		fi
	fi

	warn "falling back to Sheldritch's SHELDRITCH_SOURCES array."

	if ((${#SHELDRITCH_SOURCES[@]} == 0)); then
		error "no sourced files are cached"
		return 1
	fi

	local I Name
	zsh_run setopt KSH_ARRAYS
	for ((I = ${#SHELDRITCH_SOURCES[@]} - 1; I >= 0; I--)); do
		Path="${SHELDRITCH_SOURCES[I]}"
		[[ -r "$Path" ]] || continue
		while IFS= read -r Name; do
			if [[ "$Name" = "$Function" ]]; then
				REPLY "$Path"
				return
			fi
		done < <(funcs_in_file "$Path")
	done

	error "function '$Function' is defined, but no defining source file was found in source cache"
	return 1
}

function funcs_in_file {
	@func_info
	About='List function names that appear in FILE.'
	Usage='FILE'
	zsh_run setopt KSH_ARRAYS
	args_parse

	if ! [[ -f "$File" ]]; then
		error "file '$File' not found"
		return 1
	fi

	local Flavor='sh' Shebang=''
	case "$File" in
		*.bash) Flavor='bash' ;;
		*.zsh) Flavor='zsh' ;;
		*.ksh) Flavor='ksh' ;;
		*.sh)
			IFS= read -r Shebang < "$File" 2>/dev/null || :
			case "$Shebang" in
				'#!'*bash*|*'/bash'*) Flavor='bash' ;;
				'#!'*zsh*|*'/zsh'*)   Flavor='zsh'  ;;
				'#!'*ksh*|*'/ksh'*)   Flavor='ksh'  ;;
			esac
			;;
	esac

		awk -v shell_flavor="$Flavor" '
			function trim(s) {
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
				return s
			}

			function is_comment(line) { return line ~ /^[[:space:]]*#/ }
			function is_blank(line)   { return line ~ /^[[:space:]]*$/ }

			function strip_function_prefix(line) {
				sub(/^[[:space:]]*function[[:space:]]+/, "", line)
				return line
			}

			function handle_func_name(name) {
				# Ignore dynamic names and empties.
				if (name == "" || name == "()" || name ~ /\$/) {
					return
				}
				if (!seen[name]++) {
					print name
				}
			}

			function handle_func_list(raw_names, n, i) {
				raw_names = trim(raw_names)
				if (raw_names == "") {
					return
				}
				# zsh allows multiple names after `function`; other shells do not.
				if (shell_flavor != "zsh" && raw_names ~ /[[:space:]]/) {
					return
				}

				n = split(raw_names, parts, /[[:space:]]+/)
				for (i = 1; i <= n; i++) {
					handle_func_name(parts[i])
				}
			}

			# Main body
			{
				line = $0

				# Ignore full-line comments to avoid false positives like `#foo() {`.
				if (is_comment(line)) {
					next
				}

				if (pending_header != "") {
					# We saw a header-only line (e.g. `name()`), waiting for body opener.
					if (is_blank(line)) {
						next
					}
					if (line ~ /^[[:space:]]*[{(]/) {
						handle_func_list(pending_header)
					}
					pending_header = ""
				}

				if (line ~ /^[[:space:]]*function[[:space:]]+/) {
					rest = strip_function_prefix(line)

					# Match order (most specific first):
					# 1) function foo () { ... }
					# 2) function foo { ... }
					# 3) function foo ()          (body later)
					# 4) function foo             (zsh multi-name, body later)

					if (rest ~ /\(\)[[:space:]]*[{(]/) {
						sub(/\(\)[[:space:]]*[{(].*$/, "", rest)
						handle_func_list(rest)
						next
					}

					if (rest ~ /[[:space:]]*\{/) {
						sub(/[[:space:]]*\{.*$/, "", rest)
						handle_func_list(rest)
						next
					}

					if (rest ~ /\(\)[[:space:]]*$/) {
						sub(/\(\)[[:space:]]*$/, "", rest)
						pending_header = rest
						next
					}

					if (rest ~ /^[[:space:]]*[^[:space:]#]+([[:space:]]+[^[:space:]#]+)*[[:space:]]*$/) {
						pending_header = rest
						next
					}
				}

				# Bare forms without the `function` keyword.
				# `name () {` or `name () (`
				if (line ~ /^[[:space:]]*[^[:space:](]+[[:space:]]*\(\)[[:space:]]*[{(]/) {
					name = line
					sub(/^[[:space:]]*/, "", name)
					sub(/[[:space:]]*\(\)[[:space:]]*[{(].*$/, "", name)
					handle_func_list(name)
					next
				}

				# `name ()` (body opener may be on later line)
				if (line ~ /^[[:space:]]*[^[:space:](]+[[:space:]]*\(\)[[:space:]]*$/) {
					name = line
					sub(/^[[:space:]]*/, "", name)
					sub(/[[:space:]]*\(\)[[:space:]]*$/, "", name)
					pending_header = name
					next
				}
		}
		' "$File"
	}

# WARNING!
# `funcname` should not use any other helper functions to avoid recursion
# except where explicitly commented
function funcname {
	zsh_run setopt KSH_ARRAYS
	local quiet parent=0
	while [[ $# -gt 0 ]]; do case "$1" in
		-q | --quiet) quiet=true
			shift
			;;
		# The number of parents above this function you want to reference
		# The function you call `funcname` from is -p 0, its caller is -p 1, etc
		-p | --parent) parent="$2"
			shift
			shift
			;;
		-h | --help )
			# other utils are okay here
			# do you really expect another util to call `funcname --help`?
			echo >&2 "funcname - print the function name of the caller, or a given parent function"
			echo >&2 "Usage: funcname [options]"
			DPR_print_args -f funcname
			return 0
	esac; done

	parent="$((parent + 1))" # this function, `funcname`, counts as an additional layer

	local parentFunc="${FUNCNAME[$parent]}${funcstack[$parent]}"
	if [[ -z "$parentFunc" || "$parentFunc" = source ]] ||
		# Happens when run in shell script
		[[ "$parentFunc" = main && -z "${FUNCNAME[parent + 1]}${funcstack[parent + 1]}" ]]
	then
		[[ "$quiet" = true ]] || echo >&2 "Error: funcname: no shell function found."
		return 1
	fi
	[[ "$quiet" = true ]] || echo "$parentFunc"
	REPLY="$parentFunc"
}
ksh_run alias funcname='REPLY "${.sh.fun}"'

function alias_funcs {
	@help '
	For all defined functions matching the given regex pattern, create an alias
	replacing the pattern with the given match.
	Usage: alias_funcs FUNCTION_MATCH REPLACEMENT
	' && return

	FunctionMatch="$1"
	Replacement="$2"

	alias $(funcs | sed -E -n "s/.*/&=&/; s/$FunctionMatch/$Replacement/p")
}

# Print the contents of a given alias. Used for nested aliases.
function alias_print {
	@help '
	Print the contents of the given alias. Useful for nesting aliases.
	Usage: alias_print ALIAS_NAME
	' && return
	eval "alias=$(alias $1 | sed -E 's/^(alias )?'"$1"'=//' )"
	echo "$alias"
}

function disable_previous_aliases {
	@help "
	Temporarily unset aliases, so they don't interfere with a sourced script.
	You must run enable_previous_aliases once required work is complete.
	" && return

	PRE_UTIL_ALIASES="$(alias)"
	for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
		unalias "$alias"
	done
}

function enable_previous_aliases {
	@help "Must be run at the end of a script that disabled previous aliases" && return
	eval "$PRE_UTIL_ALIASES"
}

#
# Booleans
#

isTrue() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for bool in "$@"; do
		if [[ -z "$bool" || "$bool" = false ]]; then
			return 1
		fi

		if [[ "$bool" != true ]]; then
			warn -p 1 "isTrue argument '$bool' is not 'true', 'false' or ''!"
			echo >&2 "!!!"
			sleep 1
			return 9
		fi
	done
}

anyTrue() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for bool in "$@"; do
		[[ "$bool" = "true" ]] && return 0
	done
}

isNull() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for val in "$@"; do
		[[ "$val" = "null" ]] || return 1
	done
}

yesNoToBool() {
	lowercase "$1" >/dev/null
	case "$REPLY" in
		y | yes | true | correct) echo "true"
			;;
		n | no | false | incorrect) echo "false"
			;;
		*)
			echo "null"
			return 1
			;;
	esac
}

#
# Numbers
#

function range_intersects {
	@help "
	range_intersects: given two ranges (A and B), return true if and only if
	some integer x appears in both ranges.

	Usage: range_intersects MIN_A MAX_A MIN_B MAX_B
	" && return

	local MinA="$1" MaxA="$2" MinB="$3" MaxB="$4"
	(( ($MinB <= $MinA && $MinA <= $MaxB)
	|| ($MinB <= $MaxA && $MaxA <= $MaxB) ))
}

#
# Lists/Arrays(/Vectors, I guess)
#

function contains {
	local Match="$1"
	shift

	for Element in "$@"; do
		if [[ "$Element" = "$Match" ]]; then
			return 0
		fi
	done
	return 1
}

function contains_glob {
	local Match="$1"
	shift

	for Element in "$@"; do
		# shellcheck disable=SC2053
		if [[ "$Element" = $Match ]]; then
			return 0
		fi
	done
	return 1
}


function item {
	@func_info
	About="perform a check or operation of a single value against a given list"
	Usage=(
		"ITEM not OPERATOR ELEMENTS..."
		"ITEM in ELEMENTS..."
	)
	if [[ $# -eq 1 && "$1" =~ (-h|--help) ]]; then
		print_doc 2>&1
	fi

	if (($# < 2)); then
		print_doc
		return 1
	fi
	local item="$1" operator="$2"
	shift 2

	case "$operator" in
		not)
			item "$item" "$@"
			local exit="$?"
			case $exit in
				9) return 9;;
				0) return 1;;
				*) return 0;;
			esac
			;;
		in)
			for element in "$@"; do
				if [[ "$element" = "$item" ]]; then
					return 0
				fi
			done
			;;
		glob_in)
			for element in "$@"; do
				if [[ "$element" = $item ]]; then
					return 0
				fi
			done
			;;
		*)
			error "operator '$operator' not supported"
			echo >&2 "  Inside function '$(funcname -p 1 )'"
			return 9
	esac
	return 1 # If ya wanted tuh succeed ya shoulda done it earlia!!
}

function join_by {
	local d=${1-} f=${2-}
	(($# > 1)) || return 0
	shift 2
	printf %s "$f" "${@/#/$d}"
}


function _array_weight_compare
(( ${1%% *} < ${2%% *} ))

# function array_sort_weight {
# 	declare -a Weights REPLY_ARRAY
# 	eval 'Weights=("${'"$2"'[@]}")

# 	'"$1"'=("${REPLY_ARRAY[@]}")'
# }

function _array_compare_int
(( $1 < $2 ))
function _array_compare_string
[[ $1 < $2 ]]

# (C) CC BY-SA 4.0
# modified from https://stackoverflow.com/a/30576368
array_sort() {
	if [[ "$1" = --help ]]; then
		echo >&2  "sort positional arguments
		First argument is a function name that takes two arguments and compares them
		return value in REPLY_ARRAY
		"
		return 0
	fi

	(($# <= 1)) && return 0

	zsh_run setopt KSH_ARRAYS
	local CompareFn=$1
	shift
	case "$CompareFn" in
		string | strings )
			CompareFn=_array_compare_string;;
		int | ints | integer | integers )
			CompareFn=_array_compare_int
			for x in "$@"; do
				if [[ "$x" = *[^[:digit:]]* ]]; then
					error "Arguments include '$x' which is not an integer!"
					sleep 3
					return 9
				fi
			done
			;;
	esac

	local stack=( 0 $(($#-1)) ) start end i pivot smaller larger
	REPLY_ARRAY=("$@")
	while ((${#stack[@]})); do
		start=${stack[0]}
	end=${stack[1]}
	stack=( "${stack[@]:2}" )
	smaller=() larger=()
	pivot=${REPLY_ARRAY[start]}
	# Note: iterative, NOT recursive! :)
	for ((i=start+1;i<=end;++i)); do
		if "$CompareFn" "${REPLY_ARRAY[i]}" "$pivot"; then
			smaller+=( "${REPLY_ARRAY[i]}" )
		else
			larger+=( "${REPLY_ARRAY[i]}" )
		fi
	done
	REPLY_ARRAY=( "${REPLY_ARRAY[@]: 0: start}" "${smaller[@]}" "$pivot" "${larger[@]}" "${REPLY_ARRAY[@]: end + 1}" )
	if ((${#smaller[@]}>=2)); then stack+=( "$start" "$((start+${#smaller[@]}-1))" ); fi
	if ((${#larger[@]}>=2)); then stack+=( "$((end-${#larger[@]}+1))" "$end" ); fi
done
}

function array_map {
	@func_info
	Usage='ARRAY_NAME FILTER...'
	@opts_before_args
	Options=(
		--stdin "filter takes element via standard input instead of an argument"
	)
	opts_parse

	if ! declare -a -p "$1" >/dev/null; then
		error "'$1' is not an array"
		return 1
	fi

	zsh_run setopt KSH_ARRAYS

	local i
	# shellcheck disable=SC2086
	eval 'for (( i = 0; i < ${#'$1'[@]}; i++ )); do
		if isTrue $Stdin; then
			'$1'[$i]="$("${@:2:$# - 1}" <<<"${'$1'[$i]}")"
		else
			'$1'[$i]="$("${@:2:$# - 1}" "${'$1'[$i]}")"
		fi
	done
	'
}

function array_for {
	@func_info
	Usage='ARRAY_NAME ACTION...'
	@opts_before_args
	Options=(
		--stdin "action takes element via standard input instead of an argument"
	)
	opts_parse

	if ! declare -a -p "$1" >/dev/null; then
		error "'$1' is not an array"
		return 1
	fi

	zsh_run setopt KSH_ARRAYS

	local i
	# shellcheck disable=SC2086
	eval 'for (( i = 0; i < ${#'$1'[@]}; i++ )); do
		if isTrue $Stdin; then
			"${@:2:$# - 1}" <<<"${'$1'[$i]}"
		else
			"${@:2:$# - 1}" "${'$1'[$i]}"
		fi
	done
	'
}

function for_permutations {
	@func_info
	Usage='FUNCTION ARRAY...'
	@opts_before_args
	Options=(
		--fail-early "Fail as soon as FUNCTION returns a failure."
	)
	args_parse

	local Exit=0 Catch=true
	if isTrue $FailEarly; then
		Catch='return 1'
	fi

	_for_permutations_next 0 || return 1
	return "$Exit"
}
function _for_permutations_next {
	zsh_run setopt KSH_ARRAYS
	if (( $1 == ${#Array[@]} - 1 )); then
		"$Function" "${Array[@]}" || { $Catch; ((Exit < 127 && Exit++)); }
		return
	fi

	local i=$1 temp=''
	declare -a Copy
	Copy=("${Array[@]}")

	for (( ; i < ${#Array[@]}; i++ )) ; do
		Array=("${Copy[@]}")
		temp="${Array[i]}"
		Array[i]="${Array[$1]}"
		Array[$1]="$temp"
		_for_permutations_next $(($1 + 1)) || return 1
	done
}


#
# Misc
#

function eq {
	local i
	for ((i = 2; i <= $#; i++)); do
		[[ "$1" = "${@: i: 1}" ]] || return 1
	done
	return 0
}

# Returns the key for a given key value pair
function key {
	local delimiter='='
	if [[ "$1" = '-d' ]]; then
		delimiter="$2"
		shift
		shift
	fi

	local pair="$([[ $# -eq 0 ]] && cat || echo $1)"
	printf '%s\n' "${pair%%=*}"
}

# Returns the value for a given key value pair
function value {
	local delimiter='='
	if [[ "$1" = '-d' ]]; then
		delimiter="$2"
		(($# > 1)) && shift 2 || return 9
	fi

	local value pair
	if (($#)); then
		pair="$1"
	else
		pair="$(cat)"
	fi
	[[ "$pair" = *"$delimiter"* ]] || return 2
	[[ "$pair" =~ "$delimiter"(.*)$ ]] || return 2
	printf '%s\n' "${pair##*"$delimiter"}"
}

function ternary {
	@help 'Evaluate $1. If true, echo $2, otherwise echo $3' && return
	eval "$1" && echo "$2" || echo "$3"
}
function iif { ternary "$@"; }
if [[ -n "${ZSH_VERSION-}" ]]; then
	alias '?:=ternary'
else
	function ?: { @func_passthrough; ternary "$@"; }
fi

function ifdef {
	if [[ $# -gt 3 ]]; then
		error -p 2 "wrong argument count to ifdef (:+)"
		return 9
	fi
	[[ -n "$1" ]] && echo "$2" || echo "$3"
}
function :+ { ifdef "$@"; }

function safe_set {
	@help "
	Given a variable and a value, assign VALUE to VARIABLE_NAME, but only after checking that the following hold true:
		- the variable has previously been scoped using local, declare, typeset, etc.
		- the variable does not currently have another value
		- VARIABLE_NAME is not in the given list of reserved variabled names.

	This function is intended to help construct shell APIs where a variable is
	passed in and set by another variable. It's kind of a goofy concept, and
	it's not a secure way to ensure variable scope is enforced. I'd probably
	avoid using it and just stick to using REPLY like we do throughout this
	project.

	Usage: safe_set VARIABLE_NAME VALUE [RESERVED_VARIABLE_NAMES...]
	" && return

	# SEC: A parent function could just declare a heap of different variable
	# names to try and catch you out if you forget to declare yourself.
	if ! declare -p $1 >/dev/null; then
		error "variable '$1' must be declared beforehand"
		echo >&2 "Please call 'local $1' above this function call, and 'declare -r $1' afterwards."
		return 9

	elif deref "$1" >/dev/null && [[ -n "${REPLY}" ]]; then
		error "'$1' Must be a fresh variable, do not set it to some initial value."
		return 9

	elif contains "$1" "${@:3}"; then
		error "Variable name '$1' is reserved and cannot be used."
		return 9
	fi

	stdin "$2" read -r "$1"
}

function filter_if {
	@help "Usage: filter_if EVAL_EXPRESSION [EVAL_IF_TRUE] [EVAL_IF_FALSE]" && return
	if eval "$1"; then
		eval "${2:-cat}"
	else
		eval "${3:-cat}"
	fi
}
