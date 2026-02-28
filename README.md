<div align="center">

# LazyClaude

**Stop babysitting Claude Code. Let it cook.**

[![macOS](https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-Cocoa-F05138?logo=swift&logoColor=white)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A native macOS menu bar app that auto-approves Claude Code permission requests and auto-responds to its questions — so you can focus on what matters instead of clicking "Allow" all day.

</div>

---

## The Problem

Claude Code asks for permission **constantly**. Every file edit, every bash command, every tool call — "Allow?" "Allow?" "Allow?". If you trust what Claude is doing, those prompts are just noise slowing you down.

## The Solution

LazyClaude sits in your menu bar and handles all that for you. One toggle, zero interruptions.

## Features

- **Safe Mode** — Auto-approves everything *except* plan approvals. You still review the big decisions.
- **YOLO Mode** — Auto-approves absolutely everything. No exceptions. No interruptions. Full send.
- **Per-Project Control** — Choose which projects get auto-accept. Projects are discovered automatically — no manual setup needed.
- **Auto-Response** — Automatically answers Claude's questions with your pre-configured text (e.g. *"proceed with the recommended option"*).
- **Auto-Start** — Launches on login via LaunchAgent. Set it and forget it.
- **Native macOS** — Pure Swift/Cocoa menu bar app. No Electron, no web views, no bloat.

## Quick Start

### Requirements

- macOS 12+ (Monterey or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Xcode Command Line Tools (`xcode-select --install`)

### Install

```bash
git clone https://github.com/Alan-Lucena/LazyClaude.git
cd LazyClaude
./install.sh
```

Then add the hook to `~/.claude/settings.json`:

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
    ]
  }
}
```

> **Tip:** Add `"defaultMode": "acceptEdits"` inside `"permissions"` to also auto-accept file edits natively.

### Uninstall

```bash
./uninstall.sh
```

Then remove the `PermissionRequest` hook from `~/.claude/settings.json`.

## Usage

A bolt icon in your menu bar shows the current state:

| Icon | State | Behavior |
|:----:|-------|----------|
| `bolt.circle` | **OFF** | Claude Code shows normal permission prompts |
| `bolt.circle.fill` | **Safe** | Auto-accepts all except plan approvals |
| `bolt.trianglebadge.exclamationmark` | **YOLO** | Auto-accepts everything, no exceptions |

Click the icon to toggle, switch modes, and configure auto-response.

### Per-Project Control

Working with multiple VS Code windows? Each project can have its own auto-accept mode. Projects appear automatically in the menu after Claude Code runs in them — just open the submenu and pick a mode:

- **Global default** — Inherits from the global toggle above
- **Safe / YOLO / Off** — Overrides the global setting for that project only

This means you can keep the global toggle OFF and only enable auto-accept for specific projects, or vice versa.

## How It Works

LazyClaude hooks into Claude Code's [PermissionRequest](https://docs.anthropic.com/en/docs/claude-code/hooks) system. When Claude asks for permission, the hook script checks your configuration and responds automatically — no UI interaction needed.

```
~/.claude/hooks/
  autoaccept-hook          # Python hook — intercepts and auto-approves requests
  lazy-claude              # Swift binary — menu bar app
  .lazyclaude              # Config — global mode (safe/yolo), absent = OFF
  .lazyclaude-response     # Config — auto-response text, absent = OFF
  .lazyclaude-projects     # Config — per-project mode overrides (JSON)
  .lazyclaude-known-projects  # Auto-discovered projects (written by hook)

~/Library/LaunchAgents/
  com.lazy-claude.menubar.plist   # Starts on login
```

> **Note:** Auto-response uses an experimental hook workaround. It may stop working in a future Claude Code update, but won't break anything if it does.

## License

MIT
