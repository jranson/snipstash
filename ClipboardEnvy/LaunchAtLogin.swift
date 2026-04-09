//
//  LaunchAtLogin.swift
//  Clipboard Envy
//
//  Login Items integration via SMAppService (macOS 13+).
//

import Foundation
import ServiceManagement

enum LaunchAtLogin {
    /// True when the app is registered to open at login, including while waiting for the user to approve in System Settings.
    static var isSetToOpenAtLogin: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    static var needsApprovalInSystemSettings: Bool {
        if case .requiresApproval = SMAppService.mainApp.status {
            return true
        }
        return false
    }

    static func setOpenAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemLoginItemsPane() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
