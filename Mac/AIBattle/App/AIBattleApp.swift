import Darwin
import SwiftUI

@main
struct AIBattleApp: App {
    private let evidenceRequest: AIBattleEvidenceController.EvidenceRequest?
    private let movieRequest: AIBattleEvidenceController.MovieRequest?

    init() {
        do {
            evidenceRequest = try AIBattleEvidenceController.evidenceRequest()
            movieRequest = try AIBattleEvidenceController.movieRequest()
            if evidenceRequest != nil && movieRequest != nil {
                throw AIBattleEvidenceError.invalidArgument("Use either --aibattle-evidence or --aibattle-movie, not both.")
            }
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
        } else if let movieRequest {
            Task { @MainActor in
                do {
                    let result = try AIBattleEvidenceController.saveMovie(request: movieRequest)
                    print("aibattle-movie: \(result.outputURL.path)")
                    print("aibattle-movie-report: \(result.reportURL.path)")
                    print("aibattle-movie-frames: \(result.frameCount)")
                    print("aibattle-movie-target: \(result.snapshot.firstTuningTarget)")
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
            if evidenceRequest == nil && movieRequest == nil {
                AIBattleContentView()
                    .frame(minWidth: 1180, minHeight: 760)
            } else {
                Text(movieRequest == nil ? "AIBattle evidence capture" : "AIBattle movie capture")
                    .frame(width: 320, height: 120)
            }
        }
        .windowStyle(.titleBar)
    }
}
