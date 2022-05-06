# meta-utilities for dealing with the tools repo

tool_edit() {
    $EDITOR "$TOOLS/$1" 
}

_completion_tool_edit() {
    COMPREPLY=($(cd "$TOOLS"; compgen -f -- "${COMP_WORDS[1]}"))
}
complete -o filenames -F _completion_tool_edit tool_edit
