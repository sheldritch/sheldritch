if [[ -n "$BASH_VERSION" ]]; then
	__FILE="${BASH_SOURCE[0]}"
elif [[ -n "$KSH_VERSION" ]]; then
	__FILE="${.sh.file}"
elif [[ -n "$ZSH_VERSION" ]]; then
	__FILE="${(%):-%x}"
elif [[ -n "$SHELDRITCH" ]]; then
	__FILE="$SHELDRITCH/sheldritch.full.sh"
else
	echo >&2 'Error: cannot determine location of sheldritch.sh. Please set $SHELDRITCH. Even then, your shell is probably not supported.'
fi

source "${__FILE%.full.sh}.base.sh" "$@"

summon 'sheldritch/*/**'
