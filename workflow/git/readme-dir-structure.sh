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

		for child in "$(dirname "$readme")"/*/; do
			summary="$(basename "$child") -- $(sed -n '/^[^#]/{p; q}' $child/README.md)"
			sed -i "/## Directory Structure/a $summary" "$readme"
			
		done
		sed -i '/## Directory Structure/G' "$readme"
	fi
done
