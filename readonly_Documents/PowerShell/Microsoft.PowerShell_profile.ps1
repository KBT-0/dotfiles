# Oh My Posh prompt - atomic theme shared with bash/zsh profiles.
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config atomic | Invoke-Expression
}

# PSReadLine: command history prediction list.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    try { Set-PSReadLineOption -PredictionSource History } catch {}
    try { Set-PSReadLineOption -PredictionViewStyle ListView } catch {}
    try { Set-PSReadLineOption -EditMode Windows } catch {}
    try { Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete } catch {}
}
