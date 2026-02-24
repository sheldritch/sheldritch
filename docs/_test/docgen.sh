#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args.sh
summon sheldritch/util/test.sh

test_init

function test_docgen_generates_markdown_and_sorts_functions {
	(
		local tmp root out f md
		tmp="$(mktemp -d)" || return 1
		trap 'rm -rf "$tmp"' EXIT
		root="$tmp/root"
		out="$tmp/out"
		mkdir -p "$root" "$out" || return 1

		f="$root/sample.sh"
		cat > "$f" <<'EOF'
beta() { if [[ "$1" == --help ]]; then echo "Usage:"; echo "  beta"; return 0; fi; }
_private() { :; }
DPR_hidden() { :; }
alpha() { if [[ "$1" == --help ]]; then echo "Usage:"; echo "  alpha"; return 0; fi; }
EOF

		bash "$SHELDRITCH/workflow/docs/docgen.sh" --root="$root" --out="$out" >/dev/null

		md="$out/sample.md"
		[[ -f "$md" ]] || { error "expected generated file '$md'"; return 1; }

		# Sorted alphabetically and filtered:
		grep -q '^## alpha$' "$md" || { error "missing alpha"; return 1; }
		grep -q '^## beta$' "$md" || { error "missing beta"; return 1; }
		expect_fail grep -q '^## _private$' "$md"
		expect_fail grep -q '^## DPR_hidden$' "$md"

		# Ensure alpha comes before beta.
		awk '
			$0=="## alpha"{a=NR}
			$0=="## beta"{b=NR}
			END{exit !(a>0 && b>0 && a<b)}
		' "$md" || { error "expected alpha to appear before beta"; return 1; }
	)
}

function test_docgen_excludes_underscore_paths_and_empty_files {
	(
		local tmp root out md
		tmp="$(mktemp -d)" || return 1
		trap 'rm -rf "$tmp"' EXIT
		root="$tmp/root"
		out="$tmp/out"
		mkdir -p "$root/_skip" "$root/ok/_skip" "$out" || return 1

		cat > "$root/_skip/hidden.sh" <<'EOF'
visible() { :; }
EOF
		cat > "$root/ok/_skip/hidden2.sh" <<'EOF'
visible2() { :; }
EOF
		# Empty after filtering (private + DPR_ only) => warn + no md
		cat > "$root/ok/empty.sh" <<'EOF'
_p() { :; }
DPR_x() { :; }
EOF

		bash "$SHELDRITCH/workflow/docs/docgen.sh" --root="$root" --out="$out" >/dev/null

		expect_fail test -f "$out/_skip/hidden.md"
		expect_fail test -f "$out/ok/_skip/hidden2.md"
		expect_fail test -f "$out/ok/empty.md"
	)
}

function test_docgen_help_validity_and_timeout {
	(
		local tmp root out md
		tmp="$(mktemp -d)" || return 1
		trap 'rm -rf "$tmp"' EXIT
		root="$tmp/root"
		out="$tmp/out"
		mkdir -p "$root" "$out" || return 1

		cat > "$root/cases.sh" <<'EOF'
valid_help() {
	if [[ "$1" == --help ]]; then
		echo "Usage:"
		echo "  valid_help"
		echo
		echo "Options:"
		echo "  -f, --flag"
		echo "    some flag"
		return 0
	fi
}

short_help() { [[ "$1" == --help ]] && { echo "short"; return 0; }; }
stderr_help() { [[ "$1" == --help ]] && { echo "this goes to stderr only" >&2; return 0; }; }
fail_help() { [[ "$1" == --help ]] && return 2; }
hang_help() { [[ "$1" == --help ]] && { sleep 2; echo "never"; return 0; }; }
path_help() { [[ "$1" == --help ]] && { echo "$SHELDRITCH"; return 0; }; }
EOF

		bash "$SHELDRITCH/workflow/docs/docgen.sh" --root="$root" --out="$out" >/dev/null
		md="$out/cases.md"
		[[ -f "$md" ]] || { error "expected generated file '$md'"; return 1; }

		grep -q '^## valid_help$' "$md" || { error "missing valid_help section"; return 1; }
		grep -q '^### Usage$' "$md" || { error "missing Usage section heading"; return 1; }
		grep -q '^### Options$' "$md" || { error "missing Options section heading"; return 1; }
		grep -q '^- -f, --flag — some flag$' "$md" || { error "expected options list heuristic"; return 1; }

		# Invalid help cases should use the fallback message.
		grep -q '^## short_help$' "$md" || return 1
		awk '/^## short_help$/{f=1;next} f&&/No documentation available/{ok=1} /^## /{f=0} END{exit !ok}' "$md" ||
			{ error "expected fallback for short_help"; return 1; }

		awk '/^## stderr_help$/{f=1;next} f&&/No documentation available/{ok=1} /^## /{f=0} END{exit !ok}' "$md" ||
			{ error "expected fallback for stderr_help"; return 1; }

		awk '/^## fail_help$/{f=1;next} f&&/No documentation available/{ok=1} /^## /{f=0} END{exit !ok}' "$md" ||
			{ error "expected fallback for fail_help"; return 1; }

		awk '/^## hang_help$/{f=1;next} f&&/No documentation available/{ok=1} /^## /{f=0} END{exit !ok}' "$md" ||
			{ error "expected fallback for hang_help"; return 1; }

		awk '/^## path_help$/{f=1;next} f&&/No documentation available/{ok=1} /^## /{f=0} END{exit !ok}' "$md" ||
			{ error "expected fallback for path_help"; return 1; }
	)
}

function test_docgen_strips_ansi_but_keeps_color_comments_and_bold {
	(
		local tmp root out md esc
		tmp="$(mktemp -d)" || return 1
		trap 'rm -rf "$tmp"' EXIT
		root="$tmp/root"
		out="$tmp/out"
		mkdir -p "$root" "$out" || return 1

		cat > "$root/colors.sh" <<'EOF'
color_help() {
	if [[ "$1" == --help ]]; then
		printf "\033[31mred\033[0m\n"
		printf "\033[1mbold\033[0m\n"
		printf "\033[4mund\033[0m\n"
		return 0
	fi
}
EOF

		bash "$SHELDRITCH/workflow/docs/docgen.sh" --root="$root" --out="$out" >/dev/null
		md="$out/colors.md"

		grep -q '<!-- red start -->red<!-- red end -->' "$md" || { error "missing red span comments"; return 1; }
		grep -q '\\*\\*bold\\*\\*' "$md" || { error "missing bold markdown"; return 1; }
		grep -q '\\*\\*und\\*\\*' "$md" || { error "missing underline->bold markdown"; return 1; }

		esc=$'\x1b'
		if grep -q "$esc" "$md"; then
			error "expected no ANSI escape codes in output"
			return 1
		fi
	)
}

function test_docgen_skips_unsourceable_files {
	(
		local tmp root out
		tmp="$(mktemp -d)" || return 1
		trap 'rm -rf "$tmp"' EXIT
		root="$tmp/root"
		out="$tmp/out"
		mkdir -p "$root" "$out" || return 1

		cat > "$root/bad.sh" <<'EOF'
return 1
will_never_load() { if [[ "$1" == --help ]]; then echo "Usage: will_never_load"; return 0; fi; }
EOF

		bash "$SHELDRITCH/workflow/docs/docgen.sh" --root="$root" --out="$out" >/dev/null 2>/dev/null
		expect_fail test -f "$out/bad.md"
	)
}

test_docgen_generates_markdown_and_sorts_functions
test_docgen_excludes_underscore_paths_and_empty_files
test_docgen_help_validity_and_timeout
test_docgen_strips_ansi_but_keeps_color_comments_and_bold
test_docgen_skips_unsourceable_files
