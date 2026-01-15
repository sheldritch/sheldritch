#!/bin/bash
#
# utils for argument parsing
#
# This includes the @func_info framework, the recommended way for structuring
# bash functions
#

# shellcheck disable=SC2139,SC1091,SC2086,SC2016,SC2125,SC2030,SC2031,SC2206
# shellcheck enable=SC2034,SC2154
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
alias @func_info='declare About="" _ARGS_PARSE_USAGE=""
declare -a Usage=() Options=() Legend=()
'

alias @func_passthrough='declare FUNC_PASSTHROUGH=$((FUNC_PASSTHROUGH + 1))'

function _args_set {
	stdin "${2:-true}" read -d '' -r "$1" || true
}
function args_mark {
	@help '
	Create a mark for the given global variable
	Usage: alias_funcs MARK_NAME GLOBAL_VARIABLE_NAME
	' && return
	alias "@$1=declare $2 && _args_set $2"
}
args_mark opts_before_args _OPTS_PARSE_FIRST
args_mark opts_keep_break _OPTS_KEEP_BREAK
args_mark opts_skip_unknown _OPTS_SKIP_UNKNOWN
args_mark args_no_cache _ARGS_NO_CACHE
args_mark args_double_underscore _ARGS_DOUBLE_UNDERSCORE
args_mark usage_match_first _USAGE_MATCH_FIRST
alias @func_internal='[[ -z "$TRACE_INTERNAL" ]] && set_temp +x'

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

	# Comment out this line if you want to disable turning off SET flags
	_ArgsSet="${-//[^xu]/}"
	[[ -n "$_ArgsSet" ]] && set +$_ArgsSet

	_trace "$PS4$(funcname || echo "$0") $(args_quoted "$@")"

	_args_build_parser
	_ARGS_${__Source}_VARS

	declare _ARGS_RETURN='' "${_ARGS_VARS[@]}" "${_ARGS_OPTS[@]}" "${_ARGS_OPTS_BOOL[@]}"
	if (( ${#_ARGS_ARRAYS[@]} )); then
		${ZSH_VERSION:+eval} declare -a "${_ARGS_ARRAYS[@]/%/=()}"
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
			In="${In//"$Separator$Match"/$UpperMatch}"
		else
			In="${In//"$Separator$Match"/ $UpperMatch}"
		fi
	done
	First="${In:0:1}"
	Name="${First/ /}${In:1}"
	if [[ "${_ARGS_DOUBLE_UNDERSCORE:-}" = true ]]; then
		Name="__$Name"
	fi
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

	if [[ "${_ARGS[__Pos]}" != -?* ]]; then
		__Temp=$__Pos
		[[ "${_OPTS_PARSE_FIRST:-}" = true ]] && break
		while [[ "${_ARGS[__Pos]}" != -?* ]] && ((__Pos < "${#_ARGS[@]}")); do
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
		(( "${#Options[@]}" )) || break

		if [[ $_OPTS_SKIP_UNKNOWN = true ]]; then
			__PosArgs+=("${_ARGS[__Pos]}")
			((++__Pos))
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
				Error='Path \"$__Val\" does not exist.'
				;;
			[Ff]ile | [Ee]"xisting file" )
				Type=file
				Test='[[ -f $__Val ]]'
				Error='File \"$__Val\" does not exist.'
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
	# zsh has string/array casting issues
	[[ -v ZSH_VERSION ]] && Usage=("${Usage[@]}")

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
	# PreviouslyGreedy: A... literal B... breaks if either A or B contains literal
	#     One side needs a A.. to indicate it will not contain `literal`
	local Match Optional Variadic Literal Depth Compound PreviouslyGreedy
	local -a SplitCompound=()

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

		LineBuilder='' Format='' ArityMin=0 ArityMax=0 RunPattern='' Depth=0 PreviouslyGreedy=''

		LineBuilder+='
		local -a __CompoundVars=() __Compound=()
		local __Sep="" __Arg=""'

		# Parse the given line
		declare -a Tokens=($Line) SplitCompound=()
		for (( TokenPos = 0; TokenPos < ${#Tokens[@]}; TokenPos++ )); do
			Token="${Tokens[TokenPos]}"

			Match='' Optional='' Variadic='' Literal='' Compound=''

			if ! _args_token_talker "$Token"; then
				return 9
			fi

			# TODO: test these
			if [[ $Optional && "$RunMax" == + && $PreviousyGreedy ]]; then
				error -p 1 "
					FUNCTION BUG: Usage Line: $Line
					Portion is potentially ambiguous: '$PreviouslyGreedy ... $Token'
					If arguments matching $Token appears, those values would be gobbled up by
					$PreviouslyGreedy (assuming that the token patterns are compatible).

					To quash this error, please change the variadic token's ellipsis from three
					dots to two (e.g. from ARG... to ARG..) to indicate the argument is non-greedy
					and will allow the following optional to match arguments.
					"
				return 9
			elif [[ $Variadic && "$RunMax" != "$RunMin" && $PreviousyGreedy ]]; then
				error -p 1 "
					FUNCTION BUG: Usage Line: $Line
					Portion is potentially ambiguous: '$Token ... $PreviouslyGreedy'

					Depending on your tokens, the user may wish to include an argument into
					$PreviouslyGreedy that would be instead gobbled up by the preceding optional
					group.

					Please consider if such a scenario is possible, and change your formatting to
					ensure that provided arguments are always unambiguous.

					To quash this error, please change the variadic token's ellipsis from three
					dots to two (e.g. from ARG... to ARG..) to indicate the argument is non-greedy
					and will always show deference to the tokens before and after it.
					"
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
			if [[ -z $Literal && -z $Variadic ]]; then
				# TODO: remove = here, and add variable setting into arg parsing function?
				if [[ -v ZSH_VERSION ]]; then
					declare Names="${Name//[[^[:upper:][:digit:]]_]/= }"
					_ARGS_VARS+=($Names'=' )
				else
					_ARGS_VARS+=(${Name//[^[[:upper:][:digit:]_]]/= }'=' )
				fi
			fi

			if [[ $Variadic && "$RunMax" = + ]]; then
				error -p 1 '
					FUNCTION BUG: cannot have two VARIADIC... arguments in
					a series of tokens with the same pattern. You need to have a literal
					or argument containing a symbol in between.'
				return 9
			fi

			if [[ $Compound ]]; then
				declare -a Vars=($Name)
				_args_compound_split "$Token"
				args_quoted "${SplitCompound[@]}" >/dev/null
				LineBuilder+='
				__Compound=('"$REPLY"')
				for ((
					__Pos = ${_ARGS_BOUNDS['$TokenPos']};
					__Pos < ${_ARGS_BOUNDS['$TokenPos' + 1]};
					++__Pos
				)); do

				__Arg="${_ARGS[__Pos]}"
				_args_parse_compound "$__Arg"
				'
				for ((i = 0; i < "${#Vars[@]}"; i++)); do
					LineBuilder+="
					${Vars[i]}${Variadic:+List+}=("'"${__CompoundVars['$i']}")'
				done
				LineBuilder+=$'\ndone'

				if [[ $Variadic ]]; then
					# scalar variable names are left empty
					# and sparse *List arrays for each individual portion
					_ARGS_ARRAYS+=(${Name// /List }List)
				fi

			elif [[ "$Name" = *\ * ]]; then
				error "INTERNAL ERROR: Name has spaces ($Name), but was not treated as compound. Maybe it's an edge case we have not covered"
				return 9
			elif [[ -z $Literal ]]; then
				LineBuilder+='
				__Pos="${_ARGS_BOUNDS['$TokenPos']}"
				'$Name${Variadic:++}=${Variadic:+(}'"${_ARGS[@]: __Pos : ${_ARGS_BOUNDS['$TokenPos' + 1]} - __Pos }"'${Variadic:+)}'
				_args_check_dash '"$Name \"\$$Name\""$' || return 1\n'

				if [[ $Variadic ]]; then
					RunMax=+
					_ARGS_ARRAYS+=($Name)
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

function _args_compound_split {
	zsh_run setopt SH_WORD_SPLIT noglob KSH_ARRAYS
	local Arg="${1%...}" Token='' Atom=''
	SplitCompound=()
	while [[ -n "$Arg" ]]; do
		case "$Arg" in

			'['* )
				SplitCompound+=('[')
				Arg="${Arg:1}"
				;;

			']'* )
				SplitCompound+=(']')
				Arg="${Arg:1}"
				;;

			[[:upper:]_]* )
				Token="${Arg%%[^[:upper:][:digit:]_]*}"
				SplitCompound+=("$Token")
				Arg="${Arg#"$Token"}"
				;;
			* )
				Atom="$Arg"
				Token=''
				while true; do
					Atom="${Arg%%[[:upper:][:digit:]_\[\]]*}"
					[[ $Atom ]] || break
					Token+="$Atom"
					Arg="${Arg#"$Atom"}"
					if [[ $Atom = *\\ ]]; then
						Token+="${Arg:0:1}"
						Arg="${Arg:1}"
					fi
				done
				SplitCompound+=("$Token")
				;;
		esac
	done
}

### Uhhhhh
# track token position/index/count while we iterate. Once we start hitting non-deterministic
# argument positioning, we can refer to the Bounds array generated by _args_parse_usage, indexed by
# the token number, to pull out and parse the relevant data.

# gets the right kind of token parsing goodness or something
function _args_token_talker {
	zsh_run setopt KSH_ARRAYS SH_WORD_SPLIT
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
			# NOTE: quotes are used to treat containing characters literally, usually as
			# compound token separators
			# eg '|' or "'QUOTED_ARG'"
			error -p 1 "FUNCTION BUG: Token '$Token' in usage not currently supported. Please use 'opts_parse' instead of 'args_parse' and parse arguments yourself."
			return 9
			;;

		*\ *  )
			# TODO: two or more tokens that must be parsed together
			return 9
			;;

		*.. )
			Variadic=1

			if [[ "$Token" = *... ]]; then

				# TODO: Do some more basic pattern comparison checks for each token
				# between the two variadics
				if [[ -n "$PreviouslyGreedy" ]]; then
					error -p 2 "
					FUNCTION BUG: Usage Line: $Line
					Tokens are potentially ambiguous from $PreviouslyGreedy to $Token
					If the tokens between them match multiple times, it is not clear which token
					would store them.

					For instance the tokens 'SUPERSET... contains SUBSET...' would match
					the args 'contains contains contains contains', but it's not clear which
					contains would be the literal one (especially if passing in user input).
					In this example, using this format at all would be very bad, since SUPERSET
					and SUBSET *should* accept any input.

					Please think carefully about your use-case and decide if there are any
					potential inputs that would lead to this issue. You may need to consider
					trying another format such as 'ARRAY_NAME contains SUBSET...', or
					'SUPERSET contains SUBSET' and splitting each argument yourself.

					To quash this error, please change the ellipsis of one side from three dots
					to two (e.g. from ARG... to ARG..) to indicate the argument is non-greedy
					and will stop as soon as the rest of the usage line can be matched with the
					remaining arguments. With the above example, 'SUPERSET... contains SUBSET..'
					would put all but the very last instance of `contains` into SUPERSET.
					<contains contains> contains <contains>
					"
					return 9
				fi
				PreviouslyGreedy="$Token"
				Token="${Token%...}"
			else
				PreviouslyGreedy=''
				Token="${Token%..}"
			fi

			if [[ "$Token" = \[*\] ]]; then
				Optional=1
				_args_token_talker "${Token:1:${#Token} - 2}"
			else
				_args_token_talker "${Token}"
			fi
			return
			;;

		*\[* | *\]* )

			local Brackets="${Token//\\[][]/}" InitialDepth="$Depth" Delta='' s=0 OldGreedy="$PreviouslyGreedy"
			Brackets="${Brackets//[^[\]]/}"
			while ((TokenPos < "${#Tokens[@]}")); do
				for ((s = 0; s < ${#Brackets}; s++)); do
					case ${Brackets: s:1} in
						\[ ) ((++Depth));;
						\] )
							if ((--Depth < 0)); then
								error -p 2 "FUNCTION BUG: There are too many ']' in Token '$Token'!"
								return 9
							fi
							;;
					esac
				done
				(( Delta = Depth - InitialDepth ))

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
					if [[ "${Token: Delta: - Delta }" = *[^]]* ]]; then
						error -p 1 "FUNCTION BUG: Found ']' ending an optional run, but ] was not at the end of Token '$Token'!:
							Please make sure there are $((- Delta)) ]'s at the end of your token.
							Usage line: ${Tokens[@]}
						"
						return 9
					fi
					Token="${Token: 0: ${#Token} + Delta}"
				fi

				# TODO: check OldGreedy to see if it was updated this token, and replace
				# PreviouslyGreedy with the full optional run
				if [[ $Token = \[*\] ]]; then
					Optional=1
					_args_token_talker "${Token:1:${#Token} - 2}"
					return

				elif [[ $Token = *'['* ]]; then
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
	local Token="$1"
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
		_args_token2regex "$Token"
		Token="$REPLY"
	fi

	local Check='' i=0 Builder=''
	while ((i < "${#Token}")); do
		Check="${Token: i: 3}"
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
				${@: Arg: 1}=\"\$REPLY\"
				"
				((++Arg))
			fi
		fi
		((++i))
	done

	REPLY="$Builder"
}

function _args_check_dash {
	if [[ -z ${_ARGS_BREAK:-}
			&& ${#Options[@]} -gt 0
			&& ${_OPTS_SKIP_UNKNOWN:-} != true
			&& ${_OPTS_PARSE_FIRST:-} != true
			&& $2 = -?*
	]]; then
		error -p 2 "Argument $1 starts with '-' ($2). Positional arguments may not do so without the '--' arg beforehand"
		return 1
	fi
}

function _args_check_usage_conflicts {
	if [[ "${_USAGE_MATCH_FIRST:-}" = true ]]; then
		return
	fi
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
				_ARGS_BOUNDS=("${Bounds[@]}")
				BestLinePriorities=("${Priorities[@]}")
				_ARGS_USAGE_NUM=$LinePos
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

		# TODO: For possible matches of a single usage string, Is there a case where both the following are true?
		# 1: Match A has more tokens than Match B
		# 2: Match B has an earlier match than match A
		# Which should be prioritised?

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


			*.. | \[*..\] )

				local Run=$ArgPos Min=1 Greedy=''

				if [[ "$Token" = \[*\] ]]; then
					Token="${Token:1:${#Token} - 2}"
					Min=0
				fi

				if [[ "$Token" == *... ]]; then
					Token="${Token%...}"
					Greedy=1
				else
					Token="${Token%..}"
				fi

				# Yep, doing it again. Both [A...] and [A]... are allowed (I guess [[A]...] too)
				if [[ "$Token" = \[*\] ]]; then
					Token="${Token:1:${#Token} - 2}"
					Min=0
				fi
				((Min += ArgPos))

				if [[ "$Greedy" && $Token != *[^[:upper:][:digit:]_]* ]]; then
					# Greedy with no separators -- will gobble up all args until the end (if
					# possible)
					Run="${#_ARGS[@]}"
				else
					Priorities[$TokenPos]=40
					_args_token2regex "$Token"
					Match="$REPLY"

					while ((Run < "${#_ARGS[@]}")) && [[ "${_ARGS[Run]}" =~ $Match ]]; do
						# TODO: test off-by-one error
						if (( ! Greedy && Run >= Min )); then
							# Stop as soon as the next argument is valid
							_args_parse_usage_token $((TokenPos + 1)) $Run && return 0
						fi
						((++Run))
					done
				fi

				# From the longest match downward, test validity
				while (( Run >= Min )); do
					_args_parse_usage_token $((TokenPos + 1)) $Run && return
					((--Run))
				done
				return 1
				;;

			\[*[^]] | [^]]*\] )

				# Collect all arguments into a single token
				local Next="$Token" OptionalEnd=$TokenPos Depth=0 i
				while true; do
					# TODO: cache depth in a DepthDelta array in token_talker, since slicing is
					# expensive
					for ((i = 0; i < ${#Next}; i++)); do
						case ${Next: i: 1} in
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

					Priorities[$TokenPos]=-10 # likely overridden

					# We'll also need extra logic to handle [A B]... :blobsweat:
					# _ARGS_BOUNDS will be useless for repeating arguments
					# And disallow subsequent variadic optional runs

					# SPLIT -- execute test for both both with and without the optional arg

					# test *with* optional token
					Tokens[TokenPos]="${Token#\[}"
					Tokens[OptionalEnd]="${Tokens[OptionalEnd]%\]}"

					Exit=0
					_args_parse_usage_token $TokenPos $ArgPos || Exit=$?

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
	local Arg="$1" Pos="${2:-0}"
	local Depth="$Depth" VarPos="$VarPos" LastVar="$LastVar" VarsFound="$VarsFound"

	# extra vars for control flow and logistics
	local TopLevel='' SkipOptional=0 Temp='' Separator=''

	if ((Pos == 0)); then
		TopLevel=1
		__CompoundVars=()

		local Depth=0 VarPos=0 LastVar=''

		# Used to track how many tokens were found
		# We want to return the match with the most number of tokens
		local VarsFound='' BestCount=''
		local -a Values=()

		# keep track of which levels of optional groups are missing separators
		# If there's no separator, and we hit a variable, that's two variables in a row
		# That's illegal!!
		declare -a HasSeparator=()
	fi


	for (( ; Pos < ${#__Compound[@]}; ++Pos)); do

		case "${__Compound[Pos]}" in
			'[' )

				if [[ -n "$TopLevel" ]]; then
					if [[ -z "${HasSeparator[Depth]}" && "${__Compound[Pos + 1]}" = [[:upper]_]* ]]; then
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
				_args_parse_compound "$Arg" "$((Pos + 1))"

				# and test without it (in the current branch)
				SkipOptional="$Depth"
				;;

			']' )
				((Depth--)) || return 9
				if ((Depth < SkipOptional)); then
					# We've left the optional group being skipped, so clear value
					SkipOptional=0
				fi
				;;

			[[:digit:]]* | *[^[:upper:]_]* ) # found separator

				[[ -n "$TopLevel" ]] && HasSeparator[Depth]=1

				((SkipOptional)) && continue

				# try and find separator (and argument value beforehand, if relevant)

				# remove escapes (except escaped escapes)
				Separator="${__Compound[Pos]//'\\'/\a}"
				Separator="${Separator//'\'/}"
				Separator="${Separator//\a/\\}"

				Temp="${Arg#${LastVar:+*}"$Separator"}"
				[[ $LastVar ]] && Values[LastVar]="${Arg%%"$Separator"*}"

				if (( ${#Temp} == ${#Arg} )); then
					# Separator not found. Fallback to best match or fail
					((TopLevel && ${#__CompoundVars[@]}))
					return $?
				fi

				LastVar=''
				Arg="$Temp"
				((++VarsFound))
				;;

			* ) # found variable name
				Values[VarPos]=''

				[[ -n "$TopLevel" ]] && HasSeparator[Depth]=''

				if ! ((SkipOptional)); then
					LastVar=$VarPos
					((++VarsFound))
				fi
				((++VarPos))
				;;

		esac
	done

	if [[ $LastVar ]]; then
		Values[LastVar]="$Arg"
	fi

	if ((VarsFound > BestCount)); then
		BestCount="$VarsFound"
		__CompoundVars=("${Values[@]}")
	fi
	(( ${#__CompoundVars[@]} ))
}

function _args_build_parser_legend {
	zsh_run setopt KSH_ARRAYS

	local i=0 Type='' Name='' Validation=''
	for ((i = 0; i < "${#Legend[@]}"; i += 2)); do
		Type=''
		_args_name_to_variable "${Legend[i]}"
		Builder+=$'\n__Val="$'$Name\"
		_args_build_validation "${Legend[i + 1]}"
		Builder+="$Validation"
	done

	for ((i = 0; i < "${#_ARGS_CHECKS[@]}"; i += 4)); do
		Builder+='
		for __Val in "${'"${_ARGS_CHECKS[i + 1]}"'[@]}"; do
			if ! '"${_ARGS_CHECKS[i + 2]}"'; then
				error -p 1 "Failed check for '"${_ARGS_CHECKS[i]}: ${_ARGS_CHECKS[i + 3]}'\"
				return 1
			fi
		done"
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

# TODO: consider renaming to args_compound_read
alias arg_group_read='declare __ArgGroup __ArgGroupI && _arg_group_read'
function _arg_group_read {
	if [[ -z "$1" ]]; then
		error -p 2 "No variables provided."
		return 9
	fi
	local Builder='' Func="_ARGS_GROUP_READ_$*" Arg=''
	Func="${Func//[[:space:]]/_}"
	_ARGS_CACHE=1

	if [[ -z $__ArgGroup ]]; then
		__ArgGroup="$*"
		__ArgGroupI="0"
		if ! _has_func "$Func"; then
			Builder+='
			@help '\''
			example:
			while arg_group_read Key Value; do
			  if [[ "$Value" ]]; then
				echo "$Key: $Value" >> "$ConfigFile"
			  fi
			done
			'\'' && return
			if [[ "$__ArgGroup" != "$*" ]]; then
				error -p 2 "
				Tried to parse Arg Group \"$*\" but \"$__ArgGroup\" already set!
				Cannot parse multiple argument groups at once!
				"
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
	@help "DEPRECATED" && return
	echo "$ARGS"
	echo "$*"
	echo "$ARGS_END"
}

function args_gen_tail {
	@help "DEPRECATED" && return
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

function arg_bool {
	@help '
	Outputs an argument flag for the given variable name, if and only if that variable is set to `true`
	Usage: arg_bool VARIABLE_NAME
	' && return
	local __x
	for __x in "$@"; do
		deref "$__x" >/dev/null || continue
		# This works, despite questions you might have about variable scope
		if isTrue $REPLY; then
			lowercase $REPLY
			echo --"$REPLY"
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
		{ funcname -p 1 -q && DPR_print_args -f "$(funcname -p 1)" || DPR_print_args; } 2>&1
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

function DPR_print_args {
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
