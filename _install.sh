#!/bin/bash

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

for file in $(find "$TOOLS"/*/ -name '_install.sh'); do
	"$file"
done

