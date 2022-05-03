#
# Base script utilities
#

# Ensure the aliases created by this script are available
shopt -s expand_aliases

# temporarily unset aliases, so they don't interfere with this script
existingAliases="$(alias)"
for alias in $(alias | perl -ne "/alias (\w+)='*/ && print "'"$1\n"'); do
	unalias "$alias"
done

alias script_is_sourced='[[ "${BASH_SOURCE[0]}" != "${0}" ]]'

alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${BASH_SOURCE[0]}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

# Store the current process, to compare when running certain functions
UTIL_PID="$BASHPID"


alias safe_quit="return 2> /dev/null || exit"

# Shorthand structure for defining arguments
alias '@ARGS=while [ $# -ne 0 ]; do case "$1" in'
alias '@ENDARGS=
	;;
	# by specifying args before @ENDARGS, you can override the following values
	-h | --help )
		local HELP 2>/dev/null || :
		HELP=true # excluding help for compatibility.
		shift;
		;;
	-- )
		shift;
		break;
		;;
	'-*' )
		echo >&2 "Error: flag $1 not supported"
		shift
		safe_quit
		;;
	'*' ) break;
		;;
esac; done'

# Echo stderr debug line if turned on
debug() {
	if [ "$DEBUG" = true ]; then
		echo >&2 -e "DEBUG:" "$@"
	fi
}

enable_debug() {
	set -u
	export DEBUG=true
}

url_encode() {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote_plus('$1'))"
}

# Display the output of a diff, and ask the user if they want to continue with those changes
# returns 0 iff they say yes, otherwise return 1
diff_confirm() {

	diff="$(diff -yt "$@")"

	if [ "$?" -eq 0 ]; then
		echo "No changes were made -- automatically aborting." >&2
		return 1
	fi

	echo "$diff" | grep --color=always -E '^.{64}(\||>|<).*|$' # use grep to highlight lines with changes
	read -p "Do you wish to make these changes? (y/N): " confirm
	test "$confirm" = "y"
}

# Output the args of a script file
#
# given file must have a case block that parses args
# identified with an @ARGS comment at the top
print_args() {

	# need to be passed in explicitly, otherwise you can get bad loops.
	local function HELP

	@ARGS
		# Print args for the given function within the file
		-f | --function ) function="$2"
			shift
			shift
	@ENDARGS

	if [ "$HELP" = true ]; then
		echo >&2 "Usage: print_args [...args] [filename]"
		HELP=false print_args -f print_args
		debug "help is $HELP"
		return
	fi

	local file="${1:-${BASH_SOURCE[1]}}" # [1] is the context that called this function.

	if ! file "$file" | grep -q shell; then
		echo >&2 "Error: print_args: file '$file' is not a shell script."
		return 1
	fi

	if [ "$file" -ef "$DEVOPS_ROOT/helpers/helpers-common.sh" -a -z "$function" ]; then
		echo >&2 "Error: print_args: helpers-common.sh requires a -f function to be specified."
		return 1
	fi

	local printArgs="
	/@ARGS/,$ {
		/(esac|@ENDARGS)/q;
		/@ARGS/d;

		# print each comment and case match
		/#/p;
		/-.*\)/p;
		s/;;//p
	};
	"

	{
	echo "Args:"
	if [ -n "$function" ]; then
		# Note this runs on to the next function if no match found.
		# parsing the function end is tricky.
		sed -En "/$function().*\{/,$ { $printArgs }" "$file"
	else
		sed -En "$printArgs" "$file"
	fi
	} >&2
}

# Final line: re-apply previous aliases
eval "$existingAliases"
