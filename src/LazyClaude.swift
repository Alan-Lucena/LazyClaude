import Cocoa
import UserNotifications

// MARK: - Custom drawn toggle (iOS-style with blue/gray)
class CustomToggle: NSView {
    var isOn: Bool { didSet { needsDisplay = true } }
    var onToggle: ((Bool) -> Void)?

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: 40, height: 22))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)

        if isOn {
            NSColor.systemBlue.setFill()
        } else {
            NSColor.systemGray.withAlphaComponent(0.4).setFill()
        }
        path.fill()

        let knobDiameter = rect.height - 4
        let knobX = isOn ? rect.width - knobDiameter - 2 : 2.0
        let knobRect = NSRect(x: knobX + 0.5, y: 2.5, width: knobDiameter, height: knobDiameter)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        shadow.set()

        let knob = NSBezierPath(ovalIn: knobRect)
        NSColor.white.setFill()
        knob.fill()
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
    }
}

// MARK: - Menu item view with label + toggle
class ToggleMenuItem: NSView {
    let customToggle: CustomToggle
    let label: NSTextField
    var onToggle: ((Bool) -> Void)?

    init(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        self.customToggle = CustomToggle(isOn: isOn)
        self.label = NSTextField(labelWithString: title)
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 36))

        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.frame = NSRect(x: 16, y: 8, width: 160, height: 20)
        addSubview(label)

        customToggle.frame = NSRect(
            x: frame.width - 40 - 16,
            y: (frame.height - 22) / 2,
            width: 40,
            height: 22
        )
        customToggle.onToggle = { [weak self] val in
            self?.onToggle?(val)
        }
        addSubview(customToggle)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(isOn: Bool) {
        customToggle.isOn = isOn
    }
}

// MARK: - Project info
struct ProjectInfo {
    var name: String
    var path: String
    var lastSeen: Date
    var mode: String  // "global", "safe", "yolo", "off"
}

// MARK: - Notification click handler
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Activate the editor when user clicks the notification
        let bundleIds = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92"]
        for bundleId in bundleIds {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                app.activate()
                break
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var isEnabled = false
    var currentMode = "safe"
    var isAutoResponse = false
    var isNotificationsEnabled = false
    var responseText = ""
    var toggleView: ToggleMenuItem?
    var responseToggleView: ToggleMenuItem?
    var notifyToggleView: ToggleMenuItem?
    var safeItem: NSMenuItem!
    var yoloItem: NSMenuItem!
    var responseTextItem: NSMenuItem!
    var knownProjects: [ProjectInfo] = []
    var cachedSessionProjects: [(String, String)] = []  // (path, name)
    var cachedOpenNames: Set<String> = []
    var refreshTimer: Timer?
    var notificationTimer: Timer?
    let notificationDelegate = NotificationDelegate()
    let pendingNotificationPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-pending-notification"
    var lastNotificationTime: Date = .distantPast
    let configPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude"
    let responsePath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-response"
    let notifyPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-notify"
    let projectsConfigPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-projects"
    let knownProjectsPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-known-projects"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-cache session projects (slow, only once)
        cachedSessionProjects = discoverAllSessionProjects()
        cachedOpenNames = getOpenVSCodeProjectNames()
        readConfig()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()

        // Setup notification center for clickable notifications
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Register action category with "Ver" button
        let openAction = UNNotificationAction(
            identifier: "OPEN_EDITOR",
            title: "Abrir Editor",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "TASK_DONE",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])

        // When app becomes active (from "Abrir Editor" button), activate editor
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self,
                  Date().timeIntervalSince(self.lastNotificationTime) < 30 else { return }
            self.lastNotificationTime = .distantPast
            let bundleIds = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92"]
            for bundleId in bundleIds {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                    app.activate()
                    break
                }
            }
        }

        // Refresh open windows + session cache every 5 seconds in background
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshProjectsInBackground()
        }

        // Check for pending notifications every second
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPendingNotification()
        }

    }

    func checkPendingNotification() {
        guard FileManager.default.fileExists(atPath: pendingNotificationPath),
              let data = FileManager.default.contents(atPath: pendingNotificationPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }

        // Remove file immediately to avoid re-sending
        try? FileManager.default.removeItem(atPath: pendingNotificationPath)

        let title = json["title"] ?? "LazyClaude"
        let message = json["message"] ?? "Task finished"
        let projectName = json["projectName"] ?? ""

        lastNotificationTime = Date()

        // Show clickable notification via UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "TASK_DONE"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }


    func refreshProjectsInBackground() {
        // File I/O in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let newSessions = self?.discoverAllSessionProjects() ?? []
            DispatchQueue.main.async {
                self?.cachedSessionProjects = newSessions
                // AppleScript must run on main thread
                self?.cachedOpenNames = self?.getOpenVSCodeProjectNames() ?? []
            }
        }
    }

    func readConfig() {
        if FileManager.default.fileExists(atPath: configPath),
           let content = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let mode = content.trimmingCharacters(in: .whitespacesAndNewlines)
            isEnabled = true
            currentMode = (mode == "yolo") ? "yolo" : "safe"
        } else {
            isEnabled = false
            currentMode = "safe"
        }

        if FileManager.default.fileExists(atPath: responsePath),
           let content = try? String(contentsOfFile: responsePath, encoding: .utf8) {
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            isAutoResponse = !text.isEmpty
            responseText = text
        } else {
            isAutoResponse = false
            responseText = ""
        }

        if FileManager.default.fileExists(atPath: notifyPath),
           let content = try? String(contentsOfFile: notifyPath, encoding: .utf8) {
            isNotificationsEnabled = content.trimmingCharacters(in: .whitespacesAndNewlines) == "on"
        } else {
            isNotificationsEnabled = false
        }

        readProjectsConfig()
    }

    func readProjectsConfig() {
        knownProjects = []

        // Read per-project overrides
        var overrides: [String: String] = [:]
        if let data = FileManager.default.contents(atPath: projectsConfigPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            overrides = json
        }

        // Use cached data (refreshed every 5s in background)
        let openNames = cachedOpenNames

        // Only show projects that have an open VS Code window
        for (path, name) in cachedSessionProjects {
            guard openNames.contains(name) else { continue }
            guard !knownProjects.contains(where: { $0.path == path }) else { continue }
            let mode = overrides[path] ?? "global"
            knownProjects.append(ProjectInfo(name: name, path: path, lastSeen: Date(), mode: mode))
        }

        // Also include hook-discovered projects if they have an open window
        if let data = FileManager.default.contents(atPath: knownProjectsPath),
           let known = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            for (path, info) in known {
                let name = info["name"] as? String ?? (path as NSString).lastPathComponent
                guard openNames.contains(name) else { continue }
                guard !knownProjects.contains(where: { $0.path == path }) else { continue }
                let mode = overrides[path] ?? "global"
                knownProjects.append(ProjectInfo(name: name, path: path, lastSeen: Date(), mode: mode))
            }
        }

        knownProjects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func getOpenVSCodeProjectNames() -> Set<String> {
        let script = """
        set projectNames to {}
        tell application "System Events"
            repeat with procName in {"Code", "Code - Insiders", "Cursor"}
                if exists (process procName) then
                    tell process procName
                        repeat with w in every window
                            set end of projectNames to name of w
                        end repeat
                    end tell
                end if
            end repeat
        end tell
        return projectNames
        """

        guard let appleScript = NSAppleScript(source: script) else { return [] }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else { return [] }

        var names: Set<String> = []
        guard result.numberOfItems > 0 else { return names }
        for i in 1...result.numberOfItems {
            guard let title = result.atIndex(i)?.stringValue else { continue }
            // VS Code titles: "filename — ProjectName" or just "ProjectName"
            if let range = title.range(of: " \u{2014} ") {
                var projectName = String(title[range.upperBound...])
                // Remove suffixes like " [Extension Development Host]"
                if let bracket = projectName.range(of: " [") {
                    projectName = String(projectName[..<bracket.lowerBound])
                }
                names.insert(projectName)
            } else {
                names.insert(title)
            }
        }
        return names
    }

    func discoverAllSessionProjects() -> [(String, String)] {
        let sessionDir = NSHomeDirectory() + "/.claude/projects"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: sessionDir) else { return [] }

        var results: [(String, String)] = []
        for entry in entries {
            let entryPath = sessionDir + "/" + entry
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entryPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let dashCount = entry.filter({ $0 == "-" }).count
            guard dashCount >= 3 else { continue }

            guard let files = try? FileManager.default.contentsOfDirectory(atPath: entryPath) else { continue }
            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            guard let firstFile = jsonlFiles.first else { continue }

            let filePath = entryPath + "/" + firstFile
            guard let data = FileManager.default.contents(atPath: filePath),
                  let content = String(data: data, encoding: .utf8) else { continue }

            var projectPath: String?
            for line in content.components(separatedBy: .newlines).prefix(10) {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let cwd = json["cwd"] as? String else { continue }
                projectPath = cwd
                break
            }

            guard let path = projectPath,
                  FileManager.default.fileExists(atPath: path),
                  !results.contains(where: { $0.0 == path }) else { continue }

            let name = (path as NSString).lastPathComponent
            results.append((path, name))
        }
        return results
    }

    func writeProjectsConfig() {
        var overrides: [String: String] = [:]
        for project in knownProjects {
            if project.mode != "global" {
                overrides[project.path] = project.mode
            }
        }

        if overrides.isEmpty {
            try? FileManager.default.removeItem(atPath: projectsConfigPath)
        } else if let data = try? JSONSerialization.data(
            withJSONObject: overrides,
            options: [.prettyPrinted, .sortedKeys]
        ), let str = String(data: data, encoding: .utf8) {
            try? str.write(toFile: projectsConfigPath, atomically: true, encoding: .utf8)
        }
    }

    func projectModeLabel(_ mode: String) -> String {
        switch mode {
        case "safe": return "[Safe]"
        case "yolo": return "[YOLO]"
        case "off":  return "[Off]"
        default:     return "[Global]"
        }
    }

    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // Header
        let header = NSMenuItem(title: "LazyClaude", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(NSMenuItem.separator())

        // Auto-accept toggle
        let toggleItem = NSMenuItem()
        toggleView = ToggleMenuItem(title: "Auto-accept", isOn: isEnabled) { [weak self] isOn in
            self?.setEnabled(isOn)
        }
        toggleItem.view = toggleView
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Mode: Safe
        safeItem = NSMenuItem(title: "Safe mode", action: #selector(selectSafe), keyEquivalent: "")
        safeItem.target = self
        menu.addItem(safeItem)

        // Mode: YOLO
        yoloItem = NSMenuItem(title: "YOLO mode", action: #selector(selectYolo), keyEquivalent: "")
        yoloItem.target = self
        menu.addItem(yoloItem)

        // Projects section
        if !knownProjects.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let projectsHeader = NSMenuItem(title: "Projects", action: nil, keyEquivalent: "")
            projectsHeader.isEnabled = false
            menu.addItem(projectsHeader)

            for project in knownProjects {
                let modeLabel = projectModeLabel(project.mode)
                let title = "  \(project.name)  \(modeLabel)"

                let projectItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                projectItem.toolTip = project.path

                let submenu = NSMenu()
                let modes: [(String, String)] = [
                    ("global", "Global default"),
                    ("safe", "Safe mode"),
                    ("yolo", "YOLO mode"),
                    ("off", "Off")
                ]

                for (modeValue, modeTitle) in modes {
                    let modeItem = NSMenuItem(
                        title: modeTitle,
                        action: #selector(setProjectMode(_:)),
                        keyEquivalent: ""
                    )
                    modeItem.target = self
                    modeItem.representedObject = ["path": project.path, "mode": modeValue]
                    modeItem.state = (project.mode == modeValue) ? .on : .off
                    submenu.addItem(modeItem)
                }

                projectItem.submenu = submenu
                menu.addItem(projectItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Auto-response toggle
        let responseItem = NSMenuItem()
        responseToggleView = ToggleMenuItem(title: "Auto-response", isOn: isAutoResponse) { [weak self] isOn in
            self?.setAutoResponse(isOn)
        }
        responseItem.view = responseToggleView
        menu.addItem(responseItem)

        // Response text (clickable to edit)
        responseTextItem = NSMenuItem(title: "", action: #selector(editResponse), keyEquivalent: "")
        responseTextItem.target = self
        menu.addItem(responseTextItem)

        // Notifications toggle
        let notifyItem = NSMenuItem()
        notifyToggleView = ToggleMenuItem(title: "Notifications", isOn: isNotificationsEnabled) { [weak self] isOn in
            self?.setNotifications(isOn)
        }
        notifyItem.view = notifyToggleView
        menu.addItem(notifyItem)

        updateModeItems()

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Only reads config files + uses cached project data (fast)
        readConfig()
        buildMenu()
        updateIcon()
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on {
            writeConfig()
        } else {
            try? FileManager.default.removeItem(atPath: configPath)
            setVSCodeSkipPermissions(false)
        }
        updateModeItems()
        updateIcon()
    }

    @objc func selectSafe() {
        currentMode = "safe"
        if isEnabled { writeConfig() }
        updateModeItems()
        updateIcon()
    }

    @objc func selectYolo() {
        currentMode = "yolo"
        if isEnabled { writeConfig() }
        updateModeItems()
        updateIcon()
    }

    @objc func setProjectMode(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let path = info["path"],
              let newMode = info["mode"],
              let index = knownProjects.firstIndex(where: { $0.path == path }) else { return }

        knownProjects[index].mode = newMode
        writeProjectsConfig()
        buildMenu()
    }

    func setAutoResponse(_ on: Bool) {
        isAutoResponse = on
        if on {
            if responseText.isEmpty {
                editResponse()
            } else {
                writeResponse()
            }
        } else {
            try? FileManager.default.removeItem(atPath: responsePath)
        }
        updateModeItems()
    }

    @objc func editResponse() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Auto-response text"
        alert.informativeText = "This text will be sent as your answer when Claude asks a question."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        textField.stringValue = responseText
        textField.placeholderString = "e.g. proceed with the recommended option"
        textField.isEditable = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                isAutoResponse = false
                responseText = ""
                try? FileManager.default.removeItem(atPath: responsePath)
            } else {
                responseText = text
                isAutoResponse = true
                writeResponse()
            }
            responseToggleView?.update(isOn: isAutoResponse)
            updateModeItems()
        }
    }

    func setNotifications(_ on: Bool) {
        isNotificationsEnabled = on
        if on {
            try? "on".write(toFile: notifyPath, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(atPath: notifyPath)
        }
    }

    func writeConfig() {
        try? currentMode.write(toFile: configPath, atomically: true, encoding: .utf8)
        setVSCodeSkipPermissions(currentMode == "yolo" && isEnabled)
    }

    func writeResponse() {
        try? responseText.write(toFile: responsePath, atomically: true, encoding: .utf8)
    }

    func setVSCodeSkipPermissions(_ skip: Bool) {
        let vscodePath = NSHomeDirectory() + "/Library/Application Support/Code/User/settings.json"
        guard FileManager.default.fileExists(atPath: vscodePath),
              let data = FileManager.default.contents(atPath: vscodePath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if skip {
            json["claudeCode.allowDangerouslySkipPermissions"] = true
            json["claudeCode.initialPermissionMode"] = "bypassPermissions"
        } else {
            json.removeValue(forKey: "claudeCode.allowDangerouslySkipPermissions")
            json["claudeCode.initialPermissionMode"] = "default"
        }

        if let updated = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: updated, encoding: .utf8) {
            try? str.write(toFile: vscodePath, atomically: true, encoding: .utf8)
        }
    }

    func updateModeItems() {
        safeItem.state = (currentMode == "safe") ? .on : .off
        yoloItem.state = (currentMode == "yolo") ? .on : .off
        safeItem.isEnabled = isEnabled
        yoloItem.isEnabled = isEnabled

        if isAutoResponse && !responseText.isEmpty {
            let display = responseText.count > 30
                ? String(responseText.prefix(30)) + "..."
                : responseText
            responseTextItem.title = "\"\(display)\" ✎"
            responseTextItem.isHidden = false
        } else {
            responseTextItem.isHidden = true
        }
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if !isEnabled {
            name = "bolt.circle"
        } else if currentMode == "yolo" {
            name = "bolt.trianglebadge.exclamationmark"
        } else {
            name = "bolt.circle.fill"
        }
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "LazyClaude") {
            img.isTemplate = true
            button.image = img
        }
    }
}

// MARK: - Launch
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
