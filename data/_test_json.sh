source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/json.sh
test "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1
