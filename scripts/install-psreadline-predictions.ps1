# Install optional PowerShell PSReadLine ListView predictions.
# This disables inshellisense in the PowerShell profile to avoid competing UIs.

$ErrorActionPreference = "Stop"

$InshellisenseMarker = "# >>> inshellisense integration >>>"
$PSReadLineBeginMarker = "# >>> PSReadLine prediction integration >>>"
$PSReadLineEndMarker = "# <<< PSReadLine prediction integration <<<"

function Write-Step {
    param([string] $Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Profile {
    $profileDir = Split-Path -Parent $PROFILE
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }
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
        Write-Warning "PSGallery could not be prepared: $($_.Exception.Message)"
    }
}

function Ensure-PSReadLine {
    Write-Step "Installing/updating PSReadLine..."

    if (Get-Module -ListAvailable -Name PSReadLine) {
        Write-Host "PSReadLine already available." -ForegroundColor Green
        return
    }

    Ensure-PSGallery

    try {
        Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
    } catch {
        Write-Warning "PSReadLine install/update skipped: $($_.Exception.Message)"
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

function Enable-PSReadLineProfile {
    Ensure-Profile

    $content = Get-Content -LiteralPath $PROFILE -Raw -ErrorAction SilentlyContinue
    $content = Remove-InshellisenseBlock -Content $content
    $content = Remove-PSReadLinePredictionBlock -Content $content

    $block = @"
$PSReadLineBeginMarker
# Optional PowerShell-native prediction UI. Running install-shell-predictions.ps1 disables this block.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    try { Set-PSReadLineOption -PredictionSource History } catch {}
    try { Set-PSReadLineOption -PredictionViewStyle ListView } catch {}
    try { Set-PSReadLineOption -EditMode Windows } catch {}
    try { Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete } catch {}
}
$PSReadLineEndMarker
"@

    if ($content) {
        $content = "$($content.TrimEnd())`r`n`r`n$block"
    } else {
        $content = $block
    }

    Set-Content -LiteralPath $PROFILE -Value $content -Encoding UTF8
}

Ensure-PSReadLine
Enable-PSReadLineProfile

Write-Host ""
Write-Host "==> Done. PSReadLine ListView is enabled and inshellisense is disabled in `$PROFILE." -ForegroundColor Cyan
Write-Host "==> Open a new PowerShell tab." -ForegroundColor Cyan
