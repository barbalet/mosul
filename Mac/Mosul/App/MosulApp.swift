import Darwin
import SwiftUI

@main
struct MosulApp: App {
    private static let runtimeCheckArgument = "--check-runtime-resources"

    private let evidenceRequest: SnapshotController.EvidenceRequest?
    private let runtimeCheckRequested: Bool

    init() {
        runtimeCheckRequested = CommandLine.arguments.contains(Self.runtimeCheckArgument)

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
                    print(try Self.runtimeResourceCheckSummary())
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

    @MainActor
    private static func runtimeResourceCheckSummary() throws -> String {
        let model = MosulGameModel()
        let fileManager = FileManager.default

        if !model.lastError.isEmpty {
            throw RuntimeResourceCheckError.engine(model.lastError)
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
    case missingFile(String)
    case missingMapLevel
    case missingUnitSprite

    var errorDescription: String? {
        switch self {
        case .engine(let message):
            return message
        case .missingFile(let path):
            return "Missing runtime file: \(path)"
        case .missingMapLevel:
            return "No base map level was loaded."
        case .missingUnitSprite:
            return "No unit sprite could be resolved from the runtime sprite manifest."
        }
    }
}
