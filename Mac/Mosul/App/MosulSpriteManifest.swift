import AppKit
import Foundation

struct MosulResolvedSprite {
    let path: String
    let pixelSize: CGSize
}

final class MosulSpriteManifest {
    private static var cache: [String: MosulSpriteManifest] = [:]

    private let rootURL: URL
    private let outputRoot: String
    private let imageSets: [String: MosulSpriteImageSet]
    private let fileManager = FileManager.default

    static func shared(for runtimeResources: MosulRuntimeResources) -> MosulSpriteManifest {
        let cacheKey = runtimeResources.modernerKriegRoot
        if let cached = cache[cacheKey] {
            return cached
        }

        let manifest = MosulSpriteManifest(runtimeResources: runtimeResources)
        cache[cacheKey] = manifest
        return manifest
    }

    private init(runtimeResources: MosulRuntimeResources) {
        rootURL = runtimeResources.modernerKriegRootURL

        let manifestURL = rootURL
            .appendingPathComponent("assets/mosul/runtime/sprites/manifest.json")

        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(MosulSpriteRuntimeManifest.self, from: data) {
            outputRoot = manifest.outputRoot
            imageSets = manifest.imageSets
        } else {
            outputRoot = "assets/mosul/runtime/sprites/rendered"
            imageSets = [:]
        }
    }

    func unitSprite(for unit: MosulUnit) -> MosulResolvedSprite? {
        let descriptor = spriteDescriptor(for: unit)
        let candidates = candidateSprites(for: descriptor)

        for candidate in candidates {
            let url = spriteURL(for: candidate)
            if fileManager.fileExists(atPath: url.path) {
                return MosulResolvedSprite(path: url.path, pixelSize: pixelSize(for: candidate.imageSet))
            }
        }

        return nil
    }

    func trafficVehicleSprite(for vehicle: MosulTrafficVehicle) -> MosulResolvedSprite? {
        let descriptor = MosulSpriteDescriptor(
            imageSet: "traffic_vehicles_1024",
            faction: "civilian",
            entity: trafficVehicleEntity(for: vehicle),
            state: "intact",
            facing: spriteFacing(forDegrees: vehicle.facingDegrees),
            side: 3
        )
        let candidates = [
            descriptor,
            descriptor.with(facing: "north"),
            descriptor.with(facing: "east")
        ].filter { containsEntity($0) }

        for candidate in candidates {
            let url = spriteURL(for: candidate)
            if fileManager.fileExists(atPath: url.path) {
                return MosulResolvedSprite(path: url.path, pixelSize: pixelSize(for: candidate.imageSet))
            }
        }

        return nil
    }

    private func candidateSprites(for descriptor: MosulSpriteDescriptor) -> [MosulSpriteDescriptor] {
        [
            descriptor,
            descriptor.with(state: "standing"),
            descriptor.with(facing: defaultFacing(for: descriptor.side)),
            descriptor.with(state: "standing", facing: defaultFacing(for: descriptor.side))
        ].filter { containsEntity($0) }
    }

    private func containsEntity(_ descriptor: MosulSpriteDescriptor) -> Bool {
        guard let imageSet = imageSets[descriptor.imageSet] else {
            return true
        }

        return imageSet.factions?[descriptor.faction]?.contains(where: { $0.id == descriptor.entity }) ?? false
    }

    private func spriteURL(for descriptor: MosulSpriteDescriptor) -> URL {
        rootURL
            .appendingPathComponent(outputRoot)
            .appendingPathComponent(descriptor.imageSet)
            .appendingPathComponent(descriptor.faction)
            .appendingPathComponent(descriptor.entity)
            .appendingPathComponent(descriptor.state)
            .appendingPathComponent("\(descriptor.facing).png")
    }

    private func pixelSize(for imageSetID: String) -> CGSize {
        guard let pixelSize = imageSets[imageSetID]?.pixelSize, pixelSize.count == 2 else {
            return CGSize(width: 128, height: 128)
        }

        return CGSize(width: pixelSize[0], height: pixelSize[1])
    }

    private func spriteDescriptor(for unit: MosulUnit) -> MosulSpriteDescriptor {
        let side = unit.side
        let imageSet = side == 3 ? "civilians_128" : "infantry_128"
        let faction = spriteFaction(for: side)
        let entity = spriteEntity(for: unit)
        let state = spriteState(for: unit)
        let facing = spriteFacing(for: unit)

        return MosulSpriteDescriptor(
            imageSet: imageSet,
            faction: faction,
            entity: entity,
            state: state,
            facing: facing,
            side: side
        )
    }

    private func spriteFaction(for side: Int32) -> String {
        switch side {
        case 1:
            return "allied"
        case 2:
            return "opposing"
        case 3:
            return "civilian"
        default:
            return "allied"
        }
    }

    private func spriteEntity(for unit: MosulUnit) -> String {
        if !unit.spriteID.isEmpty {
            return unit.spriteID
        }

        let name = unit.name.lowercased()

        switch unit.side {
        case 1:
            if name.contains("medic") {
                return "us_army_medic"
            }
            if name.contains("engineer") || name.contains("breach") {
                return "us_army_engineer_breacher"
            }
            if name.contains("leader") {
                return "us_army_squad_leader"
            }
            if name.contains("automatic") {
                return "us_army_automatic_rifleman"
            }
            if name.contains("marksman") {
                return "us_army_marksman"
            }
            if name.contains("grenadier") {
                return "us_army_grenadier"
            }
            return "us_army_rifleman"
        case 2:
            if name.contains("rooftop") || name.contains("watcher") {
                return "sniper_marksman"
            }
            if name.contains("machine") {
                return "machine_gunner"
            }
            if name.contains("rpg") {
                return "rpg_gunner"
            }
            if name.contains("scout") || name.contains("looter") {
                return "armed_looter"
            }
            if name.contains("cache") || name.contains("threat") {
                return "insurgent_cell_rifleman"
            }
            return "insurgent_cell_rifleman"
        case 3:
            if name.contains("child") {
                return "young_boy"
            }
            if name.contains("elder") {
                return "old_man"
            }
            return "adult_woman"
        default:
            return "us_army_rifleman"
        }
    }

    private func trafficVehicleEntity(for vehicle: MosulTrafficVehicle) -> String {
        if vehicle.spriteID.contains("city_bus") {
            return "traffic_city_bus"
        }
        if vehicle.spriteID.contains("motorcycle") {
            return "traffic_motorcycle"
        }
        if vehicle.spriteID.contains("civilian_car") {
            return "traffic_civilian_car"
        }

        switch vehicle.kind {
        case 1:
            return "traffic_city_bus"
        case 2:
            return "traffic_motorcycle"
        default:
            return "traffic_civilian_car"
        }
    }

    private func spriteState(for unit: MosulUnit) -> String {
        if unit.soldierCount > 0 && unit.casualtyCount >= unit.soldierCount {
            return "dead"
        }
        if unit.casualtyCount > 0 || unit.status == 3 {
            return "wounded"
        }
        if unit.side == 3 {
            return "standing"
        }

        switch unit.status {
        case 2:
            return "prone"
        case 1:
            return "crouch"
        default:
            return "standing"
        }
    }

    private func spriteFacing(for unit: MosulUnit) -> String {
        guard unit.hasTarget else {
            return defaultFacing(for: unit.side)
        }

        let dx = unit.targetX - unit.x
        let dy = unit.targetY - unit.y
        if abs(dx) < 0.01 && abs(dy) < 0.01 {
            return defaultFacing(for: unit.side)
        }

        let degrees = atan2(dy, dx) * 180.0 / .pi
        switch degrees {
        case -22.5..<22.5:
            return "east"
        case 22.5..<67.5:
            return "south_east"
        case 67.5..<112.5:
            return "south"
        case 112.5..<157.5:
            return "south_west"
        case 157.5...180, -180 ..< -157.5:
            return "west"
        case -157.5 ..< -112.5:
            return "north_west"
        case -112.5 ..< -67.5:
            return "north"
        case -67.5 ..< -22.5:
            return "north_east"
        default:
            return defaultFacing(for: unit.side)
        }
    }

    private func spriteFacing(forDegrees rawDegrees: CGFloat) -> String {
        var degrees = rawDegrees.truncatingRemainder(dividingBy: 360)
        if degrees > 180 {
            degrees -= 360
        }
        if degrees <= -180 {
            degrees += 360
        }

        switch degrees {
        case -22.5..<22.5:
            return "east"
        case 22.5..<67.5:
            return "south_east"
        case 67.5..<112.5:
            return "south"
        case 112.5..<157.5:
            return "south_west"
        case 157.5...180, -180 ..< -157.5:
            return "west"
        case -157.5 ..< -112.5:
            return "north_west"
        case -112.5 ..< -67.5:
            return "north"
        case -67.5 ..< -22.5:
            return "north_east"
        default:
            return "east"
        }
    }

    private func defaultFacing(for side: Int32) -> String {
        switch side {
        case 1:
            return "east"
        case 2:
            return "west"
        default:
            return "south"
        }
    }
}

private struct MosulSpriteDescriptor {
    let imageSet: String
    let faction: String
    let entity: String
    let state: String
    let facing: String
    let side: Int32

    func with(state: String? = nil, facing: String? = nil) -> MosulSpriteDescriptor {
        MosulSpriteDescriptor(
            imageSet: imageSet,
            faction: faction,
            entity: entity,
            state: state ?? self.state,
            facing: facing ?? self.facing,
            side: side
        )
    }
}

private struct MosulSpriteRuntimeManifest: Decodable {
    let outputRoot: String
    let imageSets: [String: MosulSpriteImageSet]

    enum CodingKeys: String, CodingKey {
        case outputRoot = "output_root"
        case imageSets = "image_sets"
    }
}

private struct MosulSpriteImageSet: Decodable {
    let pixelSize: [Int]?
    let factions: [String: [MosulSpriteEntity]]?

    enum CodingKeys: String, CodingKey {
        case pixelSize = "pixel_size"
        case factions
    }
}

private struct MosulSpriteEntity: Decodable {
    let id: String
}
