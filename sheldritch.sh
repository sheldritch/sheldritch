__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%.sh}.base.sh"

summon sheldritch/data/json.sh
summon sheldritch/data/random.sh
[[ -f "$(self_dir)/system/$OS.sh" ]] && summon sheldritch/system/$OS.sh
