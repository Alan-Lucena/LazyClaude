<div align="center">

# LazyClaude

**Stop babysitting Claude Code. Let it cook.**

[![macOS](https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Windows](https://img.shields.io/badge/Windows-10%2B-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Swift](https://img.shields.io/badge/Swift-Cocoa-F05138?logo=swift&logoColor=white)](https://developer.apple.com/swift/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A menu bar / system tray app that auto-approves Claude Code permission requests and auto-responds to its questions — so you can focus on what matters instead of clicking "Allow" all day.

</div>

---

## The Problem

Claude Code asks for permission **constantly**. Every file edit, every bash command, every tool call — "Allow?" "Allow?" "Allow?". If you trust what Claude is doing, those prompts are just noise slowing you down.

## The Solution

LazyClaude sits in your menu bar (macOS) or system tray (Windows) and handles all that for you. One toggle, zero interruptions.

## Features

- **Safe Mode** — Auto-approves everything *except* plan approvals and questions. You still review the big decisions and answer Claude yourself.
- **YOLO Mode** — Auto-approves absolutely everything. No exceptions. No interruptions. Full send.
- **Per-Project Control** — Choose which projects get auto-accept. Projects are discovered automatically — no manual setup needed.
- **Auto-Response** — Automatically answers Claude's questions with your pre-configured text (e.g. *"proceed with the recommended option"*). Only active in YOLO mode.
- **Notifications** — Get a native notification with sound when Claude finishes a task, so you know when to come back.
- **Auto-Start** — Launches on login. Set it and forget it.
- **Native UI** — Swift/Cocoa menu bar app on macOS. Python/pystray system tray app on Windows.

## Quick Start

### macOS

**Requirements:** macOS 12+, [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Xcode Command Line Tools (`xcode-select --install`)

```bash
git clone https://github.com/Alan-Lucena/LazyClaude.git
cd LazyClaude
./install.sh
```

### Windows

**Requirements:** Windows 10+, [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Python 3.8+

```powershell
git clone https://github.com/Alan-Lucena/LazyClaude.git
cd LazyClaude
powershell -ExecutionPolicy Bypass -File install.ps1
```

### Hook Configuration

After installing, add the hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/autoaccept-hook",
            "timeout": 130
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-hook"
          }
        ]
      }
    ]
  }
}
```

> **Windows:** Replace the commands with `python "%USERPROFILE%\.claude\hooks\autoaccept-hook"` and `python "%USERPROFILE%\.claude\hooks\notify-hook"`. The `~` shorthand is not expanded by `cmd.exe`.

> **Tip:** Add `"defaultMode": "acceptEdits"` inside `"permissions"` to also auto-accept file edits natively.

### Update

```bash
git pull && ./install.sh        # macOS
```
```powershell
git pull
powershell -ExecutionPolicy Bypass -File install.ps1   # Windows
```

### Uninstall

```bash
./uninstall.sh                  # macOS
```
```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1  # Windows
```

Then remove the `PermissionRequest` and `Stop` hooks from `~/.claude/settings.json`.

## Usage

A bolt icon shows the current state:

| State | macOS Icon | Windows Icon | Behavior |
|-------|:----------:|:------------:|----------|
| **OFF** | `bolt.circle` | Gray bolt | Normal permission prompts |
| **Safe** | `bolt.circle.fill` | Blue bolt | Auto-accepts all except plan approvals and questions |
| **YOLO** | `bolt.trianglebadge.exclamationmark` | Red bolt | Auto-accepts everything, no exceptions |

Click the icon to toggle, switch modes, configure auto-response, and enable notifications.

### Mode Behavior

| Scenario | Safe Mode | YOLO Mode | Off |
|----------|:---------:|:---------:|:---:|
| Normal tool use | Allow | Allow | Block |
| Plan approval (ExitPlanMode) | Block | Allow | Block |
| Questions (AskUserQuestion) | Block (you answer) | Allow (auto-responds) | Block |
| Notifications | Works | Works | Works |

### Per-Project Control

Working with multiple VS Code windows? Each project can have its own auto-accept mode. Projects appear automatically in the menu — just open the submenu and pick a mode:

- **Global default** — Inherits from the global toggle
- **Safe / YOLO / Off** — Overrides the global setting for that project only

### Notifications

Enable the "Notifications" toggle to get notified when Claude finishes a task. You'll see a native notification with the project name and a sound alert.

## How It Works

LazyClaude hooks into Claude Code's [PermissionRequest](https://docs.anthropic.com/en/docs/claude-code/hooks) and [Stop](https://docs.anthropic.com/en/docs/claude-code/hooks) systems. When Claude asks for permission, the hook checks your configuration and responds automatically. When Claude finishes, the notify hook sends a notification.

```
~/.claude/hooks/
  autoaccept-hook               # Python — intercepts and auto-approves requests
  notify-hook                   # Python — sends notifications on task completion
  lazy-claude                   # macOS: Swift binary | Windows: Python tray app
  .lazyclaude                   # Global mode (safe/yolo), absent = OFF
  .lazyclaude-response          # Auto-response text, absent = OFF
  .lazyclaude-notify            # Notifications toggle (on/off), absent = OFF
  .lazyclaude-projects          # Per-project mode overrides (JSON)
  .lazyclaude-known-projects    # Auto-discovered projects (JSON)
```

## License

MIT
