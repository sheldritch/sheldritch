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

# Given a list of packages, and a given tool, install the first package that exists
install_first_with() {

	usage() {
		print_usage INSTALLER_TOOL POSSIBLE_PACKAGES...
	}

	@DEFAULT_ARGS

	installer="$1"
	shift

	for pkg in "$@"; do
		case "$installer" in 

			apt)
				if [ "$(apt-cache search --names-only ^$pkg$)" ]; then
					sudo apt-get install "$pkg" && return
				fi
				;;

			snap) 
				local confinement
				confinement="$(snap info --verbose "$pkg" 2>/dev/null |
						awk '$1 ~ /confinement:/ {print $2}')"

				if [ "$confinement" = strict ]; then
					sudo snap install "$pkg" && return
				elif [ "$confinement" = classic ]; then
					sudo snap install --classic "$pkg" && return
				fi

				;;

			yarn)
				if ! yarn info "$pkg" 2>/dev/null | grep -q '^error'; then
					yarn global add "$pkg" &&
						command -v bw 2>/dev/null
						return
				fi
				;;

			npm)
				if ! quiet npm info "$pkg"; then
					npm install -g "$pkg" && return
				fi
				;;


			choco)
				if quiet choco info "$pkg"; then
					choco install "$pkg" && return
				fi
				;;

			brew) 
				if quiet brew info "$pkg"; then
					brew install "$pkg" && return
				fi
				;;

			*)
				echo >&2 "Error: install_with_first: installer '$installer' not supported"
				return 9
				;;
		esac
	done

	return 1
}


install_basic() {

	usage() {
		print_usage "[options] POSSIBLE_PACKAGE_NAMES..."
	}

	@ARGS
		# a command the package will install. If it already exists, installation will cancel.
		-c | --command ) command="$2"
		shift
		shift
	@ENDARGS

	for installer in apt brew yarn choco snap; do
		[ "$command" ] && command -v "$command" >/dev/null && return
		if command -v "$installer" >/dev/null; then
			install_first_with $installer "$@" && return
		fi
	done
	echo >&2 "Error: install_basic: could not install one of '$@'"

}
