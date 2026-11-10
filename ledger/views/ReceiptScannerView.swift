//
//  DataScanner.swift
//  ledger
//
//  Created by Maksym Bahrov on 29.09.2026..
//

import SwiftUI
import VisionKit
import Vision

struct ReceiptScannerView: UIViewControllerRepresentable {
    /// Called as soon as the user confirms the scan, before text recognition starts.
    var onScanFinished: () -> Void
    /// Called with the scanned pages as JPEG data, so they can be attached to the transaction.
    var onPagesScanned: ([Data]) -> Void
    var onTextRecognized: (String) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onScanFinished: onScanFinished,
            onPagesScanned: onPagesScanned,
            onTextRecognized: onTextRecognized,
            onDismiss: onDismiss
        )
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanFinished: () -> Void
        let onPagesScanned: ([Data]) -> Void
        let onTextRecognized: (String) -> Void
        let onDismiss: () -> Void

        init(
            onScanFinished: @escaping () -> Void,
            onPagesScanned: @escaping ([Data]) -> Void,
            onTextRecognized: @escaping (String) -> Void,
            onDismiss: @escaping () -> Void
        ) {
            self.onScanFinished = onScanFinished
            self.onPagesScanned = onPagesScanned
            self.onTextRecognized = onTextRecognized
            self.onDismiss = onDismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            let pages = images.compactMap(\.cgImage)
            onScanFinished()
            onDismiss()

            Task {
                onPagesScanned(images.compactMap(SharedReceiptPhotos.photoData(from:)))

                var transcripts: [String] = []
                for page in pages {
                    if let transcript = try? await Self.recognizeText(in: page) {
                        transcripts.append(transcript)
                    }
                }
                onTextRecognized(transcripts.joined(separator: "\n"))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onDismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera failed: \(error)")
            onDismiss()
        }

        private static func recognizeText(in image: CGImage) async throws -> String {
            var request = RecognizeDocumentsRequest()
            request.textRecognitionOptions.automaticallyDetectLanguage = true
            request.textRecognitionOptions.useLanguageCorrection = false

            let observations = try await request.perform(on: image)
            return observations.first?.document.text.transcript ?? ""
        }
    }
}
