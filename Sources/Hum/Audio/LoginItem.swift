import ServiceManagement
import SwiftUI

/// Launch-at-login via `SMAppService` — the current API, which registers the
/// app bundle itself rather than installing a LaunchAgent plist.
///
/// Registration only works for a real bundle in a stable location, so this is
/// inert (and reports `isAvailable == false`) when running the loose binary
/// straight out of `.build` via `swift run`.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastError: String?

    /// False for a non-bundled binary, where registration would always fail.
    let isAvailable: Bool

    private let service = SMAppService.mainApp

    init() {
        // A bundled app lives inside a .app; `swift run` does not.
        isAvailable = Bundle.main.bundleURL.pathExtension == "app"
        refresh()
    }

    func refresh() {
        guard isAvailable else { return }
        let status = service.status
        isEnabled = (status == .enabled)
        // The user disabled it in System Settings; macOS will not let the app
        // silently re-enable itself, so the switch must reflect their choice.
        requiresApproval = (status == .requiresApproval)
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        lastError = nil
        do {
            if enabled {
                // Registering while already registered throws, so clear first.
                if service.status == .enabled { try? service.unregister() }
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            NSLog("Hum: login item \(enabled ? "register" : "unregister") failed — \(error)")
        }
        refresh()
    }

    /// Opens the Login Items pane, for when macOS wants explicit approval.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
