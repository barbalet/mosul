import Darwin
import SwiftUI

@main
struct MosulApp: App {
    private let evidenceRequest: SnapshotController.EvidenceRequest?

    init() {
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
    }

    var body: some Scene {
        WindowGroup {
            if evidenceRequest == nil {
                ContentView()
                    .frame(minWidth: 1180, minHeight: 760)
            } else {
                Text("Snapshot evidence capture")
                    .frame(width: 320, height: 120)
            }
        }
        .windowStyle(.titleBar)
    }
}
