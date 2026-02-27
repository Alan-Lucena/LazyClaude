#!/usr/bin/env python3
import sys, json, os

CONFIG = os.path.expanduser("~/.claude/hooks/.lazyclaude")
RESPONSE_FILE = os.path.expanduser("~/.claude/hooks/.lazyclaude-response")

ALLOW = {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}

# Parse stdin
data = json.loads(sys.stdin.read())
tool = data.get("tool_name", "")
tool_input = data.get("tool_input", {})

# Auto-response for AskUserQuestion (independent of auto-accept)
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

# Auto-accept: check config
if not os.path.exists(CONFIG):
    sys.exit(0)

mode = open(CONFIG).read().strip()

# ExitPlanMode protection (safe mode only)
if mode == "safe" and tool == "ExitPlanMode":
    sys.exit(0)

# Allow everything else
print(json.dumps(ALLOW))
