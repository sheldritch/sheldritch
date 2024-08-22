# shellcheck disable=SC2154

source "$TOOLS"/util/shell/base.sh || return 1
check_is_sourced

use_tool util/shell/shell.sh

_args_req() {
	local arg
	for arg in $args_req; do
		if [ -z "$1" ]; then
			error -p 1 "arg '$arg' must be set"

			if var_is_local usage; then
				print_usage "$usage" >&2
			else
				print_usage "$(case_big_snake $args_req)"
			fi
			return 1
		fi

		eval "$arg"'="$1"'
		shift
	done
}

# shellcheck disable=SC2142
alias args_parse='
	if [ "$args_req" ]; then
		if ! var_is_local args_req; then
			error "INTERNAL ERR: args_req must be locally defined"
			safe_quit 9
		fi
		local $args_req
		_args_req "$@" || safe_quit $?
	fi
'

