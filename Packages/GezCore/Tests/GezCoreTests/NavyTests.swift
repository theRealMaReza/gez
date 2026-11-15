import Testing
import Foundation
@testable import GezCore

@Suite("Navy (Part A)")
struct NavyTests {

    @Test("1453 fleets, admirals, inland seas, and regional ship types load cleanly")
    func test1453FleetLoading() throws {
        let w = try Scenario1453.loadBundled()

        #expect(w.navy.shipTypes.count == 8)
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
        let initialShips = sim.world.navy.totalShips(of: ven)
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
        #expect(sim.world.navy.totalShips(of: ven) == initialShips + 1)
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
        #expect(sim.world.navy.fleets.location[venMainFleet.index] != .port(try #require(sim.world.provinces.id(named: "Venice"))))
    }
}
