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

    /// Phase 20.7 Burma and Shan States: Ava, Hanthawaddy Pegu, Arakan,
    /// and the four Shan sawbwa polities (Mong Mao, Hsenwi, Hsipaw, Kale).
    func testBurmaAndShanStates() {
        let world = Scenario1453.makeWorld()
        guard let ava = world.countries.id(forTag: "AVA"),
              let peg = world.countries.id(forTag: "PEG"),
              let ark = world.countries.id(forTag: "ARK"),
              let mog = world.countries.id(forTag: "MOG"),
              let hse = world.countries.id(forTag: "HSE"),
              let hsi = world.countries.id(forTag: "HSI"),
              let kal = world.countries.id(forTag: "KAL"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Burma or Shan countries")
        }
        for c in [ava, peg, ark, mog, hse, hsi, kal] {
            XCTAssertEqual(world.countries.religion[c.index], .theravada)
        }
        XCTAssertEqual(world.countries.overlord[mog.index], mng)
        XCTAssertEqual(world.countries.subjectType[mog.index], .tributary)
        XCTAssertEqual(world.countries.overlord[hse.index], ava)
        XCTAssertEqual(world.countries.subjectType[hse.index], .tributary)
        XCTAssertEqual(world.countries.overlord[hsi.index], ava)
        XCTAssertEqual(world.countries.subjectType[hsi.index], .tributary)
        XCTAssertEqual(world.countries.overlord[kal.index], ava)
        XCTAssertEqual(world.countries.subjectType[kal.index], .vassal)

        XCTAssertTrue(world.rivers.contains { $0.name == "Irrawaddy" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Salween" })
        for name in ["Ava", "Pagan", "Prome", "Toungoo", "Pegu", "Dagon", "Martaban", "Mrauk U", "Mong Mao", "Hsenwi", "Hsipaw", "Kale"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Burma/Shan province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Toungoo")!.index])
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Prome")!.index])
    }

    /// Phase 20.7 Indochina and Siam: Ayutthaya, Lan Na, Lan Xang, Cambodia,
    /// Dai Viet, Champa, Pattani, and Kedah.
    func testIndochinaAndSiam() {
        let world = Scenario1453.makeWorld()
        guard let ayu = world.countries.id(forTag: "AYU"),
              let lna = world.countries.id(forTag: "LNA"),
              let lxa = world.countries.id(forTag: "LXA"),
              let khm = world.countries.id(forTag: "KHM"),
              let dai = world.countries.id(forTag: "DAI"),
              let cha = world.countries.id(forTag: "CHA"),
              let pat = world.countries.id(forTag: "PAT"),
              let ked = world.countries.id(forTag: "KED"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Indochina countries")
        }
        for c in [ayu, lna, lxa, khm] {
            XCTAssertEqual(world.countries.religion[c.index], .theravada)
        }
        XCTAssertEqual(world.countries.religion[dai.index], .mahayana)
        XCTAssertEqual(world.countries.religion[cha.index], .hindu)
        XCTAssertEqual(world.countries.religion[pat.index], .sunni)
        XCTAssertEqual(world.countries.religion[ked.index], .sunni)

        XCTAssertEqual(world.countries.overlord[pat.index], ayu)
        XCTAssertEqual(world.countries.overlord[ked.index], ayu)
        XCTAssertEqual(world.countries.overlord[dai.index], mng)
        XCTAssertEqual(world.countries.overlord[ayu.index], mng)
        XCTAssertEqual(world.countries.overlord[cha.index], mng)

        XCTAssertTrue(world.rivers.contains { $0.name == "Mekong" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Chao Phraya" })
        XCTAssertTrue(world.rivers.contains { $0.name == "Red River" })
        for name in ["Ayutthaya", "Phitsanulok", "Ligor", "Chiang Mai", "Luang Prabang", "Chaktomuk", "Angkor", "Thang Long", "Vijaya", "Pattani", "Kedah"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Indochina province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Ligor")!.index])
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Phitsanulok")!.index])
    }

    /// Phase 20.7 Maritime Southeast Asia: Malacca, Sumatra, Java (Majapahit,
    /// Sunda, Bali), Borneo (Brunei), Philippines, Sulawesi, and the Spice Islands.
    func testMaritimeSoutheastAsia() {
        let world = Scenario1453.makeWorld()
        guard let mlc = world.countries.id(forTag: "MLC"),
              let psa = world.countries.id(forTag: "PSA"),
              let maj = world.countries.id(forTag: "MAJ"),
              let sun = world.countries.id(forTag: "SUN"),
              let bal = world.countries.id(forTag: "BAL"),
              let plb = world.countries.id(forTag: "PLB"),
              let bni = world.countries.id(forTag: "BNI"),
              let ter = world.countries.id(forTag: "TER"),
              let tid = world.countries.id(forTag: "TID"),
              let mng = world.countries.id(forTag: "MNG") else {
            return XCTFail("missing Maritime Southeast Asia countries")
        }
        for c in [mlc, psa, plb, bni, ter, tid] {
            XCTAssertEqual(world.countries.religion[c.index], .sunni)
        }
        for c in [maj, sun, bal] {
            XCTAssertEqual(world.countries.religion[c.index], .hindu)
        }
        XCTAssertEqual(world.countries.overlord[mlc.index], mng)
        XCTAssertEqual(world.countries.subjectType[mlc.index], .tributary)
        XCTAssertEqual(world.countries.overlord[bal.index], maj)
        XCTAssertEqual(world.countries.subjectType[bal.index], .vassal)
        XCTAssertEqual(world.countries.overlord[plb.index], maj)
        XCTAssertEqual(world.countries.subjectType[plb.index], .tributary)

        for name in ["Malacca", "Pasai", "Palembang", "Bangka", "Pakuan", "Trowulan", "Gelgel", "Brunei", "Palawan", "Tondo", "Mindoro", "Cebu", "Makassar", "Buton", "Ternate", "Tidore", "Seram", "Buru"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Maritime SEA province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        // Key archipelago straits
        let malacca = world.provinces.id(named: "Malacca")!
        let siak = world.provinces.id(named: "Siak")!
        let lampung = world.provinces.id(named: "Lampung")!
        let banten = world.provinces.id(named: "Banten")!
        let blambangan = world.provinces.id(named: "Blambangan")!
        let gelgel = world.provinces.id(named: "Gelgel")!
        XCTAssertTrue(world.provinces.neighbors[malacca.index].contains(siak))
        XCTAssertTrue(world.provinces.neighbors[lampung.index].contains(banten))
        XCTAssertTrue(world.provinces.neighbors[blambangan.index].contains(gelgel))
    }

    /// Phase 20.7 West Africa, Sahel, and Guinea Coast: Mali, Tuareg Timbuktu,
    /// Songhai, Jolof, Mossi, Hausa Bakwai, Kanem-Bornu, Bulala, Darfur, Benin, Oyo, Nupe, Bono Manso.
    func testWestAfricaAndSahel() {
        let world = Scenario1453.makeWorld()
        guard let mal = world.countries.id(forTag: "MAL"),
              let trg = world.countries.id(forTag: "TRG"),
              let son = world.countries.id(forTag: "SON"),
              let kao = world.countries.id(forTag: "KAO"),
              let kbo = world.countries.id(forTag: "KBO"),
              let ben = world.countries.id(forTag: "BEN"),
              let oyo = world.countries.id(forTag: "OYO"),
              let bon = world.countries.id(forTag: "BON") else {
            return XCTFail("missing West Africa countries")
        }
        for c in [mal, trg, son, kao, kbo] {
            XCTAssertEqual(world.countries.religion[c.index], .sunni)
        }
        for c in [ben, oyo, bon] {
            XCTAssertEqual(world.countries.religion[c.index], .westAfrican)
        }
        XCTAssertTrue(world.rivers.contains { $0.name == "Niger River" })
        for name in ["Niani", "Jenne", "Timbuktu", "Gao", "Diourbel", "Wagadugu", "Kano", "Birni Gazargamu", "El Fasher", "Benin City", "Oyo-Ile", "Ife", "Bono Manso"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing West Africa province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 East Africa, Great Lakes, and Swahili Coast: Kilwa, Mombasa,
    /// Malindi, Bunyoro-Kitara, Buganda, Rwanda, Burundi, Borana, Shilluk.
    func testEastAfricaAndSwahiliCoast() {
        let world = Scenario1453.makeWorld()
        guard let kil = world.countries.id(forTag: "KIL"),
              let mba = world.countries.id(forTag: "MBA"),
              let mld = world.countries.id(forTag: "MLD"),
              let bny = world.countries.id(forTag: "BNY"),
              let bgd = world.countries.id(forTag: "BGD"),
              let rwa = world.countries.id(forTag: "RWA"),
              let brd = world.countries.id(forTag: "BRD") else {
            return XCTFail("missing East Africa countries")
        }
        for c in [kil, mba, mld] {
            XCTAssertEqual(world.countries.religion[c.index], .sunni)
        }
        for c in [bny, bgd, rwa, brd] {
            XCTAssertEqual(world.countries.religion[c.index], .bantu)
        }
        XCTAssertTrue(world.rivers.contains { $0.name == "White Nile" })
        for name in ["Kilwa", "Zanzibar", "Mombasa", "Malindi", "Sofala", "Comoros", "Bigo", "Mengo", "Nyanza", "Muramvya"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing East Africa province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        let zanzibar = world.provinces.id(named: "Zanzibar")!
        let bagamoyo = world.provinces.id(named: "Bagamoyo")!
        XCTAssertTrue(world.provinces.neighbors[zanzibar.index].contains(bagamoyo))
    }

    /// Phase 20.7 Central Africa, Southern Africa, and Madagascar: Kongo,
    /// Loango, Ndongo, Tio, Luba, Lunda, Mutapa, Butua, Sotho-Tswana, Nguni,
    /// Khoikhoi, and Malagasy polities.
    func testCentralSouthernAfricaAndMadagascar() {
        let world = Scenario1453.makeWorld()
        guard let kon = world.countries.id(forTag: "KON"),
              let lba = world.countries.id(forTag: "LBA"),
              let mtp = world.countries.id(forTag: "MTP"),
              let btw = world.countries.id(forTag: "BTW"),
              let kho = world.countries.id(forTag: "KHO"),
              let mer = world.countries.id(forTag: "MER"),
              let ant = world.countries.id(forTag: "ANT") else {
            return XCTFail("missing Central/Southern Africa or Madagascar countries")
        }
        for c in [kon, lba, mtp, btw, kho] {
            XCTAssertEqual(world.countries.religion[c.index], .bantu)
        }
        XCTAssertEqual(world.countries.religion[mer.index], .austronesian)
        XCTAssertEqual(world.countries.religion[ant.index], .sunni)
        XCTAssertTrue(world.rivers.contains { $0.name == "Congo River" })
        for name in ["Mbanza Kongo", "Soyo", "Mwibele", "Musumba", "Mount Fura", "Great Zimbabwe", "Khami", "Kaditshwene", "Natal", "Cape of Good Hope", "Alasora", "Menabe", "Vohipeno"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Southern Africa/Madagascar province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 Siberia: Khanate of Sibir (Taibugid Mar), Pelym (Mansi),
    /// Kod (Khanty), Buryats around Lake Baikal, Evenks, and Sakha/Yakuts.
    func testSiberia() {
        let world = Scenario1453.makeWorld()
        guard let sib = world.countries.id(forTag: "SIB"),
              let pel = world.countries.id(forTag: "PEL"),
              let kod = world.countries.id(forTag: "KOD"),
              let bya = world.countries.id(forTag: "BYA"),
              let evk = world.countries.id(forTag: "EVK"),
              let yak = world.countries.id(forTag: "YAK") else {
            return XCTFail("missing Siberia countries")
        }
        XCTAssertEqual(world.countries.religion[sib.index], .sunni)
        XCTAssertEqual(world.countries.government[sib.index], .steppeHorde)
        XCTAssertEqual(world.countries.religion[bya.index], .tengri)
        for c in [pel, kod, evk, yak] {
            XCTAssertEqual(world.countries.religion[c.index], .siberian)
        }
        for r in ["Ob River", "Irtysh River", "Yenisei River", "Lena River"] {
            XCTAssertTrue(world.rivers.contains { $0.name == r }, r)
        }
        for name in ["Qashliq", "Chimgi-Tura", "Pelym", "Kod", "Yeniseysk", "Olkhon", "Tuymaada", "Ayan", "Okhotsk", "Uda"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Siberia province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 HRE & Alps Part III detail: 8 new HRE tags, Lower Lusatia
    /// pledge under Brandenburg, and 4 Silesian Piast internal BOH vassals.
    func testHREDetailPartIII() {
        let world = Scenario1453.makeWorld()
        for tag in ["ANH", "OSN", "PAD", "FLD", "NAS", "KNZ", "LAU", "HLD"] {
            guard let cid = world.countries.id(forTag: tag) else {
                XCTFail("missing HRE tag \(tag)")
                continue
            }
            XCTAssertEqual(world.countries.religion[cid.index], .catholic, tag)
        }
        let cln = world.countries.id(forTag: "CLN")!
        let pad = world.countries.id(forTag: "PAD")!
        XCTAssertEqual(world.countries.overlord[pad.index], cln)
        XCTAssertEqual(world.countries.subjectType[pad.index], .personalUnion)

        let bra = world.countries.id(forTag: "BRA")!
        let lubben = world.provinces.id(named: "Lubben")!
        XCTAssertEqual(world.provinces.owner[lubben.index], bra)

        for name in ["Dessau", "Osnabruck", "Minden", "Paderborn", "Fulda", "Wiesbaden", "Siegen", "Konstanz", "Lauenburg", "Hildesheim", "Solingen", "Unna", "Verden", "Eisenach", "Gotha", "Neumarkt", "Villach", "Bregenz", "Porrentruy", "Neuchatel"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing HRE/Alps province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        for silesia in ["Cieszyn", "Oswiecim", "Olesnica", "Zagan"] {
            let pid = world.provinces.id(named: silesia)!
            XCTAssertNotNil(world.provinces.holder[pid.index], silesia)
        }
    }

    /// Phase 20.7 Italy Part III detail: Piombino (Appiani), Forli (Ordelaffi
    /// papal vicar), Benevento papal enclave, Crema (Venice), Finale/Massa
    /// internal vassals, and Naples subdivisions.
    func testItalyDetailPartIII() {
        let world = Scenario1453.makeWorld()
        guard let pio = world.countries.id(forTag: "PIO"),
              let frl = world.countries.id(forTag: "FRL"),
              let pap = world.countries.id(forTag: "PAP"),
              let ven = world.countries.id(forTag: "VEN") else {
            return XCTFail("missing Italy Part III tags")
        }
        XCTAssertEqual(world.countries.religion[pio.index], .catholic)
        XCTAssertEqual(world.countries.overlord[frl.index], pap)
        XCTAssertEqual(world.countries.subjectType[frl.index], .vassal)

        let benevento = world.provinces.id(named: "Benevento")!
        XCTAssertEqual(world.provinces.owner[benevento.index], pap)
        let crema = world.provinces.id(named: "Crema")!
        XCTAssertEqual(world.provinces.owner[crema.index], ven)

        for name in ["Piombino", "Forli", "Crema", "Benevento", "Finale", "Massa", "Capua", "Chieti", "Brindisi", "Catanzaro"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing Italy province \(name)")
    /// Phase 20.7 India detail (§2.9): Velamas buffer at Rachakonda/Devarakonda,
    /// Garhjat tributary of Orissa, Khukhra, and Vijayanagara western feudatories.
    func testIndiaDetailPartIII() {
        let world = Scenario1453.makeWorld()
        guard let vlm = world.countries.id(forTag: "VLM"),
              let grj = world.countries.id(forTag: "GRJ"),
              let ori = world.countries.id(forTag: "ORI") else {
            return XCTFail("missing India detail tags")
        }
        XCTAssertEqual(world.countries.religion[vlm.index], .hindu)
        XCTAssertEqual(world.countries.religion[grj.index], .hindu)
        XCTAssertEqual(world.countries.overlord[grj.index], ori)
        XCTAssertEqual(world.countries.subjectType[grj.index], .tributary)

        for name in ["Rachakonda", "Devarakonda", "Keonjhar", "Khukhra", "Ummattur", "Keladi"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing India province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Finale")!.index])
        XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: "Massa")!.index])
    }

    /// Phase 20.7 Ireland Part III detail: Monaghan (MacMahon / Oriel) and
    /// subdivided provinces across Leinster, Connacht, and Ulster.
    func testIrelandDetailPartIII() {
        let world = Scenario1453.makeWorld()
        guard let mnh = world.countries.id(forTag: "MNH"),
              let eng = world.countries.id(forTag: "ENG"),
              let kid = world.countries.id(forTag: "KID"),
              let ocn = world.countries.id(forTag: "OCN"),
              let tyr = world.countries.id(forTag: "TYR") else {
            return XCTFail("missing Ireland Part III tags")
        }
        XCTAssertEqual(world.countries.religion[mnh.index], .catholic)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Monaghan")!.index], mnh)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Dundalk")!.index], eng)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Belfast")!.index], eng)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Maynooth")!.index], kid)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Athlone")!.index], ocn)
        XCTAssertEqual(world.provinces.owner[world.provinces.id(named: "Coleraine")!.index], tyr)

        for name in ["Monaghan", "Athlone", "Maynooth", "Dundalk", "Belfast", "Coleraine"] {
            let pid = world.provinces.id(named: name)!
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
    }

    /// Phase 20.7 India detail (§2.9): Velamas buffer at Rachakonda/Devarakonda,
    /// Garhjat tributary of Orissa, Khukhra, and Vijayanagara western feudatories.
    func testIndiaDetailPartIII() {
        let world = Scenario1453.makeWorld()
        guard let vlm = world.countries.id(forTag: "VLM"),
              let grj = world.countries.id(forTag: "GRJ"),
              let ori = world.countries.id(forTag: "ORI") else {
            return XCTFail("missing India detail tags")
        }
        XCTAssertEqual(world.countries.religion[vlm.index], .hindu)
        XCTAssertEqual(world.countries.religion[grj.index], .hindu)
        XCTAssertEqual(world.countries.overlord[grj.index], ori)
        XCTAssertEqual(world.countries.subjectType[grj.index], .tributary)

        for name in ["Rachakonda", "Devarakonda", "Keonjhar", "Khukhra", "Ummattur", "Keladi"] {
            guard let pid = world.provinces.id(named: name) else {
                XCTFail("missing India province \(name)")
                continue
            }
            XCTAssertFalse(world.provinces.neighbors[pid.index].isEmpty, name)
        }
        for held in ["Khukhra", "Ummattur", "Barkur", "Keladi"] {
            XCTAssertNotNil(world.provinces.holder[world.provinces.id(named: held)!.index], held)
        }
    }
}
