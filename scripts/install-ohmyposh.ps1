# install-ohmyposh.ps1
# Standalone installer for Oh My Posh on Windows PowerShell 7+
# Usage: irm https://raw.githubusercontent.com/KBT-0/MyDotfiles/main/scripts/install-ohmyposh.ps1 | iex

Write-Host "==> Installing Oh My Posh..." -ForegroundColor Cyan

# 1. Install Oh My Posh via winget
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-source-agreements --accept-package-agreements
    Write-Host "Oh My Posh installed. Restart PowerShell to refresh PATH." -ForegroundColor Yellow
} else {
    Write-Host "Oh My Posh already installed." -ForegroundColor Green
}

# 2. Ensure $PROFILE exists
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Write-Host "Created PowerShell profile: $PROFILE" -ForegroundColor Green
}

# 3. Add Oh My Posh init to profile (skip if already present)
$initLine = 'oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json" | Invoke-Expression'
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -notmatch 'oh-my-posh init pwsh') {
    Add-Content $PROFILE "`n# Oh My Posh prompt"
    Add-Content $PROFILE $initLine
    Write-Host "Added Oh My Posh init to `$PROFILE" -ForegroundColor Green
} else {
    Write-Host "Oh My Posh init already in `$PROFILE — skipping" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Done! Restart PowerShell or run: . `$PROFILE" -ForegroundColor Cyan
Write-Host "==> Don't forget to install a Nerd Font: https://www.nerdfonts.com" -ForegroundColor Cyan
