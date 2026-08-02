import Foundation
import SwiftUI

enum L10n {
    static var language: AppLanguage { AppPreferences.load().language }

    static var effective: AppLanguage {
        let pref = AppPreferences.load().language
        return pref == .system ? AppLanguage.fromSystemLocale() : pref
    }

    static var isRTL: Bool {
        switch effective {
        case .persian, .arabic: return true
        default: return false
        }
    }

    private static func t(_ key: StringKey) -> String {
        LocalizationCatalog.text(key, language: effective)
    }

    static func text(_ key: StringKey) -> String { t(key) }

    // Collector
    static var collectorTitle: String { t(.collectorTitle) }
    static var collectorEmpty: String { t(.collectorEmpty) }
    static var collectorFree: String { t(.collectorFree) }
    static var collectorClear: String { t(.collectorClear) }
    static var collectorDelete: String { t(.collectorDelete) }
    static var addToCollector: String { t(.addToCollector) }
    static var collectorExpand: String { t(.collectorExpand) }
    static var collectorCollapse: String { t(.collectorCollapse) }
    static var collectorMinimize: String { t(.collectorMinimize) }
    static var collectorRestore: String { t(.collectorRestore) }
    static var collectorAfterDelete: String { t(.collectorAfterDelete) }
    static var collectorPercent: String { t(.collectorPercent) }

    // Search
    static var searchPlaceholder: String { t(.searchPlaceholder) }
    static var searchPlaceholderVolume: String { t(.searchPlaceholderVolume) }
    static var searchFilterScope: String { t(.searchFilterScope) }
    static var searchFilterCollapse: String { t(.searchFilterCollapse) }
    static var filterAll: String { t(.filterAll) }
    static var filterFolders: String { t(.filterFolders) }
    static var filterImages: String { t(.filterImages) }
    static var filterVideos: String { t(.filterVideos) }
    static var filterAudio: String { t(.filterAudio) }
    static var filterDocuments: String { t(.filterDocuments) }
    static var filterArchives: String { t(.filterArchives) }
    static var filterApps: String { t(.filterApps) }
    static var filterDeveloper: String { t(.filterDeveloper) }
    static var filterOther: String { t(.filterOther) }
    static var noSearchResults: String { t(.noSearchResults) }

    // Sort
    static var sortSizeDesc: String { t(.sortSizeDesc) }
    static var sortSizeAsc: String { t(.sortSizeAsc) }
    static var sortNameAsc: String { t(.sortNameAsc) }
    static var sortNameDesc: String { t(.sortNameDesc) }
    static var sortDateDesc: String { t(.sortDateDesc) }
    static var sortDateAsc: String { t(.sortDateAsc) }
    static var sortKind: String { t(.sortKind) }

    // Storage
    static var langSystem: String { t(.langSystem) }
    static var purgeableSpace: String { t(.purgeableSpace) }
    static var iCloudPlaceholder: String { t(.iCloudPlaceholder) }
    static var snapshotsReserved: String { t(.snapshotsReserved) }
    static var storageBreakdown: String { t(.storageBreakdown) }
    static var storageUsed: String { t(.storageUsed) }
    static var storageFree: String { t(.storageFree) }

    // Delete
    static var deleteTitle: String { t(.deleteTitle) }
    static func deleteSubtitle(count: Int, size: String) -> String { "\(count) · \(size)" }
    static var deleteSafeMessage: String { t(.deleteSafeMessage) }
    static var deleteItemsHeader: String { t(.deleteItemsHeader) }
    static var cancel: String { t(.cancel) }
    static var deleteAction: String { t(.deleteAction) }

    // Hints
    static var hintSpace: String { t(.hintSpace) }
    static var hintEnter: String { t(.hintEnter) }
    static var hintBackspace: String { t(.hintBackspace) }
    static var hintShiftSelect: String { t(.hintShiftSelect) }

    // Preferences
    static var preferences: String { t(.preferences) }
    static var prefGeneral: String { t(.prefGeneral) }
    static var prefCache: String { t(.prefCache) }
    static var prefHidden: String { t(.prefHidden) }
    static var prefLanguage: String { t(.prefLanguage) }
    static var prefScanParallel: String { t(.prefScanParallel) }
    static var prefScanParallelHelp: String { t(.prefScanParallelHelp) }

    // Global search
    static var searchScopeFolder: String { t(.searchScopeFolder) }
    static var searchScopeVolume: String { t(.searchScopeVolume) }
    static var searchIndexing: String { t(.searchIndexing) }
    static var searchSearching: String { t(.searchSearching) }
    static var searchResults: String { t(.searchResults) }
    static var searchNoResults: String { t(.searchNoResults) }
    static var searchIndexReady: String { t(.searchIndexReady) }
    static func searchResultCount(_ count: Int) -> String {
        String(format: t(.results), count)
    }
    static func searchIndexCount(_ count: Int) -> String {
        String(format: t(.filesIndexed), count)
    }
    static var searchGoToFolder: String { t(.searchGoToFolder) }
    static var searchEngineSpotlight: String { t(.searchEngineSpotlight) }
    static var searchEngineIndex: String { t(.searchEngineIndex) }
    static var searchEngineLive: String { t(.searchEngineLive) }
    static var rebuildSearchIndex: String { t(.rebuildSearchIndex) }

    // Columns
    static var columnModified: String { t(.columnModified) }
    static var columnKind: String { t(.columnKind) }
    static var columnSize: String { t(.columnSize) }
    static var columnName: String { t(.columnName) }
    static var scanFromCache: String { t(.scanFromCache) }
    static var scanLive: String { t(.scanLive) }

    // Panels
    static var panelBrowser: String { t(.panelBrowser) }
    static var panelCleanup: String { t(.panelCleanup) }
    static var panelDuplicates: String { t(.panelDuplicates) }
    static var panelHistory: String { t(.panelHistory) }
    static var panelDev: String { t(.panelDev) }
    static var panelGoal: String { t(.panelGoal) }

    // Cleanup
    static var cleanupTitle: String { t(.cleanupTitle) }
    static var cleanupEmpty: String { t(.cleanupEmpty) }
    static var cleanupEmptyDesc: String { t(.cleanupEmptyDesc) }
    static var cleanupAddAll: String { t(.cleanupAddAll) }
    static var cleanupScan: String { t(.cleanupScan) }
    static var cleanupSortScore: String { t(.cleanupSortScore) }
    static var cleanupBreakdown: String { t(.cleanupBreakdown) }
    static func cleanupCategoryCount(_ count: Int) -> String { String(format: t(.cleanupCategoryCount), count) }
    static func cleanupSummarySubtitle(items: Int, size: String) -> String {
        String(format: t(.cleanupSummarySubtitle), items, size)
    }

    // Duplicates
    static var dupTitle: String { t(.dupTitle) }
    static var dupScan: String { t(.dupScan) }
    static var dupEmpty: String { t(.dupEmpty) }
    static var dupKeep: String { t(.dupKeep) }
    static var dupDelete: String { t(.dupDelete) }

    // History
    static var historyTitle: String { t(.historyTitle) }
    static var historyEmpty: String { t(.historyEmpty) }
    static var historyDiff: String { t(.historyDiff) }
    static var historySaved: String { t(.historySaved) }
    static var historyEmptyDesc: String { t(.historyEmptyDesc) }
    static func historySnapshotsCount(_ count: Int) -> String { String(format: t(.historySnapshotsCount), count) }
    static var historyCompareCurrent: String { t(.historyCompareCurrent) }
    static var historyComparePrevious: String { t(.historyComparePrevious) }
    static var historyNetDelta: String { t(.historyNetDelta) }
    static func historyPathsChanged(_ count: Int) -> String { String(format: t(.historyPathsChanged), count) }
    static var historyRootWarning: String { t(.historyRootWarning) }
    static var historyDeleteSnapshot: String { t(.historyDeleteSnapshot) }
    static var historyRescan: String { t(.historyRescan) }
    static var historyTopItems: String { t(.historyTopItems) }
    static var historyTimeline: String { t(.historyTimeline) }
    static var historyDetails: String { t(.historyDetails) }
    static var historySearchPlaceholder: String { t(.historySearchPlaceholder) }
    static var historyFilterAll: String { t(.historyFilterAll) }
    static var historyNoChanges: String { t(.historyNoChanges) }
    static var historySincePrevious: String { t(.historySincePrevious) }
    static var historyTrackedSize: String { t(.historyTrackedSize) }
    static var historyUsageTrend: String { t(.historyUsageTrend) }
    static var historyOpenPath: String { t(.historyOpenPath) }
    static var historyChangesTitle: String { t(.historyChangesTitle) }
    static var historySnapshotDetail: String { t(.historySnapshotDetail) }

    // Dev
    static var devTitle: String { t(.devTitle) }
    static var devScan: String { t(.devScan) }
    static var devEmpty: String { t(.devEmpty) }
    static var devEmptyDesc: String { t(.devEmptyDesc) }
    static var devReclaimable: String { t(.devReclaimable) }
    static var devItemsLabel: String { t(.devItemsLabel) }
    static var devProjectsLabel: String { t(.devProjectsLabel) }
    static var devGlobalLabel: String { t(.devGlobalLabel) }
    static var devFilterAll: String { t(.devFilterAll) }
    static var devGroupByProject: String { t(.devGroupByProject) }
    static var devGroupByType: String { t(.devGroupByType) }
    static var devGlobalCaches: String { t(.devGlobalCaches) }
    static var devGlobalCachesDesc: String { t(.devGlobalCachesDesc) }

    static func devSummarySubtitle(items: Int, projects: Int, size: String) -> String {
        String(format: t(.devSummarySubtitle), items, projects, size)
    }

    static func devItemsCount(_ count: Int) -> String {
        String(format: t(.devItemsCount), count)
    }

    static func devModifiedFmt(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .none
        return String(format: t(.devModifiedFmt), fmt.string(from: date))
    }

    static func devEcoName(_ eco: DevJunkEcosystem) -> String {
        switch eco {
        case .javascript: return t(.devEcoJavaScript)
        case .typescript: return t(.devEcoTypeScript)
        case .python: return t(.devEcoPython)
        case .rust: return t(.devEcoRust)
        case .go: return t(.devEcoGo)
        case .swift: return t(.devEcoSwift)
        case .java: return t(.devEcoJava)
        case .kotlin: return t(.devEcoKotlin)
        case .ruby: return t(.devEcoRuby)
        case .php: return t(.devEcoPHP)
        case .dart: return t(.devEcoDart)
        case .docker: return t(.devEcoDocker)
        case .homebrew: return t(.devEcoHomebrew)
        case .ios: return t(.devEcoIOS)
        case .android: return t(.devEcoAndroid)
        case .web: return t(.devEcoWeb)
        case .csharp: return t(.devEcoCSharp)
        case .general: return t(.devEcoGeneral)
        }
    }

    static func devPurposeName(_ purpose: DevJunkPurpose) -> String {
        switch purpose {
        case .dependencies: return t(.devPurposeDependencies)
        case .buildOutput: return t(.devPurposeBuildOutput)
        case .buildCache: return t(.devPurposeBuildCache)
        case .devServerCache: return t(.devPurposeDevServer)
        case .testCache: return t(.devPurposeTestCache)
        case .languageCache: return t(.devPurposeLangCache)
        case .packageManager: return t(.devPurposePackageManager)
        case .runtimeData: return t(.devPurposeRuntime)
        case .tooling: return t(.devPurposeTooling)
        }
    }

    static func devPurposeDesc(_ purpose: DevJunkPurpose) -> String {
        switch purpose {
        case .dependencies: return t(.devPurposeDescDependencies)
        case .buildOutput: return t(.devPurposeDescBuildOutput)
        case .buildCache: return t(.devPurposeDescBuildCache)
        case .devServerCache: return t(.devPurposeDescDevServer)
        case .testCache: return t(.devPurposeDescTestCache)
        case .languageCache: return t(.devPurposeDescLangCache)
        case .packageManager: return t(.devPurposeDescPackageManager)
        case .runtimeData: return t(.devPurposeDescRuntime)
        case .tooling: return t(.devPurposeDescTooling)
        }
    }

    static func devSafetyName(_ safety: DevJunkSafety) -> String {
        switch safety {
        case .safe: return t(.devSafetySafe)
        case .rebuild: return t(.devSafetyRebuild)
        case .caution: return t(.devSafetyCaution)
        }
    }

    static func devFolderDesc(_ kind: DevJunkFolderKind) -> String {
        switch kind {
        case .nodeModules: return t(.devDescNodeModules)
        case .swiftBuild: return t(.devDescSwiftBuild)
        case .pycache: return t(.devDescPycache)
        case .venv: return t(.devDescVenv)
        case .next: return t(.devDescNext)
        case .turbo: return t(.devDescTurbo)
        case .pods: return t(.devDescPods)
        case .carthage: return t(.devDescCarthage)
        case .gradle: return t(.devDescGradle)
        case .rustTarget: return t(.devDescRustTarget)
        case .dist: return t(.devDescDist)
        case .build: return t(.devDescBuild)
        case .pytestCache: return t(.devDescPytestCache)
        case .mypyCache: return t(.devDescMypyCache)
        case .tox: return t(.devDescTox)
        case .cargoRegistry: return t(.devDescCargoRegistry)
        case .vendor: return t(.devDescVendor)
        case .bowerComponents: return t(.devDescBowerComponents)
        case .parcelCache: return t(.devDescParcelCache)
        case .nuxt: return t(.devDescNuxt)
        case .output: return t(.devDescOutput)
        case .cmakeDebug: return t(.devDescCmakeDebug)
        case .cmakeRelease: return t(.devDescCmakeRelease)
        case .swiftpm: return t(.devDescSwiftpm)
        case .packageResolved: return t(.devDescPackageResolved)
        case .goPkgMod: return t(.devDescGoPkgMod)
        case .homebrewCache: return t(.devDescHomebrewCache)
        case .dockerData: return t(.devDescDockerData)
        case .gradleGlobal: return t(.devDescGradleGlobal)
        case .cargoDir: return t(.devDescCargoDir)
        case .generic: return t(.devDescGeneric)
        }
    }

    static var devInCollector: String { t(.devInCollector) }

    static func devCollectorCount(_ count: Int) -> String {
        String(format: t(.devCollectorCount), count)
    }

    static var devSelectedTitle: String { t(.devSelectedTitle) }

    static func devSortTitle(_ order: DevJunkSortOrder) -> String {
        switch order {
        case .sizeDescending: return t(.sortSizeDesc)
        case .sizeAscending: return t(.sortSizeAsc)
        case .nameAscending: return t(.sortNameAsc)
        case .nameDescending: return t(.sortNameDesc)
        case .dateDescending: return t(.sortDateDesc)
        case .dateAscending: return t(.sortDateAsc)
        case .projectAscending: return t(.devSortProjectAsc)
        case .projectDescending: return t(.devSortProjectDesc)
        case .ecosystemAscending: return t(.devSortEcoAsc)
        case .purposeAscending: return t(.devSortPurposeAsc)
        }
    }

    // Goal
    static var goalTitle: String { t(.goalTitle) }
    static var goalTarget: String { t(.goalTarget) }
    static var goalSuggest: String { t(.goalSuggest) }
    static var goalProgress: String { t(.goalProgress) }
    static var goalScanning: String { t(.goalScanning) }
    static var goalAddAll: String { t(.goalAddAll) }
    static var goalSelectedTitle: String { t(.goalSelectedTitle) }
    static var goalProjectedFree: String { t(.goalProjectedFree) }
    static func goalSuggestionsTotal(_ size: String) -> String { String(format: t(.goalSuggestionsTotal), size) }
    static var goalScanHint: String { t(.goalScanHint) }
    static var goalSuggestionsTitle: String { t(.goalSuggestionsTitle) }
    static func goalDaysUnused(_ days: Int) -> String { String(format: t(.goalDaysUnused), days) }
    static var goalCategoryCache: String { t(.goalCategoryCache) }
    static var goalCategoryLogs: String { t(.goalCategoryLogs) }
    static var goalCategoryTrash: String { t(.goalCategoryTrash) }
    static var goalCategoryInstallers: String { t(.goalCategoryInstallers) }
    static var goalCategoryOldDownloads: String { t(.goalCategoryOldDownloads) }
    static var goalCategoryLargeDownloads: String { t(.goalCategoryLargeDownloads) }
    static var goalCategoryOldFiles: String { t(.goalCategoryOldFiles) }
    static var goalCategoryDevJunk: String { t(.goalCategoryDevJunk) }
    static var goalCategoryOther: String { t(.goalCategoryOther) }
    static var goalPriorityHigh: String { t(.goalPriorityHigh) }
    static var goalPriorityMedium: String { t(.goalPriorityMedium) }
    static var goalPriorityLow: String { t(.goalPriorityLow) }
    static func goalCollectorQueued(_ count: Int) -> String { String(format: t(.goalCollectorQueued), count) }
    static var goalWithCollector: String { t(.goalWithCollector) }
    static var goalStillNeed: String { t(.goalStillNeed) }

    static func goalCategoryTitle(_ category: GoalSuggestionCategory) -> String {
        switch category {
        case .cache: return goalCategoryCache
        case .logs: return goalCategoryLogs
        case .trash: return goalCategoryTrash
        case .installers: return goalCategoryInstallers
        case .oldDownloads: return goalCategoryOldDownloads
        case .largeDownloads: return goalCategoryLargeDownloads
        case .oldFiles: return goalCategoryOldFiles
        case .devJunk: return goalCategoryDevJunk
        case .other: return goalCategoryOther
        }
    }

    // Export
    static var exportCSV: String { t(.exportCSV) }
    static var exportJSON: String { t(.exportJSON) }
    static var exportDone: String { t(.exportDone) }

    // Nav
    static var recentFolders: String { t(.recentFolders) }
    static var bookmarks: String { t(.bookmarks) }
    static var addBookmark: String { t(.addBookmark) }
    static var removeBookmark: String { t(.removeBookmark) }

    // Menu bar
    static var menuBarFree: String { t(.menuBarFree) }
    static var menuBarUsed: String { t(.menuBarUsed) }
    static var menuBarOpen: String { t(.menuBarOpen) }

    // Common
    static var open: String { t(.open) }
    static var revealFinder: String { t(.revealFinder) }
    static var quickLook: String { t(.quickLook) }
    static var rescan: String { t(.rescan) }
    static var refresh: String { t(.refresh) }
    static var permissions: String { t(.permissions) }
    static var permissionsOK: String { t(.permissionsOK) }
    static var scanning: String { t(.scanning) }
    static var analyzing: String { t(.analyzing) }
    static var welcomeTitle: String { t(.welcomeTitle) }
    static var welcomeSubtitle: String { t(.welcomeSubtitle) }
    static var startScan: String { t(.startScan) }
    static var grantPermissions: String { t(.grantPermissions) }

    // Extended
    static var welcomeTagline: String { t(.welcomeTagline) }
    static var modeSelectTitle: String { t(.modeSelectTitle) }
    static var modeSimple: String { t(.modeSimple) }
    static var modeSimpleDesc: String { t(.modeSimpleDesc) }
    static var modeProfessional: String { t(.modeProfessional) }
    static var modeProfessionalDesc: String { t(.modeProfessionalDesc) }
    static var prefInterfaceMode: String { t(.prefInterfaceMode) }
    static var simpleChartScanning: String { t(.simpleChartScanning) }
    static func simpleChartScanProgress(_ completed: Int, _ total: Int) -> String {
        String(format: t(.simpleChartScanProgress), completed, total)
    }
    static func simpleChartScanRemaining(_ count: Int) -> String {
        String(format: t(.simpleChartScanRemaining), count)
    }
    static func simpleChartScanCurrent(_ name: String) -> String {
        String(format: t(.simpleChartScanCurrent), name)
    }
    static func simpleChartScanRing(_ current: Int, _ total: Int) -> String {
        String(format: t(.simpleChartScanRing), current, total)
    }
    static func simpleChartScanFiles(_ count: Int) -> String {
        String(format: t(.simpleChartScanFiles), count)
    }
    static var selectVolume: String { t(.selectVolume) }
    static var totalCapacity: String { t(.totalCapacity) }
    static var availableLabel: String { t(.availableLabel) }
    static var continueBtn: String { t(.continueBtn) }
    static var scanTakeTime: String { t(.scanTakeTime) }
    static var permAllSet: String { t(.permAllSet) }
    static var permRequired: String { t(.permRequired) }
    static var permAllSetDesc: String { t(.permAllSetDesc) }
    static var permRequiredDesc: String { t(.permRequiredDesc) }
    static var permReadyScan: String { t(.permReadyScan) }
    static func permGrantedCount(_ granted: Int, _ total: Int) -> String {
        String(format: t(.permGrantedCount), granted, total)
    }
    static var permTerminalTitle: String { t(.permTerminalTitle) }
    static var permTerminalHint: String { t(.permTerminalHint) }
    static var back: String { t(.back) }
    static var openSettings: String { t(.openSettings) }
    static var scanAnyway: String { t(.scanAnyway) }
    static var grantAllPerms: String { t(.grantAllPerms) }
    static var prefScanning: String { t(.prefScanning) }
    static var prefDisplay: String { t(.prefDisplay) }
    static var prefDefaultSort: String { t(.prefDefaultSort) }
    static var done: String { t(.done) }
    static var ok: String { t(.ok) }
    static var errorTitle: String { t(.errorTitle) }
    static var emptyFolder: String { t(.emptyFolder) }
    static var diskLabel: String { t(.diskLabel) }
    static var folderLabel: String { t(.folderLabel) }
    static var volumeLabel: String { t(.volumeLabel) }
    static var goUp: String { t(.goUp) }
    static var selectAll: String { t(.selectAll) }
    static var menuNavigate: String { t(.menuNavigate) }
    static var menuSortBy: String { t(.menuSortBy) }
    static var menuFile: String { t(.menuFile) }
    static var goalReached: String { t(.goalReached) }
    static func goalNeedMore(_ size: String) -> String { String(format: t(.goalNeedMore), size) }
    static func dupWaste(_ size: String) -> String { String(format: t(.dupWaste), size) }
    static func dupCopiesCount(_ count: Int) -> String { String(format: t(.dupCopiesCount), count) }
    static var hiddenLabel: String { t(.hiddenLabel) }
    static func itemsSelected(_ count: Int) -> String { String(format: t(.itemsSelected), count) }
    static func hintSidebar(_ spaceHint: String) -> String { String(format: t(.hintSidebar), spaceHint) }
    static var permFullDiskTitle: String { t(.permFullDiskTitle) }
    static var permFullDiskDesc: String { t(.permFullDiskDesc) }
    static var permUserFilesTitle: String { t(.permUserFilesTitle) }
    static var permUserFilesDesc: String { t(.permUserFilesDesc) }
    static var permRemovableTitle: String { t(.permRemovableTitle) }
    static var permRemovableDesc: String { t(.permRemovableDesc) }
    static var permCleanupTitle: String { t(.permCleanupTitle) }
    static var permCleanupDesc: String { t(.permCleanupDesc) }
    static var dupPhaseCollect: String { t(.dupPhaseCollect) }
    static var dupPhaseHash: String { t(.dupPhaseHash) }
    static var historyAdded: String { t(.historyAdded) }
    static var historyRemoved: String { t(.historyRemoved) }
    static var historyChanged: String { t(.historyChanged) }
    static var menuBarTotal: String { t(.menuBarTotal) }
    static func menuBarPercent(_ percent: Int) -> String { String(format: t(.menuBarPercent), percent) }
    static func errorDeleteFailed(_ msg: String) -> String { String(format: t(.errorDeleteFailed), msg) }
    static var errorCannotDelete: String { t(.errorCannotDelete) }
    static var errorCannotDeleteLibraryContainer: String { t(.errorCannotDeleteLibraryContainer) }
    static func suggestionsCount(_ count: Int) -> String { String(format: t(.suggestionsCount), count) }
    static func scanProgressFmt(_ current: Int, _ total: Int) -> String { String(format: t(.scanProgressFmt), current, total) }
    static var itemsLabel: String { t(.items) }
    static var scanningDiskTitle: String { t(.scanningDiskTitle) }
    static var scanPreparing: String { t(.scanPreparing) }
    static var scanReadingList: String { t(.scanReadingList) }
    static func scanFoundItems(_ count: Int) -> String { String(format: t(.scanFoundItems), count) }
    static func scanFolderNamed(_ name: String) -> String { String(format: t(.scanFolderNamed), name) }
    static func scanFoldersProgress(_ done: Int, _ total: Int) -> String { String(format: t(.scanFoldersProgress), done, total) }
    static var scanFinalizing: String { t(.scanFinalizing) }
    static var scanCaching: String { t(.scanCaching) }
    static func scanCachingFolders(_ done: Int, _ total: Int) -> String { String(format: t(.scanCachingFolders), done, total) }
    static func percentFmt(_ percent: Int) -> String { String(format: t(.percentFmt), percent) }
    static func progressStepFmt(_ step: Int, _ total: Int) -> String { String(format: t(.progressStepFmt), step, total) }
    static var donateTitle: String { t(.donateTitle) }
    static var donateSubtitle: String { t(.donateSubtitle) }
    static var donateThankYou: String { t(.donateThankYou) }
    static var donateCopy: String { t(.donateCopy) }
    static var donateCopied: String { t(.donateCopied) }
    static var donateAllNetworks: String { t(.donateAllNetworks) }
    static var donateSupport: String { t(.donateSupport) }
    static var menuDonate: String { t(.menuDonate) }

    // Chart & overview
    static var chartNoData: String { t(.chartNoData) }
    static func itemsCount(_ count: Int) -> String { String(format: t(.itemsCount), count) }
    static func dupGroupsCount(_ count: Int) -> String { String(format: t(.dupGroupsCount), count) }
    static func devFoldersCount(_ count: Int) -> String { String(format: t(.devFoldersCount), count) }
    static var removeFromCollector: String { t(.removeFromCollector) }
    static var overviewVolume: String { t(.overviewVolume) }
    static var overviewUsed: String { t(.overviewUsed) }
    static var overviewAvailable: String { t(.overviewAvailable) }
    static var overviewCurrentFolder: String { t(.overviewCurrentFolder) }
    static func overviewOfSize(_ size: String) -> String { String(format: t(.overviewOfSize), size) }

    // Delete warnings
    static var warnIOSBackupTitle: String { t(.warnIOSBackupTitle) }
    static var warnIOSBackupMsg: String { t(.warnIOSBackupMsg) }
    static var warnTimeMachineTitle: String { t(.warnTimeMachineTitle) }
    static var warnTimeMachineMsg: String { t(.warnTimeMachineMsg) }
    static var warnSystemTitle: String { t(.warnSystemTitle) }
    static var warnSystemMsg: String { t(.warnSystemMsg) }
    static var warnRunningAppTitle: String { t(.warnRunningAppTitle) }
    static var warnRunningAppMsg: String { t(.warnRunningAppMsg) }
    static var warnLibraryTitle: String { t(.warnLibraryTitle) }
    static var warnLibraryMsg: String { t(.warnLibraryMsg) }
    static var warnBulkDeleteTitle: String { t(.warnBulkDeleteTitle) }
    static func warnBulkDeleteMsg(_ count: Int) -> String { String(format: t(.warnBulkDeleteMsg), count) }
    static func deleteSummary(count: Int, size: String) -> String {
        count == 1
            ? String(format: t(.deleteSummaryOne), size)
            : String(format: t(.deleteSummaryMany), count, size)
    }

    static var chartStyleRose: String { t(.chartStyleRose) }
    static var chartStyleSunburst: String { t(.chartStyleSunburst) }
    static var chartStyleTreemap: String { t(.chartStyleTreemap) }
    static var chartUsedLabel: String { t(.chartUsedLabel) }
    static var chartHintDrillDown: String { t(.chartHintDrillDown) }
    static var chartHintSelect: String { t(.chartHintSelect) }
    static var prefChartStyle: String { t(.prefChartStyle) }

    static var collectionTitle: String { t(.collectionTitle) }
    static var collectionLargeFiles: String { t(.collectionLargeFiles) }
    static var collectionLargeFilesDesc: String { t(.collectionLargeFilesDesc) }
    static var collectionOldFiles: String { t(.collectionOldFiles) }
    static var collectionOldFilesDesc: String { t(.collectionOldFilesDesc) }
    static var collectionXcode: String { t(.collectionXcode) }
    static var collectionXcodeDesc: String { t(.collectionXcodeDesc) }
    static var collectionNodeModules: String { t(.collectionNodeModules) }
    static var collectionNodeModulesDesc: String { t(.collectionNodeModulesDesc) }
    static var collectionOldDownloads: String { t(.collectionOldDownloads) }
    static var collectionOldDownloadsDesc: String { t(.collectionOldDownloadsDesc) }
    static var collectionScanning: String { t(.collectionScanning) }
    static var collectionActive: String { t(.collectionActive) }

    static var detailTitle: String { t(.detailTitle) }
    static var detailPath: String { t(.detailPath) }
    static var detailCreated: String { t(.detailCreated) }
    static var detailItemCount: String { t(.detailItemCount) }
    static var detailOpenFolder: String { t(.detailOpenFolder) }
    static var detailShowLargeFiles: String { t(.detailShowLargeFiles) }
    static var detailShowDetails: String { t(.detailShowDetails) }

    static var cleanupCollectionsHint: String { t(.cleanupCollectionsHint) }
    static var devCollectionsHint: String { t(.devCollectionsHint) }

    static var finderAnalyzeVolumeNotFound: String { t(.finderAnalyzeVolumeNotFound) }
    static var finderAnalyzeHelp: String { t(.finderAnalyzeHelp) }

    static var menuAbout: String { t(.menuAbout) }
    static var aboutTagline: String { t(.aboutTagline) }
    static var aboutVersion: String { t(.aboutVersion) }
    static var aboutDeveloper: String { t(.aboutDeveloper) }
    static var aboutCopyright: String { t(.aboutCopyright) }
    static var aboutLicense: String { t(.aboutLicense) }
    static var aboutGitHub: String { t(.aboutGitHub) }
}

struct RTLLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.layoutDirection, L10n.isRTL ? .rightToLeft : .leftToRight)
    }
}

extension View {
    func applyRTLLayout() -> some View {
        modifier(RTLLayoutModifier())
    }

    @ViewBuilder
    func secondaryLabelStyle() -> some View {
        if L10n.isRTL {
            self
        } else {
            self.textCase(.uppercase)
        }
    }
}
