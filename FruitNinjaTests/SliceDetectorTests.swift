import XCTest
@testable import FruitNinja

final class SliceDetectorTests: XCTestCase {
    func testDistanceToSegment() {
        let d = SliceDetector.distance(from: CGPoint(x: 5, y: 5),
                                       toSegment: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: 10, y: 0))
        XCTAssertEqual(d, 5, accuracy: 0.0001)
    }

    func testDistanceToDegenerateSegment() {
        let d = SliceDetector.distance(from: CGPoint(x: 3, y: 4),
                                       toSegment: .zero,
                                       end: .zero)
        XCTAssertEqual(d, 5, accuracy: 0.0001)
    }

    func testCircleIntersectionIncludesTolerance() {
        XCTAssertTrue(SliceDetector.intersects(circleCenter: CGPoint(x: 0, y: 20),
                                               radius: 10,
                                               segmentStart: CGPoint(x: -50, y: 0),
                                               segmentEnd: CGPoint(x: 50, y: 0)))
        XCTAssertTrue(SliceDetector.intersects(circleCenter: CGPoint(x: 0, y: 24),
                                               radius: 10,
                                               segmentStart: CGPoint(x: -50, y: 0),
                                               segmentEnd: CGPoint(x: 50, y: 0),
                                               tolerance: 16))
        XCTAssertFalse(SliceDetector.intersects(circleCenter: CGPoint(x: 0, y: 34),
                                                radius: 10,
                                                segmentStart: CGPoint(x: -50, y: 0),
                                                segmentEnd: CGPoint(x: 50, y: 0),
                                                tolerance: 16))
    }

    func testSpeedUsesFrameDelta() {
        let speed = SliceDetector.speed(from: CGPoint(x: 0, y: 0),
                                        to: CGPoint(x: 60, y: 80),
                                        deltaTime: 0.1)
        XCTAssertEqual(speed, 1000, accuracy: 0.001)
    }

    func testSpeedHandlesZeroDelta() {
        XCTAssertEqual(SliceDetector.speed(from: .zero, to: CGPoint(x: 10, y: 10),
                                           deltaTime: 0), 0)
    }
}
