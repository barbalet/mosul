import AppKit
import SwiftUI

struct TacticalMapView: View {
    @ObservedObject var model: MosulGameModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var pinchStartZoomScale: CGFloat?

    private let scrollable: Bool
    private let minimumZoomScale: CGFloat = 1.0
    private let maximumZoomScale: CGFloat = 3.0
    private let zoomStep: CGFloat = 0.25

    private var spriteManifest: MosulSpriteManifest {
        MosulSpriteManifest.shared(for: model.runtimeResources)
    }

    init(model: MosulGameModel, scrollable: Bool = true) {
        self.model = model
        self.scrollable = scrollable
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                let contentSize = zoomedContentSize(for: proxy.size)

                Group {
                    if scrollable {
                        ScrollView([.horizontal, .vertical]) {
                            mapCanvas(size: contentSize)
                                .frame(width: contentSize.width, height: contentSize.height)
                        }
                        .scrollIndicators(.visible)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                    } else {
                        mapCanvas(size: contentSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            }
                    }
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if pinchStartZoomScale == nil {
                                pinchStartZoomScale = zoomScale
                            }
                            zoomScale = clampedZoomScale((pinchStartZoomScale ?? zoomScale) * value)
                        }
                        .onEnded { _ in
                            pinchStartZoomScale = nil
                        }
                )

                mapLevelControls
                targetingBanner
                zoomControls
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tactical map")
            .accessibilityValue("Tick \(model.tick), \(model.playerVisibleUnits.count) visible units, \(model.playerVisibleContacts.count) contact reports, \(zoomPercent)% zoom")
            .accessibilityHint("Select units or issue the active map order by clicking the map. Scroll when zoomed in.")
            .onAppear {
                model.updateTacticalMapZoom(Double(zoomScale))
            }
            .onChange(of: zoomScale) { _, scale in
                model.updateTacticalMapZoom(Double(scale))
            }
        }
    }

    private func mapCanvas(size: CGSize) -> some View {
        let layout = mapLayout(in: size)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: size.width, height: size.height)

            if let image = mapBaseImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .position(x: layout.rect.midX, y: layout.rect.midY)
                    .accessibilityHidden(true)

                ForEach(model.visibleMapLevels.filter { !$0.isBase }) { level in
                    mapLevelImage(level, layout: layout)
                }

                overlayContent(layout: layout, containerSize: size)
            } else {
                Text("Map PNG not found")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: size.width, height: size.height)
                    .accessibilityLabel("Map PNG not found")
                    .accessibilityHint("The bundled tactical map image could not be loaded.")
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard layout.rect.contains(value.location) else {
                        return
                    }

                    let map = mapPoint(for: value.location, layout: layout)
                    model.handleMapTap(x: map.x, y: map.y)
                }
        )
    }

    private func mapBaseImage() -> NSImage? {
        if let basePath = model.mapLevels.first(where: { $0.isBase && !$0.imagePath.isEmpty })?.imagePath,
           let image = MosulImageCache.shared.image(atPath: basePath) {
            return image
        }

        return MosulImageCache.shared.image(atPath: model.mapOverviewPath)
    }

    @ViewBuilder
    private func mapLevelImage(_ level: MosulMapLevel, layout: MapLayout) -> some View {
        if let image = MosulImageCache.shared.image(atPath: level.imagePath) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .opacity(mapLevelOpacity(level))
                .frame(width: layout.size.width, height: layout.size.height)
                .position(x: layout.rect.midX, y: layout.rect.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var mapLevelControls: some View {
        let overlays = model.overlayMapLevels

        return Group {
            if !overlays.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "square.3.layers.3d.top.filled")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 20)

                    ForEach(overlays) { level in
                        let active = model.visibleMapLevelIDs.contains(level.id)
                        let tactical = model.tacticalMapLevelIDs.contains(level.id)

                        Button {
                            model.toggleMapLevelVisibility(level)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Text(level.shortLabel)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(active ? Color.white : Color.secondary)
                                    .frame(width: 22, height: 20)
                                    .background(
                                        mapLevelControlColor(level).opacity(active ? 0.90 : 0.10),
                                        in: RoundedRectangle(cornerRadius: 4)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(mapLevelControlColor(level).opacity(active ? 0.95 : 0.35), lineWidth: 1)
                                    }

                                if tactical {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 5, height: 5)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(active ? "Hide" : "Show") \(level.displayName)")
                        .accessibilityValue(active ? "Visible" : "Hidden")
                        .accessibilityHint(tactical ? "This level has current tactical activity." : "Toggles this building level overlay.")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Map levels")
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button {
                adjustZoom(by: -zoomStep)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 18, height: 18)
            }
            .disabled(zoomScale <= minimumZoomScale + 0.001)
            .keyboardShortcut("-", modifiers: [.command])
            .help("Zoom out")
            .accessibilityLabel("Zoom out")
            .accessibilityHint("Decreases tactical map zoom.")

            Text("\(zoomPercent)%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 42)
                .accessibilityLabel("Map zoom")
                .accessibilityValue("\(zoomPercent) percent")

            Button {
                adjustZoom(by: zoomStep)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 18, height: 18)
            }
            .disabled(zoomScale >= maximumZoomScale - 0.001)
            .keyboardShortcut("=", modifiers: [.command])
            .help("Zoom in")
            .accessibilityLabel("Zoom in")
            .accessibilityHint("Increases tactical map zoom up to 300 percent.")

            Button {
                setZoom(minimumZoomScale)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 18, height: 18)
            }
            .disabled(zoomScale <= minimumZoomScale + 0.001)
            .keyboardShortcut("0", modifiers: [.command])
            .help("Reset zoom")
            .accessibilityLabel("Reset zoom")
            .accessibilityHint("Returns the tactical map to fit-to-window zoom.")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map zoom controls")
    }

    private var targetingBanner: some View {
        Group {
            if model.hasActiveTargetingMode {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: model.targetingBannerSymbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.92), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.targetingBannerTitle)
                            .font(.caption.weight(.semibold))
                        Text(model.targetingBannerMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 10)

                    Button {
                        model.cancelTargeting()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel targeting")
                    .accessibilityLabel("Cancel targeting")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: 460, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                }
                .padding(.top, 58)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(model.targetingBannerTitle)
                .accessibilityValue(model.targetingBannerMessage)
            }
        }
    }

    private var zoomPercent: Int {
        Int((zoomScale * 100).rounded())
    }

    private func zoomedContentSize(for viewportSize: CGSize) -> CGSize {
        let fittedMapSize = mapLayout(in: viewportSize).size
        let zoomedMapSize = CGSize(
            width: fittedMapSize.width * zoomScale,
            height: fittedMapSize.height * zoomScale
        )

        return CGSize(
            width: max(1, viewportSize.width, zoomedMapSize.width),
            height: max(1, viewportSize.height, zoomedMapSize.height)
        )
    }

    private func adjustZoom(by delta: CGFloat) {
        setZoom(zoomScale + delta)
    }

    private func setZoom(_ scale: CGFloat) {
        withAnimation(.easeOut(duration: 0.16)) {
            zoomScale = clampedZoomScale(scale)
        }
    }

    private func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumZoomScale), maximumZoomScale)
    }

    @ViewBuilder
    private func overlayContent(layout: MapLayout, containerSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            let contacts = model.playerVisibleContacts
            let units = model.playerVisibleUnits

            ForEach(model.civilians.filter { $0.risk > 0 }) { civilian in
                let point = screenPoint(x: civilian.x, y: civilian.y, layout: layout)
                civilianRiskMarker(civilian, at: point)
            }

            ForEach(model.objectives) { objective in
                let point = screenPoint(x: objective.x, y: objective.y, layout: layout)
                objectiveMarker(objective, at: point, layout: layout)
                objectiveLabel(objective, at: point, layout: layout)
            }

            ForEach(model.civilians) { civilian in
                let point = screenPoint(x: civilian.x, y: civilian.y, layout: layout)
                civilianMarker(civilian, at: point)
            }

            ForEach(model.trafficVehicles.filter { $0.active && ($0.hasDestination || $0.hasRoute) }) { vehicle in
                let point = screenPoint(x: vehicle.x, y: vehicle.y, layout: layout)
                let markerPoint = clampedMarkerPoint(point, size: trafficVehicleMarkerSize(vehicle, layout: layout), layout: layout)
                let destinationPoint = screenPoint(x: vehicle.destinationX, y: vehicle.destinationY, layout: layout)
                let destination = clampedMarkerPoint(destinationPoint, size: CGSize(width: 22, height: 22), layout: layout)

                Path { path in
                    path.move(to: markerPoint)
                    path.addLine(to: destination)
                }
                .stroke(trafficVehicleColor(vehicle).opacity(0.96), style: StrokeStyle(lineWidth: 3.0, dash: [6, 4]))
                trafficVehicleDestinationMarker(vehicle, at: destination)
            }

            ForEach(model.trafficVehicles.filter { $0.active }) { vehicle in
                let point = screenPoint(x: vehicle.x, y: vehicle.y, layout: layout)
                let markerPoint = clampedMarkerPoint(point, size: trafficVehicleMarkerSize(vehicle, layout: layout), layout: layout)

                trafficVehicleMarker(vehicle, at: markerPoint, layout: layout)
                if vehicle.isMoving || vehicle.occupiedSeats > 0 || vehicle.routeFailureCount > 0 {
                    trafficVehicleLabel(vehicle, at: markerPoint, layout: layout)
                }
            }

            ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                let point = screenPoint(x: contact.x, y: contact.y, layout: layout)
                contactMarker(
                    contact,
                    at: contactMarkerPoint(
                        contact,
                        basePoint: point,
                        index: index,
                        layout: layout,
                        contacts: contacts
                    )
                )
            }

            ForEach(model.interactions) { interaction in
                let point = screenPoint(x: interaction.x, y: interaction.y, layout: layout)
                interactionMarker(interaction, at: point, layout: layout)
            }

            ForEach(units) { unit in
                let point = screenPoint(x: unit.x, y: unit.y, layout: layout)
                let markerPoint = clampedMarkerPoint(point, size: unitMarkerSize(unit, layout: layout), layout: layout)

                if unit.hasTarget && model.canInspectFullIntel(for: unit) {
                    let targetPoint = screenPoint(x: unit.targetX, y: unit.targetY, layout: layout)
                    let target = clampedMarkerPoint(targetPoint, size: CGSize(width: 24, height: 24), layout: layout)
                    Path { path in
                        path.move(to: markerPoint)
                        path.addLine(to: target)
                    }
                    .stroke(markerColor(unit.routeMarkerID, fallback: sideColor(unit.side)).opacity(0.98), style: StrokeStyle(lineWidth: 3.2, dash: [7, 4]))
                    routeDestinationMarker(unit, at: target)
                }

                unitMarker(unit, at: markerPoint, layout: layout)
                unitLabel(unit, at: markerPoint, layout: layout)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").prefix(2).map(String.init).joined(separator: " ")
    }

    private func objectiveMarker(_ objective: MosulObjective, at point: CGPoint, layout: MapLayout) -> some View {
        let diameter = max(32, objective.radius * 2 * layout.scale)
        let color = sideColor(objective.controllingSide)
        let ringColor = markerColor(objective.markerID, fallback: color)

        return ZStack {
            Circle()
                .fill(color.opacity(0.24))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(Color.white.opacity(0.90), lineWidth: 6)
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3.8, dash: objective.controllingSide == 0 ? [7, 4] : []))
                .frame(width: diameter, height: diameter)
        }
        .shadow(color: ringColor.opacity(0.70), radius: 2.5, x: 0, y: 0)
        .position(point)
    }

    private func objectiveLabel(_ objective: MosulObjective, at point: CGPoint, layout: MapLayout) -> some View {
        let label = objective.label.isEmpty ? objective.name : objective.label
        let diameter = max(22, objective.radius * 2 * layout.scale)
        let color = sideColor(objective.controllingSide)
        let labelSize = CGSize(width: labelWidth(for: label, maxWidth: 124), height: 20)
        let labelPoint = clampedLabelPoint(
            near: point,
            offset: CGSize(width: 0, height: -(diameter * 0.5 + 14)),
            size: labelSize,
            layout: layout
        )

        return HStack(spacing: 3) {
            Image(systemName: "flag.fill")
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Color.white)
        .frame(width: labelSize.width, height: labelSize.height)
        .background(color.opacity(0.95), in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.88), lineWidth: 0.8)
        }
        .position(labelPoint)
    }

    private func civilianMarker(_ civilian: MosulCivilian, at point: CGPoint) -> some View {
        let wounded = civilian.state == 5
        let dead = civilian.state == 6
        let color = markerColor(civilian.markerID, fallback: dead ? Color.gray : wounded ? Color.red : Color.yellow)

        return ZStack {
            Circle()
                .fill(color.opacity(dead ? 0.82 : 1.0))
                .frame(width: dead || wounded ? 15 : 12, height: dead || wounded ? 15 : 12)
                .overlay(Circle().stroke(Color.white.opacity(0.86), lineWidth: 1.4))
                .shadow(color: color.opacity(0.74), radius: 2, x: 0, y: 0)
            if wounded || dead {
                Text(dead ? "X" : "+")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .position(point)
    }

    private func civilianRiskMarker(_ civilian: MosulCivilian, at point: CGPoint) -> some View {
        let risk = max(0, Int(civilian.risk))
        let clampedRisk = min(risk, 8)
        let color = markerColor("civilian_risk", fallback: Color.orange)
        let diameter = CGFloat(34 + clampedRisk * 8)
        let highRisk = risk >= 4

        return ZStack {
            Circle()
                .fill(color.opacity(highRisk ? 0.32 : 0.22))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(Color.white.opacity(0.82), lineWidth: highRisk ? 5.5 : 4.0)
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(
                    color.opacity(highRisk ? 1.0 : 0.92),
                    style: StrokeStyle(lineWidth: highRisk ? 3.4 : 2.6, dash: highRisk ? [] : [6, 4])
                )
                .frame(width: diameter, height: diameter)

            if highRisk {
                Circle()
                    .stroke(color.opacity(0.90), lineWidth: 1.6)
                    .frame(width: diameter + 8, height: diameter + 8)
                Text("R\(risk)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.90))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.96), in: RoundedRectangle(cornerRadius: 3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.90), lineWidth: 0.8)
                    }
                    .offset(x: diameter * 0.36, y: -diameter * 0.36)
            }
        }
        .shadow(color: color.opacity(0.68), radius: 2.4, x: 0, y: 0)
        .allowsHitTesting(false)
        .position(point)
        .accessibilityLabel("Civilian risk \(risk)")
    }

    private func contactMarker(_ contact: MosulContact, at point: CGPoint) -> some View {
        let color = markerColor(contact.markerID, fallback: contactColor(contact))
        let symbol = markerSymbol(contact.markerID, fallback: contactSymbol(contact))

        return ZStack {
            if model.mode == .fire && model.canFire(at: contact) {
                Circle()
                    .fill(Color.yellow.opacity(0.18))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 5.0)
                    .frame(width: 48, height: 48)
                Circle()
                    .stroke(Color.yellow.opacity(1.0), style: StrokeStyle(lineWidth: 3.0, dash: [5, 3]))
                    .frame(width: 48, height: 48)
                Text("FIRE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.98), in: RoundedRectangle(cornerRadius: 3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.9), lineWidth: 0.8)
                    }
                    .offset(y: 31)
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(contact.resolved ? 0.24 : 0.40))
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(45))
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.92), lineWidth: 4.2)
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(45))
            RoundedRectangle(cornerRadius: 2)
                .stroke(color.opacity(contact.resolved ? 0.82 : 1.0), style: StrokeStyle(lineWidth: 2.6, dash: contact.visible ? [] : [4, 2]))
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(45))
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(color)
            levelChip(model.levelLabel(for: contact.levelID), color: color)
                .offset(x: 16, y: -16)
        }
        .opacity(contact.resolved ? 0.88 : 1.0)
        .shadow(color: color.opacity(0.74), radius: 2.4, x: 0, y: 0)
        .position(point)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(contactName(contact.kind)) contact")
        .accessibilityValue("\(model.levelLabel(for: contact.levelID)), confidence \(contact.confidence)")
        .accessibilityHint(contact.resolved ? "Resolved contact report." : "Unresolved contact report.")
    }

    private func contactMarkerPoint(
        _ contact: MosulContact,
        basePoint: CGPoint,
        index: Int,
        layout: MapLayout,
        contacts: [MosulContact]
    ) -> CGPoint {
        let markerSize = CGSize(width: 32, height: 32)
        let clampedBase = clampedMarkerPoint(basePoint, size: markerSize, layout: layout)
        let clusteredContacts = Array(contacts.enumerated()).filter { pair in
            let otherIndex = pair.offset
            let otherContact = pair.element
            guard otherContact.id != contact.id || otherIndex == index else { return false }
            let otherPoint = screenPoint(x: otherContact.x, y: otherContact.y, layout: layout)
            return pointDistance(basePoint, otherPoint) <= 34
        }

        guard clusteredContacts.count > 1,
              let clusterIndex = clusteredContacts.firstIndex(where: { $0.element.id == contact.id }) else {
            return clampedBase
        }

        if clusterIndex == 0 {
            return clampedBase
        }

        let inward: CGFloat = clampedBase.x >= layout.rect.midX ? -1 : 1
        let row = clusterIndex % 3
        let column = clusterIndex / 3
        let rowYOffset: CGFloat

        switch row {
        case 1:
            rowYOffset = -10
        case 2:
            rowYOffset = 10
        default:
            rowYOffset = 0
        }

        let offset = CGSize(
            width: inward * CGFloat(14 + row * 13),
            height: CGFloat(column * 12) + rowYOffset
        )
        return clampedMarkerPoint(
            CGPoint(x: clampedBase.x + offset.width, y: clampedBase.y + offset.height),
            size: markerSize,
            layout: layout
        )
    }

    private func interactionMarker(_ interaction: MosulInteraction, at point: CGPoint, layout: MapLayout) -> some View {
        let color = markerColor(interaction.markerID, fallback: .teal)
        let symbol = markerSymbol(interaction.markerID, fallback: interactionSymbol(interaction))
        let resolved = interaction.searched || interaction.breached || (interaction.kind == 1 && interaction.open)
        let size = max(24, min(44, interaction.radius * layout.scale * 2.15))

        return ZStack {
            if interaction.actionable {
                Circle()
                    .stroke(Color.white.opacity(0.86), lineWidth: 5)
                    .frame(width: size + 18, height: size + 18)
                Circle()
                    .stroke(color.opacity(0.98), style: StrokeStyle(lineWidth: 3.1, dash: [6, 3]))
                    .frame(width: size + 18, height: size + 18)
            }

            if interaction.markerID == "rooftop_access" {
                Triangle()
                    .fill(color.opacity(resolved ? 0.24 : 0.36))
                    .frame(width: size + 2, height: size + 2)
                Triangle()
                    .stroke(Color.white.opacity(0.90), lineWidth: 4.4)
                    .frame(width: size + 2, height: size + 2)
                Triangle()
                    .stroke(color.opacity(resolved ? 0.82 : 1.0), lineWidth: 2.6)
                    .frame(width: size + 2, height: size + 2)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(resolved ? 0.22 : 0.34))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(interaction.markerID == "hidden_contact" ? 45 : 0))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.92), lineWidth: 4.2)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(interaction.markerID == "hidden_contact" ? 45 : 0))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(resolved ? 0.82 : 1.0), style: StrokeStyle(lineWidth: 2.6, dash: resolved ? [5, 3] : []))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(interaction.markerID == "hidden_contact" ? 45 : 0))
            }

            Image(systemName: resolved ? "checkmark" : symbol)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(color)

            if interaction.vertical || interaction.actionable {
                levelChip(model.levelRelationDescription(for: interaction), color: color)
                    .offset(x: size * 0.50, y: -size * 0.48)
            }
        }
        .opacity(resolved ? 0.88 : 1.0)
        .shadow(color: color.opacity(0.74), radius: 2.4, x: 0, y: 0)
        .position(point)
        .accessibilityLabel("\(interaction.label), \(interaction.state)")
    }

    private func routeDestinationMarker(_ unit: MosulUnit, at point: CGPoint) -> some View {
        let color = markerColor(unit.targetMarkerID, fallback: sideColor(unit.side))

        return ZStack {
            Circle()
                .fill(color.opacity(0.34))
                .frame(width: 26, height: 26)
            Circle()
                .stroke(Color.white.opacity(0.92), lineWidth: 4.2)
                .frame(width: 26, height: 26)
            Circle()
                .stroke(color, lineWidth: 2.6)
                .frame(width: 26, height: 26)
            Image(systemName: markerSymbol(unit.targetMarkerID, fallback: routeSymbol(unit.order)))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
        }
        .shadow(color: color.opacity(0.70), radius: 2.2, x: 0, y: 0)
        .position(point)
    }

    private func trafficVehicleDestinationMarker(_ vehicle: MosulTrafficVehicle, at point: CGPoint) -> some View {
        let color = trafficVehicleColor(vehicle)

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.32))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(45))
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.92), lineWidth: 4)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(45))
            RoundedRectangle(cornerRadius: 3)
                .stroke(color.opacity(1.0), lineWidth: 2.4)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(45))
            Image(systemName: "arrow.forward")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
        }
        .shadow(color: color.opacity(0.70), radius: 2.2, x: 0, y: 0)
        .position(point)
    }

    private func trafficVehicleMarker(_ vehicle: MosulTrafficVehicle, at point: CGPoint, layout: MapLayout) -> some View {
        let size = trafficVehicleSpriteSize(vehicle, layout: layout)
        let badgeColor = trafficVehicleColor(vehicle)

        return ZStack(alignment: .topTrailing) {
            trafficVehicleGlyph(vehicle, layout: layout)

            if vehicle.occupiedSeats > 0 {
                Text("\(vehicle.occupiedSeats)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 19, height: 19)
                    .background(badgeColor.opacity(1.0), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.92), lineWidth: 1.2)
                    }
                    .shadow(color: badgeColor.opacity(0.80), radius: 2, x: 0, y: 0)
                    .offset(x: 5, y: -5)
            }
        }
        .frame(width: size + 10, height: size + 10)
        .position(point)
        .accessibilityLabel("\(vehicle.name), \(trafficVehicleKindName(vehicle.kind))")
    }

    private func trafficVehicleLabel(_ vehicle: MosulTrafficVehicle, at point: CGPoint, layout: MapLayout) -> some View {
        let label = "\(trafficVehicleShortName(vehicle)) \(vehicle.occupiedSeats)/\(vehicle.seatCapacity)"
        let labelSize = CGSize(width: labelWidth(for: label, minWidth: 56, maxWidth: 108), height: 18)
        let spriteSize = trafficVehicleSpriteSize(vehicle, layout: layout)
        let yOffset = point.y > layout.rect.maxY - 34 ? -(spriteSize * 0.5 + 10) : spriteSize * 0.5 + 10
        let labelPoint = clampedLabelPoint(
            near: point,
            offset: CGSize(width: 0, height: yOffset),
            size: labelSize,
            layout: layout
        )

        return Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.white)
            .frame(width: labelSize.width, height: labelSize.height)
            .background(trafficVehicleColor(vehicle).opacity(0.94), in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.86), lineWidth: 0.7)
            }
            .position(labelPoint)
    }

    private func unitMarker(_ unit: MosulUnit, at point: CGPoint, layout: MapLayout) -> some View {
        let count = unitStatusCount(unit)
        let statusSize = CGSize(width: 30, height: CGFloat(max(count, 1) * 24))
        let statusPoint = clampedLabelPoint(
            near: point,
            offset: unitStatusOffset(at: point, layout: layout),
            size: statusSize,
            layout: layout
        )

        return ZStack(alignment: .topLeading) {
            unitGlyph(unit, layout: layout)
                .position(point)

            if count > 0 {
                unitStatusStack(unit)
                    .position(statusPoint)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.playerFacingUnitName(unit))
        .accessibilityValue("\(model.playerFacingUnitSideName(unit)), \(model.levelLabel(for: unit.levelID)), \(model.playerFacingUnitSummary(unit))")
        .accessibilityHint(model.canIssueOrders(to: unit) ? "Selectable command unit." : "Visible intelligence contact.")
    }

    private func unitLabel(_ unit: MosulUnit, at point: CGPoint, layout: MapLayout) -> some View {
        let levelSuffix = unit.selected || unit.routeUsesVerticalTransition ? " \(model.levelLabel(for: unit.levelID))" : ""
        let label = "\(shortName(model.playerFacingUnitName(unit)))\(levelSuffix)"
        let labelSize = CGSize(width: labelWidth(for: label, maxWidth: 122), height: 18)
        let spriteSize = unitSpriteSize(unit, layout: layout)
        let yOffset = point.y > layout.rect.maxY - 36 ? -(spriteSize * 0.5 + 10) : spriteSize * 0.5 + 10
        let labelPoint = clampedLabelPoint(
            near: point,
            offset: CGSize(width: 0, height: yOffset),
            size: labelSize,
            layout: layout
        )

        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.white)
            .frame(width: labelSize.width, height: labelSize.height)
            .background(sideColor(unit.side).opacity(0.95), in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.88), lineWidth: 0.7)
            }
            .position(labelPoint)
    }

    private func levelChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .frame(minWidth: 12)
            .frame(height: 12)
            .background(color.opacity(0.94), in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.76), lineWidth: 0.5)
            }
    }

    private func unitMarkerSize(_ unit: MosulUnit, layout: MapLayout) -> CGSize {
        let size = unitSpriteSize(unit, layout: layout)
        return CGSize(width: size + 28, height: size + 26)
    }

    private func unitStatusOffset(at point: CGPoint, layout: MapLayout) -> CGSize {
        let horizontal: CGFloat = point.x >= layout.rect.midX ? -18 : 18
        let vertical: CGFloat = point.y <= layout.rect.minY + 34 ? 18 : -18

        return CGSize(width: horizontal, height: vertical)
    }

    private func unitStatusCount(_ unit: MosulUnit) -> Int {
        var count = 0

        if !unit.selectionMarkerID.isEmpty {
            count += 1
        }

        guard model.canInspectFullIntel(for: unit) else {
            if unit.hidden || unit.revealed {
                count += 1
            }
            return count
        }

        if unit.hidden {
            count += 1
        }
        if !unit.orderMarkerID.isEmpty {
            count += 1
        }
        if !unit.suppressionMarkerID.isEmpty {
            count += 1
        }
        if !unit.casualtyMarkerID.isEmpty {
            count += 1
        }

        return count
    }

    private func unitStatusStack(_ unit: MosulUnit) -> some View {
        VStack(spacing: 2) {
            if !unit.selectionMarkerID.isEmpty {
                markerChip(symbol: "scope", color: .white, background: sideColor(unit.side))
            }

            if !model.canInspectFullIntel(for: unit) {
                markerChip(symbol: unit.revealed ? "eye.fill" : "questionmark", color: .white, background: Color.gray)
            } else {
                if unit.hidden && !unit.revealed {
                    markerChip(symbol: "eye.slash.fill", color: .white, background: .purple)
                } else if unit.hidden && unit.revealed {
                    markerChip(symbol: "eye.fill", color: .white, background: .orange)
                }
                if !unit.orderMarkerID.isEmpty {
                    markerChip(
                        symbol: markerSymbol(unit.orderMarkerID, fallback: orderSymbol(unit.order)),
                        color: .white,
                        background: markerColor(unit.orderMarkerID, fallback: sideColor(unit.side))
                    )
                }
                if !unit.suppressionMarkerID.isEmpty {
                    suppressionMarker(unit.suppression, markerID: unit.suppressionMarkerID)
                }
                if !unit.casualtyMarkerID.isEmpty {
                    casualtyMarker(unit, markerID: unit.casualtyMarkerID)
                }
            }
        }
    }

    private func markerChip(symbol: String, color: Color, background: Color) -> some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.88), lineWidth: 1.1)
                }
                .shadow(color: background.opacity(0.78), radius: 2, x: 0, y: 0)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
        }
    }

    private func suppressionMarker(_ suppression: Int32, markerID: String) -> some View {
        let clamped = max(0, min(CGFloat(suppression) / 20.0, 1.0))
        let color = markerColor(markerID, fallback: Color.orange)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.58))
                .frame(width: 26, height: 7)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 26 * clamped, height: 7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.86), lineWidth: 0.9)
        }
    }

    private func casualtyMarker(_ unit: MosulUnit, markerID: String) -> some View {
        Text("\(unit.casualtyCount)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(markerColor(markerID, fallback: Color.red), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.90), lineWidth: 1.1)
            }
            .shadow(color: markerColor(markerID, fallback: Color.red).opacity(0.80), radius: 2, x: 0, y: 0)
            .accessibilityLabel("\(unit.casualtyCount) casualties")
    }

    private func markerColor(_ markerID: String, fallback: Color) -> Color {
        switch markerID {
        case "move_route", "move_target", "order_hold":
            return Color(red: 1.00, green: 0.84, blue: 0.16)
        case "fire_order", "order_suppress", "casualty":
            return Color(red: 1.00, green: 0.18, blue: 0.12)
        case "overwatch", "order_overwatch":
            return Color(red: 0.08, green: 0.70, blue: 1.00)
        case "suppression", "order_withdraw", "hidden_contact":
            return Color(red: 1.00, green: 0.48, blue: 0.06)
        case "objective":
            return Color(red: 1.00, green: 0.78, blue: 0.10)
        case "breach_search", "order_breach_search":
            return Color(red: 0.25, green: 0.86, blue: 0.34)
        case "rooftop_access":
            return Color(red: 0.18, green: 0.82, blue: 1.00)
        case "civilian_risk":
            return Color(red: 1.00, green: 0.70, blue: 0.04)
        case "order_investigate":
            return Color(red: 0.00, green: 0.88, blue: 0.92)
        default:
            return fallback
        }
    }

    private func mapLevelOpacity(_ level: MosulMapLevel) -> Double {
        if level.alpha == "opaque" {
            return 1.0
        }
        if level.id.contains("roof_access") {
            return 0.72
        }
        if level.index >= 3 {
            return 0.66
        }
        return 0.78
    }

    private func mapLevelControlColor(_ level: MosulMapLevel) -> Color {
        if level.id.contains("roof_access") {
            return Color(red: 0.12, green: 0.78, blue: 0.56)
        }
        if level.index >= 3 {
            return Color(red: 0.48, green: 0.48, blue: 0.96)
        }
        return Color(red: 0.18, green: 0.62, blue: 0.94)
    }

    private func markerSymbol(_ markerID: String, fallback: String) -> String {
        switch markerID {
        case "selection_ring":
            return "scope"
        case "move_target", "move_route":
            return "mappin"
        case "fire_order":
            return "flame.fill"
        case "overwatch", "order_overwatch":
            return "eye.fill"
        case "suppression", "order_suppress":
            return "burst.fill"
        case "casualty":
            return "cross.case.fill"
        case "objective":
            return "flag.fill"
        case "hidden_contact":
            return "questionmark"
        case "breach_search", "order_breach_search":
            return "hammer.fill"
        case "rooftop_access":
            return "stairs"
        case "civilian_risk":
            return "person.2.fill"
        case "order_hold":
            return "hand.raised.fill"
        case "order_investigate":
            return "magnifyingglass"
        case "order_withdraw":
            return "arrow.uturn.left"
        default:
            return fallback
        }
    }

    private func sideColor(_ side: Int32) -> Color {
        switch side {
        case 1: return Color(red: 0.08, green: 0.48, blue: 1.00)
        case 2: return Color(red: 1.00, green: 0.16, blue: 0.12)
        case 3: return Color(red: 1.00, green: 0.82, blue: 0.12)
        default: return Color(red: 0.72, green: 0.76, blue: 0.82)
        }
    }

    private func contactColor(_ contact: MosulContact) -> Color {
        switch contact.kind {
        case 0:
            return Color(red: 1.00, green: 0.14, blue: 0.10)
        case 1:
            return Color(red: 1.00, green: 0.52, blue: 0.08)
        case 2:
            return Color(red: 1.00, green: 0.86, blue: 0.10)
        case 3:
            return Color(red: 0.74, green: 0.36, blue: 1.00)
        case 4:
            return Color(red: 0.74, green: 0.78, blue: 0.84)
        case 5:
            return Color(red: 0.08, green: 0.90, blue: 0.70)
        case 6:
            return Color(red: 0.10, green: 0.58, blue: 1.00)
        default:
            return sideColor(contact.side)
        }
    }

    private func contactSymbol(_ contact: MosulContact) -> String {
        switch contact.kind {
        case 0:
            return "flame.fill"
        case 1:
            return "eye.fill"
        case 2:
            return "person.2.fill"
        case 3:
            return "questionmark"
        case 4:
            return "xmark"
        case 5:
            return "magnifyingglass"
        case 6:
            return "hammer.fill"
        default:
            return "exclamationmark"
        }
    }

    private func interactionSymbol(_ interaction: MosulInteraction) -> String {
        switch interaction.kind {
        case 1:
            return "hammer.fill"
        case 3:
            return "shippingbox.fill"
        case 4:
            return "stairs"
        case 5:
            return "exclamationmark.triangle.fill"
        case 6:
            return "person.2.fill"
        default:
            return "magnifyingglass"
        }
    }

    private func orderSymbol(_ order: Int32) -> String {
        switch order {
        case 1:
            return "hand.raised.fill"
        case 2:
            return "arrow.up.right"
        case 3:
            return "arrow.up.right.circle.fill"
        case 4:
            return "scope"
        case 5:
            return "burst.fill"
        case 6:
            return "eye.fill"
        case 7:
            return "hammer.fill"
        case 8:
            return "cross.case.fill"
        case 9:
            return "arrow.uturn.left"
        case 10:
            return "magnifyingglass"
        default:
            return "smallcircle.filled.circle"
        }
    }

    private func routeSymbol(_ order: Int32) -> String {
        switch order {
        case 10:
            return "magnifyingglass"
        case 9:
            return "arrow.uturn.left"
        case 3:
            return "arrow.up.right.circle.fill"
        default:
            return "mappin"
        }
    }

    @ViewBuilder
    private func unitGlyph(_ unit: MosulUnit, layout: MapLayout) -> some View {
        let size = unitSpriteSize(unit, layout: layout)

        if let sprite = spriteManifest.unitSprite(for: unit),
           let image = MosulImageCache.shared.image(atPath: sprite.path) {
            ZStack {
                Circle()
                    .fill(sideColor(unit.side).opacity(0.34))
                    .frame(width: size * 0.86, height: size * 0.86)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .opacity(unit.hidden && !unit.revealed ? 0.84 : 1.0)
                    .shadow(color: Color.black.opacity(0.40), radius: 1.6, x: 0, y: 1)
            }
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(unit.selected ? 1.0 : 0.92), lineWidth: unit.selected ? 5.0 : 3.4)
                    .frame(width: size * 0.86, height: size * 0.86)
            }
            .overlay {
                Circle()
                    .stroke(sideColor(unit.side).opacity(1.0), lineWidth: unit.selected ? 3.0 : 2.2)
                    .frame(width: size * 0.86, height: size * 0.86)
            }
            .shadow(color: sideColor(unit.side).opacity(0.78), radius: 2.6, x: 0, y: 0)
        } else {
            Circle()
                .fill(sideColor(unit.side))
                .frame(width: unit.selected ? 26 : 22, height: unit.selected ? 26 : 22)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: unit.selected ? 4 : 3)
                }
                .shadow(color: sideColor(unit.side).opacity(0.78), radius: 2.4, x: 0, y: 0)
        }
    }

    @ViewBuilder
    private func trafficVehicleGlyph(_ vehicle: MosulTrafficVehicle, layout: MapLayout) -> some View {
        let size = trafficVehicleSpriteSize(vehicle, layout: layout)
        let color = trafficVehicleColor(vehicle)

        if let sprite = spriteManifest.trafficVehicleSprite(for: vehicle),
           let image = MosulImageCache.shared.image(atPath: sprite.path) {
            ZStack {
                Capsule()
                    .fill(color.opacity(vehicle.isMoving ? 0.34 : 0.26))
                    .frame(width: size * 0.86, height: size * 0.52)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.42), radius: 1.7, x: 0, y: 1)
            }
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.88), lineWidth: vehicle.isMoving ? 3.2 : 2.5)
                    .frame(width: size * 0.78, height: size * 0.48)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(1.0), lineWidth: vehicle.isMoving ? 2.1 : 1.6)
                    .frame(width: size * 0.78, height: size * 0.48)
            }
            .shadow(color: color.opacity(0.70), radius: 2.3, x: 0, y: 0)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: vehicle.kind == 2 ? 6 : 5)
                    .fill(color.opacity(0.58))
                    .frame(
                        width: vehicle.kind == 1 ? size * 0.76 : size * 0.62,
                        height: vehicle.kind == 2 ? size * 0.26 : size * 0.36
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: vehicle.kind == 2 ? 6 : 5)
                            .stroke(Color.white.opacity(0.88), lineWidth: 3.0)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: vehicle.kind == 2 ? 6 : 5)
                            .stroke(color.opacity(1.0), lineWidth: 1.9)
                    }
                Image(systemName: trafficVehicleSymbol(vehicle))
                    .font(.system(size: max(11, size * 0.28), weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.70), radius: 2.3, x: 0, y: 0)
        }
    }

    private func unitSpriteSize(_ unit: MosulUnit, layout: MapLayout) -> CGFloat {
        if unit.side == 3 {
            return max(30, min(52, layout.scale * 14))
        }

        return max(unit.selected ? 42 : 36, min(unit.selected ? 70 : 62, layout.scale * 17))
    }

    private func trafficVehicleSpriteSize(_ vehicle: MosulTrafficVehicle, layout: MapLayout) -> CGFloat {
        switch vehicle.kind {
        case 1:
            return max(58, min(84, layout.scale * 24))
        case 2:
            return max(34, min(48, layout.scale * 12))
        default:
            return max(44, min(66, layout.scale * 17))
        }
    }

    private func trafficVehicleMarkerSize(_ vehicle: MosulTrafficVehicle, layout: MapLayout) -> CGSize {
        let size = trafficVehicleSpriteSize(vehicle, layout: layout)
        return CGSize(width: size + 36, height: size + 30)
    }

    private func trafficVehicleShortName(_ vehicle: MosulTrafficVehicle) -> String {
        switch vehicle.kind {
        case 1:
            return "Bus"
        case 2:
            return "Moto"
        default:
            return "Car"
        }
    }

    private func trafficVehicleSymbol(_ vehicle: MosulTrafficVehicle) -> String {
        switch vehicle.kind {
        case 1:
            return "bus.fill"
        case 2:
            return "motorcycle"
        default:
            return "car.fill"
        }
    }

    private func trafficVehicleColor(_ vehicle: MosulTrafficVehicle) -> Color {
        switch vehicle.kind {
        case 1:
            return Color(red: 0.74, green: 0.78, blue: 0.86)
        case 2:
            return Color(red: 0.10, green: 0.86, blue: 0.72)
        default:
            return Color(red: 0.56, green: 0.66, blue: 0.82)
        }
    }

    private func labelWidth(for text: String, minWidth: CGFloat = 42, maxWidth: CGFloat) -> CGFloat {
        let estimated = CGFloat(text.count) * 5.6 + 14
        return min(max(estimated, minWidth), maxWidth)
    }

    private func clampedLabelPoint(near point: CGPoint, offset: CGSize, size: CGSize, layout: MapLayout) -> CGPoint {
        clampedMarkerPoint(
            CGPoint(x: point.x + offset.width, y: point.y + offset.height),
            size: size,
            layout: layout
        )
    }

    private func clampedMarkerPoint(_ point: CGPoint, size: CGSize, layout: MapLayout) -> CGPoint {
        let inset: CGFloat = 6
        let halfWidth = size.width * 0.5 + inset
        let halfHeight = size.height * 0.5 + inset
        let lowerX = layout.rect.minX + halfWidth
        let upperX = layout.rect.maxX - halfWidth
        let lowerY = layout.rect.minY + halfHeight
        let upperY = layout.rect.maxY - halfHeight

        return CGPoint(
            x: clamped(point.x, lower: lowerX, upper: upperX),
            y: clamped(point.y, lower: lowerY, upper: upperY)
        )
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard lower <= upper else {
            return (lower + upper) * 0.5
        }

        return min(max(value, lower), upper)
    }

    private func pointDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y

        return sqrt(dx * dx + dy * dy)
    }

    private func mapLayout(in size: CGSize) -> MapLayout {
        let mapWidth = max(model.mapWidth, 1)
        let mapHeight = max(model.mapHeight, 1)
        let scale = min(size.width / mapWidth, size.height / mapHeight)
        let renderedSize = CGSize(width: mapWidth * scale, height: mapHeight * scale)
        let origin = CGPoint(
            x: (size.width - renderedSize.width) * 0.5,
            y: (size.height - renderedSize.height) * 0.5
        )

        return MapLayout(rect: CGRect(origin: origin, size: renderedSize), size: renderedSize, scale: scale)
    }

    private func screenPoint(x: CGFloat, y: CGFloat, layout: MapLayout) -> CGPoint {
        CGPoint(x: layout.rect.minX + x * layout.scale, y: layout.rect.minY + y * layout.scale)
    }

    private func mapPoint(for point: CGPoint, layout: MapLayout) -> CGPoint {
        CGPoint(
            x: (point.x - layout.rect.minX) / layout.scale,
            y: (point.y - layout.rect.minY) / layout.scale
        )
    }
}

private struct MapLayout {
    let rect: CGRect
    let size: CGSize
    let scale: CGFloat
}

struct MosulImageCacheStats {
    let loadedImageCount: Int
    let missingImageCount: Int
    let loadedFileBytes: Int64
}

final class MosulImageCache {
    static let shared = MosulImageCache()

    private var images: [String: NSImage] = [:]
    private var missingPaths: Set<String> = []
    private var fileBytesByPath: [String: Int64] = [:]
    private let fileManager = FileManager.default

    private init() {}

    func image(atPath path: String) -> NSImage? {
        guard !path.isEmpty else {
            return nil
        }

        if let image = images[path] {
            return image
        }

        if missingPaths.contains(path) {
            return nil
        }

        guard let image = NSImage(contentsOfFile: path) else {
            missingPaths.insert(path)
            return nil
        }

        images[path] = image
        if let attributes = try? fileManager.attributesOfItem(atPath: path),
           let size = attributes[.size] as? NSNumber {
            fileBytesByPath[path] = size.int64Value
        }
        return image
    }

    func reset() {
        images.removeAll()
        missingPaths.removeAll()
        fileBytesByPath.removeAll()
    }

    func stats() -> MosulImageCacheStats {
        MosulImageCacheStats(
            loadedImageCount: images.count,
            missingImageCount: missingPaths.count,
            loadedFileBytes: fileBytesByPath.values.reduce(0, +)
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
