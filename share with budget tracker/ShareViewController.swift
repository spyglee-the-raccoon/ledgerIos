//
//  ShareViewController.swift
//  share with budget tracker
//
//  Created by Maksym Bahrov on 04.10.2026..
//

import UIKit
import UniformTypeIdentifiers
import Vision

/// Receives a shared receipt photo, recognizes its text and hands it over to the main app,
/// which opens AddTransaction and runs `ReceiptParser` on it.
class ShareViewController: UIViewController {
    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        spinner.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            let text = await recognizeSharedImageText()
            if let url = ReceiptShareURL.make(text: text) {
                openMainApp(url)
            }
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func recognizeSharedImageText() async -> String {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
              let data = try? await provider.loadDataRepresentation(for: .image) else {
            return ""
        }

        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = false
        let observations = try? await request.perform(on: data)
        return observations?.first?.document.text.transcript ?? ""
    }

    /// Extensions can't use `UIApplication.shared`, so walk the responder chain to reach the host application.
    private func openMainApp(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }
}

/// URL format shared with the main app: `ladger://scan?text=<recognized receipt text>`.
enum ReceiptShareURL {
    static let scheme = "ladger"
    static let host = "scan"
    static let textKey = "text"

    static func make(text: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: textKey, value: text)]
        return components.url
    }
}
