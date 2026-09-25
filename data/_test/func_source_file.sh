#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1

summon sheldritch/data/types
summon sheldritch/util/test

test_init

TmpDir="$(mktemp -d)" || return 1
trap 'rm -rf "$TmpDir"' EXIT

FixtureOne="$TmpDir/fixture1.sh"
FixtureTwo="$TmpDir/fixture2.sh"

cat >"$FixtureOne" <<'EOF'
fixture_func() { :; }
EOF

cat >"$FixtureTwo" <<'EOF'
fixture_func() { :; }
other_func() { :; }
EOF

# Reset caches to make the lookup deterministic for this test.
SHELDRITCH_SOURCES=()
SHELDRITCH_SOURCES_LOOKUP=()

# First definition should resolve to fixture_one.
source_once "$FixtureOne"
expected="$(realpath -s "$FixtureOne")"
actual="$(func_source_file fixture_func)"
[[ "$actual" = "$expected" ]]

# New definition should supersede with fixture_two.
source_once "$FixtureTwo"
expected="$(realpath -s "$FixtureTwo")"
actual="$(func_source_file fixture_func)"
[[ "$actual" = "$expected" ]]

# Non-existent function errors out.
expect_error "function 'nope' not found" func_source_file nope
