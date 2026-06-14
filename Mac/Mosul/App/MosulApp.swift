import Darwin
import SwiftUI

private let mosulProcessStartNanoseconds = DispatchTime.now().uptimeNanoseconds

@main
struct MosulApp: App {
    private static let runtimeCheckArgument = "--check-runtime-resources"
    private static let runtimeCheckOutputArgument = "--runtime-check-output"
    private static let performanceBudgetArgument = "--performance-budget"
    private static let performanceReportArgument = "--performance-report"
    private static let audioSmokeArgument = "--audio-smoke"
    private static let audioSmokeReportArgument = "--audio-smoke-report"
    static let requireBundledRuntimeArgument = "--require-bundled-runtime"
    static let disableAudioArgument = "--disable-audio"

    private let evidenceRequest: SnapshotController.EvidenceRequest?
    private let runtimeCheckRequested: Bool
    private let performanceCheckRequested: Bool
    private let performanceReportURL: URL?
    private let audioSmokeRequested: Bool
    private let audioSmokeReportURL: URL?

    init() {
        runtimeCheckRequested = CommandLine.arguments.contains(Self.runtimeCheckArgument)
        performanceReportURL = Self.argumentURL(after: Self.performanceReportArgument)
        performanceCheckRequested = performanceReportURL != nil
            || CommandLine.arguments.contains(Self.performanceBudgetArgument)
        audioSmokeReportURL = Self.argumentURL(after: Self.audioSmokeReportArgument)
        audioSmokeRequested = audioSmokeReportURL != nil
            || CommandLine.arguments.contains(Self.audioSmokeArgument)
        let requireBundledRuntime = CommandLine.arguments.contains(Self.requireBundledRuntimeArgument)
        let runtimeCheckOutputURL = Self.argumentURL(after: Self.runtimeCheckOutputArgument)
        let requestedPerformanceReportURL = performanceReportURL
        let requestedAudioSmokeReportURL = audioSmokeReportURL

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
        } else if audioSmokeRequested {
            Task { @MainActor in
                do {
                    let report = try Self.audioSmokeReport(requireBundledRuntime: requireBundledRuntime)
                    if let requestedAudioSmokeReportURL {
                        try Self.writeReport(report, to: requestedAudioSmokeReportURL)
                    }
                    print(report)
                    exit(EXIT_SUCCESS)
                } catch {
                    let report = Self.failureReport(check: "mosulgame_audio_smoke", error: error)
                    if let requestedAudioSmokeReportURL {
                        try? Self.writeReport(report, to: requestedAudioSmokeReportURL)
                    }
                    fputs("audio-smoke: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        } else if performanceCheckRequested {
            Task { @MainActor in
                do {
                    let result = try Self.performanceBudgetReport(requireBundledRuntime: requireBundledRuntime)
                    if let requestedPerformanceReportURL {
                        try Self.writeReport(result.report, to: requestedPerformanceReportURL)
                    }
                    print(result.report)
                    exit(result.passed ? EXIT_SUCCESS : EXIT_FAILURE)
                } catch {
                    let report = Self.failureReport(check: "mosulgame_performance_budget", error: error)
                    if let requestedPerformanceReportURL {
                        try? Self.writeReport(report, to: requestedPerformanceReportURL)
                    }
                    fputs("performance-budget: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        } else if runtimeCheckRequested {
            Task { @MainActor in
                do {
                    let summary = try Self.runtimeResourceCheckSummary(requireBundledRuntime: requireBundledRuntime)
                    if let runtimeCheckOutputURL {
                        try Self.writeReport(summary, to: runtimeCheckOutputURL)
                    }
                    print(summary)
                    exit(EXIT_SUCCESS)
                } catch {
                    let report = Self.failureReport(check: "mosulgame_runtime_resources", error: error)
                    if let runtimeCheckOutputURL {
                        try? Self.writeReport(report, to: runtimeCheckOutputURL)
                    }
                    fputs("runtime-check: \(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if evidenceRequest == nil && !runtimeCheckRequested && !performanceCheckRequested && !audioSmokeRequested {
                ContentView()
                    .frame(minWidth: 980, minHeight: 680)
            } else {
                Text(commandModeTitle)
                    .frame(width: 320, height: 120)
            }
        }
        .windowStyle(.titleBar)
    }

    private var commandModeTitle: String {
        if audioSmokeRequested {
            return "Audio smoke check"
        }
        if performanceCheckRequested {
            return "Performance budget check"
        }
        if runtimeCheckRequested {
            return "Runtime resource check"
        }
        return "Snapshot evidence capture"
    }

    private static func argumentURL(after option: String, arguments: [String] = CommandLine.arguments) -> URL? {
        guard let argumentIndex = arguments.firstIndex(of: option) else {
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

        if let issue = model.releaseIssue {
            throw RuntimeResourceCheckError.releaseIssue(issue)
        }

        if requireBundledRuntime && model.runtimeResources.source != .bundledApp {
            throw RuntimeResourceCheckError.releaseIssue(
                .bundledRuntimeRequired(actualSource: model.runtimeResources.source.description)
            )
        }

        guard fileManager.fileExists(atPath: model.mapOverviewPath) else {
            throw RuntimeResourceCheckError.releaseIssue(.missingRuntimeFile(path: model.mapOverviewPath))
        }

        guard let baseLevel = model.mapLevels.first(where: { $0.isBase && !$0.imagePath.isEmpty }) else {
            throw RuntimeResourceCheckError.releaseIssue(.noMapLevel)
        }

        guard fileManager.fileExists(atPath: baseLevel.imagePath) else {
            throw RuntimeResourceCheckError.releaseIssue(.missingRuntimeFile(path: baseLevel.imagePath))
        }

        let spriteManifest = SharedSpriteManifest.shared(for: model.runtimeResources)
        guard model.units.contains(where: { spriteManifest.unitSprite(for: $0) != nil }) else {
            throw RuntimeResourceCheckError.releaseIssue(.noUnitSprite)
        }

        return [
            "ok=true",
            "check=mosulgame_runtime_resources",
            "runtime_source=\(model.runtimeResources.source.description)",
            "runtime_asset_root=\(model.runtimeResources.runtimeAssetRoot)",
            "scenario=\(model.scenarioName)",
            "map_levels=\(model.mapLevels.count)",
            "units=\(model.units.count)",
            "message=MosulGame runtime resources are ready."
        ].joined(separator: "\n") + "\n"
    }

    @MainActor
    private static func audioSmokeReport(requireBundledRuntime: Bool) throws -> String {
        let model = MosulGameModel()

        if let issue = model.releaseIssue {
            throw RuntimeResourceCheckError.releaseIssue(issue)
        }

        if requireBundledRuntime && model.runtimeResources.source != .bundledApp {
            throw RuntimeResourceCheckError.releaseIssue(
                .bundledRuntimeRequired(actualSource: model.runtimeResources.source.description)
            )
        }

        let defaults = UserDefaults(suiteName: "mosul.audio.smoke.\(UUID().uuidString)") ?? .standard
        defaults.set(false, forKey: MosulAudioSettings.mutedDefaultsKey)
        defaults.set(MosulAudioSettings.defaultMasterVolume, forKey: MosulAudioSettings.masterVolumeDefaultsKey)

        let audio = MosulAudioController(userDefaults: defaults, launchArguments: CommandLine.arguments)
        audio.configure(runtimeResources: model.runtimeResources)
        audio.updateContext(model.audioContext)
        let preBattleStatus = audio.status.description
        let preBattlePlayingLoopCount = audio.playingLoopCount

        model.startPlayableBattle(as: .usPatrol)
        model.updateTacticalMapZoom(2.25)
        audio.updateContext(model.audioContext)
        let configuredStatus = audio.status.description

        audio.setMuted(true)
        let mutedAfterToggle = audio.isMuted
        let mutedValue = audio.accessibilityValue

        audio.setMuted(false)
        audio.setMasterVolume(0.4)
        let probeEvents: [MosulAudioEvent] = [
            .battleStarted(side: .usPatrol),
            .orderArmed(kind: .move),
            .orderPlaced(kind: .move),
            .tickResolved(tick: model.tick),
            .contactRevealed(contactID: 1),
            .invalidCommand(kind: .fire),
            .routeBlocked(reason: "blocked"),
            .fireResolved(attackerID: 1, targetID: 2, outcome: .fired),
            .civilianRiskChanged(level: .medium),
            .objectiveResolved(id: 1)
        ]
        for event in probeEvents {
            audio.play(event)
        }
        let mutedAfterUnmute = audio.isMuted
        let unmutedValue = audio.accessibilityValue
        let captionAfterProbe = audio.caption
        let finalStatus = audio.status.description
        audio.stopAll()

        return [
            "ok=true",
            "check=mosulgame_audio_smoke",
            "runtime_source=\(model.runtimeResources.source.description)",
            "audio_pre_battle_status=\(preBattleStatus)",
            "audio_pre_battle_playing_loop_count=\(preBattlePlayingLoopCount)",
            "audio_status=\(configuredStatus)",
            "audio_final_status=\(finalStatus)",
            "audio_asset_count=\(audio.loadedAssetCount)",
            "audio_loop_count=\(audio.loadedLoopCount)",
            "audio_cue_count=\(audio.loadedCueCount)",
            "audio_voice_count=\(audio.loadedVoiceCount)",
            "audio_muted_after_toggle=\(mutedAfterToggle)",
            "audio_muted_value=\(mutedValue)",
            "audio_muted_after_unmute=\(mutedAfterUnmute)",
            "audio_unmuted_value=\(unmutedValue)",
            "audio_caption=\(captionAfterProbe)",
            "audio_probe_events=\(probeEvents.map(\.reportName).joined(separator: ","))",
            "audio_context=\(model.audioContext.reportSummary)"
        ].joined(separator: "\n") + "\n"
    }

    @MainActor
    private static func performanceBudgetReport(requireBundledRuntime: Bool) throws -> MosulPerformanceReport {
        let budget = MosulPerformanceBudget()
        let processStart = mosulProcessStartNanoseconds
        let totalStart = DispatchTime.now().uptimeNanoseconds
        let launchToProbeMS = milliseconds(from: processStart, to: totalStart)

        let modelStart = DispatchTime.now().uptimeNanoseconds
        let model = MosulGameModel()
        let modelLoadMS = milliseconds(from: modelStart)

        if let issue = model.releaseIssue {
            throw RuntimeResourceCheckError.releaseIssue(issue)
        }

        if requireBundledRuntime && model.runtimeResources.source != .bundledApp {
            throw RuntimeResourceCheckError.releaseIssue(
                .bundledRuntimeRequired(actualSource: model.runtimeResources.source.description)
            )
        }

        let spriteStart = DispatchTime.now().uptimeNanoseconds
        let spriteManifest = SharedSpriteManifest.shared(for: model.runtimeResources)
        let unitSpriteCount = model.units.compactMap { spriteManifest.unitSprite(for: $0) }.count
        let trafficSpriteCount = model.trafficVehicles.compactMap { spriteManifest.trafficVehicleSprite(for: $0) }.count
        let spriteResolveMS = milliseconds(from: spriteStart)

        let mapStats = mapPNGStats(for: model)
        SharedImageCache.shared.reset()

        let renderStart = DispatchTime.now().uptimeNanoseconds
        let content = SharedTacticalMapView(model: model, scrollable: false)
            .frame(width: 1440, height: 900)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 1440, height: 900)
        renderer.scale = 1
        guard renderer.cgImage != nil else {
            throw RuntimeResourceCheckError.performance("Could not render the first tactical map frame.")
        }
        let firstRenderMS = milliseconds(from: renderStart)

        let cacheStats = SharedImageCache.shared.stats()
        let residentMB = megabytes(residentMemoryBytes())
        let totalProbeMS = milliseconds(from: totalStart)
        let failedBudgets = budget.failedBudgets(
            launchToProbeMS: launchToProbeMS,
            modelLoadMS: modelLoadMS,
            spriteResolveMS: spriteResolveMS,
            firstRenderMS: firstRenderMS,
            totalProbeMS: totalProbeMS,
            residentMemoryMB: residentMB,
            mapPNGTotalMB: mapStats.totalMB,
            largestMapPNGMB: mapStats.largestMB
        )
        let passed = failedBudgets.isEmpty

        let lines = [
            "ok=\(passed ? "true" : "false")",
            "check=mosulgame_performance_budget",
            "runtime_source=\(model.runtimeResources.source.description)",
            "runtime_asset_root=\(model.runtimeResources.runtimeAssetRoot)",
            "scenario=\(model.scenarioName)",
            "launch_to_probe_ms=\(format(launchToProbeMS))",
            "model_load_ms=\(format(modelLoadMS))",
            "sprite_resolve_ms=\(format(spriteResolveMS))",
            "first_map_render_ms=\(format(firstRenderMS))",
            "total_probe_ms=\(format(totalProbeMS))",
            "resident_memory_mb=\(format(residentMB))",
            "map_png_files=\(mapStats.fileCount)",
            "map_png_total_mb=\(format(mapStats.totalMB))",
            "largest_map_png_mb=\(format(mapStats.largestMB))",
            "largest_map_png=\(mapStats.largestPath)",
            "resolved_unit_sprites=\(unitSpriteCount)",
            "resolved_traffic_sprites=\(trafficSpriteCount)",
            "cached_images=\(cacheStats.loadedImageCount)",
            "missing_cached_images=\(cacheStats.missingImageCount)",
            "cached_image_file_mb=\(format(megabytes(cacheStats.loadedFileBytes)))",
            "budget_launch_to_probe_ms=\(format(budget.launchToProbeMS))",
            "budget_model_load_ms=\(format(budget.modelLoadMS))",
            "budget_sprite_resolve_ms=\(format(budget.spriteResolveMS))",
            "budget_first_map_render_ms=\(format(budget.firstRenderMS))",
            "budget_total_probe_ms=\(format(budget.totalProbeMS))",
            "budget_resident_memory_mb=\(format(budget.residentMemoryMB))",
            "budget_map_png_total_mb=\(format(budget.mapPNGTotalMB))",
            "budget_largest_map_png_mb=\(format(budget.largestMapPNGMB))",
            "failed_budgets=\(failedBudgets.isEmpty ? "none" : failedBudgets.joined(separator: ","))"
        ]

        return MosulPerformanceReport(passed: passed, report: lines.joined(separator: "\n") + "\n")
    }

    private static func writeReport(_ report: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try report.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func failureReport(check: String, error: Error) -> String {
        var lines = [
            "ok=false",
            "check=\(check)",
            "error=\(MosulReleaseIssue.reportValue(error.localizedDescription))"
        ]

        if let runtimeError = error as? RuntimeResourceCheckError,
           let issue = runtimeError.releaseIssue {
            lines.append(contentsOf: issue.reportLines)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func mapPNGStats(for model: MosulGameModel) -> MosulMapPNGStats {
        let paths = Set(([model.mapOverviewPath] + model.mapLevels.map(\.imagePath)).filter { !$0.isEmpty })
        let fileManager = FileManager.default
        var totalBytes: Int64 = 0
        var largestBytes: Int64 = 0
        var largestPath = "none"

        for path in paths {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            totalBytes += size
            if size > largestBytes {
                largestBytes = size
                largestPath = path
            }
        }

        return MosulMapPNGStats(
            fileCount: paths.count,
            totalMB: megabytes(totalBytes),
            largestMB: megabytes(largestBytes),
            largestPath: largestPath
        )
    }

    private static func residentMemoryBytes() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }
        return Int64(info.resident_size)
    }

    private static func milliseconds(from start: UInt64, to end: UInt64 = DispatchTime.now().uptimeNanoseconds) -> Double {
        guard end >= start else {
            return 0
        }

        return Double(end - start) / 1_000_000.0
    }

    private static func megabytes(_ bytes: Int64) -> Double {
        Double(bytes) / (1024.0 * 1024.0)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

enum RuntimeResourceCheckError: LocalizedError {
    case releaseIssue(MosulReleaseIssue)
    case performance(String)

    var releaseIssue: MosulReleaseIssue? {
        if case .releaseIssue(let issue) = self {
            return issue
        }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .releaseIssue(let issue):
            return "\(issue.title): \(issue.message) \(issue.recovery)"
        case .performance(let message):
            return message
        }
    }
}

private struct MosulPerformanceReport {
    let passed: Bool
    let report: String
}

private struct MosulMapPNGStats {
    let fileCount: Int
    let totalMB: Double
    let largestMB: Double
    let largestPath: String
}

private struct MosulPerformanceBudget {
    let launchToProbeMS = 5_000.0
    let modelLoadMS = 2_500.0
    let spriteResolveMS = 1_500.0
    let firstRenderMS = 5_000.0
    let totalProbeMS = 9_000.0
    let residentMemoryMB = 768.0
    let mapPNGTotalMB = 64.0
    let largestMapPNGMB = 32.0

    func failedBudgets(
        launchToProbeMS: Double,
        modelLoadMS: Double,
        spriteResolveMS: Double,
        firstRenderMS: Double,
        totalProbeMS: Double,
        residentMemoryMB: Double,
        mapPNGTotalMB: Double,
        largestMapPNGMB: Double
    ) -> [String] {
        var failed: [String] = []

        if launchToProbeMS > self.launchToProbeMS {
            failed.append("launch_to_probe_ms")
        }
        if modelLoadMS > self.modelLoadMS {
            failed.append("model_load_ms")
        }
        if spriteResolveMS > self.spriteResolveMS {
            failed.append("sprite_resolve_ms")
        }
        if firstRenderMS > self.firstRenderMS {
            failed.append("first_map_render_ms")
        }
        if totalProbeMS > self.totalProbeMS {
            failed.append("total_probe_ms")
        }
        if residentMemoryMB > self.residentMemoryMB {
            failed.append("resident_memory_mb")
        }
        if mapPNGTotalMB > self.mapPNGTotalMB {
            failed.append("map_png_total_mb")
        }
        if largestMapPNGMB > self.largestMapPNGMB {
            failed.append("largest_map_png_mb")
        }

        return failed
    }
}
