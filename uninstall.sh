#!/bin/bash

HOOKS_DIR="$HOME/.claude/hooks"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.lazy-claude.menubar.plist"

echo "==> Uninstalling LazyClaude..."

# Stop and remove LaunchAgent
echo "==> Stopping menu bar app..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Remove binaries and hook
echo "==> Removing files..."
rm -f "$HOOKS_DIR/lazy-claude"
rm -f "$HOOKS_DIR/autoaccept-hook"
rm -f "$HOOKS_DIR/.lazyclaude"
rm -f "$HOOKS_DIR/.lazyclaude-response"
rm -f "$HOOKS_DIR/.lazyclaude-projects"
rm -f "$HOOKS_DIR/.lazyclaude-known-projects"

echo ""
echo "==> LazyClaude uninstalled."
echo ""
echo "   NOTE: You should manually remove the PermissionRequest hook"
echo "   from your ~/.claude/settings.json if you added it."
