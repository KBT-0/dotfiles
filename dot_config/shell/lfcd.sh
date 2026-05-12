# lf file manager integration.
# Running `lf` through this wrapper makes the shell follow the last directory
# opened inside lf.
lfcd() {
    if ! command -v lf >/dev/null 2>&1; then
        printf '%s\n' "lf is not installed. Run scripts/install-lf.sh from the dotfiles repo." >&2
        return 127
    fi

    local tmp dir
    tmp="$(mktemp)" || return

    command lf -last-dir-path="$tmp" "$@"

    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        if [ -d "$dir" ] && [ "$dir" != "$(pwd)" ]; then
            cd "$dir" || return
        fi
    fi
}

alias lf="lfcd"
