import AppKit
import Foundation

extension Notification.Name {
    static let clipboardEnvyMenuWillOpen = Notification.Name("clipboardEnvyMenuWillOpen")
    static let clipboardEnvyMenuDidClose = Notification.Name("clipboardEnvyMenuDidClose")
}

@MainActor
enum MenuOpenBridge {
    private final class Observer: NSObject {
        @objc func menuWillTrack(_ notification: Notification) {
            guard let menu = notification.object as? NSMenu else { return }
            // Only the root status menu opening should trigger a refresh.
            guard menu.supermenu == nil else { return }
            beginTracking(menu: menu)
        }

        @objc func menuDidEndTracking(_ notification: Notification) {
            guard let menu = notification.object as? NSMenu else { return }
            // Only clear tracking state when the root menu ends tracking.
            guard menu.supermenu == nil else { return }
            endTracking(menu: menu)
        }
    }

    private static var isInstalled = false
    private static var menuObserver: Observer?
    private static var trackingMenu: NSMenu?
    private static var optionMonitors: [Any] = []
    private static var optionPollTimer: Timer?
    private static var lastOptionVisibility: Bool?
    private static let testDataMenuTitle = TransformMenuTitles.testData
    private static let managedTransformSubmenuKeys = TransformMenuTitles.managedSubmenuKeys
    private static var transformSubmenusVisibleWithoutOption: Set<String> = []
    private static var transformMenuLabelsContext: TransformMenuLabelsContext?
    private static var showAllItemBaseline: [ObjectIdentifier: Bool] = [:]

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        let observer = Observer()
        menuObserver = observer

        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(Observer.menuWillTrack(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(Observer.menuDidEndTracking(_:)),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )

    }

    private static func beginTracking(menu: NSMenu) {
        #if DEBUG
        print("[MenuOpenBridge] menu tracking began: \(menu.title)")
        #endif

        trackingMenu = menu
        let isOptionPressed = NSEvent.modifierFlags.contains(.option)
        NotificationCenter.default.post(name: .clipboardEnvyMenuWillOpen, object: nil)
        updateTestDataVisibility(in: menu, shouldShowAll: false)
        updateTransformSubmenuVisibility(in: menu, shouldShowAll: false)
        applyTransformMenuLabelUpdates(in: menu, shouldShowAll: false)
        clearShowAllOverrideSnapshot()
        captureShowAllOverrideSnapshot(in: menu)
        applyTransformOverrides(in: menu, shouldShowAll: isOptionPressed)

        lastOptionVisibility = isOptionPressed
        stopOptionPolling()
        stopOptionMonitor()
        startOptionPolling()
        startOptionMonitor()
    }

    private static func endTracking(menu: NSMenu) {
        guard trackingMenu === menu else { return }
        #if DEBUG
        print("[MenuOpenBridge] menu tracking ended: \(menu.title)")
        #endif
        NotificationCenter.default.post(name: .clipboardEnvyMenuDidClose, object: nil)
        stopOptionPolling()
        stopOptionMonitor()
        transformSubmenusVisibleWithoutOption.removeAll()
        transformMenuLabelsContext = nil
        clearShowAllOverrideSnapshot()
        lastOptionVisibility = nil
        trackingMenu = nil
    }

    static func setTransformMenuContext(_ visibleMenusWithoutOption: Set<String>) {
        transformSubmenusVisibleWithoutOption = Set(visibleMenusWithoutOption)
        guard let trackedMenu = trackingMenu else { return }
        let isOptionPressed = lastOptionVisibility ?? NSEvent.modifierFlags.contains(.option)
        if !isOptionPressed {
            updateTransformSubmenuVisibility(in: trackedMenu, shouldShowAll: false)
            rebaselineShowAllOverrides(in: trackedMenu)
        }
        applyTransformOverrides(in: trackedMenu, shouldShowAll: isOptionPressed)
    }

    static func setTransformMenuLabelsContext(_ context: TransformMenuLabelsContext) {
        transformMenuLabelsContext = context
        guard let trackedMenu = trackingMenu else { return }
        let isOptionPressed = lastOptionVisibility ?? NSEvent.modifierFlags.contains(.option)
        if !isOptionPressed {
            applyTransformMenuLabelUpdates(in: trackedMenu, shouldShowAll: false)
            rebaselineShowAllOverrides(in: trackedMenu)
        }
        applyTransformOverrides(in: trackedMenu, shouldShowAll: isOptionPressed)
    }

    static func currentTrackingMenuIfAvailable() -> NSMenu? {
        trackingMenu
    }

    static func applyTransformOverridesIfOpen(trackedMenu: NSMenu, shouldShowAll: Bool) {
        guard trackingMenu != nil else { return }
        applyTransformOverrides(in: trackedMenu, shouldShowAll: shouldShowAll)
    }

    private static func startOptionPolling() {
        guard optionPollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.075, repeats: true) { _ in
            Task { @MainActor in
                guard let trackedMenu = trackingMenu else { return }
                let isOptionPressed = NSEvent.modifierFlags.contains(.option)
                if isOptionPressed != lastOptionVisibility {
                    lastOptionVisibility = isOptionPressed
                }
                applyTransformOverrides(in: trackedMenu, shouldShowAll: isOptionPressed)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        optionPollTimer = timer
    }

    private static func startOptionMonitor() {
        guard optionMonitors.isEmpty else { return }
        let monitor = { (event: NSEvent) in
            Task { @MainActor in
                guard trackingMenu != nil else { return }
                let isOptionPressed = event.modifierFlags.contains(.option)
                if isOptionPressed != lastOptionVisibility {
                    lastOptionVisibility = isOptionPressed
                }
                if let trackedMenu = trackingMenu {
                    applyTransformOverrides(in: trackedMenu, shouldShowAll: isOptionPressed)
                }
            }
            return event
        }
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: monitor) {
            optionMonitors.append(localMonitor)
        }
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { event in
            _ = monitor(event)
        }) {
            optionMonitors.append(globalMonitor)
        }
    }

    private static func stopOptionPolling() {
        optionPollTimer?.invalidate()
        optionPollTimer = nil
    }

    private static func stopOptionMonitor() {
        lastOptionVisibility = nil
        for monitor in optionMonitors {
            NSEvent.removeMonitor(monitor)
        }
        optionMonitors.removeAll()
    }

    private static func clearShowAllOverrideSnapshot() {
        showAllItemBaseline.removeAll()
    }

    private static func rebaselineShowAllOverrides(in menu: NSMenu) {
        clearShowAllOverrideSnapshot()
        captureShowAllOverrideSnapshot(in: menu)
    }

    private static func captureShowAllOverrideSnapshot(in menu: NSMenu) {
        if let transformMenuItem = findTransformRootMenuItem(in: menu),
           let transformSubmenu = transformMenuItem.submenu {
            collectShowAllOverrideSnapshot(from: transformSubmenu)
        }
        if let setMenuItem = findSetRootMenuItem(in: menu),
           let setSubmenu = setMenuItem.submenu {
            collectShowAllOverrideSnapshot(from: setSubmenu)
        }
    }

    private static func collectShowAllOverrideSnapshot(from menu: NSMenu) {
        for item in menu.items {
            let id = ObjectIdentifier(item)
            if item.isHidden && showAllItemBaseline[id] == nil {
                showAllItemBaseline[id] = item.isHidden
            }
            if let submenu = item.submenu {
                collectShowAllOverrideSnapshot(from: submenu)
            }
        }
    }

    private static func applyTransformOverrides(in menu: NSMenu, shouldShowAll: Bool) {
        if showAllItemBaseline.isEmpty {
            captureShowAllOverrideSnapshot(in: menu)
        }

        if shouldShowAll, let transformMenuItem = findTransformRootMenuItem(in: menu),
           let transformSubmenu = transformMenuItem.submenu {
            revealAllItems(in: transformSubmenu)
        }

        for id in showAllItemBaseline.keys {
            if let item = item(for: id, in: menu) {
                item.isHidden = shouldShowAll ? false : (showAllItemBaseline[id] ?? false)
            }
        }

        if isShowingTransformItemsSectionally {
            updateTestDataVisibility(in: menu, shouldShowAll: shouldShowAll)
            updateTransformSubmenuVisibility(in: menu, shouldShowAll: shouldShowAll)
            applyTransformMenuLabelUpdates(in: menu, shouldShowAll: shouldShowAll)
            if let context = transformMenuLabelsContext {
                applyTransformItemVisibility(in: menu, shouldShowAll: shouldShowAll, context: context)
            }
        }
    }

    private static func revealAllItems(in menu: NSMenu) {
        for item in menu.items {
            item.isHidden = false
            if let submenu = item.submenu {
                revealAllItems(in: submenu)
            }
        }
    }

    private static func item(for id: ObjectIdentifier, in menu: NSMenu) -> NSMenuItem? {
        for menuItem in menu.items {
            if ObjectIdentifier(menuItem) == id {
                return menuItem
            }
            if let submenu = menuItem.submenu,
               let found = item(for: id, in: submenu) {
                return found
            }
        }
        return nil
    }

    private static var isShowingTransformItemsSectionally: Bool {
        trackingMenu != nil
    }

    private static func updateTestDataVisibility(in menu: NSMenu, shouldShowAll: Bool) {
        if let (testDataMenuItem, precedingDivider) = findTestDataMenuItem(in: menu) {
            testDataMenuItem.isHidden = !shouldShowAll
            precedingDivider?.isHidden = !shouldShowAll
            #if DEBUG
            print("[MenuOpenBridge] set Test Data visibility: \(shouldShowAll) | itemHidden=\(testDataMenuItem.isHidden)")
            #endif
        } else {
            #if DEBUG
            print("[MenuOpenBridge] could not find Test Data item in menu: \(menu.title)")
            let titles = menu.items.map { $0.title }
            print("[MenuOpenBridge] top-level titles: \(titles)")
            #endif
        }
    }

    private static func updateTransformSubmenuVisibility(in menu: NSMenu, shouldShowAll: Bool) {
        let baselineVisible = transformSubmenusVisibleWithoutOption
        guard let transformMenuItem = findTransformRootMenuItem(in: menu),
              let transformSubmenu = transformMenuItem.submenu else {
            return
        }

        for item in transformSubmenu.items {
            guard let key = canonicalTransformMenuKey(for: item, submenu: item.submenu) else { continue }
            guard managedTransformSubmenuKeys.contains(key) else { continue }

            if shouldShowAll {
                item.isHidden = false
            } else {
                item.isHidden = !baselineVisible.contains(key)
            }
        }
    }

    private static func applyTransformMenuLabelUpdates(in menu: NSMenu, shouldShowAll: Bool) {
        guard let context = transformMenuLabelsContext else { return }
        let shouldPasteAfterOperation = NSEvent.modifierFlags.contains(.shift)
        if let transformMenuItem = findTransformRootMenuItem(in: menu) {
            transformMenuItem.title = transformRootTitle(
                shouldShowAll: shouldShowAll,
                shouldPasteAfterOperation: shouldPasteAfterOperation
            )
        }
        if let setMenuItem = findSetRootMenuItem(in: menu) {
            setMenuItem.title = shouldPasteAfterOperation
                ? TransformMenuTitles.setRootPaste
                : TransformMenuTitles.setRoot
        }
        guard let transformMenuItem = findTransformRootMenuItem(in: menu),
              let transformSubmenu = transformMenuItem.submenu else {
            return
        }

        for item in transformSubmenu.items {
            let titleWithoutSparkle = TransformMenuTitles.stripSparkleSuffix(item.title)
            if titleWithoutSparkle == TransformMenuTitles.generalText {
                item.title = shouldShowAll ? context.generalText.withOption : context.generalText.withoutOption
                continue
            }

            guard let key = canonicalTransformMenuKey(for: item, submenu: item.submenu) else { continue }
            guard managedTransformSubmenuKeys.contains(key) else { continue }
            guard let variant = context.managedSubmenus[key] else { continue }

            item.title = shouldShowAll ? variant.withOption : variant.withoutOption
            if key == TransformMenuTitles.jsonOrYaml,
               let jsonYAMLSubmenu = item.submenu {
                applyJSONYAMLSectionVisibility(
                    in: jsonYAMLSubmenu,
                    shouldShowAll: shouldShowAll,
                    context: context
                )
            } else if key == TransformMenuTitles.databaseCLI,
                      let databaseCLISubmenu = item.submenu {
                applyDatabaseCLISectionVisibility(
                    in: databaseCLISubmenu,
                    shouldShowAll: shouldShowAll,
                    context: context
                )
            }
        }
    }

    private static func transformRootTitle(shouldShowAll: Bool, shouldPasteAfterOperation: Bool) -> String {
        if shouldShowAll && shouldPasteAfterOperation {
            return TransformMenuTitles.transformRootCopyPaste
        }
        if shouldShowAll {
            return TransformMenuTitles.transformRootCopy
        }
        if shouldPasteAfterOperation {
            return TransformMenuTitles.transformRootPaste
        }
        return TransformMenuTitles.transformRoot
    }

    private static func applyTransformItemVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        guard let transformMenuItem = findTransformRootMenuItem(in: menu),
              let transformSubmenu = transformMenuItem.submenu else {
            return
        }

        for topLevelItem in transformSubmenu.items {
            let topLevelTitle = TransformMenuTitles.stripSparkleSuffix(topLevelItem.title)
            let managedKey = canonicalTransformMenuKey(for: topLevelItem, submenu: topLevelItem.submenu)

            if managedKey == TransformMenuTitles.generalText,
               let submenu = topLevelItem.submenu {
                applyGeneralTextMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if managedKey == TransformMenuTitles.time,
                      let submenu = topLevelItem.submenu {
                applyTimeMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if managedKey == TransformMenuTitles.urls,
                      let submenu = topLevelItem.submenu {
                applyURLsMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if managedKey == TransformMenuTitles.jsonOrYaml,
                      let submenu = topLevelItem.submenu {
                applyJSONYAMLMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if managedKey == TransformMenuTitles.csv,
                      let submenu = topLevelItem.submenu {
                applyCSVMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if managedKey == TransformMenuTitles.databaseCLI,
                      let submenu = topLevelItem.submenu {
                applyDatabaseCLIMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if topLevelTitle == "Multi-line",
                      let submenu = topLevelItem.submenu {
                applyMultiLineMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            } else if topLevelTitle == "Encode / Hash",
                      let submenu = topLevelItem.submenu {
                applyEncodeHashMenuVisibility(in: submenu, shouldShowAll: shouldShowAll, context: context)
            }
        }
    }

    private static func applyVisibility(_ visibility: [String: Bool], in menu: NSMenu) {
        for item in menu.items {
            let rawTitle = TransformMenuTitles.stripSparkleSuffix(item.title)
            if let isVisible = visibility[rawTitle] {
                item.isHidden = !isVisible
            }
        }
    }

    private static func applyGeneralTextMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            for item in menu.items {
                if item.title.isEmpty { continue }
                item.isHidden = false
            }
            return
        }

        let visibility: [String: Bool] = [
            "Split JSON Array ✨": context.showGeneralTextSplitJSONArray
        ]
        applyVisibility(visibility, in: menu)
    }

    private static func applyTimeMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            for item in menu.items { item.isHidden = false }
            return
        }

        let visibility: [String: Bool] = [
            "→ Epoch (s)": context.showTimeEpochSecondsTransform,
            "→ Epoch (ms)": context.showTimeEpochMillisecondsTransform,
            "→ SQL DateTime (Local)": context.showTimeSQLDateTimeTransform,
            "→ SQL DateTime (UTC)": context.showTimeSQLDateTimeTransform,
            "→ RFC3339 (Z)": context.showTimeRFC3339Transform,
            "→ RFC3339 (+offset)": context.showTimeRFC3339Transform,
            "→ RFC3339 (tz abbrev)": context.showTimeRFC3339Transform,
            "→ RFC1123 (Local)": context.showTimeRFC1123Transform,
            "→ RFC1123 (UTC)": context.showTimeRFC1123Transform,
            "→ YYYY/MM/DD hh:mm:ss (Local)": context.showTimeSlashDateTimeTransform,
            "→ YYYY/MM/DD hh:mm:ss (UTC)": context.showTimeSlashDateTimeTransform,
            "→ YY/MM/DD hh:mm:ss (Local)": context.showTimeSlashDateTimeTransform,
            "→ YY/MM/DD hh:mm:ss (UTC)": context.showTimeSlashDateTimeTransform,
            "→ YYYY/MM/DD (Local)": context.showTimeSlashDateTimeTransform,
            "→ YYYY/MM/DD (UTC)": context.showTimeSlashDateTimeTransform,
            "→ YYYY/MM/DD/HH (Local)": context.showTimeSlashDateTimeTransform,
            "→ YYYY/MM/DD/HH (UTC)": context.showTimeSlashDateTimeTransform,
            "→ YY/MM/DD (Local)": context.showTimeSlashDateTimeTransform,
            "→ YY/MM/DD (UTC)": context.showTimeSlashDateTimeTransform
        ]
        applyVisibility(visibility, in: menu)
    }

    private static func applyURLsMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        let visibility: [String: Bool] = [
            "Host (Domain)": context.showShowURLExtractSection,
            "Host:Port": context.showURLExtractHostPort,
            "Port": context.showURLExtractPort,
            "Path": context.showURLExtractPath,
            "Params": context.showURLExtractQuery,
            "Hash": context.showURLExtractFragment,
            "Username": context.showURLExtractUsername,
            "Username:Password": context.showURLExtractCredentials,
            "Strip user:pass": context.showURLExtractCredentials || context.showURLExtractUsername,
            "Strip user": context.showURLExtractUsername,
            "Strip URL Params": context.showURLStripParams || context.showURLDecode
        ]
        applyVisibility(visibility, in: menu)

        for item in menu.items {
            if TransformMenuTitles.stripSparkleSuffix(item.title) == TransformMenuTitles.Section.urls.rawValue {
                item.isHidden = !context.showShowURLExtractSection
            }
        }
        if let stripItem = menu.items.first(where: { $0.title == "Strip user:pass" || $0.title == "Strip user" }) {
            stripItem.title = context.showURLExtractCredentials ? "Strip user:pass" : "Strip user"
        }
    }

    private static func applyJSONYAMLMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        let jsonSection = [
            "Sort Keys": !context.isArrayStructure,
            "Top-Level Keys": !context.isArrayStructure,
            "All Keys": context.isSimpleLiteralJsonArray,
            "Prettify": context.showJSONYAMLPrettify,
            "Minify": context.showJSONYAMLMinify,
            "Array → CSV": context.showJSONArrayToCsv
        ]
        applyVisibility(jsonSection, in: menu)
    }

    private static func applyCSVMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        applyVisibility(ofSection: .csv, in: menu, isVisible: context.showCSVSection)
        applyVisibility(ofSection: .tabPipeSeparated, in: menu, isVisible: context.showTSVPSVSection)
        applyVisibility(ofSection: .fixedWidthTable, in: menu, isVisible: context.showFixedWidthTableSection)
        applyVisibility(ofSection: .columns, in: menu, isVisible: context.showColumnsSection)

        applyVisibility([
            "→ JSON (typed)": context.showCSVSection,
            "→ JSON (strings)": context.showCSVSection,
            "→ Tab-separated": context.showCSVSection,
            "→ Pipe-separated": context.showCSVSection,
            "→ Fixed-Width Table": context.showCSVSection,
            "TSV → CSV": context.showTSVToCsv,
            "PSV → CSV": context.showPSVToCsv,
            "Table → CSV": context.showFixedWidthTableSection,
            "Table → JSON (typed)": context.showFixedWidthTableSection,
            "Table → JSON (strings)": context.showFixedWidthTableSection,
            "Strip Empty Columns": context.showStripColumns
        ], in: menu)

        for item in menu.items {
            if item.isSeparatorItem {
                item.isHidden = false
            }
        }
    }

    private static func applyDatabaseCLIMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        let mysqlVisibility = context.showsMySQLSectionWithoutOption
        let psqlVisibility = context.showsPsqlSectionWithoutOption
        let sqliteVisibility = context.showsSQLite3SectionWithoutOption
        for item in menu.items {
            let title = TransformMenuTitles.stripSparkleSuffix(item.title)
            if title == TransformMenuTitles.Section.mysql.rawValue {
                item.isHidden = !mysqlVisibility
            } else if title == TransformMenuTitles.Section.psql.rawValue {
                item.isHidden = !psqlVisibility
            } else if title == TransformMenuTitles.Section.sqlite3.rawValue {
                item.isHidden = !sqliteVisibility
            }
        }
    }

    private static func applyMultiLineMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        let visibility: [String: Bool] = [
            "Sort Lines": context.showMultiLineTransformMenus,
            "Collapse Lines": context.showMultiLineTransformMenus,
            "Remove Lines": context.showMultiLineTransformMenus,
            "Head Lines": context.showMultiLineTransformMenus,
            "Tail Lines": context.showMultiLineTransformMenus,
            "Join Lines": context.showJoinAndCRMenus,
            "CRLF → LF (strip \\r)": context.hasCarriageReturns,
            "CRLF → LF (strip \\r) ✨": context.hasCarriageReturns
        ]
        applyVisibility(visibility, in: menu)
    }

    private static func applyEncodeHashMenuVisibility(in menu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if shouldShowAll {
            revealAllItems(in: menu)
            return
        }

        var currentSection: String?
        for item in menu.items {
            let title = TransformMenuTitles.stripSparkleSuffix(item.title)
            switch title {
            case "URL", "Base64", "Base64 URL-Safe", "JWT":
                currentSection = title
                item.isHidden = title == "JWT" ? !context.showJWTDecode : false
            case "Encode":
                item.isHidden = false
            case "Decode":
                switch currentSection {
                case "URL":
                    item.isHidden = !context.showURLDecode
                case "Base64":
                    item.isHidden = !context.showBase64Decode
                case "Base64 URL-Safe":
                    item.isHidden = !context.showBase64URLDecode
                default:
                    break
                }
            case "Decode Header":
                item.isHidden = currentSection == "JWT" ? !context.showJWTDecode : item.isHidden
            case "Decode Payload":
                item.isHidden = currentSection == "JWT" ? !context.showJWTDecode : item.isHidden
            default:
                break
            }
        }
    }

    private static func applyJSONYAMLSectionVisibility(in jsonYAMLMenu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if !shouldShowAll && context.hasJSONOrYAMLContext {
            let showJSON = context.showsJSONSectionWithoutOption
            let showYAML = context.showsYAMLSectionWithoutOption
            applyVisibility(ofSection: .json, in: jsonYAMLMenu, isVisible: showJSON)
            applyVisibility(ofSection: .yaml, in: jsonYAMLMenu, isVisible: showYAML)
            return
        }

        applyVisibility(ofSection: .json, in: jsonYAMLMenu, isVisible: true)
        applyVisibility(ofSection: .yaml, in: jsonYAMLMenu, isVisible: true)
    }

    private static func applyDatabaseCLISectionVisibility(in databaseMenu: NSMenu, shouldShowAll: Bool, context: TransformMenuLabelsContext) {
        if !shouldShowAll && context.hasDatabaseCLITableContext {
            let showMySQL = context.showsMySQLSectionWithoutOption
            let showPsql = context.showsPsqlSectionWithoutOption
            let showSqlite = context.showsSQLite3SectionWithoutOption

            applyVisibility(ofSection: .mysql, in: databaseMenu, isVisible: showMySQL)
            applyVisibility(ofSection: .psql, in: databaseMenu, isVisible: showPsql)
            applyVisibility(ofSection: .sqlite3, in: databaseMenu, isVisible: showSqlite)
            return
        }

        applyVisibility(ofSection: .mysql, in: databaseMenu, isVisible: true)
        applyVisibility(ofSection: .psql, in: databaseMenu, isVisible: true)
        applyVisibility(ofSection: .sqlite3, in: databaseMenu, isVisible: true)
    }

    private static func applyVisibility(ofSection section: TransformMenuTitles.Section, in menu: NSMenu, isVisible: Bool) {
        guard let sectionHeaderIndex = menu.items.firstIndex(where: {
            TransformMenuTitles.stripSparkleSuffix($0.title) == section.rawValue
        }) else { return }
        let sectionHeader = menu.items[sectionHeaderIndex]
        sectionHeader.isHidden = !isVisible

        var idx = sectionHeaderIndex + 1
        while idx < menu.items.count {
            let item = menu.items[idx]
            let itemName = TransformMenuTitles.stripSparkleSuffix(item.title)
            if !item.isSeparatorItem,
               TransformMenuTitles.Section(rawValue: itemName) != nil {
                break
            }
            item.isHidden = !isVisible
            idx += 1
        }
    }

    private static func findTransformRootMenuItem(in menu: NSMenu) -> NSMenuItem? {
        findMenuItem(in: menu, matching: TransformMenuTitles.allTransformRootTitles)
    }

    private static func findSetRootMenuItem(in menu: NSMenu) -> NSMenuItem? {
        findMenuItem(in: menu, matching: TransformMenuTitles.allSetRootTitles)
    }

    private static func canonicalTransformMenuKey(for item: NSMenuItem, submenu: NSMenu?) -> String? {
        let title = TransformMenuTitles.stripSparkleSuffix(item.title)

        switch title {
        case TransformMenuTitles.time,
             TransformMenuTitles.urls,
             TransformMenuTitles.json,
             TransformMenuTitles.yaml,
             TransformMenuTitles.jsonOrYaml,
             TransformMenuTitles.csv,
             TransformMenuTitles.databaseCLI:
            return title == TransformMenuTitles.json || title == TransformMenuTitles.yaml
                ? TransformMenuTitles.jsonOrYaml
                : title
        default:
            break
        }

        if let submenu,
           menuLooksLikeCSVTransformMenu(submenu) {
            return TransformMenuTitles.csv
        }

        return nil
    }

    private static func menuLooksLikeCSVTransformMenu(_ menu: NSMenu) -> Bool {
        for item in menu.items {
            let rawTitle = TransformMenuTitles.stripSparkleSuffix(item.title)
            if rawTitle == "→ JSON (typed)"
                || rawTitle == "→ JSON (strings)"
                || rawTitle == "→ Tab-separated"
                || rawTitle == "→ Pipe-separated" {
                return true
            }
        }
        return false
    }

    private static func findMenuItem(in menu: NSMenu, title: String) -> NSMenuItem? {
        findMenuItem(in: menu, matching: [title])
    }

    private static func findMenuItem(in menu: NSMenu, matching titles: Set<String>) -> NSMenuItem? {
        for item in menu.items {
            if titles.contains(item.title) {
                return item
            }
            if let submenu = item.submenu,
               let found = findMenuItem(in: submenu, matching: titles) {
                return found
            }
        }
        return nil
    }

    private static func findTestDataMenuItem(in menu: NSMenu) -> (NSMenuItem, NSMenuItem?)? {
        let items = menu.items
        for index in 0..<items.count {
            let item = items[index]
            if item.title == testDataMenuTitle && item.submenu != nil {
                let divider = (index > 0 && items[index - 1].isSeparatorItem) ? items[index - 1] : nil
                return (item, divider)
            }
            if let submenu = item.submenu,
               let found = findTestDataMenuItem(in: submenu) {
                return found
            }
        }
        return nil
    }

    static func uninstall() {
        stopOptionPolling()
        stopOptionMonitor()
        if let observer = menuObserver {
            NotificationCenter.default.removeObserver(observer)
            menuObserver = nil
        }
        isInstalled = false
        clearShowAllOverrideSnapshot()
        trackingMenu = nil
    }
}
