# 
# utils for argument parsing
#

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

#
# arg parsing frameworks
#

# see `tools_args_example` below for how to use @func_info
alias @func_info='declare about args_req
declare -a usage options
declare -A _opts _opts_bool'

# alias needs to be first to ensure later functions can use it
# shellcheck disable=SC2142
alias args_parse='

	_args_options_gen "${options[@]}" || return $?

	local _opt_count "${_opts[@]}" "${_opts_bool[@]}"

	_args_options_parse "$@" || return $?

	# uses a custom opts flag to allow funcs to handle their own implementation if they want
	if [[ "${_opts_bool[__help]}" ]]; then
		print_doc 2>&1
		safe_quit
	fi

	shift "${_opt_count:-0}" # set by _args_options_parse

	if [[ "$args_req" ]]; then
		if ! var_is_local args_req; then
			error "INTERNAL ERR: args_req must be locally defined"
			safe_quit 9
		fi
		local $args_req
		_args_req "$@" || safe_quit $?
	fi
'

tools_args_example() {
	@func_info
	about='an example for what a documentation structure might look like'
	usage=(
		"--format-1 VAL [SEVERAL_OPTIONAL_ARGS...]"
		"--format-2 [OPTIONAL_ARGUMENT]"
		"JUST THESE ARGS"
	)
	options=(
		-1 --format-1=VAL "This flag has an argument. It will be put into a value called val"
		-2 --format-2 "This flag is a boolean flag. It usually requires no argument, but can support --format-2=true/false or --no-format-2"
	)
	args_parse
	echo "tools_args variables set:"
	local -p "${_opts[@]}" "${_opts_bool[@]}" | uniq
	print_doc
}

_args_req() {
	local arg
	for arg in $args_req; do
		if [[ -z "$1" ]]; then
			error -p 1 "arg '$arg' must be set"

			if var_is_declared usage; then
				print_usage "$usage" >&2
			else
				print_usage "$(case_big_snake $args_req)"
			fi
			return 1
		fi

		eval "$arg"'="$1"'
		shift
	done
}

# used internally by args_parse to create a map of flags to variables for later parsing
_args_options_gen() {

	local flags last name

	if ! var_is_declared _opts; then
		error "INTERNAL ERR: internal vars not found -- did you include '@func_info'?"
		safe_quit 9
	fi

	while [[ $# -gt 0 ]]; do
		flags=
		if ! [[ "$1" =~ ^- ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		while [[ "$1" =~ ^- ]]; do
			flags+=" $1"
			last="$1" # the last flag includes the '=VAR_NAME' part (or not if bool)
			shift
		done
		shift # throw away the docstring

		# check if flag has argument or is boolean
		if name="$(value "$last")"; then

			# TODO: Implement array flags. will need some opinionated designing.
			if [[ "$name" =~ '...' ]]; then
				error "'$name' elipsis format currently unsupported :("
				return 9
			fi

			name="$(case_camel "$name")"
			for flag in $flags; do
				_opts[${flag%%=*}]="$name"
			done
		else
			name="$(case_camel "${last#--}")"
			for flag in $flags; do
				_opts_bool[${flag}]="$name"
			done
		fi

	done
}

_args_options_parse() {
	local flag arg type value i=0
	(( "${#options[@]}" )) || return 0
	while [[ "$1" =~ ^- && "$1" != -- ]]; do
		type= arg= value=
		flag="${1%%=*}"

		# check defined flags
		if arg="${_opts_bool[$flag]}" && [[ -n "$arg" ]]; then
			type=bool
		elif arg="${_opts_bool[--${flag#--no-}]}" && [[ -n "$arg" ]]; then
			type=bool
			value=false
		else
			arg="${_opts[$flag]}"
			type=string
		fi

		# common defaults
		case "$flag" in
			-h | --help) _opts_bool[__help]=true
				return 0
		esac

		if [[ -z "$arg" ]]; then
			error -p 1 "Flag '$flag' not supported!"
			return 1
		fi

		value="${value:-$(value "$1")}"
		shift
		((i++))

		if [[ $type = bool ]]; then
			value="${value:-false}"
			if [[ ! "$value" =~ (true|false) ]]; then
				error -p 1 "Flag '$flag' is boolean"
				return 1
			fi
		fi

		if [[ -z "$value" ]]; then
			value="$1"
			shift
			((i++))
		fi

		eval "$arg='${value//\'/\'\\\'\'}'" # escape any single quotes within value

	done
	_opt_count=$i
}


zsh_run unsetopt GLOB

# Shorthand structure for defining arguments
ARGS='
while [[ $# -ne 0 ]]; do case "$1" in '
alias '@ARGS'="$ARGS"


ARGS_UTIL='
;;
# by specifying args before @ARGS_END, you can override the following values
	-h | --help )
		print_doc 2>&1
		return 0 2>/dev/null || exit 0
		shift;
		;;
	--*=* )
		key="$(key "$1")"
		value="$(value "$1")"
		shift;
		set -- "$key" "$value" "$@"
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
	if [[ $# -eq 0 ]]; then
		if [[ -t 0 ]]; then
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
		if [[ -z "${!var}" ]]; then
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

print_options() {
	while [[ $# -gt 0 ]]; do
		if [[ ! "$1" =~ ^- ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		while [[ "$1" =~ ^- ]]; do
			printf %s "$1"
			if [[ "$2" =~ ^- ]]; then
				printf ,
			fi
			printf ' '
			shift
		done
		printf '\n\t%s\n' "$1"
		shift
	done
}

print_doc() {
	[[ "$(@func_info
		about='print semantically-structured docs from standardised variables'
		usage=()
		args_parse
		echo end
	)" ]] || return $?

	exec >&2
	@func_use_parent

	if var_is_declared about; then
		echo
		echo "$func - $about"
		echo
	fi

	if declare -p | grep -q ' --  usage=.\+'; then
		echo "Usage:"
		for line in "${usage[@]}"; do
			if [[ "$line" =~ ^#(.*)$ ]]; then
				printf '\t%s\n' "$line"
				continue
			fi
			printf '\t%s\n' "$func ${options[1]:+[options]} $line"
		done
		echo
	elif isFunction usage; then
		usage
	else
		echo >&2 "No Usage line provided. However, here are the options:"
	fi

	if var_is_declared options; then
		print_options "${options[@]}" || return 9

	elif isFunction options; then
		options
	else
		{ funcname -q && print_args -f "$(funcname)" || print_args; } 2>&1
	fi

}

print_usage() {
	local name
	# funcname may not be defined if running this function, but that doesn't matter.
	# besides, in any user environment it will be defined.
	name="$(funcname -p 1 2>/dev/null)"
	if [[ "$name" = usage ]]; then
		name="$(funcname -p 2 2>/dev/null)"
	fi
	name="${name:-$0}"

	local usage
	usage="$(deindent "$@")"
	usage="${usage//$'\t'/    }"

	printf >&2 "%s\n" "Usage: $name $usage"
}

# 
#
print_args() {
	@func_info
	about='Output the args of a script file.

	Given file/function must have a case block that parses args
	identified with an @ARGS comment at the top
	'
	options=(
		-f --function=FUNCTION "Print args for the given function within the file"
	)

	args_parse

	exec >&2

	local file="$1"

	if [[ -z "$file" ]]; then
		if [[ "$BASH_VERSION" ]]; then
			file="${BASH_SOURCE[-1]}" # [1] is the context that called this function.
		elif [[ "$ZSH_VERSION" ]]; then
			# shellcheck disable=SC1087
			file="$(echo "$funcfiletrace[1]" | sed 's/:[0-9]*$//')"
		else
			error "shell not supported. Please run --help from in bash."
		fi
	fi

	if ! echo "$file" | grep -q '.sh$'; then
		error "file '$file' is not a shell script."
		return 1
	fi

	if echo "$file" | grep -q 'common.sh$' && [[ -z "$function" ]]; then
		error "function libs requires a -f function to be specified."
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

	echo "Options:"
	if [[ -n "$function" ]]; then
		# Note this runs on to the next function if no match found.
		# parsing the function end is tricky.
		sed -En "/$function().*\{/,$ { $printArgs }" "$file"
	else
		sed -En "$printArgs" "$file"
	fi
}
