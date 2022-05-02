#!/bin/bash
#
# Generate directory structure sections for README.md files
#
# Fetch the README summary in each child directory, and populate the
# `## Directory Structure` section with these summaries.
#
# Does this recursively for all READMEs beneath the current directory.

shopt -s globstar

for readme in **/README.md; do
	if grep -qi "## Directory Structure" "$readme"; then

		sed -i '/## Directory [Ss]tructure/,/^#/ {
			/^[^#]/d;
			/^$/d;
		}' "$readme"
		
		sed -i '/## Directory Structure/G' "$readme"

		for child in "$(dirname "$readme")"/*; do
			name="$(basename "$child")"
			filetype="$(file -b "$child")"
			typeis() { echo "$filetype" | grep -q "$1"; }

			if [ "$name" = "README.md" ]; then
				continue
			elif typeis "shell script"; then
				summary="$name -- $(sed -nE '/^# \w/{s/^# //; p; q}' "$child")"
			elif typeis "directory"; then
				summary="$name -- $(sed -n '/^[^#]/{p; q}' "$child/README.md")"
			else
				echo >&2 "unhandled filetype: $child"
				echo >&2 "type: $filetype"
				continue
			fi

			sed -i "/## Directory Structure/a - $summary" "$readme"
		done

		sed -i '/## Directory Structure/G' "$readme"
	fi
done
