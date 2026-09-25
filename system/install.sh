# Utilities for installing tools and their dependencies

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

summon sheldritch/core/args
summon sheldritch/system/

function _tool_install {
	declare -a deps
	declare -a commands
	while [ $# -ne 0 ]; do
	case "$1" in
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
	esac
	done

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

function install_first_with {

	@func_info
	About='Given a list of packages, and a given tool, install the first package that exists'
	Usage='INSTALLER_TOOL POSSIBLE_PACKAGES...'
	parse_opts

	installer="$1"
	shift

	for pkg in "$@"; do
		case "$installer" in

			apt)
				if [ "$(apt-cache search --names-only ^$pkg$)" ]; then
					sudo apt-get install "$pkg" && return
				fi
				;;

			brew)
				if quiet brew info "$pkg"; then
					brew install "$pkg" && return
				fi
				;;

			choco)
				if quiet choco info "$pkg"; then
					choco install "$pkg" && return
				fi
				;;

			npm)
				if quiet npm info "$pkg"; then
					npm install -g "$pkg" && return
				fi
				;;

			pacman)
				if quiet pacman -Si "$pkg"; then
					sudo pacman -S "$pkg" && return
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

			winget)
				(
				local wingetOut options choice
				set -o pipefail
				if wingetOut="$(winget.exe search -e "$pkg" 2>/dev/null | sed 's/.*\r//')" \
					&& ! echo "$wingetOut" | grep -q 'No package found'
				then

					echo "$wingetOut" | head -2 | stderr sed 's/^/\t/'
					options="$(echo "$wingetOut" | tail -n -2 | nl)"
					stderr echo "$options"

					read -p "Enter the number of the package you want to install (or enter anything else if no package is acceptable): " choice
					if source="$(echo "$options" | grep "^ *$choice" | grep -oE '\w+$')"; then
						winget.exe install -s "$source" --interactive --exact "$pkg" && return
					fi
				fi
				)
				;;

			yarn)
				if ! yarn info "$pkg" 2>/dev/null | grep -q '^error'; then
					yarn global add "$pkg" &&
						command -v "$pkg" 2>/dev/null
						return
				fi
				;;


			*)
				echo >&2 "Error: install_with_first: installer '$installer' not supported"
				return 9
				;;
		esac
	done

	return 2
}


function install_basic {
	zsh_run setopt SH_WORD_SPLIT
	declare -a Installers=(
		# in order of goodness (objectively and empirically, of course)

		# system-level package managers
		apt
		winget
		pacman # if you're on an arch-based system and another system-level package manager is available, surely you did that on purpose, riiiight?

		# app level package managers
		brew
		yarn
		npm

		# we don't like containered packages, lol
		snap
	)

	@func_info
	About='attempt to install a package using a variety of package managers'
	Usage='POSSIBLE_PACKAGE_NAMES'
	Options=(
		-c --command=NAME "a command the package will install. If it already exists, installation will cancel"
		-f --force --reinstall "install even if it already exists"
		# TODO: re-implement
		#-e --exclude=PACKAGES... "exclude the given installer from being used"

	)
	for Installer in "${Installers[@]}"; do
		Options+=(
			--${Installer}=PACKAGE "specify an exact package for $Installer"
		)
	done

	opts_parse


	for Installer in "${Installers[@]}"; do
		# in the loop so it exits if previous installer worked
		if [[ "$Command" ]] \
			&& ! isTrue $Reinstall \
			&& command -v "$Command" >/dev/null
		then
			return
		fi

		[ "${Exclude[$Installer]}" ] && continue
		if command -v "$Installer" >/dev/null; then
			install_first_with $Installer $(deref $Installer) "$@" && return
		fi
	done
	echo >&2 "Error: install_basic: could not install one of '$@'"
	return 1

}
