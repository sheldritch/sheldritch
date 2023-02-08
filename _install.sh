#!/bin/bash

SELF_DIR="$( cd "$(dirname $(realpath "${BASH_SOURCE[0]}"))" >/dev/null 2>&1 && pwd )"
TOOLS="$SELF_DIR"
grep -q TOOLS= ~/.bashrc || echo "TOOLS=$TOOLS" >> ~/.bashrc
grep -Eq 'source "?$TOOLS' ~/.bashrc || echo 'source "$TOOLS/tools.sh"' >> ~/.bashrc

set -e

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

set +e

# Raku
curl https://rakubrew.org/install-on-perl.sh | sh
eval "$($HOME/.rakubrew/bin/rakubrew init Bash)"
grep -q rakubrew ~/.bashrc || echo 'eval "$(/home/wm-admin/.rakubrew/bin/rakubrew init Bash)"' >> ~/.bashrc
rakubrew download
rakubrew build-zef
~/.raku/bin/zef install $TOOLS --force-install

for file in $(find "$TOOLS"/*/ -name '_install.sh'); do
	"$file"
done

