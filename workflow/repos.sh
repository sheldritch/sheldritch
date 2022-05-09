#!/bin/bash
# move around between certain repos

# Will try and cd directly into a repo folder from anywhere on the machine, defaulting to
# the parent 'repos' folder if no suitable repo can be found (not provided or doesn't exist)
repo() {
	(
	IFS=:
	for repoDir in $REPOS; do
		if [ -d "$repoDir/$1" ]; then
			cd "$repoDir/$1"
			return 0
		fi
	done
	cd "$(echo "$REPOS" | cut -d: -f1)"
)
}
