#!/usr/bin/env bash
# Bootstrap macOS with this dotfiles setup.

set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/KBT-0/MyDotfiles.git}"
RAW_BASE_URL="${DOTFILES_RAW_BASE_URL:-https://raw.githubusercontent.com/KBT-0/MyDotfiles/main}"
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

load_brew() {
    if command -v brew >/dev/null 2>&1; then
        return
    fi

    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_homebrew() {
    load_brew

    if command -v brew >/dev/null 2>&1; then
        echo "==> Homebrew already installed: $(command -v brew)"
        return
    fi

    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew

    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew installed, but brew is not on PATH. Restart the terminal and re-run this script." >&2
        exit 1
    fi
}

install_base_packages() {
    echo "==> Installing base packages..."
    brew update
    brew install chezmoi git node zsh oh-my-posh lf zsh-autosuggestions zsh-history-substring-search
}

apply_dotfiles() {
    echo "==> Applying dotfiles from $REPO_URL..."

    if [ -d "$CHEZMOI_SOURCE_DIR/.git" ]; then
        chezmoi update
    else
        chezmoi init --apply "$REPO_URL"
    fi
}

run_repo_script() {
    local script_name="$1"
    local local_script="$CHEZMOI_SOURCE_DIR/scripts/$script_name"
    local remote_script="$RAW_BASE_URL/scripts/$script_name"

    echo "==> Running $script_name..."

    if [ -r "$local_script" ]; then
        bash "$local_script"
    else
        curl -fsSL "$remote_script" | bash
    fi
}

install_jetbrains_font() {
    echo "==> Installing JetBrainsMono Nerd Font..."
    if command -v oh-my-posh >/dev/null 2>&1; then
        oh-my-posh font install JetBrainsMono || true
    fi
}

main() {
    if [ "$(uname -s)" != "Darwin" ]; then
        echo "This script is for macOS only." >&2
        exit 1
    fi

    install_homebrew
    install_base_packages
    apply_dotfiles

    run_repo_script install-ohmyposh.sh
    run_repo_script install-lf.sh
    run_repo_script install-shell-predictions.sh
    install_jetbrains_font

    echo "==> Re-applying dotfiles after tool installation..."
    chezmoi apply

    echo ""
    echo "==> Done. Restart the terminal or run: exec zsh"
    echo "==> Quick checks:"
    echo "    oh-my-posh --version"
    echo "    lf -version"
    echo "    type lfcd"
    echo "    command -v is && is doctor"
    echo "    chezmoi status"
}

main "$@"
