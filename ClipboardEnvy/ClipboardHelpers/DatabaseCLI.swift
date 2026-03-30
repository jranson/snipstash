import Foundation

extension ClipboardTransform {
    // MARK: - Database CLI

    nonisolated static func mysqlCliTableToCsv(_ s: String) throws -> String {
        let rows = try mysqlCliTableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func mysqlCliTableToJson(_ s: String) throws -> String {
        let rows = try mysqlCliTableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    nonisolated static func psqlCliTableToCsv(_ s: String) throws -> String {
        let rows = try psqlCliTableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func psqlCliTableToJson(_ s: String) throws -> String {
        let rows = try psqlCliTableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    nonisolated static func sqlite3TableToCsv(_ s: String) throws -> String {
        let rows = try sqlite3TableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func sqlite3TableToJson(_ s: String) throws -> String {
        let rows = try sqlite3TableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    nonisolated static func clickhouseCliTableToCsv(_ s: String) throws -> String {
        let rows = try clickhouseCliTableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func clickhouseCliTableToJson(_ s: String) throws -> String {
        let rows = try clickhouseCliTableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    private nonisolated static func mysqlCliTableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s).components(separatedBy: .newlines)
        let borderIndices = lines.indices.filter { isMySQLCliTableBorder(lines[$0]) }
        guard let firstBorder = borderIndices.first,
              let lastBorder = borderIndices.last,
              firstBorder < lastBorder else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: could not find a complete +--- table border block.")
        }

        let tableLines = lines[firstBorder...lastBorder]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard tableLines.allSatisfy({ isMySQLCliTableBorder($0) || isMySQLCliTableRow($0) }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: found non-table text inside the detected table block.")
        }

        let rows = tableLines
            .filter(isMySQLCliTableRow)
            .map(parseMySQLCliTableRow)

        guard let headers = rows.first, !headers.isEmpty, rows.count >= 2 else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: expected a header row plus at least one data row.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: one or more rows have a different number of columns than the header.")
        }
        return rows
    }

    private nonisolated static func psqlCliTableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let separatorIndex = lines.firstIndex(where: isPsqlCliTableSeparator),
              separatorIndex > 0 else {
            throw TransformError(description: "psql Table → CSV failed: could not find the dashed separator line under the header.")
        }

        let headerLine = lines[separatorIndex - 1]
        let dataLines = lines[(separatorIndex + 1)...]
            .filter { !isPsqlCliTableFooter($0) }
        guard !dataLines.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: found the header, but no data rows below it.")
        }

        let headers = parsePsqlCliTableRow(headerLine)
        guard !headers.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: header row did not contain any columns.")
        }

        let parsedDataRows = dataLines.map { line in
            normalizePsqlCliTableRow(parsePsqlCliTableRow(line), headerCount: headers.count)
        }
        guard parsedDataRows.allSatisfy({ !$0.isEmpty && $0.count == headers.count }) else {
            throw TransformError(description: "psql Table → CSV failed: one or more rows could not be aligned to the header column count.")
        }

        return [headers] + parsedDataRows
    }

    private nonisolated static func sqlite3TableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count >= 3 else {
            throw TransformError(description: "sqlite3 Table → CSV failed: expected a header row, a dashed separator row, and at least one data row.")
        }
        let headerLine = lines[0]
        let separatorLine = lines[1]
        let dataLines = Array(lines.dropFirst(2))

        let columnStarts = sqlite3ColumnStarts(from: separatorLine)
        guard !columnStarts.isEmpty else {
            throw TransformError(description: "sqlite3 Table → CSV failed: could not infer fixed-width columns from the dashed separator row.")
        }

        let headers = parseSQLite3FixedWidthRow(headerLine, columnStarts: columnStarts)
        guard !headers.isEmpty, headers.contains(where: { !$0.isEmpty }) else {
            throw TransformError(description: "sqlite3 Table → CSV failed: header row did not contain any columns.")
        }

        return [headers] + dataLines.map { parseSQLite3FixedWidthRow($0, columnStarts: columnStarts) }
    }

    /// ClickHouse client pretty tables use box-drawing characters (┌ ┬ ┐ │ └ ┘, ─).
    /// Like the MySQL CLI parser, arbitrary text before/after the table is ignored once a valid header…footer block is found.
    nonisolated static func clickhouseCliTableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s).components(separatedBy: .newlines)
        guard let (headerIdx, footerIdx) = clickhouseCliTableLineRange(lines) else {
            throw TransformError(description: "ClickHouse CLI Table → CSV failed: could not find a complete ┌…┐ header and └…┘ footer block.")
        }

        let headerText = lines[headerIdx].trimmingCharacters(in: .whitespacesAndNewlines)
        let columnInfos = try parseClickHouseCliHeaderLine(headerText)
        let columnCount = columnInfos.count
        guard columnCount > 0 else {
            throw TransformError(description: "ClickHouse CLI Table → CSV failed: header did not define any columns.")
        }

        var result: [[String]] = [columnInfos.map(\.name)]
        let trimBudgets = columnInfos.map(\.trailingSpaceTrim)
        for idx in (headerIdx + 1)..<footerIdx {
            guard clickhouseCliIsProbableDataLine(lines[idx]) else { continue }
            let trimmed = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let row = parseClickHouseCliDataRow(trimmed, columnCount: columnCount, trailingSpaceTrim: trimBudgets) else {
                throw TransformError(description: "ClickHouse CLI Table → CSV failed: a data row could not be parsed or had the wrong number of columns.")
            }
            result.append(row)
        }

        guard result.count >= 2 else {
            throw TransformError(description: "ClickHouse CLI Table → CSV failed: no data rows between header and footer.")
        }
        return result
    }

    /// Picks the first `┌…┬…┐` header, then the first `└…` grid footer after it that encloses at least one parsable data row (avoids mistaking an early or stray bottom rule when the client prints extra output between header and closing border).
    private nonisolated static func clickhouseCliTableLineRange(_ lines: [String]) -> (Int, Int)? {
        for h in lines.indices {
            guard clickhouseCliIsHeaderLine(lines[h]) else { continue }
            let headerText = lines[h].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let columnInfos = try? parseClickHouseCliHeaderLine(headerText), !columnInfos.isEmpty else { continue }
            let columnCount = columnInfos.count
            let trimBudgets = columnInfos.map(\.trailingSpaceTrim)
            for f in lines[h...].indices where clickhouseCliIsFooterLine(lines[f]) {
                guard f > h else { continue }
                if clickhouseCliBlockContainsParsableData(
                    lines: lines,
                    headerIdx: h,
                    footerIdx: f,
                    columnCount: columnCount,
                    trailingSpaceTrim: trimBudgets
                ) {
                    return (h, f)
                }
            }
        }
        return nil
    }

    private nonisolated static func clickhouseCliBlockContainsParsableData(
        lines: [String],
        headerIdx: Int,
        footerIdx: Int,
        columnCount: Int,
        trailingSpaceTrim: [Int]
    ) -> Bool {
        for idx in (headerIdx + 1)..<footerIdx {
            guard clickhouseCliIsProbableDataLine(lines[idx]) else { continue }
            let trimmed = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            if parseClickHouseCliDataRow(trimmed, columnCount: columnCount, trailingSpaceTrim: trailingSpaceTrim) != nil {
                return true
            }
        }
        return false
    }

    private nonisolated static func clickhouseCliIsHeaderLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.contains("┌") && t.contains("┬") && t.contains("┐")
    }

    /// Bottom border of the grid (not a stray “└” in prose).
    private nonisolated static func clickhouseCliIsFooterLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("└"), t.count >= 2 else { return false }
        return t.contains("─") || t.contains("┴") || t.contains("┘")
    }

    /// Row lines only: exclude header/footer reruns, horizontal rules, and box-only lines.
    private nonisolated static func clickhouseCliIsProbableDataLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if clickhouseCliIsHeaderLine(t) || clickhouseCliIsFooterLine(t) { return false }
        if clickhouseCliIsIntermediateBoxLine(t) { return false }
        return t.contains("│") || t.contains("|")
    }

    /// Horizontal dividers such as ├────┼────┤ (no “real” cell text).
    private nonisolated static func clickhouseCliIsIntermediateBoxLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return true }
        let boxOnly = Set<Character>("─│├┤┬┴┼└┘┌ ")
        return t.allSatisfy { boxOnly.contains($0) }
    }

    private nonisolated static func parseClickHouseCliHeaderLine(_ line: String) throws -> [(name: String, trailingSpaceTrim: Int)] {
        guard let iTopLeft = line.firstIndex(of: "┌"),
              let iTopRight = line.firstIndex(of: "┐"),
              iTopRight > iTopLeft else {
            throw TransformError(description: "ClickHouse CLI Table → CSV failed: malformed header line (missing ┌ or ┐).")
        }

        let afterLeft = line.index(after: iTopLeft)
        let inner = line[afterLeft..<iTopRight]
        let segments = inner.split(separator: "┬", omittingEmptySubsequences: false).map(String.init)
        guard !segments.isEmpty else {
            throw TransformError(description: "ClickHouse CLI Table → CSV failed: could not split header on ┬.")
        }

        var columns: [(String, Int)] = []
        for segment in segments {
            var body = segment
            while body.first == "─" {
                body.removeFirst()
            }
            var trailingDashes = 0
            while body.last == "─" {
                body.removeLast()
                trailingDashes += 1
            }
            let name = body.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                throw TransformError(description: "ClickHouse CLI Table → CSV failed: empty column name in header.")
            }
            columns.append((name, trailingDashes))
        }
        return columns
    }

    /// First column boundary: Unicode box `│` or ASCII `|` (PrettyCompact uses `│` for numbers and often `|` for left-aligned strings).
    private nonisolated static func clickhouseCliFirstColumnDelimiterIndex(_ line: String) -> String.Index? {
        let idxBox = line.firstIndex(of: "│")
        let idxAscii = line.firstIndex(of: "|")
        switch (idxBox, idxAscii) {
        case let (a?, b?): return min(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }

    private nonisolated static func parseClickHouseCliDataRow(
        _ line: String,
        columnCount: Int,
        trailingSpaceTrim: [Int]
    ) -> [String]? {
        guard let pipeIdx = clickhouseCliFirstColumnDelimiterIndex(line) else { return nil }
        // Normalize so every column is split on U+2502; avoids merged cells when ClickHouse mixes │ and |.
        let slice = String(line[pipeIdx...]).replacingOccurrences(of: "|", with: "│")
        let rawParts = slice.split(separator: "│", omittingEmptySubsequences: false).map(String.init)
        guard rawParts.count >= 2 else { return nil }
        var cells = Array(rawParts.dropFirst())
        if cells.last.map({ $0.isEmpty }) == true {
            cells.removeLast()
        }
        guard cells.count == columnCount else { return nil }
        return zip(cells, trailingSpaceTrim).map { raw, budget in
            let leadingTrimmed = String(raw.drop(while: { $0.isWhitespace }))
            let budgetTrimmed = trimTrailingASCIISpaces(leadingTrimmed, maxCount: budget)
            // Left-aligned string columns often pad past the header’s trailing ─ hint; strip remaining table padding.
            return trimTrailingWhitespace(budgetTrimmed)
        }
    }

    private nonisolated static func trimTrailingWhitespace(_ s: String) -> String {
        String(s.reversed().drop(while: { $0.isWhitespace }).reversed())
    }

    private nonisolated static func trimTrailingASCIISpaces(_ s: String, maxCount: Int) -> String {
        guard maxCount > 0 else { return s }
        var chars = Array(s)
        var removed = 0
        while removed < maxCount, let c = chars.last, c == " " {
            chars.removeLast()
            removed += 1
        }
        return String(chars)
    }

    private nonisolated static func isMySQLCliTableBorder(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+"), trimmed.hasSuffix("+") else { return false }
        let body = trimmed.dropFirst().dropLast()
        guard !body.isEmpty else { return false }
        return body.contains("+") && body.allSatisfy { $0 == "+" || $0 == "-" }
    }

    private nonisolated static func isMySQLCliTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    private nonisolated static func parseMySQLCliTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return [] }
        return parts.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func isPsqlCliTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "+", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0 == "-" }
        }
    }

    private nonisolated static func isPsqlCliTableFooter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else { return false }
        let body = trimmed.dropFirst().dropLast()
        return body.range(of: #"^\d+\s+rows?$"#, options: .regularExpression) != nil
    }

    private nonisolated static func parsePsqlCliTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func normalizePsqlCliTableRow(_ row: [String], headerCount: Int) -> [String] {
        guard !row.isEmpty, row.count <= headerCount else { return [] }
        if row.count == headerCount { return row }
        return row + Array(repeating: "", count: headerCount - row.count)
    }

    private nonisolated static func sqlite3ColumnStarts(from separatorLine: String) -> [Int] {
        let chars = Array(separatorLine)
        var starts: [Int] = []
        var i = 0
        while i < chars.count {
            if chars[i] == "-" {
                starts.append(i)
                while i < chars.count, chars[i] == "-" {
                    i += 1
                }
            } else if chars[i] == " " {
                i += 1
            } else {
                return []
            }
        }
        return starts
    }

    private nonisolated static func parseSQLite3FixedWidthRow(_ line: String, columnStarts: [Int]) -> [String] {
        let chars = Array(line)
        return columnStarts.enumerated().map { index, start in
            let end = index + 1 < columnStarts.count ? columnStarts[index + 1] : chars.count
            guard start < chars.count else { return "" }
            let upperBound = min(end, chars.count)
            return String(chars[start..<upperBound]).trimmingCharacters(in: .whitespaces)
        }
    }
}
