import Foundation
import CoreGraphics

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func event(_ type: CGEventType, flags: CGEventFlags = []) -> CGEvent {
    let source = CGEventSource(stateID: .privateState)
    guard let result = CGEvent(mouseEventSource: source, mouseType: type,
        mouseCursorPosition: CGPoint(x: 240, y: 180), mouseButton: .left) else {
        fatalError("Could not create the in-memory event fixture")
    }
    result.flags = flags
    result.timestamp = 918_237_123
    result.setIntegerValueField(.mouseEventClickState, value: 2)
    result.setIntegerValueField(.mouseEventNumber, value: 81)
    result.setIntegerValueField(.mouseEventDeltaX, value: 17)
    result.setIntegerValueField(.mouseEventDeltaY, value: -9)
    result.setIntegerValueField(.eventSourceUserData, value: 0x4242)
    result.setDoubleValueField(.mouseEventPressure, value: 0.625)
    return result
}

let modifiers: CGEventFlags = [.maskSecondaryFn, .maskShift, .maskControl, .maskAlternate, .maskCommand]
let transformer = MouseEventTransformer()
let down = event(.leftMouseDown, flags: modifiers)
let timestamp = down.timestamp
let location = down.location
let pressure = down.getDoubleValueField(.mouseEventPressure)
require(transformer.process(down, fnHeld: true, enabled: true) === down, "Return the original event without rebuilding it")
require(down.type == .otherMouseDown, "Fn + left down becomes middle down")
require(down.getIntegerValueField(.mouseEventButtonNumber) == 2, "Use the center button")
require(down.flags == modifiers, "Preserve every original modifier")
require(down.timestamp == timestamp && down.location == location, "Preserve position and timestamp")
for (field, expected) in [(CGEventField.mouseEventDeltaX, Int64(17)), (.mouseEventDeltaY, -9),
                         (.mouseEventClickState, 2), (.mouseEventNumber, 81), (.eventSourceUserData, 0x4242)] {
    require(down.getIntegerValueField(field) == expected, "Preserve event metadata \(field.rawValue)")
}
require(down.getDoubleValueField(.mouseEventPressure) == pressure, "Preserve the native pressure value")
let duplicate = event(.leftMouseDown)
require(transformer.process(duplicate, fnHeld: true, enabled: true) == nil, "Do not send duplicate middle-down events")
let unrelated = event(.mouseMoved)
require(transformer.process(unrelated, fnHeld: true, enabled: true) === unrelated, "Unrelated events must pass through during a drag")
let drag = event(.leftMouseDragged, flags: [.maskShift])
require(transformer.process(drag, fnHeld: false, enabled: true)?.type == .otherMouseDragged,
    "Releasing Fn early must keep the current middle-button drag")
require(drag.flags == .maskShift && drag.getIntegerValueField(.mouseEventDeltaX) == 17,
    "Preserve live drag modifiers and relative deltas")
let up = event(.leftMouseUp)
require(transformer.process(up, fnHeld: false, enabled: true)?.type == .otherMouseUp, "Match the middle down with a middle up")
require(!transformer.state.middleHeld, "Finish the gesture after mouse up")

let normal = event(.leftMouseDown)
require(transformer.process(normal, fnHeld: false, enabled: true)?.type == .leftMouseDown, "Normal clicks stay normal")
let disabled = event(.leftMouseDown)
require(transformer.process(disabled, fnHeld: true, enabled: false)?.type == .leftMouseDown, "Paused mode must preserve normal clicks")

_ = transformer.process(event(.leftMouseDown), fnHeld: true, enabled: true)
let release = transformer.cancelRelease()
require(release?.type == .otherMouseUp && release?.getIntegerValueField(.mouseEventButtonNumber) == 2,
    "Pausing, quitting, sleep, or tap interruption must release the owned middle button")
require(release?.getIntegerValueField(.mouseEventDeltaX) == 0 && release?.getDoubleValueField(.mouseEventPressure) == 0,
    "Cleanup release must not introduce extra movement or pressure")
require(transformer.cancelRelease() == nil, "Cleanup must not release the middle button twice")
require(transformer.process(event(.leftMouseDragged), fnHeld: true, enabled: false) == nil,
    "Swallow the remainder of an interrupted left drag")
require(transformer.process(event(.leftMouseUp), fnHeld: true, enabled: false) == nil,
    "Do not leak an orphan left up after cleanup")
require(transformer.process(event(.leftMouseDown), fnHeld: false, enabled: true)?.type == .leftMouseDown,
    "Resume normal clicks after interrupted gesture cleanup")
_ = transformer.process(event(.leftMouseDown), fnHeld: true, enabled: true)
_ = transformer.cancelRelease()
require(transformer.process(event(.leftMouseDown), fnHeld: true, enabled: true)?.type == .otherMouseDown,
    "Recover from a release missed while the event tap was disabled")
_ = transformer.process(event(.leftMouseUp), fnHeld: false, enabled: true)

var fn = PhysicalFnState()
fn.receive(device: 1, cookie: 296, page: 0xff, usage: 3, down: true, physical: true)
fn.receive(device: 99, cookie: 296, page: 0xff, usage: 3, down: false, physical: false)
require(fn.isDown, "Synthetic Fn-up must not clear the physical key")
fn.receive(device: 2, cookie: 4, page: 0xff01, usage: 3, down: true, physical: true)
fn.receive(device: 1, cookie: 296, page: 0xff, usage: 3, down: false, physical: true)
require(fn.isDown, "A second keyboard's held Fn remains active")
fn.remove(device: 2)
require(!fn.isDown, "Removing the last keyboard clears its hold")
print("PASS: middle click/drag/up, modifier and delta preservation, early Fn release, duplicate down, normal/paused clicks, interrupted gesture cleanup, tap recovery, and physical Fn.")
