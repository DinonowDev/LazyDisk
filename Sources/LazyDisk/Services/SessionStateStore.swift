import Foundation

struct SessionState: Codable, Sendable {
    var lastVolumeID: String?
    var lastPath: String?
}

enum SessionStateStore {
    private static let key = "LazyDisk.sessionState"

    static func load() -> SessionState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return SessionState()
        }
        return decoded
    }

    static func save(volumeID: String?, path: URL?) {
        let state = SessionState(
            lastVolumeID: volumeID,
            lastPath: path.map { PathUtils.resolved($0).path }
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
