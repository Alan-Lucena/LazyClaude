#!/usr/bin/env python3
import sys, json, os, subprocess

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

# Send macOS notification + sound
subprocess.run([
    "osascript", "-e",
    f'display notification "{message}" with title "{title}" sound name "Ping"'
], capture_output=True)
