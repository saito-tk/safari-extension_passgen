//
//  NativePasswordGeneratorView.swift
//  Passgen
//
//  Created by Codex on 2026/04/05.
//

import AppKit
import Combine
import Security
import SwiftUI
import UniformTypeIdentifiers

private let nativeSymbolOptions: [NativeSymbolOption] = [
    .init(label: "-", description: "ハイフン", value: "-"),
    .init(label: "_", description: "アンダーバー", value: "_"),
    .init(label: "@", description: "アット", value: "@"),
    .init(label: "/", description: "スラッシュ", value: "/"),
    .init(label: "*", description: "アスタリスク", value: "*"),
    .init(label: "+", description: "プラス", value: "+"),
    .init(label: ".", description: "ドット", value: "."),
    .init(label: ",", description: "カンマ", value: ","),
    .init(label: "!", description: "エクスクラメーション", value: "!"),
    .init(label: "?", description: "クエスチョン", value: "?"),
    .init(label: "#", description: "シャープ", value: "#"),
    .init(label: "$", description: "ドル", value: "$"),
    .init(label: "%", description: "パーセント", value: "%"),
    .init(label: "&", description: "アンド", value: "&"),
    .init(label: "(", description: "左かっこ", value: "("),
    .init(label: ")", description: "右かっこ", value: ")"),
    .init(label: "{", description: "左波かっこ", value: "{"),
    .init(label: "}", description: "右波かっこ", value: "}"),
    .init(label: "[", description: "左角かっこ", value: "["),
    .init(label: "]", description: "右角かっこ", value: "]"),
    .init(label: "~", description: "チルダ", value: "~"),
    .init(label: "|", description: "パイプ", value: "|"),
    .init(label: ":", description: "コロン", value: ":"),
    .init(label: ";", description: "セミコロン", value: ";"),
    .init(label: "\"", description: "ダブルクォート", value: "\""),
    .init(label: "'", description: "シングルクォート", value: "'"),
    .init(label: "^", description: "キャレット", value: "^"),
    .init(label: ">", description: "大なり", value: ">"),
    .init(label: "<", description: "小なり", value: "<"),
    .init(label: "=", description: "イコール", value: "=")
]

private let nativeSimilarCharacters = Set(["I", "l", "1", "O", "0", "o"])
let nativeSettingsStorageKey = "nativePassgenSettings"
private let nativePresetsStorageKey = "nativePassgenPresets"
private let nativeMinPasswordLength = 4
private let nativeMaxPasswordLength = 999_999
private let nativeMinPasswordCount = 1
private let nativeMaxPasswordCount = 1000
private let nativeMaxGeneratedCharacters = nativeMaxPasswordLength * 10
private let nativePasswordYieldInterval = 2_048
private let nativeMaxConsecutiveRunLimit = 99
private let uppercaseCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
private let lowercaseCharacters = "abcdefghijklmnopqrstuvwxyz"
private let digitCharacters = "0123456789"

struct NativePasswordGeneratorView: View {
    @StateObject var viewModel: NativePasswordGeneratorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: NativeFocusedField?
    @State private var activeCharacterTab: NativeCharacterTab = .uppercase
    @State private var presetPendingDeletion: NativePasswordPreset?
    @State private var isStrengthHelpPresented = false

    init(viewModel: NativePasswordGeneratorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let palette = viewModel.palette(for: colorScheme)

        ZStack {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let layout = NativeSwiftLayoutMetrics(
                    containerSize: proxy.size,
                    isSidebarVisible: viewModel.isSavedSettingsSidebarVisible
                )

                HStack(alignment: .top, spacing: layout.columnSpacing) {
                    if viewModel.isSavedSettingsSidebarVisible {
                        savedSettingsColumn(palette: palette)
                            .frame(width: layout.sidebarWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    centerColumn(palette: palette)
                        .frame(width: layout.centerWidth)

                    rightColumn(palette: palette)
                        .frame(width: layout.rightWidth)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(layout.outerPadding)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSavedSettingsSidebarVisible)
        .onChange(of: focusedField) { previousField, nextField in
            viewModel.handleFocusChange(from: previousField, to: nextField)
        }
        .alert(
            "プリセットを削除しますか？",
            isPresented: Binding(
                get: { presetPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        presetPendingDeletion = nil
                    }
                }
            ),
            presenting: presetPendingDeletion
        ) { preset in
            Button("削除", role: .destructive) {
                viewModel.deletePreset(id: preset.id)
                presetPendingDeletion = nil
            }

            Button("キャンセル", role: .cancel) {
                presetPendingDeletion = nil
            }
        } message: { preset in
            Text("「\(preset.name)」を削除します。この操作は元に戻せません。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativeDisplayThemeDidChange)) { notification in
            guard let theme = notification.object as? NativeTheme else {
                return
            }

            viewModel.applyDisplayTheme(theme)
        }
    }

    private func savedSettingsColumn(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                savedSettingsCard(palette: palette)
            }
        }
        .scrollIndicators(.visible)
    }

    private func centerColumn(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                heroCard(palette: palette)
                settingsCard(palette: palette)
                rulesCard(palette: palette)
            }
        }
        .scrollIndicators(.visible)
    }

    private func rightColumn(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            resultsCard(palette: palette)
        }
    }

    private func savedSettingsCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("保存済み設定")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.ink)

                Spacer(minLength: 0)

                Text("一覧")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(palette.surfaceSoft)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("現在の設定を保存")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.muted)

                TextField("プリセット名", text: $viewModel.presetNameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.panelBorder, lineWidth: 1)
                    )
                    .disabled(viewModel.isGenerating)

                Button {
                    viewModel.savePreset()
                } label: {
                    Text(viewModel.selectedPresetID == nil ? "保存" : "更新")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.canSavePreset ? Color.white : palette.disabledText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(viewModel.canSavePreset ? palette.accent : palette.disabledBackground)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSavePreset)

                StatusMessageView(status: viewModel.presetStatus, palette: palette)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.panelBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text("プリセット一覧")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.muted)

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(NativePresetSortKey.allCases) { sortKey in
                            Button(sortKey.title) {
                                viewModel.selectPresetSortKey(sortKey)
                            }
                        }
                    } label: {
                        Text(viewModel.presetSortKey.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.accentStrong)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(viewModel.isGenerating ? palette.disabledBackground : palette.accentSoft)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(viewModel.isGenerating)

                    Button {
                        viewModel.togglePresetSortDirection()
                    } label: {
                        Image(systemName: viewModel.presetSortDirection.systemImageName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.accentStrong)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(viewModel.isGenerating ? palette.disabledBackground : palette.accentSoft)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isGenerating)
                    .help(viewModel.presetSortDirection.title)
                }

                if viewModel.presets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("まだ保存済み設定はありません。")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.ink)

                        Text("名前を付けて保存すると、ここから設定を呼び出せます。")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.panelBorder, lineWidth: 1)
                    )
                } else {
                    ForEach(viewModel.sortedPresets) { preset in
                        let isSelected = viewModel.selectedPresetID == preset.id

                        HStack(spacing: 10) {
                            Button {
                                viewModel.selectPreset(id: preset.id)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(isSelected ? palette.accent : Color.clear)
                                        .frame(width: 4)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(preset.name)
                                            .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                                            .lineLimit(2)

                                        Text(viewModel.presetConditionSummary(for: preset))
                                            .font(.system(size: 11))
                                            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let metadataText = viewModel.presetMetadataText(for: preset) {
                                            Text(metadataText)
                                                .font(.system(size: 11))
                                                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isGenerating)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Menu {
                                Button("削除", role: .destructive) {
                                    presetPendingDeletion = preset
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
                                    .frame(width: 28, height: 28)
                            }
                            .menuStyle(.borderlessButton)
                            .disabled(viewModel.isGenerating)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? palette.accent.opacity(0.24) : palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? palette.accent.opacity(0.68) : palette.panelBorder, lineWidth: isSelected ? 2 : 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func heroCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.currentSettingsTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(palette.ink)

                Spacer(minLength: 0)

                Button(action: viewModel.generate) {
                    Text(viewModel.isGenerating ? "生成中..." : "生成")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.white)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .overlay(
                            Capsule()
                                .stroke(viewModel.isGenerating ? palette.accent.opacity(0.32) : .clear, lineWidth: 4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }

            HStack(spacing: 10) {
                numericFieldCard(
                    label: "文字数",
                    text: $viewModel.lengthText,
                    rangeText: viewModel.lengthInputRangeText,
                    focus: .length,
                    palette: palette
                )

                numericFieldCard(
                    label: "件数",
                    text: $viewModel.countText,
                    rangeText: viewModel.countInputRangeText,
                    focus: .count,
                    palette: palette
                )
            }

            StatusMessageView(status: viewModel.settingsStatus, palette: palette)
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func settingsCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "文字選択エディタ")

            characterTabBar(palette: palette)
            activeCharacterPanel(palette: palette)

            selectedCharactersSummary(palette: palette)
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func selectedCharactersSummary(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("現在選択中の文字")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.muted)

            VStack(alignment: .leading, spacing: 7) {
                selectedCharactersRow(title: "大文字", characters: uppercaseCharacters, selectedCharacters: selectedCharacterSet(for: .uppercase), excludedCharacters: excludedCharacterSet(for: .uppercase), palette: palette)
                selectedCharactersRow(title: "小文字", characters: lowercaseCharacters, selectedCharacters: selectedCharacterSet(for: .lowercase), excludedCharacters: excludedCharacterSet(for: .lowercase), palette: palette)
                selectedCharactersRow(title: "数字", characters: digitCharacters, selectedCharacters: selectedCharacterSet(for: .digits), excludedCharacters: excludedCharacterSet(for: .digits), palette: palette)
                selectedCharactersRow(title: "記号", characters: nativeSymbolOptions.map(\.value).joined(), selectedCharacters: selectedCharacterSet(for: .symbols), excludedCharacters: excludedCharacterSet(for: .symbols), palette: palette)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.surfaceSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.panelBorder, lineWidth: 1)
            )
        }
    }

    private func selectedCharacterSet(for tab: NativeCharacterTab) -> Set<String> {
        return Set(viewModel.selectedCharacters(for: tab))
    }

    private func excludedCharacterSet(for tab: NativeCharacterTab) -> Set<String> {
        guard viewModel.settings.excludeSimilar else {
            return []
        }

        switch tab {
        case .uppercase:
            return nativeSimilarCharacters.intersection(Set(uppercaseCharacters.map(String.init)))
        case .lowercase:
            return nativeSimilarCharacters.intersection(Set(lowercaseCharacters.map(String.init)))
        case .digits:
            return nativeSimilarCharacters.intersection(Set(digitCharacters.map(String.init)))
        case .symbols:
            return []
        }
    }

    private func characterTabBar(palette: NativeThemePalette) -> some View {
        HStack(spacing: 8) {
            ForEach(NativeCharacterTab.allCases) { tab in
                let isSelected = activeCharacterTab == tab

                Button {
                    activeCharacterTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.accentStrong : palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? palette.accent.opacity(0.14) : palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? palette.accent.opacity(0.34) : palette.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func activeCharacterPanel(palette: NativeThemePalette) -> some View {
        switch activeCharacterTab {
        case .uppercase:
            characterSelectionPanel(tab: .uppercase, title: "英字(大文字)", characters: uppercaseCharacters, palette: palette)
        case .lowercase:
            characterSelectionPanel(tab: .lowercase, title: "英字(小文字)", characters: lowercaseCharacters, palette: palette)
        case .digits:
            characterSelectionPanel(tab: .digits, title: "数字", characters: digitCharacters, palette: palette)
        case .symbols:
            symbolPanel(palette: palette)
        }
    }

    private func symbolPanel(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            selectionActionRow(tab: .symbols, title: "記号", palette: palette)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(Array(nativeSymbolOptions.enumerated()), id: \.offset) { index, symbol in
                    symbolButton(index: index, symbol: symbol, palette: palette)
                }
            }

            symbolImportRow(palette: palette)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func symbolButton(index: Int, symbol: NativeSymbolOption, palette: NativeThemePalette) -> some View {
        let isSelected = viewModel.settings.symbols[index]
        let foregroundColor = isSelected ? Color.white : (viewModel.isGenerating ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
        let borderColor = isSelected ? palette.accentStrong.opacity(0.92) : palette.panelBorder

        return Button {
            viewModel.toggleSymbol(at: index)
        } label: {
            Text(symbol.label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundView)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating)
        .help(symbol.description)
    }

    private func symbolImportRow(palette: NativeThemePalette) -> some View {
        HStack(spacing: 8) {
            TextField("記号を貼り付け", text: $viewModel.symbolImportText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .symbolImport)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.panelBorder, lineWidth: 1)
                )
                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                .disabled(viewModel.isGenerating)

            Button("反映") {
                viewModel.applyImportedSymbols()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(viewModel.canApplyImportedSymbols ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(palette.disabledBackground))
            )
            .opacity(viewModel.canApplyImportedSymbols ? 1 : 0.72)
            .disabled(!viewModel.canApplyImportedSymbols)
        }
    }

    private func characterSelectionPanel(
        tab: NativeCharacterTab,
        title: String,
        characters: String,
        palette: NativeThemePalette
    ) -> some View {
        let selectedCharacters = Set(viewModel.selectedCharacters(for: tab))

        return VStack(alignment: .leading, spacing: 10) {
            selectionActionRow(tab: tab, title: title, palette: palette)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(Array(characters.map(String.init).enumerated()), id: \.offset) { index, character in
                    characterSelectionButton(
                        tab: tab,
                        index: index,
                        character: character,
                        isSelected: selectedCharacters.contains(character),
                        palette: palette
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func selectionActionRow(tab: NativeCharacterTab, title: String, palette: NativeThemePalette) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink)

            Spacer(minLength: 0)

            Button(viewModel.isAllCharactersSelected(for: tab) ? "すべて解除" : "すべて選択") {
                viewModel.setAllCharacters(in: tab, selected: !viewModel.isAllCharactersSelected(for: tab))
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
            .disabled(viewModel.isGenerating)
        }
    }

    private func characterSelectionButton(
        tab: NativeCharacterTab,
        index: Int,
        character: String,
        isSelected: Bool,
        palette: NativeThemePalette
    ) -> some View {
        let foregroundColor = isSelected ? Color.white : (viewModel.isGenerating ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
        let borderColor = isSelected ? palette.accentStrong.opacity(0.92) : palette.panelBorder

        return Button {
            viewModel.toggleCharacter(in: tab, at: index)
        } label: {
            Text(character)
                .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundView)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating)
    }

    private func selectedCharactersRow(title: String, characters: String, selectedCharacters: Set<String>, excludedCharacters: Set<String>, palette: NativeThemePalette) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.muted)
                .frame(width: 36, alignment: .leading)

            FlowCharacterText(
                characters: characters.map(String.init),
                selectedCharacters: selectedCharacters,
                excludedCharacters: excludedCharacters,
                selectedColor: palette.ink,
                unselectedColor: palette.muted.opacity(0.42)
            )
        }
    }

    private func rulesCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "生成ルール")

            VStack(alignment: .leading, spacing: 10) {
                Text("生成方式")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.muted)

                generationModeBar(palette: palette)
                generationModeTip(palette: palette)
            }

            HStack(spacing: 10) {
                settingChip(title: "似た文字を除外する", selected: viewModel.settings.excludeSimilar, palette: palette) {
                    viewModel.toggleExcludeSimilar()
                }
                settingChip(title: "選択した文字種を必ず含める", selected: viewModel.settings.requireEachSelectedType, palette: palette, isEnabled: viewModel.usesRulePriorityMode) {
                    viewModel.toggleRequireEachSelectedType()
                }
                settingChip(title: "同じ文字を連続させない", selected: viewModel.disallowConsecutiveDuplicates, palette: palette, isEnabled: viewModel.usesRulePriorityMode) {
                    viewModel.toggleDisallowConsecutiveDuplicates()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("先頭文字の設定")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.muted)

                firstCharacterModeBar(palette: palette)

                if viewModel.settings.firstCharacterMode == .characterSet {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        firstCharacterChip(tab: .uppercase, title: "大文字", palette: palette)
                        firstCharacterChip(tab: .lowercase, title: "小文字", palette: palette)
                        firstCharacterChip(tab: .digits, title: "数字", palette: palette)
                        firstCharacterChip(tab: .symbols, title: "記号", palette: palette)
                    }
                } else {
                    TextField("例: abc_", text: Binding(
                        get: { viewModel.settings.fixedPrefix },
                        set: { viewModel.updateFixedPrefix($0) }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.panelBorder, lineWidth: 1)
                    )
                    .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                    .disabled(viewModel.isGenerating)
                }
            }
            .opacity(viewModel.usesRulePriorityMode ? 1 : 0.56)
            .disabled(!viewModel.usesRulePriorityMode || viewModel.isGenerating)
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func firstCharacterChip(tab: NativeCharacterTab, title: String, palette: NativeThemePalette) -> some View {
        let isSelected = viewModel.isFirstCharacterAllowed(for: tab)
        let foregroundColor = isSelected ? Color.white : (viewModel.isGenerating ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : palette.surfaceStrong)
        let borderColor = isSelected ? palette.accentStrong.opacity(0.92) : palette.panelBorder

        return Button {
            viewModel.toggleFirstCharacterAllowed(for: tab)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundView)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating)
    }

    private func firstCharacterModeBar(palette: NativeThemePalette) -> some View {
        HStack(spacing: 8) {
            ForEach(NativeFirstCharacterMode.allCases) { mode in
                let isSelected = viewModel.settings.firstCharacterMode == mode

                Button {
                    viewModel.selectFirstCharacterMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.accentStrong : palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? palette.accent.opacity(0.14) : palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? palette.accent.opacity(0.34) : palette.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
        }
    }

    private func generationModeBar(palette: NativeThemePalette) -> some View {
        HStack(spacing: 8) {
            ForEach(NativeGenerationMode.allCases) { mode in
                let isSelected = viewModel.settings.generationMode == mode

                Button {
                    viewModel.selectGenerationMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.accentStrong : palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? palette.accent.opacity(0.14) : palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? palette.accent.opacity(0.34) : palette.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
        }
    }

    private func generationModeTip(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tips")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.muted)

            Text(viewModel.settings.generationMode.tip)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func resultsCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("生成結果")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(palette.ink)

                        Text(viewModel.progressText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.accentStrong)

                        Button {
                            isStrengthHelpPresented.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.accentStrong)
                                .frame(width: 24, height: 24)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("強度評価の説明")
                        .popover(isPresented: $isStrengthHelpPresented, arrowEdge: .top) {
                            strengthHelpPopover(palette: palette)
                        }
                    }

                    Text("コピーボタンでクリップボードへ保存")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.muted)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.exportResultsAsText()
                } label: {
                    Label("テキスト出力", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.canExportResults ? palette.accentStrong : palette.disabledText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.canExportResults ? palette.accentSoft : palette.disabledBackground)
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canExportResults)
            }

            StatusMessageView(status: viewModel.resultStatus, palette: palette)

            if viewModel.results.isEmpty {
                Spacer(minLength: 0)

                Text("まだ結果がありません。設定を調整して生成してください。")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 0)
            } else {
                if viewModel.hasTruncatedResults {
                    truncatedResultsNotice(palette: palette)
                }

                if let resultMetadata = viewModel.resultMetadata {
                    resultMetadataSummary(resultMetadata, palette: palette)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.results) { password in
                            NativePasswordRow(password: password, palette: palette) {
                                viewModel.copyPassword(id: password.id)
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }
                .scrollIndicators(.visible)
            }
        }
        .padding(18)
        .nativeCardStyle(palette: palette)
    }

    private func resultMetadataSummary(_ metadata: NativePasswordResultMetadata, palette: NativeThemePalette) -> some View {
        HStack(spacing: 6) {
            resultMetadataChip("推定エントロピー: \(formatNumber(metadata.entropy)) bits", palette: palette)
                .help("固定文字を除いた生成条件全体で共通の推定エントロピー")
            resultMetadataChip(metadata.conditionSummary, palette: palette)
                .help("生成に使える文字セット数と文字カテゴリ数")
            Spacer(minLength: 0)
        }
    }

    private func resultMetadataChip(_ text: String, palette: NativeThemePalette) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(palette.surfaceStrong)
            )
            .overlay(
                Capsule()
                    .stroke(palette.panelBorder, lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    private func strengthHelpPopover(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("強度評価について")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)

                strengthHelpSection(
                    title: "結果行の読み方",
                    rows: [
                        ("総合", "このパスワードを全体として見た評価です。長さと総当たり耐性を中心に、注意点があれば評価を下げます。"),
                        ("長さ", "文字数の評価です。15文字以上をひとつの目安にし、24文字以上を最高評価にします。"),
                        ("総当たり耐性", "すべての候補を順番に試されたときの破られにくさです。先頭に固定した文字など、あらかじめ分かる文字は計算から外します。"),
                        ("推定エントロピー", "総当たり耐性を数値にしたものです。数値が大きいほど、試す候補が多くなります。"),
                        ("条件", "生成に使える文字の数と種類です。同じ生成条件では全件共通なので、一覧の上側にだけ表示します。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "グレードの意味",
                    rows: [
                        ("S", "十分強く、通常の用途ではそのまま使いやすい状態です。"),
                        ("A", "強い状態です。特に重要な用途では、もう少し長くすると余裕が出ます。"),
                        ("B", "最低目安は超えていますが、重要な用途では改善余地があります。"),
                        ("C", "最低目安に近い状態です。重要な用途では長くして再生成してください。"),
                        ("D/F", "短い、破られやすい、または危険な特徴があります。使用を避けて再生成してください。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "警告の扱い",
                    rows: [
                        ("既知リスク", "よく使われる言葉や弱いパスワードの形に近いかを、アプリ内の簡易リストで確認します。"),
                        ("推測パターン", "連番、キーボード配列、日付、繰り返しなど、他人が試しやすい並びを確認します。"),
                        ("補助メッセージ", "問題や改善余地がある場合だけ表示します。何も出ない場合は、目立つ注意点が見つからなかった状態です。")
                    ],
                    palette: palette
                )

                Text("判定は目安です。漏洩データベースへのオンライン照合は行いません。コピーとテキスト出力には省略前の全文字列を使います。")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(width: 460, height: 500, alignment: .leading)
        .background(palette.surface)
    }

    private func truncatedResultsNotice(palette: NativeThemePalette) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentStrong)

            Text("一覧表示は各パスワード先頭 \(formatNumber(100)) 文字までです。コピーとテキスト出力は全文字列を使用します。")
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.surfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func strengthHelpSection(title: String, rows: [(String, String)], palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.ink)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                strengthHelpRow(title: row.0, detail: row.1, palette: palette)
            }
        }
    }

    private func strengthHelpRow(title: String, detail: String, palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentStrong)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func numericFieldCard(label: String, text: Binding<String>, rangeText: String, focus: NativeFocusedField, palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)

                Spacer(minLength: 4)

                Text(rangeText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.muted.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            TextField("", text: normalizedNumericBinding(text))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: focus)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                .disabled(viewModel.isGenerating)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(viewModel.isGenerating ? palette.disabledBackground : palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func normalizedNumericBinding(_ text: Binding<String>) -> Binding<String> {
        Binding(
            get: {
                text.wrappedValue
            },
            set: { newValue in
                text.wrappedValue = normalizeFullWidthDigits(newValue)
            }
        )
    }

    private func settingChip(
        title: String,
        selected: Bool,
        palette: NativeThemePalette,
        isEnabled: Bool = true,
        fullWidth: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? palette.accentStrong : (viewModel.isGenerating ? palette.disabledText : palette.ink))
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 42, alignment: compact ? .center : .leading)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selected ? palette.accent.opacity(0.14) : (viewModel.isGenerating ? palette.disabledBackground : palette.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? palette.accent.opacity(0.32) : palette.panelBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating || !isEnabled)
        .opacity(isEnabled ? 1 : 0.56)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .fixedSize(horizontal: compact, vertical: false)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
    }

}

private struct NativeSwiftLayoutMetrics {
    let outerPadding: CGFloat = 18
    let columnSpacing: CGFloat = 16
    let sidebarWidth: CGFloat
    let centerWidth: CGFloat
    let rightWidth: CGFloat

    init(containerSize: CGSize, isSidebarVisible: Bool) {
        let visibleSpacingCount: CGFloat = isSidebarVisible ? 2 : 1
        let baseSidebarWidth = min(max(containerSize.width * 0.18, 244), 280)
        let resolvedSidebarWidth = isSidebarVisible ? baseSidebarWidth : 0
        let usableWidth = max(containerSize.width - (outerPadding * 2) - (columnSpacing * visibleSpacingCount) - resolvedSidebarWidth, 0)
        let proposedCenterWidth = usableWidth * 0.57
        let minimumCenterWidth: CGFloat = 520
        let minimumRightWidth: CGFloat = 360
        let resolvedCenterWidth = min(
            max(proposedCenterWidth, minimumCenterWidth),
            max(usableWidth - minimumRightWidth, minimumCenterWidth)
        )

        sidebarWidth = resolvedSidebarWidth
        centerWidth = resolvedCenterWidth
        rightWidth = max(usableWidth - resolvedCenterWidth, minimumRightWidth)
    }
}

@MainActor
final class NativePasswordGeneratorViewModel: ObservableObject {
    @Published var settings: NativePasswordSettings

    @Published var lengthText: String {
        didSet {
            clearNumericCorrectionWarningIfNeeded(previousText: oldValue, currentText: lengthText)
        }
    }

    @Published var countText: String {
        didSet {
            clearNumericCorrectionWarningIfNeeded(previousText: oldValue, currentText: countText)
        }
    }
    @Published var symbolImportText = ""
    @Published var settingsStatus = NativeInlineStatus()
    @Published var resultStatus = NativeInlineStatus()
    @Published var results: [NativeGeneratedPasswordListItem] = []
    @Published var progressCompleted = 0
    @Published var progressTotal = 0
    @Published var isGenerating = false
    @Published var isSavedSettingsSidebarVisible = true
    @Published var presetNameText = ""
    @Published var presetStatus = NativeInlineStatus()
    @Published var presets: [NativePasswordPreset] = []
    @Published var selectedPresetID: String?
    @Published var presetSortKey: NativePresetSortKey = .name
    @Published var presetSortDirection: NativePresetSortDirection = .ascending

    private var generationTask: Task<Void, Never>?
    private var isRestoringSettings = true
    private var generatedPasswordStore: [UUID: String] = [:]
    private var currentGenerationSession: NativeGenerationSession?
    private var settingsBeforePresetSelection: NativePasswordSettings?

    var lengthInputRangeText: String {
        formatCountRange(nativeMinPasswordLength, nativeMaxPasswordLength)
    }

    var countInputRangeText: String {
        formatCountRange(nativeMinPasswordCount, Self.getMaxCountForLength(settings.length))
    }

    init() {
        let restoredSettings = Self.restoreSettings()
        settings = restoredSettings
        lengthText = String(restoredSettings.length)
        countText = String(restoredSettings.count)
        presets = Self.restorePresets()
        syncCategorySelectionFlags()
        syncSelectAllState()
        isRestoringSettings = false
    }

    deinit {
        generationTask?.cancel()
    }

    func palette(for colorScheme: ColorScheme) -> NativeThemePalette {
        settings.theme.palette(for: NativeThemeAppearance(colorScheme))
    }

    var canApplyImportedSymbols: Bool {
        !symbolImportText.isEmpty && !isGenerating
    }

    var canSavePreset: Bool {
        guard !isGenerating else {
            return false
        }

        let name = Self.sanitizePresetName(presetNameText)
        guard !name.isEmpty else {
            return false
        }

        guard let selectedPreset else {
            return true
        }

        return name != selectedPreset.name || NativePasswordPresetSettings(settings: settings) != selectedPreset.settings
    }

    var currentSettingsTitle: String {
        selectedPreset?.name ?? "未保存の設定"
    }

    var usesRulePriorityMode: Bool {
        settings.generationMode == .rulePriority
    }

    var progressText: String {
        "(\(progressCompleted)/\(progressTotal))"
    }

    var canExportResults: Bool {
        !results.isEmpty && !isGenerating
    }

    var hasTruncatedResults: Bool {
        results.contains { $0.isTruncated }
    }

    var resultMetadata: NativePasswordResultMetadata? {
        results.first.map {
            NativePasswordResultMetadata(
                entropy: $0.analysis.entropy,
                conditionSummary: $0.analysis.conditionSummary
            )
        }
    }

    var sortedPresets: [NativePasswordPreset] {
        presets.sorted { firstPreset, secondPreset in
            let comparison: ComparisonResult

            switch presetSortKey {
            case .name:
                comparison = Self.comparePresetNames(firstPreset, secondPreset)
            case .createdAt:
                comparison = Self.comparePresetDates(firstPreset.createdAt, secondPreset.createdAt, firstPreset: firstPreset, secondPreset: secondPreset)
            case .updatedAt:
                comparison = Self.comparePresetDates(firstPreset.updatedAt, secondPreset.updatedAt, firstPreset: firstPreset, secondPreset: secondPreset)
            }

            switch comparison {
            case .orderedAscending:
                return presetSortDirection == .ascending
            case .orderedDescending:
                return presetSortDirection == .descending
            case .orderedSame:
                return false
            }
        }
    }

    private var selectedPreset: NativePasswordPreset? {
        guard let selectedPresetID else {
            return nil
        }

        return presets.first { $0.id == selectedPresetID }
    }

    func toggleSavedSettingsSidebar() {
        isSavedSettingsSidebarVisible.toggle()
    }

    func selectPresetSortKey(_ sortKey: NativePresetSortKey) {
        presetSortKey = sortKey
    }

    func togglePresetSortDirection() {
        presetSortDirection = presetSortDirection == .ascending ? .descending : .ascending
    }

    func savePreset() {
        guard !isGenerating else {
            return
        }

        let name = Self.sanitizePresetName(presetNameText)
        guard !name.isEmpty else {
            presetStatus = NativeInlineStatus(message: "プリセット名を入力してください。", tone: .error)
            return
        }

        let now = Date()
        let snapshot = NativePasswordPresetSettings(settings: settings)

        if let selectedPresetID,
           let selectedIndex = presets.firstIndex(where: { $0.id == selectedPresetID }) {
            let selectedPreset = presets[selectedIndex]
            let updatedPreset = NativePasswordPreset(
                id: selectedPreset.id,
                name: name,
                createdAt: selectedPreset.createdAt,
                updatedAt: now,
                settings: snapshot
            )
            presets[selectedIndex] = updatedPreset
            self.selectedPresetID = updatedPreset.id
            presetStatus = NativeInlineStatus(message: "選択中のプリセットを更新しました。")
        } else if let existingIndex = presets.firstIndex(where: { $0.name == name }) {
            let existingPreset = presets[existingIndex]
            let updatedPreset = NativePasswordPreset(
                id: existingPreset.id,
                name: name,
                createdAt: existingPreset.createdAt,
                updatedAt: now,
                settings: snapshot
            )
            presets[existingIndex] = updatedPreset
            selectedPresetID = updatedPreset.id
            settingsBeforePresetSelection = settings
            presetStatus = NativeInlineStatus(message: "既存のプリセットを更新しました。")
        } else {
            let preset = NativePasswordPreset(
                id: UUID().uuidString,
                name: name,
                createdAt: now,
                updatedAt: now,
                settings: snapshot
            )
            presets.insert(preset, at: 0)
            selectedPresetID = preset.id
            settingsBeforePresetSelection = settings
            presetStatus = NativeInlineStatus(message: "プリセットを保存しました。")
        }

        presetNameText = name
        persistPresets()
    }

    func selectPreset(id: String) {
        guard !isGenerating, let preset = presets.first(where: { $0.id == id }) else {
            return
        }

        if selectedPresetID == preset.id {
            deselectPreset()
            return
        }

        if selectedPresetID == nil {
            settingsBeforePresetSelection = settings
        }

        applySettings(preset.settings.applying(to: settings))
        selectedPresetID = preset.id
        presetNameText = preset.name
        presetStatus = NativeInlineStatus(message: "プリセットを反映しました。")
    }

    func presetMetadataText(for preset: NativePasswordPreset) -> String? {
        switch presetSortKey {
        case .name:
            return nil
        case .createdAt:
            return "作成日 \(Self.formatPresetDate(preset.createdAt))"
        case .updatedAt:
            return "更新日 \(Self.formatPresetDate(preset.updatedAt))"
        }
    }

    func presetConditionSummary(for preset: NativePasswordPreset) -> String {
        Self.conditionSummary(for: preset.settings.applying(to: NativePasswordSettings.defaultSettings))
    }

    func deletePreset(id: String) {
        guard !isGenerating, let deletedIndex = presets.firstIndex(where: { $0.id == id }) else {
            return
        }

        let deletedName = presets[deletedIndex].name
        presets.remove(at: deletedIndex)
        selectedPresetID = nil
        presetNameText = ""
        settingsBeforePresetSelection = nil
        persistPresets()
        presetStatus = NativeInlineStatus(message: "「\(deletedName)」を削除しました。")
    }

    private func deselectPreset() {
        if let settingsBeforePresetSelection {
            applySettings(settingsBeforePresetSelection)
        }

        selectedPresetID = nil
        presetNameText = ""
        self.settingsBeforePresetSelection = nil
        presetStatus = NativeInlineStatus(message: "プリセットの選択を解除しました。")
    }

    private func applySettings(_ newSettings: NativePasswordSettings) {
        settings = Self.normalizedSettings(from: newSettings)
        lengthText = String(settings.length)
        countText = String(settings.count)
        syncCategorySelectionFlags()
        syncSelectAllState()
        persistSettings()
    }

    func selectedCharacters(for tab: NativeCharacterTab) -> [String] {
        switch tab {
        case .uppercase:
            return Self.selectedCharacters(from: uppercaseCharacters, selections: settings.uppercaseSelections)
        case .lowercase:
            return Self.selectedCharacters(from: lowercaseCharacters, selections: settings.lowercaseSelections)
        case .digits:
            return Self.selectedCharacters(from: digitCharacters, selections: settings.digitSelections)
        case .symbols:
            return Self.selectedCharacters(from: nativeSymbolOptions.map(\.value).joined(), selections: settings.symbols)
        }
    }

    func isAllCharactersSelected(for tab: NativeCharacterTab) -> Bool {
        let selections: [Bool]

        switch tab {
        case .uppercase:
            selections = settings.uppercaseSelections
        case .lowercase:
            selections = settings.lowercaseSelections
        case .digits:
            selections = settings.digitSelections
        case .symbols:
            selections = settings.symbols
        }

        return selections.contains(true) && selections.allSatisfy(\.self)
    }

    func handleFocusChange(from previousField: NativeFocusedField?, to nextField: NativeFocusedField?) {
        guard previousField != nextField else {
            return
        }

        switch previousField {
        case .length:
            normalizeNumericInputs(source: .length)
        case .count:
            normalizeNumericInputs(source: .count)
        case .symbolImport, .none:
            break
        }
    }

    func isFirstCharacterAllowed(for tab: NativeCharacterTab) -> Bool {
        switch tab {
        case .uppercase:
            return settings.allowUppercaseFirst
        case .lowercase:
            return settings.allowLowercaseFirst
        case .digits:
            return settings.allowDigitsFirst
        case .symbols:
            return settings.allowSymbolsFirst
        }
    }

    func toggleFirstCharacterAllowed(for tab: NativeCharacterTab) {
        switch tab {
        case .uppercase:
            settings.allowUppercaseFirst.toggle()
        case .lowercase:
            settings.allowLowercaseFirst.toggle()
        case .digits:
            settings.allowDigitsFirst.toggle()
        case .symbols:
            settings.allowSymbolsFirst.toggle()
        }

        persistSettings()
    }

    func selectFirstCharacterMode(_ mode: NativeFirstCharacterMode) {
        settings.firstCharacterMode = mode
        persistSettings()
    }

    func selectGenerationMode(_ mode: NativeGenerationMode) {
        settings.generationMode = mode
        persistSettings()
    }

    func toggleExcludeSimilar() {
        settings.excludeSimilar.toggle()
        persistSettings()
    }

    func toggleRequireEachSelectedType() {
        settings.requireEachSelectedType.toggle()
        persistSettings()
    }

    var disallowConsecutiveDuplicates: Bool {
        settings.maxConsecutiveRun == 1
    }

    func toggleDisallowConsecutiveDuplicates() {
        settings.maxConsecutiveRun = settings.maxConsecutiveRun == 1 ? 0 : 1
        persistSettings()
    }

    func updateFixedPrefix(_ value: String) {
        settings.fixedPrefix = Self.sanitizeSingleLineText(value)
        persistSettings()
    }

    func applyDisplayTheme(_ theme: NativeTheme) {
        guard settings.theme != theme else {
            return
        }

        settings.theme = theme
        persistSettings()
    }

    func setAllCharacters(in tab: NativeCharacterTab, selected: Bool) {
        switch tab {
        case .uppercase:
            settings.uppercaseSelections = Array(repeating: selected, count: uppercaseCharacters.count)
        case .lowercase:
            settings.lowercaseSelections = Array(repeating: selected, count: lowercaseCharacters.count)
        case .digits:
            settings.digitSelections = Array(repeating: selected, count: digitCharacters.count)
        case .symbols:
            settings.symbols = Array(repeating: selected, count: nativeSymbolOptions.count)
            syncSelectAllState()
        }

        syncCategorySelectionFlags()
        persistSettings()
    }

    func toggleCharacter(in tab: NativeCharacterTab, at index: Int) {
        switch tab {
        case .uppercase:
            guard settings.uppercaseSelections.indices.contains(index) else { return }
            settings.uppercaseSelections[index].toggle()
        case .lowercase:
            guard settings.lowercaseSelections.indices.contains(index) else { return }
            settings.lowercaseSelections[index].toggle()
        case .digits:
            guard settings.digitSelections.indices.contains(index) else { return }
            settings.digitSelections[index].toggle()
        case .symbols:
            toggleSymbol(at: index)
            return
        }

        syncCategorySelectionFlags()
        persistSettings()
    }

    func toggleSymbol(at index: Int) {
        guard settings.symbols.indices.contains(index) else {
            return
        }

        settings.symbols[index].toggle()
        syncSelectAllState()
        syncCategorySelectionFlags()
        persistSettings()
    }

    func setAllSymbols(selected: Bool) {
        settings.symbols = Array(repeating: selected, count: nativeSymbolOptions.count)
        syncSelectAllState()
        syncCategorySelectionFlags()
        persistSettings()
    }

    func applyImportedSymbols() {
        let importedValue = symbolImportText
        guard !importedValue.isEmpty else {
            return
        }

        let importedCharacters = Set(importedValue.map(String.init))
        let hasSupportedSymbol = nativeSymbolOptions.contains { importedCharacters.contains($0.value) }

        guard hasSupportedSymbol else {
            symbolImportText = ""
            return
        }

        settings.symbols = nativeSymbolOptions.map { importedCharacters.contains($0.value) }
        syncSelectAllState()
        syncCategorySelectionFlags()
        persistSettings()
        symbolImportText = ""
    }

    func generate() {
        normalizeNumericInputs(source: nil)
        resultStatus = NativeInlineStatus()
        settingsStatus = NativeInlineStatus()

        if let validationMessage = validateSettings() {
            settingsStatus = NativeInlineStatus(message: validationMessage, tone: .error)
            resultStatus = NativeInlineStatus()
            results = []
            generatedPasswordStore = [:]
            currentGenerationSession = nil
            progressCompleted = 0
            progressTotal = 0
            return
        }

        generationTask?.cancel()
        results = []
        generatedPasswordStore = [:]
        currentGenerationSession = NativeGenerationSession()
        progressCompleted = 0
        progressTotal = settings.count
        isGenerating = true

        let snapshot = settings

        generationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                return
            }

            do {
                for index in 0..<snapshot.count {
                    try Task.checkCancellation()
                    let password = try await Self.createPassword(using: snapshot)
                    let listItem = NativeGeneratedPasswordListItem(password: password)

                    await MainActor.run {
                        self.results.append(listItem)
                        self.generatedPasswordStore[listItem.id] = password.value
                        self.progressCompleted = index + 1
                    }

                    if index < snapshot.count - 1 {
                        await Task.yield()
                    }
                }

                await MainActor.run {
                    self.isGenerating = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isGenerating = false
                    self.generatedPasswordStore = [:]
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.generatedPasswordStore = [:]
                    self.resultStatus = NativeInlineStatus(message: "条件に合うパスワードを生成できませんでした。", tone: .error)
                }
            }
        }
    }

    func copyPassword(id: UUID) {
        guard let value = generatedPasswordStore[id] else {
            return
        }

        copyToPasteboard(value)
    }

    func exportResultsAsText() {
        guard canExportResults else {
            return
        }

        let text = results.compactMap { generatedPasswordStore[$0.id] }.joined(separator: "\n")
        guard !text.isEmpty else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = defaultTextExportFilename()
        savePanel.title = "生成結果を書き出す"
        savePanel.message = "生成したすべてのパスワードをテキストファイルとして保存します。"

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else {
            return
        }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            resultStatus = NativeInlineStatus(message: "生成したすべてのパスワードをテキスト出力しました。")
        } catch {
            resultStatus = NativeInlineStatus(message: "テキスト出力に失敗しました。保存先を確認してください。", tone: .error)
        }
    }

    private func defaultTextExportFilename() -> String {
        let session = currentGenerationSession ?? NativeGenerationSession()
        return "passgen-\(Self.formatGenerationTimestamp(session.createdAt))-\(session.shortID).txt"
    }

    private func validateSettings() -> String? {
        if !settings.uppercase && !settings.lowercase && !settings.digits && !settings.includeSymbols {
            return "使える文字がありません。設定を見直してください。"
        }

        if settings.includeSymbols && !settings.symbols.contains(true) {
            return "使える文字がありません。設定を見直してください。"
        }

        let pools = Self.buildPools(using: settings)
        if pools.isEmpty {
            return "選択した条件で使える文字がありません。設定を見直してください。"
        }

        if settings.generationMode == .completeUniform {
            return nil
        }

        let activePoolIDs = Set(pools.map(\.id))
        if settings.requireEachSelectedType {
            let remainingSlots: Int
            let coveredPoolIDs: Set<String>

            switch settings.firstCharacterMode {
            case .characterSet:
                remainingSlots = settings.length
                coveredPoolIDs = []
            case .fixedPrefix:
                let prefixCharacters = settings.fixedPrefix.map(String.init)
                remainingSlots = settings.length - prefixCharacters.count
                coveredPoolIDs = Set(prefixCharacters.compactMap { Self.poolID(for: $0, in: pools) })
            }

            let requiredAdditionalPoolCount = activePoolIDs.subtracting(coveredPoolIDs).count
            if remainingSlots < requiredAdditionalPoolCount {
                return "現在の文字数では、選択した文字種をすべて含められません。"
            }
        }

        switch settings.firstCharacterMode {
        case .characterSet:
            let allowedFirstPoolIDs = Self.allowedFirstPoolIDs(using: settings).intersection(activePoolIDs)
            if allowedFirstPoolIDs.isEmpty {
                return "先頭に使える文字がありません。設定を見直してください。"
            }
        case .fixedPrefix:
            let prefixCharacters = settings.fixedPrefix.map(String.init)
            if prefixCharacters.count >= settings.length {
                return "先頭に固定する文字は \(formatNumber(max(1, settings.length - 1))) 文字までにしてください。"
            }

            if !prefixCharacters.isEmpty {
                let availableCharacters = Set(Self.combinePools(pools))
                if prefixCharacters.contains(where: { !availableCharacters.contains($0) }) {
                    return "先頭に固定する文字に、現在の設定では使えない文字が含まれています。"
                }
            }

            if settings.maxConsecutiveRun > 0 {
                let longestPrefixRun = Self.longestTrailingRun(in: prefixCharacters)
                if longestPrefixRun > settings.maxConsecutiveRun {
                    return "先頭に固定する文字が、同一文字の最大連続数を超えています。"
                }
            }
        }

        let combinedCharacters = Self.combinePools(pools)
        if settings.maxConsecutiveRun > 0 && combinedCharacters.count < 2 && settings.length > settings.maxConsecutiveRun {
            return "同一文字の最大連続数では条件を満たせません。"
        }

        return nil
    }

    private func normalizeNumericInputs(source: NativeFocusedField?) {
        let rawLength = Self.sanitizeNumber(lengthText, fallback: settings.length)
        let normalizedLength = Self.clampNumber(rawLength, minimum: nativeMinPasswordLength, maximum: nativeMaxPasswordLength)
        let maxCountForLength = Self.getMaxCountForLength(normalizedLength)
        let rawCount = Self.sanitizeNumber(countText, fallback: settings.count)
        let normalizedCount = Self.clampNumber(rawCount, minimum: nativeMinPasswordCount, maximum: maxCountForLength)
        let lengthAdjusted = rawLength != normalizedLength
        let countAdjusted = rawCount != normalizedCount
        let derivedCountAdjusted = maxCountForLength < rawCount && (source == .length || source == nil)

        settings.length = normalizedLength
        settings.count = normalizedCount
        lengthText = String(normalizedLength)
        countText = String(normalizedCount)
        persistSettings()

        if lengthAdjusted && (source == .length || source == nil) {
            settingsStatus = NativeInlineStatus(message: Self.lengthCorrectionMessage(normalizedLength), tone: .warning)
        }

        if countAdjusted && (source == .count || source == nil) {
            settingsStatus = NativeInlineStatus(message: Self.countCorrectionMessage(normalizedCount, maxCountForLength), tone: .warning)
            return
        }

        if derivedCountAdjusted {
            settingsStatus = NativeInlineStatus(message: Self.countCorrectionMessage(normalizedCount, maxCountForLength), tone: .warning)
        }
    }

    private func clearNumericCorrectionWarningIfNeeded(previousText: String, currentText: String) {
        guard previousText != currentText, settingsStatus.tone == .warning else {
            return
        }

        settingsStatus = NativeInlineStatus()
    }

    private func syncSelectAllState() {
        settings.selectAllSymbols = settings.symbols.contains(true) && settings.symbols.allSatisfy(\.self)
    }

    private func syncCategorySelectionFlags() {
        settings.uppercase = settings.uppercaseSelections.contains(true)
        settings.lowercase = settings.lowercaseSelections.contains(true)
        settings.digits = settings.digitSelections.contains(true)
        settings.includeSymbols = settings.symbols.contains(true)

    }

    private func persistSettings() {
        guard !isRestoringSettings else {
            return
        }

        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: nativeSettingsStorageKey)
        } catch {
            NSLog("Failed to persist native settings: %@", error.localizedDescription)
        }
    }

    private func persistPresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: nativePresetsStorageKey)
        } catch {
            presetStatus = NativeInlineStatus(message: "プリセットの保存に失敗しました。", tone: .error)
            NSLog("Failed to persist native presets: %@", error.localizedDescription)
        }
    }

    private static func restoreSettings() -> NativePasswordSettings {
        guard let data = UserDefaults.standard.data(forKey: nativeSettingsStorageKey),
              let restoredSettings = try? JSONDecoder().decode(NativePasswordSettings.self, from: data) else {
            return .defaultSettings
        }

        return normalizedSettings(from: restoredSettings)
    }

    private static func restorePresets() -> [NativePasswordPreset] {
        guard let data = UserDefaults.standard.data(forKey: nativePresetsStorageKey),
              let restoredPresets = try? JSONDecoder().decode([NativePasswordPreset].self, from: data) else {
            return []
        }

        return restoredPresets
    }

    private static func normalizedSettings(from settings: NativePasswordSettings) -> NativePasswordSettings {
        let restoredSettings = settings
        var normalizedSettings = restoredSettings
        normalizedSettings.length = clampNumber(restoredSettings.length, minimum: nativeMinPasswordLength, maximum: nativeMaxPasswordLength)
        normalizedSettings.count = clampNumber(restoredSettings.count, minimum: nativeMinPasswordCount, maximum: getMaxCountForLength(normalizedSettings.length))
        normalizedSettings.minimumUppercase = clampNumber(restoredSettings.minimumUppercase, minimum: 0, maximum: normalizedSettings.length)
        normalizedSettings.minimumLowercase = clampNumber(restoredSettings.minimumLowercase, minimum: 0, maximum: normalizedSettings.length)
        normalizedSettings.minimumDigits = clampNumber(restoredSettings.minimumDigits, minimum: 0, maximum: normalizedSettings.length)
        normalizedSettings.minimumSymbols = clampNumber(restoredSettings.minimumSymbols, minimum: 0, maximum: normalizedSettings.length)
        normalizedSettings.maxConsecutiveRun = clampNumber(restoredSettings.maxConsecutiveRun, minimum: 0, maximum: nativeMaxConsecutiveRunLimit)

        if normalizedSettings.symbols.count != nativeSymbolOptions.count {
            normalizedSettings.symbols = Array(repeating: true, count: nativeSymbolOptions.count)
        }

        if normalizedSettings.uppercaseSelections.count != uppercaseCharacters.count {
            normalizedSettings.uppercaseSelections = Array(repeating: true, count: uppercaseCharacters.count)
        }

        if normalizedSettings.lowercaseSelections.count != lowercaseCharacters.count {
            normalizedSettings.lowercaseSelections = Array(repeating: true, count: lowercaseCharacters.count)
        }

        if normalizedSettings.digitSelections.count != digitCharacters.count {
            normalizedSettings.digitSelections = Array(repeating: true, count: digitCharacters.count)
        }

        normalizedSettings.fixedPrefix = sanitizeSingleLineText(normalizedSettings.fixedPrefix)
        normalizedSettings.selectAllSymbols = normalizedSettings.symbols.contains(true) && normalizedSettings.symbols.allSatisfy(\.self)
        return normalizedSettings
    }

    private static func sanitizePresetName(_ value: String) -> String {
        sanitizeSingleLineText(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatPresetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatGenerationTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyMMddHHmm"
        return formatter.string(from: date)
    }

    private static func conditionSummary(for settings: NativePasswordSettings) -> String {
        let pools = buildPools(using: settings)
        let allCharacters = combinePools(pools)
        return "条件 \(formatNumber(allCharacters.count))字/\(formatNumber(pools.count))種"
    }

    private static func comparePresetNames(_ firstPreset: NativePasswordPreset, _ secondPreset: NativePasswordPreset) -> ComparisonResult {
        let nameComparison = firstPreset.name.localizedStandardCompare(secondPreset.name)
        if nameComparison != .orderedSame {
            return nameComparison
        }

        return firstPreset.id.localizedStandardCompare(secondPreset.id)
    }

    private static func comparePresetDates(
        _ firstDate: Date,
        _ secondDate: Date,
        firstPreset: NativePasswordPreset,
        secondPreset: NativePasswordPreset
    ) -> ComparisonResult {
        if firstDate < secondDate {
            return .orderedAscending
        }

        if firstDate > secondDate {
            return .orderedDescending
        }

        return comparePresetNames(firstPreset, secondPreset)
    }

    private static func sanitizeSingleLineText(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined()
    }

    private static func sanitizeNumber(_ value: String, fallback: Int) -> Int {
        Int(value) ?? fallback
    }

    private static func clampNumber(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    private static func getMaxCountForLength(_ length: Int) -> Int {
        let normalizedLength = clampNumber(length, minimum: nativeMinPasswordLength, maximum: nativeMaxPasswordLength)
        return max(nativeMinPasswordCount, min(nativeMaxPasswordCount, nativeMaxGeneratedCharacters / normalizedLength))
    }

    private static func lengthCorrectionMessage(_ normalizedLength: Int) -> String {
        "文字数に範囲外の値が入力されたため、\(formatNumber(normalizedLength)) に補正しました。設定できる範囲は \(formatNumber(nativeMinPasswordLength))〜\(formatNumber(nativeMaxPasswordLength)) です。"
    }

    private static func countCorrectionMessage(_ normalizedCount: Int, _ maxCountForLength: Int) -> String {
        "件数に範囲外の値が入力されたため、\(formatNumber(normalizedCount)) に補正しました。現在の文字数で設定できる件数は \(formatCountRange(nativeMinPasswordCount, maxCountForLength)) です。"
    }

    private static func createPassword(using settings: NativePasswordSettings) async throws -> NativeGeneratedPassword {
        let pools = buildPools(using: settings)
        let allCharacters = combinePools(pools)

        if settings.generationMode == .completeUniform {
            return try await createUniformPassword(from: allCharacters, length: settings.length, categoryCount: pools.count)
        }

        let requiresEachSelectedType = settings.requireEachSelectedType
        let usesFirstCharacterRestriction = settings.firstCharacterMode == .characterSet
        let usesConsecutiveLimit = settings.maxConsecutiveRun > 0
        let prefixCharacters = settings.firstCharacterMode == .fixedPrefix ? settings.fixedPrefix.map(String.init) : []
        let targetCountMap = requiresEachSelectedType
            ? buildRequiredPoolCountMap(pools: pools)
            : nil
        let resolvedAllowedFirstPoolIDs = usesFirstCharacterRestriction
            ? Self.allowedFirstPoolIDs(using: settings).intersection(Set(pools.map(\.id)))
            : Set<String>()
        let maximumConsecutiveRun = settings.maxConsecutiveRun
        var currentCountMap = requiresEachSelectedType ? Dictionary(uniqueKeysWithValues: pools.map { ($0.id, 0) }) : [:]
        var passwordCharacters: [String] = prefixCharacters
        var previousCharacter = prefixCharacters.last ?? ""
        var consecutiveCount = usesConsecutiveLimit ? Self.longestTrailingRun(in: prefixCharacters) : 0
        var iterationsSinceYield = 0

        if requiresEachSelectedType {
            for character in prefixCharacters {
                guard let poolID = Self.poolID(for: character, in: pools) else {
                    throw NativeGenerationError.unavailableCharacters
                }
                currentCountMap[poolID, default: 0] += 1
            }
        }

        while passwordCharacters.count < settings.length {
            let remainingSlots = settings.length - passwordCharacters.count
            let candidatePools = try selectCandidatePools(
                pools: pools,
                currentCountMap: currentCountMap,
                targetCountMap: targetCountMap,
                remainingSlots: remainingSlots,
                maximumConsecutiveRun: maximumConsecutiveRun,
                previousCharacter: previousCharacter,
                consecutiveCount: consecutiveCount,
                allowedFirstPoolIDs: resolvedAllowedFirstPoolIDs,
                isFirstCharacter: passwordCharacters.count == prefixCharacters.count && prefixCharacters.isEmpty,
                restrictFirstCharacter: usesFirstCharacterRestriction,
                restrictConsecutiveDuplicates: usesConsecutiveLimit
            )

            let selectedPoolIndex = try randomInt(upperBound: candidatePools.count)
            let pool = candidatePools[selectedPoolIndex]

            guard let character = try pickCharacter(
                from: pool.characters,
                previousCharacter: previousCharacter,
                consecutiveCount: consecutiveCount,
                maximumConsecutiveRun: maximumConsecutiveRun
            ) else {
                throw NativeGenerationError.unavailableCharacters
            }

            passwordCharacters.append(character)
            if requiresEachSelectedType {
                currentCountMap[pool.id, default: 0] += 1
            }

            if usesConsecutiveLimit {
                if character == previousCharacter {
                    consecutiveCount += 1
                } else {
                    previousCharacter = character
                    consecutiveCount = 1
                }
            }
            iterationsSinceYield += 1

            if iterationsSinceYield >= nativePasswordYieldInterval {
                iterationsSinceYield = 0
                await Task.yield()
            }
        }

        let password = passwordCharacters.joined()
        return NativeGeneratedPassword(
            value: password,
            entropy: estimateRulePriorityEntropy(
                settings: settings,
                pools: pools,
                allCharacters: allCharacters,
                prefixLength: prefixCharacters.count,
                allowedFirstPoolIDs: resolvedAllowedFirstPoolIDs
            ),
            charsetSize: allCharacters.count,
            categoryCount: pools.count
        )
    }

    private static func createUniformPassword(from characters: [String], length: Int, categoryCount: Int) async throws -> NativeGeneratedPassword {
        guard !characters.isEmpty else {
            throw NativeGenerationError.unavailableCharacters
        }

        var passwordCharacters: [String] = []
        passwordCharacters.reserveCapacity(length)
        var iterationsSinceYield = 0

        while passwordCharacters.count < length {
            passwordCharacters.append(characters[try randomInt(upperBound: characters.count)])
            iterationsSinceYield += 1

            if iterationsSinceYield >= nativePasswordYieldInterval {
                iterationsSinceYield = 0
                await Task.yield()
            }
        }

        let password = passwordCharacters.joined()
        return NativeGeneratedPassword(
            value: password,
            entropy: estimateEntropy(charsetSize: characters.count, length: length),
            charsetSize: characters.count,
            categoryCount: categoryCount
        )
    }

    private static func estimateRulePriorityEntropy(settings: NativePasswordSettings, pools: [NativeCharacterPool], allCharacters: [String], prefixLength: Int, allowedFirstPoolIDs: Set<String>) -> Double {
        guard !allCharacters.isEmpty else {
            return 0
        }

        switch settings.firstCharacterMode {
        case .fixedPrefix:
            return estimateEntropy(charsetSize: allCharacters.count, length: max(0, settings.length - prefixLength))
        case .characterSet:
            guard settings.length > 0 else {
                return 0
            }

            let firstCharacterSetSize = combinePools(pools.filter { allowedFirstPoolIDs.contains($0.id) }).count
            guard firstCharacterSetSize > 0 else {
                return 0
            }

            let entropy = log2(Double(firstCharacterSetSize)) + Double(max(0, settings.length - 1)) * log2(Double(allCharacters.count))
            return (entropy * 10).rounded() / 10
        }
    }

    private static func buildPools(using settings: NativePasswordSettings) -> [NativeCharacterPool] {
        var pools: [NativeCharacterPool] = []
        appendPoolIfNeeded(&pools, isEnabled: settings.uppercase, id: "uppercase", sourceCharacters: selectedCharacters(from: uppercaseCharacters, selections: settings.uppercaseSelections).joined(), excludeSimilar: settings.excludeSimilar, excludedCharacters: [])
        appendPoolIfNeeded(&pools, isEnabled: settings.lowercase, id: "lowercase", sourceCharacters: selectedCharacters(from: lowercaseCharacters, selections: settings.lowercaseSelections).joined(), excludeSimilar: settings.excludeSimilar, excludedCharacters: [])
        appendPoolIfNeeded(&pools, isEnabled: settings.digits, id: "digits", sourceCharacters: selectedCharacters(from: digitCharacters, selections: settings.digitSelections).joined(), excludeSimilar: settings.excludeSimilar, excludedCharacters: [])
        appendPoolIfNeeded(&pools, isEnabled: settings.includeSymbols, id: "symbols", sourceCharacters: selectedSymbolCharacters(from: settings), excludeSimilar: false, excludedCharacters: [])

        return pools
    }

    private static func appendPoolIfNeeded(_ pools: inout [NativeCharacterPool], isEnabled: Bool, id: String, sourceCharacters: String, excludeSimilar: Bool, excludedCharacters: Set<String>) {
        guard isEnabled else {
            return
        }

        let normalizedCharacters = normalizeCharacters(sourceCharacters, excludeSimilar: excludeSimilar, excludedCharacters: excludedCharacters)
        guard !normalizedCharacters.isEmpty else {
            return
        }

        pools.append(NativeCharacterPool(id: id, characters: normalizedCharacters))
    }

    private static func normalizeCharacters(_ characters: String, excludeSimilar: Bool, excludedCharacters: Set<String>) -> [String] {
        var seen = Set<String>()

        return characters.map(String.init).filter { character in
            if excludeSimilar && nativeSimilarCharacters.contains(character) {
                return false
            }

            if excludedCharacters.contains(character) {
                return false
            }

            return seen.insert(character).inserted
        }
    }

    private static func selectedSymbolCharacters(from settings: NativePasswordSettings) -> String {
        zip(nativeSymbolOptions, settings.symbols)
            .compactMap { option, isSelected in
                isSelected ? option.value : nil
            }
            .joined()
    }

    private static func selectedCharacters(from source: String, selections: [Bool]) -> [String] {
        zip(source.map(String.init), selections).compactMap { character, isSelected in
            isSelected ? character : nil
        }
    }

    private static func combinePools(_ pools: [NativeCharacterPool]) -> [String] {
        var seen = Set<String>()
        return pools.flatMap(\.characters).filter { seen.insert($0).inserted }
    }

    private static func poolID(for character: String, in pools: [NativeCharacterPool]) -> String? {
        pools.first { $0.characters.contains(character) }?.id
    }

    private static func longestTrailingRun(in characters: [String]) -> Int {
        guard let lastCharacter = characters.last else {
            return 0
        }

        var count = 0
        for character in characters.reversed() {
            if character == lastCharacter {
                count += 1
            } else {
                break
            }
        }

        return count
    }

    private static func selectCandidatePools(
        pools: [NativeCharacterPool],
        currentCountMap: [String: Int],
        targetCountMap: [String: Int]?,
        remainingSlots: Int,
        maximumConsecutiveRun: Int,
        previousCharacter: String,
        consecutiveCount: Int,
        allowedFirstPoolIDs: Set<String>,
        isFirstCharacter: Bool,
        restrictFirstCharacter: Bool,
        restrictConsecutiveDuplicates: Bool
    ) throws -> [NativeCharacterPool] {
        let firstCharacterFilteredPools: [NativeCharacterPool]
        if restrictFirstCharacter && isFirstCharacter {
            firstCharacterFilteredPools = pools.filter { allowedFirstPoolIDs.contains($0.id) }
        } else {
            firstCharacterFilteredPools = pools
        }

        let validAllPools: [NativeCharacterPool]
        if restrictConsecutiveDuplicates {
            validAllPools = firstCharacterFilteredPools.filter {
                hasAvailableCharacter(
                    in: $0.characters,
                    previousCharacter: previousCharacter,
                    consecutiveCount: consecutiveCount,
                    maximumConsecutiveRun: maximumConsecutiveRun
                )
            }
        } else {
            validAllPools = firstCharacterFilteredPools
        }

        guard !validAllPools.isEmpty else {
            throw NativeGenerationError.unavailableCharacters
        }

        let sourcePools: [NativeCharacterPool]
        if let targetCountMap {
            let targetPools = validAllPools.filter { pool in
                currentCountMap[pool.id, default: 0] < targetCountMap[pool.id, default: 0]
            }

            let remainingTargetCount = targetCountMap.reduce(into: 0) { partialResult, entry in
                partialResult += max(0, entry.value - currentCountMap[entry.key, default: 0])
            }

            if remainingSlots == remainingTargetCount && !targetPools.isEmpty {
                sourcePools = targetPools
            } else if !targetPools.isEmpty {
                let maxGap = targetPools.map { targetCountMap[$0.id, default: 0] - currentCountMap[$0.id, default: 0] }.max() ?? 0
                sourcePools = targetPools.filter { targetCountMap[$0.id, default: 0] - currentCountMap[$0.id, default: 0] == maxGap }
            } else {
                sourcePools = validAllPools
            }
        } else {
            sourcePools = validAllPools
        }

        if restrictConsecutiveDuplicates {
            let validPools = sourcePools.filter {
                hasAvailableCharacter(
                    in: $0.characters,
                    previousCharacter: previousCharacter,
                    consecutiveCount: consecutiveCount,
                    maximumConsecutiveRun: maximumConsecutiveRun
                )
            }
            if !validPools.isEmpty {
                return validPools
            }
        }

        return sourcePools
    }

    private static func hasAvailableCharacter(in characters: [String], previousCharacter: String, consecutiveCount: Int, maximumConsecutiveRun: Int) -> Bool {
        if maximumConsecutiveRun == 0 || previousCharacter.isEmpty || consecutiveCount < maximumConsecutiveRun {
            return !characters.isEmpty
        }

        return characters.contains { $0 != previousCharacter }
    }

    private static func pickCharacter(from characters: [String], previousCharacter: String, consecutiveCount: Int, maximumConsecutiveRun: Int) throws -> String? {
        let shouldRestrictRepeatedCharacter = maximumConsecutiveRun > 0 && !previousCharacter.isEmpty && consecutiveCount >= maximumConsecutiveRun
        let candidates = shouldRestrictRepeatedCharacter ? characters.filter { $0 != previousCharacter } : characters

        guard !candidates.isEmpty else {
            return nil
        }

        return candidates[try randomInt(upperBound: candidates.count)]
    }

    private static func allowedFirstPoolIDs(using settings: NativePasswordSettings) -> Set<String> {
        var allowedPoolIDs = Set<String>()

        if settings.allowUppercaseFirst {
            allowedPoolIDs.insert("uppercase")
        }
        if settings.allowLowercaseFirst {
            allowedPoolIDs.insert("lowercase")
        }
        if settings.allowDigitsFirst {
            allowedPoolIDs.insert("digits")
        }
        if settings.allowSymbolsFirst {
            allowedPoolIDs.insert("symbols")
        }

        return allowedPoolIDs
    }

    private static func buildRequiredPoolCountMap(pools: [NativeCharacterPool]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: pools.map { ($0.id, 1) })
    }

    private static func randomInt(upperBound: Int) throws -> Int {
        guard upperBound > 0 else {
            throw NativeGenerationError.invalidUpperBound
        }

        let maxValue = UInt64.max
        let limit = maxValue - maxValue % UInt64(upperBound)

        while true {
            var value: UInt64 = 0
            let status = withUnsafeMutableBytes(of: &value) { buffer in
                SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
            }

            guard status == errSecSuccess else {
                throw NativeGenerationError.randomFailure
            }

            if value < limit {
                return Int(value % UInt64(upperBound))
            }
        }
    }
}

struct NativePasswordSettings: Codable {
    var uppercase: Bool
    var lowercase: Bool
    var digits: Bool
    var includeSymbols: Bool
    var uppercaseSelections: [Bool]
    var lowercaseSelections: [Bool]
    var digitSelections: [Bool]
    var selectAllSymbols: Bool
    var symbols: [Bool]
    var length: Int
    var count: Int
    var minimumUppercase: Int
    var minimumLowercase: Int
    var minimumDigits: Int
    var minimumSymbols: Int
    var generationMode: NativeGenerationMode
    var excludeSimilar: Bool
    var requireEachSelectedType: Bool
    var allowUppercaseFirst: Bool
    var allowLowercaseFirst: Bool
    var allowDigitsFirst: Bool
    var allowSymbolsFirst: Bool
    var firstCharacterMode: NativeFirstCharacterMode
    var fixedPrefix: String
    var maxConsecutiveRun: Int
    var excludedCharacters: String
    var theme: NativeTheme

    static let defaultSettings = NativePasswordSettings(
        uppercase: true,
        lowercase: true,
        digits: true,
        includeSymbols: true,
        uppercaseSelections: Array(repeating: true, count: uppercaseCharacters.count),
        lowercaseSelections: Array(repeating: true, count: lowercaseCharacters.count),
        digitSelections: Array(repeating: true, count: digitCharacters.count),
        selectAllSymbols: false,
        symbols: Array(repeating: true, count: nativeSymbolOptions.count),
        length: 16,
        count: 6,
        minimumUppercase: 25,
        minimumLowercase: 25,
        minimumDigits: 25,
        minimumSymbols: 25,
        generationMode: .rulePriority,
        excludeSimilar: true,
        requireEachSelectedType: false,
        allowUppercaseFirst: true,
        allowLowercaseFirst: true,
        allowDigitsFirst: true,
        allowSymbolsFirst: true,
        firstCharacterMode: .characterSet,
        fixedPrefix: "",
        maxConsecutiveRun: 0,
        excludedCharacters: "",
        theme: .blue
    )

    enum CodingKeys: String, CodingKey {
        case uppercase
        case lowercase
        case digits
        case includeSymbols
        case uppercaseSelections
        case lowercaseSelections
        case digitSelections
        case selectAllSymbols
        case symbols
        case length
        case count
        case minimumUppercase
        case minimumLowercase
        case minimumDigits
        case minimumSymbols
        case generationMode
        case excludeSimilar
        case requireEachSelectedType
        case equalizeCharacterRatios
        case allowUppercaseFirst
        case allowLowercaseFirst
        case allowDigitsFirst
        case allowSymbolsFirst
        case firstCharacterMode
        case fixedPrefix
        case maxConsecutiveRun
        case excludedCharacters
        case noConsecutive
        case theme
    }

    init(
        uppercase: Bool,
        lowercase: Bool,
        digits: Bool,
        includeSymbols: Bool,
        uppercaseSelections: [Bool],
        lowercaseSelections: [Bool],
        digitSelections: [Bool],
        selectAllSymbols: Bool,
        symbols: [Bool],
        length: Int,
        count: Int,
        minimumUppercase: Int,
        minimumLowercase: Int,
        minimumDigits: Int,
        minimumSymbols: Int,
        generationMode: NativeGenerationMode,
        excludeSimilar: Bool,
        requireEachSelectedType: Bool,
        allowUppercaseFirst: Bool,
        allowLowercaseFirst: Bool,
        allowDigitsFirst: Bool,
        allowSymbolsFirst: Bool,
        firstCharacterMode: NativeFirstCharacterMode,
        fixedPrefix: String,
        maxConsecutiveRun: Int,
        excludedCharacters: String,
        theme: NativeTheme
    ) {
        self.uppercase = uppercase
        self.lowercase = lowercase
        self.digits = digits
        self.includeSymbols = includeSymbols
        self.uppercaseSelections = uppercaseSelections
        self.lowercaseSelections = lowercaseSelections
        self.digitSelections = digitSelections
        self.selectAllSymbols = selectAllSymbols
        self.symbols = symbols
        self.length = length
        self.count = count
        self.minimumUppercase = minimumUppercase
        self.minimumLowercase = minimumLowercase
        self.minimumDigits = minimumDigits
        self.minimumSymbols = minimumSymbols
        self.generationMode = generationMode
        self.excludeSimilar = excludeSimilar
        self.requireEachSelectedType = requireEachSelectedType
        self.allowUppercaseFirst = allowUppercaseFirst
        self.allowLowercaseFirst = allowLowercaseFirst
        self.allowDigitsFirst = allowDigitsFirst
        self.allowSymbolsFirst = allowSymbolsFirst
        self.firstCharacterMode = firstCharacterMode
        self.fixedPrefix = fixedPrefix
        self.maxConsecutiveRun = maxConsecutiveRun
        self.excludedCharacters = excludedCharacters
        self.theme = theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uppercase = try container.decodeIfPresent(Bool.self, forKey: .uppercase) ?? Self.defaultSettings.uppercase
        lowercase = try container.decodeIfPresent(Bool.self, forKey: .lowercase) ?? Self.defaultSettings.lowercase
        digits = try container.decodeIfPresent(Bool.self, forKey: .digits) ?? Self.defaultSettings.digits
        includeSymbols = try container.decodeIfPresent(Bool.self, forKey: .includeSymbols) ?? Self.defaultSettings.includeSymbols
        uppercaseSelections = try container.decodeIfPresent([Bool].self, forKey: .uppercaseSelections) ?? Self.defaultSettings.uppercaseSelections
        lowercaseSelections = try container.decodeIfPresent([Bool].self, forKey: .lowercaseSelections) ?? Self.defaultSettings.lowercaseSelections
        digitSelections = try container.decodeIfPresent([Bool].self, forKey: .digitSelections) ?? Self.defaultSettings.digitSelections
        selectAllSymbols = try container.decodeIfPresent(Bool.self, forKey: .selectAllSymbols) ?? Self.defaultSettings.selectAllSymbols
        symbols = try container.decodeIfPresent([Bool].self, forKey: .symbols) ?? Self.defaultSettings.symbols
        length = try container.decodeIfPresent(Int.self, forKey: .length) ?? Self.defaultSettings.length
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? Self.defaultSettings.count
        minimumUppercase = try container.decodeIfPresent(Int.self, forKey: .minimumUppercase) ?? (uppercase ? 25 : 0)
        minimumLowercase = try container.decodeIfPresent(Int.self, forKey: .minimumLowercase) ?? (lowercase ? 25 : 0)
        minimumDigits = try container.decodeIfPresent(Int.self, forKey: .minimumDigits) ?? (digits ? 25 : 0)
        minimumSymbols = try container.decodeIfPresent(Int.self, forKey: .minimumSymbols) ?? (includeSymbols ? 25 : 0)
        generationMode = try container.decodeIfPresent(NativeGenerationMode.self, forKey: .generationMode) ?? Self.defaultSettings.generationMode
        excludeSimilar = try container.decodeIfPresent(Bool.self, forKey: .excludeSimilar) ?? Self.defaultSettings.excludeSimilar
        if let decodedRequireEachSelectedType = try container.decodeIfPresent(Bool.self, forKey: .requireEachSelectedType) {
            requireEachSelectedType = decodedRequireEachSelectedType
        } else if let legacyEqualizeCharacterRatios = try container.decodeIfPresent(Bool.self, forKey: .equalizeCharacterRatios) {
            requireEachSelectedType = legacyEqualizeCharacterRatios
        } else {
            requireEachSelectedType = Self.defaultSettings.requireEachSelectedType
        }
        allowUppercaseFirst = try container.decodeIfPresent(Bool.self, forKey: .allowUppercaseFirst) ?? Self.defaultSettings.allowUppercaseFirst
        allowLowercaseFirst = try container.decodeIfPresent(Bool.self, forKey: .allowLowercaseFirst) ?? Self.defaultSettings.allowLowercaseFirst
        allowDigitsFirst = try container.decodeIfPresent(Bool.self, forKey: .allowDigitsFirst) ?? Self.defaultSettings.allowDigitsFirst
        allowSymbolsFirst = try container.decodeIfPresent(Bool.self, forKey: .allowSymbolsFirst) ?? Self.defaultSettings.allowSymbolsFirst
        firstCharacterMode = try container.decodeIfPresent(NativeFirstCharacterMode.self, forKey: .firstCharacterMode)
            ?? (try container.decodeIfPresent(String.self, forKey: .fixedPrefix).flatMap { $0.isEmpty ? nil : $0 } != nil ? .fixedPrefix : .characterSet)
        fixedPrefix = try container.decodeIfPresent(String.self, forKey: .fixedPrefix) ?? ""
        if let decodedMaxConsecutiveRun = try container.decodeIfPresent(Int.self, forKey: .maxConsecutiveRun) {
            maxConsecutiveRun = decodedMaxConsecutiveRun
        } else {
            let legacyNoConsecutive = try container.decodeIfPresent(Bool.self, forKey: .noConsecutive) ?? false
            maxConsecutiveRun = legacyNoConsecutive ? 1 : 0
        }
        excludedCharacters = try container.decodeIfPresent(String.self, forKey: .excludedCharacters) ?? Self.defaultSettings.excludedCharacters
        theme = try container.decodeIfPresent(NativeTheme.self, forKey: .theme) ?? Self.defaultSettings.theme
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uppercase, forKey: .uppercase)
        try container.encode(lowercase, forKey: .lowercase)
        try container.encode(digits, forKey: .digits)
        try container.encode(includeSymbols, forKey: .includeSymbols)
        try container.encode(uppercaseSelections, forKey: .uppercaseSelections)
        try container.encode(lowercaseSelections, forKey: .lowercaseSelections)
        try container.encode(digitSelections, forKey: .digitSelections)
        try container.encode(selectAllSymbols, forKey: .selectAllSymbols)
        try container.encode(symbols, forKey: .symbols)
        try container.encode(length, forKey: .length)
        try container.encode(count, forKey: .count)
        try container.encode(minimumUppercase, forKey: .minimumUppercase)
        try container.encode(minimumLowercase, forKey: .minimumLowercase)
        try container.encode(minimumDigits, forKey: .minimumDigits)
        try container.encode(minimumSymbols, forKey: .minimumSymbols)
        try container.encode(generationMode, forKey: .generationMode)
        try container.encode(excludeSimilar, forKey: .excludeSimilar)
        try container.encode(requireEachSelectedType, forKey: .requireEachSelectedType)
        try container.encode(allowUppercaseFirst, forKey: .allowUppercaseFirst)
        try container.encode(allowLowercaseFirst, forKey: .allowLowercaseFirst)
        try container.encode(allowDigitsFirst, forKey: .allowDigitsFirst)
        try container.encode(allowSymbolsFirst, forKey: .allowSymbolsFirst)
        try container.encode(firstCharacterMode, forKey: .firstCharacterMode)
        try container.encode(fixedPrefix, forKey: .fixedPrefix)
        try container.encode(maxConsecutiveRun, forKey: .maxConsecutiveRun)
        try container.encode(excludedCharacters, forKey: .excludedCharacters)
        try container.encode(theme, forKey: .theme)
    }
}

struct NativePasswordPreset: Codable, Identifiable {
    let id: String
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var settings: NativePasswordPresetSettings
}

struct NativePasswordPresetSettings: Codable, Equatable {
    var uppercase: Bool
    var lowercase: Bool
    var digits: Bool
    var includeSymbols: Bool
    var uppercaseSelections: [Bool]
    var lowercaseSelections: [Bool]
    var digitSelections: [Bool]
    var selectAllSymbols: Bool
    var symbols: [Bool]
    var length: Int
    var count: Int
    var minimumUppercase: Int
    var minimumLowercase: Int
    var minimumDigits: Int
    var minimumSymbols: Int
    var generationMode: NativeGenerationMode
    var excludeSimilar: Bool
    var requireEachSelectedType: Bool
    var allowUppercaseFirst: Bool?
    var allowLowercaseFirst: Bool?
    var allowDigitsFirst: Bool?
    var allowSymbolsFirst: Bool?
    var firstCharacterMode: NativeFirstCharacterMode
    var fixedPrefix: String?
    var maxConsecutiveRun: Int
    var excludedCharacters: String

    init(settings: NativePasswordSettings) {
        uppercase = settings.uppercase
        lowercase = settings.lowercase
        digits = settings.digits
        includeSymbols = settings.includeSymbols
        uppercaseSelections = settings.uppercaseSelections
        lowercaseSelections = settings.lowercaseSelections
        digitSelections = settings.digitSelections
        selectAllSymbols = settings.selectAllSymbols
        symbols = settings.symbols
        length = settings.length
        count = settings.count
        minimumUppercase = settings.minimumUppercase
        minimumLowercase = settings.minimumLowercase
        minimumDigits = settings.minimumDigits
        minimumSymbols = settings.minimumSymbols
        generationMode = settings.generationMode
        excludeSimilar = settings.excludeSimilar
        requireEachSelectedType = settings.requireEachSelectedType
        firstCharacterMode = settings.firstCharacterMode
        maxConsecutiveRun = settings.maxConsecutiveRun
        excludedCharacters = settings.excludedCharacters

        switch settings.firstCharacterMode {
        case .characterSet:
            allowUppercaseFirst = settings.allowUppercaseFirst
            allowLowercaseFirst = settings.allowLowercaseFirst
            allowDigitsFirst = settings.allowDigitsFirst
            allowSymbolsFirst = settings.allowSymbolsFirst
            fixedPrefix = nil
        case .fixedPrefix:
            allowUppercaseFirst = nil
            allowLowercaseFirst = nil
            allowDigitsFirst = nil
            allowSymbolsFirst = nil
            fixedPrefix = settings.fixedPrefix
        }
    }

    func applying(to currentSettings: NativePasswordSettings) -> NativePasswordSettings {
        var appliedSettings = currentSettings
        appliedSettings.uppercase = uppercase
        appliedSettings.lowercase = lowercase
        appliedSettings.digits = digits
        appliedSettings.includeSymbols = includeSymbols
        appliedSettings.uppercaseSelections = uppercaseSelections
        appliedSettings.lowercaseSelections = lowercaseSelections
        appliedSettings.digitSelections = digitSelections
        appliedSettings.selectAllSymbols = selectAllSymbols
        appliedSettings.symbols = symbols
        appliedSettings.length = length
        appliedSettings.count = count
        appliedSettings.minimumUppercase = minimumUppercase
        appliedSettings.minimumLowercase = minimumLowercase
        appliedSettings.minimumDigits = minimumDigits
        appliedSettings.minimumSymbols = minimumSymbols
        appliedSettings.generationMode = generationMode
        appliedSettings.excludeSimilar = excludeSimilar
        appliedSettings.requireEachSelectedType = requireEachSelectedType
        appliedSettings.firstCharacterMode = firstCharacterMode
        appliedSettings.maxConsecutiveRun = maxConsecutiveRun
        appliedSettings.excludedCharacters = excludedCharacters

        switch firstCharacterMode {
        case .characterSet:
            appliedSettings.allowUppercaseFirst = allowUppercaseFirst ?? NativePasswordSettings.defaultSettings.allowUppercaseFirst
            appliedSettings.allowLowercaseFirst = allowLowercaseFirst ?? NativePasswordSettings.defaultSettings.allowLowercaseFirst
            appliedSettings.allowDigitsFirst = allowDigitsFirst ?? NativePasswordSettings.defaultSettings.allowDigitsFirst
            appliedSettings.allowSymbolsFirst = allowSymbolsFirst ?? NativePasswordSettings.defaultSettings.allowSymbolsFirst
            appliedSettings.fixedPrefix = NativePasswordSettings.defaultSettings.fixedPrefix
        case .fixedPrefix:
            appliedSettings.allowUppercaseFirst = NativePasswordSettings.defaultSettings.allowUppercaseFirst
            appliedSettings.allowLowercaseFirst = NativePasswordSettings.defaultSettings.allowLowercaseFirst
            appliedSettings.allowDigitsFirst = NativePasswordSettings.defaultSettings.allowDigitsFirst
            appliedSettings.allowSymbolsFirst = NativePasswordSettings.defaultSettings.allowSymbolsFirst
            appliedSettings.fixedPrefix = fixedPrefix ?? NativePasswordSettings.defaultSettings.fixedPrefix
        }

        return appliedSettings
    }
}

struct NativeGeneratedPassword: Identifiable {
    let id = UUID()
    let value: String
    let entropy: Double
    let charsetSize: Int
    let categoryCount: Int
}

struct NativePasswordResultMetadata {
    let entropy: Double
    let conditionSummary: String
}

private struct NativeGenerationSession {
    let id: UUID
    let createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
    }

    var shortID: String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
    }
}

struct NativeGeneratedPasswordListItem: Identifiable {
    let id: UUID
    let displayValue: String
    let isTruncated: Bool
    let analysis: NativePasswordAnalysis

    nonisolated init(password: NativeGeneratedPassword) {
        id = password.id
        if password.value.count <= 100 {
            displayValue = password.value
            isTruncated = false
        } else {
            displayValue = String(password.value.prefix(100)) + "..."
            isTruncated = true
        }

        analysis = NativePasswordAnalysis(password: password.value, entropy: password.entropy, charsetSize: password.charsetSize, categoryCount: password.categoryCount)
    }
}

enum NativePasswordGrade: Int {
    case f = 0
    case d = 1
    case c = 2
    case b = 3
    case a = 4
    case s = 5

    var label: String {
        switch self {
        case .s:
            return "S"
        case .a:
            return "A"
        case .b:
            return "B"
        case .c:
            return "C"
        case .d:
            return "D"
        case .f:
            return "F"
        }
    }

}

struct NativePasswordGradeMetric: Identifiable {
    let id: String
    let title: String
    let compactTitle: String
    let grade: NativePasswordGrade
}

private enum NativePasswordRiskLevel: Int {
    case none = 0
    case minor = 1
    case caution = 2
    case warning = 3
    case danger = 4
}

private struct NativePasswordRiskSignal {
    let level: NativePasswordRiskLevel
    let message: String?
}

struct NativePasswordAnalysis {
    let entropy: Double
    let charsetSize: Int
    let categoryCount: Int
    let overallGrade: NativePasswordGrade
    let metrics: [NativePasswordGradeMetric]
    let conditionSummary: String
    let warnings: [String]

    nonisolated init(password: String, entropy: Double, charsetSize: Int, categoryCount: Int) {
        let patternFindings = getPasswordPatternFindings(password)
        let lengthGrade = getLengthGrade(length: password.count)
        let bruteForceGrade = getEntropyGrade(entropy)
        let knownRiskSignal = getKnownRiskSignal(password: password)
        let patternRiskSignal = getPatternRiskSignal(patternFindings: patternFindings)
        let overallGrade = getOverallPasswordGrade(
            lengthGrade: lengthGrade,
            bruteForceGrade: bruteForceGrade,
            knownRiskLevel: knownRiskSignal.level,
            patternRiskLevel: patternRiskSignal.level
        )

        self.entropy = entropy
        self.charsetSize = charsetSize
        self.categoryCount = categoryCount
        self.overallGrade = overallGrade
        self.metrics = [
            NativePasswordGradeMetric(id: "length", title: "長さ", compactTitle: "長さ", grade: lengthGrade),
            NativePasswordGradeMetric(id: "bruteForce", title: "総当たり耐性", compactTitle: "総当たり耐性", grade: bruteForceGrade)
        ]
        self.conditionSummary = "条件 \(formatNumber(charsetSize))字/\(formatNumber(categoryCount))種"
        self.warnings = getPasswordAnalysisMessages(
            lengthGrade: lengthGrade,
            bruteForceGrade: bruteForceGrade,
            charsetSize: charsetSize,
            knownRiskSignal: knownRiskSignal,
            patternRiskSignal: patternRiskSignal
        )
    }

    var warningDetail: String {
        warnings.joined(separator: " / ")
    }
}

private struct NativePasswordRow: View {
    let password: NativeGeneratedPasswordListItem
    let palette: NativeThemePalette
    let onCopy: () -> Void
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                NativePasswordPreviewLabel(text: password.displayValue, textColor: NSColor(palette.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)

                compactStrengthSummary

                if !password.analysis.warningDetail.isEmpty {
                    Text(password.analysis.warningDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 6) {
                Button {
                    onCopy()
                    isCopied = true

                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        isCopied = false
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accentStrong)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(palette.accentSoft)
                        )
                }
                .buttonStyle(.plain)

                if isCopied {
                    Text("Copied!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .frame(width: 48)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private var compactStrengthSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                overviewGradeChip
                compactMetricsRow
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    overviewGradeChip
                }

                compactMetricsRow
            }
        }
    }

    private var compactMetricsRow: some View {
        HStack(spacing: 4) {
            ForEach(password.analysis.metrics) { metric in
                gradeMetricChip(metric)
            }
        }
    }

    private var overviewGradeChip: some View {
        HStack(spacing: 4) {
            Text("総合")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.muted)
                .lineLimit(1)

            Text(password.analysis.overallGrade.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(gradeForeground(password.analysis.overallGrade))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(gradeBackground(password.analysis.overallGrade))
        )
        .overlay(
            Capsule()
                .stroke(gradeBorder(password.analysis.overallGrade), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private func gradeMetricChip(_ metric: NativePasswordGradeMetric) -> some View {
        HStack(spacing: 3) {
            Text(metric.compactTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.muted)
                .lineLimit(1)

            Text(metric.grade.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(gradeForeground(metric.grade))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(gradeBackground(metric.grade))
        )
        .overlay(
            Capsule()
                .stroke(gradeBorder(metric.grade), lineWidth: 1)
        )
        .help(metric.title)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func gradeForeground(_ grade: NativePasswordGrade) -> Color {
        switch grade {
        case .s, .a:
            return palette.accentStrong
        case .b, .c:
            return palette.ink
        case .d, .f:
            return palette.danger
        }
    }

    private func gradeBackground(_ grade: NativePasswordGrade) -> Color {
        switch grade {
        case .s, .a:
            return palette.accent.opacity(0.12)
        case .b, .c:
            return palette.surfaceStrong
        case .d, .f:
            return palette.danger.opacity(0.12)
        }
    }

    private func gradeBorder(_ grade: NativePasswordGrade) -> Color {
        switch grade {
        case .s, .a:
            return palette.accent.opacity(0.28)
        case .b, .c:
            return palette.panelBorder
        case .d, .f:
            return palette.danger.opacity(0.34)
        }
    }
}

private struct NativePasswordPreviewLabel: NSViewRepresentable {
    let text: String
    let textColor: NSColor

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.isSelectable = true
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byCharWrapping
        label.maximumNumberOfLines = 0
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = textColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.textColor = textColor
    }
}

private struct FlowCharacterText: View {
    let characters: [String]
    let selectedCharacters: Set<String>
    let excludedCharacters: Set<String>
    let selectedColor: Color
    let unselectedColor: Color

    var body: some View {
        Text(attributedCharacters)
            .font(.system(size: 12, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedCharacters: AttributedString {
        var result = AttributedString()

        for (index, character) in characters.enumerated() {
            let isSelected = selectedCharacters.contains(character)
            let isExcluded = excludedCharacters.contains(character)
            var segment = AttributedString(character)
            segment.font = .system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced)
            segment.foregroundColor = isExcluded ? unselectedColor : (isSelected ? selectedColor : unselectedColor)
            if isExcluded {
                segment.inlinePresentationIntent = .strikethrough
            }
            result.append(segment)

            if index != characters.count - 1 {
                var spacer = AttributedString(" ")
                spacer.font = .system(size: 12, design: .monospaced)
                spacer.foregroundColor = unselectedColor
                result.append(spacer)
            }
        }

        return result
    }
}

private struct StatusMessageView: View {
    let status: NativeInlineStatus
    let palette: NativeThemePalette

    var body: some View {
        if !status.message.isEmpty {
            Text(status.message)
                .font(.system(size: 12))
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch status.tone {
        case .info:
            return palette.muted
        case .warning:
            return palette.accentStrong
        case .error:
            return palette.danger
        }
    }
}

private struct NativeSymbolOption {
    let label: String
    let description: String
    let value: String
}

struct NativeInlineStatus {
    var message = ""
    var tone: NativeStatusTone = .info
}

private struct NativeCharacterPool {
    let id: String
    let characters: [String]
}

struct NativeThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let surfaceSoft: Color
    let surface: Color
    let surfaceStrong: Color
    let panelBorder: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let accentStrong: Color
    let accentSoft: Color
    let disabledBackground: Color
    let disabledText: Color
    let danger: Color
}

enum NativeThemeAppearance {
    case light
    case dark

    init(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .light:
            self = .light
        case .dark:
            self = .dark
        @unknown default:
            self = .light
        }
    }
}

enum NativeFocusedField: Hashable {
    case length
    case count
    case symbolImport
}

enum NativeStatusTone {
    case info
    case warning
    case error
}

enum NativeCharacterTab: String, CaseIterable, Identifiable {
    case uppercase
    case lowercase
    case digits
    case symbols

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uppercase:
            return "大文字"
        case .lowercase:
            return "小文字"
        case .digits:
            return "数字"
        case .symbols:
            return "記号"
        }
    }

}

enum NativeFirstCharacterMode: String, CaseIterable, Codable, Identifiable {
    case characterSet
    case fixedPrefix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .characterSet:
            return "文字種"
        case .fixedPrefix:
            return "固定文字"
        }
    }
}

enum NativePresetSortKey: String, CaseIterable, Identifiable {
    case name
    case createdAt
    case updatedAt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return "名前"
        case .createdAt:
            return "作成日"
        case .updatedAt:
            return "更新日"
        }
    }
}

enum NativePresetSortDirection: String {
    case ascending
    case descending

    var title: String {
        switch self {
        case .ascending:
            return "昇順"
        case .descending:
            return "降順"
        }
    }

    var systemImageName: String {
        switch self {
        case .ascending:
            return "arrow.up"
        case .descending:
            return "arrow.down"
        }
    }
}

enum NativeGenerationMode: String, CaseIterable, Codable, Identifiable {
    case completeUniform
    case rulePriority

    var id: String { rawValue }

    var title: String {
        switch self {
        case .completeUniform:
            return "完全一様"
        case .rulePriority:
            return "ルール優先"
        }
    }

    var tip: String {
        switch self {
        case .completeUniform:
            return "暗号学的に安全な乱数を使い、選択した文字の中からできるだけ公平に選んで生成します。理論上の偏りが少ない方式ですが、文字種を必ず含める、先頭文字を決める、同じ文字を連続させないといった細かい条件は使えません。"
        case .rulePriority:
            return "暗号学的に安全な乱数を使い、選択した文字種を必ず含める、先頭文字を決める、同じ文字を連続させないなどの条件を反映して生成します。サービスごとのパスワード条件に合わせやすく、細かい条件を付けたいときに向いています。"
        }
    }
}

enum NativeTheme: String, CaseIterable, Codable, Identifiable {
    case blue
    case green
    case pink
    case red
    case yellow
    case orange
    case purple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "青"
        case .green: return "緑"
        case .pink: return "ピンク"
        case .red: return "赤"
        case .yellow: return "黄色"
        case .orange: return "オレンジ"
        case .purple: return "紫"
        }
    }

    func palette(for appearance: NativeThemeAppearance) -> NativeThemePalette {
        switch (self, appearance) {
        case (.blue, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xEDF4FF),
                backgroundBottom: Color(hex: 0xD7E6FF),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x435E91, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x60708A),
                accent: Color(hex: 0x2F6FE4),
                accentStrong: Color(hex: 0x1D4FB8),
                accentSoft: Color(hex: 0xDBE8FF),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.blue, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x0F1726),
                backgroundBottom: Color(hex: 0x16233A),
                panel: Color(hex: 0x172235, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1E2C45, opacity: 0.94),
                surface: Color(hex: 0x243451, opacity: 0.94),
                surfaceStrong: Color(hex: 0x2C4062, opacity: 0.96),
                panelBorder: Color(hex: 0x78A6FF, opacity: 0.20),
                ink: Color(hex: 0xEDF4FF),
                muted: Color(hex: 0xA8BAD8),
                accent: Color(hex: 0x6C9EFF),
                accentStrong: Color(hex: 0x4B82F6),
                accentSoft: Color(hex: 0x233B63),
                disabledBackground: Color(hex: 0x243245, opacity: 0.96),
                disabledText: Color(hex: 0x7183A0),
                danger: Color(hex: 0xF07A6A)
            )
        case (.green, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xECF9F1),
                backgroundBottom: Color(hex: 0xD6F0DF),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x3F805D, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x5D7D69),
                accent: Color(hex: 0x2C9B59),
                accentStrong: Color(hex: 0x1F7341),
                accentSoft: Color(hex: 0xDAF4E3),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.green, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x101B16),
                backgroundBottom: Color(hex: 0x18281F),
                panel: Color(hex: 0x17251E, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1D3127, opacity: 0.94),
                surface: Color(hex: 0x243B30, opacity: 0.94),
                surfaceStrong: Color(hex: 0x2B473A, opacity: 0.96),
                panelBorder: Color(hex: 0x6BD69A, opacity: 0.18),
                ink: Color(hex: 0xEEF8F2),
                muted: Color(hex: 0xA8C8B5),
                accent: Color(hex: 0x53C97F),
                accentStrong: Color(hex: 0x34A861),
                accentSoft: Color(hex: 0x204431),
                disabledBackground: Color(hex: 0x243245, opacity: 0.96),
                disabledText: Color(hex: 0x7183A0),
                danger: Color(hex: 0xF07A6A)
            )
        case (.pink, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF0F7),
                backgroundBottom: Color(hex: 0xFFDBE9),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0xA64E80, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x8A6077),
                accent: Color(hex: 0xE2539A),
                accentStrong: Color(hex: 0xB83776),
                accentSoft: Color(hex: 0xFFDCEC),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.pink, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x1C121A),
                backgroundBottom: Color(hex: 0x2A1623),
                panel: Color(hex: 0x271927, opacity: 0.96),
                surfaceSoft: Color(hex: 0x341E31, opacity: 0.94),
                surface: Color(hex: 0x40233C, opacity: 0.94),
                surfaceStrong: Color(hex: 0x4A2945, opacity: 0.96),
                panelBorder: Color(hex: 0xFF8AC2, opacity: 0.18),
                ink: Color(hex: 0xFFF3FA),
                muted: Color(hex: 0xD3B2C5),
                accent: Color(hex: 0xFF82BF),
                accentStrong: Color(hex: 0xE45A9F),
                accentSoft: Color(hex: 0x4A2540),
                disabledBackground: Color(hex: 0x3B2E3A, opacity: 0.96),
                disabledText: Color(hex: 0xA88FA1),
                danger: Color(hex: 0xFF8A78)
            )
        case (.red, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF0F0),
                backgroundBottom: Color(hex: 0xFFD9D9),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0xA34D4D, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x8A6464),
                accent: Color(hex: 0xDC4F4F),
                accentStrong: Color(hex: 0xB33838),
                accentSoft: Color(hex: 0xFFE0E0),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.red, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x1C1212),
                backgroundBottom: Color(hex: 0x2A1717),
                panel: Color(hex: 0x281919, opacity: 0.96),
                surfaceSoft: Color(hex: 0x351F1F, opacity: 0.94),
                surface: Color(hex: 0x402525, opacity: 0.94),
                surfaceStrong: Color(hex: 0x4B2B2B, opacity: 0.96),
                panelBorder: Color(hex: 0xFF8D8D, opacity: 0.18),
                ink: Color(hex: 0xFFF4F4),
                muted: Color(hex: 0xD0B0B0),
                accent: Color(hex: 0xFF7A7A),
                accentStrong: Color(hex: 0xE65C5C),
                accentSoft: Color(hex: 0x4A2828),
                disabledBackground: Color(hex: 0x3B2E3A, opacity: 0.96),
                disabledText: Color(hex: 0xA88FA1),
                danger: Color(hex: 0xFF8A78)
            )
        case (.yellow, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFFBE8),
                backgroundBottom: Color(hex: 0xFFF0BF),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0xA88A36, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x8A794B),
                accent: Color(hex: 0xD1A21D),
                accentStrong: Color(hex: 0xA87F12),
                accentSoft: Color(hex: 0xFFF0BF),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.yellow, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x1B1810),
                backgroundBottom: Color(hex: 0x292313),
                panel: Color(hex: 0x272111, opacity: 0.96),
                surfaceSoft: Color(hex: 0x342A16, opacity: 0.94),
                surface: Color(hex: 0x40331B, opacity: 0.94),
                surfaceStrong: Color(hex: 0x4A3C20, opacity: 0.96),
                panelBorder: Color(hex: 0xFFD15E, opacity: 0.18),
                ink: Color(hex: 0xFFF9EA),
                muted: Color(hex: 0xD8C18F),
                accent: Color(hex: 0xF0C24A),
                accentStrong: Color(hex: 0xD9A624),
                accentSoft: Color(hex: 0x493A1A),
                disabledBackground: Color(hex: 0x3A3425, opacity: 0.96),
                disabledText: Color(hex: 0xA99B77),
                danger: Color(hex: 0xFF9872)
            )
        case (.orange, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF4EA),
                backgroundBottom: Color(hex: 0xFFE0C4),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0xAA6A36, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x8C6B51),
                accent: Color(hex: 0xEA7E2F),
                accentStrong: Color(hex: 0xBF5D19),
                accentSoft: Color(hex: 0xFFE4CF),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.orange, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x1B1410),
                backgroundBottom: Color(hex: 0x2A1C12),
                panel: Color(hex: 0x271B14, opacity: 0.96),
                surfaceSoft: Color(hex: 0x342218, opacity: 0.94),
                surface: Color(hex: 0x402A1D, opacity: 0.94),
                surfaceStrong: Color(hex: 0x4B3120, opacity: 0.96),
                panelBorder: Color(hex: 0xFFAB72, opacity: 0.18),
                ink: Color(hex: 0xFFF6EE),
                muted: Color(hex: 0xD6B49A),
                accent: Color(hex: 0xFF9A57),
                accentStrong: Color(hex: 0xF07C2C),
                accentSoft: Color(hex: 0x4A301E),
                disabledBackground: Color(hex: 0x3A3025, opacity: 0.96),
                disabledText: Color(hex: 0xA99484),
                danger: Color(hex: 0xFF9872)
            )
        case (.purple, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xF5EFFF),
                backgroundBottom: Color(hex: 0xE4D8FF),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x6C53A6, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x70608D),
                accent: Color(hex: 0x7E57E7),
                accentStrong: Color(hex: 0x5E3DBD),
                accentSoft: Color(hex: 0xE7DDFF),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.purple, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x15121D),
                backgroundBottom: Color(hex: 0x20162A),
                panel: Color(hex: 0x211927, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2B2034, opacity: 0.94),
                surface: Color(hex: 0x352740, opacity: 0.94),
                surfaceStrong: Color(hex: 0x3F2E4B, opacity: 0.96),
                panelBorder: Color(hex: 0xB196FF, opacity: 0.18),
                ink: Color(hex: 0xF8F3FF),
                muted: Color(hex: 0xC0B0E0),
                accent: Color(hex: 0xA88BFF),
                accentStrong: Color(hex: 0x8566F0),
                accentSoft: Color(hex: 0x3F2C63),
                disabledBackground: Color(hex: 0x322A3D, opacity: 0.96),
                disabledText: Color(hex: 0x988AB1),
                danger: Color(hex: 0xFF8A78)
            )
        }
    }
}

private enum NativeGenerationError: Error {
    case invalidUpperBound
    case randomFailure
    case unavailableCharacters
}

private struct SecureRandomNumberGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        var value: UInt64 = 0
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }

        if status == errSecSuccess {
            return value
        }

        return UInt64.random(in: UInt64.min...UInt64.max)
    }
}

private nonisolated func getLengthGrade(length: Int) -> NativePasswordGrade {
    if length >= 24 {
        return .s
    }
    if length >= 20 {
        return .a
    }
    if length >= 16 {
        return .b
    }
    if length >= 15 {
        return .c
    }
    if length >= 8 {
        return .d
    }

    return .f
}

private nonisolated func getEntropyGrade(_ entropy: Double) -> NativePasswordGrade {
    if entropy >= 128 {
        return .s
    }
    if entropy >= 100 {
        return .a
    }
    if entropy >= 80 {
        return .b
    }
    if entropy >= 60 {
        return .c
    }
    if entropy >= 40 {
        return .d
    }

    return .f
}

private nonisolated func getKnownRiskSignal(password: String) -> NativePasswordRiskSignal {
    if isBlockedPassword(password) {
        return NativePasswordRiskSignal(level: .danger, message: "既知の弱いパスワード候補に一致します。")
    }

    let normalizedPassword = normalizePasswordForRisk(password)
    if isSimpleWeakPasswordDerivative(normalizedPassword) {
        return NativePasswordRiskSignal(level: .warning, message: "既知の弱い語句を単純に変形しています。")
    }

    let commonWordCoverage = getCommonPasswordWordCoverage(normalizedPassword)
    if commonWordCoverage >= 0.25 {
        return NativePasswordRiskSignal(level: .caution, message: "一般的な語句が大きな割合を占めます。")
    }

    return NativePasswordRiskSignal(level: .none, message: nil)
}

private nonisolated func getPatternRiskSignal(patternFindings: [NativePasswordPatternFinding]) -> NativePasswordRiskSignal {
    guard !patternFindings.isEmpty else {
        return NativePasswordRiskSignal(level: .none, message: nil)
    }

    let maxCoverage = patternFindings.map(\.coverage).max() ?? 0
    let combinedCoverage = min(1, patternFindings.reduce(0.0) { $0 + $1.coverage })
    let message = getPatternFindingWarningMessage(patternFindings)

    if maxCoverage >= 0.85 || combinedCoverage >= 0.95 {
        return NativePasswordRiskSignal(level: .danger, message: message)
    }
    if maxCoverage >= 0.65 || combinedCoverage >= 0.8 {
        return NativePasswordRiskSignal(level: .warning, message: message)
    }
    if maxCoverage >= 0.45 || combinedCoverage >= 0.6 {
        return NativePasswordRiskSignal(level: .caution, message: message)
    }
    if maxCoverage >= 0.25 || combinedCoverage >= 0.35 {
        return NativePasswordRiskSignal(level: .minor, message: "軽い推測パターンを含みます: \(getPatternFindingMessages(patternFindings))")
    }

    return NativePasswordRiskSignal(level: .none, message: nil)
}

private nonisolated func getCommonPasswordWordCoverage(_ normalizedPassword: String) -> Double {
    guard !normalizedPassword.isEmpty else {
        return 0
    }

    let matchLength = getLongestCommonPasswordWordMatchLength(normalizedPassword)
    return Double(matchLength) / Double(normalizedPassword.count)
}

private nonisolated func isSimpleWeakPasswordDerivative(_ normalizedPassword: String) -> Bool {
    guard !normalizedPassword.isEmpty else {
        return false
    }

    for blockedPassword in getNativePasswordBlocklist() {
        guard blockedPassword.count >= 4 else {
            continue
        }

        if normalizedPassword.hasPrefix(blockedPassword) {
            let suffix = String(normalizedPassword.dropFirst(blockedPassword.count))
            if isSimpleNumericPadding(suffix) {
                return true
            }
        }

        if normalizedPassword.hasSuffix(blockedPassword) {
            let prefix = String(normalizedPassword.dropLast(blockedPassword.count))
            if isSimpleNumericPadding(prefix) {
                return true
            }
        }
    }

    return false
}

private nonisolated func isSimpleNumericPadding(_ value: String) -> Bool {
    !value.isEmpty && value.count <= 4 && value.allSatisfy(\.isNumber)
}

private nonisolated func isMeaningfulPatternFinding(_ finding: NativePasswordPatternFinding) -> Bool {
    if finding.coverage >= 0.25 {
        return true
    }
    if finding.passwordLength <= 20 {
        return finding.matchedLength >= 4
    }
    if finding.passwordLength <= 100 {
        return finding.matchedLength >= 10 || finding.coverage >= 0.15
    }

    return finding.matchedLength >= 24 || finding.coverage >= 0.1
}

private nonisolated func makePatternFinding(message: String, penalty: Double, matchedLength: Int, passwordLength: Int) -> NativePasswordPatternFinding? {
    guard matchedLength > 0 else {
        return nil
    }

    let finding = NativePasswordPatternFinding(
        message: message,
        penalty: penalty,
        matchedLength: matchedLength,
        passwordLength: passwordLength
    )

    return isMeaningfulPatternFinding(finding) ? finding : nil
}

private nonisolated func getPatternFindingMessages(_ patternFindings: [NativePasswordPatternFinding]) -> String {
    patternFindings.map(\.message).joined(separator: "、")
}

private nonisolated func getPatternFindingWarningMessage(_ patternFindings: [NativePasswordPatternFinding]) -> String {
    "推測されやすいパターンを含みます: \(getPatternFindingMessages(patternFindings))"
}

private nonisolated func getLengthAndEntropyMessages(lengthGrade: NativePasswordGrade, bruteForceGrade: NativePasswordGrade) -> [String] {
    var messages: [String] = []

    if isPasswordGrade(lengthGrade, atMost: .d) {
        messages.append("文字数が短めです。15文字以上を推奨します。")
    } else if lengthGrade == .c {
        messages.append("15文字は最低目安です。重要な用途では20文字以上を推奨します。")
    } else if lengthGrade == .b {
        messages.append("重要な用途では20文字以上にすると余裕が出ます。")
    }

    if isPasswordGrade(bruteForceGrade, atMost: .d) {
        messages.append("総当たり耐性が低めです。文字数を増やすと改善します。")
    } else if bruteForceGrade == .c {
        messages.append("総当たり耐性は最低目安です。100 bits以上を推奨します。")
    } else if bruteForceGrade == .b {
        messages.append("重要な用途では100 bits以上にすると余裕が出ます。")
    }

    return messages
}

private nonisolated func getBreadthMessage(charsetSize: Int) -> String? {
    if charsetSize <= 9 {
        return "文字セットが狭いため、同じ長さでも候補数が少なめです。"
    }

    return nil
}

private nonisolated func getOverallPasswordGrade(
    lengthGrade: NativePasswordGrade,
    bruteForceGrade: NativePasswordGrade,
    knownRiskLevel: NativePasswordRiskLevel,
    patternRiskLevel: NativePasswordRiskLevel
) -> NativePasswordGrade {
    var grade = minPasswordGrade(lengthGrade, bruteForceGrade)
    let highestRiskLevel = max(knownRiskLevel.rawValue, patternRiskLevel.rawValue)

    switch highestRiskLevel {
    case NativePasswordRiskLevel.danger.rawValue...:
        return .f
    case NativePasswordRiskLevel.warning.rawValue:
        grade = capPasswordGrade(grade, maximum: .c)
    case NativePasswordRiskLevel.caution.rawValue:
        grade = capPasswordGrade(grade, maximum: .b)
    case NativePasswordRiskLevel.minor.rawValue:
        grade = capPasswordGrade(grade, maximum: .a)
    default:
        break
    }

    return grade
}

private nonisolated func minPasswordGrade(_ first: NativePasswordGrade, _ second: NativePasswordGrade) -> NativePasswordGrade {
    first.rawValue < second.rawValue ? first : second
}

private nonisolated func capPasswordGrade(_ grade: NativePasswordGrade, maximum: NativePasswordGrade) -> NativePasswordGrade {
    grade.rawValue > maximum.rawValue ? maximum : grade
}

private nonisolated func isPasswordGrade(_ grade: NativePasswordGrade, atMost threshold: NativePasswordGrade) -> Bool {
    grade.rawValue <= threshold.rawValue
}

private nonisolated func getPasswordAnalysisMessages(
    lengthGrade: NativePasswordGrade,
    bruteForceGrade: NativePasswordGrade,
    charsetSize: Int,
    knownRiskSignal: NativePasswordRiskSignal,
    patternRiskSignal: NativePasswordRiskSignal
) -> [String] {
    var messages = getLengthAndEntropyMessages(lengthGrade: lengthGrade, bruteForceGrade: bruteForceGrade)

    if let knownRiskMessage = knownRiskSignal.message {
        messages.append(knownRiskMessage)
    }
    if let patternRiskMessage = patternRiskSignal.message {
        messages.append(patternRiskMessage)
    }
    if let breadthMessage = getBreadthMessage(charsetSize: charsetSize) {
        messages.append(breadthMessage)
    }

    return Array(messages.prefix(3))
}

private struct NativePasswordPatternFinding {
    let message: String
    let penalty: Double
    let matchedLength: Int
    let passwordLength: Int

    nonisolated var coverage: Double {
        guard passwordLength > 0 else {
            return 0
        }

        return min(1, Double(matchedLength) / Double(passwordLength))
    }
}

private nonisolated func getPasswordPatternFindings(_ password: String) -> [NativePasswordPatternFinding] {
    let lowercasePassword = password.lowercased()
    guard !lowercasePassword.isEmpty else {
        return []
    }

    let passwordLength = lowercasePassword.count
    let normalizedPassword = normalizePasswordForRisk(lowercasePassword)
    var findings: [NativePasswordPatternFinding] = []

    if let finding = makePatternFinding(
        message: "よく使われる単語",
        penalty: 0.2,
        matchedLength: getLongestCommonPasswordWordMatchLength(normalizedPassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }
    if let finding = makePatternFinding(
        message: "連続文字列",
        penalty: 0.16,
        matchedLength: getLongestSequentialRunLength(lowercasePassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }
    if let finding = makePatternFinding(
        message: "キーボード配列",
        penalty: 0.18,
        matchedLength: getLongestKeyboardRunLength(lowercasePassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }
    if let finding = makePatternFinding(
        message: "同一文字の繰り返し",
        penalty: 0.14,
        matchedLength: getLongestRepeatedCharacterRunLength(lowercasePassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }
    if let finding = makePatternFinding(
        message: "短いブロックの繰り返し",
        penalty: 0.18,
        matchedLength: getLongestRepeatedBlockLength(lowercasePassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }
    if let finding = makePatternFinding(
        message: "日付らしい数字",
        penalty: 0.14,
        matchedLength: getLongestDateLikeDigitsLength(lowercasePassword),
        passwordLength: passwordLength
    ) {
        findings.append(finding)
    }

    return findings
}

private nonisolated func foldPasswordForPatternMatching(_ password: String) -> String {
    let replacements: [Character: Character] = [
        "0": "o",
        "1": "l",
        "3": "e",
        "4": "a",
        "5": "s",
        "7": "t",
        "@": "a",
        "$": "s"
    ]

    return String(password.lowercased().map { replacements[$0] ?? $0 })
}

private nonisolated func isBlockedPassword(_ password: String) -> Bool {
    getNativePasswordBlocklist().contains(normalizePasswordForRisk(password))
}

private nonisolated func getNativePasswordBlocklist() -> Set<String> {
    Set([
        "password",
        "password1",
        "password123",
        "qwerty",
        "qwerty123",
        "admin",
        "admin123",
        "administrator",
        "welcome",
        "welcome1",
        "letmein",
        "iloveyou",
        "abc123",
        "123456",
        "12345678",
        "123456789",
        "dragon",
        "monkey",
        "master",
        "login",
        "user",
        "root",
        "secret"
    ])
}

private nonisolated func normalizePasswordForRisk(_ password: String) -> String {
    foldPasswordForPatternMatching(password).filter { $0.isLetter || $0.isNumber }
}

private nonisolated func getCommonPasswordWords() -> [String] {
    [
        "password",
        "pass",
        "admin",
        "administrator",
        "welcome",
        "login",
        "user",
        "root",
        "secret",
        "letmein",
        "iloveyou",
        "dragon",
        "monkey",
        "master",
        "passgen",
        "safari",
        "apple"
    ]
}

private nonisolated func getLongestCommonPasswordWordMatchLength(_ normalizedPassword: String) -> Int {
    getCommonPasswordWords()
        .filter { normalizedPassword.contains($0) }
        .map(\.count)
        .max() ?? 0
}

private nonisolated func getLongestSequentialRunLength(_ password: String) -> Int {
    let scalars = Array(password.unicodeScalars)
    guard scalars.count >= 2 else {
        return 0
    }

    var longestRun = 0
    var ascendingLength = 1
    var descendingLength = 1

    for index in 1..<scalars.count {
        let previous = scalars[index - 1]
        let current = scalars[index]
        let isComparable = isASCIILetterOrDigit(previous) && isASCIILetterOrDigit(current)

        if isComparable && current.value == previous.value + 1 {
            ascendingLength += 1
        } else {
            ascendingLength = 1
        }

        if isComparable && previous.value == current.value + 1 {
            descendingLength += 1
        } else {
            descendingLength = 1
        }

        longestRun = max(longestRun, ascendingLength, descendingLength)
    }

    return longestRun >= 4 ? longestRun : 0
}

private nonisolated func isASCIILetterOrDigit(_ scalar: UnicodeScalar) -> Bool {
    (48...57).contains(scalar.value) || (97...122).contains(scalar.value)
}

private nonisolated func getLongestKeyboardRunLength(_ password: String) -> Int {
    let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm", "1234567890"]
    var longestRun = 0

    for row in rows {
        let rowCharacters = Array(row)

        for length in 4...rowCharacters.count {
            for startIndex in 0...(rowCharacters.count - length) {
                let segment = String(rowCharacters[startIndex..<(startIndex + length)])
                if password.contains(segment) || password.contains(String(segment.reversed())) {
                    longestRun = max(longestRun, length)
                }
            }
        }
    }

    return longestRun
}

private nonisolated func getLongestRepeatedCharacterRunLength(_ password: String) -> Int {
    let characters = Array(password)
    guard !characters.isEmpty else {
        return 0
    }

    var runLength = 1
    var longestRun = 1
    for index in 1..<characters.count {
        if characters[index] == characters[index - 1] {
            runLength += 1
            longestRun = max(longestRun, runLength)
        } else {
            runLength = 1
        }
    }

    return longestRun >= 4 ? longestRun : 0
}

private nonisolated func getLongestRepeatedBlockLength(_ password: String) -> Int {
    let characters = Array(password)
    guard characters.count >= 6 else {
        return 0
    }

    var longestRun = 0
    for blockLength in 2...4 where characters.count >= blockLength * 3 {
        for startIndex in 0...(characters.count - blockLength * 3) {
            let block = Array(characters[startIndex..<(startIndex + blockLength)])
            var repeatCount = 1
            var nextStart = startIndex + blockLength

            while nextStart + blockLength <= characters.count {
                let nextBlock = Array(characters[nextStart..<(nextStart + blockLength)])
                guard nextBlock == block else {
                    break
                }

                repeatCount += 1
                if repeatCount >= 3 {
                    longestRun = max(longestRun, repeatCount * blockLength)
                }

                nextStart += blockLength
            }
        }
    }

    return longestRun
}

private nonisolated func getLongestDateLikeDigitsLength(_ password: String) -> Int {
    let digitRuns = password.split { !$0.isNumber }.map(String.init)
    var longestRun = 0

    for run in digitRuns where run.count >= 6 {
        let digits = Array(run)

        if digits.count >= 8 {
            for startIndex in 0...(digits.count - 8) {
                if isValidDateDigits(String(digits[startIndex..<(startIndex + 8)]), yearLength: 4) {
                    longestRun = max(longestRun, 8)
                }
            }
        }

        for startIndex in 0...(digits.count - 6) {
            if isValidDateDigits(String(digits[startIndex..<(startIndex + 6)]), yearLength: 2) {
                longestRun = max(longestRun, 6)
            }
        }
    }

    return longestRun
}

private nonisolated func isValidDateDigits(_ digits: String, yearLength: Int) -> Bool {
    let characters = Array(digits)
    let monthStart = yearLength
    let dayStart = yearLength + 2

    guard characters.count == yearLength + 4,
          let month = Int(String(characters[monthStart..<dayStart])),
          let day = Int(String(characters[dayStart..<(dayStart + 2)])) else {
        return false
    }

    return (1...12).contains(month) && (1...31).contains(day)
}

private nonisolated func estimateEntropy(charsetSize: Int, length: Int) -> Double {
    guard charsetSize > 0 else {
        return 0
    }

    return (Double(length) * log2(Double(charsetSize)) * 10).rounded() / 10
}

private func copyToPasteboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

private nonisolated func formatNumber<T: BinaryInteger>(_ value: T) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: Int(value))) ?? "\(value)"
}

private nonisolated func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = value.rounded(.towardZero) == value ? 0 : 1
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func formatCountRange(_ minimum: Int, _ maximum: Int) -> String {
    if minimum == maximum {
        return "\(formatNumber(minimum)) のみ"
    }

    return "\(formatNumber(minimum))〜\(formatNumber(maximum))"
}

private func normalizeFullWidthDigits(_ value: String) -> String {
    var scalars = String.UnicodeScalarView()

    for scalar in value.unicodeScalars {
        let scalarValue = scalar.value

        if (0xFF10...0xFF19).contains(scalarValue), let convertedScalar = UnicodeScalar(scalarValue - 0xFEE0) {
            scalars.append(convertedScalar)
        } else {
            scalars.append(scalar)
        }
    }

    return String(scalars)
}

private extension View {
    func nativeCardStyle(palette: NativeThemePalette) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.panelBorder, lineWidth: 1)
            )
    }
}

private extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
