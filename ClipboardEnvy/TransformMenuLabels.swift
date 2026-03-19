import Foundation

enum TransformMenuTitles {
    static let sparkleSuffix = " ✨"
    static let testData = "Test Data"
    static let transformRoot = "Transform Clipboard Text"
    static let transformRootCopy = "Copy (⌘C) & Transform Text"
    static let transformRootPaste = "Transform Clipboard & Paste (⌘V)"
    static let transformRootCopyPaste = "Copy (⌘C), Transform, Paste (⌘V)"
    static let setRoot = "Set Clipboard Text"
    static let setRootPaste = "Set Clipboard & Paste (⌘V)"
    static let generalText = "General Text"
    static let time = "Time"
    static let urls = "URLs"
    static let json = "JSON"
    static let yaml = "YAML"
    static let jsonOrYaml = "JSON / YAML"
    static let csv = "CSV"
    static let databaseCLI = "Database CLI"

    enum Section: String {
        case json = "JSON"
        case yaml = "YAML"
        case mysql = "mysql"
        case psql = "psql"
        case sqlite3 = "sqlite3"
        case urls = "Extract"
        case fixedWidthTable = "Fixed-Width Table"
        case csv = "CSV"
        case tabPipeSeparated = "Tab/Pipe-Separated"
        case columns = "Columns"
    }

    enum ManagedSubmenu: String, CaseIterable {
        case time = "Time"
        case urls = "URLs"
        case jsonOrYaml = "JSON / YAML"
        case csv = "CSV"
        case databaseCLI = "Database CLI"
    }

    static let managedSubmenuKeys: Set<String> = Set(ManagedSubmenu.allCases.map(\.rawValue))
    static let allTransformRootTitles: Set<String> = [
        transformRoot,
        transformRootCopy,
        transformRootPaste,
        transformRootCopyPaste
    ]
    static let allSetRootTitles: Set<String> = [
        setRoot,
        setRootPaste
    ]

    static func stripSparkleSuffix(_ title: String) -> String {
        title.replacingOccurrences(of: sparkleSuffix, with: "")
    }
}

struct TransformMenuLabelVariant {
    let withoutOption: String
    let withOption: String
}

struct TransformMenuLabelsContext {
    let transformRootTitle: String
    let setRootTitle: String
    let generalText: TransformMenuLabelVariant
    let managedSubmenus: [String: TransformMenuLabelVariant]
    let showGeneralTextSplitJSONArray: Bool
    let showGeneralTextZeroWidthRemove: Bool
    let showsJSONSectionWithoutOption: Bool
    let showsYAMLSectionWithoutOption: Bool
    let hasJSONOrYAMLContext: Bool
    let showJSONYAMLPrettify: Bool
    let showJSONYAMLMinify: Bool
    let showTimeEpochSecondsTransform: Bool
    let showTimeEpochMillisecondsTransform: Bool
    let showTimeSQLDateTimeTransform: Bool
    let showTimeRFC3339Transform: Bool
    let showTimeRFC1123Transform: Bool
    let showTimeSlashDateTimeTransform: Bool
    let showURLExtractHostPort: Bool
    let showURLExtractPort: Bool
    let showURLExtractPath: Bool
    let showURLExtractQuery: Bool
    let showURLExtractFragment: Bool
    let showURLExtractUsername: Bool
    let showURLExtractCredentials: Bool
    let showShowURLExtractSection: Bool
    let showURLStripParams: Bool
    let showURLDecode: Bool
    let showBase64Decode: Bool
    let showBase64URLDecode: Bool
    let showJWTDecode: Bool
    let showMultiLineTransformMenus: Bool
    let showJoinAndCRMenus: Bool
    let hasCarriageReturns: Bool
    let isJsonArray: Bool
    let isArrayStructure: Bool
    let isSimpleLiteralJsonArray: Bool
    let showJSONArrayToCsv: Bool
    let showCSVSection: Bool
    let showTSVPSVSection: Bool
    let showTSVToCsv: Bool
    let showPSVToCsv: Bool
    let showFixedWidthTableSection: Bool
    let showStripColumns: Bool
    let showColumnsSection: Bool
    let showsMySQLSectionWithoutOption: Bool
    let showsPsqlSectionWithoutOption: Bool
    let showsSQLite3SectionWithoutOption: Bool
    let hasDatabaseCLITableContext: Bool
}
