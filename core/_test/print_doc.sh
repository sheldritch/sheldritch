#!/bin/bash
[[ -n ${SHELDRITCH_SUBSHELL:-} ]] ||
	source "$SHELDRITCH/sheldritch.base.sh" || return 1
summon sheldritch/core/args.sh
summon sheldritch/util/test.sh

test_init

function test_print_doc_does_not_warn_when_usage_declared_empty {
	(
		function docgen_test_noargs {
			@func_info
			About='test fixture'
			Usage=()
			Options=(
				--foo=FOO 'foo option'
			)
			args_parse
		}

		local Help
		Help="$(docgen_test_noargs --help 2>&1)" || return 1
		if [[ "$Help" == *'No Usage line provided.'* ]]; then
			error "print_doc warned unexpectedly when Usage is declared empty"
			echo >&2 "$Help"
			return 1
		fi
		[[ "$Help" == *$'\nUsage:'* ]] || { error 'missing Usage section'; return 1; }
		[[ "$Help" == *$'\n\tdocgen_test_noargs [options]'* ]] || { error 'missing minimal usage line'; return 1; }
	)
}

test_print_doc_does_not_warn_when_usage_declared_empty
