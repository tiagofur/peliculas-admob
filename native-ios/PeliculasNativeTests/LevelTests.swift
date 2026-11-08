import XCTest
@testable import PeliculasNative

/// Espejo de `Level.defaultLevels` de Flutter: mismos 7 umbrales.
final class LevelTests: XCTestCase {
  func testThresholds() {
    XCTAssertEqual(UserLevel.level(for: 0).level, 1)
    XCTAssertEqual(UserLevel.level(for: 149).level, 1)
    XCTAssertEqual(UserLevel.level(for: 150).level, 2)
    XCTAssertEqual(UserLevel.level(for: 399).level, 2)
    XCTAssertEqual(UserLevel.level(for: 400).level, 3)
    XCTAssertEqual(UserLevel.level(for: 799).level, 3)
    XCTAssertEqual(UserLevel.level(for: 800).level, 4)
    XCTAssertEqual(UserLevel.level(for: 1499).level, 4)
    XCTAssertEqual(UserLevel.level(for: 1500).level, 5)
    XCTAssertEqual(UserLevel.level(for: 2499).level, 5)
    XCTAssertEqual(UserLevel.level(for: 2500).level, 6)
    XCTAssertEqual(UserLevel.level(for: 3999).level, 6)
    XCTAssertEqual(UserLevel.level(for: 4000).level, 7)
    XCTAssertEqual(UserLevel.level(for: 99999).level, 7)
  }

  func testProgressAndMissing() {
    XCTAssertEqual(UserLevel.level(for: 0).pointsToNext(from: 0), 150)
    XCTAssertNil(UserLevel.level(for: 4000).pointsToNext(from: 5000))
    XCTAssertEqual(UserLevel.level(for: 5000).progress(from: 5000), 1, accuracy: 0.001)
    XCTAssertEqual(UserLevel.level(for: 75).progress(from: 75), 0.5, accuracy: 0.001)
  }
}
