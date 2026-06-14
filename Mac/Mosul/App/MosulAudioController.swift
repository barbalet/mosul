import Foundation

struct MosulAudioSettings: Equatable {
    static let mutedDefaultsKey = "mosul.sound.muted"
    static let masterVolumeDefaultsKey = "mosul.sound.masterVolume"
    static let defaultMasterVolume = 0.55

    var muted: Bool
    var masterVolume: Double
    var disabledByLaunchArgument: Bool
}

enum MosulAudioStatus: Equatable {
    case unconfigured
    case disabledByLaunchArgument
    case silentNoManifest
    case manifestReady(assetCount: Int)
    case manifestInvalid(String)

    var description: String {
        switch self {
        case .unconfigured:
            return "Sound is waiting for runtime resources."
        case .disabledByLaunchArgument:
            return "Sound is disabled for this launch."
        case .silentNoManifest:
            return "Sound is ready, with no bundled audio manifest yet."
        case .manifestReady(let assetCount):
            if assetCount == 1 {
                return "Sound is ready with 1 manifest asset."
            }
            return "Sound is ready with \(assetCount) manifest assets."
        case .manifestInvalid(let message):
            return "Sound manifest issue: \(message)"
        }
    }
}

@MainActor
final class MosulAudioController: ObservableObject {
    @Published private(set) var settings: MosulAudioSettings
    @Published private(set) var status: MosulAudioStatus = .unconfigured

    private let userDefaults: UserDefaults
    private let launchArguments: [String]

    init(
        userDefaults: UserDefaults = .standard,
        launchArguments: [String] = CommandLine.arguments
    ) {
        self.userDefaults = userDefaults
        self.launchArguments = launchArguments

        let storedVolume = userDefaults.object(forKey: MosulAudioSettings.masterVolumeDefaultsKey) as? Double
        let volume = Self.clampedVolume(storedVolume ?? MosulAudioSettings.defaultMasterVolume)
        settings = MosulAudioSettings(
            muted: userDefaults.bool(forKey: MosulAudioSettings.mutedDefaultsKey),
            masterVolume: volume,
            disabledByLaunchArgument: launchArguments.contains(MosulApp.disableAudioArgument)
        )

        if settings.disabledByLaunchArgument {
            status = .disabledByLaunchArgument
        }
    }

    var isMuted: Bool {
        settings.disabledByLaunchArgument || settings.muted
    }

    var isSilent: Bool {
        isMuted || settings.masterVolume <= 0
    }

    var isDisabledByLaunchArgument: Bool {
        settings.disabledByLaunchArgument
    }

    var masterVolume: Double {
        settings.masterVolume
    }

    var accessibilityValue: String {
        if settings.disabledByLaunchArgument {
            return "Sound disabled for this launch"
        }
        if isMuted {
            return "Sound muted"
        }
        return "Sound on, \(Int((settings.masterVolume * 100).rounded())) percent volume"
    }

    func configure(runtimeResources: MosulRuntimeResources) {
        guard !settings.disabledByLaunchArgument else {
            status = .disabledByLaunchArgument
            return
        }

        let manifestURL = runtimeResources.runtimeAssetRootURL
            .appendingPathComponent("assets/mosul/audio/mosul_audio_manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            status = .silentNoManifest
            return
        }

        do {
            status = .manifestReady(assetCount: try Self.audioAssetCount(in: manifestURL))
        } catch {
            status = .manifestInvalid(error.localizedDescription)
        }
    }

    func toggleMuted() {
        setMuted(!settings.muted)
    }

    func setMuted(_ muted: Bool) {
        guard !settings.disabledByLaunchArgument else { return }

        settings.muted = muted
        userDefaults.set(muted, forKey: MosulAudioSettings.mutedDefaultsKey)
        stopAllIfSilent()
    }

    func setMasterVolume(_ volume: Double) {
        guard !settings.disabledByLaunchArgument else { return }

        settings.masterVolume = Self.clampedVolume(volume)
        userDefaults.set(settings.masterVolume, forKey: MosulAudioSettings.masterVolumeDefaultsKey)
        stopAllIfSilent()
    }

    func stopAll() {
        // S1 is intentionally mute-first. S3 will attach the mixer graph here.
    }

    private func stopAllIfSilent() {
        if isSilent {
            stopAll()
        }
    }

    private static func clampedVolume(_ volume: Double) -> Double {
        guard volume.isFinite else {
            return MosulAudioSettings.defaultMasterVolume
        }
        return min(1, max(0, volume))
    }

    private static func audioAssetCount(in manifestURL: URL) throws -> Int {
        let data = try Data(contentsOf: manifestURL)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let manifest = object as? [String: Any] else {
            throw MosulAudioManifestError.invalidRoot
        }
        guard let assets = manifest["assets"] as? [[String: Any]] else {
            throw MosulAudioManifestError.missingAssets
        }
        return assets.count
    }
}

private enum MosulAudioManifestError: LocalizedError {
    case invalidRoot
    case missingAssets

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "manifest root must be a JSON object"
        case .missingAssets:
            return "manifest must contain an assets array"
        }
    }
}
