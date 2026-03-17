import XCTest
@testable import Clipboard_Envy

@MainActor
final class ClipboardHelpersTests: XCTestCase {

    // MARK: - Test Data File Helpers

    /// Returns the path to a file in the testdata directory at the project root.
    /// Uses #filePath to locate relative to this test file without requiring bundle resources.
    private func testdataPath(_ filename: String) -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return projectRoot.appendingPathComponent("testdata").appendingPathComponent(filename).path
    }

    /// Reads a file from the testdata directory and returns its contents as a string.
    private func readTestdata(_ filename: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let path = testdataPath(filename)
        return try String(contentsOfFile: path, encoding: .utf8)
    }

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

    func testSlugify_convertsUnderscoresToHyphens() {
        XCTAssertEqual(ClipboardTransform.slugify("hello_world"), "hello-world")
        XCTAssertEqual(ClipboardTransform.slugify("foo_bar_baz"), "foo-bar-baz")
        XCTAssertEqual(ClipboardTransform.slugify("CONST_CASE"), "const-case")
        XCTAssertEqual(ClipboardTransform.slugify("mixed_spaces and_underscores"), "mixed-spaces-and-underscores")
    }

    func testSlugify_handlesCamelCase() {
        XCTAssertEqual(ClipboardTransform.slugify("camelCase"), "camel-case")
        XCTAssertEqual(ClipboardTransform.slugify("myVariableName"), "my-variable-name")
        XCTAssertEqual(ClipboardTransform.slugify("getHTTPResponse"), "get-httpresponse")
    }

    func testSlugify_handlesPascalCase() {
        XCTAssertEqual(ClipboardTransform.slugify("PascalCase"), "pascal-case")
        XCTAssertEqual(ClipboardTransform.slugify("MyClassName"), "my-class-name")
        XCTAssertEqual(ClipboardTransform.slugify("HTTPRequest"), "httprequest")
    }

    func testSlugify_handlesMixedInput() {
        XCTAssertEqual(ClipboardTransform.slugify("myVariable_name"), "my-variable-name")
        XCTAssertEqual(ClipboardTransform.slugify("Some Mixed_Input"), "some-mixed-input")
        XCTAssertEqual(ClipboardTransform.slugify("user123Name"), "user123-name")
    }

    func testSlugify_collapsesConsecutiveHyphens() {
        XCTAssertEqual(ClipboardTransform.slugify("a--b"), "a-b")
        XCTAssertEqual(ClipboardTransform.slugify("a---b"), "a-b")
        XCTAssertEqual(ClipboardTransform.slugify("hello___world"), "hello-world")
    }

    func testSlugify_stripsLeadingTrailingHyphens() {
        XCTAssertEqual(ClipboardTransform.slugify("-hello-"), "hello")
        XCTAssertEqual(ClipboardTransform.slugify("__hello__"), "hello")
        XCTAssertEqual(ClipboardTransform.slugify("  hello  "), "hello")
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

    func testUrlDecodePlusToSpace() {
        // For typical x-www-form-urlencoded bodies, '+' should decode to space.
        XCTAssertEqual(ClipboardTransform.urlDecode("hello+world"), "hello world")
        XCTAssertEqual(ClipboardTransform.urlDecode("a+b+c"), "a b c")
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

    func testJWTDecodeHeader() throws {
        let jwt = try readTestdata("sample-jwt-encoded.txt")
        guard let header = ClipboardTransform.jwtDecodeHeader(jwt) else {
            XCTFail("jwtDecodeHeader failed")
            return
        }
        XCTAssertTrue(header.contains("alg"))
        XCTAssertTrue(header.contains("HS256"))
        XCTAssertTrue(header.contains("typ"))
        XCTAssertTrue(header.contains("JWT"))
    }

    func testJWTDecodePayload_fromFile() throws {
        let jwt = try readTestdata("sample-jwt-encoded.txt")
        guard let payload = ClipboardTransform.jwtDecode(jwt) else {
            XCTFail("jwtDecode failed")
            return
        }
        XCTAssertTrue(payload.contains("sub"))
        XCTAssertTrue(payload.contains("1234567890"))
        XCTAssertTrue(payload.contains("name"))
        XCTAssertTrue(payload.contains("John Doe"))
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

    func testIsSimpleLiteralJsonArray_trueForStringLiterals() {
        let json = #"["Commas","Spaces","CommaSpaces","Tabs","Pipes","Colons","Semicolons"]"#
        XCTAssertTrue(ClipboardTransform.isSimpleLiteralJsonArray(json))
    }

    func testIsSimpleLiteralJsonArray_trueForNumericAndBooleanLiterals() {
        let json = #"[1,2,3,4,true,false,null]"#
        XCTAssertTrue(ClipboardTransform.isSimpleLiteralJsonArray(json))
    }

    func testIsSimpleLiteralJsonArray_falseForArrayOfObjects() {
        let json = #"[{"a":1},{"b":2}]"#
        XCTAssertFalse(ClipboardTransform.isSimpleLiteralJsonArray(json))
    }

    func testIsSimpleLiteralJsonArray_falseForNestedArrays() {
        let json = #"[[1,2],[3,4]]"#
        XCTAssertFalse(ClipboardTransform.isSimpleLiteralJsonArray(json))
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

    func testTrimTrailingCommas() {
        let input = "a,\nb ,  \nc"
        XCTAssertEqual(ClipboardTransform.trimTrailingCommas(input), "a\nb  \nc")
    }

    func testTrimTrailingSemicolons() {
        let input = "a;\nb ;\nc ;   \nd"
        XCTAssertEqual(ClipboardTransform.trimTrailingSemicolons(input), "a\nb\nc   \nd")
    }

    func testRemoveUniqueLines() {
        let input = "a\nb\na\nc\nc\nd"
        XCTAssertEqual(ClipboardTransform.removeUniqueLines(input), "a\na\nc\nc")
    }

    func testKeepUniqueLines() {
        let input = "a\nb\na\nc\nc\nd"
        XCTAssertEqual(ClipboardTransform.keepUniqueLines(input), "b\nd")
    }

    func testKeepDuplicateLinesCollapsed() {
        let input = "a\nb\na\nc\nc\nd"
        XCTAssertEqual(ClipboardTransform.keepDuplicateLinesCollapsed(input), "a\nc")
    }

    func testSortLinesByFrequencyAscending() {
        let input = "a\nb\na\nc\nc\nc"
        let output = ClipboardTransform.sortLinesByFrequencyAscending(input)
        XCTAssertTrue(output.hasPrefix("b\n"))
    }

    func testSortLinesByFrequencyDescending() {
        let input = "a\nb\na\nc\nc\nc"
        let output = ClipboardTransform.sortLinesByFrequencyDescending(input)
        XCTAssertTrue(output.hasPrefix("c\n"))
    }

    func testWrapLines_basic() {
        let input = "a\nb\n"
        XCTAssertEqual(ClipboardTransform.wrapLines(input, prefix: "\"", suffix: "\""), "\"a\"\n\"b\"\n")
    }

    func testUnwrapLines_basic() {
        let input = "\"a\"\n\"b\""
        XCTAssertEqual(ClipboardTransform.unwrapLines(input, prefix: "\"", suffix: "\""), "a\nb")
    }

    func testUnwrapLines_handlesOnlyPrefixOrSuffix() {
        let input = "[a\nb]"
        XCTAssertEqual(ClipboardTransform.unwrapLines(input, prefix: "[", suffix: "]"), "a\nb")
    }

    func testBuiltinMultilineWrappers_containsExpectedEntries() {
        let labels = ClipboardTransform.builtinMultilineWrappers().map { $0.label }
        XCTAssertTrue(labels.contains("\"line\""))
        XCTAssertTrue(labels.contains("`line`"))
        XCTAssertTrue(labels.contains("'line'"))
        XCTAssertTrue(labels.contains("\"line\","))
        XCTAssertTrue(labels.contains("[line]"))
        XCTAssertTrue(labels.contains("- line"))
        XCTAssertTrue(labels.contains("// line"))
    }

    func testCustomMultilineWrappers_parsesDefaultsDictionary() {
        let defaults = UserDefaults.standard
        let key = "TextLineWrappers"
        let entryKey = "AngleBrackets"
        let entryValue = "<|>"
        let original = defaults.dictionary(forKey: key)

        var dict = original ?? [:]
        dict[entryKey] = entryValue
        defaults.set(dict, forKey: key)

        let items = ClipboardTransform.customMultilineWrappers()
        XCTAssertTrue(items.contains { $0.label == entryKey && $0.prefix == "<" && $0.suffix == ">" })

        if let original = original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testJoinLines_basic() {
        let input = "a\nb\nc"
        XCTAssertEqual(ClipboardTransform.joinLines(input, delimiter: ","), "a,b,c")
    }

    func testSplitLines_basic() {
        let input = "a,b,c"
        XCTAssertEqual(ClipboardTransform.splitLines(on: ",", input), "a\nb\nc")
    }

    func testBuiltinMultilineJoiners_containsExpectedDefaults() {
        let labels = ClipboardTransform.builtinMultilineJoiners().map { $0.label }
        XCTAssertTrue(labels.contains("Commas"))
        XCTAssertTrue(labels.contains("Spaces"))
        XCTAssertTrue(labels.contains("Tabs"))
    }

    func testLinesToTypedJsonArray_infersTypesAndHonorsQuotedStrings() throws {
        let input = """
        1
        2.5
        true
        "hello"
        'world'
        """
        let json = ClipboardTransform.linesToTypedJsonArray(input)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
        XCTAssertEqual(arr.count, 5)
        XCTAssertEqual(arr[0] as? Int, 1)
        XCTAssertEqual(arr[1] as? Double, 2.5)
        XCTAssertEqual(arr[2] as? Bool, true)
        XCTAssertEqual(arr[3] as? String, "hello")
        XCTAssertEqual(arr[4] as? String, "world")
    }

    func testLinesToStringJsonArray_preservesLineCount() throws {
        let input = "a\nb\nc"
        let json = ClipboardTransform.linesToStringJsonArray(input)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String])
        XCTAssertEqual(arr, ["a", "b", "c"])
    }

    func testSimpleLiteralJsonArrayToLines_basic() {
        let json = #"["Commas","Spaces","Tabs"]"#
        let lines = ClipboardTransform.simpleLiteralJsonArrayToLines(json)
        XCTAssertEqual(lines, "Commas\nSpaces\nTabs")
    }

    func testRemoveSubstring_andCustomMultilineRemoves() {
        let input = "a,b,c"
        let expectedAfterRemove = "abc"
        XCTAssertEqual(ClipboardTransform.removeSubstring(input, target: ","), expectedAfterRemove)

        let defaults = UserDefaults.standard
        let key = "TextRemoves"
        let entryKey = "NoCommas"
        let entryValue = ","
        let original = defaults.dictionary(forKey: key)

        var dict = original ?? [:]
        dict[entryKey] = entryValue
        defaults.set(dict, forKey: key)

        let custom = ClipboardTransform.customMultilineRemoves()
        XCTAssertTrue(custom.contains { $0.label == entryKey && $0.target == entryValue })

        if let original = original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testRemoveZeroWidthCharacters() {
        let input = "a\u{200B}b\u{FEFF}c"
        XCTAssertEqual(ClipboardTransform.removeZeroWidthCharacters(input), "abc")
    }

    func testSwapSubstrings_andCustomMultilineSwaps() {
        let input = "a.b.c"
        let expectedAfterSwap = "a,b,c"
        XCTAssertEqual(ClipboardTransform.swapSubstrings(input, from: ".", to: ","), expectedAfterSwap)

        let defaults = UserDefaults.standard
        let key = "TextSwaps"
        let entryKey = "DotsToCommas"
        let entryValue = ". -> ,"
        let original = defaults.dictionary(forKey: key)

        var dict = original ?? [:]
        dict[entryKey] = entryValue
        defaults.set(dict, forKey: key)

        let custom = ClipboardTransform.customMultilineSwaps()
        XCTAssertTrue(custom.contains { $0.label == entryKey && $0.from == "." && $0.to == "," })

        if let original = original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testAwkPrintColumns_whitespaceDelimiter_basic() {
        let input = TestData.awkWhitespaceSample

        // Print $1: header + first column values.
        let result1 = ClipboardTransform.awkPrintColumns(input, columns: [1])
        XCTAssertEqual(result1, """
        Column1
        cel1a
        cel2a
        cel3a
        cell4a
        """)

        // Print $3: header + third column values.
        let result3 = ClipboardTransform.awkPrintColumns(input, columns: [3])
        XCTAssertEqual(result3, """
        Column3
        cel1c
        cel2c
        cel3c
        cell4c
        """)
    }

    func testAwkPrintColumns_whitespaceDelimiter_outOfRangeProducesBlankLine() {
        let input = "onlyOneColumn"
        let result = ClipboardTransform.awkPrintColumns(input, columns: [3])
        XCTAssertEqual(result, "")
    }

    func testAwkPrintColumns_customDelimiter_preservesEmptyColumnsBetweenDelimiters() {
        let input = TestData.awkDelimitedSample

        // Print $3 and $2 via explicit columns helper; note blank cells preserved.
        let result3 = ClipboardTransform.awkPrintColumns(input, columns: [3, 2], delimiter: "/")
        XCTAssertEqual(result3, """
        Column3 Column2
        cell1c cell1b
        cell2c cell2b
        cell3c cell3b
        cell4b
        """)

        // Print $4: header + fourth column values; note blank for row3 (cell2d).
        let result4 = ClipboardTransform.awkPrintColumns(input, columns: [4], delimiter: "/")
        XCTAssertEqual(result4, """
        Column4
        cell1d
        
        cell3d
        cell4d
        """)
    }

    func testAwk_parser_whitespace_defaultDelimiter() {
        let input = TestData.awkWhitespaceSample
        let cmd = "{print $1\"-\"$3}"
        let result = ClipboardTransform.awk(input, command: cmd)
        XCTAssertEqual(result, """
        Column1-Column3
        cel1a-cel1c
        cel2a-cel2c
        cel3a-cel3c
        cell4a-cell4c
        """)
    }

    func testAwk_parser_customDelimiter_andLiterals() {
        let input = TestData.awkDelimitedSample
        let cmd = "-d '/' {print \"C3=\"$3\" C5=\"$5}"
        let result = ClipboardTransform.awk(input, command: cmd)
        XCTAssertEqual(result, """
        C3=Column3 C5=Column5
        C3=cell1c C5=cell1e
        C3=cell2c C5=cell2e
        C3=cell3c C5=cell3e
        C3= C5=cell4e
        """)
    }

    func testCustomAwkPrintPatterns_parsesDefaultsDictionary() {
        let defaults = UserDefaults.standard
        let key = "AwkPrintPatterns"
        let entryKey = "FirstAndThird"
        let entryValue = "{print $1\"-\"$3}"
        let original = defaults.dictionary(forKey: key)

        var dict = original ?? [:]
        dict[entryKey] = entryValue
        defaults.set(dict, forKey: key)

        let patterns = ClipboardTransform.customAwkPrintPatterns()
        XCTAssertTrue(patterns.contains { $0.label == entryKey && $0.command == entryValue })

        if let original = original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testAwkPrintColumns_multipleColumns_joinedWithSpace() {
        let input = "a,b,c,d"
        let result = ClipboardTransform.awkPrintColumns(input, columns: [1, 3], delimiter: ",")
        XCTAssertEqual(result, "a c")
    }

    // Deprecated: column-based Awk patterns have been replaced by AwkPrintPatterns.

    func testFancyQuotesToStraight() {
        let input = "“hello” ‘world’"
        let output = ClipboardTransform.fancyQuotesToStraight(input)
        XCTAssertEqual(output, "\"hello\" 'world'")
    }

    func testHeadLines_basic() {
        let input = "a\nb\nc\nd"
        XCTAssertEqual(ClipboardTransform.headLines(input, count: 2), "a\nb")
    }

    func testHeadLines_moreThanAvailable() {
        let input = "a\nb"
        XCTAssertEqual(ClipboardTransform.headLines(input, count: 5), "a\nb")
    }

    func testTailLines_basic() {
        let input = "a\nb\nc\nd"
        XCTAssertEqual(ClipboardTransform.tailLines(input, count: 2), "c\nd")
    }

    func testTailLines_moreThanAvailable() {
        let input = "a\nb"
        XCTAssertEqual(ClipboardTransform.tailLines(input, count: 5), "a\nb")
    }

    func testRemoveFirstLines_basic() {
        let input = "a\nb\nc\nd"
        XCTAssertEqual(ClipboardTransform.removeFirstLines(input, count: 2), "c\nd")
    }

    func testRemoveFirstLines_moreThanAvailable_returnsEmpty() {
        let input = "a\nb"
        XCTAssertEqual(ClipboardTransform.removeFirstLines(input, count: 5), "")
    }

    func testRemoveLastLines_basic() {
        let input = "a\nb\nc\nd"
        XCTAssertEqual(ClipboardTransform.removeLastLines(input, count: 2), "a\nb")
    }

    func testRemoveLastLines_moreThanAvailable_returnsEmpty() {
        let input = "a\nb"
        XCTAssertEqual(ClipboardTransform.removeLastLines(input, count: 5), "")
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

    // MARK: - Column Operations

    func testDetectDelimiter_csv() {
        let csv = "a,b,c\n1,2,3"
        XCTAssertEqual(ClipboardTransform.detectDelimiter(csv), ",")
    }

    func testDetectDelimiter_tsv() {
        let tsv = "a\tb\tc\n1\t2\t3"
        XCTAssertEqual(ClipboardTransform.detectDelimiter(tsv), "\t")
    }

    func testDetectDelimiter_psv() {
        let psv = "a|b|c\n1|2|3"
        XCTAssertEqual(ClipboardTransform.detectDelimiter(psv), "|")
    }

    func testDetectDelimiter_noDelimiter() {
        let text = "hello world"
        XCTAssertNil(ClipboardTransform.detectDelimiter(text))
    }

    func testColumnHeaders_csv() {
        let csv = "name,age,city\nAlice,30,NYC\nBob,25,LA"
        let headers = ClipboardTransform.columnHeaders(csv)
        XCTAssertEqual(headers, ["name", "age", "city"])
    }

    func testColumnHeaders_maxColumns() {
        let csv = "a,b,c,d,e,f\n1,2,3,4,5,6"
        let headers = ClipboardTransform.columnHeaders(csv, maxColumns: 3)
        XCTAssertEqual(headers, ["a", "b", "c"])
    }

    func testColumnHeaders_psv() {
        let psv = "col1|col2|col3\nval1|val2|val3"
        let headers = ClipboardTransform.columnHeaders(psv)
        XCTAssertEqual(headers, ["col1", "col2", "col3"])
    }

    func testExtractColumnRange_singleColumn() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.extractColumnRange(csv, fromIndex: 1, toIndex: 1)
        XCTAssertEqual(result, "b\n2\n5")
    }

    func testExtractColumnRange_multipleColumns() {
        let csv = "a,b,c,d\n1,2,3,4\n5,6,7,8"
        let result = ClipboardTransform.extractColumnRange(csv, fromIndex: 1, toIndex: 2)
        XCTAssertEqual(result, "b,c\n2,3\n6,7")
    }

    func testExtractColumnRange_reversedIndices() {
        let csv = "a,b,c,d\n1,2,3,4"
        let result = ClipboardTransform.extractColumnRange(csv, fromIndex: 2, toIndex: 0)
        XCTAssertEqual(result, "a,b,c\n1,2,3")
    }

    func testExtractColumnRange_preservesTSV() {
        let tsv = "a\tb\tc\n1\t2\t3"
        let result = ClipboardTransform.extractColumnRange(tsv, fromIndex: 0, toIndex: 1)
        XCTAssertEqual(result, "a\tb\n1\t2")
    }

    func testExtractColumnRange_preservesPSV() {
        let psv = "a|b|c\n1|2|3"
        let result = ClipboardTransform.extractColumnRange(psv, fromIndex: 1, toIndex: 2)
        XCTAssertEqual(result, "b|c\n2|3")
    }

    func testSwapColumns_basic() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.swapColumns(csv, indexA: 0, indexB: 2)
        XCTAssertEqual(result, "c,b,a\n3,2,1\n6,5,4")
    }

    func testSwapColumns_adjacent() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.swapColumns(csv, indexA: 0, indexB: 1)
        XCTAssertEqual(result, "b,a,c\n2,1,3")
    }

    func testSwapColumns_sameIndex() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.swapColumns(csv, indexA: 1, indexB: 1)
        XCTAssertEqual(result, csv)
    }

    func testSwapColumns_preservesPSV() {
        let psv = "a|b|c\n1|2|3"
        let result = ClipboardTransform.swapColumns(psv, indexA: 0, indexB: 2)
        XCTAssertEqual(result, "c|b|a\n3|2|1")
    }

    func testMoveColumnToStart() {
        let csv = "a,b,c,d\n1,2,3,4"
        let result = ClipboardTransform.moveColumnToStart(csv, fromIndex: 2)
        XCTAssertEqual(result, "c,a,b,d\n3,1,2,4")
    }

    func testMoveColumnToStart_alreadyFirst() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.moveColumnToStart(csv, fromIndex: 0)
        XCTAssertEqual(result, csv)
    }

    func testMoveColumnToEnd() {
        let csv = "a,b,c,d\n1,2,3,4"
        let result = ClipboardTransform.moveColumnToEnd(csv, fromIndex: 1)
        XCTAssertEqual(result, "a,c,d,b\n1,3,4,2")
    }

    func testMoveColumnToEnd_alreadyLast() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.moveColumnToEnd(csv, fromIndex: 2)
        XCTAssertEqual(result, csv)
    }

    func testMoveColumnBefore() {
        let csv = "a,b,c,d\n1,2,3,4"
        let result = ClipboardTransform.moveColumnBefore(csv, fromIndex: 3, beforeIndex: 1)
        XCTAssertEqual(result, "a,d,b,c\n1,4,2,3")
    }

    func testMoveColumnBefore_samePosition() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.moveColumnBefore(csv, fromIndex: 1, beforeIndex: 1)
        XCTAssertEqual(result, csv)
    }

    func testMoveColumnBefore_immediatelyAfter() {
        let csv = "a,b,c\n1,2,3"
        let result = ClipboardTransform.moveColumnBefore(csv, fromIndex: 1, beforeIndex: 2)
        XCTAssertEqual(result, csv)
    }

    func testRemoveColumn_first() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.removeColumn(csv, columnIndex: 0)
        XCTAssertEqual(result, "b,c\n2,3\n5,6")
    }

    func testRemoveColumn_middle() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.removeColumn(csv, columnIndex: 1)
        XCTAssertEqual(result, "a,c\n1,3\n4,6")
    }

    func testRemoveColumn_last() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.removeColumn(csv, columnIndex: 2)
        XCTAssertEqual(result, "a,b\n1,2\n4,5")
    }

    func testRemoveColumn_singleColumnReturnsNil() {
        let csv = "a\n1\n2"
        let result = ClipboardTransform.removeColumn(csv, columnIndex: 0)
        XCTAssertNil(result)
    }

    func testRemoveColumn_preservesTSV() {
        let tsv = "a\tb\tc\n1\t2\t3"
        let result = ClipboardTransform.removeColumn(tsv, columnIndex: 1)
        XCTAssertEqual(result, "a\tc\n1\t3")
    }

    func testRemoveColumn_preservesPSV() {
        let psv = "a|b|c\n1|2|3"
        let result = ClipboardTransform.removeColumn(psv, columnIndex: 0)
        XCTAssertEqual(result, "b|c\n2|3")
    }

    func testStripEmptyColumns_removesEmptyMiddle() {
        let csv = "a,b,c\n1,,3\n4,,6"
        let result = ClipboardTransform.stripEmptyColumns(csv)
        XCTAssertEqual(result, "a,c\n1,3\n4,6")
    }

    func testStripEmptyColumns_removesMultipleEmpty() {
        let csv = "a,b,c,d\n1,,,4\n5,,,8"
        let result = ClipboardTransform.stripEmptyColumns(csv)
        XCTAssertEqual(result, "a,d\n1,4\n5,8")
    }

    func testStripEmptyColumns_noEmptyColumns() {
        let csv = "a,b,c\n1,2,3\n4,5,6"
        let result = ClipboardTransform.stripEmptyColumns(csv)
        XCTAssertEqual(result, csv)
    }

    func testStripEmptyColumns_partiallyFilledColumnKept() {
        let csv = "a,b,c\n1,,3\n4,5,6"
        let result = ClipboardTransform.stripEmptyColumns(csv)
        XCTAssertEqual(result, csv)
    }

    func testStripEmptyColumns_whitespaceOnlyIsEmpty() {
        let csv = "a,b,c\n1,  ,3\n4,   ,6"
        let result = ClipboardTransform.stripEmptyColumns(csv)
        XCTAssertEqual(result, "a,c\n1,3\n4,6")
    }

    func testStripEmptyColumns_preservesTSV() {
        let tsv = "a\tb\tc\n1\t\t3\n4\t\t6"
        let result = ClipboardTransform.stripEmptyColumns(tsv)
        XCTAssertEqual(result, "a\tc\n1\t3\n4\t6")
    }

    func testSortByColumn_stringSort() {
        let csv = "name,age\nCharlie,30\nAlice,25\nBob,35"
        let result = ClipboardTransform.sortByColumn(csv, columnIndex: 0)
        XCTAssertEqual(result, "name,age\nAlice,25\nBob,35\nCharlie,30")
    }

    func testSortByColumn_numericSort() {
        let csv = "name,age\nCharlie,30\nAlice,5\nBob,25"
        let result = ClipboardTransform.sortByColumn(csv, columnIndex: 1)
        XCTAssertEqual(result, "name,age\nAlice,5\nBob,25\nCharlie,30")
    }

    func testSortByColumn_stableSort() {
        let csv = "name,color\nAlice,red\nBob,blue\nCharlie,red\nDave,blue"
        let result = ClipboardTransform.sortByColumn(csv, columnIndex: 1)
        XCTAssertEqual(result, "name,color\nBob,blue\nDave,blue\nAlice,red\nCharlie,red")
    }

    func testSortByColumn_preservesTSV() {
        let tsv = "name\tage\nCharlie\t30\nAlice\t25"
        let result = ClipboardTransform.sortByColumn(tsv, columnIndex: 0)
        XCTAssertEqual(result, "name\tage\nAlice\t25\nCharlie\t30")
    }

    func testSortByColumn_singleRow() {
        let csv = "a,b\n1,2"
        let result = ClipboardTransform.sortByColumn(csv, columnIndex: 0)
        XCTAssertEqual(result, csv)
    }

    func testSortByColumn_headerOnly() {
        let csv = "a,b,c"
        let result = ClipboardTransform.sortByColumn(csv, columnIndex: 0)
        XCTAssertEqual(result, csv)
    }

    // MARK: - Testdata File Analysis Tests

    func testAnalyzer_csvFile() throws {
        let content = try readTestdata("sample.csv")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .csv)
        XCTAssertEqual(analysis["Columns"], "6")
        XCTAssertEqual(analysis["Rows"], "5")
    }

    func testAnalyzer_jsonObjectFile() throws {
        let content = try readTestdata("sample-object.json")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .json)
        XCTAssertEqual(analysis["Structure"], "Object")
        XCTAssertFalse(analysis.isArrayStructure)
    }

    func testAnalyzer_jsonArrayFile() throws {
        let content = try readTestdata("sample-array.json")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .json)
        XCTAssertEqual(analysis["Structure"], "Array")
        XCTAssertTrue(analysis.isArrayStructure)
        XCTAssertEqual(analysis["Element Count"], "5")
    }

    func testAnalyzer_psvFile() throws {
        let content = try readTestdata("sample.psv")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .psv)
        XCTAssertEqual(analysis["Columns"], "5")
        XCTAssertEqual(analysis["Rows"], "5")
    }

    func testAnalyzer_tsvFile() throws {
        let content = try readTestdata("sample.tsv")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .tsv)
        XCTAssertEqual(analysis["Columns"], "5")
        XCTAssertEqual(analysis["Rows"], "5")
    }

    func testAnalyzer_yamlFile() throws {
        let content = try readTestdata("sample.yaml")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .yaml)
        XCTAssertEqual(analysis["Structure"], "Object")
    }

    func testAnalyzer_base64File() throws {
        let content = try readTestdata("tell-tale-heart-base64.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .base64)
        XCTAssertNotNil(analysis["Encoded Size"])
        XCTAssertNotNil(analysis["Decoded Size"])
        XCTAssertNotNil(analysis["Decoded Preview"])
        XCTAssertEqual(analysis["Lines"], "37")
    }

    func testAnalyzer_base64URLFile() throws {
        let content = try readTestdata("tell-tale-heart-base64url.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .base64URL)
        XCTAssertNotNil(analysis["Encoded Size"])
        XCTAssertNotNil(analysis["Decoded Size"])
        XCTAssertNotNil(analysis["Decoded Preview"])
        XCTAssertEqual(analysis["Lines"], "37")
    }

    func testAnalyzer_mysqlCliFile() throws {
        let content = try readTestdata("sample-mysql-cli.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .databaseCLITable)
        XCTAssertEqual(analysis.databaseFormat, "MySQL CLI")
        XCTAssertEqual(analysis["Columns"], "5")
        XCTAssertEqual(analysis["Data Rows"], "5")
    }

    func testAnalyzer_psqlCliFile() throws {
        let content = try readTestdata("sample-psql-cli.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .databaseCLITable)
        XCTAssertEqual(analysis.databaseFormat, "psql")
        XCTAssertEqual(analysis["Columns"], "5")
    }

    func testAnalyzer_sqlite3CliFile() throws {
        let content = try readTestdata("sample-sqlite3-cli.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .databaseCLITable)
        XCTAssertEqual(analysis.databaseFormat, "sqlite3")
        XCTAssertEqual(analysis["Columns"], "5")
    }

    func testAnalyzer_urlsFile_firstLineDetectedAsURL() throws {
        let content = try readTestdata("sample-urls.txt")
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        let analysis = ClipboardAnalyzer.analyze(firstLine)
        XCTAssertEqual(analysis.dataType, .url)
        XCTAssertEqual(analysis["Scheme"], "https")
        XCTAssertEqual(analysis["Host"], "example.com")
    }

    func testTransform_mysqlCliToCsv() throws {
        let content = try readTestdata("sample-mysql-cli.txt")
        let csv = try ClipboardTransform.mysqlCliTableToCsv(content)
        XCTAssertTrue(csv.contains("id,name,department,hire_date,active"))
        XCTAssertTrue(csv.contains("Alice Johnson"))
    }

    func testTransform_psqlCliToCsv() throws {
        let content = try readTestdata("sample-psql-cli.txt")
        let csv = try ClipboardTransform.psqlCliTableToCsv(content)
        XCTAssertTrue(csv.contains("id"))
        XCTAssertTrue(csv.contains("Alice Johnson"))
    }

    func testTransform_sqlite3ToCsv() throws {
        let content = try readTestdata("sample-sqlite3-cli.txt")
        let csv = try ClipboardTransform.sqlite3TableToCsv(content)
        XCTAssertTrue(csv.contains("id,name,department,hire_date,active"))
        XCTAssertTrue(csv.contains("Alice Johnson"))
    }

    func testTransform_csvToJson() throws {
        let content = try readTestdata("sample.csv")
        let json = try ClipboardTransform.csvToJson(content)
        XCTAssertTrue(json.contains("Alice Johnson"))
        XCTAssertTrue(json.contains("alice@example.com"))
    }

    func testTransform_base64Decode() throws {
        let encoded = try readTestdata("tell-tale-heart-base64.txt")
        let decoded = ClipboardTransform.base64Decode(encoded)
        XCTAssertTrue(decoded.hasPrefix("The Tell-Tale Heart"))
    }

    func testTransform_base64URLDecode() throws {
        let encoded = try readTestdata("tell-tale-heart-base64url.txt")
        let decoded = ClipboardTransform.base64URLDecode(encoded)
        XCTAssertTrue(decoded.hasPrefix("The Tell-Tale Heart"))
    }

    func testAnalyzer_urlEncodedFile_detectedAsPossiblyURLEncoded() throws {
        let content = try readTestdata("tell-tale-heart-p1-urlencoded.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertTrue(analysis.isPossiblyURLEncoded)
        XCTAssertEqual(analysis["URL Encoded"], "Yes")
        XCTAssertNotNil(analysis["Encoded Size"])
        XCTAssertNotNil(analysis["Decoded Size"])
        XCTAssertEqual(analysis["Words"], "80")
        XCTAssertEqual(analysis["Lines"], "1")
        XCTAssertEqual(analysis["Em Dashes"], "5")
    }

    func testTransform_urlDecode() throws {
        let encoded = try readTestdata("tell-tale-heart-p1-urlencoded.txt")
        let decoded = ClipboardTransform.urlDecode(encoded)
        XCTAssertTrue(decoded.hasPrefix("True!"))
        XCTAssertTrue(decoded.contains("nervous"))
        XCTAssertTrue(decoded.contains("whole story."))
    }

    func testAnalyzer_urlEncodedDetection_requiresNoSpaces() {
        let withSpaces = "hello%20world test"
        let analysis = ClipboardAnalyzer.analyze(withSpaces)
        XCTAssertFalse(analysis.isPossiblyURLEncoded)
    }

    func testAnalyzer_urlEncodedDetection_detectsPlusSign() {
        let withPlus = "hello+world"
        let analysis = ClipboardAnalyzer.analyze(withPlus)
        XCTAssertTrue(analysis.isPossiblyURLEncoded)
    }

    func testAnalyzer_urlEncodedDetection_detectsPercentHex() {
        let withPercent = "hello%21world"
        let analysis = ClipboardAnalyzer.analyze(withPercent)
        XCTAssertTrue(analysis.isPossiblyURLEncoded)
    }

    // MARK: - Fixed-Width Tables

    func testAnalyzer_fixedWidthDockerContainers_detectedAsFixedWidthTableAndKnownType() throws {
        let content = try readTestdata("sample-fixed-width-table.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .fixedWidthTable)
        XCTAssertEqual(analysis["Columns"], "7")
        XCTAssertEqual(analysis["Rows"], "7")
        XCTAssertEqual(analysis.tableTypeName, "Docker Containers List")
    }

    func testAnalyzer_openFilesList_detectedAsFixedWidthTableAndKnownType() throws {
        let content = try readTestdata("sample-open-files-list.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .fixedWidthTable)
        XCTAssertEqual(analysis.tableTypeName, "Open Files List")
    }

    func testAnalyzer_kubernetesPodsList_detectedAsPodsList() throws {
        let content = try readTestdata("sample-k8s-pods-list.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .fixedWidthTable)
        XCTAssertEqual(analysis.tableTypeName, "Kubernetes Pods List")
    }

    func testAnalyzer_psProcessList_detectedAsFixedWidthProcessList() throws {
        let content = try readTestdata("sample-ps-process-list.txt")
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .fixedWidthTable)
        XCTAssertEqual(analysis.tableTypeName, "Process List")
    }

    func testAnalyzer_psAuxStyleProcessList_detectedAsProcessList() throws {
        let content = """
USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
joeuser          63700  48.4  9.2 448117440 12373200   ??  Rs   10:16PM  33:42.78 /System/Library/Frameworks/Virtualization.framework/Versions/A/XPCServices/com.apple.Virtualization.VirtualMachine.xpc/Contents/MacOS/
joeuser          65085   9.4  0.9 1896047824 1268672   ??  S    10:19PM  15:40.94 /Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Renderer).app/Contents/MacOS/Cursor Helper (Renderer) --type=renderer --us
"""
        let analysis = ClipboardAnalyzer.analyze(content)
        XCTAssertEqual(analysis.dataType, .fixedWidthTable)
        XCTAssertEqual(analysis.tableTypeName, "Process List")
    }

    func testTransform_fixedWidthDockerContainers_toCsvAndJson() throws {
        let content = try readTestdata("sample-fixed-width-table.txt")
        let csv = try ClipboardTransform.fixedWidthTableToCsv(content)
        // Header should contain the three key Docker columns in order.
        let header = csv.components(separatedBy: .newlines).first ?? ""
        XCTAssertTrue(header.hasPrefix("CONTAINER ID,IMAGE,COMMAND"), "header should start with key Docker columns; got: \(header)")

        let jsonTyped = try ClipboardTransform.fixedWidthTableToJson(content)
        let rowsTyped = try decodeJSONArray(jsonTyped)
        XCTAssertEqual(rowsTyped.count, 7)
        XCTAssertNotNil(rowsTyped.first?["CONTAINER ID"])

        let jsonStrings = try ClipboardTransform.fixedWidthTableToJsonStrings(content)
        let rowsStrings = try decodeJSONArray(jsonStrings)
        XCTAssertEqual(rowsStrings.count, 7)
        XCTAssertEqual(rowsStrings.first?["CONTAINER ID"] as? String, "0174770c786b")
    }

    func testCsvToFixedWidthTable_roundTripWithCsvToJson() throws {
        let content = try readTestdata("sample.csv")
        let csv = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let table = try ClipboardTransform.csvToFixedWidthTable(csv)
        let backToCsv = try ClipboardTransform.fixedWidthTableToCsv(table)

        let jsonOriginal = try ClipboardTransform.csvToJson(csv)
        let jsonRoundTrip = try ClipboardTransform.csvToJson(backToCsv)

        let rowsOriginal = try decodeJSONArray(jsonOriginal)
        let rowsRoundTrip = try decodeJSONArray(jsonRoundTrip)
        XCTAssertEqual(rowsOriginal.count, rowsRoundTrip.count)
        XCTAssertEqual(rowsOriginal.first?["id"] as? Int, rowsRoundTrip.first?["id"] as? Int)
        XCTAssertEqual(rowsOriginal.first?["name"] as? String, rowsRoundTrip.first?["name"] as? String)
    }
}
