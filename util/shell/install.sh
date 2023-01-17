# Utilities for installing tools and their dependencies

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

_tool_install() {
	usage() {
		print_usage '[options]'
	}

	declare -a deps
	declare -a commands
	@ARGS
		-n | --name ) name="$2"
			shift
			shift
			;;
		-d | --dep | --depends-on ) deps+=("$2")
			shift
			shift
			;;
		-c | --command ) commands+=("$2")
			shift
			shift
	@ENDARGS

	for dep in "${deps[@]}"; do
		if ! command -v "$dep" >/dev/null ; then
			echo >&2 "Error: cannot install $name: dependency '$dep' not found"
			return 1
		fi
	done

	for command in "${commands[@]}"; do
		if ! eval "$command"; then
			echo >&2 "Error: cannot install $name: command failed \`$command'\`"
			return 1
		fi
	done

}
