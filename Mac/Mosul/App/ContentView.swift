import SwiftUI

struct ContentView: View {
    @StateObject private var model = MosulGameModel()
    @State private var snapshotStatus = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                TacticalMapView(model: model)
                    .padding(12)
                Divider()
                inspector
                    .frame(width: 340)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MosulVersion.displayName)
                    .font(.headline)
                Text("\(model.scenarioName)  |  \(model.mapName)  |  Tick \(model.tick)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Map Mode", selection: $model.mode) {
                ForEach(MosulMapMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            Button("Hold") { model.issueHold() }
                .disabled(model.selectedUnit == nil)
            Button("Overwatch") { model.issueOverwatch() }
                .disabled(model.selectedUnit == nil)
            Button("Rally") { model.issueRally() }
                .disabled(model.selectedUnit == nil)

            Divider()
                .frame(height: 24)

            Button("Step") { model.step() }
            Button("AI Tick") { model.runAI() }
            Button("AI x10") { model.runAI(steps: 10) }
            Button {
                saveSnapshot()
            } label: {
                Label("Snapshot", systemImage: "camera")
            }
            Button("Reset") { model.reset() }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                scorePanel
                afterActionPanel
                selectedPanel
                interactionsPanel
                unitsPanel
                contactsPanel
                briefingPanel

                if !model.lastError.isEmpty {
                    Text(model.lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !snapshotStatus.isEmpty {
                    Text(snapshotStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(14)
        }
    }

    private var scorePanel: some View {
        panel("Situation") {
            metricRow("Score", "\(model.score.total)")
            metricRow("Outcome", outcomeName(model.score.outcome))
            metricRow("Objectives", "\(model.score.controlledObjectives) controlled / \(model.score.contestedObjectives) contested")
            metricRow("Interactions", "\(model.score.interactionPoints)")
            metricRow("Civilian Risk", "\(model.score.civilianRisk)")
            metricRow("Casualties", "US \(model.score.playerCasualties) | Opfor \(model.score.opforCasualties) | Civ \(model.score.civilianCasualties)")
        }
    }

    private var afterActionPanel: some View {
        let report = model.afterAction
        let score = report.score

        return panel("After Action") {
            HStack {
                Text(outcomeName(score.outcome))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(outcomeColor(score.outcome).opacity(0.16), in: Capsule())
                    .foregroundStyle(outcomeColor(score.outcome))
                Spacer()
                Text("\(score.total)")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Text(report.narrative.isEmpty ? "No after-action narrative loaded." : report.narrative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            metricRow("Objectives", signed(score.objectivePoints))
            metricRow("Interactions", signed(score.interactionPoints))
            metricRow("Civilian Risk", signed(-score.civilianRiskPenalty))
            metricRow("Casualties", signed(-score.casualtyPenalty))
            metricRow("Time", signed(-score.timePenalty))

            if !report.summary.isEmpty {
                Text(report.summary)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedPanel: some View {
        panel("Selected") {
            if let unit = model.selectedUnit {
                Text(unit.name)
                    .font(.subheadline.weight(.semibold))
                metricRow("Side", sideName(unit.side))
                metricRow("Order", orderName(unit.order))
                metricRow("Status", statusName(unit.status))
                metricRow("Position", "\(Int(unit.x)), \(Int(unit.y)) m")
                metricRow("Soldiers", "\(unit.soldierCount - unit.casualtyCount)/\(unit.soldierCount)")
                metricRow("Suppression", "\(unit.suppression)")

                let tasks = Array(model.selectedInteractionTasks.prefix(5))
                if !tasks.isEmpty {
                    Divider()
                    ForEach(tasks) { interaction in
                        interactionTaskRow(interaction)
                    }
                }
            } else {
                Text("Select a unit on the map or in the list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var interactionsPanel: some View {
        let unresolved = model.interactions.filter { !$0.searched && !$0.breached }.count
        let actionable = model.interactions.filter { $0.actionable }.count
        let rooftop = model.interactions.filter { $0.kind == 4 }.count

        return panel("Interactions") {
            metricRow("Visible", "\(model.interactions.count)")
            metricRow("Unresolved", "\(unresolved)")
            metricRow("Actionable", "\(actionable)")
            metricRow("Rooftop", "\(rooftop)")
        }
    }

    private var unitsPanel: some View {
        panel("Units") {
            ForEach(model.units) { unit in
                Button {
                    model.select(unitID: unit.id)
                } label: {
                    HStack {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
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
                ForEach(model.contacts.prefix(8)) { contact in
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

    private var briefingPanel: some View {
        panel("Briefing") {
            Text(model.briefing.isEmpty ? "No briefing loaded." : model.briefing)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }

    private func signed(_ value: Int32) -> String {
        if value > 0 {
            return "+\(value)"
        }

        return "\(value)"
    }

    private func interactionTaskRow(_ interaction: MosulInteraction) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(interaction.label)
                        .font(.caption.weight(.semibold))
                    Text("\(interactionKindName(interaction.kind)) | \(interaction.state) | \(Int(interaction.distance)) m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    if primaryInteractionTitle(interaction) != "Route", interaction.routeAvailable {
                        Button("Route") {
                            model.routeToInteraction(interaction)
                        }
                        .disabled(model.selectedUnit == nil)
                    }

                    Button(primaryInteractionTitle(interaction)) {
                        performPrimaryInteraction(interaction)
                    }
                    .disabled(!primaryInteractionEnabled(interaction))
                }
                .font(.caption2)
            }
        }
        .padding(.vertical, 3)
    }

    private func primaryInteractionTitle(_ interaction: MosulInteraction) -> String {
        if interaction.source == 1 {
            if interaction.vertical || interaction.open {
                return "Route"
            }

            return "Breach"
        }

        return interaction.searched ? "Searched" : "Search"
    }

    private func primaryInteractionEnabled(_ interaction: MosulInteraction) -> Bool {
        if interaction.source == 1 && (interaction.vertical || interaction.open) {
            return interaction.routeAvailable
        }

        if interaction.source == 1 {
            return interaction.actionable
        }

        return interaction.actionable && !interaction.searched
    }

    private func performPrimaryInteraction(_ interaction: MosulInteraction) {
        if interaction.source == 1 {
            if interaction.vertical || interaction.open {
                model.routeToInteraction(interaction)
            } else {
                model.issueBreach(interaction)
            }
            return
        }

        model.issueSearch(interaction)
    }

    private func interactionKindName(_ kind: Int32) -> String {
        switch kind {
        case 1:
            return "Breach"
        case 3:
            return "Cache"
        case 4:
            return "Rooftop"
        case 5:
            return "Danger"
        case 6:
            return "Shelter"
        default:
            return "Search"
        }
    }

    private func outcomeColor(_ outcome: Int32) -> Color {
        switch outcome {
        case 1:
            return .green
        case 2:
            return .orange
        case 3:
            return .red
        default:
            return .secondary
        }
    }

    private func saveSnapshot() {
        do {
            let url = try SnapshotController.saveMapSnapshot(model: model)
            snapshotStatus = "\(SnapshotController.codename): \(url.path)"
        } catch {
            snapshotStatus = "\(SnapshotController.codename): \(error.localizedDescription)"
        }
    }
}
