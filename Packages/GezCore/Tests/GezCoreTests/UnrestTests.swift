import XCTest
@testable import GezCore

/// Phase 12 Part C: unrest and rebel factions.
final class UnrestTests: XCTestCase {
    private func month(_ n: Int) -> GameDate {
        GameDate(year: 1453 + (5 + n) / 12, month: (5 + n) % 12 + 1, day: 1)
    }

    private func points(_ world: World, _ p: ProvinceID, _ cause: UnrestCause) -> Double {
        UnrestSystem.causes(world, in: p, date: month(0)).first { $0.cause == cause }?.points ?? 0
    }

    private func totalPeople(_ world: World) -> Double { world.pops.size.reduce(0, +) }

    /// A country the test plays itself (so the AI does not answer the rebels),
    /// with every peasant taxed double and hungry.
    private func angryFrance() throws -> (World, CountryID) {
        var world = Scenario1453.makeWorld()
        let fra = try XCTUnwrap(world.countries.id(forTag: "FRA"))
        world.humanCountries.insert(fra)
        world.countries.taxLevel[fra.index] = Array(repeating: 2, count: TaxClass.allCases.count)
        for p in world.provinces(ownedBy: fra) { world.provinces.famine[p.index] = 0.6 }
        return (world, fra)
    }

    /// A risen faction placed by hand, one month from victory, standing
    /// where no royal army is.
    private func plantRisen(
        _ world: inout World, _ country: CountryID, _ kind: RebelKind, _ configure: (inout RebelFaction) -> Void
    ) throws -> RebelFaction {
        world.humanCountries.insert(country)
        world.unrest.resize(provinces: world.provinces.count, countries: world.countries.count)
        let capital = world.countries.capital[country.index]
        let spot = try XCTUnwrap(world.provinces(ownedBy: country).first {
            $0 != capital && world.military.armies(in: $0).isEmpty
        })
        let infantry = try XCTUnwrap(world.military.unit("infantry"))
        let army = world.military.armies.append(
            name: "Test rebels", owner: country, province: spot,
            regiments: [Regiment(type: infantry.id, origin: .levy, men: 1_000, morale: infantry.morale, homeProvince: spot)],
            isRebel: true)
        var f = RebelFaction(id: world.unrest.nextFactionID, country: country, kind: kind)
        world.unrest.nextFactionID += 1
        f.progress = 100
        f.risen = true
        f.armies = [Int(army.rawValue)]
        f.monthsInField = UnrestModel.monthsToWin - 1
        f.provinces = [spot]
        configure(&f)
        world.unrest.factions.append(f)
        return f
    }

    func testUnrestComesFromRealCauses() throws {
        var world = Scenario1453.makeWorld()
        let fra = try XCTUnwrap(world.countries.id(forTag: "FRA"))
        let paris = try XCTUnwrap(world.provinces.id(named: "Paris"))
        XCTAssertEqual(points(world, paris, .tax), 0, accuracy: 1e-9)
        XCTAssertEqual(points(world, paris, .famine), 0, accuracy: 1e-9)

        world.countries.taxLevel[fra.index][TaxClass.peasants.rawValue] = 2
        XCTAssertEqual(points(world, paris, .tax), 0.6 * UnrestModel.taxAbove, accuracy: 1e-9)
        world.countries.taxLevel[fra.index][TaxClass.peasants.rawValue] = 0
        XCTAssertLessThan(points(world, paris, .tax), 0, "low taxes calm people")

        world.provinces.famine[paris.index] = 1
        world.provinces.devastation[paris.index] = 1
        world.provinces.religiousUnrest[paris.index] = 50
        XCTAssertEqual(points(world, paris, .famine), UnrestModel.famine, accuracy: 1e-9)
        XCTAssertEqual(points(world, paris, .devastation), UnrestModel.devastation, accuracy: 1e-9)
        XCTAssertEqual(points(world, paris, .religion), 50 * UnrestModel.religionShare, accuracy: 1e-9)
        PlagueSystem.startOutbreak(&world, in: paris, disease: .plague, date: month(0), severity: 1)
        XCTAssertGreaterThan(points(world, paris, .plague), 0)

        // Foreign rule: a Greek town under the Ottomans; accepting the culture ends it.
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let thessaloniki = try XCTUnwrap(world.provinces.id(named: "Thessaloniki"))
        XCTAssertGreaterThan(points(world, thessaloniki, .culture), 3)
        world.countries.acceptedCultures[tur.index].insert(world.provinces.majorityCulture[thessaloniki.index])
        XCTAssertLessThan(points(world, thessaloniki, .culture), 3)

        // Soldiers on the spot calm a province; a shaky throne stirs the whole realm.
        let host = try XCTUnwrap(world.military.armies(of: tur).first)
        let camp = world.military.armies.province[Int(host.rawValue)]
        if world.provinces.owner[camp.index] == tur {
            XCTAssertLessThan(points(world, camp, .garrison), 0)
        }
        world.government.stability[fra.index] = 0
        let steady = points(world, paris, .succession)
        world.government.stability[fra.index] = -3
        XCTAssertEqual(points(world, paris, .succession) - steady, 3 * UnrestModel.instability, accuracy: 1e-9)
        world.government.stability[fra.index] = 2
        XCTAssertEqual(points(world, paris, .succession) - steady, -2 * UnrestModel.stabilityCalm, accuracy: 1e-9)
        world.government.stability[fra.index] = -3

        // The stored number follows the causes month by month, within 0…100.
        var rng = GameRandom(seed: 1)
        world.humanCountries.insert(fra)
        UnrestSystem.runMonthly(&world, date: month(1), random: &rng)
        let first = world.unrest.unrest(paris.index)
        UnrestSystem.runMonthly(&world, date: month(2), random: &rng)
        XCTAssertGreaterThan(first, 5)
        XCTAssertGreaterThan(world.unrest.unrest(paris.index), first)
        XCTAssertTrue(world.unrest.unrest.allSatisfy { $0 >= 0 && $0 <= 100 })
        XCTAssertGreaterThan(UnrestSystem.averageUnrest(world, of: fra), 0)
        XCTAssertEqual(rng.rawState, GameRandom(seed: 1).rawState, "unrest uses the calamities' random numbers")
    }

    func testPeasantsRiseFromTheirPopsAndCanBeCrushed() throws {
        var (world, fra) = try angryFrance()
        var rng = GameRandom(seed: 2)
        UnrestSystem.runMonthly(&world, date: month(0), random: &rng)
        let brewing = try XCTUnwrap(world.unrest.factions(of: fra).first { $0.kind == .peasants })
        XCTAssertGreaterThan(brewing.progress, 0)
        XCTAssertFalse(brewing.risen)
        XCTAssertFalse(brewing.provinces.isEmpty)
        XCTAssertGreaterThan(RebelSystem.expectedMen(world, brewing), UnrestModel.minRisingMen)
        XCTAssertFalse(RebelSystem.demand(world, brewing).isEmpty)
        XCTAssertFalse(RebelSystem.concession(world, brewing).isEmpty)

        // Rising: the men leave the pops and stand on the map as a rebel army.
        var peopleBefore = totalPeople(world)
        var risen: (id: Int, months: Int)?
        for m in 1...150 {
            peopleBefore = totalPeople(world)
            UnrestSystem.runMonthly(&world, date: month(m), random: &rng)
            if let f = world.unrest.factions(of: fra).first(where: { $0.kind == .peasants && $0.risen }) {
                risen = (f.id, m)
                break
            }
        }
        let rising = try XCTUnwrap(risen, "the peasants never rose")
        XCTAssertGreaterThan(rising.months, 12, "a rising takes years, not months")
        let f = try XCTUnwrap(world.unrest.faction(id: rising.id))
        let men = RebelSystem.men(world, f)
        XCTAssertGreaterThanOrEqual(men, UnrestModel.minRisingMen)
        XCTAssertLessThanOrEqual(men, UnrestModel.maxRisingMen)
        XCTAssertEqual(peopleBefore - totalPeople(world), Double(men), accuracy: 1)
        let army = try XCTUnwrap(f.armies.first)
        XCTAssertTrue(world.military.armies.alive[army] && world.military.armies.isRebel[army])
        XCTAssertEqual(world.military.armies.owner[army], fra)
        XCTAssertTrue(world.unrest.isFactionArmy(army))
        XCTAssertGreaterThanOrEqual(world.unrest.risings, 1) // other countries may have had theirs
        XCTAssertEqual(RebelSystem.monthsToVictory(f), UnrestModel.monthsToWin)
        let seat = world.military.armies.province[army]

        // A: a strong royal army arrives and crushes them; the survivors go home.
        var a = world
        let cavalry = try XCTUnwrap(a.military.unit("cavalry"))
        a.military.armies.append(
            name: "Royal host", owner: fra, province: seat,
            regiments: (0..<80).map { _ in Regiment(type: cavalry.id, origin: .professional, men: cavalry.maxMen, morale: cavalry.morale) })
        let beforeCrush = totalPeople(a)
        UnrestSystem.runMonthly(&a, date: month(rising.months + 1), random: &rng)
        XCTAssertNil(a.unrest.faction(id: rising.id), "crushed")
        XCTAssertFalse(a.military.armies.alive[army])
        XCTAssertGreaterThanOrEqual(a.unrest.rebelDefeats, world.unrest.rebelDefeats + 1)
        XCTAssertGreaterThan(totalPeople(a), beforeCrush, "survivors return to their villages")
        XCTAssertLessThan(totalPeople(a), beforeCrush + Double(men), "but not all of them")
        XCTAssertGreaterThan(a.unrest.quietMonths[fra.index], 0)
        XCTAssertGreaterThan(a.unrest.calm[seat.index], 0)

        // B: nobody comes. After a year in the field they win and force the taxes down.
        var b = world
        for aid in b.military.armies(of: fra) { b.military.armies.remove(aid) }
        let stability = b.government.stability[fra.index]
        for m in 1...UnrestModel.monthsToWin {
            XCTAssertNotNil(b.unrest.faction(id: rising.id))
            UnrestSystem.runMonthly(&b, date: month(rising.months + m), random: &rng)
        }
        XCTAssertNil(b.unrest.faction(id: rising.id), "they won and went home")
        XCTAssertGreaterThanOrEqual(b.unrest.rebelVictories, world.unrest.rebelVictories + 1)
        XCTAssertFalse(b.military.armies.alive[army])
        let peasantTax = TaxClass.peasants.rawValue
        XCTAssertEqual(b.countries.taxLevel[fra.index][peasantTax], UnrestModel.enforcedPeasantTax, accuracy: 1e-9)
        XCTAssertEqual(b.government.stability[fra.index], max(GovernmentModel.minStability, stability - 1))
        // The settlement holds: raising the tax again is undone next month.
        b.countries.taxLevel[fra.index][peasantTax] = 2
        UnrestSystem.runMonthly(&b, date: month(rising.months + 20), random: &rng)
        XCTAssertEqual(b.countries.taxLevel[fra.index][peasantTax], UnrestModel.enforcedPeasantTax, accuracy: 1e-9)
        XCTAssertGreaterThan(b.provinces.devastation[seat.index], 0, "the land they held suffered")
    }

    func testConcessionsTroopsAndLowerTaxes() throws {
        var (world, fra) = try angryFrance()
        var rng = GameRandom(seed: 3)
        for m in 0..<6 { UnrestSystem.runMonthly(&world, date: month(m), random: &rng) }
        let f = try XCTUnwrap(world.unrest.factions(of: fra).first { $0.kind == .peasants })
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        XCTAssertEqual(RebelSystem.concede(&world, tur, faction: f.id, date: month(6)), .noSuchFaction)
        XCTAssertEqual(RebelSystem.sendTroops(&world, fra, faction: 9_999), .noSuchFaction)

        // Lower taxes: a quarter of the normal rate at a time, down to nothing.
        let k = TaxClass.peasants.rawValue
        XCTAssertNil(RebelSystem.lowerTaxes(&world, fra))
        XCTAssertEqual(world.countries.taxLevel[fra.index][k], 1.75, accuracy: 1e-9)
        var poor = world
        poor.countries.taxLevel[fra.index][k] = 0
        XCTAssertEqual(RebelSystem.lowerTaxes(&poor, fra), .nothingToDo)

        // Troops: with no army there is nobody to send; with one next door it marches.
        var noArmy = world
        for aid in noArmy.military.armies(of: fra) { noArmy.military.armies.remove(aid) }
        XCTAssertEqual(RebelSystem.sendTroops(&noArmy, fra, faction: f.id), .noArmy)
        let target = try XCTUnwrap(f.provinces.first)
        if let next = world.provinces.neighbors[target.index].first(where: { world.provinces.owner[$0.index] == fra }) {
            var marching = noArmy
            let infantry = try XCTUnwrap(marching.military.unit("infantry"))
            let army = marching.military.armies.append(
                name: "Royal guard", owner: fra, province: next,
                regiments: [Regiment(type: infantry.id, origin: .professional, men: 1_000, morale: infantry.morale)])
            XCTAssertNil(RebelSystem.sendTroops(&marching, fra, faction: f.id))
            XCTAssertEqual(marching.military.armies.path[Int(army.rawValue)].last, target)
            XCTAssertEqual(RebelSystem.sendTroops(&marching, fra, faction: f.id), .nothingToDo, "already on its way")
        }

        // Concession: they disband for a smaller tax cut; prestige suffers, quiet follows.
        let prestige = world.countries.prestige[fra.index]
        XCTAssertNil(RebelSystem.concede(&world, fra, faction: f.id, date: month(6)))
        XCTAssertNil(world.unrest.faction(id: f.id))
        XCTAssertEqual(world.countries.taxLevel[fra.index][k], UnrestModel.concededPeasantTax, accuracy: 1e-9)
        XCTAssertEqual(world.unrest.peasantTaxCapMonths[fra.index], UnrestModel.concededTaxMonths)
        XCTAssertLessThan(world.countries.prestige[fra.index], prestige)
        XCTAssertEqual(world.unrest.quietMonths[fra.index], UnrestModel.quietMonthsAfterConcession)
        XCTAssertEqual(world.unrest.concessions, 1)
    }

    func testZealotsAndTheirSettlement() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 4)
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        world.humanCountries.insert(tur)
        var orthodox: [Int] = []
        for p in 0..<world.provinces.count where world.provinces.owner[p] == tur && world.provinces.religion[p] == .orthodox {
            world.provinces.religiousUnrest[p] = 80
            orthodox.append(p)
        }
        XCTAssertGreaterThan(orthodox.count, 3)
        for m in 0..<4 { UnrestSystem.runMonthly(&world, date: month(m), random: &rng) }
        let f = try XCTUnwrap(world.unrest.factions(of: tur).first { $0.kind == .zealots })
        XCTAssertEqual(f.religion, .orthodox)
        XCTAssertGreaterThan(f.progress, 0)
        XCTAssertTrue(RebelSystem.name(world, f).contains("Zealots"))
        XCTAssertTrue(f.provinces.allSatisfy { world.provinces.religion[$0.index] == .orthodox })

        // Giving way: their provinces calm down and no missionary stays among them.
        world.faith.missionaries.append(MissionaryAssignment(country: tur, province: ProvinceID(orthodox[0])))
        XCTAssertNil(RebelSystem.concede(&world, tur, faction: f.id, date: month(4)))
        XCTAssertEqual(world.provinces.religiousUnrest[orthodox[0]], 40, accuracy: 1e-9)
        XCTAssertFalse(world.faith.missionaries.contains { $0.province.index == orthodox[0] })
        XCTAssertNil(world.unrest.faction(id: f.id))
    }

    func testVictoriousRebelsEnforceTheirDemands() throws {
        var rng = GameRandom(seed: 5)
        let base = Scenario1453.makeWorld()
        let fra = try XCTUnwrap(base.countries.id(forTag: "FRA"))
        let tur = try XCTUnwrap(base.countries.id(forTag: "TUR"))

        // Estate rebels take a privilege.
        var nobles = base
        let estate = try XCTUnwrap(nobles.government.estates[fra.index].first { e in
            nobles.government.rules.privileges(of: e).contains { !nobles.government.privileges[fra.index].contains($0) }
        })
        let nf = try plantRisen(&nobles, fra, .nobles) { $0.estate = estate.index }
        let wanted = try XCTUnwrap(RebelSystem.wantedPrivilege(nobles, nf))
        let stability = nobles.government.stability[fra.index]
        UnrestSystem.runMonthly(&nobles, date: month(1), random: &rng)
        XCTAssertNil(nobles.unrest.faction(id: nf.id))
        XCTAssertTrue(nobles.government.privileges[fra.index].contains(wanted))
        XCTAssertEqual(nobles.government.stability[fra.index], max(GovernmentModel.minStability, stability - 1))
        XCTAssertFalse(nobles.military.armies.alive[nf.armies[0]])

        // A pretender takes the throne.
        var throne = base
        let ch = throne.people.characters
        let ruler = try XCTUnwrap(throne.countries.ruler[fra.index])
        let claimant = try XCTUnwrap(ch.ids.first {
            $0 != ruler && ch.isAlive($0) && !ch.female[$0.index] && ch.court[$0.index] == fra
                && ch.age($0, on: month(0)) >= CharacterSystem.adultAge
        })
        let pf = try plantRisen(&throne, fra, .pretender) { $0.pretender = claimant }
        XCTAssertTrue(RebelSystem.name(throne, pf).contains(ch.fullName(claimant)))
        UnrestSystem.runMonthly(&throne, date: month(1), random: &rng)
        XCTAssertEqual(throne.countries.ruler[fra.index], claimant)
        XCTAssertNil(throne.unrest.faction(id: pf.id))

        // Separatists: their provinces go to a country of their own, or their culture is accepted.
        var free = base
        let thessaloniki = try XCTUnwrap(free.provinces.id(named: "Thessaloniki"))
        let greek = free.provinces.majorityCulture[thessaloniki.index]
        let sf = try plantRisen(&free, tur, .separatists) { $0.culture = greek }
        let plan = RebelSystem.breakaway(free, sf)
        UnrestSystem.runMonthly(&free, date: month(1), random: &rng)
        XCTAssertNil(free.unrest.faction(id: sf.id))
        switch plan {
        case .country(let target, let provinces):
            XCTAssertNotEqual(target, tur)
            XCTAssertFalse(provinces.isEmpty)
            XCTAssertFalse(provinces.contains(free.countries.capital[tur.index]?.index ?? -1))
            for p in provinces {
                XCTAssertEqual(free.provinces.owner[p], target)
                XCTAssertTrue(free.provinces.cores[p].contains(target))
                XCTAssertEqual(base.provinces.majorityCulture[p], greek)
            }
            XCTAssertNotNil(free.countries.capital[target.index])
        case .acceptance:
            XCTAssertTrue(free.countries.acceptedCultures[tur.index].contains(greek))
        }

        // Zealots: a large enough faith takes the state; a small one wins toleration.
        var faith = base
        let zf = try plantRisen(&faith, tur, .zealots) { $0.religion = .orthodox }
        let share = RebelSystem.faithShare(faith, tur, .orthodox)
        let town = try XCTUnwrap((0..<faith.provinces.count).first {
            faith.provinces.owner[$0] == tur && faith.provinces.religion[$0] == .orthodox
        })
        faith.provinces.religiousUnrest[town] = 50
        UnrestSystem.runMonthly(&faith, date: month(1), random: &rng)
        XCTAssertNil(faith.unrest.faction(id: zf.id))
        if share >= UnrestModel.stateFaithShare {
            XCTAssertEqual(faith.countries.religion[tur.index], .orthodox)
        } else {
            XCTAssertEqual(faith.countries.religion[tur.index], base.countries.religion[tur.index])
            XCTAssertLessThan(faith.provinces.religiousUnrest[town], 50)
        }
        XCTAssertEqual(faith.unrest.rebelVictories, 1)
    }

    func testTheAIAnswersRebels() throws {
        var rng = GameRandom(seed: 6)
        var world = Scenario1453.makeWorld()
        let fra = try XCTUnwrap(world.countries.id(forTag: "FRA"))
        XCTAssertFalse(world.humanCountries.contains(fra))
        world.unrest.resize(provinces: world.provinces.count, countries: world.countries.count)
        let k = TaxClass.peasants.rawValue

        // Angry about taxes at 75%: the AI lowers the tax to normal first.
        world.countries.taxLevel[fra.index][k] = 2
        var f = RebelFaction(id: 500, country: fra, kind: .peasants)
        f.progress = 75
        world.unrest.factions.append(f)
        UnrestSystem.runMonthly(&world, date: month(1), random: &rng)
        XCTAssertEqual(world.countries.taxLevel[fra.index][k], 1, accuracy: 1e-9)
        XCTAssertNotNil(world.unrest.faction(id: 500))

        // At 90% with no army to speak of, it gives way before it comes to war.
        let at = try XCTUnwrap(world.unrest.factions.firstIndex { $0.id == 500 })
        world.unrest.factions[at].progress = 92
        for aid in world.military.armies(of: fra) { world.military.armies.remove(aid) }
        UnrestSystem.runMonthly(&world, date: month(2), random: &rng)
        XCTAssertNil(world.unrest.faction(id: 500))
        XCTAssertEqual(world.unrest.concessions, 1)
        XCTAssertLessThanOrEqual(world.countries.taxLevel[fra.index][k], UnrestModel.concededPeasantTax)
        XCTAssertEqual(world.unrest.risings, 0)
    }

    /// A peace that takes a realm's last province ends its rebel factions
    /// at once (review fix, Phase 13: peace can come on any day, and the
    /// monthly clean-up left a landless country's faction for up to a month).
    func testAnnexedCountryLosesItsRebelsAtOnce() throws {
        var world = Scenario1453.makeWorld()
        let tur = try XCTUnwrap(world.countries.id(forTag: "TUR"))
        let alb = try XCTUnwrap(world.countries.id(forTag: "ALB"))
        let war = try XCTUnwrap(world.diplomacy.activeWar(between: tur, and: alb))
        let albania = world.provinces(ownedBy: alb)
        XCTAssertFalse(albania.isEmpty)
        world.unrest.resize(provinces: world.provinces.count, countries: world.countries.count)
        var f = RebelFaction(id: 900, country: alb, kind: .peasants)
        f.progress = 40
        f.provinces = albania
        world.unrest.factions.append(f)
        world.unrest.factions.append(RebelFaction(id: 901, country: tur, kind: .peasants))

        for p in albania { world.provinces.occupiedBy[p.index] = tur }
        if let i = world.diplomacy.wars.firstIndex(where: { $0.id == war.id }) {
            world.diplomacy.wars[i].warScore = war.isAttacker(tur) ? 1.0 : -1.0
        }
        let offer = PeaceOffer(warID: war.id, winner: tur, loser: alb,
                               demands: albania.map { .cedeProvince(province: $0, to: tur) })
        if case .failure(let err) = world.executePeaceTreaty(offer, date: GameDate(year: 1453, month: 7, day: 14), forceAccept: true) {
            return XCTFail("Peace failed: \(err)")
        }
        XCTAssertTrue(world.provinces(ownedBy: alb).isEmpty)
        XCTAssertNil(world.unrest.faction(id: 900), "the annexed realm's rebels are gone")
        XCTAssertNotNil(world.unrest.faction(id: 901), "the winner's own factions stay")
    }

    func testUnrestSaveLoadAndDeterminism() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 31)
        let fra = try XCTUnwrap(sim.world.countries.id(forTag: "FRA"))
        sim.world.countries.taxLevel[fra.index] = Array(repeating: 2, count: TaxClass.allCases.count)
        _ = try plantRisen(&sim.world, fra, .peasants) { $0.monthsInField = 2 }
        sim.advance(days: 40)
        XCTAssertFalse(sim.world.unrest.unrest.isEmpty)

        let data = try SaveStorage.encodeArchive(sim, name: "unrest_test", playerTag: "FRA")
        let restored = try SaveStorage.decodeArchive(from: data).simulation
        XCTAssertEqual(restored.world.unrest, sim.world.unrest)

        sim.advance(days: 35)
        restored.advance(days: 35)
        XCTAssertEqual(restored.world.unrest, sim.world.unrest)
        XCTAssertEqual(restored.world.pops.size, sim.world.pops.size)
        XCTAssertEqual(restored.world.military.armies.alive, sim.world.military.armies.alive)
    }

    /// Two years of the whole game with plague, famine, earthquakes and
    /// unrest running: numbers stay sane, and the log shows how hard the
    /// world is hit (for balancing; the ten-year run prints the same line).
    func testTwoYearsOfCalamitiesStaySane() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let before = sim.world.provinces.population.reduce(0, +)
        sim.advance(days: 730)
        let w = sim.world
        XCTAssertTrue(w.unrest.unrest.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 100 })
        for f in w.unrest.factions {
            XCTAssertTrue(f.progress >= 0 && f.progress <= 100)
            XCTAssertTrue(w.provinces.owner.contains(f.country), "factions belong to countries with land")
        }
        XCTAssertEqual(w.unrest.risings, 0, "no faction can reach 100% in two years")
        let dead = w.calamity.totalDeaths.reduce(0, +) + w.calamity.totalFamineDeaths + w.calamity.totalQuakeDeaths
        XCTAssertTrue(dead.isFinite)
        XCTAssertLessThan(dead, before * 0.04, "calamities kill well under 4% of the world in two years")
        for p in 0..<w.provinces.count {
            XCTAssertTrue(w.provinces.population[p].isFinite && w.provinces.population[p] >= 0)
            XCTAssertTrue(w.provinces.famine[p] >= 0 && w.provinces.famine[p] <= 1)
            for d in Disease.allCases {
                let i = w.calamity.immunity(p, d)
                XCTAssertTrue(i >= 0 && i <= 1)
            }
        }
        print(CalamityReport.line(w, label: "two years"))
    }
}
