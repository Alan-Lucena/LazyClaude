import Cocoa

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

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var isEnabled = false
    var currentMode = "safe"
    var isAutoResponse = false
    var responseText = ""
    var toggleView: ToggleMenuItem?
    var responseToggleView: ToggleMenuItem?
    var safeItem: NSMenuItem!
    var yoloItem: NSMenuItem!
    var responseTextItem: NSMenuItem!
    let configPath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude"
    let responsePath = NSHomeDirectory() + "/.claude/hooks/.lazyclaude-response"

    func applicationDidFinishLaunching(_ notification: Notification) {
        readConfig()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
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

        updateModeItems()

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        readConfig()
        toggleView?.update(isOn: isEnabled)
        responseToggleView?.update(isOn: isAutoResponse)
        updateModeItems()
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
