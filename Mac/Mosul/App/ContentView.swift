import SwiftUI

struct ContentView: View {
    @StateObject private var model = MosulGameModel()
    @State private var snapshotStatus = ""

    private var modeBinding: Binding<MosulMapMode> {
        Binding(
            get: { model.mode },
            set: { model.setMode($0) }
        )
    }

    var body: some View {
        Group {
            if let issue = model.releaseIssue {
                releaseIssueView(issue)
            } else {
                ZStack {
                    gameLayout
                        .disabled(model.playableSide == nil)
                        .blur(radius: model.playableSide == nil ? 1.2 : 0)

                    if model.playableSide == nil {
                        sideSelectionOverlay
                            .padding(24)
                    }
                }
            }
        }
    }

    private func releaseIssueView(_ issue: MosulReleaseIssue) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 5) {
                    Text(issue.title)
                        .font(.title2.weight(.semibold))
                    Text(issue.message)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            Label(issue.recovery, systemImage: "wrench.and.screwdriver.fill")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Text(issue.diagnostic)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Release issue")
        .accessibilityHint("The app could not start the playable scenario and shows recovery details.")
    }

    private var gameLayout: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.width < 1100 || proxy.size.height < 720
            let inspectorWidth = min(340, max(300, proxy.size.width * 0.28))
            let inspectorHeight = min(300, max(220, proxy.size.height * 0.36))

            VStack(spacing: 0) {
                header
                Divider()

                if compactLayout {
                    VStack(spacing: 0) {
                        TacticalMapView(model: model)
                            .padding(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilitySortPriority(2)

                        Divider()

                        inspector
                            .frame(maxWidth: .infinity)
                            .frame(height: inspectorHeight)
                            .accessibilitySortPriority(1)
                    }
                } else {
                    HStack(spacing: 0) {
                        TacticalMapView(model: model)
                            .padding(12)
                            .accessibilitySortPriority(2)

                        Divider()

                        inspector
                            .frame(width: inspectorWidth)
                            .accessibilitySortPriority(1)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MOSUL tactical scenario")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    headerTitleBlock

                    Spacer(minLength: 12)

                    commandControls
                }

                HStack(alignment: .top, spacing: 12) {
                    headerTitleBlock
                        .frame(minWidth: 220, alignment: .leading)

                    Spacer(minLength: 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        commandControls
                            .padding(.vertical, 1)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Command controls")
                    .accessibilityHint("Scroll horizontally for all tactical controls.")
                }
            }

            commandStatusRow
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MosulVersion.displayName)
                .font(.headline)
                .lineLimit(1)
            Text("\(model.scenarioName)  |  \(model.commandSideTitle) vs \(model.opponentSideTitle)  |  Tick \(model.tick)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(MosulVersion.displayName), \(model.scenarioName)")
        .accessibilityValue("\(model.commandSideTitle) versus \(model.opponentSideTitle), tick \(model.tick)")
    }

    private var commandControls: some View {
        HStack(spacing: 8) {
            Picker("Map Mode", selection: modeBinding) {
                ForEach(MosulMapMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            .help(model.mode.prompt)
            .accessibilityLabel("Map mode")
            .accessibilityValue(model.mode.rawValue)
            .accessibilityHint(model.mode.prompt)

            Button {
                model.issueHold()
            } label: {
                Label("Hold", systemImage: "hand.raised.fill")
            }
            .disabled(!model.selectedUnitCanReceiveOrders)
            .keyboardShortcut("h", modifiers: [.command])
            .help("Hold the selected command unit in place.")
            .accessibilityLabel("Hold selected unit")
            .accessibilityHint("Orders the selected command unit to hold position.")

            Button {
                model.issueOverwatch()
            } label: {
                Label("Overwatch", systemImage: "eye.fill")
            }
            .disabled(!model.selectedUnitCanReceiveOrders)
            .keyboardShortcut("o", modifiers: [.command])
            .help("Set the selected command unit to overwatch.")
            .accessibilityLabel("Set overwatch")
            .accessibilityHint("Orders the selected command unit to watch for threats.")

            Button {
                model.issueRally()
            } label: {
                Label("Rally", systemImage: "cross.case.fill")
            }
            .disabled(!model.selectedUnitCanReceiveOrders)
            .keyboardShortcut("r", modifiers: [.command])
            .help("Rally the selected command unit.")
            .accessibilityLabel("Rally selected unit")
            .accessibilityHint("Attempts to reduce suppression for the selected command unit.")

            Divider()
                .frame(height: 24)

            Button {
                model.step()
            } label: {
                Label("Step", systemImage: "forward.frame.fill")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityLabel("Advance one tick")
            .accessibilityHint("Runs one full tactical simulation tick.")

            Button {
                model.runOpponentAI()
            } label: {
                Label("Opponent Tick", systemImage: "cpu")
            }
            .disabled(model.playableSide == nil)
            .keyboardShortcut("t", modifiers: [.command])
            .accessibilityLabel("Run opponent tick")
            .accessibilityHint("Runs one opponent AI tick for the non-command side.")

            Button {
                model.runOpponentAI(steps: 10)
            } label: {
                Label("Opponent x10", systemImage: "forward.end.fill")
            }
            .disabled(model.playableSide == nil)
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .accessibilityLabel("Run ten opponent ticks")
            .accessibilityHint("Runs ten opponent AI ticks for faster playtesting.")

            Button {
                saveSnapshot()
            } label: {
                Label("Snapshot", systemImage: "camera")
            }
            .keyboardShortcut("p", modifiers: [.command])
            .accessibilityLabel("Save snapshot")
            .accessibilityHint("Writes a local tactical map PNG snapshot.")

            Button {
                model.resetPlayableBattle()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .accessibilityLabel("Reset battle")
            .accessibilityHint("Restarts the playable scenario.")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var commandStatusRow: some View {
        HStack(spacing: 8) {
            Label(model.commandHint, systemImage: model.mode.symbolName)
                .font(.caption)
                .foregroundStyle(model.selectedUnitCanReceiveOrders ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            if model.hiddenEnemyUnitCount > 0 {
                Label("\(model.hiddenEnemyUnitCount) unconfirmed contacts withheld", systemImage: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Command status")
        .accessibilityValue(model.commandHint)
    }

    private var sideSelectionOverlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(MosulVersion.displayName)
                        .font(.largeTitle.weight(.semibold))
                    Text(model.scenarioName)
                        .font(.headline)
                    Text("Market / Commercial Streets, Mosul, 2003")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(model.objectives.count) objectives")
                    Text("\(model.units.count) combat units")
                    Text("\(model.civilians.count) civilians")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                Label("Secure the market approaches without turning civilian risk into the deciding loss.", systemImage: "scope")
                Label("Use rooftop and upper-floor routes to resolve hidden contacts before the district unravels.", systemImage: "square.3.layers.3d.top.filled")
                Label("The after-action score is reported from the U.S. stabilization perspective.", systemImage: "list.clipboard")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(MosulPlayableSide.allCases) { side in
                    sideSelectionButton(side)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        }
        .frame(maxWidth: 720)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Side selection")
        .accessibilityHint("Choose which side to command before play begins.")
    }

    private func sideSelectionButton(_ side: MosulPlayableSide) -> some View {
        Button {
            model.startPlayableBattle(as: side)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: side.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 20)
                    Text("Start \(side.title)")
                        .font(.headline)
                }
                Text(side.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(12)
        }
        .buttonStyle(.borderedProminent)
        .tint(side == .usPatrol ? Color.blue : Color.red)
        .keyboardShortcut(side == .usPatrol ? "1" : "2", modifiers: [.command])
        .accessibilityLabel("Start \(side.title)")
        .accessibilityHint(side.subtitle)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                commandPanel
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

                if !model.playerNotice.isEmpty {
                    Text(model.playerNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector")
    }

    private var commandPanel: some View {
        panel("Command Context") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.commandSideTitle)
                        .font(.caption.weight(.semibold))
                    Text("Opponent: \(model.opponentSideTitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu("Side") {
                    ForEach(MosulPlayableSide.allCases) { side in
                        Button(side.title) {
                            model.startPlayableBattle(as: side)
                        }
                        .accessibilityHint("Switch command side to \(side.title).")
                    }
                }
                .font(.caption)
                .accessibilityLabel("Command side")
                .accessibilityValue(model.commandSideTitle)
            }

            if let playableSide = model.playableSide {
                Text(playableSide.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            metricRow("Mode", model.mode.rawValue)
            metricRow("Command State", model.selectedUnitCanReceiveOrders ? "Ready" : "Select command unit")
        }
    }

    private var scorePanel: some View {
        panel("U.S. Stabilization Score") {
            metricRow("Score", "\(model.score.total)")
            metricRow("Outcome", outcomeName(model.score.outcome))
            metricRow("Objectives", "\(model.score.controlledObjectives) controlled / \(model.score.contestedObjectives) contested")
            metricRow("Interactions", "\(model.score.interactionPoints)")
            metricRow("Civilian Risk", "\(model.score.civilianRisk)")
            metricRow("Casualties", "US \(model.score.playerCasualties) | Opfor \(model.score.opforCasualties) | Civ \(model.score.civilianCasualties)")
            Text("Score remains from the U.S. stabilization perspective, separate from the chosen command side.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var afterActionPanel: some View {
        let report = model.afterAction
        let score = report.score

        return panel("U.S. After Action") {
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
                let fullIntel = model.canInspectFullIntel(for: unit)

                Text(model.playerFacingUnitName(unit))
                    .font(.subheadline.weight(.semibold))
                metricRow("Side", model.playerFacingUnitSideName(unit))
                metricRow("Level", model.levelName(for: unit.levelID))
                metricRow("Position", fullIntel ? "\(Int(unit.x)), \(Int(unit.y)) m" : model.playerFacingPosition(x: unit.x, y: unit.y))
                metricRow("Control", model.canIssueOrders(to: unit) ? "Command" : "Intel")

                if fullIntel {
                    metricRow("Order", orderName(unit.order))
                    metricRow("Status", statusName(unit.status))
                    if !unit.topologyNodeID.isEmpty {
                        metricRow("Node", unit.topologyNodeID)
                    }
                    if unit.routeUsesVerticalTransition {
                        metricRow("Route", "\(model.levelLabel(for: unit.levelID))->\(model.levelLabel(for: unit.targetLevelID))")
                    }
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
                    Text("Exact order, strength, and suppression are hidden until this contact is resolved.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        let activeLevels = model.tacticalMapLevelIDs.map { model.levelLabel(for: $0) }.sorted().joined(separator: ", ")

        return panel("Map Tasks") {
            metricRow("Known", "\(model.interactions.count)")
            metricRow("Unresolved", "\(unresolved)")
            metricRow("Actionable", "\(actionable)")
            metricRow("Rooftop", "\(rooftop)")
            if !activeLevels.isEmpty {
                metricRow("Active Levels", activeLevels)
            }
        }
    }

    private var unitsPanel: some View {
        panel("Units") {
            ForEach(model.playerVisibleUnits) { unit in
                Button {
                    model.select(unitID: unit.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.playerFacingUnitName(unit))
                                .font(.caption.weight(.semibold))
                            Text(model.playerFacingUnitSummary(unit))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.canIssueOrders(to: unit) {
                            Text("You")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        } else if !model.canInspectFullIntel(for: unit) {
                            Text("Intel")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if model.canInspectFullIntel(for: unit) {
                            Text("\(unit.soldierCount - unit.casualtyCount)/\(unit.soldierCount)")
                                .font(.caption.monospacedDigit())
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .accessibilityLabel(model.playerFacingUnitName(unit))
                .accessibilityValue(model.playerFacingUnitSummary(unit))
                .accessibilityHint(model.canIssueOrders(to: unit) ? "Select this command unit." : "Inspect this reported contact.")
            }

            if model.hiddenEnemyUnitCount > 0 {
                Divider()
                Label("\(model.hiddenEnemyUnitCount) opposing elements remain unconfirmed.", systemImage: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contactsPanel: some View {
        panel("Contact Reports") {
            let contacts = model.playerVisibleContacts

            if contacts.isEmpty {
                Text("No reports yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(contacts.prefix(8)) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(contactName(contact.kind)) at \(model.playerFacingPosition(x: contact.x, y: contact.y))")
                            .font(.caption.weight(.semibold))
                        Text("Tick \(contact.tick) | \(model.levelLabel(for: contact.levelID)) | \(model.playerFacingContactSideName(contact)) | confidence \(contact.confidence)")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
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
                    Text("\(interactionKindName(interaction.kind)) | \(model.levelRelationDescription(for: interaction)) | \(interaction.state) | \(Int(interaction.distance)) m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    if primaryInteractionTitle(interaction) != "Route", interaction.routeAvailable {
                        Button {
                            model.routeToInteraction(interaction)
                        } label: {
                            Label("Route", systemImage: "arrow.up.right")
                        }
                        .disabled(!model.selectedUnitCanReceiveOrders)
                        .help("Route the selected command unit to this task.")
                        .accessibilityLabel("Route to \(interaction.label)")
                        .accessibilityHint("Moves the selected command unit toward this map task.")
                    }

                    Button {
                        performPrimaryInteraction(interaction)
                    } label: {
                        Label(primaryInteractionTitle(interaction), systemImage: primaryInteractionSymbol(interaction))
                    }
                    .disabled(!primaryInteractionEnabled(interaction))
                    .help(primaryInteractionTitle(interaction))
                    .accessibilityLabel("\(primaryInteractionTitle(interaction)) \(interaction.label)")
                    .accessibilityHint("\(interactionKindName(interaction.kind)) task on \(model.levelRelationDescription(for: interaction)).")
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
        guard model.selectedUnitCanReceiveOrders else {
            return false
        }

        if interaction.source == 1 && (interaction.vertical || interaction.open) {
            return interaction.routeAvailable
        }

        if interaction.source == 1 {
            return interaction.actionable
        }

        return interaction.actionable && !interaction.searched
    }

    private func primaryInteractionSymbol(_ interaction: MosulInteraction) -> String {
        if interaction.source == 1 {
            if interaction.vertical || interaction.open {
                return "arrow.up.right"
            }

            return "hammer.fill"
        }

        return interaction.searched ? "checkmark" : "magnifyingglass"
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
