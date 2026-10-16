$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$HomeDir        = $env:USERPROFILE
$AgyDir         = Join-Path $HomeDir ".gemini\antigravity-cli"
$SettingsFile   = Join-Path $AgyDir "settings.json"
$StatuslineDest = Join-Path $HomeDir ".gemini\statusline.ps1"
$StatuslineSrc  = Join-Path $ScriptDir "statusline.ps1"

$esc    = [char]27
$blue   = "$esc[38;2;0;153;255m"
$green  = "$esc[38;2;0;175;80m"
$red    = "$esc[38;2;255;85;85m"
$yellow = "$esc[38;2;230;200;0m"
$dim    = "$esc[2m"
$reset  = "$esc[0m"

$symCheck = [char]0x2713 # check mark
$symCross = [char]0x2717 # cross mark
$symArrow = [char]0x2192 # right arrow
$symDash  = [string]::new([char]0x2500, 24)

function Write-Ok([string]$msg)   { Write-Host "  ${green}${symCheck}${reset} $msg" }
function Write-Warn([string]$msg) { Write-Host "  ${yellow}!${reset} $msg" }
function Write-Fail([string]$msg) { Write-Host "  ${red}${symCross}${reset} $msg"; exit 1 }

Write-Host ""
Write-Host "  ${blue}agy-statusline installer${reset}"
Write-Host "  ${dim}${symDash}${reset}"
Write-Host ""

# -- Check deps -------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail "Missing dependency: git  $symArrow  install it and retry"
}
Write-Ok "Dependencies found (git, PowerShell native JSON)"

# -- Check agy dir ----------------------------------------
if (-not (Test-Path -Path $AgyDir -PathType Container)) {
    Write-Fail "Antigravity CLI not found at $AgyDir - is agy installed?"
}
Write-Ok "Found agy config at ${dim}$AgyDir${reset}"

# -- Copy script ------------------------------------------
$geminiDir = Split-Path -Parent $StatuslineDest
if (-not (Test-Path -Path $geminiDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $geminiDir | Out-Null
}

if (Test-Path -Path $StatuslineDest -PathType Leaf) {
    Copy-Item -Path $StatuslineDest -Destination "${StatuslineDest}.bak" -Force
    Write-Warn "Backed up existing statusline to ${dim}statusline.ps1.bak${reset}"
}

Copy-Item -Path $StatuslineSrc -Destination $StatuslineDest -Force
Write-Ok "Installed statusline to ${dim}$StatuslineDest${reset}"

# -- Update settings.json ---------------------------------
if (-not (Test-Path -Path $SettingsFile -PathType Leaf)) {
    [System.IO.File]::WriteAllText($SettingsFile, "{}", (New-Object System.Text.UTF8Encoding($false)))
}

$rawSettings = [System.IO.File]::ReadAllText($SettingsFile, [System.Text.Encoding]::UTF8)
if ([string]::IsNullOrWhiteSpace($rawSettings)) {
    $rawSettings = "{}"
}
$settings = $rawSettings | ConvertFrom-Json

$statusCmd  = 'powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\.gemini\statusline.ps1'
$currentCmd = if ($settings.PSObject.Properties['statusLine'] -and $settings.statusLine.command) {
    [string]$settings.statusLine.command
} else {
    ""
}

if ($currentCmd -eq $statusCmd -and $settings.statusLine.enabled -eq $true) {
    Write-Ok "Settings already configured"
} else {
    $statusLineObj = [PSCustomObject]@{
        type    = "command"
        command = $statusCmd
        enabled = $true
    }
    if ($settings.PSObject.Properties['statusLine']) {
        $settings.statusLine = $statusLineObj
    } else {
        $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLineObj -Force
    }
    $newJson = $settings | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($SettingsFile, $newJson + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "Updated ${dim}settings.json${reset} with statusLine config"
}

Write-Host ""
Write-Host "  ${green}Done!${reset} Restart agy to see your status line."
Write-Host ""
