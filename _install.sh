#!/bin/bash

set -e

SELF_DIR="$( cd "$(dirname $(realpath "${BASH_SOURCE[0]}"))" >/dev/null 2>&1 && pwd )"
TOOLS="$SELF_DIR"
grep -q TOOLS= ~/.bashrc || echo "TOOLS=$TOOLS" >> ~/.bashrc
grep -Eq 'source "\$TOOLS' ~/.bashrc || echo 'source "$TOOLS/tools.sh"' >> ~/.bashrc

source ~/.bashrc

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

