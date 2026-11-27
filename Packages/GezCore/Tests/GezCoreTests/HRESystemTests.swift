import Testing
import Foundation
@testable import GezCore

@Suite("HRE System")
struct HRESystemTests {
    @Test("1453 HRE data loads emperor, electors, free cities, prince-bishops, princes, provinces and effects")
    func bundled1453Data() throws {
        let world = Scenario1453.makeWorld()
        let def = try #require(world.rulingRules.system("hre"))
        #expect(def.name == "Holy Roman Empire")
        #expect(def.provinces.count == 157)
        #expect(def.param("elector_count") == 7)

        let hab = try #require(world.countries.id(forTag: "HAB"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let sal = try #require(world.countries.id(forTag: "SAL"))
        let swi = try #require(world.countries.id(forTag: "SWI"))
        let ham = try #require(world.countries.id(forTag: "HAM"))
        let bur = try #require(world.countries.id(forTag: "BUR"))
        let fra = try #require(world.countries.id(forTag: "FRA"))

        #expect(RulingEngine.leader(world, "hre") == hab)
        #expect(RulingEngine.members(world, "hre").count == 63)
        #expect(RulingEngine.holders(world, "hre", "elector").count == 7)
        #expect(RulingEngine.holders(world, "hre", "free_city").count == 9)
        #expect(RulingEngine.holders(world, "hre", "prince_bishop").count == 18)

        #expect(RulingEngine.isMember(world, "hre", swi))
        #expect(RulingEngine.isMember(world, "hre", ham))
        #expect(!RulingEngine.hasRole(world, "hre", ham, "free_city"))
        #expect(RulingEngine.hasRole(world, "hre", mai, "elector"))
        #expect(RulingEngine.hasRole(world, "hre", mai, "prince_bishop"))
        #expect(RulingEngine.hasRole(world, "hre", sal, "prince_bishop"))
        #expect(!RulingEngine.isMember(world, "hre", bur))
        #expect(!RulingEngine.isMember(world, "hre", fra))

        #expect(RulingEngine.value(world, "hre", "authority") == 20)

        // Favour per-country value respects 0..100 limits.
        var w = world
        RulingEngine.setCountryValue(&w, "hre", "favour", swi, 150)
        #expect(RulingEngine.countryValue(w, "hre", "favour", swi) == 100)
        RulingEngine.setCountryValue(&w, "hre", "favour", swi, -25)
        #expect(RulingEngine.countryValue(w, "hre", "favour", swi) == 0)

        // Role effects apply to Free Imperial Cities and Emperor (scaled by authority).
        let baseFreeCity = Effects(estates: 0)
        var withHREFreeCity = Effects(estates: 0)
        RulingEngine.addEffects(world, nur, into: &withHREFreeCity)
        #expect(abs(withHREFreeCity[.trade] - baseFreeCity[.trade] - 0.10) < 1e-9)
        #expect(abs(withHREFreeCity[.tax] - baseFreeCity[.tax] - 0.05) < 1e-9)
        #expect(abs(withHREFreeCity[.fortDefence] - baseFreeCity[.fortDefence] - 0.15) < 1e-9)

        var empFx = Effects(estates: 0)
        RulingEngine.addEffects(world, hab, into: &empFx)
        // Base leader (tax +0.05, manpower +0.10) + authority 20/100 scaled (crownPower +0.02, vassalOpinion +3, tax +0.02)
        #expect(abs(empFx[.manpower] - 0.10) < 1e-9)
        #expect(abs(empFx[.tax] - 0.07) < 1e-9)
        #expect(abs(empFx[.crownPower] - 0.02) < 1e-9)
        #expect(abs(empFx[.vassalOpinion] - 3.0) < 1e-9)
    }

    @Test("Emperor death triggers election by the 7 electors and shifts when electors favour another prince")
    func imperialElection() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = Scenario1453.startDate
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let bra = try #require(world.countries.id(forTag: "BRA"))
        let electors = RulingEngine.holders(world, "hre", "elector")
        #expect(electors.count == 7)

        // Default 1453: Habsburgs are favoured to retain the crown on Frederick III's death.
        let frederick = try #require(world.countries.ruler[hab.index])
        CharacterSystem.kill(&world, frederick, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.leader(world, "hre") == hab)
        #expect(RulingEngine.value(world, "hre", "authority") == 25)

        // Now turn all 7 electors strongly against HAB and strongly in favour of Brandenburg.
        for e in electors {
            world.diplomacy.setOpinion(of: hab, by: e, value: -180)
            world.diplomacy.setOpinion(of: bra, by: e, value: 180)
        }
        RulingEngine.setCountryValue(&world, "hre", "favour", bra, 100)

        let leans = HRESystem.electorLeans(in: world)
        #expect(leans.count == 7)
        #expect(leans.allSatisfy { $0.lean == bra })

        let nextHabRuler = try #require(world.countries.ruler[hab.index])
        CharacterSystem.kill(&world, nextHabRuler, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.leader(world, "hre") == bra)
    }

    @Test("Monthly Imperial Authority rises in peace and falls with internal wars or foreign-held Imperial provinces")
    func authorityDynamics() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 77)
        let date = GameDate(year: 1453, month: 7, day: 1)

        // In 1453 peace, monthly delta is positive.
        let peaceDelta = HRESystem.monthlyAuthorityDelta(in: world)
        #expect(peaceDelta > 0.3)

        let before = RulingEngine.value(world, "hre", "authority")
        RulingEngine.runMonthly(&world, date: date, random: &rng)
        #expect(RulingEngine.value(world, "hre", "authority") > before)

        // Hand 25 Imperial provinces to France -> authority delta turns negative.
        let fra = try #require(world.countries.id(forTag: "FRA"))
        let def = try #require(world.rulingRules.system("hre"))
        for pid in def.provinces.prefix(25) {
            world.provinces.owner[pid.index] = fra
        }
        let foreignDelta = HRESystem.monthlyAuthorityDelta(in: world)
        #expect(foreignDelta < peaceDelta)

        // Authority stays within 0..100 after many months.
        RulingEngine.setValue(&world, "hre", "authority", 99)
        var wPeace = Scenario1453.makeWorld()
        RulingEngine.setValue(&wPeace, "hre", "authority", 99)
        for m in 1...40 {
            RulingEngine.runMonthly(&wPeace, date: GameDate(year: 1454 + m / 12, month: (m % 12) + 1, day: 1), random: &rng)
        }
        #expect(RulingEngine.value(wPeace, "hre", "authority") <= 100)
        #expect(RulingEngine.value(wPeace, "hre", "authority") >= 0)
    }

    @Test("Annexing an HRE member or Free City costs Imperial Authority and replenishes vacated electorates")
    func annexedMembersAndElectorReplenishment() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 99)
        let date = GameDate(year: 1453, month: 7, day: 1)
        let bav = try #require(world.countries.id(forTag: "BAV"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let ans = try #require(world.countries.id(forTag: "ANS"))

        // Annex Free Imperial City Nuremberg -> -8 authority.
        RulingEngine.setValue(&world, "hre", "authority", 50)
        for p in world.provinces.owner.indices where world.provinces.owner[p] == nur {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: date, random: &rng)
        #expect(!RulingEngine.isMember(world, "hre", nur))
        #expect(RulingEngine.value(world, "hre", "authority") < 43)

        // Annex prince Ansbach -> -5 authority.
        RulingEngine.setValue(&world, "hre", "authority", 50)
        for p in world.provinces.owner.indices where world.provinces.owner[p] == ans {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 8, day: 1), random: &rng)
        #expect(!RulingEngine.isMember(world, "hre", ans))
        #expect(RulingEngine.value(world, "hre", "authority") < 46)

        // Annex elector Mainz -> electorate is automatically replenished back to 7.
        for p in world.provinces.owner.indices where world.provinces.owner[p] == mai {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 9, day: 1), random: &rng)
        #expect(!RulingEngine.hasRole(world, "hre", mai, "elector"))
        #expect(RulingEngine.holders(world, "hre", "elector").count == 7)
    }

    @Test("HRE simulation is deterministic over 24 months and survives save/restore identically")
    func determinismAndSaveRoundTrip() throws {
        let simA = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 208)
        let simB = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 208)
        simA.advance(days: 730)
        simB.advance(days: 730)
        #expect(simA.world.rulings == simB.world.rulings)

        // Save/restore round-trip after modifying authority and favour.
        let sax = try #require(simA.world.countries.id(forTag: "SAX"))
        RulingEngine.setValue(&simA.world, "hre", "authority", 42)
        RulingEngine.setCountryValue(&simA.world, "hre", "favour", sax, 35)

        let snap = SaveSnapshot(capturing: simA)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(SaveSnapshot.self, from: data)
        let restored = try decoded.restore()
        #expect(restored.world.rulings == simA.world.rulings)

        simA.advance(days: 60)
        restored.advance(days: 60)
        #expect(simA.world.rulings == restored.world.rulings)
    }
}
