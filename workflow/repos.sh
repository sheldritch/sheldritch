#!/bin/bash
# move around between certain repos

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/util/complete

# Directories storing repos
if [[ -z "${REPOS:-}" ]]; then
	# sensibly set REPO_DIR based on the first existing directory
	# Feel free to add your own repo here
	for dir in "$HOME"/{repos,git,code,projects}; do
		if [[ -d "$dir" ]]; then
			[[ -z "${REPOS:-}" ]] && REPOS="$dir" || REPOS="$REPOS:$dir"
		fi
	done
fi

function repo_list {
	@func_info
	About='Print directories from all repos

	Searches directories in the :-separated REPOS environment variable.
	'
	opts_parse

	local repoDir
	(
	IFS=:
	for repoDir in ${REPOS:-}; do
		complete_file_path "$repoDir" "$1"
	done
	) | grep /$ | sort -u
}

function _complete_repo_list {
	COMPREPLY=($(compgen -W "$(repo_list ${COMP_WORDS[COMP_CWORD]})" -- "${COMP_WORDS[COMP_CWORD]}"))
}

# print the directory for a given repo
function repo_dir {
	@func_info
	About='Print the path for the given repo

	Searches directories in the : separated REPOS environment variable.
	'
	Usage='REPO'
	args_parse

	zsh_run setopt sh_word_split
	local Found
	Found="$(
		IFS=:
		for repoDir in ${REPOS:-}; do
			if [[ -d "$repoDir/$Repo" ]]; then
				echo "$repoDir/$Repo"
				break
			fi
		done
	)"
	echo "$Found"
	zsh_run unsetopt sh_word_split
	test -d "$Found"
}

# Will try and cd directly into a repo folder from anywhere on the machine
function repo {
	@func_info
	About='Change the working directory to the given repo.

	Searches directories in the : separated REPOS environment variable.
	'
	Usage='REPO'
	args_parse

	if ! dir="$(repo_dir "$1")"; then
		error "could not find directory '$1' in repos."
		return 2
	fi

	cd "$dir/$2"
}

function _complete_repo {
	_complete_repo_list
	bash_run compopt -o nospace
}

complete -F _complete_repo repo
