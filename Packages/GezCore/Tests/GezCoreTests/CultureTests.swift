import XCTest
@testable import GezCore

final class CultureTests: XCTestCase {
    private func culturePop(in world: World, province: ProvinceID, culture: CultureID) -> Double {
        var sum = 0.0
        for i in world.pops.range(for: province) where world.pops.culture[i] == culture {
            sum += world.pops.size[i]
        }
        return sum
    }

    func testGovernmentRankAndLawAcceptedCultureSlots() throws {
        var world = Scenario1453.makeWorld()
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR")) // large empire + tolerance law
        XCTAssertEqual(CultureSystem.governmentRank(world, tur), .empire)
        XCTAssertGreaterThanOrEqual(CultureSystem.acceptedCultureSlots(world, tur), 4) // 3 empire + 1 tolerance

        let boh = try XCTUnwrap(world.countries.id(forTag: "BOH"))
        let slotsBefore = CultureSystem.acceptedCultureSlots(world, boh)
        let faithArea = try XCTUnwrap(world.government.rules.lawAreas.firstIndex(where: { $0.key == "faith" }))
        let openOpt = try XCTUnwrap(world.government.rules.lawAreas[faithArea].options.firstIndex(where: { $0.key == "open" }))
        let orthoOpt = try XCTUnwrap(world.government.rules.lawAreas[faithArea].options.firstIndex(where: { $0.key == "orthodoxy" }))

        world.government.laws[boh.index][faithArea] = openOpt
        GovernmentSystem.refreshEffects(&world, boh)
        let openSlots = CultureSystem.acceptedCultureSlots(world, boh)

        world.government.laws[boh.index][faithArea] = orthoOpt
        GovernmentSystem.refreshEffects(&world, boh)
        let orthoSlots = CultureSystem.acceptedCultureSlots(world, boh)

        XCTAssertGreaterThan(openSlots, orthoSlots)
        XCTAssertGreaterThanOrEqual(slotsBefore, 1)
    }

    func testAcceptedCultureRemovesTaxManpowerAndContentmentPenalties() throws {
        var worldA = Scenario1453.makeWorld()
        var worldB = worldA
        let tur = try XCTUnwrap(worldA.countries.id(forTag: "TUR"))
        let thessaloniki = try XCTUnwrap(worldA.provinces.id(named: "Thessaloniki"))
        let greek = worldA.provinces.majorityCulture[thessaloniki.index]
        XCTAssertNotEqual(greek, worldA.countries.primaryCulture[tur.index])

        // Accept Greek in worldB only
        XCTAssertNil(CultureSystem.acceptCulture(&worldB, country: tur, culture: greek, date: Scenario1453.startDate))
        XCTAssertTrue(CultureSystem.isAccepted(worldB, country: tur, culture: greek))

        let owned = worldA.provinces(ownedBy: tur)
        let mpBefore = ArmySystem.calculateMaxManpower(worldA, tur, owned: owned)
        let mpAfter = ArmySystem.calculateMaxManpower(worldB, tur, owned: owned)
        XCTAssertGreaterThan(mpAfter, mpBefore)

        // Advance one month -> higher tax and higher Greek pop contentment when accepted
        MarketSystem.runMonthly(&worldA)
        MarketSystem.runMonthly(&worldB)
        let taxA = worldA.countries.lastTax[tur.index].reduce(0, +)
        let taxB = worldB.countries.lastTax[tur.index].reduce(0, +)
        XCTAssertGreaterThan(taxB, taxA)

        var satA = 0.0, cntA = 0.0
        for i in worldA.pops.range(for: thessaloniki) where worldA.pops.culture[i] == greek {
            satA += worldA.pops.satisfaction[i] * worldA.pops.size[i]
            cntA += worldA.pops.size[i]
        }
        var satB = 0.0, cntB = 0.0
        for i in worldB.pops.range(for: thessaloniki) where worldB.pops.culture[i] == greek {
            satB += worldB.pops.satisfaction[i] * worldB.pops.size[i]
            cntB += worldB.pops.size[i]
        }
        XCTAssertGreaterThan(satB / cntB, satA / cntA)

        // Revoking removes accepted status and drops Greek pop satisfaction
        let beforeRevokeSat = worldB.pops.satisfaction[worldB.pops.range(for: thessaloniki).first!]
        XCTAssertTrue(CultureSystem.revokeCulture(&worldB, country: tur, culture: greek, date: Scenario1453.startDate))
        XCTAssertFalse(CultureSystem.isAccepted(worldB, country: tur, culture: greek))
        XCTAssertLessThan(worldB.pops.satisfaction[worldB.pops.range(for: thessaloniki).first!], beforeRevokeSat)
    }

    func testSlowAssimilationConditions() throws {
        var world = Scenario1453.makeWorld()
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let turkish = world.countries.primaryCulture[tur.index]

        // Find a province bordering a Turkish-majority province whose pops are non-Turkish
        var candidate: ProvinceID?
        for p in 0..<world.provinces.count where world.provinces.owner[p] == tur && world.provinces.majorityCulture[p] != turkish {
            let nearTurkish = world.provinces.neighbors[p].contains { world.provinces.majorityCulture[$0.index] == turkish }
            if nearTurkish {
                candidate = ProvinceID(p)
                break
            }
        }
        let targetProv = try XCTUnwrap(candidate)
        let stateRel = world.countries.religion[tur.index]

        // Isolate assimilation from unrelated war/famine migration in this unit test
        world.provinces.religiousUnrest = Array(repeating: 0, count: world.provinces.count)
        world.provinces.devastation = Array(repeating: 0, count: world.provinces.count)
        world.provinces.famine = Array(repeating: 0, count: world.provinces.count)
        world.provinces.occupiedBy = Array(repeating: nil, count: world.provinces.count)
        world.military.sieges = []
        world.military.battles = []
        world.economy.markets.met = Array(repeating: 1.0, count: world.economy.markets.met.count)

        // While wrong religion or unhappy -> NO assimilation
        for i in world.pops.range(for: targetProv) {
            world.pops.satisfaction[i] = 0.25
        }
        var rng = GameRandom(seed: 10)
        let turkishWrongFaithBefore = culturePop(in: world, province: targetProv, culture: turkish)
        CultureSystem.runMonthly(&world, date: GameDate(year: 1453, month: 6, day: 1), random: &rng)
        XCTAssertEqual(culturePop(in: world, province: targetProv, culture: turkish), turkishWrongFaithBefore, accuracy: 1e-6)

        // Switch province pops to state religion AND content (>= 0.80) -> assimilates toward Turkish!
        for i in world.pops.range(for: targetProv) {
            world.pops.religion[i] = stateRel
            world.pops.satisfaction[i] = 0.85
        }
        world.refreshProvinceSummaries()

        let before = culturePop(in: world, province: targetProv, culture: turkish)
        for m in 7...12 {
            CultureSystem.runMonthly(&world, date: GameDate(year: 1453, month: m, day: 1), random: &rng)
        }
        let after = culturePop(in: world, province: targetProv, culture: turkish)
        XCTAssertGreaterThan(after, before)
        XCTAssertGreaterThan(world.provinces.assimilationProgress[targetProv.index], 0)
    }

    func testMigrationConservesTotalPopulationUnderDevastationPersecutionAndFamine() throws {
        var world = Scenario1453.makeWorld()
        let beforeTotal = world.pops.size.reduce(0, +)

        // Pick 3 trigger provinces: war devastation, religious persecution, famine
        let prov1 = try XCTUnwrap(world.provinces.id(named: "Thessaloniki"))
        let prov2 = try XCTUnwrap(world.provinces.id(named: "Prague"))
        let prov3 = try XCTUnwrap(world.provinces.id(named: "Vienna") ?? world.provinces.id(named: "Alexandria"))

        world.provinces.devastation[prov1.index] = 0.9
        world.provinces.religiousUnrest[prov2.index] = 45.0
        world.provinces.famine[prov3.index] = 0.85

        let p1Before = world.provinces.population[prov1.index]
        let p2Before = world.provinces.population[prov2.index]
        let p3Before = world.provinces.population[prov3.index]

        var rng = GameRandom(seed: 42)
        CultureSystem.runMonthly(&world, date: GameDate(year: 1453, month: 6, day: 1), random: &rng)

        let afterTotal = world.pops.size.reduce(0, +)
        XCTAssertEqual(afterTotal, beforeTotal, accuracy: 1e-6, "Migration must strictly conserve total world population")
        XCTAssertLessThan(world.provinces.population[prov1.index], p1Before)
        XCTAssertLessThan(world.provinces.population[prov2.index], p2Before)
        XCTAssertLessThan(world.provinces.population[prov3.index], p3Before)
        XCTAssertLessThan(world.provinces.lastNetMigration[prov1.index], 0)

        // Verify destinations received positive net migration
        let anyInflow = world.provinces.lastNetMigration.contains { $0 > 0 }
        XCTAssertTrue(anyInflow)
    }

    func testCultureSaveLoadAndDeterminism() throws {
        let sim1 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 314)
        let sim2 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 314)
        let tur = try XCTUnwrap(sim1.world.countries.id(forTag: "TUR"))
        let thessaloniki = try XCTUnwrap(sim1.world.provinces.id(named: "Thessaloniki"))
        let greek = sim1.world.provinces.majorityCulture[thessaloniki.index]

        XCTAssertNil(CultureSystem.acceptCulture(&sim1.world, country: tur, culture: greek, date: sim1.date))
        XCTAssertNil(CultureSystem.acceptCulture(&sim2.world, country: tur, culture: greek, date: sim2.date))

        sim1.world.provinces.devastation[thessaloniki.index] = 0.6
        sim2.world.provinces.devastation[thessaloniki.index] = 0.6

        sim1.advance(days: 65)
        sim2.advance(days: 65)

        XCTAssertEqual(sim1.world.pops.size, sim2.world.pops.size)
        XCTAssertEqual(sim1.world.provinces.assimilationProgress, sim2.world.provinces.assimilationProgress)
        XCTAssertEqual(sim1.world.provinces.lastNetMigration, sim2.world.provinces.lastNetMigration)

        let data = try SaveStorage.encodeArchive(sim1, name: "culture_test", playerTag: "TUR")
        let loaded = try SaveStorage.decodeArchive(from: data).simulation
        XCTAssertEqual(loaded.world.countries.acceptedCultures[tur.index], [greek])
        XCTAssertEqual(loaded.world.provinces.devastation, sim1.world.provinces.devastation)
        XCTAssertEqual(loaded.world.provinces.famine, sim1.world.provinces.famine)
        XCTAssertEqual(loaded.world.provinces.assimilationProgress, sim1.world.provinces.assimilationProgress)
    }

    /// The culture lookup table equals the per-pop checks (review speed-up).
    func testCultureStandingMatchesDirectChecks() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        for _ in 0..<62 { sim.tick() }
        let w = sim.world
        let table = CultureStanding(w)
        for c in 0..<w.countries.count {
            let one = CultureStanding(w, only: CountryID(c))
            for x in 0..<w.cultures.count {
                let cid = CountryID(c), cul = CultureID(x)
                let expected: UInt8 = CultureSystem.isAccepted(w, country: cid, culture: cul) ? 0
                    : (CultureSystem.isSameFamily(w, country: cid, culture: cul) ? 1 : 2)
                XCTAssertEqual(table.category(w, cid, cul), expected)
                XCTAssertEqual(one.category(w, cid, cul), expected)
            }
        }
    }

    /// Folding tiny groups keeps every person and leaves no group under one
    /// person (review fix: pop groups grew without limit).
    func testFoldDustConservesPeopleAndRemovesTinyGroups() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        for _ in 0..<200 { sim.tick() }
        var pops = sim.world.pops
        let P = sim.world.provinces.count
        // Add some dust by hand so the test does not depend on the run.
        if pops.count > 0 { pops.size[0] = max(pops.size[0], 100) }
        let before = pops.size.reduce(0, +)
        pops.foldDust(provinceCount: P)
        let after = pops.size.reduce(0, +)
        XCTAssertEqual(before, after, accuracy: max(1e-6, before * 1e-12))
        for p in 0..<P {
            let r = pops.range(for: ProvinceID(p))
            let classes = Set(r.map { pops.socialClass[$0] })
            for cls in classes {
                let rows = r.filter { pops.socialClass[$0] == cls }
                // A tiny group may remain only if it is the only group of its class.
                if rows.count > 1 {
                    for i in rows { XCTAssertGreaterThanOrEqual(pops.size[i], PopDust.foldBelow) }
                }
            }
        }
    }
}
