# agy-statusline (Windows Port)

Windows PowerShell port of [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) for the **Antigravity CLI** (`agy`) â€” displays the active model, session context usage, working directory/git branch, and real-time quota consumption.

## What it shows

```
Gemini 4 Argon (Medium) 75% (argon 7d) â”‚ âœï¸  ctx 0% â”‚ my-project (main*) â”‚ Google AI Pro

gemini 5h     â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹   0% âŸ³ 04:03
gemini 7d     â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹â—‹   0% âŸ³ oct 23, 14:04
argon 7d      â—â—â—â—â—â—â—â—‹â—‹â—‹  75% âŸ³ oct 23, 13:48
claude/gpt 5h â—â—â—â—â—â—‹â—‹â—‹â—‹â—‹  52% âŸ³ 04:11
claude/gpt 7d â—â—â—â—â—â—â—â—‹â—‹â—‹  76% âŸ³ oct 22, 17:01
```

| Field | Description |
|-------|-------------|
| Model + `%` | Active model, followed by its **binding quota** â€” the most-used limit that applies to it (e.g. `75% (argon 7d)`) |
| `âœï¸ ctx %` | Context window usage for the current session (not quota) |
| Directory (branch*) | Working directory + git branch (`*` = uncommitted changes) |
| Plan | Account tier (Google AI Pro, etc.) |
| `<pool> 5h` / `<pool> 7d` | Rolling 5-hour and weekly quota used, per pool |
| `<model> 7d` | Model-specific bucket (e.g. `argon`) when `agy` reports one |

> Quota percentages are **used**, i.e. `100 âˆ’ remaining` as shown in `/usage`.

### How quota buckets are discovered

Every key under `quota` in the JSON `agy` sends is parsed as `<pool>[-<subpool>...]-<window>`:

- `gemini-5h`, `gemini-weekly` â†’ **gemini** pool
- `3p-5h`, `3p-weekly` â†’ **claude/gpt** pool (Claude Opus, Claude Sonnet, GPT-OSS)
- `gemini-argon-wtu-weekly` â†’ model-specific **argon** bucket

All buckets are shown. Those that apply to the active model are listed first in white; the rest are dimmed. New pools or model-specific buckets appear automatically â€” no code changes needed.

## Requirements

- **Windows PowerShell 5.1+** or **PowerShell 7+** (built into Windows â€” no `jq` needed!)
- `git` â€” for branch info
- `agy` (Antigravity CLI) installed and configured

## Installation

```powershell
git clone https://github.com/your-username/agy-statusline
cd agy-statusline
powershell -ExecutionPolicy Bypass -File .\bin\install.ps1
```

Restart `agy` to see the status line.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\bin\uninstall.ps1
```

This restores your previous statusline (if any) and removes the `statusLine` entry from `settings.json`.

## Project structure

```
agy-statusline/
â”œâ”€â”€ bin/
â”‚   â”œâ”€â”€ statusline.ps1  # Main script (copied to %USERPROFILE%\.gemini\)
â”‚   â”œâ”€â”€ install.ps1     # Installer
â”‚   â””â”€â”€ uninstall.ps1   # Uninstaller
â””â”€â”€ README.md
```

## How it works

`agy` runs the command configured under `statusLine` in `settings.json`, passing the current session state as JSON via stdin. The script parses it using PowerShell's native `ConvertFrom-Json` and returns ANSI-colored text for the terminal.

The installer configures the following in `%USERPROFILE%\.gemini\antigravity-cli\settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.gemini\\statusline.ps1",
  "enabled": true
}
```

> **Note:** On Windows, `agy` runs this command via `cmd.exe /c` and escapes embedded `"` as `\"`, which cmd does not understand. Keep the command free of double quotes and cmd metacharacters (`&`, `|`, `<`, `>`, `^`). `%USERPROFILE%` is expanded by cmd.

You can also toggle the status line at any time from within `agy` using `/statusline`.
