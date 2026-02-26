# Claude Flow

Native macOS permission manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Replaces the default VSCode/terminal permission prompts with native macOS popups that appear on top of all windows, so you can approve or deny from anywhere.

## Features

- **Native macOS popup** for every permission request (Bash, Edit, Write, etc.) — no need to switch to VSCode
- **Menu bar toggle** with an iOS-style switch to auto-accept all permissions with one click
- **"Allow All" button** in the popup to enable auto-accept on the fly
- **Plan mode protection** — `ExitPlanMode` always requires manual approval, even with auto-accept on
- **Keyboard shortcuts** — Enter to allow, Escape to deny
- **Smart detail display** — shows commands, file paths, or URLs depending on the tool type
- **Auto-start** via LaunchAgent — menu bar app starts on login

## Requirements

- macOS 12+ (Monterey or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-flow.git
cd claude-flow
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
            "command": "~/.claude/hooks/permission-popup",
            "timeout": 130
          }
        ]
      }
    ]
  }
}
```

> **Tip:** Add `"defaultMode": "acceptEdits"` inside `"permissions"` to auto-accept file edits and only get popups for Bash and other tools.

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Then remove the `PermissionRequest` hook from your `~/.claude/settings.json`.

## How it works

### Permission popup

When Claude Code requests any permission, a native macOS dialog appears on top of all windows:

- **Allow** (Enter) — approve this specific request
- **Deny** (Escape) — reject this request
- **Allow All** — approve this request AND enable auto-accept for all future requests

The popup shows the tool name and the relevant detail (command for Bash, file path for Edit/Write, URL for WebFetch, etc.).

### Menu bar app

A bolt icon lives in your menu bar:

| Icon | State |
|------|-------|
| `bolt.circle` | Auto-accept **OFF** — popups appear for every request |
| `bolt.circle.fill` | Auto-accept **ON** — all requests auto-approved silently |

Click the icon to toggle auto-accept with an iOS-style switch.

### Architecture

```
~/.claude/hooks/
  permission-popup     # Compiled binary — handles permission popups
  claude-menubar       # Compiled binary — menu bar toggle app
  .autoaccept          # Flag file — exists = auto-accept ON

~/Library/LaunchAgents/
  com.claude-flow.menubar.plist  # Auto-start menu bar on login
```

The popup binary checks for the `.autoaccept` flag file. If it exists, permissions are auto-approved. If not, the native dialog is shown. The menu bar app creates/deletes this file when you toggle.

`ExitPlanMode` is excluded from auto-accept — plans always require manual approval.

## Configuration

### Limit to Bash only

If you only want the popup for Bash commands (and let Claude Code handle edits normally):

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/permission-popup",
            "timeout": 130
          }
        ]
      }
    ]
  }
}
```

### Add more exclusions

Edit `src/PermissionPopup.swift` and add tool names to the skip list:

```swift
let skipAutoAccept = ["ExitPlanMode", "AnotherTool"].contains(toolName)
```

Then recompile:

```bash
swiftc -O -o ~/.claude/hooks/permission-popup src/PermissionPopup.swift -framework Cocoa
```

## License

MIT
