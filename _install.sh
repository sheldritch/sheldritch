#!/bin/bash

set -e


SELF_DIR="$( cd "$(dirname $(realpath "${BASH_SOURCE[0]}"))" >/dev/null 2>&1 && pwd )"
SHELDRITCH="$SELF_DIR"

add_tools_envar() {
	if [ -f "$1" ]; then
		if grep -q SHELDRITCH= "$1"; then
			# export needed for executable scripts that use $SHELDRITCH
			sed -i -e "/SHELDRITCH=/s%^.*$%export SHELDRITCH=$SHELDRITCH%" "$1"
		else
			echo "export SHELDRITCH=$SHELDRITCH" >> "$1"
		fi
	fi
}
add_tools_envar ~/.bashrc
# non-interactive init files need $SHELDRITCH when they source the app
add_tools_envar ~/.profile
add_tools_envar ~/.bash_profile

grep -Eq 'source "\$SHELDRITCH' ~/.bashrc || echo 'source "$SHELDRITCH/tools.sh"' >> ~/.bashrc

cat <<-EOF
###
### Critical resources -- needed to run base sheldritch
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

source "$SHELDRITCH/sheldritch.base.sh"

set +e

summon system/install.sh

install_basic -c jq jq
install_basic -e winget -c bw bitwarden-cli @bitwarden/cli bw

cat <<-EOF
###
### Optional resources -- you may end up using only some of these tools
###
EOF

for file in "$SHELDRITCH"/install/install_*.sh; do
	echo "$file" | grep -q install_bundle && continue
	"$file" || safe_quit 1
done

for file in $(find "$SHELDRITCH"/*/ -name '_install.sh'); do
	echo >&2 "installing $file"
	"$file" || safe_quit 1
done
echo >&2 "Installations complete."
