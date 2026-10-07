struct PhysicalFnState {
    struct Key: Hashable { let device: UInt64; let cookie: UInt32 }
    private var pressed: Set<Key> = []
    var isDown: Bool { !pressed.isEmpty }

    static func isFn(page: UInt32, usage: UInt32) -> Bool {
        // Apple's Fn usages: Top Case FF/03 and Vendor Keyboard FF01/03.
        usage == 3 && (page == 0xff || page == 0xff01)
    }

    mutating func receive(device: UInt64, cookie: UInt32, page: UInt32,
                          usage: UInt32, down: Bool, physical: Bool) {
        guard physical, Self.isFn(page: page, usage: usage) else { return }
        let key = Key(device: device, cookie: cookie)
        if down { pressed.insert(key) } else { pressed.remove(key) }
    }

    mutating func remove(device: UInt64) { pressed = pressed.filter { $0.device != device } }
    mutating func clear() { pressed.removeAll() }
}

