import Testing
import Foundation
@testable import GezCore

@Suite("Technology")
struct TechnologyTests {
    @Test("Starting 1453 levels vary by region, government cap and country overrides")
    func startingLevels1453() {
        let w = Scenario1453.makeWorld()
        #expect(w.techRules.tracks.count == 3)
        #expect(w.techRules.tracks[0].count == 20)
        #expect(w.techRules.institutions.count == 4)

        let flo = w.countries.id(forTag: "FLO")!
        #expect(w.tech.level(flo, .administrative) == 4)
        #expect(w.tech.level(flo, .diplomatic) == 4)
        #expect(w.tech.level(flo, .military) == 4)

        let tur = w.countries.id(forTag: "TUR")!
        #expect(w.tech.level(tur, .administrative) == 4)
        #expect(w.tech.level(tur, .diplomatic) == 4)
        #expect(w.tech.level(tur, .military) == 4)

        let mos = w.countries.id(forTag: "MOS")!
        #expect(w.tech.level(mos, .administrative) == 3)
        #expect(w.tech.level(mos, .diplomatic) == 3)
        #expect(w.tech.level(mos, .military) == 3)

        let nog = w.countries.id(forTag: "NOG")!
        #expect(w.tech.level(nog, .administrative) == 2)
        #expect(w.tech.level(nog, .diplomatic) == 2)

        let eth = w.countries.id(forTag: "ETH")!
        #expect(w.tech.level(eth, .administrative) == 3)
        #expect(w.tech.level(eth, .diplomatic) == 2)
        #expect(w.tech.level(eth, .military) == 3)
    }

    @Test("Research speed scales with skills, colleges, paper/books and focus")
    func researchSpeedAndFocus() {
        var w = Scenario1453.makeWorld()
        let tur = w.countries.id(forTag: "TUR")!

        w.tech.setFocus(of: tur, to: .balanced)
        let balMil = TechSystem.breakdown(w, for: tur, track: .military, year: 1453)
        w.tech.setFocus(of: tur, to: .military)
        let focMil = TechSystem.breakdown(w, for: tur, track: .military, year: 1453)
        let focAdm = TechSystem.breakdown(w, for: tur, track: .administrative, year: 1453)

        #expect(focMil.focusShare == 0.50)
        #expect(focAdm.focusShare == 0.25)
        #expect(focMil.totalMonthlyGain > balMil.totalMonthlyGain)
        #expect(focMil.sharedCollegesOrZero > 0)
        #expect(focMil.sharedPaperContrib > 0 || focMil.sharedBooksContrib > 0)

        // Adding a College level increases monthly research gain.
        let cap = w.countries.capital[tur.index]!
        let colID = w.economy.buildingType(key: "college")!
        let oldLvl = w.economy.buildings.level(cap, colID)
        w.economy.buildings.setLevel(cap, colID, oldLvl + 1)
        let boostedMil = TechSystem.breakdown(w, for: tur, track: .military, year: 1453)
        #expect(boostedMil.totalMonthlyGain > focMil.totalMonthlyGain)
    }

    @Test("Neighbour bonus gives -5% cost per level ahead, capped at -25%")
    func neighbourBonus() {
        var w = Scenario1453.makeWorld()
        let ser = w.countries.id(forTag: "SER")!
        let tur = w.countries.id(forTag: "TUR")!
        // Raise TUR military tech well ahead of SER (they share a border).
        w.tech.setLevel(ser, .military, 3)
        w.tech.setLevel(tur, .military, 5)
        let twoAhead = TechSystem.breakdown(w, for: ser, track: .military, year: 1500)
        #expect(twoAhead.neighbourLevelsAhead >= 2)
        #expect(abs(twoAhead.neighbourBonusFraction - Double(min(5, twoAhead.neighbourLevelsAhead)) * 0.05) < 1e-9)

        w.tech.setLevel(tur, .military, 12)
        let capAhead = TechSystem.breakdown(w, for: ser, track: .military, year: 1500)
        #expect(abs(capAhead.neighbourBonusFraction - 0.25) < 1e-9)
        #expect(capAhead.effectiveCost < twoAhead.effectiveCost)
    }

    @Test("Monthly research accumulates progress, levels up, and saves deterministically")
    func deterministicAdvanceAndSaveRoundTrip() throws {
        let simA = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let tur = simA.world.countries.id(forTag: "TUR")!
        simA.world.humanCountries.insert(tur)
        simA.world.tech.setFocus(of: tur, to: .military)
        // Put TUR just below Mil level 5 effective cost so the first monthly tick advances it.
        let bd = TechSystem.breakdown(simA.world, for: tur, track: .military, year: 1453)
        let milSlot = simA.world.tech.slot(tur, .military)
        simA.world.tech.progress[milSlot] = max(0, bd.effectiveCost - 1.0)

        simA.advance(days: 35)
        #expect(simA.world.tech.level(tur, .military) == 5)
        #expect(simA.world.tech.progress(tur, .administrative) > 0)

        let data = try SaveStorage.encodeArchive(simA, name: "TechTest", playerTag: "TUR")
        let (simB, _) = try SaveStorage.decodeArchive(from: data)

        // Also ensure an older save missing `tech` loads cleanly.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if var snap = json["snapshot"] as? [String: Any] {
            snap.removeValue(forKey: "tech")
            json["snapshot"] = snap
        }
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let (legacySim, _) = try SaveStorage.decodeArchive(from: legacyData)
        #expect(legacySim.world.tech.level(tur, .military) == 4)

        simA.advance(days: 35)
        simB.advance(days: 35)

        #expect(simA.world.tech.levels == simB.world.tech.levels)
        #expect(simA.world.tech.progress == simB.world.tech.progress)
        #expect(simA.world.tech.focus == simB.world.tech.focus)
    }
}

private extension TechTrackBreakdown {
    var sharedCollegesOrZero: Double { sharedCollegeContrib }
}
