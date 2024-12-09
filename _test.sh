(
trap 'STACKTRACE=1; error FAILED' ERR
cd "$TOOLS"

source "util/shell/base.sh"
command -v aes_encryptor.sh

for file in $(find */ -name '_test*.sh'); do
	(
	set -e
	source "$TOOLS/util/shell/base.sh"
	source "$file"
	) || FAIL=1
done

[[ -z "$FAIL" ]] && echo 'all tests passed'
exit $FAIL
) >/dev/null
