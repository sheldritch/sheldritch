#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args

# print true iff the given function is a defined function
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
		# Under `setopt KSH_ARRAYS`, `${(k)functions}` expands oddly; force array expansion.
		print -l ${(ok)functions[@]}
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
		Path="${SHELDRITCH_SOURCES[$I]}"
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
	About='List function names that appear in FILE, or from standard input when FILE is -.'
	Usage='FILES...'
	Options=(

		-e --regexp=PATTERN     "Regex to match function names by"
		-F --fixed-strings      "Interpret PATTERN as a fixed string, not a regular expression."

		-n --line-number        "include the line number where the function is found"
		-h --no-filename        "suppress prefixing file names on each line. This is default if one file or '-' given."
		-H --with-filename      "Prefix file names on each line. This is default if multiple FILES given."

		-m --max-count=NUMBER   "Stop once NUMBER functions have been found"
	)
	zsh_run setopt KSH_ARRAYS
	args_parse

	local Error=0
	# Set vars for awk
	FixedStrings="$(bool2int "$FixedStrings")"
	LineNumber="$(bool2int "$LineNumber")"
	if isTrue "$NoFilename"; then
		WithFilename=0
	elif isTrue "$WithFilename"; then
		WithFilename=1
	else
		WithFilename=$((${#Files[@]} > 1))
	fi

	awk \
		-v regexp="$Regexp" \
		-v fixed_strings="$FixedStrings" \
		-v max_count="$MaxCount" \
		-v line_numbers="$LineNumber" \
		-v with_filename="$WithFilename" \
		'
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
			# Ignore dynamic names, non-shell signatures, and empties.
			if (name == "" || name == "()" || name ~ /[$()]/) {
				return
			}
			if (regexp) {
				if (with_filename) {
					if (name != regex) { return }
				} else {
					if (name !~ regex) { return }
				}
			}
			if (!seen[name]++) {
				print \
					(with_filename ? FILENAME":" : "") \
					(line_numbers  ? FNR":"      : "") \
					name
			}

			if (max_count && ++count >= max_count) {
				exit
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

		FNR == 1 {
			shell_flavor = ( \
				FILENAME ~ /\.bash$/ ? "bash" : \
				FILENAME ~ /\.zsh$/  ? "zsh"  : \
				FILENAME ~ /\.ksh$/  ? "ksh"  : \
				$0 ~ /^#!.*bash/ ? "bash" : \
				$0 ~ /^#!.*zsh/  ? "zsh"  : \
				line ~ /^#!.*ksh/  ? "ksh"  : \
				"sh" \
			)
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
	' "${Files[@]}"
}

# Print the name of the currently executing function.
# Use the -p N flag, where N is the Nth parent function up the call chain.
#
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

