#!/usr/bin/env bash
# Install lf, the terminal file manager used by the shell `lfcd` wrapper.

set -euo pipefail

LF_RELEASE_BASE_URL="https://github.com/gokcehan/lf/releases/latest/download"
INSTALL_PREFIX="${LF_INSTALL_PREFIX:-$HOME/.local}"
INSTALL_BIN_DIR="$INSTALL_PREFIX/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LFCD_TARGET_DIR="$CONFIG_HOME/shell"
LFCD_TARGET="$LFCD_TARGET_DIR/lfcd.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url"
    else
        echo "Need curl or wget to download lf." >&2
        return 1
    fi
}

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Need root privileges to install lf. Install sudo or run as root." >&2
        exit 1
    fi
}

install_lfcd() {
    local script_dir repo_root source_file
    script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
    repo_root="$(CDPATH= cd -- "$script_dir/.." 2>/dev/null && pwd || true)"
    source_file="$repo_root/dot_config/shell/lfcd.sh"

    mkdir -p "$LFCD_TARGET_DIR"

    if [ -r "$source_file" ]; then
        cp "$source_file" "$LFCD_TARGET"
    else
        {
            printf '%s\n' '# lf file manager integration.'
            printf '%s\n' '# Running `lf` through this wrapper makes the shell follow the last directory'
            printf '%s\n' '# opened inside lf.'
            printf '%s\n' 'lfcd() {'
            printf '%s\n' '    if ! command -v lf >/dev/null 2>&1; then'
            printf '%s\n' '        printf '"'"'%s\n'"'"' "lf is not installed. Run scripts/install-lf.sh from the dotfiles repo." >&2'
            printf '%s\n' '        return 127'
            printf '%s\n' '    fi'
            printf '%s\n' ''
            printf '%s\n' '    local tmp dir'
            printf '%s\n' '    tmp="$(mktemp)" || return'
            printf '%s\n' ''
            printf '%s\n' '    command lf -last-dir-path="$tmp" "$@"'
            printf '%s\n' ''
            printf '%s\n' '    if [ -f "$tmp" ]; then'
            printf '%s\n' '        dir="$(cat "$tmp")"'
            printf '%s\n' '        rm -f "$tmp"'
            printf '%s\n' '        if [ -d "$dir" ] && [ "$dir" != "$(pwd)" ]; then'
            printf '%s\n' '            cd "$dir" || return'
            printf '%s\n' '        fi'
            printf '%s\n' '    fi'
            printf '%s\n' '}'
            printf '%s\n' ''
            printf '%s\n' 'alias lf="lfcd"'
        } >"$LFCD_TARGET"
    fi

    chmod 644 "$LFCD_TARGET"
    ensure_shell_source "$HOME/.bashrc"

    if command -v zsh >/dev/null 2>&1; then
        ensure_shell_source "$HOME/.zshrc"
    fi

    echo "lfcd installed to $LFCD_TARGET"
}

ensure_shell_source() {
    local rc_file="$1"

    if [ ! -e "$rc_file" ]; then
        touch "$rc_file"
    fi

    if grep -Fq "lfcd.sh" "$rc_file"; then
        return
    fi

    {
        printf '\n'
        printf '%s\n' 'if [ -r "$HOME/.config/shell/lfcd.sh" ]; then'
        printf '%s\n' '    . "$HOME/.config/shell/lfcd.sh"'
        printf '%s\n' 'fi'
    } >>"$rc_file"
}

release_os() {
    case "$(uname -s)" in
        Darwin) printf '%s\n' darwin ;;
        Linux) printf '%s\n' linux ;;
        *) return 1 ;;
    esac
}

release_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) printf '%s\n' amd64 ;;
        arm64 | aarch64) printf '%s\n' arm64 ;;
        armv6l | armv7l) printf '%s\n' arm ;;
        i386 | i686) printf '%s\n' 386 ;;
        *) return 1 ;;
    esac
}

install_from_github_release() {
    local os arch archive url lf_bin

    os="$(release_os)" || return 1
    arch="$(release_arch)" || return 1
    archive="$TMP_DIR/lf-${os}-${arch}.tar.gz"
    url="$LF_RELEASE_BASE_URL/lf-${os}-${arch}.tar.gz"

    echo "==> Installing lf from official GitHub release: lf-${os}-${arch}.tar.gz"
    download "$url" "$archive" || return 1

    tar -xzf "$archive" -C "$TMP_DIR"
    lf_bin="$(find "$TMP_DIR" -type f -name lf | head -n 1)"

    if [ -z "$lf_bin" ]; then
        echo "Could not find lf binary in release archive." >&2
        return 1
    fi

    mkdir -p "$INSTALL_BIN_DIR"
    install -m 0755 "$lf_bin" "$INSTALL_BIN_DIR/lf"
    export PATH="$INSTALL_BIN_DIR:$PATH"
}

install_with_package_manager() {
    case "$(uname -s)" in
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "Need Homebrew to install lf on macOS." >&2
                return 1
            fi
            brew install lf
            ;;
        Linux)
            if command -v dnf >/dev/null 2>&1; then
                run_root dnf install -y lf
            elif command -v apt-get >/dev/null 2>&1; then
                run_root apt-get update
                run_root apt-get install -y lf
            elif command -v pacman >/dev/null 2>&1; then
                run_root pacman -S --needed lf
            elif command -v zypper >/dev/null 2>&1; then
                run_root zypper install -y lf
            else
                echo "No supported package manager found." >&2
                return 1
            fi
            ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
    esac
}

if command -v lf >/dev/null 2>&1; then
    echo "lf is already installed: $(command -v lf)"
    lf -version 2>/dev/null || true
    install_lfcd
    exit 0
fi

if ! install_from_github_release; then
    echo "==> GitHub release install failed; falling back to package manager..."
    if ! install_with_package_manager; then
        echo "Could not install lf automatically." >&2
        exit 1
    fi
fi

echo "lf installed: $(command -v lf)"
install_lfcd
