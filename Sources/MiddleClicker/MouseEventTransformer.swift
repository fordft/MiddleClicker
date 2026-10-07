import CoreGraphics
import Dispatch

final class MouseEventTransformer {
    private(set) var state = MiddleClickState()
    private var gestureTemplate: CGEvent?

    func process(_ event: CGEvent, fnHeld: Bool, enabled: Bool) -> CGEvent? {
        let input: MouseInput
        switch event.type {
        case .leftMouseDown: input = .leftDown
        case .leftMouseDragged: input = .leftDrag
        case .leftMouseUp: input = .leftUp
        default: input = .unrelated
        }
        let decision = state.handle(input, fnHeld: fnHeld, enabled: enabled)
        switch decision {
        case .passThrough: return event
        case .suppress: return nil
        case .middleDown: event.type = .otherMouseDown
        case .middleDrag: event.type = .otherMouseDragged
        case .middleUp: event.type = .otherMouseUp
        }
        // Mutate the original event so deltas, flags, click count, pressure, timestamp,
        // and targeting metadata survive. Rebuilding it loses relative 3D mouse movement.
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
        if decision == .middleUp { gestureTemplate = nil }
        else { gestureTemplate = event.copy() }
        return event
    }

    func cancelRelease() -> CGEvent? {
        guard state.cancel() else { return nil }
        defer { gestureTemplate = nil }
        guard let release = gestureTemplate?.copy() else { return nil }
        release.type = .otherMouseUp
        release.location = CGEvent(source: nil)?.location ?? release.location
        release.timestamp = DispatchTime.now().uptimeNanoseconds
        release.flags = CGEventSource.flagsState(.combinedSessionState)
        release.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
        release.setIntegerValueField(.mouseEventDeltaX, value: 0)
        release.setIntegerValueField(.mouseEventDeltaY, value: 0)
        release.setDoubleValueField(.mouseEventPressure, value: 0)
        return release
    }
}
