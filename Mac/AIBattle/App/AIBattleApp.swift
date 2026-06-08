import Darwin
import SwiftUI

@main
struct AIBattleApp: App {
    private let evidenceRequest: AIBattleEvidenceController.EvidenceRequest?

    init() {
        do {
            evidenceRequest = try AIBattleEvidenceController.evidenceRequest()
        } catch {
            fputs("aibattle: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }

        if let evidenceRequest {
            Task { @MainActor in
                do {
                    let result = try AIBattleEvidenceController.saveEvidence(request: evidenceRequest)
                    print("aibattle: \(result.outputURL.path)")
                    print("aibattle-report: \(result.reportURL.path)")
                    print("aibattle-target: \(result.snapshot.firstTuningTarget)")
                    exit(EXIT_SUCCESS)
                } catch {
                    fputs("aibattle: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if evidenceRequest == nil {
                AIBattleContentView()
                    .frame(minWidth: 1180, minHeight: 760)
            } else {
                Text("AIBattle evidence capture")
                    .frame(width: 320, height: 120)
            }
        }
        .windowStyle(.titleBar)
    }
}
