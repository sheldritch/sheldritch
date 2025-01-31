#!/bin/bash
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

#
# Functions
#

is_function() {
	declare -p ${BASH_VERSION:+-F} -f "$1" >/dev/null 2>&1
}

funcs() {
	if [[ "$ZSH_VERSION" ]]; then
		# shellcheck disable=SC2296
		print -l ${(ok)functions}
	else
		declare -F | awk '{print $3}'
	fi
}

# WARNING!
# `funcname` should not use any other helper functions to avoid recursion
# except where explicitly commented
funcname() {
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
			print_args -f funcname
			return 0
	esac; done

	parent="$((parent + 1))" # this function, `funcname`, counts as an additional layer

	local parentFunc="${FUNCNAME[$parent]}${funcstack[@]:$parent:1}"
	if [[ -z "$parentFunc" || "$parentFunc" = source ]] ||
		# Happens when run in shell script
		[[ "$parentFunc" = main && -z "${FUNCNAME[$(($parent + 1))]}${funcstack[@]:parent + 1:1}" ]]
	then
		[[ "$quiet" = true ]] || echo >&2 "Error: funcname: no shell function found."
		return 1
	fi
	[[ "$quiet" = true ]] || echo "$parentFunc"
	REPLY="$parentFunc"
}

# for all defined functions, create an alias replacing the given extended regex
# with the given match
alias_funcs() {
	functionMatch="$1"
	replacement="$2"

	alias $(funcs | sed -E -n "s/.*/&=&/; s/$functionMatch/$replacement/p")
}

# Print the contents of a given alias. Used for nested aliases.
alias_print() {
	eval "alias=$(alias $1 | sed -E 's/^(alias )?'"$1"'=//' )"
	echo "$alias"
}

# temporarily unset aliases, so they don't interfere with a helper script
disable_previous_aliases() {
	PRE_UTIL_ALIASES="$(alias)"
	for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
		unalias "$alias"
	done
}

# Must be run at the end of a script that disabled previous aliases
enable_previous_aliases() {
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
		test "$bool" = "true" && return 0
	done
}

isNull() {
	if [[ $# -eq 0 ]]; then
		return 2
	fi
	for val in "$@"; do
		test "$val" = "null" || return 1
	done
}

yesNoToBool() {
	case "${1,,}" in
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
# Lists
#

contains() {
  local Match="$1"
  shift

  for Element in "$@"; do
	  if [[ "$Element" = "$Match" ]]; then
		  return 0
	  fi
  done
  return 1
}

contains_glob() {
  local Match="$1"
  shift

  for Element in "$@"; do
	  if [[ "$Element" = $Match ]]; then
		  return 0
	  fi
  done
  return 1
}


item() {
	@func_info
	About="perform a check or operation of a single value against a given list"
	Usage=(
		"ITEM not OPERATOR ELEMENTS..."
		"ITEM in ELEMENTS..."
	)
	parse_args
	if [[ $# -eq 1 && "$1" =~ (-h|--help) ]]; then
		print_docs 2>&1
	fi

	local item="$1" operator="$2"
	if ! shift 2; then
		print_docs
		return 1
	fi

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

join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
	printf %s "$f" "${@/#/$d}"
  fi
}


for_permutations() {
  local function="$1" exit=0
  shift || return 1
  declare -a array=("$@")

  _for_permutations_next 0
  [[ "$items" == "" ]] && echo "$out" && return
  return "$exit"
}
_for_permutations_next() {
	zsh_run setopt KSH_ARRAYS
	if (( $1 == ${#array[@]} - 1 )); then
		"$function" "${array[@]}" || ((exit < 127 && exit++))
		return
	fi

	local i=$1 temp=''
	declare -a copy=("${array[@]}")

	for (( ; i < ${#array[@]}; i++ )) ; do
		array=("${copy[@]}")
		temp="${array[i]}"
		array[i]="${array[$1]}"
		array[$1]="$temp"
		_for_permutations_next $(($1 + 1))
	done
}


#
# Misc
#

# Returns the key for a given key value pair
key() {
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
value() {
	local delimiter='='
	if [[ "$1" = '-d' ]]; then
		delimiter="$2"
		shift 2 || return 9
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

ternary() {
       eval "$1" && echo "$2" || echo "$3"
}
bash_run ?:() { ternary "$@"; }
zsh_run \?:() { ternary "$@"; }

ifdef() {
	if [[ $# -gt 3 ]]; then
		error -p 2 "wrong argument count to ifdef (:+)"
		return 9
	fi
	[[ -n "$1" ]] && echo "$2" || echo "$3"
}
:+ () { ifdef "$@"; }

safe_set() {
	if ! declare -p $1 >/dev/null; then
		error "variable '$1' must be declared beforehand"
		echo >&2 "Please call 'local $1' above this function call, and 'declare -r $1' afterwards."
		return 9

	elif [[ -n "${!1}" ]]; then
		error "'$1' Must be a fresh variable, do not set it to some initial value."
		return 9

	elif [[ "$1" = "$2" ]]; then
		error variable cannot be "$2"
		return 9
	fi

	eval $1="${!2}"
}

filter_if() {
	if eval "$1"; then
		eval "${2:-cat}"
	else
		eval "${3:-cat}"
	fi
}
