import Foundation

public enum ChartPrefetchPlanner {
    public struct Candidate: Sendable {
        public let item: DiskItem
        public let priority: Int

        public init(item: DiskItem, priority: Int) {
            self.item = item
            self.priority = priority
        }
    }

    public static func plan(
        chartMap: [String: [DiskItem]],
        chartParents: [DiskItem],
        siblings: [DiskItem],
        maxCount: Int = 48
    ) -> [DiskItem] {
        var seen = Set<String>()
        var candidates: [Candidate] = []

        func append(_ item: DiskItem, priority: Int) {
            guard item.isDirectory, !item.isVirtual else { return }
            let path = PathUtils.resolved(item.url).path
            guard seen.insert(path).inserted else { return }
            candidates.append(Candidate(item: item, priority: priority))
        }

        for children in chartMap.values {
            for child in children {
                append(child, priority: 0)
            }
        }

        for parent in chartParents {
            append(parent, priority: 1)
        }

        for item in siblings.sorted(by: { $0.size > $1.size }) {
            append(item, priority: 2)
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.item.size > rhs.item.size
            }
            .prefix(maxCount)
            .map(\.item)
    }
}
