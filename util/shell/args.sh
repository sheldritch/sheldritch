# 
# utils for argument parsing
#

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

#
# arg parsing frameworks
#

_args_req() {
	local arg
	for arg in $args_req; do
		if [ -z "$1" ]; then
			error -p 1 "arg '$arg' must be set"

			if var_is_local usage; then
				print_usage "$usage" >&2
			else
				print_usage "$(case_big_snake $args_req)"
			fi
			return 1
		fi

		echo >&2  "$arg"'="${!arg}"'
		eval "$arg"'="$1"'
		shift
	done
}

# shellcheck disable=SC2142
alias args_parse='
	if [ "$args_req" ]; then
		if ! var_is_local args_req; then
			error "INTERNAL ERR: args_req must be locally defined"
			safe_quit 9
		fi
		local $args_req
		_args_req "$@" || safe_quit $?
	fi
'

zsh_run unsetopt GLOB

# Shorthand structure for defining arguments
ARGS='
local HELP >/dev/null 2>/dev/null || :
while [ $# -ne 0 ]; do case "$1" in '
alias '@ARGS'="$ARGS"


ARGS_UTIL='
;;
# by specifying args before @ARGS_END, you can override the following values
	-h | --help )
		local HELP >/dev/null 2>/dev/null || :
		HELP=true # excluding help for compatibility.

		if [[ "$(! funcname -q && declare -p usage || local -p usage)" ]]; then
			print_usage "$usage"
		elif isFunction usage; then
			usage
		else
			echo >&2 "No Usage line provided. However, here are the options:"
		fi

		if isFunction options; then
			options
		else
			funcname -q && print_args -f "$(funcname)" || print_args
		fi

		return 0 2>/dev/null || exit 0;

		shift;
		;;
	--*=* )
		key="$(key "$1")"
		value="$(value "$1")"
		shift;
		set "$key" "$value" "$@"
		continue;
		;;
	-- )
		shift;
		break;
'
alias @ARGS_UTIL="$ARGS_UTIL"

ARGS_END_PASSTHROUGH="$ARGS_UTIL"'
		;;
	# preserve any unrecognised flags and arguments in the arguments list
	'*' )
		echo >&2 "Error: flag $1 not supported"
		shift
		safe_quit
		;;
	'*' )
		break
		;;
esac; done'

alias @ARGS_END_PASSTHROUGH="$ARGS_END_PASSTHROUGH"

ARGS_END="$ARGS_UTIL"'
		;;
	'-*' )
		echo >&2 "Error: flag $1 not supported"
		shift
		safe_quit
		;;
	'*' )
		break
		;;
esac; done'
alias @ARGS_END="$ARGS_END"

alias '@ENDARGS='"$ARGS_END"

args_gen() {
	echo "$ARGS"
	echo "$*"
	echo "$ARGS_END"
}

args_gen_tail() {
	echo "$*"
	echo "$ARGS_END"
}

alias "@ARGS_DEFAULT=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"
alias "@DEFAULT_ARGS=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"

zsh_run setopt GLOB

#
# Arg parsing utils
#

args_or_stdin() {
	local args
	if [ $# -eq 0 ]; then
		if [ -t 0 ]; then
			echo >&2 "Error: $(funcname -p 1) run with no args, but nothing piped in"
			return 1
		fi
		args="$(cat)"
	else
		args="$*"
	fi
	echo "$args"
}


alias check_var_set='__check_var_set() {
	for var in "$@"; do
		if [ -z "${!var}" ]; then
			echo >&2 "Error: $(funcname -p 1): option '\''$var'\'' not set"
			safe_quit 1
		fi
	done
}
__check_var_set'

#
# Arg formatting and printing
#

# Outputs an argument flag for the given variable name, if and only if that variable is set to `true`
arg_bool() {
	local __x
	for __x in "$@"; do
		# This works, despite questions you might have about variable scope
		if isTrue ${!__x}; then
			echo --"$(echo "$__x" | sed "s/[A-Z]/-\L&/g")"
		fi
	done
}

args_quoted() {
	# from https://unix.stackexchange.com/a/307017
	awk -v q="'" '
	  function shellquote(s) {
		gsub(q, q "\\" q q, s)
		return q s q
	  }
	  BEGIN {
		for (i = 1; i < ARGC; i++) {
		  printf "%s", sep shellquote(ARGV[i])
		  sep = " "
		}
		printf "\n"
	  }' "$@"
}


#
# args documentation
#

print_usage() {
	local name
	# funcname may not be defined if running this function, but that doesn't matter.
	# besides, in any user environment it will be defined.
	name="$(funcname -p 1 2>/dev/null)"
	if [[ "$name" = usage ]]; then
		name="$(funcname -p 2 2>/dev/null)"
	fi
	name="${name:-$0}"
	echo >&2 "Usage: $name" "$@"
}

# Output the args of a script file
#
# given file must have a case block that parses args
# identified with an @ARGS comment at the top
#
# WARNING: print_args must NOT use `funcname` internally.
print_args() {

	local function HELP
	@ARGS
		# Print args for the given function within the file
		-f | --function ) function="$2"
			shift
			shift
	@ARGS_END

	if isTrue $HELP; then
		echo >&2 "Usage: print_args [...args] [filename]"
		HELP=false print_args -f print_args
		debug "help is $HELP"
		return
	fi

	local file="$1"

	if [ -z "$file" ]; then
		if [ "$BASH_VERSION" ]; then
			file="${BASH_SOURCE[-1]}" # [1] is the context that called this function.
		elif [ "$ZSH_VERSION" ]; then
			file="$(echo "$funcfiletrace[1]" | sed 's/:[0-9]*$//')"
		else
			echo >&2 "Error: print_args: shell not supported. Please run --help from in bash."
		fi
	fi

	if ! echo "$file" | grep -q '.sh$'; then
		echo >&2 "Error: print_args: file '$file' is not a shell script."
		return 1
	fi

	if echo "$file" | grep -q 'common.sh$' && [ -z "$function" ]; then
		echo >&2 "Error: print_args: function libs requires a -f function to be specified."
		return 1
	fi

	local printArgs="
	/@ARGS/,$ {
		/(esac|@ARGS_END|@ENDARGS)/q;
		/@ARGS/d;

		# print each comment and case match
		/#/p;
		/-.*\)/p;
		s/;;//p
	};
	"

	{
	echo "Options:"
	if [ -n "$function" ]; then
		# Note this runs on to the next function if no match found.
		# parsing the function end is tricky.
		sed -En "/$function().*\{/,$ { $printArgs }" "$file"
	else
		sed -En "$printArgs" "$file"
	fi
	} >&2
}
