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
    var isAutoAccept = false
    var toggleView: ToggleMenuItem?
    let flagPath = NSHomeDirectory() + "/.claude/hooks/.autoaccept"

    func applicationDidFinishLaunching(_ notification: Notification) {
        isAutoAccept = FileManager.default.fileExists(atPath: flagPath)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Header
        let header = NSMenuItem(title: "Claude Flow", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(NSMenuItem.separator())

        // Toggle
        let toggleItem = NSMenuItem()
        toggleView = ToggleMenuItem(title: "Auto-accept All", isOn: isAutoAccept) { [weak self] isOn in
            self?.setAutoAccept(isOn)
        }
        toggleItem.view = toggleView
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let current = FileManager.default.fileExists(atPath: flagPath)
        if current != isAutoAccept {
            isAutoAccept = current
            updateIcon()
        }
        toggleView?.update(isOn: isAutoAccept)
    }

    func setAutoAccept(_ on: Bool) {
        isAutoAccept = on
        if on {
            FileManager.default.createFile(atPath: flagPath, contents: nil)
        } else {
            try? FileManager.default.removeItem(atPath: flagPath)
        }
        updateIcon()
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let name = isAutoAccept ? "bolt.circle.fill" : "bolt.circle"
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "Claude Auto-Accept") {
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
