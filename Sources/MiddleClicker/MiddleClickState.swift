enum MouseInput {
    case leftDown, leftDrag, leftUp, unrelated
}

enum MouseDecision: Equatable {
    case passThrough, middleDown, middleDrag, middleUp, suppress
}

struct MiddleClickState {
    private(set) var middleHeld = false
    private(set) var discardingInterruptedGesture = false

    mutating func handle(_ input: MouseInput, fnHeld: Bool, enabled: Bool) -> MouseDecision {
        switch input {
        case .leftDown:
            if middleHeld { return .suppress }
            // A fresh down proves that any missed release of an interrupted gesture is over.
            discardingInterruptedGesture = false
            if enabled && fnHeld {
                middleHeld = true
                return .middleDown
            }
            return .passThrough
        case .leftDrag:
            if middleHeld { return .middleDrag }
            return discardingInterruptedGesture ? .suppress : .passThrough
        case .leftUp:
            if middleHeld {
                middleHeld = false
                return .middleUp
            }
            if discardingInterruptedGesture {
                discardingInterruptedGesture = false
                return .suppress
            }
            return .passThrough
        case .unrelated:
            return .passThrough
        }
    }

    @discardableResult mutating func cancel() -> Bool {
        guard middleHeld else { return false }
        middleHeld = false
        discardingInterruptedGesture = true
        return true
    }
}
