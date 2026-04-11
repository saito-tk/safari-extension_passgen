//
//  AppDelegate.swift
//  Passgen
//
//  Created by Takahiro Saito on 2026/04/04.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: SettingsWindowController?
    private var appearanceObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installSettingsMenuItemIfNeeded()
        applyAppearance(AppPreferences.shared.appearanceMode)
        observeAppearanceModeChanges()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc func openSettingsWindow(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }

    private func installSettingsMenuItemIfNeeded() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else {
            return
        }

        if appMenu.items.contains(where: { $0.action == #selector(openSettingsWindow(_:)) }) {
            return
        }

        let settingsItem = NSMenuItem(
            title: "設定...",
            action: #selector(openSettingsWindow(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self

        appMenu.insertItem(settingsItem, at: 1)
        appMenu.insertItem(.separator(), at: 2)
    }

    private func observeAppearanceModeChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .appAppearanceModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let mode = notification.object as? AppAppearanceMode else {
                return
            }

            self?.applyAppearance(mode)
        }
    }

    private func applyAppearance(_ mode: AppAppearanceMode) {
        NSApp.appearance = mode.appearance
    }
}
