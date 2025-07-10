## Basics

Sheldritch uses a declarative approach to argument parsing. After initialising
the with @func_info, you set a collection of common variables to define usage
metadata. Once set, you run `opts_parse` or `args_parse` (explained below), and
the shadowy inner workings of Sheldritch automatically parses user input,
validates certain preconditions, and puts them into variables. It also uses the
metadata to produce help output when the `--help` flag is given.

Here are the variables that Sheldritch's @func_info uses:

- About -- a simple text field to explain what your function does. Also used to
  populate --help output.
- Usage -- a list of example formats, using placeholders.
    - Example: 'ARG1 [ARG2] ARG3...'
    - Takes either a string (if the command takes only one format), or a list of
      strings (one for each possible format).
    - Explained further in <#Tokens>.
- Options
    - takes any number of flags, followed by a string explaining its purpose.
      The final flag may include an equals sign and a tag (e.g. --backup=FILE),
      which signifies that a flag takes a value, instead of being true/false
    - e.g. `-f --force "Overwrite DESTINATION even if it already exists."`
    - You don't need to explicitly list --help, help output is completely
      handled for you.
    - which flags are parsed and how errors are handled can be modified with
      <#Marks> (described below).
- Legend -- Defines and explains the contents of TOKENS that appear in Usage
  strings.
    - takes a key-value array of TOKEN_NAME "and a string explaining its use"
    - Can also take validation. Legend validation always checks variables after
      the final values have been set
    - Legend may also explain the tags from options, and can apply validation to
      them. For instance, if your Options array contains --backup=FILE, your
      Legend may include `FILE "Existing file, required."`. This would apply
      that validation to the --backup option and Backup variable.

### `opts_parse` vs `args_parse`

`opts_parse` will only parse flags, leaving "$@" as the remaining arguments.
`args_parse` will additionally parse arguments based on the Usage value once flags have been handled.

Even if you don't have any options, calling `opts_parse` is still a good idea so
`--help` will handled for you automatically.

## Usage String Tokens

Single variable tokens -- eg VARIABLE_NAME

- Variable tags may only contain uppercase alphabetic characters, digits
  (only after the first character) and _ (underscore).

Optional Tokens -- eg [VARIABLE_NAME]

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
  `List`. For the examples above: EmailUserList EmailDomainList KeyList
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

# Marks (Annotations)

Marks are little flags before some code to tweak its behaviour on a meta level.

- @func_info -- indicates that the function argument parsing is handled by
  Sheldritch args.sh

- @func_use_parent -- Incompatible with @func_info and other marks. Accept the
    -p/--parent flag, identifying the Nth parent function calling the current
    function. The current function is 0, the function calling it is 1, its
    calling function is 2 and so on. This mark sets the ParentLevel variable,
    to what -p was set to, and the Parent variable, which is the name of the
    function that -p refers to.

- @func_passthrough -- TODOCUMENT

- @func_internal -- TODOCUMENT

- @opts_before_args -- stop parsing options as soon as the first non-flag is
  found. Any remaining flags will be considered part of the standard args.

- @opts_keep_break -- if a `--` is found within the arguments, do not remove it
  when parsing arguments

- @opts_skip_unknown -- If a flag is found that is not in the Options list, do
  not through an error, just leave it as part of the arguments.
    - Note that this might cause errors if a flag value starts with a `-`. If
      `--foo --bar` are arguments, where `--bar` is the value given to the
      `--foo` @flag, and `--bar` is registered as an option but `--foo` is not,
      the argument @`--bar` will be removed from the arguments and `--foo` will
      be left without a @value.

- @args_no_cache -- Disable caching all of the args metadata and code which is
  generated on a function's first run.
    - Since Sheldritch's arg parsing is optimised for many function runs, using
      this mark is a massive performance hit, and is only really useful for
      debugging or running tests.

- @args_double_underscore -- start every variable created by @func_info with
  `__DoubleUnderscores`
    - This is useful when taking a variable name as an argument, to avoid
      conflicting with it.

- @usage_match_first -- Do not judge the priority of the usage strings provided
  -- simply use the first one that matches.

# Validation

- Integer
- Decimal


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
