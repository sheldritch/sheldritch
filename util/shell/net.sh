source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/shell.sh
use_tool services/bitwarden/bitwarden.sh

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
	esac

	timeout 3 sh -c "until nc -z '$1' '$2'; do sleep 0.05; done"
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

