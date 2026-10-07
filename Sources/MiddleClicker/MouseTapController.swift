import AppKit
import CoreGraphics

final class MouseTapController {
    let transformer = MouseEventTransformer()
    var enabled = true
    var fnIsHeld: () -> Bool = { false }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private(set) var errorMessage: String?
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func refresh(accessible: Bool, suspended: Bool) {
        guard accessible, !suspended else {
            stop()
            errorMessage = accessible ? nil : "Enable Accessibility for MiddleClicker"
            return
        }
        if tap == nil { start() }
        else if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            cancelGesture()
            CGEvent.tapEnable(tap: tap, enable: true)
            errorMessage = CGEvent.tapIsEnabled(tap: tap) ? nil : "Mouse remapping is unavailable; reopen MiddleClicker"
        }
    }

    private func start() {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<MouseTapController>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    controller.cancelGesture()
                    if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                guard let transformed = controller.transformer.process(event,
                    fnHeld: controller.fnIsHeld(), enabled: controller.enabled) else { return nil }
                return Unmanaged.passUnretained(transformed)
            }, userInfo: context) else {
            errorMessage = "Could not enable mouse remapping; check Accessibility and reopen MiddleClicker"
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            errorMessage = "Could not start mouse remapping"
            return
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        errorMessage = nil
    }

    func cancelGesture() {
        if let release = transformer.cancelRelease() { release.post(tap: .cgSessionEventTap) }
    }

    func stop() {
        cancelGesture()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
}
