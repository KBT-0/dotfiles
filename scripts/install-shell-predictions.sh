#!/usr/bin/env bash
# Install the live prediction engines used by the dotfiles:
# - ble.sh for Bash/Linux
# - zsh-autocomplete for Zsh/macOS

set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
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
        echo "Need curl or wget to download shell prediction tools." >&2
        exit 1
    fi
}

extract_ble_archive() {
    local archive="$1"
    local output_dir="$2"

    if command -v xz >/dev/null 2>&1; then
        tar -xJf "$archive" -C "$output_dir"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$archive" "$output_dir" <<'PY'
import sys
import tarfile

archive, output_dir = sys.argv[1], sys.argv[2]
with tarfile.open(archive, mode="r:xz") as tar:
    tar.extractall(output_dir)
PY
        return
    fi

    echo "Need xz or python3 to unpack ble.sh nightly releases." >&2
    exit 1
}

install_blesh() {
    if ! command -v bash >/dev/null 2>&1; then
        return
    fi

    if ! command -v awk >/dev/null 2>&1; then
        echo "Need awk to install ble.sh. On Fedora, install package: gawk" >&2
        exit 1
    fi

    echo "==> Installing ble.sh for Bash..."
    mkdir -p "$DATA_HOME"
    download \
        "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz" \
        "$TMP_DIR/ble-nightly.tar.xz"
    extract_ble_archive "$TMP_DIR/ble-nightly.tar.xz" "$TMP_DIR"
    bash "$TMP_DIR/ble-nightly/ble.sh" --install "$DATA_HOME"
}

install_zsh_autocomplete() {
    if ! command -v zsh >/dev/null 2>&1; then
        return
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "Need git to install zsh-autocomplete." >&2
        exit 1
    fi

    local target="$DATA_HOME/zsh-autocomplete"
    echo "==> Installing zsh-autocomplete for Zsh..."

    if [ -d "$target/.git" ]; then
        git -C "$target" pull --ff-only
    else
        git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "$target"
    fi
}

install_blesh
install_zsh_autocomplete

echo ""
echo "==> Done. Re-run chezmoi apply and restart your shell."
