import Foundation

// MARK: - Test Data (embedded for Test Data menu when Option is held)
// Contents mirror testdata/ for clipboard testing without file I/O.

enum TestData {
    static let jsonArray = """
    [
      {"id": 1, "name": "Alice", "department": "Engineering", "active": true},
      {"id": 2, "name": "Bob", "department": "Marketing", "active": false},
      {"id": 3, "name": "Charlie", "department": "Engineering", "active": true},
      {"id": 4, "name": "Diana", "department": "Sales", "active": true},
      {"id": 5, "name": "Eve", "department": "HR", "active": false}
    ]
    """

    static let jsonObject = """
    {
      "name": "myApp",
      "version": "1.0.0",
      "description": "A cool utility for macOS",
      "author": {
        "name": "Developer",
        "email": "dev@example.com"
      },
      "features": ["toc", "index", "editor"],
      "settings": {
        "theme": "dark",
        "fontSize": 14,
        "autoSave": true,
        "maxHistory": 100
      },
      "enabled": true,
      "lastUpdated": "2026-03-01T12:00:00Z"
    }
    """

    static let csv = """
    id,name,email,age,active,score
    1,Alice Johnson,alice@example.com,28,true,95.5
    2,Bob Smith,bob@example.com,35,false,82.3
    3,Charlie Brown,charlie@example.com,42,true,91.0
    4,Diana Prince,diana@example.com,31,true,88.7
    5,Eve Wilson,eve@example.com,27,false,76.2
    """

    static let tsv = """
    order_id\tcustomer\tproduct\tquantity\ttotal
    1001\tJohn Doe\tWidget A\t5\t125.00
    1002\tJane Smith\tWidget B\t2\t50.00
    1003\tBob Wilson\tGadget X\t1\t299.99
    1004\tAlice Brown\tWidget A\t10\t250.00
    1005\tCharlie Day\tGadget Y\t3\t89.97
    """

    static let psv = """
    product_id|product_name|category|price|in_stock
    SKU001|Wireless Mouse|Electronics|29.99|true
    SKU002|USB-C Cable|Accessories|12.50|true
    SKU003|Mechanical Keyboard|Electronics|149.00|false
    SKU004|Monitor Stand|Furniture|45.00|true
    SKU005|Webcam HD|Electronics|79.99|true
    """

    static let yaml = """
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: app-config
      namespace: production
      labels:
        app: clipboard-envy
        environment: prod
    data:
      database:
        host: db.example.com
        port: 5432
        name: clipboard_db
      features:
        - auto-detection
        - transformations
        - history
      settings:
        maxConnections: 100
        timeout: 30
        retryEnabled: true
      secrets:
        - name: API_KEY
          valueFrom: vault
        - name: DB_PASSWORD
          valueFrom: vault
    """

    /// Single URL with query params for testing Strip URL Params.
    static let urlWithParams = "https://example.com/search?q=hello+world&lang=en"

    static let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30"

    static let urlEncoded = "True%21%20%E2%80%94%20nervous%20%E2%80%94%20very%2C%20very%20dreadfully%20nervous%20I%20had%20been%20and%20am%3B%20but%20why%20will%20you%20say%20that%20I%20am%20mad%3F%20The%20disease%20had%20sharpened%20my%20senses%20%E2%80%94%20not%20destroyed%20%E2%80%94%20not%20dulled%20them.%20Above%20all%20was%20the%20sense%20of%20hearing%20acute.%20I%20heard%20all%20things%20in%20the%20heaven%20and%20in%20the%20earth.%20I%20heard%20many%20things%20in%20hell.%20How%2C%20then%2C%20am%20I%20mad%3F%20Hearken%21%20and%20observe%20how%20healthily%20%E2%80%94%20how%20calmly%20I%20can%20tell%20you%20the%20whole%20story."

    static let mysqlCLI = """
    mysql> SELECT * FROM employees;
    +----+----------------+---------------+------------+--------+
    | id | name           | department    | hire_date  | active |
    +----+----------------+---------------+------------+--------+
    |  1 | Alice Johnson  | Engineering   | 2020-03-15 | 1      |
    |  2 | Bob Smith      | Marketing     | 2019-07-22 | 1      |
    |  3 | Charlie Brown | Engineering   | 2021-01-10 | 0      |
    |  4 | Diana Prince   | Sales         | 2018-11-05 | 1      |
    |  5 | Eve Wilson     | HR            | 2022-06-30 | NULL   |
    +----+----------------+---------------+------------+--------+
    5 rows in set (0.00 sec)
    """

    static let psqlCLI = """
     id |     name       |  department   | hire_date  | active
    ----+----------------+---------------+------------+--------
      1 | Alice Johnson  | Engineering   | 2020-03-15 | t
      2 | Bob Smith      | Marketing     | 2019-07-22 | t
      3 | Charlie Brown | Engineering   | 2021-01-10 | f
      4 | Diana Prince   | Sales         | 2018-11-05 | t
      5 | Eve Wilson     | HR            | 2022-06-30 | NULL
    (5 rows)
    """

    static let sqlite3CLI = """
    id  name            department     hire_date   active
    --  --------------  -------------  ----------  ------
    1   Alice Johnson   Engineering    2020-03-15  1
    2   Bob Smith       Marketing      2019-07-22  1
    3   Charlie Brown   Engineering    2021-01-10  0
    4   Diana Prince    Sales          2018-11-05  1
    5   Eve Wilson      HR             2022-06-30  NULL
    """

    static let plainText = """
    The Tell-Tale Heart

    True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them. Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story.
    """

    // Base64 and Base64URL (Tell-Tale Heart) – first paragraph only to keep binary size reasonable
    static let base64 = "VGhlIFRlbGwtVGFsZSBIZWFydAoKVHJ1ZSEg4oCUIG5lcnZvdXMg4oCUIHZlcnksIHZlcnkgZHJlYWRmdWxseSBuZXJ2b3VzIEkgaGFkIGJlZW4gYW5kIGFtOyBidXQgd2h5IHdpbGwgeW91IHNheSB0aGF0IEkgYW0gbWFkPyBUaGUgZGlzZWFzZSBoYWQgc2hhcnBlbmVkIG15IHNlbnNlcyDigJQgbm90IGRlc3Ryb3llZCDigJQgbm90IGR1bGxlZCB0aGVtLiBBYm92ZSBhbGwgd2FzIHRoZSBzZW5zZSBvZiBoZWFyaW5nIGFjdXRlLiBJIGhlYXJkIGFsbCB0aGluZ3MgaW4gdGhlIGhlYXZlbiBhbmQgaW4gdGhlIGVhcnRoLiBJIGhlYXJkIG1hbnkgdGhpbmdzIGluIGhlbGwuIEhvdywgdGhlbiwgYW0gSSBtYWQ/IEhlYXJrZW4hIGFuZCBvYnNlcnZlIGhvdyBoZWFsdGhpbHkg4oCUIGhvdyBjYWxtbHkgSSBjYW4gdGVsbCB5b3UgdGhlIHdob2xlIHN0b3J5Lgo="

    /// URL-safe base64 (same content as base64, with - and _ instead of + and /).
    static var base64URL: String {
        base64.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
}
