import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import IOKit.hidsystem
import ServiceManagement

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
let projectURL = URL(string: "https://github.com/fordft/MiddleClicker")!
let arguments = CommandLine.arguments
let dataDirectory = arguments.firstIndex(of: "--state-directory").flatMap { index -> URL? in
    arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1], isDirectory: true) : nil
} ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MiddleClicker", isDirectory: true)

func inputAccessGranted() -> Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }
func json(_ value: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let fnMonitor = PhysicalFnMonitor()
    let mouseTap = MouseTapController()
    let loginItem = LoginItemController()
    var item: NSStatusItem!
    var statusItem: NSMenuItem!
    var enableItem: NSMenuItem!
    var accessibilityItem: NSMenuItem!
    var inputItem: NSMenuItem!
    var loginMenuItem: NSMenuItem!
    var loginHelpItem: NSMenuItem!
    var timer: Timer?
    var signalSources: [DispatchSourceSignal] = []
    var testWindow: ClickTestWindowController?
    var enabled = !UserDefaults.standard.bool(forKey: "paused")
    var suspended = false
    var awaitFnRelease = false
    var accessible = false
    var previousStatus: String?
    var showTestAtLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem = NSMenuItem(title: "MiddleClicker", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)
        menu.addItem(.separator())
        enableItem = add("Enable MiddleClicker", action: #selector(toggleEnabled), to: menu)
        add("Test Middle Click…", action: #selector(openTestWindow), to: menu)
        menu.addItem(.separator())
        accessibilityItem = add("Open Accessibility Settings…", action: #selector(openAccessibility), to: menu)
        inputItem = add("Open Input Monitoring Settings…", action: #selector(openInputMonitoring), to: menu)
        menu.addItem(.separator())
        loginMenuItem = add("Launch at Login", action: #selector(toggleLogin), to: menu)
        loginHelpItem = add("Open Login Items Settings…", action: #selector(openLoginSettings), to: menu)
        add("Show App in Finder", action: #selector(showApp), to: menu)
        add("Project and Updates…", action: #selector(openProject), to: menu)
        menu.addItem(.separator())
        add("Quit MiddleClicker", action: #selector(quitApp), to: menu, key: "q")
        item.menu = menu

        mouseTap.fnIsHeld = { [weak self] in
            guard let self else { return false }
            return self.fnMonitor.errorMessage == nil && self.fnMonitor.isDown && !self.awaitFnRelease
        }
        fnMonitor.onChange = { [weak self] in
            guard let self else { return }
            if !self.fnMonitor.isDown { self.awaitFnRelease = false }
        }
        loginItem.configureDefault()
        log("Started version \(appVersion).")
        refresh()
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(suspend), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        for number in [SIGTERM, SIGINT, SIGHUP] {
            Darwin.signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
        if showTestAtLaunch { openTestWindow() }
        if (!accessible || !fnMonitor.permissionGranted) && !UserDefaults.standard.bool(forKey: "seenPermissionGuideV2") {
            UserDefaults.standard.set(true, forKey: "seenPermissionGuideV2")
            DispatchQueue.main.async { [weak self] in self?.permissionGuide() }
        }
    }

    @discardableResult func add(_ title: String, action: Selector, to menu: NSMenu, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        menu.addItem(entry)
        return entry
    }

    @objc func refresh() {
        accessible = AXIsProcessTrusted()
        fnMonitor.refreshAccess()
        if !fnMonitor.isDown { awaitFnRelease = false }
        mouseTap.enabled = enabled
        mouseTap.refresh(accessible: accessible, suspended: suspended)
        updateStatus()
    }

    func updateStatus() {
        guard item != nil else { return }
        let message: String
        if !enabled { message = "Paused — normal clicks pass through" }
        else if suspended { message = "Paused while your session is inactive" }
        else if !accessible { message = "Enable Accessibility for MiddleClicker" }
        else if let error = fnMonitor.errorMessage { message = error }
        else if let error = mouseTap.errorMessage { message = error }
        else if awaitFnRelease { message = "Release Fn once to resume" }
        else if mouseTap.transformer.state.middleHeld { message = "Middle-button drag active" }
        else { message = "Ready — Fn + Click or Drag" }

        let warning = !accessible || fnMonitor.errorMessage != nil || mouseTap.errorMessage != nil
        let symbol = warning ? "exclamationmark.circle" : "computermouse"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MiddleClicker")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.title = " MC"
        item.button?.toolTip = "MiddleClicker: \(message)"
        statusItem.title = message
        enableItem.state = enabled ? .on : .off
        accessibilityItem.title = accessible ? "Accessibility: Enabled — Settings…" : "Enable Accessibility…"
        inputItem.title = fnMonitor.permissionGranted ? "Input Monitoring: Enabled — Settings…" : "Enable Input Monitoring…"
        loginMenuItem.state = loginItem.isEnabled ? .on : (loginItem.needsApproval ? .mixed : .off)
        loginHelpItem.isHidden = !loginItem.needsApproval && loginItem.errorMessage == nil
        loginHelpItem.toolTip = loginItem.errorMessage
        let status: [String: Any] = ["version": appVersion, "pid": ProcessInfo.processInfo.processIdentifier,
            "enabled": enabled, "status": message, "accessibility": accessible,
            "inputMonitoring": fnMonitor.permissionGranted, "physicalFnKeyboards": fnMonitor.keyboardCount,
            "fnHeld": fnMonitor.isDown, "middleButtonHeld": mouseTap.transformer.state.middleHeld,
            "mouseTapRunning": mouseTap.isRunning, "launchAtLogin": loginItem.isEnabled,
            "loginItemNeedsApproval": loginItem.needsApproval, "loginItemError": loginItem.errorMessage ?? ""]
        if let encoded = try? json(status) { try? encoded.write(to: dataDirectory.appendingPathComponent("status.json"), options: .atomic) }
        if message != previousStatus {
            if message.contains("Could not") || message.contains("unavailable") { log(message) }
            previousStatus = message
        }
    }

    func permissionGuide() {
        let alert = NSAlert()
        alert.messageText = "Set up Fn + Middle Click"
        alert.informativeText = "Allow MiddleClicker in Accessibility so it can convert mouse clicks, and Input Monitoring so it can read the physical Fn key. Only Fn and left-click gestures are observed; typed text is not collected. If macOS asks, choose Quit & Reopen. Both settings are also available from the menu-bar icon."
        alert.addButton(withTitle: accessible ? "Open Input Monitoring" : "Open Accessibility")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if accessible { openInputMonitoring() } else { openAccessibility() }
        }
    }

    @objc func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(!enabled, forKey: "paused")
        if !enabled { mouseTap.cancelGesture() }
        mouseTap.enabled = enabled
        log(enabled ? "Enabled." : "Paused.")
        updateStatus()
    }
    @objc func suspend() {
        suspended = true
        mouseTap.stop()
        updateStatus()
    }
    @objc func resume() {
        suspended = false
        awaitFnRelease = fnMonitor.isDown
        refresh()
    }
    @objc func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("Privacy_Accessibility")
    }
    @objc func openInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openSettings("Privacy_ListenEvent")
    }
    func openSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") { NSWorkspace.shared.open(url) }
    }
    @objc func toggleLogin() {
        loginItem.setEnabled(!(loginItem.isEnabled || loginItem.needsApproval))
        if let error = loginItem.errorMessage { log(error) }
        updateStatus()
    }
    @objc func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc func openTestWindow() {
        if testWindow == nil { testWindow = ClickTestWindowController() }
        testWindow?.open()
    }
    @objc func showApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    @objc func openProject() { NSWorkspace.shared.open(projectURL) }
    @objc func quitApp() { NSApp.terminate(nil) }
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !accessible || !fnMonitor.permissionGranted { permissionGuide() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        mouseTap.stop()
        fnMonitor.stop()
        log("Stopped; released any owned middle button.")
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func log(_ message: String) {
        let file = dataDirectory.appendingPathComponent("activity.log")
        let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(message)\n".utf8)
        if let data = try? Data(contentsOf: file), data.count < 65_536,
           let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            do { try handle.seekToEnd(); try handle.write(contentsOf: line) } catch { }
        } else { try? line.write(to: file, options: .atomic) }
    }
}

do {
    if arguments.contains("--preview-test-window") {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = ClickTestWindowController()
        window.open()
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { app.terminate(nil) }
        withExtendedLifetime(window) { app.run() }
        exit(0)
    }
    if arguments.contains("--permissions") {
        print(String(decoding: try json(["accessibility": AXIsProcessTrusted(), "inputMonitoring": inputAccessGranted()]), as: UTF8.self))
        exit(0)
    }
    if arguments.contains("--status") {
        print(String(decoding: try Data(contentsOf: dataDirectory.appendingPathComponent("status.json")), as: UTF8.self))
        exit(0)
    }
    if arguments.contains("--login-item-status") || arguments.contains("--login-item-self-test") {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        if arguments.contains("--login-item-self-test") {
            guard LoginItemController.isInstalled else { throw NSError(domain: "MiddleClicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Copy the test app into Applications first."]) }
            let before = SMAppService.mainApp.status
            guard before == .notRegistered || before == .notFound else { throw NSError(domain: "MiddleClicker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Refusing to change an existing login registration."]) }
            try SMAppService.mainApp.register()
            defer { try? SMAppService.mainApp.unregister() }
            guard SMAppService.mainApp.status == .enabled else { throw NSError(domain: "MiddleClicker", code: 3, userInfo: [NSLocalizedDescriptionKey: "Login item needs macOS approval."]) }
            try SMAppService.mainApp.unregister()
            print("PASS: native login item registration and removal.")
        }
        let login = LoginItemController()
        print(String(decoding: try json(["enabled": login.isEnabled, "needsApproval": login.needsApproval,
            "installedInApplications": LoginItemController.isInstalled]), as: UTF8.self))
        exit(0)
    }
    try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
    let lock = Darwin.open(dataDirectory.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, 0o600)
    guard lock >= 0 else { throw NSError(domain: "MiddleClicker", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create the app lock."]) }
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { print("MiddleClicker is already running."); exit(0) }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    delegate.showTestAtLaunch = arguments.contains("--show-test-window")
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
} catch {
    fputs("MiddleClicker: \(error.localizedDescription)\n", stderr)
    exit(1)
}
