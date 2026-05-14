# Install lf, the terminal file manager, and the PowerShell lfcd wrapper.

$ErrorActionPreference = "Stop"

$LfReleaseBaseUrl = "https://github.com/gokcehan/lf/releases/latest/download"
$InstallDir = Join-Path $HOME ".local\bin"

function Write-Step {
    param([string] $Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
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

function Install-LfBinary {
    if (Get-Command lf.exe -ErrorAction SilentlyContinue) {
        Write-Host "lf is already installed: $((Get-Command lf.exe).Source)" -ForegroundColor Green
        lf.exe -version 2>$null
        return
    }

    $arch = Get-LfWindowsArch
    $assetName = "lf-windows-$arch.zip"
    $url = "$LfReleaseBaseUrl/$assetName"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lf-$([System.Guid]::NewGuid())"
    $zipPath = Join-Path $tempDir $assetName

    Write-Step "Installing lf from official GitHub release: $assetName"
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

        $lfExe = Get-ChildItem -Path $tempDir -Recurse -Filter "lf.exe" | Select-Object -First 1
        if (-not $lfExe) {
            throw "Could not find lf.exe in $assetName"
        }

        Copy-Item -LiteralPath $lfExe.FullName -Destination (Join-Path $InstallDir "lf.exe") -Force
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-UserPath $InstallDir
    Write-Host "lf installed: $(Join-Path $InstallDir "lf.exe")" -ForegroundColor Green
}

function Ensure-PowerShellLfcd {
    $profileDir = Split-Path -Parent $PROFILE
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }

    $beginMarker = "# >>> lfcd integration >>>"
    $endMarker = "# <<< lfcd integration <<<"
    $block = @"
$beginMarker
# lf file manager integration.
`$LfBinDir = Join-Path `$HOME ".local\bin"
if ((Test-Path -LiteralPath `$LfBinDir) -and ((`$env:Path -split ';') -notcontains `$LfBinDir)) {
    `$env:Path = "`$LfBinDir;`$env:Path"
}

function lfcd {
    param(
        [Parameter(ValueFromRemainingArguments = `$true)]
        [string[]] `$LfArgs
    )

    `$lfCommand = Get-Command lf.exe -ErrorAction SilentlyContinue
    if (-not `$lfCommand) {
        Write-Warning "lf.exe not found. Run scripts/install-lf.ps1 from the dotfiles repo."
        return
    }

    `$lastDir = & `$lfCommand.Source -print-last-dir @LfArgs
    if (`$LASTEXITCODE -ne 0) {
        return
    }

    if (`$lastDir -and (Test-Path -LiteralPath `$lastDir -PathType Container)) {
        Set-Location -LiteralPath `$lastDir
    }
}

Set-Alias -Name lf -Value lfcd -Option AllScope -Force
$endMarker
"@

    $content = Get-Content -LiteralPath $PROFILE -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        $content = ""
    }

    if ($content.Contains($beginMarker)) {
        $pattern = "(?s)" + [regex]::Escape($beginMarker) + ".*?" + [regex]::Escape($endMarker)
        $content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
        Set-Content -LiteralPath $PROFILE -Value $content -Encoding UTF8
    } elseif ($content -match 'function\s+lfcd') {
        Write-Host "PowerShell profile already contains lfcd." -ForegroundColor Green
    } else {
        Add-Content -LiteralPath $PROFILE -Value "`n$block" -Encoding UTF8
    }

    Write-Host "lfcd added to PowerShell profile: $PROFILE" -ForegroundColor Green
}

Install-LfBinary
Ensure-PowerShellLfcd

Write-Host ""
Write-Host "==> Done. Open a new PowerShell tab, then run:" -ForegroundColor Cyan
Write-Host "    lf -version"
Write-Host "    Get-Command lfcd"
