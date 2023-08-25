# move around between certain repos

repo_list() {
	local repos
	(
	IFS=:
	for repoDir in $REPOS; do
		cd "$repoDir"
		repos+="$(echo */.git) "
	done
	echo $repos | tr ' ' '\n' | sort -u | sed 's_/\.git__g'
	)
}

alias @complete_repo_list='COMPREPLY=($(compgen -W "$(repo_list)" -- "${COMP_WORDS[COMP_CWORD]}"))'

_complete_repo_list() {
	@complete_repo_list
}

# print the directory for a given repo
repo_dir() {
	if [ -z "$1" ]; then return 1; fi

	local repo
	repo="$(
		IFS=:
		for repoDir in $REPOS; do
			if [ -d "$repoDir/$1" ]; then
				echo "$repoDir/$1"
				break
			fi
		done
	)"
	echo "$repo"
}

# Will try and cd directly into a repo folder from anywhere on the machine
repo() {

	if ! dir="$(repo_dir "$1")"; then
		cd "$(echo "$REPOS" | sed 's/:.*//')"
		return
	fi

	cd "$dir/$2"
}

_complete_repo() {
	local cur="${COMP_WORDS[COMP_CWORD]}"

	if [ $COMP_CWORD = 1 ]; then
		@complete_repo_list

	else
		local IFS=$'\n'
		COMPREPLY=($(complete_file_path "$(repo_dir "${COMP_WORDS[1]}")" "$cur"))
	fi

	if ! [ "${#COMPREPLY[@]}" -eq 1 -a -f "${COMPREPLY[0]}" ]; then
		compopt -o nospace
	fi
}

complete -F _complete_repo repo
