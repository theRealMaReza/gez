import Foundation

/// Loads ruling systems and formables from `Resources/rulings1453.json`
/// (built by `tools/rulings/rulinggen.py` from `data/rulings/`) and sets up
/// the 1453 state.
public enum RulingLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case wrongMap(file: Int, world: Int)
        case unknownTag(String)
        case unknownModifier(String)
        case unknownGovernment(String)

        public var description: String {
            switch self {
            case .missingResource:
                return "Missing rulings1453.json resource in GezCore bundle."
            case .wrongMap(let file, let world):
                return "rulings1453.json was built for \(file) provinces but the map has \(world); run tools/rulings/rulinggen.py."
            case .unknownTag(let tag):
                return "rulings1453.json references unknown country tag '\(tag)'."
            case .unknownModifier(let m):
                return "rulings1453.json references unknown modifier '\(m)'."
            case .unknownGovernment(let g):
                return "rulings1453.json references unknown government '\(g)'."
            }
        }
    }

    struct RolePayload: Decodable {
        let role: String
        let tags: [String]
    }

    struct ValuePayload: Decodable {
        let key: String
        let value: Double
        let min: Double?
        let max: Double?
    }

    struct LimitPayload: Decodable {
        let key: String
        let min: Double
        let max: Double
    }

    struct ParamPayload: Decodable {
        let key: String
        let value: Double
    }

    struct RoleEffectPayload: Decodable {
        let role: String
        let mods: [String: Double]
        let scaleBy: String?
        let divisor: Double?
    }

    struct SystemPayload: Decodable {
        let key: String
        let name: String
        let leader: String?
        let roles: [RolePayload]
        let values: [ValuePayload]
        let countryLimits: [LimitPayload]?
        let params: [ParamPayload]
        let provinces: [Int]
        let roleEffects: [RoleEffectPayload]
    }

    struct FormablePayload: Decodable {
        let id: String
        let name: String
        let text: String
        let color: [Int]
        let shield: String
        let eligible: [String]
        let trigger: [EventCondition]
        let government: String?
        let reforms: [String]
        let effects: [EventEffect]
        let missionTree: String?
        let ai: Bool
        let unique: Bool
    }

    struct FilePayload: Decodable {
        let provinceCount: Int
        let systems: [SystemPayload]
        let formables: [FormablePayload]
    }

    public static func loadBundled(into world: inout World, date: GameDate) throws {
        guard let url = GezResources.url(forResource: "rulings1453", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world, date: date)
    }

    /// Reads the rules and builds the starting state (`RulingEngine.setUp`).
    public static func load(from data: Data, into world: inout World, date: GameDate) throws {
        let file = try JSONDecoder().decode(FilePayload.self, from: data)
        guard file.provinceCount == world.provinces.count else {
            throw LoadError.wrongMap(file: file.provinceCount, world: world.provinces.count)
        }
        let countries = world.countries
        let provinceCount = world.provinces.count
        func country(_ tag: String) throws -> CountryID {
            guard let c = countries.id(forTag: tag) else { throw LoadError.unknownTag(tag) }
            return c
        }
        func mods(_ m: [String: Double]) throws -> [Double] {
            var out = Array(repeating: 0.0, count: Modifier.allCases.count)
            for k in m.keys.sorted() {
                guard let mod = Modifier(key: k) else { throw LoadError.unknownModifier(k) }
                out[mod.rawValue] += m[k] ?? 0
            }
            return out
        }

        var systems: [RulingSystemDef] = []
        for s in file.systems {
            var roles: [String: [CountryID]] = [:]
            var order: [String] = []
            for r in s.roles {
                let ids = try r.tags.map(country)
                roles[r.role, default: []].append(contentsOf: ids)
                if !order.contains(r.role) { order.append(r.role) }
            }
            for k in roles.keys.sorted() {
                roles[k] = Array(Set(roles[k] ?? [])).sorted { $0.index < $1.index }
            }
            var values: [String: Double] = [:]
            var limits: [String: ClosedRange<Double>] = [:]
            for v in s.values {
                values[v.key] = v.value
                if v.min != nil || v.max != nil {
                    let lo = v.min ?? -Double.greatestFiniteMagnitude
                    let hi = v.max ?? Double.greatestFiniteMagnitude
                    limits[v.key] = lo...max(lo, hi)
                }
            }
            for l in s.countryLimits ?? [] {
                limits[l.key] = l.min...max(l.min, l.max)
            }
            var params: [String: Double] = [:]
            for p in s.params { params[p.key] = p.value }
            let effects = try s.roleEffects.map {
                RulingRoleEffect(role: $0.role, values: try mods($0.mods), scaleBy: $0.scaleBy, scaleDivisor: $0.divisor ?? 1)
            }
            systems.append(RulingSystemDef(
                key: s.key,
                name: s.name,
                leader: try s.leader.map(country),
                roles: roles,
                roleOrder: order,
                values: values,
                limits: limits,
                params: params,
                provinces: s.provinces.filter { $0 >= 0 && $0 < provinceCount }.map(ProvinceID.init),
                roleEffects: effects
            ))
        }

        var formables: [FormableDef] = []
        for f in file.formables {
            var gov: GovernmentType?
            if let g = f.government {
                guard let t = GovernmentType(rawValue: g) else { throw LoadError.unknownGovernment(g) }
                gov = t
            }
            let rgb = f.color.map { UInt8(clamping: $0) } + [0, 0, 0]
            formables.append(FormableDef(
                id: f.id,
                name: f.name,
                text: f.text,
                color: RGB(rgb[0], rgb[1], rgb[2]),
                shield: f.shield,
                eligible: try f.eligible.map(country),
                trigger: f.trigger,
                government: gov,
                reforms: f.reforms,
                effects: f.effects,
                missionTree: f.missionTree,
                ai: f.ai,
                unique: f.unique
            ))
        }

        world.rulingRules = RulingRules(systems: systems, formables: formables, countryCount: world.countries.count)
        RulingEngine.setUp(&world, date: date)
    }
}
