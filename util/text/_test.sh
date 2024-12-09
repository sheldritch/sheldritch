set -e 

use_tool util/text/text.sh

[[ "$(url_encode 'a=b')" = 'a%3db' ]]
[[ "$(url_encode --only-if-escaped = 'a=b')" = 'a%3db' ]]
[[ "$(url_encode --only-if-escaped = 'a=b')" = 'a=b' ]]
[[ "$(url_encode --ignore-escaped = 'a=b')" = 'a%3db' ]]
[[ "$(url_encode --ignore-escaped = 'a\=b')" = 'a=b' ]]
[[ "$(url_encode --only-encode 'k' --ignore-escaped = 'a\=b')" = 'a=b' ]]
[[ "$(url_encode --only-encode '=' --ignore-escaped = 'a\=b')" = 'a=b' ]]
[[ "$(url_encode --only-encode '=' 'a\=b')" = 'a\%3db' ]]
[[ "$(url_encode --only-encode '\' 'a\=b')" = 'a%5c=b' ]]
