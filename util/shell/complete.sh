source "$TOOLS/util/shell/base.sh" || return 1

check_is_sourced

# Returns a list of paths in dir '$1' that start with '$2'
# Directories are ended with '/', and files are not.
complete_file_path() {
	local directory Path
	directory="$1"
	Path="$2"

	(
	cd "$directory" || return 1

	for file in "$Path"*; do
		if [[ "$file" =~ $'\n' ]]; then
			echo >&2 "Error: new-line found in matches! '$file'"
			echo >&2 "Cannot provide file path list."
			return 3
		fi
		if [[ "$file" =~ (\\Q|\\E) ]]; then
			echo >&2 "Error: \Q or \E found in matches."
			echo >&2 "Cannot provide file path list."
			return 3
		fi
	done
	ls -p | grep -P "^\Q$Path\E"
	)
}

# Example use of the function above
_complete_file_path() {
	local IFS=$'\n'
	COMPREPLY=($(complete_file_path . ${COMP_WORDS[COMP_CWORD]}))

	if ! [ "${#COMPREPLY[@]}" -eq 1 -a -f "${COMPREPLY[0]}" ]; then
		bash_run compopt -o nospace
	fi
}
# To auto-complete itself
complete -F _complete_file_path complete_file_path
