#!/bin/bash
set -e

HOOKS_DIR="$HOME/.claude/hooks"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude-flow.menubar.plist"

echo "==> Installing Claude Flow..."

# Create hooks directory
mkdir -p "$HOOKS_DIR"

# Compile binaries
echo "==> Compiling permission popup..."
swiftc -O -o "$HOOKS_DIR/permission-popup" "$(dirname "$0")/src/PermissionPopup.swift" -framework Cocoa

echo "==> Compiling menu bar app..."
swiftc -O -o "$HOOKS_DIR/claude-menubar" "$(dirname "$0")/src/ClaudeMenuBar.swift" -framework Cocoa

# Install LaunchAgent
echo "==> Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS_DIR"
cat > "$LAUNCH_AGENTS_DIR/$PLIST_NAME" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude-flow.menubar</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HOOKS_DIR}/claude-menubar</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Configure Claude Code hooks
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Check if PermissionRequest hook already exists
if grep -q "PermissionRequest" "$SETTINGS_FILE" 2>/dev/null; then
    echo ""
    echo "==> PermissionRequest hook already exists in $SETTINGS_FILE"
    echo "    Please verify it points to: $HOOKS_DIR/permission-popup"
else
    echo ""
    echo "==> Add this to your $SETTINGS_FILE under \"hooks\":"
    echo ""
    cat <<EOF
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${HOOKS_DIR}/permission-popup",
            "timeout": 130
          }
        ]
      }
    ]
EOF
fi

# Start menu bar app
echo ""
echo "==> Starting menu bar app..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "==> Claude Flow installed successfully!"
echo ""
echo "   - Permission popup: $HOOKS_DIR/permission-popup"
echo "   - Menu bar app:     $HOOKS_DIR/claude-menubar"
echo "   - LaunchAgent:      $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "   You should see a bolt icon in your menu bar."
