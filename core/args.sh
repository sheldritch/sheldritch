#!/bin/bash
#
# utils for argument parsing
#
# This includes the @func_info framework, the recommended way for structuring
# bash functions
#

# shellcheck disable=SC2154,SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031,SC2206
#
# https://github.com/vlisivka/bash-modules/blob/master/bash-modules/examples/showcase-arguments.sh#L16
# Is a pretty cool alternative to this. I'll be stealing some of that functionality here (like extra
# validation info in the doc string)

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH"/sheldritch.base.sh || return 1
check_is_sourced

function __main {
	summon sheldritch/data/text || return 1
}

#
# arg parsing frameworks
#

# NOTE: This file make heavy use of dynamically-scoped variables, to prevent the need of copying
# arguments between functions.

# aliases needs to be first to ensure later functions can use it
alias @func_info='declare About="" ArgsReq="" _ARGS_PARSE_USAGE=""
declare -a Usage=() Options=() Legend=()
'

alias @func_passthrough='declare FUNC_PASSTHROUGH=$((FUNC_PASSTHROUGH + 1))'

function _args_set {
	read "$1" <<<"${2:-true}"
	#eval "$1"='"${2:-true}"'
}
function args_edict {
	alias "@$1=declare $2 && _args_set $2"
}
args_edict opts_before_args _OPTS_PARSE_FIRST
args_edict opts_keep_break _OPTS_KEEP_BREAK
args_edict opts_skip_unknown _OPTS_SKIP_UNKNOWN
args_edict args_no_cache _ARGS_NO_CACHE
args_edict usage_match_first _USAGE_MATCH_FIRST

alias _has_func='declare >/dev/null 2>&1 -p ${BASH_VERSION:+-F} -f'

# shellcheck disable=SC2142
alias opts_parse='
	ksh_run typeset KSH_FUNCTION="${.sh.fun}"
	declare _ArgsSet= __Source="${FUNCNAME:-${funcstack:-${0//[^[:alnum:]]/_}}}" _ARGS_USAGE_NUM=
	# NOTE: _ARGS contains "$@"
	declare -a ${KSH_VERSION:+-g} _ARGS=("$@") _ARGS_FORMATS=() _ARGS_FORMAT_INFO=() \
		_ARGS_VARS=() _ARGS_ARRAYS=() _ARGS_OPTS=() _ARGS_OPTS_BOOL=() \
		_ARGS_CHECKS=()
	[[ -n "${_ARGS_CACHE:-}" ]] || declare -g _ARGS_CACHE=1

	_ArgsSet="${-//[^xu]/}"
	#[[ -n "$_ArgsSet" ]] && set +$_ArgsSet

	_trace "$PS4$(funcname || echo "$0") $(args_quoted "$@")"

	_args_build_parser
	_ARGS_${__Source}_VARS

	declare _ARGS_RETURN='' "${_ARGS_VARS[@]}" "${_ARGS_OPTS[@]}" "${_ARGS_OPTS_BOOL[@]}"
	if (( ${#_ARGS_ARRAYS[@]} )); then
		declare -a "${_ARGS_ARRAYS[@]/%/=()}"
	fi

	_ARGS_${__Source} || safe_quit
	if [[ -n "$_ARGS_RETURN" ]]; then safe_quit; fi

	set -- "${_ARGS[@]}" # modified by parsing function

	[[ -n "$_ArgsSet" ]] && set -$_ArgsSet
'

alias args_parse='
declare _ARGS_PARSE_USAGE=1
opts_parse
'
alias parse_args=args_parse
alias parse_opts=opts_parse

function _args_name_to_variable {
	local -l In="$1"
	zsh_run In="${In:l}"
	local +l In
	local Separator Match

	local -u First UpperMatch

	# PERF: I've tested this with a per-character array and a pure "${//}" approach.
	# regex works best for a dozen individual options

	while [[ "$In" =~ ([^[:alnum:]]+)([[:lower:]]|$) ]]; do
		recapture 1 >/dev/null
		Separator="$REPLY"
		recapture 2 >/dev/null
		Match="$REPLY"
		UpperMatch="$Match"

		if [[ -z $Match ]]; then
			In="${In%"$Separator"}"
			break
		# This has a nice side effect of being able to escape - and _ in usage strings
		elif [[ "$Separator" = [_-] ]]; then
			In="${In//$Separator$Match/$UpperMatch}"
		else
			In="${In//$Separator$Match/ $UpperMatch}"
		fi
	done
	First="${In:0:1}"
	Name="${First/ /}${In:1}"
}

function _args_build_parser {
	local Cache="_ARGS_$__Source"

	# TODO: for ksh compatibility, we'd need to change all dynamic variables to optionally be global
	# if using ksh, e.g. _ARGS_BUILDER
	local Builder='' GlobEnabled=''
	[[ -o noglob ]] || GlobEnabled=1
	set -o noglob
	trap ' [[ $GlobEnabled = 1 ]] && set +o noglob ' ERR

	_args_build_parser_opts &&

	if [[ -n "${_ARGS_PARSE_USAGE:-}" ]]; then
		_args_parse_builder || return 9
	fi &&

	_args_build_parser_legend &&

	if ! eval "function $Cache { $Builder"$'\n }'; then
		error "Eval failed! See computed builder below:
		$Builder
		And Usage was:
		${Usage[@]}
		"
		return 9
	fi &&

	_args_build_varcache || return 9
	[[ $GlobEnabled = 1 ]] && set +o noglob
}

function _args_build_varcache {
	local Builder='' x=''

	Builder+='
		_ARGS_VARS=('
	for x in "${_ARGS_VARS[@]}"; do
		Builder+=$'\n"'"$x"\"
	done
	Builder+=')'

	Builder+='
		_ARGS_ARRAYS=('
	for x in "${_ARGS_ARRAYS[@]}"; do
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

	eval "function _ARGS_${__Source}_VARS { $Builder; }"
}

function _args_build_parser_opts {
	zsh_run setopt SH_WORD_SPLIT KSH_ARRAYS

	if ! var_is_declared _ARGS_OPTS; then
		error -p "FUNCTION BUG: internal vars not found -- did you include '@func_info'?"
		ecode 9
		safe_quit
	fi

	# PERFORMANCE: Bash mallocs and frees on every `shift` call in its `shift_args` function
	# https://github.com/bminor/bash/blob/master/builtins/common.c#L438
	# So, we should iterate over a read-only array
	Builder+='
	zsh_run setopt KSH_ARRAYS
	declare __Flag='' __Val='' __Pos=0 __Temp=0
	declare -a __PosArgs=()

	while ((__Pos < "${#_ARGS[@]}")); do

	if [[ "${_ARGS[__Pos]}" != -* ]]; then
		__Temp=$__Pos
		[[ "${_OPTIONS_PARSE_FIRST:-}" = 1 ]] && break
		while [[ "${_ARGS[__Pos]}" != -* ]] && ((__Pos < "${#_ARGS[@]}")); do
			((++__Pos))
		done
		__PosArgs+=("${_ARGS[@]: __Temp: __Pos - __Temp}")
		continue
	fi

	unset __Val
	__Flag="${_ARGS[__Pos]}"
	if [[ "$__Flag" = --no-* ]]; then
		__Flag="--${__Flag#--no-}=false"
	fi
	if [[ "$__Flag" = *=* ]]; then
		__Val="${__Flag#*=}"
		__Flag="${__Flag%%=*}"
	fi
	'

	Builder+=$'case "$__Flag" in\n'
	local Validation='' # used to build validation for each arg

	# --Name=Tag
	local Type='' Name='' Tag='' Opt=0 IsArray
	while ((Opt < "${#Options[@]}")); do
		if ! [[ "${Options[Opt]}" = -* ]]; then
			error -p 3 "argument flag format is messed up!"
			error -p 3 "Rest of array is as follows: $(args_quoted "${_ARGS[@]}")"
			return 9
		fi

		while [[ "${Options[Opt + 1]}" = -* ]]; do
			Builder+=" ${Options[Opt]} |"
			((++Opt))
		done
		Name="${Options[Opt]}" IsArray=''

		if [[ "$Name" = *=* ]]; then
			Type=string
			# TODO: Implement array flags. will need some opinionated designing.
			# probably, all bash arguments until the next /^-/ are part of the array,
			# but this is escapable with '\-'
			#
			# Also need separate way to allow flag to be used multiple times
			if [[ "$Name" = *... ]]; then
				error -p 1 "'$Name' elipsis format currently unsupported :("
				return 9
			fi

			Tag="${Name#*=}"
			Name="${Name%%=*}"
		else
			Type=bool
		fi
		_args_name_to_variable "${Name#-}" # function handles possible leading '-'

		# TODO: handle separators in the tag
		# NOTE: Name is now space separated
		# Also, maybe _args_name_to_variable with an interior processing here
		# if [[ "$Tag" = *[^[:alnum:]_]* ]]; then
		# 	while rematch "$Name" '[^[:alnum:]_]+' >/dev/null; do
		# 		local Separator="$REPLY"

		# 		Builder+="${Name%%"$Separator"*}='${Value%%"$Separator"*}'"$'\n'

		# 		Name="${Name#*"$Separator"}"
		# 		[[ "$Value" = *"$Separator"* ]] || Value=''
		# 		Value="${Value#*"$Separator"}"
		# 	done
		# fi
		# eval "$Name='$Value'"

		Builder+=" ${Options[Opt]%%=*} )"$'\n'


		# build validation early to extract type info
		_args_build_validation "${Options[Opt + 1]}"

		case "$Type" in
			bool)
				_ARGS_OPTS_BOOL+=("$Name=")
				# Using __Val here makes it easier to have validation tests follow a standard
				# structure
				Builder+='__Val="${__Val-true}"
				'

				;;
			*)
				_ARGS_OPTS+=("$Name=")
				Builder+='
				if [[ -z "${__Val+x}" ]]; then
					__Val="${_ARGS[__Pos + 1]}"
					((++__Pos))
				fi
				'

				;;
		esac

		Builder+="$Validation
		((++__Pos))
		"

		if [[ -n "$IsArray" ]]; then
			Builder+="$Name"'+=("$__Val");;
			'
		else
			Builder+="$Name"'="$__Val";;
			'
		fi

		# clear last flag and description
		((Opt += 2))
	done

	Builder+='
	-h | --help )
		print_doc -p 1 2>&1
		_ARGS_RETURN=1
		return 0
		;;
	-- )
		_ARGS_BREAK=1
		if [[ "$_OPTS_KEEP_BREAK" != true ]]; then
			((++__Pos))
		fi
		break
		;;
	* )
		# if no options spec was defined, assume flags are parsed elsewhere
		(( "${#Options[@]}" )) || return 0

		if [[ -n $_OPTS_SKIP_UNKNOWN ]]; then
			((++__Pos))
			__PosArgs+=("${_ARGS[__Pos]}")
			continue
		fi

		error -p 1 "Flag \"$__Flag\" not supported!"
		return 1
		;;

	esac
	done

	_ARGS=("${__PosArgs[@]}" "${_ARGS[@]: __Pos: ${#_ARGS[@]} - __Pos}")
	__Flag=''
	'
}

function _args_build_validation {
	# read predicate requirements from docstring
	local DocString="${1%%.*}" Predicate='' Test='' Error=''
	Validation=''
	while true; do
		Predicate="${DocString%%,*}"
		Predicate="${Predicate# }"
		DocString="${DocString#*, }"
		Test=''

		case "$Predicate" in

			# Type declarations & checks
			[Ii]nt | [Ii]nteger )
				Type=integer
				# --or-null is on because this also handles usage args in parse_legend.
				# Also, it allows us to 'unset' values if necessary. To do a final check that a
				# value must be set, either use the 'Required' predicate or specify it in each Usage
				Test='is_type --or-null integer "$__Val"'
				Error="$Tag"' must be an integer, got ${__Flag:+$__Flag }\"$__Val\" instead.'
				;;
			[Dd]ecimal )
				Type=decimal
				Test='is_type --or-null decimal "$__Val"'
				Error="$Tag"' must be a decimal, got ${__Flag:+$__Flag }\"$__Val\" instead.'
				;;
			[Bb]ool | [Bb]oolean )
				Type=bool
				Test='[[ $__Val =~ ^(true|false|)$ ]]'
				Error='${__Flag:-$Tag} must be boolean.'
				;;
			[Aa]"llowed multiple times" | [Mm]"ultiple allowed" | [Cc]"an have multiple" )
				IsArray=1
				;;

			[Nn]"ew file" )
				Type=file
				Test='[[ -e \$(dirname "$__Val") ]]'
				Error='Parent directory of file \"$__Val\" does not exist.'
				;;
			[Ee]"xisting path" )
				Type=file
				Test='[[ -e $__Val ]]'
				Error='Path '$__Val' does not exist.'
				;;
			[Ff]ile | [Ee]"xisting file" )
				Type=file
				Test='[[ -f $__Val ]]'
				Error='File '$__Val' does not exist.'
				;;


			[Nn]o\ repeats )
				Test='! contains "$__Val" "${'"$Name[@]}\""
				Error="$Tag"' must have no duplicates, but got ${__Flag:+$__Flag }\"$__Val\" twice.'
				;;

			[Mm]atches\ /*/ | /*/ )
				Predicate="${Predicate#*/}"
				Predicate="${Predicate%/}"
				Test="[[ -z \$$Name || \$$Name =~ $Predicate ]]"
				Error="$Tag"' must match /'"$Predicate"'/, got ${__Flag:+$__Flag }'"'\$$Name'"' instead.'
				;;

			[\>\<=]* | [\>\<=]=* )
				# TODO: accept tag name variables
				Test="[[ -z \$$Name ]] || {
					is_type integer \$$Name && (( $Name $Predicate ))
				}"
				_ARGS_CHECKS+=("$Tag" "$Name" "$Test"
					"Failed test: $Tag $Predicate"
				)
				;;

			[Rr]equired )
				_ARGS_CHECKS+=("${Tag:-Name}" "$Name" '[[ -n "$__Val" ]]'
					'${__Flag:-$Tag} must be set to a value.'
				)
				;;

			[Dd]"efaults to "* )
				local Default="${Predicate#[Dd]efaults to }"

				if [[ "$Default" = [\"\']*[\'\"] ]]; then
					Default="${Default:1: ${#Default} - 2}"

				elif [[ "$Default" = *\ * ]]; then
					error -p 1 "FUNCTION BUG: $Tag: default containing spaces must be surrounded in quotes."
					return 9

				elif [[ "$Default" = *[[:upper:]]* && "$Default" != *[^[:upper:][:digit:]_]* ]]; then
					local OldName="$Name"
					_args_name_to_variable "$Default"
					Default="\$$Name"
					Name="$OldName"
				fi

				if [[ -n "$Type" ]] && ! is_type "$Type"; then
					error -p 1 "FUNCTION BUG: ${Tag:-$Name}: default must match option type '$Type'."
					return 9
				fi

				_ARGS_CHECKS+=("${Tag:-Name}" "$Name" "$Name=\${$Name:-$Default}"
					"$Predicate"
				)
				;;

			#\(\(*\)\) ) ;;
			* )
				# TODO: have some kind of lenient error checking to make sure the devs haven't
				# completely messed up.
				true
		esac

		if [[ -n "$Test" ]]; then
			Validation+="
				if ! $Test; then
					error -p 1 \"$Error\"
					return 1
				fi
			"
		fi
		if [[ "$Predicate" == "$DocString" ]]; then
			break
		fi
	done
}

function _args_build_assoc_array {
	local Opts="$(declare -p "$@")"
	Opts="${Opts//declare -A/}"
	Opts="${Opts//typeset -g -A/}"
	Builder+="$Opts"
}

function _args_parse_builder {
	((${#Usage[@]} > 0)) || return 0

	zsh_run setopt SH_WORD_SPLIT noglob KSH_ARRAYS

	# one parser for each usage line
	declare -a Parsers
	# Parsers["${#Usage[@]}" - 1]=' ' # reserve space???
	# Parsers["${#Usage[@]}" - 1]=''

	_args_build_usage_parsers || return

	Builder+='
	__Pos=0

	declare -a _ARGS_BOUNDS=() _ARGS_COMPOUND=()
	if ! _args_parse_dynamic; then
		error -p 2 "Arguments did not match any usage strings. $(args_quoted "$@")"
		print_doc -p 2
		return 1
	fi

	case "$_ARGS_USAGE_NUM" in
	'
	local i
	for ((i=0; i < ${#Usage[@]}; i++)); do
		Builder+="$i) "
		if [[ "${Parsers[$i]}" = \#* ]]; then
			Builder+="error 'INTERNAL ERROR: chosen usage line $i is a comment!'; return 9 ;;"
			continue
		fi

		Builder+=" ${Parsers[i]};;"$'\n'
	done
	Builder+=$'esac'
}

#  MAIN GOALS OF THIS FUNCTION
#  - determine if we can sort argument parsing now or defer to later
#  - determine if we can distinguish the right usage for all user inputs
#  - prioritise which usage line should be selected first
function _args_build_usage_parsers {
	zsh_run setopt KSH_ARRAYS SH_WORD_SPLIT

	[[ ${#Usage[@]} -lt 2 && -z "$Usage" ]] && return 0

	local Format='' Name='' Line='' TokenPos='' GlobEnabled=''

	[[ -o noglob ]] || GlobEnabled=1
	set -o noglob

	# a Run is a consecutive series of arguments that share the same required pattern
	# a run may only contain a single variadic argument, however it can contain any number
	# of optional or required arguments.
	local RunMin RunMax RunPattern
	# Format info values, used to identify which Usage string should be used to parse args
	local ArityMin=0 ArityMax=0

	# Flags for the token talker to telepath to
	local Match Optional Variadic Literal Compound Depth

	local LineBuilder='' TokenPos=0

	# TODO: might need a full pre-processing step, for the following:
	#  - check if an optional run is treated as variadic or not (so we can make each arg an array)
	#  - determine if a variable name is referred to later as variadic, meaning we should save both
	#    variables into a single array.

	for ((LinePos = 0; LinePos < ${#Usage[@]}; LinePos++)); do
		Line="${Usage[LinePos]}"
		if [[ "$Line" = \#* ]]; then
			_ARGS_FORMATS+=('#')
			_ARGS_FORMAT_INFO+=('#')
			continue
		fi

		LineBuilder='' Format='' ArityMin=0 ArityMax=0 RunPattern='' Depth=0

		LineBuilder+='
		local __Compound="" __Sep="" __Arg=""'

		# Parse the given line
		declare -a Tokens=($Line)
		for (( TokenPos = 0; TokenPos < ${#Tokens[@]}; TokenPos++ )); do
			Token="${Tokens[TokenPos]}"

			Match='' Optional='' Variadic='' Literal='' Compound=''
			# TODO: make generic
			if ! _args_token_talker "$Token"; then
				return 9
			fi

			# a new regex or match means a new run pattern
			if [[ "$RunPattern" != "$Match" ]]; then
				if [[ -n "$RunPattern" ]]; then
					_args_usage_record_run
				fi
				RunMin=0
				RunMax=0
				RunPattern="$Match"
			fi

			# TODO: handle the case when parsing requires lookahead

			if [[ -z $Optional ]]; then
				((++RunMin))
			elif [[ "$RunMax" != + ]]; then
				((++RunMax))
			fi
			if [[ -z $Literal ]]; then
				_ARGS_VARS+=(${Name// /= }=)
			fi

			if [[ $Variadic && "$RunMax" = + ]]; then
				error -p 1 '
					FUNCTION BUG: cannot have two VARIADIC... arguments in
					a series of tokens with the same pattern. You need to have a literal
					or argument containing a symbol in between.'
				return 9
			fi

			if [[ $Compound ]]; then
				local x CompoundPos=1
				declare -a Vars=($Name)
				LineBuilder+='
				__Arg="${_ARGS[ ${_ARGS_BOUNDS['$TokenPos']} ]}"
				# See this func for how compound arg parsing works
				# This code just interprets its output
				_args_parse_compound "'"$Token"'" "$__Arg"
				__Compound="$REPLY"
				# fetch the 1st arg index from the format string
				__Pos="${__Compound%%[^[:digit:]]*}"
				__Compound="${__Compound#$__Pos}"
				'
				for x in $Name; do
					LineBuilder+='

					if (( $__Pos == '$CompoundPos' )); then
						# fetch the separator from the format string
						__Sep="${__Compound%%[[:digit:]]*}"
						__Compound="${__Compound#"$__Sep"}"

						# fetch the value from the arg and strip the separator
					'
					if [[ $Variadic ]]; then
						# TODO: variadics need to be appended, in case values are added elsewhere
						# will rewrite _args_parse_compound to return a sparse array of set values
						# and append each value to each variadic (including unset ones)
						error 'Have not yet implemented variadic compound args'
						return 9
					else
						LineBuilder+=$x'="${__Arg%%"$__Sep"${__Sep:+*}}"'
						#LineBuilder+=$x'="${__Compound[i]:-$x}"
					fi

					LineBuilder+='
						__Arg="${__Arg#*"$__Sep"}"

						# fetch the next arg index from the format string
						__Pos="${__Compound%%[^[:digit:]]*}"
						__Compound="${__Compound#$__Pos}"
					fi
					'
					((++CompoundPos))
				done

				if [[ $Variadic ]]; then
					# scalar variable names are left empty
					# and sparse *List arrays for each individual portion
					_ARGS_ARRAYS+=(${Name// /List= }List=)
				fi

			elif [[ "$Name" = *\ * ]]; then
				error "INTERNAL ERROR: Name has spaces ($Name), but was not treated as compound. Maybe it's an edge case we have not covered"
				return 9
			elif [[ -z $Literal ]]; then
				LineBuilder+='
				__Pos="${_ARGS_BOUNDS['$TokenPos']}"
				'$Name${Variadic:++}'=("${_ARGS[@]: __Pos : ${_ARGS_BOUNDS['$TokenPos' + 1]} - __Pos }")
				_args_check_dash '"$Name \"\$$Name\""$' || return 1\n'

				if [[ $Variadic ]]; then
					RunMax=+
					_ARGS_ARRAYS+=($Name)
				else
					_ARGS_VARS+=(${Name//[^[[:upper:][:digit:]_]]/ }'=')
				fi
			fi
		done
		_args_usage_record_run

		_ARGS_FORMATS+=("${Format% }")
		_ARGS_FORMAT_INFO+=("$ArityMin $ArityMax")
		Parsers[$LinePos]="$LineBuilder"
	done
	[[ $GlobEnabled = 1 ]] && set +o noglob
	_args_check_usage_conflicts
}

function _args_usage_record_run {
	((ArityMin += RunMin))
	if [[ $RunMax = + ]]; then
		ArityMax=$RunMax
	else
		((RunMax += RunMin))
		[[ $ArityMax = + ]] && ArityMax=$RunMax || ((ArityMax += RunMax))
	fi
	Format+="$RunPattern $RunMin $RunMax "
}

### Uhhhhh
# track token position/index/count while we iterate. Once we start hitting non-deterministic
# argument positioning, we can refer to the Bounds array generated by _args_parse_usage, indexed by
# the token number, to pull out and parse the relevant data.

# gets the right kind of token parsing goodness or something
function _args_token_talker {
	zsh_run setopt KSH_ARRAYS
	local Token="$1"

	case "$Token" in
		'' )
			# Empty tokens are intentionally wiped by lookaheads like [ ARG ] and { ARG }, telling
			# us to ignore control characters that have already been handled.
			# Don't worry, they're completely impossible for users to inject themselves, we're safe
			# to use it.
			return
			;;

		'{' | \"* | \'* )
			error -p 1 "FUNCTION BUG: Token '$Token' in usage not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
			return 9
			;;

		*\ *  )
			# TODO: two or more tokens that must be parsed together
			return 9
			;;

		*... )
			Variadic=1
			if [[ "$Token" = \[*\] ]]; then
				Optional=1
				_args_token_talker "${Token:1:${#Token} - 5}"
			else
				_args_token_talker "${Token%...}"
			fi
			return
			;;

		*\[* | *\]* )

			local Next="${Token}" InitialDepth="$Depth" Delta='' s=0
			while ((TokenPos < "${#Tokens[@]}")); do
				for ((s = 0; s < ${#Next}; s++)); do
					case ${Next:s:1} in
						\[ ) ((++Depth));;
						\] )
							if ((--Depth < 0)); then
								error -p 2 "FUNCTION BUG: There are too many ']' in Token '$Token'!"
								return 9
							elif ((Depth < InitialDepth)); then
								if (( s != ${#Next} + Depth - InitialDepth )); then
									error -p 1 "FUNCTION BUG: Found ']' ending an optional run, but ] was not at the end of Token '$Token'!:
									${#Next} - ($Depth - $InitialDepth) != $s
									${Token:0: s} >>${Token:s:1}<< ${Token: s + 1}
									Usage line: ${Tokens[@]}
									"
									return 9
								fi
							fi
							;;
					esac
				done
				(( Delta = Depth - InitialDepth ))

				# TODO: This

				if ((Depth > InitialDepth)); then
					if [[ "${Token: 0: Delta }" = *[^[]* ]]; then
						error -p 1 "FUNCTION BUG: There are too many '[' in Token '$Token'!
							If you meant to start an optional run (e.g. [A B]), make sure that
							$Delta of the ['s in your token are at the start.
							Usage line: ${Tokens[@]}
						"
						return 9
					fi
					Token="${Token: Delta}"
				elif ((Depth < InitialDepth)); then
					Token="${Token: 0: ${#Token} + Delta}"
				fi

				if [[ $Token = \[*\] ]]; then
					Optional=1
					if [[ "$Token" = *...\] ]]; then
						Variadic=1
						_args_token_talker "${Token:1:${#Token} - 5}"
					else
						_args_token_talker "${Token:1:${#Token} - 2}"
					fi
					return

				elif [[ $Token = *[* ]]; then
					Compound=1
					_args_name_to_variable "$Token"
					return
				else
					_args_token_talker "${Token}"
					return
				fi

			done

			error -p 1 "FUNCTION BUG: Runs of optional arguments not currently supported. Please split into two usage lines"
			return 9
			;;

		*[[:upper:]_]* )
			if [[ $Token = *[^[:upper:][:digit:]_]* ]]; then
				Compound=1
			else
				Match='*'
			fi
			_args_name_to_variable "$Token"
			return
			;;


		-* )
			# will have to parse the next token manually
			# TODO: Don't forget to use _OPTS_BOOL to determine if it has an argument!
			# (false might always be an argument, but thankfully that's literal so easy to
			# handle)
			# TODO: also, usage strings might check for a specific value `--flag=exact-match`, or
			# just that they're set (--flag=FLAG)
			Flag=1
			Literal=1 # maybe remove?
			return
			;;

		# anything only containing lowercase, digits or symbols are considered literal.
		# (assuming control characters like [ ] or { } are parsed out earlier)
		*[[:lower:]]* )
			Literal=1
			return
			;;

	esac
}


function _args_token2regex {
	#Token="[ALPHA=BETA]=GAMMA[LAMMA]"

	# A]A or A[A disallowed
	if [[ "$Token" = *[[:upper:][:digit:]_][][][[:upper:]_]* ]]; then
		error -2 "Must have a separator between the boundaries of optional sections
		e.g. ALPHA[=BETA] is allowed but ALPHA[BETA] is not.
		"
		return 9
	fi
	# TODO: handle escaping \[ and \]
	# TODO: fix replace escaping
	replace "$Token" '([$.()|*+?{\^])' '\\1' >/dev/null
	Token="${REPLY//\[/(}"
	Token="${Token//\]/)?}"
	replace "^$Token\$" '[[:upper:][:digit:]_]+' '(.+)' >/dev/null
}

function _args_regex_parser {
	local Token="$1" CaptureGroup=0 i=0 Arg=2
	if [[ "$Token" != ^*$ ]]; then
		_args_token2regex
		Token="$REPLY"
	fi

	local Check='' i=0 Builder=''
	while ((i < "${#Token}")); do
		Check="${Token:i:3}"
		if [[ $Check == [^\\]\(* ]]; then
			((++CaptureGroup))
		elif [[ $Check == [^\\]\)* ]]; then
			if [[ $Check == *[^?] ]]; then

				if ((Arg > $#)); then
					error "INTERNAL ERROR: Given regex '$Token' has more capture groups than the provided Args! ${@:2}"
					return 9
				fi

				Builder+="
				recapture $CaptureGroup
				${@:Arg:1}=\"\$REPLY\"
				"
				((++Arg))
			fi
		fi
		((++i))
	done

	REPLY="$Builder"
}

function _args_check_dash {
	if [[ -z ${_ARGS_BREAK:-}${_OPTS_SKIP_UNKNOWN:-} && $2 = -* ]]; then 
		error -p 2 "Argument $1 starts with '-' ($2). Positional arguments may not do so without the '--' arg beforehand"
		return 1
	fi
}

function _args_check_usage_conflicts {
	# Compare the computed formats to check that no usage line conflicts with another
	local i j
	for ((i=0; i < ${#_ARGS_FORMATS[@]}; i++)); do
		[[ "${_ARGS_FORMATS[$i]}" = \#* ]] && continue
		for ((j=i + 1; j < ${#_ARGS_FORMATS[@]}; j++)); do
			if [[ "${_ARGS_FORMATS[$i]}" = "${_ARGS_FORMATS[$j]}" ]]; then
				error -p 1 "$(deindent "FUNCTION BUG: The following usage lines are ambiguous!
				${Usage[$i]}
				${Usage[$j]}
				Either distinguish them with flags or other literals, or use 'opts_parse' and manually parse positional args yourself.")"
				return 9
			fi
		done
	done
}


# Find all possible matches for the given usages
# Select the usage with the best match
# record the change points between each usage token, which can then be referenced by the variable
# setting.
function _args_parse_dynamic {
	zsh_run setopt KSH_ARRAYS SH_WORD_SPLIT

	[[ ${#Usage[@]} -lt 2 && -z "$Usage" ]] && return 0

	local Name='' Line='' TokenPos='' GlobEnabled='' i=0 ExactMatch=''
	local ArityMin ArityMax OtherInfo

	declare -a Bounds=() Priorities=() BestLinePriorities=()
	_ARGS_BOUNDS=() _ARGS_COMPOUND=()

	# TODO: can probably move this to root level of @func_info
	[[ -o noglob ]] || GlobEnabled=1
	set -o noglob
	for ((LinePos = 0; LinePos < ${#Usage[@]}; LinePos++)); do
		Line="${Usage[LinePos]}"
		Bounds=()
		if [[ "$Line" = \#* ]]; then
			continue
		fi

		# Parse the given line
		declare -a Tokens=($Line)
		if _args_parse_usage_token 0 0; then
			if [[ "${_USAGE_MATCH_FIRST:-}" ]]; then
				_ARGS_BOUNDS="${Bounds[@]}"
				break
			fi

			# check if the new match has better criteria than the previous best
			# and thus should replace it
			# TODO: we can frontload some checks in _args_parse_usage_token to break early

			for ((i = 0; i < ${#Bounds[@]} && i < ${#_ARGS_BOUNDS[@]}; i++)); do

				if (( ${Bounds[i]} > ${_ARGS_BOUNDS[i]} )); then
					continue 2
				elif (( ${Bounds[i]} < ${_ARGS_BOUNDS[i]} )); then
					_ARGS_BOUNDS=()
					break
				elif (( ${Priorities[i]} < ${BestLinePriorities[i]} )); then
					continue 2
				elif (( ${Priorities[i]} > ${BestLinePriorities[i]} )); then
					_ARGS_BOUNDS=()
					break
				fi
			done

			read ArityMin ArityMax OtherInfo <<<"${_ARGS_FORMAT_INFO[LinePos]}"
			if [[
				# prioritise exact argument matches
				( -z "$ExactMatch" && "$ArityMin" = "$ArityMax" )
				# prioritise existing bounds
				|| ((${#_ARGS_BOUNDS[@]} == 0))
			]]; then
				_ARGS_BOUNDS=("${Bounds[@]}")
				BestLinePriorities=("${Priorities[@]}")
				_ARGS_USAGE_NUM=$LinePos
				[[ "$ArityMin" = "$ArityMax" ]] && ExactMatch=1
			fi
		fi
	done
	[[ $GlobEnabled = 1 ]] && set +o noglob
	((${#_ARGS_BOUNDS[@]}))
}

# recursive function for checking a given token matches, moving on to the next one,
# and branching out when multiple matching formats are possible
function _args_parse_usage_token {
	zsh_run setopt KSH_ARRAYS
	local TokenPos="$1" ArgPos="$2" Arg='' Token="$3" Exit=''
	Token="${Token:-${Tokens[TokenPos]}}"

	while ((TokenPos < ${#Tokens[@]})); do

		# quit early if existing bounds is already better than this possibility
		if ((${#_ARGS_BOUNDS[@]} && ${_ARGS_BOUNDS[TokenPos]:-$ArgPos} < ArgPos)); then
			return 1
		fi

		Bounds[$TokenPos]=$ArgPos
		Arg="${_ARGS[ArgPos]}"
		Priorities[$TokenPos]=0

		case "$Token" in
			'' )
				# Empty tokens are intentionally wiped by lookaheads like [ ARG ] and { ARG }, telling
				# us to ignore control characters that have already been handled.
				# Don't worry, they're completely impossible for users to inject themselves, we're safe
				# to use it.
				return
				;;

			'{' | \"* | \'* )
				error -p 1 "FUNCTION BUG: Token '$Token' in usage not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
				return 9
				;;

			*... )

				local Run=$ArgPos Min=1
				Token="${Token%...}"
				if [[ "$Token" = \[*\] ]]; then
					Token="${Token:1:${#Token} - 2}"
					Min=0
				fi
				((Min += ArgPos))

				replace "$Token" '[[:upper:][:digit:]_]+' '*' >/dev/null
				Match="$REPLY"
				if [[ "$Match" = '*' ]]; then
					Run="${#_ARGS[@]}"
				else
					Priorities[$TokenPos]=40
				fi
				while ((Run < "${#_ARGS[@]}")) && [[ "${_ARGS[Run]}" = $Match ]]; do
					((++Run))
				done
				# From the longest match downward, test validity
				while (( Run >= Min )); do
					_args_parse_usage_token $((TokenPos + 1)) $((Run)) && return
					((--Run))
				done
				return 1
				;;

			\[*[^]] | [^]]*\] )

				# Collect all arguments into a single token
				local Next="$Token" OptionalEnd=$TokenPos Depth=0 i
				while true; do
					# TODO: cache depth in a DepthDelta array in token_talker, since slicing is expensive
					for ((i = 0; i < ${#Next}; i++)); do
						case ${Next:i:1} in
							\[ ) ((++Depth));;
							\] ) ((Depth--));;
						esac
					done

					if ((Depth)); then
						((++OptionalEnd))
						if ((OptionalEnd >= "${#Tokens[@]}")); then
							error "FUNCTION BUG: Never matched a ] for [ starting at '$Token'. Current usage:
							${Tokens[@]}"
							sleep 3
							return 9
						fi
						Next="${Tokens[OptionalEnd]}"
						continue
					fi

					if ((TokenPos == OptionalEnd)); then
						# Nice, a single token with exactly the number of
						# brackets we need :relieved:
						if [[ $Token != \[*\] ]]; then
							# ( will continue into variable matching below due to fallthrough)
							break
						fi
					fi

					# TODO check ending ] is at the end of the ending argument
					# VAR]BOO is not allowed (to make handling a tad easier)
					# We'll also need extra logic to handle [A B]... :blobsweat:

					# SPLIT -- execute test for both both with and without the optional arg
					#
					# TODO: write out a heap of examples and really stress test the boundaries of
					# optionals
					#
					# Current considerations:
					#
					# ARRAY... contains ELEMENTS...
					# This is definitely not okay, `contains contains contains contains contains`
					#
					# ARRAY... [not] contains ELEMENT
					# ARRAY might contain `not`, there is a chance of a function bug here
					# But devs can check themselves for `not`, explicitly disallow it, etc
					# Should probably throw an error that needs to be quashed by an 'allow ambiguous'
					# annotation
					#
					# OBJECT is [not] PROPERTIES...
					# This one is a little more clear, it's pretty obvious that the first `not` will be
					# taken by the functiongg
					#
					#
					# A [B] literal ARRAY...
					#
					# Fine:
					# A [B] literal KEY=VALUE...

					Priorities[$TokenPos]=-10 # likely overridden

					# test *with* optional token
					Tokens[TokenPos]="${Token#[}"
					Tokens[OptionalEnd]="${Tokens[OptionalEnd]%]}"

					Exit=0
					_args_parse_usage_token $TokenPos $ArgPos "${Token:1:${#Token} - 2}" || Exit=$?

					Tokens[TokenPos]="[${Tokens[TokenPos]}"
					Tokens[OptionalEnd]="${Tokens[OptionalEnd]}]"
					((Exit == 0)) && return 0

					# and test without
					for ((i = TokenPos; i <= OptionalEnd; i++)); do
						Bounds[$i]=$ArgPos
						Priorities[$i]=${Priorities[TokenPos]}
					done
					_args_parse_usage_token $((OptionalEnd + 1)) $ArgPos
					return $?

				done

				# Note the continue into variable matching here.
				;&

			*[[:upper:]_]* )
				if [[ $Token = *[^[:upper:][:digit:]_]* ]]; then
					# has separators
					Priorities[$TokenPos]=50
					_args_token2regex "$Token"
					[[ "$Arg" =~ $REPLY ]] || return 1
				else
					Match='*'
				fi

				((++TokenPos))
				((++ArgPos))
				Token="${Tokens[TokenPos]}"
				continue
				;;


			# anything only containing lowercase, digits or symbols are considered literal.
			# (assuming control characters like [ ] or { } are parsed out earlier)
			* )
				if [[ "$Arg" != $Token ]]; then
					return 1
				fi

				Literal=1
				Priorities[$TokenPos]=100
				((++TokenPos))
				((++ArgPos))
				Token="${Tokens[TokenPos]}"
				continue
				;;

		esac
	done
	((ArgPos == ${#_ARGS[@]})) || return 1
	# Add final bounds to mark end of last argument
	Bounds+=($ArgPos)
	Priorities+=(-100)
}

# parse arg tokens with symbol separators
# e.g. KEY=VALUE or X,Y[,Z][,WIDTH,HEIGHT[,DEPTH]]
function _args_parse_compound {
	zsh_run setopt KSH_ARRAYS

	# vars for tracking our position in the token
	local Queue="$1" Arg="$2" VarNum=${3:-0} Depth="${4:-0}"

	# Used to track how many tokens were found
	# We want to return the match with the most number of tokens
	local VarsFound='' Best='' BestCount=''

	# extra vars for control flow and logistics
	local TopLevel='' SkipOptional=0 Temp='' Separator=''

	if [[ -n "$3" ]]; then
		local Result="$Result"
	else
		local TopLevel=1 Result=''

		# used to pass the VarsFound variable to the parent function
		local _VarsFound=0

		# keep track of which levels of optional groups are missing separators
		# If there's no separator, and we hit a variable, that's two variables in a row
		# That's illegal!!
		declare -a HasSeparator=()
	fi


	while ((${#Queue})); do

		case "$Queue" in
			'['* )
				Queue="${Queue:1}"

				if [[ -n "$TopLevel" ]]; then
					if [[ -z "${HasSeparator[Depth]}" && "$Queue" = [[:upper]_]* ]]; then
						error -p 1 "FUNCTION BUG: Usage token '$1' is ambiguous and thus illegal.
						It's possible that two variables would have no separator between them, making it impossible to distinguish the correct value.
						The latter conflicting variable starts here: '$Queue'
						"
						return 9
					fi
					HasSeparator[$((Depth + 1))]="${HasSeparator[Depth]}"
				fi

				((++Depth))
				((SkipOptional)) && continue

				# Branching paths:
				# test with this optional group
				if _args_parse_compound "$Queue" "$Arg" "$VarNum" "$Depth"; then
					((_VarsFound += VarsFound))
					if ((_VarsFound > BestCount)); then
						BestCount="$_VarsFound"
						Best="$REPLY"
					fi
				fi
				# and test without it (in the current branch)
				SkipOptional="$Depth"
				;;

			']'* )
				Queue="${Queue:1}"
				((Depth--)) || return 9
				if ((Depth < SkipOptional)); then
					# We've left the optional group being skipped, so clear value
					SkipOptional=0
				fi
				;;

			[[:upper:]_]* ) # found variable name
				((++VarNum))
				# Trim name from queue
				Temp="${Queue%%[^[:upper:][:digit:]_]*}"
				Queue="${Queue#"$Temp"}"
				[[ -n "$TopLevel" ]] && HasSeparator[Depth]=''

				((SkipOptional)) && continue
				Result+="$VarNum"
				((++VarsFound))
				;;

			* ) # found separator
				# TODO: handle \ escapes
				# trim from queue
				Separator="${Queue%%[][:upper:]_[]*}"
				Queue="${Queue#"$Separator"}"
				[[ -n "$TopLevel" ]] && HasSeparator[Depth]=1

				((SkipOptional)) && continue

				# Try and match argument

				# include preceding variable if one exists
				[[ "$Result" = *[[:digit:]] ]] && Temp='*' || Temp=''
				Temp="${Arg#$Temp"$Separator"}"

				if (( ${#Temp} == ${#Arg} )); then
					# Separator not found. Fallback to best match or fail
					REPLY="$Best"
					[[ -n "$Best" ]]
					return $?
				fi
				Arg="$Temp"
				Result+="$Separator"
				((++VarsFound))

		esac
	done

	if ((BestCount > VarsFound)); then
		REPLY="$Best"
	else
		REPLY="$Result"
		_VarsFound="$VarsFound"
	fi
}

function _args_build_parser_legend {
	zsh_run setopt KSH_ARRAYS

	local i=0 Type='' Name='' Validation=''
	for ((i = 0; i < "${#Legend[@]}"; i += 2)); do
		Type=''
		_args_name_to_variable "${Legend[i]}"
		_args_build_validation "${Legend[i + 1]}"
		Builder+="$Validation"
	done

	for ((i = 0; i < "${#_ARGS_CHECKS[@]}"; i += 4)); do
		Builder+='
		for __Val in "${'"${_ARGS_CHECKS[i + 1]}"'[@]}"; do
			if ! '"${_ARGS_CHECKS[i + 2]}"'; then
				error -p 1 "Failed check for '"${_ARGS_CHECK[i]}: ${_ARGS_CHECK[i + 3]}'\"
				return 1
			fi
		done
		"
	done
}

function usage_has {
	local Token
	for Token; do
		contains "$Token" ${Usage[_ARGS_USAGE_NUM]} || return 1
	done
	return 0
}

function usage_has_glob {
	local Token
	for Token; do
		contains_glob "$Token" ${Usage[_ARGS_USAGE_NUM]} || return 1
	done
	return 0
}

alias arg_group_read='declare __ArgGroup __ArgGroupI; _arg_group_read'
function _arg_group_read {
	if [[ -z "$1" ]]; then
		error -p 2 "No variables provided."
		return 9
	fi
	local Builder='' Func="_ARGS_GROUP_READ_${*// /_}" Arg=''
	_ARGS_CACHE=1

	if [[ -z $__ArgGroup ]]; then
		__ArgGroup="$*"
		__ArgGroupI="0"
		if ! _has_func "$Func"; then
			Builder+='
			if [[ "$__ArgGroup" != "$*" ]]; then
				error -p 2 "Cannot parse multiple argument groups at once!
				Tried to parse \"$*\" but \"$__ArgGroup\" already set!"
				return 9
			elif ((__ArgGroupI == 0)); then
				if ! declare -p -a "${@/%/List}" >/dev/null; then
					return 9
				fi
			fi
			if (("$__ArgGroupI" >= "${#'$1'List[@]}")); then
				# break loop
				__ArgGroup='' __ArgGroupI=''
				return 1
			fi
			'
			for Arg in "$@"; do
				Builder+=$'\n'"$Arg=\"\${${Arg}List[\$__ArgGroupI]}\""
			done
			Builder+=$'\n((++__ArgGroupI))'
			# TODO: for ksh, this will have to be an alias, since dynamic variables aren't an
			# option.
			eval "function $Func { $Builder"$'\n}'
		fi
	fi
	$Func "$@" || {
		local Exit=$?
		__ArgGroup='' __ArgGroupI=''
		[[ $? -eq 1 ]] || unset "$Func"
		return $Exit
	}
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

function args_gen {
	echo "$ARGS"
	echo "$*"
	echo "$ARGS_END"
}

function args_gen_tail {
	echo "$*"
	echo "$ARGS_END"
}

alias "@ARGS_DEFAULT=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"
alias "@DEFAULT_ARGS=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"

zsh_run setopt GLOB

#
# Arg parsing utils
#

function args_or_stdin {
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
function arg_bool {
	local __x
	for __x in "$@"; do
		# This works, despite questions you might have about variable scope
		if isTrue $(deref $__x); then
			echo --"$(echo "$__x" | sed "s/[A-Z]/-\L&/g")"
		fi
	done
}

if [[ -v ZSH_VERSION ]]; then
	eval '
	function args_quoted {
		REPLY="${@:q}"
		echo "$REPLY"
	}
	'
elif [[ -v BASH_VERSION ]]; then
	eval '
	function args_quoted {
		REPLY="${@@Q}"
		echo "$REPLY"
	}
	'
else
	function args_quoted {
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
	}
fi


#
# args documentation
#

function print_options {
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

function print_doc {
	local _ArgsSet="${-//[^xu]/}"
	${_ArgsSet:+set +$_ArgsSet}

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

	function __has { var_is_declared "$1" && [[ -n "$(deref "$1")" ]]; }

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

	${_ArgsSet:+set -$_ArgsSet}
}

function print_usage {
	local Name=''
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

function print_args {
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
