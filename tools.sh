# Makes all the shell scripts in `tools` available to the shell
#
source "$TOOLS/util/shell/base.sh" "$@" || return 1
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

	_tools_trace 'Running root tools.sh'

	export MSYS=winsymlinks:nativestrict
	local iop=/proc/sys/fs/binfmt_misc/WSLInterop
	if [[ -f "$iop" ]] && grep -sq enabled "$iop"; then
		__browser="cmd.exe /c start"
		if [[ "$BROWSER" && "$BROWSER" != "$__browser" ]]; then
			echo >&2 "Warning: setting BROWSER as '$__browser' for WSL. To quash this warning, unset BROWSER or set it as '$__browser' yourself."
		fi
		export BROWSER="$__browser"
	fi


	# Add things to PATH if not already added
	if command -v yarn >/dev/null; then
		add_to_path $(sh -c "yarn bin")
	fi
	add_to_path "$HOME/.yarn/bin"


	if find "$TOOLS/tools.sh" -not -perm /111 -quit 2>/dev/null; then
		exec=/111
	else
		exec=+111
	fi

	# source all non-executable shell scripts
	for file in $(find "$TOOLS" -type f -not -perm $exec -name '*.sh' -not -path "*/.bin/*"  \
		| sed "s|^$TOOLS/tools.sh$||" \
		| xargs grep -l ^check_is_sourced$)
	do
		if [[ "$DEBUG" ]]; then
			echo >&2 "$file"
			time source "$file"
		else
			source_once "$file"
		fi
	done

	add_tools_to_bin() {
		(
		cd "$TOOLS"
		for file in $(find -L . \
			\( -path '*/.*' -o -path '*/_*' \) -prune `: # skip files/directories starting with '.' or '_' `\
				-o -type f -print `: # print all other files `\
			)
		do
			[[ -x "$file" ]] || continue
			ln -sf ".$file" "$TOOLS/.bin" # `find` adds `./` to each $file already
		done
		)
	}

	if [[ "$sync" ]]; then
		add_tools_to_bin
	else
		(add_tools_to_bin &)
	fi

	if ! [[ "$PATH" =~ "$TOOLS/.bin" ]]; then
		PATH="$TOOLS/.bin:$PATH"
	fi
}
tool_sync "$@"
