# No shebang, we want this to run in the user's shell
# shellcheck shell=zsh

set -e

cat <<-EOF
###
### Installing critical dependencies needed to run base sheldritch
###
EOF

case "$(uname -s)" in
    Linux*)     machine=Linux;;
    Darwin*)

		if ! command -v brew >/dev/null; then
			brewCmds="$(/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
				| tee /dev/tty | grep -A 3 'Run these three commands' | tail -n 3
			)"
			echo >&2 "We are running those three commands above (you don't need to manually do it)":
			eval "$brewCmds"
		fi

		brew install coreutils

		;;

    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

cat <<-EOF
###
### Installing sheldritch
###
EOF

SHELDRITCH="$(dirname "{BASH_SOURCE[0]:-${(%):-%x}}")"

source "$SHELDRITCH/sheldritch.base.sh"

add_envar() {
	if [ -f "$1" ]; then
		if grep -q SHELDRITCH= "$1"; then
			# export needed for executable scripts that use $SHELDRITCH
			sed -i -e "/SHELDRITCH=/s%^.*$%export SHELDRITCH=$SHELDRITCH%" "$1"
		else
			echo "export SHELDRITCH=$SHELDRITCH" >> "$1"
		fi
	fi
}

declare Shell=${SHELL##*/}
add_envar ~/.${Shell}rc
# non-interactive init files need $SHELDRITCH when they source the app
add_envar ~/.profile
add_envar ~/.${Shell}_profile

grep -Eq 'source "\$SHELDRITCH' ~/.${Shell}rc || echo 'source "$SHELDRITCH/sheldritch.full.sh"' >> ~/.${Shell}rc


summon sheldritch/system/install.sh
install_basic -c jq jq

echo >&2 "Installations complete."
