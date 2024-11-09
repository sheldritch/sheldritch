source "$TOOLS"/util/shell/base.sh || return 1
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

