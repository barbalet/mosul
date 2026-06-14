import Foundation
import SwiftUI

private func bridgeString<T>(_ value: T) -> String {
    var copy = value
    return withUnsafePointer(to: &copy) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { cString in
            String(cString: cString)
        }
    }
}

struct MosulUnit: Identifiable {
    let id: UInt32
    let name: String
    let spriteID: String
    let selectionMarkerID: String
    let orderMarkerID: String
    let routeMarkerID: String
    let targetMarkerID: String
    let suppressionMarkerID: String
    let casualtyMarkerID: String
    let levelID: String
    let targetLevelID: String
    let topologyNodeID: String
    let side: Int32
    let order: Int32
    let status: Int32
    let x: CGFloat
    let y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let hasTarget: Bool
    let hidden: Bool
    let revealed: Bool
    let selected: Bool
    let routeUsesVerticalTransition: Bool
    let suppression: Int32
    let morale: Int32
    let soldierCount: Int
    let casualtyCount: Int
}

struct MosulObjective: Identifiable {
    let id: UInt32
    let name: String
    let label: String
    let markerID: String
    let controllingSide: Int32
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let value: Int32
}

struct MosulCivilian: Identifiable {
    let id: UInt32
    let name: String
    let spriteID: String
    let markerID: String
    let x: CGFloat
    let y: CGFloat
    let state: Int32
    let stress: Int32
    let risk: Int32
}

struct MosulTrafficVehicle: Identifiable {
    let id: UInt32
    let scenarioID: String
    let name: String
    let spriteID: String
    let levelID: String
    let destinationLevelID: String
    let topologyNodeID: String
    let routeFailureReason: String
    let kind: Int32
    let boardingMode: Int32
    let x: CGFloat
    let y: CGFloat
    let destinationX: CGFloat
    let destinationY: CGFloat
    let hasDestination: Bool
    let speedMPerTick: CGFloat
    let facingDegrees: CGFloat
    let seatCapacity: Int32
    let occupiedSeats: Int32
    let active: Bool
    let blocksMovement: Bool
    let hasRoute: Bool
    let routeStepCount: Int
    let routeStepIndex: Int
    let routeTotalCost: Int32
    let routeUsesVerticalTransition: Bool
    let routeFailureCount: UInt32

    var isMoving: Bool {
        active && hasDestination
    }

    var isStatic: Bool {
        active && !hasDestination
    }
}

struct MosulContact: Identifiable {
    let id: UInt32
    let tick: UInt32
    let attackerUnitID: UInt32
    let targetUnitID: UInt32
    let markerID: String
    let levelID: String
    let kind: Int32
    let side: Int32
    let x: CGFloat
    let y: CGFloat
    let intensity: Int32
    let confidence: Int32
    let visible: Bool
    let resolved: Bool
}

struct MosulInteraction: Identifiable {
    let numericID: UInt32
    let id: String
    let label: String
    let markerID: String
    let state: String
    let levelID: String
    let targetLevelID: String
    let topologyNodeID: String
    let targetNodeID: String
    let kind: Int32
    let source: Int32
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let distance: CGFloat
    let priority: Int32
    let searched: Bool
    let breached: Bool
    let open: Bool
    let vertical: Bool
    let sameLevel: Bool
    let actionable: Bool
    let routeAvailable: Bool
}

struct MosulMapLevel: Identifiable {
    let id: String
    let imagePath: String
    let alpha: String
    let index: Int32
    let elevationM: CGFloat

    var isBase: Bool {
        index <= 1 || alpha == "opaque"
    }

    var shortLabel: String {
        if isBase {
            return "G"
        }
        if id.contains("roof_access") {
            return "R"
        }
        return "\(index)"
    }

    var displayName: String {
        if isBase {
            return "Ground"
        }
        if id.contains("roof_access") {
            return "Roof Access"
        }
        return "Level \(index)"
    }
}

struct MosulScore {
    var total: Int32 = 0
    var objectivePoints: Int32 = 0
    var interactionPoints: Int32 = 0
    var civilianRiskPenalty: Int32 = 0
    var casualtyPenalty: Int32 = 0
    var timePenalty: Int32 = 0
    var playerCasualties: Int32 = 0
    var opforCasualties: Int32 = 0
    var civilianCasualties: Int32 = 0
    var civilianRisk: Int32 = 0
    var controlledObjectives: UInt32 = 0
    var contestedObjectives: UInt32 = 0
    var outcome: Int32 = 0
}

struct MosulAfterAction {
    var score = MosulScore()
    var summary = ""
    var narrative = ""
}

enum MosulMapMode: String, CaseIterable, Identifiable {
    case select = "Select"
    case move = "Move"
    case investigate = "Investigate"
    case fire = "Fire"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .select:
            return "scope"
        case .move:
            return "arrow.up.right"
        case .investigate:
            return "magnifyingglass"
        case .fire:
            return "scope"
        }
    }

    var prompt: String {
        switch self {
        case .select:
            return "Select a command unit or inspect a reported contact."
        case .move:
            return "Click the map to set a movement target."
        case .investigate:
            return "Click the map to investigate a contact or terrain cue."
        case .fire:
            return "Click a highlighted opposing contact to fire with the selected unit."
        }
    }
}

enum MosulPlayableSide: Int32, CaseIterable, Identifiable {
    case usPatrol = 1
    case opposingCell = 2

    var id: Int32 { rawValue }

    var title: String {
        switch self {
        case .usPatrol:
            return "U.S. Patrol"
        case .opposingCell:
            return "Opposing Cell"
        }
    }

    var subtitle: String {
        switch self {
        case .usPatrol:
            return "Stabilize the market streets, resolve contacts, and protect civilians."
        case .opposingCell:
            return "Disrupt the patrol, preserve hidden positions, and keep the district unsettled."
        }
    }

    var symbolName: String {
        switch self {
        case .usPatrol:
            return "shield.lefthalf.filled"
        case .opposingCell:
            return "scope"
        }
    }

    var opponent: MosulPlayableSide {
        switch self {
        case .usPatrol:
            return .opposingCell
        case .opposingCell:
            return .usPatrol
        }
    }
}

struct MosulRuntimeResources {
    enum Source: Equatable {
        case bundledApp
        case sourceCheckout

        var description: String {
            switch self {
            case .bundledApp:
                return "bundled app resources"
            case .sourceCheckout:
                return "source checkout"
            }
        }
    }

    private static let defaultScenarioPath = "game/mosul/scenarios/market_commercial_streets_2003.mkscenario"
    private static let mapManifestPath = "assets/mosul/manifests/market_commercial_streets_2003.mapmanifest"
    private static let markerManifestPath = "assets/mosul/manifests/mosul_2003_markers.markermanifest"
    private static let spriteRuntimeManifestPath = "assets/mosul/runtime/sprites/manifest.json"

    let runtimeAssetRootURL: URL
    let source: Source

    var runtimeAssetRoot: String {
        runtimeAssetRootURL.path
    }

    static func resolve(
        filePath: String = #filePath,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> MosulRuntimeResources {
        if let bundledRoot = bundledModernerKriegRoot(bundle: bundle, fileManager: fileManager) {
            return MosulRuntimeResources(runtimeAssetRootURL: bundledRoot, source: .bundledApp)
        }

        return MosulRuntimeResources(
            runtimeAssetRootURL: sourceCheckoutModernerKriegRoot(filePath: filePath, fileManager: fileManager),
            source: .sourceCheckout
        )
    }

    private static func bundledModernerKriegRoot(bundle: Bundle, fileManager: FileManager) -> URL? {
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }

        let root = resourceURL
            .appendingPathComponent("mosul-runtime", isDirectory: true)
            .appendingPathComponent("modernerKrieg", isDirectory: true)

        return isUsableModernerKriegRoot(root, fileManager: fileManager) ? root : nil
    }

    private static func sourceCheckoutModernerKriegRoot(filePath: String, fileManager: FileManager) -> URL {
        var candidate = URL(fileURLWithPath: filePath).deletingLastPathComponent()

        for _ in 0..<10 {
            let root = candidate.appendingPathComponent("modernerKrieg", isDirectory: true)
            if isUsableModernerKriegRoot(root, fileManager: fileManager)
                || fileManager.fileExists(atPath: root.appendingPathComponent("README.md").path) {
                return root
            }
            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../modernerKrieg", isDirectory: true)
            .standardized
    }

    private static func isUsableModernerKriegRoot(_ root: URL, fileManager: FileManager) -> Bool {
        [
            defaultScenarioPath,
            mapManifestPath,
            markerManifestPath,
            spriteRuntimeManifestPath
        ].allSatisfy { relativePath in
            fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path)
        }
    }
}

struct MosulReleaseIssue {
    let title: String
    let message: String
    let recovery: String
    let diagnostic: String

    var reportLines: [String] {
        [
            "title=\(Self.reportValue(title))",
            "message=\(Self.reportValue(message))",
            "recovery=\(Self.reportValue(recovery))",
            "diagnostic=\(Self.reportValue(diagnostic))"
        ]
    }

    static func unsupportedPlatform(version: OperatingSystemVersion) -> MosulReleaseIssue {
        MosulReleaseIssue(
            title: "This Mac is not supported",
            message: "MOSUL requires macOS 14 or later for the current SwiftUI renderer and bundled runtime checks.",
            recovery: "Update macOS, or use a Mac that supports macOS 14 or later.",
            diagnostic: "Detected macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)."
        )
    }

    static func runtimeLoadFailure(
        message: String,
        runtimeResources: MosulRuntimeResources
    ) -> MosulReleaseIssue {
        MosulReleaseIssue(
            title: "MOSUL cannot load the demo data",
            message: "The Market / Commercial Streets scenario could not be opened from \(runtimeResources.source.description).",
            recovery: "Reinstall MosulGame, or restore Contents/Resources/mosul-runtime in the app bundle. Development builds can also restore the modernerKrieg checkout.",
            diagnostic: "\(message) Runtime root: \(runtimeResources.runtimeAssetRoot)"
        )
    }

    static func missingRuntimeFile(path: String) -> MosulReleaseIssue {
        MosulReleaseIssue(
            title: "MOSUL runtime file is missing",
            message: "A required scenario, map, or sprite file is not present in the app bundle.",
            recovery: "Reinstall MosulGame from a complete release build, then run the runtime-resource check again.",
            diagnostic: path
        )
    }

    static func bundledRuntimeRequired(actualSource: String) -> MosulReleaseIssue {
        MosulReleaseIssue(
            title: "MOSUL bundled runtime is missing",
            message: "This copy of MosulGame did not load its bundled scenario and art data.",
            recovery: "Use a packaged MosulGame.app that contains Contents/Resources/mosul-runtime, or rebuild the app bundle before distribution.",
            diagnostic: "Loaded \(actualSource) instead of bundled app resources."
        )
    }

    static var noMapLevel: MosulReleaseIssue {
        MosulReleaseIssue(
            title: "MOSUL map data is incomplete",
            message: "The demo scenario loaded, but no base map level was available for rendering.",
            recovery: "Rebuild the runtime resource payload and verify the map manifest before shipping.",
            diagnostic: "No base MosulMapLevel with an image path was loaded."
        )
    }

    static var noUnitSprite: MosulReleaseIssue {
        MosulReleaseIssue(
            title: "MOSUL unit art is incomplete",
            message: "The demo scenario loaded, but no unit sprite could be resolved from the runtime sprite manifest.",
            recovery: "Regenerate or recopy the runtime sprite payload before shipping.",
            diagnostic: "No playable unit resolved to a runtime PNG sprite."
        )
    }

    static func reportValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

@MainActor
final class MosulGameModel: ObservableObject {
    @Published var scenarioName = "MOSUL"
    @Published var briefing = ""
    @Published var mapName = ""
    @Published var mapOverviewPath = ""
    @Published var mapLevels: [MosulMapLevel] = []
    @Published var visibleMapLevelIDs: Set<String> = []
    @Published var lastError = ""
    @Published var tick: UInt32 = 0
    @Published var mapWidth: CGFloat = 500
    @Published var mapHeight: CGFloat = 500
    @Published var units: [MosulUnit] = []
    @Published var objectives: [MosulObjective] = []
    @Published var civilians: [MosulCivilian] = []
    @Published var trafficVehicles: [MosulTrafficVehicle] = []
    @Published var contacts: [MosulContact] = []
    @Published var interactions: [MosulInteraction] = []
    @Published var score = MosulScore()
    @Published var afterAction = MosulAfterAction()
    @Published var mode: MosulMapMode = .select
    @Published var playableSide: MosulPlayableSide?
    @Published var playerNotice = ""
    @Published private(set) var audioEvents: [MosulAudioEvent] = []
    @Published private(set) var audioContext = MosulAudioContext.empty

    private var engine: OpaquePointer?
    private var mapLevelVisibilityInitialized = false
    private var audioBaselineInitialized = false
    private var lastAudioVisibleContactIDs: Set<UInt32> = []
    private var lastAudioCivilianRisk: Int32 = 0
    private var lastAudioObjectiveControl: [UInt32: Int32] = [:]
    private var lastAudioOutcome: Int32 = 0
    private var tacticalMapZoom = 1.0
    private var battleIndex: UInt32 = 1
    let runtimeResources: MosulRuntimeResources
    let runtimeAssetRoot: String

    var mosulRoot: String {
        URL(fileURLWithPath: runtimeAssetRoot)
            .deletingLastPathComponent()
            .path
    }

    init() {
        runtimeResources = MosulRuntimeResources.resolve()
        runtimeAssetRoot = runtimeResources.runtimeAssetRoot
        engine = runtimeAssetRoot.withCString { root in
            MosulEngineCreate(root)
        }
        refresh()
    }

    deinit {
        if let engine {
            MosulEngineDestroy(engine)
        }
    }

    var selectedUnit: MosulUnit? {
        units.first(where: { $0.selected })
    }

    var releaseIssue: MosulReleaseIssue? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)
        ) {
            return .unsupportedPlatform(version: version)
        }

        if !lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .runtimeLoadFailure(message: lastError, runtimeResources: runtimeResources)
        }

        return nil
    }

    var selectedUnitCanReceiveOrders: Bool {
        guard let selectedUnit else { return false }
        return canIssueOrders(to: selectedUnit)
    }

    var selectedUnitIsPlayerVisible: Bool {
        guard let selectedUnit else { return false }
        return isUnitPlayerVisible(selectedUnit)
    }

    var commandSideTitle: String {
        playableSide?.title ?? "Choose Side"
    }

    var opponentSideTitle: String {
        playableSide?.opponent.title ?? "Opponent"
    }

    var commandHint: String {
        guard let playableSide else {
            return "Choose a side to begin command."
        }

        guard let selectedUnit else {
            return "Select a \(playableSide.title) unit to enable orders."
        }

        guard selectedUnitIsPlayerVisible else {
            return "That contact is not confirmed by \(playableSide.title) observers."
        }

        if selectedUnitCanReceiveOrders {
            return "\(mode.prompt) Active unit: \(playerFacingUnitName(selectedUnit))."
        }

        return "\(playerFacingUnitName(selectedUnit)) is available as intel only; select a \(playableSide.title) unit for orders."
    }

    var hasActiveTargetingMode: Bool {
        mode != .select
    }

    var selectedUnitHasPendingOrder: Bool {
        guard selectedUnitCanReceiveOrders, let selectedUnit else {
            return false
        }

        return selectedUnit.hasTarget
    }

    var selectedUnitPendingOrderHint: String {
        guard let selectedUnit, selectedUnitCanReceiveOrders else {
            return "Select a command unit to issue orders."
        }

        guard selectedUnit.hasTarget else {
            return "No pending map order. Choose Move, Investigate, or Fire."
        }

        return "\(orderName(selectedUnit.order)) target: \(playerFacingPosition(x: selectedUnit.targetX, y: selectedUnit.targetY)). Press Step to execute movement over time."
    }

    var targetingBannerTitle: String {
        switch mode {
        case .select:
            return "Select Unit"
        case .move:
            return "Choose Destination"
        case .investigate:
            return "Choose Investigation Point"
        case .fire:
            return "Choose Fire Target"
        }
    }

    var targetingBannerMessage: String {
        guard selectedUnitCanReceiveOrders, let selectedUnit else {
            return "Select a \(commandSideTitle) unit before issuing orders."
        }

        let unitName = playerFacingUnitName(selectedUnit)
        switch mode {
        case .select:
            return "Click a unit or contact to inspect it."
        case .move:
            return "\(unitName): click the map to set a destination. A dashed line appears; press Step to move."
        case .investigate:
            return "\(unitName): click a suspicious contact, danger area, or task. Press Step to approach cautiously."
        case .fire:
            if fireTargetContacts.isEmpty {
                return "\(unitName): no highlighted fire targets are visible. Investigate contacts, advance time, or cancel targeting."
            }
            return "\(unitName): click a highlighted opposing contact. Line of sight, range, ammunition, and civilian risk are checked."
        }
    }

    var targetingBannerSymbol: String {
        mode.symbolName
    }

    var fireTargetContacts: [MosulContact] {
        playerVisibleContacts.filter(canFire)
    }

    var hiddenEnemyUnitCount: Int {
        units.filter { unit in
            guard let playableSide else { return false }
            return unit.side == playableSide.opponent.rawValue && !isUnitPlayerVisible(unit)
        }.count
    }

    var playerVisibleUnits: [MosulUnit] {
        units.filter(isUnitPlayerVisible)
    }

    var playerVisibleContacts: [MosulContact] {
        contacts.filter(isContactPlayerVisible)
    }

    var tacticalMapLevelIDs: Set<String> {
        var ids = Set<String>()

        if let selectedUnit, isUnitPlayerVisible(selectedUnit) {
            ids.insert(selectedUnit.levelID)
            if canInspectFullIntel(for: selectedUnit) {
                ids.insert(selectedUnit.targetLevelID)
            }
        }

        for unit in playerVisibleUnits where unit.routeUsesVerticalTransition && canInspectFullIntel(for: unit) {
            ids.insert(unit.levelID)
            ids.insert(unit.targetLevelID)
        }

        for contact in playerVisibleContacts where !contact.resolved {
            ids.insert(contact.levelID)
        }

        for interaction in interactions where interaction.actionable || interaction.vertical {
            ids.insert(interaction.levelID)
            ids.insert(interaction.targetLevelID)
        }

        ids.remove("")
        return ids
    }

    var selectedInteractionTasks: [MosulInteraction] {
        guard selectedUnitCanReceiveOrders else { return [] }

        return interactions.sorted { first, second in
            if first.actionable != second.actionable {
                return first.actionable
            }
            if first.searched != second.searched {
                return !first.searched
            }
            if first.distance != second.distance {
                return first.distance < second.distance
            }
            return first.priority > second.priority
        }
    }

    func canIssueOrders(to unit: MosulUnit) -> Bool {
        guard let playableSide else {
            return true
        }

        return unit.side == playableSide.rawValue
    }

    func setMode(_ nextMode: MosulMapMode) {
        if nextMode == .select {
            mode = .select
            playerNotice = nextMode.prompt
            return
        }

        guard selectedUnitCanReceiveOrders else {
            mode = .select
            playerNotice = "Select a \(commandSideTitle) unit before choosing \(nextMode.rawValue)."
            recordAudioEvent(.invalidCommand(kind: MosulOrderKind(mapMode: nextMode)))
            return
        }

        mode = nextMode
        playerNotice = nextMode.prompt
        recordAudioEvent(.orderArmed(kind: MosulOrderKind(mapMode: nextMode)))
    }

    func beginMoveOrder() {
        setMode(.move)
    }

    func beginInvestigateOrder() {
        setMode(.investigate)
    }

    func beginFireOrder() {
        guard selectedUnitCanReceiveOrders else {
            mode = .select
            playerNotice = "Select a \(commandSideTitle) unit before firing."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }

        mode = .fire
        if fireTargetContacts.isEmpty {
            playerNotice = "Fire targeting active. No valid opposing unit contacts are visible yet."
        } else {
            playerNotice = "Fire targeting active. Click a highlighted opposing contact."
        }
        recordAudioEvent(.orderArmed(kind: .fire))
    }

    func cancelTargeting() {
        mode = .select
        playerNotice = "Targeting cancelled."
    }

    func isUnitPlayerVisible(_ unit: MosulUnit) -> Bool {
        guard let playableSide else {
            return true
        }

        if unit.side == playableSide.rawValue || unit.side == 3 {
            return true
        }

        return !unit.hidden || unit.revealed
    }

    func isContactPlayerVisible(_ contact: MosulContact) -> Bool {
        guard playableSide != nil else {
            return true
        }

        return contact.visible || contact.confidence > 0 || contact.resolved
    }

    func canInspectFullIntel(for unit: MosulUnit) -> Bool {
        guard let playableSide else {
            return true
        }

        return unit.side == playableSide.rawValue || unit.side == 3
    }

    func playerFacingUnitName(_ unit: MosulUnit) -> String {
        if canInspectFullIntel(for: unit) {
            return unit.name
        }

        if unit.revealed {
            return "Revealed \(sideName(unit.side))"
        }

        return "Reported \(sideName(unit.side))"
    }

    func playerFacingUnitSideName(_ unit: MosulUnit) -> String {
        guard let playableSide else {
            return sideName(unit.side)
        }

        if unit.side == playableSide.rawValue {
            return "\(playableSide.title) command"
        }

        if unit.side == 3 {
            return "Civilian"
        }

        return "Opposing contact"
    }

    func playerFacingContactSideName(_ contact: MosulContact) -> String {
        guard let playableSide else {
            return sideName(contact.side)
        }

        if contact.side == playableSide.rawValue {
            return "\(playableSide.title) report"
        }

        if contact.side == 3 {
            return "Civilian report"
        }

        if contact.side == 0 {
            return "Unconfirmed"
        }

        return "Opposing contact"
    }

    func playerFacingPosition(x: CGFloat, y: CGFloat) -> String {
        guard playableSide != nil else {
            return "\(Int(x)), \(Int(y)) m"
        }

        let roundedX = Int((x / 10).rounded() * 10)
        let roundedY = Int((y / 10).rounded() * 10)
        return "~\(roundedX), ~\(roundedY) m"
    }

    func playerFacingUnitSummary(_ unit: MosulUnit) -> String {
        let level = levelLabel(for: unit.levelID)

        if canInspectFullIntel(for: unit) {
            return "\(playerFacingUnitSideName(unit)) | \(level) | \(orderName(unit.order)) | \(statusName(unit.status))"
        }

        let certainty = unit.revealed ? "confirmed" : "reported"
        return "\(playerFacingUnitSideName(unit)) | \(level) | \(certainty)"
    }

    var visibleMapLevels: [MosulMapLevel] {
        mapLevels.filter { level in
            level.isBase || visibleMapLevelIDs.contains(level.id)
        }
    }

    var overlayMapLevels: [MosulMapLevel] {
        mapLevels.filter { !$0.isBase }
    }

    func mapLevel(for id: String) -> MosulMapLevel? {
        mapLevels.first { $0.id == id }
    }

    func levelLabel(for id: String) -> String {
        guard !id.isEmpty else {
            return "?"
        }

        if let level = mapLevel(for: id) {
            return level.shortLabel
        }

        if id.contains("ground") {
            return "G"
        }
        if id.contains("roof") {
            return "R"
        }

        return String(id.prefix(2)).uppercased()
    }

    func levelName(for id: String) -> String {
        if let level = mapLevel(for: id) {
            return level.displayName
        }

        return id.isEmpty ? "Unknown" : id
    }

    func levelRelationDescription(for interaction: MosulInteraction) -> String {
        if interaction.vertical {
            return "\(levelLabel(for: interaction.levelID))->\(levelLabel(for: interaction.targetLevelID))"
        }

        if !interaction.sameLevel {
            return "\(levelLabel(for: interaction.levelID))/\(levelLabel(for: interaction.targetLevelID))"
        }

        return levelLabel(for: interaction.levelID)
    }

    func toggleMapLevelVisibility(_ level: MosulMapLevel) {
        guard !level.isBase else { return }

        if visibleMapLevelIDs.contains(level.id) {
            visibleMapLevelIDs.remove(level.id)
        } else {
            visibleMapLevelIDs.insert(level.id)
        }
    }

    func updateTacticalMapZoom(_ zoom: Double) {
        let clamped = min(3.0, max(1.0, zoom.isFinite ? zoom : 1.0))
        guard abs(clamped - tacticalMapZoom) > 0.005 else { return }

        tacticalMapZoom = clamped
        updateAudioContext(
            visibleContactCount: playerVisibleContacts.count,
            civilianRisk: score.civilianRisk
        )
    }

    func reset(battleIndex: UInt32 = 1) {
        guard let engine else { return }
        self.battleIndex = battleIndex
        audioEvents.removeAll()
        audioBaselineInitialized = false
        _ = MosulEngineResetBattle(engine, battleIndex)
        refresh()
    }

    func startPlayableBattle(as side: MosulPlayableSide) {
        playableSide = side
        reset(battleIndex: battleIndex)
        playerNotice = "Command selected: \(side.title)."
        recordAudioEvent(.battleStarted(side: side))
        selectFirstControlledUnit()
        recordSelectedAudioEvent()
    }

    func resetPlayableBattle() {
        let previousSide = playableSide
        reset(battleIndex: battleIndex)
        if playableSide != nil {
            selectFirstControlledUnit()
            if let previousSide {
                recordAudioEvent(.battleStarted(side: previousSide))
                recordSelectedAudioEvent()
            }
        }
        if let previousSide {
            playerNotice = "Battle reset for \(previousSide.title)."
        }
    }

    func step() {
        guard let engine else { return }
        _ = MosulEngineStep(engine, 1)
        refresh()
        recordAudioEvent(.tickResolved(tick: tick))
    }

    func runAI(steps: UInt32 = 1) {
        guard let engine else { return }
        _ = MosulEngineRunAI(engine, steps)
        refresh()
        recordAudioEvent(.tickResolved(tick: tick))
    }

    func runOpponentAI(steps: UInt32 = 1) {
        guard let engine else { return }

        if let playableSide {
            _ = MosulEngineRunAIForSide(engine, playableSide.opponent.rawValue, steps)
        } else {
            _ = MosulEngineRunAI(engine, steps)
        }
        refresh()
        recordAudioEvent(.tickResolved(tick: tick))
    }

    func select(unitID: UInt32) {
        guard let engine else { return }
        _ = MosulEngineSelectUnit(engine, unitID)
        refresh()
        if validateSelectionVisibility(engine) {
            updateSelectionNotice()
            recordSelectedAudioEvent()
        }
    }

    func issueHold() {
        issueOrder(1, label: "Hold")
    }

    func issueRally() {
        issueOrder(8, label: "Rally")
    }

    func issueOverwatch() {
        issueOrder(6, label: "Watch")
    }

    func issueSearch(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            recordAudioEvent(.invalidCommand(kind: .search))
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedSearch(engine, interactionID)
        }
        refresh()
        playerNotice = "Search issued for \(interaction.label)."
        recordAudioEvent(.orderPlaced(kind: .search))
    }

    func issueBreach(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            recordAudioEvent(.invalidCommand(kind: .breach))
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedBreach(engine, interactionID)
        }
        refresh()
        playerNotice = "Breach issued for \(interaction.label)."
        recordAudioEvent(.orderPlaced(kind: .breach))
    }

    func routeToInteraction(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            recordAudioEvent(.invalidCommand(kind: .route))
            return
        }
        guard interaction.routeAvailable else {
            playerNotice = "Route blocked to \(interaction.label). Choose another path or clear the obstruction first."
            recordAudioEvent(.routeBlocked(reason: interaction.state))
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedRouteToInteraction(engine, interactionID)
        }
        refresh()
        playerNotice = "Route set to \(interaction.label)."
        recordAudioEvent(.orderPlaced(kind: .route))
    }

    func canFire(at contact: MosulContact) -> Bool {
        guard selectedUnitCanReceiveOrders,
              let selectedUnit,
              let target = units.first(where: { $0.id == contact.targetUnitID }) else {
            return false
        }

        return target.side != selectedUnit.side && target.side != 3
    }

    func fireAtContact(_ contact: MosulContact) {
        guard let engine else { return }
        guard let selectedUnit else {
            playerNotice = "Select a \(commandSideTitle) unit before firing."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }
        guard let target = units.first(where: { $0.id == contact.targetUnitID }) else {
            playerNotice = "This contact is not tied to a target unit."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }
        guard canIssueOrders(to: selectedUnit) else {
            playerNotice = "Select a \(commandSideTitle) unit before firing."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }
        guard target.side != selectedUnit.side && target.side != 3 else {
            playerNotice = "Fire is only available against opposing unit contacts."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }

        let attackerName = playerFacingUnitName(selectedUnit)
        let targetName = playerFacingUnitName(target)
        var fireResult = MosulFireResultSummary()
        let ok = MosulEngineSelectedUnitFire(engine, contact.targetUnitID, &fireResult)
        refresh()

        guard ok else {
            playerNotice = "Fire failed: no valid selected unit or target."
            recordAudioEvent(
                .fireResolved(attackerID: selectedUnit.id, targetID: target.id, outcome: .failed)
            )
            return
        }

        if !fireResult.visible {
            playerNotice = "\(attackerName) has no line of sight to \(targetName)."
            recordAudioEvent(.lineOfSightBlocked)
            recordAudioEvent(
                .fireResolved(attackerID: selectedUnit.id, targetID: target.id, outcome: .blockedLineOfSight)
            )
        } else if fireResult.shots_fired <= 0 {
            playerNotice = "\(attackerName) cannot fire on \(targetName): out of range, out of ammo, or no eligible shooters."
            recordAudioEvent(
                .fireResolved(attackerID: selectedUnit.id, targetID: target.id, outcome: .noShots)
            )
        } else {
            let riskText = fireResult.civilian_risk_added > 0 ? ", +\(fireResult.civilian_risk_added) civilian risk" : ""
            playerNotice = "\(attackerName) fired on \(targetName): \(fireResult.shots_fired) shots, \(fireResult.hits) hits, \(fireResult.casualties) casualties, +\(fireResult.suppression_added) suppression\(riskText)."
            recordAudioEvent(
                .fireResolved(attackerID: selectedUnit.id, targetID: target.id, outcome: .fired)
            )
        }
    }

    func fireAtMapPoint(x: CGFloat, y: CGFloat) {
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before firing."
            mode = .select
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }

        guard let contact = nearestFireTargetContact(x: x, y: y) else {
            playerNotice = "No valid fire target at that point. Click a highlighted opposing contact or cancel targeting."
            recordAudioEvent(.invalidCommand(kind: .fire))
            return
        }

        fireAtContact(contact)
        mode = .select
    }

    private func nearestFireTargetContact(x: CGFloat, y: CGFloat) -> MosulContact? {
        let toleranceM = max(18, min(mapWidth, mapHeight) * 0.055)
        let candidates = fireTargetContacts.map { contact in
            let dx = contact.x - x
            let dy = contact.y - y
            return (contact: contact, distance: sqrt(dx * dx + dy * dy))
        }

        return candidates
            .filter { $0.distance <= toleranceM }
            .min { $0.distance < $1.distance }?
            .contact
    }

    func handleMapTap(x: CGFloat, y: CGFloat) {
        guard let engine else { return }

        switch mode {
        case .select:
            _ = MosulEngineSelectUnitAt(engine, Float(x), Float(y))
            refresh()
            if validateSelectionVisibility(engine) {
                updateSelectionNotice()
            }
            return
        case .move:
            guard selectedUnitCanReceiveOrders else {
                playerNotice = "Select a \(commandSideTitle) unit before moving."
                mode = .select
                recordAudioEvent(.invalidCommand(kind: .move))
                return
            }
            let unitName = selectedUnit.map(playerFacingUnitName) ?? "selected unit"
            _ = MosulEngineIssueSelectedMove(engine, Float(x), Float(y))
            mode = .select
            refresh()
            playerNotice = "Move target set for \(unitName)."
            recordAudioEvent(.orderPlaced(kind: .move))
            return
        case .investigate:
            guard selectedUnitCanReceiveOrders else {
                playerNotice = "Select a \(commandSideTitle) unit before investigating."
                mode = .select
                recordAudioEvent(.invalidCommand(kind: .investigate))
                return
            }
            let unitName = selectedUnit.map(playerFacingUnitName) ?? "selected unit"
            _ = MosulEngineIssueSelectedInvestigate(engine, Float(x), Float(y))
            mode = .select
            refresh()
            playerNotice = "Investigation target set for \(unitName)."
            recordAudioEvent(.orderPlaced(kind: .investigate))
            return
        case .fire:
            fireAtMapPoint(x: x, y: y)
            return
        }
    }

    func refresh() {
        guard let engine else {
            lastError = "Unable to create Mosul engine from \(runtimeResources.source.description) at \(runtimeAssetRoot)."
            return
        }

        scenarioName = String(cString: MosulEngineScenarioName(engine))
        briefing = String(cString: MosulEngineBriefing(engine))
        mapName = String(cString: MosulEngineMapName(engine))
        mapOverviewPath = String(cString: MosulEngineMapOverviewPath(engine))
        lastError = String(cString: MosulEngineLastError(engine))
        tick = MosulEngineTick(engine)
        mapWidth = CGFloat(MosulEngineMapWidthM(engine))
        mapHeight = CGFloat(MosulEngineMapHeightM(engine))

        refreshMapLevels(engine)
        refreshUnits(engine)
        refreshObjectives(engine)
        refreshCivilians(engine)
        refreshTrafficVehicles(engine)
        refreshContacts(engine)
        refreshInteractions(engine)
        refreshTacticalMapLevelVisibility()
        refreshScore(engine)
        refreshAfterAction(engine)
        refreshAudioState()
    }

    private func refreshMapLevels(_ engine: OpaquePointer) {
        let previousOverlayIDs = Set(mapLevels.filter { !$0.isBase }.map(\.id))
        var raw = Array(repeating: MosulMapLevelSummary(), count: 8)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyMapLevels(engine, buffer.baseAddress, buffer.count)
        }

        let refreshed = raw.prefix(Int(count)).map { item in
            MosulMapLevel(
                id: bridgeString(item.id),
                imagePath: bridgeString(item.image_path),
                alpha: bridgeString(item.alpha),
                index: item.index,
                elevationM: CGFloat(item.elevation_m)
            )
        }
        .sorted { first, second in
            if first.index != second.index {
                return first.index < second.index
            }
            return first.id < second.id
        }

        let overlayIDs = Set(refreshed.filter { !$0.isBase }.map(\.id))
        mapLevels = refreshed

        if !mapLevelVisibilityInitialized {
            visibleMapLevelIDs = overlayIDs
            mapLevelVisibilityInitialized = true
        } else {
            visibleMapLevelIDs = visibleMapLevelIDs.intersection(overlayIDs)
            visibleMapLevelIDs.formUnion(overlayIDs.subtracting(previousOverlayIDs))
        }
    }

    private func refreshTacticalMapLevelVisibility() {
        let overlayIDs = Set(mapLevels.filter { !$0.isBase }.map(\.id))
        visibleMapLevelIDs.formUnion(tacticalMapLevelIDs.intersection(overlayIDs))
    }

    private func issueOrder(_ order: Int32, label: String) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            recordAudioEvent(.invalidCommand(kind: MosulOrderKind(engineOrder: order)))
            return
        }

        let unitName = selectedUnit.map(playerFacingUnitName) ?? "selected unit"
        _ = MosulEngineIssueSelectedOrder(engine, order)
        refresh()
        playerNotice = "\(label) issued to \(unitName)."
        recordAudioEvent(.orderPlaced(kind: MosulOrderKind(engineOrder: order)))
    }

    private func validateSelectionVisibility(_ engine: OpaquePointer) -> Bool {
        guard let selectedUnit, !isUnitPlayerVisible(selectedUnit) else {
            return true
        }

        _ = MosulEngineClearSelection(engine)
        refresh()
        playerNotice = "No confirmed contact at that position."
        recordAudioEvent(.invalidCommand(kind: .unknown))
        return false
    }

    private func updateSelectionNotice() {
        guard let selectedUnit else {
            playerNotice = "No unit selected."
            return
        }

        if selectedUnitCanReceiveOrders {
            playerNotice = "\(playerFacingUnitName(selectedUnit)) selected for command."
        } else {
            playerNotice = "\(playerFacingUnitName(selectedUnit)) selected as intel only."
            mode = .select
        }
    }

    private func selectFirstControlledUnit() {
        guard let engine,
              let playableSide,
              let unit = units.first(where: { $0.side == playableSide.rawValue }) else {
            return
        }

        _ = MosulEngineSelectUnit(engine, unit.id)
        refresh()
    }

    private func recordSelectedAudioEvent() {
        guard let selectedUnit,
              isUnitPlayerVisible(selectedUnit),
              let side = MosulPlayableSide(rawValue: selectedUnit.side) else {
            return
        }

        recordAudioEvent(.unitSelected(id: selectedUnit.id, side: side))
    }

    private func recordAudioEvent(_ event: MosulAudioEvent) {
        audioEvents.append(event)
        if audioEvents.count > 256 {
            audioEvents.removeFirst(audioEvents.count - 256)
        }
    }

    private func refreshAudioState() {
        let visibleContactIDs = Set(playerVisibleContacts.map(\.id))
        let civilianRisk = score.civilianRisk
        let objectiveControl = Dictionary(uniqueKeysWithValues: objectives.map { ($0.id, $0.controllingSide) })
        let outcome = afterAction.score.outcome

        updateAudioContext(
            visibleContactCount: visibleContactIDs.count,
            civilianRisk: civilianRisk
        )

        guard audioBaselineInitialized else {
            lastAudioVisibleContactIDs = visibleContactIDs
            lastAudioCivilianRisk = civilianRisk
            lastAudioObjectiveControl = objectiveControl
            lastAudioOutcome = outcome
            audioBaselineInitialized = true
            return
        }

        for contactID in visibleContactIDs.subtracting(lastAudioVisibleContactIDs).sorted() {
            recordAudioEvent(.contactRevealed(contactID: contactID))
        }

        if civilianRisk > lastAudioCivilianRisk {
            recordAudioEvent(.civilianRiskChanged(level: civilianRiskLevel(for: civilianRisk)))
        }

        for objective in objectives {
            let previous = lastAudioObjectiveControl[objective.id]
            if let previous,
               previous != objective.controllingSide,
               objective.controllingSide != 0 {
                recordAudioEvent(.objectiveResolved(id: objective.id))
            }
        }

        if outcome != lastAudioOutcome, outcome != 0 {
            recordAudioEvent(.afterAction(outcome: MosulOutcomeBand(scoreOutcome: outcome)))
        }

        lastAudioVisibleContactIDs = visibleContactIDs
        lastAudioCivilianRisk = civilianRisk
        lastAudioObjectiveControl = objectiveControl
        lastAudioOutcome = outcome
    }

    private func updateAudioContext(visibleContactCount: Int, civilianRisk: Int32) {
        let unresolvedRiskCount = civilians.filter { $0.risk > 0 }.count
        let movingVisibleUnitCount = playerVisibleUnits.filter { $0.hasTarget }.count
        let movingTrafficVehicleCount = trafficVehicles.filter(\.isMoving).count
        let casualtyPressure = Double(score.playerCasualties + score.civilianCasualties) * 0.08
        let contactPressure = Double(visibleContactCount) * 0.12
        let riskPressure = min(0.42, Double(max(0, civilianRisk)) / 120.0)
        let movementPressure = min(0.12, Double(movingVisibleUnitCount) * 0.03)
        let suppressionPressure = min(0.18, Double(units.map(\.suppression).reduce(0, +)) / 500.0)
        let tension = min(1.0, contactPressure + riskPressure + casualtyPressure + movementPressure + suppressionPressure)

        audioContext = MosulAudioContext(
            tick: tick,
            selectedSide: playableSide,
            selectedUnitID: selectedUnit?.id,
            mapZoom: tacticalMapZoom,
            visibleContactCount: visibleContactCount,
            unresolvedCivilianRiskCount: unresolvedRiskCount,
            movingVisibleUnitCount: movingVisibleUnitCount,
            movingTrafficVehicleCount: movingTrafficVehicleCount,
            activeTargetingMode: mode == .select ? nil : mode,
            tension: tension
        )
    }

    private func civilianRiskLevel(for risk: Int32) -> MosulCivilianRiskAudioLevel {
        if risk >= 60 {
            return .high
        }
        if risk >= 25 {
            return .medium
        }
        return .low
    }

    private func refreshUnits(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulUnitSummary(), count: 64)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyUnits(engine, buffer.baseAddress, buffer.count)
        }

        units = raw.prefix(Int(count)).map { item in
            MosulUnit(
                id: item.id,
                name: bridgeString(item.name),
                spriteID: bridgeString(item.sprite_id),
                selectionMarkerID: bridgeString(item.selection_marker_id),
                orderMarkerID: bridgeString(item.order_marker_id),
                routeMarkerID: bridgeString(item.route_marker_id),
                targetMarkerID: bridgeString(item.target_marker_id),
                suppressionMarkerID: bridgeString(item.suppression_marker_id),
                casualtyMarkerID: bridgeString(item.casualty_marker_id),
                levelID: bridgeString(item.level_id),
                targetLevelID: bridgeString(item.target_level_id),
                topologyNodeID: bridgeString(item.topology_node_id),
                side: item.side,
                order: item.order,
                status: item.status,
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                targetX: CGFloat(item.target_x_m),
                targetY: CGFloat(item.target_y_m),
                hasTarget: item.has_target,
                hidden: item.hidden,
                revealed: item.revealed,
                selected: item.selected,
                routeUsesVerticalTransition: item.route_uses_vertical_transition,
                suppression: item.suppression,
                morale: item.morale,
                soldierCount: item.soldier_count,
                casualtyCount: item.casualty_count
            )
        }
    }

    private func refreshObjectives(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulObjectiveSummary(), count: 16)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyObjectives(engine, buffer.baseAddress, buffer.count)
        }

        objectives = raw.prefix(Int(count)).map { item in
            MosulObjective(
                id: item.id,
                name: bridgeString(item.name),
                label: bridgeString(item.label),
                markerID: bridgeString(item.marker_id),
                controllingSide: item.controlling_side,
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                radius: CGFloat(item.radius_m),
                value: item.value
            )
        }
    }

    private func refreshCivilians(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulCivilianSummary(), count: 128)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyCivilians(engine, buffer.baseAddress, buffer.count)
        }

        civilians = raw.prefix(Int(count)).map { item in
            MosulCivilian(
                id: item.id,
                name: bridgeString(item.name),
                spriteID: bridgeString(item.sprite_id),
                markerID: bridgeString(item.marker_id),
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                state: item.state,
                stress: item.stress,
                risk: item.risk
            )
        }
    }

    private func refreshTrafficVehicles(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulTrafficVehicleSummary(), count: 32)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyTrafficVehicles(engine, buffer.baseAddress, buffer.count)
        }

        trafficVehicles = raw.prefix(Int(count)).map { item in
            MosulTrafficVehicle(
                id: item.id,
                scenarioID: bridgeString(item.scenario_id),
                name: bridgeString(item.name),
                spriteID: bridgeString(item.sprite_id),
                levelID: bridgeString(item.level_id),
                destinationLevelID: bridgeString(item.destination_level_id),
                topologyNodeID: bridgeString(item.topology_node_id),
                routeFailureReason: bridgeString(item.route_failure_reason),
                kind: item.kind,
                boardingMode: item.boarding_mode,
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                destinationX: CGFloat(item.destination_x_m),
                destinationY: CGFloat(item.destination_y_m),
                hasDestination: item.has_destination,
                speedMPerTick: CGFloat(item.speed_m_per_tick),
                facingDegrees: CGFloat(item.facing_degrees),
                seatCapacity: item.seat_capacity,
                occupiedSeats: item.occupied_seats,
                active: item.active,
                blocksMovement: item.blocks_movement,
                hasRoute: item.has_route,
                routeStepCount: item.route_step_count,
                routeStepIndex: item.route_step_index,
                routeTotalCost: item.route_total_cost,
                routeUsesVerticalTransition: item.route_uses_vertical_transition,
                routeFailureCount: item.route_failure_count
            )
        }
    }

    private func refreshContacts(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulContactSummary(), count: 64)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyContacts(engine, buffer.baseAddress, buffer.count)
        }

        contacts = raw.prefix(Int(count)).map { item in
            MosulContact(
                id: item.id,
                tick: item.tick,
                attackerUnitID: item.attacker_unit_id,
                targetUnitID: item.target_unit_id,
                markerID: bridgeString(item.marker_id),
                levelID: bridgeString(item.level_id),
                kind: item.kind,
                side: item.side,
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                intensity: item.intensity,
                confidence: item.confidence,
                visible: item.visible,
                resolved: item.resolved
            )
        }
    }

    private func refreshInteractions(_ engine: OpaquePointer) {
        var raw = Array(repeating: MosulInteractionSummary(), count: 128)
        let count = raw.withUnsafeMutableBufferPointer { buffer in
            MosulEngineCopyInteractions(engine, buffer.baseAddress, buffer.count)
        }

        interactions = raw.prefix(Int(count)).map { item in
            MosulInteraction(
                numericID: item.numeric_id,
                id: bridgeString(item.interaction_id),
                label: bridgeString(item.label),
                markerID: bridgeString(item.marker_id),
                state: bridgeString(item.state),
                levelID: bridgeString(item.level_id),
                targetLevelID: bridgeString(item.target_level_id),
                topologyNodeID: bridgeString(item.topology_node_id),
                targetNodeID: bridgeString(item.target_node_id),
                kind: item.kind,
                source: item.source,
                x: CGFloat(item.x_m),
                y: CGFloat(item.y_m),
                radius: CGFloat(item.radius_m),
                distance: CGFloat(item.distance_m),
                priority: item.priority,
                searched: item.searched,
                breached: item.breached,
                open: item.open,
                vertical: item.vertical,
                sameLevel: item.same_level,
                actionable: item.actionable,
                routeAvailable: item.route_available
            )
        }
    }

    private func refreshScore(_ engine: OpaquePointer) {
        var raw = MosulScoreSummary()
        guard MosulEngineCopyScore(engine, &raw) else {
            score = MosulScore()
            return
        }

        score = MosulScore(
            total: raw.total_score,
            objectivePoints: raw.objective_points,
            interactionPoints: raw.interaction_points,
            civilianRiskPenalty: raw.civilian_risk_penalty,
            casualtyPenalty: raw.casualty_penalty,
            timePenalty: raw.time_penalty,
            playerCasualties: raw.player_casualties,
            opforCasualties: raw.opfor_casualties,
            civilianCasualties: raw.civilian_casualties,
            civilianRisk: raw.civilian_risk,
            controlledObjectives: raw.controlled_objectives,
            contestedObjectives: raw.contested_objectives,
            outcome: raw.outcome
        )
    }

    private func refreshAfterAction(_ engine: OpaquePointer) {
        var raw = MosulAfterActionSummary()
        guard MosulEngineCopyAfterAction(engine, &raw) else {
            afterAction = MosulAfterAction(score: score)
            return
        }

        afterAction = MosulAfterAction(
            score: score(from: raw.score),
            summary: bridgeString(raw.summary),
            narrative: bridgeString(raw.narrative)
        )
    }

    private func score(from raw: MosulScoreSummary) -> MosulScore {
        MosulScore(
            total: raw.total_score,
            objectivePoints: raw.objective_points,
            interactionPoints: raw.interaction_points,
            civilianRiskPenalty: raw.civilian_risk_penalty,
            casualtyPenalty: raw.casualty_penalty,
            timePenalty: raw.time_penalty,
            playerCasualties: raw.player_casualties,
            opforCasualties: raw.opfor_casualties,
            civilianCasualties: raw.civilian_casualties,
            civilianRisk: raw.civilian_risk,
            controlledObjectives: raw.controlled_objectives,
            contestedObjectives: raw.contested_objectives,
            outcome: raw.outcome
        )
    }

}

func sideName(_ side: Int32) -> String {
    switch side {
    case 1: return "U.S. Patrol"
    case 2: return "Opposing Cell"
    case 3: return "Civilian"
    default: return "Neutral"
    }
}

func orderName(_ order: Int32) -> String {
    switch order {
    case 1: return "Hold"
    case 2: return "Move"
    case 3: return "Assault"
    case 4: return "Fire"
    case 5: return "Suppress"
    case 6: return "Watch"
    case 7: return "Breach"
    case 8: return "Rally"
    case 9: return "Withdraw"
    case 10: return "Investigate"
    default: return "None"
    }
}

func statusName(_ status: Int32) -> String {
    switch status {
    case 1: return "Suppressed"
    case 2: return "Pinned"
    case 3: return "Broken"
    default: return "Ready"
    }
}

func outcomeName(_ outcome: Int32) -> String {
    switch outcome {
    case 1: return "Success"
    case 2: return "Partial"
    case 3: return "Failure"
    default: return "In Progress"
    }
}

func contactName(_ kind: Int32) -> String {
    switch kind {
    case 0: return "Fire"
    case 1: return "Reveal"
    case 2: return "Civilian Risk"
    case 3: return "Suspected"
    case 4: return "False Contact"
    default: return "Contact"
    }
}

func trafficVehicleKindName(_ kind: Int32) -> String {
    switch kind {
    case 0: return "Car"
    case 1: return "Bus"
    case 2: return "Motorcycle"
    default: return "Vehicle"
    }
}

func trafficBoardingModeName(_ mode: Int32) -> String {
    switch mode {
    case 0: return "inside"
    case 1: return "on"
    default: return "boarding"
    }
}
