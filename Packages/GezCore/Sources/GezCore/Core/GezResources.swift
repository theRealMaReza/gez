import Foundation

/// Resolves data files (`*.json`, `*.idmap`) for `GezCore`.
///
/// Front-ends that do not run as a SwiftPM bundle (such as the Godot
/// GDExtension) can set `GezResources.dataDirectory` before loading the
/// scenario; when `nil`, lookups fall back to `Bundle.module`.
public enum GezResources {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _dataDirectory: URL?

    /// Optional directory containing the scenario JSON and `.idmap` files.
    /// When set, `url(forResource:withExtension:)` checks this directory first
    /// and falls back to `Bundle.module` if the file is not present there.
    public static var dataDirectory: URL? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _dataDirectory
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _dataDirectory = newValue
        }
    }

    public static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let dir = dataDirectory {
            let candidate = dir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }
}
