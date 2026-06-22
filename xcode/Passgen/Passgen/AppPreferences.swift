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
    static let nativeDisplayThemeDidChange = Notification.Name("NativeDisplayThemeDidChange")
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

    var displayTheme: NativeTheme {
        get {
            Self.restoreNativeSettings().theme
        }
        set {
            var settings = Self.restoreNativeSettings()
            guard settings.theme != newValue else {
                return
            }

            settings.theme = newValue
            Self.persistNativeSettings(settings)
            NotificationCenter.default.post(name: .nativeDisplayThemeDidChange, object: newValue)
        }
    }

    private static func restoreNativeSettings() -> NativePasswordSettings {
        guard let data = UserDefaults.standard.data(forKey: nativeSettingsStorageKey),
              let restoredSettings = try? JSONDecoder().decode(NativePasswordSettings.self, from: data) else {
            return .defaultSettings
        }

        return restoredSettings
    }

    private static func persistNativeSettings(_ settings: NativePasswordSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: nativeSettingsStorageKey)
        } catch {
            NSLog("Failed to persist display theme: %@", error.localizedDescription)
        }
    }
}
