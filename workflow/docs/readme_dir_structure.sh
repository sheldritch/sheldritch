#!/bin/bash
#
# Generate directory structure sections for README.md files
#
# Fetch the README summary in each child directory, and populate the
# `## Directory Structure` section with these summaries.
#
# Does this recursively for all READMEs beneath the current directory.

shopt -s globstar
source "$SHELDRITCH/sheldritch.base.sh" || exit 1
summon  sheldritch/data/text/print_first_block

directory="${1:-.}"

readmeTemplate() {
	envsubst << EOF
# ${name^}
TODO: Write description

## Directory Structure
EOF
}

# Return a list of all Directory READMEs under a given directory
#
# A directory README is a README explaining the contents of a given directory
getDirectoryReadmes() {
	if [ -z "$1" ]; then
		echo >&2 "readme-dir-structure.sh: getDirectoryReadmes: Error: no directory provided."
	fi
	grep -li '## Directory Structure' "$1"/**/README.md
}

# For a given README, create a README for each child directory, recursively
createChildReadmes() {
	for child in $(find "$(dirname "$1")" -maxdepth 1 -type d); do
		childReadme="$child/README.md"
		name="$(basename "$child")"

		if ! [ -f "$childReadme" ]; then
			echo >&2 "README for '$child' doesn't exist. Creating template."
			readmeTemplate > "$childReadme"

			createChildReadmes "$childReadme"
		fi

	done
}

for readme in $(getDirectoryReadmes "$directory"); do
	createChildReadmes "$readme"
done

for readme in $(getDirectoryReadmes "$directory"); do

	sed -i '/## Directory [Ss]tructure/,/^#/ {
		/^[^#]/d;
		/^$/d;
	}' "$readme"

	sed -i '/## Directory Structure/G' "$readme"

	for child in "$(dirname "$readme")"/*; do
		name="$(basename "$child")"
		filetype="$(file -b "$child")"
		typeis() { echo "$filetype" | grep -q "$@"; }
		nameis() { echo "$name" | grep -q "$@" ; }

		if [ "$name" = "README.md" ]; then
			continue


		elif typeis "directory"; then
			summary="$name -- $(print_first_block '^\w+' "$child/README.md")"

		elif typeis "script" || nameis "\.sh$"; then
			summary="$name -- $(print_first_block '^# \w+' "$child" | sed 's/# //')"

		else
			echo >&2 "unhandled filetype: $child"
			echo >&2 "type: $filetype"
			continue
		fi

		summary="$(echo $summary | sed 's/\.?\s*\n/. /g')"

		sed -i "/## Directory Structure/a - $summary" "$readme"
	done

	sed -i '/## Directory Structure/G' "$readme"
done
