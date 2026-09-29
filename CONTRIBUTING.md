# Contributing

## Style

For general best practices when using Sheldritch, see the [corresponding
documentation](/docs/best-practices.md).

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
- Wrap text lines  markdown files to a reasonable extent.
- Shell variables should use PascalCase unless global or overriding external
    env vars; this avoids conflicting with zsh reserved variables.
- Variables in other languages (awk, python, raku etc) should follow whatever
    convention is most common for that language.

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
    `Usage`, `Options`, `Legend`, and let `print_doc` handle `--help`.

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
- Always quote variables inside tests (`[[ "$Var" ]]`), in case setopt
    SH_WORD_SPLIT is set.
- But DON'T quote inside  numerical evaluations, e.g. `(( "$Integer" ))`.
    Quotes inside argument substitutions are okay: `(( $(lines "$text") ))`.
- Ensure code supports arrays being zero-indexed or one-indexed for zsh. To do
    this, you can either call `zsh_run setopt ksh_arrays` inside a function, or
    use array slices (e.g. `${Array[@]:$Index:$Length}`). Make sure you preserve the
    original setting when returning control to the shell.
  - Array Slices must use $-prefixed variables in array slices.
      `${Array[@]:Index:Length}` is NOT allowed.
- Use the `dict_` functions for associative arrays and SHELDRITCH_HAS_ASSOC_ARRAYS

#### Bash
- Sheldritch aims to support Bash v3 and above.
- `typeset -g` appears in 4.2
    - If you're in the top level, falling back to `typeset` will work. There's
        a check in `sheldritch.base.sh` you can use to test this. So don't use
        `typeset -g` in a function.
    - Any uses of globstar must be matched with a fallback `find`.

#### Korn Shell (ksh)
- Korn Shell is not currently supported, but we try and make at least some
    effort so if somebody wants it someday, it's a slightly less horrifying
    challenge.
- As long as you have `core/compat.ksh` sourced, `local` and `declare` are
    aliased to `typeset`, so you can use each freely.
- Always use typeset when defining arrays. Raw arrays (`Var=()`) are actually
    compound variables (i.e. structs).

### Logging & Errors
- Use `log`, `warn`, `error`, and `debug` helpers
- Use `safe_quit` when it's ambiguous if you're running inside a function or
    directly in a script.
- Return/error code shorthands:
    - 1 if the user did something stupid, or if there's only one error state
        (e.g. simply equality check)
    - 9 for fatal/internal errors (bugs, invariant breaks, impossible states).
        Mnemonic: 9 is the SIGKILL signal to terminate a process immediately.

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
