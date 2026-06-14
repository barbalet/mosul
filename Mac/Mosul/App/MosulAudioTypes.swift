import Foundation

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
