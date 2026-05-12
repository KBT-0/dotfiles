#!/usr/bin/env bash
# Install the IDE-style below-prompt suggestion runtime used by Bash/Zsh.

set -euo pipefail

PREFIX="${INSHELLISENSE_NPM_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
IS_BIN="$BIN_DIR/is"

if ! command -v npm >/dev/null 2>&1; then
    echo "Need npm to install inshellisense." >&2
    echo "Install Node.js/npm first, then re-run this script." >&2
    exit 1
fi

mkdir -p "$PREFIX"
export PATH="$BIN_DIR:$PATH"

echo "==> Installing inshellisense into $PREFIX..."
npm install -g --prefix "$PREFIX" @microsoft/inshellisense

if [ ! -x "$IS_BIN" ]; then
    echo "inshellisense installed, but '$IS_BIN' was not created." >&2
    exit 1
fi

echo "==> Generating Bash shell plugin..."
"$IS_BIN" init bash >/dev/null

if command -v zsh >/dev/null 2>&1; then
    echo "==> Generating Zsh shell plugin..."
    "$IS_BIN" init zsh >/dev/null
fi

echo ""
echo "==> Done. Re-run chezmoi apply and restart your shell."
