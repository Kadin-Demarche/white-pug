import Foundation
import ServiceManagement

/// Wraps SMAppService so the "Launch at login" toggle works without a
/// separate login-item helper binary. Only takes effect for the built
/// .app bundle (see Scripts/build-app.sh) — it's a no-op when running via
/// `swift run` since there's no stable bundle identifier to register.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Pugwire: failed to update launch-at-login setting: \(error)")
            }
        }
    }
}
