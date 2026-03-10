import XCTest
@testable import Clipboard_Envy

@MainActor
final class ClipboardHelpersTests: XCTestCase {
    private func decodeJSONArray(_ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> [[String: Any]] {
        let data = try XCTUnwrap(json.data(using: .utf8), file: file, line: line)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            file: file,
            line: line
        )
    }

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

    func testJsonPrettifyMinify_supportsCommentedJsonLines() {
        let commented = """
            // this is a comment
            {
              // inline group comment
              "b": 2,
              "a": 1
            }
            """
        let minified = ClipboardTransform.jsonMinify(commented)
        let minifiedObj = try? JSONSerialization.jsonObject(with: Data(minified.utf8)) as? [String: Int]
        XCTAssertEqual(minifiedObj, ["a": 1, "b": 2])
        let pretty = ClipboardTransform.jsonPrettify(commented)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("\"a\""))
        XCTAssertTrue(pretty.contains("\"b\""))
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

    func testJsonStripNulls_minifiedInput() {
        let input = #"{"a":1,"b":null,"c":"null","d":{"e":null,"f":2},"g":[1,null,"null",{"h":null,"i":3}]}"#
        let result = ClipboardTransform.jsonStripNulls(input)
        let expected = #"{"a":1,"c":"null","d":{"f":2},"g":[1,"null",{"i":3}]}"#
        XCTAssertEqual(result, expected)
    }

    func testJsonStripNulls_prettyInput() throws {
        let input = """
        {
          "a": null,
          "b": {
            "c": 1,
            "d": null
          },
          "e": [
            null,
            2
          ]
        }
        """
        let result = ClipboardTransform.jsonStripNulls(input)
        let rows = try decodeJSONArray("[\(result)]")
        let obj = try XCTUnwrap(rows.first)

        XCTAssertNil(obj["a"])
        XCTAssertEqual((obj["b"] as? [String: Any])?["c"] as? Int, 1)
        XCTAssertNil((obj["b"] as? [String: Any])?["d"])
        XCTAssertEqual(obj["e"] as? [Int], [2])
    }

    func testJsonStripNulls_invalidJson_returnsInputUnchanged() {
        let bad = "not json"
        XCTAssertEqual(ClipboardTransform.jsonStripNulls(bad), bad)
    }

    func testJsonStripEmptyStrings_minifiedInput() {
        let input = #"{"a":1,"b":"","c":"hello","d":{"e":"","f":2},"g":[1,"","world",{"h":"","i":3}]}"#
        let result = ClipboardTransform.jsonStripEmptyStrings(input)
        let expected = #"{"a":1,"c":"hello","d":{"f":2},"g":[1,"world",{"i":3}]}"#
        XCTAssertEqual(result, expected)
    }

    func testJsonStripEmptyStrings_prettyInput() throws {
        let input = """
        {
          "a": "",
          "b": {
            "c": 1,
            "d": ""
          },
          "e": [
            "",
            2
          ]
        }
        """
        let result = ClipboardTransform.jsonStripEmptyStrings(input)
        let rows = try decodeJSONArray("[\(result)]")
        let obj = try XCTUnwrap(rows.first)

        XCTAssertNil(obj["a"])
        XCTAssertEqual((obj["b"] as? [String: Any])?["c"] as? Int, 1)
        XCTAssertNil((obj["b"] as? [String: Any])?["d"])
        XCTAssertEqual(obj["e"] as? [Int], [2])
    }

    func testJsonStripEmptyStrings_invalidJson_returnsInputUnchanged() {
        let bad = "not json"
        XCTAssertEqual(ClipboardTransform.jsonStripEmptyStrings(bad), bad)
    }

    func testJsonStripEmptyStrings_supportCommentedJsonLines() {
        let commented = """
            // comment
            {"obj":{"a":1,"b":""},"arr":[{"c":2},""]}
            """
        XCTAssertEqual(ClipboardTransform.jsonStripEmptyStrings(commented), "{\"arr\":[{\"c\":2}],\"obj\":{\"a\":1}}")
    }

    func testJsonTransforms_supportCommentedJsonLines() {
        let commented = """
            // comment
            {"obj":{"a":1,"b":null},"arr":[{"c":2},null]}
            """
        XCTAssertEqual(ClipboardTransform.jsonSortKeys(commented), "{\"arr\":[{\"c\":2},null],\"obj\":{\"a\":1,\"b\":null}}")
        XCTAssertEqual(ClipboardTransform.jsonStripNulls(commented), "{\"arr\":[{\"c\":2}],\"obj\":{\"a\":1}}")
        XCTAssertEqual(ClipboardTransform.jsonTopLevelKeys(commented), "arr\nobj")
        XCTAssertEqual(ClipboardTransform.jsonAllKeys(commented), "a\narr\nb\nc\nobj")
    }

    func testJsonTopLevelKeys_object_returnsOnlyRootKeysSorted() {
        let input = #"{"z":1,"a":{"k":2},"m":[{"inner":3}]}"#
        let result = ClipboardTransform.jsonTopLevelKeys(input)
        XCTAssertEqual(result, "a\nm\nz")
    }

    func testJsonTopLevelKeys_array_returnsUnionOfObjectElementKeysSorted() {
        let input = #"[{"a":1,"z":9},{"b":2},{"a":3,"m":4},5]"#
        let result = ClipboardTransform.jsonTopLevelKeys(input)
        XCTAssertEqual(result, "a\nb\nm\nz")
    }

    func testJsonAllKeys_returnsRecursiveUnionSorted() {
        let input = #"{"root":1,"obj":{"a":2,"nested":{"b":3}},"arr":[{"c":4},5],"z":null}"#
        let result = ClipboardTransform.jsonAllKeys(input)
        XCTAssertEqual(result, "a\narr\nb\nc\nnested\nobj\nroot\nz")
    }

    func testJsonTopLevelKeys_invalidJson_returnsInputUnchanged() {
        let bad = "not json"
        XCTAssertEqual(ClipboardTransform.jsonTopLevelKeys(bad), bad)
    }

    func testJsonAllKeys_invalidJson_returnsInputUnchanged() {
        let bad = "not json"
        XCTAssertEqual(ClipboardTransform.jsonAllKeys(bad), bad)
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

    func testJsonToYaml_supportsCommentedJsonLines() throws {
        let commented = """
            // metadata comment
            {"name":"x","count":2}
            """
        let yaml = try ClipboardTransform.jsonToYaml(commented)
        XCTAssertTrue(yaml.contains("name: x"))
        XCTAssertTrue(yaml.contains("count: 2"))
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
        let csv = """
        id,enabled,label,score
        12,True,red,1
        24,t,blue,2.5
        29,NULL,NULL,NULL
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, true)
        XCTAssertEqual(rows[0]["label"] as? String, "red")
        let score = try XCTUnwrap((rows[1]["score"] as? NSNumber)?.doubleValue)
        XCTAssertEqual(score, 2.5, accuracy: 0.0001)
        XCTAssertTrue(rows[2]["enabled"] is NSNull)
        XCTAssertTrue(rows[2]["label"] is NSNull)
        XCTAssertTrue(rows[2]["score"] is NSNull)
    }

    func testCsvToJson_usesExplicitDatatypesRow() throws {
        let csv = """
        id,enabled,label,score,created_at
        INT,BOOLEAN,VARCHAR(255),"DECIMAL(10,2)",DATETIME
        12,true,red,1.25,2026-03-09 12:34:56
        29,NULL,NULL,NULL,NULL
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, true)
        XCTAssertEqual((rows[0]["score"] as? NSNumber)?.doubleValue, 1.25)
        XCTAssertEqual(rows[0]["label"] as? String, "red")
        XCTAssertEqual(rows[0]["created_at"] as? String, "2026-03-09 12:34:56")
        XCTAssertTrue(rows[1]["enabled"] is NSNull)
        XCTAssertTrue(rows[1]["label"] is NSNull)
        XCTAssertTrue(rows[1]["score"] is NSNull)
        XCTAssertTrue(rows[1]["created_at"] is NSNull)
    }

    func testCsvToJson_datatypesRowDetectionIsCaseInsensitive() throws {
        let csv = """
        id,enabled
        uInT64,bOoLeAn
        24,F
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["id"] as? Int, 24)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, false)
    }

    func testCsvToJson_nonDatatypeSecondRowFallsBackToInference() throws {
        let csv = """
        id,label
        12,red
        24,blue
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["label"] as? String, "red")
    }

    func testCsvToJson_infersNumericColumnWhenRemainingCellsAreBlank() throws {
        let csv = """
        id,label
        12,12
        24,12
        29,
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0]["label"] as? Int, 12)
        XCTAssertEqual(rows[1]["label"] as? Int, 12)
        XCTAssertTrue(rows[2]["label"] is NSNull)
    }

    func testCsvToJson_emptyStringCellsAreNull() throws {
        let csv = """
        id,name,description
        1,Alice,
        2,,hello
        3,,
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJson(csv))

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0]["name"] as? String, "Alice")
        XCTAssertTrue(rows[0]["description"] is NSNull, "empty string cell should be null")
        XCTAssertTrue(rows[1]["name"] is NSNull, "empty string cell should be null")
        XCTAssertEqual(rows[1]["description"] as? String, "hello")
        XCTAssertTrue(rows[2]["name"] is NSNull)
        XCTAssertTrue(rows[2]["description"] is NSNull)
    }

    func testCsvToJsonStrings() throws {
        let csv = """
        id,enabled,label
        12,True,red
        29,NULL,NULL
        """
        let rows = try decodeJSONArray(ClipboardTransform.csvToJsonStrings(csv))

        XCTAssertEqual(rows[0]["id"] as? String, "12")
        XCTAssertEqual(rows[0]["enabled"] as? String, "True")
        XCTAssertEqual(rows[1]["label"] as? String, "NULL")
    }

    func testJsonArrayToCsv() throws {
        let json = "[{\"a\":1,\"b\":2},{\"a\":3,\"b\":4}]"
        let csv = try ClipboardTransform.jsonArrayToCsv(json)
        XCTAssertTrue(csv.contains("a,b") || csv.contains("b,a"))
    }

    func testJsonArrayToCsv_supportsCommentedJsonLines() throws {
        let json = """
            \t// exported rows
            [{"a":1,"b":2},{"a":3,"b":4}]
            """
        let csv = try ClipboardTransform.jsonArrayToCsv(json)
        XCTAssertTrue(csv.contains("a,b"), "expected sorted headers")
        XCTAssertTrue(csv.contains("1,2"))
        XCTAssertTrue(csv.contains("3,4"))
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

    func testMysqlCliTableToCsv_convertsNullToEmptyCell() throws {
        let input = """
        mysql> select * from colors;
        +--------+-------+
        | id     | label |
        +--------+-------+
        |     12 | red   |
        |     24 | blue  |
        |     29 | NULL  |
        +--------+-------+
        """

        let expected = """
        id,label
        12,red
        24,blue
        29,
        """

        XCTAssertEqual(try ClipboardTransform.mysqlCliTableToCsv(input), expected)
    }

    func testMysqlCliTableToJson_infersTypesAndNulls() throws {
        let input = """
        mysql> select * from colors;
        +--------+---------+---------+
        | id     | enabled | label   |
        +--------+---------+---------+
        |     12 | True    | red     |
        |     24 | f       | blue    |
        |     29 | NULL    | NULL    |
        +--------+---------+---------+
        """

        let rows = try decodeJSONArray(ClipboardTransform.mysqlCliTableToJson(input))
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, true)
        XCTAssertEqual(rows[1]["enabled"] as? Bool, false)
        XCTAssertTrue(rows[2]["enabled"] is NSNull)
        XCTAssertTrue(rows[2]["label"] is NSNull)
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

    func testPsqlCliTableToCsv_convertsNullToEmptyCell() throws {
        let input = """
        id | label
        ----+-------
        12 | red
        24 | blue
        29 | NULL
        """

        let expected = """
        id,label
        12,red
        24,blue
        29,
        """

        XCTAssertEqual(try ClipboardTransform.psqlCliTableToCsv(input), expected)
    }

    func testPsqlCliTableToJson_infersTypesAndNulls() throws {
        let input = """
        id | enabled | label
        ----+---------+-------
        12 | True | red
        24 | f | blue
        29 | NULL | NULL
        """

        let rows = try decodeJSONArray(ClipboardTransform.psqlCliTableToJson(input))
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, true)
        XCTAssertEqual(rows[1]["enabled"] as? Bool, false)
        XCTAssertTrue(rows[2]["enabled"] is NSNull)
        XCTAssertTrue(rows[2]["label"] is NSNull)
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

    func testSqlite3TableToCsv_convertsNullToEmptyCell() throws {
        let input = """
        id  label
        --  -----
        12  red
        24  blue
        29  NULL
        """

        let expected = """
        id,label
        12,red
        24,blue
        29,
        """

        XCTAssertEqual(try ClipboardTransform.sqlite3TableToCsv(input), expected)
    }

    func testSqlite3TableToJson_infersTypesAndNulls() throws {
        let input = """
        id  enabled  label
        --  -------  -----
        12  True     red
        24  f        blue
        29  NULL     NULL
        """

        let rows = try decodeJSONArray(ClipboardTransform.sqlite3TableToJson(input))
        XCTAssertEqual(rows[0]["id"] as? Int, 12)
        XCTAssertEqual(rows[0]["enabled"] as? Bool, true)
        XCTAssertEqual(rows[1]["enabled"] as? Bool, false)
        XCTAssertTrue(rows[2]["enabled"] is NSNull)
        XCTAssertTrue(rows[2]["label"] is NSNull)
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

    // MARK: - Time Format Parsing

    func testParseEpochSeconds() {
        let date = TimeFormat.parseEpochSeconds("1704067200")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseEpochMilliseconds() {
        let date = TimeFormat.parseEpochMilliseconds("1704067200000")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseEpochMilliseconds_rejectsShortNumbers() {
        XCTAssertNil(TimeFormat.parseEpochMilliseconds("1704067200"))
    }

    func testParseRFC3339_withZ() {
        let date = TimeFormat.parseRFC3339("2024-01-01T00:00:00.000Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseRFC3339_withOffset() {
        let date = TimeFormat.parseRFC3339("2024-01-01T00:00:00+00:00")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseRFC3339_withAbbreviation() {
        let date = TimeFormat.parseRFC3339("2024-01-01T00:00:00.000GMT")
        XCTAssertNotNil(date)
    }

    func testParseSQLDateTime() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        let expected = f.date(from: "2024-01-01 12:30:45")

        let date = TimeFormat.parseSQLDateTime("2024-01-01 12:30:45")
        XCTAssertNotNil(date)
        XCTAssertEqual(date, expected)
    }

    func testParseRFC1123() {
        let date = TimeFormat.parseRFC1123("Mon, 01 Jan 2024 00:00:00 GMT")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseSlashDateTime_YYYYMMDD() {
        let date = TimeFormat.parseSlashDateTime("2024/01/15")
        XCTAssertNotNil(date)
    }

    func testParseSlashDateTime_YYYYMMDDHHmmss() {
        let date = TimeFormat.parseSlashDateTime("2024/01/15 12:30:45")
        XCTAssertNotNil(date)
    }

    func testParseSlashDateTime_YYYYMMDDHH() {
        let date = TimeFormat.parseSlashDateTime("2024/01/15/12")
        XCTAssertNotNil(date)
    }

    func testParseSlashDateTime_YYMMDD() {
        let date = TimeFormat.parseSlashDateTime("24/01/15")
        XCTAssertNotNil(date)
    }

    func testParseSlashDateTime_YYMMDDHHmmss() {
        let date = TimeFormat.parseSlashDateTime("24/01/15 12:30:45")
        XCTAssertNotNil(date)
    }

    func testParseSlashDateTime_twoDigitYear_lessThan70_treatedAs2000s() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let date26 = TimeFormat.parseSlashDateTime("26/03/10 21:11:53")
        XCTAssertNotNil(date26)
        XCTAssertEqual(calendar.component(.year, from: date26!), 2026)

        let date00 = TimeFormat.parseSlashDateTime("00/06/15")
        XCTAssertNotNil(date00)
        XCTAssertEqual(calendar.component(.year, from: date00!), 2000)

        let date69 = TimeFormat.parseSlashDateTime("69/12/31")
        XCTAssertNotNil(date69)
        XCTAssertEqual(calendar.component(.year, from: date69!), 2069)
    }

    func testParseSlashDateTime_twoDigitYear_70orGreater_treatedAs1900s() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let date70 = TimeFormat.parseSlashDateTime("70/01/01")
        XCTAssertNotNil(date70)
        XCTAssertEqual(calendar.component(.year, from: date70!), 1970)

        let date99 = TimeFormat.parseSlashDateTime("99/12/31 23:59:59")
        XCTAssertNotNil(date99)
        XCTAssertEqual(calendar.component(.year, from: date99!), 1999)

        let date85 = TimeFormat.parseSlashDateTime("85/07/04")
        XCTAssertNotNil(date85)
        XCTAssertEqual(calendar.component(.year, from: date85!), 1985)
    }

    func testParseSlashDateTime_fourDigitYear_unchanged() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let date2026 = TimeFormat.parseSlashDateTime("2026/03/10")
        XCTAssertNotNil(date2026)
        XCTAssertEqual(calendar.component(.year, from: date2026!), 2026)

        let date1985 = TimeFormat.parseSlashDateTime("1985/07/04")
        XCTAssertNotNil(date1985)
        XCTAssertEqual(calendar.component(.year, from: date1985!), 1985)
    }

    func testParseAnyFormat_detectsEpochSeconds() {
        let date = TimeFormat.parseAnyFormat("1704067200")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseAnyFormat_detectsEpochMilliseconds() {
        let date = TimeFormat.parseAnyFormat("1704067200000")
        XCTAssertNotNil(date)
        XCTAssertEqual(Int(date!.timeIntervalSince1970), 1704067200)
    }

    func testParseAnyFormat_detectsRFC3339() {
        let date = TimeFormat.parseAnyFormat("2024-01-01T00:00:00.000Z")
        XCTAssertNotNil(date)
    }

    func testParseAnyFormat_detectsSQLDateTime() {
        let date = TimeFormat.parseAnyFormat("2024-01-01 12:30:45")
        XCTAssertNotNil(date)
    }

    func testParseAnyFormat_detectsRFC1123() {
        let date = TimeFormat.parseAnyFormat("Mon, 01 Jan 2024 00:00:00 GMT")
        XCTAssertNotNil(date)
    }

    func testParseAnyFormat_detectsSlashFormat() {
        let date = TimeFormat.parseAnyFormat("2024/01/15 12:30:45")
        XCTAssertNotNil(date)
    }

    func testParseAnyFormat_returnsNilForInvalidInput() {
        XCTAssertNil(TimeFormat.parseAnyFormat("not a date"))
        XCTAssertNil(TimeFormat.parseAnyFormat(""))
        XCTAssertNil(TimeFormat.parseAnyFormat("   "))
    }

    // MARK: - Time Output Formatting

    func testTimeOutputEpochSeconds() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.epochSeconds(from: date), "1704067200")
    }

    func testTimeOutputEpochMilliseconds() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.epochMilliseconds(from: date), "1704067200000")
    }

    func testTimeOutputSQLDateTimeUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.sqlDateTimeUTC(from: date), "2024-01-01 00:00:00")
    }

    func testTimeOutputRFC3339Z() {
        let date = Date(timeIntervalSince1970: 1704067200)
        let result = TimeOutput.rfc3339Z(from: date)
        XCTAssertTrue(result.hasSuffix("Z"))
        XCTAssertTrue(result.hasPrefix("2024-01-01T00:00:00"))
    }

    func testTimeOutputRFC1123UTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.rfc1123UTC(from: date), "Mon, 01 Jan 2024 00:00:00 GMT")
    }

    func testTimeOutputYYYYMMDDUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.yyyyMMddUTC(from: date), "2024/01/01")
    }

    func testTimeOutputYYYYMMDDHHmmssUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.yyyyMMddHHmmssUTC(from: date), "2024/01/01 00:00:00")
    }

    func testTimeOutputYYYYMMDDHHUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.yyyyMMddHHUTC(from: date), "2024/01/01/00")
    }

    func testTimeOutputYYMMDDUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.yyMMddUTC(from: date), "24/01/01")
    }

    func testTimeOutputYYMMDDHHmmssUTC() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(TimeOutput.yyMMddHHmmssUTC(from: date), "24/01/01 00:00:00")
    }

    // MARK: - Time Transform Round-trips

    func testTimeTransformEpochToRFC3339() {
        let result = ClipboardTransform.timeToRFC3339Z("1704067200")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("2024-01-01T00:00:00"))
    }

    func testTimeTransformRFC3339ToEpoch() {
        let result = ClipboardTransform.timeToEpochSeconds("2024-01-01T00:00:00.000Z")
        XCTAssertEqual(result, "1704067200")
    }

    func testTimeTransformSQLToRFC3339() {
        let result = ClipboardTransform.timeToRFC3339Z("2024-01-01 00:00:00")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("2024-01-01T"))
    }

    func testTimeTransformRFC1123ToEpoch() {
        let result = ClipboardTransform.timeToEpochSeconds("Mon, 01 Jan 2024 00:00:00 GMT")
        XCTAssertEqual(result, "1704067200")
    }

    func testTimeTransformSlashToEpoch() {
        let result = ClipboardTransform.timeToEpochSeconds("2024/01/15 12:30:45")
        XCTAssertNotNil(result)
    }

    func testTimeTransformInvalidInputReturnsNil() {
        XCTAssertNil(ClipboardTransform.timeToEpochSeconds("not a date"))
        XCTAssertNil(ClipboardTransform.timeToRFC3339Z("invalid"))
        XCTAssertNil(ClipboardTransform.timeToSQLDateTimeLocal("garbage"))
    }

    func testTimeTransformEpochMillisecondsToFormats() {
        let result = ClipboardTransform.timeToRFC3339Z("1704067200000")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("2024-01-01T00:00:00"))
    }

    func testTimeTransformToAllFormats() {
        let epoch = "1704067200"

        XCTAssertNotNil(ClipboardTransform.timeToEpochSeconds(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToEpochMilliseconds(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToSQLDateTimeLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToSQLDateTimeUTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToRFC3339Z(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToRFC3339WithOffset(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToRFC3339WithAbbreviation(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToRFC1123Local(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToRFC1123UTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDHHmmssLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDHHmmssUTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYMMDDHHmmssLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYMMDDHHmmssUTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDUTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDHHLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYYYMMDDHHUTC(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYMMDDLocal(epoch))
        XCTAssertNotNil(ClipboardTransform.timeToYYMMDDUTC(epoch))
    }

    // MARK: - ClipboardSet Time Functions

    func testClipboardSetEpochSeconds() {
        let result = ClipboardSet.epochSeconds()
        XCTAssertNotNil(Int(result))
    }

    func testClipboardSetEpochMilliseconds() {
        let result = ClipboardSet.epochMilliseconds()
        XCTAssertNotNil(Int64(result))
        XCTAssertTrue(result.count >= 13)
    }

    func testClipboardSetSQLDateTimeFormats() {
        let local = ClipboardSet.sqlDateTimeLocal()
        let utc = ClipboardSet.sqlDateTimeUTC()
        XCTAssertTrue(local.contains("-"))
        XCTAssertTrue(local.contains(":"))
        XCTAssertTrue(utc.contains("-"))
        XCTAssertTrue(utc.contains(":"))
    }

    func testClipboardSetRFC3339Formats() {
        let z = ClipboardSet.rfc3339Z()
        let offset = ClipboardSet.rfc3339WithOffset()
        let abbrev = ClipboardSet.rfc3339WithAbbreviation()
        XCTAssertTrue(z.hasSuffix("Z"))
        XCTAssertTrue(z.contains("T"))
        XCTAssertTrue(offset.contains("T"))
        XCTAssertTrue(abbrev.contains("T"))
    }

    func testClipboardSetRFC1123Formats() {
        let local = ClipboardSet.rfc1123Local()
        let utc = ClipboardSet.rfc1123UTC()
        XCTAssertTrue(local.contains(","))
        XCTAssertTrue(utc.hasSuffix("GMT"))
    }

    func testClipboardSetSlashFormats() {
        let yyyymmddLocal = ClipboardSet.yyyyMMddLocal()
        let yyyymmddUTC = ClipboardSet.yyyyMMddUTC()
        let yyyymmddhhLocal = ClipboardSet.yyyyMMddHHLocal()
        let yyyymmddhhUTC = ClipboardSet.yyyyMMddHHUTC()
        let yyyymmddhhmmssLocal = ClipboardSet.yyyyMMddHHmmssLocal()
        let yyyymmddhhmmssUTC = ClipboardSet.yyyyMMddHHmmssUTC()

        XCTAssertTrue(yyyymmddLocal.contains("/"))
        XCTAssertTrue(yyyymmddUTC.contains("/"))
        XCTAssertTrue(yyyymmddhhLocal.contains("/"))
        XCTAssertTrue(yyyymmddhhUTC.contains("/"))
        XCTAssertTrue(yyyymmddhhmmssLocal.contains("/"))
        XCTAssertTrue(yyyymmddhhmmssUTC.contains("/"))
        XCTAssertTrue(yyyymmddhhmmssLocal.contains(":"))
        XCTAssertTrue(yyyymmddhhmmssUTC.contains(":"))
    }

    func testClipboardSetYYFormats() {
        let yymmddLocal = ClipboardSet.yyMMddLocal()
        let yymmddUTC = ClipboardSet.yyMMddUTC()
        let yymmddhhmmssLocal = ClipboardSet.yyMMddHHmmssLocal()
        let yymmddhhmmssUTC = ClipboardSet.yyMMddHHmmssUTC()

        XCTAssertTrue(yymmddLocal.contains("/"))
        XCTAssertTrue(yymmddUTC.contains("/"))
        XCTAssertEqual(yymmddLocal.split(separator: "/").first?.count, 2)
        XCTAssertEqual(yymmddUTC.split(separator: "/").first?.count, 2)
        XCTAssertTrue(yymmddhhmmssLocal.contains(":"))
        XCTAssertTrue(yymmddhhmmssUTC.contains(":"))
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
