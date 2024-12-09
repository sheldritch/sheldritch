(
trap 'echo >&2 FAILED: $BASH_SOURCE: $BASH_COMMAND; FAIL=1' ERR
set -e
cd "$TOOLS"

command -v aes_encryptor.sh

for file in $(find */ -name '_test*.sh'); do
	(
	source "$TOOLS/util/shell/base.sh"
	source "$file"
	) || FAIL=1
done

[[ -z "$FAIL" ]] && echo 'all tests passed'
exit $FAIL
) >/dev/null
