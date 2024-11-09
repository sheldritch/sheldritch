source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

use_tool util/shell/shell.sh

# Markdown Metadata from front matter
mdmd() {
	local file start end

	file="$1"
	shift
	start="$(head -n 1 "$file")"

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
			jqj "$frontMatter" "$@"
			;;
		yaml)
			echo "$frontMatter" | yq "$@"
			;;
	esac
}
