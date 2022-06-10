#!/bin/bash
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

_completion_repo_list() {
	COMPREPLY=($(compgen -W "$(repo_list)" -- "${COMP_WORDS[COMP_CWORD]}"))
}

# print the directory for a given repo
repo_dir() {
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
	cd "$(repo_dir "$1")"
}

complete -F _completion_repo_list repo
