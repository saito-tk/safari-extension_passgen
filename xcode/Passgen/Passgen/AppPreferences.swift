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
    static let passwordResultPreferencesDidChange = Notification.Name("PasswordResultPreferencesDidChange")
    static let similarCharacterExclusionsDidChange = Notification.Name("SimilarCharacterExclusionsDidChange")
}

final class AppPreferences {
    static let shared = AppPreferences()

    private enum StorageKey {
        static let clipboardAutoClearEnabled = "clipboardAutoClearEnabled"
        static let clipboardAutoClearSeconds = "clipboardAutoClearSeconds"
        static let maskGeneratedPasswordsByDefault = "maskGeneratedPasswordsByDefault"
        static let similarCharacterExclusions = "similarCharacterExclusions"
    }

    static let minimumClipboardAutoClearSeconds = 5
    static let maximumClipboardAutoClearSeconds = 600

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

    var isClipboardAutoClearEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.clipboardAutoClearEnabled) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: StorageKey.clipboardAutoClearEnabled)
        }
        set {
            guard isClipboardAutoClearEnabled != newValue else {
                return
            }

            UserDefaults.standard.set(newValue, forKey: StorageKey.clipboardAutoClearEnabled)
            NotificationCenter.default.post(name: .passwordResultPreferencesDidChange, object: nil)
        }
    }

    var clipboardAutoClearSeconds: Int {
        get {
            let storedValue = UserDefaults.standard.integer(forKey: StorageKey.clipboardAutoClearSeconds)
            guard storedValue != 0 else {
                return 90
            }

            return Self.clampedClipboardAutoClearSeconds(storedValue)
        }
        set {
            let normalizedValue = Self.clampedClipboardAutoClearSeconds(newValue)
            guard clipboardAutoClearSeconds != normalizedValue else {
                return
            }

            UserDefaults.standard.set(normalizedValue, forKey: StorageKey.clipboardAutoClearSeconds)
            NotificationCenter.default.post(name: .passwordResultPreferencesDidChange, object: nil)
        }
    }

    var masksGeneratedPasswordsByDefault: Bool {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.maskGeneratedPasswordsByDefault) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: StorageKey.maskGeneratedPasswordsByDefault)
        }
        set {
            guard masksGeneratedPasswordsByDefault != newValue else {
                return
            }

            UserDefaults.standard.set(newValue, forKey: StorageKey.maskGeneratedPasswordsByDefault)
            NotificationCenter.default.post(name: .passwordResultPreferencesDidChange, object: nil)
        }
    }

    var similarCharacterExclusions: [String] {
        get {
            let storedValues = UserDefaults.standard.stringArray(forKey: StorageKey.similarCharacterExclusions)
                ?? nativeSimilarCharacterOptions
            return Self.normalizedSimilarCharacterExclusions(storedValues)
        }
        set {
            let normalizedValues = Self.normalizedSimilarCharacterExclusions(newValue)
            guard similarCharacterExclusions != normalizedValues else {
                return
            }

            UserDefaults.standard.set(normalizedValues, forKey: StorageKey.similarCharacterExclusions)
            NotificationCenter.default.post(name: .similarCharacterExclusionsDidChange, object: nil)
        }
    }

    private static func clampedClipboardAutoClearSeconds(_ value: Int) -> Int {
        min(max(value, minimumClipboardAutoClearSeconds), maximumClipboardAutoClearSeconds)
    }

    private static func normalizedSimilarCharacterExclusions(_ values: [String]) -> [String] {
        let selectedValues = Set(values)
        return nativeSimilarCharacterOptions.filter { selectedValues.contains($0) }
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
