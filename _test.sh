__FILE="${BASH_SOURCE[0]:-${(%):-%x}}"
source "${__FILE%/*}/sheldritch.base.sh"

(
trap 'STACKTRACE=1; error FAILED' ERR
cd "$SHELDRITCH"
export SHELDRITCH

command -v self_file

for file in $(find */ -name '_test*.sh'); do
	(
	set -e
	"./$file"
	) || FAIL=1
done

[[ -z "$FAIL" ]] && echo 'all tests passed'
exit $FAIL
) >/dev/null
