[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/json.sh
json_obj a 1 b 2 c 3
json_obj a b
[[ "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1 ]]
