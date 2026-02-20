# Contributing

## Style

For general best practices when using Sheldritch, see the [corresponding
documentation](docs/best-practices.md).

Unless required, (e.g. variable case), Sheldritch avoids prescribing style or
specific shell settings. The following directives only apply to code within
Sheldritch itself -- you can do what you damn well please in your own external
code. Furthermore, since Sheldritch is a foundational library on which all
other libraries are built, it does many things differently from how you would
in a library *using* Sheldritch. For instance, it frequently favours
over-optimised code for performance over readability, maintainability, etc.

### General
- Write code and variable names in US English and documentation in Australian
    English (except where directly referencing variable/function names).
- Wrap markdown files to a reasonable extent.

### Formatting & Spacing
- In arithmetic tests with non‑alnum either side, keep spaces inside brackets:
    `(( ${#SHELDRITCH_SOURCES[@]} ))`.
- Prefer `$Var` over `${Var}` unless braces are required.
- Prefer `${Var+ }` (space) to check if Var is set; it's a little more clear
    than the deprecated `${Var+x}`.

### Flags & Arguments
- Prefer `--flag value` over `--flag=value` for readability; `--flag=value` is
    acceptable when using glob expansion for repeated arguments.
- Use the `@func_info` framework for non-trivial functions, unless following
    the [performance instructions below](#performance).
- Use `@func_info`/`opts_parse`/`args_parse` for new functions; populate
    `Usage`, `Options`, `Legend`, and let `print_doc` serve `--help`.

### Imports & Modules
- While libraries using Sheldritch will frequently source `sheldritch.sh` for
    convenience, Tomes in Sheldritch always source `sheldritch.base.sh` and use
    the minimum number of summons possible. This makes sourcing any individual
    file in Sheldritch as fast as possible.

### Cross‑Shell Safety and Compatibility
- Guard shell-specific behaviour with `bash_run`/`zsh_run`/`ksh_run`; avoid
    unguarded bashisms in shared code.
- Be familiar with the compatibility helpers from `core/compat.*` and
    `system/system.sh` and use them where relevant.
- Ensure code supports arrays being zero-indexed or one-indexed for zsh. To do
    this, you can either call `zsh_run setopt ksh_arrays` inside a function, or
    use array slices (e.g. `${Array[@]:0:1}`). Make sure you preserve the
    original setting when returning control to the shell.

### Logging & Errors
- Use `log`, `warn`, `error`, and `debug` helpers
- Use `safe_quit` when it's ambiguous if you're running inside a function or
    directly in a script.

### Testing
- Place tests under `_test/` or `_test*.sh`; start with `test_init` from
    `util/test`.
- Use `expect_fail`, `expect_error`, `expect_return`, and `expect_array_eq` to
    keep assertions consistent.

### Performance
- Low-level and frequently run functions should be well-optimised for
    performance. These include most functions under `core/*`, `data/types`, and
    pretty much anything used in `sheldritch.base.sh` or its sources.
- When writing performant code:
    - Sheldritch usually contains short, frequently run functions. These
        benefit from being written in pure bash, with no calls to external
        commands.
    - Avoid `$(subshells)` and `command | pipes`. Many functions set `$REPLY`,
        so you can use `command >/dev/null; Var="$REPLY"` instead.
    - Be careful of which functions you are using, make sure they also follow
        the guidelines above.
    - Use @help and manual argument parsing.
