import Foundation
import CoreGraphics
import IOKit.hid
import IOKit.hidsystem

final class PhysicalFnMonitor {
    private var manager: IOHIDManager?
    private var devices: [UInt64: String] = [:]
    private var state = PhysicalFnState()
    private(set) var permissionGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    private(set) var openError: String?
    var onChange: (() -> Void)?
    var isDown: Bool { state.isDown }
    var keyboardCount: Int { devices.count }
    var errorMessage: String? {
        if !permissionGranted { return "Enable Input Monitoring for MiddleClicker" }
        if let openError { return openError }
        if devices.isEmpty { return "No physical keyboard with a Fn key is connected" }
        return nil
    }

    static func registryID(_ device: IOHIDDevice) -> UInt64 {
        var identifier: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &identifier)
        return identifier
    }

    static func isPhysical(_ device: IOHIDDevice) -> Bool {
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        return !transport.localizedCaseInsensitiveContains("virtual")
            && !product.localizedCaseInsensitiveContains("virtual")
            && !product.localizedCaseInsensitiveContains("karabiner")
    }

    func refreshAccess() {
        let granted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if !granted {
            if manager != nil { stop() }
            permissionGranted = false
            return
        }
        permissionGranted = true
        if manager == nil { start() }
    }

    private func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        let keyboard: [String: Any] = [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 6]
        IOHIDManagerSetDeviceMatching(manager, keyboard as CFDictionary)
        let fnElements: [[String: Any]] = [0xff, 0xff01].map {
            [kIOHIDElementUsagePageKey: $0, kIOHIDElementUsageKey: 3]
        }
        // The HID queue contains only Fn values. Other keys never reach our callback.
        IOHIDManagerSetInputValueMatchingMultiple(manager, fnElements as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<PhysicalFnMonitor>.fromOpaque(context).takeUnretainedValue().receive(value)
        }, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<PhysicalFnMonitor>.fromOpaque(context).takeUnretainedValue().attach(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let monitor = Unmanaged<PhysicalFnMonitor>.fromOpaque(context).takeUnretainedValue()
            let id = PhysicalFnMonitor.registryID(device)
            monitor.devices.removeValue(forKey: id)
            monitor.state.remove(device: id)
            monitor.onChange?()
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, 0) // Shared access; never seize the keyboard.
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, 0)
            openError = "Could not read physical Fn (\(result)); reopen MiddleClicker"
            return
        }
        self.manager = manager
        openError = nil
        for device in IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? [] { attach(device) }
    }

    private func attach(_ device: IOHIDDevice) {
        guard Self.isPhysical(device) else { return }
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] ?? []
        let fnElements = elements.filter {
            PhysicalFnState.isFn(page: IOHIDElementGetUsagePage($0), usage: IOHIDElementGetUsage($0))
                && IOHIDElementGetType($0) != kIOHIDElementTypeCollection
        }
        guard !fnElements.isEmpty else { return }
        let id = Self.registryID(device)
        guard devices[id] == nil else { return }
        devices[id] = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Keyboard"
        for element in fnElements {
            let value = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
            if IOHIDDeviceGetValue(device, element, value) == kIOReturnSuccess {
                receive(value.pointee.takeUnretainedValue())
            }
            value.deallocate()
        }
        onChange?()
    }

    private func receive(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        guard Self.isPhysical(device) else { return }
        let before = state.isDown
        state.receive(device: Self.registryID(device), cookie: IOHIDElementGetCookie(element),
            page: IOHIDElementGetUsagePage(element), usage: IOHIDElementGetUsage(element),
            down: IOHIDValueGetIntegerValue(value) != 0, physical: true)
        if state.isDown != before { onChange?() }
    }

    func stop() {
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, 0)
        }
        manager = nil
        devices.removeAll()
        state.clear()
    }
}
