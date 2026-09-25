#!/bin/zsh
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

case $(uname | tr '[:upper:]' '[:lower:]') in
	linux*)
		export OS=linux
		;;
	darwin*)
		export OS=mac
		;;
	msys* | windows* | cygwin* | mingw*_nt-*)
		export OS=windows
		;;
	*)
		export OS=unknown
		;;
esac

alias '@OS_CASE=case "$OS" in'

zsh_run unsetopt GLOB
alias '@OS_CASE_END_ERROR=
		;;
	'*' )
		echo >&2 "Error: OS $OS not supported"
		safe_quit
		;;
esac'
zsh_run setopt GLOB

if [[ $OS = mac ]] && ! command -v brew >/dev/null; then
	echo >&2 "Error: Homebrew not found in Mac install. Ensure it is installed and initialised before using Sheldritch."
	return 1
fi


export MSYS=winsymlinks:nativestrict
OS_WSL=/proc/sys/fs/binfmt_misc/WSLInterop
if [[ -f "$OS_WSL" ]] && grep -sq enabled "$OS_WSL"; then
	OS_WSL=1

	__browser=/tmp/$USER/sheldritch/BROWSER
	echo >"$__browser" '#!/bin/bash
	(cd /mnt/c || cd /c && cmd.exe /c start "${1//&/^&}")'
	chmod u+x "$__browser"

	if [[ "$BROWSER" && "$BROWSER" != "$__browser" ]]; then
		echo >&2 "Warning: setting BROWSER as '$__browser' for WSL. To quash this warning, unset BROWSER or set it as '$__browser' yourself."
	fi
	export BROWSER="$__browser"
else
	unset OS_WSL
fi

function url_open {
	@help '
	Attempt to open the given URL in a browser, or gracefully fail such that the user can still open the link themselves.
	' && return 0
	link="$1"
	if [[ "$XDG_SESSION_TYPE" = tty ]]; then
		echo >&2 "Open the following link in your browser:"
		echo >&2 "$link"
		return
	fi

	echo >&2 "Trying to open link in your browser..."
	echo >&2 "If you don't see the browser open up, manually open the following link in your browser:"
	echo >&2 "$link"

	if grep -sq enabled /proc/sys/fs/binfmt_misc/WSLInterop; then
		(cd /mnt/c || cd /c && cmd.exe /c start "${link//&/^&}")
	elif command -v xdg-open; then
		xdg-open "$link"
	else
		echo >&2 "Error: no link opener available. Please do so manually."
	fi
}

function wsl_open {
	@help '
	Open a file from within WSL
	' && return 0
	typeset Path="$1"
	Path="${Path#file://}"
	[[ -e "$Path" ]] && Path="$(wslpath -w "$Path")"
	(cd /mnt/c || cd /c && cmd.exe /c start "${Path//&/^&}")
}

# Execute the arguments as a command, as if it was running from a terminal.
# from https://stackoverflow.com/a/60279429
function fake_tty {
  # Create a temporary file for storing the status code
  Tmp=$(mktemp)

  # Ensure it worked or fail with status 99
  [ "$Tmp" ] || return 99

  # Produce a script that runs the command provided to faketty as
  # arguments and stores the status code in the temporary file
  Cmd="$(printf '%q ' "$@")"'; echo $? > '$Tmp

  # Run the script through /bin/sh with fake tty
  if [ "$(uname)" = "Darwin" ]; then
    # MacOS
    script -Fq /dev/null /bin/sh -c "$Cmd"
  else
    script -qfc "/bin/sh -c $(printf "%q " "$Cmd")" /dev/null
  fi

  # Ensure that the status code was written to the temporary file or
  # fail with status 99
  [ -s $Tmp ] || return 99

  # Collect the status code from the temporary file
  Err=$(cat $Tmp)

  # Remove the temporary file
  rm -f $Tmp

  # Return the status code
  return $Err
}

