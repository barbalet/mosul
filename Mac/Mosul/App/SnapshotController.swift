import AppKit
import SwiftUI

enum SnapshotController {
    static let codename = "snapshot"
    static let directoryName = "snapshots"
    static let evidenceArgument = "--snapshot-evidence"

    enum EvidenceOrder: String {
        case move
        case investigate

        var engineOrder: Int32 {
            switch self {
            case .move:
                return 2
            case .investigate:
                return 10
            }
        }

        var mapMode: MosulMapMode {
            switch self {
            case .move:
                return .move
            case .investigate:
                return .investigate
            }
        }

        var displayName: String {
            switch self {
            case .move:
                return "Move"
            case .investigate:
                return "Investigate"
            }
        }
    }

    struct EvidenceRequest {
        var outputURL: URL?
        var reportURL: URL?
        var size = CGSize(width: 1440, height: 900)
        var scale: CGFloat = 1.0
        var aiTicks: UInt32 = 10
        var battleIndex: UInt32 = 1
        var side: MosulPlayableSide = .usPatrol
        var order: EvidenceOrder = .investigate
        var requireBundledRuntime = false
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

        let content = TacticalMapView(model: model, scrollable: false)
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
            case "--snapshot-report":
                request.reportURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
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
            case "--snapshot-side":
                request.side = try sideValue(after: argument, in: arguments, at: index)
                index += 2
            case "--snapshot-order":
                request.order = try orderValue(after: argument, in: arguments, at: index)
                index += 2
            case MosulApp.requireBundledRuntimeArgument:
                request.requireBundledRuntime = true
                index += 1
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

        if !model.lastError.isEmpty {
            throw SnapshotError.runtimeLoadFailed(model.lastError)
        }

        if request.requireBundledRuntime && model.runtimeResources.source != .bundledApp {
            throw SnapshotError.runtimeSourceMismatch(model.runtimeResources.source.description)
        }

        model.reset(battleIndex: request.battleIndex)
        model.startPlayableBattle(as: request.side)

        if request.aiTicks > 0 {
            model.runOpponentAI(steps: request.aiTicks)
        }

        if model.selectedUnit == nil,
           let playerUnit = model.units.first(where: { $0.side == request.side.rawValue }) {
            model.select(unitID: playerUnit.id)
        }

        guard let selectedUnit = model.selectedUnit else {
            throw SnapshotError.noCommandableUnit(request.side.title)
        }

        let target = evidenceOrderTarget(for: selectedUnit, in: model)
        model.mode = request.order.mapMode
        model.handleMapTap(x: target.x, y: target.y)

        let report = try evidenceReport(for: model, request: request)
        if let reportURL = request.reportURL {
            let directoryURL = reportURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
        }

        return try savePlayerSnapshot(
            model: model,
            size: request.size,
            scale: request.scale,
            outputURL: request.outputURL
        )
    }

    @MainActor
    private static func savePlayerSnapshot(
        model: MosulGameModel,
        size: CGSize,
        scale: CGFloat,
        outputURL: URL?
    ) throws -> URL {
        let fileURL = outputURL ?? URL(fileURLWithPath: model.mosulRoot)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName(for: model.tick))
        let directoryURL = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let content = PlayerEvidenceSnapshotView(model: model)
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

    @MainActor
    private static func evidenceOrderTarget(for unit: MosulUnit, in model: MosulGameModel) -> CGPoint {
        let horizontalOffset: CGFloat = unit.x < model.mapWidth * 0.65 ? 42 : -42
        let verticalOffset: CGFloat = unit.y < model.mapHeight * 0.65 ? 34 : -34
        let x = min(max(unit.x + horizontalOffset, 12), model.mapWidth - 12)
        let y = min(max(unit.y + verticalOffset, 12), model.mapHeight - 12)

        return CGPoint(x: x, y: y)
    }

    @MainActor
    private static func evidenceReport(for model: MosulGameModel, request: EvidenceRequest) throws -> String {
        guard let selectedUnit = model.selectedUnit else {
            throw SnapshotError.noCommandableUnit(request.side.title)
        }

        let visibleOverlayLevels = model.visibleMapLevels.filter { !$0.isBase }
        let afterActionTextPresent = !model.afterAction.narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !model.afterAction.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let orderIssued = selectedUnit.order == request.order.engineOrder && selectedUnit.hasTarget
        let checks = [
            ("side_selected", model.playableSide == request.side),
            ("selected_unit_present", true),
            ("order_issued", orderIssued),
            ("upper_floor_overlay_visible", !visibleOverlayLevels.isEmpty),
            ("after_action_text_present", afterActionTextPresent)
        ]

        let failedChecks = checks.filter { !$0.1 }.map(\.0)
        if !failedChecks.isEmpty {
            throw SnapshotError.evidenceValidationFailed(failedChecks.joined(separator: ", "))
        }

        let overlayNames = visibleOverlayLevels.map(\.displayName).joined(separator: ", ")
        let controlledUnits = model.units.filter { $0.side == request.side.rawValue }.count

        return [
            "ok=true",
            "scenario=\(model.scenarioName)",
            "runtime_source=\(model.runtimeResources.source.description)",
            "side=\(request.side.title)",
            "controlled_units=\(controlledUnits)",
            "selected_unit=\(selectedUnit.name)",
            "selected_unit_level=\(model.levelName(for: selectedUnit.levelID))",
            "requested_order=\(request.order.displayName)",
            "selected_unit_order=\(orderName(selectedUnit.order))",
            "selected_unit_has_target=\(selectedUnit.hasTarget)",
            "visible_overlay_levels=\(overlayNames)",
            "after_action_text_present=\(afterActionTextPresent)",
            "after_action_outcome=\(outcomeName(model.afterAction.score.outcome))",
            "tick=\(model.tick)"
        ].joined(separator: "\n") + "\n"
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

    private static func sideValue(after option: String, in arguments: [String], at index: Int) throws -> MosulPlayableSide {
        let rawValue = try value(after: option, in: arguments, at: index)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch rawValue {
        case "1", "us", "u.s.", "us-patrol", "u.s.-patrol", "patrol":
            return .usPatrol
        case "2", "opfor", "opposing", "opposing-cell", "cell":
            return .opposingCell
        default:
            throw SnapshotError.invalidEvidenceArgument("\(option) must be us-patrol or opposing-cell")
        }
    }

    private static func orderValue(after option: String, in arguments: [String], at index: Int) throws -> EvidenceOrder {
        let rawValue = try value(after: option, in: arguments, at: index).lowercased()
        guard let order = EvidenceOrder(rawValue: rawValue) else {
            throw SnapshotError.invalidEvidenceArgument("\(option) must be move or investigate")
        }

        return order
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
    case runtimeLoadFailed(String)
    case runtimeSourceMismatch(String)
    case noCommandableUnit(String)
    case evidenceValidationFailed(String)
    case invalidEvidenceArgument(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Could not render the Mosul tactical map."
        case .pngEncodingFailed:
            return "Could not encode the Mosul tactical map as PNG."
        case .runtimeLoadFailed(let message):
            return message
        case .runtimeSourceMismatch(let source):
            return "Expected bundled runtime resources, but loaded \(source)."
        case .noCommandableUnit(let side):
            return "No commandable unit was available for \(side)."
        case .evidenceValidationFailed(let checks):
            return "Snapshot evidence did not satisfy required checks: \(checks)."
        case .invalidEvidenceArgument(let message):
            return message
        }
    }
}

private struct PlayerEvidenceSnapshotView: View {
    @ObservedObject var model: MosulGameModel

    var body: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.width < 1100 || proxy.size.height < 720
            let panelHeight = min(280, max(200, proxy.size.height * 0.36))
            let panelWidth = min(360, max(300, proxy.size.width * 0.28))

            if compactLayout {
                VStack(spacing: 0) {
                    TacticalMapView(model: model, scrollable: false)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    ScrollView {
                        evidencePanel
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: panelHeight)
                }
            } else {
                HStack(spacing: 0) {
                    TacticalMapView(model: model, scrollable: false)
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    evidencePanel
                        .frame(width: panelWidth)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MOSUL evidence snapshot")
    }

    private var evidencePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(MosulVersion.displayName)
                    .font(.title2.weight(.semibold))
                Text(model.scenarioName)
                    .font(.headline)
                Text("Market / Commercial Streets, Mosul, 2003")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            panel("Command") {
                metricRow("Side", model.commandSideTitle)
                metricRow("Opponent", model.opponentSideTitle)
                metricRow("Tick", "\(model.tick)")
            }

            panel("Selected Unit") {
                if let selectedUnit = model.selectedUnit {
                    metricRow("Name", selectedUnit.name)
                    metricRow("Side", sideName(selectedUnit.side))
                    metricRow("Order", orderName(selectedUnit.order))
                    metricRow("Level", model.levelName(for: selectedUnit.levelID))
                    metricRow("Target", selectedUnit.hasTarget ? "\(Int(selectedUnit.targetX)), \(Int(selectedUnit.targetY)) m" : "None")
                } else {
                    Text("No unit selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            panel("Visible Overlays") {
                let overlays = model.visibleMapLevels.filter { !$0.isBase }
                if overlays.isEmpty {
                    Text("Ground only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overlays) { level in
                        HStack(spacing: 6) {
                            Image(systemName: "square.3.layers.3d.top.filled")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(level.displayName)
                                .font(.caption)
                        }
                    }
                }
            }

            panel("U.S. After Action") {
                metricRow("Outcome", outcomeName(model.afterAction.score.outcome))
                metricRow("Score", "\(model.afterAction.score.total)")
                Text(model.afterAction.narrative.isEmpty ? model.afterAction.summary : model.afterAction.narrative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}
