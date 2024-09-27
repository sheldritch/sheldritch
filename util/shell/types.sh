source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/args.sh

#
# Functions
#

isFunction() {
	if [[ "$BASH_VERSION" ]]; then
		[[ "$(type -t "$1")" = function ]]
	elif [[ "$ZSH_VERSION" ]]; then
		[[ "$(whence -w)" = function ]]
	fi
}

funcs() {
	if [ "$ZSH_VERSION" ]; then
		print -l ${(ok)functions}
	else
		declare -F | awk '{print $3}'
	fi
}

# WARNING!
# `funcname` should not use any other helper functions
# except print_args
funcname() {
	local quiet parent
	@ARGS
		-q | --quiet) quiet=true
			shift
			;;
		# The number of parents above this function you want to reference
		# The function you call `funcname` from is -p 0, its caller is -p 1, etc
		-p | --parent) parent="$2"
			shift
			shift
	@ARGS_END

	# done manually since @ARGS and print_usage use funcname internally
	if [ "$HELP" = true ]; then
		echo >&2 "funcname: print the function name of the caller, or a given parent function"
		echo >&2 "Usage: funcname [options]"
		print_args -f funcname
		return 0
	fi

	parent="${parent:-0}"
	parent="$(($parent + 1))" # this function, `funcname`, counts as an additional layer

	print() {
		if [ "$quiet" != true ]; then
			echo "$@"
		fi
	}

	local parentFunc="${FUNCNAME[$parent]}${funcstack[@]:$parent:1}"
	if [ -z "$parentFunc" ] ||
		# Happens when run in shell script
		[ "$parentFunc" = main -a -z "${FUNCNAME[$(($parent + 1))]}${funcstack[@]:$(($parent + 1)):1}" ]
	then
		print >&2 "Error: funcname: no bash function found."
		return 1
	fi
	print "$parentFunc"
}

# for all defined functions, create an alias replacing the given extended regex
# with the given match
alias_funcs() {
	functionMatch="$1"
	replacement="$2"

	alias $(funcs | sed -E -n "s/.*/&=&/; s/$functionMatch/$replacement/p")
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
	if [ $# -eq 0 ]; then
		return 2
	fi
	for bool in "$@"; do
		test "$bool" = "true" && return 0
	done
}

isNull() {
	if [ $# -eq 0 ]; then
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
  local match="$1"
  shift

  for element in "$@"; do
	  if [ "$element" = "$match" ]; then
		  return 0
	  fi
  done
  return 1
}

item() {
	usage() {
		print_usage "perform a check or operation of a single value against a given list"
	}
	@ARGS_DEFAULT
	local item="$1" operator="$2"
	shift 2 || return 1

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

#
# Misc
#

# Returns the key for a given key value pair
key() {
	local delimiter='='
	if [ "$1" = '-d' ]; then
		delimiter="$2"
		shift
		shift
	fi

	local pair="$([ $# -eq 0 ] && cat || echo $1)"
	printf '%s\n' "${pair%%=*}"
}

# Returns the value for a given key value pair
value() {
	local delimiter='='
	if [ "$1" = '-d' ]; then
		delimiter="$2"
		shift
		shift
	fi

	local value pair="$([ $# -eq 0 ] && cat || echo $1)"
	[[ "$pair" =~ "$delimiter"(.*)$ ]] || return 2
	printf '%s\n' "${BASH_REMATCH[1]}"
}

ternary() {
       eval "$1" && echo "$2" || echo "$3"
}
?:() {
       ternary "$@"
}

ifdef() {
       if [[ $# -gt 3 ]]; then
               error -p 2 "wrong argument count to ifdef (:+)"
               return 9
       fi
       [[ -n "$1" ]] && echo "$2" || echo "$3"
}
:+ () { ifdef "$@"; }

