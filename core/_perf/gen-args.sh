#!/bin/bash

NumArgs="$1"
NumberWords="$(/usr/lib/libnumbertext/spellout 1-"$NumArgs" | sed 's/[^a-z]\+/-/g')"
WordsPascal=($(sed -E 's/(^|-)(.)/\U\2/g' <<<"$NumberWords"))
WordsBigSnake=($(tr -- -a-z _A-Z <<<"$NumberWords" ))

echo 'perf_baseline() { echo ded; };'

echo 'perf_baseline() {
declare -a Args=()
local ' ${WordsPascal[@]} '
while [[ $# -ne 0 ]]; do
	case "$1" in
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
'
i=0
for (( i=0; i < (${#WordsPascal[@]} / 2); i++)); do
	printf '%s="%s"\n' "${WordsPascal[$i]}" "$((i + 1))"
	((i++))
	[[ $i = 9 ]] && break
done

echo '

if [[ "$Help" = true ]]; then
	echo "perf_baseline: A test function that is a load of fun!"
	echo
	echo "Usage: perf_baseline [options] '"${WordsBigSnake[@]:0:$i}"' OTHER_NUMBERS..."
	echo
	echo Options:
	echo
fi
'
for Var in "${WordsPascal[@]:0:$i}"; do
	echo "if [[ -n \$$Var ]]; then echo \"Argument '$Var' is set to \$$Var.\"; fi"
done

echo '
echo "$@"
}'

echo "perf_func_info() {
@func_info
About='A test function that is a load of fun!'
Options=()
Usage='"${WordsBigSnake[@]:0:$i}" OTHER_NUMBERS...'
"
echo $'args_parse \n'

for Var in "${WordsPascal[@]}"; do
	echo "if [[ -n \$$Var ]]; then echo \"Argument '$Var' is set to \$$Var.\"; fi"
done
echo 'echo "${OtherNumbers[@]}"'

echo '
	local -p
	for x in "${NiceWords[@]}"; do echo "\"$x\" is nice."; done
}'
