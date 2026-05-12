# Kemal's Dotfiles

Cross-platform development environment configs managed with [chezmoi](https://chezmoi.io).

**Supported platforms:**
- 🪟 Windows (PowerShell 7)
- 🍎 macOS (zsh)
- 🐧 Linux (bash) — WSL Fedora, Debian VPS

---

## Quick start (full install)

Install everything on a new machine with one command.

### macOS / Linux

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply KBT-0
```

### Windows (PowerShell 7)

```powershell
winget install twpayne.chezmoi
chezmoi init --apply KBT-0
```

That's it — chezmoi will:
1. Clone this repo
2. Detect your OS
3. Apply the right configs to the right places

---

## Partial install (just one tool)

Want only Oh My Posh? Or just Starship? Run a single script.

### Available tools

| Tool | Description | Install script |
|---|---|---|
| Oh My Posh | Prompt theming | `install-ohmyposh.*` |
| Shell prediction menus | Live below-prompt history/completion suggestions | `install-shell-predictions.sh` |
| Starship | Cross-platform prompt (alternative) | `install-starship.sh` |
| fzf | Fuzzy command finder (Ctrl+R) | `install-fzf.sh` |
| atuin | Cloud-sync shell history | `install-atuin.sh` |
| PSReadLine config | PowerShell history & predictions | `install-psreadline.ps1` |

### One-line installers

**macOS / Linux:**

```bash
# Oh My Posh
curl -fsSL https://raw.githubusercontent.com/KBT-0/dotfiles/main/scripts/install-ohmyposh.sh | bash

# Starship
curl -fsSL https://raw.githubusercontent.com/KBT-0/dotfiles/main/scripts/install-starship.sh | bash

# fzf
curl -fsSL https://raw.githubusercontent.com/KBT-0/dotfiles/main/scripts/install-fzf.sh | bash

# Live shell prediction menus
curl -fsSL https://raw.githubusercontent.com/KBT-0/dotfiles/main/scripts/install-shell-predictions.sh | bash
```

**Windows (PowerShell):**

```powershell
# Oh My Posh
irm https://raw.githubusercontent.com/KBT-0/dotfiles/main/scripts/install-ohmyposh.ps1 | iex
```

---

## What's in this repo

```
dotfiles/
├── home/                          # chezmoi-managed files (auto-applied)
│   ├── dot_zshrc                  # → ~/.zshrc (macOS)
│   ├── dot_bashrc                 # → ~/.bashrc (Linux)
│   ├── dot_config/                # -> ~/.config/
│   │   └── starship.toml
│   └── AppData/                   # Windows-only files
│       └── Local/...
├── scripts/                       # Standalone single-tool installers
│   ├── install-ohmyposh.sh
│   ├── install-starship.sh
│   └── ...
└── docs/                          # Setup notes
```

Oh My Posh uses the same atomic theme on PowerShell, bash, and zsh:

```text
https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json
```

Live below-prompt command suggestions are aligned as follows:

- PowerShell: `PSReadLine` history predictions in `ListView`
- Bash/Linux: `ble.sh` automatic completion menus
- Zsh/macOS: `zsh-autocomplete` history-first suggestions

---

## Pull just one file with chezmoi

If you already have chezmoi installed and only want one config:

```bash
chezmoi init https://github.com/KBT-0/dotfiles.git  # clone without applying
chezmoi cd                                          # go to source dir
# inspect or selectively copy what you want
chezmoi apply ~/.zshrc                              # apply just .zshrc
```

---

## Update an existing install

```bash
chezmoi update          # pull latest + apply
chezmoi diff            # preview what would change
chezmoi apply -v        # apply (verbose)
```

---

## Editing dotfiles

Don't edit `~/.zshrc` directly — edit it through chezmoi:

```bash
chezmoi edit ~/.zshrc       # opens the source file in $EDITOR
chezmoi apply               # applies your changes
chezmoi cd                  # cd into the source repo
git add . && git commit -m "tweak zsh" && git push
```

---

## License

MIT — feel free to copy anything you find useful.
