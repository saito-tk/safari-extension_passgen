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
        window.setContentSize(NSSize(width: 390, height: 530))
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
    @State private var isClipboardAutoClearEnabled = AppPreferences.shared.isClipboardAutoClearEnabled
    @State private var clipboardAutoClearSeconds = AppPreferences.shared.clipboardAutoClearSeconds
    @State private var masksGeneratedPasswordsByDefault = AppPreferences.shared.masksGeneratedPasswordsByDefault
    @State private var similarCharacterExclusions = Set(AppPreferences.shared.similarCharacterExclusions)
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
                Text("パスワードの保護")
                    .font(.system(size: 15, weight: .semibold))

                Toggle("コピー後に自動削除", isOn: $isClipboardAutoClearEnabled)

                if isClipboardAutoClearEnabled {
                    Stepper(value: $clipboardAutoClearSeconds, in: AppPreferences.minimumClipboardAutoClearSeconds...AppPreferences.maximumClipboardAutoClearSeconds, step: 5) {
                        Text("\(clipboardAutoClearSeconds) 秒後に削除")
                    }
                }

                Toggle("生成後はパスワードを隠す", isOn: $masksGeneratedPasswordsByDefault)

                VStack(alignment: .leading, spacing: 6) {
                    Text("似た文字の除外対象")
                        .font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 18) {
                        similarCharacterExclusionGroup(["O", "o", "0"])
                        similarCharacterExclusionGroup(["I", "l", "1"])
                    }
                }

                Text("自動削除は、コピー後に別の内容へ置き換えられていない場合だけ実行します。")
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
        .onChange(of: isClipboardAutoClearEnabled) { _, newValue in
            AppPreferences.shared.isClipboardAutoClearEnabled = newValue
        }
        .onChange(of: clipboardAutoClearSeconds) { _, newValue in
            AppPreferences.shared.clipboardAutoClearSeconds = newValue
        }
        .onChange(of: masksGeneratedPasswordsByDefault) { _, newValue in
            AppPreferences.shared.masksGeneratedPasswordsByDefault = newValue
        }
        .onChange(of: similarCharacterExclusions) { _, newValue in
            AppPreferences.shared.similarCharacterExclusions = nativeSimilarCharacterOptions.filter { newValue.contains($0) }
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

    private func similarCharacterExclusionGroup(_ characters: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(characters, id: \.self) { character in
                Toggle(isOn: Binding(
                    get: { similarCharacterExclusions.contains(character) },
                    set: { isSelected in
                        if isSelected {
                            similarCharacterExclusions.insert(character)
                        } else {
                            similarCharacterExclusions.remove(character)
                        }
                    }
                )) {
                    Text(character)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .toggleStyle(.checkbox)
            }
        }
    }
}
