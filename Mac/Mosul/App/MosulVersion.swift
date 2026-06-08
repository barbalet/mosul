enum MosulVersion {
    static let shortVersion = "0.1"
    static let build = "1"
    static let tagPrefix = "v"

    static var tagName: String {
        "\(tagPrefix)\(shortVersion)"
    }

    static var displayName: String {
        "MosulGame \(shortVersion)"
    }
}
