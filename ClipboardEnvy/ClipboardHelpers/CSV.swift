import Foundation

extension ClipboardTransform {
    // MARK: - CSV / TSV / PSV

    nonisolated static func csvToJson(_ s: String) throws -> String {
        let rows = parseCSVRows(s)
        guard let headers = rows.first, !headers.isEmpty else {
            throw TransformError(description: "CSV → JSON failed: no CSV header row was found.")
        }
        let normalizedRows = rows.dropFirst().map { normalizeRow($0, to: headers.count) }
        let firstDataRow = normalizedRows.first
        let explicitTypes = firstDataRow.flatMap(explicitJSONColumnTypes(from:))
        return try jsonString(
            fromHeaders: headers,
            dataRows: explicitTypes == nil ? normalizedRows : Array(normalizedRows.dropFirst()),
            formatName: "CSV",
            columnTypes: explicitTypes ?? inferJSONColumnTypes(headers: headers, rows: normalizedRows),
            inferTypes: true
        )
    }

    nonisolated static func csvToJsonStrings(_ s: String) throws -> String {
        let rows = parseCSVRows(s)
        guard let headers = rows.first, !headers.isEmpty else {
            throw TransformError(description: "CSV → JSON failed: no CSV header row was found.")
        }
        return try jsonString(
            fromHeaders: headers,
            dataRows: rows.dropFirst().map { normalizeRow($0, to: headers.count) },
            formatName: "CSV",
            columnTypes: Array(repeating: .string, count: headers.count),
            inferTypes: false
        )
    }

    nonisolated static func jsonArrayToCsv(_ s: String) throws -> String {
        let sanitized = sanitizeCommentedJSONInput(s)
        guard let data = sanitized.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !array.isEmpty else {
            throw TransformError(description: "JSON Array → CSV failed: clipboard must contain a non-empty JSON array of objects.")
        }
        let keys: [String] = (array.first?.keys.map { $0 } ?? []).sorted()
        guard !keys.isEmpty else {
            throw TransformError(description: "JSON Array → CSV failed: the first object does not contain any keys.")
        }
        func escape(_ v: String) -> String {
            if v.contains(",") || v.contains("\"") || v.contains("\n") {
                return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return v
        }
        let headerLine = keys.map(escape).joined(separator: ",")
        let dataLines = array.map { obj in
            keys.map { escape(String(describing: obj[$0] ?? "")) }.joined(separator: ",")
        }
        return ([headerLine] + dataLines).joined(separator: "\n")
    }

    nonisolated static func csvToPsv(_ s: String) -> String {
        parseCSVRows(s).map { makeDelimitedLine($0, delimiter: "|") }.joined(separator: "\n")
    }

    nonisolated static func psvToCsv(_ s: String) throws -> String {
        try delimitedToCsv(s, delimiter: "|", formatName: "PSV")
    }

    nonisolated static func tsvToCsv(_ s: String) throws -> String {
        try delimitedToCsv(s, delimiter: "\t", formatName: "TSV")
    }

    nonisolated static func csvToTsv(_ s: String) -> String {
        parseCSVRows(s).map { makeDelimitedLine($0, delimiter: "\t") }.joined(separator: "\n")
    }

    // MARK: - Fixed-Width Tables

    /// Parses a simple fixed-width, space-aligned table (no borders) into rows of columns.
    /// Uses runs of 2+ spaces as delimiters, mirroring ClipboardAnalyzer's detection heuristic.
    nonisolated static func fixedWidthTableRows(_ s: String) -> [[String]] {
        let unix = windowsNewlinesToUnix(s)
        let lines = unix.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return [] }

        func split(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return [] }
            let nsLine = trimmed as NSString
            let pattern = "\\s{2,}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return trimmed.components(separatedBy: .whitespaces)
            }

            let range = NSRange(location: 0, length: nsLine.length)
            var lastEnd = 0
            var fields: [String] = []

            regex.enumerateMatches(in: trimmed, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                let fieldRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let field = nsLine.substring(with: fieldRange).trimmingCharacters(in: .whitespaces)
                if !field.isEmpty {
                    fields.append(field)
                }
                lastEnd = match.range.location + match.range.length
            }

            if lastEnd < nsLine.length {
                let tailRange = NSRange(location: lastEnd, length: nsLine.length - lastEnd)
                let tail = nsLine.substring(with: tailRange).trimmingCharacters(in: .whitespaces)
                if !tail.isEmpty {
                    fields.append(tail)
                }
            }

            return fields
        }

        let header = split(lines[0])
        guard !header.isEmpty else { return [] }

        let dataRows = lines.dropFirst().map { split($0) }
        let normalizedRows: [[String]] = dataRows.map { row in
            if row.count == header.count { return row }
            if row.count < header.count {
                return row + Array(repeating: "", count: header.count - row.count)
            }
            return Array(row.prefix(header.count))
        }

        return [header] + normalizedRows
    }

    /// Converts a fixed-width table to CSV, normalizing NULL-like tokens to empty cells.
    nonisolated static func fixedWidthTableToCsv(_ s: String) throws -> String {
        let rows = fixedWidthTableRows(s)
        guard let headers = rows.first, !headers.isEmpty, rows.count >= 2 else {
            throw TransformError(description: "Table → CSV failed: expected a header row plus at least one data row.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "Table → CSV failed: one or more rows have a different number of columns than the header.")
        }
        return csvString(from: rows, nullsAsEmpty: true)
    }

    /// Converts a fixed-width table to a typed JSON array via CSV.
    nonisolated static func fixedWidthTableToJson(_ s: String) throws -> String {
        let csv = try fixedWidthTableToCsv(s)
        return try csvToJson(csv)
    }

    /// Converts a fixed-width table to a stringly-typed JSON array via CSV.
    nonisolated static func fixedWidthTableToJsonStrings(_ s: String) throws -> String {
        let csv = try fixedWidthTableToCsv(s)
        return try csvToJsonStrings(csv)
    }

    /// Converts CSV to a simple fixed-width table, padding columns to the maximum width seen.
    nonisolated static func csvToFixedWidthTable(_ s: String) throws -> String {
        let rows = parseCSVRows(s)
        guard let header = rows.first, !header.isEmpty else {
            throw TransformError(description: "CSV → Table failed: no CSV header row was found.")
        }
        let allRows = rows
        let columnCount = header.count
        var widths = Array(repeating: 0, count: columnCount)

        for row in allRows {
            for (idx, value) in row.enumerated() where idx < columnCount {
                let length = value.count
                if length > widths[idx] {
                    widths[idx] = length
                }
            }
        }

        func pad(_ value: String, to width: Int) -> String {
            let count = value.count
            if count >= width { return value }
            return value + String(repeating: " ", count: width - count)
        }

        let lines = allRows.map { row in
            row.enumerated().map { idx, value in
                pad(value, to: widths[idx])
            }.joined(separator: "  ")
        }

        return lines.joined(separator: "\n")
    }

    nonisolated static func parseCSVRows(_ s: String) -> [[String]] {
        parseDelimitedRows(s, delimiter: ",")
    }

    nonisolated static func parseCSVLine(_ line: String) -> [String] {
        parseDelimitedLine(line, delimiter: ",")
    }

    // Shared helper for DatabaseCLI conversion files.
    nonisolated static func csvString(from rows: [[String]], nullsAsEmpty: Bool) -> String {
        rows.enumerated().map { index, row in
            row.map { value in
                let outputValue = if index > 0, nullsAsEmpty, isNullToken(value) {
                    ""
                } else {
                    value
                }
                return escapeCSVField(outputValue)
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    private enum InferredJSONColumnType {
        case string
        case bool
        case int
        case double
    }

    private nonisolated static func normalizeRow(_ row: [String], to count: Int) -> [String] {
        if row.count == count { return row }
        if row.count < count {
            return row + Array(repeating: "", count: count - row.count)
        }
        return Array(row.prefix(count))
    }

    private nonisolated static func parseDelimitedRows(_ s: String, delimiter: Character) -> [[String]] {
        windowsNewlinesToUnix(s).components(separatedBy: .newlines).map { parseDelimitedLine($0, delimiter: delimiter) }
    }

    private nonisolated static func parseDelimitedLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == delimiter, !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }

        fields.append(current)
        return fields
    }

    private nonisolated static func makeDelimitedLine(_ fields: [String], delimiter: Character) -> String {
        fields.map { field in
            if field.contains(delimiter) || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }.joined(separator: String(delimiter))
    }

    private nonisolated static func delimitedToCsv(_ s: String, delimiter: Character, formatName: String) throws -> String {
        let trimmed = windowsNewlinesToUnix(s).trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            throw TransformError(description: "\(formatName) → CSV failed: clipboard is empty.")
        }

        let rows = parseDelimitedRows(trimmed, delimiter: delimiter)
        guard let headers = rows.first, !headers.isEmpty else {
            throw TransformError(description: "\(formatName) → CSV failed: no header row was found.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "\(formatName) → CSV failed: one or more rows have a different number of columns than the header.")
        }

        return rows.map { makeDelimitedLine($0, delimiter: ",") }.joined(separator: "\n")
    }

    private nonisolated static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private nonisolated static func jsonString(
        fromHeaders headers: [String],
        dataRows: [[String]],
        formatName: String,
        columnTypes: [InferredJSONColumnType],
        inferTypes: Bool
    ) throws -> String {
        let objects: [[String: Any]] = dataRows.map { values in
            var dict: [String: Any] = [:]
            for (index, key) in headers.enumerated() {
                let value = index < values.count ? values[index] : ""
                dict[key] = jsonValue(for: value, type: columnTypes[index], inferTypes: inferTypes)
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: data, encoding: .utf8) else {
            throw TransformError(description: "\(formatName) → JSON failed: rows could not be encoded as JSON.")
        }
        return out
    }

    private nonisolated static func inferJSONColumnTypes(headers: [String], rows: [[String]]) -> [InferredJSONColumnType] {
        headers.indices.map { columnIndex in
            let values = rows.map { row in
                columnIndex < row.count ? row[columnIndex] : ""
            }.filter { !isNullLikeForInference($0) }

            guard !values.isEmpty else { return .string }
            if values.allSatisfy({ parseBoolean($0) != nil }) { return .bool }
            if values.allSatisfy({ parseInteger($0) != nil }) { return .int }
            if values.allSatisfy({ parseDouble($0) != nil }) { return .double }
            return .string
        }
    }

    private nonisolated static func explicitJSONColumnTypes(from row: [String]) -> [InferredJSONColumnType]? {
        let columnTypes = row.map(explicitJSONColumnType)
        guard columnTypes.allSatisfy({ $0 != nil }) else { return nil }
        return columnTypes.compactMap { $0 }
    }

    private nonisolated static func explicitJSONColumnType(for value: String) -> InferredJSONColumnType? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if matchesExplicitJSONType(normalized, exactMatches: [
            "int", "int8", "int16", "int32", "int64", "int128", "int256",
            "uint", "uint8", "uint16", "uint32", "uint64", "uint128", "uint256",
            "byte", "long",
        ], prefixMatches: []) {
            return .int
        }
        if matchesExplicitJSONType(normalized, exactMatches: [
            "float32", "float64", "decimal", "number",
        ], prefixMatches: [
            "float32(", "float64(", "decimal(",
        ]) {
            return .double
        }
        if matchesExplicitJSONType(normalized, exactMatches: [
            "string", "date", "date32", "time", "datetime", "time64", "datetime64",
            "uuid", "enum", "ipv4", "ipv6",
        ], prefixMatches: [
            "varchar(",
        ]) {
            return .string
        }
        if normalized == "boolean" { return .bool }
        return nil
    }

    private nonisolated static func matchesExplicitJSONType(
        _ value: String,
        exactMatches: [String],
        prefixMatches: [String]
    ) -> Bool {
        exactMatches.contains(value) || prefixMatches.contains { value.hasPrefix($0) }
    }

    private nonisolated static func jsonValue(for rawValue: String, type: InferredJSONColumnType, inferTypes: Bool) -> Any {
        if inferTypes, isNullToken(rawValue) { return NSNull() }
        if inferTypes, isBlankNullForTypedValue(rawValue) { return NSNull() }

        switch type {
        case .bool:
            return parseBoolean(rawValue) ?? false
        case .int:
            return parseInteger(rawValue) ?? rawValue
        case .double:
            return parseDouble(rawValue) ?? rawValue
        case .string:
            return rawValue
        }
    }

    private nonisolated static func isNullToken(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("NULL") == .orderedSame
    }

    private nonisolated static func isNullLikeForInference(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || isNullToken(trimmed)
    }

    private nonisolated static func isBlankNullForTypedValue(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private nonisolated static func parseBoolean(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "t": return true
        case "false", "f": return false
        default: return nil
        }
    }

    private nonisolated static func parseInteger(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated static func parseDouble(_ value: String) -> Double? {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              number.isFinite else {
            return nil
        }
        return number
    }

    // MARK: - Column Operations

    /// Removes a single column by index, preserving the delimiter.
    nonisolated static func removeColumn(_ s: String, columnIndex: Int) -> String? {
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard !rows.isEmpty else { return nil }
        guard let firstRow = rows.first, columnIndex < firstRow.count else { return nil }
        guard firstRow.count > 1 else { return nil }

        let filteredRows = rows.map { row in
            var newRow = row
            if columnIndex < newRow.count {
                newRow.remove(at: columnIndex)
            }
            return newRow
        }

        return filteredRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Removes columns that are completely empty (all data rows have empty values).
    /// Header row is not considered in the emptiness check.
    nonisolated static func stripEmptyColumns(_ s: String) -> String? {
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard rows.count >= 2 else { return s }

        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())
        let columnCount = headerRow.count

        var nonEmptyColumnIndices: [Int] = []
        for colIndex in 0..<columnCount {
            let hasData = dataRows.contains { row in
                guard colIndex < row.count else { return false }
                return !row[colIndex].trimmingCharacters(in: .whitespaces).isEmpty
            }
            if hasData {
                nonEmptyColumnIndices.append(colIndex)
            }
        }

        guard nonEmptyColumnIndices.count < columnCount else { return s }
        guard !nonEmptyColumnIndices.isEmpty else { return nil }

        let filteredRows = rows.map { row in
            nonEmptyColumnIndices.map { idx in
                idx < row.count ? row[idx] : ""
            }
        }

        return filteredRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Sorts the delimited data by a column, preserving the delimiter.
    /// Uses stable sort to preserve relative order of equal elements.
    nonisolated static func sortByColumn(_ s: String, columnIndex: Int, ascending: Bool = true) -> String? {
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard rows.count >= 2 else { return s }

        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())

        let sortedData = dataRows.enumerated().sorted { (a, b) in
            let valueA = columnIndex < a.element.count ? a.element[columnIndex] : ""
            let valueB = columnIndex < b.element.count ? b.element[columnIndex] : ""

            let comparison = naturalCompare(valueA, valueB)
            if comparison == 0 {
                return a.offset < b.offset
            }
            return ascending ? comparison < 0 : comparison > 0
        }.map { $0.element }

        let allRows = [headerRow] + sortedData
        return allRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Natural comparison that handles numbers embedded in strings correctly.
    private nonisolated static func naturalCompare(_ a: String, _ b: String) -> Int {
        let trimmedA = a.trimmingCharacters(in: .whitespaces)
        let trimmedB = b.trimmingCharacters(in: .whitespaces)

        if let numA = Double(trimmedA), let numB = Double(trimmedB) {
            if numA < numB { return -1 }
            if numA > numB { return 1 }
            return 0
        }

        return trimmedA.localizedStandardCompare(trimmedB).rawValue
    }

    /// Detects the delimiter used in the delimited text (CSV, TSV, or PSV).
    nonisolated static func detectDelimiter(_ s: String) -> Character? {
        let firstLine = windowsNewlinesToUnix(s).components(separatedBy: .newlines).first ?? ""
        let commaCount = firstLine.filter { $0 == "," }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count
        let pipeCount = firstLine.filter { $0 == "|" }.count

        if commaCount >= tabCount && commaCount >= pipeCount && commaCount > 0 { return "," }
        if tabCount >= commaCount && tabCount >= pipeCount && tabCount > 0 { return "\t" }
        if pipeCount >= commaCount && pipeCount >= tabCount && pipeCount > 0 { return "|" }
        return nil
    }

    /// Returns the column headers from delimited text (max 26).
    nonisolated static func columnHeaders(_ s: String, maxColumns: Int = 26) -> [String] {
        guard let delimiter = detectDelimiter(s) else { return [] }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard let headers = rows.first, !headers.isEmpty else { return [] }
        return Array(headers.prefix(maxColumns))
    }

    /// Extracts a range of columns (fromIndex to toIndex inclusive) preserving the delimiter.
    nonisolated static func extractColumnRange(_ s: String, fromIndex: Int, toIndex: Int) -> String? {
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard !rows.isEmpty else { return nil }

        let startIdx = min(fromIndex, toIndex)
        let endIdx = max(fromIndex, toIndex)

        let extractedRows = rows.map { row -> [String] in
            guard endIdx < row.count else {
                return Array(row[startIdx..<min(row.count, endIdx + 1)])
            }
            return Array(row[startIdx...endIdx])
        }

        return extractedRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Swaps two columns by their indices, preserving the delimiter.
    nonisolated static func swapColumns(_ s: String, indexA: Int, indexB: Int) -> String? {
        guard indexA != indexB else { return s }
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard !rows.isEmpty else { return nil }

        let swappedRows = rows.map { row -> [String] in
            var newRow = row
            let maxIndex = max(indexA, indexB)
            if maxIndex >= newRow.count {
                newRow.append(contentsOf: Array(repeating: "", count: maxIndex - newRow.count + 1))
            }
            let temp = newRow[indexA]
            newRow[indexA] = newRow[indexB]
            newRow[indexB] = temp
            return newRow
        }

        return swappedRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Moves a column to a new position, preserving the delimiter.
    /// - Parameters:
    ///   - s: The delimited text
    ///   - fromIndex: The current index of the column to move
    ///   - toIndex: The target index (column will be inserted before this index, or at end if toIndex >= column count)
    nonisolated static func moveColumn(_ s: String, fromIndex: Int, toIndex: Int) -> String? {
        guard fromIndex != toIndex else { return s }
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard !rows.isEmpty else { return nil }

        let movedRows = rows.map { row -> [String] in
            var newRow = row
            guard fromIndex < newRow.count else { return newRow }

            let value = newRow.remove(at: fromIndex)
            let insertIndex = toIndex > fromIndex ? min(toIndex - 1, newRow.count) : min(toIndex, newRow.count)
            newRow.insert(value, at: insertIndex)
            return newRow
        }

        return movedRows.map { makeDelimitedLine($0, delimiter: delimiter) }.joined(separator: "\n")
    }

    /// Moves a column to the start (index 0), preserving the delimiter.
    nonisolated static func moveColumnToStart(_ s: String, fromIndex: Int) -> String? {
        guard fromIndex > 0 else { return s }
        return moveColumn(s, fromIndex: fromIndex, toIndex: 0)
    }

    /// Moves a column to the end, preserving the delimiter.
    nonisolated static func moveColumnToEnd(_ s: String, fromIndex: Int) -> String? {
        guard let delimiter = detectDelimiter(s) else { return nil }
        let rows = parseDelimitedRows(s, delimiter: delimiter)
        guard let firstRow = rows.first else { return nil }
        guard fromIndex < firstRow.count - 1 else { return s }
        return moveColumn(s, fromIndex: fromIndex, toIndex: firstRow.count)
    }

    /// Moves a column to before another column, preserving the delimiter.
    nonisolated static func moveColumnBefore(_ s: String, fromIndex: Int, beforeIndex: Int) -> String? {
        guard fromIndex != beforeIndex && fromIndex != beforeIndex - 1 else { return s }
        return moveColumn(s, fromIndex: fromIndex, toIndex: beforeIndex)
    }
}
