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
        /// Longest side of a stored page; enough to read the receipt, small enough to store many.
        private static let maxPhotoDimension: CGFloat = 1600

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
                onPagesScanned(images.compactMap(Self.photoData(from:)))

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

        private static func photoData(from image: UIImage) -> Data? {
            let scale = min(1, maxPhotoDimension / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            return resized.jpegData(compressionQuality: 0.6)
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
