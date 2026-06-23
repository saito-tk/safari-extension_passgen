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
        window.setContentSize(NSSize(width: 390, height: 330))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAppearanceMode = AppPreferences.shared.appearanceMode
    @State private var selectedDisplayTheme = AppPreferences.shared.displayTheme
    private let displayThemeColumns = Array(repeating: GridItem(.fixed(34), spacing: 10), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("アプリテーマ")
                    .font(.system(size: 15, weight: .semibold))

                Picker("アプリテーマ", selection: $selectedAppearanceMode) {
                    Text(AppAppearanceMode.system.title).tag(AppAppearanceMode.system)
                    Text(AppAppearanceMode.light.title).tag(AppAppearanceMode.light)
                    Text(AppAppearanceMode.dark.title).tag(AppAppearanceMode.dark)
                }
                .pickerStyle(.segmented)

                Text("アプリ全体の外観を切り替えます。System は macOS の設定に追従します。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("表示テーマ")
                    .font(.system(size: 15, weight: .semibold))

                LazyVGrid(columns: displayThemeColumns, alignment: .leading, spacing: 12) {
                    ForEach(NativeTheme.allCases) { theme in
                        displayThemeButton(theme)
                    }
                }

                Text("生成画面のアクセントカラーを切り替えます。生成内容には影響しません。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: selectedAppearanceMode) { _, newValue in
            AppPreferences.shared.appearanceMode = newValue
        }
        .onChange(of: selectedDisplayTheme) { _, newValue in
            AppPreferences.shared.displayTheme = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativeDisplayThemeDidChange)) { notification in
            guard let theme = notification.object as? NativeTheme else {
                return
            }

            selectedDisplayTheme = theme
        }
    }

    private func displayThemeButton(_ theme: NativeTheme) -> some View {
        let palette = theme.palette(for: NativeThemeAppearance(colorScheme))
        let isSelected = selectedDisplayTheme == theme

        return Button {
            selectedDisplayTheme = theme
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.28 : 0.16), lineWidth: 1)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.32), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 34, height: 34)
            .overlay(
                Circle()
                    .stroke(isSelected ? palette.accentStrong : Color.clear, lineWidth: 2)
                    .frame(width: 32, height: 32)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? palette.accent.opacity(0.24) : Color.clear, lineWidth: 4)
                    .frame(width: 38, height: 38)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.displayName)
        .accessibilityLabel("表示テーマ \(theme.displayName)")
    }
}
