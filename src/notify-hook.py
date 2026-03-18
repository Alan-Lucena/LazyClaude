#!/usr/bin/env python3
import sys, json, os, time

NOTIFY_CONFIG = os.path.expanduser("~/.claude/hooks/.lazyclaude-notify")
PENDING_PATH = os.path.expanduser("~/.claude/hooks/.lazyclaude-pending-notification")

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
    message = f"Task finished in {project_name}"
elif stop_reason == "max_tokens":
    message = f"Hit token limit in {project_name}"
else:
    message = f"Claude stopped in {project_name} ({stop_reason})"

# Debounce: skip if a notification was sent less than 5 seconds ago
DEBOUNCE_PATH = os.path.expanduser("~/.claude/hooks/.lazyclaude-notify-last")
if os.path.exists(DEBOUNCE_PATH):
    try:
        age = time.time() - os.path.getmtime(DEBOUNCE_PATH)
        if age < 5:
            sys.exit(0)
    except OSError:
        pass

# Touch debounce file
with open(DEBOUNCE_PATH, "w") as f:
    f.write("")

# Write pending notification file for the Swift app to pick up
notification = {
    "title": "LazyClaude",
    "message": message,
    "projectName": project_name
}

with open(PENDING_PATH, "w") as f:
    json.dump(notification, f)
