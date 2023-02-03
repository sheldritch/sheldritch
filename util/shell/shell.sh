#
# Common env/setup for use for other tool scripts
#

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# Print the contents of a given alias. Used for nested aliases.
alias_print() {
	alias "$1" | sed -e "s/^\s*alias $1='//" -e "s/'$//"
}

# Shorthand structure for defining arguments
alias '@ARGS=local HELP 2>/dev/null || :
while [ $# -ne 0 ]; do case "$1" in'


alias '@ARGS_UTIL=
;;
# by specifying args before @ENDARGS, you can override the following values
	-h | --help )
		local HELP 2>/dev/null || :
		HELP=true # excluding help for compatibility.

		if [ "$(type -t usage)" = function ]; then
			usage
		else
			echo >&2 "No Usage line provided. However, here are the options:"
		fi

		if [ "$(type -t options)" = function ]; then
			options
		else
			funcname -q && print_args -f "$(funcname)" || print_args
		fi

		return 0 2>/dev/null || exit 0;

		shift;
		;;
	-- )
		shift;
		break;
'

alias '@ENDARGS='"$(alias_print @ARGS_UTIL)"'
		;;
	'-*' )
		echo >&2 "Error: flag $1 not supported"
		shift
		safe_quit
		;;
	'*' ) break;
		;;
esac; done'

args_gen() {
	echo "$(alias_print @ARGS)"
	echo "$*"
	echo "$(alias_print @ENDARGS)"
}

args_gen_tail() {
	echo "$*"
	echo "$(alias_print @ENDARGS)"
}

alias "@DEFAULT_ARGS=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"

isTrue() {
	if [ $# -eq 0 ]; then
		return 2
	fi
	for bool in "$@"; do
		test "$*" = "true" || return 1
	done
}

isNull() {
	if [ $# -eq 0 ]; then
		return 2
	fi
	for val in "$@"; do
		test "$*" = "null" || return 1
	done
}


alias check_var_set='__check_var_set() {
	for var in "$@"; do
		if [ -z "${!var}" ]; then
			echo >&2 "Error: $(funcname -p 1): option '\''$var'\'' not set"
			return 1
		fi
	done
}
__check_var_set'

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
	local pair="$([ $# -eq 0 ] cat || echo $1)"
	echo "$pair" | cut -d = -f 1
}

# Returns the value for a given key value pair
value() {
	local pair="$([ $# -eq 0 ] cat || echo $1)"
	echo "$pair" | cut -d = -f 2
}

funcname() {
	local quiet parent
	@ARGS
		-q | --quiet) quiet=true
			shift
			;;
		# The number of parents above this function you want to reference
		# The function you call `funcname` from is -p 0, its caller is -p 1, etc
		-p | --parent) parent="$2"
			shift
			shift
	@ENDARGS

	# done manually since @ARGS and print_usage use funcname internally
	if isTrue $HELP; then
		echo >&2 "funcname: print the function name of the caller, or a given parent function"
		echo >&2 "Usage: funcname [options]"
		print_args -f funcname
		return 0
	fi

	parent="${parent:-0}"
	parent="$(($parent + 1))" # add this current function as another layer down

	print() {
		if [ "$quiet" != true ]; then
			echo "$@"
		fi
	}

	local parentFunc="${FUNCNAME[$parent]}"
	if [ -z "$parentFunc" ] ||
		# Happens when run in shell script
		[ "$parentFunc" = main -a -z "${FUNCNAME[$(($parent + 1))]}" ]
	then
		echo >&2 "Error: funcname: no bash function found."
		return 1
	fi
	print "$parentFunc"
}

print_usage() {
	echo >&2 "Usage: $(funcname -p 2)" "$@"
}

# Output the args of a script file
#
# given file must have a case block that parses args
# identified with an @ARGS comment at the top
print_args() {

	local function HELP
	@ARGS
		# Print args for the given function within the file
		-f | --function ) function="$2"
			shift
			shift
	@ENDARGS

	if isTrue $HELP; then
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

url_open() {
	link="$1"
	if echo "$XDG_SESSION_TYPE" | grep -qE "(x11|wayland)"; then
		xdg-open "$link"
	elif [ "$XDG_SESSION_TYPE" = tty ]; then
		echo "Open the following link in your browser:"
		echo "$link"
	else
		echo >&2 "Error: Unknown XDG type: $XDG_SESSION_TYPE"
		echo "Open the following link in your browser:"
		echo "$link"
	fi
}

fmtvar() {
	@ARGS
		-u | --upper | --upper-case | --to-upper) upperCase=true
			shift
	@ENDARGS

	# intermediate tr to '-' means existing _s are not squeezed into 1
	var="$(echo -n $1 | tr --squeeze --complement 'A-Za-z0-9_' "-" | tr - _)"

	if isTrue $upperCase; then
		var="$(echo -n $var | tr '[a-z]' '[A-Z]')"
	fi

	echo "$var"
}

#outputs an argument flag for the given variable name, if and only if that variable is set to `true`
arg_bool() {
	if isTrue ${!1}; then
		echo --"$(echo "$1" | sed 's/[A-Z]/-\L&/g')"
	fi
}

# print
case $(uname | tr '[:upper:]' '[:lower:]') in
	linux*)
		export OS=linux
		;;
	darwin*)
		export OS=mac
		;;
	msys* | windows* | cygwin*)
		export OS=windows
		;;
	*)
		export OS=unknown
		;;
esac

ip_local() {
	case $OS in
		linux) ip route get 1 | perl -ne ' /src (\S+)/ && print "$1\n" ';;
		mac) ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk 'NR == 1 {print $2}' ;;
		*) echo >&2 "Error: ip_local: Unspported operating system. Please update the function to add support."; return 1 ;;
	esac
}
alias ipl=ip_local

ip_public() {
	curl ifconfig.me
}
alias ipp=ip_public

use_tool util/shell/json.sh
use_tool util/shell/random.sh
[[ "$OS" = "linux" ]] && source_once "util/linux/linux.sh"