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
if [[ -f "$OS_WSL" ]] && grep -sq enabled "$WSL"; then
	OS_WSL=1
	__browser="cmd.exe /c start"
	if [[ "$BROWSER" && "$BROWSER" != "$__browser" ]]; then
		echo >&2 "Warning: setting BROWSER as '$__browser' for WSL. To quash this warning, unset BROWSER or set it as '$__browser' yourself."
	fi
	export BROWSER="$__browser"
else
	unset OS_WSL
fi

function url_open {
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
	elif command -v xdg-open ; then
		xdg-open "$link"
	else
		echo >&2 "Error: no link opener available. Please do so manually."
	fi
}

function wsl_open {
	typeset Path="$1"
	Path="${Path#file://}"
	[[ -e "$Path" ]] && Path="$(wslpath -w "$Path")"
	(cd /mnt/c || cd /c && cmd.exe /c start "${Path//&/^&}")
}

