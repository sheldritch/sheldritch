#
# utils for argument parsing
#
# This includes the @func_info framework, the recommended way for structuring
# bash functions
#
# For an example of how to use it, see tools_args_example() function definition
# later in this file

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# NOTE: There's a use_tool declaration at the bottom, once all the aliases have been properly declared

#
# arg parsing frameworks
#

# aliases needs to be first to ensure later functions can use it
alias @func_info='declare about args_req
declare -a usage options
declare -A _opts _opts_bool
'

# shellcheck disable=SC2142
alias args_parse='
	declare _args_set
	if [[ $- =~ x ]]; then
		_args_set=x
		set +x
	fi
	_tools_trace "$PS4$(funcname || echo "$0") $(args_quoted "$@")"

	_args_options_gen "${options[@]}" || return $?

	declare _opt_count ${_opts[@]//[^[:alnum:]]/ } "${_opts_bool[@]}"

	_args_options_parse "$@" || return $?

	# uses a custom opts flag to allow funcs to handle their own implementation if they want
	if [[ "${_opts_bool[__help]}" ]]; then
		print_doc 2>&1
		safe_quit
	fi

	shift "${_opt_count:-0}" # set by _args_options_parse

	# TODO: allow mixing of options and required arguments by parsing these in _args_options_parse
	# Might need to consider how variadic arguments interact with this
	if [[ "$args_req" ]]; then
		if ! var_is_local args_req; then
			error "INTERNAL ERR: args_req must be locally defined"
			safe_quit 9
		fi
		declare $args_req
		for x in $args_req; do
			_args_req "$x" "$1" || safe_quit $?
			shift
		done
	fi

	set -$_args_set
'

tools_args_example() {

	# initialise the func_info framework
	@func_info

	# structured definition of function operation metadata
	about='an example function showing how to use @func_info to parse --option-flags and auto-document'
	usage=(
		# this usage array (which can also be a single string) is currently only used for documentation
		# it shows all the different allowed formats excluding optional arguments.
		# That is, the arguments of the command MUST include the arguments of one of these examples.
		"# (strings starting with '#' are comments)"
		"--print-vars [SPECIFIC_VARS_TO_PRINT...]"
		"--print-help"
		"--example=boolean FUNCTION_FLAG"
		"--example=string  FUNCTION_FLAG FUNCTION_VARIABLE"
	)

	# A list of the flags that can be passed into the command.
	options=(
		# format is FLAGS... FLAG_DESCRIPTION
		--print-vars "A boolean flag to enable the print-var feature. Boolean flags usually have no argument, but can support --<arg>=true/false or --no-<arg>"
		# any number of flags can be provided, including single-letter flags.
		# the final flag defines the boolean variable name (`printHelp` here)
		-h '-?' --HALP --print-help "@func_info automatically defines a --help flag, so you don't need to define one yourself like we do here."

		# note the declared value name EXAMPLE_TYPE. This is *always* on the last flag. This will create a variable called `exampleType`
		-x --eg --example=EXAMPLE_TYPE "Print out what the option def format would look like for the given type"

		# Any symbols within the variable name will split it into separate variables (here we get target, val1 and val2 all as separate variables)
		'--equals-or=TARGET=VAL1||VAL2' 'show that multiple vars can be auto-parsed if separated by symbols (other than - or _)'

		# PERFORMANCE: each additional option adds about 33 microseconds to command runtime
		# If you expect your function to be run hundreds of times, consider parsing args manually:
		# https://mywiki.wooledge.org/BashFAQ/035
	)
	args_parse

	if [[ "$target$val1$val2" ]]; then
		echo "equals or!! checking to see if '$target' equals either '$val1' or '$val2'..."
		case "$target" in
			"$val1" )
				echo "'$target' equals the first value, $val1!";&
			"$val2" )
				echo "'$target' equals the second value, $val2!";&
		esac
	fi

	# variables are automatically declared in args_parse
	if [[ "$printVars" = true ]]; then
		if [[ $# -gt 0 && -z "$exampleType" ]]; then
			local -p "$@"
		else
			echo "standard args:"
			local -p "${_opts[@]}" | sort --unique
			echo "boolean args:"
			local -p "${_opts_bool[@]}" | sort --unique
		fi
	fi

	# you can still set defaults like so:
	printHelp="${printHelp:-false}"

	# if the command didn't specify, flag variables are empty (''), including boolean flags
	# so be careful in your boolean checks -- if var='', then [[ "$var" = true ]] is false and [[ "$var" != false ]] is true
	if [[ "$printHelp" = true ]]; then
		print_doc
		return
	fi

	case "$exampleType" in
		'' ) return ;;

		string )
			if [[ -z "$2" ]]; then
				error "string arguments must define a variable name/argument value name. See args.sh for the example's code"
				return 1
			fi
			;;
		bool | boolean )
			if [[ -n "$2" ]]; then
				error "boolean arguments cannot set a custom variable name. See args.sh for this example's code."
				return 1
			fi
			;;

		* )
			error "flag type not supported!"
			return 1
	esac

	local flag var prefix=--
	var="$(case_big_snake "$2")"
	flag="$(case_kebab "$1")"

	if [[ "$flag" =~ ^-?.$ ]]; then
		prefix=-
	fi
	flag="${flag#$prefix}"

	echo 'options=('
	printf "\t%s%s%s 'STRING EXPLAINING THE FLAG'\n" "$prefix" "$flag" "${var:+=$var}"
	echo ')'
	echo "variable name: '$(case_camel "${var:-$flag}")'"
}

_args_req() {
	local arg="$1"
	shift
	if [[ -z "$1" ]]; then
		error -p 1 "arg '$arg' must be set"

		if var_is_declared usage; then
			print_doc
		else
			print_usage "$(case_big_snake $args_req)"
		fi
		return 1
	fi

	eval "$arg"'="$1"'
}

_args_name_to_camel() {
	local in="${1,,}"

	while [[ "$in" =~ ([_-])(.) ]]; do
		local separator="${BASH_REMATCH[1]}"
		local match="${BASH_REMATCH[2]}"

		in="${in//$separator$match/${match^}}"
	done
	name="$in"
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
		if [[ "$last" =~ = ]]; then
			name="${last#*=}"

			# TODO: Implement array flags. will need some opinionated designing.
			# probably, all bash arguments until the next /^-/ are part of the array,
			# but this is escapable with '\-'
			if [[ "$name" =~ '...' ]]; then
				error "'$name' elipsis format currently unsupported :("
				return 9
			fi

			_args_name_to_camel "$name"
			for flag in $flags; do
				_opts[${flag%%=*}]="$name"
			done
		else
			_args_name_to_camel "${last#--}"
			for flag in $flags; do
				_opts_bool[${flag}]="$name"
			done
		fi

	done
}

alias __shift='((i++)); shift'
_args_options_parse() {
	local flag arg type value i=0

	while [[ "$1" =~ ^- ]]; do
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

		if [[ -z "$arg" ]]; then

			# fall back to common defaults
			case "$flag" in
				-h | --help)
					_opts_bool[__help]=true
					break
					;;
				-- )
					__shift
					break
					;;
				*)
					# if no options spec was defined, assume flags are parsed elsewhere
					(( "${#options[@]}" )) || return 0

					error -p 1 "Flag '$flag' not supported!"
					return 1
			esac
		fi

		if [[ -z "$value" && "$1" =~ =(.+)$ ]]; then
			value="${value:-$(value "$1")}"
		fi
		__shift

		if [[ $type = bool ]]; then
			value="${value:-true}"
			if [[ ! "$value" =~ (true|false) ]]; then
				error -p 1 "Flag '$flag' is boolean"
				return 1
			fi
		fi

		if [[ -z "$value" ]]; then
			value="$1"
			__shift
		fi

		# escape any single quotes within value so we can assign with eval
		value="${value//\'/\'\\\'\'}"

		if [[ "$type" = string ]]; then
			while [[ "$arg" =~ [^[:alnum:]]+ ]]; do
				local separator="${BASH_REMATCH[0]}"

				eval "${arg%%"$separator"*}='${value%%"$separator"*}'"

				arg="${arg#*"$separator"}"
				[[ "$value" =~ "$separator" ]] || value=''
				value="${value#*"$separator"}"
			done
		fi

		eval "$arg='$value'"

	done
	_opt_count=$i
}
unalias __shift


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
esac; done
_tools_trace "+$(funcname || echo "$0") $(args_quoted "$@")"
'
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
	echo
	echo "Options:"
	while [[ $# -gt 0 ]]; do
		if [[ ! "$1" =~ ^- ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		printf '  '
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
	# run docs in subshell so we don't clobber variables
	[[ "$(@func_info
		about='print semantically-structured docs from standardised variables'
		usage=()
		args_parse
		echo end # if no echo, we know args_parse exited early.
	)" ]] || return $?

	exec >&2
	@func_use_parent
	# TODO: ensure support of standalone scripts

	__has() { var_is_declared "$1" && [[ -n "${!1}" ]]; }

	if __has about; then
		echo
		echo "$func - $about"
		echo
	fi

	if __has usage; then
		echo "Usage:"
		for line in "${usage[@]}"; do
			if [[ "$line" =~ ^#(.*)$ ]]; then
				printf '\t%s\n' "$line"
				continue
			fi
			printf '\t%s%s\n' "$func ${options[1]:+[options] }" "$line"
		done
	elif isFunction usage &&
		awk "/${func:+"$func *() *{ *"}$/,/^}/" "$(self_file)" | grep -q 'usage()'; then
		usage
	else
		echo >&2 "No Usage line provided. However, here are the options:"
	fi

	if __has options; then
		print_options "${options[@]}" || return 9

	elif isFunction options; then
		options
	else
		{ funcname -p 1 -q && print_args -f "$(funcname -p 1)" || print_args; } 2>&1
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
		sed -En "/$function().*\{/,/^\}/ { $printArgs }" "$file"
	else
		sed -En "$printArgs" "$file"
	fi
}

use_tool util/text/text.sh || return 1
