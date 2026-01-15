[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function mdmd {
	local file start end

	@help '
	parse markdown metadata from front matter
	Usage: mdmd FILE YQ_ARGS...
	' && return

	file="$1"
	shift
	start="$(head -n 1 -- "$file")"

	case "$start" in
		'{' )
			end='}'
			type=json
			;;
		'---' )
			end='---'
			type=yaml
			;;
		* )
			echo >&2 "Error: type of front matter starting with the following is currently unsupported"
			echo >&2 "$start"
			;;
	esac

	frontMatter="$(awk "
		/^$end$/ { frontMatter=0 }
		frontMatter { print }
		NR == 1 { frontMatter=1 }
		" "$file")"

	case "$type" in
		json)
			echo "$frontMatter" | jq "$@"
			;;
		yaml)
			echo "$frontMatter" | yq "$@"
			;;
	esac
}
