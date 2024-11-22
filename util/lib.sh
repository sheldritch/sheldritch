#
# Functions for importing and handling shell scripts like libraries
#

source_once() {
	local Path="$1"
	if ! [[ "$Path" = /* ]]; then
		Path="$(realpath -s "$1")"
	fi

	if [[ "$SHELDRITCH_SOURCES" = *"$Path"* ]]; then
		_trace "source_once: skipping export '$Path': Already sourced"
		return
	fi

	if [[ -x "$Path" ]]; then
		echo >&2 "Error: $Path is an executable, presumably not a sourced file."
		return 1
	fi

	SHELDRITCH_SOURCES+="$(echo -e "\n$Path")" # before source to prevent dependency loops
	_trace "source_once: sourcing '$Path'"
	_trace ""
	_trace "sources currently:"
	_trace "$SHELDRITCH_SOURCES"
	source "$1"
}

# imports the given library/file (relative to the library dir)
summon() {
	local HELP FORCE
	while [[ $# -ne 0 ]]; do
		case "$1" in
			-f | --force ) FORCE=true
				shift
				;;
			-h | --help ) HELP=true
				shift
				break
				;;
			* ) break
				;;
		esac
	done

	SHELDRITCH_RESET="$FORCE"

	if [[ "$HELP" = true ]]; then
		echo >&2 "summon -- imports the library/file (relative to the library dir)"
		echo >&2 "Usage: summon [--force] <lib>"
	fi

	for lib in "$@"; do
		lib="$SHELDRITCH/$lib"

		if [[ "$SHELDRITCH_SOURCES" = *"$lib"* ]]; then
			continue
		fi

		if [[ -d "$lib" ]]; then
			_trace "Importing tools in directory '$lib'"
			export PATH="$(find "$lib" -type d -printf "%p:")$PATH"
			source_once "$lib"/*
		elif [[ -x "$lib" ]]; then
			_trace "Importing executable lib '$lib'"
			# shellcheck disable=SC2139
			alias "$(basename "$lib")=$lib"
		else
			if [[ "$SHELDRITCH_RESET" = true ]]; then
				_trace "Force source lib '$lib'"
				source "$lib"
			else
				source_once "$lib"
			fi
		fi
	done

	if [[ "$FORCE" ]]; then
		SHELDRITCH_RESET=""
	fi

}

# shellcheck disable=SC2142
alias script_is_sourced='{ [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; }'

# shellcheck disable=SC2139
alias check_is_sourced="if ! script_is_sourced; then
	echo \"You aren't sourcing ${0}. Make sure you are to have its libs available to you.\"
	exit 1
fi"
check_is_sourced

check_is_sourced_func() {
	if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "$ZSH_EVAL_CONTEXT" = toplevel ]]; then
		echo "You aren't sourcing ${0}. Make sure you are to have its libs available to you."
		exit 1
	fi
}

