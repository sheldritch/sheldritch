[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function confirm {
	@func_info
	About='prompt user for yes/no and return the response as an exit code.

		If input is a pipe, will print input to user before asking.
		If output is also a pipe, will pass on input iff confirm is true.'

	Options=(
		-q --question --query --inquiry --quiz
			-p --prompt=QUESTION "the question to print to the user to get a yes/no response for"

		-d --default=DEFAULT "yes or no. the default value to return."
		-e --echo -v --verbose "print true/false based on response"
	)
	args_parse

	Prompt="${Prompt-Confirm?}"

	local Input
	if ! [ -t 0 ]; then
		debug 'piped input'
		Input="$(cat)"
		echo "$Input" >/dev/tty
	fi

	while true; do

		if [[ "$Default" ]]; then
			Default="$(yesNoToBool "$Default")"

			if [[ "$Default" = null ]]; then
				echo >&2 "Error: invalid default passed to 'confirm'"
				echo >&2 "Complain to whoever wrote the tool your using to fix it."
				echo >&2 "This applies doubly so if it was you."
				return 9
			fi
		fi

		local PromptOpts
		if [[ -z "$Default" ]]; then
			PromptOpts=y/n
		elif isTrue "$Default"; then
			PromptOpts=Y/n
		else
			PromptOpts=y/N
		fi

		local Confirm
		read -rp "${Prompt:+$(deindent "$Prompt [$PromptOpts]: ")}" Confirm < /dev/tty

		local Response
		if Response="$(yesNoToBool "${Confirm:-$Default}")"; then

			if ! [[ -t 0 || -t 1 ]]; then
				if isTrue "$Response"; then
					echo "$Input"
				fi
			elif isTrue $Verbose; then
				echo "$Response"
			fi

			isTrue "$Response"
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

