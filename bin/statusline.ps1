$ErrorActionPreference = 'SilentlyContinue'

# Ensure UTF-8 output encoding for Unicode icons and symbols
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$rawInput = [Console]::In.ReadToEnd()

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    [Console]::Out.Write("agy")
    exit 0
}

try {
    $data = $rawInput | ConvertFrom-Json
} catch {
    [Console]::Out.Write("agy")
    exit 0
}

# -- Colors ----------------------------------------------
$esc     = [char]27
$blue    = "$esc[38;2;0;153;255m"
$orange  = "$esc[38;2;255;176;85m"
$green   = "$esc[38;2;0;175;80m"
$cyan    = "$esc[38;2;86;182;194m"
$red     = "$esc[38;2;255;85;85m"
$yellow  = "$esc[38;2;230;200;0m"
$white   = "$esc[38;2;220;220;220m"
$magenta = "$esc[38;2;180;140;255m"
$dim     = "$esc[2m"
$reset   = "$esc[0m"

# -- Unicode Symbols (Codepoint-safe for Windows PowerShell 5.1) --
$symBar   = [char]0x2502                             # vertical bar
$symPen   = "$([char]0x270D)$([char]0xFE0F)"         # writing hand
$symZap   = [char]0x26A1                             # high voltage
$symFull  = [char]0x25CF                             # filled circle
$symEmpty = [char]0x25CB                             # empty circle
$symReset = [char]0x27F3                             # clockwise arrow

$sep = " ${dim}${symBar}${reset} "

# -- Helpers ---------------------------------------------
function Get-ColorForPct([int]$pct) {
    if ($pct -ge 90)     { return $red }
    elseif ($pct -ge 70) { return $yellow }
    elseif ($pct -ge 50) { return $orange }
    else                 { return $green }
}

function Build-Bar([int]$pct, [int]$width) {
    if ($pct -lt 0)   { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }

    $filled = [int][Math]::Floor(($pct * $width) / 100)
    $empty  = $width - $filled
    $barColor = Get-ColorForPct $pct

    $filledStr = [string]::new($symFull, $filled)
    $emptyStr  = [string]::new($symEmpty, $empty)

    return "${barColor}${filledStr}${dim}${emptyStr}${reset}"
}

function Format-ResetTime([string]$resetIso, [string]$style) {
    if ([string]::IsNullOrWhiteSpace($resetIso) -or $resetIso -eq "null") {
        return ""
    }
    try {
        $dt = [DateTimeOffset]::Parse($resetIso, [System.Globalization.CultureInfo]::InvariantCulture).LocalDateTime
        if ($style -eq "time") {
            return $dt.ToString("HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
        } else {
            return $dt.ToString("MMM d, HH:mm", [System.Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant()
        }
    } catch {
        return ""
    }
}

# -- Extract JSON data ------------------------------------
$modelName = if ($data.model -and $data.model.display_name) { [string]$data.model.display_name } else { "agy" }

$cwd = if ($data.cwd -and [string]$data.cwd -ne "null") { [string]$data.cwd } else { "" }
if ([string]::IsNullOrWhiteSpace($cwd)) {
    $cwd = (Get-Location).Path
}
$trimmedCwd = $cwd.TrimEnd('\', '/')
$dirname = if ($trimmedCwd) { Split-Path -Leaf $trimmedCwd } else { $cwd }

$usedPctRaw = if ($data.context_window -and $null -ne $data.context_window.used_percentage) {
    [double]$data.context_window.used_percentage
} else {
    0.0
}
$ctxPct = [int][Math]::Round($usedPctRaw, [System.MidpointRounding]::AwayFromZero)

$agentState = if ($data.agent_state -and [string]$data.agent_state -ne "null") { [string]$data.agent_state } else { "" }
$planTier   = if ($data.plan_tier -and [string]$data.plan_tier -ne "null")   { [string]$data.plan_tier }   else { "" }

# -- Git info ---------------------------------------------
$gitBranch = ""
$gitDirty  = ""
if (Get-Command git -ErrorAction SilentlyContinue) {
    $insideWorkTree = & git -C $cwd rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $insideWorkTree -eq "true") {
        $branchOut = & git -C $cwd symbolic-ref --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branchOut) {
            $gitBranch = ($branchOut | Out-String).Trim()
        }
        $porcelainOut = & git -C $cwd --no-optional-locks status --porcelain 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($porcelainOut | Out-String))) {
            $gitDirty = "*"
        }
    }
}

# -- Agent state icon -------------------------------------
$stateIcon = switch ($agentState) {
    { $_ -in @("working", "running") } { "${symZap} " }
    default                            { "" }
}

# -- LINE 1: Model | Context % | Directory (branch) | Plan --
$ctxColor = Get-ColorForPct $ctxPct

$line1 = "${blue}${modelName}${reset}"
$line1 += $sep
$line1 += "${symPen}  ${ctxColor}${ctxPct}%${reset}"
$line1 += $sep
$line1 += "${stateIcon}${cyan}${dirname}${reset}"
if (-not [string]::IsNullOrEmpty($gitBranch)) {
    $line1 += " ${green}(${gitBranch}${red}${gitDirty}${green})${reset}"
}
if (-not [string]::IsNullOrEmpty($planTier)) {
    $line1 += "${sep}${dim}${planTier}${reset}"
}

# -- Detect model pool (3p = Claude/Anthropic, gemini = Google) --
$modelId = if ($data.model -and $data.model.id) { ([string]$data.model.id).ToLowerInvariant() } else { "" }
if ($modelId -match 'claude|anthropic|3p') {
    $quotaPool = "3p"
} else {
    $quotaPool = "gemini"
}

# -- Quota lines (from agy JSON - only active pool) ---------------
$barWidth = 10
$quotaLines = New-Object System.Collections.Generic.List[string]

if ($quotaPool -eq "3p") {
    $q5hKey    = "3p-5h"
    $qwkKey    = "3p-weekly"
    $poolLabel = "claude"
} else {
    $q5hKey    = "gemini-5h"
    $qwkKey    = "gemini-weekly"
    $poolLabel = "gemini"
}

# 5h quota
$q5hObj = if ($data.quota) { $data.quota.$q5hKey } else { $null }
if ($null -ne $q5hObj -and $null -ne $q5hObj.remaining_fraction) {
    $q5hRem      = [double]$q5hObj.remaining_fraction
    $q5hPct      = [int][Math]::Round((1.0 - $q5hRem) * 100.0, [System.MidpointRounding]::AwayFromZero)
    $q5hResetIso = if ($q5hObj.reset_time) { [string]$q5hObj.reset_time } else { "" }
    $q5hBar      = Build-Bar $q5hPct $barWidth
    $q5hColor    = Get-ColorForPct $q5hPct
    $q5hPctFmt   = "{0,3}" -f $q5hPct
    $q5hResetFmt = Format-ResetTime $q5hResetIso "time"

    $qLine = "${white}${poolLabel} 5h${reset} ${q5hBar} ${q5hColor}${q5hPctFmt}%${reset}"
    if (-not [string]::IsNullOrEmpty($q5hResetFmt)) {
        $qLine += " ${dim}${symReset}${reset} ${white}${q5hResetFmt}${reset}"
    }
    $quotaLines.Add($qLine)
}

# weekly quota
$qwkObj = if ($data.quota) { $data.quota.$qwkKey } else { $null }
if ($null -ne $qwkObj -and $null -ne $qwkObj.remaining_fraction) {
    $qwkRem      = [double]$qwkObj.remaining_fraction
    $qwkPct      = [int][Math]::Round((1.0 - $qwkRem) * 100.0, [System.MidpointRounding]::AwayFromZero)
    $qwkResetIso = if ($qwkObj.reset_time) { [string]$qwkObj.reset_time } else { "" }
    $qwkBar      = Build-Bar $qwkPct $barWidth
    $qwkColor    = Get-ColorForPct $qwkPct
    $qwkPctFmt   = "{0,3}" -f $qwkPct
    $qwkResetFmt = Format-ResetTime $qwkResetIso "datetime"

    $qLine = "${white}${poolLabel} 7d${reset} ${qwkBar} ${qwkColor}${qwkPctFmt}%${reset}"
    if (-not [string]::IsNullOrEmpty($qwkResetFmt)) {
        $qLine += " ${dim}${symReset}${reset} ${white}${qwkResetFmt}${reset}"
    }
    $quotaLines.Add($qLine)
}

# -- Output -----------------------------------------------
[Console]::Out.Write($line1)
if ($quotaLines.Count -gt 0) {
    [Console]::Out.Write("`n`n" + ($quotaLines -join "`n"))
}

exit 0
