# Install the default PowerShell prediction UI: inshellisense.
# This disables PSReadLine ListView/MenuComplete profile hooks to avoid conflicts.

$ErrorActionPreference = "Stop"

$InshellisenseMarker = "# >>> inshellisense integration >>>"
$PSReadLineBeginMarker = "# >>> PSReadLine prediction integration >>>"
$PSReadLineEndMarker = "# <<< PSReadLine prediction integration <<<"

function Write-Step {
    param([string] $Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $extraPaths = @(
        "$HOME\.local\bin",
        "$env:APPDATA\npm",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramFiles\nodejs",
        "$env:ProgramFiles\PowerShell\7"
    )

    $env:Path = (($machinePath, $userPath) + $extraPaths | Where-Object { $_ }) -join ";"
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

function Ensure-Node {
    Refresh-Path
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "npm not found and winget is unavailable. Install Node.js LTS, then re-run this script."
    }

    Write-Step "Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm still not found. Open a new PowerShell tab and re-run this script."
    }
}

function Ensure-Profile {
    $profileDir = Split-Path -Parent $PROFILE
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }
}

function Remove-InshellisenseBlock {
    param([string] $Content)

    if (-not $Content) {
        return ""
    }

    $pattern = "(?s)" + [regex]::Escape($InshellisenseMarker) + ".*$"
    return ([regex]::Replace($Content, $pattern, "")).TrimEnd()
}

function Remove-PSReadLinePredictionBlock {
    param([string] $Content)

    if (-not $Content) {
        return ""
    }

    if ($Content.Contains($PSReadLineBeginMarker)) {
        $pattern = "(?s)\s*" + [regex]::Escape($PSReadLineBeginMarker) + ".*?" + [regex]::Escape($PSReadLineEndMarker)
        $Content = [regex]::Replace($Content, $pattern, "")
    }

    $lines = $Content -split "`r?`n"
    $skipLegacyBlock = $false
    $filtered = foreach ($line in $lines) {
        if ($line -eq "# PSReadLine: command history prediction list.") {
            $skipLegacyBlock = $true
            continue
        }

        if ($skipLegacyBlock) {
            if ($line -eq "}") {
                $skipLegacyBlock = $false
            }
            continue
        }

        if ($line -match 'Set-PSReadLineOption\s+-PredictionSource') { continue }
        if ($line -match 'Set-PSReadLineOption\s+-PredictionViewStyle') { continue }
        if ($line -match 'Set-PSReadLineKeyHandler\s+-Key\s+Tab\s+-Function\s+MenuComplete') { continue }
        $line
    }

    return (($filtered -join "`r`n").TrimEnd())
}

function Enable-InshellisenseProfile {
    Ensure-Profile

    $content = Get-Content -LiteralPath $PROFILE -Raw -ErrorAction SilentlyContinue
    $content = Remove-InshellisenseBlock -Content $content
    $content = Remove-PSReadLinePredictionBlock -Content $content

    $block = @"
$InshellisenseMarker
# Default prediction UI. Keep this block last in the profile.
`$InshellisenseNodeBin = Join-Path `$env:ProgramFiles "nodejs"
if ((Test-Path -LiteralPath `$InshellisenseNodeBin) -and ((`$env:Path -split ';') -notcontains `$InshellisenseNodeBin)) {
    `$env:Path = "`$InshellisenseNodeBin;`$env:Path"
}

`$InshellisenseNpmBin = Join-Path `$env:APPDATA "npm"
if ((Test-Path -LiteralPath `$InshellisenseNpmBin) -and ((`$env:Path -split ';') -notcontains `$InshellisenseNpmBin)) {
    `$env:Path = "`$InshellisenseNpmBin;`$env:Path"
}

`$InshellisensePwshInit = Join-Path `$HOME ".inshellisense\init\pwsh\init.ps1"
if (Test-Path -LiteralPath `$InshellisensePwshInit -PathType Leaf) {
    . `$InshellisensePwshInit
}
"@

    if ($content) {
        $content = "$($content.TrimEnd())`r`n`r`n$block"
    } else {
        $content = $block
    }

    Set-Content -LiteralPath $PROFILE -Value $content -Encoding UTF8
}

Write-Step "Installing inshellisense..."
Ensure-Node
npm install -g @microsoft/inshellisense

$npmBin = Join-Path $env:APPDATA "npm"
if (Test-Path -LiteralPath $npmBin) {
    Add-UserPath $npmBin
}
Refresh-Path

if (-not (Get-Command is -ErrorAction SilentlyContinue)) {
    Write-Warning "inshellisense was installed, but 'is' is not visible in this PowerShell session yet. Open a new tab if needed."
} else {
    $isCommand = Get-Command is -ErrorAction SilentlyContinue
    & $isCommand.Source init pwsh | Out-Null
}

Enable-InshellisenseProfile

Write-Host ""
Write-Host "==> Done. inshellisense is enabled and PSReadLine prediction hooks are disabled in `$PROFILE." -ForegroundColor Cyan
Write-Host "==> Open a new PowerShell tab, then run: is doctor" -ForegroundColor Cyan
