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

    @Test("1453 starting armies, fleets, forts and buildings stay even above current tech")
    func starting1453MapEntitiesUntouched() {
        let w = Scenario1453.makeWorld()
        // MOS starts at Mil 3 with a standing Bombard (which requires Mil 4 to recruit anew).
        let mos = w.countries.id(forTag: "MOS")!
        let artID = w.military.unitByKey["artillery"]!
        #expect(w.tech.level(mos, .military) == 3)
        #expect(!ArmySystem.canRecruit(w, mos, artID))

        // Venice keeps its Shipyard 4 in Venice even though Adm is 4 (new level-4 builds require Adm 6).
        let ven = w.countries.id(forTag: "VEN")!
        let venProv = w.countries.capital[ven.index]!
        let shipyardID = w.economy.buildingType(key: "shipyard")!
        #expect(w.economy.buildings.level(venProv, shipyardID) == 4)
        #expect(w.tech.level(ven, .administrative) == 4)
        #expect(BuildingSystem.refusal(w, ven, venProv, shipyardID, checkMoney: false) == .techLocked(track: .administrative, required: 12))

        // Naples or Paris keeps starting level-4+ forts/workshops.
        let paris = w.provinces.ids.first { w.provinces.name[$0.index] == "Paris" } ?? w.countries.capital[w.countries.id(forTag: "FRA")!.index]!
        #expect(w.provinces.fortLevel[paris.index] >= 3)
    }

    @Test("Military, Diplomatic and Administrative unlocks gate recruitment, ships, buildings, forts and trade range")
    func unlocksGateActionsAndAI() {
        var w = Scenario1453.makeWorld()
        let tur = w.countries.id(forTag: "TUR")!
        let cap = w.countries.capital[tur.index]!
        w.countries.treasury[tur.index] = 10_000
        w.military.manpower[tur.index] = 50_000
        w.navy.sailors[tur.index] = 10_000

        // 1. Military unit gating
        let muskID = w.military.unitByKey["musketeers"]!
        let halberdID = w.military.unitByKey["halberdiers"]!
        #expect(ArmySystem.recruitRefusal(w, tur, in: cap, unit: muskID) == .unitLocked)
        #expect(ArmySystem.unitLockReason(w, tur, muskID) == "Requires Military Tech 9")
        w.tech.setLevel(tur, .military, 5)
        #expect(ArmySystem.canRecruit(w, tur, halberdID))
        #expect(!ArmySystem.canRecruit(w, tur, muskID))
        w.tech.setLevel(tur, .military, 9)
        #expect(ArmySystem.canRecruit(w, tur, muskID))

        // 2. Ship gating
        let galleonID = w.navy.shipByKey["galleon"]!
        #expect(NavySystem.buildShipRefusal(w, tur, in: cap, type: galleonID) == .shipLocked)
        #expect(NavySystem.shipLockReason(w, tur, galleonID) == "Requires Diplomatic Tech 8")
        w.tech.setLevel(tur, .diplomatic, 8)
        #expect(NavySystem.canBuildShip(w, tur, galleonID))

        // 3. Building level 4-5 & Fort level 2-5 gating
        let farmID = w.economy.buildingType(key: "farm_estate")!
        w.provinces.development[cap.index] = 15 // ensure free slots
        w.economy.buildings.setLevel(cap, farmID, 3)
        #expect(BuildingSystem.refusal(w, tur, cap, farmID) == .techLocked(track: .administrative, required: 6))
        w.tech.setLevel(tur, .administrative, 6)
        #expect(BuildingSystem.refusal(w, tur, cap, farmID) == nil)
        w.economy.buildings.setLevel(cap, farmID, 4)
        #expect(BuildingSystem.refusal(w, tur, cap, farmID) == .techLocked(track: .administrative, required: 12))

        let fortID = w.economy.buildingType(key: "fort")!
        let edirne = w.provinces.ids.first { w.provinces.name[$0.index] == "Edirne" }!
        w.provinces.development[edirne.index] = 15
        w.economy.buildings.setLevel(edirne, fortID, 2)
        w.tech.setLevel(tur, .military, 7)
        #expect(BuildingSystem.refusal(w, tur, edirne, fortID) == .techLocked(track: .military, required: 8))
        w.tech.setLevel(tur, .military, 8)
        #expect(BuildingSystem.refusal(w, tur, edirne, fortID) == nil)

        // 4. Trade range gating
        let gen = w.countries.id(forTag: "GEN")!
        w.tech.setLevel(gen, .diplomatic, 1) // range = 3 steps
        let londonMkt = w.economy.markets.ids.first { w.economy.markets.name[$0.index] == "London" }!
        let cairoMkt = w.economy.markets.ids.first { w.economy.markets.name[$0.index] == "Cairo" }!
        let grain = w.economy.goods.id(forKey: "grain")!
        let pathLen = (w.tradePath(for: gen, from: londonMkt, to: cairoMkt)?.count ?? 1) - 1
        if pathLen > 3 {
            #expect(TradeSystem.create(&w, owner: gen, good: grain, from: londonMkt, to: cairoMkt, volume: 10) == .outOfRange)
            w.tech.setLevel(gen, .diplomatic, 15) // range = 24 steps
            #expect(TradeSystem.create(&w, owner: gen, good: grain, from: londonMkt, to: cairoMkt, volume: 10) == nil)
        }

        // 5. Administrative efficiency & accepted cultures
        let baseSlots = CultureSystem.acceptedCultureSlots(w, tur)
        w.tech.setLevel(tur, .administrative, 15)
        #expect(CultureSystem.acceptedCultureSlots(w, tur) == baseSlots + 2)
        #expect(w.techEffects(tur, track: .administrative).adminEff >= 0.10)

        // 6. AI takes tech into account when recruiting and building
        let mos = w.countries.id(forTag: "MOS")!
        let mCap = w.countries.capital[mos.index]!
        w.countries.treasury[mos.index] = 10_000
        w.countries.lastMonthlyIncome[mos.index] = 20
        w.countries.lastMonthlyExpenses[mos.index] = 5
        w.military.manpower[mos.index] = 50_000
        w.military.maxManpower[mos.index] = 50_000
        w.provinces.development[mCap.index] = 15

        // At Adm 4, fill level 3 on all owned Moscow provinces' buildings; AI must not queue level 4.
        for t in 0..<w.economy.buildings.typeCount {
            if w.economy.buildings.level(mCap, BuildingTypeID(t)) > 0 {
                w.economy.buildings.setLevel(mCap, BuildingTypeID(t), 3)
            }
        }
        w.economy.buildings.setLevel(mCap, farmID, 3)
        let beforeConstructions = w.economy.buildings.constructions.count
        BuildingSystem.runAI(&w, month: mos.index % 12)
        let queuedLv4Early = w.economy.buildings.constructions.dropFirst(beforeConstructions).contains { $0.level >= 4 }
        #expect(!queuedLv4Early)

        w.tech.setLevel(mos, .military, 6)
        let pikeID = w.military.unitByKey["pikemen"]!
        let regsBefore = w.military.armies(of: mos).reduce(0) { $0 + w.military.armies.regiments[Int($1.rawValue)].count }
        ArmySystem.runAI(&w, month: mos.index % 12, date: Scenario1453.startDate)
        ArmySystem.runAI(&w, month: mos.index % 12, date: Scenario1453.startDate)
        let allRegsAfter = w.military.armies(of: mos).flatMap { w.military.armies.regiments[Int($0.rawValue)] }
        #expect(allRegsAfter.count > regsBefore)
        #expect(allRegsAfter.contains { $0.type == pikeID })
    }
}

private extension TechTrackBreakdown {
    var sharedCollegesOrZero: Double { sharedCollegeContrib }
}
