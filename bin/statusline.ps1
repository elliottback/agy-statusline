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
$symFull  = [char]0x2588                             # full block
$symEmpty = [char]0x2591                             # light shade
$symReset = [char]0x27F3                             # clockwise arrow

$sep = " ${dim}${symBar}${reset} "

# -- Helpers ---------------------------------------------
function Get-ColorForPct([int]$pct) {
    if ($pct -ge 80)     { return $red }
    elseif ($pct -ge 50) { return $yellow }
    else                 { return $green }
}

function Build-Bar([int]$pct, [int]$width) {
    if ($pct -lt 0)   { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }

    $filled = [int][Math]::Round(($pct * $width) / 100.0, [System.MidpointRounding]::AwayFromZero)
    if ($pct -gt 0 -and $filled -eq 0) { $filled = 1 }
    $empty  = $width - $filled
    $barColor = Get-ColorForPct $pct

    $filledStr = [string]::new($symFull, $filled)
    $emptyStr  = [string]::new($symEmpty, $empty)

    return "${dim}[${reset}${barColor}${filledStr}${reset}${dim}${emptyStr}]${reset}"
}

function Format-ResetTime([object]$qObj) {
    if ($null -eq $qObj) { return "" }
    
    $totalSeconds = $null
    if ($null -ne $qObj.reset_in_seconds) {
        $totalSeconds = [double]$qObj.reset_in_seconds
    } elseif (-not [string]::IsNullOrWhiteSpace($qObj.reset_time) -and $qObj.reset_time -ne "null") {
        try {
            $dt = [DateTimeOffset]::Parse([string]$qObj.reset_time, [System.Globalization.CultureInfo]::InvariantCulture)
            $diff = $dt - [DateTimeOffset]::UtcNow
            $totalSeconds = $diff.TotalSeconds
        } catch {
            return ""
        }
    }

    if ($null -eq $totalSeconds -or $totalSeconds -le 0) {
        return ""
    }

    $sec = [int][Math]::Round($totalSeconds)
    if ($sec -ge 31536000) { return "$([int][Math]::Round($sec / 31536000.0))y" }
    if ($sec -ge 2592000)  { return "$([int][Math]::Round($sec / 2592000.0))mo" }
    if ($sec -ge 604800)   { return "$([int][Math]::Round($sec / 604800.0))w" }
    if ($sec -ge 86400)    { return "$([int][Math]::Round($sec / 86400.0))d" }
    if ($sec -ge 3600)     { return "$([int][Math]::Round($sec / 3600.0))h" }
    if ($sec -ge 60)       { return "$([int][Math]::Round($sec / 60.0))m" }
    return "${sec}s"
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

$line1 = "${blue}${modelName}${reset}{{QUOTA}}"
$line1 += $sep
$line1 += "${symPen}  ${dim}ctx${reset} ${ctxColor}${ctxPct}%${reset}"
$line1 += $sep
$line1 += "${stateIcon}${cyan}${dirname}${reset}"
if (-not [string]::IsNullOrEmpty($gitBranch)) {
    $line1 += " ${green}(${gitBranch}${red}${gitDirty}${green})${reset}"
}
if (-not [string]::IsNullOrEmpty($planTier)) {
    $line1 += "${sep}${dim}${planTier}${reset}"
}

# -- Detect model pool (3p = Claude/Anthropic/etc, gemini = Google) --
$modelId = if ($data.model -and $data.model.id) { ([string]$data.model.id).ToLowerInvariant() } else { "" }
$modelText = ("$modelId " + $modelName.ToLowerInvariant())
$modelTokens = @($modelText -split '[^a-z0-9]+' | Where-Object { $_ })
if ($modelText -match 'claude|anthropic|gpt|openai|\b3p\b') {
    $quotaPool = "3p"
} else {
    $quotaPool = "gemini"
}

# -- Quota lines (generic discovery from agy JSON) -----------------
# Keys look like "<pool>-<window>" (e.g. gemini-5h, 3p-weekly) or
# "<pool>-<subpool...>-<window>" for model-specific buckets
# (e.g. gemini-argon-wtu-weekly). We show the active pool's base buckets
# plus any sub-pool bucket whose segments match a word in the active model.
$barWidth = 20
$quotaLines = New-Object System.Collections.Generic.List[string]

function Get-WindowInfo([string]$window) {
    switch -Regex ($window) {
        '^(\d+)h$'         { return @{ Label = $window; Order = [int]$Matches[1]; Style = "time" } }
        '^(daily|1d)$'     { return @{ Label = "1d";    Order = 24;               Style = "datetime" } }
        '^(weekly|7d|wk)$' { return @{ Label = "7d";    Order = 168;              Style = "datetime" } }
        '^(monthly|30d)$'  { return @{ Label = "30d";   Order = 720;              Style = "datetime" } }
        default            { return @{ Label = $window; Order = 100000;           Style = "datetime" } }
    }
}

$poolLabel = if ($quotaPool -eq "3p") { "claude" } else { "gemini" }
$buckets = New-Object System.Collections.Generic.List[object]
$poolLabels = @{ "3p" = "claude/gpt"; "gemini" = "gemini" }

if ($data.quota) {
    foreach ($prop in $data.quota.PSObject.Properties) {
        $q = $prop.Value
        if ($null -eq $q -or $null -eq $q.remaining_fraction) { continue }

        $segments = @($prop.Name.ToLowerInvariant() -split '-')
        if ($segments.Count -lt 2) { continue }

        $pool   = $segments[0]
        $window = $segments[-1]
        $middle = if ($segments.Count -gt 2) { @($segments[1..($segments.Count - 2)]) } else { @() }

        $label    = if ($poolLabels.ContainsKey($pool)) { $poolLabels[$pool] } else { $pool }
        $isSub    = $false
        $isActive = ($pool -eq $quotaPool)
        if ($middle.Count -gt 0) {
            # Model-specific bucket, e.g. gemini-argon-wtu-weekly -> "argon"
            $isSub   = $true
            $matched = @($middle | Where-Object { $modelTokens -contains $_ })
            if ($matched.Count -gt 0) {
                $label = $matched -join " "
            } else {
                $label = $middle[0]
                $isActive = $false
            }
        }

        $info = Get-WindowInfo $window
        $buckets.Add([PSCustomObject]@{
            Label     = $label
            Window    = $info.Label
            Order     = $info.Order
            Style     = $info.Style
            IsSub     = $isSub
            IsActive  = $isActive
            Pool      = $pool
            Remaining = [double]$q.remaining_fraction
            QuotaObj  = $q
        })
    }
}

# Active-model buckets first, then the rest grouped by pool
$sorted = @($buckets | Sort-Object -Property `
    @{ Expression = { -not $_.IsActive } }, `
    @{ Expression = { $_.Pool -ne $quotaPool } }, `
    @{ Expression = "Pool" }, `
    @{ Expression = "IsSub" }, `
    @{ Expression = "Label" }, `
    @{ Expression = "Order" })
$labelWidth = 0
foreach ($b in $sorted) {
    $len = ("{0} {1}" -f $b.Label, $b.Window).Length
    if ($len -gt $labelWidth) { $labelWidth = $len }
}

foreach ($b in $sorted) {
    $pct      = [int][Math]::Round((1.0 - $b.Remaining) * 100.0, [System.MidpointRounding]::AwayFromZero)
    $bar      = Build-Bar $pct $barWidth
    $color    = Get-ColorForPct $pct
    $pctFmt   = "{0,3}" -f $pct
    $resetFmt = Format-ResetTime $b.QuotaObj
    $name     = ("{0} {1}" -f $b.Label, $b.Window).PadRight($labelWidth)
    $nameColor = if ($b.IsActive) { $white } else { $dim }

    $qLine = "${nameColor}${name}${reset} ${bar} ${color}${pctFmt}%${reset}"
    if (-not [string]::IsNullOrEmpty($resetFmt)) {
        $qLine += " ${dim}${symReset}${reset} ${nameColor}${resetFmt}${reset}"
    }
    $quotaLines.Add($qLine)
}

# -- Top line: binding (most-used) quota for the active model --
$quotaSeg = ""
$activeBuckets = @($sorted | Where-Object { $_.IsActive })
if ($activeBuckets.Count -gt 0) {
    $binding = $activeBuckets | Sort-Object -Property Remaining | Select-Object -First 1
    $bPct    = [int][Math]::Round((1.0 - $binding.Remaining) * 100.0, [System.MidpointRounding]::AwayFromZero)
    $bColor  = Get-ColorForPct $bPct
    $quotaSeg = " ${bColor}${bPct}%${reset} ${dim}($($binding.Label) $($binding.Window))${reset}"
}
$line1 = $line1.Replace("{{QUOTA}}", $quotaSeg)

# -- Output -----------------------------------------------
[Console]::Out.Write($line1)
if ($quotaLines.Count -gt 0) {
    [Console]::Out.Write("`n`n" + ($quotaLines -join "`n"))
}

exit 0
