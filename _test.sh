(
cd "$TOOLS"
trap 'echo >&2 FAILED: $BASH_SOURCE: $BASH_COMMAND; FAIL=1' ERR

command -v aes_encryptor.sh

test "$(jqj "$(json_obj a 1 b 2 c 3)" .a)" = 1

shopt -s globstar

for file in $(find */ -name '_test*.sh'); do
	source "$file" || FAIL=1
done

return $FAIL
) >/dev/null
