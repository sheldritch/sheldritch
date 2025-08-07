#!/bin/bash
# meta-utilities for modifying sheldritch libraries

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/data/text
summon sheldritch/util/complete.sh

# TODO: this file is broken

# this should be easy to abstract generally
function lib_list {
	(
	IFS=:
	for Dir in ${REPOS:-}; do
		complete_file_path "$Dir" "$1"
	done
	) | sort -u
}

function _complete_sheldritch_lib {
	bash_run compopt -o nospace
	COMPREPLY=($(compgen -W "$(lib_list ${COMP_WORDS[COMP_CWORD]})" -- "${COMP_WORDS[COMP_CWORD]}"))
}

complete -F _complete_sheldritch_lib summon

function be_summoned_by {
	cd "$(lib_find "$1")"
}
function bsb { @func_passthrough; be_summoned_by "$@"; }
complete -F _complete_sheldritch_lib be_summoned_by

function transmute {
	@func_info
	About='mutate the essential being of a sheldritch library
	(Find a file in one of your library directories and open it in your editor)

	Also works with a unique file name, e.g. "tool_edit ldap.sh"
	'
	Usage=(
		PATHS...
		#'--function=SHELL_FUNCTION_NAME'
	)
	Options=(
		-f --function=FUNCTION "The name of the function to open"
		-w --workspace=WORKSPACE "Select a directory to run the editor from. Defaults to a library's root dir"
	)
	args_parse

	array_map Paths lib_find || return 1

	zsh_run setopt KSH_ARRAYS

	(
	IFS=:
	for Path in $(lib_paths); do
		if [[ "${Paths[0]}" == "$Path"* ]]; then
			cd "$Path" || return 3
			break
		fi
	done

	if [ -z "$EDITOR" ]; then
		error "\$EDITOR is not set. Please add it to your rc file."
		exit 1
	fi

	$EDITOR "${Paths[@]}" || exit 2
	) || return $?
	lib_use --force "${Paths[@]}"
	for __Path in "${Paths[@]}"; do
		source "$__Path"
	done
	return

	local FirstFileAndLine
	declare -a files
	declare -a args

	if [[ -n "$Function" ]]; then
		local file= matches=
		matches="$(cd "$TOOLS"; grep -rno -e "^$function(" -e "^alias $function=")"

		if lines_none "$file"; then
			matches="$(cd "$TOOLS"; grep -rno "$function\w*(")"
		fi

		file="$(echo "$matches" | cut -d : -f 1 | sort -u)"

		if ! lines_one "$file"; then
			echo >&2 "Error: tool_edit: could not find single file location for '$function()':"
			echo >&2 "$file"
			return 1
		fi
		Paths+=("$file")

		FirstFileAndLine="${FirstFileAndLine:-$(echo "$matches" | awk -F : 'NR == 1 { print $1":"$2 }')}"
	fi

	for Path in "${Paths[@]}"; do
		matches="$(find "$TOOLS"/* -path "*$Path*")"

		debug matches: "\n$matches"
		if lines_one "$matches"; then
			files+=("$matches")
		elif matches="$(echo "$matches" | grep /$Path)" \
			&& lines_one "$matches"
		then
			files+=("$matches")
		else
			files+=("$TOOLS/$Path")
		fi
	done

	if [ "$FirstFileAndLine" ]; then
		case "$EDITOR" in
			vim*) args+=(
				+$(echo "$FirstFileAndLine" | cut -d : -f 2)
				'+normal zz'
			)
				;;
			code*) args+=(-g $FirstFileAndLine)
				;;
		esac
	fi

	(
	cd "${workspace:-$TOOLS}"

	$EDITOR "${args[@]}" "$@" "${files[@]}"
	)
}
complete -F _complete_sheldritch_lib transmute
