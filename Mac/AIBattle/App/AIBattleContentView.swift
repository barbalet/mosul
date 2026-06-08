import AppKit
import AVFoundation
import SwiftUI

private enum AIBattleCompletionReason {
    case playerSuccess
    case playerPartial
    case playerPressuredPartial
    case opforHeld
    case stalled
}

private struct AIBattleResultPressure {
    let unresolvedContacts: Int
    let unresolvedInteractions: Int
    let highRiskCivilians: Int
    let engagedUnits: Int

    var score: Int {
        unresolvedContacts * 2
            + unresolvedInteractions
            + highRiskCivilians * 2
            + max(0, engagedUnits - 1)
    }

    var state: String {
        if score >= 9 {
            return "High pressure"
        }
        if score >= 5 {
            return "Moderate pressure"
        }
        if score > 0 {
            return "Low pressure"
        }
        return "Settled"
    }
}

private enum AIBattleTuningPolicy {
    static let maxTicks: UInt32 = 120
    static let watchdogTicks: UInt32 = 40
    static let minimumPartialTicks: UInt32 = 80
    static let partialPressureLimit = 2

    @MainActor
    static func resultPressure(for model: MosulGameModel) -> AIBattleResultPressure {
        AIBattleResultPressure(
            unresolvedContacts: model.contacts.filter { !$0.resolved }.count,
            unresolvedInteractions: model.interactions.filter { !$0.searched && !$0.breached && !$0.open }.count,
            highRiskCivilians: model.civilians.filter { $0.risk >= 4 }.count,
            engagedUnits: model.units.filter { $0.hasTarget || $0.suppression > 0 }.count
        )
    }

    @MainActor
    static func completionReason(for model: MosulGameModel, maxTicks: UInt32 = maxTicks) -> AIBattleCompletionReason? {
        switch model.score.outcome {
        case 1:
            return .playerSuccess
        case 2:
            let pressure = resultPressure(for: model)
            guard model.tick >= minimumPartialTicks || pressure.score <= partialPressureLimit || model.tick >= maxTicks else {
                return nil
            }

            return pressure.score <= partialPressureLimit ? .playerPartial : .playerPressuredPartial
        default:
            break
        }

        return model.tick >= maxTicks ? .opforHeld : nil
    }

    static func partialSettlementState(tick: UInt32, pressure: AIBattleResultPressure, maxTicks: UInt32 = maxTicks) -> String {
        guard tick < maxTicks else {
            return pressure.score <= partialPressureLimit ? "Settled at limit" : "Pressured at limit"
        }
        guard tick >= minimumPartialTicks else {
            return "Settling until tick \(minimumPartialTicks)"
        }

        return pressure.score <= partialPressureLimit ? "Settled enough" : "Pressure accepted"
    }

    static func resultText(for reason: AIBattleCompletionReason, maxTicks: UInt32 = maxTicks) -> String {
        switch reason {
        case .playerSuccess:
            return "Player AI decisive win"
        case .playerPartial:
            return "Player AI clean partial"
        case .playerPressuredPartial:
            return "Player AI pressured partial"
        case .opforHeld:
            return "Opposing AI held to tick \(maxTicks)"
        case .stalled:
            return "No tactical decision"
        }
    }
}

struct AIBattleTuningSnapshot {
    let battleNumber: UInt32
    let tick: UInt32
    let maxTicks: UInt32
    let watchdogTicks: UInt32
    let stagnantTicks: UInt32
    let score: MosulScore
    let unitCount: Int
    let playerUnits: Int
    let opforUnits: Int
    let movingUnits: Int
    let engagedUnits: Int
    let contactReports: Int
    let unresolvedContacts: Int
    let civilianCount: Int
    let civiliansAtRisk: Int
    let highRiskCivilians: Int
    let woundedCivilians: Int
    let deadCivilians: Int
    let interactionCount: Int
    let unresolvedInteractions: Int
    let actionableInteractions: Int
    let resultPressureScore: Int
    let resultPressureState: String
    let partialSettlementState: String
    let lastResult: String

    @MainActor
    init(
        model: MosulGameModel,
        battleNumber: UInt32,
        maxTicks: UInt32,
        watchdogTicks: UInt32,
        stagnantTicks: UInt32,
        lastResult: String
    ) {
        self.battleNumber = battleNumber
        tick = model.tick
        self.maxTicks = maxTicks
        self.watchdogTicks = watchdogTicks
        self.stagnantTicks = stagnantTicks
        score = model.score
        unitCount = model.units.count
        playerUnits = model.units.filter { $0.side == 1 }.count
        opforUnits = model.units.filter { $0.side == 2 }.count
        movingUnits = model.units.filter { $0.order == 2 }.count
        engagedUnits = model.units.filter { $0.hasTarget || $0.suppression > 0 }.count
        contactReports = model.contacts.count
        unresolvedContacts = model.contacts.filter { !$0.resolved }.count
        civilianCount = model.civilians.count
        civiliansAtRisk = model.civilians.filter { $0.risk > 0 }.count
        highRiskCivilians = model.civilians.filter { $0.risk >= 4 }.count
        woundedCivilians = model.civilians.filter { $0.state == 5 }.count
        deadCivilians = model.civilians.filter { $0.state == 6 }.count
        interactionCount = model.interactions.count
        unresolvedInteractions = model.interactions.filter { !$0.searched && !$0.breached && !$0.open }.count
        actionableInteractions = model.interactions.filter { $0.actionable || $0.routeAvailable }.count
        let pressure = AIBattleTuningPolicy.resultPressure(for: model)
        resultPressureScore = pressure.score
        resultPressureState = pressure.state
        partialSettlementState = AIBattleTuningPolicy.partialSettlementState(
            tick: model.tick,
            pressure: pressure,
            maxTicks: maxTicks
        )
        self.lastResult = lastResult
    }

    var pacingState: String {
        if stagnantTicks >= watchdogTicks / 2 {
            return "Watchdog pressure"
        }
        if tick >= maxTicks && score.outcome == 0 {
            return "Time-limit hold"
        }
        if contactReports == 0 && tick >= 20 {
            return "Slow contact"
        }
        if engagedUnits > 0 || unresolvedContacts > 0 {
            return "Contact active"
        }
        if movingUnits > 0 {
            return "Maneuvering"
        }
        return "Opening"
    }

    var riskState: String {
        if deadCivilians > 0 || woundedCivilians > 0 {
            return "Civilian harm"
        }
        if highRiskCivilians > 0 {
            return "High risk visible"
        }
        if civiliansAtRisk > 0 {
            return "Risk visible"
        }
        return "Low risk"
    }

    var resultState: String {
        switch score.outcome {
        case 1:
            return "Player AI success"
        case 2:
            if resultPressureScore > AIBattleTuningPolicy.partialPressureLimit {
                return "Player AI pressured partial"
            }
            return "Player AI clean partial"
        default:
            return tick >= maxTicks ? "Opposing AI holds" : "In progress"
        }
    }

    var firstTuningTarget: String {
        if score.outcome == 2 && resultPressureScore > AIBattleTuningPolicy.partialPressureLimit {
            return "Keep partial results under review until unresolved contact, interaction, and civilian-risk pressure settles."
        }
        if highRiskCivilians > 0 || woundedCivilians > 0 || deadCivilians > 0 {
            return "Prioritize civilian-risk readability when risk rings overlap contact and objective markers."
        }
        if unresolvedContacts > 3 {
            return "Group contact reports by urgency so the battle state reads faster during active fights."
        }
        if unresolvedInteractions > 0 && actionableInteractions == 0 {
            return "Clarify route/action affordances for unresolved search, breach, and rooftop interactions."
        }
        if tick >= maxTicks && score.outcome == 0 {
            return "Tune AI pacing or result criteria so held battles explain why the opposing AI survived."
        }
        return "Keep gathering AIBattle evidence; no single readability bottleneck dominates this sample."
    }

    var reportText: String {
        """
        AIBattle Evidence
        battle=\(battleNumber)
        tick=\(tick)
        max_ticks=\(maxTicks)
        result=\(resultState)
        last_result=\(lastResult)
        pacing=\(pacingState)
        risk=\(riskState)
        score=\(score.total)
        objectives=\(score.controlledObjectives) controlled / \(score.contestedObjectives) contested
        contacts=\(contactReports) total / \(unresolvedContacts) unresolved
        result_pressure=\(resultPressureState) / \(resultPressureScore)
        partial_settlement=\(partialSettlementState)
        units=\(unitCount) total / \(playerUnits) player / \(opforUnits) opfor / \(movingUnits) moving / \(engagedUnits) engaged
        civilians=\(civilianCount) total / \(civiliansAtRisk) at_risk / \(highRiskCivilians) high_risk / \(woundedCivilians) wounded / \(deadCivilians) dead
        interactions=\(interactionCount) total / \(unresolvedInteractions) unresolved / \(actionableInteractions) actionable
        first_tuning_target=\(firstTuningTarget)
        """
    }
}

struct AIBattleContentView: View {
    @StateObject private var model = MosulGameModel()
    @State private var battleNumber: UInt32 = 1
    @State private var isPlaying = true
    @State private var ticksPerPulse: UInt32 = 1
    @State private var cooldownPulses = 0
    @State private var stagnantTicks: UInt32 = 0
    @State private var previousSignature = ""
    @State private var lastResult = "Battle 1 running"
    @State private var didStart = false

    private let maxTicks = AIBattleTuningPolicy.maxTicks
    private let watchdogTicks = AIBattleTuningPolicy.watchdogTicks
    private let restartCooldownPulses = 18
    private let pulse = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                TacticalMapView(model: model)
                    .padding(12)
                Divider()
                inspector
                    .frame(width: 360)
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            startBattle(1)
        }
        .onReceive(pulse) { _ in
            advanceBattle()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AIBattle")
                    .font(.headline)
                Text("Battle \(battleNumber)  |  Tick \(model.tick)  |  \(statusText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Speed", selection: $ticksPerPulse) {
                Text("x1").tag(UInt32(1))
                Text("x3").tag(UInt32(3))
                Text("x10").tag(UInt32(10))
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Button {
                isPlaying.toggle()
            } label: {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }

            Button {
                startBattle(battleNumber + 1)
            } label: {
                Label("New Battle", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                battlePanel
                scorePanel
                tuningPanel
                civilianPanel
                unitsPanel
                contactsPanel

                if !model.lastError.isEmpty {
                    Text(model.lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
        }
    }

    private var battlePanel: some View {
        panel("Autoplay") {
            metricRow("Battle", "\(battleNumber)")
            metricRow("State", statusText)
            metricRow("Last Result", lastResult)
            metricRow("Speed", "\(ticksPerPulse) tick\(ticksPerPulse == 1 ? "" : "s") / pulse")
            metricRow("Limit", "\(maxTicks) ticks")
            metricRow("Watchdog", "\(stagnantTicks)/\(watchdogTicks)")
            metricRow("Partial Settle", "tick \(AIBattleTuningPolicy.minimumPartialTicks)+")
        }
    }

    private var scorePanel: some View {
        panel("Score") {
            metricRow("Total", "\(model.score.total)")
            metricRow("Outcome", outcomeName)
            metricRow("Objectives", "\(model.score.controlledObjectives) controlled / \(model.score.contestedObjectives) contested")
            metricRow("Civilian Risk", "\(model.score.civilianRisk)")
            metricRow("Casualties", "US \(model.score.playerCasualties) | Opfor \(model.score.opforCasualties) | Civ \(model.score.civilianCasualties)")
        }
    }

    private var civilianPanel: some View {
        let atRisk = model.civilians.filter { $0.risk > 0 }.count
        let wounded = model.civilians.filter { $0.state == 5 }.count
        let dead = model.civilians.filter { $0.state == 6 }.count

        return panel("Civilians") {
            metricRow("Tracked", "\(model.civilians.count)")
            metricRow("At Risk", "\(atRisk)")
            metricRow("Wounded", "\(wounded)")
            metricRow("Dead", "\(dead)")
        }
    }

    private var tuningPanel: some View {
        let snapshot = tuningSnapshot

        return panel("Tuning") {
            metricRow("Pacing", snapshot.pacingState)
            metricRow("Risk", snapshot.riskState)
            metricRow("Result", snapshot.resultState)
            metricRow("Contacts", "\(snapshot.unresolvedContacts)/\(snapshot.contactReports) unresolved")
            metricRow("Interactions", "\(snapshot.actionableInteractions) actionable / \(snapshot.unresolvedInteractions) unresolved")
            metricRow("Pressure", "\(snapshot.resultPressureState) / \(snapshot.resultPressureScore)")
            metricRow("Partial", snapshot.partialSettlementState)

            Divider()

            Text(snapshot.firstTuningTarget)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unitsPanel: some View {
        panel("Units") {
            ForEach(model.units) { unit in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(sideColor(unit.side))
                        .frame(width: 9, height: 9)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(unit.name)
                            .font(.caption.weight(.semibold))
                        Text("\(sideName(unit.side)) | \(orderName(unit.order)) | \(statusName(unit.status))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(unit.soldierCount - unit.casualtyCount)/\(unit.soldierCount)")
                        .font(.caption.monospacedDigit())
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var contactsPanel: some View {
        panel("Contacts") {
            if model.contacts.isEmpty {
                Text("No reports yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.contacts.prefix(10)) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(contactName(contact.kind)) at \(Int(contact.x)), \(Int(contact.y)) m")
                            .font(.caption.weight(.semibold))
                        Text("Tick \(contact.tick) | \(sideName(contact.side)) | confidence \(contact.confidence)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var statusText: String {
        if cooldownPulses > 0 {
            return "Restarting"
        }

        return isPlaying ? "Running" : "Paused"
    }

    private var outcomeName: String {
        if cooldownPulses > 0 {
            return lastResult
        }

        switch model.score.outcome {
        case 1:
            return "Player AI Success"
        case 2:
            return "Player AI Partial"
        default:
            return model.tick >= maxTicks ? "Opposing AI Holds" : "In Progress"
        }
    }

    private var tuningSnapshot: AIBattleTuningSnapshot {
        AIBattleTuningSnapshot(
            model: model,
            battleNumber: battleNumber,
            maxTicks: maxTicks,
            watchdogTicks: watchdogTicks,
            stagnantTicks: stagnantTicks,
            lastResult: lastResult
        )
    }

    private func advanceBattle() {
        guard isPlaying else { return }

        if cooldownPulses > 0 {
            cooldownPulses -= 1
            if cooldownPulses == 0 {
                startBattle(battleNumber + 1)
            }
            return
        }

        var stepsRemaining = ticksPerPulse
        while stepsRemaining > 0 {
            model.runAI()

            if let reason = completionReason() {
                completeBattle(reason)
                break
            }

            stepsRemaining -= 1
        }
    }

    private func completionReason() -> AIBattleCompletionReason? {
        if let reason = AIBattleTuningPolicy.completionReason(for: model, maxTicks: maxTicks) {
            return reason
        }

        return updateProgressWatchdog() ? .stalled : nil
    }

    private func completeBattle(_ reason: AIBattleCompletionReason) {
        lastResult = resultText(for: reason)
        cooldownPulses = restartCooldownPulses
    }

    private func startBattle(_ number: UInt32) {
        battleNumber = max(number, 1)
        model.reset(battleIndex: battleNumber)
        previousSignature = progressSignature()
        stagnantTicks = 0
        cooldownPulses = 0
        lastResult = "Battle \(battleNumber) running"
    }

    private func updateProgressWatchdog() -> Bool {
        let signature = progressSignature()
        if signature == previousSignature {
            stagnantTicks += 1
        } else {
            stagnantTicks = 0
            previousSignature = signature
        }

        return stagnantTicks >= watchdogTicks
    }

    private func progressSignature() -> String {
        AIBattleProgress.signature(for: model)
    }

    private func resultText(for reason: AIBattleCompletionReason) -> String {
        AIBattleTuningPolicy.resultText(for: reason, maxTicks: maxTicks)
    }

    private func sideColor(_ side: Int32) -> Color {
        switch side {
        case 1:
            return Color(red: 0.24, green: 0.48, blue: 0.73)
        case 2:
            return Color(red: 0.68, green: 0.22, blue: 0.18)
        case 3:
            return Color(red: 0.82, green: 0.67, blue: 0.34)
        default:
            return Color.gray
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

enum AIBattleEvidenceController {
    static let evidenceArgument = "--aibattle-evidence"
    static let movieArgument = "--aibattle-movie"

    struct EvidenceRequest {
        var outputURL: URL?
        var reportURL: URL?
        var size = CGSize(width: 1600, height: 1000)
        var scale: CGFloat = 1.0
        var aiTicks: UInt32 = 80
        var battleIndex: UInt32 = 1
        var maxTicks = AIBattleTuningPolicy.maxTicks
        var watchdogTicks = AIBattleTuningPolicy.watchdogTicks
    }

    struct MovieRequest {
        var outputURL: URL?
        var reportURL: URL?
        var size = CGSize(width: 1600, height: 1000)
        var scale: CGFloat = 1.0
        var framesPerSecond: Int32 = 6
        var tailSeconds: Double = 2.0
        var battleIndex: UInt32 = 1
        var maxTicks = AIBattleTuningPolicy.maxTicks
        var watchdogTicks = AIBattleTuningPolicy.watchdogTicks
    }

    struct EvidenceResult {
        let outputURL: URL
        let reportURL: URL
        let snapshot: AIBattleTuningSnapshot
    }

    struct MovieResult {
        let outputURL: URL
        let reportURL: URL
        let snapshot: AIBattleTuningSnapshot
        let frameCount: Int
    }

    static func evidenceRequest(arguments: [String] = CommandLine.arguments) throws -> EvidenceRequest? {
        guard arguments.contains(evidenceArgument) else {
            return nil
        }

        var request = EvidenceRequest()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case evidenceArgument:
                index += 1
            case "--aibattle-output":
                request.outputURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-report":
                request.reportURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-width":
                request.size.width = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-height":
                request.size.height = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-scale":
                request.scale = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-ai-ticks":
                request.aiTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-battle":
                request.battleIndex = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-max-ticks":
                request.maxTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-watchdog-ticks":
                request.watchdogTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            default:
                index += 1
            }
        }

        if request.size.width <= 0 || request.size.height <= 0 || request.scale <= 0 {
            throw AIBattleEvidenceError.invalidArgument("AIBattle evidence width, height, and scale must be positive")
        }

        return request
    }

    static func movieRequest(arguments: [String] = CommandLine.arguments) throws -> MovieRequest? {
        guard arguments.contains(movieArgument) else {
            return nil
        }

        var request = MovieRequest()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case movieArgument:
                index += 1
            case "--aibattle-movie-output":
                request.outputURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-movie-report":
                request.reportURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-movie-width":
                request.size.width = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-movie-height":
                request.size.height = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-movie-scale":
                request.scale = CGFloat(try doubleValue(after: argument, in: arguments, at: index))
                index += 2
            case "--aibattle-movie-fps":
                request.framesPerSecond = try int32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-movie-tail-seconds":
                request.tailSeconds = try doubleValue(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-movie-battle":
                request.battleIndex = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-movie-max-ticks":
                request.maxTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            case "--aibattle-movie-watchdog-ticks":
                request.watchdogTicks = try uint32Value(after: argument, in: arguments, at: index)
                index += 2
            default:
                index += 1
            }
        }

        if request.size.width <= 0 || request.size.height <= 0 || request.scale <= 0 {
            throw AIBattleEvidenceError.invalidArgument("AIBattle movie width, height, and scale must be positive")
        }
        if request.framesPerSecond <= 0 {
            throw AIBattleEvidenceError.invalidArgument("AIBattle movie frames per second must be positive")
        }
        if request.tailSeconds < 0 {
            throw AIBattleEvidenceError.invalidArgument("AIBattle movie tail seconds cannot be negative")
        }

        return request
    }

    @MainActor
    static func saveEvidence(request: EvidenceRequest) throws -> EvidenceResult {
        let model = MosulGameModel()
        model.reset(battleIndex: request.battleIndex)

        var ticksRun: UInt32 = 0
        var lastResult = "Battle \(request.battleIndex) running"
        while ticksRun < request.aiTicks && ticksRun < request.maxTicks {
            model.runAI()
            ticksRun += 1

            if let reason = AIBattleTuningPolicy.completionReason(for: model, maxTicks: request.maxTicks) {
                lastResult = AIBattleTuningPolicy.resultText(for: reason, maxTicks: request.maxTicks)
                break
            }
        }

        if ticksRun >= request.maxTicks && model.score.outcome == 0 {
            lastResult = "Opposing AI held to tick \(request.maxTicks)"
        }

        let snapshot = AIBattleTuningSnapshot(
            model: model,
            battleNumber: request.battleIndex,
            maxTicks: request.maxTicks,
            watchdogTicks: request.watchdogTicks,
            stagnantTicks: 0,
            lastResult: lastResult
        )
        let outputURL = request.outputURL ?? URL(fileURLWithPath: model.mosulRoot)
            .appendingPathComponent("snapshots/evidence/aibattle-evidence.png")
        let reportURL = request.reportURL ?? outputURL
            .deletingPathExtension()
            .appendingPathExtension("txt")

        try writeEvidenceImage(
            model: model,
            snapshot: snapshot,
            outputURL: outputURL,
            size: request.size,
            scale: request.scale
        )
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try snapshot.reportText.write(to: reportURL, atomically: true, encoding: .utf8)

        return EvidenceResult(outputURL: outputURL, reportURL: reportURL, snapshot: snapshot)
    }

    @MainActor
    static func saveMovie(request: MovieRequest) throws -> MovieResult {
        let model = MosulGameModel()
        model.reset(battleIndex: request.battleIndex)

        let outputURL = request.outputURL ?? URL(fileURLWithPath: model.mosulRoot)
            .appendingPathComponent("snapshots/evidence/aibattle-battle-\(request.battleIndex).mov")
        let reportURL = request.reportURL ?? outputURL
            .deletingPathExtension()
            .appendingPathExtension("txt")
        let encoder = try AIBattleMovieEncoder(
            outputURL: outputURL,
            size: request.size,
            scale: request.scale,
            framesPerSecond: request.framesPerSecond
        )

        var lastResult = "Battle \(request.battleIndex) running"
        var previousSignature = AIBattleProgress.signature(for: model)
        var stagnantTicks: UInt32 = 0
        var finalSnapshot = AIBattleTuningSnapshot(
            model: model,
            battleNumber: request.battleIndex,
            maxTicks: request.maxTicks,
            watchdogTicks: request.watchdogTicks,
            stagnantTicks: stagnantTicks,
            lastResult: lastResult
        )

        try encoder.append(
            renderMovieFrame(model: model, snapshot: finalSnapshot, request: request)
        )

        while model.tick < request.maxTicks {
            model.runAI()

            if let reason = AIBattleTuningPolicy.completionReason(for: model, maxTicks: request.maxTicks) {
                lastResult = AIBattleTuningPolicy.resultText(for: reason, maxTicks: request.maxTicks)
            } else if AIBattleProgress.updateWatchdog(
                model: model,
                previousSignature: &previousSignature,
                stagnantTicks: &stagnantTicks
            ) >= request.watchdogTicks {
                lastResult = AIBattleTuningPolicy.resultText(for: .stalled, maxTicks: request.maxTicks)
            }

            finalSnapshot = AIBattleTuningSnapshot(
                model: model,
                battleNumber: request.battleIndex,
                maxTicks: request.maxTicks,
                watchdogTicks: request.watchdogTicks,
                stagnantTicks: stagnantTicks,
                lastResult: lastResult
            )

            try encoder.append(
                renderMovieFrame(model: model, snapshot: finalSnapshot, request: request)
            )

            if lastResult != "Battle \(request.battleIndex) running" {
                break
            }
        }

        if model.tick >= request.maxTicks && model.score.outcome == 0 {
            lastResult = "Opposing AI held to tick \(request.maxTicks)"
            finalSnapshot = AIBattleTuningSnapshot(
                model: model,
                battleNumber: request.battleIndex,
                maxTicks: request.maxTicks,
                watchdogTicks: request.watchdogTicks,
                stagnantTicks: stagnantTicks,
                lastResult: lastResult
            )
        }

        let tailFrames = Int((request.tailSeconds * Double(request.framesPerSecond)).rounded())
        if tailFrames > 0 {
            let frame = try renderMovieFrame(model: model, snapshot: finalSnapshot, request: request)
            for _ in 0..<tailFrames {
                try encoder.append(frame)
            }
        }

        try encoder.finish()
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try finalSnapshot.reportText.write(to: reportURL, atomically: true, encoding: .utf8)

        return MovieResult(
            outputURL: outputURL,
            reportURL: reportURL,
            snapshot: finalSnapshot,
            frameCount: encoder.frameCount
        )
    }

    @MainActor
    private static func writeEvidenceImage(
        model: MosulGameModel,
        snapshot: AIBattleTuningSnapshot,
        outputURL: URL,
        size: CGSize,
        scale: CGFloat
    ) throws {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let content = AIBattleEvidenceView(model: model, snapshot: snapshot)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = scale

        guard let image = renderer.cgImage else {
            throw AIBattleEvidenceError.renderFailed
        }

        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw AIBattleEvidenceError.pngEncodingFailed
        }

        try data.write(to: outputURL, options: .atomic)
    }

    @MainActor
    private static func renderMovieFrame(
        model: MosulGameModel,
        snapshot: AIBattleTuningSnapshot,
        request: MovieRequest
    ) throws -> CGImage {
        let content = AIBattleMovieFrameView(model: model, snapshot: snapshot)
            .frame(width: request.size.width, height: request.size.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: request.size.width, height: request.size.height)
        renderer.scale = request.scale

        guard let image = renderer.cgImage else {
            throw AIBattleEvidenceError.renderFailed
        }

        return image
    }

    private static func value(after option: String, in arguments: [String], at index: Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw AIBattleEvidenceError.invalidArgument("\(option) requires a value")
        }

        return arguments[valueIndex]
    }

    private static func doubleValue(after option: String, in arguments: [String], at index: Int) throws -> Double {
        let rawValue = try value(after: option, in: arguments, at: index)
        guard let value = Double(rawValue) else {
            throw AIBattleEvidenceError.invalidArgument("\(option) requires a numeric value")
        }

        return value
    }

    private static func uint32Value(after option: String, in arguments: [String], at index: Int) throws -> UInt32 {
        let rawValue = try value(after: option, in: arguments, at: index)
        guard let value = UInt32(rawValue) else {
            throw AIBattleEvidenceError.invalidArgument("\(option) requires an unsigned integer value")
        }

        return value
    }

    private static func int32Value(after option: String, in arguments: [String], at index: Int) throws -> Int32 {
        let rawValue = try value(after: option, in: arguments, at: index)
        guard let value = Int32(rawValue) else {
            throw AIBattleEvidenceError.invalidArgument("\(option) requires a signed integer value")
        }

        return value
    }
}

private enum AIBattleProgress {
    @MainActor
    static func signature(for model: MosulGameModel) -> String {
        let objectives = model.objectives
            .map { "\($0.id):\($0.controllingSide)" }
            .joined(separator: ";")
        let contacts = model.contacts
            .map { "\($0.id):\($0.kind):\($0.resolved):\($0.confidence)" }
            .joined(separator: ";")
        let civilians = model.civilians
            .map { "\($0.id):\($0.state):\(Int($0.x)):\(Int($0.y)):\($0.risk):\($0.stress)" }
            .joined(separator: ";")
        let interactions = model.interactions
            .map { "\($0.id):\($0.state):\($0.searched):\($0.breached):\($0.open)" }
            .joined(separator: ";")
        let units = model.units
            .map { "\($0.id):\($0.order):\($0.status):\(Int($0.x)):\(Int($0.y)):\(Int($0.targetX)):\(Int($0.targetY)):\($0.hasTarget):\($0.revealed):\($0.suppression):\($0.casualtyCount)" }
            .joined(separator: ";")

        return "\(objectives)|\(contacts)|\(civilians)|\(interactions)|\(units)"
    }

    @MainActor
    @discardableResult
    static func updateWatchdog(
        model: MosulGameModel,
        previousSignature: inout String,
        stagnantTicks: inout UInt32
    ) -> UInt32 {
        let currentSignature = signature(for: model)
        if currentSignature == previousSignature {
            stagnantTicks += 1
        } else {
            stagnantTicks = 0
            previousSignature = currentSignature
        }

        return stagnantTicks
    }
}

private final class AIBattleMovieEncoder {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let framesPerSecond: Int32
    private(set) var frameCount = 0

    init(outputURL: URL, size: CGSize, scale: CGFloat, framesPerSecond: Int32) throws {
        pixelWidth = Self.evenPixelDimension(size.width * scale)
        pixelHeight = Self.evenPixelDimension(size.height * scale)
        self.framesPerSecond = framesPerSecond

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(8_000_000, pixelWidth * pixelHeight * 4),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        guard writer.canAdd(input) else {
            throw AIBattleEvidenceError.movieWriterFailed("Could not add the movie video input.")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw AIBattleEvidenceError.movieWriterFailed(writer.error?.localizedDescription ?? "Could not start movie writing.")
        }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage) throws {
        guard writer.status == .writing else {
            throw AIBattleEvidenceError.movieWriterFailed(writer.error?.localizedDescription ?? "Movie writer is not active.")
        }

        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }

        guard let pixelBuffer = makePixelBuffer(from: image) else {
            throw AIBattleEvidenceError.movieEncodingFailed
        }

        let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: framesPerSecond)
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw AIBattleEvidenceError.movieWriterFailed(writer.error?.localizedDescription ?? "Could not append a movie frame.")
        }
        frameCount += 1
    }

    func finish() throws {
        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw AIBattleEvidenceError.movieWriterFailed(writer.error?.localizedDescription ?? "Could not finish movie writing.")
        }
    }

    private func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else {
            return nil
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        return pixelBuffer
    }

    private static func evenPixelDimension(_ value: CGFloat) -> Int {
        let rounded = max(2, Int(value.rounded(.down)))
        return rounded % 2 == 0 ? rounded : rounded - 1
    }
}

private struct AIBattleMovieFrameView: View {
    @ObservedObject var model: MosulGameModel
    let snapshot: AIBattleTuningSnapshot

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                TacticalMapView(model: model)
                    .padding(12)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    battlePanel
                    scorePanel
                    tuningPanel
                    civilianPanel
                    unitsPanel
                    contactsPanel
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(width: 410, alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AIBattle")
                    .font(.headline)
                Text("Battle \(snapshot.battleNumber) | Tick \(snapshot.tick) | \(snapshot.resultState)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(snapshot.lastResult)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var battlePanel: some View {
        panel("Autoplay") {
            metricRow("State", snapshot.pacingState)
            metricRow("Last Result", snapshot.lastResult)
            metricRow("Limit", "\(snapshot.maxTicks) ticks")
            metricRow("Watchdog", "\(snapshot.stagnantTicks)/\(snapshot.watchdogTicks)")
        }
    }

    private var scorePanel: some View {
        panel("Score") {
            metricRow("Total", "\(snapshot.score.total)")
            metricRow("Outcome", snapshot.resultState)
            metricRow("Objectives", "\(snapshot.score.controlledObjectives) controlled / \(snapshot.score.contestedObjectives) contested")
            metricRow("Civilian Risk", "\(snapshot.score.civilianRisk)")
            metricRow("Casualties", "US \(snapshot.score.playerCasualties) | Opfor \(snapshot.score.opforCasualties) | Civ \(snapshot.score.civilianCasualties)")
        }
    }

    private var tuningPanel: some View {
        panel("Tuning") {
            metricRow("Risk", snapshot.riskState)
            metricRow("Contacts", "\(snapshot.unresolvedContacts)/\(snapshot.contactReports) unresolved")
            metricRow("Interactions", "\(snapshot.actionableInteractions) actionable / \(snapshot.unresolvedInteractions) unresolved")
            metricRow("Pressure", "\(snapshot.resultPressureState) / \(snapshot.resultPressureScore)")
            metricRow("Partial", snapshot.partialSettlementState)
            Text(snapshot.firstTuningTarget)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var civilianPanel: some View {
        panel("Civilians") {
            metricRow("Tracked", "\(snapshot.civilianCount)")
            metricRow("At Risk", "\(snapshot.civiliansAtRisk)")
            metricRow("High Risk", "\(snapshot.highRiskCivilians)")
            metricRow("Wounded/Dead", "\(snapshot.woundedCivilians)/\(snapshot.deadCivilians)")
        }
    }

    private var unitsPanel: some View {
        panel("Units") {
            ForEach(model.units.prefix(6)) { unit in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(sideColor(unit.side))
                        .frame(width: 7, height: 7)
                    Text(unit.name)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(orderName(unit.order)) \(unit.soldierCount - unit.casualtyCount)/\(unit.soldierCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var contactsPanel: some View {
        panel("Contacts") {
            if model.contacts.isEmpty {
                Text("No reports yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.contacts.prefix(5)) { contact in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(contactName(contact.kind))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("T\(contact.tick) \(Int(contact.x)),\(Int(contact.y))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            content()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .font(.caption2)
    }

    private func sideColor(_ side: Int32) -> Color {
        switch side {
        case 1:
            return Color(red: 0.24, green: 0.48, blue: 0.73)
        case 2:
            return Color(red: 0.68, green: 0.22, blue: 0.18)
        case 3:
            return Color(red: 0.82, green: 0.67, blue: 0.34)
        default:
            return Color.gray
        }
    }
}

private struct AIBattleEvidenceView: View {
    @ObservedObject var model: MosulGameModel
    let snapshot: AIBattleTuningSnapshot

    var body: some View {
        HStack(spacing: 0) {
            TacticalMapView(model: model)
                .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("AIBattle Evidence")
                    .font(.title3.weight(.semibold))
                Text("Battle \(snapshot.battleNumber) | Tick \(snapshot.tick)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                panel("Pacing") {
                    metricRow("State", snapshot.pacingState)
                    metricRow("Result", snapshot.resultState)
                    metricRow("Score", "\(snapshot.score.total)")
                    metricRow("Contacts", "\(snapshot.unresolvedContacts)/\(snapshot.contactReports) unresolved")
                    metricRow("Interactions", "\(snapshot.actionableInteractions) actionable")
                    metricRow("Pressure", "\(snapshot.resultPressureState) / \(snapshot.resultPressureScore)")
                    metricRow("Partial", snapshot.partialSettlementState)
                }

                panel("Civilian Risk") {
                    metricRow("State", snapshot.riskState)
                    metricRow("At Risk", "\(snapshot.civiliansAtRisk)")
                    metricRow("High Risk", "\(snapshot.highRiskCivilians)")
                    metricRow("Wounded/Dead", "\(snapshot.woundedCivilians)/\(snapshot.deadCivilians)")
                }

                panel("First Target") {
                    Text(snapshot.firstTuningTarget)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: 390, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

enum AIBattleEvidenceError: LocalizedError {
    case invalidArgument(String)
    case renderFailed
    case pngEncodingFailed
    case movieEncodingFailed
    case movieWriterFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        case .renderFailed:
            return "Could not render the AIBattle evidence view."
        case .pngEncodingFailed:
            return "Could not encode the AIBattle evidence PNG."
        case .movieEncodingFailed:
            return "Could not encode an AIBattle movie frame."
        case .movieWriterFailed(let message):
            return "Could not write the AIBattle movie: \(message)"
        }
    }
}
