# bootstrap-windows.ps1
# Bootstrap Windows PowerShell 7 with this dotfiles setup.

$ErrorActionPreference = "Stop"

$RepoUrl = if ($env:DOTFILES_REPO_URL) { $env:DOTFILES_REPO_URL } else { "https://github.com/KBT-0/MyDotfiles.git" }
$LfReleaseBaseUrl = "https://github.com/gokcehan/lf/releases/latest/download"

function Write-Step {
    param([string] $Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $extraPaths = @(
        "$HOME\.local\bin",
        "$env:LOCALAPPDATA\Programs\oh-my-posh\bin",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramFiles\PowerShell\7"
    )

    $env:Path = (($machinePath, $userPath) + $extraPaths | Where-Object { $_ }) -join ";"
}

function Require-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from Microsoft Store, then run this script again."
    }
}

function Install-WingetPackage {
    param(
        [string] $Id,
        [string] $Name,
        [string] $Command
    )

    Refresh-Path
    if ($Command -and (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "$Name already installed." -ForegroundColor Green
        return
    }

    Write-Step "Installing $Name..."
    winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
}

function Add-UserPath {
    param([string] $Path)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) {
        $parts = $userPath -split ';' | Where-Object { $_ }
    }

    if ($parts -notcontains $Path) {
        $newPath = (($parts + $Path) | Where-Object { $_ }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    if (($env:Path -split ';') -notcontains $Path) {
        $env:Path = "$Path;$env:Path"
    }
}

function Get-LfWindowsArch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { return "amd64" }
        "ARM64" { return "amd64" }
        "x86" { return "386" }
        default { return "amd64" }
    }
}

function Install-Lf {
    Write-Step "Installing lf..."
    Refresh-Path

    if (Get-Command lf.exe -ErrorAction SilentlyContinue) {
        Write-Host "lf already installed." -ForegroundColor Green
        return
    }

    $installDir = Join-Path $HOME ".local\bin"
    $arch = Get-LfWindowsArch
    $assetName = "lf-windows-$arch.zip"
    $url = "$LfReleaseBaseUrl/$assetName"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lf-$([System.Guid]::NewGuid())"
    $zipPath = Join-Path $tempDir $assetName

    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

        $lfExe = Get-ChildItem -Path $tempDir -Recurse -Filter "lf.exe" | Select-Object -First 1
        if (-not $lfExe) {
            throw "Could not find lf.exe in $assetName"
        }

        Copy-Item -LiteralPath $lfExe.FullName -Destination (Join-Path $installDir "lf.exe") -Force
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-UserPath $installDir
    Refresh-Path
}

function Ensure-PSGallery {
    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }

        $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($repo -and $repo.InstallationPolicy -ne "Trusted") {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
    } catch {
        Write-Warning "PSGallery hazirlanamadi: $($_.Exception.Message)"
    }
}

function Ensure-PSReadLine {
    Write-Step "Installing/updating PSReadLine..."
    Ensure-PSGallery

    try {
        Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
    } catch {
        Write-Warning "PSReadLine kurulumu atlandi: $($_.Exception.Message)"
    }
}

function Ensure-PowerShellProfile {
    Write-Step "Writing PowerShell 7 profile..."

    $profileDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell"
    $profilePath = Join-Path $profileDir "Microsoft.PowerShell_profile.ps1"
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

    $profileContent = @'
# Oh My Posh prompt - atomic theme shared with bash/zsh profiles.
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config atomic | Invoke-Expression
}

# >>> lfcd integration >>>
# lf file manager integration.
$LfBinDir = Join-Path $HOME ".local\bin"
if ((Test-Path -LiteralPath $LfBinDir) -and (($env:Path -split ';') -notcontains $LfBinDir)) {
    $env:Path = "$LfBinDir;$env:Path"
}

function lfcd {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $LfArgs
    )

    $lfCommand = Get-Command lf.exe -ErrorAction SilentlyContinue
    if (-not $lfCommand) {
        Write-Warning "lf.exe not found. Run scripts/install-lf.ps1 from the dotfiles repo."
        return
    }

    $lastDir = & $lfCommand.Source -print-last-dir @LfArgs
    if ($LASTEXITCODE -ne 0) {
        return
    }

    if ($lastDir -and (Test-Path -LiteralPath $lastDir -PathType Container)) {
        Set-Location -LiteralPath $lastDir
    }
}

Set-Alias -Name lf -Value lfcd -Option AllScope -Force
# <<< lfcd integration <<<

# PSReadLine: command history prediction list.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    try { Set-PSReadLineOption -PredictionSource History } catch {}
    try { Set-PSReadLineOption -PredictionViewStyle ListView } catch {}
    try { Set-PSReadLineOption -EditMode Windows } catch {}
    try { Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete } catch {}
}
'@

    Set-Content -Path $profilePath -Value $profileContent -Encoding UTF8
}

function Install-JetBrainsNerdFont {
    Write-Step "Installing JetBrainsMono Nerd Font..."
    Refresh-Path

    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        try {
            oh-my-posh font install JetBrainsMono
        } catch {
            Write-Warning "JetBrainsMono font could not be installed automatically: $($_.Exception.Message)"
            Write-Warning "Install manually if needed: oh-my-posh font install JetBrainsMono"
        }
    }
}

function Apply-Dotfiles {
    Write-Step "Applying dotfiles from $RepoUrl..."
    Refresh-Path

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        throw "chezmoi PATH icinde bulunamadi. Yeni PowerShell acip script'i tekrar calistir."
    }

    $sourceDir = Join-Path $HOME ".local\share\chezmoi"
    if (Test-Path (Join-Path $sourceDir ".git")) {
        chezmoi update
    } else {
        chezmoi init --apply $RepoUrl
    }
}

Require-Winget

Install-WingetPackage -Id "Microsoft.PowerShell" -Name "PowerShell 7" -Command "pwsh"
Install-WingetPackage -Id "Microsoft.WindowsTerminal" -Name "Windows Terminal" -Command "wt"
Install-WingetPackage -Id "twpayne.chezmoi" -Name "chezmoi" -Command "chezmoi"
Install-WingetPackage -Id "JanDeDobbeleer.OhMyPosh" -Name "Oh My Posh" -Command "oh-my-posh"
Install-Lf

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
Ensure-PSReadLine
Apply-Dotfiles
Ensure-PowerShellProfile
Install-JetBrainsNerdFont

Write-Host ""
Write-Host "==> Done. Open a new PowerShell 7 tab in Windows Terminal." -ForegroundColor Cyan
Write-Host "==> Set the Windows Terminal profile font to JetBrainsMono Nerd Font." -ForegroundColor Cyan
Write-Host "==> Quick checks:" -ForegroundColor Cyan
Write-Host "    `$PSVersionTable.PSVersion"
Write-Host "    oh-my-posh --version"
Write-Host "    lf -version"
Write-Host "    Get-Command lfcd"
Write-Host "    Get-Module PSReadLine -ListAvailable"
Write-Host "    chezmoi status"
