#!/bin/bash
# move around between certain repos

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/util/complete.sh

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
	About='print directories from all repos'
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
	if [[ -z "$1" ]]; then return 1; fi

	zsh_run setopt sh_word_split
	local repo
	repo="$(
		IFS=:
		for repoDir in ${REPOS:-}; do
			if [[ -d "$repoDir/$1" ]]; then
				echo "$repoDir/$1"
				break
			fi
		done
	)"
	echo "$repo"
	zsh_run unsetopt sh_word_split
	test -d "$repo"
}

# Will try and cd directly into a repo folder from anywhere on the machine
function repo {

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
