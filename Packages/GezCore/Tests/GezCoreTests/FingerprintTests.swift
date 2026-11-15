import XCTest
import Foundation
@testable import GezCore

/// Prints a checksum of the world on the first of every month, so two
/// versions of the code can be compared: if a speed-up changes nothing, both
/// print the same lines. Runs only when GEZ_FINGERPRINT=1 (the
/// "fingerprint" CI job, by hand), so normal test runs are unaffected.
final class FingerprintTests: XCTestCase {
    /// FNV-1a over the text form of each part (Swift prints doubles exactly).
    static func hash(_ value: Any) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in String(describing: value).utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01b3
        }
        return String(h, radix: 16)
    }

    static func parts(_ sim: Simulation) -> [(String, String)] {
        let w = sim.world
        let a = w.military.armies
        return [
            ("rng", String(sim.random.rawState, radix: 16)),
            ("owner", hash(w.provinces.owner)),
            ("occupied", hash(w.provinces.occupiedBy)),
            ("pop", hash(w.provinces.population)),
            ("garrison", hash(w.provinces.fortGarrison)),
            ("holder", hash(w.provinces.holder)),
            ("treasury", hash(w.countries.treasury)),
            ("rulers", hash([w.countries.ruler, w.countries.heir])),
            ("armies", hash([a.alive.map { $0 ? 1 : 0 }, a.province.map(\.index), a.owner.map(\.index),
                             a.regiments.map { $0.map(\.men) }, a.path.map { $0.map(\.index) }] as [Any])),
            ("wars", hash(w.diplomacy.wars.map { "\($0.id) \($0.attackers) \($0.defenders) \($0.warScore)" })),
            ("treaties", hash(w.diplomacy.treaties.map { "\($0.type) \($0.first.index) \($0.second.index)" })),
            ("people", hash([w.people.characters.death.map { $0.map { "\($0)" } ?? "-" }, w.people.characters.spouses.map { $0.map(\.index) }] as [Any])),
            ("prices", hash(w.economy.markets.price)),
        ]
    }

    func testPrintFingerprints() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GEZ_FINGERPRINT"] == "1",
                          "fingerprint: runs in the fingerprint job only")
        let days = Int(ProcessInfo.processInfo.environment["GEZ_FINGERPRINT_DAYS"] ?? "730") ?? 730
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let t0 = Date()
        for _ in 0..<days {
            sim.tick()
            if sim.date.isFirstOfMonth {
                let p = Self.parts(sim)
                let all = Self.hash(p.map(\.1))
                print("FINGERPRINT \(sim.date) \(all) " + p.map { "\($0.0)=\($0.1)" }.joined(separator: " "))
            }
        }
        print(String(format: "FINGERPRINT done in %.1fs", Date().timeIntervalSince(t0)))
    }
}
