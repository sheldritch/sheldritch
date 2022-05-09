# meta-utilities for dealing with the tools repo

# Completion for files in $TOOLS
_completion_tool_list() {
    COMPREPLY=($(cd "$TOOLS"; compgen -f -- "${COMP_WORDS[COMP_CWORD]}"))
}

tool_edit() {
    $EDITOR "$TOOLS/$1" 
}
complete -o filenames -F _completion_tool_list tool_edit

tool_commit() {
    if [ $# -lt 2 ]; then
        echo >&2 "Usage: tool_commit: <tool> <commit message>"
    fi

    file="$1"
    message="$2"
    shift 2

    name="$(basename "$file")"
    if [ $(find "$TOOLS" -name "$name" | wc -l) -gt 1 ]; then
        name="$file"
    fi

    git commit -m "$name: $message" "$TOOLS/$file" "$@"
}
complete -o filenames -F _completion_tool_list tool_commit
