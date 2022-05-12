# meta-utilities for dealing with the tools repo

# Completion for files in $TOOLS
_completion_tool_list() {
    COMPREPLY=($(cd "$TOOLS"; compgen -f -- "${COMP_WORDS[COMP_CWORD]}"))
}

complete -o filenames -F _completion_tool_list use_tool

tool_edit() {
    declare -a files
    while [ $# -ne 0 ]; do
        case "$1" in
            --help ) HELP=true
                shift
                break
                ;;
            -- )
                shift
                break
                ;;
            * ) files+=("$TOOLS/$1")
                shift
                ;;
        esac
    done 

    if [ "$HELP" = true ]; then
        echo >&2 "Usage: tool_edit tools... [-- bare-args...]"
    fi
    $EDITOR "$@" "${files[@]}"

    for file in "${files[@]}"; do
        if ! [ -x "$file" ] && echo "$file" | grep -q "\.sh$"; then
            source "$file"
        fi
    done
}
complete -o filenames -F _completion_tool_list tool_edit

if [ "$EDITOR" ]; then
    alias "tool_$EDITOR"=tool_edit
    complete -o filenames -F _completion_tool_list "tool_$EDITOR"
fi

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
