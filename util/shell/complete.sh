# Returns a list of paths in dir '$1' that start with '$2'
# Directories are ended with '/', and files are not.
complete_file_path() {
	local directory path
	directory="$1"
	path="$2"

	(
	cd "$directory"

	for file in "$path"*; do
		if [ $(echo -n "$file" | wc -l) -gt 0 ]; then
			echo >&2 "Error: new-line found in matches!"
			echo >&2 "Cannot provide file path list."
			return 3
		fi

		if [ -d "$file" ]; then
			echo "$file/" 
		elif [ -f "$file" ]; then
			echo "$file"
		fi
	done
	)
}

# Example use of the function above
_complete_file_path() {
	local IFS=$'\n'
	COMPREPLY=($(complete_file_path . ${COMP_WORDS[COMP_CWORD]}))

	if ! [ "${#COMPREPLY[@]}" -eq 1 -a -f "${COMPREPLY[0]}" ]; then
		compopt -o nospace
	fi
}
# To auto-complete itself
complete -F _complete_file_path complete_file_path
