# LazyClaude

Auto-accept permission manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on macOS. A menu bar app that lets you auto-approve all Claude Code permission requests and auto-respond to questions with one click.

## Features

- **Menu bar toggle** with an iOS-style switch to enable/disable auto-accept
- **Safe mode** — auto-accepts everything except plan approvals (`ExitPlanMode`)
- **YOLO mode** — auto-accepts absolutely everything, no exceptions
- **Auto-response** — auto-answers Claude's questions (`AskUserQuestion`) with a pre-configured text
- **Auto-start** via LaunchAgent — starts on login

## Requirements

- macOS 12+ (Monterey or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3 (included with Xcode CLI Tools)

## Install

```bash
git clone https://github.com/YOUR_USERNAME/lazy-claude.git
cd lazy-claude
chmod +x install.sh
./install.sh
```

Then add the hook to your `~/.claude/settings.json`:

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

> **Tip:** Add `"defaultMode": "acceptEdits"` inside `"permissions"` to auto-accept file edits and only get prompts for Bash and other tools.

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Then remove the `PermissionRequest` hook from your `~/.claude/settings.json`.

## How it works

### Menu bar app

A bolt icon lives in your menu bar:

| Icon | State |
|------|-------|
| `bolt.circle` | **OFF** — Claude Code shows its normal permission prompts |
| `bolt.circle.fill` | **Safe mode** — auto-accepts all except plan approvals |
| `bolt.trianglebadge.exclamationmark` | **YOLO mode** — auto-accepts everything, no exceptions |

Click the icon to toggle auto-accept, choose your mode, and configure auto-response.

### Modes

- **Safe mode** (default) — Auto-approves all permission requests except `ExitPlanMode`. Plans always require your manual approval.
- **YOLO mode** — Auto-approves everything including plan approvals. Zero interruptions.

### Auto-response

When enabled, Claude's questions (`AskUserQuestion`) are automatically answered with your pre-configured text. Click the response text in the menu to edit it.

This is useful when you want Claude to always proceed with a specific approach (e.g., "proceed with the recommended option") without asking you.

> **Note:** Auto-response uses an experimental workaround. It may stop working in a future Claude Code update, but won't break anything if it does.

### Architecture

```
~/.claude/hooks/
  autoaccept-hook        # Python script — handles permissions and auto-response
  lazy-claude            # Compiled binary — menu bar toggle app
  .lazyclaude            # Config file — contains mode ("safe" or "yolo"), absent = OFF
  .lazyclaude-response   # Response file — contains auto-response text, absent = OFF

~/Library/LaunchAgents/
  com.lazy-claude.menubar.plist  # Auto-start menu bar on login
```

## License

MIT
