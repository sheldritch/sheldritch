[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
check_is_sourced

function curl_json {
	curl -X POST -H 'Content-Type: application/json' "$@"
}

function port_wait {
	@func_info
	Usage='[HOST] PORT'
	Legend=(
		HOST "defaults to localhost."
	)
	Options=(
		-t --timeout "Big timeout buys a fridge friend."
	)
	args_parse

	timeout "${Timeout:-0}" sh -c "until nc -z '$Host' '$Port'; do sleep 0.05; done"
}

function port_publish {
	@func_info
	Usage='PRIVATE_PORT PUBLIC_PORT'
	Options=(
		-v --verbose "output debug information"
	)
	args_parse

	socat tcp-listen:$PublicPort,reuseaddr,fork tcp:0.0.0.0:$PrivatePort $(isTrue $Verbose || echo >/dev/null) &
	port_wait $PublicPort
}

function ip_local {
	case $OS in
		linux) ip route get 1 | perl -ne ' /src (\S+)/ && print "$1\n" ';;
		mac) ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk 'NR == 1 {print $2}' ;;
		*) echo >&2 "Error: ip_local: Unspported operating system. Please update the function to add support."; return 1 ;;
	esac
}
alias ipl=ip_local

function ip_public {
	curl ifconfig.me
}
alias ipp=ip_public

