//
//  AppPreferences.swift
//  Passgen
//
//  Created by Codex on 2026/04/05.
//

import AppKit
import Foundation

enum AppPresentationMode: Int {
    case web
    case swift

    static let storageKey = "appPresentationMode"

    var title: String {
        switch self {
        case .web:
            "Web版"
        case .swift:
            "Swift版"
        }
    }

    var preferredContentSize: NSSize {
        switch self {
        case .web:
            NSSize(width: 452, height: 760)
        case .swift:
            NSSize(width: 1380, height: 840)
        }
    }
}

extension Notification.Name {
    static let appPresentationModeDidChange = Notification.Name("AppPresentationModeDidChange")
}

final class AppPreferences {
    static let shared = AppPreferences()

    private init() {}

    var presentationMode: AppPresentationMode {
        get {
            AppPresentationMode(rawValue: UserDefaults.standard.integer(forKey: AppPresentationMode.storageKey)) ?? .web
        }
        set {
            guard presentationMode != newValue else {
                return
            }

            UserDefaults.standard.set(newValue.rawValue, forKey: AppPresentationMode.storageKey)
            NotificationCenter.default.post(name: .appPresentationModeDidChange, object: newValue)
        }
    }
}
