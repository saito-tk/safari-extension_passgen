//
//  ViewController.swift
//  Passgen
//
//  Created by Takahiro Saito on 2026/04/04.
//

import Cocoa
import SwiftUI

class ViewController: NSViewController {
    private let nativeViewModel = NativePasswordGeneratorViewModel()
    private lazy var nativeHostingView = NSHostingView(rootView: NativePasswordGeneratorView(viewModel: nativeViewModel))
    private let preferredWindowSize = NSSize(width: 1380, height: 840)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNativeView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard let window = view.window else {
            return
        }

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
}
