import Foundation

public enum StringKey: String, CaseIterable {
    case collectorTitle, collectorEmpty, collectorFree, collectorClear, collectorDelete, addToCollector
    case collectorExpand, collectorCollapse, collectorMinimize, collectorRestore, collectorAfterDelete, collectorPercent
    case searchPlaceholder, searchPlaceholderVolume, searchFilterScope, searchFilterCollapse, filterAll, filterFolders, filterImages
    case filterVideos, filterAudio, filterDocuments, filterArchives, filterApps, filterDeveloper, filterOther
    case noSearchResults, sortSizeDesc, sortSizeAsc, sortNameAsc, sortNameDesc, sortDateDesc, sortDateAsc, sortKind
    case langSystem, purgeableSpace, iCloudPlaceholder, snapshotsReserved
    case storageBreakdown, storageUsed, storageFree, deleteTitle, deleteSafeMessage, deleteItemsHeader
    case cancel, deleteAction, hintSpace, hintEnter, hintBackspace, hintShiftSelect
    case preferences, prefGeneral, prefCache, prefHidden, prefLanguage, prefScanParallel, prefScanParallelHelp
    case searchScopeFolder, searchScopeVolume, searchIndexing, searchSearching, searchResults, searchNoResults
    case searchIndexReady, searchGoToFolder, searchEngineSpotlight, searchEngineIndex, searchEngineLive, rebuildSearchIndex
    case columnModified, columnKind, columnSize, columnName, scanFromCache, scanLive
    case panelBrowser, panelCleanup, panelDuplicates, panelHistory, panelDev, panelGoal
    case cleanupTitle, cleanupEmpty, cleanupEmptyDesc, cleanupAddAll, cleanupScan, cleanupSortScore
    case cleanupBreakdown, cleanupCategoryCount, cleanupSummarySubtitle
    case dupTitle, dupScan, dupEmpty, dupKeep, dupDelete
    case historyTitle, historyEmpty, historyDiff, historyGrowth, historySaved
    case historyEmptyDesc, historySnapshotsCount, historyCompareCurrent, historyComparePrevious
    case historyNetDelta, historyPathsChanged, historyRootWarning, historyDeleteSnapshot
    case historyRescan, historyTopItems, historyTimeline, historyDetails, historySearchPlaceholder
    case historyFilterAll, historyNoChanges, historySincePrevious, historyTrackedSize, historyUsageTrend
    case historyOpenPath, historyChangesTitle, historySnapshotDetail
    case devTitle, devScan, devEmpty, devEmptyDesc, devReclaimable
    case devItemsLabel, devProjectsLabel, devGlobalLabel, devSummarySubtitle
    case devFilterAll, devGroupByProject, devGroupByType, devGlobalCaches, devGlobalCachesDesc, devItemsCount, devModifiedFmt
    case devEcoJavaScript, devEcoTypeScript, devEcoPython, devEcoRust, devEcoGo, devEcoSwift
    case devEcoJava, devEcoKotlin, devEcoRuby, devEcoPHP, devEcoDart, devEcoDocker, devEcoHomebrew
    case devEcoIOS, devEcoAndroid, devEcoWeb, devEcoCSharp, devEcoGeneral
    case devPurposeDependencies, devPurposeBuildOutput, devPurposeBuildCache, devPurposeDevServer
    case devPurposeTestCache, devPurposeLangCache, devPurposePackageManager, devPurposeRuntime, devPurposeTooling
    case devPurposeDescDependencies, devPurposeDescBuildOutput, devPurposeDescBuildCache, devPurposeDescDevServer
    case devPurposeDescTestCache, devPurposeDescLangCache, devPurposeDescPackageManager, devPurposeDescRuntime, devPurposeDescTooling
    case devSafetySafe, devSafetyRebuild, devSafetyCaution
    case devDescNodeModules, devDescSwiftBuild, devDescPycache, devDescVenv, devDescNext, devDescTurbo
    case devDescPods, devDescCarthage, devDescGradle, devDescRustTarget, devDescDist, devDescBuild
    case devDescPytestCache, devDescMypyCache, devDescTox, devDescCargoRegistry, devDescVendor
    case devDescBowerComponents, devDescParcelCache, devDescNuxt, devDescOutput, devDescCmakeDebug
    case devDescCmakeRelease, devDescSwiftpm, devDescPackageResolved, devDescGoPkgMod, devDescHomebrewCache
    case devDescDockerData, devDescGradleGlobal, devDescCargoDir, devDescGeneric
    case devInCollector, devCollectorCount, devSelectedTitle
    case devSortProjectAsc, devSortProjectDesc, devSortEcoAsc, devSortPurposeAsc
    case goalTitle, goalTarget, goalSuggest, goalProgress
    case goalScanning, goalAddAll, goalSelectedTitle, goalProjectedFree
    case goalSuggestionsTotal, goalScanHint, goalSuggestionsTitle, goalDaysUnused
    case goalCategoryCache, goalCategoryLogs, goalCategoryTrash, goalCategoryInstallers
    case goalCategoryOldDownloads, goalCategoryLargeDownloads, goalCategoryOldFiles, goalCategoryDevJunk
    case goalCategoryOther, goalPriorityHigh, goalPriorityMedium, goalPriorityLow
    case goalCollectorQueued, goalWithCollector, goalStillNeed
    case exportCSV, exportJSON, exportDone
    case recentFolders, bookmarks, addBookmark, removeBookmark
    case menuBarFree, menuBarUsed, menuBarOpen
    case items, results, filesIndexed, showInFolder, open, revealFinder, quickLook
    case rescan, refresh, permissions, permissionsOK, scanning, analyzing
    case welcomeTitle, welcomeSubtitle, startScan, grantPermissions
    case english, persian, chinese, french, arabic, turkish
    // Extended UI
    case welcomeTagline, selectVolume, totalCapacity, availableLabel, continueBtn, scanTakeTime
    case permAllSet, permRequired, permAllSetDesc, permRequiredDesc, permReadyScan, permGrantedCount
    case permTerminalTitle, permTerminalHint, back, openSettings, scanAnyway, grantAllPerms
    case prefScanning, prefDisplay, prefDefaultSort, done, ok, errorTitle
    case emptyFolder, diskLabel, folderLabel, volumeLabel, goUp, selectAll
    case menuNavigate, menuSortBy, menuFile
    case goalReached, goalNeedMore, dupWaste, dupCopiesCount, hiddenLabel, itemsSelected, hintSidebar
    case permFullDiskTitle, permFullDiskDesc, permUserFilesTitle, permUserFilesDesc
    case permRemovableTitle, permRemovableDesc, permCleanupTitle, permCleanupDesc
    case dupPhaseCollect, dupPhaseHash, historyAdded, historyRemoved, historyChanged
    case menuBarTotal, menuBarPercent, errorDeleteFailed, errorCannotDelete, errorCannotDeleteLibraryContainer, suggestionsCount, scanProgressFmt
    case scanningDiskTitle, scanPreparing, scanReadingList, scanFoundItems
    case scanFolderNamed, scanFoldersProgress, scanFinalizing, scanCaching, scanCachingFolders
    case percentFmt, progressStepFmt
    case donateTitle, donateSubtitle, donateThankYou, donateCopy, donateCopied, donateAllNetworks, donateSupport, menuDonate
    // Chart & overview
    case chartNoData, itemsCount, dupGroupsCount, devFoldersCount, removeFromCollector
    case overviewVolume, overviewUsed, overviewAvailable, overviewCurrentFolder, overviewOfSize
    // Delete warnings
    case warnIOSBackupTitle, warnIOSBackupMsg, warnTimeMachineTitle, warnTimeMachineMsg
    case warnSystemTitle, warnSystemMsg, warnRunningAppTitle, warnRunningAppMsg
    case warnLibraryTitle, warnLibraryMsg, warnBulkDeleteTitle, warnBulkDeleteMsg
    case deleteSummaryOne, deleteSummaryMany
    // Chart styles
    case chartStyleRose, chartStyleSunburst, chartStyleTreemap, chartUsedLabel, chartHintDrillDown, prefChartStyle
    // Smart collections
    case collectionTitle, collectionLargeFiles, collectionLargeFilesDesc
    case collectionOldFiles, collectionOldFilesDesc, collectionXcode, collectionXcodeDesc
    case collectionNodeModules, collectionNodeModulesDesc, collectionOldDownloads, collectionOldDownloadsDesc
    case collectionScanning, collectionActive
    // Detail panel
    case detailTitle, detailPath, detailCreated, detailItemCount, detailOpenFolder
    case detailShowLargeFiles, detailShowDetails, chartHintSelect
    // Panel integration
    case cleanupCollectionsHint, devCollectionsHint
    // Finder integration
    case finderAnalyzeVolumeNotFound, finderAnalyzeHelp
    // About
    case menuAbout, aboutTagline, aboutVersion, aboutDeveloper, aboutCopyright, aboutLicense, aboutGitHub
    // Interface mode
    case modeSelectTitle, modeSimple, modeSimpleDesc, modeProfessional, modeProfessionalDesc, prefInterfaceMode
    case simpleChartScanning
    case simpleChartScanProgress, simpleChartScanRemaining, simpleChartScanCurrent, simpleChartScanRing, simpleChartScanFiles
}

public struct LocalizationCatalog {
    public static func text(_ key: StringKey, language: AppLanguage) -> String {
        let lang = language == .system ? AppLanguage.fromSystemLocale() : language
        return table[key]?[lang] ?? table[key]?[.english] ?? key.rawValue
    }

    public static func format(_ key: StringKey, language: AppLanguage, _ args: CVarArg...) -> String {
        let template = text(key, language: language)
        return String(format: template, arguments: args)
    }

    private nonisolated(unsafe) static let table: [StringKey: [AppLanguage: String]] = [
        .collectorTitle: ml(en: "Collector", fa: "سطل جمع‌آوری", zh: "收集器", fr: "Collecteur", ar: "المجمع", tr: "Toplayıcı"),
        .collectorEmpty: ml(en: "Drag items here before deleting", fa: "آیتم‌ها را اینجا بکشید", zh: "拖放项目到此处", fr: "Glissez les éléments ici", ar: "اسحب العناصر هنا", tr: "Öğeleri buraya sürükleyin"),
        .collectorFree: ml(en: "Will free", fa: "آزاد می‌شود", zh: "将释放", fr: "Libérera", ar: "سيُحرر", tr: "Boşalacak"),
        .collectorClear: ml(en: "Clear", fa: "خالی کردن", zh: "清空", fr: "Vider", ar: "مسح", tr: "Temizle"),
        .collectorDelete: ml(en: "Delete All", fa: "حذف همه", zh: "全部删除", fr: "Tout supprimer", ar: "حذف الكل", tr: "Tümünü sil"),
        .addToCollector: ml(en: "Add to Collector", fa: "افزودن به سطل", zh: "添加到收集器", fr: "Ajouter au collecteur", ar: "إضافة للمجمع", tr: "Toplayıcıya ekle"),
        .collectorExpand: ml(en: "Expand", fa: "باز کردن", zh: "展开", fr: "Développer", ar: "توسيع", tr: "Genişlet"),
        .collectorCollapse: ml(en: "Collapse", fa: "جمع کردن", zh: "收起", fr: "Réduire", ar: "طي", tr: "Daralt"),
        .collectorMinimize: ml(en: "Minimize", fa: "کوچک کردن", zh: "最小化", fr: "Réduire au minimum", ar: "تصغير", tr: "Küçült"),
        .collectorRestore: ml(en: "Restore Collector", fa: "بازگرداندن سطل", zh: "恢复收集器", fr: "Restaurer le collecteur", ar: "استعادة المجمع", tr: "Toplayıcıyı geri yükle"),
        .collectorAfterDelete: ml(en: "Free space after delete", fa: "فضای آزاد پس از حذف", zh: "删除后可用空间", fr: "Espace libre après suppression", ar: "المساحة بعد الحذف", tr: "Silme sonrası boş alan"),
        .collectorPercent: ml(en: "of disk used", fa: "از دیسک", zh: "占磁盘", fr: "du disque", ar: "من القرص", tr: "diskin"),
        .searchPlaceholder: ml(en: "Search in folder…", fa: "جستجو در فولدر…", zh: "在文件夹中搜索…", fr: "Rechercher dans le dossier…", ar: "بحث في المجلد…", tr: "Klasörde ara…"),
        .searchPlaceholderVolume: ml(en: "Search entire volume…", fa: "جستجو در کل دیسک…", zh: "搜索整个磁盘…", fr: "Rechercher sur tout le volume…", ar: "بحث في القرص كاملاً…", tr: "Tüm diskte ara…"),
        .searchFilterScope: ml(en: "Search & Filter", fa: "جستجو و فیلتر", zh: "搜索与筛选", fr: "Recherche et filtres", ar: "بحث وتصفية", tr: "Ara ve filtrele"),
        .searchFilterCollapse: ml(en: "Hide search & filters", fa: "بستن جستجو و فیلتر", zh: "隐藏搜索和筛选", fr: "Masquer recherche et filtres", ar: "إخفاء البحث والتصفية", tr: "Arama ve filtreleri gizle"),
        .filterAll: ml(en: "All", fa: "همه", zh: "全部", fr: "Tout", ar: "الكل", tr: "Tümü"),
        .filterFolders: ml(en: "Folders", fa: "فولدرها", zh: "文件夹", fr: "Dossiers", ar: "مجلدات", tr: "Klasörler"),
        .filterImages: ml(en: "Images", fa: "تصاویر", zh: "图片", fr: "Images", ar: "صور", tr: "Görseller"),
        .filterVideos: ml(en: "Videos", fa: "ویدیو", zh: "视频", fr: "Vidéos", ar: "فيديو", tr: "Videolar"),
        .filterAudio: ml(en: "Audio", fa: "صوتی", zh: "音频", fr: "Audio", ar: "صوت", tr: "Ses"),
        .filterDocuments: ml(en: "Documents", fa: "اسناد", zh: "文档", fr: "Documents", ar: "مستندات", tr: "Belgeler"),
        .filterArchives: ml(en: "Archives", fa: "آرشیو", zh: "压缩包", fr: "Archives", ar: "أرشيف", tr: "Arşivler"),
        .filterApps: ml(en: "Apps", fa: "برنامه‌ها", zh: "应用", fr: "Apps", ar: "تطبيقات", tr: "Uygulamalar"),
        .filterDeveloper: ml(en: "Code", fa: "کد", zh: "代码", fr: "Code", ar: "كود", tr: "Kod"),
        .filterOther: ml(en: "Other", fa: "سایر", zh: "其他", fr: "Autre", ar: "أخرى", tr: "Diğer"),
        .noSearchResults: ml(en: "No matches found", fa: "نتیجه‌ای یافت نشد", zh: "未找到结果", fr: "Aucun résultat", ar: "لا نتائج", tr: "Sonuç yok"),
        .sortSizeDesc: ml(en: "Size ↓", fa: "حجم ↓", zh: "大小 ↓", fr: "Taille ↓", ar: "الحجم ↓", tr: "Boyut ↓"),
        .sortSizeAsc: ml(en: "Size ↑", fa: "حجم ↑", zh: "大小 ↑", fr: "Taille ↑", ar: "الحجم ↑", tr: "Boyut ↑"),
        .sortNameAsc: ml(en: "Name A–Z", fa: "نام الف–ی", zh: "名称 A–Z", fr: "Nom A–Z", ar: "الاسم أ–ي", tr: "Ad A–Z"),
        .sortNameDesc: ml(en: "Name Z–A", fa: "نام ی–الف", zh: "名称 Z–A", fr: "Nom Z–A", ar: "الاسم ي–أ", tr: "Ad Z–A"),
        .sortDateDesc: ml(en: "Newest", fa: "جدیدترین", zh: "最新", fr: "Plus récent", ar: "الأحدث", tr: "En yeni"),
        .sortDateAsc: ml(en: "Oldest", fa: "قدیمی‌ترین", zh: "最旧", fr: "Plus ancien", ar: "الأقدم", tr: "En eski"),
        .sortKind: ml(en: "Kind", fa: "نوع", zh: "类型", fr: "Type", ar: "النوع", tr: "Tür"),
        .langSystem: ml(en: "System", fa: "سیستم", zh: "系统", fr: "Système", ar: "النظام", tr: "Sistem"),
        .purgeableSpace: ml(en: "Purgeable", fa: "قابل آزادسازی", zh: "可清除", fr: "Purgeable", ar: "قابل التفريغ", tr: "Temizlenebilir"),
        .iCloudPlaceholder: ml(en: "iCloud Placeholder", fa: "فایل iCloud", zh: "iCloud占位", fr: "iCloud", ar: "iCloud", tr: "iCloud"),
        .snapshotsReserved: ml(en: "Snapshots & Reserved", fa: "اسنپ‌شات و رزرو", zh: "快照和保留", fr: "Snapshots", ar: "لقطات النظام", tr: "Anlık görüntüler"),
        .storageBreakdown: ml(en: "Storage", fa: "فضا", zh: "存储", fr: "Stockage", ar: "التخزين", tr: "Depolama"),
        .storageUsed: ml(en: "Used", fa: "استفاده", zh: "已用", fr: "Utilisé", ar: "مستخدم", tr: "Kullanılan"),
        .storageFree: ml(en: "Free", fa: "آزاد", zh: "可用", fr: "Libre", ar: "حر", tr: "Boş"),
        .deleteTitle: ml(en: "Delete permanently?", fa: "حذف دائمی؟", zh: "永久删除？", fr: "Supprimer définitivement ?", ar: "حذف نهائي؟", tr: "Kalıcı olarak silinsin mi?"),
        .deleteSafeMessage: ml(en: "This action cannot be undone.", fa: "این عمل قابل بازگشت نیست.", zh: "此操作无法撤销。", fr: "Cette action est irréversible.", ar: "لا يمكن التراجع عن هذا الإجراء.", tr: "Bu işlem geri alınamaz."),
        .deleteItemsHeader: ml(en: "Items", fa: "آیتم‌ها", zh: "项目", fr: "Éléments", ar: "عناصر", tr: "Öğeler"),
        .cancel: ml(en: "Cancel", fa: "لغو", zh: "取消", fr: "Annuler", ar: "إلغاء", tr: "İptal"),
        .deleteAction: ml(en: "Delete", fa: "حذف", zh: "删除", fr: "Supprimer", ar: "حذف", tr: "Sil"),
        .hintSpace: ml(en: "Space — Preview", fa: "Space — پیش‌نمایش", zh: "空格 — 预览", fr: "Espace — Aperçu", ar: "مسافة — معاينة", tr: "Space — Önizleme"),
        .hintEnter: ml(en: "↵ Open", fa: "↵ باز کردن", zh: "↵ 打开", fr: "↵ Ouvrir", ar: "↵ فتح", tr: "↵ Aç"),
        .hintBackspace: ml(en: "⌫ Up", fa: "⌫ برگشت", zh: "⌫ 返回", fr: "⌫ Retour", ar: "⌫ رجوع", tr: "⌫ Yukarı"),
        .hintShiftSelect: ml(en: "⇧ Range", fa: "⇧ بازه", zh: "⇧ 范围", fr: "⇧ Plage", ar: "⇧ نطاق", tr: "⇧ Aralık"),
        .preferences: ml(en: "Preferences…", fa: "تنظیمات…", zh: "偏好设置…", fr: "Préférences…", ar: "التفضيلات…", tr: "Tercihler…"),
        .prefGeneral: ml(en: "General", fa: "عمومی", zh: "通用", fr: "Général", ar: "عام", tr: "Genel"),
        .prefCache: ml(en: "Persistent cache", fa: "کش پایدار", zh: "持久缓存", fr: "Cache persistant", ar: "ذاكرة دائمة", tr: "Kalıcı önbellek"),
        .prefHidden: ml(en: "Show hidden files", fa: "فایل‌های مخفی", zh: "显示隐藏文件", fr: "Fichiers cachés", ar: "الملفات المخفية", tr: "Gizli dosyalar"),
        .prefLanguage: ml(en: "Language", fa: "زبان", zh: "语言", fr: "Langue", ar: "اللغة", tr: "Dil"),
        .prefScanParallel: ml(en: "Scan parallelism", fa: "موازی‌سازی", zh: "扫描并行度", fr: "Parallélisme", ar: "التوازي", tr: "Paralellik"),
        .prefScanParallelHelp: ml(en: "Higher = faster, more CPU", fa: "بیشتر = سریع‌تر", zh: "更高=更快", fr: "Plus = plus rapide", ar: "أعلى = أسرع", tr: "Yüksek = hızlı"),
        .searchScopeFolder: ml(en: "This folder", fa: "این فولدر", zh: "此文件夹", fr: "Ce dossier", ar: "هذا المجلد", tr: "Bu klasör"),
        .searchScopeVolume: ml(en: "Entire volume", fa: "کل دیسک", zh: "整个磁盘", fr: "Tout le volume", ar: "القرص كاملاً", tr: "Tüm disk"),
        .searchIndexing: ml(en: "Building index…", fa: "ساخت ایندکس…", zh: "建立索引…", fr: "Indexation…", ar: "بناء الفهرس…", tr: "Dizin oluşturuluyor…"),
        .searchSearching: ml(en: "Searching…", fa: "جستجو…", zh: "搜索中…", fr: "Recherche…", ar: "بحث…", tr: "Aranıyor…"),
        .searchResults: ml(en: "Search results", fa: "نتایج", zh: "搜索结果", fr: "Résultats", ar: "النتائج", tr: "Sonuçlar"),
        .searchNoResults: ml(en: "No files found", fa: "فایلی نیست", zh: "未找到文件", fr: "Aucun fichier", ar: "لا ملفات", tr: "Dosya yok"),
        .searchIndexReady: ml(en: "Index ready", fa: "ایندکس آماده", zh: "索引就绪", fr: "Index prêt", ar: "الفهرس جاهز", tr: "Dizin hazır"),
        .searchGoToFolder: ml(en: "Show in folder", fa: "نمایش در فولدر", zh: "在文件夹中显示", fr: "Afficher", ar: "عرض في المجلد", tr: "Klasörde göster"),
        .searchEngineSpotlight: ml(en: "Spotlight", fa: "Spotlight", zh: "Spotlight", fr: "Spotlight", ar: "Spotlight", tr: "Spotlight"),
        .searchEngineIndex: ml(en: "Index", fa: "ایندکس", zh: "索引", fr: "Index", ar: "فهرس", tr: "Dizin"),
        .searchEngineLive: ml(en: "Live", fa: "زنده", zh: "实时", fr: "Direct", ar: "مباشر", tr: "Canlı"),
        .rebuildSearchIndex: ml(en: "Rebuild index", fa: "بازسازی ایندکس", zh: "重建索引", fr: "Reconstruire", ar: "إعادة بناء", tr: "Dizini yenile"),
        .columnModified: ml(en: "Modified", fa: "تاریخ", zh: "修改", fr: "Modifié", ar: "التعديل", tr: "Değişiklik"),
        .columnKind: ml(en: "Kind", fa: "نوع", zh: "类型", fr: "Type", ar: "النوع", tr: "Tür"),
        .columnSize: ml(en: "Size", fa: "حجم", zh: "大小", fr: "Taille", ar: "الحجم", tr: "Boyut"),
        .columnName: ml(en: "Name", fa: "نام", zh: "名称", fr: "Nom", ar: "الاسم", tr: "Ad"),
        .scanFromCache: ml(en: "From cache", fa: "از کش", zh: "来自缓存", fr: "Depuis cache", ar: "من الذاكرة", tr: "Önbellekten"),
        .scanLive: ml(en: "Scanning…", fa: "اسکن…", zh: "扫描中…", fr: "Analyse…", ar: "فحص…", tr: "Taranıyor…"),
        .panelBrowser: ml(en: "Browse", fa: "مرور", zh: "浏览", fr: "Parcourir", ar: "تصفح", tr: "Gözat"),
        .panelCleanup: ml(en: "Cleanup", fa: "پاکسازی", zh: "清理", fr: "Nettoyage", ar: "تنظيف", tr: "Temizlik"),
        .panelDuplicates: ml(en: "Duplicates", fa: "تکراری", zh: "重复", fr: "Doublons", ar: "مكررات", tr: "Kopyalar"),
        .panelHistory: ml(en: "History", fa: "تاریخچه", zh: "历史", fr: "Historique", ar: "السجل", tr: "Geçmiş"),
        .panelDev: ml(en: "Developer", fa: "توسعه", zh: "开发者", fr: "Développeur", ar: "مطور", tr: "Geliştirici"),
        .panelGoal: ml(en: "Free Space", fa: "هدف فضا", zh: "释放空间", fr: "Espace libre", ar: "مساحة حرة", tr: "Boş alan"),
        .cleanupTitle: ml(en: "Smart Cleanup", fa: "پاکسازی هوشمند", zh: "智能清理", fr: "Nettoyage intelligent", ar: "تنظيف ذكي", tr: "Akıllı temizlik"),
        .cleanupEmpty: ml(en: "No suggestions yet", fa: "پیشنهادی نیست", zh: "暂无建议", fr: "Aucune suggestion", ar: "لا اقتراحات", tr: "Öneri yok"),
        .cleanupEmptyDesc: ml(en: "Scan caches, installers, and aging files to find space you can reclaim safely.", fa: "کش‌ها، نصب‌کننده‌ها و فایل‌های قدیمی را اسکن کنید تا فضای قابل بازیابی پیدا شود.", zh: "扫描缓存、安装包和旧文件，找出可安全释放的空间。", fr: "Analysez caches, installateurs et anciens fichiers pour libérer de l'espace.", ar: "افحص الذاكرة المؤقتة وملفات التثبيت والملفات القديمة لاسترداد المساحة.", tr: "Önbellekleri, yükleyicileri ve eski dosyaları tarayarak alan kazanın."),
        .cleanupAddAll: ml(en: "Add all to Collector", fa: "همه به سطل", zh: "全部添加", fr: "Tout ajouter", ar: "إضافة الكل", tr: "Tümünü ekle"),
        .cleanupScan: ml(en: "Scan suggestions", fa: "اسکن پیشنهادها", zh: "扫描建议", fr: "Analyser", ar: "فحص", tr: "Tara"),
        .cleanupSortScore: ml(en: "Priority", fa: "اولویت", zh: "优先级", fr: "Priorité", ar: "الأولوية", tr: "Öncelik"),
        .cleanupBreakdown: ml(en: "By category", fa: "بر اساس دسته", zh: "按类别", fr: "Par catégorie", ar: "حسب الفئة", tr: "Kategoriye göre"),
        .cleanupCategoryCount: ml(en: "%d items", fa: "%d مورد", zh: "%d 项", fr: "%d éléments", ar: "%d عناصر", tr: "%d öğe"),
        .cleanupSummarySubtitle: ml(en: "%d items · %@ reclaimable", fa: "%d مورد · %@ قابل بازیابی", zh: "%d 项 · 可释放 %@", fr: "%d éléments · %@ récupérables", ar: "%d عناصر · %@ قابلة للاسترداد", tr: "%d öğe · %@ kazanılabilir"),
        .dupTitle: ml(en: "Duplicate Files", fa: "فایل‌های تکراری", zh: "重复文件", fr: "Doublons", ar: "ملفات مكررة", tr: "Yinelenen dosyalar"),
        .dupScan: ml(en: "Find duplicates", fa: "یافتن تکراری", zh: "查找重复", fr: "Trouver", ar: "بحث", tr: "Bul"),
        .dupEmpty: ml(en: "No duplicates found", fa: "تکراری نیست", zh: "无重复", fr: "Aucun doublon", ar: "لا مكررات", tr: "Kopya yok"),
        .dupKeep: ml(en: "Keep", fa: "نگه دار", zh: "保留", fr: "Garder", ar: "احتفظ", tr: "Sakla"),
        .dupDelete: ml(en: "Add copies to Collector", fa: "کپی‌ها به سطل", zh: "副本到收集器", fr: "Ajouter copies", ar: "إضافة النسخ", tr: "Kopyaları ekle"),
        .historyTitle: ml(en: "Scan History", fa: "تاریخچه اسکن", zh: "扫描历史", fr: "Historique", ar: "سجل الفحص", tr: "Tarama geçmişi"),
        .historyEmpty: ml(en: "No history yet", fa: "تاریخچه‌ای نیست", zh: "暂无历史", fr: "Pas d'historique", ar: "لا سجل", tr: "Geçmiş yok"),
        .historyDiff: ml(en: "Since last scan", fa: "از آخرین اسکن", zh: "自上次扫描", fr: "Depuis dernier scan", ar: "منذ آخر فحص", tr: "Son taramadan"),
        .historyGrowth: ml(en: "+%@ added", fa: "+%@ اضافه", zh: "+%@ 增加", fr: "+%@ ajouté", ar: "+%@ مضاف", tr: "+%@ eklendi"),
        .historySaved: ml(en: "Snapshot saved", fa: "ذخیره شد", zh: "已保存", fr: "Enregistré", ar: "تم الحفظ", tr: "Kaydedildi"),
        .historyEmptyDesc: ml(en: "Complete a full volume scan to capture your first snapshot. Each rescan adds a new entry you can compare over time.", fa: "یک اسکن کامل ولوم انجام دهید تا اولین اسنپ‌شات ذخیره شود. هر اسکن مجدد یک ورودی جدید برای مقایسه اضافه می‌کند.", zh: "完成一次完整卷扫描以捕获第一个快照。每次重新扫描都会添加可比较的新条目。", fr: "Effectuez une analyse complète du volume pour capturer votre premier instantané. Chaque nouvelle analyse ajoute une entrée comparable.", ar: "أكمل فحصاً كاملاً للحجم لالتقاط أول لقطة. كل فحص جديد يضيف إدخالاً للمقارنة.", tr: "İlk anlık görüntüyü yakalamak için tam bir birim taraması yapın. Her yeniden tarama karşılaştırılabilir yeni bir giriş ekler."),
        .historySnapshotsCount: ml(en: "%d snapshots", fa: "%d اسنپ‌شات", zh: "%d 个快照", fr: "%d instantanés", ar: "%d لقطات", tr: "%d anlık görüntü"),
        .historyCompareCurrent: ml(en: "vs Now", fa: "نسبت به الان", zh: "对比当前", fr: "vs maintenant", ar: "مقابل الآن", tr: "şimdiye göre"),
        .historyComparePrevious: ml(en: "vs Previous", fa: "نسبت به قبلی", zh: "对比上次", fr: "vs précédent", ar: "مقابل السابق", tr: "öncekine göre"),
        .historyNetDelta: ml(en: "Net change", fa: "تغییر خالص", zh: "净变化", fr: "Variation nette", ar: "التغيير الصافي", tr: "Net değişim"),
        .historyPathsChanged: ml(en: "%d paths", fa: "%d مسیر", zh: "%d 个路径", fr: "%d chemins", ar: "%d مسار", tr: "%d yol"),
        .historyRootWarning: ml(en: "You're viewing a subfolder. Switch to the volume root for an accurate comparison.", fa: "در زیرپوشه هستید. برای مقایسه دقیق به ریشه ولوم بروید.", zh: "您正在查看子文件夹。切换到卷根目录以进行准确比较。", fr: "Vous consultez un sous-dossier. Allez à la racine du volume pour une comparaison précise.", ar: "أنت تعرض مجلداً فرعياً. انتقل إلى جذر الحجم لمقارنة دقيقة.", tr: "Alt klasördesiniz. Doğru karşılaştırma için birim köküne gidin."),
        .historyDeleteSnapshot: ml(en: "Delete snapshot", fa: "حذف اسنپ‌شات", zh: "删除快照", fr: "Supprimer l'instantané", ar: "حذف اللقطة", tr: "Anlık görüntüyü sil"),
        .historyRescan: ml(en: "Rescan volume", fa: "اسکن مجدد ولوم", zh: "重新扫描卷", fr: "Réanalyser le volume", ar: "إعادة فحص الحجم", tr: "Birimi yeniden tara"),
        .historyTopItems: ml(en: "Largest at scan", fa: "بزرگ‌ترین‌ها در اسکن", zh: "扫描时最大项", fr: "Plus gros à l'analyse", ar: "الأكبر عند الفحص", tr: "Taramadaki en büyükler"),
        .historyTimeline: ml(en: "Timeline", fa: "خط زمانی", zh: "时间线", fr: "Chronologie", ar: "الجدول الزمني", tr: "Zaman çizelgesi"),
        .historyDetails: ml(en: "Changes", fa: "تغییرات", zh: "变化", fr: "Modifications", ar: "التغييرات", tr: "Değişiklikler"),
        .historySearchPlaceholder: ml(en: "Filter paths…", fa: "فیلتر مسیر…", zh: "筛选路径…", fr: "Filtrer chemins…", ar: "تصفية المسارات…", tr: "Yolları filtrele…"),
        .historyFilterAll: ml(en: "All", fa: "همه", zh: "全部", fr: "Tout", ar: "الكل", tr: "Tümü"),
        .historyNoChanges: ml(en: "No changes detected", fa: "تغییری شناسایی نشد", zh: "未检测到变化", fr: "Aucun changement", ar: "لا تغييرات", tr: "Değişiklik yok"),
        .historySincePrevious: ml(en: "Since previous scan", fa: "از اسکن قبلی", zh: "自上次扫描", fr: "Depuis l'analyse précédente", ar: "منذ الفحص السابق", tr: "Önceki taramadan beri"),
        .historyTrackedSize: ml(en: "Tracked data", fa: "داده ردیابی‌شده", zh: "跟踪数据", fr: "Données suivies", ar: "البيانات المتتبعة", tr: "İzlenen veri"),
        .historyUsageTrend: ml(en: "Usage trend", fa: "روند مصرف", zh: "使用趋势", fr: "Tendance d'utilisation", ar: "اتجاه الاستخدام", tr: "Kullanım eğilimi"),
        .historyOpenPath: ml(en: "Open in browser", fa: "باز کردن در مرورگر", zh: "在浏览器中打开", fr: "Ouvrir dans le navigateur", ar: "فتح في المتصفح", tr: "Tarayıcıda aç"),
        .historyChangesTitle: ml(en: "What changed", fa: "چه چیزی تغییر کرد", zh: "变化内容", fr: "Ce qui a changé", ar: "ما الذي تغير", tr: "Ne değişti"),
        .historySnapshotDetail: ml(en: "Snapshot overview", fa: "خلاصه اسنپ‌شات", zh: "快照概览", fr: "Aperçu de l'instantané", ar: "نظرة على اللقطة", tr: "Anlık görüntü özeti"),
        .devTitle: ml(en: "Developer Junk", fa: "زباله توسعه", zh: "开发垃圾", fr: "Déchets dev", ar: "ملفات التطوير", tr: "Geliştirici çöpü"),
        .devScan: ml(en: "Scan dev folders", fa: "اسکن dev", zh: "扫描开发目录", fr: "Scanner dev", ar: "فحص dev", tr: "Dev tara"),
        .devEmpty: ml(en: "No dev junk found", fa: "چیزی نیست", zh: "未找到", fr: "Rien trouvé", ar: "لا شيء", tr: "Bulunamadı"),
        .devEmptyDesc: ml(en: "Scans for node_modules, build caches, virtual environments, and package manager caches across your projects.", fa: "node_modules، کش build، محیط‌های مجازی و کش پکیج‌منیجر را در پروژه‌ها پیدا می‌کند.", zh: "扫描项目中的 node_modules、构建缓存、虚拟环境和包管理器缓存。", fr: "Recherche node_modules, caches de build, environnements virtuels et caches de gestionnaires de paquets.", ar: "يفحص node_modules وذاكرة البناء والبيئات الافتراضية وذاكرة مديري الحزم.", tr: "Projelerde node_modules, derleme önbellekleri, sanal ortamlar ve paket yöneticisi önbelleklerini tarar."),
        .devReclaimable: ml(en: "Reclaimable", fa: "قابل آزادسازی", zh: "可释放", fr: "Récupérable", ar: "قابل الاسترداد", tr: "Geri kazanılabilir"),
        .devItemsLabel: ml(en: "items", fa: "آیتم", zh: "项", fr: "éléments", ar: "عناصر", tr: "öğe"),
        .devProjectsLabel: ml(en: "projects", fa: "پروژه", zh: "项目", fr: "projets", ar: "مشاريع", tr: "proje"),
        .devGlobalLabel: ml(en: "global", fa: "سراسری", zh: "全局", fr: "global", ar: "عام", tr: "genel"),
        .devSummarySubtitle: ml(en: "%d items · %d projects · %@ reclaimable", fa: "%d آیتم · %d پروژه · %@ قابل آزادسازی", zh: "%d 项 · %d 项目 · 可释放 %@", fr: "%d éléments · %d projets · %@ récupérables", ar: "%d عنصر · %d مشروع · %@ قابل الاسترداد", tr: "%d öğe · %d proje · %@ geri kazanılabilir"),
        .devFilterAll: ml(en: "All", fa: "همه", zh: "全部", fr: "Tout", ar: "الكل", tr: "Tümü"),
        .devGroupByProject: ml(en: "By Project", fa: "بر اساس پروژه", zh: "按项目", fr: "Par projet", ar: "حسب المشروع", tr: "Projeye göre"),
        .devGroupByType: ml(en: "By Type", fa: "بر اساس نوع", zh: "按类型", fr: "Par type", ar: "حسب النوع", tr: "Türe göre"),
        .devGlobalCaches: ml(en: "Global & System Caches", fa: "کش‌های سراسری و سیستمی", zh: "全局和系统缓存", fr: "Caches globaux et système", ar: "ذاكرة عامة ونظام", tr: "Genel ve sistem önbellekleri"),
        .devGlobalCachesDesc: ml(en: "Shared across all projects — package registries, tool caches", fa: "مشترک بین همه پروژه‌ها — رجیستری پکیج‌ها و کش ابزارها", zh: "所有项目共享 — 包注册表、工具缓存", fr: "Partagé entre tous les projets — registres de paquets, caches d'outils", ar: "مشترك بين جميع المشاريع — سجلات الحزم وذاكرة الأدوات", tr: "Tüm projelerde paylaşılan — paket kayıtları, araç önbellekleri"),
        .devItemsCount: ml(en: "%d items", fa: "%d آیتم", zh: "%d 项", fr: "%d éléments", ar: "%d عنصر", tr: "%d öğe"),
        .devModifiedFmt: ml(en: "Modified %@", fa: "تغییر %@", zh: "修改于 %@", fr: "Modifié %@", ar: "تعديل %@", tr: "Değiştirildi %@"),
        .devEcoJavaScript: ml(en: "JavaScript", fa: "جاوااسکریپت", zh: "JavaScript", fr: "JavaScript", ar: "JavaScript", tr: "JavaScript"),
        .devEcoTypeScript: ml(en: "TypeScript", fa: "تایپ‌اسکریپت", zh: "TypeScript", fr: "TypeScript", ar: "TypeScript", tr: "TypeScript"),
        .devEcoPython: ml(en: "Python", fa: "پایتون", zh: "Python", fr: "Python", ar: "Python", tr: "Python"),
        .devEcoRust: ml(en: "Rust", fa: "راست", zh: "Rust", fr: "Rust", ar: "Rust", tr: "Rust"),
        .devEcoGo: ml(en: "Go", fa: "گو", zh: "Go", fr: "Go", ar: "Go", tr: "Go"),
        .devEcoSwift: ml(en: "Swift", fa: "سوئیفت", zh: "Swift", fr: "Swift", ar: "Swift", tr: "Swift"),
        .devEcoJava: ml(en: "Java", fa: "جاوا", zh: "Java", fr: "Java", ar: "Java", tr: "Java"),
        .devEcoKotlin: ml(en: "Kotlin", fa: "کاتلین", zh: "Kotlin", fr: "Kotlin", ar: "Kotlin", tr: "Kotlin"),
        .devEcoRuby: ml(en: "Ruby", fa: "روبی", zh: "Ruby", fr: "Ruby", ar: "Ruby", tr: "Ruby"),
        .devEcoPHP: ml(en: "PHP", fa: "PHP", zh: "PHP", fr: "PHP", ar: "PHP", tr: "PHP"),
        .devEcoDart: ml(en: "Dart", fa: "دارت", zh: "Dart", fr: "Dart", ar: "Dart", tr: "Dart"),
        .devEcoDocker: ml(en: "Docker", fa: "داکر", zh: "Docker", fr: "Docker", ar: "Docker", tr: "Docker"),
        .devEcoHomebrew: ml(en: "Homebrew", fa: "هوم‌برو", zh: "Homebrew", fr: "Homebrew", ar: "Homebrew", tr: "Homebrew"),
        .devEcoIOS: ml(en: "iOS / Apple", fa: "iOS / اپل", zh: "iOS / Apple", fr: "iOS / Apple", ar: "iOS / Apple", tr: "iOS / Apple"),
        .devEcoAndroid: ml(en: "Android", fa: "اندروید", zh: "Android", fr: "Android", ar: "Android", tr: "Android"),
        .devEcoWeb: ml(en: "Web / Frontend", fa: "وب / فرانت‌اند", zh: "Web / 前端", fr: "Web / Frontend", ar: "ويب / واجهة", tr: "Web / Frontend"),
        .devEcoCSharp: ml(en: "C# / .NET", fa: "C# / .NET", zh: "C# / .NET", fr: "C# / .NET", ar: "C# / .NET", tr: "C# / .NET"),
        .devEcoGeneral: ml(en: "General", fa: "عمومی", zh: "通用", fr: "Général", ar: "عام", tr: "Genel"),
        .devPurposeDependencies: ml(en: "Dependencies", fa: "وابستگی‌ها", zh: "依赖", fr: "Dépendances", ar: "تبعيات", tr: "Bağımlılıklar"),
        .devPurposeBuildOutput: ml(en: "Build Output", fa: "خروجی build", zh: "构建输出", fr: "Sortie de build", ar: "مخرجات البناء", tr: "Derleme çıktısı"),
        .devPurposeBuildCache: ml(en: "Build Cache", fa: "کش build", zh: "构建缓存", fr: "Cache de build", ar: "ذاكرة البناء", tr: "Derleme önbelleği"),
        .devPurposeDevServer: ml(en: "Dev Server Cache", fa: "کش dev server", zh: "开发服务器缓存", fr: "Cache serveur dev", ar: "ذاكرة خادم التطوير", tr: "Dev sunucu önbelleği"),
        .devPurposeTestCache: ml(en: "Test Cache", fa: "کش تست", zh: "测试缓存", fr: "Cache de tests", ar: "ذاكرة الاختبار", tr: "Test önbelleği"),
        .devPurposeLangCache: ml(en: "Language Cache", fa: "کش زبان", zh: "语言缓存", fr: "Cache langage", ar: "ذاكرة اللغة", tr: "Dil önbelleği"),
        .devPurposePackageManager: ml(en: "Package Manager", fa: "مدیر پکیج", zh: "包管理器", fr: "Gestionnaire de paquets", ar: "مدير الحزم", tr: "Paket yöneticisi"),
        .devPurposeRuntime: ml(en: "Runtime Data", fa: "داده runtime", zh: "运行时数据", fr: "Données runtime", ar: "بيانات التشغيل", tr: "Çalışma zamanı verisi"),
        .devPurposeTooling: ml(en: "Tooling", fa: "ابزارها", zh: "工具", fr: "Outils", ar: "أدوات", tr: "Araçlar"),
        .devPurposeDescDependencies: ml(en: "Installed packages — re-download with npm/yarn/pip/cargo", fa: "پکیج‌های نصب‌شده — با npm/yarn/pip/cargo دوباره دانلود می‌شوند", zh: "已安装的包 — 可通过 npm/yarn/pip/cargo 重新下载", fr: "Paquets installés — re-téléchargeables via npm/yarn/pip/cargo", ar: "حزم مثبتة — تُعاد تنزيلها عبر npm/yarn/pip/cargo", tr: "Yüklü paketler — npm/yarn/pip/cargo ile yeniden indirilebilir"),
        .devPurposeDescBuildOutput: ml(en: "Compiled binaries and production builds", fa: "باینری‌های کامپایل‌شده و build تولیدی", zh: "编译的二进制文件和生产构建", fr: "Binaires compilés et builds de production", ar: "ملفات ثنائية مُجمَّعة وبناءات الإنتاج", tr: "Derlenmiş ikili dosyalar ve üretim derlemeleri"),
        .devPurposeDescBuildCache: ml(en: "Intermediate build artifacts — speeds up next compile", fa: "آرتیفکت‌های میانی build — کامپایل بعدی را سریع‌تر می‌کند", zh: "中间构建产物 — 加速下次编译", fr: "Artefacts intermédiaires — accélère la prochaine compilation", ar: "مخرجات بناء وسيطة — تُسرِّع التجميع التالي", tr: "Ara derleme çıktıları — sonraki derlemeyi hızlandırır"),
        .devPurposeDescDevServer: ml(en: "Hot-reload and dev server caches — rebuild on next run", fa: "کش hot-reload و dev server — در اجرای بعدی rebuild می‌شود", zh: "热重载和开发服务器缓存 — 下次运行时重建", fr: "Caches hot-reload et serveur dev — reconstruit au prochain lancement", ar: "ذاكرة إعادة التحميل وخادم التطوير — يُعاد البناء عند التشغيل التالي", tr: "Hot-reload ve dev sunucu önbellekleri — sonraki çalıştırmada yeniden oluşturulur"),
        .devPurposeDescTestCache: ml(en: "Test runner caches — regenerated on next test run", fa: "کش test runner — در اجرای بعدی تست دوباره ساخته می‌شود", zh: "测试运行器缓存 — 下次测试时重新生成", fr: "Caches de tests — régénérés au prochain lancement", ar: "ذاكرة مشغل الاختبار — تُعاد عند التشغيل التالي", tr: "Test çalıştırıcı önbellekleri — sonraki testte yeniden oluşturulur"),
        .devPurposeDescLangCache: ml(en: "Bytecode and type-check caches", fa: "کش bytecode و type-check", zh: "字节码和类型检查缓存", fr: "Caches bytecode et vérification de types", ar: "ذاكرة bytecode وفحص الأنواع", tr: "Bytecode ve tip kontrol önbellekleri"),
        .devPurposeDescPackageManager: ml(en: "Global package registry and download caches", fa: "رجیستری و کش دانلود پکیج‌های سراسری", zh: "全局包注册表和下载缓存", fr: "Registre global et caches de téléchargement", ar: "سجل الحزم العام وذاكرة التنزيل", tr: "Genel paket kaydı ve indirme önbellekleri"),
        .devPurposeDescRuntime: ml(en: "Container images and runtime state", fa: "ایمیج کانتینر و وضعیت runtime", zh: "容器镜像和运行时状态", fr: "Images de conteneurs et état runtime", ar: "صور الحاويات وحالة التشغيل", tr: "Konteyner imajları ve çalışma zamanı durumu"),
        .devPurposeDescTooling: ml(en: "Third-party build tools and lock files", fa: "ابزارهای build شخص ثالث و فایل‌های lock", zh: "第三方构建工具和锁文件", fr: "Outils de build tiers et fichiers de verrouillage", ar: "أدوات بناء طرف ثالث وملفات القفل", tr: "Üçüncü taraf derleme araçları ve kilit dosyaları"),
        .devSafetySafe: ml(en: "Safe", fa: "ایمن", zh: "安全", fr: "Sûr", ar: "آمن", tr: "Güvenli"),
        .devSafetyRebuild: ml(en: "Rebuild", fa: "نیاز به rebuild", zh: "需重建", fr: "Reconstruire", ar: "إعادة بناء", tr: "Yeniden derle"),
        .devSafetyCaution: ml(en: "Caution", fa: "احتیاط", zh: "谨慎", fr: "Attention", ar: "حذر", tr: "Dikkat"),
        .devDescNodeModules: ml(en: "npm/yarn/pnpm installed packages for this project", fa: "پکیج‌های نصب‌شده npm/yarn/pnpm این پروژه", zh: "此项目的 npm/yarn/pnpm 已安装包", fr: "Paquets npm/yarn/pnpm installés pour ce projet", ar: "حزم npm/yarn/pnpm المثبتة لهذا المشروع", tr: "Bu proje için yüklü npm/yarn/pnpm paketleri"),
        .devDescSwiftBuild: ml(en: "Swift Package Manager build output (.build)", fa: "خروجی build Swift Package Manager", zh: "Swift Package Manager 构建输出", fr: "Sortie de build Swift Package Manager", ar: "مخرجات بناء Swift Package Manager", tr: "Swift Package Manager derleme çıktısı"),
        .devDescPycache: ml(en: "Python bytecode cache — auto-regenerated on import", fa: "کش bytecode پایتون — هنگام import خودکار ساخته می‌شود", zh: "Python 字节码缓存 — 导入时自动重新生成", fr: "Cache bytecode Python — régénéré à l'import", ar: "ذاكرة bytecode بايثون — تُعاد عند الاستيراد", tr: "Python bytecode önbelleği — import sırasında yeniden oluşturulur"),
        .devDescVenv: ml(en: "Python virtual environment with isolated packages", fa: "محیط مجازی پایتون با پکیج‌های ایزوله", zh: "Python 虚拟环境及隔离包", fr: "Environnement virtuel Python avec paquets isolés", ar: "بيئة Python الافتراضية مع حزم معزولة", tr: "İzole paketlerle Python sanal ortamı"),
        .devDescNext: ml(en: "Next.js build output and dev server cache (.next)", fa: "خروجی build و کش dev server نکست‌جی‌اس", zh: "Next.js 构建输出和开发服务器缓存", fr: "Sortie de build et cache serveur dev Next.js", ar: "مخرجات بناء Next.js وذاكرة خادم التطوير", tr: "Next.js derleme çıktısı ve dev sunucu önbelleği"),
        .devDescTurbo: ml(en: "Turborepo remote and local build cache", fa: "کش build محلی و remote توربورپو", zh: "Turborepo 远程和本地构建缓存", fr: "Cache de build local et distant Turborepo", ar: "ذاكرة بناء Turborepo المحلية والبعيدة", tr: "Turborepo yerel ve uzak derleme önbelleği"),
        .devDescPods: ml(en: "CocoaPods iOS/macOS dependencies", fa: "وابستگی‌های CocoaPods برای iOS/macOS", zh: "CocoaPods iOS/macOS 依赖", fr: "Dépendances CocoaPods iOS/macOS", ar: "تبعيات CocoaPods لـ iOS/macOS", tr: "CocoaPods iOS/macOS bağımlılıkları"),
        .devDescCarthage: ml(en: "Carthage pre-built iOS frameworks", fa: "فریم‌ورک‌های ازپیش‌ساخته Carthage", zh: "Carthage 预构建 iOS 框架", fr: "Frameworks iOS pré-construits Carthage", ar: "أطر iOS مُجمَّعة مسبقًا من Carthage", tr: "Carthage önceden derlenmiş iOS framework'leri"),
        .devDescGradle: ml(en: "Gradle build cache for Android/Java/Kotlin", fa: "کش build گرادل برای اندروید/جاوا/کاتلین", zh: "Android/Java/Kotlin 的 Gradle 构建缓存", fr: "Cache de build Gradle pour Android/Java/Kotlin", ar: "ذاكرة بناء Gradle لـ Android/Java/Kotlin", tr: "Android/Java/Kotlin için Gradle derleme önbelleği"),
        .devDescRustTarget: ml(en: "Rust compiled artifacts (target/)", fa: "آرتیفکت‌های کامپایل‌شده راست (target/)", zh: "Rust 编译产物 (target/)", fr: "Artefacts compilés Rust (target/)", ar: "مخرجات Rust المُجمَّعة (target/)", tr: "Rust derlenmiş çıktıları (target/)"),
        .devDescDist: ml(en: "Production build output (dist/)", fa: "خروجی build تولیدی (dist/)", zh: "生产构建输出 (dist/)", fr: "Sortie de build de production (dist/)", ar: "مخرجات بناء الإنتاج (dist/)", tr: "Üretim derleme çıktısı (dist/)"),
        .devDescBuild: ml(en: "Generic build output directory", fa: "فولدر خروجی build عمومی", zh: "通用构建输出目录", fr: "Répertoire de sortie de build générique", ar: "مجلد مخرجات بناء عام", tr: "Genel derleme çıktısı dizini"),
        .devDescPytestCache: ml(en: "pytest test discovery and run cache", fa: "کش discovery و اجرای pytest", zh: "pytest 测试发现和运行缓存", fr: "Cache de découverte et exécution pytest", ar: "ذاكرة اكتشاف وتشغيل pytest", tr: "pytest test keşif ve çalıştırma önbelleği"),
        .devDescMypyCache: ml(en: "mypy static type checker cache", fa: "کش type checker استاتیک mypy", zh: "mypy 静态类型检查器缓存", fr: "Cache du vérificateur de types statique mypy", ar: "ذاكرة فاحص الأنواع الثابت mypy", tr: "mypy statik tip denetleyici önbelleği"),
        .devDescTox: ml(en: "tox multi-environment test cache", fa: "کش تست چندمحیطی tox", zh: "tox 多环境测试缓存", fr: "Cache de tests multi-environnements tox", ar: "ذاكرة اختبار tox متعدد البيئات", tr: "tox çoklu ortam test önbelleği"),
        .devDescCargoRegistry: ml(en: "Global Rust crate registry cache (~/.cargo/registry)", fa: "کش رجیستری crate راست سراسری", zh: "全局 Rust crate 注册表缓存", fr: "Cache du registre global de crates Rust", ar: "ذاكرة سجل crate Rust العام", tr: "Genel Rust crate kayıt önbelleği"),
        .devDescVendor: ml(en: "Composer/Go vendored dependencies", fa: "وابستگی‌های vendor شده Composer/Go", zh: "Composer/Go 供应商依赖", fr: "Dépendances vendored Composer/Go", ar: "تبعيات Composer/Go الموردة", tr: "Composer/Go vendor bağımlılıkları"),
        .devDescBowerComponents: ml(en: "Legacy Bower frontend packages", fa: "پکیج‌های فرانت‌اند Bower قدیمی", zh: "旧版 Bower 前端包", fr: "Anciens paquets frontend Bower", ar: "حزم Bower الأمامية القديمة", tr: "Eski Bower frontend paketleri"),
        .devDescParcelCache: ml(en: "Parcel bundler transform cache", fa: "کش transform باندلر Parcel", zh: "Parcel 打包器转换缓存", fr: "Cache de transformation du bundler Parcel", ar: "ذاكرة تحويل مجمّع Parcel", tr: "Parcel bundler dönüşüm önbelleği"),
        .devDescNuxt: ml(en: "Nuxt.js build and dev server cache", fa: "کش build و dev server ناکست", zh: "Nuxt.js 构建和开发服务器缓存", fr: "Cache de build et serveur dev Nuxt.js", ar: "ذاكرة بناء وخادم تطوير Nuxt.js", tr: "Nuxt.js derleme ve dev sunucu önbelleği"),
        .devDescOutput: ml(en: "Nuxt/SvelteKit production output", fa: "خروجی تولیدی Nuxt/SvelteKit", zh: "Nuxt/SvelteKit 生产输出", fr: "Sortie de production Nuxt/SvelteKit", ar: "مخرجات إنتاج Nuxt/SvelteKit", tr: "Nuxt/SvelteKit üretim çıktısı"),
        .devDescCmakeDebug: ml(en: "CMake debug build directory", fa: "فولدر build دیباگ CMake", zh: "CMake 调试构建目录", fr: "Répertoire de build debug CMake", ar: "مجلد بناء تصحيح CMake", tr: "CMake debug derleme dizini"),
        .devDescCmakeRelease: ml(en: "CMake release build directory", fa: "فولدر build رلیز CMake", zh: "CMake 发布构建目录", fr: "Répertoire de build release CMake", ar: "مجلد بناء إصدار CMake", tr: "CMake release derleme dizini"),
        .devDescSwiftpm: ml(en: "SwiftPM configuration and build state", fa: "پیکربندی و وضعیت build SwiftPM", zh: "SwiftPM 配置和构建状态", fr: "Configuration et état de build SwiftPM", ar: "تكوين وحالة بناء SwiftPM", tr: "SwiftPM yapılandırma ve derleme durumu"),
        .devDescPackageResolved: ml(en: "SwiftPM resolved dependency lock file", fa: "فایل lock وابستگی‌های حل‌شده SwiftPM", zh: "SwiftPM 已解析依赖锁文件", fr: "Fichier de verrouillage des dépendances SwiftPM", ar: "ملف قفل تبعيات SwiftPM المحلولة", tr: "SwiftPM çözümlenmiş bağımlılık kilit dosyası"),
        .devDescGoPkgMod: ml(en: "Global Go module download cache (~/go/pkg/mod)", fa: "کش دانلود ماژول گو سراسری", zh: "全局 Go 模块下载缓存", fr: "Cache global de téléchargement de modules Go", ar: "ذاكرة تنزيل وحدة Go العامة", tr: "Genel Go modül indirme önbelleği"),
        .devDescHomebrewCache: ml(en: "Homebrew formula download cache", fa: "کش دانلود فرمول‌های Homebrew", zh: "Homebrew 公式下载缓存", fr: "Cache de téléchargement des formules Homebrew", ar: "ذاكرة تنزيل صيغ Homebrew", tr: "Homebrew formül indirme önbelleği"),
        .devDescDockerData: ml(en: "Docker Desktop VM and container data", fa: "داده VM و کانتینر Docker Desktop", zh: "Docker Desktop 虚拟机和容器数据", fr: "Données VM et conteneurs Docker Desktop", ar: "بيانات VM وحاويات Docker Desktop", tr: "Docker Desktop VM ve konteyner verisi"),
        .devDescGradleGlobal: ml(en: "Global Gradle daemon and dependency cache", fa: "کش daemon و وابستگی گرادل سراسری", zh: "全局 Gradle 守护进程和依赖缓存", fr: "Cache global du daemon et des dépendances Gradle", ar: "ذاكرة daemon Gradle والتبعيات العامة", tr: "Genel Gradle daemon ve bağımlılık önbelleği"),
        .devDescCargoDir: ml(en: "Rust cargo home — registry, git checkouts, build cache", fa: "خانه cargo راست — رجیستری، git checkout، کش build", zh: "Rust cargo 主目录 — 注册表、git 检出、构建缓存", fr: "Répertoire cargo Rust — registre, checkouts git, cache de build", ar: "مجلد cargo Rust — السجل، git checkout، ذاكرة البناء", tr: "Rust cargo ana dizini — kayıt, git checkout, derleme önbelleği"),
        .devDescGeneric: ml(en: "Development artifact folder", fa: "فولدر آرتیفکت توسعه", zh: "开发产物文件夹", fr: "Dossier d'artefacts de développement", ar: "مجلد مخرجات التطوير", tr: "Geliştirme çıktısı klasörü"),
        .devInCollector: ml(en: "In Collector", fa: "در سطل", zh: "已加入收集器", fr: "Dans le collecteur", ar: "في المجمع", tr: "Toplayıcıda"),
        .devCollectorCount: ml(en: "%d in Collector", fa: "%d در سطل", zh: "%d 项在收集器", fr: "%d dans le collecteur", ar: "%d في المجمع", tr: "%d toplayıcıda"),
        .devSelectedTitle: ml(en: "Queued for cleanup", fa: "در صف حذف", zh: "待清理", fr: "En file pour nettoyage", ar: "في قائمة التنظيف", tr: "Temizlik için sıraya alındı"),
        .devSortProjectAsc: ml(en: "Project A→Z", fa: "پروژه الف→ی", zh: "项目 A→Z", fr: "Projet A→Z", ar: "المشروع أ→ي", tr: "Proje A→Z"),
        .devSortProjectDesc: ml(en: "Project Z→A", fa: "پروژه ی→الف", zh: "项目 Z→A", fr: "Projet Z→A", ar: "المشروع ي→أ", tr: "Proje Z→A"),
        .devSortEcoAsc: ml(en: "Language / stack", fa: "زبان / استک", zh: "语言/技术栈", fr: "Langage / stack", ar: "اللغة / المكدس", tr: "Dil / stack"),
        .devSortPurposeAsc: ml(en: "Type (deps, build…)", fa: "نوع (وابستگی، build…)", zh: "类型（依赖、构建…）", fr: "Type (deps, build…)", ar: "النوع (تبعيات، بناء…)", tr: "Tür (bağımlılık, build…)"),
        .goalTitle: ml(en: "Free Space Goal", fa: "هدف آزادسازی", zh: "释放目标", fr: "Objectif d'espace", ar: "هدف المساحة", tr: "Boş alan hedefi"),
        .goalTarget: ml(en: "Target to free", fa: "هدف آزادسازی", zh: "目标释放", fr: "Objectif", ar: "الهدف", tr: "Hedef"),
        .goalSuggest: ml(en: "Suggest items", fa: "پیشنهاد آیتم", zh: "推荐项目", fr: "Suggérer", ar: "اقتراح", tr: "Öner"),
        .goalProgress: ml(en: "Progress", fa: "پیشرفت", zh: "进度", fr: "Progrès", ar: "التقدم", tr: "İlerleme"),
        .goalScanning: ml(en: "Scanning for space…", fa: "در حال جستجوی فضا…", zh: "正在扫描空间…", fr: "Recherche d'espace…", ar: "جارٍ البحث عن مساحة…", tr: "Alan aranıyor…"),
        .goalAddAll: ml(en: "Add all to Collector", fa: "افزودن همه به سطل", zh: "全部加入收集器", fr: "Tout ajouter", ar: "إضافة الكل للمجمع", tr: "Tümünü toplayıcıya ekle"),
        .goalSelectedTitle: ml(en: "Queued for cleanup", fa: "در صف حذف", zh: "待清理", fr: "En file d'attente", ar: "في قائمة التنظيف", tr: "Temizlik kuyruğu"),
        .goalProjectedFree: ml(en: "After cleanup", fa: "بعد پاکسازی", zh: "清理后", fr: "Après nettoyage", ar: "بعد التنظيف", tr: "Temizlikten sonra"),
        .goalSuggestionsTotal: ml(en: "Suggestions free %@", fa: "پیشنهادها %@ آزاد می‌کنند", zh: "建议可释放 %@", fr: "Suggestions libèrent %@", ar: "الاقتراحات تحرر %@", tr: "Öneriler %@ boşaltır"),
        .goalScanHint: ml(en: "Scans caches, old downloads, large files, and unused items ranked by safety and size.", fa: "کش، دانلودهای قدیمی، فایل‌های حجیم و موارد بلااستفاده را بر اساس امنیت و حجم اولویت‌بندی می‌کند.", zh: "按安全性和大小扫描缓存、旧下载、大文件和未使用项。", fr: "Analyse caches, anciens téléchargements et gros fichiers par priorité.", ar: "يفحص الذاكرة المؤقتة والتنزيلات القديمة والملفات الكبيرة.", tr: "Önbellek, eski indirmeler ve büyük dosyaları tarar."),
        .goalSuggestionsTitle: ml(en: "Suggested items", fa: "آیتم‌های پیشنهادی", zh: "推荐项目", fr: "Éléments suggérés", ar: "العناصر المقترحة", tr: "Önerilen öğeler"),
        .goalDaysUnused: ml(en: "%d days unused", fa: "%d روز استفاده نشده", zh: "%d 天未使用", fr: "%d jours sans usage", ar: "%d يوم بدون استخدام", tr: "%d gündür kullanılmadı"),
        .goalCategoryCache: ml(en: "Cache", fa: "کش", zh: "缓存", fr: "Cache", ar: "ذاكرة مؤقتة", tr: "Önbellek"),
        .goalCategoryLogs: ml(en: "Logs", fa: "لاگ", zh: "日志", fr: "Journaux", ar: "سجلات", tr: "Günlükler"),
        .goalCategoryTrash: ml(en: "Trash", fa: "سطل", zh: "废纸篓", fr: "Corbeille", ar: "سلة", tr: "Çöp"),
        .goalCategoryInstallers: ml(en: "Installers", fa: "نصب‌کننده", zh: "安装包", fr: "Installateurs", ar: "مثبتات", tr: "Kurulum dosyaları"),
        .goalCategoryOldDownloads: ml(en: "Old Downloads", fa: "دانلودهای قدیمی", zh: "旧下载", fr: "Anciens téléchargements", ar: "تنزيلات قديمة", tr: "Eski indirmeler"),
        .goalCategoryLargeDownloads: ml(en: "Large Downloads", fa: "دانلودهای حجیم", zh: "大下载", fr: "Gros téléchargements", ar: "تنزيلات كبيرة", tr: "Büyük indirmeler"),
        .goalCategoryOldFiles: ml(en: "Unused Files", fa: "فایل‌های بلااستفاده", zh: "未使用文件", fr: "Fichiers inutilisés", ar: "ملفات غير مستخدمة", tr: "Kullanılmayan dosyalar"),
        .goalCategoryDevJunk: ml(en: "Developer", fa: "توسعه‌دهنده", zh: "开发者", fr: "Développeur", ar: "مطور", tr: "Geliştirici"),
        .goalCategoryOther: ml(en: "Other", fa: "سایر", zh: "其他", fr: "Autre", ar: "أخرى", tr: "Diğer"),
        .goalPriorityHigh: ml(en: "Safe", fa: "ایمن", zh: "安全", fr: "Sûr", ar: "آمن", tr: "Güvenli"),
        .goalPriorityMedium: ml(en: "Review", fa: "بررسی", zh: "需审查", fr: "À vérifier", ar: "مراجعة", tr: "İncele"),
        .goalPriorityLow: ml(en: "Caution", fa: "احتیاط", zh: "谨慎", fr: "Prudence", ar: "حذر", tr: "Dikkat"),
        .goalCollectorQueued: ml(en: "%d in Collector", fa: "%d در سطل", zh: "收集器 %d 项", fr: "%d dans le collecteur", ar: "%d في المجمع", tr: "Toplayıcıda %d"),
        .goalWithCollector: ml(en: "Including Collector", fa: "شامل سطل", zh: "含收集器", fr: "Avec collecteur", ar: "يشمل المجمع", tr: "Toplayıcı dahil"),
        .goalStillNeed: ml(en: "Still need", fa: "هنوز لازم", zh: "仍需", fr: "Encore besoin", ar: "لا يزال مطلوب", tr: "Hâlâ gerekli"),
        .exportCSV: ml(en: "Export CSV", fa: "خروجی CSV", zh: "导出CSV", fr: "Exporter CSV", ar: "تصدير CSV", tr: "CSV dışa aktar"),
        .exportJSON: ml(en: "Export JSON", fa: "خروجی JSON", zh: "导出JSON", fr: "Exporter JSON", ar: "تصدير JSON", tr: "JSON dışa aktar"),
        .exportDone: ml(en: "Export saved", fa: "ذخیره شد", zh: "已导出", fr: "Exporté", ar: "تم التصدير", tr: "Kaydedildi"),
        .recentFolders: ml(en: "Recent", fa: "اخیر", zh: "最近", fr: "Récent", ar: "حديث", tr: "Son"),
        .bookmarks: ml(en: "Bookmarks", fa: "نشانک‌ها", zh: "书签", fr: "Favoris", ar: "إشارات", tr: "Yer imleri"),
        .addBookmark: ml(en: "Bookmark folder", fa: "نشانک", zh: "添加书签", fr: "Marquer", ar: "إشارة", tr: "Yer imi"),
        .removeBookmark: ml(en: "Remove bookmark", fa: "حذف نشانک", zh: "移除书签", fr: "Retirer", ar: "إزالة", tr: "Kaldır"),
        .menuBarFree: ml(en: "free", fa: "آزاد", zh: "可用", fr: "libre", ar: "حر", tr: "boş"),
        .menuBarUsed: ml(en: "used", fa: "استفاده", zh: "已用", fr: "utilisé", ar: "مستخدم", tr: "kullanılan"),
        .menuBarOpen: ml(en: "Open LazyDisk", fa: "باز کردن", zh: "打开", fr: "Ouvrir", ar: "فتح", tr: "Aç"),
        .items: ml(en: "items", fa: "آیتم", zh: "项", fr: "éléments", ar: "عناصر", tr: "öğe"),
        .results: ml(en: "%d results", fa: "%d نتیجه", zh: "%d 结果", fr: "%d résultats", ar: "%d نتيجة", tr: "%d sonuç"),
        .filesIndexed: ml(en: "%d indexed", fa: "%d ایندکس", zh: "%d 已索引", fr: "%d indexés", ar: "%d مفهرس", tr: "%d dizinli"),
        .showInFolder: ml(en: "Show in folder", fa: "نمایش", zh: "显示", fr: "Afficher", ar: "عرض", tr: "Göster"),
        .open: ml(en: "Open", fa: "باز کردن", zh: "打开", fr: "Ouvrir", ar: "فتح", tr: "Aç"),
        .revealFinder: ml(en: "Reveal in Finder", fa: "Finder", zh: "在Finder显示", fr: "Finder", ar: "Finder", tr: "Finder"),
        .quickLook: ml(en: "Quick Look", fa: "پیش‌نمایش", zh: "快速查看", fr: "Aperçu", ar: "معاينة", tr: "Hızlı Bakış"),
        .rescan: ml(en: "Rescan", fa: "اسکن مجدد", zh: "重新扫描", fr: "Rescanner", ar: "إعادة فحص", tr: "Yeniden tara"),
        .refresh: ml(en: "Refresh", fa: "بروزرسانی", zh: "刷新", fr: "Actualiser", ar: "تحديث", tr: "Yenile"),
        .permissions: ml(en: "Permissions", fa: "دسترسی‌ها", zh: "权限", fr: "Autorisations", ar: "الأذونات", tr: "İzinler"),
        .permissionsOK: ml(en: "Permissions OK", fa: "دسترسی OK", zh: "权限正常", fr: "OK", ar: "الأذونات OK", tr: "İzinler OK"),
        .scanning: ml(en: "Scanning…", fa: "اسکن…", zh: "扫描…", fr: "Analyse…", ar: "فحص…", tr: "Taranıyor…"),
        .analyzing: ml(en: "Analyzing…", fa: "تحلیل…", zh: "分析…", fr: "Analyse…", ar: "تحليل…", tr: "Analiz…"),
        .welcomeTitle: ml(en: "LazyDisk", fa: "LazyDisk", zh: "LazyDisk", fr: "LazyDisk", ar: "LazyDisk", tr: "LazyDisk"),
        .welcomeSubtitle: ml(en: "Visualize and clean your disk", fa: "دیسک را ببین و تمیز کن", zh: "可视化管理磁盘", fr: "Visualisez votre disque", ar: "عرض وتنظيف القرص", tr: "Diskinizi görün ve temizleyin"),
        .startScan: ml(en: "Start Scan", fa: "شروع اسکن", zh: "开始扫描", fr: "Démarrer", ar: "بدء الفحص", tr: "Taramayı başlat"),
        .grantPermissions: ml(en: "Grant Permissions", fa: "اعطای دسترسی", zh: "授予权限", fr: "Autorisations", ar: "منح الأذونات", tr: "İzin ver"),
        .english: ml(en: "English", fa: "English", zh: "English", fr: "English", ar: "English", tr: "English"),
        .persian: ml(en: "فارسی", fa: "فارسی", zh: "فارسی", fr: "فارسی", ar: "فارسی", tr: "فارسی"),
        .chinese: ml(en: "中文", fa: "中文", zh: "中文", fr: "中文", ar: "中文", tr: "中文"),
        .french: ml(en: "Français", fa: "Français", zh: "Français", fr: "Français", ar: "Français", tr: "Français"),
        .arabic: ml(en: "العربية", fa: "العربية", zh: "العربية", fr: "العربية", ar: "العربية", tr: "العربية"),
        .turkish: ml(en: "Türkçe", fa: "Türkçe", zh: "Türkçe", fr: "Türkçe", ar: "Türkçe", tr: "Türkçe"),
        .welcomeTagline: ml(en: "See exactly what's using your disk space", fa: "ببین چه چیزی فضای دیسک را اشغال کرده", zh: "精确查看磁盘空间占用", fr: "Voyez ce qui utilise votre disque", ar: "اعرف ما يشغل مساحة القرص", tr: "Disk alanınızı tam olarak görün"),
        .selectVolume: ml(en: "Select volume to scan", fa: "انتخاب دیسک برای اسکن", zh: "选择要扫描的磁盘", fr: "Choisir le volume", ar: "اختر القرص للفحص", tr: "Taranacak disk"),
        .totalCapacity: ml(en: "Total capacity", fa: "ظرفیت کل", zh: "总容量", fr: "Capacité totale", ar: "السعة الكلية", tr: "Toplam kapasite"),
        .availableLabel: ml(en: "Available", fa: "موجود", zh: "可用", fr: "Disponible", ar: "متاح", tr: "Kullanılabilir"),
        .continueBtn: ml(en: "Continue", fa: "ادامه", zh: "继续", fr: "Continuer", ar: "متابعة", tr: "Devam"),
        .scanTakeTime: ml(en: "Scanning may take a few minutes depending on disk size", fa: "اسکن بسته به حجم دیسک چند دقیقه طول می‌کشد", zh: "扫描可能需要几分钟", fr: "L'analyse peut prendre quelques minutes", ar: "قد يستغرق الفحص دقائق", tr: "Tarama birkaç dakika sürebilir"),
        .permAllSet: ml(en: "You're All Set!", fa: "همه چیز آماده است!", zh: "一切就绪！", fr: "Tout est prêt !", ar: "كل شيء جاهز!", tr: "Her şey hazır!"),
        .permRequired: ml(en: "Permissions Required", fa: "دسترسی لازم است", zh: "需要权限", fr: "Autorisations requises", ar: "الأذونات مطلوبة", tr: "İzin gerekli"),
        .permAllSetDesc: ml(en: "LazyDisk has everything it needs. Press Start Scan to analyze your disk.", fa: "LazyDisk همه دسترسی‌ها را دارد. اسکن را شروع کن.", zh: "LazyDisk 已准备就绪。开始扫描。", fr: "LazyDisk est prêt. Lancez l'analyse.", ar: "LazyDisk جاهز. ابدأ الفحص.", tr: "LazyDisk hazır. Taramayı başlatın."),
        .permRequiredDesc: ml(en: "Grant access below for a complete disk analysis.\nOne tap opens System Settings for you.", fa: "برای تحلیل کامل، دسترسی‌ها را بده.\nیک کلیک تنظیمات را باز می‌کند.", zh: "授予权限以完整分析磁盘。", fr: "Accordez l'accès pour une analyse complète.", ar: "امنح الوصول للتحليل الكامل.", tr: "Tam analiz için izin verin."),
        .permReadyScan: ml(en: "All permissions granted — ready to scan", fa: "همه دسترسی‌ها داده شد — آماده اسکن", zh: "权限已授予 — 可以扫描", fr: "Autorisations accordées — prêt", ar: "الأذونات ممنوحة — جاهز", tr: "İzinler verildi — hazır"),
        .permGrantedCount: ml(en: "%d of %d granted", fa: "%d از %d داده شد", zh: "已授予 %d/%d", fr: "%d sur %d accordées", ar: "%d من %d ممنوحة", tr: "%d / %d verildi"),
        .permTerminalTitle: ml(en: "Running from Terminal?", fa: "از ترمینال اجرا می‌کنی؟", zh: "从终端运行？", fr: "Depuis le Terminal ?", ar: "تشغيل من الطرفية؟", tr: "Terminalden mi?"),
        .permTerminalHint: ml(en: "Grant Full Disk Access to Terminal (or iTerm), not LazyDisk. For best results: open dist/LazyDisk.app", fa: "Full Disk Access را به Terminal بده. بهتر: dist/LazyDisk.app", zh: "将完全磁盘访问授予终端。", fr: "Accordez l'accès au Terminal.", ar: "امنح الوصول للطرفية.", tr: "Tam Disk Erişimini Terminal'e verin."),
        .back: ml(en: "Back", fa: "برگشت", zh: "返回", fr: "Retour", ar: "رجوع", tr: "Geri"),
        .openSettings: ml(en: "Open Settings", fa: "باز کردن تنظیمات", zh: "打开设置", fr: "Ouvrir Réglages", ar: "فتح الإعدادات", tr: "Ayarları aç"),
        .scanAnyway: ml(en: "Scan Anyway", fa: "اسکن بدون دسترسی", zh: "仍然扫描", fr: "Analyser quand même", ar: "فحص على أي حال", tr: "Yine de tara"),
        .grantAllPerms: ml(en: "Grant All Permissions", fa: "اعطای همه دسترسی‌ها", zh: "授予所有权限", fr: "Tout autoriser", ar: "منح كل الأذونات", tr: "Tüm izinleri ver"),
        .prefScanning: ml(en: "Scanning", fa: "اسکن", zh: "扫描", fr: "Analyse", ar: "الفحص", tr: "Tarama"),
        .prefDisplay: ml(en: "Display", fa: "نمایش", zh: "显示", fr: "Affichage", ar: "العرض", tr: "Görünüm"),
        .prefDefaultSort: ml(en: "Default sort", fa: "مرتب‌سازی پیش‌فرض", zh: "默认排序", fr: "Tri par défaut", ar: "الترتيب الافتراضي", tr: "Varsayılan sıralama"),
        .done: ml(en: "Done", fa: "تمام", zh: "完成", fr: "Terminé", ar: "تم", tr: "Bitti"),
        .ok: ml(en: "OK", fa: "باشه", zh: "好", fr: "OK", ar: "موافق", tr: "Tamam"),
        .errorTitle: ml(en: "Error", fa: "خطا", zh: "错误", fr: "Erreur", ar: "خطأ", tr: "Hata"),
        .emptyFolder: ml(en: "Empty folder", fa: "فولدر خالی", zh: "空文件夹", fr: "Dossier vide", ar: "مجلد فارغ", tr: "Boş klasör"),
        .diskLabel: ml(en: "Disk", fa: "دیسک", zh: "磁盘", fr: "Disque", ar: "القرص", tr: "Disk"),
        .folderLabel: ml(en: "Folder", fa: "فولدر", zh: "文件夹", fr: "Dossier", ar: "مجلد", tr: "Klasör"),
        .volumeLabel: ml(en: "Volume", fa: "دیسک", zh: "卷", fr: "Volume", ar: "القرص", tr: "Birim"),
        .goUp: ml(en: "Go up", fa: "برگشت", zh: "上一级", fr: "Monter", ar: "أعلى", tr: "Yukarı"),
        .selectAll: ml(en: "Select All", fa: "انتخاب همه", zh: "全选", fr: "Tout sélectionner", ar: "تحديد الكل", tr: "Tümünü seç"),
        .menuNavigate: ml(en: "Navigate", fa: "ناوبری", zh: "导航", fr: "Naviguer", ar: "تنقل", tr: "Gezin"),
        .menuSortBy: ml(en: "Sort By", fa: "مرتب‌سازی", zh: "排序", fr: "Trier par", ar: "ترتيب حسب", tr: "Sırala"),
        .menuFile: ml(en: "File", fa: "فایل", zh: "文件", fr: "Fichier", ar: "ملف", tr: "Dosya"),
        .goalReached: ml(en: "Goal reached!", fa: "به هدف رسیدی!", zh: "目标达成！", fr: "Objectif atteint !", ar: "تم الوصول للهدف!", tr: "Hedefe ulaşıldı!"),
        .goalNeedMore: ml(en: "Need %@ more", fa: "%@ دیگر لازم است", zh: "还需 %@", fr: "Encore %@ nécessaires", ar: "بحاجة إلى %@ إضافية", tr: "%@ daha gerekli"),
        .dupWaste: ml(en: "Waste: %@", fa: "اتلاف: %@", zh: "浪费: %@", fr: "Gaspillage : %@", ar: "هدر: %@", tr: "İsraf: %@"),
        .dupCopiesCount: ml(en: "%d copies", fa: "%d کپی", zh: "%d 个副本", fr: "%d copies", ar: "%d نسخ", tr: "%d kopya"),
        .hiddenLabel: ml(en: "hidden", fa: "مخفی", zh: "隐藏", fr: "caché", ar: "مخفي", tr: "gizli"),
        .itemsSelected: ml(en: "%d selected", fa: "%d انتخاب", zh: "已选 %d", fr: "%d sélectionnés", ar: "%d محدد", tr: "%d seçili"),
        .hintSidebar: ml(en: "Click open · ⌘ select · ⇧ range · drag → Collector · %@", fa: "کلیک باز · ⌘ انتخاب · ⇧ بازه · کشیدن → سطل · %@", zh: "点击打开 · ⌘选择 · ⇧范围 · 拖到收集器 · %@", fr: "Clic · ⌘ sélect · ⇧ plage · glisser → Collecteur · %@", ar: "نقر · ⌘ تحديد · ⇧ نطاق · سحب → المجمع · %@", tr: "Tıkla · ⌘ seç · ⇧ aralık · sürükle → Toplayıcı · %@"),
        .permFullDiskTitle: ml(en: "Full Disk Access", fa: "دسترسی کامل دیسک", zh: "完全磁盘访问", fr: "Accès complet au disque", ar: "وصول كامل للقرص", tr: "Tam Disk Erişimi"),
        .permFullDiskDesc: ml(en: "Scan system folders, caches, hidden files, and other users' data", fa: "اسکن فولدرهای سیستم، کش، فایل‌های مخفی", zh: "扫描系统文件夹、缓存和隐藏文件", fr: "Analyser dossiers système et caches", ar: "فحص مجلدات النظام والملفات المخفية", tr: "Sistem klasörleri ve önbellekler"),
        .permUserFilesTitle: ml(en: "Files & Folders", fa: "فایل‌ها و فولدرها", zh: "文件和文件夹", fr: "Fichiers et dossiers", ar: "الملفات والمجلدات", tr: "Dosyalar ve klasörler"),
        .permUserFilesDesc: ml(en: "Access Documents, Desktop, Downloads, and Library", fa: "دسترسی به Documents، Desktop، Downloads", zh: "访问文稿、桌面、下载", fr: "Accès Documents, Bureau, Téléchargements", ar: "الوصول للمستندات وسطح المكتب", tr: "Belgeler, Masaüstü, İndirilenler"),
        .permRemovableTitle: ml(en: "Removable Volumes", fa: "دیسک‌های خارجی", zh: "可移动卷", fr: "Volumes amovibles", ar: "أقراص قابلة للإزالة", tr: "Çıkarılabilir birimler"),
        .permRemovableDesc: ml(en: "Analyze external drives and USB volumes", fa: "تحلیل درایوهای USB", zh: "分析外部驱动器", fr: "Analyser disques externes", ar: "تحليل الأقراص الخارجية", tr: "Harici sürücüleri analiz et"),
        .permCleanupTitle: ml(en: "Trash & Cleanup", fa: "سطل و پاکسازی", zh: "废纸篓和清理", fr: "Corbeille et nettoyage", ar: "السلة والتنظيف", tr: "Çöp ve temizlik"),
        .permCleanupDesc: ml(en: "Delete files and folders permanently", fa: "حذف دائمی فایل‌ها و پوشه‌ها", zh: "永久删除文件和文件夹", fr: "Supprimer définitivement fichiers et dossiers", ar: "حذف الملفات والمجلدات نهائياً", tr: "Dosya ve klasörleri kalıcı olarak sil"),
        .dupPhaseCollect: ml(en: "Collecting files…", fa: "جمع‌آوری فایل‌ها…", zh: "收集文件…", fr: "Collecte…", ar: "جمع الملفات…", tr: "Dosyalar toplanıyor…"),
        .dupPhaseHash: ml(en: "Hashing candidates…", fa: "هش کردن…", zh: "哈希候选…", fr: "Hachage…", ar: "تجزئة…", tr: "Hashleniyor…"),
        .historyAdded: ml(en: "Added", fa: "اضافه شده", zh: "新增", fr: "Ajouté", ar: "مضاف", tr: "Eklenen"),
        .historyRemoved: ml(en: "Removed", fa: "حذف شده", zh: "移除", fr: "Supprimé", ar: "محذوف", tr: "Kaldırılan"),
        .historyChanged: ml(en: "Changed", fa: "تغییر یافته", zh: "已更改", fr: "Modifié", ar: "متغير", tr: "Değişen"),
        .menuBarTotal: ml(en: "Total", fa: "کل", zh: "总计", fr: "Total", ar: "الإجمالي", tr: "Toplam"),
        .menuBarPercent: ml(en: "%d%% used", fa: "%d%% استفاده", zh: "已用 %d%%", fr: "%d%% utilisé", ar: "%d%% مستخدم", tr: "%d%% kullanılan"),
        .errorDeleteFailed: ml(en: "Failed to delete: %@", fa: "حذف ناموفق: %@", zh: "删除失败: %@", fr: "Échec suppression : %@", ar: "فشل الحذف: %@", tr: "Silinemedi: %@"),
        .errorCannotDelete: ml(en: "Cannot delete system-protected or virtual items.", fa: "حذف آیتم‌های محافظت‌شده ممکن نیست.", zh: "无法删除受保护项。", fr: "Suppression impossible.", ar: "لا يمكن الحذف.", tr: "Korumalı öğeler silinemez."),
        .errorCannotDeleteLibraryContainer: ml(en: "The Caches or Logs folder cannot be deleted as a whole. Select individual items inside it instead.", fa: "پوشه Caches یا Logs را نمی‌توان یکجا حذف کرد. آیتم‌های داخل آن را جداگانه انتخاب کنید.", zh: "无法整体删除 Caches 或 Logs 文件夹。请改为选择其中的单个项目。", fr: "Le dossier Caches ou Logs ne peut pas être supprimé en entier. Sélectionnez les éléments qu'il contient.", ar: "لا يمكن حذف مجلد Caches أو Logs بالكامل. اختر العناصر داخله بدلاً من ذلك.", tr: "Caches veya Logs klasörü bir bütün olarak silinemez. Bunun yerine içindeki öğeleri seçin."),
        .suggestionsCount: ml(en: "%d suggestions", fa: "%d پیشنهاد", zh: "%d 条建议", fr: "%d suggestions", ar: "%d اقتراح", tr: "%d öneri"),
        .scanProgressFmt: ml(en: "%d / %d", fa: "%d / %d", zh: "%d / %d", fr: "%d / %d", ar: "%d / %d", tr: "%d / %d"),
        .scanningDiskTitle: ml(en: "Scanning Disk", fa: "در حال اسکن دیسک", zh: "正在扫描磁盘", fr: "Analyse du disque", ar: "فحص القرص", tr: "Disk taranıyor"),
        .scanPreparing: ml(en: "Preparing scan…", fa: "آماده‌سازی اسکن…", zh: "准备扫描…", fr: "Préparation…", ar: "تحضير الفحص…", tr: "Tarama hazırlanıyor…"),
        .scanReadingList: ml(en: "Reading folder list…", fa: "خواندن لیست فولدر…", zh: "读取文件夹列表…", fr: "Lecture des dossiers…", ar: "قراءة المجلدات…", tr: "Klasör listesi okunuyor…"),
        .scanFoundItems: ml(en: "Found %d items — measuring sizes…", fa: "%d آیتم یافت شد — اندازه‌گیری…", zh: "找到 %d 项 — 测量大小…", fr: "%d éléments — mesure…", ar: "وُجد %d عنصر — قياس…", tr: "%d öğe bulundu — ölçülüyor…"),
        .scanFolderNamed: ml(en: "Scanning %@…", fa: "اسکن %@…", zh: "扫描 %@…", fr: "Analyse de %@…", ar: "فحص %@…", tr: "%@ taranıyor…"),
        .scanFoldersProgress: ml(en: "Scanning %d of %d folders…", fa: "اسکن %d از %d فولدر…", zh: "扫描 %d / %d 文件夹…", fr: "Analyse %d sur %d dossiers…", ar: "فحص %d من %d مجلد…", tr: "%d / %d klasör taranıyor…"),
        .scanFinalizing: ml(en: "Finalizing results…", fa: "نهایی‌سازی نتایج…", zh: "完成结果…", fr: "Finalisation…", ar: "إنهاء النتائج…", tr: "Sonuçlar tamamlanıyor…"),
        .scanCaching: ml(en: "Caching subfolders…", fa: "کش کردن زیرفولدرها…", zh: "缓存子文件夹…", fr: "Mise en cache…", ar: "تخزين المجلدات…", tr: "Alt klasörler önbelleğe alınıyor…"),
        .scanCachingFolders: ml(en: "Caching %d of %d folders…", fa: "کش %d از %d فولدر…", zh: "缓存 %d / %d 文件夹…", fr: "Cache %d sur %d…", ar: "تخزين %d من %d…", tr: "%d / %d klasör önbelleğe alınıyor…"),
        .percentFmt: ml(en: "%d%%", fa: "%d%%", zh: "%d%%", fr: "%d%%", ar: "%d%%", tr: "%d%%"),
        .progressStepFmt: ml(en: "Step %d of %d", fa: "مرحله %d از %d", zh: "步骤 %d / %d", fr: "Étape %d sur %d", ar: "الخطوة %d من %d", tr: "Adım %d / %d"),
        .donateTitle: ml(en: "Support LazyDisk", fa: "حمایت از LazyDisk", zh: "支持 LazyDisk", fr: "Soutenir LazyDisk", ar: "ادعم LazyDisk", tr: "LazyDisk'i destekle"),
        .donateSubtitle: ml(en: "Open-source and free. Your donation helps keep development going.", fa: "متن‌باز و رایگان. حمایت شما به ادامه توسعه کمک می‌کند.", zh: "开源免费。您的捐赠有助于持续开发。", fr: "Open source et gratuit. Votre don aide à poursuivre le développement.", ar: "مفتوح المصدر ومجاني. تبرعك يساعد على استمرار التطوير.", tr: "Açık kaynak ve ücretsiz. Bağışınız geliştirmeye devam etmemize yardımcı olur."),
        .donateThankYou: ml(en: "Every contribution means a lot — thank you!", fa: "هر حمایتی ارزشمند است — ممنون!", zh: "每一份支持都很珍贵 — 谢谢！", fr: "Chaque contribution compte — merci !", ar: "كل مساهمة مهمة — شكراً!", tr: "Her katkı çok değerli — teşekkürler!"),
        .donateCopy: ml(en: "Copy Address", fa: "کپی آدرس", zh: "复制地址", fr: "Copier l'adresse", ar: "نسخ العنوان", tr: "Adresi kopyala"),
        .donateCopied: ml(en: "Copied!", fa: "کپی شد!", zh: "已复制！", fr: "Copié !", ar: "تم النسخ!", tr: "Kopyalandı!"),
        .donateAllNetworks: ml(en: "All networks", fa: "همه شبکه‌ها", zh: "所有网络", fr: "Tous les réseaux", ar: "جميع الشبكات", tr: "Tüm ağlar"),
        .donateSupport: ml(en: "Support the project", fa: "حمایت از پروژه", zh: "支持项目", fr: "Soutenir le projet", ar: "ادعم المشروع", tr: "Projeyi destekle"),
        .menuDonate: ml(en: "Donate…", fa: "حمایت مالی…", zh: "捐赠…", fr: "Faire un don…", ar: "تبرع…", tr: "Bağış yap…"),
        .chartNoData: ml(en: "No data to display", fa: "داده‌ای برای نمایش نیست", zh: "无数据可显示", fr: "Aucune donnée", ar: "لا توجد بيانات", tr: "Gösterilecek veri yok"),
        .itemsCount: ml(en: "%d items", fa: "%d آیتم", zh: "%d 项", fr: "%d éléments", ar: "%d عنصر", tr: "%d öğe"),
        .dupGroupsCount: ml(en: "%d groups", fa: "%d گروه", zh: "%d 组", fr: "%d groupes", ar: "%d مجموعة", tr: "%d grup"),
        .devFoldersCount: ml(en: "%d folders", fa: "%d فولدر", zh: "%d 文件夹", fr: "%d dossiers", ar: "%d مجلد", tr: "%d klasör"),
        .removeFromCollector: ml(en: "Remove from Collector", fa: "حذف از سطل", zh: "从收集器移除", fr: "Retirer du collecteur", ar: "إزالة من المجمع", tr: "Toplayıcıdan kaldır"),
        .overviewVolume: ml(en: "Volume", fa: "دیسک", zh: "卷", fr: "Volume", ar: "القرص", tr: "Birim"),
        .overviewUsed: ml(en: "Used", fa: "استفاده‌شده", zh: "已用", fr: "Utilisé", ar: "مستخدم", tr: "Kullanılan"),
        .overviewAvailable: ml(en: "Available", fa: "آزاد", zh: "可用", fr: "Disponible", ar: "متاح", tr: "Boş"),
        .overviewCurrentFolder: ml(en: "Current folder", fa: "فولدر فعلی", zh: "当前文件夹", fr: "Dossier actuel", ar: "المجلد الحالي", tr: "Geçerli klasör"),
        .overviewOfSize: ml(en: "of %@", fa: "از %@", zh: "共 %@", fr: "sur %@", ar: "من %@", tr: "/ %@"),
        .warnIOSBackupTitle: ml(en: "iOS Device Backup", fa: "پشتیبان iOS", zh: "iOS 设备备份", fr: "Sauvegarde iOS", ar: "نسخة iOS احتياطية", tr: "iOS yedekleme"),
        .warnIOSBackupMsg: ml(en: "These folders contain iPhone/iPad backups. Deleting them removes device backups permanently.", fa: "این فولدرها شامل پشتیبان iPhone/iPad است. حذف آن‌ها پشتیبان را برای همیشه از بین می‌برد.", zh: "这些文件夹包含 iPhone/iPad 备份。删除将永久移除备份。", fr: "Ces dossiers contiennent des sauvegardes iPhone/iPad. La suppression est définitive.", ar: "تحتوي هذه المجلدات على نسخ iPhone/iPad احتياطية. الحذف نهائي.", tr: "Bu klasörler iPhone/iPad yedekleri içerir. Silmek kalıcıdır."),
        .warnTimeMachineTitle: ml(en: "Time Machine Data", fa: "داده Time Machine", zh: "Time Machine 数据", fr: "Données Time Machine", ar: "بيانات Time Machine", tr: "Time Machine verisi"),
        .warnTimeMachineMsg: ml(en: "These items may be related to Time Machine snapshots or backups.", fa: "این آیتم‌ها ممکن است مربوط به اسنپ‌شات یا پشتیبان Time Machine باشند.", zh: "这些项目可能与 Time Machine 快照或备份有关。", fr: "Ces éléments peuvent être liés à Time Machine.", ar: "قد تكون مرتبطة بـ Time Machine.", tr: "Time Machine anlık görüntüleriyle ilgili olabilir."),
        .warnSystemTitle: ml(en: "System Files", fa: "فایل‌های سیستم", zh: "系统文件", fr: "Fichiers système", ar: "ملفات النظام", tr: "Sistem dosyaları"),
        .warnSystemMsg: ml(en: "Deleting system files can break macOS. These items are strongly protected.", fa: "حذف فایل‌های سیستم می‌تواند macOS را خراب کند. این آیتم‌ها به‌شدت محافظت شده‌اند.", zh: "删除系统文件可能破坏 macOS。这些项目受严格保护。", fr: "Supprimer des fichiers système peut endommager macOS.", ar: "حذف ملفات النظام قد يتلف macOS.", tr: "Sistem dosyalarını silmek macOS'u bozabilir."),
        .warnRunningAppTitle: ml(en: "Running Applications", fa: "برنامه‌های در حال اجرا", zh: "正在运行的应用", fr: "Applications en cours", ar: "تطبيقات قيد التشغيل", tr: "Çalışan uygulamalar"),
        .warnRunningAppMsg: ml(en: "These applications are currently running. Quit them before deleting.", fa: "این برنامه‌ها در حال اجرا هستند. قبل از حذف آن‌ها را ببندید.", zh: "这些应用正在运行。删除前请先退出。", fr: "Ces applications sont en cours d'exécution. Quittez-les avant de supprimer.", ar: "هذه التطبيقات قيد التشغيل. أغلقها قبل الحذف.", tr: "Bu uygulamalar çalışıyor. Silmeden önce kapatın."),
        .warnLibraryTitle: ml(en: "Important Library Data", fa: "داده مهم Library", zh: "重要库数据", fr: "Données Library importantes", ar: "بيانات Library مهمة", tr: "Önemli Library verisi"),
        .warnLibraryMsg: ml(en: "These Library folders may contain mail, keychain data, or app settings.", fa: "این فولدرهای Library ممکن است شامل ایمیل، keychain یا تنظیمات برنامه باشند.", zh: "这些 Library 文件夹可能包含邮件、钥匙串或应用设置。", fr: "Ces dossiers Library peuvent contenir mail, trousseau ou réglages.", ar: "قد تحتوي على بريد أو keychain أو إعدادات.", tr: "Mail, anahtar zinciri veya uygulama ayarları içerebilir."),
        .warnBulkDeleteTitle: ml(en: "Bulk Delete", fa: "حذف گروهی", zh: "批量删除", fr: "Suppression groupée", ar: "حذف جماعي", tr: "Toplu silme"),
        .warnBulkDeleteMsg: ml(en: "You are about to delete %d items. Review carefully before confirming.", fa: "در حال حذف %d آیتم هستید. قبل از تأیید با دقت بررسی کنید.", zh: "即将删除 %d 个项目。请仔细确认。", fr: "Vous allez supprimer %d éléments. Vérifiez avant de confirmer.", ar: "أنت على وشك حذف %d عنصر. راجع بعناية.", tr: "%d öğe silinecek. Onaylamadan önce kontrol edin."),
        .deleteSummaryOne: ml(en: "Delete 1 item (%@) permanently?", fa: "۱ آیتم (%@) برای همیشه حذف شود؟", zh: "永久删除 1 个项目 (%@)？", fr: "Supprimer définitivement 1 élément (%@) ?", ar: "حذف عنصر واحد (%@) نهائياً؟", tr: "1 öğe (%@) kalıcı olarak silinsin mi?"),
        .deleteSummaryMany: ml(en: "Delete %d items (%@) permanently?", fa: "%d آیتم (%@) برای همیشه حذف شوند؟", zh: "永久删除 %d 个项目 (%@)？", fr: "Supprimer définitivement %d éléments (%@) ?", ar: "حذف %d عنصر (%@) نهائياً؟", tr: "%d öğe (%@) kalıcı olarak silinsin mi?"),
        .chartStyleRose: ml(en: "Rose", fa: "گل‌رز", zh: "玫瑰图", fr: "Rose", ar: "وردي", tr: "Gül"),
        .chartStyleSunburst: ml(en: "Sunburst", fa: "خورشیدی", zh: "旭日图", fr: "Sunburst", ar: "شمسي", tr: "Sunburst"),
        .chartStyleTreemap: ml(en: "Treemap", fa: "نقشه درختی", zh: "树状图", fr: "Treemap", ar: "خريطة شجرية", tr: "Treemap"),
        .chartUsedLabel: ml(en: "used", fa: "استفاده‌شده", zh: "已用", fr: "utilisé", ar: "مستخدم", tr: "kullanılan"),
        .chartHintDrillDown: ml(en: "Click segment to drill down", fa: "کلیک برای ورود", zh: "点击扇区深入", fr: "Cliquer pour explorer", ar: "انقر للتعمق", tr: "Detay için tıkla"),
        .chartHintSelect: ml(en: "Click to view details", fa: "کلیک برای جزئیات", zh: "点击查看详情", fr: "Cliquer pour les détails", ar: "انقر للتفاصيل", tr: "Detay için tıkla"),
        .prefChartStyle: ml(en: "Chart style", fa: "نوع نمودار", zh: "图表样式", fr: "Style de graphique", ar: "نمط الرسم", tr: "Grafik stili"),
        .collectionTitle: ml(en: "Smart Collections", fa: "مجموعه‌های هوشمند", zh: "智能集合", fr: "Collections intelligentes", ar: "مجموعات ذكية", tr: "Akıllı koleksiyonlar"),
        .collectionLargeFiles: ml(en: "Large Files", fa: "فایل‌های بزرگ", zh: "大文件", fr: "Gros fichiers", ar: "ملفات كبيرة", tr: "Büyük dosyalar"),
        .collectionLargeFilesDesc: ml(en: "Files over 1 GB", fa: "بیش از ۱ گیگابایت", zh: "超过 1 GB", fr: "Plus de 1 Go", ar: "أكبر من 1 GB", tr: "1 GB üzeri"),
        .collectionOldFiles: ml(en: "Old Files", fa: "فایل‌های قدیمی", zh: "旧文件", fr: "Anciens fichiers", ar: "ملفات قديمة", tr: "Eski dosyalar"),
        .collectionOldFilesDesc: ml(en: "Not modified in 6+ months", fa: "بدون تغییر ۶+ ماه", zh: "6 个月以上未修改", fr: "Non modifiés depuis 6+ mois", ar: "لم تُعدّل منذ 6+ أشهر", tr: "6+ ay değişmemiş"),
        .collectionXcode: ml(en: "Xcode Junk", fa: "زباله Xcode", zh: "Xcode 垃圾", fr: "Déchets Xcode", ar: "مخلفات Xcode", tr: "Xcode çöpü"),
        .collectionXcodeDesc: ml(en: "DerivedData, Archives…", fa: "DerivedData، Archives…", zh: "DerivedData、Archives…", fr: "DerivedData, Archives…", ar: "DerivedData، Archives…", tr: "DerivedData, Archives…"),
        .collectionNodeModules: ml(en: "node_modules", fa: "node_modules", zh: "node_modules", fr: "node_modules", ar: "node_modules", tr: "node_modules"),
        .collectionNodeModulesDesc: ml(en: "Dependency folders", fa: "فولدرهای وابستگی", zh: "依赖文件夹", fr: "Dossiers de dépendances", ar: "مجلدات التبعيات", tr: "Bağımlılık klasörleri"),
        .collectionOldDownloads: ml(en: "Old Downloads", fa: "دانلودهای قدیمی", zh: "旧下载", fr: "Anciens téléchargements", ar: "تنزيلات قديمة", tr: "Eski indirmeler"),
        .collectionOldDownloadsDesc: ml(en: "Downloads older than 30 days", fa: "بیش از ۳۰ روز", zh: "超过 30 天", fr: "Plus de 30 jours", ar: "أقدم من 30 يومًا", tr: "30 günden eski"),
        .collectionScanning: ml(en: "Scanning collection…", fa: "در حال اسکن مجموعه…", zh: "正在扫描集合…", fr: "Analyse de la collection…", ar: "جارٍ فحص المجموعة…", tr: "Koleksiyon taranıyor…"),
        .collectionActive: ml(en: "Collection", fa: "مجموعه", zh: "集合", fr: "Collection", ar: "مجموعة", tr: "Koleksiyon"),
        .detailTitle: ml(en: "Details", fa: "جزئیات", zh: "详情", fr: "Détails", ar: "التفاصيل", tr: "Detaylar"),
        .detailPath: ml(en: "Path", fa: "مسیر", zh: "路径", fr: "Chemin", ar: "المسار", tr: "Yol"),
        .detailCreated: ml(en: "Created", fa: "ایجاد", zh: "创建", fr: "Créé", ar: "أُنشئ", tr: "Oluşturulma"),
        .detailItemCount: ml(en: "Items", fa: "آیتم‌ها", zh: "项目", fr: "Éléments", ar: "عناصر", tr: "Öğeler"),
        .detailOpenFolder: ml(en: "Open Folder", fa: "باز کردن فولدر", zh: "打开文件夹", fr: "Ouvrir le dossier", ar: "فتح المجلد", tr: "Klasörü aç"),
        .detailShowLargeFiles: ml(en: "Large Files Here", fa: "فایل‌های بزرگ اینجا", zh: "此处大文件", fr: "Gros fichiers ici", ar: "ملفات كبيرة هنا", tr: "Buradaki büyük dosyalar"),
        .detailShowDetails: ml(en: "Show Details", fa: "نمایش جزئیات", zh: "显示详情", fr: "Afficher les détails", ar: "عرض التفاصيل", tr: "Detayları göster"),
        .cleanupCollectionsHint: ml(en: "Old downloads are listed in Browse → Smart Collections:", fa: "دانلودهای قدیمی در مرورگر → مجموعه‌های هوشمند:", zh: "旧下载见浏览 → 智能集合：", fr: "Anciens téléchargements dans Parcourir → Collections :", ar: "التنزيلات القديمة في التصفح → المجموعات:", tr: "Eski indirmeler Gözat → Akıllı koleksiyonlar:"),
        .devCollectionsHint: ml(en: "Xcode junk and volume-wide node_modules → Browse → Smart Collections:", fa: "زباله Xcode و node_modules سراسری → مرورگر → مجموعه‌های هوشمند:", zh: "Xcode 垃圾和全盘 node_modules → 浏览 → 智能集合：", fr: "Déchets Xcode et node_modules → Parcourir → Collections :", ar: "مخلفات Xcode و node_modules → التصفح → المجموعات:", tr: "Xcode çöpü ve node_modules → Gözat → Akıllı koleksiyonlar:"),
        .finderAnalyzeVolumeNotFound: ml(en: "That folder is not on a disk LazyDisk can scan.", fa: "این فولدر روی دیسکی نیست که LazyDisk بتواند اسکن کند.", zh: "该文件夹不在 LazyDisk 可扫描的磁盘上。", fr: "Ce dossier n'est pas sur un volume analysable par LazyDisk.", ar: "هذا المجلد ليس على قرص يمكن لـ LazyDisk فحصه.", tr: "Bu klasör LazyDisk'in tarayabileceği bir diskte değil."),
        .finderAnalyzeHelp: ml(en: "Finder → right-click → Quick Actions → Analyze with LazyDisk (enable under System Settings → Privacy → Extensions → Finder).", fa: "Finder → کلیک راست → Quick Actions → Analyze with LazyDisk (از System Settings → Privacy → Extensions → Finder فعال کنید).", zh: "Finder → 右键 → 快速操作 → Analyze with LazyDisk（在系统设置 → 隐私 → 扩展 → Finder 中启用）。", fr: "Finder → clic droit → Actions rapides → Analyze with LazyDisk.", ar: "Finder → نقرة يمين → إجراءات سريعة → Analyze with LazyDisk.", tr: "Finder → sağ tık → Hızlı Eylemler → Analyze with LazyDisk."),
        .menuAbout: ml(en: "About LazyDisk", fa: "درباره LazyDisk", zh: "关于 LazyDisk", fr: "À propos de LazyDisk", ar: "حول LazyDisk", tr: "LazyDisk Hakkında"),
        .aboutTagline: ml(en: "A native macOS disk space analyzer", fa: "تحلیل‌گر فضای دیسک بومی macOS", zh: "原生 macOS 磁盘空间分析器", fr: "Analyseur d'espace disque macOS natif", ar: "محلل مساحة القرص الأصلي لـ macOS", tr: "Yerel macOS disk alanı analizörü"),
        .aboutVersion: ml(en: "Version", fa: "نسخه", zh: "版本", fr: "Version", ar: "الإصدار", tr: "Sürüm"),
        .aboutDeveloper: ml(en: "Developer", fa: "توسعه‌دهنده", zh: "开发者", fr: "Développeur", ar: "المطور", tr: "Geliştirici"),
        .aboutCopyright: ml(en: "Copyright", fa: "حق نشر", zh: "版权", fr: "Copyright", ar: "حقوق النشر", tr: "Telif hakkı"),
        .aboutLicense: ml(en: "License", fa: "مجوز", zh: "许可证", fr: "Licence", ar: "الترخيص", tr: "Lisans"),
        .aboutGitHub: ml(en: "View on GitHub", fa: "مشاهده در GitHub", zh: "在 GitHub 上查看", fr: "Voir sur GitHub", ar: "عرض على GitHub", tr: "GitHub'da görüntüle"),
        .modeSelectTitle: ml(en: "Choose your experience", fa: "تجربه خود را انتخاب کنید", zh: "选择体验模式", fr: "Choisissez votre expérience", ar: "اختر تجربتك", tr: "Deneyiminizi seçin"),
        .modeSimple: ml(en: "Simple", fa: "ساده", zh: "简洁", fr: "Simple", ar: "بسيط", tr: "Basit"),
        .modeSimpleDesc: ml(en: "Sunburst chart & file list", fa: "نمودار و لیست فایل", zh: "旭日图和文件列表", fr: "Graphique et liste", ar: "مخطط وقائمة ملفات", tr: "Güneş grafiği ve dosya listesi"),
        .modeProfessional: ml(en: "Professional", fa: "حرفه‌ای", zh: "专业", fr: "Professionnel", ar: "احترافي", tr: "Profesyonel"),
        .modeProfessionalDesc: ml(en: "Full features & tools", fa: "تمام امکانات و ابزارها", zh: "完整功能和工具", fr: "Toutes les fonctions", ar: "جميع الميزات والأدوات", tr: "Tüm özellikler ve araçlar"),
        .prefInterfaceMode: ml(en: "Interface mode", fa: "حالت رابط", zh: "界面模式", fr: "Mode d'interface", ar: "وضع الواجهة", tr: "Arayüz modu"),
        .simpleChartScanning: ml(en: "Scanning subfolders…", fa: "در حال اسکن زیرپوشه‌ها…", zh: "正在扫描子文件夹…", fr: "Analyse des sous-dossiers…", ar: "جارٍ فحص المجلدات الفرعية…", tr: "Alt klasörler taranıyor…"),
        .simpleChartScanProgress: ml(en: "%d of %d folders", fa: "%d از %d فولدر", zh: "%d / %d 文件夹", fr: "%d sur %d dossiers", ar: "%d من %d مجلد", tr: "%d / %d klasör"),
        .simpleChartScanRemaining: ml(en: "%d remaining", fa: "%d باقی‌مانده", zh: "剩余 %d", fr: "%d restants", ar: "%d متبقٍ", tr: "%d kaldı"),
        .simpleChartScanCurrent: ml(en: "Scanning: %@", fa: "در حال اسکن: %@", zh: "正在扫描：%@", fr: "Analyse : %@", ar: "جارٍ فحص: %@", tr: "Taranıyor: %@"),
        .simpleChartScanRing: ml(en: "Ring %d of %d", fa: "حلقه %d از %d", zh: "第 %d / %d 环", fr: "Anneau %d sur %d", ar: "الحلقة %d من %d", tr: "Halka %d / %d"),
        .simpleChartScanFiles: ml(en: "%d files indexed", fa: "%d فایل بررسی شد", zh: "已索引 %d 个文件", fr: "%d fichiers indexés", ar: "تم فهرسة %d ملف", tr: "%d dosya tarandı"),
    ]

    private static func ml(en: String, fa: String, zh: String, fr: String, ar: String, tr: String) -> [AppLanguage: String] {
        [.english: en, .persian: fa, .chinese: zh, .french: fr, .arabic: ar, .turkish: tr]
    }
}
