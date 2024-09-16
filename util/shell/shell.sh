#
# Common env/setup for use for other tool scripts
#

# shellcheck disable=SC1009,SC1073,SC1072
source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

use_tool util/shell/args.sh
use_tool util/shell/types.sh
use_tool util/system/system.sh

# Print the contents of a given alias. Used for nested aliases.
alias_print() {
	eval "alias=$(alias $1 | sed -E 's/^(alias )?'"$1"'=//' )"
	echo "$alias"
}

find_bin() {
	for x in ${PATH//://*${1}* }*${1}*; do
		[ -f "$x" ] && echo $x
	done
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

# TODO: replace with args.sh case_
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

if [ $OS = mac ] && ! command -v brew >/dev/null; then
	echo >&2 "Error: Homebrew not found in Mac install. Ensure it is installed and initialised before using the tools repo."
	return 1
fi

now() { echo "$(date +%s.%N)"; }

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
[[ -f util/system/$OS.sh ]] && use_tool util/system/$OS.sh
