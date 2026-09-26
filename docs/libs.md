# Library Usage

## Summon

Sheldritch uses the term 'Tome' (analogous to a 'module') because multiple
directory structures and file types are supported. In both the following cases,
`summon animals/birds` would source the `birds.sh` file:

```text
animals/
├── birds.sh
└── lizards.sh

animals/
├── birds
│   ├── birds.sh
│   ├── flightless.sh
│   └── owls.sh
└── lizards.sh
```

This allows the structure of your project to expand organically. Let's say you
have the former structure (with `animals/birds.sh`) and want to add a new Tome
for owls. It would make more sense to have it as `animals/birds/owls` rather
than just `animals/owls`. You can simply move `birds.sh` to a `birds`
subdirectory (as in the latter example). Any existing `summon animals/birds`
commands will continue to work.

Alternatively, let's say that `birds.sh` is getting too large, and you'd like
to split the helpers for flightless birds into its own Tome. The process is the
same as the previous example, except since the contents of `flightless.sh`
*used* to be in `birds.sh`, you need to add `summon animals/birds/flightless`
to the top of `birds.sh`. This will ensure that the functions remain accessible
to external scripts currently using them.

### Shell detection

For a given Tome, if a file exists with an extension matches the users current
shell, that file will be sourced instead of the generic shell file. So for
`foo/bar`, `foo/bar.bash` will be sourced instead of `foo/bar.sh`.

A current example of this in action is `core/compat`, which by definition needs
to include specific implementations for different shells. Each `compat.*` file
could sit under either the `core/` directory or `core/compat/`, it doesn't
matter which.

### Circular dependencies

If your Tomes are just defining a bunch of functions, circular dependencies are
usually a non issue. File A can summon File B, which can summon File A, and you
don't get stuck in an infinite loop.

The only exception to this is if File B refers to something defined in File
A outside of a function definition:

File A:
```bash
summon foo/b

function bar {
  echo "Heheh, I'm in danger!"
}
```

File B:
```bash
summon foo/a
bar
```

File A will summon File B, File B will *skip* the File A summon since it's
already in the process of being summoned, and then `bar` will try and execute
and fail because File A hasn't executed beyond its first line.

Thankfully, this won't lead to an infinite loop or something, you'll just get
a `Command 'bar' not found` error.

### Globbing

Multiple files may also be added at once using a glob as a wildcard pattern.
Make sure you always wrap globs in quotes.

```sh
summon 'potions/ingredients/*'
```

Globs will ignore any directory or file starting with `_`. This allows
non-library files like tests or incidental scripts to be excluded. In this
repo, some examples are `_test/`, `_perf/` and `_install.sh`.
Underscore-prefixed files may still be summoned by specifying the path directly
and explicitly:

```sh
summon 'potions/ingredients/*'
summon 'potions/ingredients/_dangerous'
```

Recursive globs are also possible using `**`, searching all directories under
the specified module. `**` should only go at the end of paths.

```sh
summon 'souls/**'
```

## Interaction with other shell library utilities

(This section is TODO)
