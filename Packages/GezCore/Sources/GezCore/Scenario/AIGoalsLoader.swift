import Foundation

/// Loads historical AI goal lists from `Resources/ai_goals1453.json`
/// (built by `tools/ai/aigen.py` from `data/ai/goals_1453.txt`).
public enum AIGoalsLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case wrongMap(file: Int, world: Int)
        case unknownTag(String)
        case unknownProvince(String)
        case unknownGoalType(String)
        case unknownBuildTarget(String)

        public var description: String {
            switch self {
            case .missingResource:
                return "Missing ai_goals1453.json resource in GezCore bundle."
            case .wrongMap(let file, let world):
                return "ai_goals1453.json was built for \(file) provinces but the map has \(world); run tools/ai/aigen.py."
            case .unknownTag(let tag):
                return "ai_goals1453.json references unknown country tag '\(tag)'."
            case .unknownProvince(let prov):
                return "ai_goals1453.json references unknown province '\(prov)'."
            case .unknownGoalType(let raw):
                return "ai_goals1453.json references unknown goal type '\(raw)'."
            case .unknownBuildTarget(let raw):
                return "ai_goals1453.json references unknown build_up target '\(raw)'."
            }
        }
    }

    private struct DatePayload: Decodable {
        let year: Int
        let month: Int
        let day: Int

        var gameDate: GameDate { GameDate(year: year, month: month, day: day) }
    }

    private struct GoalPayload: Decodable {
        let id: String
        let country: String
        let type: String
        let target: String
        let earliestDate: DatePayload
        let giveUpDate: DatePayload
        let priority: Int
        let note: String?
    }

    private struct FilePayload: Decodable {
        let provinceCount: Int
        let goals: [GoalPayload]
    }

    public static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "ai_goals1453", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world)
    }

    public static func load(from data: Data, into world: inout World) throws {
        let payload = try JSONDecoder().decode(FilePayload.self, from: data)
        guard payload.provinceCount == world.provinces.count else {
            throw LoadError.wrongMap(file: payload.provinceCount, world: world.provinces.count)
        }

        var defs: [AIGoalDef] = []
        defs.reserveCapacity(payload.goals.count)

        for item in payload.goals {
            guard let cid = world.countries.id(forTag: item.country) else {
                throw LoadError.unknownTag(item.country)
            }
            guard let gtype = AIGoalType(rawValue: item.type) else {
                throw LoadError.unknownGoalType(item.type)
            }

            var targetProv: ProvinceID?
            var targetCountry: CountryID?
            var buildFocus: AIGoalBuildFocus?

            switch gtype {
            case .conquerProvince, .defendProvince:
                guard let pid = world.provinces.id(named: item.target) else {
                    throw LoadError.unknownProvince(item.target)
                }
                targetProv = pid
            case .allyWith, .vassalize, .keepPeaceWith:
                guard let tid = world.countries.id(forTag: item.target) else {
                    throw LoadError.unknownTag(item.target)
                }
                targetCountry = tid
            case .buildUp:
                guard let focus = AIGoalBuildFocus(rawValue: item.target) else {
                    throw LoadError.unknownBuildTarget(item.target)
                }
                buildFocus = focus
            }

            defs.append(AIGoalDef(
                id: item.id,
                country: cid,
                type: gtype,
                target: item.target,
                targetProvince: targetProv,
                targetCountry: targetCountry,
                buildFocus: buildFocus,
                earliestDate: item.earliestDate.gameDate,
                giveUpDate: item.giveUpDate.gameDate,
                priority: item.priority,
                note: item.note ?? ""
            ))
        }

        world.aiRules.setGoals(defs, countryCount: world.countries.count)
        world.ai.resize(countries: world.countries.count)
    }
}
