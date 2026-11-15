import XCTest
@testable import GezCore

/// The wars already being fought on 30 May 1453 (Hundred Years' War,
/// Lombardy, Albania, Delhi–Jaunpur) must not end in a white peace on the
/// first monthly tick just because they began years before 1453.
final class StartingWarsTests: XCTestCase {
    func testStartingWarsSurviveTheirFirstMonths() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let startIDs = sim.world.diplomacy.wars.map(\.id).sorted()
        XCTAssertEqual(startIDs.count, 4, "expected the four 1453 wars, got \(startIDs)")
        // Day 2 (1 June) and 1 July are both monthly ticks.
        for _ in 0..<45 { sim.tick() }
        let still = Set(sim.world.diplomacy.wars.map(\.id))
        for id in startIDs {
            XCTAssertTrue(still.contains(id), "\(id) ended within 45 days of the start")
        }
    }
}
