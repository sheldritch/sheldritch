__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%.full.sh}.base.sh"

summon \
	'sheldritch/core/*'      \
	'sheldritch/data/*'      \
	'sheldritch/data/text/*' \
	'sheldritch/langs/*'     \
	'sheldritch/system/*'    \
	'sheldritch/util/*'      \
	'sheldritch/workflow/*'
