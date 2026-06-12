import Darwin
import SwiftUI

@main
struct MosulApp: App {
    private static let runtimeCheckArgument = "--check-runtime-resources"
    private static let runtimeCheckOutputArgument = "--runtime-check-output"
    static let requireBundledRuntimeArgument = "--require-bundled-runtime"

    private let evidenceRequest: SnapshotController.EvidenceRequest?
    private let runtimeCheckRequested: Bool

    init() {
        runtimeCheckRequested = CommandLine.arguments.contains(Self.runtimeCheckArgument)
        let requireBundledRuntime = CommandLine.arguments.contains(Self.requireBundledRuntimeArgument)
        let runtimeCheckOutputURL = Self.runtimeCheckOutputURL()

        do {
            evidenceRequest = try SnapshotController.evidenceRequest()
        } catch {
            fputs("snapshot: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }

        if let evidenceRequest {
            Task { @MainActor in
                do {
                    let url = try SnapshotController.saveEvidenceSnapshot(request: evidenceRequest)
                    print("snapshot: \(url.path)")
                    exit(EXIT_SUCCESS)
                } catch {
                    fputs("snapshot: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        }

        if runtimeCheckRequested {
            Task { @MainActor in
                do {
                    let summary = try Self.runtimeResourceCheckSummary(requireBundledRuntime: requireBundledRuntime)
                    if let runtimeCheckOutputURL {
                        try summary.write(to: runtimeCheckOutputURL, atomically: true, encoding: .utf8)
                    }
                    print(summary)
                    exit(EXIT_SUCCESS)
                } catch {
                    fputs("runtime-check: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if evidenceRequest == nil && !runtimeCheckRequested {
                ContentView()
                    .frame(minWidth: 1180, minHeight: 760)
            } else {
                Text(runtimeCheckRequested ? "Runtime resource check" : "Snapshot evidence capture")
                    .frame(width: 320, height: 120)
            }
        }
        .windowStyle(.titleBar)
    }

    private static func runtimeCheckOutputURL(arguments: [String] = CommandLine.arguments) -> URL? {
        guard let argumentIndex = arguments.firstIndex(of: runtimeCheckOutputArgument) else {
            return nil
        }

        let valueIndex = argumentIndex + 1
        guard valueIndex < arguments.count else {
            return nil
        }

        return URL(fileURLWithPath: arguments[valueIndex])
    }

    @MainActor
    private static func runtimeResourceCheckSummary(requireBundledRuntime: Bool) throws -> String {
        let model = MosulGameModel()
        let fileManager = FileManager.default

        if !model.lastError.isEmpty {
            throw RuntimeResourceCheckError.engine(model.lastError)
        }

        if requireBundledRuntime && model.runtimeResources.source != .bundledApp {
            throw RuntimeResourceCheckError.notBundled(model.runtimeResources.source.description)
        }

        guard fileManager.fileExists(atPath: model.mapOverviewPath) else {
            throw RuntimeResourceCheckError.missingFile(model.mapOverviewPath)
        }

        guard let baseLevel = model.mapLevels.first(where: { $0.isBase && !$0.imagePath.isEmpty }) else {
            throw RuntimeResourceCheckError.missingMapLevel
        }

        guard fileManager.fileExists(atPath: baseLevel.imagePath) else {
            throw RuntimeResourceCheckError.missingFile(baseLevel.imagePath)
        }

        let spriteManifest = MosulSpriteManifest.shared(for: model.runtimeResources)
        guard model.units.contains(where: { spriteManifest.unitSprite(for: $0) != nil }) else {
            throw RuntimeResourceCheckError.missingUnitSprite
        }

        return "runtime-check: \(model.runtimeResources.source.description), \(model.scenarioName), \(model.mapLevels.count) map levels, \(model.units.count) units"
    }
}

enum RuntimeResourceCheckError: LocalizedError {
    case engine(String)
    case notBundled(String)
    case missingFile(String)
    case missingMapLevel
    case missingUnitSprite

    var errorDescription: String? {
        switch self {
        case .engine(let message):
            return message
        case .notBundled(let source):
            return "Expected bundled runtime resources, but loaded \(source)."
        case .missingFile(let path):
            return "Missing runtime file: \(path)"
        case .missingMapLevel:
            return "No base map level was loaded."
        case .missingUnitSprite:
            return "No unit sprite could be resolved from the runtime sprite manifest."
        }
    }
}
