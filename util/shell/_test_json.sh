use_tool util/shell/json.sh
test "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1
