//
//  ViewController.swift
//  Passgen
//
//  Created by Takahiro Saito on 2026/04/04.
//

import Cocoa
import WebKit

class ViewController: NSViewController {

    @IBOutlet var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let popupURL = Bundle.main.url(forResource: "popup", withExtension: "html"),
              let resourceURL = Bundle.main.resourceURL else {
            assertionFailure("popup.html is missing from the app bundle.")
            return
        }

        webView.loadFileURL(popupURL, allowingReadAccessTo: resourceURL)
    }
}
