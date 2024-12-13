#!/bin/bash
#
# utils for argument parsing
#
# This includes the @func_info framework, the recommended way for structuring
# bash functions
#
# For an example of how to use it, see tools_args_example() function definition
# later in this file

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031

source "$SHELDRITCH"/sheldritch.base.sh || return 1
check_is_sourced

__main() {
	summon sheldritch/data/text || return 1
}

#
# arg parsing frameworks
#

# aliases needs to be first to ensure later functions can use it
alias @func_info='declare About='' ArgsReq=''
declare -a Usage=() Options=()
declare -A _Opts=() _OptsBool=()
'

alias @func_passthrough='declare FUNC_PASSTHROUGH=$((FUNC_PASSTHROUGH + 1))'

# shellcheck disable=SC2142
alias args_parse='
	declare _ArgsSet=''
	[[ $- = *x* ]] && _ArgsSet+=x
	[[ $- = *u* ]] && _ArgsSet+=u
	[[ -n "$_ArgsSet" ]] && set +$_ArgsSet

	_trace "$PS4$(funcname || echo "$0") $(args_quoted "$@")"

	_args_options_gen "${Options[@]}" || return $?

	declare _OptCount ${_Opts[@]//[^[:alnum:]]/ } "${_OptsBool[@]}"
	if [[ "$_ArgsSet" = *u* ]]; then
		for __Arg in _OptCount ${_Opts[@]//[^[:alnum:]]/ } "${_OptsBool[@]}"; do
			declare "$Arg"=''
		done
	fi

	_args_options_parse "$@" || return $?

	# uses a custom opts flag to allow funcs to handle their own implementation if they want
	if [[ "${_OptsBool[__help]}" ]]; then
		print_doc 2>&1
		safe_quit
	fi

	shift "${_OptCount:-0}" # set by _args_options_parse

	# TODO: allow mixing of options and required arguments by parsing these in _args_options_parse
	# Might need to consider how variadic arguments interact with this
	if [[ "$ArgsReq" ]]; then
		if ! var_is_declared ArgsReq; then
			error "INTERNAL ERR: ArgsReq must be declared"
			safe_quit 9
		fi
		declare $ArgsReq
		for x in $ArgsReq; do
			_args_req "$x" "$1" || safe_quit $?
			shift
		done
	fi

	[[ -n "$_ArgsSet" ]] && set -$_ArgsSet
'
alias parse_args=args_parse

tools_args_example() {

	# initialise the func_info framework
	@func_info

	# structured definition of function operation metadata
	About='an example function showing how to use @func_info to parse --option-flags and auto-document'
	Usage=(
		# this usage array (which can also be a single string) is currently only used for documentation
		# it shows all the different allowed formats excluding optional arguments.
		# That is, the arguments of the command MUST include the arguments of one of these examples.
		"# (strings starting with '#' are comments)"
		"--print-vars [SPECIFIC_VARS_TO_PRINT...]"
		"{ -h | --print-help }"
		"--example=boolean FUNCTION_FLAG"
		"--example=string  FUNCTION_FLAG FUNCTION_VARIABLE"
	)

	# A list of the flags that can be passed into the command.
	Options=(
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

	if [[ -n "$Target$Val1$Val2" ]]; then
		echo "equals or!! checking to see if '$Target' equals either '$Val1' or '$Val2'..."
		case "$Target" in
			"$Val1" )
				echo "'$Target' equals the first value, $Val1!";&
			"$Val2" )
				echo "'$Target' equals the second value, $Val2!";&
		esac
	fi

	# variables are automatically declared in args_parse
	if [[ "$PrintVars" = true ]]; then
		if [[ $# -gt 0 && -z "$ExampleType" ]]; then
			local -p "$@"
		else
			echo "standard args:"
			local -p "${_Opts[@]}" | sort --unique
			echo "boolean args:"
			local -p "${_OptsBool[@]}" | sort --unique
		fi
	fi

	# you can still set defaults like so:
	PrintHelp="${PrintHelp:-false}"

	# if the command didn't specify, flag variables are empty (''), including boolean flags
	# so be careful in your boolean checks -- if Var='', then [[ "$Var" = true ]] is false and [[ "$Var" != false ]] is true
	if [[ "$PrintHelp" = true ]]; then
		print_doc
		return
	fi

	case "$ExampleType" in
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

	local Flag Var Prefix=--
	Var="$(case_big_snake "$2")"
	Flag="$(case_kebab "$1")"

	if [[ "$Flag" =~ ^-?.$ ]]; then
		Prefix=-
	fi
	Flag="${Flag#$Prefix}"

	echo 'Options=('
	printf "\t%s%s%s 'STRING EXPLAINING THE FLAG'\n" "$Prefix" "$Flag" "${Var:+=$Var}"
	echo ')'
	echo "variable name: '$(case_camel "${Var:-$Flag}")'"
}

_args_req() {
	local Arg="$1"
	shift
	if [[ -z "$1" ]]; then
		error -p 1 "arg '$Arg' must be set"

		if var_is_declared Usage; then
			print_doc
		else
			print_usage "$(case_big_snake $ArgsReq)"
		fi
		return 1
	fi

	eval "$Arg"'="$1"'
}

_args_name_to_camel() {
	local -l In="$1"
	local +l In

	# PERF: I've tested this with a per-character array and a pure "${//}" approach.
	# regex works best for a dozen individual options

	while [[ "$In" =~ ([_-])(.) ]]; do
		recapture 1 >/dev/null
		local Separator="$REPLY"
		recapture 2 >/dev/null
		local Match="$REPLY"
		local -u UpperMatch="$Match"

		In="${In//$Separator$Match/$UpperMatch}"
	done
	local -u First="${In:0:1}"
	Name="$First${In:1}"
}

f() {
@func_info
Options=(-a=AN_VALUE "this is a value!")
args_parse
local -p
}

# used internally by args_parse to create a map of flags to variables for later parsing
_args_options_gen() {

	local Flags Last Name

	if ! var_is_declared _Opts; then
		error "INTERNAL ERR: internal vars not found -- did you include '@func_info'?"
		safe_quit 9
	fi

	funcname -q -p 1
	local Cache="_Opts_$REPLY"

	if [[ -v "$Cache" ]]; then
		# TODO: Consider making a function instead of a variable, need to explore pros vs cons
		zsh_run  eval "${(P)Cache}"
		bash_run eval "${!Cache}"
		ksh_run  eval "eval \"\$$Cache\""
		return
	fi

	while [[ $# -gt 0 ]]; do
		Flags=
		if ! [[ "$1" = -* ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		while [[ "$1" = -* ]]; do
			Flags+=" $1"
			Last="$1" # the last flag includes the '=VAR_NAME' part (or not if bool)
			shift
		done
		shift # throw away the docstring

		# check if flag has argument or is boolean
		if [[ "$Last" = *=* ]]; then
			Name="${Last#*=}"

			# TODO: Implement array flags. will need some opinionated designing.
			# probably, all bash arguments until the next /^-/ are part of the array,
			# but this is escapable with '\-'
			if [[ "$Name" = *... ]]; then
				error -p 1 "'$Name' elipsis format currently unsupported :("
				return 9
			fi

			_args_name_to_camel "$Name"
			for Flag in $Flags; do
				_Opts[${Flag%%=*}]="$Name"
			done
		else
			_args_name_to_camel "${Last#--}"
			for Flag in $Flags; do
				_OptsBool[${Flag}]="$Name"
			done
		fi

	done
	local Opts="$(declare -p _Opts _OptsBool)"
	declare -g $Cache="${Opts//declare -A/}"
}

alias __shift='((i++)); shift'
_args_options_parse() {
	local Flag='' Arg='' Type='' Value='' i=0

	while [[ "$1" =~ ^- ]]; do
		Type= Arg= Value=
		Flag="${1%%=*}"

		# check defined flags
		if Arg="${_OptsBool[$Flag]}" && [[ -n "$Arg" ]]; then
			Type=bool
		elif Arg="${_OptsBool[--${Flag#--no-}]}" && [[ -n "$Arg" ]]; then
			Type=bool
			Value=false
		else
			Arg="${_Opts[$Flag]}"
			Type=string
		fi

		if [[ -z "$Arg" ]]; then

			# fall back to common defaults
			case "$Flag" in
				-h | --help)
					_OptsBool[__help]=true
					break
					;;
				-- )
					__shift
					break
					;;
				*)
					# if no options spec was defined, assume flags are parsed elsewhere
					(( "${#Options[@]}" )) || return 0

					error -p 1 "Flag '$Flag' not supported!"
					return 1
			esac
		fi

		if [[ -z "$Value" && "$1" =~ =(.+)$ ]]; then
			Value="${Value:-$(value "$1")}"
		fi
		__shift

		if [[ $Type = bool ]]; then
			Value="${Value:-true}"
			if [[ ! "$Value" =~ (true|false) ]]; then
				error -p 1 "Flag '$Flag' is boolean"
				return 1
			fi
		fi

		if [[ -z "$Value" ]]; then
			Value="$1"
			__shift
		fi

		# escape any single quotes within value so we can assign with eval
		Value="${Value//\'/\'\\\'\'}"

		if [[ "$Type" = string ]]; then
			while rematch "$Arg" '[^[:alnum:]]+' >/dev/null; do
				local Separator="$REPLY"

				eval "${Arg%%"$Separator"*}='${Value%%"$Separator"*}'"

				Arg="${Arg#*"$Separator"}"
				[[ "$Value" =~ "$Separator" ]] || Value=''
				Value="${Value#*"$Separator"}"
			done
		fi

		eval "$Arg='$Value'"

	done
	_OptCount=$i
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
_trace "+$(funcname || echo "$0") $(args_quoted "$@")"
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
	local Args
	if [[ $# -eq 0 ]]; then
		if [[ -t 0 ]]; then
			echo >&2 "Error: $(funcname -p 1) run with no args, but nothing piped in"
			return 1
		fi
		Args="$(cat)"
	else
		Args="$*"
	fi
	echo "$Args"
	REPLY="$Args"
}


alias check_var_set='__check_var_set() {
	for Var in "$@"; do
		if [[ -z "$(deref "$Var")" ]]; then
			echo >&2 "Error: $(funcname -p 1): option '\''$Var'\'' not set"
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
		if isTrue $(deref $__x); then
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
		About='print semantically-structured docs from standardised variables'
		Usage=()
		args_parse
		echo end # if no echo, we know args_parse exited early.
	)" ]] || return $?

	exec >&2
	@func_use_parent
	# TODO: ensure support of standalone scripts

	__has() { var_is_declared "$1" && [[ -n "$(deref "$1")" ]]; }

	if __has About; then
		echo
		echo "$Parent - $About"
		echo
	fi

	if __has Usage; then
		echo "Usage:"
		for Line in "${Usage[@]}"; do
			if [[ "$Line" =~ ^#(.*)$ ]]; then
				printf '\t%s\n' "$Line"
				continue
			fi
			printf '\t%s%s\n' "$Parent ${Options[1]:+[options] }" "$Line"
		done
	elif isFunction usage &&
		awk "/${Parent:+"$Parent *() *{ *"}$/,/^}/" "$(self_file)" | grep -q 'usage()'; then
		usage
	else
		echo >&2 "No Usage line provided. However, here are the options:"
	fi

	if __has Options; then
		print_options "${Options[@]}" || return 9

	elif isFunction options; then
		options
	else
		{ funcname -p 1 -q && print_args -f "$(funcname -p 1)" || print_args; } 2>&1
	fi

}

print_usage() {
	local Name
	# funcname may not be defined if running this function, but that doesn't matter.
	# besides, in any user environment it will be defined.
	Name="$(funcname -p 1 2>/dev/null)"
	if [[ "$Name" = usage ]]; then
		Name="$(funcname -p 2 2>/dev/null)"
	fi
	Name="${Name:-$0}"

	local Usage
	Usage="$(deindent "$@")"
	Usage="${Usage//$'\t'/    }"

	printf >&2 "%s\n" "Usage: $Name $Usage"
}

print_args() {
	@func_info
	About='Output the args of a script file.

	Given file/function must have a case block that parses args
	identified with an @ARGS comment at the top
	'
	Options=(
		-f --function=FUNCTION "Print args for the given function within the file"
	)

	args_parse

	exec >&2

	local File="$1"

	if [[ -z "$File" ]]; then
		if [[ "$BASH_VERSION" ]]; then
			File="${BASH_SOURCE[1]}" # [1] is the context that called this function.
		elif [[ "$ZSH_VERSION" ]]; then
			# shellcheck disable=SC1087
			File="$(echo "$funcfiletrace[1]" | sed 's/:[0-9]*$//')"
		else
			error "shell not supported. Please run --help from in bash."
		fi
	fi

	if ! echo "$File" | grep -q '.sh$'; then
		error "file '$File' is not a shell script."
		return 1
	fi

	if echo "$File" | grep -q 'common.sh$' && [[ -z "$Function" ]]; then
		error "function libs requires a -f function to be specified."
		return 1
	fi

	local PrintArgs="
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
	if [[ -n "$Function" ]]; then
		# Note this runs on to the next function if no match found.
		# parsing the function end is tricky.
		sed -En "/$Function().*\{/,/^\}/ { $PrintArgs }" "$File"
	else
		sed -En "$PrintArgs" "$File"
	fi
}

__main "$@"
