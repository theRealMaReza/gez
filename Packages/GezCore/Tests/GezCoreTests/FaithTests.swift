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
}
