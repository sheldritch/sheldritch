## Tokens

Single variable tokens -- eg VARIABLE_NAME

- Variable tags may only contain uppercase alphabetic characters and _ - (underscore).

Optional Tokens

- Optional tokens may or may not exist
- Any other kind of token may be wrapped in [ ] to be treated as an optional
  token.

Variadic Tokens -- eg SOURCE_FILES... [EXTRA_ARGS...] [CHILD_NODES]...

- A Variadic argument may be put anywhere in the usage string, however two
  variadic tokens may not be placed next to each other (excepting variadic
  compound tokens, see below).

Compound Tokens -- eg EMAIL_USER@EMAIL_DOMAIN KEY[=VALUE] !NEGATED_VAR

- Compound tokens contain several variables, separated by some non-variable tag
characters.
- Arguments for Compound Tokens are automatically split into variables. For the
  examples above: EmailUser EmailDomain Key Value and NegatedVar
- Compound tokens may take any number of optional portions, but internal
  portions may not be variadic nor quoted.
- Compound select the available format containing the most number of variables
  and separator strings.

Variadic Compound Tokens -- e.g. EMAIL_USER@EMAIL_DOMAIN... KEY[=VALUE]... !NEGATED_VAR...

- Arguments for Variadic Compound Tokens are split into variables suffixed with
- `List`. For the examples above: EmailUserList EmailDomainList KeyList
  ValueList and NegatedVarList
- *List variables are sparsely populated -- An element is created for *every*
  variable, even if in an unused optional portion. eg if `KEY[=VALUE]` is `key`,
  `ValueList` will contain an empty string ('') for that argument.
- Regular variable names (without `List`) are still declared as local, so you
  can write `for NegatedVar in "${NegatedVarList[@]}"` without manually
  declaring `NegatedVar` first.
- Multiple variables in a Variadic Compound Token may be iterated over easily
  using `arg_group_read`:
  ```bash
  while arg_group_read Key Value; do
    if [[ "$Value" ]]; then
      echo "$Key: $Value" >> "$ConfigFile"
    fi
  done
  ```

Quoted Tokens [NOT YET IMPLEMENTED] -- eg '|' "'QUOTED_ARG'"

- Quoted tokens treat control characters (|, [, ], {, }, ...) literally.
- Quotes must surround the entire token. Internal quotes are merely treated as
  separators. You can use backslash escapes (`\`) instead.

## Usage String Priority
- Usage strings with an exact number of arguments (i.e. without any optional or
  variadic arguments) are prioritiesed

# Extended argument parsing example.
```bash
# TODO: update to match current formatting
function sheldritch_args_example {

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

	local Flag='' Var='' Prefix=--
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
```
