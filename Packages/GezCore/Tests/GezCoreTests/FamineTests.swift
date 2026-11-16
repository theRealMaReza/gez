import XCTest
@testable import GezCore

/// Phase 12 Part B: harvests, famine and earthquakes.
final class FamineTests: XCTestCase {
    private func first(of month: Int, _ year: Int = 1453) -> GameDate {
        GameDate(year: year, month: month, day: 1)
    }

    private func people(_ world: World, in p: Int, _ cls: SocialClass) -> Double {
        var sum = 0.0
        for i in world.pops.range(for: ProvinceID(p)) where world.pops.socialClass[i] == cls { sum += world.pops.size[i] }
        return sum
    }

    func testHarvestIsRolledOnceAYearInAugust() {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1)
        FamineSystem.runMonthly(&world, date: first(of: 7), random: &rng)
        XCTAssertTrue(world.calamity.harvest.allSatisfy { $0 == 1 }, "no harvest before August")

        FamineSystem.runMonthly(&world, date: first(of: 8), random: &rng)
        XCTAssertEqual(world.calamity.harvestYear, 1453)
        let harvest = world.calamity.harvest
        XCTAssertEqual(harvest.count, world.provinces.count)
        XCTAssertTrue(harvest.allSatisfy { $0 >= FamineModel.worstHarvest && $0 <= FamineModel.bestHarvest })
        XCTAssertGreaterThan(Set(harvest).count, 20, "regions and states differ")
        let mean = harvest.reduce(0, +) / Double(harvest.count)
        XCTAssertEqual(mean, 1, accuracy: 0.1)
        // Provinces of one state share their weather.
        let state = world.states.provinces[0]
        XCTAssertEqual(Set(state.map { harvest[$0.index] }).count, 1)

        FamineSystem.runMonthly(&world, date: first(of: 9), random: &rng)
        XCTAssertEqual(world.calamity.harvest, harvest, "the harvest stays until next August")
        FamineSystem.runMonthly(&world, date: first(of: 8, 1454), random: &rng)
        XCTAssertNotEqual(world.calamity.harvest, harvest)
        XCTAssertEqual(rng.rawState, GameRandom(seed: 1).rawState, "famine uses its own random numbers")
    }

    func testDevastationLootingAndLeviesCutTheCrop() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 2)
        let fra = try XCTUnwrap(world.countries.id(forTag: "FRA"))
        let paris = try XCTUnwrap(world.provinces.id(named: "Paris"))
        let quiet = try XCTUnwrap(world.provinces(ownedBy: fra).first { $0 != paris })
        world.provinces.devastation[paris.index] = 1
        FamineSystem.runMonthly(&world, date: first(of: 6), random: &rng)
        XCTAssertEqual(world.calamity.stapleYieldFactor(paris.index), 1 - FamineModel.devastationLoss, accuracy: 1e-9)
        XCTAssertEqual(world.calamity.stapleYieldFactor(quiet.index), 1, accuracy: 1e-9)

        world.military.sieges.append(Siege(province: paris, besieger: fra, startDate: first(of: 6)))
        FamineSystem.runMonthly(&world, date: first(of: 6), random: &rng)
        XCTAssertEqual(world.calamity.stapleYieldFactor(paris.index),
                       (1 - FamineModel.devastationLoss) * FamineModel.lootingFactor, accuracy: 1e-9)

        // Levies kept under arms in July and September (not rolling the August harvest here).
        guard case .success = ArmySystem.raiseLevies(&world, fra, in: quiet) else {
            return XCTFail("could not raise levies")
        }
        FamineSystem.runMonthly(&world, date: first(of: 7), random: &rng)
        FamineSystem.runMonthly(&world, date: first(of: 9), random: &rng)
        XCTAssertEqual(world.calamity.levyHarvestLoss[quiet.index], 2 * FamineModel.levyLossPerMonth, accuracy: 1e-9)
        XCTAssertEqual(world.calamity.stapleYieldFactor(quiet.index), 1 - 2 * FamineModel.levyLossPerMonth, accuracy: 1e-9)
        // Outside the harvest months nothing is added; next July the slate is clean.
        FamineSystem.runMonthly(&world, date: first(of: 11), random: &rng)
        XCTAssertEqual(world.calamity.levyHarvestLoss[quiet.index], 2 * FamineModel.levyLossPerMonth, accuracy: 1e-9)
        ArmySystem.disbandLevies(&world, of: fra)
        FamineSystem.runMonthly(&world, date: first(of: 7, 1454), random: &rng)
        XCTAssertEqual(world.calamity.levyHarvestLoss[quiet.index], 0)
    }

    func testFailedHarvestBringsFamineThatKillsThePoorAndThenPasses() {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 3)
        let P = world.provinces.count

        // A normal month first: the markets learn what they are used to.
        FamineSystem.runMonthly(&world, date: first(of: 10), random: &rng)
        XCTAssertEqual(world.provinces.famine.filter { $0 > 0 }.count, 0)
        XCTAssertEqual(world.calamity.stapleNorm.count, world.economy.markets.count)

        // The harvest fails everywhere.
        for p in 0..<P { FamineSystem.setHarvest(&world, in: ProvinceID(p), to: 0.4) }
        FamineSystem.runMonthly(&world, date: first(of: 11), random: &rng)
        let staplesBefore = FamineSystem.stapleRatios(world)
        MarketSystem.runMonthly(&world)
        let staplesAfter = FamineSystem.stapleRatios(world)
        XCTAssertLessThan(staplesAfter.reduce(0, +), staplesBefore.reduce(0, +) * 0.8, "less food reaches the markets")

        let worst = (0..<P).max { world.provinces.population[$0] < world.provinces.population[$1] }!
        let noblesBefore = people(world, in: worst, .nobles)
        let peasantsBefore = people(world, in: worst, .peasants)
        let moodBefore = world.pops.satisfaction[world.pops.range(for: ProvinceID(worst)).first!]
        FamineSystem.runMonthly(&world, date: first(of: 12), random: &rng)

        let starving = world.provinces.famine.filter { $0 >= 0.3 }.count
        XCTAssertGreaterThan(starving, P / 4, "famine across the land")
        XCTAssertGreaterThan(world.calamity.totalFamineDeaths, 0)
        XCTAssertTrue(world.calamity.notes.contains { $0.kind == "famine" })
        XCTAssertGreaterThan(world.provinces.famine[worst], 0.3)
        XCTAssertGreaterThan(world.calamity.lastFamineDeaths[worst], 0)
        let noblesLost = 1 - people(world, in: worst, .nobles) / noblesBefore
        let peasantsLost = 1 - people(world, in: worst, .peasants) / peasantsBefore
        XCTAssertGreaterThan(peasantsLost, 0)
        XCTAssertLessThan(noblesLost, peasantsLost * 0.5, "the poor starve first")
        XCTAssertLessThan(world.pops.satisfaction[world.pops.range(for: ProvinceID(worst)).first!], moodBefore)

        // Good harvests return: the famine fades over the next months.
        for p in 0..<P { FamineSystem.setHarvest(&world, in: ProvinceID(p), to: 1) }
        let deathsAtPeak = world.calamity.totalFamineDeaths
        for m in 1...10 {
            FamineSystem.runMonthly(&world, date: first(of: m <= 7 ? m : m + 2, 1454), random: &rng)
            MarketSystem.runMonthly(&world)
        }
        XCTAssertGreaterThan(world.calamity.totalFamineDeaths, deathsAtPeak)
        XCTAssertLessThan(world.provinces.famine.filter { $0 >= 0.3 }.count, starving / 4)
    }

    func testFaultZonesAndKnownEarthquakesAreLoaded() throws {
        let world = Scenario1453.makeWorld()
        let rules = world.calamityRules
        XCTAssertGreaterThanOrEqual(rules.faultZones.count, 20)
        func zone(_ name: String) throws -> FaultZone { try XCTUnwrap(rules.faultZones.first { $0.name == name }) }
        // The six areas the roadmap names.
        let pairs = [("North Anatolian Fault", "Konstantiniyye"), ("Aegean Sea", "Athens"),
                     ("Southern Apennines and Calabria", "Naples"), ("Tabriz", "Tabriz"),
                     ("Lisbon and the Gulf of Cadiz", "Lisbon"), ("Kashmir and the Punjab Hills", "Srinagar")]
        for (zoneName, town) in pairs {
            let province = try XCTUnwrap(world.provinces.id(named: town))
            XCTAssertTrue(try zone(zoneName).provinces.contains(province), "\(town) lies in \(zoneName)")
        }
        for z in rules.faultZones {
            XCTAssertFalse(z.provinces.isEmpty)
            XCTAssertTrue(z.yearlyChance > 0 && z.yearlyChance < 0.5 && z.strength > 0 && z.strength <= 1)
        }
        let naples = try XCTUnwrap(rules.historicalQuakes.first { $0.date == GameDate(year: 1456, month: 12, day: 5) })
        XCTAssertEqual(world.provinces.name[naples.province.index], "Naples")
    }

    func testEarthquakeDamagesBuildingsFortsAndPeople() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 9)
        let naples = try XCTUnwrap(world.provinces.id(named: "Naples"))
        let neighbour = try XCTUnwrap(world.provinces.neighbors[naples.index].first)
        let T = world.economy.buildings.typeCount
        func levels(_ p: ProvinceID) -> Int { (0..<T).reduce(0) { $0 + world.economy.buildings.level(p, BuildingTypeID($1)) } }
        let levelsBefore = levels(naples)
        XCTAssertGreaterThan(levelsBefore, 3)
        let peopleBefore = world.provinces.population[naples.index]
        let neighbourBefore = world.provinces.population[neighbour.index]

        var lost = 0
        var dead = 0.0
        for _ in 0..<3 {
            let r = QuakeSystem.strike(&world, epicentre: naples, strength: 1, name: "Test quake", date: first(of: 6), rng: &rng)
            lost += r.buildingLevelsLost + r.fortLevelsLost
            dead += r.deaths
        }
        XCTAssertGreaterThan(lost, 0)
        XCTAssertLessThan(levels(naples), levelsBefore)
        XCTAssertGreaterThan(dead, 0)
        XCTAssertLessThan(world.provinces.population[naples.index], peopleBefore * 0.95)
        XCTAssertLessThan(world.provinces.population[neighbour.index], neighbourBefore, "the neighbours are shaken too")
        XCTAssertGreaterThan(world.provinces.population[neighbour.index] / neighbourBefore,
                             world.provinces.population[naples.index] / peopleBefore, "but less than the epicentre")
        XCTAssertGreaterThan(world.provinces.devastation[naples.index], 0.5)
        XCTAssertGreaterThan(world.provinces.devastation[neighbour.index], 0)
        for p in [naples, neighbour] {
            let fort = try XCTUnwrap(world.economy.buildingTypes.firstIndex { $0.effect == .fort })
            XCTAssertEqual(world.provinces.fortLevel[p.index], world.economy.buildings.level(p, BuildingTypeID(fort)))
            XCTAssertLessThanOrEqual(world.provinces.fortGarrison[p.index], world.provinces.maxGarrison(of: p))
        }
        XCTAssertEqual(world.calamity.quakes.count, 3)
        XCTAssertEqual(world.calamity.totalQuakeDeaths, dead, accuracy: 1e-6)
        XCTAssertTrue(world.calamity.notes.contains { $0.kind == "earthquake" && $0.province == naples })
    }

    func testKnownAndChanceEarthquakes() throws {
        // The Naples earthquake of 5 December 1456 strikes on the next monthly tick.
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 4)
        QuakeSystem.runMonthly(&world, date: first(of: 12, 1456), random: &rng)
        XCTAssertFalse(world.calamity.quakes.contains { $0.name == "The Great Earthquake of Naples" })
        QuakeSystem.runMonthly(&world, date: first(of: 1, 1457), random: &rng)
        let naples = try XCTUnwrap(world.calamity.quakes.first { $0.name == "The Great Earthquake of Naples" })
        XCTAssertEqual(world.provinces.name[naples.epicentre.index], "Naples")
        QuakeSystem.runMonthly(&world, date: first(of: 2, 1457), random: &rng)
        XCTAssertEqual(world.calamity.quakes.filter { $0.name == "The Great Earthquake of Naples" }.count, 1, "only once")

        // Fifty years of chance: a damaging earthquake every couple of years, always on a fault.
        var fresh = Scenario1453.makeWorld()
        fresh.calamityRules.historicalQuakes = []
        var onFault = Set<Int>()
        for z in fresh.calamityRules.faultZones { for p in z.provinces { onFault.insert(p.index) } }
        var count = 0
        for year in 1454..<1504 {
            for m in 1...12 {
                QuakeSystem.runMonthly(&fresh, date: first(of: m, year), random: &rng)
                for q in fresh.calamity.quakes {
                    XCTAssertTrue(onFault.contains(q.epicentre.index))
                    XCTAssertTrue(q.strength > 0 && q.strength <= 1)
                }
                count += fresh.calamity.quakes.count
                fresh.calamity.quakes = []
            }
        }
        XCTAssertGreaterThan(count, 6)
        XCTAssertLessThan(count, 70)
        XCTAssertEqual(rng.rawState, GameRandom(seed: 4).rawState, "earthquakes use their own random numbers")
    }

    func testFamineAndQuakeSaveLoadAndDeterminism() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 21)
        var rng = GameRandom(seed: 6)
        let naples = try XCTUnwrap(sim.world.provinces.id(named: "Naples"))
        QuakeSystem.strike(&sim.world, epicentre: naples, strength: 0.8, name: "Test quake", date: sim.date, rng: &rng)
        sim.advance(days: 70) // past 1 August: the harvest is rolled

        XCTAssertEqual(sim.world.calamity.harvestYear, 1453)
        let data = try SaveStorage.encodeArchive(sim, name: "famine_test", playerTag: "NAP")
        let restored = try SaveStorage.decodeArchive(from: data).simulation
        XCTAssertEqual(restored.world.calamity, sim.world.calamity)
        XCTAssertEqual(restored.world.calamityRules, sim.world.calamityRules)
        XCTAssertEqual(restored.world.provinces.famine, sim.world.provinces.famine)

        sim.advance(days: 35)
        restored.advance(days: 35)
        XCTAssertEqual(restored.world.calamity, sim.world.calamity)
        XCTAssertEqual(restored.world.pops.size, sim.world.pops.size)
        XCTAssertEqual(restored.world.economy.markets.price, sim.world.economy.markets.price)
    }
}
