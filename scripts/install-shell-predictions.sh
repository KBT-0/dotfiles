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

patch_bash_oh_my_posh_order() {
    local integration_file="$HOME/.inshellisense/shell/shellIntegration.bash"

    if [ ! -f "$integration_file" ]; then
        echo "Bash shell plugin was generated, but '$integration_file' was not found." >&2
        exit 1
    fi

    if grep -Fq "MyDotfiles Oh My Posh compatibility" "$integration_file"; then
        sed -i '/^# MyDotfiles Oh My Posh compatibility\.$/,$d' "$integration_file"
    fi

    cat >>"$integration_file" <<'EOF'

# MyDotfiles Oh My Posh compatibility.
# In an inshellisense session, Oh My Posh must render first and inshellisense
# must add its OSC 6973 prompt markers after that render.
if [[ -n "${ISTERM:-}" && -n "${bash_preexec_imported:-}" ]] && type _omp_hook >/dev/null 2>&1 && type __is_precmd >/dev/null 2>&1; then
    __mydotfiles_remove_omp_prompt_command() {
        local cmd filtered=()

        if declare -p PROMPT_COMMAND 2>/dev/null | grep -q '^declare -[^ ]*a'; then
            for cmd in "${PROMPT_COMMAND[@]}"; do
                [[ "$cmd" == "_omp_hook" ]] && continue
                filtered+=("$cmd")
            done
            PROMPT_COMMAND=("${filtered[@]}")
        elif [[ "${PROMPT_COMMAND:-}" == *"_omp_hook"* ]]; then
            PROMPT_COMMAND="${PROMPT_COMMAND//_omp_hook/}"
            PROMPT_COMMAND="${PROMPT_COMMAND//;;/;}"
            PROMPT_COMMAND="${PROMPT_COMMAND%;}"
            PROMPT_COMMAND="${PROMPT_COMMAND#;}"
        fi

        if declare -p __is_original_prompt_command 2>/dev/null | grep -q '^declare -[^ ]*a'; then
            filtered=()
            for cmd in "${__is_original_prompt_command[@]}"; do
                [[ "$cmd" == "_omp_hook" ]] && continue
                filtered+=("$cmd")
            done
            __is_original_prompt_command=("${filtered[@]}")
        elif [[ "${__is_original_prompt_command:-}" == *"_omp_hook"* ]]; then
            __is_original_prompt_command="${__is_original_prompt_command//_omp_hook/}"
            __is_original_prompt_command="${__is_original_prompt_command//;;/;}"
            __is_original_prompt_command="${__is_original_prompt_command%;}"
            __is_original_prompt_command="${__is_original_prompt_command#;}"
        fi
    }

    __mydotfiles_omp_then_inshellisense_precmd() {
        _omp_hook
        __is_precmd
    }

    __mydotfiles_remove_omp_prompt_command

    if declare -p precmd_functions >/dev/null 2>&1; then
        __mydotfiles_filtered_precmd_functions=()
        for __mydotfiles_precmd_function in "${precmd_functions[@]}"; do
            [[ "$__mydotfiles_precmd_function" == "__is_precmd" ]] && continue
            [[ "$__mydotfiles_precmd_function" == "__mydotfiles_omp_then_inshellisense_precmd" ]] && continue
            __mydotfiles_filtered_precmd_functions+=("$__mydotfiles_precmd_function")
        done
        precmd_functions=(__mydotfiles_omp_then_inshellisense_precmd "${__mydotfiles_filtered_precmd_functions[@]}")
        unset __mydotfiles_filtered_precmd_functions __mydotfiles_precmd_function
    fi
fi
EOF
}

echo "==> Generating Bash shell plugin..."
"$IS_BIN" init bash >/dev/null
patch_bash_oh_my_posh_order

if command -v zsh >/dev/null 2>&1; then
    echo "==> Generating Zsh shell plugin..."
    "$IS_BIN" init zsh >/dev/null
fi

echo ""
echo "==> Done. Re-run chezmoi apply and restart your shell."
