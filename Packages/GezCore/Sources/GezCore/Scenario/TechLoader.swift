import Foundation

/// Loads technology tracks, starting levels and institution rules from
/// `Resources/technology1453.json` (built by `tools/technology/techgen.py`).
public enum TechLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case wrongMap(file: Int, world: Int)
        case badTrack(String)
        case badOrigin(String)

        public var description: String {
            switch self {
            case .missingResource:
                return "Missing technology1453.json resource in GezCore bundle."
            case .wrongMap(let file, let world):
                return "technology1453.json was built for \(file) provinces but the map has \(world); run tools/technology/techgen.py."
            case .badTrack(let key):
                return "technology1453.json: invalid track '\(key)'."
            case .badOrigin(let text):
                return "technology1453.json: invalid institution origin '\(text)'."
            }
        }
    }

    private struct FilePayload: Decodable {
        struct LevelEntry: Decodable {
            let level: Int
            let targetYear: Int
            let baseCost: Double
            let effects: [String: Double]
            let summary: String
        }
        struct StartingLevels: Decodable {
            let regions: [String: [Int]]
            let govCaps: [String: [Int]]
            let countries: [String: [Int]]
        }
        struct OriginEntry: Decodable {
            let kind: String
            let value: String
            let provinceIndex: Int?
        }
        struct InstitutionEntry: Decodable {
            let key: String
            let name: String
            let spawnYear: Int
            let origin: OriginEntry
            let spreadNeighbour: Double
            let spreadTrade: Double
            let spreadBurgher: Double
            let summary: String
        }

        let provinceCount: Int
        let params: [String: Double]
        let tracks: [String: [LevelEntry]]
        let startingLevels: StartingLevels
        let institutions: [InstitutionEntry]
    }

    public static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "technology1453", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world)
    }

    public static func load(from data: Data, into world: inout World) throws {
        let payload = try JSONDecoder().decode(FilePayload.self, from: data)
        let P = world.provinces.count
        guard payload.provinceCount == P else {
            throw LoadError.wrongMap(file: payload.provinceCount, world: P)
        }

        var rules = TechRules()
        var params = TechParams()
        if let v = payload.params["base_cost"] { params.baseCost = v }
        if let v = payload.params["neighbour_bonus_per_level"] { params.neighbourBonusPerLevel = v }
        if let v = payload.params["neighbour_bonus_cap"] { params.neighbourBonusCap = v }
        if let v = payload.params["ahead_of_time_per_year"] { params.aheadOfTimePerYear = v }
        if let v = payload.params["ahead_of_time_cap"] { params.aheadOfTimeCap = v }
        if let v = payload.params["institution_penalty_per_year"] { params.institutionPenaltyPerYear = v }
        if let v = payload.params["institution_penalty_cap"] { params.institutionPenaltyCap = v }
        if let v = payload.params["embraced_research_bonus"] { params.embracedResearchBonus = v }
        if let v = payload.params["embrace_min_dev_share"] { params.embraceMinDevShare = v }
        if let v = payload.params["embrace_ducats_per_dev"] { params.embraceDucatsPerDev = v }
        if let v = payload.params["embrace_min_cost"] { params.embraceMinCost = v }
        rules.params = params

        var trackTables: [[TechLevelDef]] = []
        for track in TechTrack.allCases {
            guard let rawLevels = payload.tracks[track.key], rawLevels.count == TechRules.maxLevel else {
                throw LoadError.badTrack(track.key)
            }
            let sorted = rawLevels.sorted { $0.level < $1.level }
            trackTables.append(sorted.map { entry in
                var eff = TechEffects()
                if let v = entry.effects["tax_eff"] { eff.taxEff = v }
                if let v = entry.effects["prod_eff"] { eff.prodEff = v }
                if let v = entry.effects["trade_eff"] { eff.tradeEff = v }
                if let v = entry.effects["trade_range"] { eff.tradeRange = Int(v.rounded()) }
                if let v = entry.effects["admin_eff"] { eff.adminEff = v }
                if let v = entry.effects["max_building"] { eff.maxBuilding = Int(v.rounded()) }
                if let v = entry.effects["max_fort"] { eff.maxFort = Int(v.rounded()) }
                if let v = entry.effects["tactics"] { eff.tactics = v }
                if let v = entry.effects["land_morale"] { eff.landMorale = v }
                if let v = entry.effects["relations"] { eff.relations = Int(v.rounded()) }
                if let v = entry.effects["accepted_cultures"] { eff.acceptedCultures = Int(v.rounded()) }
                if let v = entry.effects["reform_progress"] { eff.reformProgress = v }
                return TechLevelDef(
                    level: entry.level,
                    targetYear: entry.targetYear,
                    baseCost: entry.baseCost,
                    effects: eff,
                    summary: entry.summary
                )
            })
        }
        rules.tracks = trackTables
        rules.regionStart = payload.startingLevels.regions
        for (govKey, vals) in payload.startingLevels.govCaps {
            if let gov = GovernmentType(rawValue: govKey) {
                rules.govCaps[gov] = vals
            }
        }
        rules.countryStart = payload.startingLevels.countries

        for (idx, inst) in payload.institutions.enumerated() {
            let origin: InstitutionOriginRule
            switch inst.origin.kind {
            case "region":
                origin = .region(inst.origin.value)
            case "province":
                guard let pidx = inst.origin.provinceIndex, pidx >= 0, pidx < P else {
                    throw LoadError.badOrigin(inst.origin.value)
                }
                origin = .province(ProvinceID(pidx))
            case "dynamic":
                origin = .dynamic(inst.origin.value)
            default:
                throw LoadError.badOrigin(inst.origin.kind)
            }
            rules.institutions.append(InstitutionDef(
                index: idx,
                key: inst.key,
                name: inst.name,
                spawnYear: inst.spawnYear,
                origin: origin,
                spreadNeighbour: inst.spreadNeighbour,
                spreadTrade: inst.spreadTrade,
                spreadBurgher: inst.spreadBurgher,
                summary: inst.summary
            ))
        }

        world.techRules = rules
        applyInitialState(into: &world)
    }

    /// Initializes starting tech levels and 1453 active institutions from `world.techRules`.
    public static func applyInitialState(into world: inout World) {
        let C = world.countries.count
        let P = world.provinces.count
        let I = world.techRules.institutions.count
        var state = TechState()
        state.resize(countries: C, provinces: P, institutions: I)

        let rules = world.techRules
        for c in world.countries.ids {
            let tag = world.countries.tag[c.index]
            let gov = world.countries.government[c.index]
            let capRegion: String? = world.countries.capital[c.index].map { world.regionName(of: $0) }
            let vals: [Int]
            if let override = rules.countryStart[tag], override.count == 3 {
                vals = override
            } else {
                var base = capRegion.flatMap { rules.regionStart[$0] } ?? [3, 3, 3]
                if let cap = rules.govCaps[gov], cap.count == 3 {
                    base = [min(base[0], cap[0]), min(base[1], cap[1]), min(base[2], cap[2])]
                }
                vals = base
            }
            for track in TechTrack.allCases {
                state.setLevel(c, track, vals[track.rawValue])
            }
            // Start AI focus sensibly; player defaults to balanced.
            state.setFocus(of: c, to: .balanced)
        }

        // Seed institutions already active in 1453 (e.g., Renaissance in Italy).
        for inst in rules.institutions where inst.spawnYear <= Scenario1453.startDate.year {
            state.institutionSpawned[inst.index] = true
            state.institutionSpawnYear[inst.index] = inst.spawnYear
            if case .region(let regName) = inst.origin {
                var originProv: ProvinceID?
                var bestDev = -1
                for p in 0..<P {
                    let pid = ProvinceID(p)
                    if world.regionName(of: pid) == regName {
                        state.setProvincePresence(pid, institution: inst.index, 1.0)
                        let dev = world.provinces.development[p]
                        if dev > bestDev {
                            bestDev = dev
                            originProv = pid
                        }
                    }
                }
                state.institutionOrigin[inst.index] = originProv
                for c in world.countries.ids {
                    if let cap = world.countries.capital[c.index], world.regionName(of: cap) == regName {
                        state.setEmbraced(c, institution: inst.index, true)
                    }
                }
            } else if case .province(let pid) = inst.origin {
                state.institutionOrigin[inst.index] = pid
                state.setProvincePresence(pid, institution: inst.index, 1.0)
                if let owner = world.provinces.owner[pid.index] {
                    state.setEmbraced(owner, institution: inst.index, true)
                }
            }
        }

        world.tech = state
    }
}
