[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/json.sh
summon sheldritch/util/test.sh

test_init

JSON='{
 "a": "b",
 "b": 2,
 "c": false,
 "d": null,
 "e": +233e98,
 "f": [1,2,"4"],
 "g": { "h": "i" }
}
'

[[ "$(jqj "$JSON" -r .b)" == 2 ]]
expect_error "expected JSON as first argument" jqj pinata .a

json_obj a 1 b 2 c 3
json_obj a b
expect_error "odd number of arguments" json_obj a 1 b
[[ "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1 ]]


[[ "$(json_field "$JSON" b)" = 2 ]]
expect_error '.*' json_field "$JSON" .b
expect_error '^$' json_field "$JSON" Z

expect_error "expected JSON as first argument" jbool potatoe
jbool true
expect_error '^$' jbool false
expect_error '^$' jbool null
jbool false '. | not'
expect_error '^$' jbool true '. | not'

jtype true boolean
jtype false boolean
jtype '{}' object
jtype null null

expect_fail jtype true string
expect_fail jtype false string
expect_fail jtype '{}' null
expect_fail jtype null number

[[ "$(jtype true)"  = boolean ]]
[[ "$(jtype false)" = boolean ]]
[[ "$(jtype '{}')"  = object  ]]
[[ "$(jtype null)"  = null    ]]

[[ "$(json_keys "$JSON")" = '"a"
"b"
"c"
"d"
"e"
"f"
"g"' ]]
