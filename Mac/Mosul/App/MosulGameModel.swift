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

    var id: String { rawValue }
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

    var opponent: MosulPlayableSide {
        switch self {
        case .usPatrol:
            return .opposingCell
        case .opposingCell:
            return .usPatrol
        }
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

    private var engine: OpaquePointer?
    private var mapLevelVisibilityInitialized = false
    private var battleIndex: UInt32 = 1
    let modernerKriegRoot: String

    var mosulRoot: String {
        URL(fileURLWithPath: modernerKriegRoot)
            .deletingLastPathComponent()
            .path
    }

    init() {
        modernerKriegRoot = Self.findModernerKriegRoot()
        engine = modernerKriegRoot.withCString { root in
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

    var selectedUnitCanReceiveOrders: Bool {
        guard let selectedUnit else { return false }
        return canIssueOrders(to: selectedUnit)
    }

    var commandSideTitle: String {
        playableSide?.title ?? "Choose Side"
    }

    var opponentSideTitle: String {
        playableSide?.opponent.title ?? "Opponent"
    }

    var tacticalMapLevelIDs: Set<String> {
        var ids = Set<String>()

        if let selectedUnit {
            ids.insert(selectedUnit.levelID)
            ids.insert(selectedUnit.targetLevelID)
        }

        for unit in units where unit.routeUsesVerticalTransition {
            ids.insert(unit.levelID)
            ids.insert(unit.targetLevelID)
        }

        for contact in contacts where !contact.resolved {
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

    func reset(battleIndex: UInt32 = 1) {
        guard let engine else { return }
        self.battleIndex = battleIndex
        _ = MosulEngineResetBattle(engine, battleIndex)
        refresh()
    }

    func startPlayableBattle(as side: MosulPlayableSide) {
        playableSide = side
        playerNotice = "Command selected: \(side.title)."
        reset(battleIndex: battleIndex)
        selectFirstControlledUnit()
    }

    func resetPlayableBattle() {
        reset(battleIndex: battleIndex)
        if playableSide != nil {
            selectFirstControlledUnit()
        }
    }

    func step() {
        guard let engine else { return }
        _ = MosulEngineStep(engine, 1)
        refresh()
    }

    func runAI(steps: UInt32 = 1) {
        guard let engine else { return }
        _ = MosulEngineRunAI(engine, steps)
        refresh()
    }

    func runOpponentAI(steps: UInt32 = 1) {
        guard let engine else { return }

        if let playableSide {
            _ = MosulEngineRunAIForSide(engine, playableSide.opponent.rawValue, steps)
        } else {
            _ = MosulEngineRunAI(engine, steps)
        }
        refresh()
    }

    func select(unitID: UInt32) {
        guard let engine else { return }
        _ = MosulEngineSelectUnit(engine, unitID)
        refresh()
    }

    func issueHold() {
        issueOrder(1)
    }

    func issueRally() {
        issueOrder(8)
    }

    func issueOverwatch() {
        issueOrder(6)
    }

    func issueSearch(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedSearch(engine, interactionID)
        }
        refresh()
    }

    func issueBreach(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedBreach(engine, interactionID)
        }
        refresh()
    }

    func routeToInteraction(_ interaction: MosulInteraction) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            return
        }

        _ = interaction.id.withCString { interactionID in
            MosulEngineIssueSelectedRouteToInteraction(engine, interactionID)
        }
        refresh()
    }

    func handleMapTap(x: CGFloat, y: CGFloat) {
        guard let engine else { return }

        switch mode {
        case .select:
            _ = MosulEngineSelectUnitAt(engine, Float(x), Float(y))
        case .move:
            guard selectedUnitCanReceiveOrders else {
                playerNotice = "Select a \(commandSideTitle) unit before moving."
                mode = .select
                return
            }
            _ = MosulEngineIssueSelectedMove(engine, Float(x), Float(y))
            mode = .select
        case .investigate:
            guard selectedUnitCanReceiveOrders else {
                playerNotice = "Select a \(commandSideTitle) unit before investigating."
                mode = .select
                return
            }
            _ = MosulEngineIssueSelectedInvestigate(engine, Float(x), Float(y))
            mode = .select
        }

        refresh()
    }

    func refresh() {
        guard let engine else {
            lastError = "Unable to create Mosul engine. Expected modernerKrieg at \(modernerKriegRoot)."
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

    private func issueOrder(_ order: Int32) {
        guard let engine else { return }
        guard selectedUnitCanReceiveOrders else {
            playerNotice = "Select a \(commandSideTitle) unit before issuing orders."
            return
        }

        _ = MosulEngineIssueSelectedOrder(engine, order)
        refresh()
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

    private static func findModernerKriegRoot(filePath: String = #filePath) -> String {
        var candidate = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        for _ in 0..<10 {
            let root = candidate.appendingPathComponent("modernerKrieg")
            if fileManager.fileExists(atPath: root.appendingPathComponent("README.md").path) {
                return root.path
            }
            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../modernerKrieg")
            .standardized
            .path
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
    case 6: return "Overwatch"
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
