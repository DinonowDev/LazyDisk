import Foundation

enum CollectorService {
    static func contains(_ items: [DiskItem], url: URL) -> Bool {
        let key = PathUtils.resolved(url).path
        return items.contains { PathUtils.resolved($0.url).path == key }
    }

    static func merge(_ items: [DiskItem], adding item: DiskItem) -> [DiskItem] {
        guard !item.isVirtual else { return items }
        guard !contains(items, url: item.url) else { return items }
        return items + [item]
    }

    static func totalSize(of items: [DiskItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    static func freePercent(size: Int64, of volumeUsed: Int64) -> Double {
        guard volumeUsed > 0 else { return 0 }
        return Double(size) / Double(volumeUsed) * 100
    }
}
