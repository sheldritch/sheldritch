#!/bin/bash
#
# Generate per-file Markdown documentation from `FUNCTION --help` output.
#
# Defaults:
# - Root: $SHELDRITCH
# - Output: $SHELDRITCH/docs/generated/
#
# Constraints:
# - Only shell source files are considered (*.sh, *.bash, *.zsh, *.ksh).
# - Any file/dir whose path component starts with "_" is excluded.
# - Private functions (leading "_") and any `DPR_` functions are excluded.
# - Help is invoked as `FUNCTION --help` with a 1s timeout and stdin closed.
#

[[ -n ${SHELDRITCH_SUBSHELL:-} ]] || source "$SHELDRITCH/sheldritch.base.sh" || exit 1
summon sheldritch/data/types.sh
summon sheldritch/core/args.sh

docgen_is_shell_file() {
	case "$1" in
		*.sh|*.bash|*.zsh|*.ksh) return 0 ;;
	esac
	return 1
}

docgen_has_underscore_component() {
	local RelativePath="$1" Component
	IFS=/ read -r -a DocgenParts <<< "$RelativePath"
	for Component in "${DocgenParts[@]}"; do
		[[ "$Component" == _* ]] && return 0
	done
	return 1
}

docgen_strip_ansi() {
	local Esc
	Esc=$'\x1b'
	# shellcheck disable=SC2001
	sed "s/${Esc}\\[[0-9;]*m//g"
}

docgen_ansi_to_comments_and_bold() {
	# Convert ANSI SGR spans to:
	# - Color: HTML comments `<!-- red start -->...<!-- red end -->`
	# - Bold/underline: Markdown bold `**...**`
	#
	# Strips all escape codes from output.
	awk '
		function color_name(code) {
			if (code == 30) return "black"
			if (code == 31) return "red"
			if (code == 32) return "green"
			if (code == 33) return "yellow"
			if (code == 34) return "blue"
			if (code == 35) return "magenta"
			if (code == 36) return "cyan"
			if (code == 37) return "white"
			if (code == 90) return "bright black"
			if (code == 91) return "bright red"
			if (code == 92) return "bright green"
			if (code == 93) return "bright yellow"
			if (code == 94) return "bright blue"
			if (code == 95) return "bright magenta"
			if (code == 96) return "bright cyan"
			if (code == 97) return "bright white"
			return ""
		}

		function emit_state_change(new_bold, new_underline, new_color,  old_emph, new_emph) {
			old_emph = (bold || underline)
			new_emph = (new_bold || new_underline)

			# Close emphasis before ending a color span so the color wrapper stays outermost.
			if (old_emph && !new_emph) {
				printf "**"
			}
			if (color != "" && new_color != color) {
				printf "<!-- %s end -->", color
			}
			if (new_color != "" && new_color != color) {
				printf "<!-- %s start -->", new_color
			}
			if (!old_emph && new_emph) {
				printf "**"
			}

			bold = new_bold
			underline = new_underline
			color = new_color
		}

		function apply_sgr(seq,  n, i, p, c, new_bold, new_underline, new_color) {
			new_bold = bold
			new_underline = underline
			new_color = color

			# Empty params means reset.
			if (seq == "") {
				new_bold = 0
				new_underline = 0
				new_color = ""
				emit_state_change(new_bold, new_underline, new_color)
				return
			}

			n = split(seq, params, ";")
			for (i = 1; i <= n; i++) {
				p = params[i]
				if (p == "") p = 0

				if (p == 0) {
					new_bold = 0
					new_underline = 0
					new_color = ""
				} else if (p == 1) {
					new_bold = 1
				} else if (p == 22) {
					new_bold = 0
				} else if (p == 4) {
					new_underline = 1
				} else if (p == 24) {
					new_underline = 0
				} else if (p == 39) {
					new_color = ""
				} else if ((p >= 30 && p <= 37) || (p >= 90 && p <= 97)) {
					c = color_name(p)
					if (c != "") new_color = c
				}
			}
			emit_state_change(new_bold, new_underline, new_color)
		}

		BEGIN {
			bold = 0
			underline = 0
			color = ""
		}

		{
			line = $0
			while (match(line, /\033\[[0-9;]*m/)) {
				printf "%s", substr(line, 1, RSTART - 1)
				seq = substr(line, RSTART + 2, RLENGTH - 3) # inside ESC[ ... m
				apply_sgr(seq)
				line = substr(line, RSTART + RLENGTH)
			}
			print line
		}

		END {
			# Close any open wrappers.
			if (bold || underline) {
				printf "**"
			}
			if (color != "") {
				printf "<!-- %s end -->", color
			}
			printf "\n"
		}
	'
}

docgen_help_to_markdown() {
	local Line Raw Trimmed InCode=0 Section=''
	local OptName='' OptDescFirst='' OptDescRest=()
	local Emitted='' LastBlank=''

	docgen__flush_opt() {
		local I
		[[ -n "$OptName" ]] || return 0
		if [[ -n "$OptDescFirst" ]]; then
			printf -- '- %s — %s\n' "$OptName" "$OptDescFirst"
			for ((I = 0; I < ${#OptDescRest[@]}; I++)); do
				printf '  %s\n' "${OptDescRest[I]}"
			done
		else
			printf -- '- %s\n' "$OptName"
		fi
		OptName=''
		OptDescFirst=''
		OptDescRest=()
		return 0
	}

	while IFS= read -r Line || [[ -n "$Line" ]]; do
		Raw="$Line"

		if [[ "$Raw" == '```'* ]]; then
			docgen__flush_opt
			printf '%s\n' "$Raw"
			Emitted=1
			LastBlank=''
			((InCode = 1 - InCode))
			continue
		fi

		if ((InCode)); then
			printf '%s\n' "$Raw"
			Emitted=1
			LastBlank=''
			continue
		fi

		Trimmed="${Raw#"${Raw%%[!$' \t']*}"}"
		Trimmed="${Trimmed%"${Trimmed##*[!$' \t']}"}"

		if [[ -z "$Trimmed" ]]; then
			docgen__flush_opt
			[[ -n "$Emitted" ]] || continue
			[[ -n "$LastBlank" ]] && continue
			printf '\n'
			LastBlank=1
			continue
		fi
		Emitted=1
		LastBlank=''

		if [[ "$Trimmed" =~ ^[[:alnum:]][[:alnum:]_./[:space:]-]*:[[:space:]]*$ ]] && [[ ! "$Raw" =~ ^[[:space:]] ]]; then
			docgen__flush_opt
			Section="${Trimmed%:}"
			printf '### %s\n' "$Section"
			continue
		fi

		# `print_options`-style option entries (primarily under an "Options" section):
		#   -f, --flag
		#       description...
		if [[ "$Section" == Options ]]; then
			if [[ "$Raw" =~ ^[[:space:]]{2,}(-|--) ]] && [[ "$Trimmed" =~ ^--?[^[:space:]] ]]; then
				docgen__flush_opt
				OptName="$Trimmed"
				continue
			fi

			if [[ -n "$OptName" ]]; then
				# Capture one or more description/continuation lines (even if the help output
				# embedded newlines without indentation).
				if [[ -z "$OptDescFirst" ]]; then
					OptDescFirst="$Trimmed"
				else
					OptDescRest+=("$Trimmed")
				fi
				continue
			fi
		fi

		# Convert common list syntaxes to native Markdown lists.
		if [[ "$Trimmed" =~ ^[-*+][[:space:]]+ ]]; then
			docgen__flush_opt
			printf -- '- %s\n' "${Trimmed#? }"
			continue
		fi

		# Under Usage, indented lines are almost always usage examples; avoid accidental code blocks.
		if [[ "$Section" == Usage && "$Raw" =~ ^[[:space:]] ]]; then
			docgen__flush_opt
			printf -- '- %s\n' "$Trimmed"
			continue
		fi

		# Examples are often multi-line shell snippets; render code-ish lines as
		# inline-code list items to preserve line breaks without introducing code fences.
		if [[ "$Section" =~ [Ee]xample ]]; then
			if [[
				"$Trimmed" =~ ^(for|while|until|if|elif|then|fi|case|esac|do|done|function|local|export|unset|set|shift|return|break|continue|echo|printf|cat|jq|sed|awk)([[:space:]]|$) ||
				"$Trimmed" == *'$('* ||
				"$Trimmed" == *'='* ||
				"$Trimmed" == *'|'*
			]]; then
				local EscapedInlineCode=''
				docgen__flush_opt
				EscapedInlineCode="${Trimmed//\`/\\\`}"
				printf -- '- `%s`\n' "$EscapedInlineCode"
				continue
			fi
		fi

		# Avoid implicit Markdown code blocks by stripping leading indentation.
		docgen__flush_opt
		printf '%s\n' "$Trimmed"
	done

	docgen__flush_opt
	return 0
}

docgen_file_is_sourcable() {
	local File="$1" ExitCode
	timeout 1 bash -c '
		export SHELDRITCH="$1"
		source "$2"
	' bash "$SHELDRITCH" "$File" </dev/null >/dev/null 2>&1
	ExitCode=$?
	[[ $ExitCode -eq 0 ]] && return 0
	return 1
}

docgen_func_help_markdown() {
	local File="$1" Func="$2"
	local TempStdoutFile TempStderrFile ExitCode HelpStdout HelpStderr PlainHelp PlainHelpTrimmed PlainHelpNoWhitespace

	TempStdoutFile="$(mktemp)" || return 1
	TempStderrFile="$(mktemp)" || { rm -f "$TempStdoutFile"; return 1; }
	trap 'rm -f "$TempStdoutFile" "$TempStderrFile"' RETURN

	timeout 1 bash -c '
		export SHELDRITCH="$1"
		source "$2" || exit $?
		"$3" --help
	' bash "$SHELDRITCH" "$File" "$Func" </dev/null >"$TempStdoutFile" 2>"$TempStderrFile"
	ExitCode=$?

	HelpStdout="$(cat "$TempStdoutFile")"
	HelpStderr="$(cat "$TempStderrFile")"

	if [[ $ExitCode -ne 0 ]]; then
		return 1
	fi

	if [[ -z "$HelpStdout" ]]; then
		if [[ -n "$HelpStderr" ]]; then
			warn "docgen: '$Func --help' for '$File' produced output on stderr only; treating as blank"
		fi
		return 1
	fi

	PlainHelp="$(printf '%s' "$HelpStdout" | docgen_strip_ansi)"
	PlainHelpTrimmed="$PlainHelp"
	PlainHelpTrimmed="${PlainHelpTrimmed#"${PlainHelpTrimmed%%[!$' \t\r\n']*}"}"
	PlainHelpTrimmed="${PlainHelpTrimmed%"${PlainHelpTrimmed##*[!$' \t\r\n']}"}"

	# Some functions treat "--help" as a normal argument and print a value (often
	# a path) rather than documentation; treat a single existing path as "no help".
	if [[ "$PlainHelpTrimmed" != *$'\n'* && "$PlainHelpTrimmed" == */* && -e "$PlainHelpTrimmed" ]]; then
		warn "docgen: '$Func --help' for '$File' printed a path; treating as blank"
		return 1
	fi

	PlainHelpNoWhitespace="$PlainHelp"
	PlainHelpNoWhitespace="${PlainHelpNoWhitespace//$'\n'/}"
	PlainHelpNoWhitespace="${PlainHelpNoWhitespace//$'\r'/}"
	PlainHelpNoWhitespace="${PlainHelpNoWhitespace//$'\t'/}"
	PlainHelpNoWhitespace="${PlainHelpNoWhitespace// /}"
	((${#PlainHelpNoWhitespace} >= 10)) || return 1

	printf '%s' "$HelpStdout" |
		docgen_ansi_to_comments_and_bold |
		docgen_help_to_markdown
}

docgen_main() {
	@func_info
	About='Generate per-file Markdown documentation from `FUNCTION --help` output.'
	Usage=()
	Options=(
		--root=DIR "Root directory to scan for shell files (default: \$SHELDRITCH)"
		--out=DIR  "Output directory for generated Markdown (default: \$SHELDRITCH/docs/generated)"
	)
	args_parse
	Root="${Root:-${SHELDRITCH:-.}}"
	Out="${Out:-${SHELDRITCH:-.}/docs/generated}"

	local RootDir OutputDir
	RootDir="$(realpath -s "$Root")" || return 1
	OutputDir="$(realpath -s "$Out")" || return 1

	local File RelativePath OutFile OutputFileDir Arg
	local -a Funcs=() Sorted=()

	while IFS= read -r -d '' File; do
		docgen_is_shell_file "$File" || continue
		RelativePath="${File#"$RootDir"/}"
		[[ "$RelativePath" != "$File" ]] || RelativePath="$(basename "$File")"

		docgen_has_underscore_component "$RelativePath" && continue

		if ! docgen_file_is_sourcable "$File"; then
			error "docgen: file is not sourceable in bash; skipping: $RelativePath"
			continue
		fi

		Funcs=()
		while IFS= read -r Arg || [[ -n "$Arg" ]]; do
			[[ -z "$Arg" ]] && continue
			[[ "$Arg" == _* ]] && continue
			[[ "$Arg" == DPR_* ]] && continue
			# Filter obvious false positives from embedded languages (e.g. awk `function name(args)`).
			[[ "$Arg" == *"("* || "$Arg" == *")"* ]] && continue
			Funcs+=("$Arg")
		done < <(funcs_in_file "$File")

		if ((${#Funcs[@]} == 0)); then
			warn "docgen: no public functions found in '$RelativePath'; skipping"
			continue
		fi

		mapfile -t Sorted < <(printf '%s\n' "${Funcs[@]}" | LC_ALL=C sort -u)

		OutFile="$OutputDir/${RelativePath%.*}.md"
		OutputFileDir="$(dirname "$OutFile")"
		mkdir -p "$OutputFileDir" || return 1

		{
			printf '# %s\n\n' "$RelativePath"
			for Arg in "${Sorted[@]}"; do
				printf '## %s\n\n' "$Arg"
				if ! docgen_func_help_markdown "$File" "$Arg"; then
					printf '%s\n' 'No documentation available. If you need support, please create an issue.'
				fi
				printf '\n\n'
			done
			} > "$OutFile"
	done < <(find "$RootDir" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.zsh' -o -name '*.ksh' \) -print0)
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	docgen_main "$@"
fi
