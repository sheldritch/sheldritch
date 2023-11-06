#
# Common env/setup for use for other tool scripts
#

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# Print the contents of a given alias. Used for nested aliases.
alias_print() {
	alias "$1" | sed -e "s/^\s*alias $1='//" -e "s/'$//"
}

# for all defined functions, create an alias replacing the given extended regex
# with the given match
alias_funcs() {
	functionMatch="$1"
	replacement="$2"
	for func in $(declare -F | awk '$3 ~ /'"$functionMatch"'/ { print $3; }'); do
		alias $(echo $func | sed -E "s/$functionMatch/$replacement/")=$func
	done
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
	--*=* ) 
		key="$(key "$1")"
		value="$(value "$1")"
		shift;
		set "$key" "$value" "$@"
		continue;
		;;
	-- )
		shift;
		break;
'

alias '@ARGS_END='"$(alias_print @ARGS_UTIL)"'
		;;
	'-*' )
		echo >&2 "Error: flag $1 not supported"
		shift
		safe_quit
		;;
	'*' ) break;
		;;
esac; done'

alias '@ENDARGS='"$(alias_print @ARGS_END)"

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
		if [ -z "$bool" -o "$bool" = false ]; then
			return 1
		fi

		if [ "$bool" != true ]; then
			echo >&2 "Warning!: isTrue argument '$bool' is not 'true', 'false' or ''!"
			echo >&2 "!!!"
			echo >&2 "inside function $(funcname -p 1)"
			sleep 1
			return 1
		fi
	done
}

anyTrue() {
	if [ $# -eq 0 ]; then
		return 2
	fi
	for bool in "$@"; do
		test "$bool" = "true" && return 0
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

args_or_stdin() {
	local args
	if [ $# -eq 0 ]; then
		if [ -t 0 ]; then
			echo >&2 "Error: $(funcname -p 1) run with no args, but nothing piped in"
			return 1
		fi
		args="$(cat)"
	else
		args="$*"
	fi
	echo "$args"
}

contains() {
  local match="$1"
  shift

  for element in "$@"; do
	  if [ "$element" = "$match" ]; then
		  return 0
	  fi
  done
  return 1
}

url_encode() {
	usage() {
		print_usage "[options] [TEXT_TO_ENCODE...]"
	}

	declare -a encodeIfEscaped ignoreIfEscaped onlyEncode
	@ARGS
		# If specified, only encode the characters that appear in this argument.
		#
		# Each argument may contain either multiple non-whitespace characters separated by whitespace,
		# or a single whitespace character.
		#
		# May work in conjunction with --only-if-escaped or --ignore-escaped.
		-o | --only | --only-encode)
			if [ $(echo -n "$2" | wc -c) -eq 1 ]; then
				onlyEncode+=("$2")
			else
				onlyEncode+=($2)
			fi
			shift
			shift
			;;

		# Only encode the given character if it's escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--only-if-escaped) encodeIfEscaped+=($2)
			shift
			shift
			;;

		# Only encode the given character if it's NOT escaped with '\'
		# Multiple characters may be given if separated by whitespace
		--ignore-escaped) ignoreIfEscaped+=($2)
			shift
			shift

	@ARGS_END

	local args="$(args_or_stdin "$@")"

	if [ "$onlyEncode" ]; then
		local encodeChars

		# Find and replace individual characters with their encoded form
		for char in "${onlyEncode[@]}"; do
			local encoded matchPrefix replacePrefix
			encoded="$(url_encode "$char")"

			if contains "$char" "${encodeIfEscaped[@]}"; then
				matchPrefix='\\'

			elif contains "$char" "${ignoreIfEscaped[@]}"; then
				matchPrefix='([^\\])'
				replacePrefix='$1'
			fi

			encodeChars+="s/$matchPrefix\\Q$char\\E/$replacePrefix$encoded/g; "
			# remove leading slash from any remaining non-encoded instances
			encodeChars+='s/\Q\'"$char"'\E/'"$char"'/g; '
		done

		echo "$args" | perl -pe "$encodeChars"
		return $?
	fi

	# pre/post-processing
	local preProc postProc

	# escape single quotes, because we use them inside python.
	preProc+='s/\\'\''/'\\\''/g; '

	for i in "${!ignoreIfEscaped[@]}"; do
		# prevent escaped characters from being encoded
		preProc+='s/\\'${ignoreIfEscaped[$i]}'/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/g; '

		postProc+='s/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/\'${ignoreIfEscaped[$i]}'/g; '
	done

	for i in "${!encodeIfEscaped[@]}"; do
		# _prevent_ un-escaped characters from being encoded
		preProc+='s/([^\\])'${encodeIfEscaped[$i]}'/\1~URL_ENCODE_ESCAPED_CHAR_'$i'~/g; '
		# remove extra escape from chars to be encoded
		preProc+='s/\\('${encodeIfEscaped[$i]}')/\1/g; '

		postProc+='s/~URL_ENCODE_ESCAPED_CHAR_'$i'~/\'${encodeIfEscaped[$i]}'/g; '
	done

	echo "'$args'" \
		| perl -pe "$preProc" \
		| xargs -I {} python3 -c "import sys, urllib.parse as ul; print (ul.quote('{}'))" \
		| perl -pe "$postProc"
}

url_decode() {
	python3 -c "import sys, urllib.parse as ul; print (ul.quote('$*'))"
}

find_bin() {
	for x in ${PATH//://*${1}* }*${1}*; do
		[ -f "$x" ] && echo $x
	done
}

yesNoToBool() {
	case "$1" in
		[yY] | [Yy]es | true | correct) echo "true"
			;;
		[nN] | [Nn]o | false | incorrect) echo "false"
			;;
		*)
			echo "null"
			return 1
			;;
	esac
}

confirm() {
	local question default
	@ARGS
		-q | --question | --query | --inquiry | --quiz | -p | --prompt) question="$2"
			shift
			shift
			;;
		-d | --default ) default="$2"
			shift
			shift
	@ENDARGS

	while true; do

		if [ "$default" ]; then
			default="$(yesNoToBool "$default")"

			if [ "$default" = null ]; then
				echo >&2 "Error: invalid default passed to 'confirm'"
				echo >&2 "Complain to whoever wrote the tool your using to fix it."
				echo >&2 "This applies doubly so if it was you."
				return 9
			fi
		fi

		local promptOpts
		if [ -z "$default" ]; then
			promptOpts=y/n
		elif isTrue "$default"; then
			promptOpts=Y/n
		else
			promptOpts=y/N
		fi

		read -p "${question:+$question [$promptOpts]: }" TOOLS_CONFIRM

		local response
		if response="$(yesNoToBool "$TOOLS_CONFIRM")"; then
			echo "$response"
			return
		fi

		if [ -z "$TOOLS_CONFIRM" -a -n "$default" ]; then
			echo "$default"
			return
		fi

		echo >&2 "Error: Please reply 'yes' or 'no'"
		echo >&2

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
	local pair="$([ $# -eq 0 ] && cat || echo $1)"
	echo "$pair" | cut -d = -f 1
}

# Returns the value for a given key value pair
value() {
	local pair="$([ $# -eq 0 ] && cat || echo $1)"
	value="$(echo "$pair" | cut --only-delimited -d = -f 2)"
	test "$value" || return 2
	echo "$value"
}

# WARNING!
# funcname should not use any helper functions internally
# except print_args
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
	if [ "$HELP" = true ]; then
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
		print >&2 "Error: funcname: no bash function found."
		return 1
	fi
	print "$parentFunc"
}

print_usage() {
	local name
	name="$(funcname -p 2 2>/dev/null)"
	name="${name:-$0}"
	echo >&2 "Usage: $name" "$@"
}

# Output the args of a script file
#
# given file must have a case block that parses args
# identified with an @ARGS comment at the top
#
# WARNING: print_args must NOT use `funcname` internally.
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
	if [ "$XDG_SESSION_TYPE" = tty ]; then
		echo >&2 "Open the following link in your browser:"
		echo >&2 "$link"
	elif command -v xdg-open ; then
		echo >&2 "Trying to open link in your browser."
		echo >&2 "If you don't see the browser open up, manually open the following link in your browser:"
		xdg-open "$link"
		echo >&2 "$link"
	else
		echo >&2 "Error: Unknown XDG type: $XDG_SESSION_TYPE"
		echo >&2 "Open the following link in your browser:"
		echo >&2 "$link"
	fi
}

fmtvar() {
	@ARGS
		-u | --upper | --upper-case | --to-upper) upperCase=true
			shift
	@ENDARGS

	# intermediate tr to '-' means existing _s are not squeezed into 1
	var="$(echo -n $1 | tr -c -s 'A-Za-z0-9_' "-" | tr -- - _)"

	if isTrue $upperCase; then
		var="$(echo -n $var | tr '[a-z]' '[A-Z]')"
	fi

	echo "$var"
}

# Outputs an argument flag for the given variable name, if and only if that variable is set to `true`
arg_bool() {
	if isTrue ${!1}; then
		echo --"$(echo "$1" | sed 's/[A-Z]/-\L&/g')"
	fi
}

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

alias '@OS_CASE=case "$OS" in'

alias '@OS_CASE_END_ERROR=
		;;
	'*' )
		echo >&2 "Error: OS $OS not supported"
		safe_quit
		;;
esac'

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

now() { echo "$(date +%S.%N)"; }

use_tool util/shell/json.sh
use_tool util/shell/random.sh
[[ "$OS" = linux ]] && use_tool util/linux/linux.sh
