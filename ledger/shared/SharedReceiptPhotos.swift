//
//  SharedReceiptPhotos.swift
//  ledger
//

import UIKit

enum SharedReceiptPhotos {
    private static let appGroup = "group.work.spyglee.ledger"
    private static let maxPhotoDimension: CGFloat = 1600

    private static var directoryURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "shared-receipt", directoryHint: .isDirectory)
    }

    static func photoData(from image: UIImage) -> Data? {
        let scale = min(1, maxPhotoDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }

    static func save(_ pages: [Data]) {
        guard let directoryURL else { return }
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: directoryURL)
        guard !pages.isEmpty,
              (try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)) != nil else { return }
        for (index, page) in pages.enumerated() {
            try? page.write(to: directoryURL.appending(path: "page-\(index).jpg"))
        }
    }

    static func take() -> [Data] {
        guard let directoryURL else { return [] }
        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: directoryURL) }
        var pages: [Data] = []
        var index = 0
        while let page = try? Data(contentsOf: directoryURL.appending(path: "page-\(index).jpg")) {
            pages.append(page)
            index += 1
        }
        return pages
    }
}
