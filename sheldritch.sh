if [[ -n "$BASH_VERSION" ]]; then
	__FILE="${BASH_SOURCE[0]}"
elif [[ -n "$KSH_VERSION" ]]; then
	__FILE="${.sh.file}"
elif [[ -n "$ZSH_VERSION" ]]; then
	__FILE="${(%):-%x}"
elif [[ -n "$SHELDRITCH" ]]; then
	__FILE="$SHELDRITCH/sheldritch.sh"
else
	echo >&2 'Error: cannot determine location of sheldritch.sh. Please set $SHELDRITCH. Even then, your shell is probably not supported.'
fi

source "${__FILE%.sh}.base.sh" "$@"

summon \
	'sheldritch/core/*'      \
	'sheldritch/data/*'      \
	'sheldritch/data/text/*' \
	'sheldritch/net/*'       \
	'sheldritch/system/*'    \
	'sheldritch/util/*'

if [[ -f "$(self_dir)/system/$OS.sh" ]]; then
	summon sheldritch/system/$OS.sh
fi
