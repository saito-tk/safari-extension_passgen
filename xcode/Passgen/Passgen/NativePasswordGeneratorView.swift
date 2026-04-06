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
private let nativeMaxPasswordCount = 30
private let nativePasswordYieldInterval = 2_048

struct NativePasswordGeneratorView: View {
    @StateObject var viewModel: NativePasswordGeneratorViewModel
    @FocusState private var focusedField: NativeFocusedField?
    @State private var isSavedSettingsSidebarVisible = true

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
            analysisCard(palette: palette)
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

    private func analysisCard(palette: NativeThemePalette) -> some View {
        let latestResult = viewModel.results.last

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("強度サマリー")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.ink)

                Spacer(minLength: 0)

                Text(latestResult == nil ? "未生成" : "最新の結果")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                    )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                analysisMetricCard(
                    title: "強度評価",
                    value: latestResult?.strengthLabel ?? "未生成",
                    detail: latestResult.map { "推定 \(formatNumber($0.entropy)) bits" } ?? "生成後に表示されます",
                    palette: palette
                )
                analysisMetricCard(
                    title: "点数",
                    value: "—",
                    detail: "Task 2 で追加予定",
                    palette: palette
                )
                analysisMetricCard(
                    title: "警告",
                    value: latestResult == nil ? "—" : "なし",
                    detail: "詳細な検出は次の段階で追加します",
                    palette: palette
                )
                analysisMetricCard(
                    title: "偏り・ユニーク率",
                    value: "—",
                    detail: "生成後に見やすく表示します",
                    palette: palette
                )
            }
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
            sectionHeader(title: "文字セット")
            charsetGrid(palette: palette)
            symbolSection(palette: palette)
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
    }

    private func charsetGrid(palette: NativeThemePalette) -> some View {
        HStack(spacing: 8) {
            settingChip(title: "英字(大文字)", selected: viewModel.settings.uppercase, palette: palette, compact: true) {
                viewModel.toggleUppercase()
            }

            settingChip(title: "英字(小文字)", selected: viewModel.settings.lowercase, palette: palette, compact: true) {
                viewModel.toggleLowercase()
            }

            settingChip(title: "数字", selected: viewModel.settings.digits, palette: palette, compact: true) {
                viewModel.toggleDigits()
            }

            Spacer(minLength: 0)
        }
    }

    private func symbolSection(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            settingChip(title: "記号", selected: viewModel.settings.includeSymbols, palette: palette, fullWidth: true) {
                viewModel.toggleIncludeSymbols()
            }

            if viewModel.settings.includeSymbols {
                symbolPanel(palette: palette)
            }
        }
    }

    private func symbolPanel(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 0)

                Button(viewModel.settings.selectAllSymbols ? "すべて解除" : "すべて選択") {
                    viewModel.setAllSymbols(selected: !viewModel.settings.selectAllSymbols)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(viewModel.isGenerating ? palette.disabledText : palette.muted)
                .disabled(viewModel.isGenerating)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(Array(nativeSymbolOptions.enumerated()), id: \.offset) { index, symbol in
                    symbolButton(index: index, symbol: symbol, palette: palette)
                }
            }

            symbolImportRow(palette: palette)
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

    private func rulesCard(palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "生成ルール")

            HStack(spacing: 10) {
                settingChip(title: "似た文字を除外する", selected: viewModel.settings.excludeSimilar, palette: palette) {
                    viewModel.toggleExcludeSimilar()
                }

                settingChip(title: "同じ文字を連続させない", selected: viewModel.settings.noConsecutive, palette: palette) {
                    viewModel.toggleNoConsecutive()
                }
            }
        }
        .padding(16)
        .nativeCardStyle(palette: palette)
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
                            NativePasswordRow(password: password, palette: palette)
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
        .disabled(viewModel.isGenerating)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .fixedSize(horizontal: compact, vertical: false)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
    }

    private func analysisMetricCard(title: String, value: String, detail: String, palette: NativeThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.muted)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.ink)

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.panelBorder, lineWidth: 1)
        )
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
    @Published var results: [NativeGeneratedPassword] = []
    @Published var progressCompleted = 0
    @Published var progressTotal = 0
    @Published var isGenerating = false

    private var generationTask: Task<Void, Never>?
    private var isRestoringSettings = true

    init() {
        let restoredSettings = Self.restoreSettings()
        settings = restoredSettings
        lengthText = String(restoredSettings.length)
        countText = String(restoredSettings.count)
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

    var progressText: String {
        "(\(progressCompleted)/\(progressTotal))"
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

    func toggleUppercase() {
        settings.uppercase.toggle()
        persistSettings()
    }

    func toggleLowercase() {
        settings.lowercase.toggle()
        persistSettings()
    }

    func toggleDigits() {
        settings.digits.toggle()
        persistSettings()
    }

    func toggleIncludeSymbols() {
        settings.includeSymbols.toggle()
        persistSettings()
    }

    func toggleExcludeSimilar() {
        settings.excludeSimilar.toggle()
        persistSettings()
    }

    func toggleNoConsecutive() {
        settings.noConsecutive.toggle()
        persistSettings()
    }

    func selectTheme(_ theme: NativeTheme) {
        settings.theme = theme
        persistSettings()
    }

    func toggleSymbol(at index: Int) {
        guard settings.symbols.indices.contains(index) else {
            return
        }

        settings.symbols[index].toggle()
        syncSelectAllState()
        persistSettings()
    }

    func setAllSymbols(selected: Bool) {
        settings.symbols = Array(repeating: selected, count: nativeSymbolOptions.count)
        syncSelectAllState()
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
            progressCompleted = 0
            progressTotal = 0
            return
        }

        generationTask?.cancel()
        results = []
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

                    await MainActor.run {
                        self.results.append(password)
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
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.resultStatus = NativeInlineStatus(message: "条件に合うパスワードを生成できませんでした。", tone: .error)
                }
            }
        }
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

        if settings.length < pools.count {
            return "文字数が短すぎます。"
        }

        let combinedCharacters = Self.combinePools(pools)
        if settings.noConsecutive && combinedCharacters.count < 2 && settings.length > 1 {
            return "同じ文字を連続させない設定では、少なくとも 2 種類以上の文字が必要です。"
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

        if normalizedSettings.symbols.count != nativeSymbolOptions.count {
            normalizedSettings.symbols = Array(repeating: true, count: nativeSymbolOptions.count)
        }

        normalizedSettings.selectAllSymbols = normalizedSettings.symbols.contains(true) && normalizedSettings.symbols.allSatisfy(\.self)
        return normalizedSettings
    }

    private static func sanitizeNumber(_ value: String, fallback: Int) -> Int {
        Int(value) ?? fallback
    }

    private static func clampNumber(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    private static func getMaxCountForLength(_ length: Int) -> Int {
        let normalizedLength = clampNumber(length, minimum: nativeMinPasswordLength, maximum: nativeMaxPasswordLength)
        return max(nativeMinPasswordCount, min(nativeMaxPasswordCount, nativeMaxPasswordLength / normalizedLength))
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
        let requiredPoolIDs = Set(pools.map(\.id))
        var mutableRequiredPoolIDs = requiredPoolIDs
        var passwordCharacters: [String] = []
        var previousCharacter = ""
        var iterationsSinceYield = 0

        while passwordCharacters.count < settings.length {
            let remainingSlots = settings.length - passwordCharacters.count
            let candidatePools = try selectCandidatePools(
                pools: pools,
                requiredPoolIDs: mutableRequiredPoolIDs,
                remainingSlots: remainingSlots,
                noConsecutive: settings.noConsecutive,
                previousCharacter: previousCharacter
            )

            let selectedPoolIndex = try randomInt(upperBound: candidatePools.count)
            let pool = candidatePools[selectedPoolIndex]

            guard let character = try pickCharacter(from: pool.characters, previousCharacter: previousCharacter, noConsecutive: settings.noConsecutive) else {
                throw NativeGenerationError.unavailableCharacters
            }

            passwordCharacters.append(character)
            previousCharacter = character
            mutableRequiredPoolIDs.remove(pool.id)
            iterationsSinceYield += 1

            if iterationsSinceYield >= nativePasswordYieldInterval {
                iterationsSinceYield = 0
                await Task.yield()
            }
        }

        let password = passwordCharacters.joined()
        return NativeGeneratedPassword(value: password, entropy: estimateEntropy(charsetSize: allCharacters.count, length: settings.length))
    }

    private static func buildPools(using settings: NativePasswordSettings) -> [NativeCharacterPool] {
        var pools: [NativeCharacterPool] = []

        appendPoolIfNeeded(&pools, isEnabled: settings.uppercase, id: "uppercase", sourceCharacters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", excludeSimilar: settings.excludeSimilar)
        appendPoolIfNeeded(&pools, isEnabled: settings.lowercase, id: "lowercase", sourceCharacters: "abcdefghijklmnopqrstuvwxyz", excludeSimilar: settings.excludeSimilar)
        appendPoolIfNeeded(&pools, isEnabled: settings.digits, id: "digits", sourceCharacters: "0123456789", excludeSimilar: settings.excludeSimilar)
        appendPoolIfNeeded(&pools, isEnabled: settings.includeSymbols, id: "symbols", sourceCharacters: selectedSymbolCharacters(from: settings), excludeSimilar: false)

        return pools
    }

    private static func appendPoolIfNeeded(_ pools: inout [NativeCharacterPool], isEnabled: Bool, id: String, sourceCharacters: String, excludeSimilar: Bool) {
        guard isEnabled else {
            return
        }

        let normalizedCharacters = normalizeCharacters(sourceCharacters, excludeSimilar: excludeSimilar)
        guard !normalizedCharacters.isEmpty else {
            return
        }

        pools.append(NativeCharacterPool(id: id, characters: normalizedCharacters))
    }

    private static func normalizeCharacters(_ characters: String, excludeSimilar: Bool) -> [String] {
        var seen = Set<String>()

        return characters.map(String.init).filter { character in
            if excludeSimilar && nativeSimilarCharacters.contains(character) {
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

    private static func combinePools(_ pools: [NativeCharacterPool]) -> [String] {
        var seen = Set<String>()
        return pools.flatMap(\.characters).filter { seen.insert($0).inserted }
    }

    private static func selectCandidatePools(
        pools: [NativeCharacterPool],
        requiredPoolIDs: Set<String>,
        remainingSlots: Int,
        noConsecutive: Bool,
        previousCharacter: String
    ) throws -> [NativeCharacterPool] {
        let requiredPools = pools.filter { requiredPoolIDs.contains($0.id) }
        let sourcePools: [NativeCharacterPool]

        if remainingSlots == requiredPools.count {
            sourcePools = requiredPools
        } else if !requiredPools.isEmpty {
            let shouldPrioritizeRequiredPools = try randomInt(upperBound: 100) < 55
            sourcePools = shouldPrioritizeRequiredPools ? requiredPools : pools
        } else {
            sourcePools = pools
        }

        let validPools = sourcePools.filter { hasAvailableCharacter(in: $0.characters, previousCharacter: previousCharacter, noConsecutive: noConsecutive) }
        if !validPools.isEmpty {
            return validPools
        }

        return pools.filter { hasAvailableCharacter(in: $0.characters, previousCharacter: previousCharacter, noConsecutive: noConsecutive) }
    }

    private static func hasAvailableCharacter(in characters: [String], previousCharacter: String, noConsecutive: Bool) -> Bool {
        if !noConsecutive {
            return !characters.isEmpty
        }

        return characters.contains { $0 != previousCharacter }
    }

    private static func pickCharacter(from characters: [String], previousCharacter: String, noConsecutive: Bool) throws -> String? {
        let candidates = noConsecutive ? characters.filter { $0 != previousCharacter } : characters

        guard !candidates.isEmpty else {
            return nil
        }

        return candidates[try randomInt(upperBound: candidates.count)]
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
    var selectAllSymbols: Bool
    var symbols: [Bool]
    var length: Int
    var count: Int
    var excludeSimilar: Bool
    var noConsecutive: Bool
    var theme: NativeTheme

    static let defaultSettings = NativePasswordSettings(
        uppercase: true,
        lowercase: true,
        digits: true,
        includeSymbols: true,
        selectAllSymbols: false,
        symbols: Array(repeating: true, count: nativeSymbolOptions.count),
        length: 16,
        count: 6,
        excludeSimilar: true,
        noConsecutive: false,
        theme: .blue
    )
}

struct NativeGeneratedPassword: Identifiable {
    let id = UUID()
    let value: String
    let entropy: Double

    var displayValue: String {
        if value.count <= 100 {
            return value
        }

        return String(value.prefix(100)) + "..."
    }

    var note: String {
        guard value.count > 100 else {
            return ""
        }

        return "表示は先頭 \(formatNumber(100)) 文字までです。実際の文字数は \(formatNumber(value.count)) 文字です。"
    }

    var strengthLabel: String {
        let uniqueCoverage = getUniqueCoverage(value)
        var adjustedEntropy = entropy

        if uniqueCoverage < 0.45 {
            adjustedEntropy -= 20
        } else if uniqueCoverage < 0.6 {
            adjustedEntropy -= 10
        } else if uniqueCoverage < 0.75 {
            adjustedEntropy -= 5
        }

        if adjustedEntropy >= 100 {
            return "Very Strong"
        }
        if adjustedEntropy >= 80 {
            return "Strong"
        }
        if adjustedEntropy >= 60 {
            return "Good"
        }
        return "Basic"
    }
}

private struct NativePasswordRow: View {
    let password: NativeGeneratedPassword
    let palette: NativeThemePalette
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(password.displayValue)
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
                    Text(password.strengthLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accentStrong)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.12))
                        )

                    Text("推定 \(formatNumber(password.entropy)) bits")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.05))
                        )
                }
            }

            VStack(spacing: 6) {
                Button {
                    copyToPasteboard(password.value)
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

private func getUniqueCoverage(_ password: String) -> Double {
    guard !password.isEmpty else {
        return 0
    }

    return Double(Set(password.map(String.init)).count) / Double(password.count)
}

private func copyToPasteboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

private func formatNumber<T: BinaryInteger>(_ value: T) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: Int(value))) ?? "\(value)"
}

private func formatNumber(_ value: Double) -> String {
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
