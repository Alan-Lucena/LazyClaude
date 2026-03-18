#!/usr/bin/env python3
import sys, json, os, subprocess, shutil

NOTIFY_CONFIG = os.path.expanduser("~/.claude/hooks/.lazyclaude-notify")

# Check if notifications are enabled
if not os.path.exists(NOTIFY_CONFIG):
    sys.exit(0)

config = open(NOTIFY_CONFIG).read().strip()
if config != "on":
    sys.exit(0)

# Parse stdin for context
data = json.loads(sys.stdin.read())
stop_reason = data.get("stop_reason", "end_turn")
cwd = data.get("cwd", "")
project_name = os.path.basename(cwd.rstrip("/")) if cwd else "Unknown"

# Build notification
if stop_reason == "end_turn":
    title = "LazyClaude"
    message = f"Task finished in {project_name}"
elif stop_reason == "max_tokens":
    title = "LazyClaude"
    message = f"Hit token limit in {project_name}"
else:
    title = "LazyClaude"
    message = f"Claude stopped in {project_name} ({stop_reason})"

# Detect which editor has this project open
def detect_editor_app():
    """Detect if the project is open in VS Code, Code Insiders, or Cursor."""
    for app_name in ["Code", "Code - Insiders", "Cursor"]:
        check = f'''
        tell application "System Events"
            if exists (process "{app_name}") then
                tell process "{app_name}"
                    repeat with w in every window
                        if name of w contains "{project_name}" then return "{app_name}"
                    end repeat
                end tell
            end if
        end tell
        '''
        try:
            result = subprocess.run(
                ["osascript", "-e", check],
                capture_output=True, text=True, timeout=5
            )
            if result.stdout.strip() == app_name:
                return app_name
        except Exception:
            continue
    # Fallback: try common editors
    for app_name in ["Cursor", "Visual Studio Code"]:
        try:
            result = subprocess.run(
                ["pgrep", "-x", app_name.split()[0]],
                capture_output=True, timeout=3
            )
            if result.returncode == 0:
                return app_name
        except Exception:
            continue
    return "Visual Studio Code"

editor_app = detect_editor_app()

# Map process name to application name for activation
app_name_map = {
    "Code": "Visual Studio Code",
    "Code - Insiders": "Visual Studio Code - Insiders",
    "Cursor": "Cursor",
}
activate_app = app_name_map.get(editor_app, editor_app)

# Use terminal-notifier if available (clickable notifications)
terminal_notifier = shutil.which("terminal-notifier")
if terminal_notifier:
    subprocess.run([
        terminal_notifier,
        "-title", title,
        "-message", message,
        "-sound", "Ping",
        "-execute", f'osascript -e \'tell application "{activate_app}" to activate\'',
    ], capture_output=True)
else:
    # Fallback: osascript notification (not clickable) + auto-activate
    subprocess.run([
        "osascript", "-e",
        f'display notification "{message}" with title "{title}" sound name "Ping"'
    ], capture_output=True)
