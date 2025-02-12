# Sheldritch -- shell framework imbued with black magic
Sheldritch (pronounced S̸h̸e̴l̴d̷r̴i̸t̸c̴h̷) is a development environment for the shell,
with a library and importer system, argument parsing, cross-shell compatibility
commands and a slew of different utilities.

## Installation

### Sheldon

Sheldon is a package manager for shell modules.

1. Install Sheldon from https://github.com/rossmacarthur/sheldon?tab=readme-ov-file#-installation
2. run
    ```sh
    sheldon init --shell "${SHELL##*/}"
    sheldon add sheldritch --github eidolic/sheldritch --use sheldritch.full.sh
    eval "$(sheldon source)"
    ```
3. Add `eval "$(sheldon source)"` to your shell rc file.

### Manual

Clone to the directory you want it and run `./_install.sh`.

## Feature Overview

### Library and imports

The goal of Sheldritch's library system is to import as little code as possible
for your given utility.

The `summon` command lets you semantically include files based on your directory
structure:

```sh
summon <library>/<directory>/<module>
```

### Argument Parsing

Sheldritch's `@func_info` argument parsing framework combines code
documentation, help output, and parsing and validation into a single semantic
structure.

Here's an example. Let's write a version of `cp` based on its manpage usage
lines. You can imagine that the system's `cp` command only takes a single source
argument and single destination argument, for some unholy reason.

```sh
function cp {
	@func_info
	About='Copy files and directories'
	Usage=(
		'SOURCE DEST'
		'SOURCE... DIRECTORY'
		'-t DIRECTORY SOURCE...'
	)
    Legend=(
        SOURCE 'Existing path. A file or directory to be copied into its new location'
        DEST   'New file. Target for the directory to be copied to.'
    )
	Options=(
		-t --target=DIRECTORY 'copy the listed files into the given directory'
		-T --no-target 'disallow copying inside of directories'
		-f --force 'force copy, even if the file already exists'
	)
	args_parse

	if [[ "$NoTarget" == true ]]; then
		Dest="${Dest:-$Directory}"
	fi

	if [[ -n "$Dest" ]]; then
		if [[ -d "$Dest" ]]; then
			error "Destination '$Dest' must not be a directory!"
			return 2
		fi
		command cp "$Source" "$Dest"
		return $?
	fi

	local File='' Fail=''
	for File in "${Source[@]}"; do
		command cp "$File" "$Directory/$File" || Fail=1
	done
    return $Fail
}
```
