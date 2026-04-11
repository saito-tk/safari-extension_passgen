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
private let nativeSettingsStorageKey = "nativePassgenSettings"
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
    @FocusState private var focusedField: NativeFocusedField?
    @State private var isSavedSettingsSidebarVisible = true
    @State private var activeCharacterTab: NativeCharacterTab = .uppercase

    init(viewModel: NativePasswordGeneratorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let palette = viewModel.palette

        ZStack {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let layout = NativeSwiftLayoutMetrics(containerSize: proxy.size, isSidebarVisible: isSavedSettingsSidebarVisible)

                HStack(alignment: .top, spacing: layout.columnSpacing) {
                    if isSavedSettingsSidebarVisible {
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
        .animation(.easeInOut(duration: 0.2), value: isSavedSettingsSidebarVisible)
        .onChange(of: focusedField) { previousField, nextField in
            viewModel.handleFocusChange(from: previousField, to: nextField)
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
                sidebarToggleRow(palette: palette)
                heroCard(palette: palette)
                settingsCard(palette: palette)
                rulesCard(palette: palette)
                themeCard(palette: palette)
            }
        }
        .scrollIndicators(.visible)
    }

    private func rightColumn(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            resultsCard(palette: palette)
        }
    }

    private func sidebarToggleRow(palette: NativeThemePalette) -> some View {
        HStack {
            Button {
                isSavedSettingsSidebarVisible.toggle()
            } label: {
                Label(
                    isSavedSettingsSidebarVisible ? "保存済み設定を隠す" : "保存済み設定を表示",
                    systemImage: isSavedSettingsSidebarVisible ? "sidebar.leading" : "sidebar.left"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentStrong)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.74))
                )
                .overlay(
                    Capsule()
                        .stroke(palette.panelBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
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
                            .fill(Color.white.opacity(0.7))
                    )
            }

            Text("ここに保存した設定が並びます。保存機能を追加するまでは、空の一覧として表示されます。")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)

            VStack(alignment: .leading, spacing: 10) {
                Text("まだ保存済み設定はありません。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.ink)

                Text("設定名を付けて保存した項目を、ここから呼び出したり整理したりできる構成にします。")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.panelBorder, lineWidth: 1)
            )
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func heroCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("パスワードジェネレータ")
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
                    focus: .length,
                    palette: palette
                )

                numericFieldCard(
                    label: "件数",
                    text: $viewModel.countText,
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
                    .fill(Color.white.opacity(0.72))
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
                                .fill(isSelected ? palette.accent.opacity(0.14) : Color.white.opacity(0.82))
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
                .fill(Color.white.opacity(0.72))
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
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.95))
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
                        .fill(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.96))
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
                .fill(Color.white.opacity(0.72))
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
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.95))
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
                            .fill(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.96))
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
            : AnyShapeStyle(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.95))
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
                                .fill(isSelected ? palette.accent.opacity(0.14) : Color.white.opacity(0.82))
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
                                .fill(isSelected ? palette.accent.opacity(0.14) : Color.white.opacity(0.82))
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
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
    }

    private func themeCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("表示テーマ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.muted)

                Spacer(minLength: 0)

                Text("見た目のみ")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
            }

            HStack(spacing: 10) {
                ForEach(NativeTheme.allCases) { theme in
                    let swatchPalette = theme.palette
                    Button {
                        viewModel.selectTheme(theme)
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [swatchPalette.accent, swatchPalette.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(viewModel.settings.theme == theme ? palette.accent.opacity(0.22) : Color.clear, lineWidth: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isGenerating)
                    .help(theme.displayName)
                }
            }
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
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
                    }

                    Text("コピーボタンでクリップボードへ保存")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.muted)
                }

                Spacer(minLength: 0)
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.results) { password in
                            NativePasswordRow(
                                password: password,
                                palette: palette,
                                previewLineLength: isSavedSettingsSidebarVisible ? 40 : 52
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

    private func numericFieldCard(label: String, text: Binding<String>, focus: NativeFocusedField, palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: focus)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.ink)
                .disabled(viewModel.isGenerating)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
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
                        .fill(selected ? palette.accent.opacity(0.14) : (viewModel.isGenerating ? palette.disabledBackground : Color.white.opacity(0.82)))
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

    @Published var lengthText: String
    @Published var countText: String
    @Published var symbolImportText = ""
    @Published var settingsStatus = NativeInlineStatus()
    @Published var resultStatus = NativeInlineStatus()
    @Published var results: [NativeGeneratedPasswordListItem] = []
    @Published var progressCompleted = 0
    @Published var progressTotal = 0
    @Published var isGenerating = false

    private var generationTask: Task<Void, Never>?
    private var isRestoringSettings = true
    private var generatedPasswordStore: [UUID: String] = [:]

    init() {
        let restoredSettings = Self.restoreSettings()
        settings = restoredSettings
        lengthText = String(restoredSettings.length)
        countText = String(restoredSettings.count)
        syncCategorySelectionFlags()
        syncSelectAllState()
        isRestoringSettings = false
    }

    deinit {
        generationTask?.cancel()
    }

    var palette: NativeThemePalette {
        settings.theme.palette
    }

    var canApplyImportedSymbols: Bool {
        !symbolImportText.isEmpty && !isGenerating
    }

    var usesRulePriorityMode: Bool {
        settings.generationMode == .rulePriority
    }

    var progressText: String {
        "(\(progressCompleted)/\(progressTotal))"
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

    func selectTheme(_ theme: NativeTheme) {
        settings.theme = theme
        persistSettings()
    }

    func updateFixedPrefix(_ value: String) {
        settings.fixedPrefix = Self.sanitizeSingleLineText(value)
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
        settingsStatus = settingsStatus.tone == .warning ? settingsStatus : NativeInlineStatus()

        if let validationMessage = validateSettings() {
            settingsStatus = NativeInlineStatus(message: validationMessage, tone: .error)
            resultStatus = NativeInlineStatus()
            results = []
            generatedPasswordStore = [:]
            progressCompleted = 0
            progressTotal = 0
            return
        }

        generationTask?.cancel()
        results = []
        generatedPasswordStore = [:]
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

    private static func restoreSettings() -> NativePasswordSettings {
        guard let data = UserDefaults.standard.data(forKey: nativeSettingsStorageKey),
              let restoredSettings = try? JSONDecoder().decode(NativePasswordSettings.self, from: data) else {
            return .defaultSettings
        }

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
            return try await createUniformPassword(from: allCharacters, length: settings.length)
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
            entropy: estimateEntropy(charsetSize: allCharacters.count, length: settings.length),
            charsetSize: allCharacters.count
        )
    }

    private static func createUniformPassword(from characters: [String], length: Int) async throws -> NativeGeneratedPassword {
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
            charsetSize: characters.count
        )
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

struct NativeGeneratedPassword: Identifiable {
    let id = UUID()
    let value: String
    let entropy: Double
    let charsetSize: Int
}

struct NativeGeneratedPasswordListItem: Identifiable {
    let id: UUID
    let displayValue: String
    let note: String
    let analysis: NativePasswordAnalysis

    nonisolated init(password: NativeGeneratedPassword) {
        id = password.id
        if password.value.count <= 100 {
            displayValue = password.value
            note = ""
        } else {
            displayValue = String(password.value.prefix(100)) + "..."
            note = "表示は先頭 \(formatNumber(100)) 文字までです。実際の文字数は \(formatNumber(password.value.count)) 文字です。"
        }

        analysis = NativePasswordAnalysis(password: password.value, entropy: password.entropy, charsetSize: password.charsetSize)
    }
}

struct NativePasswordAnalysis {
    let entropy: Double
    let charsetSize: Int
    let expectedDistinctCount: Double
    let actualDistinctCount: Int
    let variety: Double
    let balance: Double
    let warnings: [String]

    nonisolated init(password: String, entropy: Double, charsetSize: Int) {
        let actualDistinctCount = getDistinctCharacterCount(password)
        let expectedDistinctCount = getExpectedDistinctCount(charsetSize: charsetSize, length: password.count)
        let variety = min(1, Double(actualDistinctCount) / max(expectedDistinctCount, 1))
        let balance = getBalanceScore(password)
        var warnings: [String] = []

        if entropy < 60 {
            warnings.append("文字数または文字種が少なめです")
        }
        if variety < 0.88 {
            warnings.append("この文字数に対して、重複がやや多めです")
        }
        if balance < 0.82 {
            warnings.append("一部の文字に偏りがあります")
        }
        if warnings.isEmpty {
            warnings.append("この文字数では自然なばらつきです")
        }

        self.entropy = entropy
        self.charsetSize = charsetSize
        self.expectedDistinctCount = expectedDistinctCount
        self.actualDistinctCount = actualDistinctCount
        self.variety = variety
        self.balance = balance
        self.warnings = warnings
    }

    var warningDetail: String {
        warnings.joined(separator: " / ")
    }
}

private struct NativePasswordRow: View {
    let password: NativeGeneratedPasswordListItem
    let palette: NativeThemePalette
    let previewLineLength: Int
    let onCopy: () -> Void
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(wrapPasswordPreview(password.displayValue, lineLength: previewLineLength))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !password.note.isEmpty {
                    Text(password.note)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }

                HStack(spacing: 6) {
                    Text("Variety \(formatNumber(password.analysis.variety * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.88))
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.panelBorder, lineWidth: 1)
                        )

                    Text("Balance \(formatNumber(password.analysis.balance * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accentStrong)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.12))
                        )
                }

                Text(password.analysis.warningDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .frame(width: 38, height: 38)
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
            .frame(width: 52)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
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
            return "SecRandomCopyBytes と拒否サンプリングを使い、選択した文字集合から各位置を独立に一様抽選します。似た文字の除外は反映されますが、文字種必須・連続禁止・先頭文字設定は使用しません。"
        case .rulePriority:
            return "選択した文字種を必ず含める、先頭文字設定、同じ文字の連続禁止などの生成ルールを優先します。サービス要件に合わせやすい一方、候補全体に対する完全一様ではありません。"
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

    var palette: NativeThemePalette {
        switch self {
        case .blue:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xEDF4FF),
                backgroundBottom: Color(hex: 0xD7E6FF),
                panel: Color.white.opacity(0.92),
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
        case .green:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xECF9F1),
                backgroundBottom: Color(hex: 0xD6F0DF),
                panel: Color.white.opacity(0.92),
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
        case .pink:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF0F7),
                backgroundBottom: Color(hex: 0xFFDBE9),
                panel: Color.white.opacity(0.92),
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
        case .red:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF0F0),
                backgroundBottom: Color(hex: 0xFFD9D9),
                panel: Color.white.opacity(0.92),
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
        case .yellow:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFFBE8),
                backgroundBottom: Color(hex: 0xFFF0BF),
                panel: Color.white.opacity(0.92),
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
        case .orange:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xFFF4EA),
                backgroundBottom: Color(hex: 0xFFE0C4),
                panel: Color.white.opacity(0.92),
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
        case .purple:
            return NativeThemePalette(
                backgroundTop: Color(hex: 0xF5EFFF),
                backgroundBottom: Color(hex: 0xE4D8FF),
                panel: Color.white.opacity(0.92),
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

private func estimateEntropy(charsetSize: Int, length: Int) -> Double {
    guard charsetSize > 0 else {
        return 0
    }

    return (Double(length) * log2(Double(charsetSize)) * 10).rounded() / 10
}

private func getDistinctCharacterCount(_ password: String) -> Int {
    Set(password.map(String.init)).count
}

private func getExpectedDistinctCount(charsetSize: Int, length: Int) -> Double {
    guard charsetSize > 0, length > 0 else {
        return 0
    }

    let charsetSizeDouble = Double(charsetSize)
    let remainingProbability = pow((charsetSizeDouble - 1) / charsetSizeDouble, Double(length))
    return charsetSizeDouble * (1 - remainingProbability)
}

private func getBalanceScore(_ password: String) -> Double {
    guard !password.isEmpty else {
        return 0
    }

    var counts: [String: Int] = [:]
    for character in password.map(String.init) {
        counts[character, default: 0] += 1
    }

    let total = Double(password.count)
    let distinctCount = counts.count
    guard distinctCount > 1 else {
        return distinctCount == 1 ? 1 : 0
    }

    let shannonEntropy = counts.values.reduce(0.0) { partialResult, count in
        let probability = Double(count) / total
        return partialResult - (probability * log2(probability))
    }

    return min(1, max(0, shannonEntropy / log2(Double(distinctCount))))
}

private func copyToPasteboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

private nonisolated func wrapPasswordPreview(_ text: String, lineLength: Int = 40) -> String {
    guard lineLength > 0, text.count > lineLength else {
        return text
    }

    var wrappedLines: [String] = []
    var currentLine = ""
    currentLine.reserveCapacity(lineLength)

    for character in text {
        currentLine.append(character)

        if currentLine.count == lineLength {
            wrappedLines.append(currentLine)
            currentLine.removeAll(keepingCapacity: true)
        }
    }

    if !currentLine.isEmpty {
        wrappedLines.append(currentLine)
    }

    return wrappedLines.joined(separator: "\n")
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
