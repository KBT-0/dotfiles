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
