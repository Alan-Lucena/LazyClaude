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

# Detect which editor has this project open
def detect_editor():
    """Detect if project is open in VS Code, Code Insiders, or Cursor."""
    for exe_name, display_name in [("Cursor", "Cursor"), ("Code", "Code"), ("Code - Insiders", "Code - Insiders")]:
        check = f'''
        $procs = Get-Process -Name "{exe_name}" -ErrorAction SilentlyContinue
        if ($procs) {{
            foreach ($p in $procs) {{
                if ($p.MainWindowTitle -like "*{project_name}*") {{
                    Write-Output "{exe_name}"
                    exit
                }}
            }}
        }}
        '''
        try:
            result = subprocess.run(
                ["powershell", "-ExecutionPolicy", "Bypass", "-Command", check],
                capture_output=True, text=True, timeout=5
            )
            if result.stdout.strip() == exe_name:
                return exe_name
        except Exception:
            continue
    return "Code"

editor_process = detect_editor()

# Send Windows toast notification via PowerShell with click-to-focus
ps_script = f'''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast activationType="protocol" launch="" duration="short">
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

# Register click handler to focus the editor window
$activated = Register-ObjectEvent -InputObject $toast -EventName Activated -Action {{
    $procs = Get-Process -Name "{editor_process}" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {{
        if ($p.MainWindowTitle -like "*{project_name}*") {{
            Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {{
                [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
                [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            }}
"@
            [Win32]::ShowWindow($p.MainWindowHandle, 9)
            [Win32]::SetForegroundWindow($p.MainWindowHandle)
            break
        }}
    }}
}}

[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("LazyClaude").Show($toast)
Start-Sleep -Seconds 10
Unregister-Event -SourceIdentifier $activated.Name
'''

try:
    subprocess.Popen(
        ["powershell", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
except Exception:
    # Fallback: simple balloon tip (not clickable)
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
