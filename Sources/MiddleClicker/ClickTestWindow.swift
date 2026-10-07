import AppKit

final class ClickTestView: NSView {
    private var message = "Hold Fn and click or drag here"
    private var points: [NSPoint] = []
    private var middleDown = false
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let area = bounds.insetBy(dx: 22, dy: 22)
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: area, xRadius: 18, yRadius: 18).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (message as NSString).draw(in: NSRect(x: 32, y: bounds.height - 83, width: bounds.width - 64, height: 54),
            withAttributes: [.font: NSFont.systemFont(ofSize: 19, weight: .medium),
                .foregroundColor: middleDown ? NSColor.systemPurple : NSColor.labelColor,
                .paragraphStyle: paragraph])
        ("Shift, Option, Control, and Command remain available.\nRelease the click to finish the middle-button drag." as NSString)
            .draw(in: NSRect(x: 40, y: 36, width: bounds.width - 80, height: 42),
                withAttributes: [.font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph])
        if let first = points.first {
            let line = NSBezierPath()
            line.move(to: first)
            for point in points.dropFirst() { line.line(to: point) }
            line.lineWidth = 4
            line.lineCapStyle = .round
            line.lineJoinStyle = .round
            NSColor.systemPurple.setStroke()
            line.stroke()
            NSColor.systemPurple.setFill()
            NSBezierPath(ovalIn: NSRect(x: first.x - 4, y: first.y - 4, width: 8, height: 8)).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        middleDown = false
        points = []
        message = "Left click — check Fn and permission settings"
        needsDisplay = true
    }
    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else { super.otherMouseDown(with: event); return }
        middleDown = true
        points = [convert(event.locationInWindow, from: nil)]
        message = "Middle button down — keep dragging"
        needsDisplay = true
    }
    override func otherMouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 2 else { super.otherMouseDragged(with: event); return }
        middleDown = true
        if points.count < 1_000 { points.append(convert(event.locationInWindow, from: nil)) }
        message = "Middle-button drag detected"
        needsDisplay = true
    }
    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2 else { super.otherMouseUp(with: event); return }
        middleDown = false
        message = "Middle button released — it works"
        needsDisplay = true
    }
}

final class ClickTestWindowController: NSWindowController {
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 370),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MiddleClicker — Test Middle Click"
        window.contentView = ClickTestView(frame: NSRect(x: 0, y: 0, width: 580, height: 370))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func open() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
