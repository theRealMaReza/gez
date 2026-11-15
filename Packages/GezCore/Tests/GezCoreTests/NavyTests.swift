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
        for _ in 0..<90 {
            s1.tick()
            s2.tick()
        }
        #expect(s1.world.navy.sailors == s2.world.navy.sailors)
        #expect(s1.world.navy.lastNavyUpkeep == s2.world.navy.lastNavyUpkeep)
        #expect(s1.world.navy.fleets.location == s2.world.navy.fleets.location)
        #expect(s1.world.navy.ships.hull == s2.world.navy.ships.hull)
        #expect(s1.world.navy.ships.crew == s2.world.navy.ships.crew)
    }
}
