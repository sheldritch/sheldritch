#!/bin/bash
#
# utils for argument parsing
#
# This includes the @func_info framework, the recommended way for structuring
# bash functions
#
# For an example of how to use it, see sheldritch_args_example() function definition
# later in this file

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031,SC2206

source "$SHELDRITCH"/sheldritch.base.sh || return 1
check_is_sourced

__main() {
	summon sheldritch/data/text || return 1
}

#
# arg parsing frameworks
#

# aliases needs to be first to ensure later functions can use it
alias @func_info='declare About="" ArgsReq="" _ARGS_PARSE_USAGE=""
declare -a Usage=() Options=() Settings=()
'

alias @func_passthrough='declare FUNC_PASSTHROUGH=$((FUNC_PASSTHROUGH + 1))'

unalias @set
@set() { declare -p "$1" >/dev/null && eval "$1"='"${2:-1}"'; }
alias @set='declare $_SET && @set $_SET'
alias @options_first='declare _SET=_OPTIONS_PARSE_FIRST && @set'
alias @opts_first=@options_first
alias @args_no_cache='declare _SET=_ARGS_NO_CACHE && @set'

# shellcheck disable=SC2142
alias opts_parse='
	declare _ArgsSet= __Source="${FUNCNAME:-${funcstack:-${0##/[^[:alnum:]]/_}}}"
	declare -a _ARGS=() _ARGS_FORMATS=() _ARGS_FORMAT_INFO=() _ARGS_VARS=() _ARGS_ARRAYS=()
	declare -A _Opts=() _OptsBool=()

	[[ $- = *x* ]] && _ArgsSet+=x
	[[ $- = *u* ]] && _ArgsSet+=u
	#[[ -n "$_ArgsSet" ]] && set +$_ArgsSet

	_trace "$PS4$(funcname || echo "$0") $(args_quoted "$@")"

	_args_build_parser
	_ARGS_${__Source}_VARS

	declare _ARGS_COUNT=0 _ARGS_RETURN "${_ARGS_VARS[@]}" "${_ARGS_OPTS[@]}" "${_ARGS_OPTS_BOOL[@]}"
	if (( ${#_ARGS_ARRAYS[@]} )); then
		declare -a "${_ARGS_ARRAYS[@]}"
	fi

	_ARGS_${__Source} "$@" || safe_quit
	if [[ -n "$_ARGS_RETURN" ]]; then safe_quit; fi

	# set by _ARGS_* funcs to show how many args to skip
	shift "${_ARGS_COUNT:-0}"

    #if [[ -n "$ArgsReq" ]]; then
	#	if ! var_is_declared ArgsReq; then
	#		error "INTERNAL ERR: ArgsReq must be declared"
	#		ecode 9
	#		safe_quit
	#	fi
	#	declare $ArgsReq
	#	for x in $ArgsReq; do
	#		_args_req "$x" "$1" || safe_quit
	#		shift
	#	done
	#fi

	[[ -n "$_ArgsSet" ]] && set -$_ArgsSet
'

alias parse_args=args_parse

alias args_parse='
declare _ARGS_PARSE_USAGE=1
opts_parse
'

alias parse_opts=opts_parse

# TODO: update to match current formatting
sheldritch_args_example() {

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
		-h '-?' --HALP --print-help "@func_info automatically defines a --help flag, so you don't need to define one yourself like we do here (but can if you want)."

		# note the declared value name EXAMPLE_TYPE. This is *always* on the last flag. This will create a variable called `exampleType`
		-x --eg --example=EXAMPLE_TYPE "Print out what the option def format would look like for the given type"

		# Any symbols within the variable name will split it into separate variables (here we get EqualsOrTarget, EqualsOrVal1 and EqualsOrVal2 all as separate variables)
		'--equals-or=TARGET=VAL1||VAL2' 'show that multiple vars can be auto-parsed if separated by symbols (other than - or _)'

		# PERFORMANCE: @func_info has about 0.3 milliseconds initial overhead, plus 25 microseconds
		# per flag.
		# In comparison, manual parsing has about .04 milliseconds initial overhead, plus 13
		# microseconds per flag.
		#
		# If you expect your function to be run hundreds of times in a row, consider parsing args manually:
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

_args_name_to_variable() {
	local -l In="$1"
	zsh_run In="${In:l}"
	local +l In

	# PERF: I've tested this with a per-character array and a pure "${//}" approach.
	# regex works best for a dozen individual options

	while [[ "$In" =~ ([^[:alnum:]])([[:lower:]]) ]]; do
		recapture 1 >/dev/null
		local Separator="$REPLY"
		recapture 2 >/dev/null
		local Match="$REPLY"
		local -u UpperMatch="$Match"

		if [[ "$Separator" = [_-] ]]; then
			In="${In//$Separator$Match/$UpperMatch}"
		else
			In="${In//$Match/$UpperMatch}"
		fi
	done
	local -u First="${In:0:1}"
	Name="$First${In:1}"
}

_args_build_parser() {
	local Cache="_ARGS_$__Source"

	if [[ -z "${_ARGS_NO_CACHE:-}" ]] &&
		declare -p ${BASH_VERSION:+-F} -f "$Cache" >/dev/null 2>/dev/null
	then
		# TODO: clear this cache when a function is redefined (or at least re-summoned)
		# There must be somewhere we can pull a map of function to filenames we can use
		# to invalidate cache
		# Or, we maybe can detect if a file is `source`d outside of source_once (and also invalidate
		# cache when source_once --force used)
		return 0
	fi

	local Builder=''
	_args_build_parser_opts || return 9

	if [[ -n "${_ARGS_PARSE_USAGE:-}" ]]; then
		_args_usage_build_vars || return 9
		_args_build_parser_usage || return 9
	fi

	if ! eval "$Cache() { $Builder"$'\n }'; then
		error "Eval failed! See computed builder below:
		$Builder
		"
		return 9
	fi

	_args_build_varcache
}

_args_build_varcache() {
	local Builder=''

	Builder+='
		_ARGS_VARS=('
	for x in "${_ARGS_VARS[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	Builder+='
		_ARGS_ARRAYS=('
	for x in "${_ARGS_OPTS_BOOL[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	Builder+='
		_ARGS_OPTS=('
	for x in "${_ARGS_OPTS[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	Builder+='
		_ARGS_OPTS_BOOL=('
	for x in "${_ARGS_OPTS_BOOL[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'


	Builder+='
		_ARGS_FORMATS=('
	for x in "${_ARGS_FORMATS[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	Builder+='
		_ARGS_FORMAT_INFO=('
	for x in "${_ARGS_FORMAT_INFO[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	eval "_ARGS_${__Source}_VARS() { $Builder; }"
}

_args_build_parser_opts() {
	local Func="${1:-_Opts_$__Source}" Shift='((_ARGS_COUNT++)); shift'
	if ! var_is_declared _Opts; then
		error "INTERNAL ERR: internal vars not found -- did you include '@func_info'?"
		ecode 9
		safe_quit
	fi

	Builder+='
	declare __Flag __Val
	while (($#)); do

	if [[ "$1" != -* ]]; then
		[[ "${_OPTIONS_PARSE_FIRST:-}" = 1 ]] && break
		_ARGS+=("$1")
		'"$Shift"'
		continue
	fi

	__Flag="$1"
	if [[ "$__Flag" = --no-* ]]; then
		__Flag="--${__Flag#--no-}=false"
	fi
	if [[ "$__Flag" = *=* ]]; then
		__Val="${__Flag#*=}"
		__Flag="${__Flag%%=*}"
	fi
	'

	Builder+=$'case "$__Flag" in\n'

	local Type Name
	set -- "${Options[@]}"
	while (($#)); do
		if ! [[ "$1" = -* ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		while [[ "$2" = -* ]]; do
			Builder+=" $1 |"
			shift
		done

		if [[ "$1" = *=* ]]; then
			Type=string
			# TODO: Implement array flags. will need some opinionated designing.
			# probably, all bash arguments until the next /^-/ are part of the array,
			# but this is escapable with '\-'
			if [[ "$1" = *... ]]; then
				error -p 1 "'$1' elipsis format currently unsupported :("
				return 9
			fi

			Name="${1%%=*}"

		else
			Type=bool
			Name="$1"
		fi
		_args_name_to_variable "${Name#-}" # function handles possible leading '-'

		# TODO: unless an array, symbol separators should have separate variables
		_ARGS_VARS+=(${Name//[^[:alnum:]]/}'=')

		# if [[ "$Type" = string && "$Name" = *[^[:alnum:]_]* ]]; then
		# 	while rematch "$Name" '[^[:alnum:]_]+' >/dev/null; do
		# 		local Separator="$REPLY"

		# 		Builder+="${Name%%"$Separator"*}='${Value%%"$Separator"*}'"$'\n'

		# 		Name="${Name#*"$Separator"}"
		# 		[[ "$Value" = *"$Separator"* ]] || Value=''
		# 		Value="${Value#*"$Separator"}"
		# 	done
		# fi
		# eval "$Name='$Value'"

		Builder+=" ${1%%=*} )"$'\n'

		case "$Type" in
			bool)
				Builder+='
				'$Name'="${__Val-true}"
				unset __Val

				if ! [[ "$'$Name'" = true || "$'$Name'" == false ]]; then
					error -p 1 "Flag '\''$__Flag'\'' is boolean"
					return 1
				fi'
				;;
			string) Builder+='
				if [[ -n "${__Val+x}" ]]; then
					'$Name'="$__Val";
					unset __Val
					'"$Shift"'; continue;
				fi
				'$Name'="$2"
				'"$Shift"
				;;
		esac
		Builder+="
			$Shift;;
		"

		shift; shift # throw away the docstring
	done


	Builder+='
	-h | --help )
		print_doc 2>&1
		return 0
		;;
	-- )
		declare _ARGS_BREAK=1
		'"$Shift"'
		break
		;;
	* )
		# if no options spec was defined, assume flags are parsed elsewhere
		(( "${#Options[@]}" )) || return 0

		error -p 1 "Flag \"$1\" not supported!"
		return 1
		;;

	esac
	done

	set -- "${_ARGS[@]}" "$@"
	'
}

_args_build_assoc_array() {
	local Opts="$(declare -p "$@")"
	Opts="${Opts//declare -A/}"
	Opts="${Opts//typeset -g -A/}"
	Builder+="$Opts"
}

_args_thinking_usage_priority() {
	# LEGEND (extended regex)
	# R[0-9]+ -- run of required singular arguments (number is count)
	# O[0-9]+ -- run of optional singular arguments (number is max count)
	# R\+     -- run of the above including at most one variadic argument (unknown count)
	# O\+     -- run of only optional arguments at most one variadic argument (unknown count)
	# [a-z]+  -- literal argument (argument value matching its name)

	##### Thinking priority #####

	# could store 'counts' for any given format
	# TODO: will have to consider all the many features as I go
	local FORMAT="--literal-flag R4 R:R3 R=R+ R+ literal R+"


	# an exact number of matches will be selected over an array
	local FORMAT="R4"
	local FORMAT="R+"

	# But if both are variable, they will be incompatible
	local FORMAT="R3 R+"
	local FORMAT="R+"

	# Literals take precedence
	local FORMAT="R3 literal R1"
	local FORMAT="R5"

	# Literals also distinguish variadics (allowed together)
	local FORMAT="R+ literal R+"
	local FORMAT="R+"

	# Should these two values be equivalent?
	# My current thinking is whatever literal is found first is used
	local FORMAT="R+ literal R+"
	local FORMAT="R+ other_literal R+"
	# Could have a list of first possible literals

}

_args_usage_priority() {
	# TODO: rework priority once special (literals and symbol-separated) arguments are managed with
	# _ARGS_SPECIAL.
	# We might end up relying on arity once special args are considered.
	case "${1:-$Line}" in
		# NOTE: the order of each case influences the priority here
		*[[:lower:]]* ) Priority=5;;
		*...* ) Priority=1;;
		*\[* )  Priority=2;;

		# NOTE: this check for interspersed symbols is negative, so needs to go
		# after checks for other symbols
		*[^[:upper:]_[:space:]]* ) Priority=4;;
		* )  Priority=3;;
	esac
}

_args_usage_build_vars() {
	[[ ${#Usage[@]} -lt 2 && -z "$Usage" ]] && return 0

	# TODO: calculate performance of word split vs manually using ${~~var}
	zsh_run setopt SH_WORD_SPLIT

	# calculate a format summary of each usage. This is used to distinguish one usage line from
	# another in parsing
	local Name Line AlsoLine='' Token
	for Line in "${Usage[@]}"; do

		if [[ "$Line" = \#* ]]; then
			_ARGS_FORMATS+=('#')
			_ARGS_FORMAT_INFO+=('#')
			continue
		fi
		# a Run is the current string of variable arguments. Hitting a literal argument starts a new run
		# certain sequential arguments are not allowed in a given run.
		local Format='' RunType='' RunCount=''
		# Format info values, used to identify which Usage string should be used to parse args
		local ArityMin=0 ArityMax=0 Priority=0 SubPriority=0 FirstLiteral='' LiteralArity=''
		# TODO: priority should consider the gap between min and max arity

		# duplicating variable with AlsoLine to work around zsh automatic quoting
		[[ -z "$ZSH_VERSION" ]] && AlsoLine="$Line"
		for Token in ${ZSH_VERSION:+${~~Line}} $AlsoLine; do

			case "$Token" in
				'{' | \"* | \'* )
					# TODO: I guess I could do a new RunType for grouped variables like this?
					error -p 1 "FUNCTION BUG: Token '$Token' in usage not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
					return 9
					;;

				*[[:lower:]]* )
					error -p 1 "FUNCTION BUG: literals not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
					if [[ -z "$FirstLiteral" ]]; then
						FirstLiteral="$Token"
						LiteralArity="$((ArityMin + RunCount))"
					fi
					return 9
					;;

				*... )

					# Note: Variadic arguments with separated names will join:
					# e.g. FirstNameSecondName
					_args_name_to_variable "$Token"
					_ARGS_ARRAYS+=(${Name//[^[:alnum:]]/})

					if [[ "$RunCount" = + ]]; then
						error -p 1 'FUNCTION BUG: cannot have two variadics without a literal argument or argument separator between the two.'
						return 9
					fi

					RunCount=+
					;;

				# Optional Args

				\[*...\]  )
					if [[ "$RunCount" = + ]]; then
						error -p 1 'FUNCTION BUG: cannot have two variadics without a literal argument or argument separator between the two.'
						return 9
					fi
					RunCount=+
					;;
				\[*\]  )
					Token="${Token//[][]/}"
					_args_usage_parse_token O || return $?
					;;
				\[*[^]] )
					error -p 1 "FUNCTION BUG: Runs of optional arguments not currently supported. Please split into two usage lines"
					return 9
					;;


				*[^[:upper:]_]* )
					local Temp="$Token"
					# TODO: unless an array, symbol separators should have separate variables
					while false && [[ "$Temp" = *[:upper:]_* ]]; do
						# TODO: FIXME
						Temp="${Temp%%[[:upper:]]*}${Temp#*[[:upper:]]}"
					done
					_args_usage_parse_token "$Temp" || return $?
					error -p 1 "FUNCTION BUG: Internal separators ($Token) not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
					return 9
					;;

				* ) _args_usage_parse_token R || return $?
			esac
		done
		_args_usage_parse_token END || return $?

		if [[ "$ArityMax" != + ]]; then
			((ArityMax += ArityMin))
		fi
		_args_usage_priority

		_ARGS_FORMAT_INFO+=("$ArityMin $ArityMax $Priority $SubPriority $FirstLiteral $LiteralArity")
		_ARGS_FORMATS+=("${Format# }")
	done

	# Compare the computed formats to check that no usage line conflicts with another
	local i j
	for ((i=0; i < ${#_ARGS_FORMATS[@]}; i++)); do
		[[ "${_ARGS_FORMATS[@]:$i:1}" = \#* ]] && continue
		read ArityMinI ArityMaxI InfoI <<<"${_ARGS_FORMAT_INFO[@]:$i:1}"
		for ((j=i + 1; j < ${#_ARGS_FORMATS[@]}; j++)); do
			read ArityMinJ ArityMaxJ InfoJ <<<"${_ARGS_FORMAT_INFO[@]:$j:1}"
			if [[
				# TODO: literals and symbol arguments will need more complex logic here
				( $InfoI = $InfoJ && (
					   ($ArityMinI -ge $ArityMinJ && $ArityMinI -le $ArityMaxJ)
					|| ($ArityMaxI -ge $ArityMinJ && $ArityMaxI -le $ArityMaxJ)
				))
				|| ("${_ARGS_FORMATS[@]:$i:1}" = "${_ARGS_FORMATS[@]:$j:1}")
			]]; then
				error -p 1 "$(deindent "FUNCTION BUG: The following usage lines are ambiguous!
				${Usage[@]:$i:1}
				${Usage[@]:$j:1}
				Either distinguish them with flags or other literals, or use 'opts_parse' and manually parse positional args yourself.")"
				return 9
			fi
		done
	done
}

_args_usage_parse_token() {
	_args_name_to_variable "$Token"
	# Note: arguments with separated names will join:
	# e.g. FirstNameSecondName
	_ARGS_VARS+=(${Name//[^[:alnum:]]/}'=')

	if [[ "RunCount" = + ]]; then
		error -p 2 "FUNCTION BUG: args after variadic arg ($Token) not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
		return 9
		# Once implemented, we'd just keep our variadic arity marker here,
		# hence return
		return
	fi

	if [[ "$RunType" = "$1" ]]; then
		((RunCount++))
	else

		if [[ "$RunCount" = + ]] || ((RunCount)); then
			Format+=" ${RunType}$RunCount"

			if [[ "$RunCount" = + ]]; then
				ArityMax=+
			elif [[ "$RunType" = *R* ]]; then
				(( ArityMin += RunCount ))
			else
				(( ArityMax += RunCount ))
			fi
		fi
		RunType="$1"
		RunCount=1
	fi
}

_args_special_example() {
declare -a Usage=(
	'A B lita'
	'C litb'
)
declare -A _ARGS_SPECIAL=(
	[ArityMin0]=3
	[ArityMax0]=3
	[Arg0]=lita
	[ArityMin0]=3
	[ArityMax0]=3
	[Arg0]=lita
)


}

# We need to unpack all possible forms of arguments that have optional portions
# This function is an example of how we might do so.
_args_enumerate_internal_optionals() {
	local Token="${1:-LEFT[+PLUS]=RIGHT[-MINUS[*TIMES]]}" Match

	if [[ -z "$1" ]]; then
		Token="${Token/\*/\\*}"
		declare -a OptionalForms OptionalPatterns
	fi

	local Pre='' Optional='' Post="$Token"
	Token=''
	while ((${#Post})); do

		local i Depth=0 Start=0
		for ((i = 0; i < ${#Post}; i++)); do
			case "${Post:i:1}" in
				'[' )
					if ((++Depth == 1)); then
						Start=$((i + 1))
						Token+="${Post:0:i}"
					fi
					;;
				']' )
					if ((--Depth == 0)); then
						break
					fi
					;;
			esac

		done
		if ((i == ${#Post})) then break; fi

		Pre="${Pre}${Post:0:Start - 1}"
		Optional="${Post:Start:i - Start}"
		Post="${Post:i + 1:${#Post} - i}"
		_args_enumerate_internal_optionals "${Pre}${Optional}${Post}"

	done

	Token+="$Post"
	#if ! contains "$Token" "${OptionalForms[@]}"; then
		OptionalForms+=("$Token")
		replace "$Token" '[[:upper:]_]+' '*' >/dev/null
		OptionalPatterns+=("$REPLY")
	#fi

	if [[ -z "$1" ]]; then
		echo "Optional Forms ${OptionalForms[@]}"
		echo "Optional Patterns ${OptionalPatterns[@]}"
	fi
}

_args_build_parser_usage() {
	((${#Usage[@]})) || return 0
	Builder+='
	local _ARGS_FORMAT=""
	_args_usage_select_format "$@"

	# ${@:slice} starts at 1
	local __Arg=1
	case "$_ARGS_FORMAT" in
	'
	for ((i=0; i < ${#_ARGS_FORMATS[@]}; i++)); do
		Builder+="$i) "

		if [[ "${_ARGS_FORMATS[@]:$i:1}" = \#* ]]; then
			Builder+="error -p 1 'INTERNAL ERROR: chosen usage line $i is a comment!'; return 9 ;;"
		fi

		local __Arg=1 Name
		for Token in ${Usage[@]:$i:1}; do
			_args_name_to_variable "$Token"
			Name="${Name//[^[:alnum:]]/}"
			case "$Token" in
				*...)
					# TODO: If token is ARG..., check the next value to see what you might need to stop at
					Builder+="$Name"$'=("${@:$__Arg:$# - $__Arg + 1}")\n((__Arg = $# + 1))\n'
					;;
				* )
					Builder+="
					$Name"'="${@:$__Arg:1}"
					((__Arg++))'"
					[[ -n \${_ARGS_BREAK:-} && \$$Name = -* ]] && _args_dash_error $Name \$$Name && return 1"$'\n'
					;;
			esac
		done

		Builder+=$';;\n'
	done

	Builder+="esac; ((_ARGS_COUNT = __Arg - 1))"
}

_args_dash_error() {
	error -p 1 "Argument $1 starts with '-' ($2). Positional arguments may not do so without the '--' arg beforehand"
}

_args_usage_select_format() {
	local i OldPriority=0
	local ArityMin='' ArityMax='' Priority='' SubPriority='' FirstLiteral='' LiteralArity=''

	for ((i=0; i < ${#_ARGS_FORMATS[@]}; i++)); do

		read ArityMin ArityMax Priority SubPriority FirstLiteral LiteralArity <<<"${_ARGS_FORMAT_INFO[@]:$i:1}"
		if [[ "$-" = *x* ]]; then echo >&2 "${_ARGS_FORMAT_INFO[@]:$i:1}"; fi
		[[ "$ArityMin" = \#* ]] && continue

		if ((OldPriority > Priority)); then continue; fi

		if [[
			( "$ArityMax" = + )
				|| ("$#" = "$ArityMin" && "$ArityMin" = "$ArityMax")
				|| ( "$ArityMax" != + && "$ArityMin" -le "$#" && "$#" -le "$ArityMax" )
		]]; then
			_ARGS_FORMAT=$i
			OldPriority=$Priority
		fi
	done

	if [[ -z "$_ARGS_FORMAT" ]]; then
		error -p 2 "Arguments did not match any usage strings. $(args_quoted "$@")"
		print_doc -p 2
		return 1
	fi
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
			ecode 1
			safe_quit
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
	if [[ -v BASH_VERSION ]]; then
		REPLY="${@@Q}"
		echo "$REPLY"
	elif [[ -v ZSH_VERSION ]]; then
		REPLY="${@:q}"
		echo "$REPLY"

	else
		# from https://unix.stackexchange.com/a/307017
		REPLY="$(awk -v q="'" '
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
		}' "$@")"
		echo "$REPLY"
	fi
}


#
# args documentation
#

print_options() {
	echo
	echo "Options:"
	while [[ $# -gt 0 ]]; do
		if [[ ! "$1" = -* ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "$@")"
			return 9
		fi

		printf '  '
		while [[ "$1" = -* ]]; do
			printf %s "$1"
			if [[ "$2" = -* ]]; then
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
			if [[ "$Line" = \#* ]]; then
				printf '\t%s\n' "$Line"
				continue
			fi
			printf '\t%s%s\n' "$Parent ${Options[1]:+[options] }" "$Line"
		done
	elif is_function usage &&
		awk "/${Parent:+"$Parent *() *{ *"}$/,/^}/" "$(self_file)" | grep -q 'usage()'; then
		usage
	else
		echo >&2 "No Usage line provided. However, here are the options:"
	fi

	if __has Options; then
		print_options "${Options[@]}" || return 9

	elif is_function options; then
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
