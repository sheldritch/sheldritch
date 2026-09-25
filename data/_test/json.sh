#!/bin/bash
#
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/data/json
summon sheldritch/util/test

test_init
trap "STACKTRACE=1; error FAILED" ERR

JSON='{
 "a": "b",
 "b": 2,
 "c": false,
 "d": null,
 "e": +233e8,
 "f": [1,2,"4"],
 "g": { "h": "i" }
}
'

declare a b c d
expect_return 8 json2vars --check "$JSON" a b c d
expect_return 24 json2vars --check "$JSON" a b c d d
[[ $a = b ]]
[[ $b = 2 ]]
[[ $c = false ]]
[[ $d = "" ]]

[[ "$(jqj "$JSON" -r .b)" == 2 ]]
expect_error "expected JSON as first argument" jqj pinata .a

json_obj a 1 b 2 c 3 >/dev/null
json_obj a b >/dev/null
expect_error "odd number of arguments" json_obj a 1 b
[[ "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1 ]]


[[ "$(json_field "$JSON" b)" = 2 ]]
expect_fail json_field "$JSON" .b
expect_fail json_field "$JSON" Z

expect_error "expected JSON as first argument" jbool potatoe
jbool true
expect_fail jbool false
expect_fail jbool null
jbool false '. | not'
jbool '"string"'
jbool '""'
jbool 0
jbool '{}'
jbool '[]'
expect_fail jbool true '. | not'

json_check "$JSON" '.a == "b"'
json_check "$JSON" '.a'
for x in c d h; do
	expect_error "failed check '.$x'" json_check "$JSON" .$x
done
expect_error "failed check '.c == true'" json_check "$JSON" '.c == true'
json_check "$JSON" '.c | not'

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
[[ "$(json_keys "[9,9,9]")" = '0
1
2' ]]

declare a b c d e f g
json2vars "$JSON" a b c

[[ $a = b ]]
[[ $b = 2 ]]
[[ $c = false ]]
[[ $d = '' ]]
[[ $e = '' ]]

json2vars "$JSON" d e
[[ $d = '' ]]
json_check "$e" '. == 233e8'

expect_error 'variables must be declared beforehand' json2vars a b c plant=d
declare plant
json2vars "$JSON" a b c plant=c
[[ $a = b ]]
[[ $b = 2 ]]
[[ $c = false ]]
[[ $plant = false ]]
