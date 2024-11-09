source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh

curl_json() {
	curl -X POST -H 'Content-Type: application/json' "$@"
}

port_wait() {
	local host port
	usage() {
		print_usage '[HOST] PORT'
	}

	@ARGS
		-t | --timeout ) timeout=$2
			shift
			shift
	@ENDARGS

	case $# in
		1) 
			host=localhost
			port="$1"
			;;
		2)
			host="$1"
			port="$2"
			;;
		*) 
			usage >&2
			return 1
	esac

	timeout 3 sh -c "until nc -z '$host' '$port'; do sleep 0.05; done"
}

port_publish() {

	@ARGS
		-v | --verbose ) verbose=true
			shift
			shift
	@ENDARGS

	local privatePort="$1"
	local publicPort="$2"

	socat tcp-listen:$publicPort,reuseaddr,fork tcp:0.0.0.0:$privatePort $(isTrue $verbose || echo >/dev/null) &
	port_wait $publicPort
}

ip_local() {
	case $OS in
		linux) ip route get 1 | perl -ne ' /src (\S+)/ && print "$1\n" ';;
		mac) ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk 'NR == 1 {print $2}' ;;
		*) echo >&2 "Error: ip_local: Unspported operating system. Please update the function to add support."; return 1 ;;
	esac
}
alias ipl=ip_local

ip_public() {
	curl ifconfig.me
}
alias ipp=ip_public

