import AppKit
import SwiftUI

struct TacticalMapView: View {
    @ObservedObject var model: MosulGameModel

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
                Circle()
                    .stroke(sideColor(objective.controllingSide), lineWidth: 2)
                    .frame(
                        width: max(14, objective.radius * 2 * layout.scale),
                        height: max(14, objective.radius * 2 * layout.scale)
                    )
                    .position(point)
            }

            ForEach(model.civilians) { civilian in
                let point = screenPoint(x: civilian.x, y: civilian.y, layout: layout)
                Circle()
                    .fill(Color.yellow.opacity(civilian.risk > 0 ? 0.9 : 0.55))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                    .position(point)
            }

            ForEach(model.contacts) { contact in
                let point = screenPoint(x: contact.x, y: contact.y, layout: layout)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(contact.resolved ? Color.gray : Color.orange, lineWidth: 1.5)
                    .frame(width: 13, height: 13)
                    .rotationEffect(.degrees(45))
                    .position(point)
            }

            ForEach(model.units) { unit in
                let point = screenPoint(x: unit.x, y: unit.y, layout: layout)

                if unit.hasTarget {
                    let target = screenPoint(x: unit.targetX, y: unit.targetY, layout: layout)
                    Path { path in
                        path.move(to: point)
                        path.addLine(to: target)
                    }
                    .stroke(sideColor(unit.side).opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }

                VStack(spacing: 2) {
                    Circle()
                        .fill(sideColor(unit.side))
                        .frame(width: unit.selected ? 20 : 16, height: unit.selected ? 20 : 16)
                        .overlay {
                            Circle()
                                .stroke(unit.selected ? Color.white : Color.black.opacity(0.35), lineWidth: unit.selected ? 3 : 1)
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

    private func sideColor(_ side: Int32) -> Color {
        switch side {
        case 1: return Color(red: 0.24, green: 0.48, blue: 0.73)
        case 2: return Color(red: 0.68, green: 0.22, blue: 0.18)
        case 3: return Color(red: 0.82, green: 0.67, blue: 0.34)
        default: return Color.gray
        }
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
