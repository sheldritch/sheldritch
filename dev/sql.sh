#!/bin/bash
# Common helpers for database management

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function sql_query {
	local select table where order limit
	while [ $# -ne 0 ]; do
		case "$1" in

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
			;;

		-- )
			shift
			break
			;;
		* ) break
			;;
		esac
	done


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

function sqlq { sql_query "$@"; }

function sql_in {
	@func_info
	About='Check if COLUMN_NAME is one of the given values.
		Possible values maybe of a given type provided via --type.
	'
	Usage="COLUMN_NAME [POSSIBLE_VALUES...]"
	Options=(-t --type "Defaults to string. The type of the possible values. If 'column', references
		the value of the column instead.")
	opts_parse

	Column="$1"
	shift
	printf "\"$Column\" IN ("

	while [[ $# -gt 0 ]]; do
		case "$Type" in
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
