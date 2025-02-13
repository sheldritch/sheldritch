#!/bin/bash
#
# helpers relating to the XDG OpenDesktop specification
#
# This is a no-dependency file.

function xdg {
	typeset data="${XDG_DATA_HOME:-$HOME/.local/share}" config="${XDG_CONFIG_HOME:-$HOME/.config}"
	case "$1" in
		--help       ) printf '%s\n%s\n' 'Usage: xdg DIR_TYPE' 'https://specifications.freedesktop.org/basedir-spec/latest/';;
		cache        ) printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}";;
		config       ) printf '%s\n' "$config";;
		config-dirs  ) printf '%s\n' "${config:+$config:}${XDG_CONFIG_DIRS:-/etc/xdg}";;
		data         ) printf '%s\n' "$data";;
		data-dirs    ) printf '%s\n' "${data:+$data:}${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}";;
		runtime      ) printf '%s\n' "${XDG_RUNTIME_HOME:-/tmp}";;
		state        ) printf '%s\n' "${XDG_STATE_HOME:-$data}";;
		*            ) return 1
	esac
}

function xdg_search {
	typeset dir type delim='\n'
	case "$1" in
		-0 | --zero ) delim='\0'
			shift 1 || return 1
			;;
		-d | --delimiter ) delim="$2"
			if [[ -z "$delim" ]]; then
				echo >&2 "Error: xdg_search: no delimiter passed to -d"
				return 1
			fi
			shift 2
			;;
	esac

	type="$1" 
	shift
	while read -rd : dir; do
		for Path in "$@"; do
			if [[ -e "$dir/$Path" ]]; then
				printf "%s$delim" "$dir/$Path"
			fi
		done
	done < <(xdg "$type")
}
