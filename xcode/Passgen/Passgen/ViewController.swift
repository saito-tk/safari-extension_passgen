//
//  ViewController.swift
//  Passgen
//
//  Created by Takahiro Saito on 2026/04/04.
//

import Cocoa
import Combine
import SwiftUI

class ViewController: NSViewController {
    private let nativeViewModel = NativePasswordGeneratorViewModel()
    private lazy var nativeHostingView = NSHostingView(rootView: NativePasswordGeneratorView(viewModel: nativeViewModel))
    private let preferredWindowSize = NSSize(width: 1380, height: 840)
    private var sidebarVisibilityObserver: AnyCancellable?
    private weak var sidebarToggleButton: NSButton?
    private var sidebarAccessoryController: NSTitlebarAccessoryViewController?
    private weak var configuredWindow: NSWindow?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNativeView()
        observeSidebarVisibility()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard let window = view.window else {
            return
        }

        configureWindow(window)
        window.minSize = preferredWindowSize
        window.setContentSize(preferredWindowSize)
    }

    private func configureNativeView() {
        guard nativeHostingView.superview == nil else {
            return
        }

        nativeHostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nativeHostingView)

        NSLayoutConstraint.activate([
            nativeHostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeHostingView.topAnchor.constraint(equalTo: view.topAnchor),
            nativeHostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func observeSidebarVisibility() {
        sidebarVisibilityObserver = nativeViewModel.$isSavedSettingsSidebarVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                self?.updateSidebarToggleButton(isVisible: isVisible)
            }
    }

    private func configureWindow(_ window: NSWindow) {
        guard configuredWindow !== window else {
            return
        }

        configuredWindow = window
        window.toolbar = nil
        installSidebarAccessoryIfNeeded(on: window)
        updateSidebarToggleButton(isVisible: nativeViewModel.isSavedSettingsSidebarVisible)
    }

    @objc private func toggleSavedSettingsSidebar(_ sender: Any?) {
        nativeViewModel.toggleSavedSettingsSidebar()
    }

    private func installSidebarAccessoryIfNeeded(on window: NSWindow) {
        guard sidebarAccessoryController == nil else {
            return
        }

        let iconImage = sidebarToggleImage(
            isVisible: nativeViewModel.isSavedSettingsSidebarVisible,
            accessibilityDescription: "保存済み設定を表示"
        ) ?? NSImage()

        let button = NSButton(
            image: iconImage,
            target: self,
            action: #selector(toggleSavedSettingsSidebar(_:))
        )
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.focusRingType = .none
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = sidebarToggleTintColor(isVisible: nativeViewModel.isSavedSettingsSidebarVisible)

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        button.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])

        let accessoryController = NSTitlebarAccessoryViewController()
        accessoryController.view = containerView
        accessoryController.layoutAttribute = .left

        window.addTitlebarAccessoryViewController(accessoryController)
        sidebarAccessoryController = accessoryController
        sidebarToggleButton = button
    }

    private func updateSidebarToggleButton(isVisible: Bool) {
        guard let button = sidebarToggleButton else {
            return
        }

        let label = isVisible ? "保存済み設定を隠す" : "保存済み設定を表示"
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.contentTintColor = sidebarToggleTintColor(isVisible: isVisible)
        button.image = sidebarToggleImage(
            isVisible: isVisible,
            accessibilityDescription: label
        )
    }

    private func sidebarToggleImage(isVisible: Bool, accessibilityDescription: String) -> NSImage? {
        let iconConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let symbolName = isVisible ? "sidebar.leading" : "sidebar.left"
        return NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(iconConfiguration)
    }

    private func sidebarToggleTintColor(isVisible: Bool) -> NSColor {
        isVisible ? .labelColor : .tertiaryLabelColor
    }
}
