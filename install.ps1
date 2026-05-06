# LazyClaude Windows Installer
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$HooksDir = "$env:USERPROFILE\.claude\hooks"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

Write-Host "==> Installing LazyClaude for Windows..."

# Kill existing process
Get-CimInstance Win32_Process -Filter "Name LIKE 'python%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*tray.py*" -or $_.CommandLine -like "*lazy-claude-tray*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Create hooks directory
New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null

# Install hooks
Write-Host "==> Installing hooks..."
Copy-Item "$ScriptDir\src\autoaccept-hook.py" "$HooksDir\autoaccept-hook" -Force
Copy-Item "$ScriptDir\src\windows\notify-hook.py" "$HooksDir\notify-hook" -Force

# Install tray app
Write-Host "==> Installing tray app..."
Copy-Item "$ScriptDir\src\windows\tray.py" "$HooksDir\lazy-claude-tray.py" -Force

# Check Python dependencies
Write-Host "==> Checking Python dependencies..."
try {
    python -c "import pystray, PIL" 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "    pystray and Pillow already installed."
} catch {
    Write-Host "    Installing pystray and Pillow..."
    pip install pystray Pillow --quiet
}

# Create startup shortcut
Write-Host "==> Creating startup shortcut..."
$ShortcutPath = "$StartupDir\LazyClaude.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$pythonw = Get-Command pythonw -ErrorAction SilentlyContinue
if ($pythonw) { $Shortcut.TargetPath = $pythonw.Source } else { $Shortcut.TargetPath = (Get-Command python).Source }
$Shortcut.Arguments = "`"$HooksDir\lazy-claude-tray.py`""
$Shortcut.WindowStyle = 7  # Minimized
$Shortcut.Description = "LazyClaude System Tray"
$Shortcut.Save()

# Configure Claude Code hooks
$SettingsFile = "$env:USERPROFILE\.claude\settings.json"

if (-not (Test-Path $SettingsFile)) {
    '{}' | Out-File -Encoding utf8 $SettingsFile
}

$settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json

if ($settings.hooks.PermissionRequest) {
    Write-Host ""
    Write-Host "==> PermissionRequest hook already exists in settings.json"
    Write-Host "    Please verify it points to: $HooksDir\autoaccept-hook"
} else {
    Write-Host ""
    Write-Host "==> Add this to your $SettingsFile under `"hooks`":"
    Write-Host ""
    Write-Host @"
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python \"$HooksDir\autoaccept-hook\"",
            "timeout": 130
          }
        ]
      }
    ]
"@
}

if ($settings.hooks.Stop) {
    Write-Host "==> Stop hook already exists in settings.json"
    Write-Host "    Please verify it points to: $HooksDir\notify-hook"
} else {
    Write-Host ""
    Write-Host "==> Also add this under `"hooks`" for notifications:"
    Write-Host ""
    Write-Host @"
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python \"$HooksDir\notify-hook\""
          }
        ]
      }
    ]
"@
}

# Start tray app
Write-Host ""
Write-Host "==> Starting tray app..."
Start-Process pythonw -ArgumentList "`"$HooksDir\lazy-claude-tray.py`"" -WindowStyle Hidden

Write-Host ""
Write-Host "==> LazyClaude installed successfully!"
Write-Host ""
Write-Host "   - Auto-accept hook: $HooksDir\autoaccept-hook"
Write-Host "   - Notify hook:      $HooksDir\notify-hook"
Write-Host "   - Tray app:         $HooksDir\lazy-claude-tray.py"
Write-Host "   - Config file:      $HooksDir\.lazyclaude"
Write-Host "   - Startup shortcut: $ShortcutPath"
Write-Host ""
Write-Host "   You should see a bolt icon in your system tray."
