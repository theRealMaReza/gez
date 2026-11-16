import XCTest
@testable import GezCore

final class DiagPopTests: XCTestCase {
    func testPrintFingerprintsDiag() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate)
        func line(_ tag: String) {
            let w = sim.world
            var levy = 0, prof = 0
            for c in w.countries.ids { levy += w.military.totalMen(of: c, origin: .levy); prof += w.military.totalMen(of: c, origin: .professional) }
            let pops = w.pops.size.reduce(0, +)
            print(String(format: "PROFILE DIAG %@ pops=%.0f levy=%d prof=%d rows=%d wars=%d", tag, pops, levy, prof, w.pops.count, w.diplomacy.wars.count))
        }
        line("start")
        for m in 1...12 { sim.advance(days: 30); line("m\(m)") }
    }
}
