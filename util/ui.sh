source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function confirm {
	function usage {
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

		local confirm
		read -rp "${question:+$question [$promptOpts]: }" confirm < /dev/tty

		local response
		if response="$(yesNoToBool "${confirm:-$default}")"; then

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
function diff_confirm {

	diff="$(diff -yt "$@")"

	if [ "$?" -eq 0 ]; then
		echo "No changes were made -- automatically aborting." >&2
		return 1
	fi

	echo "$diff" | grep --color=always -E '^.{64}(\||>|<).*|$' # use grep to highlight lines with changes
	read -rp "Do you wish to make these changes? (y/N): " confirm
	test "$confirm" = "y"
}

