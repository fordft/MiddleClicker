import Foundation
import ServiceManagement

final class LoginItemController {
    private let preference = "launchAtLogin"
    private(set) var errorMessage: String?
    var status: SMAppService.Status { SMAppService.mainApp.status }
    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }
    var wantsEnabled: Bool { UserDefaults.standard.object(forKey: preference) as? Bool ?? true }

    static var isInstalled: Bool {
        let folder = Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let locations = [URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
        return locations.contains { $0.resolvingSymlinksInPath().standardizedFileURL == folder }
    }

    func configureDefault() {
        if UserDefaults.standard.object(forKey: preference) == nil {
            UserDefaults.standard.set(true, forKey: preference)
        }
        guard wantsEnabled else { return }
        guard Self.isInstalled else {
            errorMessage = "Move MiddleClicker to Applications to enable Launch at Login"
            return
        }
        // Respect a macOS refusal instead of repeatedly registering behind the user's choice.
        if status == .enabled || status == .requiresApproval { return }
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        if enabled && !Self.isInstalled {
            errorMessage = "Move MiddleClicker to Applications to enable Launch at Login"
            return
        }
        do {
            if enabled {
                if status != .enabled && status != .requiresApproval { try SMAppService.mainApp.register() }
            } else if status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: preference)
        } catch {
            errorMessage = "Could not change Launch at Login: \(error.localizedDescription)"
        }
    }
}
