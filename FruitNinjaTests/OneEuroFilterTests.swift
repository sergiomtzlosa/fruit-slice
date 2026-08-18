import XCTest
@testable import FruitNinja

final class OneEuroFilterTests: XCTestCase {
    func testFirstSampleIsReturnedExactly() {
        let filter = FNOneEuroFilter(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)
        let point = CGPoint(x: 0.25, y: 0.75)
        let filtered = filter.filterPoint(point, timestamp: 10)
        XCTAssertEqual(filtered.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(filtered.y, point.y, accuracy: 0.0001)
    }

    func testFilterSmoothsABigJump() {
        let filter = FNOneEuroFilter(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)
        let start = CGPoint(x: 0.2, y: 0.2)
        _ = filter.filterPoint(start, timestamp: 1.0)
        let jump = CGPoint(x: 0.8, y: 0.8)
        let filtered = filter.filterPoint(jump, timestamp: 1.0 + 1.0 / 60.0)
        XCTAssertGreaterThan(filtered.x, start.x)
        XCTAssertLessThan(filtered.x, jump.x)
        XCTAssertGreaterThan(filtered.y, start.y)
        XCTAssertLessThan(filtered.y, jump.y)
    }

    func testConstantInputConverges() {
        let filter = FNOneEuroFilter(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)
        let target = CGPoint(x: 0.6, y: 0.4)
        var result = filter.filterPoint(target, timestamp: 0)
        for frame in 1...240 {
            result = filter.filterPoint(target, timestamp: Double(frame) / 60.0)
        }
        XCTAssertEqual(result.x, target.x, accuracy: 0.001)
        XCTAssertEqual(result.y, target.y, accuracy: 0.001)
    }

    func testResetClearsState() {
        let filter = FNOneEuroFilter(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)
        _ = filter.filterPoint(CGPoint(x: 0.1, y: 0.1), timestamp: 1.0)
        filter.reset()
        let point = CGPoint(x: 0.9, y: 0.7)
        let filtered = filter.filterPoint(point, timestamp: 2.0)
        XCTAssertEqual(filtered.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(filtered.y, point.y, accuracy: 0.0001)
    }

    func testLongGapRestartsFilter() {
        let filter = FNOneEuroFilter(minCutoff: 1.0, beta: 0.5, dCutoff: 1.0)
        _ = filter.filterPoint(.zero, timestamp: 1.0)
        let point = CGPoint(x: 0.9, y: 0.9)
        let filtered = filter.filterPoint(point, timestamp: 3.0)
        XCTAssertEqual(filtered.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(filtered.y, point.y, accuracy: 0.0001)
    }
}
