#!/usr/bin/env python3
"""LazyClaude notification hook for Windows.

Uses PowerShell toast notifications via BurntToast or native .NET.
"""

import sys
import json
import os
import subprocess

NOTIFY_CONFIG = os.path.join(os.path.expanduser("~"), ".claude", "hooks", ".lazyclaude-notify")

# Check if notifications are enabled
if not os.path.exists(NOTIFY_CONFIG):
    sys.exit(0)

if open(NOTIFY_CONFIG).read().strip() != "on":
    sys.exit(0)

# Parse stdin
data = json.loads(sys.stdin.read())
stop_reason = data.get("stop_reason", "end_turn")
cwd = data.get("cwd", "")
project_name = os.path.basename(cwd.rstrip("/\\")) if cwd else "Unknown"

# Build message
if stop_reason == "end_turn":
    message = f"Task finished in {project_name}"
elif stop_reason == "max_tokens":
    message = f"Hit token limit in {project_name}"
else:
    message = f"Claude stopped in {project_name} ({stop_reason})"

# Send Windows toast notification via PowerShell
ps_script = f'''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast duration="short">
    <visual>
        <binding template="ToastGeneric">
            <text>LazyClaude</text>
            <text>{message}</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("LazyClaude").Show($toast)
'''

try:
    subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
        capture_output=True, timeout=10
    )
except Exception:
    # Fallback: simple balloon tip
    fallback = f'''
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.ShowBalloonTip(5000, "LazyClaude", "{message}", [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 6
    $notify.Dispose()
    '''
    try:
        subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-Command", fallback],
            capture_output=True, timeout=15
        )
    except Exception:
        pass
