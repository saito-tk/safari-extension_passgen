//
//  NativePasswordGeneratorView.swift
//  Passgen
//
//  Created by Codex on 2026/04/05.
//

import AppKit
import Combine
import CryptoKit
import Security
import SwiftUI
import UniformTypeIdentifiers

nonisolated private let nativeSymbolOptions: [NativeSymbolOption] = [
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
nonisolated private let uppercaseCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
nonisolated private let lowercaseCharacters = "abcdefghijklmnopqrstuvwxyz"
nonisolated private let digitCharacters = "0123456789"

struct NativePasswordGeneratorView: View {
    @StateObject var viewModel: NativePasswordGeneratorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: NativeFocusedField?
    @State private var activeCharacterTab: NativeCharacterTab = .uppercase
    @State private var presetPendingDeletion: NativePasswordPreset?
    @State private var isSavedSettingsHelpPresented = false
    @State private var isCharacterEditorHelpPresented = false
    @State private var isRulesHelpPresented = false
    @State private var isStrengthHelpPresented = false
    @State private var isPresetExportSheetPresented = false

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
        .sheet(isPresented: $isPresetExportSheetPresented) {
            NativePresetExportSelectionSheet(
                viewModel: viewModel,
                palette: palette,
                isPresented: $isPresetExportSheetPresented
            )
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

                Button {
                    isSavedSettingsHelpPresented.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accentStrong)
                }
                .buttonStyle(.plain)
                .help("保存済み設定の説明")
                .popover(isPresented: $isSavedSettingsHelpPresented, arrowEdge: .top) {
                    savedSettingsHelpPopover(palette: palette)
                }

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
                    Text(viewModel.presetSaveButtonTitle)
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

                    Menu {
                        Button("エクスポート...") {
                            viewModel.preparePresetExportSelection()
                            isPresetExportSheetPresented = true
                        }
                        .disabled(!viewModel.canStartPresetExport)

                        Button("インポート...") {
                            viewModel.importPresetsFromJSON()
                        }
                        .disabled(!viewModel.canImportPresets)
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.accentStrong)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(viewModel.isGenerating ? palette.disabledBackground : palette.accentSoft)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(viewModel.isGenerating)
                    .help("プリセットのインポート/エクスポート")
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

                        HStack(spacing: 0) {
                            Button {
                                viewModel.selectPreset(id: preset.id)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(isSelected ? palette.accent : Color.clear)
                                        .frame(width: 4)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(preset.name)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                                                .lineLimit(2)

                                            if preset.isLocked {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.accentStrong)
                                                    .help("ロック中")
                                            }
                                        }

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
                                .padding(.leading, 12)
                                .padding(.vertical, 12)
                                .padding(.trailing, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isGenerating)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                            Menu {
                                Button {
                                    viewModel.togglePresetLock(id: preset.id)
                                } label: {
                                    Label(preset.isLocked ? "ロック解除" : "ロック", systemImage: preset.isLocked ? "lock.open" : "lock")
                                }

                                Button("削除", role: .destructive) {
                                    if preset.isLocked {
                                        viewModel.showLockedPresetDeletionMessage()
                                    } else {
                                        presetPendingDeletion = preset
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
                                    .frame(width: 28, height: 28)
                            }
                            .padding(.trailing, 12)
                            .menuStyle(.borderlessButton)
                            .disabled(viewModel.isGenerating)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                Button(action: viewModel.toggleGeneration) {
                    Text(viewModel.generationButtonTitle)
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
                .disabled(viewModel.isCancellingGeneration)
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
            sectionHeaderWithHelp(
                title: "文字選択エディタ",
                isPresented: $isCharacterEditorHelpPresented,
                palette: palette
            ) {
                characterEditorHelpPopover(palette: palette)
            }

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
        let foregroundColor = isSelected ? Color.white : (viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surfaceStrong)
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
        .disabled(viewModel.isPasswordSettingsEditingDisabled)
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
                        .fill(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surfaceStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.panelBorder, lineWidth: 1)
                )
                .foregroundStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.ink)
                .disabled(viewModel.isPasswordSettingsEditingDisabled)

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
            .foregroundStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.muted)
            .disabled(viewModel.isPasswordSettingsEditingDisabled)
        }
    }

    private func characterSelectionButton(
        tab: NativeCharacterTab,
        index: Int,
        character: String,
        isSelected: Bool,
        palette: NativeThemePalette
    ) -> some View {
        let foregroundColor = isSelected ? Color.white : (viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surfaceStrong)
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
        .disabled(viewModel.isPasswordSettingsEditingDisabled)
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
            sectionHeaderWithHelp(
                title: "生成ルール",
                isPresented: $isRulesHelpPresented,
                palette: palette
            ) {
                generationRulesHelpPopover(palette: palette)
            }

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
                            .fill(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.panelBorder, lineWidth: 1)
                    )
                    .foregroundStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.ink)
                    .disabled(viewModel.isPasswordSettingsEditingDisabled)
                }
            }
            .opacity(viewModel.usesRulePriorityMode ? 1 : 0.56)
            .disabled(!viewModel.usesRulePriorityMode || viewModel.isPasswordSettingsEditingDisabled)
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func firstCharacterChip(tab: NativeCharacterTab, title: String, palette: NativeThemePalette) -> some View {
        let isSelected = viewModel.isFirstCharacterAllowed(for: tab)
        let foregroundColor = isSelected ? Color.white : (viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.muted)
        let backgroundView: AnyShapeStyle = isSelected
            ? AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentStrong], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surfaceStrong)
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
        .disabled(viewModel.isPasswordSettingsEditingDisabled)
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
                .disabled(viewModel.isPasswordSettingsEditingDisabled)
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
                .disabled(viewModel.isPasswordSettingsEditingDisabled)
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
                    resultMetadataSummary(resultMetadata, generationHash: viewModel.generationHashText, palette: palette)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.results) { password in
                            NativePasswordRow(
                                password: password,
                                isCopied: viewModel.copiedPasswordIDs.contains(password.id),
                                characterCompositionHelpTextProvider: {
                                    viewModel.characterCompositionHelpText(for: password.id)
                                },
                                palette: palette
                            ) {
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

    private func resultMetadataSummary(_ metadata: NativePasswordResultMetadata, generationHash: String?, palette: NativeThemePalette) -> some View {
        HStack(spacing: 6) {
            resultMetadataChip("推定エントロピー: \(formatNumber(metadata.entropy)) bits", palette: palette)
                .help("固定文字を除いた生成条件全体で共通の推定エントロピー")
            resultMetadataChip(metadata.conditionSummary, palette: palette)
                .help("生成に使える文字セット数と文字カテゴリ数")
            Spacer(minLength: 0)
            if let generationHash {
                resultMetadataChip("ハッシュ: \(generationHash)", palette: palette)
                    .help("この生成結果セットを識別する短縮ハッシュ。テキスト出力ファイル名にも使われます。")
            }
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

    private func characterEditorHelpPopover(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("文字選択エディタについて")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)

                strengthHelpSection(
                    title: "ここで決めること",
                    rows: [
                        ("文字種", "大文字、小文字、数字、記号の中から、生成に使う文字の種類を選びます。"),
                        ("個別選択", "文字を個別にオン / オフできます。オフにした文字は、生成候補から外れます。"),
                        ("記号", "使いたい記号だけを選べます。記号文字列を貼り付けて、まとめて反映することもできます。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "確認のしかた",
                    rows: [
                        ("現在選択中の文字", "最終的に生成候補へ入る文字を確認する欄です。薄く表示されている文字は候補に入りません。"),
                        ("生成結果への影響", "候補に入る文字が多いほど、同じ文字数でも総当たり耐性が上がりやすくなります。")
                    ],
                    palette: palette
                )
            }
            .padding(16)
        }
        .frame(width: 430, height: 360, alignment: .leading)
        .background(palette.surface)
    }

    private func savedSettingsHelpPopover(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("保存済み設定について")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)

                strengthHelpSection(
                    title: "保存と更新",
                    rows: [
                        ("保存", "現在の文字数、件数、文字選択、生成ルールを名前付きのプリセットとして保存します。"),
                        ("更新", "プリセット選択中に内容や名前を変えた場合は、保存済みのプリセットを更新できます。"),
                        ("ロック", "よく使うプリセットをロックすると、選択中でも文字選択や生成ルールを変更できなくなり、更新や削除もできません。文字数と件数は変更できます。"),
                        ("テーマ", "表示テーマはアプリ全体の見た目設定なので、プリセットには含まれません。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "一覧の使い方",
                    rows: [
                        ("選択", "プリセットを選ぶと、その設定が中央カラムに反映されます。"),
                        ("選択解除", "選択中のプリセットをもう一度選ぶと、選択前の未保存設定に戻ります。"),
                        ("ソート", "名前、作成日、更新日で並び替えできます。日付で並べると、該当する日付も表示します。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "削除",
                    rows: [
                        ("設定ボタン", "各プリセット行の設定ボタンからロック、ロック解除、削除を選べます。"),
                        ("確認", "削除前に確認ダイアログを表示します。ロック中は削除できず、確認ダイアログも表示しません。")
                    ],
                    palette: palette
                )
            }
            .padding(16)
        }
        .frame(width: 430, height: 430, alignment: .leading)
        .background(palette.surface)
    }

    private func generationRulesHelpPopover(palette: NativeThemePalette) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("生成ルールについて")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)

                strengthHelpSection(
                    title: "生成方式",
                    rows: [
                        ("完全一様", "選んだ文字の中から、できるだけ公平に選ぶ方式です。細かい条件より、偏りの少なさを優先します。"),
                        ("ルール優先", "先頭文字や必ず含める文字種など、サービスごとの条件に合わせやすい方式です。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "追加ルール",
                    rows: [
                        ("似た文字を除外する", "`I`、`l`、`1`、`O`、`0` など、見間違えやすい文字を避けます。"),
                        ("選択した文字種を必ず含める", "大文字や数字など、選んだ文字種が少なくとも 1 文字ずつ入るようにします。"),
                        ("同じ文字を連続させない", "`aa` や `11` のように同じ文字が続く並びを避けます。")
                    ],
                    palette: palette
                )

                strengthHelpSection(
                    title: "先頭文字の設定",
                    rows: [
                        ("文字種", "先頭に使ってよい文字種を選びます。"),
                        ("固定文字", "指定した文字列を必ず先頭に付けます。固定文字は他人に知られている前提で強度を見積もります。")
                    ],
                    palette: palette
                )

                Text("一部の追加ルールは `ルール優先` のときに使えます。`完全一様` では、選んだ文字から公平に選ぶことを優先します。")
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

    private func sectionHeaderWithHelp<HelpContent: View>(
        title: String,
        isPresented: Binding<Bool>,
        palette: NativeThemePalette,
        @ViewBuilder helpContent: @escaping () -> HelpContent
    ) -> some View {
        HStack(spacing: 8) {
            sectionHeader(title: title)

            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accentStrong)
            }
            .buttonStyle(.plain)
            .help("\(title)の説明")
            .popover(isPresented: isPresented, arrowEdge: .top) {
                helpContent()
            }

            Spacer(minLength: 0)
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
                .foregroundStyle(viewModel.isNumericSettingsEditingDisabled ? palette.disabledText : palette.ink)
                .disabled(viewModel.isNumericSettingsEditingDisabled)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(viewModel.isNumericSettingsEditingDisabled ? palette.disabledBackground : palette.surface)
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
                .foregroundStyle(selected ? palette.accentStrong : (viewModel.isPasswordSettingsEditingDisabled ? palette.disabledText : palette.ink))
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 42, alignment: compact ? .center : .leading)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selected ? palette.accent.opacity(0.14) : (viewModel.isPasswordSettingsEditingDisabled ? palette.disabledBackground : palette.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? palette.accent.opacity(0.32) : palette.panelBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPasswordSettingsEditingDisabled || !isEnabled)
        .opacity(isEnabled ? 1 : 0.56)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .fixedSize(horizontal: compact, vertical: false)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
    }

}

private struct NativePresetExportSelectionSheet: View {
    @ObservedObject var viewModel: NativePasswordGeneratorViewModel
    let palette: NativeThemePalette
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Text("エクスポートするプリセット")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.ink)

                Spacer(minLength: 0)

                Text("\(viewModel.selectedPresetExportCount)件選択中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.muted)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.sortedPresets) { preset in
                        Button {
                            viewModel.togglePresetExportSelection(id: preset.id)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: viewModel.isPresetSelectedForExport(id: preset.id) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(viewModel.isPresetSelectedForExport(id: preset.id) ? palette.accentStrong : palette.muted)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(preset.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(palette.ink)
                                            .lineLimit(2)

                                        if preset.isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(palette.accentStrong)
                                        }
                                    }

                                    Text(viewModel.presetConditionSummary(for: preset))
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(viewModel.isPresetSelectedForExport(id: preset.id) ? palette.accent.opacity(0.55) : palette.panelBorder, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 260)

            HStack(spacing: 10) {
                Button("すべて選択") {
                    viewModel.selectAllPresetsForExport()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentStrong)

                Button("すべて解除") {
                    viewModel.clearPresetExportSelection()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.muted)

                Spacer(minLength: 0)

                Button("キャンセル") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.muted)

                Button {
                    if viewModel.exportSelectedPresetsAsJSON() {
                        isPresented = false
                    }
                } label: {
                    Text("エクスポート")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.canExportSelectedPresets ? Color.white : palette.disabledText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.canExportSelectedPresets ? palette.accent : palette.disabledBackground)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canExportSelectedPresets)
            }
        }
        .padding(18)
        .frame(width: 460, height: 520)
        .background(palette.surfaceSoft)
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
    private var isApplyingNumericCorrection = false

    @Published var lengthText: String {
        didSet {
            let normalizedText = normalizeFullWidthDigits(lengthText)
            if normalizedText != lengthText {
                lengthText = normalizedText
                return
            }

            clearNumericCorrectionWarningIfNeeded(previousText: oldValue, currentText: lengthText)
        }
    }

    @Published var countText: String {
        didSet {
            let normalizedText = normalizeFullWidthDigits(countText)
            if normalizedText != countText {
                countText = normalizedText
                return
            }

            clearNumericCorrectionWarningIfNeeded(previousText: oldValue, currentText: countText)
        }
    }
    @Published var symbolImportText = ""
    @Published var settingsStatus = NativeInlineStatus()
    @Published var resultStatus = NativeInlineStatus()
    @Published var results: [NativeGeneratedPasswordListItem] = []
    @Published private(set) var copiedPasswordIDs: Set<UUID> = []
    @Published var progressCompleted = 0
    @Published var progressTotal = 0
    @Published var isGenerating = false
    @Published var isCancellingGeneration = false
    @Published var isSavedSettingsSidebarVisible = true
    @Published var presetNameText = ""
    @Published var presetStatus = NativeInlineStatus()
    @Published var presets: [NativePasswordPreset] = []
    @Published var selectedPresetID: String?
    @Published var presetSortKey: NativePresetSortKey = .name
    @Published var presetSortDirection: NativePresetSortDirection = .ascending
    @Published var presetExportSelectionIDs: Set<String> = []

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

    var generationButtonTitle: String {
        if isCancellingGeneration {
            return "停止中..."
        }

        return isGenerating ? "停止" : "生成"
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
        !symbolImportText.isEmpty && canEditPasswordSettings
    }

    var canEditPasswordSettings: Bool {
        !isGenerating && selectedPreset?.isLocked != true
    }

    var isPasswordSettingsEditingDisabled: Bool {
        !canEditPasswordSettings
    }

    var canEditNumericSettings: Bool {
        !isGenerating
    }

    var isNumericSettingsEditingDisabled: Bool {
        !canEditNumericSettings
    }

    var isSelectedPresetLocked: Bool {
        selectedPreset?.isLocked == true
    }

    var presetSaveButtonTitle: String {
        if isSelectedPresetLocked {
            return "ロック中"
        }

        return selectedPresetID == nil ? "保存" : "更新"
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

        guard !selectedPreset.isLocked else {
            return false
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

    var canImportPresets: Bool {
        !isGenerating
    }

    var canStartPresetExport: Bool {
        !isGenerating && !presets.isEmpty
    }

    var canExportSelectedPresets: Bool {
        !isGenerating && !presetExportSelectionIDs.isEmpty
    }

    var selectedPresetExportCount: Int {
        presetExportSelectionIDs.count
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

    var generationHashText: String? {
        guard !results.isEmpty, let currentGenerationSession else {
            return nil
        }

        return currentGenerationSession.shortHash
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

    func preparePresetExportSelection() {
        presetExportSelectionIDs = Set(sortedPresets.map(\.id))
    }

    func togglePresetExportSelection(id: String) {
        if presetExportSelectionIDs.contains(id) {
            presetExportSelectionIDs.remove(id)
        } else {
            presetExportSelectionIDs.insert(id)
        }
    }

    func isPresetSelectedForExport(id: String) -> Bool {
        presetExportSelectionIDs.contains(id)
    }

    func selectAllPresetsForExport() {
        presetExportSelectionIDs = Set(presets.map(\.id))
    }

    func clearPresetExportSelection() {
        presetExportSelectionIDs = []
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

        if let selectedPreset, selectedPreset.isLocked {
            presetStatus = NativeInlineStatus(message: "ロック中のプリセットは更新できません。", tone: .warning)
            return
        }

        if let lockedPreset = presets.first(where: { $0.name == name && $0.id != selectedPresetID && $0.isLocked }) {
            presetStatus = NativeInlineStatus(message: "「\(lockedPreset.name)」はロック中のため上書きできません。", tone: .warning)
            return
        }

        if let selectedPresetID,
           let selectedIndex = presets.firstIndex(where: { $0.id == selectedPresetID }) {
            let selectedPreset = presets[selectedIndex]
            let updatedPreset = NativePasswordPreset(
                id: selectedPreset.id,
                name: name,
                createdAt: selectedPreset.createdAt,
                updatedAt: now,
                isLocked: selectedPreset.isLocked,
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
                isLocked: existingPreset.isLocked,
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
                isLocked: false,
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

    func togglePresetLock(id: String) {
        guard !isGenerating, let presetIndex = presets.firstIndex(where: { $0.id == id }) else {
            return
        }

        presets[presetIndex].isLocked.toggle()
        presets[presetIndex].updatedAt = Date()

        let preset = presets[presetIndex]
        if selectedPresetID == preset.id {
            presetNameText = preset.name

            if preset.isLocked {
                applySettings(preset.settings.applying(to: settings))
            }
        }

        persistPresets()
        presetStatus = NativeInlineStatus(message: preset.isLocked ? "「\(preset.name)」をロックしました。" : "「\(preset.name)」のロックを解除しました。")
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
        let settings = preset.settings.applying(to: NativePasswordSettings.defaultSettings)
        let condition = Self.conditionSummary(for: settings).replacingOccurrences(of: "/", with: " / ")
        return "文字数 \(formatNumber(settings.length))\n\(condition)"
    }

    func deletePreset(id: String) {
        guard !isGenerating, let deletedIndex = presets.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard !presets[deletedIndex].isLocked else {
            showLockedPresetDeletionMessage()
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

    func showLockedPresetDeletionMessage() {
        presetStatus = NativeInlineStatus(message: "ロック中のため削除できません。", tone: .warning)
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

        guard !isGenerating else {
            lengthText = String(settings.length)
            countText = String(settings.count)
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
        guard canEditPasswordSettings else {
            return
        }

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
        guard canEditPasswordSettings else {
            return
        }

        settings.firstCharacterMode = mode
        persistSettings()
    }

    func selectGenerationMode(_ mode: NativeGenerationMode) {
        guard canEditPasswordSettings else {
            return
        }

        settings.generationMode = mode
        persistSettings()
    }

    func toggleExcludeSimilar() {
        guard canEditPasswordSettings else {
            return
        }

        settings.excludeSimilar.toggle()
        persistSettings()
    }

    func toggleRequireEachSelectedType() {
        guard canEditPasswordSettings else {
            return
        }

        settings.requireEachSelectedType.toggle()
        persistSettings()
    }

    var disallowConsecutiveDuplicates: Bool {
        settings.maxConsecutiveRun == 1
    }

    func toggleDisallowConsecutiveDuplicates() {
        guard canEditPasswordSettings else {
            return
        }

        settings.maxConsecutiveRun = settings.maxConsecutiveRun == 1 ? 0 : 1
        persistSettings()
    }

    func updateFixedPrefix(_ value: String) {
        guard canEditPasswordSettings else {
            return
        }

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
        guard canEditPasswordSettings else {
            return
        }

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
        guard canEditPasswordSettings else {
            return
        }

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
        guard canEditPasswordSettings else {
            return
        }

        guard settings.symbols.indices.contains(index) else {
            return
        }

        settings.symbols[index].toggle()
        syncSelectAllState()
        syncCategorySelectionFlags()
        persistSettings()
    }

    func setAllSymbols(selected: Bool) {
        guard canEditPasswordSettings else {
            return
        }

        settings.symbols = Array(repeating: selected, count: nativeSymbolOptions.count)
        syncSelectAllState()
        syncCategorySelectionFlags()
        persistSettings()
    }

    func applyImportedSymbols() {
        guard canEditPasswordSettings else {
            return
        }

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
            copiedPasswordIDs = []
            currentGenerationSession = nil
            progressCompleted = 0
            progressTotal = 0
            return
        }

        generationTask?.cancel()
        results = []
        generatedPasswordStore = [:]
        copiedPasswordIDs = []
        currentGenerationSession = NativeGenerationSession()
        progressCompleted = 0
        progressTotal = settings.count
        isGenerating = true
        isCancellingGeneration = false

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
                    self.isCancellingGeneration = false
                    self.generationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isGenerating = false
                    self.isCancellingGeneration = false
                    self.generationTask = nil
                    self.resultStatus = NativeInlineStatus(message: "生成を停止しました。")
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.isCancellingGeneration = false
                    self.generationTask = nil
                    self.generatedPasswordStore = [:]
                    self.copiedPasswordIDs = []
                    self.resultStatus = NativeInlineStatus(message: "条件に合うパスワードを生成できませんでした。", tone: .error)
                }
            }
        }
    }

    func toggleGeneration() {
        if isGenerating {
            cancelGeneration()
        } else {
            generate()
        }
    }

    func cancelGeneration() {
        guard isGenerating, !isCancellingGeneration else {
            return
        }

        isCancellingGeneration = true
        generationTask?.cancel()
    }

    func copyPassword(id: UUID) {
        guard let value = generatedPasswordStore[id] else {
            return
        }

        copyToPasteboard(value)
        copiedPasswordIDs.insert(id)
    }

    func characterCompositionHelpText(for id: UUID) -> String {
        guard let value = generatedPasswordStore[id] else {
            return "文字種の内訳を取得できません。"
        }

        return NativePasswordCharacterComposition(password: value).detailText
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

    func exportSelectedPresetsAsJSON() -> Bool {
        guard canExportSelectedPresets else {
            presetStatus = NativeInlineStatus(message: "エクスポートするプリセットを選択してください。", tone: .warning)
            return false
        }

        let selectedPresets = sortedPresets.filter { presetExportSelectionIDs.contains($0.id) }
        guard !selectedPresets.isEmpty else {
            presetStatus = NativeInlineStatus(message: "エクスポートするプリセットを選択してください。", tone: .warning)
            return false
        }

        let document = NativePresetExportDocument(exportedAt: Date(), presets: selectedPresets)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(document)
        } catch {
            presetStatus = NativeInlineStatus(message: "プリセットのJSON作成に失敗しました。", tone: .error)
            return false
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = defaultPresetExportFilename()
        savePanel.title = "プリセットを書き出す"
        savePanel.message = "選択したプリセットをJSONファイルとして保存します。"

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else {
            return false
        }

        do {
            try data.write(to: url, options: .atomic)
            presetStatus = NativeInlineStatus(message: "\(selectedPresets.count)件のプリセットをエクスポートしました。")
            return true
        } catch {
            presetStatus = NativeInlineStatus(message: "プリセットのエクスポートに失敗しました。保存先を確認してください。", tone: .error)
            return false
        }
    }

    func importPresetsFromJSON() {
        guard canImportPresets else {
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "プリセットを読み込む"
        openPanel.message = "PassgenのプリセットJSONファイルを選択してください。"

        let response = openPanel.runModal()
        guard response == .OK, let url = openPanel.url else {
            return
        }

        let importedPresets: [NativePasswordPreset]
        do {
            let data = try Data(contentsOf: url)
            importedPresets = try Self.decodePresetExportDocument(from: data)
        } catch let error as NativePresetImportError {
            presetStatus = NativeInlineStatus(message: error.message, tone: .error)
            return
        } catch {
            presetStatus = NativeInlineStatus(message: "プリセットJSONを読み込めませんでした。ファイルを確認してください。", tone: .error)
            return
        }

        let existingIDs = Set(presets.map(\.id))
        let duplicatedPresets = importedPresets.filter { existingIDs.contains($0.id) }

        if !duplicatedPresets.isEmpty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "すでに取り込み済みのプリセットがあります。"
            alert.informativeText = "同じUUIDのプリセットが\(duplicatedPresets.count)件あります。別名でインポートすると、UUIDを再発行して追加します。"
            alert.addButton(withTitle: "別名でインポート")
            alert.addButton(withTitle: "キャンセル")

            guard alert.runModal() == .alertFirstButtonReturn else {
                presetStatus = NativeInlineStatus(message: "プリセットのインポートをキャンセルしました。")
                return
            }
        }

        var knownIDs = existingIDs
        var knownNames = Set(presets.map(\.name))
        let preparedPresets = importedPresets.map { importedPreset in
            let normalizedPreset = Self.normalizedImportedPreset(importedPreset)

            if knownIDs.contains(normalizedPreset.id) {
                let renamedPreset = NativePasswordPreset(
                    id: UUID().uuidString,
                    name: Self.uniqueImportedPresetName(baseName: normalizedPreset.name, existingNames: &knownNames),
                    createdAt: normalizedPreset.createdAt,
                    updatedAt: Date(),
                    isLocked: normalizedPreset.isLocked,
                    settings: normalizedPreset.settings
                )
                knownIDs.insert(renamedPreset.id)
                return renamedPreset
            }

            knownIDs.insert(normalizedPreset.id)
            knownNames.insert(normalizedPreset.name)
            return normalizedPreset
        }

        guard !preparedPresets.isEmpty else {
            presetStatus = NativeInlineStatus(message: "インポートできるプリセットがありません。", tone: .warning)
            return
        }

        presets.insert(contentsOf: preparedPresets, at: 0)
        persistPresets()
        presetStatus = NativeInlineStatus(message: "\(preparedPresets.count)件のプリセットをインポートしました。")
    }

    private func defaultTextExportFilename() -> String {
        let session = currentGenerationSession ?? NativeGenerationSession()
        return "passgen-\(Self.formatGenerationTimestamp(session.createdAt))-\(session.shortHash).txt"
    }

    private func defaultPresetExportFilename() -> String {
        "passgen-presets-\(Self.formatGenerationTimestamp(Date())).json"
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
        guard !isGenerating else {
            lengthText = String(settings.length)
            countText = String(settings.count)
            return
        }

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
        isApplyingNumericCorrection = true
        lengthText = String(normalizedLength)
        countText = String(normalizedCount)
        isApplyingNumericCorrection = false
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
        guard !isApplyingNumericCorrection, previousText != currentText, settingsStatus.tone == .warning else {
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

    private static func decodePresetExportDocument(from data: Data) throws -> [NativePasswordPreset] {
        let object = try JSONSerialization.jsonObject(with: data)
        let version = try presetExportVersion(from: object)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch version {
        case NativePresetExportDocument.currentVersion:
            return try decodePresetExport(from: data, object: object, decoder: decoder)
        default:
            throw NativePresetImportError(message: "対応していないプリセットJSONのバージョンです。")
        }
    }

    private static func presetExportVersion(from object: Any) throws -> Int {
        guard let root = object as? [String: Any],
              let presetObjects = root["presets"] as? [[String: Any]],
              !presetObjects.isEmpty else {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        if let format = root["format"] as? String,
           format != NativePresetExportDocument.formatIdentifier {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        guard let version = integerValue(root["version"]) else {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        return version
    }

    private static func decodePresetExport(from data: Data, object: Any, decoder: JSONDecoder) throws -> [NativePasswordPreset] {
        try validatePresetExportObject(object)

        let document = try decoder.decode(NativePresetExportPayload.self, from: data)
        guard !document.presets.isEmpty else {
            throw NativePresetImportError(message: "インポートできるプリセットがありません。")
        }

        var importedIDs = Set<String>()
        return try document.presets.map { preset in
            guard UUID(uuidString: preset.id) != nil else {
                throw NativePresetImportError(message: "プリセットJSONに不正なUUIDが含まれています。")
            }

            guard importedIDs.insert(preset.id).inserted else {
                throw NativePresetImportError(message: "プリセットJSON内に重複したUUIDがあります。")
            }

            let sanitizedName = sanitizePresetName(preset.name)
            guard !sanitizedName.isEmpty, sanitizedName == preset.name else {
                throw NativePresetImportError(message: "プリセットJSONに不正なプリセット名が含まれています。")
            }

            try validatePresetSettings(preset.settings)
            return normalizedImportedPreset(preset)
        }
    }

    private static func validatePresetExportObject(_ object: Any) throws {
        guard let root = object as? [String: Any] else {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        let rootKeys = Set(root.keys)
        let allowedRootKeys: Set<String> = ["format", "version", "exportedAt", "presets"]
        guard rootKeys.isSubset(of: allowedRootKeys),
              rootKeys.contains("presets") else {
            throw NativePresetImportError(message: "プリセットJSONの項目が正しくありません。")
        }

        if let format = root["format"] as? String,
           format != NativePresetExportDocument.formatIdentifier {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        guard let decodedVersion = integerValue(root["version"]),
              decodedVersion == NativePresetExportDocument.currentVersion else {
            throw NativePresetImportError(message: "対応していないプリセットJSONのバージョンです。")
        }

        if let exportedAt = root["exportedAt"] as? String,
           ISO8601DateFormatter().date(from: exportedAt) == nil {
            throw NativePresetImportError(message: "プリセットJSONの日時が正しくありません。")
        }

        guard let presetObjects = root["presets"] as? [[String: Any]],
              !presetObjects.isEmpty else {
            throw NativePresetImportError(message: "プリセットJSONの形式が正しくありません。")
        }

        try presetObjects.forEach(validatePresetObject)
    }

    private static func validatePresetObject(_ object: [String: Any]) throws {
        let presetKeys = Set(object.keys)
        guard presetKeys == ["id", "name", "createdAt", "updatedAt", "isLocked", "settings"] else {
            throw NativePresetImportError(message: "プリセットJSONのプリセット項目が正しくありません。")
        }

        guard let id = object["id"] as? String,
              UUID(uuidString: id) != nil,
              let name = object["name"] as? String,
              !sanitizePresetName(name).isEmpty,
              sanitizePresetName(name) == name,
              let createdAt = object["createdAt"] as? String,
              ISO8601DateFormatter().date(from: createdAt) != nil,
              let updatedAt = object["updatedAt"] as? String,
              ISO8601DateFormatter().date(from: updatedAt) != nil,
              object["isLocked"] is Bool,
              let settingsObject = object["settings"] as? [String: Any] else {
            throw NativePresetImportError(message: "プリセットJSONのプリセット値が正しくありません。")
        }

        try validatePresetSettingsObject(settingsObject)
    }

    private static func validatePresetSettingsObject(_ object: [String: Any]) throws {
        let allowedKeys: Set<String> = [
            "uppercase", "lowercase", "digits", "includeSymbols",
            "uppercaseSelections", "lowercaseSelections", "digitSelections", "selectAllSymbols", "selectedSymbols",
            "length", "count", "minimumUppercase", "minimumLowercase", "minimumDigits", "minimumSymbols",
            "generationMode", "excludeSimilar", "requireEachSelectedType",
            "allowUppercaseFirst", "allowLowercaseFirst", "allowDigitsFirst", "allowSymbolsFirst",
            "firstCharacterMode", "fixedPrefix", "maxConsecutiveRun", "excludedCharacters"
        ]
        let requiredKeys: Set<String> = [
            "uppercase", "lowercase", "digits", "includeSymbols",
            "uppercaseSelections", "lowercaseSelections", "digitSelections", "selectAllSymbols",
            "length", "count", "minimumUppercase", "minimumLowercase", "minimumDigits", "minimumSymbols",
            "generationMode", "excludeSimilar", "requireEachSelectedType",
            "firstCharacterMode", "maxConsecutiveRun", "excludedCharacters"
        ]
        let keys = Set(object.keys)

        guard keys.isSubset(of: allowedKeys),
              requiredKeys.isSubset(of: keys),
              keys.contains("selectedSymbols") else {
            throw NativePresetImportError(message: "プリセットJSONの設定項目が正しくありません。")
        }

        guard object["uppercase"] is Bool,
              object["lowercase"] is Bool,
              object["digits"] is Bool,
              object["includeSymbols"] is Bool,
              object["selectAllSymbols"] is Bool,
              object["excludeSimilar"] is Bool,
              object["requireEachSelectedType"] is Bool,
              isBooleanArray(object["uppercaseSelections"], count: uppercaseCharacters.count),
              isBooleanArray(object["lowercaseSelections"], count: lowercaseCharacters.count),
              isBooleanArray(object["digitSelections"], count: digitCharacters.count),
              let length = integerValue(object["length"]),
              let count = integerValue(object["count"]),
              let minimumUppercase = integerValue(object["minimumUppercase"]),
              let minimumLowercase = integerValue(object["minimumLowercase"]),
              let minimumDigits = integerValue(object["minimumDigits"]),
              let minimumSymbols = integerValue(object["minimumSymbols"]),
              let maxConsecutiveRun = integerValue(object["maxConsecutiveRun"]),
              let generationMode = object["generationMode"] as? String,
              NativeGenerationMode(rawValue: generationMode) != nil,
              let firstCharacterMode = object["firstCharacterMode"] as? String,
              let decodedFirstCharacterMode = NativeFirstCharacterMode(rawValue: firstCharacterMode),
              object["excludedCharacters"] is String else {
            throw NativePresetImportError(message: "プリセットJSONの設定値が正しくありません。")
        }

        guard isStringArray(object["selectedSymbols"]) else {
            throw NativePresetImportError(message: "プリセットJSONの設定値が正しくありません。")
        }

        guard length >= nativeMinPasswordLength,
              length <= nativeMaxPasswordLength,
              count >= nativeMinPasswordCount,
              count <= getMaxCountForLength(length),
              minimumUppercase >= 0,
              minimumLowercase >= 0,
              minimumDigits >= 0,
              minimumSymbols >= 0,
              maxConsecutiveRun >= 0,
              maxConsecutiveRun <= nativeMaxConsecutiveRunLimit else {
            throw NativePresetImportError(message: "プリセットJSONの設定値が範囲外です。")
        }

        switch decodedFirstCharacterMode {
        case .characterSet:
            guard object["allowUppercaseFirst"] is Bool,
                  object["allowLowercaseFirst"] is Bool,
                  object["allowDigitsFirst"] is Bool,
                  object["allowSymbolsFirst"] is Bool,
                  object["fixedPrefix"] == nil else {
                throw NativePresetImportError(message: "プリセットJSONの先頭文字設定が正しくありません。")
            }
        case .fixedPrefix:
            guard object["fixedPrefix"] is String,
                  object["allowUppercaseFirst"] == nil,
                  object["allowLowercaseFirst"] == nil,
                  object["allowDigitsFirst"] == nil,
                  object["allowSymbolsFirst"] == nil else {
                throw NativePresetImportError(message: "プリセットJSONの先頭文字設定が正しくありません。")
            }
        }
    }

    private static func validatePresetSettings(_ settings: NativePasswordPresetSettings) throws {
        guard settings.uppercaseSelections.count == uppercaseCharacters.count,
              settings.lowercaseSelections.count == lowercaseCharacters.count,
              settings.digitSelections.count == digitCharacters.count else {
            throw NativePresetImportError(message: "プリセットJSONの文字選択数が正しくありません。")
        }
    }

    private static func normalizedImportedPreset(_ preset: NativePasswordPreset) -> NativePasswordPreset {
        let normalizedSettings = normalizedSettings(from: preset.settings.applying(to: .defaultSettings))
        return NativePasswordPreset(
            id: preset.id,
            name: preset.name,
            createdAt: preset.createdAt,
            updatedAt: preset.updatedAt,
            isLocked: preset.isLocked,
            settings: NativePasswordPresetSettings(settings: normalizedSettings)
        )
    }

    private static func uniqueImportedPresetName(baseName: String, existingNames: inout Set<String>) -> String {
        let sanitizedBaseName = sanitizePresetName(baseName)
        let fallbackBaseName = sanitizedBaseName.isEmpty ? "インポートしたプリセット" : sanitizedBaseName
        var candidate = "\(fallbackBaseName) のコピー"
        var index = 2

        while existingNames.contains(candidate) {
            candidate = "\(fallbackBaseName) のコピー \(index)"
            index += 1
        }

        existingNames.insert(candidate)
        return candidate
    }

    private static func isBooleanArray(_ value: Any?, count: Int? = nil) -> Bool {
        guard let array = value as? [Any] else {
            return false
        }

        if let count, array.count != count {
            return false
        }

        return array.allSatisfy { $0 is Bool }
    }

    private static func isStringArray(_ value: Any?) -> Bool {
        guard let array = value as? [Any] else {
            return false
        }

        return array.allSatisfy { $0 is String }
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }

        guard let numberValue = value as? NSNumber, CFGetTypeID(numberValue) != CFBooleanGetTypeID() else {
            return nil
        }

        return numberValue.intValue
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

    fileprivate static func symbolSelections(from selectedSymbols: [String]) -> [Bool] {
        let selectedValues = Set(selectedSymbols)
        return nativeSymbolOptions.map { selectedValues.contains($0.value) }
    }

    fileprivate static func selectedSymbolValues(from selections: [Bool]) -> [String] {
        zip(nativeSymbolOptions, selections).compactMap { option, isSelected in
            isSelected ? option.value : nil
        }
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
            try Task.checkCancellation()
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
                try Task.checkCancellation()
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
            try Task.checkCancellation()
            passwordCharacters.append(characters[try randomInt(upperBound: characters.count)])
            iterationsSinceYield += 1

            if iterationsSinceYield >= nativePasswordYieldInterval {
                iterationsSinceYield = 0
                try Task.checkCancellation()
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
        case selectedSymbols
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
        symbols = NativePasswordGeneratorViewModel.symbolSelections(
            from: try container.decodeIfPresent([String].self, forKey: .selectedSymbols)
                ?? NativePasswordGeneratorViewModel.selectedSymbolValues(from: Self.defaultSettings.symbols)
        )
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
        try container.encode(NativePasswordGeneratorViewModel.selectedSymbolValues(from: symbols), forKey: .selectedSymbols)
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

private struct NativePresetImportError: Error {
    let message: String
}

private struct NativePresetExportDocument: Codable {
    static let formatIdentifier = "passgen.presets"
    static let currentVersion = 2

    let format: String
    let version: Int
    let exportedAt: Date
    let presets: [NativePasswordPreset]

    init(exportedAt: Date, presets: [NativePasswordPreset]) {
        format = Self.formatIdentifier
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.presets = presets
    }
}

private struct NativePresetExportPayload: Decodable {
    let format: String?
    let version: Int?
    let exportedAt: Date?
    let presets: [NativePasswordPreset]
}

struct NativePasswordPreset: Codable, Identifiable {
    let id: String
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var isLocked: Bool
    var settings: NativePasswordPresetSettings

    init(
        id: String,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        isLocked: Bool = false,
        settings: NativePasswordPresetSettings
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isLocked = isLocked
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case isLocked
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        settings = try container.decode(NativePasswordPresetSettings.self, forKey: .settings)
    }
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

    private enum CodingKeys: String, CodingKey {
        case uppercase
        case lowercase
        case digits
        case includeSymbols
        case uppercaseSelections
        case lowercaseSelections
        case digitSelections
        case selectAllSymbols
        case selectedSymbols
        case length
        case count
        case minimumUppercase
        case minimumLowercase
        case minimumDigits
        case minimumSymbols
        case generationMode
        case excludeSimilar
        case requireEachSelectedType
        case allowUppercaseFirst
        case allowLowercaseFirst
        case allowDigitsFirst
        case allowSymbolsFirst
        case firstCharacterMode
        case fixedPrefix
        case maxConsecutiveRun
        case excludedCharacters
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uppercase = try container.decode(Bool.self, forKey: .uppercase)
        lowercase = try container.decode(Bool.self, forKey: .lowercase)
        digits = try container.decode(Bool.self, forKey: .digits)
        includeSymbols = try container.decode(Bool.self, forKey: .includeSymbols)
        uppercaseSelections = try container.decode([Bool].self, forKey: .uppercaseSelections)
        lowercaseSelections = try container.decode([Bool].self, forKey: .lowercaseSelections)
        digitSelections = try container.decode([Bool].self, forKey: .digitSelections)
        selectAllSymbols = try container.decode(Bool.self, forKey: .selectAllSymbols)
        symbols = NativePasswordGeneratorViewModel.symbolSelections(from: try container.decode([String].self, forKey: .selectedSymbols))
        length = try container.decode(Int.self, forKey: .length)
        count = try container.decode(Int.self, forKey: .count)
        minimumUppercase = try container.decode(Int.self, forKey: .minimumUppercase)
        minimumLowercase = try container.decode(Int.self, forKey: .minimumLowercase)
        minimumDigits = try container.decode(Int.self, forKey: .minimumDigits)
        minimumSymbols = try container.decode(Int.self, forKey: .minimumSymbols)
        generationMode = try container.decode(NativeGenerationMode.self, forKey: .generationMode)
        excludeSimilar = try container.decode(Bool.self, forKey: .excludeSimilar)
        requireEachSelectedType = try container.decode(Bool.self, forKey: .requireEachSelectedType)
        allowUppercaseFirst = try container.decodeIfPresent(Bool.self, forKey: .allowUppercaseFirst)
        allowLowercaseFirst = try container.decodeIfPresent(Bool.self, forKey: .allowLowercaseFirst)
        allowDigitsFirst = try container.decodeIfPresent(Bool.self, forKey: .allowDigitsFirst)
        allowSymbolsFirst = try container.decodeIfPresent(Bool.self, forKey: .allowSymbolsFirst)
        firstCharacterMode = try container.decode(NativeFirstCharacterMode.self, forKey: .firstCharacterMode)
        fixedPrefix = try container.decodeIfPresent(String.self, forKey: .fixedPrefix)
        maxConsecutiveRun = try container.decode(Int.self, forKey: .maxConsecutiveRun)
        excludedCharacters = try container.decode(String.self, forKey: .excludedCharacters)
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
        try container.encode(NativePasswordGeneratorViewModel.selectedSymbolValues(from: symbols), forKey: .selectedSymbols)
        try container.encode(length, forKey: .length)
        try container.encode(count, forKey: .count)
        try container.encode(minimumUppercase, forKey: .minimumUppercase)
        try container.encode(minimumLowercase, forKey: .minimumLowercase)
        try container.encode(minimumDigits, forKey: .minimumDigits)
        try container.encode(minimumSymbols, forKey: .minimumSymbols)
        try container.encode(generationMode, forKey: .generationMode)
        try container.encode(excludeSimilar, forKey: .excludeSimilar)
        try container.encode(requireEachSelectedType, forKey: .requireEachSelectedType)
        try container.encodeIfPresent(allowUppercaseFirst, forKey: .allowUppercaseFirst)
        try container.encodeIfPresent(allowLowercaseFirst, forKey: .allowLowercaseFirst)
        try container.encodeIfPresent(allowDigitsFirst, forKey: .allowDigitsFirst)
        try container.encodeIfPresent(allowSymbolsFirst, forKey: .allowSymbolsFirst)
        try container.encode(firstCharacterMode, forKey: .firstCharacterMode)
        try container.encodeIfPresent(fixedPrefix, forKey: .fixedPrefix)
        try container.encode(maxConsecutiveRun, forKey: .maxConsecutiveRun)
        try container.encode(excludedCharacters, forKey: .excludedCharacters)
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

    var shortHash: String {
        let digest = SHA256.hash(data: Data(id.uuidString.utf8))
        return digest.prefix(6).map { String(format: "%02x", $0) }.joined()
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

struct NativePasswordCharacterComposition {
    let uppercaseCount: Int
    let lowercaseCount: Int
    let digitCount: Int
    let symbolCount: Int
    let otherCount: Int

    nonisolated init(password: String) {
        let uppercaseSet = Set(uppercaseCharacters.map(String.init))
        let lowercaseSet = Set(lowercaseCharacters.map(String.init))
        let digitSet = Set(digitCharacters.map(String.init))
        let symbolSet = Set(nativeSymbolOptions.map(\.value))

        var uppercaseCount = 0
        var lowercaseCount = 0
        var digitCount = 0
        var symbolCount = 0
        var otherCount = 0

        for character in password.map(String.init) {
            if uppercaseSet.contains(character) {
                uppercaseCount += 1
            } else if lowercaseSet.contains(character) {
                lowercaseCount += 1
            } else if digitSet.contains(character) {
                digitCount += 1
            } else if symbolSet.contains(character) {
                symbolCount += 1
            } else {
                otherCount += 1
            }
        }

        self.uppercaseCount = uppercaseCount
        self.lowercaseCount = lowercaseCount
        self.digitCount = digitCount
        self.symbolCount = symbolCount
        self.otherCount = otherCount
    }

    var detailText: String {
        var rows = [
            "文字種の内訳",
            "大文字: \(formatNumber(uppercaseCount))",
            "小文字: \(formatNumber(lowercaseCount))",
            "数字: \(formatNumber(digitCount))",
            "記号: \(formatNumber(symbolCount))"
        ]

        if otherCount > 0 {
            rows.append("その他: \(formatNumber(otherCount))")
        }

        return rows.joined(separator: "\n")
    }
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
    let isCopied: Bool
    let characterCompositionHelpTextProvider: () -> String
    let palette: NativeThemePalette
    let onCopy: () -> Void
    @State private var characterCompositionHelpText: String?
    @State private var showCopyFeedback = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                NativePasswordPreviewLabel(text: password.displayValue, textColor: NSColor(palette.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(resolvedCharacterCompositionHelpText)

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
                    showCopyFeedback = true
                    copyFeedbackTask?.cancel()
                    copyFeedbackTask = Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            showCopyFeedback = false
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(showCopyFeedback ? palette.surface : palette.accentStrong)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(showCopyFeedback ? palette.accentStrong : palette.accentSoft)
                            )
                            .overlay(
                                Circle()
                                    .stroke(showCopyFeedback ? palette.accentStrong.opacity(0.45) : Color.clear, lineWidth: 4)
                            )

                        if isCopied {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.accentStrong)
                                .background(
                                    Circle()
                                        .fill(palette.surface)
                                        .frame(width: 12, height: 12)
                                )
                                .offset(x: 2, y: -2)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .scaleEffect(showCopyFeedback ? 1.08 : 1)
                }
                .buttonStyle(.plain)
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
        .animation(.easeOut(duration: 0.16), value: showCopyFeedback)
        .onHover { isHovering in
            guard isHovering, characterCompositionHelpText == nil else {
                return
            }

            characterCompositionHelpText = characterCompositionHelpTextProvider()
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
    }

    private var resolvedCharacterCompositionHelpText: String {
        characterCompositionHelpText ?? "文字種の内訳を読み込み中..."
    }

    private var compactStrengthSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                overviewGradeChip
                compactMetricsRow
            }
            .fixedSize(horizontal: true, vertical: false)
            .help(resolvedCharacterCompositionHelpText)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    overviewGradeChip
                }

                compactMetricsRow
            }
            .help(resolvedCharacterCompositionHelpText)
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

private struct NativeSymbolOption: Sendable {
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
    case teal
    case mint
    case cyan
    case indigo
    case purple
    case lavender
    case pink
    case red
    case orange
    case yellow
    case gray

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "青"
        case .green: return "緑"
        case .teal: return "ティール"
        case .mint: return "ミント"
        case .cyan: return "シアン"
        case .indigo: return "インディゴ"
        case .purple: return "紫"
        case .lavender: return "ラベンダー"
        case .pink: return "ピンク"
        case .red: return "ローズ"
        case .orange: return "オレンジ"
        case .yellow: return "黄色"
        case .gray: return "グレー"
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
                backgroundBottom: Color(hex: 0x162236),
                panel: Color(hex: 0x172131, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1D2A3E, opacity: 0.94),
                surface: Color(hex: 0x23324A, opacity: 0.94),
                surfaceStrong: Color(hex: 0x2A3B55, opacity: 0.96),
                panelBorder: Color(hex: 0x6F95D6, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xA7B6CE),
                accent: Color(hex: 0x7FA6E8),
                accentStrong: Color(hex: 0x5F86D0),
                accentSoft: Color(hex: 0x253A5C),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
                backgroundTop: Color(hex: 0x101813),
                backgroundBottom: Color(hex: 0x17231B),
                panel: Color(hex: 0x172019, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1C2A21, opacity: 0.94),
                surface: Color(hex: 0x233329, opacity: 0.94),
                surfaceStrong: Color(hex: 0x2A3B30, opacity: 0.96),
                panelBorder: Color(hex: 0x6FA984, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xA5BDAE),
                accent: Color(hex: 0x76B88C),
                accentStrong: Color(hex: 0x57996F),
                accentSoft: Color(hex: 0x243F2D),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.teal, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xEAF8F7),
                backgroundBottom: Color(hex: 0xD2EEEB),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x3D7E78, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x587B78),
                accent: Color(hex: 0x239A8B),
                accentStrong: Color(hex: 0x197267),
                accentSoft: Color(hex: 0xD7F2EE),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.teal, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x0F1818),
                backgroundBottom: Color(hex: 0x152424),
                panel: Color(hex: 0x162120, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1B2B2A, opacity: 0.94),
                surface: Color(hex: 0x213433, opacity: 0.94),
                surfaceStrong: Color(hex: 0x283D3B, opacity: 0.96),
                panelBorder: Color(hex: 0x69AAA2, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0x9FBDBA),
                accent: Color(hex: 0x6DB8AD),
                accentStrong: Color(hex: 0x4D988E),
                accentSoft: Color(hex: 0x213F3B),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.mint, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xEFFAF5),
                backgroundBottom: Color(hex: 0xDAF2E8),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x51846E, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x607D70),
                accent: Color(hex: 0x45A777),
                accentStrong: Color(hex: 0x2F7D59),
                accentSoft: Color(hex: 0xDDF5EA),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.mint, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x101816),
                backgroundBottom: Color(hex: 0x17231F),
                panel: Color(hex: 0x17211E, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1D2B27, opacity: 0.94),
                surface: Color(hex: 0x24342F, opacity: 0.94),
                surfaceStrong: Color(hex: 0x2B3D37, opacity: 0.96),
                panelBorder: Color(hex: 0x7CAE96, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xA8C0B4),
                accent: Color(hex: 0x82BA9A),
                accentStrong: Color(hex: 0x619B79),
                accentSoft: Color(hex: 0x263F34),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.cyan, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xECF8FC),
                backgroundBottom: Color(hex: 0xD5EEF6),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x3B7890, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x597989),
                accent: Color(hex: 0x2598BC),
                accentStrong: Color(hex: 0x1A7190),
                accentSoft: Color(hex: 0xD8F1F8),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.cyan, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x0F171B),
                backgroundBottom: Color(hex: 0x15222A),
                panel: Color(hex: 0x162027, opacity: 0.96),
                surfaceSoft: Color(hex: 0x1B2932, opacity: 0.94),
                surface: Color(hex: 0x21323D, opacity: 0.94),
                surfaceStrong: Color(hex: 0x283A46, opacity: 0.96),
                panelBorder: Color(hex: 0x6BA6BA, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xA0B9C3),
                accent: Color(hex: 0x72B4C9),
                accentStrong: Color(hex: 0x5094AA),
                accentSoft: Color(hex: 0x233D48),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.indigo, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xF0F3FF),
                backgroundBottom: Color(hex: 0xDDE5FF),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x4F5F9E, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x626B8D),
                accent: Color(hex: 0x5366D8),
                accentStrong: Color(hex: 0x3B4AA6),
                accentSoft: Color(hex: 0xE1E6FF),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.indigo, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x121521),
                backgroundBottom: Color(hex: 0x1A1F31),
                panel: Color(hex: 0x1A1D2B, opacity: 0.96),
                surfaceSoft: Color(hex: 0x222638, opacity: 0.94),
                surface: Color(hex: 0x292E43, opacity: 0.94),
                surfaceStrong: Color(hex: 0x30364E, opacity: 0.96),
                panelBorder: Color(hex: 0x8993D0, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xB0B5CE),
                accent: Color(hex: 0x929BDA),
                accentStrong: Color(hex: 0x727CC4),
                accentSoft: Color(hex: 0x30365B),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
                backgroundTop: Color(hex: 0x1A1419),
                backgroundBottom: Color(hex: 0x261A23),
                panel: Color(hex: 0x261C24, opacity: 0.96),
                surfaceSoft: Color(hex: 0x30242D, opacity: 0.94),
                surface: Color(hex: 0x392B35, opacity: 0.94),
                surfaceStrong: Color(hex: 0x42323E, opacity: 0.96),
                panelBorder: Color(hex: 0xC18AA8, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xC7B0BD),
                accent: Color(hex: 0xD28AAC),
                accentStrong: Color(hex: 0xB5678E),
                accentSoft: Color(hex: 0x4A3040),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.red, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF1F2),
                backgroundBottom: Color(hex: 0xFFE0E2),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0xA85C64, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x876368),
                accent: Color(hex: 0xCC5B66),
                accentStrong: Color(hex: 0x9D414B),
                accentSoft: Color(hex: 0xFFE1E5),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.red, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x1A1415),
                backgroundBottom: Color(hex: 0x251B1D),
                panel: Color(hex: 0x251C1F, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2F2427, opacity: 0.94),
                surface: Color(hex: 0x382B2F, opacity: 0.94),
                surfaceStrong: Color(hex: 0x413337, opacity: 0.96),
                panelBorder: Color(hex: 0xBE8C92, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xC5B0B3),
                accent: Color(hex: 0xCF8A91),
                accentStrong: Color(hex: 0xAE6871),
                accentSoft: Color(hex: 0x493234),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
                backgroundTop: Color(hex: 0x191711),
                backgroundBottom: Color(hex: 0x242117),
                panel: Color(hex: 0x242117, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2D291D, opacity: 0.94),
                surface: Color(hex: 0x363124, opacity: 0.94),
                surfaceStrong: Color(hex: 0x403A2A, opacity: 0.96),
                panelBorder: Color(hex: 0xB8A276, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xC5B99D),
                accent: Color(hex: 0xC7AA68),
                accentStrong: Color(hex: 0xA88943),
                accentSoft: Color(hex: 0x443B25),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
                backgroundTop: Color(hex: 0x1A1511),
                backgroundBottom: Color(hex: 0x251E17),
                panel: Color(hex: 0x251E18, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2F261E, opacity: 0.94),
                surface: Color(hex: 0x382D24, opacity: 0.94),
                surfaceStrong: Color(hex: 0x42352A, opacity: 0.96),
                panelBorder: Color(hex: 0xBE9274, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xC4B2A2),
                accent: Color(hex: 0xC99570),
                accentStrong: Color(hex: 0xAA724D),
                accentSoft: Color(hex: 0x4A3728),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
                backgroundTop: Color(hex: 0x15131D),
                backgroundBottom: Color(hex: 0x201A2B),
                panel: Color(hex: 0x211B28, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2A2234, opacity: 0.94),
                surface: Color(hex: 0x322A3E, opacity: 0.94),
                surfaceStrong: Color(hex: 0x3A3148, opacity: 0.96),
                panelBorder: Color(hex: 0xA18FCF, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xBDB0D4),
                accent: Color(hex: 0xA895D8),
                accentStrong: Color(hex: 0x8770C2),
                accentSoft: Color(hex: 0x3A315B),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.lavender, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xF8F2FF),
                backgroundBottom: Color(hex: 0xE9DCFA),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x7D679B, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x756A86),
                accent: Color(hex: 0x9A6FD0),
                accentStrong: Color(hex: 0x7350A3),
                accentSoft: Color(hex: 0xEEE2FB),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.lavender, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x17151C),
                backgroundBottom: Color(hex: 0x211C29),
                panel: Color(hex: 0x211D27, opacity: 0.96),
                surfaceSoft: Color(hex: 0x2A2532, opacity: 0.94),
                surface: Color(hex: 0x332D3D, opacity: 0.94),
                surfaceStrong: Color(hex: 0x3C3547, opacity: 0.96),
                panelBorder: Color(hex: 0xAA94C5, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xC1B5CE),
                accent: Color(hex: 0xB49AD0),
                accentStrong: Color(hex: 0x9575B9),
                accentSoft: Color(hex: 0x413451),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
            )
        case (.gray, .light):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xF3F6FA),
                backgroundBottom: Color(hex: 0xE2E8F0),
                panel: Color.white.opacity(0.92),
                surfaceSoft: Color.white.opacity(0.72),
                surface: Color.white.opacity(0.82),
                surfaceStrong: Color.white.opacity(0.95),
                panelBorder: Color(hex: 0x64748B, opacity: 0.14),
                ink: Color(hex: 0x142033),
                muted: Color(hex: 0x64748B),
                accent: Color(hex: 0x667085),
                accentStrong: Color(hex: 0x475467),
                accentSoft: Color(hex: 0xE4E7EC),
                disabledBackground: Color(hex: 0xA9B4C6, opacity: 0.18),
                disabledText: Color(hex: 0x8C98AA),
                danger: Color(hex: 0xB54D3C)
            )
        case (.gray, .dark):
            return NativeThemePalette(
                backgroundTop: Color(hex: 0x11151B),
                backgroundBottom: Color(hex: 0x1A2029),
                panel: Color(hex: 0x1B2028, opacity: 0.96),
                surfaceSoft: Color(hex: 0x242A34, opacity: 0.94),
                surface: Color(hex: 0x2B323E, opacity: 0.94),
                surfaceStrong: Color(hex: 0x333B48, opacity: 0.96),
                panelBorder: Color(hex: 0x8A93A3, opacity: 0.17),
                ink: Color(hex: 0xF4F7FB),
                muted: Color(hex: 0xAEB6C3),
                accent: Color(hex: 0x9CA6B5),
                accentStrong: Color(hex: 0x7D8796),
                accentSoft: Color(hex: 0x343C49),
                disabledBackground: Color(hex: 0x2A313C, opacity: 0.96),
                disabledText: Color(hex: 0x7F8A9A),
                danger: Color(hex: 0xE08378)
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
