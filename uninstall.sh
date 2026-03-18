#!/bin/bash

HOOKS_DIR="$HOME/.claude/hooks"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.lazy-claude.menubar.plist"

echo "==> Uninstalling LazyClaude..."

# Stop and remove LaunchAgent
echo "==> Stopping menu bar app..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
pkill -f "lazy-claude" 2>/dev/null || true

# Remove app bundle and hooks
echo "==> Removing files..."
rm -rf "$HOOKS_DIR/LazyClaude.app"
rm -f "$HOOKS_DIR/lazy-claude"
rm -f "$HOOKS_DIR/autoaccept-hook"
rm -f "$HOOKS_DIR/notify-hook"
rm -f "$HOOKS_DIR/.lazyclaude"
rm -f "$HOOKS_DIR/.lazyclaude-response"
rm -f "$HOOKS_DIR/.lazyclaude-notify"
rm -f "$HOOKS_DIR/.lazyclaude-notify-last"
rm -f "$HOOKS_DIR/.lazyclaude-projects"
rm -f "$HOOKS_DIR/.lazyclaude-known-projects"
rm -f "$HOOKS_DIR/.lazyclaude-pending-notification"

echo ""
echo "==> LazyClaude uninstalled."
echo ""
echo "   NOTE: You should manually remove the hooks (PermissionRequest, Stop)"
echo "   from your ~/.claude/settings.json if you added them."
