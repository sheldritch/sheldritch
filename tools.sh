# Makes all the shell scripts in `tools` available to the shell
#
source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

tool_sync() {

	local noClear DEBUG sync

	while [ $# -ne 0 ]; do
		case "$1" in
			--no-clear) noClear=true
				shift
				;;
			--debug) DEBUG=true
				shift
				;;
			--sync) sync=true
				shift
				;;
			* ) echo >&2 "unknown arg '$1'"
				return 1
				;;
		esac
	done

	if [[ -z "$noClear" ]]; then
		if [[ "$TOOLS_SOURCES" =~ "shell.sh" ]]; then echo >&2 "Note: re-running tools.sh"; fi
		unset TOOLS_SOURCES
	fi


	# Add things to PATH if not already added
	if command -v yarn >/dev/null; then
		add_to_path $(sh -c "yarn bin")
	fi
	add_to_path "$HOME/.yarn/bin"
}
tool_sync "$@"
