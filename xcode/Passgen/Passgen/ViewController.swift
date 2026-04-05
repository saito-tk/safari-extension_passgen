//
//  ViewController.swift
//  Passgen
//
//  Created by Takahiro Saito on 2026/04/04.
//

import Cocoa
import SwiftUI
import WebKit

class ViewController: NSViewController {
    private let contentContainer = NSView()
    private let nativeViewModel = NativePasswordGeneratorViewModel()
    private lazy var nativeHostingView = NSHostingView(rootView: NativePasswordGeneratorView(viewModel: nativeViewModel))
    private var presentationObserver: NSObjectProtocol?

    @IBOutlet var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        configureWebView()
        configureNativeView()
        observePresentationModeChanges()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard view.window != nil else {
            return
        }

        applyMode(AppPreferences.shared.presentationMode, adjustWindow: true)
    }

    deinit {
        if let presentationObserver {
            NotificationCenter.default.removeObserver(presentationObserver)
        }
    }

    private func configureLayout() {
        webView.removeFromSuperview()

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureWebView() {
        guard let popupURL = Bundle.main.url(forResource: "popup", withExtension: "html"),
              let resourceURL = Bundle.main.resourceURL else {
            assertionFailure("popup.html is missing from the app bundle.")
            return
        }

        webView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        webView.loadFileURL(popupURL, allowingReadAccessTo: resourceURL)
    }

    private func configureNativeView() {
        nativeHostingView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(nativeHostingView)

        NSLayoutConstraint.activate([
            nativeHostingView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            nativeHostingView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            nativeHostingView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            nativeHostingView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    private func observePresentationModeChanges() {
        presentationObserver = NotificationCenter.default.addObserver(
            forName: .appPresentationModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let mode = notification.object as? AppPresentationMode else {
                return
            }

            self.applyMode(mode, adjustWindow: true)
        }
    }

    private func applyMode(_ mode: AppPresentationMode, adjustWindow: Bool) {
        webView.isHidden = mode != .web
        nativeHostingView.isHidden = mode != .swift

        if adjustWindow, let window = view.window {
            resizeWindow(for: mode, in: window)
        }
    }

    private func resizeWindow(for mode: AppPresentationMode, in window: NSWindow) {
        let targetSize = mode.preferredContentSize
        window.minSize = targetSize
        window.setContentSize(targetSize)
    }
}
