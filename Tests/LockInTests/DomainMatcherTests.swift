import XCTest
@testable import LockIn

final class DomainMatcherTests: XCTestCase {
    func testMatchesSubdomains() {
        XCTAssertTrue(DomainMatcher.host("news.ycombinator.com", matchesDomain: "ycombinator.com"))
        XCTAssertFalse(DomainMatcher.host("notyoutube.com", matchesDomain: "youtube.com"))
    }

    func testNormalizesDomains() {
        XCTAssertEqual(DomainMatcher.normalizedDomain(" https://www.Example.com/path "), "example.com/path")
        XCTAssertEqual(DomainMatcher.normalizedDomain("youtube.com/shorts"), "youtube.com/shorts")
        XCTAssertNil(DomainMatcher.normalizedDomain("https://youtube.com/watch?v=1"))
        XCTAssertNil(DomainMatcher.normalizedDomain("localhost"))
    }

    func testMatchesPathRules() {
        XCTAssertTrue(DomainMatcher.url(URL(string: "https://youtube.com/shorts")!, matchesDomain: "youtube.com/shorts"))
        XCTAssertTrue(DomainMatcher.url(URL(string: "https://www.youtube.com/shorts/abc")!, matchesDomain: "youtube.com/shorts"))
        XCTAssertFalse(DomainMatcher.url(URL(string: "https://youtube.com/watch?v=1")!, matchesDomain: "youtube.com/shorts"))
        XCTAssertFalse(DomainMatcher.host("youtube.com", matchesDomain: "youtube.com/shorts"))
    }
}
