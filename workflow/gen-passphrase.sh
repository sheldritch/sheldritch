#!/bin/bash
#
# generate a good passphrase.
# 4 dictionary words, with a random number/letter interspliced
main() {
    gen_password
}

# Insert random character into string
# used for password generation
insert_rand_char() {
    local string char pos
    char="$1"
    string="$2"

    if [ "$char" = "symbol" ]; then
        char=$(tr -dc '!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 1)
    elif [ "$char" = "digit" ]; then
        char=$(tr -dc '0-9' </dev/urandom | head -c 1)
    fi
    pos=$(shuf -i 1-$length -n 1)
    password="${password:0:$pos}$char${password:$pos}"
    echo "$password"
}

gen_password() {
    local password length
    while [[ "$length" -lt 20 ]]; do
        password="$(shuf --random-source=/dev/urandom --repeat --head-count=4 /usr/share/dict/words)"
        length="$(wc -c <<<"$password")"
    done

    password="$(insert_rand_char digit "$password")"
    password="$(insert_rand_char symbol "$password")"

    echo $password # treat newlines as spaces
}

main
