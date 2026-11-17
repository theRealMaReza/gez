import Foundation

/// Loads condition-triggered historical and chronicle event definitions from
/// `Resources/events1453.json` (built by `tools/events/eventgen.py`).
public enum EventLoader {
    public enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case wrongMap(file: Int, world: Int)
        case unknownTag(String)
        case unknownCategory(String)

        public var description: String {
            switch self {
            case .missingResource:
                return "Missing events1453.json resource in GezCore bundle."
            case .wrongMap(let file, let world):
                return "events1453.json was built for \(file) provinces but the map has \(world); run tools/events/eventgen.py."
            case .unknownTag(let tag):
                return "events1453.json references unknown country tag '\(tag)'."
            case .unknownCategory(let cat):
                return "events1453.json references unknown event category '\(cat)'."
            }
        }
    }

    private struct DatePayload: Decodable {
        let year: Int
        let month: Int
        let day: Int

        var gameDate: GameDate { GameDate(year: year, month: month, day: day) }
    }

    private struct AIModPayload: Decodable {
        let condition: EventCondition
        let op: EventAIWeightModifier.Op
        let value: Double
    }

    private struct MTTHModPayload: Decodable {
        let condition: EventCondition
        let factor: Double
    }

    private struct OptionPayload: Decodable {
        let label: String
        let aiWeight: Double
        let aiModifiers: [AIModPayload]
        let effects: [EventEffect]
    }

    private struct EventPayload: Decodable {
        let id: String
        let title: String
        let text: String
        let category: String
        let countries: [String]
        let dateFrom: DatePayload?
        let dateTo: DatePayload?
        let exactDate: DatePayload?
        let mtth: Double
        let mtthModifiers: [MTTHModPayload]
        let fireOnce: Bool
        let perCountry: Bool
        let triggeredOnly: Bool
        let major: Bool
        let trigger: [EventCondition]
        let options: [OptionPayload]
    }

    private struct FilePayload: Decodable {
        let provinceCount: Int
        let events: [EventPayload]
    }

    public static func loadBundled(into world: inout World) throws {
        guard let url = GezResources.url(forResource: "events1453", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try load(from: Data(contentsOf: url), into: &world)
    }

    public static func load(from data: Data, into world: inout World) throws {
        let payload = try JSONDecoder().decode(FilePayload.self, from: data)
        guard payload.provinceCount == world.provinces.count else {
            throw LoadError.wrongMap(file: payload.provinceCount, world: world.provinces.count)
        }

        var defs: [EventDef] = []
        defs.reserveCapacity(payload.events.count)
        for item in payload.events {
            guard let cat = EventCategory(rawValue: item.category) else {
                throw LoadError.unknownCategory(item.category)
            }
            var cids: [CountryID] = []
            cids.reserveCapacity(item.countries.count)
            for tag in item.countries {
                guard let cid = world.countries.id(forTag: tag) else {
                    throw LoadError.unknownTag(tag)
                }
                cids.append(cid)
            }
            let opts = item.options.map { opt in
                EventOptionDef(
                    label: opt.label,
                    aiWeight: opt.aiWeight,
                    aiModifiers: opt.aiModifiers.map {
                        EventAIWeightModifier(condition: $0.condition, op: $0.op, value: $0.value)
                    },
                    effects: opt.effects
                )
            }
            let mtthMods = item.mtthModifiers.map {
                EventMTTHModifier(condition: $0.condition, factor: $0.factor)
            }
            defs.append(EventDef(
                id: item.id,
                title: item.title,
                text: item.text,
                category: cat,
                countryTags: item.countries,
                countryIDs: cids,
                dateFrom: item.dateFrom?.gameDate,
                dateTo: item.dateTo?.gameDate,
                exactDate: item.exactDate?.gameDate,
                mtth: item.mtth,
                mtthModifiers: mtthMods,
                fireOnce: item.fireOnce,
                perCountry: item.perCountry,
                triggeredOnly: item.triggeredOnly,
                major: item.major,
                trigger: item.trigger,
                options: opts
            ))
        }

        var rules = EventRules()
        rules.events = defs
        rules.rebuildIndexes(countryCount: world.countries.count)
        world.eventRules = rules
        world.events.resize(countries: world.countries.count)
    }
}
