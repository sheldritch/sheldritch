__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%.sh}.base.sh"

summon sheldritch/util/shell/json.sh
summon sheldritch/util/shell/random.sh
[[ -f util/system/$OS.sh ]] && summon sheldritch/util/system/$OS.sh
