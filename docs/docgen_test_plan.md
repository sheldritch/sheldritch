# Documentation Generation Test Plan

This document captures the agreed intent, requirements, and a concrete test
plan for generating per-file Markdown documentation from `--help` output.

## Goal (Intent)

For each source file in the Sheldritch codebase (excluding underscore-prefixed
files/directories), generate a corresponding Markdown file under
`docs/generated/` containing documentation for each public function defined in
that source file. Documentation is derived from calling `FUNCTION --help` and
formatting the result as native Markdown.

## Clarifications And Constraints (Agreed)

- Output location: write generated docs under `docs/generated/`.
- `docs/generated/` should be gitignored (generated artifacts, not committed here).
- File set: include all files except any file/dir with a leading `_` prefix.
- Function set: exclude private functions (leading `_`) and ignore any `DPR_` functions.
- Shell: run doc generation using `bash` (Sheldritch aims for cross-shell support, but use bash).
- Sourcing: as long as `$SHELDRITCH` is set, source target files directly (no need to source `sheldritch.base.sh` first).
- Help invocation:
  - Call `FUNCTION --help`.
  - Enforce a 1-second timeout per `--help` call (assume `timeout` exists).
  - Provide stdin as closed (`</dev/null`) and treat waiting for input as a failure.
  - Help is expected to print to stdout.
  - If `--help` exits successfully but only prints to stderr, emit a warning for that function and treat help output as blank.
  - If `--help` fails (non-zero), treat as invalid help.
  - If help output length is less than 10 characters, treat as invalid help.
- Markdown formatting:
  - Do not use fenced code blocks.
  - Default formatting is paragraph text.
  - Use a heuristic to detect lists and render native Markdown lists where appropriate.
  - If help output follows the standard `@func_info`/`print_doc` structure, create Markdown subheadings for each detected section.
- Colors: preserve ANSI color spans by wrapping them with HTML comments that describe the color in plain English (e.g. `<!-- red start -->...<!-- red end -->`).
- Isolation: avoid cross-file pollution by processing each file in a fresh subshell/environment.
- Iteration approach: first get a working baseline that emits raw (validated) help text per function, then review the produced output and iterate on post-processing heuristics.

## Expected Markdown Structure

- `# <relative file path>`
- `## <function name>`
- Under each function:
  - If valid help exists, render it in Markdown.
  - If help is invalid or unavailable: `No documentation available. If you need support, please create an issue.`
  - If sections are detected (standard `@func_info` help), use `### <Section Name>` headings (e.g. `Usage`, `Options`, `Legend`, `Examples`).

## Test Plan

### 1. File Discovery And Exclusions

- Ensure files and directories starting with `_` are excluded from traversal.
- Ensure traversal includes all other library areas (e.g. `core/`, `data/`, `util/`, `system/`, `net/`, `workflow/`).
- Confirm output mirrors input tree under `docs/generated/` (one `.md` per source file).

### 2. Function Discovery And Exclusions

For a representative sample file:

- `funcs_in_file` returns only public function names (no `_private`).
- `DPR_` functions are excluded even if they appear in the file.
- Ensure function names with unusual but valid characters are handled (e.g. `?:`, `:+`, `foo-bar`).

### 3. Help Invocation Validity

Create a fixture library file with functions that cover:

- **Valid help**:
  - `--help` exits 0 and prints a normal-length (>10 chars) usage message to stdout.
- **No help**:
  - `--help` prints nothing and exits 0.
  - `--help` prints fewer than 10 characters and exits 0.
  - `--help` prints only to stderr and exits 0 (expect warning + blank help).
- **Failed help**:
  - `--help` exits non-zero (expect invalid/blank help).
- **Hanging help**:
  - `--help` waits for input or sleeps (expect timeout + invalid/blank help).

Acceptance: only valid stdout help is included in generated markdown; all other cases yield the standard "No documentation available..." message.

### 4. Section Detection And Formatting

Using a function that uses `@func_info`/`print_doc` style output:

- Detect and render common sections as headings (e.g. `Usage:`, `Options:`).
- Ensure section ordering matches help output ordering.
- Ensure non-section text is rendered as paragraphs (no code fences).

### 5. List Heuristics

Verify list detection works for typical help formats:

- Lines that look like options (e.g. `-f, --flag ...`) become `-` list items.
- Indented bullet-like blocks become `-` list items.
- Plain paragraphs remain paragraphs (do not over-list).

### 6. Color Preservation

Create a function whose `--help` emits ANSI color codes:

- Generated Markdown includes HTML comments marking color spans with plain English names.
- The content remains readable even if the renderer ignores the comments.

### 7. Isolation / Cross-File Pollution

Have two files define the same function name differently:

- When generating docs for file A, ensure `--help` corresponds to A’s definition.
- When generating docs for file B, ensure `--help` corresponds to B’s definition.

Acceptance: each file’s doc reflects only that file’s sourced environment (fresh subshell per file).

### 8. Performance / Safety Checks

- Time a run on the full repo and verify:
  - Each `--help` is capped at 1 second.
  - The generator does not block waiting for user input.
  - Total runtime is within an acceptable range for the codebase size.

## Implementation Notes (Non-Goals)

- This is not a full shell parser. Help formatting is heuristic and should be iterated based on observed outputs.
- If a function’s help requires external dependencies or credentials, it should still be safe: time out and omit help rather than executing long-running operations.
