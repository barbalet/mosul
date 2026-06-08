import AppKit
import SwiftUI

enum SnapshotController {
    static let codename = "snapshot"
    static let directoryName = "snapshots"
    static let evidenceArgument = "--snapshot-evidence"

    struct EvidenceRequest {
        var outputURL: URL?
        var size = CGSize(width: 1440, height: 1440)
        var scale: CGFloat = 1.0
        var aiTicks: UInt32 = 10
        var battleIndex: UInt32 = 1
    }

    @MainActor
    static func saveMapSnapshot(
        model: MosulGameModel,
        size: CGSize = CGSize(width: 1440, height: 1440),
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0,
        outputURL: URL? = nil
    ) throws -> URL {
        let fileURL = outputURL ?? URL(fileURLWithPath: model.mosulRoot)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName(for: model.tick))
        let directoryURL = fileURL.deletingLastPathComponent()

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

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func evidenceRequest(arguments: [String] = CommandLine.arguments) throws -> EvidenceRequest? {
        guard arguments.contains(evidenceArgument) else {
            return nil
        }

        var request = EvidenceRequest()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case evidenceArgument:
                index += 1
            case "--snapshot-output":
                request.outputURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
                index += 2
            case "--snapshot-width":
                request.size.width = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--snapshot-height":
                request.size.height = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--snapshot-scale":
                request.scale = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--snapshot-ai-ticks":
                request.aiTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--snapshot-battle":
                request.battleIndex = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            default:
                index += 1
            }
        }

        if request.size.width <= 0 || request.size.height <= 0 || request.scale <= 0 {
            throw SnapshotError.invalidEvidenceArgument("snapshot width, height, and scale must be positive")
        }

        return request
    }

    @MainActor
    static func saveEvidenceSnapshot(request: EvidenceRequest) throws -> URL {
        let model = MosulGameModel()
        model.reset(battleIndex: request.battleIndex)

        if model.selectedUnit == nil,
           let playerUnit = model.units.first(where: { $0.side == 1 }) {
            model.select(unitID: playerUnit.id)
        }

        if request.aiTicks > 0 {
            model.runAI(steps: request.aiTicks)
        }

        return try saveMapSnapshot(
            model: model,
            size: request.size,
            scale: request.scale,
            outputURL: request.outputURL
        )
    }

    private static func value(after option: String, in arguments: [String], at index: Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SnapshotError.invalidEvidenceArgument("\(option) requires a value")
        }

        return arguments[valueIndex]
    }

    private static func doubleValue(after option: String, in arguments: [String], at index: Int) throws -> Double {
        let rawValue = try value(after: option, in: arguments, at: index)
        guard let value = Double(rawValue) else {
            throw SnapshotError.invalidEvidenceArgument("\(option) requires a numeric value")
        }

        return value
    }

    private static func uint32Value(after option: String, in arguments: [String], at index: Int) throws -> UInt32 {
        let rawValue = try value(after: option, in: arguments, at: index)
        guard let value = UInt32(rawValue) else {
            throw SnapshotError.invalidEvidenceArgument("\(option) requires an unsigned integer value")
        }

        return value
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
    case invalidEvidenceArgument(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Could not render the Mosul tactical map."
        case .pngEncodingFailed:
            return "Could not encode the Mosul tactical map as PNG."
        case .invalidEvidenceArgument(let message):
            return message
        }
    }
}
