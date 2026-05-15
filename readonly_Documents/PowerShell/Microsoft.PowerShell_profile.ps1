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

# >>> inshellisense integration >>>
# Default prediction UI. Keep this block last in the profile.
$InshellisenseNodeBin = Join-Path $env:ProgramFiles "nodejs"
if ((Test-Path -LiteralPath $InshellisenseNodeBin) -and (($env:Path -split ';') -notcontains $InshellisenseNodeBin)) {
    $env:Path = "$InshellisenseNodeBin;$env:Path"
}

$InshellisenseNpmBin = Join-Path $env:APPDATA "npm"
if ((Test-Path -LiteralPath $InshellisenseNpmBin) -and (($env:Path -split ';') -notcontains $InshellisenseNpmBin)) {
    $env:Path = "$InshellisenseNpmBin;$env:Path"
}

$InshellisensePwshInit = Join-Path $HOME ".inshellisense\init\pwsh\init.ps1"
if (Test-Path -LiteralPath $InshellisensePwshInit -PathType Leaf) {
    . $InshellisensePwshInit
}
