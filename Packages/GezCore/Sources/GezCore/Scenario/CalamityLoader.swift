import Foundation

/// Loads fault zones and known earthquakes from `Resources/calamity1453.json`
/// (built by `tools/calamity/calamitygen.py`) into `world.calamityRules`.
public enum CalamityLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case wrongMap(file: Int, world: Int)
        case badProvince(String, Int)
        case badDate(String)

        public var description: String {
            switch self {
            case .missingResource:
                return "Missing calamity1453.json resource in GezCore bundle."
            case .wrongMap(let file, let world):
                return "calamity1453.json was built for \(file) provinces but the map has \(world); run tools/calamity/calamitygen.py."
            case .badProvince(let name, let index):
                return "calamity1453.json: '\(name)' names province \(index), which does not exist."
            case .badDate(let name):
                return "calamity1453.json: '\(name)' has an impossible date."
            }
        }
    }

    private struct FilePayload: Decodable {
        struct Zone: Decodable {
            let name: String
            let yearlyChance: Double
            let strength: Double
            let provinces: [Int]
        }
        struct Quake: Decodable {
            let name: String
            let year: Int
            let month: Int
            let day: Int
            let province: Int
            let strength: Double
        }
        let provinceCount: Int
        let faultZones: [Zone]
        let historicalQuakes: [Quake]
    }

    public static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "calamity1453", withExtension: "json") else {
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
        var rules = CalamityRules()
        for z in payload.faultZones {
            for p in z.provinces where p < 0 || p >= P { throw LoadError.badProvince(z.name, p) }
            rules.faultZones.append(FaultZone(name: z.name, yearlyChance: z.yearlyChance, strength: z.strength,
                                              provinces: z.provinces.map(ProvinceID.init)))
        }
        for q in payload.historicalQuakes {
            guard q.province >= 0, q.province < P else { throw LoadError.badProvince(q.name, q.province) }
            guard (1...12).contains(q.month), q.day >= 1, q.day <= GameDate.daysInMonth[q.month - 1] else {
                throw LoadError.badDate(q.name)
            }
            rules.historicalQuakes.append(HistoricalQuake(
                name: q.name, date: GameDate(year: q.year, month: q.month, day: q.day),
                province: ProvinceID(q.province), strength: q.strength))
        }
        world.calamityRules = rules
        world.calamity.resize(provinces: P)
    }
}
