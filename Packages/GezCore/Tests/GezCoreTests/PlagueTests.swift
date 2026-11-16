import XCTest
@testable import GezCore

/// Phase 12 Part A: plague, camp fever and smallpox.
final class PlagueTests: XCTestCase {
    private func month(_ n: Int) -> GameDate {
        GameDate(year: 1453 + (5 + n) / 12, month: (5 + n) % 12 + 1, day: 1)
    }

    private func people(_ world: World, in p: ProvinceID, _ cls: SocialClass? = nil) -> Double {
        var sum = 0.0
        for i in world.pops.range(for: p) where cls == nil || world.pops.socialClass[i] == cls {
            sum += world.pops.size[i]
        }
        return sum
    }

    /// The biggest towns of the map, largest first.
    private func greatTowns(_ world: World, _ n: Int) -> [ProvinceID] {
        let order = (0..<world.provinces.count).sorted {
            let a = world.provinces.development[$0], b = world.provinces.development[$1]
            return a != b ? a > b : $0 < $1
        }
        return order.prefix(n).map(ProvinceID.init)
    }

    func testCourseWeightsAddUpToOne() {
        for d in Disease.allCases {
            let n = PlagueModel.rule(d).months
            var sum = 0.0
            for t in 0..<n { sum += PlagueModel.courseWeight(months: n, month: t) }
            XCTAssertEqual(sum, 1, accuracy: 1e-9)
            // Peak in the middle, not at the ends.
            XCTAssertGreaterThan(PlagueModel.courseWeight(months: n, month: n / 2), PlagueModel.courseWeight(months: n, month: 0))
        }
        XCTAssertEqual(PlagueModel.courseWeight(months: 9, month: 9), 0)
    }

    func testOutbreakKillsThePoorMoreAndLeavesImmunity() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 5)
        let town = try XCTUnwrap(world.provinces.id(named: "Konstantiniyye"))
        let before = people(world, in: town)
        let noblesBefore = people(world, in: town, .nobles)
        let peasantsBefore = people(world, in: town, .peasants)
        XCTAssertGreaterThan(noblesBefore, 0)

        XCTAssertTrue(PlagueSystem.startOutbreak(&world, in: town, disease: .plague, date: month(0)))
        XCTAssertFalse(PlagueSystem.startOutbreak(&world, in: town, disease: .plague, date: month(0)), "already struck")
        XCTAssertGreaterThan(world.calamity.infection(town.index, .plague), 0)

        let months = PlagueModel.rule(.plague).months
        for m in 1...months {
            XCTAssertTrue(world.calamity.hasOutbreak(town.index, .plague))
            PlagueSystem.runMonthly(&world, date: month(m), random: &rng)
        }
        XCTAssertFalse(world.calamity.hasOutbreak(town.index, .plague), "the outbreak ends after its months")

        let lost = 1 - people(world, in: town) / before
        XCTAssertGreaterThan(lost, 0.02)
        XCTAssertLessThan(lost, 0.25)
        XCTAssertEqual(world.provinces.population[town.index], people(world, in: town), accuracy: 1)
        XCTAssertGreaterThan(world.calamity.totalDeaths[Disease.plague.rawValue], 0)

        let noblesLost = 1 - people(world, in: town, .nobles) / noblesBefore
        let peasantsLost = 1 - people(world, in: town, .peasants) / peasantsBefore
        XCTAssertLessThan(noblesLost, peasantsLost * 0.7, "nobles die less than peasants")

        // Survivors are immune for years, then it fades.
        XCTAssertGreaterThan(world.calamity.immunity(town.index, .plague), 0.7)
        XCTAssertFalse(PlagueSystem.startOutbreak(&world, in: town, disease: .plague, date: month(months + 1)))
        // Another disease is another matter.
        XCTAssertTrue(PlagueSystem.startOutbreak(&world, in: town, disease: .smallpox, date: month(months + 1)))
        let slot = world.calamity.slot(town.index, .plague)
        world.calamity.immunity[slot] = 0.9
        let immune = world.calamity.immunity(town.index, .plague)
        for m in 0..<24 { PlagueSystem.runMonthly(&world, date: month(months + 2 + m), random: &rng) }
        XCTAssertLessThan(world.calamity.immunity(town.index, .plague), immune)
    }

    func testPlagueSpreadsFromGreatTowns() {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 11)
        let towns = greatTowns(world, 8)
        for t in towns {
            XCTAssertTrue(PlagueSystem.startOutbreak(&world, in: t, disease: .plague, date: month(0), severity: 1))
        }
        var struck = Set(towns.map(\.index))
        for m in 1...12 {
            PlagueSystem.runMonthly(&world, date: month(m), random: &rng)
            for p in 0..<world.provinces.count where world.calamity.hasOutbreak(p, .plague) { struck.insert(p) }
        }
        XCTAssertGreaterThan(struck.count, towns.count, "plague reached provinces beyond where it began")
        // It does not swallow the whole map in a year either.
        XCTAssertLessThan(struck.count, world.provinces.count / 2)
    }

    func testPlagueDoesNotUseTheGamesRandomNumbers() {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 77)
        let state = rng.rawState
        for m in 1...6 { PlagueSystem.runMonthly(&world, date: month(m), random: &rng) }
        XCTAssertEqual(rng.rawState, state)
        XCTAssertTrue(world.calamity.seeded)
    }

    func testQuarantineAndCordonCostMoneyTradeAndTime() throws {
        var world = Scenario1453.makeWorld()
        let ven = try XCTUnwrap(world.countries.id(forTag: "VEN"))
        let capital = try XCTUnwrap(world.countries.capital[ven.index])
        XCTAssertTrue(world.hasSeaAccess(capital))
        world.countries.treasury[ven.index] = 500

        // Quarantine: paid at once, less tax, only on the sea, only at home.
        XCTAssertNil(PlagueSystem.setQuarantine(&world, ven, capital, on: true))
        XCTAssertTrue(world.calamity.isQuarantined(capital.index))
        XCTAssertEqual(world.countries.treasury[ven.index], 500 - PlagueSystem.quarantineCost(world, capital), accuracy: 1e-9)
        XCTAssertEqual(world.calamity.taxFactor(capital.index), PlagueModel.quarantineTaxFactor, accuracy: 1e-9)
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        XCTAssertEqual(PlagueSystem.setQuarantine(&world, tur, capital, on: true), .notOwner)
        if let inland = (0..<world.provinces.count).first(where: {
            world.provinces.owner[$0] != nil && !world.provinces.isCoastal[$0]
        }) {
            let owner = world.provinces.owner[inland]!
            world.countries.treasury[owner.index] = 500
            XCTAssertEqual(PlagueSystem.setQuarantine(&world, owner, ProvinceID(inland), on: true), .notAPort)
        }

        // Cordon: marches through it take half as long again.
        XCTAssertNil(PlagueSystem.setCordon(&world, ven, capital, on: true))
        XCTAssertTrue(world.calamity.isCordoned(capital.index))
        XCTAssertEqual(world.calamity.taxFactor(capital.index),
                       PlagueModel.quarantineTaxFactor * PlagueModel.cordonTaxFactor, accuracy: 1e-9)
        var longMarch: (from: ProvinceID, to: ProvinceID, days: Double)?
        for p in 0..<world.provinces.count where world.provinces.owner[p] != nil && world.provinces.occupiedBy[p] == nil {
            for n in world.provinces.neighbors[p] {
                let days = ArmySystem.stepDays(world, from: ProvinceID(p), to: n)
                if days >= 3 && !world.calamity.isCordoned(n.index) { longMarch = (ProvinceID(p), n, days) }
            }
            if longMarch != nil { break }
        }
        let march = try XCTUnwrap(longMarch)
        let marchOwner = try XCTUnwrap(world.provinces.owner[march.from.index])
        world.countries.treasury[marchOwner.index] = 500
        XCTAssertNil(PlagueSystem.setCordon(&world, marchOwner, march.from, on: true))
        XCTAssertGreaterThan(ArmySystem.stepDays(world, from: march.from, to: march.to), march.days * 1.3)
        XCTAssertGreaterThan(ArmySystem.stepDays(world, from: march.to, to: march.from), 0)

        // A poor country cannot afford it.
        world.countries.treasury[tur.index] = 0
        let turCapital = try XCTUnwrap(world.countries.capital[tur.index])
        XCTAssertEqual(PlagueSystem.setCordon(&world, tur, turCapital, on: true), .noMoney)

        // Lifting is free and always allowed.
        XCTAssertNil(PlagueSystem.setQuarantine(&world, ven, capital, on: false))
        XCTAssertNil(PlagueSystem.setCordon(&world, ven, capital, on: false))
        XCTAssertEqual(world.calamity.taxFactor(capital.index), 1)
    }

    func testCampFeverStartsInSiegesAndArmiesCarrySickness() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 3)
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let host = try XCTUnwrap(world.military.armies(of: tur).first)
        let camp = world.military.armies.province[Int(host.rawValue)]
        let menBefore = world.military.armies.totalMen(of: host)
        XCTAssertGreaterThan(menBefore, 1_000)

        // A long siege breeds camp fever sooner or later.
        world.military.sieges.append(Siege(province: camp, besieger: tur, startDate: month(0)))
        var feverMonth: Int?
        for m in 1...240 {
            PlagueSystem.runMonthly(&world, date: month(m), random: &rng)
            if world.calamity.hasOutbreak(camp.index, .typhus) {
                feverMonth = m
                break
            }
        }
        let started = try XCTUnwrap(feverMonth, "no camp fever in 20 years of siege")

        // Soldiers standing in it die, and the army becomes a carrier.
        for m in 1...3 { PlagueSystem.runMonthly(&world, date: month(started + m), random: &rng) }
        XCTAssertLessThan(world.military.armies.totalMen(of: host), menBefore)
        XCTAssertTrue(world.military.armies.alive[Int(host.rawValue)])
        XCTAssertTrue(world.calamity.carrierArmy.contains(Int(host.rawValue)))
    }

    func testPlagueSaveLoadAndDeterminism() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 42)
        for t in greatTowns(sim.world, 4) {
            PlagueSystem.startOutbreak(&sim.world, in: t, disease: .plague, date: sim.date, severity: 1)
        }
        let ven = try XCTUnwrap(sim.world.countries.id(forTag: "VEN"))
        let capital = try XCTUnwrap(sim.world.countries.capital[ven.index])
        sim.world.countries.treasury[ven.index] += 200
        XCTAssertNil(PlagueSystem.setQuarantine(&sim.world, ven, capital, on: true))
        sim.advance(days: 40)

        let data = try SaveStorage.encodeArchive(sim, name: "plague_test", playerTag: "VEN")
        let restored = try SaveStorage.decodeArchive(from: data).simulation
        XCTAssertEqual(restored.world.calamity, sim.world.calamity)

        sim.advance(days: 35)
        restored.advance(days: 35)
        XCTAssertEqual(restored.world.calamity, sim.world.calamity)
        XCTAssertEqual(restored.world.pops.size, sim.world.pops.size)
        XCTAssertEqual(restored.world.countries.treasury, sim.world.countries.treasury)
    }
}
