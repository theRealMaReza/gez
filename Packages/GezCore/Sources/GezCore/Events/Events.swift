import Foundation

/// Categories for historical and triggered narrative events (Phase 14).
public enum EventCategory: String, CaseIterable, Sendable, Codable {
    case historical
    case dynastic
    case religious
    case military
    case diplomatic
    case internalAffairs = "internal"
    case calamity

    public var displayName: String {
        switch self {
        case .historical: return "Historical"
        case .dynastic: return "Dynastic"
        case .religious: return "Religious"
        case .military: return "Military"
        case .diplomatic: return "Diplomatic"
        case .internalAffairs: return "Internal"
        case .calamity: return "Calamity"
        }
    }
}

/// Fixed, reusable condition vocabulary shared by events and future mission trees.
public struct EventCondition: Sendable, Equatable, Codable {
    public let kind: String
    public let str: String?
    public let int: Int?
    public let num: Double?
    public let bool: Bool?

    public init(
        kind: String,
        str: String? = nil,
        int: Int? = nil,
        num: Double? = nil,
        bool: Bool? = nil
    ) {
        self.kind = kind
        self.str = str
        self.int = int
        self.num = num
        self.bool = bool
    }
}

/// Target selector for province-scoped effects.
public enum EventProvinceTarget: String, Sendable, Equatable, Codable {
    case capital
    case all
    case province
    case context
}

/// Fixed, reusable effect vocabulary shared by events and future mission trees.
public struct EventEffect: Sendable, Equatable, Codable {
    public let kind: String
    public let target: String?
    public let str: String?
    public let str2: String?
    public let int: Int?
    public let int2: Int?
    public let num: Double?
    public let mods: [String: Double]?

    public init(
        kind: String,
        target: String? = nil,
        str: String? = nil,
        str2: String? = nil,
        int: Int? = nil,
        int2: Int? = nil,
        num: Double? = nil,
        mods: [String: Double]? = nil
    ) {
        self.kind = kind
        self.target = target
        self.str = str
        self.str2 = str2
        self.int = int
        self.int2 = int2
        self.num = num
        self.mods = mods
    }
}

public struct EventAIWeightModifier: Sendable, Equatable, Codable {
    public enum Op: String, Sendable, Equatable, Codable {
        case mul
        case add
    }

    public let condition: EventCondition
    public let op: Op
    public let value: Double

    public init(condition: EventCondition, op: Op, value: Double) {
        self.condition = condition
        self.op = op
        self.value = value
    }
}

public struct EventMTTHModifier: Sendable, Equatable, Codable {
    public let condition: EventCondition
    public let factor: Double

    public init(condition: EventCondition, factor: Double) {
        self.condition = condition
        self.factor = factor
    }
}

public struct EventOptionDef: Sendable, Equatable {
    public let label: String
    public let aiWeight: Double
    public let aiModifiers: [EventAIWeightModifier]
    public let effects: [EventEffect]

    public init(
        label: String,
        aiWeight: Double,
        aiModifiers: [EventAIWeightModifier] = [],
        effects: [EventEffect] = []
    ) {
        self.label = label
        self.aiWeight = aiWeight
        self.aiModifiers = aiModifiers
        self.effects = effects
    }
}

public struct EventDef: Sendable, Equatable {
    public let id: String
    public let title: String
    public let text: String
    public let category: EventCategory
    /// Empty means any country may be tested (subject to `trigger`).
    public let countryTags: [String]
    /// Pre-resolved country IDs matching `countryTags` for fast monthly dispatch.
    public let countryIDs: [CountryID]
    public let dateFrom: GameDate?
    public let dateTo: GameDate?
    public let exactDate: GameDate?
    /// Mean time to happen in months (`0` = fires immediately once conditions pass).
    public let mtth: Double
    public let mtthModifiers: [EventMTTHModifier]
    public let fireOnce: Bool
    public let perCountry: Bool
    public let triggeredOnly: Bool
    public let major: Bool
    public let trigger: [EventCondition]
    public let options: [EventOptionDef]

    public init(
        id: String,
        title: String,
        text: String,
        category: EventCategory,
        countryTags: [String] = [],
        countryIDs: [CountryID] = [],
        dateFrom: GameDate? = nil,
        dateTo: GameDate? = nil,
        exactDate: GameDate? = nil,
        mtth: Double = 12,
        mtthModifiers: [EventMTTHModifier] = [],
        fireOnce: Bool = true,
        perCountry: Bool = false,
        triggeredOnly: Bool = false,
        major: Bool = false,
        trigger: [EventCondition] = [],
        options: [EventOptionDef]
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.category = category
        self.countryTags = countryTags
        self.countryIDs = countryIDs
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.exactDate = exactDate
        self.mtth = mtth
        self.mtthModifiers = mtthModifiers
        self.fireOnce = fireOnce
        self.perCountry = perCountry
        self.triggeredOnly = triggeredOnly
        self.major = major
        self.trigger = trigger
        self.options = options
    }
}

/// Immutable event definitions and pre-indexed lookup tables (not saved).
public struct EventRules: Sendable {
    public var events: [EventDef] = []
    public var indexByID: [String: Int] = [:]
    /// Event indices restricted to specific countries, indexed by `CountryID.index`.
    public var eventsByCountry: [[Int]] = []
    /// Event indices without a country whitelist (evaluated across eligible countries).
    public var globalCandidateIndices: [Int] = []

    public init() {}

    public func event(id: String) -> EventDef? {
        guard let idx = indexByID[id] else { return nil }
        return events[idx]
    }

    public mutating func rebuildIndexes(countryCount: Int) {
        indexByID = [:]
        eventsByCountry = Array(repeating: [], count: max(0, countryCount))
        globalCandidateIndices = []
        for (idx, ev) in events.enumerated() {
            indexByID[ev.id] = idx
            guard !ev.triggeredOnly else { continue }
            if ev.countryIDs.isEmpty {
                globalCandidateIndices.append(idx)
            } else {
                for cid in ev.countryIDs where cid.index >= 0 && cid.index < countryCount {
                    eventsByCountry[cid.index].append(idx)
                }
            }
        }
    }
}

/// Timed country modifier granted by an event (or future mission).
public struct ActiveEventModifier: Sendable, Equatable, Codable {
    public var country: CountryID
    public var key: String
    public var name: String
    public var expiry: GameDate
    /// Values indexed by `Modifier.rawValue`.
    public var values: [Double]

    public init(country: CountryID, key: String, name: String, expiry: GameDate, values: [Double]) {
        self.country = country
        self.key = key
        self.name = name
        self.expiry = expiry
        self.values = values
    }
}

/// Timed Casus Belli granted by an event (or future mission).
public struct GrantedEventCB: Sendable, Equatable, Codable {
    public var country: CountryID
    public var target: CountryID
    public var casusBelli: CasusBelli
    public var expiry: GameDate

    public init(country: CountryID, target: CountryID, casusBelli: CasusBelli, expiry: GameDate) {
        self.country = country
        self.target = target
        self.casusBelli = casusBelli
        self.expiry = expiry
    }
}

/// A concrete pending choice awaiting a player (or queued for AI resolution).
public struct PendingEvent: Sendable, Equatable, Codable {
    public var instanceID: Int
    public var eventID: String
    public var country: CountryID
    public var date: GameDate
    public var title: String
    public var text: String
    public var category: EventCategory
    public var contextProvince: ProvinceID?
    public var options: [PendingEventOption]

    public init(
        instanceID: Int,
        eventID: String,
        country: CountryID,
        date: GameDate,
        title: String,
        text: String,
        category: EventCategory,
        contextProvince: ProvinceID? = nil,
        options: [PendingEventOption]
    ) {
        self.instanceID = instanceID
        self.eventID = eventID
        self.country = country
        self.date = date
        self.title = title
        self.text = text
        self.category = category
        self.contextProvince = contextProvince
        self.options = options
    }
}

public struct PendingEventOption: Sendable, Equatable, Codable {
    public var label: String
    public var tooltip: String
    public var aiWeight: Double
    public var effects: [EventEffect]

    public init(label: String, tooltip: String, aiWeight: Double, effects: [EventEffect]) {
        self.label = label
        self.tooltip = tooltip
        self.aiWeight = aiWeight
        self.effects = effects
    }
}

/// History entry of resolved events for the alerts-area "Recent Events" list.
public struct RecentEventEntry: Sendable, Equatable, Codable {
    public var date: GameDate
    public var country: CountryID
    public var eventID: String
    public var title: String
    public var category: EventCategory
    public var chosenLabel: String
    public var effectSummary: String
    public var major: Bool

    public init(
        date: GameDate,
        country: CountryID,
        eventID: String,
        title: String,
        category: EventCategory,
        chosenLabel: String,
        effectSummary: String,
        major: Bool
    ) {
        self.date = date
        self.country = country
        self.eventID = eventID
        self.title = title
        self.category = category
        self.chosenLabel = chosenLabel
        self.effectSummary = effectSummary
        self.major = major
    }
}

/// Mutable event state stored on `World` and persisted in saves.
public struct EventsState: Sendable, Equatable, Codable {
    public var countryCount: Int = 0
    public var firedGlobal: Set<String> = []
    public var firedPerCountry: [Set<String>] = []
    public var countryFlags: [Set<String>] = []
    public var globalFlags: Set<String> = []
    public var activeModifiers: [ActiveEventModifier] = []
    public var grantedCBs: [GrantedEventCB] = []
    public var pending: [PendingEvent] = []
    public var recent: [RecentEventEntry] = []
    public var nextInstanceID: Int = 1
    public var firedTotal: Int = 0
    public var firedByCategory: [String: Int] = [:]

    /// Dedicated deterministic RNG stream so event rolls never shift main `Simulation.random`.
    public var rngState: UInt64 = 0
    public var seeded: Bool = false

    public init() {}

    public mutating func resize(countries c: Int) {
        if firedPerCountry.count < c {
            firedPerCountry.append(contentsOf: repeatElement([], count: c - firedPerCountry.count))
        } else if firedPerCountry.count > c {
            firedPerCountry = Array(firedPerCountry.prefix(c))
        }
        if countryFlags.count < c {
            countryFlags.append(contentsOf: repeatElement([], count: c - countryFlags.count))
        } else if countryFlags.count > c {
            countryFlags = Array(countryFlags.prefix(c))
        }
        countryCount = c
    }

    public func hasFlag(_ flag: String, for country: CountryID) -> Bool {
        guard country.index >= 0, country.index < countryFlags.count else { return false }
        return countryFlags[country.index].contains(flag)
    }

    public mutating func setFlag(_ flag: String, for country: CountryID, active: Bool = true) {
        guard country.index >= 0, country.index < countryFlags.count else { return }
        if active {
            countryFlags[country.index].insert(flag)
        } else {
            countryFlags[country.index].remove(flag)
        }
    }

    public func modifiers(for country: CountryID) -> [ActiveEventModifier] {
        activeModifiers.filter { $0.country == country }
    }

    public func pendingEvent(for country: CountryID) -> PendingEvent? {
        pending.first { $0.country == country }
    }

    public func recentEvents(for country: CountryID, limit: Int = 12) -> [RecentEventEntry] {
        var out: [RecentEventEntry] = []
        for item in recent.reversed() where item.country == country {
            out.append(item)
            if out.count >= limit { break }
        }
        return out
    }

    public mutating func recordRecent(_ entry: RecentEventEntry) {
        recent.append(entry)
        if recent.count > 160 {
            recent.removeFirst(recent.count - 160)
        }
    }
}

extension World {
    /// Dedicated RNG stream for historical and narrative events, split off `Simulation.random`
    /// without consuming numbers from the main stream.
    mutating func beginEventRandom(_ random: GameRandom) -> GameRandom {
        if !events.seeded {
            events.rngState = random.rawState ^ 0xE7E4_1453_5B9C_2D01
            events.seeded = true
        }
        return GameRandom(seed: events.rngState)
    }

    mutating func endEventRandom(_ rng: GameRandom) {
        events.rngState = rng.rawState
    }
}
