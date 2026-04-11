//
//  SettingsWindowController.swift
//  Passgen
//
//  Created by Codex on 2026/04/05.
//

import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 360, height: 260))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsView: View {
    @State private var selectedMode = AppPreferences.shared.presentationMode
    @State private var selectedAppearanceMode = AppPreferences.shared.appearanceMode

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("表示方式")
                    .font(.system(size: 15, weight: .semibold))

                Picker("表示方式", selection: $selectedMode) {
                    Text(AppPresentationMode.web.title).tag(AppPresentationMode.web)
                    Text(AppPresentationMode.swift.title).tag(AppPresentationMode.swift)
                }
                .pickerStyle(.segmented)

                Text("変更するとメインウィンドウの表示内容とサイズが切り替わります。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("アプリテーマ")
                    .font(.system(size: 15, weight: .semibold))

                Picker("アプリテーマ", selection: $selectedAppearanceMode) {
                    Text(AppAppearanceMode.system.title).tag(AppAppearanceMode.system)
                    Text(AppAppearanceMode.light.title).tag(AppAppearanceMode.light)
                    Text(AppAppearanceMode.dark.title).tag(AppAppearanceMode.dark)
                }
                .pickerStyle(.segmented)

                Text("Swift版アプリ全体の外観を切り替えます。System は macOS の設定に追従します。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: selectedMode) { _, newValue in
            AppPreferences.shared.presentationMode = newValue
        }
        .onChange(of: selectedAppearanceMode) { _, newValue in
            AppPreferences.shared.appearanceMode = newValue
        }
    }
}
