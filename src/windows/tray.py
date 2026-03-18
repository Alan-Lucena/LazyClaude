#!/usr/bin/env python3
"""LazyClaude - Windows System Tray App

Mirrors the macOS Swift menu bar app functionality using pystray.
Requires: pip install pystray Pillow
"""

import os
import sys
import json
import subprocess
import threading
import time

try:
    import pystray
    from PIL import Image, ImageDraw
except ImportError:
    print("Required packages missing. Install with:")
    print("  pip install pystray Pillow")
    sys.exit(1)

# Config paths
CLAUDE_DIR = os.path.join(os.path.expanduser("~"), ".claude", "hooks")
CONFIG_PATH = os.path.join(CLAUDE_DIR, ".lazyclaude")
RESPONSE_PATH = os.path.join(CLAUDE_DIR, ".lazyclaude-response")
NOTIFY_PATH = os.path.join(CLAUDE_DIR, ".lazyclaude-notify")
PROJECTS_PATH = os.path.join(CLAUDE_DIR, ".lazyclaude-projects")
KNOWN_PROJECTS_PATH = os.path.join(CLAUDE_DIR, ".lazyclaude-known-projects")
SESSIONS_DIR = os.path.join(os.path.expanduser("~"), ".claude", "projects")
VSCODE_SETTINGS = os.path.join(os.environ.get("APPDATA", ""), "Code", "User", "settings.json")


class LazyClaude:
    def __init__(self):
        self.is_enabled = False
        self.current_mode = "safe"
        self.is_auto_response = False
        self.response_text = ""
        self.is_notifications = False
        self.known_projects = []  # list of dicts: {name, path, mode}
        self.icon = None
        self.read_config()

        # Background refresh for projects
        self._refresh_thread = threading.Thread(target=self._refresh_loop, daemon=True)
        self._refresh_thread.start()

    def _refresh_loop(self):
        while True:
            time.sleep(5)
            self.discover_projects()
            if self.icon:
                self.icon.update_menu()

    # ── Config I/O ──────────────────────────────────────────────

    def read_config(self):
        if os.path.exists(CONFIG_PATH):
            mode = open(CONFIG_PATH).read().strip()
            self.is_enabled = True
            self.current_mode = "yolo" if mode == "yolo" else "safe"
        else:
            self.is_enabled = False
            self.current_mode = "safe"

        if os.path.exists(RESPONSE_PATH):
            text = open(RESPONSE_PATH).read().strip()
            self.is_auto_response = bool(text)
            self.response_text = text
        else:
            self.is_auto_response = False
            self.response_text = ""

        if os.path.exists(NOTIFY_PATH):
            self.is_notifications = open(NOTIFY_PATH).read().strip() == "on"
        else:
            self.is_notifications = False

        self.discover_projects()

    def write_config(self):
        os.makedirs(CLAUDE_DIR, exist_ok=True)
        with open(CONFIG_PATH, "w") as f:
            f.write(self.current_mode)
        self.set_vscode_skip_permissions(self.current_mode == "yolo" and self.is_enabled)

    def write_response(self):
        with open(RESPONSE_PATH, "w") as f:
            f.write(self.response_text)

    def write_projects_config(self):
        overrides = {p["path"]: p["mode"] for p in self.known_projects if p["mode"] != "global"}
        if not overrides:
            try:
                os.remove(PROJECTS_PATH)
            except FileNotFoundError:
                pass
        else:
            with open(PROJECTS_PATH, "w") as f:
                json.dump(overrides, f, indent=2)

    # ── Project Discovery ───────────────────────────────────────

    def discover_projects(self):
        overrides = {}
        if os.path.exists(PROJECTS_PATH):
            try:
                overrides = json.load(open(PROJECTS_PATH))
            except Exception:
                pass

        projects = []
        seen_paths = set()

        # Scan session directories
        if os.path.isdir(SESSIONS_DIR):
            for entry in os.listdir(SESSIONS_DIR):
                entry_path = os.path.join(SESSIONS_DIR, entry)
                if not os.path.isdir(entry_path):
                    continue
                if entry.count("-") < 3:
                    continue
                try:
                    jsonl_files = [f for f in os.listdir(entry_path) if f.endswith(".jsonl")]
                    if not jsonl_files:
                        continue
                    filepath = os.path.join(entry_path, jsonl_files[0])
                    with open(filepath) as f:
                        for line in list(f)[:10]:
                            try:
                                data = json.loads(line)
                                cwd = data.get("cwd")
                                if cwd and os.path.exists(cwd) and cwd not in seen_paths:
                                    seen_paths.add(cwd)
                                    name = os.path.basename(cwd.rstrip("/\\")) or cwd
                                    mode = overrides.get(cwd, "global")
                                    projects.append({"name": name, "path": cwd, "mode": mode})
                                    break
                            except (json.JSONDecodeError, KeyError):
                                continue
                except Exception:
                    continue

        # Also include hook-discovered projects
        if os.path.exists(KNOWN_PROJECTS_PATH):
            try:
                known = json.load(open(KNOWN_PROJECTS_PATH))
                for path, info in known.items():
                    if path not in seen_paths and os.path.exists(path):
                        seen_paths.add(path)
                        name = info.get("name", os.path.basename(path))
                        mode = overrides.get(path, "global")
                        projects.append({"name": name, "path": path, "mode": mode})
            except Exception:
                pass

        projects.sort(key=lambda p: p["name"].lower())
        self.known_projects = projects

    # ── VS Code Integration ─────────────────────────────────────

    def set_vscode_skip_permissions(self, skip):
        if not os.path.exists(VSCODE_SETTINGS):
            return
        try:
            with open(VSCODE_SETTINGS) as f:
                settings = json.load(f)
        except Exception:
            return

        if skip:
            settings["claudeCode.allowDangerouslySkipPermissions"] = True
            settings["claudeCode.initialPermissionMode"] = "bypassPermissions"
        else:
            settings.pop("claudeCode.allowDangerouslySkipPermissions", None)
            settings["claudeCode.initialPermissionMode"] = "default"

        try:
            with open(VSCODE_SETTINGS, "w") as f:
                json.dump(settings, f, indent=2)
        except Exception:
            pass

    # ── Actions ─────────────────────────────────────────────────

    def toggle_enabled(self):
        self.is_enabled = not self.is_enabled
        if self.is_enabled:
            self.write_config()
        else:
            try:
                os.remove(CONFIG_PATH)
            except FileNotFoundError:
                pass
            self.set_vscode_skip_permissions(False)
        self.update_icon()

    def set_mode(self, mode):
        self.current_mode = mode
        if self.is_enabled:
            self.write_config()
        self.update_icon()

    def toggle_auto_response(self):
        self.is_auto_response = not self.is_auto_response
        if self.is_auto_response:
            if not self.response_text:
                self.edit_response()
            else:
                self.write_response()
        else:
            try:
                os.remove(RESPONSE_PATH)
            except FileNotFoundError:
                pass

    def edit_response(self):
        """Open a simple input dialog via PowerShell."""
        ps_script = f'''
Add-Type -AssemblyName Microsoft.VisualBasic
$result = [Microsoft.VisualBasic.Interaction]::InputBox(
    "This text will be sent as your answer when Claude asks a question.",
    "LazyClaude - Auto-response",
    "{self.response_text}"
)
Write-Output $result
'''
        try:
            result = subprocess.run(
                ["powershell", "-Command", ps_script],
                capture_output=True, text=True, timeout=60
            )
            text = result.stdout.strip()
            if text:
                self.response_text = text
                self.is_auto_response = True
                self.write_response()
            else:
                self.is_auto_response = False
                self.response_text = ""
                try:
                    os.remove(RESPONSE_PATH)
                except FileNotFoundError:
                    pass
        except Exception:
            pass

    def toggle_notifications(self):
        self.is_notifications = not self.is_notifications
        if self.is_notifications:
            with open(NOTIFY_PATH, "w") as f:
                f.write("on")
        else:
            try:
                os.remove(NOTIFY_PATH)
            except FileNotFoundError:
                pass

    def set_project_mode(self, path, mode):
        for p in self.known_projects:
            if p["path"] == path:
                p["mode"] = mode
                break
        self.write_projects_config()

    # ── Icon Drawing ────────────────────────────────────────────

    def create_icon_image(self):
        """Draw a bolt icon matching the current state."""
        size = 64
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        if not self.is_enabled:
            # Gray bolt outline
            color = (150, 150, 150, 255)
        elif self.current_mode == "yolo":
            # Red/orange bolt
            color = (255, 69, 58, 255)
        else:
            # Blue bolt (safe)
            color = (0, 122, 255, 255)

        # Draw a lightning bolt
        bolt = [
            (30, 4), (14, 30), (28, 30),
            (22, 60), (50, 24), (34, 24), (42, 4)
        ]
        draw.polygon(bolt, fill=color)

        if not self.is_enabled:
            # Draw circle outline for "off" state
            draw.ellipse([4, 4, 60, 60], outline=color, width=3)

        return img

    def update_icon(self):
        if self.icon:
            self.icon.icon = self.create_icon_image()

    # ── Menu Building ───────────────────────────────────────────

    def build_menu(self):
        self.read_config()

        def on_toggle(icon, item):
            self.toggle_enabled()

        def on_safe(icon, item):
            self.set_mode("safe")

        def on_yolo(icon, item):
            self.set_mode("yolo")

        def on_auto_response(icon, item):
            self.toggle_auto_response()

        def on_edit_response(icon, item):
            self.edit_response()

        def on_notify(icon, item):
            self.toggle_notifications()

        # Mode label for display
        def mode_label():
            if not self.is_enabled:
                return "OFF"
            return self.current_mode.upper()

        items = [
            pystray.MenuItem(
                f"LazyClaude [{mode_label()}]",
                None, enabled=False
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                "Auto-accept",
                on_toggle,
                checked=lambda item: self.is_enabled
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                "Safe mode",
                on_safe,
                checked=lambda item: self.current_mode == "safe",
                enabled=lambda item: self.is_enabled
            ),
            pystray.MenuItem(
                "YOLO mode",
                on_yolo,
                checked=lambda item: self.current_mode == "yolo",
                enabled=lambda item: self.is_enabled
            ),
        ]

        # Projects submenu
        if self.known_projects:
            items.append(pystray.Menu.SEPARATOR)

            for project in self.known_projects:
                mode_labels = {"global": "Global", "safe": "Safe", "yolo": "YOLO", "off": "Off"}
                current_label = mode_labels.get(project["mode"], "Global")

                def make_mode_setter(path, mode):
                    def setter(icon, item):
                        self.set_project_mode(path, mode)
                    return setter

                def make_checker(path, mode):
                    def checker(item):
                        for p in self.known_projects:
                            if p["path"] == path:
                                return p["mode"] == mode
                        return False
                    return checker

                submenu = pystray.Menu(
                    *[
                        pystray.MenuItem(
                            label,
                            make_mode_setter(project["path"], mode_val),
                            checked=make_checker(project["path"], mode_val)
                        )
                        for mode_val, label in [
                            ("global", "Global default"),
                            ("safe", "Safe mode"),
                            ("yolo", "YOLO mode"),
                            ("off", "Off"),
                        ]
                    ]
                )

                items.append(pystray.MenuItem(
                    f"  {project['name']}  [{current_label}]",
                    submenu
                ))

        items.append(pystray.Menu.SEPARATOR)

        # Auto-response
        items.append(pystray.MenuItem(
            "Auto-response",
            on_auto_response,
            checked=lambda item: self.is_auto_response
        ))

        if self.is_auto_response and self.response_text:
            display = self.response_text[:30] + "..." if len(self.response_text) > 30 else self.response_text
            items.append(pystray.MenuItem(
                f'  "{display}"',
                on_edit_response
            ))

        # Notifications
        items.append(pystray.MenuItem(
            "Notifications",
            on_notify,
            checked=lambda item: self.is_notifications
        ))

        items.append(pystray.Menu.SEPARATOR)
        items.append(pystray.MenuItem("Quit", lambda icon, item: icon.stop()))

        return pystray.Menu(*items)

    # ── Run ─────────────────────────────────────────────────────

    def run(self):
        self.icon = pystray.Icon(
            "LazyClaude",
            self.create_icon_image(),
            "LazyClaude",
            menu=self.build_menu()
        )
        self.icon.run()


if __name__ == "__main__":
    app = LazyClaude()
    app.run()
