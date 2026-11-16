import XCTest
@testable import GezCore

final class FaithTests: XCTestCase {
    private func popCount(in world: World, province: ProvinceID, religion: Religion) -> Double {
        var sum = 0.0
        for i in world.pops.range(for: province) where world.pops.religion[i] == religion {
            sum += world.pops.size[i]
        }
        return sum
    }

    private func firstProvince(in world: World, ownedBy tag: String, majorityReligion: Religion? = nil) -> ProvinceID? {
        guard let c = world.countries.id(forTag: tag) else { return nil }
        for p in 0..<world.provinces.count {
            guard world.provinces.owner[p] == c else { continue }
            if let rel = majorityReligion, world.provinces.religion[p] != rel { continue }
            return ProvinceID(p)
        }
        return nil
    }

    func testRequiredHolySitesLoaded() throws {
        let world = Scenario1453.makeWorld()
        let required = ["Rome", "Constantinople", "Jerusalem", "Mecca", "Medina",
                        "Najaf", "Karbala", "Varanasi", "Bodh Gaya", "Axum"]
        let names = Set(world.faith.holySites.map(\.name))
        for site in required {
            XCTAssertTrue(names.contains(site), "Expected holy site '\(site)' to be loaded")
        }
        let pap = try XCTUnwrap(world.countries.id(forTag: "PAP"))
        let papSites = FaithSystem.holySitesHeld(in: world, by: pap)
        XCTAssertTrue(papSites.contains(where: { $0.name == "Rome" }))

        let hej = try XCTUnwrap(world.countries.id(forTag: "HEJ"))
        let hejSites = FaithSystem.holySitesHeld(in: world, by: hej)
        XCTAssertTrue(hejSites.contains(where: { $0.name == "Mecca" }))
        XCTAssertTrue(hejSites.contains(where: { $0.name == "Medina" }))
    }

    func testHolySiteEffectsOnPrestigeStabilityAndClergyLoyalty() throws {
        var world = Scenario1453.makeWorld()
        let pap = try XCTUnwrap(world.countries.id(forTag: "PAP"))
        let clergy = try XCTUnwrap(world.government.estates[pap.index].first {
            if case .socialClass(.clergy) = world.government.rules.estates[$0.index].source { return true }
            return false
        })

        let costWithRome = GovernmentSystem.stabilityCost(world, pap)
        let loyaltyWithRome = GovernmentSystem.loyaltyTarget(world, pap, clergy)

        // Temporarily lose Rome -> prestige gain stops, stability cost rises, Clergy loyalty target drops.
        let romeProv = try XCTUnwrap(world.faith.holySites.first(where: { $0.name == "Rome" })?.province)
        world.provinces.owner[romeProv.index] = world.countries.id(forTag: "NAP")
        FaithSystem.refreshHolySiteCounts(&world)

        let costWithoutRome = GovernmentSystem.stabilityCost(world, pap)
        let loyaltyWithoutRome = GovernmentSystem.loyaltyTarget(world, pap, clergy)
        XCTAssertGreaterThan(costWithoutRome, costWithRome)
        XCTAssertLessThan(loyaltyWithoutRome, loyaltyWithRome)

        // Restore Rome and tick a month -> prestige increases.
        world.provinces.owner[romeProv.index] = pap
        let beforePrestige = world.countries.prestige[pap.index]
        var rng = GameRandom(seed: 1453)
        var d = Scenario1453.startDate
        d.advanceOneDay()
        FaithSystem.runMonthly(&world, date: d, random: &rng)
        XCTAssertGreaterThan(world.countries.prestige[pap.index], beforePrestige)
    }

    func testConversionDriversClergyTemplesAndLaw() throws {
        var world = Scenario1453.makeWorld()
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let thessaloniki = try XCTUnwrap(firstProvince(in: world, ownedBy: "TUR", majorityReligion: .orthodox))
        let faithArea = try XCTUnwrap(world.government.rules.lawAreas.firstIndex(where: { $0.key == "faith" }))
        let orthoOpt = try XCTUnwrap(world.government.rules.lawAreas[faithArea].options.firstIndex(where: { $0.key == "orthodoxy" }))
        let openOpt = try XCTUnwrap(world.government.rules.lawAreas[faithArea].options.firstIndex(where: { $0.key == "open" }))
        let templeID = try XCTUnwrap(world.economy.buildingTypes.firstIndex(where: { $0.key == "temple" }).map(BuildingTypeID.init))
        let clergy = try XCTUnwrap(world.government.estates[tur.index].first {
            if case .socialClass(.clergy) = world.government.rules.estates[$0.index].source { return true }
            return false
        })

        // Baseline rate (tolerance law, existing temple/clergy)
        let baseRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        XCTAssertGreaterThan(baseRate, 0)

        // Open tolerance law slows conversion vs orthodoxy law
        world.government.laws[tur.index][faithArea] = openOpt
        let openRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        world.government.laws[tur.index][faithArea] = orthoOpt
        let orthoRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        XCTAssertLessThan(openRate, baseRate)
        XCTAssertGreaterThan(orthoRate, baseRate)

        // Temples speed conversion
        let curTemple = world.economy.buildings.level(thessaloniki, templeID)
        world.economy.buildings.setLevel(thessaloniki, templeID, curTemple + 2)
        let templedRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        XCTAssertGreaterThan(templedRate, orthoRate)

        // Higher Clergy loyalty speeds conversion
        world.government.loyalty[tur.index][clergy.index] = 15
        let lowClergyRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        world.government.loyalty[tur.index][clergy.index] = 95
        let highClergyRate = FaithSystem.monthlyConversionRate(world: world, province: thessaloniki, from: .orthodox)
        XCTAssertGreaterThan(highClergyRate, lowClergyRate)
    }

    func testDhimmiMilletAndHussiteCompactsBlockConversion() throws {
        var world = Scenario1453.makeWorld()
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let balkanProv = try XCTUnwrap(firstProvince(in: world, ownedBy: "TUR", majorityReligion: .orthodox))
        let baseline = FaithSystem.monthlyConversionRate(world: world, province: balkanProv, from: .orthodox)

        let ownCourtsIdx = try XCTUnwrap(world.government.rules.privileges.firstIndex(where: { $0.key == "own_courts" }))
        let milletIdx = try XCTUnwrap(world.government.rules.privileges.firstIndex(where: { $0.key == "millet" }))

        // own_courts slows conversion without completely blocking it
        world.government.privileges[tur.index].insert(ownCourtsIdx)
        let slowed = FaithSystem.monthlyConversionRate(world: world, province: balkanProv, from: .orthodox)
        XCTAssertGreaterThan(slowed, 0)
        XCTAssertLessThan(slowed, baseline)

        // millet completely blocks non-Muslim conversion and missionary dispatch
        world.government.privileges[tur.index].insert(milletIdx)
        XCTAssertEqual(FaithSystem.monthlyConversionRate(world: world, province: balkanProv, from: .orthodox), 0)
        if case .blockedByPrivilege = FaithSystem.missionaryRefusal(world, by: tur, in: balkanProv) {
            // expected
        } else {
            XCTFail("Expected millet privilege to block missionary dispatch")
        }

        // Hussite Compacts block Catholic <-> Hussite conversion
        let boh = try XCTUnwrap(world.countries.id(forTag: "BOH"))
        let prague = try XCTUnwrap(world.countries.capital[boh.index])
        XCTAssertTrue(world.faith.hussiteCompactsActive)
        XCTAssertEqual(FaithSystem.monthlyConversionRate(world: world, province: prague, from: .catholic), 0)
        world.faith.hussiteCompactsActive = false
        XCTAssertGreaterThan(FaithSystem.monthlyConversionRate(world: world, province: prague, from: .catholic), 0)
    }

    func testMissionaryAcceleratesConversionAndCostsDucats() throws {
        let simA = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 77)
        let simB = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 77)
        let tur = try XCTUnwrap(simA.world.countries.id(forTag: "TUR"))
        let prov = try XCTUnwrap(
            simA.world.provinces.id(named: "Thessaloniki")
                ?? firstProvince(in: simA.world, ownedBy: "TUR", majorityReligion: .orthodox)
        )
        XCTAssertEqual(simA.world.provinces.owner[prov.index], tur)

        simA.world.humanCountries = [tur]
        simB.world.humanCountries = [tur]
        let sunniBefore = popCount(in: simA.world, province: prov, religion: .sunni)
        let err = FaithSystem.sendMissionary(&simB.world, by: tur, to: prov, date: simB.date)
        XCTAssertNil(err)
        XCTAssertTrue(FaithSystem.hasMissionary(simB.world, in: prov))

        simA.advance(days: 120)
        simB.advance(days: 120)

        let sunniA = popCount(in: simA.world, province: prov, religion: .sunni)
        let sunniB = popCount(in: simB.world, province: prov, religion: .sunni)
        XCTAssertGreaterThan(sunniB, sunniA)
        XCTAssertGreaterThan(sunniB, sunniBefore)
        XCTAssertGreaterThan(simB.world.provinces.conversionProgress[prov.index], simA.world.provinces.conversionProgress[prov.index])

        // Recall stops missionary
        if FaithSystem.hasMissionary(simB.world, in: prov) {
            XCTAssertTrue(FaithSystem.recallMissionary(&simB.world, by: tur, from: prov))
        }
        XCTAssertFalse(FaithSystem.hasMissionary(simB.world, in: prov))

        // Direct monthly upkeep accounting check
        var upkeepWorld = Scenario1453.makeWorld()
        let beforeTreasury = upkeepWorld.countries.treasury[tur.index]
        let beforeExpenses = upkeepWorld.countries.lastMonthlyExpenses[tur.index]
        XCTAssertNil(FaithSystem.sendMissionary(&upkeepWorld, by: tur, to: prov, date: Scenario1453.startDate))
        var rng = GameRandom(seed: 1)
        FaithSystem.runMonthly(&upkeepWorld, date: GameDate(year: 1453, month: 6, day: 1), random: &rng)
        XCTAssertEqual(beforeTreasury - upkeepWorld.countries.treasury[tur.index], FaithModel.missionaryMonthlyCost, accuracy: 1e-9)
        XCTAssertEqual(upkeepWorld.countries.lastMonthlyExpenses[tur.index] - beforeExpenses, FaithModel.missionaryMonthlyCost, accuracy: 1e-9)
    }

    func testReligiousUnrestInWrongFaithProvinces() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 11)
        let wrongProv = try XCTUnwrap(firstProvince(in: sim.world, ownedBy: "TUR", majorityReligion: .orthodox))
        let sameProv = try XCTUnwrap(firstProvince(in: sim.world, ownedBy: "TUR", majorityReligion: .sunni))

        sim.advance(days: 120)
        XCTAssertGreaterThan(sim.world.provinces.religiousUnrest[wrongProv.index], 1.0)
        XCTAssertLessThan(sim.world.provinces.religiousUnrest[sameProv.index], sim.world.provinces.religiousUnrest[wrongProv.index])
    }

    func testFaithSaveLoadAndDeterminismWithPopSplits() throws {
        let sim1 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 999)
        let tur = try XCTUnwrap(sim1.world.countries.id(forTag: "TUR"))
        let balkan = try XCTUnwrap(firstProvince(in: sim1.world, ownedBy: "TUR", majorityReligion: .orthodox))
        XCTAssertNil(FaithSystem.sendMissionary(&sim1.world, by: tur, to: balkan, date: sim1.date))
        sim1.advance(days: 90) // splits new Sunni pop rows into balkan

        let data = try SaveStorage.encodeArchive(sim1, name: "faith_test", playerTag: "TUR")
        let restored = try SaveStorage.decodeArchive(from: data).simulation

        XCTAssertEqual(restored.world.pops.count, sim1.world.pops.count)
        XCTAssertEqual(restored.world.faith, sim1.world.faith)
        XCTAssertEqual(restored.world.provinces.religiousUnrest[balkan.index], sim1.world.provinces.religiousUnrest[balkan.index])
        XCTAssertEqual(restored.world.provinces.conversionProgress[balkan.index], sim1.world.provinces.conversionProgress[balkan.index])
        XCTAssertEqual(restored.world.countries.prestige, sim1.world.countries.prestige)

        // Advance both further and confirm exact parity (determinism across save/reload and pop table rebuild).
        sim1.advance(days: 60)
        restored.advance(days: 60)
        XCTAssertEqual(restored.world.pops.size, sim1.world.pops.size)
        XCTAssertEqual(restored.world.provinces.religiousUnrest, sim1.world.provinces.religiousUnrest)
    }

    // MARK: - Part B: Historical Movements

    func testHussiteQuestionDecisionsAndAIResolution() throws {
        var world = Scenario1453.makeWorld()
        let boh = try XCTUnwrap(world.countries.id(forTag: "BOH"))
        let pap = try XCTUnwrap(world.countries.id(forTag: "PAP"))
        let prague = try XCTUnwrap(world.countries.capital[boh.index])
        XCTAssertEqual(world.faith.hussiteOutcome, .unresolved)
        XCTAssertTrue(world.faith.hussiteCompactsActive)

        // Taborite revival ends Compacts and lowers Papal opinion
        let opinBefore = world.diplomacy.opinion(of: boh, by: pap)
        XCTAssertTrue(MovementSystem.resolveHussiteQuestion(&world, choice: .taboriteRevival, by: boh, date: GameDate(year: 1456, month: 4, day: 1)))
        XCTAssertEqual(world.faith.hussiteOutcome, .taboriteRevival)
        XCTAssertFalse(world.faith.hussiteCompactsActive)
        XCTAssertLessThan(world.diplomacy.opinion(of: boh, by: pap), opinBefore)
        XCTAssertGreaterThan(FaithSystem.monthlyConversionRate(world: world, province: prague, from: .catholic), 0)

        // Separate run: AI resolves Hussite question probabilistically over 1454-1475
        var aiWorld = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 42)
        for yr in 1453...1478 {
            for mo in 1...12 {
                MovementSystem.runMonthly(&aiWorld, date: GameDate(year: yr, month: mo, day: 1), random: &rng)
            }
        }
        XCTAssertNotEqual(aiWorld.faith.hussiteOutcome, .unresolved)
    }

    func testSufiOrdersAndSafaviyyaQizilbashRise() throws {
        var world = Scenario1453.makeWorld()
        let ardabil = try XCTUnwrap(world.provinces.id(named: "Ardabil"))
        let twelverBefore = popCount(in: world, province: ardabil, religion: .twelver)
        let safStrengthBefore = world.faith.safaviyyaStrength
        XCTAssertEqual(world.faith.safaviyyaPhase, .growing)

        var rng = GameRandom(seed: 1453)
        for yr in 1453...1518 {
            for mo in 1...12 {
                MovementSystem.runMonthly(&world, date: GameDate(year: yr, month: mo, day: 1), random: &rng)
            }
        }

        XCTAssertGreaterThan(world.faith.safaviyyaStrength, safStrengthBefore)
        XCTAssertTrue(world.faith.safaviyyaPhase == .militant || world.faith.safaviyyaPhase == .triumphant)
        XCTAssertGreaterThan(popCount(in: world, province: ardabil, religion: .twelver), twelverBefore)
        XCTAssertNotNil(world.faith.safaviyyaYear)
        if world.faith.safaviyyaPhase == .triumphant, let owner = world.provinces.owner[ardabil.index] {
            XCTAssertEqual(world.countries.religion[owner.index], .twelver)
        }
    }

    func testReformationNeverBefore1500AppearsBy1530AndSpreadsAlongTradeRoutes() throws {
        var w1 = Scenario1453.makeWorld()
        var w2 = w1
        var rng1 = GameRandom(seed: 2026)
        var rng2 = GameRandom(seed: 2026)

        // Check every month from 1453 to 1532: must NOT appear before 1500, MUST appear before end of 1530.
        var appearedBefore1500 = false
        for yr in 1453...1532 {
            for mo in 1...12 {
                let d = GameDate(year: yr, month: mo, day: 1)
                MovementSystem.runMonthly(&w1, date: d, random: &rng1)
                MovementSystem.runMonthly(&w2, date: d, random: &rng2)
                if yr < 1500 && (!w1.faith.reformationCentres.isEmpty || w1.faith.reformationStarted) {
                    appearedBefore1500 = true
                }
            }
            if yr == 1530 {
                XCTAssertTrue(w1.faith.reformationStarted, "Reformation should appear by 1530")
                XCTAssertFalse(w1.faith.reformationCentres.isEmpty)
            }
        }
        XCTAssertFalse(appearedBefore1500, "Reformation must never appear before 1500")
        XCTAssertTrue(w1.faith.reformationReligions.contains(.protestant))
        XCTAssertTrue(w1.faith.reformationReligions.contains(.reformed))

        // Determinism: identical outputs for identical seeds
        XCTAssertEqual(w1.faith, w2.faith)
        XCTAssertEqual(w1.pops.size, w2.pops.size)

        // Verify pops converted both in a centre's home province AND in a trade-route partner market!
        let centre = try XCTUnwrap(w1.faith.reformationCentres.first)
        XCTAssertGreaterThan(popCount(in: w1, province: centre.province, religion: centre.religion), 0)

        let homeMarket = w1.economy.provinceMarket[centre.province.index]
        let linkedMarkets = Set(w1.economy.routes.compactMap { r -> MarketID? in
            if r.from == homeMarket { return r.to }
            if r.to == homeMarket { return r.from }
            return nil
        })
        var tradeConvertsFound = false
        for p in 0..<w1.provinces.count where ProvinceID(p) != centre.province && linkedMarkets.contains(w1.economy.provinceMarket[p]) {
            if popCount(in: w1, province: ProvinceID(p), religion: centre.religion) > 0 {
                tradeConvertsFound = true
                break
            }
        }
        XCTAssertTrue(tradeConvertsFound, "Reformation should spread along trade routes to linked markets")

        // Verify save/load preserves Reformation centres & movement phases cleanly
        let sim = Simulation(restoringWorld: w1, date: GameDate(year: 1532, month: 12, day: 1), random: rng1, ticksRun: 100)
        let data = try SaveStorage.encodeArchive(sim, name: "reformation_save", playerTag: "TUR")
        let loaded = try SaveStorage.decodeArchive(from: data).simulation
        XCTAssertEqual(loaded.world.faith.reformationCentres, w1.faith.reformationCentres)
        XCTAssertEqual(loaded.world.faith.safaviyyaPhase, w1.faith.safaviyyaPhase)
        XCTAssertEqual(loaded.world.faith.hussiteOutcome, w1.faith.hussiteOutcome)
    }
}
