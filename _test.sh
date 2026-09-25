if [[ -n ${BASH_VERSION-} ]]; then
	__FILE="${BASH_SOURCE[0]}"
elif [[ -n ${KSH_VERSION-} ]]; then
	__FILE="${.sh.file}"
elif [[ -n ${ZSH_VERSION-} ]]; then
	__FILE="${(%):-%x}"
elif [[ -n "$SHELDRITCH" ]]; then
	__FILE="$SHELDRITCH/sheldritch.sh"
else
	echo >&2 'Error: cannot determine location of sheldritch.sh. Please set $SHELDRITCH. Even then, your shell is probably not supported.'
fi

source "${__FILE%_test.sh}sheldritch.base.sh"

bash_run shopt -s globstar
ksh_run set -o globstar

if ! { summon sheldritch/data/types && funcs_in_file "$__FILE"; } >/dev/null 2>&1; then
	error "skipping function coverage: failed to summon/run funcs_in_file for ${THIS_SHELL:-this shell}"
else

	echo "Coverage:"
	echo "The following functions do not have tests:"
	while IFS= read -r f; do
		# Ignore empty lines (e.g. if the parser ever emits blanks).
		[[ -n "$f" ]] || continue
		grep -F -q "$f " **/_test/**/* **/_test*.sh || echo "$f"
	done < <(grep -r '^function [^_]' |
		grep -v passthrough |
		cut -f 2 -d ' ' |
		# Handle `function foo()` style declarations.
		sed 's/()$//' |
		sort -u
	)
fi

echo "Running tests:"
(
trap 'STACKTRACE=1; error FAILED' ERR
cd "$SHELDRITCH"
export SHELDRITCH

command -v self_file

for file in $(find */ -path '*/_test*.sh'); do
	"$SHELL" "./$file" || FAIL=1
done

[[ -z "${FAIL-}" ]] && log 'all tests passed'
exit ${FAIL:-0}
) >/dev/null
