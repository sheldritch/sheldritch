#!/bin/bash
source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/util/test
summon sheldritch/data/random

test_init

(($(random_word | wc -c) > 1))
[[ "$(random_word)" != *\ * ]]
[[ "$(random_word -c 2)" = *\ * ]]
[[ "$(random_word -c 2)" != "$(random_word)" ]]
[[ "$(random_word)" != "$(random_word)" ]]

[[ "$(random_word -c word 2>&1)" =~ "must be an integer" ]]


(($(random_hex | wc -c) == 1))
(($(random_hex -c 5 | wc -c) == 5))
[[ "$(random_hex -c 40)" != *[^[:xdigit:]]* ]]
[[ "$(random_hex -c 40)" != "$(random_hex -c 40)" ]]

[[ "$(random_hex -c word 2>&1)" =~ "must be an integer" ]]


(($(random_char | wc -c) == 1))
(($(random_char -c 5 | wc -c) == 5))
[[ "$(random_char -c 40)" != *[[:cntrl:]]* ]]
[[ "$(random_char --safe -c 40)" != *[[%^:/]]* ]]
[[ "$(random_char --safe -c 40 'a^:/')" != *[]%^:/[]* ]]
[[ "$(random_char --safe -c 40 'a^:/')" != *[^a]* ]]
[[ "$(random_char -c 20)" != "$(random_char -c 20)" ]]
[[ "$(random_char a -c 20)" != *[^a]* ]]

[[ "$(random_char -c word 2>&1)" =~ "must be an integer" ]]


(($(random_symbol | wc -c) == 1))
(($(random_symbol -c 5 | wc -c) == 5))
[[ "$(random_symbol -c 40)" != *[^[:punct:]]* ]]
[[ "$(random_symbol -c 40)" != "$(random_symbol -c 40)" ]]

[[ "$(random_symbol -c word 2>&1)" =~ "must be an integer" ]]


(($(random_digit | wc -c) == 1))
(($(random_digit -c 5 | wc -c) == 5))
[[ "$(random_digit -c 40)" != *[^[:digit:]]* ]]
[[ "$(random_digit -c 40)" != "$(random_digit -c 40)" ]]

[[ "$(random_digit -c word 2>&1)" =~ "must be an integer" ]]

for x in {0..30}; do
	port="$(random_port)"
	((port > 1024 && port < 65535))
done

ecode "$EXIT" || safe_quit
