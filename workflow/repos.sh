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

# Will try and cd directly into a repo folder from anywhere on the machine, defaulting to
# the parent 'repos' folder if no suitable repo can be found (not provided or doesn't exist)
repo() {
	local repo
	repo=$(
		IFS=:
		for repoDir in $REPOS; do
			if [ -d "$repoDir/$1" ]; then
				echo "$repoDir/$1"
				break
			fi
		done
	)

	repo="${repo:-$(echo "$REPOS" | cut -d: -f1)}"
	cd "$repo"
}

complete -F _completion_repo_list repo
