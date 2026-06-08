import AppKit
import SwiftUI

enum SnapshotController {
    static let codename = "snapshot"
    static let directoryName = "snapshots"

    @MainActor
    static func saveMapSnapshot(
        model: MosulGameModel,
        size: CGSize = CGSize(width: 1440, height: 1440),
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    ) throws -> URL {
        let directoryURL = URL(fileURLWithPath: model.mosulRoot)
            .appendingPathComponent(directoryName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let content = TacticalMapView(model: model)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = scale

        guard let image = renderer.cgImage else {
            throw SnapshotError.renderFailed
        }

        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngEncodingFailed
        }

        let fileURL = directoryURL.appendingPathComponent(fileName(for: model.tick))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func fileName(for tick: UInt32, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"

        return "snapshot-\(formatter.string(from: date))-tick\(String(format: "%06u", tick)).png"
    }
}

enum SnapshotError: LocalizedError {
    case renderFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Could not render the Mosul tactical map."
        case .pngEncodingFailed:
            return "Could not encode the Mosul tactical map as PNG."
        }
    }
}
