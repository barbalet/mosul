import SwiftUI

struct ContentView: View {
    @StateObject private var model = MosulGameModel()
    @StateObject private var audio = MosulAudioController()
    @State private var snapshotStatus = ""
    @State private var showHowToPlay = true
    @State private var activeCommandControlTip: CommandControlTip?
    @State private var seenCommandControlTips: Set<CommandControlTip> = []
    @State private var showMovementCoach = false
    @State private var movementCoachDismissed = false
    @State private var movementCoachUnitID: UInt32?
    @State private var handledAudioEventCount = 0

    var body: some View {
        Group {
            if let issue = model.releaseIssue {
                releaseIssueView(issue)
            } else {
                ZStack {
                    gameLayout
                        .disabled(showHowToPlay || model.playableSide == nil)
                        .blur(radius: showHowToPlay || model.playableSide == nil ? 1.2 : 0)

                    if showHowToPlay {
                        howToPlayOverlay
                            .padding(24)
                    } else if model.playableSide == nil {
                        sideSelectionOverlay
                            .padding(24)
                    }
                }
            }
        }
        .onAppear {
            audio.configure(runtimeResources: model.runtimeResources)
            audio.updateContext(model.audioContext)
        }
        .onChange(of: model.selectedUnit?.id) { _, _ in
            presentMovementCoachIfNeeded()
        }
        .onChange(of: showHowToPlay) { _, _ in
            presentMovementCoachIfNeeded()
        }
        .onChange(of: model.audioContext) { _, context in
            audio.updateContext(context)
        }
        .onChange(of: model.audioEvents) { _, events in
            if events.count < handledAudioEventCount {
                handledAudioEventCount = 0
            }

            for event in events.dropFirst(handledAudioEventCount) {
                audio.play(event)
            }
            handledAudioEventCount = events.count
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
            if model.hasActiveTargetingMode {
                Button {
                    model.cancelTargeting()
                } label: {
                    Label("Cancel Targeting", systemImage: "xmark.circle.fill")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .help("Cancel the current target selection.")
                .accessibilityLabel("Cancel targeting")
            }

            soundControls(includeVolume: true, includeShortcut: !showHowToPlay && model.playableSide != nil)

            Button {
                handleCommandControl(.step, showTipFirst: !model.selectedUnitHasPendingOrder) {
                    model.step()
                }
            } label: {
                Label(model.selectedUnitHasPendingOrder ? "Step: Execute" : "Step", systemImage: "forward.frame.fill")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityLabel("Advance one tick")
            .accessibilityHint("Runs one full tactical simulation tick.")
            .popover(isPresented: commandControlTipBinding(.step), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                commandControlTipView(.step)
            }

            Button {
                handleCommandControl(.opponentTick) {
                    model.runOpponentAI()
                }
            } label: {
                Label("Opponent Tick", systemImage: "cpu")
            }
            .disabled(model.playableSide == nil)
            .keyboardShortcut("t", modifiers: [.command])
            .accessibilityLabel("Run opponent tick")
            .accessibilityHint("Runs one opponent AI tick for the non-command side.")
            .popover(isPresented: commandControlTipBinding(.opponentTick), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                commandControlTipView(.opponentTick)
            }

            Button {
                handleCommandControl(.opponentTen) {
                    model.runOpponentAI(steps: 10)
                }
            } label: {
                Label("Opponent x10", systemImage: "forward.end.fill")
            }
            .disabled(model.playableSide == nil)
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .accessibilityLabel("Run ten opponent ticks")
            .accessibilityHint("Runs ten opponent AI ticks for faster playtesting.")
            .popover(isPresented: commandControlTipBinding(.opponentTen), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                commandControlTipView(.opponentTen)
            }

            Button {
                handleCommandControl(.snapshot) {
                    saveSnapshot()
                }
            } label: {
                Label("Snapshot", systemImage: "camera")
            }
            .keyboardShortcut("p", modifiers: [.command])
            .accessibilityLabel("Save snapshot")
            .accessibilityHint("Writes a local tactical map PNG snapshot.")
            .popover(isPresented: commandControlTipBinding(.snapshot), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                commandControlTipView(.snapshot)
            }

            Button {
                handleCommandControl(.reset) {
                    model.resetPlayableBattle()
                }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .accessibilityLabel("Reset battle")
            .accessibilityHint("Restarts the playable scenario.")
            .popover(isPresented: commandControlTipBinding(.reset), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                commandControlTipView(.reset)
            }
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

            if !audio.caption.isEmpty {
                Label(audio.caption, systemImage: "radio.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel("Radio")
                    .accessibilityValue(audio.caption)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Command status")
        .accessibilityValue(model.commandHint)
    }

    private var howToPlayOverlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "scope")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How to Play")
                        .font(.largeTitle.weight(.semibold))
                    Text("Command a small force through a confused urban fight. Select units, issue simple orders, investigate contacts, and keep civilians from becoming the cost of winning.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                soundControls(includeVolume: false, includeShortcut: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                howToPlayRow(
                    "Read the map",
                    "Bright blue marks your command units. Red and orange mark danger or hostile reports. Yellow marks civilians, objectives, and civilian risk. Green and teal mark tasks, routes, and upper-level access.",
                    symbol: "map.fill"
                )
                howToPlayRow(
                    "Movement",
                    "Select one of your command units, choose Move, then click a destination on the map. A route or destination line appears, and the unit moves when you press Step.",
                    symbol: "arrow.up.right"
                )
                howToPlayRow(
                    "Investigating",
                    "Choose Investigate, then click a suspicious contact, danger area, or building task. The selected unit moves more cautiously and can resolve map tasks when it reaches them.",
                    symbol: "magnifyingglass"
                )
                howToPlayRow(
                    "Watch",
                    "Select a command unit and press Watch to stop it and put it into a watch posture. It does not auto-fire; use Fire for a specific target.",
                    symbol: "eye.fill"
                )
                howToPlayRow(
                    "Firing",
                    "Select a command unit, press Fire, then click a highlighted opposing contact. Fire checks line of sight, range, ammunition, cover, suppression, casualties, and civilian risk.",
                    symbol: "scope"
                )
                howToPlayRow(
                    "Time",
                    "After giving orders, press Step to run one tactical tick. Movement, investigations, suppression recovery, reports, objectives, and civilian risk update during ticks.",
                    symbol: "forward.frame.fill"
                )
                howToPlayRow(
                    "Resolve tasks before racing time",
                    "Use the right-side task list to route, search, breach, and use rooftops. The score rewards objectives and resolved interactions, but punishes casualties and civilian risk.",
                    symbol: "checklist"
                )
            }

            HStack {
                Label("First time you touch a top control, a short explanation opens below it. Click the same control again to use it.", systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 18)

                Button {
                    showHowToPlay = false
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        }
        .frame(maxWidth: 840)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How to play")
        .accessibilityHint("Explains the basic play loop before side selection.")
    }

    private func howToPlayRow(_ title: String, _ message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

                soundControls(includeVolume: false, includeShortcut: true)
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
            presentMovementCoachIfNeeded()
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

    private func soundControls(includeVolume: Bool, includeShortcut: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                audio.toggleMuted()
            } label: {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 18, height: 18)
            }
            .disabled(audio.isDisabledByLaunchArgument)
            .help(audio.isMuted ? "Unmute sound." : "Mute sound.")
            .accessibilityLabel(audio.isMuted ? "Unmute sound" : "Mute sound")
            .accessibilityHint("Toggles all MosulGame sound immediately.")
            .accessibilityValue(audio.accessibilityValue)
            .modifier(SoundKeyboardShortcut(enabled: includeShortcut))

            if includeVolume {
                Slider(
                    value: Binding(
                        get: { audio.masterVolume },
                        set: { audio.setMasterVolume($0) }
                    ),
                    in: 0...1
                )
                .frame(width: 74)
                .disabled(audio.isDisabledByLaunchArgument)
                .help(audio.status.description)
                .accessibilityLabel("Sound volume")
                .accessibilityValue(audio.accessibilityValue)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sound controls")
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                commandPanel
                selectedCommandPanel
                rulesPanel
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
                            presentMovementCoachIfNeeded()
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

            metricRow("Targeting", model.mode.rawValue)
            metricRow("Command State", model.selectedUnitCanReceiveOrders ? "Ready" : "Select command unit")
        }
    }

    private var selectedCommandPanel: some View {
        panel("Selected Unit Commands") {
            if let unit = model.selectedUnit, model.canIssueOrders(to: unit) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.playerFacingUnitName(unit))
                                .font(.caption.weight(.semibold))
                            Text(model.selectedUnitPendingOrderHint)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 6)], spacing: 6) {
                        Button {
                            movementCoachDismissed = true
                            showMovementCoach = false
                            model.beginMoveOrder()
                        } label: {
                            Label("Move", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .keyboardShortcut("m", modifiers: [.command])
                        .help("Choose a destination on the map.")
                        .accessibilityHint("Starts movement targeting for the selected unit.")
                        .popover(isPresented: movementCoachBinding, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                            movementCoachView
                        }

                        unitCommandButton("Investigate", symbol: "magnifyingglass") {
                            model.beginInvestigateOrder()
                        }
                        .keyboardShortcut("i", modifiers: [.command])

                        unitCommandButton("Fire", symbol: "scope") {
                            model.beginFireOrder()
                        }
                        .keyboardShortcut("f", modifiers: [.command])

                        unitCommandButton("Watch", symbol: "eye.fill") {
                            model.issueOverwatch()
                        }
                        .keyboardShortcut("o", modifiers: [.command])

                        unitCommandButton("Hold", symbol: "hand.raised.fill") {
                            model.issueHold()
                        }
                        .keyboardShortcut("h", modifiers: [.command])

                        unitCommandButton("Rally", symbol: "cross.case.fill") {
                            model.issueRally()
                        }
                        .keyboardShortcut("r", modifiers: [.command])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if model.hasActiveTargetingMode {
                        Button {
                            model.cancelTargeting()
                        } label: {
                            Label("Cancel Targeting", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else if let unit = model.selectedUnit {
                Text("\(model.playerFacingUnitName(unit)) is visible intelligence only. Select one of your command units to issue orders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Select one of your command units. Its available orders appear here as buttons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rulesPanel: some View {
        panel("How Orders Work") {
            orderRuleRow(
                "Movement",
                "Select your unit, press Move, click the map, then press Step. A dashed target line appears before the unit moves; traffic, buildings, and upper-level routes can slow or block it.",
                symbol: "arrow.up.right"
            )
            orderRuleRow(
                "Watch",
                "Select your unit and press Watch. It cancels movement and keeps the unit watching from its current position; it is a posture, not automatic reaction fire.",
                symbol: "eye.fill"
            )
            orderRuleRow(
                "Fire",
                "Select your unit, press Fire, then click a highlighted opposing contact. The shot resolves only with line of sight, range, ammunition, and an eligible shooter.",
                symbol: "scope"
            )
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
                Text("To fire, select one of your command units, then use Fire on an opposing unit contact. The selected unit must have line of sight, range, ammunition, and an eligible shooter.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(contacts.prefix(8)) { contact in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(contactName(contact.kind)) at \(model.playerFacingPosition(x: contact.x, y: contact.y))")
                                .font(.caption.weight(.semibold))
                            Text("Tick \(contact.tick) | \(model.levelLabel(for: contact.levelID)) | \(model.playerFacingContactSideName(contact)) | confidence \(contact.confidence)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        if contact.targetUnitID != 0 {
                            Button {
                                model.fireAtContact(contact)
                            } label: {
                                Label("Fire", systemImage: "scope")
                            }
                            .disabled(!model.canFire(at: contact))
                            .font(.caption2)
                            .help("Fire the selected command unit at this contact.")
                            .accessibilityLabel("Fire at \(contactName(contact.kind)) contact")
                            .accessibilityHint("Uses the selected command unit to resolve line of sight, range, ammunition, cover, suppression, casualties, and civilian risk.")
                        }
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

    private func unitCommandButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .help(title)
        .accessibilityLabel(title)
    }

    private var movementCoachBinding: Binding<Bool> {
        Binding(
            get: { showMovementCoach },
            set: { isPresented in
                showMovementCoach = isPresented
                if !isPresented {
                    movementCoachDismissed = true
                }
            }
        )
    }

    private var movementCoachView: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Movement")
                        .font(.headline)
                    Text("Movement is deliberate. First choose Move, then click a destination on the map. The dashed line is the pending order; the unit moves only after you press Step.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("1. Press Move", systemImage: "1.circle.fill")
                Label("2. Click the destination", systemImage: "2.circle.fill")
                Label("3. Press Step: Execute", systemImage: "3.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Dismiss") {
                    movementCoachDismissed = true
                    showMovementCoach = false
                }
                Spacer()
                Button {
                    movementCoachDismissed = true
                    showMovementCoach = false
                    model.beginMoveOrder()
                } label: {
                    Label("Start Move", systemImage: "arrow.up.right")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
    }

    private func presentMovementCoachIfNeeded() {
        guard !movementCoachDismissed,
              !showHowToPlay,
              model.playableSide != nil,
              model.selectedUnitCanReceiveOrders,
              let selectedUnit = model.selectedUnit else {
            return
        }

        guard movementCoachUnitID != selectedUnit.id else {
            return
        }

        movementCoachUnitID = selectedUnit.id
        showMovementCoach = true
    }

    private func orderRuleRow(_ title: String, _ message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    private func handleCommandControl(_ tip: CommandControlTip, showTipFirst: Bool = true, action: () -> Void) {
        if showTipFirst, presentCommandControlTipIfNeeded(tip) {
            return
        }

        action()
    }

    @discardableResult
    private func presentCommandControlTipIfNeeded(_ tip: CommandControlTip) -> Bool {
        guard !seenCommandControlTips.contains(tip) else {
            return false
        }

        seenCommandControlTips.insert(tip)
        activeCommandControlTip = tip
        return true
    }

    private func commandControlTipBinding(_ tip: CommandControlTip) -> Binding<Bool> {
        Binding(
            get: { activeCommandControlTip == tip },
            set: { isPresented in
                if !isPresented, activeCommandControlTip == tip {
                    activeCommandControlTip = nil
                }
            }
        )
    }

    private func commandControlTipView(_ tip: CommandControlTip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: tip.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title)
                        .font(.headline)
                    Text(tip.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("This appears only on first use in this play session. Click the same control again to use it.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Got it") {
                    activeCommandControlTip = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
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

private enum CommandControlTip: String, Hashable, Identifiable {
    case mapMode
    case hold
    case overwatch
    case rally
    case step
    case opponentTick
    case opponentTen
    case snapshot
    case reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mapMode:
            return "Map Mode"
        case .hold:
            return "Hold"
        case .overwatch:
            return "Watch"
        case .rally:
            return "Rally"
        case .step:
            return "Step"
        case .opponentTick:
            return "Opponent Tick"
        case .opponentTen:
            return "Opponent x10"
        case .snapshot:
            return "Snapshot"
        case .reset:
            return "Reset"
        }
    }

    var symbolName: String {
        switch self {
        case .mapMode:
            return "scope"
        case .hold:
            return "hand.raised.fill"
        case .overwatch:
            return "eye.fill"
        case .rally:
            return "cross.case.fill"
        case .step:
            return "forward.frame.fill"
        case .opponentTick:
            return "cpu"
        case .opponentTen:
            return "forward.end.fill"
        case .snapshot:
            return "camera"
        case .reset:
            return "arrow.counterclockwise"
        }
    }

    var message: String {
        switch self {
        case .mapMode:
            return "Select inspects the map. Move lets you click a destination for the selected command unit. Investigate lets that unit move cautiously toward suspicious contacts or terrain cues."
        case .hold:
            return "Orders the selected command unit to stay in place. Use it when the unit should secure ground instead of drifting toward another task."
        case .overwatch:
            return "Orders the selected command unit to stop moving and watch from its current position. It is not automatic reaction fire; use Fire for a specific opposing contact."
        case .rally:
            return "Attempts to reduce suppression on the selected command unit so it can keep acting effectively."
        case .step:
            return "Advances the whole tactical simulation by one tick. Movement, investigations, reports, objectives, suppression, and civilian risk update after you step."
        case .opponentTick:
            return "Runs one AI tick for the non-command side. It helps test enemy movement without repeatedly stepping everything by hand."
        case .opponentTen:
            return "Runs ten opponent AI ticks in a row for faster playtesting. Use it when you want the opposition to progress quickly."
        case .snapshot:
            return "Writes a tactical map PNG to disk so you can inspect or share the current state."
        case .reset:
            return "Restarts the playable scenario for the current command side. It clears the current battle state."
        }
    }
}

private struct SoundKeyboardShortcut: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyboardShortcut("m", modifiers: [.command, .shift])
        } else {
            content
        }
    }
}
