import Foundation

/// Loads holy sites from `Resources/faith1453.json` into `world.faith`.
public enum FaithLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case unknownProvince(String)
        case unknownReligion(String)

        public var description: String {
            switch self {
            case .missingResource: return "Missing faith1453.json resource in GezCore bundle."
            case .unknownProvince(let name): return "Unknown holy site province '\(name)'."
            case .unknownReligion(let name): return "Unknown holy site religion '\(name)'."
            }
        }
    }

    private struct FilePayload: Decodable {
        struct SiteEntry: Decodable {
            let name: String
            let province: String
            let religions: [String]
        }
        let holySites: [SiteEntry]
    }

    public static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "faith1453", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world)
    }

    public static func load(from data: Data, into world: inout World) throws {
        let payload = try JSONDecoder().decode(FilePayload.self, from: data)
        var provByName: [String: ProvinceID] = [:]
        provByName.reserveCapacity(world.provinces.count)
        for p in 0..<world.provinces.count {
            provByName[world.provinces.name[p]] = ProvinceID(p)
        }

        var sites: [HolySite] = []
        var byProv: [Int: [Int]] = [:]
        sites.reserveCapacity(payload.holySites.count)

        for entry in payload.holySites {
            guard let pid = provByName[entry.province] else {
                throw LoadError.unknownProvince(entry.province)
            }
            var rels: [Religion] = []
            for rKey in entry.religions {
                guard let rel = Religion(rawValue: rKey) else {
                    throw LoadError.unknownReligion(rKey)
                }
                rels.append(rel)
            }
            let idx = sites.count
            sites.append(HolySite(name: entry.name, province: pid, religions: rels))
            byProv[pid.index, default: []].append(idx)
        }

        world.faith = FaithState()
        world.faith.holySites = sites
        world.faith.holySitesByProvince = byProv
        world.faith.holySiteCountHeld = Array(repeating: 0, count: world.countries.count)
        world.faith.hussiteCompactsActive = true
        world.faith.hussiteOutcome = .unresolved
        world.faith.safaviyyaPhase = .growing
        world.faith.safaviyyaStrength = 0.25
    }
}
