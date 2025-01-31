__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%.sh}.base.sh"

summon \
	'sheldritch/core/*'      \
	'sheldritch/data/*'      \
	'sheldritch/data/text/*' \
	'sheldritch/net/*'    \
	'sheldritch/system/*'    \
	'sheldritch/util/*'

if [[ -f "$(self_dir)/system/$OS.sh" ]]; then
	summon sheldritch/system/$OS.sh
fi
