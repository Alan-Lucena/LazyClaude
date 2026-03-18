#!/bin/bash
set -e

HOOKS_DIR="$HOME/.claude/hooks"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.lazy-claude.menubar.plist"

echo "==> Installing LazyClaude..."

# Kill existing process if running
pkill -f "lazy-claude" 2>/dev/null || true

# Create hooks directory
mkdir -p "$HOOKS_DIR"

# Install auto-accept hook
echo "==> Installing auto-accept hook..."
cp "$(dirname "$0")/src/autoaccept-hook.py" "$HOOKS_DIR/autoaccept-hook"
chmod +x "$HOOKS_DIR/autoaccept-hook"

# Compile menu bar app
echo "==> Compiling menu bar app..."
swiftc -O -o "$HOOKS_DIR/lazy-claude" "$(dirname "$0")/src/LazyClaude.swift" -framework Cocoa

# Install LaunchAgent
echo "==> Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS_DIR"
cat > "$LAUNCH_AGENTS_DIR/$PLIST_NAME" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lazy-claude.menubar</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HOOKS_DIR}/lazy-claude</string>
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
    echo "    Please verify it points to: $HOOKS_DIR/autoaccept-hook"
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
            "command": "${HOOKS_DIR}/autoaccept-hook",
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
echo "==> LazyClaude installed successfully!"
echo ""
echo "   - Auto-accept hook: $HOOKS_DIR/autoaccept-hook"
echo "   - Menu bar app:     $HOOKS_DIR/lazy-claude"
echo "   - Config file:      $HOOKS_DIR/.lazyclaude"
echo "   - LaunchAgent:      $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "   You should see a bolt icon in your menu bar."
