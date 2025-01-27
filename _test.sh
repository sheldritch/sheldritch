__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%_test.sh}sheldritch.base.sh"

(
trap 'STACKTRACE=1; error FAILED' ERR
cd "$SHELDRITCH"
export SHELDRITCH

command -v self_file

for file in $(find */ -path '*/_test*.sh'); do
	"$SHELL" "./$file" || FAIL=1
done

[[ -z "$FAIL" ]] && log 'all tests passed'
exit $FAIL
) >/dev/null
