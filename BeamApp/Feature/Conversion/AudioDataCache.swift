import Foundation

actor AudioDataCache {
    static let shared = AudioDataCache()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let memoryLimitCount = 16
    private var memoryCache: [String: Data] = [:]
    private var accessOrder: [String] = []

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = base.appendingPathComponent("BeamAudioDataCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func data(for url: URL) -> Data? {
        let key = cacheKey(for: url)

        if let cached = memoryCache[key] {
            touch(key)
            print("🎧 [AudioCache] HIT(memory): \(url.absoluteString)")
            return cached
        }

        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL) else {
            print("🎧 [AudioCache] MISS: \(url.absoluteString)")
            return nil
        }

        storeInMemory(data, for: key)
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        print("🎧 [AudioCache] HIT(disk): \(url.absoluteString)")
        return data
    }

    func store(_ data: Data, for url: URL) {
        let key = cacheKey(for: url)
        storeInMemory(data, for: key)

        let fileURL = cacheDirectory.appendingPathComponent(key)
        do {
            try data.write(to: fileURL, options: .atomic)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            pruneIfNeeded()
            print("🎧 [AudioCache] STORED: \(url.absoluteString) (\(data.count) bytes)")
        } catch {
            print("🎧 [AudioCache] STORE FAILED: \(url.absoluteString) -> \(error)")
        }
    }

    private func storeInMemory(_ data: Data, for key: String) {
        memoryCache[key] = data
        touch(key)

        while accessOrder.count > memoryLimitCount {
            let oldest = accessOrder.removeFirst()
            memoryCache.removeValue(forKey: oldest)
        }
    }

    private func touch(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func cacheKey(for url: URL) -> String {
        let raw = url.absoluteString
        let encoded = Data(raw.utf8).base64EncodedString()
        return encoded
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func pruneIfNeeded(maxBytes: Int64 = 500 * 1024 * 1024) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let entries: [(url: URL, size: Int64, modified: Date)] = contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (
                url,
                Int64(values.fileSize ?? 0),
                values.contentModificationDate ?? .distantPast
            )
        }

        var total = entries.reduce(0) { $0 + $1.size }
        guard total > maxBytes else { return }

        for entry in entries.sorted(by: { $0.modified < $1.modified }) {
            if total <= maxBytes { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
