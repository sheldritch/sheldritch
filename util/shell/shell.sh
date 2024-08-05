#
# Common env/setup for use for other tool scripts
#

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

# Print the contents of a given alias. Used for nested aliases.
alias_print() {
	eval "alias=$(alias $1 | sed -E 's/^(alias )?'"$1"'=//' )"
	echo "$alias"
}

# for all defined functions, create an alias replacing the given extended regex
# with the given match
alias_funcs() {
	functionMatch="$1"
	replacement="$2"

	alias $(funcs | sed -E -n "s/.*/&=&/; s/$functionMatch/$replacement/p")
}

isFunction() {
	if [ "$BASH_VERSION" ]; then
		test "$(type -t $1)" = function
	elif [ "$ZSH_VERSION" ]; then
		test "$(whence -w)" = function
	fi
}

zsh_run unsetopt GLOB

# Shorthand structure for defining arguments
ARGS='
local HELP >/dev/null 2>/dev/null || :
while [ $# -ne 0 ]; do case "$1" in '
alias '@ARGS'="$ARGS"


local ARGS_UTIL='
;;
# by specifying args before @ARGS_END, you can override the following values
	-h | --help )
		local HELP >/dev/null 2>/dev/null || :
		HELP=true # excluding help for compatibility.

		if isFunction usage; then
			usage
		else
			echo >&2 "No Usage line provided. However, here are the options:"
		fi

		if isFunction options; then
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
alias @ARGS_UTIL="$ARGS_UTIL"

local ARGS_END_PASSTHROUGH="$ARGS_UTIL"'
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
esac; done'
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

alias "@DEFAULT_ARGS=$( args_gen "@ARGS_DEFAULT_ARGS_ONLY )" )"

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

zsh_run setopt GLOB

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

item() {
	usage() {
		print_usage "perform a check or operation of a single value against a given list"
	}
	@ARGS_DEFAULT
	local item="$1" operator="$2"
	shift 2 || return 1

	case "$operator" in
		not)
			item "$item" "$@"
			local exit="$?"
			case $exit in
				9) return 9;;
				0) return 1;;
				*) return 0;;
			esac
			;;
		in)
			for element in "$@"; do
				if [[ "$element" = "$item" ]]; then
					return 0
				fi
			done
			;;
		*)
			error "operator '$operator' not supported"
			echo >&2 "  Inside function '$(funcname -p 1 )'"
			return 9
	esac
	return 1 # If ya wanted tuh succeed ya shoulda done it earlia!!
}


# shellcheck disable=SC1056
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

	for i in $(seq ${#ignoreIfEscaped[@]}); do
		# prevent escaped characters from being encoded
		preProc+='s/\\'${ignoreIfEscaped[@]:$i:1}'/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/g; '

		postProc+='s/~URL_ENCODE_UNESCAPED_CHAR_'$i'~/\'${ignoreIfEscaped[@]}'/g; '
	done

	for i in $(seq ${#ignoreIfEscaped[@]}); do
		# _prevent_ un-escaped characters from being encoded
		preProc+='s/([^\\])'${encodeIfEscaped[@]:$i:1}'/\1~URL_ENCODE_ESCAPED_CHAR_'$i'~/g; '
		# remove extra escape from chars to be encoded
		preProc+='s/\\('${encodeIfEscaped[@]:$i:1}')/\1/g; '

		postProc+='s/~URL_ENCODE_ESCAPED_CHAR_'$i'~/\'${encodeIfEscaped[@]:$i:1}'/g; '
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
	usage() {
		echo "confirm: prompt user for yes/no and return the response as an exit code."
		print_usage "[args...]"
		echo
		echo "If input is a pipe, will print input to user before asking."
		echo "If output is also a pipe, will pass on input iff confirm is true."
	}
	local question default echo
	@ARGS
		-q | --question | --query | --inquiry | --quiz \
			| -p | --prompt \
		) question="$2"
			shift
			shift
			;;
		-d | --default ) default="$2"
			shift
			shift
			;;
		# print true/false based on response
		-e | --echo | -v | --verbose ) echo=true
			shift
	@ARGS_END

	local input
	if ! [ -t 0 ]; then
		debug 'confirm: piped input'
		input="$(cat)"
		echo "$input" >/dev/tty
	fi

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

		read -rp "${question:+$question [$promptOpts]: }" TOOLS_CONFIRM < /dev/tty

		local response
		if response="$(yesNoToBool "${TOOLS_CONFIRM:-$default}")"; then

			if ! [ -t 0 -o -t 1 ]; then
				if isTrue "$response"; then
					echo "$input"
				fi
			elif isTrue $echo; then
				echo "$response"
			fi

			isTrue "$response"
			return $?
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
	read -rp "Do you wish to make these changes? (y/N): " confirm
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

funcs() {
	if [ "$ZSH_VERSION" ]; then
		print -l ${(ok)functions}
	else
		declare -F | awk '{print $3}'
	fi
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
	@ARGS_END

	# done manually since @ARGS and print_usage use funcname internally
	if [ "$HELP" = true ]; then
		echo >&2 "funcname: print the function name of the caller, or a given parent function"
		echo >&2 "Usage: funcname [options]"
		print_args -f funcname
		return 0
	fi

	parent="${parent:-0}"
	parent="$(($parent + 1))" # this function, `funcname`, counts as an additional layer

	print() {
		if [ "$quiet" != true ]; then
			echo "$@"
		fi
	}

	local parentFunc="${FUNCNAME[$parent]}${funcstack[@]:$parent:1}"
	if [ -z "$parentFunc" ] ||
		# Happens when run in shell script
		[ "$parentFunc" = main -a -z "${FUNCNAME[$(($parent + 1))]}${funcstack[@]:$(($parent + 1)):1}" ]
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
	@ARGS_END

	if isTrue $HELP; then
		echo >&2 "Usage: print_args [...args] [filename]"
		HELP=false print_args -f print_args
		debug "help is $HELP"
		return
	fi

	local file="$1"

	if [ -z "$file" ]; then
		if [ "$BASH_VERSION" ]; then
			file="${BASH_SOURCE[-1]}" # [1] is the context that called this function.
		elif [ "$ZSH_VERSION" ]; then
			file="$(echo "$funcfiletrace[1]" | sed 's/:[0-9]*$//')"
		else
			echo >&2 "Error: print_args: shell not supported. Please run --help from in bash."
		fi
	fi

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
		/(esac|@ARGS_END)/q;
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
		return
	fi

	echo >&2 "Trying to open link in your browser..."
	echo >&2 "If you don't see the browser open up, manually open the following link in your browser:"
	echo >&2 "$link"

	if grep -sq enabled /proc/sys/fs/binfmt_misc/WSLInterop; then
		(cd /mnt/c || cd /c && cmd.exe /c start "$link")
	elif command -v xdg-open ; then
		xdg-open "$link"
	else
		echo >&2 "Error: no link opener available. Please do so manually."
	fi
}

fmtvar() {
	@ARGS
		-u | --upper | --upper-case | --to-upper) upperCase=true
			shift
	@ARGS_END

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
	msys* | windows* | cygwin* | mingw*_nt-*)
		export OS=windows
		;;
	*)
		export OS=unknown
		;;
esac

alias '@OS_CASE=case "$OS" in'

zsh_run unsetopt GLOB
alias '@OS_CASE_END_ERROR=
		;;
	'*' )
		echo >&2 "Error: OS $OS not supported"
		safe_quit
		;;
esac'
zsh_run setopt GLOB

if [ $OS = mac ] && ! command -v brew >/dev/null; then
	echo >&2 "Error: Homebrew not found in Mac install. Ensure it is installed and initialised before using the tools repo."
	return 1
fi

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

quiet() { "$@" >/dev/null 2>/dev/null; }
stderr() { "$@" >&2; }
error() {
	local prefix
	if funcname -p 1 -q; then
		prefix="$(funcname -p 1): "
	fi
	echo "Error: $prefix$*" >&2
}

function su_write() {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null "$1"
}

function su_append() {
	if [ $# -ne 1 ]; then
		error "requires one file name as argument"
		return 1
	fi
	sudo tee > /dev/null -a "$1"
}

use_tool util/shell/json.sh
use_tool util/shell/random.sh
[[ "$OS" = linux ]] && use_tool util/linux/linux.sh || :
