//
//  DataScanner.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 29.09.2026..
//

import SwiftUI
import VisionKit
import Vision

struct ReceiptScannerView: UIViewControllerRepresentable {
    var onTextRecognized: (String) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onTextRecognized: (String) -> Void
        let onDismiss: () -> Void

        init(onTextRecognized: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
            self.onTextRecognized = onTextRecognized
            self.onDismiss = onDismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            onDismiss()

            Task {
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
