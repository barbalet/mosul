import SwiftUI

private enum AIBattleCompletionReason {
    case playerSuccess
    case playerPartial
    case opforHeld
    case stalled
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
        let units = model.units
            .map { "\($0.id):\($0.order):\($0.status):\(Int($0.x)):\(Int($0.y)):\(Int($0.targetX)):\(Int($0.targetY)):\($0.hasTarget):\($0.revealed):\($0.suppression):\($0.casualtyCount)" }
            .joined(separator: ";")

        return "\(objectives)|\(contacts)|\(civilians)|\(units)"
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
