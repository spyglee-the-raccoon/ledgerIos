//
//  ShareViewController.swift
//  share with ledger
//
//  Created by Maksym Bahrov on 04.10.2026..
//

import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

/// Receives a shared receipt photo or PDF, recognizes its text and hands it over to the main app,
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
            let text = await recognizeSharedText()
            if let url = ReceiptShareURL.make(text: text) {
                openMainApp(url)
            }
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func recognizeSharedText() async -> String {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }),
           let data = await loadData(of: .pdf, from: provider) {
            return await recognizePDFText(data)
        }

        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
              let data = await loadData(of: .image, from: provider) else {
            return ""
        }
        return await recognizeText(in: data)
    }

    /// Renders each PDF page to an image and runs the same OCR as for shared photos,
    /// so the main app's `ReceiptParser` gets text in the same layout either way.
    private func recognizePDFText(_ data: Data) async -> String {
        guard let document = PDFDocument(data: data) else { return "" }
        var transcripts: [String] = []
        for index in 0..<min(document.pageCount, Self.maxPDFPages) {
            guard let page = document.page(at: index),
                  let imageData = render(page) else { continue }
            let text = await recognizeText(in: imageData)
            if !text.isEmpty {
                transcripts.append(text)
            }
        }
        return transcripts.joined(separator: "\n")
    }

    /// Renders a PDF page at a higher scale than its point size so small receipt text stays legible for OCR.
    private func render(_ page: PDFPage) -> Data? {
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * Self.pdfRenderScale, height: bounds.height * Self.pdfRenderScale)
        return page.thumbnail(of: size, for: .mediaBox).pngData()
    }

    private func recognizeText(in imageData: Data) async -> String {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = false
        let observations = try? await request.perform(on: imageData)
        return observations?.first?.document.text.transcript ?? ""
    }

    private func loadData(of type: UTType, from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static let maxPDFPages = 5
    private static let pdfRenderScale: CGFloat = 3

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
