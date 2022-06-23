#!/bin/bash
#
# generate a good passphrase.
# 4 dictionary words, with a random number/letter interspliced

source "$TOOLS/util/shell/base.sh" || return 1
check_is_sourced

use_tool util/shell/random.sh

local password length
while [[ "$length" -lt 20 ]]; do
	password="$(random_word -c 4)"
	length="$(wc -c <<<"$password")"
done

password="$(random_insert_char digit "$password")"
password="$(random_insert_char symbol "$password")"

echo $password # treat newlines as spaces
