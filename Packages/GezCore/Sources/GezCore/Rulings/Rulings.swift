import Foundation

/// Phase 20.8: ruling systems (HRE, Shogunate, Mandate of Heaven, Sejm,
/// kurultai, mandala rings...) and formable nations.
///
/// The fixed rules come from `Resources/rulings1453.json` (built by
/// `tools/rulings/rulinggen.py` from `data/rulings/`). The changing state
/// lives in `RulingState` on `World` and is saved whole. Guide for writing a
/// new system: `docs/RULING_SYSTEMS.md`.

// MARK: - Fixed data (not saved)

/// A modifier bundle that every holder of a role in a ruling system gets.
public struct RulingRoleEffect: Sendable, Equatable {
    /// `member` (every member), `leader`, or any role name from the data.
    public let role: String
    /// Indexed by `Modifier.rawValue`.
    public let values: [Double]
    /// When set, the values are multiplied by `system value / scaleDivisor`.
    public let scaleBy: String?
    public let scaleDivisor: Double

    public init(role: String, values: [Double], scaleBy: String? = nil, scaleDivisor: Double = 1) {
        self.role = role
        self.values = values
        self.scaleBy = scaleBy
        self.scaleDivisor = scaleDivisor
    }
}

/// One ruling system as written in `data/rulings/systems/<key>.txt`.
public struct RulingSystemDef: Sendable, Equatable {
    public let key: String
    public let name: String
    /// Leader on 30 May 1453 (emperor, shogun, Ming emperor...), if any.
    public let leader: CountryID?
    /// Starting role holders. `member` is the plain membership role; every
    /// holder of any role is also a member. Countries are sorted by index.
    public let roles: [String: [CountryID]]
    /// Role names in the order the data lists them (for stable iteration).
    public let roleOrder: [String]
    /// Starting system-wide numbers (Imperial Authority, Mandate...).
    public let values: [String: Double]
    /// Lowest and highest allowed value of a system number.
    public let limits: [String: ClosedRange<Double>]
    /// Fixed constants the Swift code reads (`param(...)`); never saved.
    public let params: [String: Double]
    /// Provinces that belong to the system's lands (Imperial provinces...).
    public let provinces: [ProvinceID]
    public let roleEffects: [RulingRoleEffect]

    public init(
        key: String,
        name: String,
        leader: CountryID? = nil,
        roles: [String: [CountryID]] = [:],
        roleOrder: [String] = [],
        values: [String: Double] = [:],
        limits: [String: ClosedRange<Double>] = [:],
        params: [String: Double] = [:],
        provinces: [ProvinceID] = [],
        roleEffects: [RulingRoleEffect] = []
    ) {
        self.key = key
        self.name = name
        self.leader = leader
        self.roles = roles
        self.roleOrder = roleOrder.isEmpty ? roles.keys.sorted() : roleOrder
        self.values = values
        self.limits = limits
        self.params = params
        self.provinces = provinces
        self.roleEffects = roleEffects
    }

    public func param(_ key: String, default value: Double = 0) -> Double {
        params[key] ?? value
    }
}

/// A nation a country can turn into, as written in `data/rulings/formables/*.txt`.
public struct FormableDef: Sendable, Equatable {
    /// Short key such as `SPA`; never the tag of a 1453 country.
    public let id: String
    public let name: String
    /// Flavour text for the offer pop-up.
    public let text: String
    public let color: RGB
    /// Picture key for the shield (`arms_<shield>.png`); usually `id`.
    public let shield: String
    /// Countries that may form it; empty = any country passing `trigger`.
    public let eligible: [CountryID]
    /// Requirements in the event condition vocabulary.
    public let trigger: [EventCondition]
    /// Switches the government type when formed.
    public let government: GovernmentType?
    /// Reform option keys set on forming (in the new government's tree).
    public let reforms: [String]
    /// Extra effects in the event effect vocabulary (prestige, cores...).
    public let effects: [EventEffect]
    /// Mission tree key for Phase 21 (nil = keep the current one).
    public let missionTree: String?
    /// Computer countries form it as soon as they can.
    public let ai: Bool
    /// Only one country can ever form it.
    public let unique: Bool

    public init(
        id: String,
        name: String,
        text: String = "",
        color: RGB,
        shield: String? = nil,
        eligible: [CountryID] = [],
        trigger: [EventCondition] = [],
        government: GovernmentType? = nil,
        reforms: [String] = [],
        effects: [EventEffect] = [],
        missionTree: String? = nil,
        ai: Bool = true,
        unique: Bool = true
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.color = color
        self.shield = shield ?? id
        self.eligible = eligible
        self.trigger = trigger
        self.government = government
        self.reforms = reforms
        self.effects = effects
        self.missionTree = missionTree
        self.ai = ai
        self.unique = unique
    }
}

/// All ruling systems and formables (same for every game; not saved).
public struct RulingRules: Sendable {
    public private(set) var systems: [RulingSystemDef] = []
    public private(set) var formables: [FormableDef] = []
    private var systemIndexByKey: [String: Int] = [:]
    private var formableIndexByID: [String: Int] = [:]
    /// Formables restricted to named countries, by `CountryID.index`.
    public private(set) var formablesByCountry: [[Int]] = []
    /// Formables any country may try.
    public private(set) var openFormables: [Int] = []

    public init() {}

    public init(systems: [RulingSystemDef], formables: [FormableDef], countryCount: Int) {
        self.systems = systems
        self.formables = formables
        rebuild(countryCount: countryCount)
    }

    public mutating func rebuild(countryCount: Int) {
        systemIndexByKey = [:]
        for (i, s) in systems.enumerated() { systemIndexByKey[s.key] = i }
        formableIndexByID = [:]
        formablesByCountry = Array(repeating: [], count: max(0, countryCount))
        openFormables = []
        for (i, f) in formables.enumerated() {
            formableIndexByID[f.id] = i
            if f.eligible.isEmpty {
                openFormables.append(i)
            } else {
                for c in f.eligible where c.index >= 0 && c.index < countryCount {
                    formablesByCountry[c.index].append(i)
                }
            }
        }
    }

    public func systemIndex(_ key: String) -> Int? { systemIndexByKey[key] }
    public func system(_ key: String) -> RulingSystemDef? { systemIndexByKey[key].map { systems[$0] } }
    public func formableIndex(_ id: String) -> Int? { formableIndexByID[id] }
    public func formable(_ id: String) -> FormableDef? { formableIndexByID[id].map { formables[$0] } }

    /// Formables `country` could try, in data order.
    public func candidates(for country: CountryID) -> [Int] {
        var out = openFormables
        if country.index >= 0 && country.index < formablesByCountry.count {
            out.append(contentsOf: formablesByCountry[country.index])
        }
        return out.sorted()
    }
}

// MARK: - Saved state

/// Changing state of one ruling system. Generic on purpose: a new system
/// stores its numbers here (by key) instead of adding save fields, so
/// adding or changing a system never breaks old saves.
public struct RulingSystemState: Sendable, Equatable, Codable {
    public var key: String
    /// False once the system is dissolved (e.g. the HRE abolished).
    public var active: Bool
    public var leader: CountryID?
    /// Roles held by each country (by `CountryID.index`), sorted;
    /// empty = not a member. Members always hold `member`.
    public var roles: [[String]]
    /// System-wide numbers (Imperial Authority, Mandate...).
    public var values: [String: Double]
    /// Per-country numbers, each array by `CountryID.index`.
    public var countryValues: [String: [Double]]
    /// Named switches (reforms passed, crises under way...).
    public var flags: Set<String>
    /// Free counter for staged systems (reforms passed, ring level...).
    public var stage: Int
    public var leaderSince: GameDate?

    public init(key: String, countryCount: Int) {
        self.key = key
        self.active = true
        self.leader = nil
        self.roles = Array(repeating: [], count: countryCount)
        self.values = [:]
        self.countryValues = [:]
        self.flags = []
        self.stage = 0
        self.leaderSince = nil
    }

    public mutating func resize(countries n: Int) {
        if roles.count < n {
            roles.append(contentsOf: repeatElement([], count: n - roles.count))
        } else if roles.count > n {
            roles = Array(roles.prefix(n))
        }
        for k in countryValues.keys.sorted() {
            var v = countryValues[k] ?? []
            if v.count < n { v.append(contentsOf: repeatElement(0, count: n - v.count)) }
            if v.count > n { v = Array(v.prefix(n)) }
            countryValues[k] = v
        }
        if let l = leader, l.index >= n { leader = nil }
    }

    public func isMember(_ c: CountryID) -> Bool {
        c.index >= 0 && c.index < roles.count && !roles[c.index].isEmpty
    }

    public func hasRole(_ c: CountryID, _ role: String) -> Bool {
        if role == "leader" { return leader == c }
        return c.index >= 0 && c.index < roles.count && roles[c.index].contains(role)
    }

    /// Members in country order.
    public var members: [CountryID] {
        roles.indices.filter { !roles[$0].isEmpty }.map(CountryID.init)
    }

    /// Holders of `role` in country order (`leader` gives the leader).
    public func holders(_ role: String) -> [CountryID] {
        if role == "leader" { return leader.map { [$0] } ?? [] }
        return roles.indices.filter { roles[$0].contains(role) }.map(CountryID.init)
    }
}

/// When and how a country took on a formable's identity.
public struct FormedRecord: Sendable, Equatable, Codable {
    public var country: CountryID
    public var formable: String
    public var date: GameDate
    /// Name before forming (shown in the Chronicle and tooltips).
    public var previousName: String

    public init(country: CountryID, formable: String, date: GameDate, previousName: String) {
        self.country = country
        self.formable = formable
        self.date = date
        self.previousName = previousName
    }
}

/// Everything about ruling systems and formables that changes in play.
/// Saved whole (`SaveSnapshot.rulings`).
public struct RulingState: Sendable, Equatable, Codable {
    public var countryCount: Int = 0
    /// Same order as `RulingRules.systems`.
    public var systems: [RulingSystemState] = []
    /// Formable id each country now is (nil = still its 1453 self).
    public var formedAs: [String?] = []
    /// Every formation so far, oldest first.
    public var formed: [FormedRecord] = []
    /// Phase 21 mission tree key per country (nil = its own tag's tree).
    public var missionTree: [String?] = []
    /// Formables already offered to a human player (by formable id).
    public var offered: [Set<String>] = []
    /// Whether each country owned land at the last monthly check.
    public var hadLand: [Bool] = []
    /// Dedicated random stream (see `World.beginRulingRandom`).
    public var rngState: UInt64 = 0
    public var seeded: Bool = false

    public init() {}

    public mutating func resize(countries n: Int) {
        func fit<T>(_ a: inout [T], _ fill: T) {
            if a.count < n { a.append(contentsOf: repeatElement(fill, count: n - a.count)) }
            if a.count > n { a = Array(a.prefix(n)) }
        }
        fit(&formedAs, nil)
        fit(&missionTree, nil)
        fit(&offered, [])
        fit(&hadLand, false)
        for i in systems.indices { systems[i].resize(countries: n) }
        countryCount = n
    }

    public func system(_ key: String) -> RulingSystemState? {
        systems.first { $0.key == key }
    }
}
