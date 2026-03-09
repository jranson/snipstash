import XCTest
@testable import SnipStash

@MainActor
final class ClipboardHelpersTests: XCTestCase {

    // MARK: - Case / whitespace

    func testLowercase() {
        XCTAssertEqual(ClipboardTransform.lowercase("HELLO"), "hello")
    }

    func testUppercase() {
        XCTAssertEqual(ClipboardTransform.uppercase("hello"), "HELLO")
    }

    func testTrimmed() {
        XCTAssertEqual(ClipboardTransform.trimmed("  a b  \n"), "a b")
    }

    func testLowercaseTrimmed() {
        XCTAssertEqual(ClipboardTransform.lowercaseTrimmed("  HELLO  "), "hello")
    }

    func testSlugify() {
        XCTAssertEqual(ClipboardTransform.slugify("Hello World!"), "hello-world")
        XCTAssertEqual(ClipboardTransform.slugify("  a  b  "), "a-b")
    }

    func testTitleCase() {
        XCTAssertEqual(ClipboardTransform.titleCase("hello world"), "Hello World")
    }

    func testSentenceCase() {
        XCTAssertEqual(ClipboardTransform.sentenceCase("hello WORLD"), "Hello world")
        XCTAssertEqual(ClipboardTransform.sentenceCase("  a  "), "A")
    }

    func testCamelCase() {
        XCTAssertEqual(ClipboardTransform.camelCase("hello world"), "helloWorld")
        XCTAssertEqual(ClipboardTransform.camelCase("foo_bar"), "fooBar")
    }

    func testPascalCase() {
        XCTAssertEqual(ClipboardTransform.pascalCase("hello world"), "HelloWorld")
    }

    func testSnakeCase() {
        XCTAssertEqual(ClipboardTransform.snakeCase("Hello World"), "hello_world")
    }

    func testConstCase() {
        XCTAssertEqual(ClipboardTransform.constCase("Hello World"), "HELLO_WORLD")
        XCTAssertEqual(ClipboardTransform.constCase("myVariableName"), "MY_VARIABLE_NAME")
        XCTAssertEqual(ClipboardTransform.constCase("foo bar baz"), "FOO_BAR_BAZ")
    }

    // MARK: - URL

    func testStripUrlParams() {
        XCTAssertEqual(ClipboardTransform.stripUrlParams("https://a.com/p?x=1#h"), "https://a.com/p")
    }

    func testUrlEncodeDecode() {
        let s = "a b+c"
        XCTAssertEqual(ClipboardTransform.urlDecode(ClipboardTransform.urlEncode(s)), "a b+c")
    }

    func testUrlExtractHostIfValid() {
        // With port in URL: Host returns host only (no port).
        XCTAssertEqual(ClipboardTransform.urlExtractHostIfValid("https://google.com:8443/some/path?param1=val1"), "google.com")
        // Without port: Host returns host.
        XCTAssertEqual(ClipboardTransform.urlExtractHostIfValid("https://example.com/path"), "example.com")
        XCTAssertNil(ClipboardTransform.urlExtractHostIfValid("not a url"))
    }

    func testUrlExtractHostPortIfValid() {
        // With port: returns "host:port".
        XCTAssertEqual(ClipboardTransform.urlExtractHostPortIfValid("https://google.com:8443/some/path?param1=val1"), "google.com:8443")
        // Without port: returns host only.
        XCTAssertEqual(ClipboardTransform.urlExtractHostPortIfValid("https://example.com/path"), "example.com")
        XCTAssertNil(ClipboardTransform.urlExtractHostPortIfValid("not a url"))
    }

    func testUrlExtractPortIfValid() {
        // With port: returns port string.
        XCTAssertEqual(ClipboardTransform.urlExtractPortIfValid("https://google.com:8443/some/path?param1=val1"), "8443")
        // Without port: returns nil (caller beeps).
        XCTAssertNil(ClipboardTransform.urlExtractPortIfValid("https://example.com/path"))
        XCTAssertNil(ClipboardTransform.urlExtractPortIfValid("not a url"))
    }

    func testUrlExtractPathIfValid() {
        XCTAssertEqual(ClipboardTransform.urlExtractPathIfValid("https://a.com/foo/bar"), "/foo/bar")
    }

    // MARK: - Base64

    func testBase64EncodeDecode() {
        let s = "hello"
        XCTAssertEqual(ClipboardTransform.base64Decode(ClipboardTransform.base64Encode(s)), s)
    }

    // MARK: - Base64URL

    func testBase64URLEncodeDecode() {
        let s = "hello"
        let enc = ClipboardTransform.base64URLEncode(s)
        XCTAssertFalse(enc.contains("+"))
        XCTAssertFalse(enc.contains("/"))
        XCTAssertEqual(ClipboardTransform.base64URLDecode(enc), s)
    }

    // MARK: - Checksums

    func testMD5Checksum() {
        XCTAssertEqual(ClipboardTransform.md5Checksum("hello").count, 32)
    }

    func testSHA1Checksum() {
        XCTAssertEqual(ClipboardTransform.sha1Checksum("hello").count, 40)
    }

    func testSHA256Checksum() {
        XCTAssertEqual(ClipboardTransform.sha256Checksum("hello").count, 64)
    }

    // MARK: - CRC32

    func testCRC32() {
        XCTAssertEqual(ClipboardTransform.crc32("hello").count, 8)
        // CRC32 of "hello" is 0x3610a686 per standard
        XCTAssertEqual(ClipboardTransform.crc32("hello"), "3610a686")
    }

    // MARK: - JWT

    func testJWTEncodeDecode() {
        let payload = "{\"sub\":\"123\"}"
        guard let jwt = ClipboardTransform.jwtEncode(payload) else { XCTFail("jwtEncode failed"); return }
        XCTAssertTrue(jwt.contains("."))
        let parts = jwt.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        guard let decoded = ClipboardTransform.jwtDecode(jwt) else { XCTFail("jwtDecode failed"); return }
        XCTAssertTrue(decoded.contains("sub"))
    }

    // MARK: - JSON

    func testJsonPrettifyMinify() {
        let min = "{\"a\":1,\"b\":2}"
        let pretty = ClipboardTransform.jsonPrettify(min)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertEqual(ClipboardTransform.jsonMinify(pretty), min)
    }

    func testJsonSortKeys_minifiedInput_returnsMinifiedSortedOutput() {
        // No newlines → minify sorted output
        let result = ClipboardTransform.jsonSortKeys("{\"z\":3,\"a\":1,\"m\":2}")
        XCTAssertEqual(result, "{\"a\":1,\"m\":2,\"z\":3}")
        XCTAssertFalse(result.contains("\n"))
    }

    func testJsonSortKeys_prettyInput_returnsPrettifiedSortedOutput() {
        // Has newlines → prettify sorted output
        let input = "{\n  \"z\": 3,\n  \"a\": 1\n}"
        let result = ClipboardTransform.jsonSortKeys(input)
        XCTAssertTrue(result.contains("\n"))
        let aRange = result.range(of: "\"a\"")!
        let zRange = result.range(of: "\"z\"")!
        XCTAssertTrue(aRange.lowerBound < zRange.lowerBound, "\"a\" should appear before \"z\" in prettified output")
    }

    func testJsonSortKeys_invalidJson_returnsInputUnchanged() {
        let bad = "not json"
        XCTAssertEqual(ClipboardTransform.jsonSortKeys(bad), bad)
    }

    // MARK: - YAML

    func testYamlPrettifyMinify() {
        let json = "{\"a\":1}"
        XCTAssertTrue(ClipboardTransform.yamlPrettify(json).contains("\n"))
        XCTAssertEqual(ClipboardTransform.yamlMinify(json), "{\"a\":1}")
    }

    func testYamlMinify_structurePreserved() {
        let input = """
        abcde: null
        arrayObject:
          - red
          - green
          - blue
        key1: value1
        key2: false
        key3: 1.7
        subObject:
          key4: true
        """
        let expected = "{abcde: null, arrayObject: [red, green, blue], key1: value1, key2: false, key3: 1.7, subObject: {key4: true}}"
        XCTAssertEqual(ClipboardTransform.yamlMinify(input), expected)
    }

    func testYamlMinify_preservesQuotedNumberAsString() {
        let input = "key: '1.7'"
        let expected = "{key: '1.7'}"
        XCTAssertEqual(ClipboardTransform.yamlMinify(input), expected)
        let prettified = ClipboardTransform.yamlPrettify(expected)
        XCTAssertTrue(prettified.contains("key: '1.7'"), "prettify should preserve quoted string")
    }

    func testYamlPrettify_unminifiesMinifiedInput() {
        let minified = "{abcde: null, arrayObject: [red line, green, blue], key1: value1, key2: false, key3: '1.7', subObject: {key4: true}}"
        let result = ClipboardTransform.yamlPrettify(minified)
        XCTAssertTrue(result.contains("abcde: null"), "should contain abcde")
        XCTAssertTrue(result.contains("arrayObject:"), "should contain arrayObject key")
        XCTAssertTrue(result.contains("- red line"), "should contain list item with space")
        XCTAssertTrue(result.contains("- green"), "should contain green")
        XCTAssertTrue(result.contains("- blue"), "should contain blue")
        XCTAssertTrue(result.contains("key1: value1"), "should contain key1")
        XCTAssertTrue(result.contains("key2: false"), "should contain key2")
        XCTAssertTrue(result.contains("key3: '1.7'"), "quoted number should be emitted as string key3: '1.7'")
        XCTAssertTrue(result.contains("subObject:"), "should contain subObject")
        XCTAssertTrue(result.contains("key4: true"), "should contain nested key4")
        XCTAssertTrue(result.contains("\n"), "output should be multi-line")
    }

    func testJsonToYaml() throws {
        let json = "{\"name\":\"x\",\"count\":2}"
        let yaml = try ClipboardTransform.jsonToYaml(json)
        XCTAssertTrue(yaml.contains("name:"))
    }

    /// JSON string values that look like numbers (e.g. "2.8") must be emitted quoted in YAML so they stay strings.
    func testJsonToYaml_preservesQuotedNumbersAsStrings() throws {
        let minifiedJson = "{\"key5\":\"2.8\",\"key2\":false,\"key3\":1.7,\"key1\":\"value1\"}"
        let yaml = try ClipboardTransform.jsonToYaml(minifiedJson)
        // key5 is a string "2.8" in JSON; YAML must quote it so it stays a string (key5: "2.8")
        XCTAssertTrue(yaml.contains("key5: \"2.8\""), "key5 string value 2.8 must be quoted in YAML; got: \(yaml)")
        // key3 is a number 1.7 in JSON; YAML should emit unquoted
        XCTAssertTrue(yaml.contains("key3: 1.7"), "key3 numeric value should be unquoted; got: \(yaml)")
        // Round-trip: YAML -> JSON should still have key5 as string
        let backJson = try ClipboardTransform.yamlToJson(yaml)
        guard let data = backJson.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("round-trip JSON should be valid")
            return
        }
        XCTAssertEqual(obj["key5"] as? String, "2.8", "key5 must remain a string after JSON->YAML->JSON")
        XCTAssertEqual(obj["key3"] as? Double, 1.7, "key3 must remain a number")
    }

    func testYamlToJson() throws {
        let yaml = "a: 1\nb: 2"
        let json = try ClipboardTransform.yamlToJson(yaml)
        XCTAssertTrue(json.contains("a"))
    }

    func testYamlToJson_minifiedYamlProducesMinifiedJson() throws {
        let minifiedYaml = "{abcde: null, arrayObject: [red line, green, blue], key1: value1, key2: false, key3: '1.7', subObject: {key4: true}}"
        let json = try ClipboardTransform.yamlToJson(minifiedYaml)
        XCTAssertFalse(json.contains("\n"), "minified YAML input should produce single-line JSON")
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("output should be valid JSON object")
            return
        }
        XCTAssertTrue(obj["abcde"] is NSNull)
        XCTAssertEqual(obj["key1"] as? String, "value1")
        XCTAssertEqual(obj["key2"] as? Bool, false)
        XCTAssertEqual(obj["key3"] as? String, "1.7")
        XCTAssertEqual(obj["arrayObject"] as? [String], ["red line", "green", "blue"])
        XCTAssertEqual((obj["subObject"] as? [String: Any])?["key4"] as? Bool, true)
    }

    func testYamlToJson_topLevelArrayOfObjects() throws {
        let yaml = """
        -
          one: hello!
          two: "10"
        -
          one: goodbuy
          two: "20"
        """

        let json = try ClipboardTransform.yamlToJson(yaml)
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("output should be a valid JSON array")
            return
        }

        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0]["one"] as? String, "hello!")
        XCTAssertEqual(arr[0]["two"] as? String, "10")
        XCTAssertEqual(arr[1]["one"] as? String, "goodbuy")
        XCTAssertEqual(arr[1]["two"] as? String, "20")
    }

    // MARK: - CSV / JSON

    func testCsvToJson() throws {
        let csv = "a,b\n1,2\n3,4"
        let json = try ClipboardTransform.csvToJson(csv)
        XCTAssertTrue(json.contains("a") && json.contains("1"))
    }

    func testJsonArrayToCsv() throws {
        let json = "[{\"a\":1,\"b\":2},{\"a\":3,\"b\":4}]"
        let csv = try ClipboardTransform.jsonArrayToCsv(json)
        XCTAssertTrue(csv.contains("a,b") || csv.contains("b,a"))
    }

    func testCsvToTsv() {
        let csv = "a,b\n1,2"
        let tsv = ClipboardTransform.csvToTsv(csv)
        XCTAssertTrue(tsv.contains("\t"))
    }

    func testCsvToPsv() {
        let csv = "a,b\n1,2"
        let psv = ClipboardTransform.csvToPsv(csv)
        XCTAssertEqual(psv, "a|b\n1|2")
    }

    func testPsvToCsv() throws {
        let psv = "a|b\n1|2"
        let csv = try ClipboardTransform.psvToCsv(psv)
        XCTAssertEqual(csv, "a,b\n1,2")
    }

    func testTsvToCsv() throws {
        let tsv = "a\tb\n1\t2"
        let csv = try ClipboardTransform.tsvToCsv(tsv)
        XCTAssertEqual(csv, "a,b\n1,2")
    }

    func testMysqlCliTableToCsv() throws {
        let input = """
        Some noise before the table
        mysql> SELECT * FROM something;

        +--------------------------------+---------------+------------------------------+--------------+
        | GRANTEE                        | TABLE_CATALOG | PRIVILEGE_TYPE               | IS_GRANTABLE |
        +--------------------------------+---------------+------------------------------+--------------+
        | 'rdsadmin'@'localhost'         | def           | SELECT                       | YES          |
        | 'rdsadmin'@'localhost'         | def           | INSERT                       | YES          |
        +--------------------------------+---------------+------------------------------+--------------+

        2 rows in set (0.00 sec)
        """

        let expected = """
        GRANTEE,TABLE_CATALOG,PRIVILEGE_TYPE,IS_GRANTABLE
        'rdsadmin'@'localhost',def,SELECT,YES
        'rdsadmin'@'localhost',def,INSERT,YES
        """

        XCTAssertEqual(try ClipboardTransform.mysqlCliTableToCsv(input), expected)
    }

    func testMysqlCliTableToCsv_invalidInputReturnsNil() {
        let input = """
        not a mysql cli table
        | header | row |
        """

        XCTAssertThrowsError(try ClipboardTransform.mysqlCliTableToCsv(input)) { error in
            XCTAssertTrue(String(describing: error).contains("could not find a complete +--- table border block"))
        }
    }

    func testPsqlCliTableToCsv() throws {
        let input = """
        pid | datname | username | client_addr | client_port | backend_start | query_start | query | state
        -------+---------+----------+----------------+-------------+---------------------+---------------------+------------------------------------------------------+---------------------
        1234 | mydb1 | postgres | 192.168.1.100 | 5432 | 2023-10-04 15:04:00 | 2023-10-04 15:04:05 | SELECT * FROM mytable; | active
        5678 | mydb2 | user1 | 192.168.1.101 | 5432 | 2023-10-04 15:05:00 | 2023-10-04 15:05:03 | UPDATE mytable SET name = 'John Doe' WHERE id = 123; | idle in transaction
        9012 | postgres | user2 | 192.168.1.102 | 5432 | 2023-10-04 15:06:00 |  |  | idle
        """

        let expected = """
        pid,datname,username,client_addr,client_port,backend_start,query_start,query,state
        1234,mydb1,postgres,192.168.1.100,5432,2023-10-04 15:04:00,2023-10-04 15:04:05,SELECT * FROM mytable;,active
        5678,mydb2,user1,192.168.1.101,5432,2023-10-04 15:05:00,2023-10-04 15:05:03,UPDATE mytable SET name = 'John Doe' WHERE id = 123;,idle in transaction
        9012,postgres,user2,192.168.1.102,5432,2023-10-04 15:06:00,,,idle
        """

        XCTAssertEqual(try ClipboardTransform.psqlCliTableToCsv(input), expected)
    }

    func testPsqlCliTableToCsv_matchesProvidedSampleShape() throws {
        let input = """
        pid | datname | username | client_addr | client_port | backend_start | query_start | query | state
        -------+---------+---------+-------------+-------------+---------------+---------------+-----------------+----------
        1234 | mydb1   | postgres | 192.168.1.100 | 5432 | 2023-10-04 15:04:00 | 2023-10-04 15:04:05 | SELECT * FROM mytable; | active
        5678 | mydb2   | user1    | 192.168.1.101 | 5432 | 2023-10-04 15:05:00 | 2023-10-04 15:05:03 | UPDATE mytable SET name = 'John Doe' WHERE id = 123; | idle in transaction
        9012 | postgres | 192.168.1.102 | 5432 | 2023-10-04 15:06:00 |                |                | idle |
        """

        let expected = """
        pid,datname,username,client_addr,client_port,backend_start,query_start,query,state
        1234,mydb1,postgres,192.168.1.100,5432,2023-10-04 15:04:00,2023-10-04 15:04:05,SELECT * FROM mytable;,active
        5678,mydb2,user1,192.168.1.101,5432,2023-10-04 15:05:00,2023-10-04 15:05:03,UPDATE mytable SET name = 'John Doe' WHERE id = 123;,idle in transaction
        9012,postgres,192.168.1.102,5432,2023-10-04 15:06:00,,,idle,
        """

        XCTAssertEqual(try ClipboardTransform.psqlCliTableToCsv(input), expected)
    }

    func testPsqlCliTableToCsv_ignoresRowCountFooter() throws {
        let input = """
        pid | datname
        -----+---------
        1234 | mydb1

        (1 row)
        """

        let expected = """
        pid,datname
        1234,mydb1
        """

        XCTAssertEqual(try ClipboardTransform.psqlCliTableToCsv(input), expected)
    }

    func testPsqlCliTableToCsv_invalidInputReturnsNil() {
        let input = """
        pid | datname
        not-a-separator
        1234 | mydb1
        """

        XCTAssertThrowsError(try ClipboardTransform.psqlCliTableToCsv(input)) { error in
            XCTAssertTrue(String(describing: error).contains("could not find the dashed separator line"))
        }
    }

    func testSqlite3TableToCsv() throws {
        let input = """
        one      two
        -------  ---
        hello!   10
        goodbuy  20
        """

        let expected = """
        one,two
        hello!,10
        goodbuy,20
        """

        XCTAssertEqual(try ClipboardTransform.sqlite3TableToCsv(input), expected)
    }

    // MARK: - Quote escaping

    func testEscapeUnescapeDoubleQuotes() {
        let s = "a\"b"
        XCTAssertEqual(ClipboardTransform.unescapeDoubleQuotes(ClipboardTransform.escapeDoubleQuotes(s)), s)
    }

    func testEscapeUnescapeSingleQuotes() {
        let s = "a'b"
        XCTAssertEqual(ClipboardTransform.unescapeSingleQuotes(ClipboardTransform.escapeSingleQuotes(s)), s)
    }

    func testEscapeUnescapeBackslashes() {
        let s = "a\\b"
        XCTAssertEqual(ClipboardTransform.unescapeBackslashes(ClipboardTransform.escapeBackslashes(s)), s)
    }

    func testEscapeUnescapeDollar() {
        let s = "a$b"
        XCTAssertEqual(ClipboardTransform.unescapeDollar(ClipboardTransform.escapeDollar(s)), s)
    }

    // MARK: - Line tools

    func testWindowsNewlinesToUnix() {
        XCTAssertEqual(ClipboardTransform.windowsNewlinesToUnix("a\r\nb\r\n"), "a\nb\n")
    }

    func testSortLines() {
        XCTAssertEqual(ClipboardTransform.sortLines("c\na\nb"), "a\nb\nc")
    }

    func testDeduplicateLines() {
        XCTAssertEqual(ClipboardTransform.deduplicateLines("a\nb\na"), "a\nb")
    }

    func testSortAndDeduplicateLines() {
        XCTAssertEqual(ClipboardTransform.sortAndDeduplicateLines("c\na\nb\na"), "a\nb\nc")
    }

    func testReverseLines() {
        XCTAssertEqual(ClipboardTransform.reverseLines("a\nb\nc"), "c\nb\na")
    }

    func testRemoveEmptyLines() {
        XCTAssertEqual(ClipboardTransform.removeEmptyLines("a\n\nb\n\n\nc"), "a\nb\nc")
        XCTAssertEqual(ClipboardTransform.removeEmptyLines("a\n   \nb"), "a\nb", "Whitespace-only lines should be removed")
        XCTAssertEqual(ClipboardTransform.removeEmptyLines("a\nb"), "a\nb", "No empty lines: unchanged")
    }

    func testIndentLines() {
        XCTAssertEqual(ClipboardTransform.indentLines("a\nb"), "\ta\n\tb")
        XCTAssertEqual(ClipboardTransform.indentLines(""), "\t")
    }

    func testUnindentLines() {
        XCTAssertEqual(ClipboardTransform.unindentLines("\ta\n\tb"), "a\nb")
        XCTAssertEqual(ClipboardTransform.unindentLines("a\n\tb"), "a\nb", "Lines without leading tab are left unchanged")
    }

    func testIndentUnindentRoundTrip() {
        let s = "foo\nbar\nbaz"
        XCTAssertEqual(ClipboardTransform.unindentLines(ClipboardTransform.indentLines(s)), s)
    }

    func testTrimLines() {
        XCTAssertEqual(ClipboardTransform.trimLines("  a  \n  b  "), "a\nb")
        XCTAssertEqual(ClipboardTransform.trimLines("no padding"), "no padding")
        XCTAssertEqual(ClipboardTransform.trimLines("\t hello \t\n world"), "hello\nworld")
    }

    // MARK: - HTML escaping

    func testHtmlEscape() {
        XCTAssertEqual(ClipboardTransform.htmlEscape("<b>\"hi\" & 'you'</b>"),
                       "&lt;b&gt;&quot;hi&quot; &amp; &#39;you&#39;&lt;/b&gt;")
    }

    func testHtmlUnescape() {
        XCTAssertEqual(ClipboardTransform.htmlUnescape("&lt;b&gt;&quot;hi&quot; &amp; &#39;you&#39;&lt;/b&gt;"),
                       "<b>\"hi\" & 'you'</b>")
    }

    func testHtmlEscapeUnescapeRoundTrip() {
        let s = "<script>alert(\"xss\" & 'injection')</script>"
        XCTAssertEqual(ClipboardTransform.htmlUnescape(ClipboardTransform.htmlEscape(s)), s)
    }

    func testHtmlEscape_ampersandFirst() {
        // Ampersands in the input should not be double-escaped
        XCTAssertEqual(ClipboardTransform.htmlEscape("a & b"), "a &amp; b")
        XCTAssertEqual(ClipboardTransform.htmlUnescape("a &amp; b"), "a & b")
    }

    // MARK: - parseCSVLine

    func testParseCSVLine() {
        let row = ClipboardTransform.parseCSVLine("a,\"b,c\",d")
        XCTAssertEqual(row, ["a", "b,c", "d"])
    }

    // MARK: - Argon2id (phc-winner-argon2 via Argon2PHC)

    /// Deterministic test: fixed salt lets us compare against the argon2-cffi Python reference.
    /// Reference command:
    ///   from argon2.low_level import hash_secret_raw, Type; import base64
    ///   hash_secret_raw(b"test-string", b"testsalttestsalt", time_cost=1, memory_cost=2048,
    ///                   parallelism=1, hash_len=32, type=Type.ID)
    ///   → tag b64 (no padding): zWovv0ZTstoTMc7fqZAl/hby11hra4FQFSFYAGW2IFs
    func testArgon2idDeterministic() {
        let password = Data("test-string".utf8)
        let salt     = Data("testsalttestsalt".utf8)  // 16 bytes
        guard let phc = Argon2PHC.hash(
            password: password, salt: salt,
            memoryKiB: 2048, iterations: 1, parallelism: 1, tagLength: 32
        ) else {
            XCTFail("Argon2PHC.hash returned nil")
            return
        }
        // PHC string: $argon2id$v=19$m=...,t=...,p=...$<salt>$<tag> → 5 $ -delimited fields
        let parts = phc.split(separator: "$", omittingEmptySubsequences: true)
        XCTAssertEqual(parts.count, 5, "PHC string should have 5 fields — got: \(phc)")
        let tagB64 = String(parts[4])
        XCTAssertEqual(tagB64, "zWovv0ZTstoTMc7fqZAl/hby11hra4FQFSFYAGW2IFs",
                       "Argon2id tag does not match reference. Full PHC: \(phc)")
    }

    // MARK: - ClipboardSet (Random: ULID, etc.)

    /// ULID must never return nil (would cause "beep" in UI). Length 26, Crockford base32 alphabet.
    func testRandomULIDNeverNilAndValidFormat() {
        let crockfordBase32 = CharacterSet(charactersIn: "0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        for _ in 0..<50 {
            guard let ulid = ClipboardSet.randomULID() else {
                XCTFail("ClipboardSet.randomULID() returned nil — would beep without setting clipboard")
                return
            }
            XCTAssertEqual(ulid.count, 26, "ULID must be 26 characters; got \(ulid.count): \(ulid)")
            for scalar in ulid.unicodeScalars {
                XCTAssertTrue(crockfordBase32.contains(scalar), "ULID must use only Crockford base32; got invalid char in: \(ulid)")
            }
        }
    }

    /// ULIDs should be lexicographically sortable (timestamp in first 48 bits).
    func testRandomULIDSortable() {
        var ulids: [String] = []
        for _ in 0..<20 {
            guard let ulid = ClipboardSet.randomULID() else {
                XCTFail("ClipboardSet.randomULID() returned nil")
                return
            }
            ulids.append(ulid)
        }
        let sorted = ulids.sorted()
        for i in 0..<(sorted.count - 1) {
            XCTAssertLessThanOrEqual(sorted[i], sorted[i + 1], "ULIDs should be in sort order")
        }
    }
}
