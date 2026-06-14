import AVFoundation
import Foundation

struct MosulAudioSettings: Equatable {
    static let mutedDefaultsKey = "mosul.sound.muted"
    static let masterVolumeDefaultsKey = "mosul.sound.masterVolume"
    static let defaultMasterVolume = 0.55

    var muted: Bool
    var masterVolume: Double
    var disabledByLaunchArgument: Bool
}

enum MosulAudioBus: String, Codable, CaseIterable, Hashable {
    case ambience
    case tactical
    case radio
    case ui
}

enum MosulAudioAssetKind: String, Codable {
    case loop
    case oneShot = "one_shot"
    case voice
}

struct MosulAudioAsset: Decodable, Equatable {
    let id: String
    let file: String
    let bus: MosulAudioBus
    let kind: MosulAudioAssetKind
    let license: String
    let attribution: String
    let sourceURL: String
    let locale: String
    let transcript: String
    let durationSeconds: Double?
    let loopPointsSeconds: [Double]?
    let lufs: Double?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case file
        case bus
        case kind
        case license
        case attribution
        case sourceURL = "source_url"
        case locale
        case transcript
        case durationSeconds = "duration_seconds"
        case loopPointsSeconds = "loop_points_seconds"
        case lufs
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        file = try container.decode(String.self, forKey: .file)
        bus = try container.decode(MosulAudioBus.self, forKey: .bus)
        kind = try container.decode(MosulAudioAssetKind.self, forKey: .kind)
        license = try container.decode(String.self, forKey: .license)
        attribution = try container.decodeIfPresent(String.self, forKey: .attribution) ?? ""
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL) ?? ""
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? ""
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript) ?? ""
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        loopPointsSeconds = try container.decodeIfPresent([Double].self, forKey: .loopPointsSeconds)
        lufs = try container.decodeIfPresent(Double.self, forKey: .lufs)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

struct MosulAudioManifest: Decodable, Equatable {
    let schemaVersion: Int
    let loudnessTargetLUFS: Double?
    let assets: [MosulAudioAsset]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case loudnessTargetLUFS = "loudness_target_lufs"
        case assets
    }
}

enum MosulOrderKind: String, Equatable {
    case move
    case investigate
    case fire
    case watch
    case hold
    case rally
    case search
    case breach
    case route
    case step
    case opponentTick = "opponent_tick"
    case reset
    case unknown

    init(mapMode: MosulMapMode) {
        switch mapMode {
        case .select:
            self = .unknown
        case .move:
            self = .move
        case .investigate:
            self = .investigate
        case .fire:
            self = .fire
        }
    }

    init(engineOrder: Int32) {
        switch engineOrder {
        case 1:
            self = .hold
        case 2:
            self = .move
        case 6:
            self = .watch
        case 8:
            self = .rally
        case 10:
            self = .investigate
        default:
            self = .unknown
        }
    }
}

enum MosulFireAudioOutcome: String, Equatable {
    case failed
    case blockedLineOfSight = "blocked_line_of_sight"
    case noShots = "no_shots"
    case fired
}

enum MosulCivilianRiskAudioLevel: String, Equatable {
    case low
    case medium
    case high
}

enum MosulOutcomeBand: String, Equatable {
    case success
    case partial
    case failure
    case unresolved

    init(scoreOutcome: Int32) {
        switch scoreOutcome {
        case 1:
            self = .success
        case 2:
            self = .partial
        case 3:
            self = .failure
        default:
            self = .unresolved
        }
    }
}

struct MosulAudioContext: Equatable {
    var tick: UInt32
    var selectedSide: MosulPlayableSide?
    var selectedUnitID: UInt32?
    var mapZoom: Double
    var visibleContactCount: Int
    var unresolvedCivilianRiskCount: Int
    var movingVisibleUnitCount: Int
    var movingTrafficVehicleCount: Int
    var activeTargetingMode: MosulMapMode?
    var tension: Double

    static let empty = MosulAudioContext(
        tick: 0,
        selectedSide: nil,
        selectedUnitID: nil,
        mapZoom: 1.0,
        visibleContactCount: 0,
        unresolvedCivilianRiskCount: 0,
        movingVisibleUnitCount: 0,
        movingTrafficVehicleCount: 0,
        activeTargetingMode: nil,
        tension: 0
    )

    var reportSummary: String {
        [
            "tick:\(tick)",
            "side:\(selectedSide?.title ?? "none")",
            "unit:\(selectedUnitID.map(String.init) ?? "none")",
            "zoom:\(String(format: "%.2f", mapZoom))",
            "contacts:\(visibleContactCount)",
            "civilian_risk:\(unresolvedCivilianRiskCount)",
            "moving_units:\(movingVisibleUnitCount)",
            "moving_traffic:\(movingTrafficVehicleCount)",
            "mode:\(activeTargetingMode?.rawValue ?? "none")",
            "tension:\(String(format: "%.2f", tension))"
        ].joined(separator: ",")
    }
}

enum MosulAudioEvent: Equatable {
    case battleStarted(side: MosulPlayableSide)
    case unitSelected(id: UInt32, side: MosulPlayableSide)
    case orderArmed(kind: MosulOrderKind)
    case orderPlaced(kind: MosulOrderKind)
    case tickResolved(tick: UInt32)
    case contactRevealed(contactID: UInt32)
    case fireResolved(attackerID: UInt32, targetID: UInt32, outcome: MosulFireAudioOutcome)
    case lineOfSightBlocked
    case invalidCommand(kind: MosulOrderKind)
    case routeBlocked(reason: String)
    case civilianRiskChanged(level: MosulCivilianRiskAudioLevel)
    case objectiveResolved(id: UInt32)
    case afterAction(outcome: MosulOutcomeBand)

    var reportName: String {
        switch self {
        case .battleStarted:
            return "battle_started"
        case .unitSelected:
            return "unit_selected"
        case .orderArmed:
            return "order_armed"
        case .orderPlaced:
            return "order_placed"
        case .tickResolved:
            return "tick_resolved"
        case .contactRevealed:
            return "contact_revealed"
        case .fireResolved:
            return "fire_resolved"
        case .lineOfSightBlocked:
            return "line_of_sight_blocked"
        case .invalidCommand:
            return "invalid_command"
        case .routeBlocked:
            return "route_blocked"
        case .civilianRiskChanged:
            return "civilian_risk_changed"
        case .objectiveResolved:
            return "objective_resolved"
        case .afterAction:
            return "after_action"
        }
    }

    var reportDetail: String {
        switch self {
        case .battleStarted(let side):
            return side.title
        case .unitSelected(let id, let side):
            return "\(side.title):\(id)"
        case .orderArmed(let kind), .orderPlaced(let kind):
            return kind.rawValue
        case .tickResolved(let tick):
            return String(tick)
        case .contactRevealed(let contactID):
            return String(contactID)
        case .fireResolved(let attackerID, let targetID, let outcome):
            return "\(attackerID)->\(targetID):\(outcome.rawValue)"
        case .lineOfSightBlocked:
            return "blocked"
        case .invalidCommand(let kind):
            return kind.rawValue
        case .routeBlocked(let reason):
            return reason.isEmpty ? "blocked" : reason
        case .civilianRiskChanged(let level):
            return level.rawValue
        case .objectiveResolved(let id):
            return String(id)
        case .afterAction(let outcome):
            return outcome.rawValue
        }
    }

    var reportLine: String {
        "\(reportName):\(reportDetail)"
    }
}

enum MosulAudioStatus: Equatable {
    case unconfigured
    case disabledByLaunchArgument
    case silentNoManifest
    case engineReady(assetCount: Int, loopCount: Int, running: Bool)
    case manifestInvalid(String)
    case engineFailed(String)

    var description: String {
        switch self {
        case .unconfigured:
            return "Sound is waiting for runtime resources."
        case .disabledByLaunchArgument:
            return "Sound is disabled for this launch."
        case .silentNoManifest:
            return "Sound is ready, with no bundled audio manifest yet."
        case .engineReady(let assetCount, let loopCount, let running):
            let runningText = running ? "running" : "idle"
            return "Sound engine \(runningText) with \(assetCount) manifest assets and \(loopCount) loops."
        case .manifestInvalid(let message):
            return "Sound manifest issue: \(message)"
        case .engineFailed(let message):
            return "Sound engine issue: \(message)"
        }
    }
}

@MainActor
final class MosulAudioController: ObservableObject {
    @Published private(set) var settings: MosulAudioSettings
    @Published private(set) var status: MosulAudioStatus = .unconfigured
    @Published private(set) var context = MosulAudioContext.empty

    private enum CueID {
        static let orderArm = "ui.order.arm"
        static let orderConfirm = "ui.order.confirm"
        static let invalid = "ui.invalid"
        static let tick = "tactical.tick"
        static let movement = "tactical.movement"
        static let contact = "tactical.contact"
        static let routeBlocked = "tactical.route_blocked"
        static let fire = "tactical.fire"
        static let objective = "tactical.objective"
        static let risk = "tactical.risk"
    }

    private let userDefaults: UserDefaults
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private var busMixers: [MosulAudioBus: AVAudioMixerNode] = [:]
    private var loopPlayers: [String: AVAudioPlayerNode] = [:]
    private var loopFiles: [String: AVAudioFile] = [:]
    private var loopAssets: [String: MosulAudioAsset] = [:]
    private var oneShotPlayers: [String: AVAudioPlayerNode] = [:]
    private var oneShotFiles: [String: AVAudioFile] = [:]
    private var oneShotAssets: [String: MosulAudioAsset] = [:]
    private var graphConfigured = false
    private var currentRuntimeRoot: URL?
    private var manifestAssetCount = 0
    private var ambienceDucked = false
    private var duckRestoreWorkItem: DispatchWorkItem?
    private var lastCuePlayback: [String: TimeInterval] = [:]

    init(
        userDefaults: UserDefaults = .standard,
        launchArguments: [String] = CommandLine.arguments
    ) {
        self.userDefaults = userDefaults

        let storedVolume = userDefaults.object(forKey: MosulAudioSettings.masterVolumeDefaultsKey) as? Double
        let volume = Self.clampedVolume(storedVolume ?? MosulAudioSettings.defaultMasterVolume)
        settings = MosulAudioSettings(
            muted: userDefaults.bool(forKey: MosulAudioSettings.mutedDefaultsKey),
            masterVolume: volume,
            disabledByLaunchArgument: launchArguments.contains(MosulApp.disableAudioArgument)
        )

        if settings.disabledByLaunchArgument {
            status = .disabledByLaunchArgument
        }
    }

    var isMuted: Bool {
        settings.disabledByLaunchArgument || settings.muted
    }

    var isSilent: Bool {
        isMuted || settings.masterVolume <= 0
    }

    var isDisabledByLaunchArgument: Bool {
        settings.disabledByLaunchArgument
    }

    var masterVolume: Double {
        settings.masterVolume
    }

    var loadedAssetCount: Int {
        manifestAssetCount
    }

    var loadedLoopCount: Int {
        loopPlayers.count
    }

    var loadedCueCount: Int {
        oneShotPlayers.count
    }

    var accessibilityValue: String {
        if settings.disabledByLaunchArgument {
            return "Sound disabled for this launch"
        }
        if isMuted {
            return "Sound muted"
        }
        return "Sound on, \(Int((settings.masterVolume * 100).rounded())) percent volume"
    }

    func configure(runtimeResources: MosulRuntimeResources) {
        guard !settings.disabledByLaunchArgument else {
            stopAll()
            status = .disabledByLaunchArgument
            return
        }

        if currentRuntimeRoot == runtimeResources.runtimeAssetRootURL {
            startLoopPlaybackIfNeeded()
            applyMixerVolumes()
            refreshStatus()
            return
        }

        stopAll()
        detachPlayers()
        currentRuntimeRoot = runtimeResources.runtimeAssetRootURL
        manifestAssetCount = 0

        let manifestURL = runtimeResources.runtimeAssetRootURL
            .appendingPathComponent("assets/mosul/audio/mosul_audio_manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            status = .silentNoManifest
            return
        }

        do {
            let manifest = try Self.loadManifest(at: manifestURL)
            manifestAssetCount = manifest.assets.count
            try configureGraphIfNeeded()
            try loadAssets(manifest.assets, relativeTo: manifestURL.deletingLastPathComponent())
            applyMixerVolumes()
            refreshStatus()
        } catch {
            status = .manifestInvalid(error.localizedDescription)
        }
    }

    func toggleMuted() {
        setMuted(!settings.muted)
    }

    func setMuted(_ muted: Bool) {
        guard !settings.disabledByLaunchArgument else { return }

        settings.muted = muted
        userDefaults.set(muted, forKey: MosulAudioSettings.mutedDefaultsKey)
        applyMixerVolumes()
        startLoopPlaybackIfNeeded()
        refreshStatus()
    }

    func setMasterVolume(_ volume: Double) {
        guard !settings.disabledByLaunchArgument else { return }

        settings.masterVolume = Self.clampedVolume(volume)
        userDefaults.set(settings.masterVolume, forKey: MosulAudioSettings.masterVolumeDefaultsKey)
        applyMixerVolumes()
        startLoopPlaybackIfNeeded()
        refreshStatus()
    }

    func updateContext(_ nextContext: MosulAudioContext) {
        context = nextContext
        setAmbienceDucked(nextContext.tension >= 0.65)
        applyMixerVolumes()
        startLoopPlaybackIfNeeded()
        refreshStatus()
    }

    func play(_ event: MosulAudioEvent) {
        guard !settings.disabledByLaunchArgument else { return }

        switch event {
        case .battleStarted, .unitSelected:
            playCue(CueID.orderConfirm, cooldown: 0.12)
        case .orderArmed:
            playCue(CueID.orderArm, cooldown: 0.08)
        case .orderPlaced(let kind):
            playOrderPlacedCue(kind)
        case .tickResolved:
            if context.movingVisibleUnitCount > 0 || context.movingTrafficVehicleCount > 0 {
                playCue(CueID.movement, cooldown: 0.35)
            } else {
                playCue(CueID.tick, cooldown: 0.28)
            }
        case .contactRevealed:
            duckAmbienceBriefly()
            playCue(CueID.contact, cooldown: 0.6)
        case .fireResolved(_, _, let outcome):
            duckAmbienceBriefly()
            switch outcome {
            case .fired:
                playCue(CueID.fire, cooldown: 0.5)
            case .blockedLineOfSight:
                playCue(CueID.routeBlocked, cooldown: 0.35)
            case .failed, .noShots:
                playCue(CueID.invalid, cooldown: 0.2)
            }
        case .lineOfSightBlocked, .routeBlocked:
            duckAmbienceBriefly()
            playCue(CueID.routeBlocked, cooldown: 0.35)
        case .invalidCommand:
            playCue(CueID.invalid, cooldown: 0.18)
        case .civilianRiskChanged:
            duckAmbienceBriefly()
            playCue(CueID.risk, cooldown: 0.8)
        case .objectiveResolved, .afterAction:
            playCue(CueID.objective, cooldown: 0.8)
        }
    }

    private func playOrderPlacedCue(_ kind: MosulOrderKind) {
        switch kind {
        case .move, .route, .investigate:
            playCue(CueID.orderConfirm, cooldown: 0.1)
            playCue(CueID.movement, cooldown: 0.25)
        case .fire:
            playCue(CueID.orderArm, cooldown: 0.1)
        case .watch, .hold, .rally, .search, .breach, .step, .opponentTick, .reset, .unknown:
            playCue(CueID.orderConfirm, cooldown: 0.1)
        }
    }

    private func playCue(_ assetID: String, cooldown: TimeInterval) {
        guard !isSilent,
              let player = oneShotPlayers[assetID],
              let file = oneShotFiles[assetID] else {
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        if let previous = lastCuePlayback[assetID], now - previous < cooldown {
            return
        }
        lastCuePlayback[assetID] = now

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.stop()
            player.scheduleFile(file, at: nil)
            player.play()
            refreshStatus()
        } catch {
            status = .engineFailed(error.localizedDescription)
        }
    }

    func stopAll() {
        duckRestoreWorkItem?.cancel()
        duckRestoreWorkItem = nil
        for player in loopPlayers.values {
            player.stop()
        }
        for player in oneShotPlayers.values {
            player.stop()
        }
        if engine.isRunning {
            engine.pause()
        }
        refreshStatus()
    }

    private func configureGraphIfNeeded() throws {
        guard !graphConfigured else { return }

        engine.attach(masterMixer)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: nil)

        for bus in MosulAudioBus.allCases {
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(mixer, to: masterMixer, format: nil)
            busMixers[bus] = mixer
        }

        graphConfigured = true
    }

    private func loadAssets(_ assets: [MosulAudioAsset], relativeTo audioRoot: URL) throws {
        for asset in assets {
            let fileURL = audioRoot.appendingPathComponent(asset.file)
            let file = try AVAudioFile(forReading: fileURL)

            switch asset.kind {
            case .loop:
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: mixer(for: asset.bus), format: file.processingFormat)
                loopPlayers[asset.id] = player
                loopFiles[asset.id] = file
                loopAssets[asset.id] = asset
            case .oneShot, .voice:
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: mixer(for: asset.bus), format: file.processingFormat)
                player.volume = 0.8
                oneShotPlayers[asset.id] = player
                oneShotFiles[asset.id] = file
                oneShotAssets[asset.id] = asset
            }
        }
    }

    private func detachPlayers() {
        for player in loopPlayers.values {
            player.stop()
            engine.detach(player)
        }
        for player in oneShotPlayers.values {
            player.stop()
            engine.detach(player)
        }
        loopPlayers.removeAll()
        loopFiles.removeAll()
        loopAssets.removeAll()
        oneShotPlayers.removeAll()
        oneShotFiles.removeAll()
        oneShotAssets.removeAll()
        lastCuePlayback.removeAll()
    }

    private func mixer(for bus: MosulAudioBus) -> AVAudioMixerNode {
        busMixers[bus] ?? masterMixer
    }

    private func startLoopPlaybackIfNeeded() {
        guard shouldRunLoops else {
            return
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            applyLoopVolumes()
            for assetID in loopPlayers.keys.sorted() {
                startLoop(assetID)
            }
        } catch {
            status = .engineFailed(error.localizedDescription)
        }
    }

    private func startLoop(_ assetID: String) {
        guard let player = loopPlayers[assetID],
              let file = loopFiles[assetID],
              !player.isPlaying else {
            return
        }

        scheduleLoop(assetID, file: file, player: player)
        player.play()
    }

    private func scheduleLoop(_ assetID: String, file: AVAudioFile, player: AVAudioPlayerNode) {
        player.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor in
                self?.loopDidFinish(assetID)
            }
        }
    }

    private func loopDidFinish(_ assetID: String) {
        guard shouldRunLoops,
              engine.isRunning,
              let player = loopPlayers[assetID],
              let file = loopFiles[assetID] else {
            return
        }

        scheduleLoop(assetID, file: file, player: player)
        if !player.isPlaying {
            player.play()
        }
    }

    private var shouldRunLoops: Bool {
        !isSilent && !loopPlayers.isEmpty && context.selectedSide != nil
    }

    private func applyMixerVolumes() {
        masterMixer.outputVolume = isMuted ? 0 : Float(settings.masterVolume)
        let tension = Float(min(1, max(0, context.tension)))
        let ambienceDuck: Float = ambienceDucked ? 0.42 : 1.0
        busMixers[.ambience]?.outputVolume = ambienceDuck * (1.0 - 0.18 * tension)
        busMixers[.tactical]?.outputVolume = min(1.0, 0.9 + 0.1 * tension)
        busMixers[.radio]?.outputVolume = 0.82
        busMixers[.ui]?.outputVolume = 0.82
        applyLoopVolumes()
    }

    private func applyLoopVolumes() {
        let tension = min(1, max(0, context.tension))
        let zoomFocus = min(1, max(0, (context.mapZoom - 1.0) / 2.0))
        let movement = min(1, Double(context.movingVisibleUnitCount + context.movingTrafficVehicleCount) / 5.0)

        for (assetID, player) in loopPlayers {
            guard let asset = loopAssets[assetID] else {
                player.volume = 0.18
                continue
            }

            let tags = Set(asset.tags)
            var volume = 0.16
            if tags.contains("low_tension") {
                volume = 0.34 * (1.0 - 0.46 * tension) * (1.0 - 0.18 * zoomFocus)
            } else if tags.contains("high_tension") {
                volume = 0.04 + 0.26 * tension
            } else if tags.contains("generator") {
                volume = 0.10 + 0.12 * zoomFocus
            } else if tags.contains("engine") {
                volume = 0.05 + 0.18 * movement + 0.06 * zoomFocus
            }

            player.volume = Float(min(0.44, max(0.02, volume)))
        }
    }

    private func setAmbienceDucked(_ ducked: Bool) {
        guard ambienceDucked != ducked else { return }
        ambienceDucked = ducked
        applyMixerVolumes()
    }

    private func duckAmbienceBriefly() {
        setAmbienceDucked(true)
        duckRestoreWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.setAmbienceDucked(false)
            }
        }
        duckRestoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: workItem)
    }

    private func refreshStatus() {
        guard !settings.disabledByLaunchArgument else {
            status = .disabledByLaunchArgument
            return
        }
        guard currentRuntimeRoot != nil else {
            status = .unconfigured
            return
        }

        status = .engineReady(
            assetCount: manifestAssetCount,
            loopCount: loopPlayers.count,
            running: engine.isRunning
        )
    }

    private static func loadManifest(at manifestURL: URL) throws -> MosulAudioManifest {
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(MosulAudioManifest.self, from: data)
        guard manifest.schemaVersion == 1 else {
            throw MosulAudioManifestError.unsupportedSchema(manifest.schemaVersion)
        }
        return manifest
    }

    private static func clampedVolume(_ volume: Double) -> Double {
        guard volume.isFinite else {
            return MosulAudioSettings.defaultMasterVolume
        }
        return min(1, max(0, volume))
    }
}

private enum MosulAudioManifestError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "unsupported audio manifest schema_version \(version)"
        }
    }
}
