import Testing
import Foundation
@testable import GezCore

@Suite("Navy (Part A)")
struct NavyTests {

    @Test("1453 fleets, admirals, inland seas, and regional ship types load cleanly")
    func test1453FleetLoading() throws {
        let w = try Scenario1453.loadBundled()

        #expect(w.navy.shipTypes.count == 16)
        for key in ["cog", "galley", "carrack", "light_ship", "venetian_great_galley", "ottoman_galley", "dhow", "ghurab"] {
            #expect(w.navy.shipByKey[key] != nil, "Missing ship type \(key)")
        }

        // Check major naval powers have starting fleets & historical ships.
        for tag in ["TUR", "VEN", "GEN", "ARA", "NAP", "POR", "CAS", "LUB", "BRE", "TEU", "RIG", "DAN", "SWE", "ENG", "FRA", "KNI", "MAM", "TUN", "MOR", "GUJ", "CLT", "HOR", "VIJ", "BNG"] {
            let cid = try #require(w.countries.id(forTag: tag), "Missing country \(tag)")
            #expect(w.navy.totalShips(of: cid) > 0, "\(tag) should start with ships")
            #expect(!w.navy.fleets(of: cid).isEmpty, "\(tag) should start with fleets")
        }

        // Historical admirals loaded on key 1453 fleets.
        let tur = try #require(w.countries.id(forTag: "TUR"))
        let ven = try #require(w.countries.id(forTag: "VEN"))
        let hamza = try #require(w.people.characters.id(forKey: "hamza_bey"))
        let loredan = try #require(w.people.characters.id(forKey: "loredan_alvise"))
        #expect(w.navy.fleets(of: tur).contains { w.navy.fleets.admiral[$0.index] == hamza })
        #expect(w.navy.fleets(of: ven).contains { w.navy.fleets.admiral[$0.index] == loredan })

        // Inland sea flags (Med, Black, Baltic, Red) vs Open Ocean.
        let aegean = try #require(w.seaZones.id(named: "Northern Aegean"))
        let blackSea = try #require(w.seaZones.id(named: "Western Black Sea"))
        let baltic = try #require(w.seaZones.id(named: "Baltic Sea"))
        let redSea = try #require(w.seaZones.id(named: "Central Red Sea"))
        let atlantic = try #require(w.seaZones.id(named: "Open Atlantic"))
        #expect(w.seaZones.isInland[aegean.index])
        #expect(w.seaZones.isInland[blackSea.index])
        #expect(w.seaZones.isInland[baltic.index])
        #expect(w.seaZones.isInland[redSea.index])
        #expect(!w.seaZones.isInland[atlantic.index])

        // Straits map cleanly to sea zones.
        let gibraltar = try #require(w.provinces.id(named: "Gibraltar"))
        let ceuta = try #require(w.provinces.id(named: "Ceuta"))
        #expect(w.isStrait(gibraltar, ceuta))
        #expect(!w.straitSeaZones(between: gibraltar, and: ceuta).isEmpty)
        let gallipoli = try #require(w.provinces.id(named: "Gallipoli"))
        let biga = try #require(w.provinces.id(named: "Biga"))
        #expect(w.isStrait(gallipoli, biga))
    }

    @Test("Regional ships unlock only for matching tags, cultures, or regions")
    func testRegionalShipUnlocks() throws {
        let w = try Scenario1453.loadBundled()
        let ven = try #require(w.countries.id(forTag: "VEN"))
        let tur = try #require(w.countries.id(forTag: "TUR"))
        let guj = try #require(w.countries.id(forTag: "GUJ"))
        let por = try #require(w.countries.id(forTag: "POR"))

        let venGalley = try #require(w.navy.shipByKey["venetian_great_galley"])
        let turGalley = try #require(w.navy.shipByKey["ottoman_galley"])
        let dhow = try #require(w.navy.shipByKey["dhow"])
        let ghurab = try #require(w.navy.shipByKey["ghurab"])
        let carrack = try #require(w.navy.shipByKey["carrack"])

        #expect(NavySystem.canBuildShip(w, ven, venGalley))
        #expect(!NavySystem.canBuildShip(w, tur, venGalley))
        #expect(NavySystem.canBuildShip(w, tur, turGalley))
        #expect(!NavySystem.canBuildShip(w, ven, turGalley))
        #expect(NavySystem.canBuildShip(w, guj, dhow))
        #expect(NavySystem.canBuildShip(w, guj, ghurab))
        #expect(!NavySystem.canBuildShip(w, por, dhow))
        #expect(NavySystem.canBuildShip(w, por, carrack))
    }

    @Test("Sailors derive from coastal peasant and burgher pops, 0 for landlocked realms")
    func testSailorsFromCoastalPops() throws {
        let w = try Scenario1453.loadBundled()
        let ven = try #require(w.countries.id(forTag: "VEN"))
        let boh = try #require(w.countries.id(forTag: "BOH"))
        let swi = try #require(w.countries.id(forTag: "SWI"))

        #expect(w.navy.maxSailors[ven.index] > 500)
        #expect(w.navy.sailors[ven.index] > 300)
        #expect(w.navy.maxSailors[boh.index] == 0)
        #expect(w.navy.maxSailors[swi.index] == 0)
    }

    @Test("Shipbuilding checks docks/coastal, deducts cost/sailors/goods, and completes on time")
    func testShipBuildingAndCompletion() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let tur = try #require(sim.world.countries.id(forTag: "TUR"))
        let venice = try #require(sim.world.provinces.id(named: "Venice"))
        let zadar = try #require(sim.world.provinces.id(named: "Zadar"))
        let ankara = try #require(sim.world.provinces.id(named: "Ankara"))
        let galleyId = try #require(sim.world.navy.shipByKey["galley"])
        let carrackId = try #require(sim.world.navy.shipByKey["carrack"])

        // Landlocked (even by an inland lake like Ankara) / wrong owner / no docks refusals.
        #expect(NavySystem.buildShipRefusal(sim.world, tur, in: ankara, type: galleyId) == .notCoastal)
        #expect(NavySystem.buildShipRefusal(sim.world, ven, in: zadar, type: galleyId) == .noDocks)
        #expect(NavySystem.buildShipRefusal(sim.world, tur, in: venice, type: galleyId) == .notOwner)

        // Ensure Venice has plenty of treasury for test.
        sim.world.countries.treasury[ven.index] = 1_000.0
        let initialTreasury = sim.world.countries.treasury[ven.index]
        let initialSailors = sim.world.navy.sailors[ven.index]
        let shipTableBefore = sim.world.navy.ships.count
        let wood = try #require(sim.world.economy.goods.id(forKey: "wood"))
        let navalSupplies = try #require(sim.world.economy.goods.id(forKey: "naval_supplies"))
        let cannons = try #require(sim.world.economy.goods.id(forKey: "cannons"))
        let market = try #require(sim.world.market(of: venice))
        let beforeWoodDemand = sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, wood)]
        let beforeNavalDemand = sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, navalSupplies)]
        let beforeCannonsDemand = sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, cannons)]

        let res = NavySystem.startShipConstruction(&sim.world, ven, in: venice, type: carrackId)
        guard case .success(let job) = res else {
            Issue.record("Expected carrack construction in Venice to succeed, got \(res)")
            return
        }
        #expect(job.monthsTotal == 12)
        #expect(sim.world.countries.treasury[ven.index] < initialTreasury)
        #expect(sim.world.navy.sailors[ven.index] == initialSailors - Double(sim.world.navy.shipType(carrackId).maxCrew))
        #expect(sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, wood)] > beforeWoodDemand)
        #expect(sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, navalSupplies)] > beforeNavalDemand)
        #expect(sim.world.economy.markets.pendingDemand[sim.world.economy.markets.slot(market, cannons)] > beforeCannonsDemand)

        // Advance simulation across 12 monthly ticks (first-of-month launches completed ship).
        for _ in 0..<370 {
            sim.tick()
        }
        // The whole world runs for that year, so Venice may also lose ships
        // at sea or in battle (it did after the 20.7 Mongolia data, #48): check
        // that the carrack itself was launched, not Venice's fleet total.
        #expect(!sim.world.navy.constructions.contains { $0.country == ven && $0.province == venice && $0.shipType == carrackId })
        let launched = (shipTableBefore..<sim.world.navy.ships.count).contains { i in
            sim.world.navy.ships.type[i] == carrackId && sim.world.navy.ships.originProvince[i] == venice
        }
        #expect(launched)
    }

    @Test("Save/load roundtrip preserves ships, fleets, constructions, and sailors")
    func testSaveLoadRoundtrip() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let venice = try #require(sim.world.provinces.id(named: "Venice"))
        let galleyId = try #require(sim.world.navy.shipByKey["galley"])
        sim.world.countries.treasury[ven.index] = 500
        _ = NavySystem.startShipConstruction(&sim.world, ven, in: venice, type: galleyId)

        let data = try SaveStorage.encodeArchive(sim, name: "navy_test", playerTag: "VEN")
        let restored = try SaveStorage.decodeArchive(from: data).simulation

        #expect(restored.world.navy.fleets.count == sim.world.navy.fleets.count)
        #expect(restored.world.navy.ships.count == sim.world.navy.ships.count)
        #expect(restored.world.navy.constructions == sim.world.navy.constructions)
        #expect(restored.world.navy.sailors[ven.index] == sim.world.navy.sailors[ven.index])
    }

    @Test("Two runs from 1453 produce bit-identical naval state")
    func testDeterminism() {
        let s1 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let s2 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        for _ in 0..<120 {
            s1.tick()
            s2.tick()
        }
        #expect(s1.world.navy.sailors == s2.world.navy.sailors)
        #expect(s1.world.navy.lastNavyUpkeep == s2.world.navy.lastNavyUpkeep)
        #expect(s1.world.navy.lastAttritionLosses == s2.world.navy.lastAttritionLosses)
        #expect(s1.world.navy.fleets.location == s2.world.navy.fleets.location)
        #expect(s1.world.navy.fleets.supply == s2.world.navy.fleets.supply)
        #expect(s1.world.navy.ships.hull == s2.world.navy.ships.hull)
        #expect(s1.world.navy.ships.crew == s2.world.navy.ships.crew)
    }
}

@Suite("Navy (Part B)")
struct NavyMovementAndAITests {

    @Test("Fleets move zone to zone daily, dock in friendly ports, and speed scales with admiral Martial and inland galleys")
    func testMovementAndAdmiralSpeed() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let venFleet = try #require(sim.world.navy.fleets(of: ven).first)
        let aegeanS = try #require(sim.world.seaZones.id(named: "Southern Aegean"))
        let ionian = try #require(sim.world.seaZones.id(named: "Ionian Sea"))
        let northAdriatic = try #require(sim.world.seaZones.id(named: "Northern Adriatic"))

        // Speed bonus: compare seaStepDays with Martial 12 vs Martial 1 admiral.
        let loredan = try #require(sim.world.navy.fleets.admiral[venFleet.index])
        sim.world.people.characters.skills[loredan.index][Skill.martial.rawValue] = 12
        let fastDays = NavySystem.seaStepDays(sim.world, from: northAdriatic, to: ionian, fleet: venFleet)
        sim.world.people.characters.skills[loredan.index][Skill.martial.rawValue] = 1
        let slowDays = NavySystem.seaStepDays(sim.world, from: northAdriatic, to: ionian, fleet: venFleet)
        #expect(fastDays < slowDays)

        // Pure galley fleet gets inland-sea speed bonus in Ionian Sea vs Open Atlantic.
        let galleyType = try #require(sim.world.navy.shipByKey["galley"])
        let galleyFleet = sim.world.navy.fleets.append(name: "Galley Squadron", owner: ven, location: .sea(ionian))
        let gIdx = sim.world.navy.ships.add(type: galleyType, fleet: galleyFleet, crew: 150)
        sim.world.navy.fleets.shipIndices[galleyFleet.index].append(gIdx)
        let openAtlantic = try #require(sim.world.seaZones.id(named: "Open Atlantic"))
        #expect(NavySystem.fleetSpeed(sim.world, galleyFleet, in: ionian) > NavySystem.fleetSpeed(sim.world, galleyFleet, in: openAtlantic))

        // Sail venFleet from Venice port into Southern Aegean then dock at Negroponte.
        sim.world.humanCountries.insert(ven)
        #expect(NavySystem.orderMoveFleet(&sim.world, venFleet, toSea: aegeanS))
        for _ in 0..<25 { sim.tick() }
        #expect(sim.world.navy.fleets.location[venFleet.index] == .sea(aegeanS))

        let negroponte = try #require(sim.world.provinces.id(named: "Negroponte"))
        #expect(NavySystem.orderDockFleet(&sim.world, venFleet, inPort: negroponte))
        for _ in 0..<10 { sim.tick() }
        #expect(sim.world.navy.fleets.location[venFleet.index] == .port(negroponte))
    }

    @Test("Split and merge organize ships cleanly within the same location")
    func testSplitAndMerge() throws {
        var w = try Scenario1453.loadBundled()
        let ven = try #require(w.countries.id(forTag: "VEN"))
        let venFleet = try #require(w.navy.fleets(of: ven).first)
        let initialCount = w.navy.shipCount(of: venFleet)
        #expect(initialCount >= 4)

        let det = try #require(NavySystem.splitFleet(&w, fleet: venFleet))
        #expect(w.navy.shipCount(of: venFleet) + w.navy.shipCount(of: det) == initialCount)
        #expect(w.navy.fleets.location[venFleet.index] == w.navy.fleets.location[det.index])

        let merged = NavySystem.mergeFleetsInLocation(&w, into: venFleet)
        #expect(merged >= 1)
        #expect(w.navy.shipCount(of: venFleet) == initialCount)
        #expect(!w.navy.fleets.alive[det.index])
    }

    @Test("Sea attrition damages unsupplied ships while friendly ports repair hull and resupply")
    func testAttritionAndPortRepair() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        sim.world.humanCountries.insert(ven)
        let fleet = try #require(sim.world.navy.fleets(of: ven).first)
        let openAtlantic = try #require(sim.world.seaZones.id(named: "Open Atlantic"))

        // Place fleet out of supply range in Open Atlantic with low supply.
        sim.world.navy.fleets.location[fleet.index] = .sea(openAtlantic)
        sim.world.navy.fleets.supply[fleet.index] = 15.0
        for _ in 0..<25 { sim.tick() }

        #expect(sim.world.navy.fleets.supply[fleet.index] == 0)
        #expect(NavySystem.fleetAverageHull(sim.world, fleet) < 100.0)
        #expect(sim.world.navy.lastAttritionLosses[ven.index] > 0)

        // Return to friendly Venice port and run through 2 monthly ticks -> supply 100 and hull repairs.
        let hullDamaged = NavySystem.fleetAverageHull(sim.world, fleet)
        let venice = try #require(sim.world.provinces.id(named: "Venice"))
        sim.world.navy.fleets.location[fleet.index] = .port(venice)
        sim.world.navy.fleets.path[fleet.index].removeAll()
        for _ in 0..<65 { sim.tick() }

        #expect(sim.world.navy.fleets.supply[fleet.index] == 100.0)
        #expect(NavySystem.fleetAverageHull(sim.world, fleet) > hullDamaged)
    }

    @Test("Fleet AI at war sends stronger fleets to hunt enemy fleets and blockade enemy ports")
    func testFleetAIWarBehavior() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let pap = try #require(sim.world.countries.id(forTag: "PAP"))
        let adriaticN = try #require(sim.world.seaZones.id(named: "Northern Adriatic"))

        // Remove starting ships from PAP and give PAP a tiny 1-cog fleet in Northern Adriatic so VEN clearly overmatches it.
        for f in sim.world.navy.fleets(of: pap) { sim.world.navy.fleets.alive[f.index] = false }
        let ancona = try #require(sim.world.provinces.id(named: "Ancona"))
        let cog = try #require(sim.world.navy.shipByKey["cog"])
        let papWeakFleet = NavySystem.launchShip(&sim.world, country: pap, in: ancona, type: cog)
        sim.world.navy.fleets.location[papWeakFleet.index] = .sea(adriaticN)
        sim.world.humanCountries.insert(pap) // prevent PAP AI from fleeing instantly

        // Declare war VEN -> PAP cleanly.
        let war = War(
            id: "test_ven_pap",
            name: "Venetian-Papal War",
            startDate: sim.date,
            casusBelli: .claim,
            warGoal: .conquerProvince(ancona),
            attackers: [ven],
            defenders: [pap]
        )
        sim.world.diplomacy.wars.append(war)

        // Advance past next first-of-month so NavySystem.runAI runs.
        for _ in 0..<35 { sim.tick() }
        let venMainFleet = try #require(sim.world.navy.fleets(of: ven).first)
        let mission = sim.world.navy.fleets.mission[venMainFleet.index]
        #expect(mission == .hunt || mission == .blockade)
        let venicePort = try #require(sim.world.provinces.id(named: "Venice"))
        #expect(sim.world.navy.fleets.location[venMainFleet.index] != .port(venicePort))
    }
}

@Suite("Navy (Part C)")
struct NavyBattleAndBlockadeTests {

    private func makeFleet(
        _ world: inout World,
        name: String,
        owner: CountryID,
        sea: SeaZoneID,
        ships: [(ShipTypeID, Int)],
        admiral: CharacterID? = nil
    ) -> FleetID {
        let fid = world.navy.fleets.append(name: name, owner: owner, location: .sea(sea), admiral: admiral)
        for (tid, count) in ships {
            let st = world.navy.shipType(tid)
            for _ in 0..<count {
                let sIdx = world.navy.ships.add(type: tid, fleet: fid, hull: 100.0, crew: st.maxCrew, morale: 3.0)
                world.navy.fleets.shipIndices[fid.index].append(sIdx)
            }
        }
        return fid
    }

    @Test("Stronger fleet wins multi-day naval battle, captures ships, retreats loser, and grants war score")
    func testStrongerFleetWinsAndCapturesAndGrantsWarScore() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 42)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let tur = try #require(sim.world.countries.id(forTag: "TUR"))
        let aegeanS = try #require(sim.world.seaZones.id(named: "Southern Aegean"))
        sim.world.humanCountries.insert(ven)
        sim.world.humanCountries.insert(tur)

        // Isolate test clash in Southern Aegean with clear size advantage + high Martial admiral for VEN.
        for f in sim.world.navy.fleets(of: ven) { sim.world.navy.fleets.alive[f.index] = false }
        for f in sim.world.navy.fleets(of: tur) { sim.world.navy.fleets.alive[f.index] = false }

        let war = War(
            id: "ven_tur_naval",
            name: "Aegean War",
            startDate: sim.date,
            casusBelli: .claim,
            warGoal: .superiority,
            attackers: [ven],
            defenders: [tur]
        )
        sim.world.diplomacy.wars.append(war)

        let carrack = try #require(sim.world.navy.shipByKey["carrack"])
        let galley = try #require(sim.world.navy.shipByKey["galley"])
        let cog = try #require(sim.world.navy.shipByKey["cog"])

        let loredan = try #require(sim.world.people.characters.id(forKey: "loredan_alvise"))
        sim.world.people.characters.skills[loredan.index][Skill.martial.rawValue] = 10

        let venFleet = makeFleet(&sim.world, name: "Grand Armada", owner: ven, sea: aegeanS,
                                 ships: [(carrack, 6), (galley, 8)], admiral: loredan)
        let turFleet = makeFleet(&sim.world, name: "Turkish Flotilla", owner: tur, sea: aegeanS,
                                 ships: [(galley, 4), (cog, 4)])

        // Battle should start on day 1 and finish within <= 15 days.
        for _ in 0..<18 {
            sim.tick()
            if !sim.world.navy.recentBattles.isEmpty { break }
        }

        let report = try #require(sim.world.navy.recentBattles.last)
        #expect(report.winnerCountry == ven)
        #expect(report.days >= 2)
        #expect(report.warScoreDelta > 0)
        #expect(sim.world.navy.fleets.location[venFleet.index] == .sea(aegeanS))
        if sim.world.navy.fleets.alive[turFleet.index] {
            // Defeated surviving fleet retreated away from Southern Aegean toward port.
            #expect(sim.world.navy.fleets.location[turFleet.index] != .sea(aegeanS) ||
                    sim.world.navy.fleets.destinationPort[turFleet.index] != nil)
        }
        let updatedWar = try #require(sim.world.diplomacy.activeWar(between: ven, and: tur))
        #expect(updatedWar.battleWarScore > 0)

        // Verify ship capture mechanics trigger across battered boarding engagements.
        var totalCaptured = report.attackerShipsCaptured + report.defenderShipsCaptured
        if totalCaptured == 0 {
            for trial in 1...12 {
                let s = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: UInt64(trial * 77))
                s.world.humanCountries.insert(ven)
                s.world.humanCountries.insert(tur)
                for f in s.world.navy.fleets(of: ven) { s.world.navy.fleets.alive[f.index] = false }
                for f in s.world.navy.fleets(of: tur) { s.world.navy.fleets.alive[f.index] = false }
                s.world.diplomacy.wars.append(war)
                _ = makeFleet(&s.world, name: "CapV", owner: ven, sea: aegeanS, ships: [(carrack, 5), (galley, 10)], admiral: loredan)
                _ = makeFleet(&s.world, name: "CapT", owner: tur, sea: aegeanS, ships: [(cog, 12)])
                for _ in 0..<16 {
                    s.tick()
                    if let r = s.world.navy.recentBattles.last {
                        totalCaptured += r.attackerShipsCaptured + r.defenderShipsCaptured
                        break
                    }
                }
                if totalCaptured > 0 { break }
            }
        }
        #expect(totalCaptured > 0)
    }

    @Test("Galleys perform stronger in inland seas than in open oceans")
    func testGalleyInlandSeaCombatBonus() throws {
        let baseWorld = Scenario1453.makeWorld()
        let aegean = try #require(baseWorld.seaZones.id(named: "Northern Aegean"))
        let atlantic = try #require(baseWorld.seaZones.id(named: "Open Atlantic"))

        func runClash(in zone: SeaZoneID, seed: UInt64) throws -> Int {
            let sim = Simulation(world: baseWorld, startDate: Scenario1453.startDate, seed: seed)
            let ven = try #require(sim.world.countries.id(forTag: "VEN"))
            let gen = try #require(sim.world.countries.id(forTag: "GEN"))
            sim.world.humanCountries.insert(ven)
            sim.world.humanCountries.insert(gen)
            for f in sim.world.navy.fleets(of: ven) { sim.world.navy.fleets.alive[f.index] = false }
            for f in sim.world.navy.fleets(of: gen) { sim.world.navy.fleets.alive[f.index] = false }
            sim.world.diplomacy.wars.append(War(
                id: "galley_test", name: "Galley Clash", startDate: sim.date,
                casusBelli: .claim, warGoal: .superiority, attackers: [ven], defenders: [gen]
            ))
            let galley = try #require(sim.world.navy.shipByKey["galley"])
            let light = try #require(sim.world.navy.shipByKey["light_ship"])
            _ = makeFleet(&sim.world, name: "VenG", owner: ven, sea: zone, ships: [(galley, 8)])
            _ = makeFleet(&sim.world, name: "GenL", owner: gen, sea: zone, ships: [(light, 8)])
            for _ in 0..<18 {
                sim.tick()
                if let r = sim.world.navy.recentBattles.last(where: {
                    $0.attackerCountry == ven || $0.defenderCountry == ven
                }) {
                    return r.defenderShipsLost - r.attackerShipsLost
                }
            }
            return 0
        }

        let seeds: [UInt64] = Array(1...15)
        let inlandNet = try seeds.reduce(0) { try $0 + runClash(in: aegean, seed: $1) }
        let oceanNet = try seeds.reduce(0) { try $0 + runClash(in: atlantic, seed: $1) }
        #expect(inlandNet > oceanNet)
    }

    @Test("Blockade removes coastal siege penalty, cuts sea trade capacity, and ticks blockade war score")
    func testBlockadeEffects() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let pap = try #require(sim.world.countries.id(forTag: "PAP"))
        let ancona = try #require(sim.world.provinces.id(named: "Ancona"))
        let adriaticS = try #require(sim.world.provinceSeas[ancona.index].first)
        sim.world.humanCountries.insert(ven)
        sim.world.humanCountries.insert(pap)

        sim.world.diplomacy.wars.append(War(
            id: "blockade_war", name: "Ancona War", startDate: sim.date,
            casusBelli: .claim, warGoal: .conquerProvince(ancona), attackers: [ven], defenders: [pap]
        ))

        // Put PAP fort in Ancona and besiege it with VEN army while PAP ships are cleared.
        sim.world.provinces.fortLevel[ancona.index] = 1
        sim.world.provinces.fortGarrison[ancona.index] = 1000
        let inf = try #require(sim.world.military.unitByKey["infantry"])
        _ = ArmySystem.recruitProfessional(&sim.world, ven, in: ancona, unit: inf)
        // Hack army owner standing directly in ancona as besieging army
        let armyId = sim.world.military.armies.append(
            name: "Siege Force", owner: ven, province: ancona,
            regiments: [Regiment(type: inf, origin: .professional, men: 3000, morale: 3.0)]
        )
        #expect(sim.world.military.armies.alive[Int(armyId.rawValue)])

        // Day 1 without fleet blockade: siege exists and `blockaded == false` (takes -2 coastal penalty).
        sim.tick()
        let unblockedSiege = try #require(sim.world.military.siege(in: ancona))
        #expect(!unblockedSiege.blockaded)
        let capBefore = TradeSystem.linkCapacities(sim.world)

        // Move VEN fleet into sea zone touching Ancona and Naples/Adriatic market centres -> blockades Ancona & Venice/Rome sea links.
        let venMarketProv = try #require(sim.world.provinces.id(named: "Venice"))
        _ = venMarketProv
        let carrack = try #require(sim.world.navy.shipByKey["carrack"])
        let bFleet = makeFleet(&sim.world, name: "Blockaders", owner: ven, sea: adriaticS, ships: [(carrack, 4)])
        #expect(sim.world.navy.fleets.alive[bFleet.index])

        for _ in 0..<20 { sim.tick() }
        let blockedSiege = try #require(sim.world.military.siege(in: ancona))
        #expect(blockedSiege.blockaded)
        #expect(sim.world.navy.blockadedProvinces.contains(ancona))

        let capAfter = TradeSystem.linkCapacities(sim.world)
        let seaIndices = sim.world.economy.marketLinkIsSea.indices.filter { sim.world.economy.marketLinkIsSea[$0] }
        #expect(seaIndices.contains { capAfter[$0] < capBefore[$0] })

        let warAfter = try #require(sim.world.diplomacy.activeWar(between: ven, and: pap))
        #expect(warAfter.blockadeWarScore > 0)
    }

    @Test("Hostile fleet blocks strait crossing unless marching side controls both shores")
    func testStraitBlocking() throws {
        var world = try Scenario1453.loadBundled()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let gra = try #require(world.countries.id(forTag: "GRA"))
        let por = try #require(world.countries.id(forTag: "POR"))
        let gibraltar = try #require(world.provinces.id(named: "Gibraltar"))
        let ceuta = try #require(world.provinces.id(named: "Ceuta"))
        let alboran = try #require(world.straitSeaZones(between: gibraltar, and: ceuta).first)

        // CAS war with POR & GRA: GRA controls Gibraltar, POR controls Ceuta. CAS has hostile POR fleet in Alboran Sea.
        world.diplomacy.wars.append(War(
            id: "strait_war", name: "Strait Test", startDate: Scenario1453.startDate,
            casusBelli: .claim, warGoal: .superiority, attackers: [cas], defenders: [por, gra]
        ))
        let inf = try #require(world.military.unitByKey["infantry"])
        let army = world.military.armies.append(
            name: "Crossers", owner: cas, province: gibraltar,
            regiments: [Regiment(type: inf, origin: .professional, men: 2000, morale: 3.0)]
        )
        let carrack = try #require(world.navy.shipByKey["carrack"])
        _ = makeFleet(&world, name: "Strait Blockade", owner: por, sea: alboran, ships: [(carrack, 3)])

        // Neither shore controlled by CAS -> hostile fleet blocks path across Gibraltar-Ceuta.
        #expect(!ArmySystem.canCrossStrait(world, from: gibraltar, to: ceuta, for: cas))
        #expect(ArmySystem.findPath(world, from: gibraltar, to: ceuta, army: army).isEmpty)

        // If CAS controls both shores (Gibraltar and Ceuta), army MAY cross despite hostile fleet!
        world.provinces.occupiedBy[gibraltar.index] = cas
        world.provinces.occupiedBy[ceuta.index] = cas
        #expect(ArmySystem.canCrossStrait(world, from: gibraltar, to: ceuta, for: cas))
        #expect(ArmySystem.findPath(world, from: gibraltar, to: ceuta, army: army) == [ceuta])
    }
}

@Suite("Navy (Part D - Transport & Amphibious)")
struct NavyTransportTests {

    @Test("Armies board Cogs in port (1 ship per 1,000 men), sail, and fight with amphibious penalty on hostile landing")
    func testEmbarkSailAndAmphibiousLandingPenalty() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 4242)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let pap = try #require(sim.world.countries.id(forTag: "PAP"))
        let venice = try #require(sim.world.provinces.id(named: "Venice"))
        let ancona = try #require(sim.world.provinces.id(named: "Ancona"))
        sim.world.humanCountries.insert(ven)
        sim.world.humanCountries.insert(pap)

        sim.world.diplomacy.wars.append(War(
            id: "adriatic_landing", name: "Adriatic War", startDate: sim.date,
            casusBelli: .claim, warGoal: .conquerProvince(ancona), attackers: [ven], defenders: [pap]
        ))

        let inf = try #require(sim.world.military.unitByKey["infantry"])
        let bigArmy = sim.world.military.armies.append(
            name: "First Host", owner: ven, province: venice,
            regiments: [
                Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0),
                Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0),
                Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0),
            ]
        )
        let defArmy = sim.world.military.armies.append(
            name: "Ancona Guard", owner: pap, province: ancona,
            regiments: [Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0)]
        )
        _ = defArmy

        let cog = try #require(sim.world.navy.shipByKey["cog"])
        let fleet = sim.world.navy.fleets.append(name: "Transports", owner: ven, location: .port(venice))
        for _ in 0..<2 {
            let s = sim.world.navy.ships.add(type: cog, fleet: fleet, crew: 80)
            sim.world.navy.fleets.shipIndices[fleet.index].append(s)
        }

        // 3,000 men need 3 cogs; 2 cogs must refuse embarkation.
        #expect(!NavySystem.canEmbark(sim.world, army: bigArmy, onto: fleet))
        #expect(!NavySystem.embarkArmy(&sim.world, army: bigArmy, onto: fleet))

        // Add 3rd cog -> embark succeeds; embarked army cannot land-march directly.
        let s3 = sim.world.navy.ships.add(type: cog, fleet: fleet, crew: 80)
        sim.world.navy.fleets.shipIndices[fleet.index].append(s3)
        #expect(NavySystem.embarkArmy(&sim.world, army: bigArmy, onto: fleet))
        #expect(sim.world.military.armies.embarkedOnFleet[Int(bigArmy.rawValue)] == fleet)
        #expect(!ArmySystem.orderMove(&sim.world, army: bigArmy, to: ancona))

        // Sail across Adriatic and land in Ancona -> triggers battle with isAmphibiousLanding == true (-2 penalty).
        #expect(NavySystem.orderTransportAndLand(&sim.world, fleet: fleet, to: ancona))
        var sawAmphibiousBattle = false
        for _ in 0..<20 {
            sim.tick()
            if sim.world.military.battles.contains(where: { $0.province == ancona && $0.isAmphibiousLanding }) {
                sawAmphibiousBattle = true
                break
            }
        }
        #expect(sawAmphibiousBattle)
        #expect(sim.world.military.armies.embarkedOnFleet[Int(bigArmy.rawValue)] == nil)
        #expect(sim.world.military.armies.province[Int(bigArmy.rawValue)] == ancona)
    }

    @Test("AI uses transport ships to cross sea and invade overseas coastal target")
    func testAINavalTransportCrossing() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 888)
        let ven = try #require(sim.world.countries.id(forTag: "VEN"))
        let pap = try #require(sim.world.countries.id(forTag: "PAP"))
        // Keep VEN as AI (remove from humanCountries), landlock separation across Crete (Candia) -> Ragusa / Ancona.
        let candia = try #require(sim.world.provinces.id(named: "Candia"))
        let ancona = try #require(sim.world.provinces.id(named: "Ancona"))
        // Give PAP only Ancona coastal army target? Keep war VEN vs KNI on Rhodes (island vs island, guaranteed overseas)!
        let kni = try #require(sim.world.countries.id(forTag: "KNI"))
        let rhodes = try #require(sim.world.provinces.id(named: "Rhodes"))
        _ = pap
        _ = ancona

        // Clear VEN mainland armies so VEN only has an island army in Candia + cogs in Candia port.
        for a in sim.world.military.armies(of: ven) { sim.world.military.armies.remove(a) }
        for f in sim.world.navy.fleets(of: ven) { sim.world.navy.fleets.alive[f.index] = false }
        for f in sim.world.navy.fleets(of: kni) { sim.world.navy.fleets.alive[f.index] = false }
        for a in sim.world.military.armies(of: kni) { sim.world.military.armies.remove(a) }

        let inf = try #require(sim.world.military.unitByKey["infantry"])
        let candiaArmy = sim.world.military.armies.append(
            name: "Candia Garrison", owner: ven, province: candia,
            regiments: [
                Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0),
                Regiment(type: inf, origin: .professional, men: 1000, morale: 3.0),
            ]
        )
        let cog = try #require(sim.world.navy.shipByKey["cog"])
        let fleet = sim.world.navy.fleets.append(name: "Crete Squadron", owner: ven, location: .port(candia))
        for _ in 0..<4 {
            let s = sim.world.navy.ships.add(type: cog, fleet: fleet, crew: 80)
            sim.world.navy.fleets.shipIndices[fleet.index].append(s)
        }

        sim.world.diplomacy.wars.append(War(
            id: "ai_amphib", name: "Rhodes Expedition", startDate: sim.date,
            casusBelli: .claim, warGoal: .conquerProvince(rhodes), attackers: [ven], defenders: [kni]
        ))

        var landedOnRhodes = false
        for _ in 0..<45 {
            sim.tick()
            if sim.world.military.armies.province[Int(candiaArmy.rawValue)] == rhodes
                && sim.world.military.armies.embarkedOnFleet[Int(candiaArmy.rawValue)] == nil {
                landedOnRhodes = true
                break
            }
        }
        #expect(landedOnRhodes)
    }

    /// Nobody commands an army and a fleet at the same time (review fix).
    @Test("No character leads both an army and a fleet")
    func noCharacterLeadsBothAnArmyAndAFleet() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        for _ in 0..<62 { sim.tick() }
        let w = sim.world
        var admirals = Set<CharacterID>()
        for f in 0..<w.navy.fleets.count where w.navy.fleets.alive[f] {
            if let a = w.navy.fleets.admiral[f] { admirals.insert(a) }
        }
        for a in 0..<w.military.armies.count where w.military.armies.alive[a] {
            if let cmd = w.military.armies.commander[a] {
                #expect(!admirals.contains(cmd), "\(w.people.characters.name[cmd.index]) leads an army and a fleet")
            }
        }
    }

    /// The once-a-day dock table gives the same answers as asking
    /// canDockAtController pair by pair (review speed-up).
    @Test("Dock permission table matches canDockAtController")
    func dockFriendsMatchesPairwiseCheck() {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        for _ in 0..<120 { sim.tick() }
        let w = sim.world
        let friends = NavySystem.dockFriends(w)
        for o in 0..<w.countries.count {
            for c in 0..<w.countries.count {
                let slow = NavySystem.canDockAtController(w, CountryID(o), controller: CountryID(c))
                let fast = o == c || friends[o].contains(c)
                #expect(slow == fast, "dock \(o) at \(c)")
            }
        }
    }
}
