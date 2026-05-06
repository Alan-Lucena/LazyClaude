# LazyClaude Windows Uninstaller
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$HooksDir = "$env:USERPROFILE\.claude\hooks"
$StartupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

Write-Host "==> Uninstalling LazyClaude..."

# Kill tray app
Get-CimInstance Win32_Process -Filter "Name LIKE 'python%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*tray.py*" -or $_.CommandLine -like "*lazy-claude-tray*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Remove files
$files = @(
    "$HooksDir\autoaccept-hook",
    "$HooksDir\notify-hook",
    "$HooksDir\lazy-claude-tray.py",
    "$HooksDir\.lazyclaude",
    "$HooksDir\.lazyclaude-response",
    "$HooksDir\.lazyclaude-notify",
    "$HooksDir\.lazyclaude-projects",
    "$HooksDir\.lazyclaude-known-projects",
    "$StartupDir\LazyClaude.lnk"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "   Removed: $file"
    }
}

Write-Host ""
Write-Host "==> LazyClaude uninstalled."
Write-Host "    Note: Claude Code hook config in ~/.claude/settings.json was not modified."
Write-Host "    Remove the PermissionRequest and Stop hooks manually if desired."
