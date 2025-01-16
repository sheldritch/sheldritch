#!/bin/bash

NumArgs="$1"
NumberWords="$(/usr/lib/libnumbertext/spellout 1-"$NumArgs" | sed 's/[^a-z]\+/-/g')"
WordsPascal=($(sed -E 's/(^|-)(.)/\U\2/g' <<<"$NumberWords"))
WordsBigSnake=($(tr -- -a-z _A-Z <<<"$NumberWords" ))

echo 'perf_baseline() {
declare -a Args=()
local ' ${WordsPascal[@]} '
while [[ $# -ne 0 ]]; do
	case "$1" in'


i=0
while read Word; do
	printf '\t\t-%s | --%s ) %s="$2"\n' "$((i + 1))" "$Word" "${WordsPascal[$i]}"
	printf '\t\tshift 2 || return 1;;\n'
	((i++))
done <<<"${NumberWords}"
echo '
		-h | --help ) Help=true
			shift
			break
			;;
		-* ) 
			echo >&2 "Error: perf_baseline: unknown argument \"$1\""
			return 1
			;;
		* ) Args+=("$1")
			shift
			;;
	esac
done
set -- "${Args[@]}" "$@"

if [[ "$Help" = true ]]; then
	echo "perf_baseline: A test function that is a load of fun!"
	echo
	echo "Usage: perf_baseline [options] NICE_WORDS..."
	echo
	echo Options:
	echo
'
i=0
while read Word; do
	printf '\techo "\t-%s, --%s=%s"\n\techo "\t\t A string of reasonable length that describes this variable"\n' "$((i + 1))" "$Word" "${WordsBigSnake[$i]}"
	((i++))
done <<<"${NumberWords}"
echo fi

for Var in "${WordsPascal[@]}"; do
	echo "if [[ -n \$$Var ]]; then echo \"Argument '$Var' is set to \$$Var.\"; fi"
done

echo '
}'

echo "perf_func_info() {
@func_info
About='A test function that is a load of fun!'
Usage='NICE_WORDS...'
Options=(
"
i=0
while read Word; do
	printf '\t-%s --%s=%s "A string of reasonable length that describes this variable"\n' "$((i + 1))" "$Word" "${WordsBigSnake[$i]}"
	((i++))
done <<<"$NumberWords"
echo $')
args_parse
\n'

for Var in "${WordsPascal[@]}"; do
	echo "if [[ -n \$$Var ]]; then echo \"Argument '$Var' is set to \$$Var.\"; fi"
done

echo '
local -p
	for x in "${NiceWords[@]}"; do echo "\"$x\" is nice."; done
}'
