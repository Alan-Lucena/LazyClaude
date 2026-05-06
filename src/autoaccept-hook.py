#!/usr/bin/env python3
import sys, json, os, datetime

CONFIG = os.path.expanduser("~/.claude/hooks/.lazyclaude")
RESPONSE_FILE = os.path.expanduser("~/.claude/hooks/.lazyclaude-response")
PROJECTS_FILE = os.path.expanduser("~/.claude/hooks/.lazyclaude-projects")
KNOWN_PROJECTS_FILE = os.path.expanduser("~/.claude/hooks/.lazyclaude-known-projects")

ALLOW = {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}

# Parse stdin
data = json.loads(sys.stdin.read())
tool = data.get("tool_name", "")
tool_input = data.get("tool_input", {})
cwd = data.get("cwd", "")

# Register discovered project
if cwd:
    try:
        known = {}
        if os.path.exists(KNOWN_PROJECTS_FILE):
            with open(KNOWN_PROJECTS_FILE) as f:
                known = json.load(f)
        known[cwd] = {
            "name": os.path.basename(cwd.rstrip("/\\")) or cwd,
            "last_seen": datetime.datetime.now().isoformat()
        }
        with open(KNOWN_PROJECTS_FILE, "w") as f:
            json.dump(known, f, indent=2)
    except Exception:
        pass

# Determine effective mode: project-specific or global
mode = None

if cwd:
    try:
        if os.path.exists(PROJECTS_FILE):
            with open(PROJECTS_FILE) as f:
                projects = json.load(f)
            check_path = cwd
            while True:
                if check_path in projects:
                    project_mode = projects[check_path]
                    if project_mode == "off":
                        sys.exit(0)
                    elif project_mode in ("safe", "yolo"):
                        mode = project_mode
                    break
                parent = os.path.dirname(check_path)
                if parent == check_path:
                    break
                check_path = parent
    except Exception:
        pass

# Fall back to global config
if mode is None:
    if not os.path.exists(CONFIG):
        sys.exit(0)
    mode = open(CONFIG).read().strip()

# Safe mode protections
if mode == "safe":
    # Don't auto-exit plan mode
    if tool == "ExitPlanMode":
        sys.exit(0)
    # Don't auto-respond to AskUserQuestion — let the user answer
    if tool == "AskUserQuestion":
        sys.exit(0)

# Auto-response for AskUserQuestion (yolo mode only)
if tool == "AskUserQuestion" and os.path.exists(RESPONSE_FILE):
    response_text = open(RESPONSE_FILE).read().strip()
    if response_text:
        questions = tool_input.get("questions", [])
        answers = {}
        for q in questions:
            answers[q.get("question", "")] = response_text
        result = {
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {
                    "behavior": "allow",
                    "updatedInput": {
                        "questions": questions,
                        "answers": answers
                    }
                }
            }
        }
        print(json.dumps(result))
        sys.exit(0)

# Allow everything else
print(json.dumps(ALLOW))
