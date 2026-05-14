#!/usr/bin/env bash
# install-ohmyposh.sh
# Standalone installer for Oh My Posh on macOS / Linux
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/KBT-0/MyDotfiles/main/scripts/install-ohmyposh.sh | bash

set -e

echo "==> Installing Oh My Posh..."

# 1. Detect shell and OS
OS="$(uname -s)"
SHELL_NAME="$(basename "$SHELL")"

case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc"; INIT_SHELL="zsh" ;;
    bash) RC_FILE="$HOME/.bashrc"; INIT_SHELL="bash" ;;
    fish) RC_FILE="$HOME/.config/fish/config.fish"; INIT_SHELL="fish" ;;
    *)
        echo "Unsupported shell: $SHELL_NAME"
        echo "Manually add the init line to your shell's rc file."
        exit 1
        ;;
esac

echo "Detected: $OS with $SHELL_NAME ($RC_FILE)"
THEME_URL="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json"

# 2. Install Oh My Posh
if ! command -v oh-my-posh >/dev/null 2>&1; then
    if [[ "$OS" == "Darwin" ]]; then
        # macOS: prefer Homebrew
        if command -v brew >/dev/null 2>&1; then
            brew install jandedobbeleer/oh-my-posh/oh-my-posh
        else
            echo "Homebrew not found. Install from https://brew.sh, then re-run this script."
            exit 1
        fi
    else
        # Linux: official installer
        curl -s https://ohmyposh.dev/install.sh | bash -s
    fi
    echo "Oh My Posh installed."
else
    echo "Oh My Posh already installed."
fi

# 3. Ensure rc file exists
[ -f "$RC_FILE" ] || touch "$RC_FILE"

# 4. Add init line. If another Oh My Posh init exists, replace it so every
# platform uses the same atomic theme as the Windows PowerShell profile.
INIT_LINE="eval \"\$(oh-my-posh init $INIT_SHELL --config $THEME_URL)\""

if grep -q "oh-my-posh init" "$RC_FILE"; then
    sed -i.bak "s|.*oh-my-posh init.*|$INIT_LINE|" "$RC_FILE"
    echo "Updated Oh My Posh init in $RC_FILE"
else
    {
        echo ""
        echo "# Oh My Posh prompt"
        echo "$INIT_LINE"
    } >> "$RC_FILE"
    echo "Added Oh My Posh init to $RC_FILE"
fi

echo ""
echo "==> Done! Restart your terminal or run: source $RC_FILE"
echo "==> Don't forget to install a Nerd Font: https://www.nerdfonts.com"
