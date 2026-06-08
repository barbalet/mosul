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

            ForEach(model.units) { unit in
                let point = screenPoint(x: unit.x, y: unit.y, layout: layout)

                if unit.hasTarget {
                    let target = screenPoint(x: unit.targetX, y: unit.targetY, layout: layout)
                    Path { path in
                        path.move(to: point)
                        path.addLine(to: target)
                    }
                    .stroke(sideColor(unit.side).opacity(0.78), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
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

        return ZStack {
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, dash: objective.controllingSide == 0 ? [5, 4] : []))
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
        let color = dead ? Color.gray : wounded ? Color.red : Color.yellow
        let riskSize = CGFloat(14 + min(max(civilian.risk, 0), 8) * 3)

        return ZStack {
            if civilian.risk > 0 {
                Circle()
                    .stroke(Color.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
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
        let color = contactColor(contact)
        let symbol = contactSymbol(contact)

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

    private func routeDestinationMarker(_ unit: MosulUnit, at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(sideColor(unit.side).opacity(0.16))
                .frame(width: 18, height: 18)
            Circle()
                .stroke(sideColor(unit.side), lineWidth: 1.6)
                .frame(width: 18, height: 18)
            Image(systemName: routeSymbol(unit.order))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(sideColor(unit.side))
        }
        .position(point)
    }

    private func unitStatusStack(_ unit: MosulUnit) -> some View {
        VStack(spacing: 2) {
            if unit.selected {
                markerChip(symbol: "scope", color: .white, background: sideColor(unit.side))
            }
            if unit.hidden && !unit.revealed {
                markerChip(symbol: "eye.slash.fill", color: .white, background: .purple)
            } else if unit.hidden && unit.revealed {
                markerChip(symbol: "eye.fill", color: .white, background: .orange)
            }
            if unit.order != 0 {
                markerChip(symbol: orderSymbol(unit.order), color: .white, background: sideColor(unit.side))
            }
            if unit.suppression > 0 {
                suppressionMarker(unit.suppression)
            }
            if unit.casualtyCount > 0 {
                casualtyMarker(unit)
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

    private func suppressionMarker(_ suppression: Int32) -> some View {
        let clamped = max(0, min(CGFloat(suppression) / 20.0, 1.0))

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.35))
                .frame(width: 22, height: 5)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange)
                .frame(width: 22 * clamped, height: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.55), lineWidth: 0.5)
        }
    }

    private func casualtyMarker(_ unit: MosulUnit) -> some View {
        Text("\(unit.casualtyCount)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Color.red, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            }
            .accessibilityLabel("\(unit.casualtyCount) casualties")
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
