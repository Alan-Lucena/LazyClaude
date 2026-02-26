import Cocoa

// MARK: - Parse stdin as raw JSON
let inputData = FileHandle.standardInput.readDataToEndOfFile()
let json = (try? JSONSerialization.jsonObject(with: inputData)) as? [String: Any] ?? [:]

let toolName = json["tool_name"] as? String ?? "Tool"
let toolInput = json["tool_input"] as? [String: Any] ?? [:]

// Extract the most relevant detail depending on tool type
let detail: String
if let command = toolInput["command"] as? String {
    detail = command
} else if let filePath = toolInput["file_path"] as? String {
    detail = filePath
} else if let url = toolInput["url"] as? String {
    detail = url
} else if let d = toolInput["description"] as? String {
    detail = d
} else if let data = try? JSONSerialization.data(withJSONObject: toolInput, options: [.prettyPrinted]),
          let str = String(data: data, encoding: .utf8) {
    detail = str
} else {
    detail = "No details"
}

let displayDetail = detail.count > 800 ? String(detail.prefix(800)) + "…" : detail

let allowJSON = """
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
"""
let denyJSON = """
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied by user"}}}
"""

// MARK: - Check auto-accept flag (skip for ExitPlanMode)
let flagPath = NSHomeDirectory() + "/.claude/hooks/.autoaccept"
let skipAutoAccept = toolName == "ExitPlanMode"
if !skipAutoAccept && FileManager.default.fileExists(atPath: flagPath) {
    FileHandle.standardOutput.write(allowJSON.data(using: .utf8)!)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    exit(0)
}

// MARK: - Setup app
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// MARK: - Build alert
let alert = NSAlert()
alert.messageText = "Claude Code — \(toolName)"
alert.informativeText = ""
alert.alertStyle = .informational

// Terminal icon
if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
    let icon = NSWorkspace.shared.icon(forFile: terminalURL.path)
    icon.size = NSSize(width: 64, height: 64)
    alert.icon = icon
}

// MARK: - Accessory view (label + code block)
let accessoryWidth: CGFloat = 380

let lineCount = displayDetail.components(separatedBy: "\n").count
let charLines = Int(ceil(Double(displayDetail.count) / 55.0))
let estimatedLines = max(lineCount, charLines)
let codeHeight: CGFloat = min(160, max(48, CGFloat(estimatedLines) * 16 + 16))
let labelHeight: CGFloat = 20
let spacing: CGFloat = 6
let totalHeight = labelHeight + spacing + codeHeight

let container = NSView(frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: totalHeight))

// Label
let label = NSTextField(labelWithString: "Wants to execute:")
label.font = .systemFont(ofSize: 12, weight: .medium)
label.textColor = .secondaryLabelColor
label.frame = NSRect(x: 0, y: totalHeight - labelHeight, width: accessoryWidth, height: labelHeight)
container.addSubview(label)

// Code block background
let codeFrame = NSRect(x: 0, y: 0, width: accessoryWidth, height: codeHeight)
let codeBg = NSView(frame: codeFrame)
codeBg.wantsLayer = true
codeBg.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
codeBg.layer?.cornerRadius = 8
codeBg.layer?.borderColor = NSColor.separatorColor.cgColor
codeBg.layer?.borderWidth = 0.5
container.addSubview(codeBg)

// Scroll view inside code block
let inset: CGFloat = 1
let scrollView = NSScrollView(frame: NSRect(
    x: inset, y: inset,
    width: codeFrame.width - inset * 2,
    height: codeFrame.height - inset * 2
))
scrollView.hasVerticalScroller = true
scrollView.autohidesScrollers = true
scrollView.borderType = .noBorder
scrollView.drawsBackground = false

let textView = NSTextView(frame: NSRect(
    x: 0, y: 0,
    width: scrollView.frame.width,
    height: scrollView.frame.height
))
textView.string = displayDetail
textView.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
textView.textColor = .labelColor
textView.isEditable = false
textView.isSelectable = true
textView.drawsBackground = false
textView.textContainerInset = NSSize(width: 8, height: 6)
textView.textContainer?.widthTracksTextView = true
textView.isVerticallyResizable = true
textView.autoresizingMask = [.width]

scrollView.documentView = textView
codeBg.addSubview(scrollView)

alert.accessoryView = container

// MARK: - Buttons (right to left: Allow, Deny, Allow All)
alert.addButton(withTitle: "Allow")
alert.addButton(withTitle: "Deny")
alert.addButton(withTitle: "Allow All")
alert.buttons[1].keyEquivalent = "\u{1b}" // Escape = Deny

// MARK: - Show & get response
NSApp.activate(ignoringOtherApps: true)
let response = alert.runModal()

// MARK: - Output
let output: String
switch response {
case .alertFirstButtonReturn:
    output = allowJSON
case .alertThirdButtonReturn:
    FileManager.default.createFile(atPath: flagPath, contents: nil)
    output = allowJSON
default:
    output = denyJSON
}

FileHandle.standardOutput.write(output.data(using: .utf8)!)
FileHandle.standardOutput.write("\n".data(using: .utf8)!)

exit(0)
