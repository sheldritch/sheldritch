#!/bin/bash
# Common helpers for database management

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

sql_query() {
	local select table where order limit
	@ARGS
		-s | --select)
			if [ -z "$select" ]; then
				select="$2"
			else
				select+=", $2"
			fi
			shift
			shift
			;;

		-t | --table) table="$2"
			shift
			shift
			;;

		-w | --where)
			if [ -z "$where" ]; then
				where="$2"
			else
				where+=" AND $2"
			fi
			shift
			shift
			;;

		-o | --order) order="$2"
			shift
			shift
			;;

		-l | --limit) limit="$2"
			shift
			shift

	@ENDARGS

	select="${select:-*}"

	local query="$(cat <<-END
		SELECT $select
			FROM $table
			${where:+WHERE $where}
			${order:+ORDER BY $order}
			${limit:+LIMIT $limit}
			;
		END
	)"
	debug "$query"
	echo "$query"
}

sqlq() { sql_query "$@"; }

sql_in() {
	usage() {
		print_usage "COLUMN_NAME [POSSIBLE_VALUES...]"
	}

	local type
	@ARGS
		--type) type="$2"
			shift
			shift
	@ARGS_END

	type="${type:-string}"

	column="$1"
	shift
	printf "\"$column\" IN ("

	while [[ $# -gt 0 ]]; do
		case "$type" in
			string) printf "'$1'";;
			column) printf "\"$1\"";;
			*) printf "$1";;
		esac
		shift
		if [[ $# -gt 0 ]]; then
			printf ", "
		fi
	done

	printf ")\n"
}
