#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1

summon sheldritch/data/types
summon sheldritch/util/test

zsh_run setopt KSH_ARRAYS

test_init

TmpDir="$(mktemp -d)" || return 1
trap 'rm -rf "$TmpDir"' EXIT

assert_funcs_in_file() {
	local File="$1"
	shift || :
	local -a Expected=("$@") Names=()
	while IFS= read -r Name; do
		[[ -z "$Name" ]] && continue
		Names+=("$Name")
	done <<EOF
$(funcs_in_file "$File")
EOF
	expect_array_eq Names "${Expected[@]}"
}

# Bash (and non-zsh) single-name headers across all supported syntaxes.
(
	Path="$TmpDir/bash_basic.bash"
	cat >"$Path" <<'EOF'
function _fun1() { :; }
_fun2 () { :; }
_fun2 () { :; }   # duplicate
_fun3()
{
  :
}
   _spaced   ()    { :; }
_fun4 ()
(
  :
)
function _fun7 () (
  :
)
function _fun5 {
  :
}
function _fun6
{
  :
}
_pending1 ()

{
  :
}
function _pending2

{
  :
}
$dyn() { :; }    # dynamic name, should be ignored
EOF
	assert_funcs_in_file "$Path" _fun1 _fun2 _fun3 _spaced _fun4 _fun7 _fun5 _fun6 _pending1 _pending2
)

# Non-zsh flavors should ignore multiple names after `function`.
(
	Path="$TmpDir/nonzsh_multi.bash"
	cat >"$Path" <<'EOF'
function alpha beta () { :; }
function gamma delta { :; }
EOF
	assert_funcs_in_file "$Path"
)

# Zsh allows multiple names after `function`.
(
Path="$TmpDir/multi_names.zsh"
cat >"$Path" <<'EOF'
function _za _zb () { :; }
function _zh _zi () (
  :
)
function _zc _zd { :; }
function _ze
{
  :
}
function _zdup _zdup { :; }
EOF
	assert_funcs_in_file "$Path" _za _zb _zh _zi _zc _zd _ze _zdup
)

# Shebang should override .sh default to pick zsh flavor.
(
	Path="$TmpDir/shebang_zsh.sh"
	cat >"$Path" <<'EOF'
#!/usr/bin/env zsh
function sa sb { :; }
EOF
	assert_funcs_in_file "$Path" sa sb
)

# Bash shebang keeps bash rules (multi-names rejected) and still finds singles.
(
	Path="$TmpDir/shebang_bash.sh"
	cat >"$Path" <<'EOF'
#!/usr/bin/env bash
function bashshebang { :; }
function _ba _bb { :; }
EOF
	assert_funcs_in_file "$Path" bashshebang
)

# ksh flavor handles its headers and subshell-style bodies.
(
	Path="$TmpDir/shebang_ksh.sh"
	cat >"$Path" <<'EOF'
#!/usr/bin/env ksh
function _kk1 { :; }
_kk2() { :; }
_kk3() ( : )
EOF
	assert_funcs_in_file "$Path" _kk1 _kk2 _kk3
)

# Standard input should be accepted when FILE is '-' and should still honor
# shebang-based flavor detection.
(
	Names=()
	while IFS= read -r Name; do
		[[ -z "$Name" ]] && continue
		Names+=("$Name")
	done <<EOF
$(funcs_in_file - <<'EOF_STDIN'
#!/usr/bin/env zsh
function _stdin_a _stdin_b { :; }
_stdin_c() { :; }
EOF_STDIN
)
EOF
	expect_array_eq Names _stdin_a _stdin_b _stdin_c
)

# Embedded awk-style function declarations should not be treated as shell
# functions.
(
	Path="$TmpDir/embedded_awk.sh"
	cat >"$Path" <<'EOF'
_real_shell() { :; }
awk '
	function trim(s) {
		return s
	}
	function Date(str, regex) {
		return str
	}
'
function _also_real {
	:
}
EOF
	assert_funcs_in_file "$Path" _real_shell _also_real
)

# Comments and trailing text should be ignored.
(
	Path="$TmpDir/comments.sh"
	cat >"$Path" <<'EOF'
# foo() { :; }
   # function bar() { :; }
_real1() { :; } # trailing comment
function _real2
{
  :
}
EOF
	assert_funcs_in_file "$Path" _real1 _real2
)

# Pending header should survive intervening comments; dangling headers without a body
# should not emit anything.
(
	Path="$TmpDir/pending_comment.sh"
	cat >"$Path" <<'EOF'
_commented ()
# a comment before the body opener
{
  :
}
_dangling ()

# never opens a body
EOF
	assert_funcs_in_file "$Path" _commented
)

# Missing file should return an error message.
expect_error "file '.*/does_not_exist.sh' not found" funcs_in_file "$TmpDir/does_not_exist.sh"
