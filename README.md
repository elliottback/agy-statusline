# agy-statusline (Windows Port)

Windows PowerShell port of [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) for the **Antigravity CLI** (`agy`) — displays the active model, session context usage, working directory/git branch, and real-time quota consumption.

## What it shows

```
Claude Sonnet 4.6 (Thinking) │ ✍️  27% │ my-project (main*) │ Google AI Pro

claude 5h ●●○○○○○○○○  21% ⟳ 20:40
claude 7d ●○○○○○○○○○  16% ⟳ jul 4, 20:57
```

| Field | Description |
|-------|-------------|
| Model | Active model for the current session |
| `✍️ %` | Context window usage for the current session |
| Directory (branch*) | Working directory + git branch (`*` = uncommitted changes) |
| Plan | Account tier (Google AI Pro, etc.) |
| `claude/gemini 5h` | 5-hour rolling quota for the active model pool |
| `claude/gemini 7d` | Weekly quota for the active model pool |

> The quota pool shown (`claude` or `gemini`) is automatically detected based on the active model — no configuration needed.

## Requirements

- **Windows PowerShell 5.1+** or **PowerShell 7+** (built into Windows — no `jq` needed!)
- `git` — for branch info
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
├── bin/
│   ├── statusline.ps1  # Main script (copied to %USERPROFILE%\.gemini\)
│   ├── install.ps1     # Installer
│   └── uninstall.ps1   # Uninstaller
└── README.md
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
