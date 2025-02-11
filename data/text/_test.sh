source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/text
trap 'STACKTRACE=1; error FAILED' ERR

function test_encode {
	val="$1"
	shift
	url_encode "$@" >/dev/null

	[[ "$REPLY" = "$val" ]]
}

test_encode 'a%3db'  'a=b'
test_encode 'a%3db'  --only-if-escaped = 'a\=b'
test_encode 'a=b'    --only-if-escaped = 'a=b'
test_encode 'a%3db'  --ignore-escaped = 'a=b'
test_encode 'a=b'    --ignore-escaped = 'a\=b'
test_encode 'a=b'    --only-encode 'k' --ignore-escaped = 'a\=b'
test_encode 'a\%3db' --only-encode '=' 'a\=b'
test_encode 'a%5c=b' --only-encode '\' 'a\=b'
