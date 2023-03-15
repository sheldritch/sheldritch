#!/bin/bash

set -e


SELF_DIR="$( cd "$(dirname $(realpath "${BASH_SOURCE[0]}"))" >/dev/null 2>&1 && pwd )"
TOOLS="$SELF_DIR"

add_tools_envar() {
	if [ -f "$1" ]; then
		if grep -q TOOLS= "$1"; then
			# export needed for executable scripts that use $TOOLS
			sed -i -e "/TOOLS=/s%^.*$%export TOOLS=$TOOLS%" "$1"
		else
			echo "export TOOLS=$TOOLS" >> "$1"
		fi
	fi
}
add_tools_envar ~/.bashrc
# non-interactive init files need $TOOLS when they source $TOOLS/util/base.sh
add_tools_envar ~/.profile
add_tools_envar ~/.bash_profile

grep -Eq 'source "\$TOOLS' ~/.bashrc || echo 'source "$TOOLS/tools.sh"' >> ~/.bashrc

source "$TOOLS/tools.sh" --sync

cat <<-EOF
###
### Critical resources -- needed to run util/shell/base.sh
###
EOF

case "$(uname -s)" in
    Linux*)     machine=Linux;;
    Darwin*)

		if ! command -v brew >/dev/null; then
			brewCmds="$(/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
				| tee /dev/tty | grep -A 3 'Run these three commands' | tail -n 3
			)"
			echo >&2 "Running those three commands above (you don't need to manually do it)":
			eval "$brewCmds"
		fi

		brew install coreutils

		;;

    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

source "$TOOLS/util/shell/base.sh"

set +e

cat <<-EOF
###
### Optional resources -- you may end up using only some of these tools
###
EOF

use_tool install/install_raku.sh


for file in $(find "$TOOLS"/*/ -name '_install.sh'); do
	echo >&2 "installing $file"
	"$file"
done
echo >&2 "Installations complete."

