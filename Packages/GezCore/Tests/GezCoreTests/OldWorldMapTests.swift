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

    /// Phase 20.7 East Asia core: Ming China, Joseon, Ashikaga and shugo
    /// vassals, Ryukyu, Ainu, tributaries, and the East Asian faiths.
    func testEastAsiaCore() {
        let world = Scenario1453.makeWorld()
        guard let mng = world.countries.id(forTag: "MNG"),
              let jos = world.countries.id(forTag: "JOS"),
              let ash = world.countries.id(forTag: "ASH"),
              let ryu = world.countries.id(forTag: "RYU"),
              let ain = world.countries.id(forTag: "AIN") else {
            return XCTFail("missing East Asia core countries")
        }
        XCTAssertEqual(world.countries.religion[mng.index], .confucian)
        XCTAssertEqual(world.countries.religion[jos.index], .confucian)
        XCTAssertEqual(world.countries.religion[ash.index], .shinto)
        XCTAssertEqual(world.countries.religion[ryu.index], .mahayana)
        XCTAssertEqual(world.countries.religion[ain.index], .siberian)

        XCTAssertEqual(world.countries.overlord[jos.index], mng)
        XCTAssertEqual(world.countries.subjectType[jos.index], .tributary)
        XCTAssertEqual(world.countries.overlord[ryu.index], mng)
        XCTAssertEqual(world.countries.subjectType[ryu.index], .tributary)

        for shugoTag in ["HSK", "YMN", "HTK", "SHB", "OUC", "SMZ", "OTM", "SHN", "KNO", "KMK", "UES", "TKD", "IMG", "DTE", "AND"] {
            guard let shugo = world.countries.id(forTag: shugoTag) else {
                XCTFail("missing shugo tag \(shugoTag)")
                continue
            }
            XCTAssertEqual(world.countries.overlord[shugo.index], ash, shugoTag)
            XCTAssertEqual(world.countries.subjectType[shugo.index], .vassal, shugoTag)
        }

        // Rivers and Jiuquan connectivity
        XCTAssertTrue(world.rivers.contains { $0.name == "Yellow River" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Yangtze" })
        guard let jiuquan = world.provinces.id(named: "Jiuquan") else { return XCTFail("missing Jiuquan") }
        XCTAssertFalse(world.provinces.neighbors[jiuquan.index].isEmpty)

        // Great vassal holdings in Ming China
        let taiyuan = world.provinces.id(named: "Taiyuan")!
        XCTAssertNotNil(world.provinces.holder[taiyuan.index])
    }

    /// Phase 20.7 Tarim Basin and Moghulistan: expanded Moghulistan, Dughlat
    /// Emirate of Kashgar vassal, Kara Del (Hami) Ming tributary, and overland
    /// Silk Road connectivity between China and Central Asia.
    func testTarimBasinAndMoghulistan() {
        let world = Scenario1453.makeWorld()
        guard let mgh = world.countries.id(forTag: "MGH"),
              let dug = world.countries.id(forTag: "DUG"),
              let kdl = world.countries.id(forTag: "KDL"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Tarim Basin countries")
        }
        XCTAssertEqual(world.countries.religion[mgh.index], .sunni)
        XCTAssertEqual(world.countries.religion[dug.index], .sunni)
        XCTAssertEqual(world.countries.religion[kdl.index], .mahayana)
        XCTAssertEqual(world.countries.overlord[dug.index], mgh)
        XCTAssertEqual(world.countries.subjectType[dug.index], .vassal)
        XCTAssertEqual(world.countries.overlord[kdl.index], mng)
        XCTAssertEqual(world.countries.subjectType[kdl.index], .tributary)

        XCTAssertTrue(world.rivers.contains { $0.name == "Tarim River" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Ili River" })
        XCTAssertNotNil(world.provinces.id(named: "Kashgar"))
        XCTAssertNotNil(world.provinces.id(named: "Aksu"))
        XCTAssertNotNil(world.provinces.id(named: "Turpan"))
        XCTAssertNotNil(world.provinces.id(named: "Hami"))
        XCTAssertNotNil(world.provinces.id(named: "Dunhuang"))

        // Overland Silk Road: Yumen links Dunhuang to Jiuquan.
        guard let yumen = world.provinces.id(named: "Yumen"),
              let jiuquan = world.provinces.id(named: "Jiuquan"),
              let dunhuang = world.provinces.id(named: "Dunhuang") else {
            return XCTFail("missing Hexi-Tarim corridor provinces")
        }
        XCTAssertTrue(world.provinces.neighbors[yumen.index].contains(jiuquan))
        XCTAssertTrue(world.provinces.neighbors[yumen.index].contains(dunhuang))
    }

    /// Phase 20.7 Tibet and Bhutan: Phagmodrupa, Rinpungpa vassal, Guge,
    /// Mangyul Gungthang, Derge (Kham), Amdo, Bhutan, and Himalayan/Sichuan links.
    func testTibetAndBhutan() {
        let world = Scenario1453.makeWorld()
        guard let pha = world.countries.id(forTag: "PHA"),
              let rin = world.countries.id(forTag: "RIN"),
              let gug = world.countries.id(forTag: "GUG"),
              let gnt = world.countries.id(forTag: "GNT"),
              let drg = world.countries.id(forTag: "DRG"),
              let amd = world.countries.id(forTag: "AMD"),
              let bhu = world.countries.id(forTag: "BHU") else {
            return XCTFail("missing Tibet countries")
        }
        for c in [pha, rin, gug, gnt, drg, amd, bhu] {
            XCTAssertEqual(world.countries.religion[c.index], .tibetan)
        }
        XCTAssertEqual(world.countries.overlord[rin.index], pha)
        XCTAssertEqual(world.countries.subjectType[rin.index], .vassal)

        XCTAssertTrue(world.rivers.contains { $0.name == "Yarlung Tsangpo" })
        for name in ["Lhasa", "Nedong", "Shigatse", "Tsaparang", "Dzongka", "Derge", "Rebkong", "Bumthang", "Xining"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Tibetan province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 Mongols and Oirats: Oirat steppe horde under Esen Taishi,
    /// Northern Yuan vassal, Uriankhai Three Guards Ming tributary, and Lake Baikal.
    func testMongolsAndOirats() {
        let world = Scenario1453.makeWorld()
        guard let oir = world.countries.id(forTag: "OIR"),
              let nyu = world.countries.id(forTag: "NYU"),
              let uri = world.countries.id(forTag: "URI"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Mongol/Oirat countries")
        }
        for c in [oir, nyu, uri] {
            XCTAssertEqual(world.countries.religion[c.index], .tengri)
            XCTAssertEqual(world.countries.government[c.index], .steppeHorde)
        }
        XCTAssertEqual(world.countries.overlord[nyu.index], oir)
        XCTAssertEqual(world.countries.subjectType[nyu.index], .vassal)
        XCTAssertEqual(world.countries.overlord[uri.index], mng)
        XCTAssertEqual(world.countries.subjectType[uri.index], .tributary)

        XCTAssertTrue(world.rivers.contains { $0.name == "Orkhon River" })
        for name in ["Karakorum", "Kobdo", "Beshbalik", "Shangdu", "Ordos", "Hohhot", "Doyan", "Taining"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Mongol province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 Manchuria: Jianzhou, Haixi, and Wild Jurchens, Ming tributaries,
    /// Amur/Songhua rivers, Sakhalin straits, and Aisin Gioro great vassal.
    func testManchuriaJurchens() {
        let world = Scenario1453.makeWorld()
        guard let jzh = world.countries.id(forTag: "JZH"),
              let hxi = world.countries.id(forTag: "HXI"),
              let wjr = world.countries.id(forTag: "WJR"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Manchuria Jurchen countries")
        }
        for c in [jzh, hxi, wjr] {
            XCTAssertEqual(world.countries.religion[c.index], .siberian)
        }
        XCTAssertEqual(world.countries.overlord[jzh.index], mng)
        XCTAssertEqual(world.countries.subjectType[jzh.index], .tributary)
        XCTAssertEqual(world.countries.overlord[hxi.index], mng)
        XCTAssertEqual(world.countries.subjectType[hxi.index], .tributary)

        XCTAssertTrue(world.rivers.contains { $0.name == "Amur River" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Songhua River" })
        let hetuAla = world.provinces.id(named: "Hetu Ala")!
        XCTAssertNotNil(world.provinces.holder[hetuAla.index])

        // Sakhalin strait connectivity
        let teshio = world.provinces.id(named: "Teshio")!
        let kuyeSouth = world.provinces.id(named: "Kuye South")!
        let nurgan = world.provinces.id(named: "Nurgan")!
        let kuyeNorth = world.provinces.id(named: "Kuye North")!
        XCTAssertTrue(world.provinces.neighbors[teshio.index].contains(kuyeSouth))
        XCTAssertTrue(world.provinces.neighbors[nurgan.index].contains(kuyeNorth))
    }
}
