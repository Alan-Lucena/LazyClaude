#!/bin/bash

HOOKS_DIR="$HOME/.claude/hooks"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude-flow.menubar.plist"

echo "==> Uninstalling Claude Flow..."

# Stop and remove LaunchAgent
echo "==> Stopping menu bar app..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Remove binaries
echo "==> Removing binaries..."
rm -f "$HOOKS_DIR/permission-popup"
rm -f "$HOOKS_DIR/claude-menubar"
rm -f "$HOOKS_DIR/.autoaccept"

# Remove source files (optional, kept by install)
rm -f "$HOOKS_DIR/PermissionPopup.swift"
rm -f "$HOOKS_DIR/ClaudeMenuBar.swift"
rm -f "$HOOKS_DIR/permission-popup.sh"

echo ""
echo "==> Claude Flow uninstalled."
echo ""
echo "   NOTE: You should manually remove the PermissionRequest hook"
echo "   from your ~/.claude/settings.json if you added it."
