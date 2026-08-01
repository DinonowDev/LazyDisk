# LazyDisk Coding Standards

Guidelines for contributors and AI-assisted development.

## File organization

| Limit | Guideline |
|-------|-----------|
| **Target** | ≤ 300 lines per `.swift` file |
| **Maximum** | 400 lines — split before exceeding |

### How to split

- **View models**: core type + `TypeName+Feature.swift` extensions (e.g. `DiskBrowserViewModel+Navigation.swift`)
- **Views**: extract subviews into `FeatureSubView.swift` files
- **Services**: one service per file; helpers in `ServiceName+Helpers.swift` if needed
- **LazyDiskCore**: pure logic only — no `AppKit`, `SwiftUI`, or `NSWorkspace`

## Naming

| Kind | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `ScanHistoryStore` |
| Methods / properties | camelCase | `performGlobalSearch()` |
| Files | Match primary type | `TreemapLayoutEngine.swift` |
| UI extensions | `Model+UI.swift` | `ContentFilter+UI.swift` |
| View-model extensions | `ViewModel+Area.swift` | `DiskBrowserViewModel+Collector.swift` |

## Access control

When splitting a type across files, `private` members are **not** visible to extensions in other files. Use `internal` (default) for members shared across extension files; keep `private` only for file-local helpers.

## Comments

```swift
// MARK: - Navigation

/// Navigates to `url`, cancelling any in-flight folder scan.
func navigate(to url: URL) { ... }
```

- File header (optional): `// DiskBrowserViewModel+Scanning.swift — volume and folder scan orchestration`
- Prefer `// MARK: -` sections over long comment blocks
- Document non-obvious behavior, not obvious syntax

## Concurrency

- Mark UI types `@MainActor`
- Store `Task` handles and call `.cancel()` before starting replacement work
- Use `navigationGeneration` (or similar) to ignore stale async results

## Testing

- Testable logic belongs in `LazyDiskCore`
- Run `swift test` after refactors
- Do not add tests that only assert trivial getters

## Commit messages

```
feat: add treemap drill-down
fix: correct Spotlight fallback when index is stale
refactor: split DiskBrowserViewModel into extensions
docs: update coding standards
```
