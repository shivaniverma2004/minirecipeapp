//
//  AppLogger.swift
//  miniRecipe
//

import Foundation
import os

/// Unified `Logger` access; only this file imports `os` so call sites stay free of OSLog interpolation requirements.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "miniRecipe"

    private static let authLogger = Logger(subsystem: subsystem, category: "Auth")
    private static let recipeLogger = Logger(subsystem: subsystem, category: "Recipe")
    private static let profileLogger = Logger(subsystem: subsystem, category: "Profile")
    private static let notificationsLogger = Logger(subsystem: subsystem, category: "Notifications")
    private static let feedLogger = Logger(subsystem: subsystem, category: "Feed")

    static func auth(_ message: String) { authLogger.error("\(message)") }
    static func recipe(_ message: String) { recipeLogger.error("\(message)") }
    static func profile(_ message: String) { profileLogger.error("\(message)") }
    static func notifications(_ message: String) { notificationsLogger.error("\(message)") }
    static func feed(_ message: String) { feedLogger.error("\(message)") }
}
