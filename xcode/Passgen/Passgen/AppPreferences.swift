//
//  AppPreferences.swift
//  Passgen
//
//  Created by Codex on 2026/04/05.
//

import AppKit
import Foundation

enum AppAppearanceMode: Int {
    case system
    case light
    case dark

    static let storageKey = "appAppearanceMode"

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }
}

extension Notification.Name {
    static let appAppearanceModeDidChange = Notification.Name("AppAppearanceModeDidChange")
}

final class AppPreferences {
    static let shared = AppPreferences()

    private init() {}

    var appearanceMode: AppAppearanceMode {
        get {
            AppAppearanceMode(rawValue: UserDefaults.standard.integer(forKey: AppAppearanceMode.storageKey)) ?? .system
        }
        set {
            guard appearanceMode != newValue else {
                return
            }

            UserDefaults.standard.set(newValue.rawValue, forKey: AppAppearanceMode.storageKey)
            NotificationCenter.default.post(name: .appAppearanceModeDidChange, object: newValue)
        }
    }
}
