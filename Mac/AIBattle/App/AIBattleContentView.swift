import AppKit
import SwiftUI

private enum AIBattleCompletionReason {
    case playerSuccess
    case playerPartial
    case opforHeld
    case stalled
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
            return "Player AI partial"
        default:
            return tick >= maxTicks ? "Opposing AI holds" : "In progress"
        }
    }

    var firstTuningTarget: String {
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

    private let maxTicks: UInt32 = 120
    private let watchdogTicks: UInt32 = 40
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
        switch model.score.outcome {
        case 1:
            return .playerSuccess
        case 2:
            return .playerPartial
        default:
            break
        }

        if model.tick >= maxTicks {
            return .opforHeld
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

    private func resultText(for reason: AIBattleCompletionReason) -> String {
        switch reason {
        case .playerSuccess:
            return "Player AI decisive win"
        case .playerPartial:
            return "Player AI partial win"
        case .opforHeld:
            return "Opposing AI held to tick \(maxTicks)"
        case .stalled:
            return "No tactical decision"
        }
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

    struct EvidenceRequest {
        var outputURL: URL?
        var reportURL: URL?
        var size = CGSize(width: 1600, height: 1000)
        var scale: CGFloat = 1.0
        var aiTicks: UInt32 = 80
        var battleIndex: UInt32 = 1
        var maxTicks: UInt32 = 120
        var watchdogTicks: UInt32 = 40
    }

    struct EvidenceResult {
        let outputURL: URL
        let reportURL: URL
        let snapshot: AIBattleTuningSnapshot
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

    @MainActor
    static func saveEvidence(request: EvidenceRequest) throws -> EvidenceResult {
        let model = MosulGameModel()
        model.reset(battleIndex: request.battleIndex)

        var ticksRun: UInt32 = 0
        var lastResult = "Battle \(request.battleIndex) running"
        while ticksRun < request.aiTicks && ticksRun < request.maxTicks {
            model.runAI()
            ticksRun += 1

            if model.score.outcome == 1 {
                lastResult = "Player AI decisive win"
                break
            }
            if model.score.outcome == 2 {
                lastResult = "Player AI partial win"
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

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        case .renderFailed:
            return "Could not render the AIBattle evidence view."
        case .pngEncodingFailed:
            return "Could not encode the AIBattle evidence PNG."
        }
    }
}
