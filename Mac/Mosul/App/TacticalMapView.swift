import AppKit
import SwiftUI

struct TacticalMapView: View {
    @ObservedObject var model: MosulGameModel
    private var spriteManifest: MosulSpriteManifest {
        MosulSpriteManifest.shared(for: model.modernerKriegRoot)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = mapLayout(in: proxy.size)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))

                if let image = NSImage(contentsOfFile: model.mapOverviewPath) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: layout.size.width, height: layout.size.height)
                        .position(x: layout.rect.midX, y: layout.rect.midY)
                        .overlay(alignment: .topLeading) {
                            overlayContent(layout: layout)
                        }
                } else {
                    Text("Map PNG not found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard layout.rect.contains(value.location) else { return }
                        let map = mapPoint(for: value.location, layout: layout)
                        model.handleMapTap(x: map.x, y: map.y)
                    }
            )
        }
    }

    @ViewBuilder
    private func overlayContent(layout: MapLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.objectives) { objective in
                let point = screenPoint(x: objective.x, y: objective.y, layout: layout)
                objectiveMarker(objective, at: point, layout: layout)
            }

            ForEach(model.civilians) { civilian in
                let point = screenPoint(x: civilian.x, y: civilian.y, layout: layout)
                civilianMarker(civilian, at: point)
            }

            ForEach(model.contacts) { contact in
                let point = screenPoint(x: contact.x, y: contact.y, layout: layout)
                contactMarker(contact, at: point)
            }

            ForEach(model.interactions) { interaction in
                let point = screenPoint(x: interaction.x, y: interaction.y, layout: layout)
                interactionMarker(interaction, at: point, layout: layout)
            }

            ForEach(model.units) { unit in
                let point = screenPoint(x: unit.x, y: unit.y, layout: layout)

                if unit.hasTarget {
                    let target = screenPoint(x: unit.targetX, y: unit.targetY, layout: layout)
                    Path { path in
                        path.move(to: point)
                        path.addLine(to: target)
                    }
                    .stroke(markerColor(unit.routeMarkerID, fallback: sideColor(unit.side)).opacity(0.78), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    routeDestinationMarker(unit, at: target)
                }

                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        unitGlyph(unit, layout: layout)
                        unitStatusStack(unit)
                            .offset(x: 13, y: -12)
                    }
                    Text(shortName(unit.name))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 3)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 3))
                }
                .position(point)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .position(x: layout.rect.midX, y: layout.rect.midY)
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").prefix(2).map(String.init).joined(separator: " ")
    }

    private func objectiveMarker(_ objective: MosulObjective, at point: CGPoint, layout: MapLayout) -> some View {
        let diameter = max(22, objective.radius * 2 * layout.scale)
        let color = sideColor(objective.controllingSide)
        let ringColor = markerColor(objective.markerID, fallback: color)

        return ZStack {
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, dash: objective.controllingSide == 0 ? [5, 4] : []))
                .frame(width: diameter, height: diameter)
            VStack(spacing: 1) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(objective.label.isEmpty ? objective.name : objective.label)
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 3))
            }
            .foregroundStyle(color)
            .offset(y: -(diameter * 0.5 + 14))
        }
        .position(point)
    }

    private func civilianMarker(_ civilian: MosulCivilian, at point: CGPoint) -> some View {
        let wounded = civilian.state == 5
        let dead = civilian.state == 6
        let color = markerColor(civilian.markerID, fallback: dead ? Color.gray : wounded ? Color.red : Color.yellow)
        let riskSize = CGFloat(14 + min(max(civilian.risk, 0), 8) * 3)

        return ZStack {
            if civilian.risk > 0 {
                Circle()
                    .stroke(markerColor("civilian_risk", fallback: Color.orange).opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: riskSize, height: riskSize)
            }
            Circle()
                .fill(color.opacity(dead ? 0.65 : 0.9))
                .frame(width: dead || wounded ? 10 : 8, height: dead || wounded ? 10 : 8)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
            if wounded || dead {
                Text(dead ? "X" : "+")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .position(point)
    }

    private func contactMarker(_ contact: MosulContact, at point: CGPoint) -> some View {
        let color = markerColor(contact.markerID, fallback: contactColor(contact))
        let symbol = markerSymbol(contact.markerID, fallback: contactSymbol(contact))

        return ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(contact.resolved ? 0.08 : 0.16))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(45))
            RoundedRectangle(cornerRadius: 2)
                .stroke(color.opacity(contact.resolved ? 0.65 : 1.0), style: StrokeStyle(lineWidth: 1.8, dash: contact.visible ? [] : [3, 2]))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(45))
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .opacity(contact.resolved ? 0.72 : 1.0)
        .position(point)
    }

    private func interactionMarker(_ interaction: MosulInteraction, at point: CGPoint, layout: MapLayout) -> some View {
        let color = markerColor(interaction.markerID, fallback: .teal)
        let symbol = markerSymbol(interaction.markerID, fallback: interactionSymbol(interaction))
        let resolved = interaction.searched || interaction.breached || (interaction.kind == 1 && interaction.open)
        let size = max(18, min(34, interaction.radius * layout.scale * 2.0))

        return ZStack {
            if interaction.actionable {
                Circle()
                    .stroke(color.opacity(0.76), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: size + 14, height: size + 14)
            }

            if interaction.markerID == "rooftop_access" {
                Triangle()
                    .fill(color.opacity(resolved ? 0.12 : 0.20))
                    .frame(width: size + 2, height: size + 2)
                Triangle()
                    .stroke(color.opacity(resolved ? 0.55 : 0.95), lineWidth: 1.8)
                    .frame(width: size + 2, height: size + 2)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(resolved ? 0.10 : 0.18))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(interaction.markerID == "hidden_contact" ? 45 : 0))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(resolved ? 0.55 : 0.95), style: StrokeStyle(lineWidth: 1.8, dash: resolved ? [4, 3] : []))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(interaction.markerID == "hidden_contact" ? 45 : 0))
            }

            Image(systemName: resolved ? "checkmark" : symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
        .opacity(resolved ? 0.72 : 1.0)
        .position(point)
        .accessibilityLabel("\(interaction.label), \(interaction.state)")
    }

    private func routeDestinationMarker(_ unit: MosulUnit, at point: CGPoint) -> some View {
        let color = markerColor(unit.targetMarkerID, fallback: sideColor(unit.side))

        return ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 18, height: 18)
            Circle()
                .stroke(color, lineWidth: 1.6)
                .frame(width: 18, height: 18)
            Image(systemName: markerSymbol(unit.targetMarkerID, fallback: routeSymbol(unit.order)))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
        }
        .position(point)
    }

    private func unitStatusStack(_ unit: MosulUnit) -> some View {
        VStack(spacing: 2) {
            if !unit.selectionMarkerID.isEmpty {
                markerChip(symbol: "scope", color: .white, background: sideColor(unit.side))
            }
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

    private func markerChip(symbol: String, color: Color, background: Color) -> some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func suppressionMarker(_ suppression: Int32, markerID: String) -> some View {
        let clamped = max(0, min(CGFloat(suppression) / 20.0, 1.0))
        let color = markerColor(markerID, fallback: Color.orange)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.35))
                .frame(width: 22, height: 5)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 22 * clamped, height: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.55), lineWidth: 0.5)
        }
    }

    private func casualtyMarker(_ unit: MosulUnit, markerID: String) -> some View {
        Text("\(unit.casualtyCount)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(markerColor(markerID, fallback: Color.red), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            }
            .accessibilityLabel("\(unit.casualtyCount) casualties")
    }

    private func markerColor(_ markerID: String, fallback: Color) -> Color {
        switch markerID {
        case "move_route", "move_target", "order_hold":
            return Color(red: 0.75, green: 0.70, blue: 0.38)
        case "fire_order", "order_suppress", "casualty":
            return Color(red: 0.78, green: 0.24, blue: 0.20)
        case "overwatch", "order_overwatch":
            return Color(red: 0.32, green: 0.55, blue: 0.68)
        case "suppression", "order_withdraw", "hidden_contact":
            return Color(red: 0.78, green: 0.48, blue: 0.20)
        case "objective":
            return Color(red: 0.55, green: 0.50, blue: 0.28)
        case "breach_search", "order_breach_search":
            return Color(red: 0.45, green: 0.58, blue: 0.42)
        case "rooftop_access":
            return Color(red: 0.38, green: 0.58, blue: 0.67)
        case "civilian_risk":
            return Color(red: 0.86, green: 0.68, blue: 0.28)
        case "order_investigate":
            return Color(red: 0.30, green: 0.66, blue: 0.70)
        default:
            return fallback
        }
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
        case 1: return Color(red: 0.24, green: 0.48, blue: 0.73)
        case 2: return Color(red: 0.68, green: 0.22, blue: 0.18)
        case 3: return Color(red: 0.82, green: 0.67, blue: 0.34)
        default: return Color.gray
        }
    }

    private func contactColor(_ contact: MosulContact) -> Color {
        switch contact.kind {
        case 0:
            return .red
        case 1:
            return .orange
        case 2:
            return .yellow
        case 3:
            return .purple
        case 4:
            return .gray
        case 5:
            return .mint
        case 6:
            return .blue
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
           let image = NSImage(contentsOfFile: sprite.path) {
            ZStack {
                Circle()
                    .fill(sideColor(unit.side).opacity(0.16))
                    .frame(width: size * 0.72, height: size * 0.72)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .opacity(unit.hidden && !unit.revealed ? 0.72 : 1.0)
            }
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(unit.selected ? Color.white : sideColor(unit.side).opacity(0.55), lineWidth: unit.selected ? 3 : 1)
                    .frame(width: size * 0.78, height: size * 0.78)
            }
        } else {
            Circle()
                .fill(sideColor(unit.side))
                .frame(width: unit.selected ? 20 : 16, height: unit.selected ? 20 : 16)
                .overlay {
                    Circle()
                        .stroke(unit.selected ? Color.white : Color.black.opacity(0.35), lineWidth: unit.selected ? 3 : 1)
                }
        }
    }

    private func unitSpriteSize(_ unit: MosulUnit, layout: MapLayout) -> CGFloat {
        if unit.side == 3 {
            return max(24, min(46, layout.scale * 12))
        }

        return max(unit.selected ? 34 : 30, min(unit.selected ? 62 : 54, layout.scale * 15))
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
