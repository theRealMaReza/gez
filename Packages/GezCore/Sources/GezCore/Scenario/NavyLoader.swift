import Foundation

/// Loads `Resources/navy1453.json` (built by `tools/navy/navgen.py`) into
/// `world.navy`, sea-zone metadata (centers and inland-sea flags), and
/// strait-to-sea-zone guard mappings.
enum NavyLoader {
    static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "navy1453", withExtension: "json") else {
            throw Scenario1453.LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world)
    }

    static func load(from data: Data, into world: inout World) throws {
        let file = try JSONDecoder().decode(NavyFile.self, from: data)
        var navy = Navy()
        navy.resize(countries: world.countries.count)

        for (z, meta) in file.seaZones.enumerated() where z < world.seaZones.count {
            world.seaZones.isInland[z] = meta.inland
            world.seaZones.centerX[z] = meta.centerX
            world.seaZones.centerY[z] = meta.centerY
        }

        for st in file.straits {
            guard st.a >= 0, st.a < world.provinces.count, st.b >= 0, st.b < world.provinces.count else {
                continue
            }
            let pair = ProvincePair(ProvinceID(st.a), ProvinceID(st.b))
            let seas = st.seas.filter { $0 >= 0 && $0 < world.seaZones.count }.map(SeaZoneID.init)
            world.straitSeas[pair] = seas
        }

        for (idx, s) in file.ships.enumerated() {
            guard let sClass = ShipClass(rawValue: s.shipClass) else {
                throw Scenario1453.LoadError.unknownValue("ship class \(s.shipClass)")
            }
            var goods: [(GoodID, Double)] = []
            for key in s.goods.keys.sorted() {
                guard let gid = world.economy.goods.id(forKey: key) else {
                    throw Scenario1453.LoadError.unknownValue("good \(key)")
                }
                goods.append((gid, s.goods[key]!))
            }
            let requires = try parseRequirements(s.requires)
            let id = ShipTypeID(idx)
            let stype = ShipType(
                id: id,
                key: s.key,
                name: s.name,
                shipClass: sClass,
                speed: s.speed,
                maxHull: s.hull,
                cannons: s.cannons,
                maxCrew: s.crew,
                buildMonths: s.buildMonths,
                cost: s.cost,
                upkeep: s.upkeep,
                capacity: s.capacity,
                goods: goods,
                requires: requires,
                minDipTech: s.minDipTech ?? 1
            )
            navy.shipTypes.append(stype)
            navy.shipByKey[s.key] = id
        }

        for f in file.fleets {
            guard let cid = world.countries.id(forTag: f.country) else {
                throw Scenario1453.LoadError.unknownValue("country \(f.country)")
            }
            guard f.province >= 0 && f.province < world.provinces.count else {
                throw Scenario1453.LoadError.unknownValue("port province \(f.province)")
            }
            let pid = ProvinceID(f.province)
            var admiral: CharacterID?
            if let key = f.admiral {
                guard let ch = world.people.characters.id(forKey: key) else {
                    throw Scenario1453.LoadError.unknownValue("admiral \(key)")
                }
                admiral = ch
            }
            let fid = navy.fleets.append(
                name: f.name,
                owner: cid,
                location: .port(pid),
                admiral: admiral
            )
            for entry in f.ships {
                guard let tid = navy.shipByKey[entry.type] else {
                    throw Scenario1453.LoadError.unknownValue("ship type \(entry.type)")
                }
                let stype = navy.shipType(tid)
                for _ in 0..<entry.count {
                    let sIdx = navy.ships.add(
                        type: tid,
                        fleet: fid,
                        hull: 100.0,
                        crew: stype.maxCrew,
                        morale: 3.0,
                        originProvince: pid
                    )
                    navy.fleets.shipIndices[fid.index].append(sIdx)
                }
            }
        }

        world.navy = navy
    }

    private static func parseRequirements(_ reqs: [NavyFile.Requirement]) throws -> [UnitUnlock] {
        var out: [UnitUnlock] = []
        for req in reqs {
            switch req.kind {
            case "estate":
                out.append(.estate(req.values))
            case "government":
                let govs = try req.values.map { raw -> GovernmentType in
                    guard let g = GovernmentType(rawValue: raw) else {
                        throw Scenario1453.LoadError.unknownValue("government \(raw)")
                    }
                    return g
                }
                out.append(.government(govs))
            case "culture":
                out.append(.culture(req.values))
            case "region":
                out.append(.region(req.values))
            case "tags":
                out.append(.tags(req.values))
            default:
                throw Scenario1453.LoadError.unknownValue("ship requirement \(req.kind)")
            }
        }
        return out
    }
}

private struct NavyFile: Decodable {
    struct Requirement: Decodable {
        let kind: String
        let values: [String]
    }

    struct ShipDef: Decodable {
        let key: String
        let name: String
        let shipClass: String
        let speed: Double
        let hull: Double
        let cannons: Int
        let crew: Int
        let buildMonths: Int
        let cost: Double
        let upkeep: Double
        let capacity: Int
        let goods: [String: Double]
        let requires: [Requirement]
        let minDipTech: Int?
    }

    struct ShipStack: Decodable {
        let type: String
        let count: Int
    }

    struct FleetEntry: Decodable {
        let country: String
        let name: String
        let province: Int
        let admiral: String?
        let ships: [ShipStack]
    }

    struct SeaZoneMeta: Decodable {
        let name: String
        let inland: Bool
        let centerX: Double
        let centerY: Double
    }

    struct StraitEntry: Decodable {
        let a: Int
        let b: Int
        let seas: [Int]
    }

    let ships: [ShipDef]
    let fleets: [FleetEntry]
    let seaZones: [SeaZoneMeta]
    let straits: [StraitEntry]
}
