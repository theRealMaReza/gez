import XCTest
@testable import GezCore

/// Phase 20.7 part 1: the Old World map box, unknown land and the new faiths.
final class OldWorldMapTests: XCTestCase {
    /// The map covers Afro-Eurasia (25 W to 148 E, 35 S to 71.5 N) at
    /// 48 pixels per degree (owner, 23 Nov 2026).
    func testMapBoxAndDetail() throws {
        let world = Scenario1453.makeWorld()
        XCTAssertEqual(world.map.pixelsPerDegree, 48)
        XCTAssertEqual(world.map.longitudeMin, -25)
        XCTAssertEqual(world.map.latitudeMax, 71.5)
        XCTAssertEqual(world.map.width, 8304)
        XCTAssertEqual(world.map.height, 5112)
        let ids = try ProvinceIDMap.loadBundled()
        let seas = try ProvinceIDMap.loadBundledSeas()
        XCTAssertEqual(ids.width, world.map.width)
        XCTAssertEqual(seas.height, world.map.height)
        // Province ids must fit the 8192-wide map colour texture of the game.
        XCTAssertLessThan(world.provinces.count + 2, 8192)
    }

    /// The new land is on the map: Kyoto, the Cape and Java are land, and
    /// still wasteland until their region pull requests fill them.
    func testNewLandIsOnTheMap() throws {
        let world = Scenario1453.makeWorld()
        let ids = try ProvinceIDMap.loadBundled()
        for (lat, lon) in [(35.0, 135.8), (-33.9, 18.6), (-7.5, 110.5), (39.9, 116.4)] {
            let p = world.map.point(for: GeoPoint(latitude: lat, longitude: lon))
            XCTAssertNotEqual(ids.value(x: p.x, y: p.y), ProvinceIDMap.water, "\(lat), \(lon) should be land")
        }
        // The South China Sea is a sea zone.
        let seas = try ProvinceIDMap.loadBundledSeas()
        let scs = world.map.point(for: GeoPoint(latitude: 13.0, longitude: 114.0))
        XCTAssertEqual(seas.seaZone(x: scs.x, y: scs.y), world.seaZones.id(named: "South China Sea"))
    }

    /// Australia and New Guinea are unknown land: wasteland in the province
    /// map, marked in the sea map, and never taken for a sea zone.
    func testUnknownLand() throws {
        let world = Scenario1453.makeWorld()
        let ids = try ProvinceIDMap.loadBundled()
        let seas = try ProvinceIDMap.loadBundledSeas()
        for (lat, lon) in [(-25.0, 134.0), (-5.5, 142.0)] {
            let p = world.map.point(for: GeoPoint(latitude: lat, longitude: lon))
            XCTAssertEqual(ids.value(x: p.x, y: p.y), ProvinceIDMap.wasteland)
            XCTAssertTrue(seas.isUnknownLand(x: p.x, y: p.y))
            XCTAssertNil(seas.seaZone(x: p.x, y: p.y))
        }
        // Known wasteland (the Sahara) is not unknown land.
        let sahara = world.map.point(for: GeoPoint(latitude: 24.0, longitude: 23.0))
        XCTAssertFalse(seas.isUnknownLand(x: sahara.x, y: sahara.y))
        // No sea value other than the marker points past the sea zones.
        let count = world.seaZones.count
        for v in Set(seas.values) where v != ProvinceIDMap.unknownLand {
            XCTAssertLessThanOrEqual(Int(v), count)
        }
    }

    /// New faiths and their families; older cases keep their order (saves
    /// and history store a religion as its position in the list).
    func testNewFaiths() {
        XCTAssertEqual(Religion.allCases.firstIndex(of: .folk), 26)
        XCTAssertEqual(Religion.mahayana.family, .dharmic)
        for r in [Religion.confucian, .daoist, .shinto] {
            XCTAssertEqual(r.family, .eastAsian)
        }
        for r in [Religion.westAfrican, .bantu, .eastAfrican, .siberian, .austronesian, .highland] {
            XCTAssertEqual(r.family, .pagan)
        }
        XCTAssertEqual(Religion(rawValue: "west_african"), .westAfrican)
        XCTAssertEqual(Religion(rawValue: "east_african"), .eastAfrican)
        XCTAssertEqual(ReligionFamily.eastAsian.displayName, "East Asian")
        let names = Set(Religion.allCases.map(\.displayName))
        XCTAssertEqual(names.count, Religion.allCases.count, "display names must differ")
    }

    /// The Oromo, Sidama and Kafa keep their own faith (Waaqeffanna and
    /// kin), now East African traditions instead of generic folk religion.
    func testHornFaithsMoved() {
        let world = Scenario1453.makeWorld()
        guard let kaffa = world.countries.id(forTag: "KAF") else { return XCTFail("no Kaffa") }
        XCTAssertEqual(world.countries.religion[kaffa.index], .eastAfrican)
    }
}
