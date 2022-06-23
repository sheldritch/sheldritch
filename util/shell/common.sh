#
# Common env/setup for use for other tool scripts
#

source "$TOOLS"/util/shell/base.sh || return 1

# Shorthand structure for defining arguments
alias '@ARGS=while [ $# -ne 0 ]; do case "$1" in'
alias '@ENDARGS=
	;;
	# by specifying args before @ENDARGS, you can override the following values
	-h | --help )
		local HELP 2>/dev/null || :
		HELP=true # excluding help for compatibility.

		if [ "$(type -t usage)" = function ]; then
			usage
			funcname -q && print_args -f "$(funcname)" || print_args
			return 0;
		fi

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


url_encode() {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote_plus('$*'))"
}

find_bin() {
	for x in ${PATH//://*${1}* }*${1}*; do
		[ -f "$x" ] && echo $x
	done
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

# Returns the key for a given key value pair
key() {
	echo "$1" | cut -d = -f 1
}

# Returns the value for a given key value pair
value() {
	echo "$1" | cut -d = -f 2
}

funcname() {
	local quiet
	if [ "$1" = '-q' ]; then
		quiet=true
	fi

	print() {
		if [ "$quiet" != true ]; then
			echo "$@"
		fi
	}

	if [ "${FUNCNAME[1]}" ]; then
		print "${FUNCNAME[1]}"
		return 0
	fi
	return 1
}

print_usage() {
	echo >&2 "Usage: $*"
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
		/(esac|@ENDARGS)/q;
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

use_tool util/shell/json.sh
use_tool util/shell/random.sh
