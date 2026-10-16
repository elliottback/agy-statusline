$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$HomeDir          = $env:USERPROFILE
$StatuslineDest   = Join-Path $HomeDir ".gemini\statusline.ps1"
$StatuslineBackup = "${StatuslineDest}.bak"
$SettingsFile     = Join-Path $HomeDir ".gemini\antigravity-cli\settings.json"

$esc    = [char]27
$blue   = "$esc[38;2;0;153;255m"
$green  = "$esc[38;2;0;175;80m"
$yellow = "$esc[38;2;230;200;0m"
$dim    = "$esc[2m"
$reset  = "$esc[0m"

$symCheck = [char]0x2713 # check mark
$symDash  = [string]::new([char]0x2500, 26)

function Write-Ok([string]$msg)   { Write-Host "  ${green}${symCheck}${reset} $msg" }
function Write-Warn([string]$msg) { Write-Host "  ${yellow}!${reset} $msg" }

Write-Host ""
Write-Host "  ${blue}agy-statusline uninstaller${reset}"
Write-Host "  ${dim}${symDash}${reset}"
Write-Host ""

# Restore backup or remove
if (Test-Path -Path $StatuslineBackup -PathType Leaf) {
    Copy-Item -Path $StatuslineBackup -Destination $StatuslineDest -Force
    Remove-Item -Path $StatuslineBackup -Force
    Write-Ok "Restored previous statusline from backup"
} elseif (Test-Path -Path $StatuslineDest -PathType Leaf) {
    Remove-Item -Path $StatuslineDest -Force
    Write-Ok "Removed ${dim}statusline.ps1${reset}"
} else {
    Write-Warn "No statusline found - nothing to remove"
}

# Clean settings.json
if (Test-Path -Path $SettingsFile -PathType Leaf) {
    $rawSettings = [System.IO.File]::ReadAllText($SettingsFile, [System.Text.Encoding]::UTF8)
    if (-not [string]::IsNullOrWhiteSpace($rawSettings)) {
        $settings = $rawSettings | ConvertFrom-Json
        if ($settings.PSObject.Properties['statusLine']) {
            $settings.PSObject.Properties.Remove('statusLine')
            $newJson = $settings | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($SettingsFile, $newJson + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
        }
    }
    Write-Ok "Removed statusLine from ${dim}settings.json${reset}"
}

Write-Host ""
Write-Host "  ${green}Done!${reset} Restart agy to apply changes."
Write-Host ""
