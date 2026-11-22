import Foundation
import XCTest
@testable import GezCore

/// Phase 20 part 8: curved country names follow the country's shape.
final class MapLabelCurveTests: XCTestCase {
    func testLevelRowGivesAStraightLevelName() {
        let pts = (0..<10).map { (x: Double($0) * 20, y: 100.0, w: 100.0) }
        let c = MapLabelInfo.curve(points: pts)
        XCTAssertLessThan(abs(c.angle), 0.01)
        XCTAssertLessThan(abs(c.bend), 0.5)
        XCTAssertGreaterThan(c.length, 150)
    }

    func testSlopedCountryFollowsItsSlopeButNoSteeperThan40Degrees() {
        // a long country going down to the right at 30 degrees
        let pts = (0..<12).map { i -> (x: Double, y: Double, w: Double) in
            let t = Double(i) * 20
            return (x: t * cos(Double.pi / 6), y: t * sin(Double.pi / 6), w: 50)
        }
        let c = MapLabelInfo.curve(points: pts)
        XCTAssertEqual(c.angle, Double.pi / 6, accuracy: 0.05)
        // a nearly vertical one is held at 40 degrees
        let tall = (0..<12).map { (x: Double($0) * 2, y: Double($0) * 30, w: 50.0) }
        XCTAssertLessThanOrEqual(abs(MapLabelInfo.curve(points: tall).angle), Double.pi * 2 / 9 + 1e-9)
    }

    func testArchedCountryBends() {
        // provinces on an arch: the ends lie lower on screen (larger y) than the middle
        let pts = (-6...6).map { i -> (x: Double, y: Double, w: Double) in
            let x = Double(i) * 20
            return (x: x, y: 0.004 * x * x, w: 60)
        }
        let c = MapLabelInfo.curve(points: pts)
        XCTAssertGreaterThan(c.bend, 2)
        XCTAssertLessThanOrEqual(c.bend, c.length * 0.22 + 1e-9)
    }

    func testOneProvinceGivesASmallLevelName() {
        let c = MapLabelInfo.curve(points: [(x: 10, y: 10, w: 400)])
        XCTAssertEqual(c.angle, 0)
        XCTAssertEqual(c.bend, 0)
        XCTAssertEqual(c.length, 20, accuracy: 0.01)
    }
}
