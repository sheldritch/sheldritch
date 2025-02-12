#!/bin/bash
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args.sh

function now { echo "$(date +%s.%N)"; }

function table_date_comp {
	@func_info
	About='prints all rows from stdin'
	Usage='OPERATOR DATE'
	Options=(
		-f --field=FIELD "integer. the column position containing the time, starting from one"
	)

	Field="${Field:-NF}"

	case "$Operator" in
		lt ) Operator='<';;
		gt ) Operator='>';;
		* )
			error 'Did not receive any arguments! did you accidentally do file direction instead of greater/less than?'
			return 9
	esac

	awk -F '( *\t+ *| {2,})' -v DEBUG="$DEBUG" '
		function Date(str, regex) {
			if (regex) {
				match(str, regex)
				if (RLENGTH == -1) { return }
				str = substr(str, RSTART, RLENGTH)
			}
			if (!str) { return }

			if (1) { quiet="2>/dev/null" }
			"date +%s -d \""str"\" "quiet" || :" | getline times[str]

			if (DEBUG) { print "input date: "str", output date: "times[str]  }

			return times[str]
		}

		function Duration(date) {
			if (date !~ /^[+-]( *[0-9]*(w|d|h|m|s) *)+$/)
				return

			gsub(/[0-9]w/, "&eeks ", date)
			gsub(/[0-9]d/, "&ays ", date)
			gsub(/[0-9]h/, "&ours ", date)
			gsub(/[0-9]m/, "&inutes ", date)
			gsub(/[0-9]s/, "&econds ", date)

			if (gsub(/^ *-/, "", date)) {
				gsub(/[0-9]+/, "-&", date)
			}

			return Date(date)
		}

		function Epoch(date) {
			#if (date !~ /[0-9]/) { date="now" }

			if (result = Duration(date)) return result
			if (result = Date(date))     return result

			if (result = Date(date, "^.*[+-][0-9]{4}")) return result
			if (result = Date(date, "[0-9]*-[0-9]*-[0-9]*[ T][0-9]*:[0-9]*:[0-9]*[-0-9 T.:/PM]*")) return result

			return 0
		}
		BEGIN { date = Epoch("'"$Date"'") }
		Epoch($'"$Field"') && date '"$Operator"' Epoch($'"$Field"')
	'
}
