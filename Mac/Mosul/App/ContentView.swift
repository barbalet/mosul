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
                selectedPanel
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
            metricRow("Objectives", "\(model.score.controlledObjectives) controlled / \(model.score.contestedObjectives) contested")
            metricRow("Civilian Risk", "\(model.score.civilianRisk)")
            metricRow("Casualties", "US \(model.score.playerCasualties) | Opfor \(model.score.opforCasualties) | Civ \(model.score.civilianCasualties)")
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
            } else {
                Text("Select a unit on the map or in the list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private func saveSnapshot() {
        do {
            let url = try SnapshotController.saveMapSnapshot(model: model)
            snapshotStatus = "\(SnapshotController.codename): \(url.path)"
        } catch {
            snapshotStatus = "\(SnapshotController.codename): \(error.localizedDescription)"
        }
    }
}
