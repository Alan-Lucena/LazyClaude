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

# Install hooks
echo "==> Installing hooks..."
cp "$(dirname "$0")/src/autoaccept-hook.py" "$HOOKS_DIR/autoaccept-hook"
cp "$(dirname "$0")/src/notify-hook.py" "$HOOKS_DIR/notify-hook"
chmod +x "$HOOKS_DIR/autoaccept-hook" "$HOOKS_DIR/notify-hook"

# Build menu bar app as .app bundle (required for notifications)
echo "==> Building menu bar app..."
APP_DIR="$HOOKS_DIR/LazyClaude.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Compile binary
swiftc -O -o "$APP_DIR/Contents/MacOS/lazy-claude" "$(dirname "$0")/src/LazyClaude.swift" -framework Cocoa

# Bundle terminal-notifier for clickable notifications
if command -v terminal-notifier &>/dev/null; then
    TN_APP="$(dirname "$(dirname "$(which terminal-notifier)")")"
    if [ -d "$TN_APP/terminal-notifier.app" ]; then
        echo "==> Bundling terminal-notifier..."
        cp -R "$TN_APP/terminal-notifier.app" "$APP_DIR/Contents/Resources/terminal-notifier.app"
    fi
elif command -v brew &>/dev/null; then
    echo "==> Installing terminal-notifier (for clickable notifications)..."
    brew install terminal-notifier
    TN_APP="$(dirname "$(dirname "$(which terminal-notifier)")")"
    if [ -d "$TN_APP/terminal-notifier.app" ]; then
        cp -R "$TN_APP/terminal-notifier.app" "$APP_DIR/Contents/Resources/terminal-notifier.app"
    fi
else
    echo "==> Note: Install terminal-notifier for clickable notifications:"
    echo "    brew install terminal-notifier"
fi

# Sign the app bundle
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

# Create Info.plist with bundle ID (used by -sender for notification branding)
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.lazyclaude.menubar</string>
    <key>CFBundleName</key>
    <string>LazyClaude</string>
    <key>CFBundleExecutable</key>
    <string>lazy-claude</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

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
        <string>open</string>
        <string>-a</string>
        <string>${HOOKS_DIR}/LazyClaude.app</string>
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

# Check if Stop hook already exists
if grep -q '"Stop"' "$SETTINGS_FILE" 2>/dev/null; then
    echo "==> Stop hook already exists in $SETTINGS_FILE"
    echo "    Please verify it points to: $HOOKS_DIR/notify-hook"
else
    echo ""
    echo "==> Also add this under \"hooks\" for notifications:"
    echo ""
    cat <<EOF
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${HOOKS_DIR}/notify-hook"
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
echo "   - Menu bar app:     $HOOKS_DIR/LazyClaude.app"
echo "   - Config file:      $HOOKS_DIR/.lazyclaude"
echo "   - LaunchAgent:      $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "   You should see a bolt icon in your menu bar."
echo "   macOS will ask for notification permissions on first launch."
