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

    func applicationDidFinishLaunching(_ notification: Notification) {
        installSettingsMenuItemIfNeeded()
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
}
