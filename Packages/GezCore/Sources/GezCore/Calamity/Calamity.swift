import Foundation

/// Phase 12 state: plague (Part A), famine and earthquakes (Part B).
/// Everything is stored per province in flat arrays, like `ProvinceTable`.

/// The three sicknesses of the game.
public enum Disease: Int, CaseIterable, Sendable, Codable {
    /// Bubonic plague: the great killer of cities and ports.
    case plague
    /// Typhus ("camp fever"): born in sieges, army camps and famines.
    case typhus
    /// Smallpox: strikes each generation that has not met it.
    case smallpox

    public var key: String {
        switch self {
        case .plague: return "plague"
        case .typhus: return "typhus"
        case .smallpox: return "smallpox"
        }
    }

    public var displayName: String {
        switch self {
        case .plague: return "Plague"
        case .typhus: return "Camp fever"
        case .smallpox: return "Smallpox"
        }
    }
}

/// The numbers of one disease.
public struct DiseaseRule: Sendable {
    /// Months an outbreak lasts in a province.
    public let months: Int
    /// Share of the people struck in a crowded town that never met it.
    public let attack: Double
    /// Share of the struck who die (peasants; other classes differ).
    public let lethality: Double
    /// Share of a province's immunity lost each month.
    public let immunityFade: Double
    /// Monthly chance of a fresh outbreak in a crowded province.
    public let originChance: Double
}

/// Tuning for plague. `tools/calamity/plague_prototype.py` is a Python
/// copy used for balancing; keep the two in step.
public enum PlagueModel {
    public static func rule(_ d: Disease) -> DiseaseRule {
        switch d {
        case .plague:
            return DiseaseRule(months: 9, attack: 0.30, lethality: 0.35, immunityFade: 0.0030, originChance: 0.0005)
        case .typhus:
            return DiseaseRule(months: 6, attack: 0.20, lethality: 0.15, immunityFade: 0.0100, originChance: 0)
        case .smallpox:
            return DiseaseRule(months: 7, attack: 0.35, lethality: 0.12, immunityFade: 0.0015, originChance: 0.0003)
        }
    }

    /// A province can only be struck when at least this share is not immune.
    public static let minSusceptible = 0.45
    /// After an outbreak the province counts as this immune (survivors plus
    /// the people it never reached); it fades from there over the years.
    public static let immunityAfter = 0.75
    /// Never more than this share struck in one outbreak.
    public static let maxAttack = 0.6
    /// Fresh outbreaks need a crowded place: a big town, or a busy coast.
    public static let crowdedDevelopment = 7
    public static let crowdedCoastDevelopment = 5

    /// Spread chances are `min(cap, k × share struck this month)`.
    public static let neighbourSpread = 3.0
    public static let neighbourSpreadCap = 0.12
    public static let routeSpread = 4.0
    public static let routeSpreadCap = 0.20
    public static let seaSpread = 3.0
    public static let seaSpreadCap = 0.12
    /// Camp fever travels less from village to village.
    public static let typhusNeighbourFactor = 0.5
    /// A port quarantine or a cordon lets this share of the spread through.
    public static let quarantineLeak = 0.2
    public static let cordonLeak = 0.25
    /// An army that stood in a struck province carries the sickness this long.
    public static let carrierMonths = 3
    public static let carrierSpreadChance = 0.5
    /// Soldiers in camp die this much faster than townsfolk.
    public static let campLethality = 1.5

    /// Camp fever starts in sieges, overcrowded camps and famines.
    public static let typhusSiegeChance = 0.06
    public static let typhusCampChance = 0.04
    public static let typhusFamineChance = 0.01
    public static let typhusCampSoldiers = 15_000
    public static let typhusFamineAbove = 0.4

    /// Costs and penalties of the two answers a ruler has.
    public static let quarantineTaxFactor = 0.85
    public static let quarantineSeaTradeFactor = 0.5
    public static let cordonTaxFactor = 0.90
    public static let cordonMarchFactor = 1.5

    /// A courtier in a struck capital dies with chance `this × share struck` a month.
    public static let courtDeathFactor = 0.12

    /// The poor die more: the well-fed and well-housed can leave or hide.
    public static func classLethality(_ c: SocialClass) -> Double {
        switch c {
        case .nobles: return 0.5
        case .clergy: return 0.85
        case .burghers: return 0.9
        case .peasants: return 1.0
        case .slaves: return 1.25
        }
    }

    /// Bigger, denser places are struck harder (development 1 → 0.35, 10 → 1.25).
    public static func crowding(development: Int) -> Double {
        0.25 + 0.10 * Double(min(max(development, 1), 10))
    }

    /// How the struck are spread over the months of an outbreak: slow start,
    /// a peak in the middle, slow end. The shares of all months add up to 1.
    public static func courseWeight(months n: Int, month t: Int) -> Double {
        guard n > 0, t >= 0, t < n else { return 0 }
        func raw(_ k: Int) -> Double { (Double(k) + 0.5) * (Double(n - k) - 0.5) }
        var total = 0.0
        for k in 0..<n { total += raw(k) }
        return total > 0 ? raw(t) / total : 0
    }

    public static func quarantineCost(development: Int) -> Double { 0.4 + 0.08 * Double(development) }
    public static func cordonCost(development: Int) -> Double { 0.6 + 0.06 * Double(development) }
}

/// One line for the alerts and the chronicle: where and when something struck.
public struct CalamityNote: Sendable, Equatable, Codable {
    public var date: GameDate
    public var province: ProvinceID
    /// "plague", "typhus", "smallpox" (later parts add "famine", "earthquake").
    public var kind: String
    public var text: String

    public init(date: GameDate, province: ProvinceID, kind: String, text: String) {
        self.date = date
        self.province = province
        self.kind = kind
        self.text = text
    }
}

/// Mutable plague state. Disease arrays are flat: `[province * 3 + disease]`.
public struct CalamityState: Sendable, Equatable, Codable {
    public static let diseaseCount = Disease.allCases.count

    public var provinceCount: Int = 0
    /// Months into the outbreak (1 = first month); 0 = no outbreak.
    public var course: [Int] = []
    /// Share of the province struck over the whole outbreak.
    public var attack: [Double] = []
    /// Share of the province that cannot catch the disease now (0 to 1).
    public var immunity: [Double] = []
    /// Port quarantine: ships wait offshore; less plague by sea, less trade.
    public var quarantine: [Bool] = []
    /// Cordon: guarded roads; less plague by land, slower marches.
    public var cordon: [Bool] = []
    /// People who died of disease in the most recent month, per province.
    public var lastDeaths: [Double] = []
    /// People who died of each disease since the game began.
    public var totalDeaths: [Double] = Array(repeating: 0, count: CalamityState.diseaseCount)
    /// Armies carrying a sickness with them (parallel arrays).
    public var carrierArmy: [Int] = []
    public var carrierDisease: [Int] = []
    public var carrierMonthsLeft: [Int] = []
    /// The calamities' own stream of random numbers (a `GameRandom` state),
    /// split off the game's stream on the first month so that plague rolls
    /// do not reshuffle every other system's luck.
    public var rngState: UInt64 = 0
    public var seeded: Bool = false
    /// Newest last, kept short; for alerts.
    public var notes: [CalamityNote] = []

    public init() {}

    /// Makes room for every province (keeps what is there).
    public mutating func resize(provinces n: Int) {
        guard n != provinceCount || course.count != n * Self.diseaseCount else { return }
        let d = Self.diseaseCount
        course = Self.fit(course, n * d, 0)
        attack = Self.fit(attack, n * d, 0)
        immunity = Self.fit(immunity, n * d, 0)
        quarantine = Self.fit(quarantine, n, false)
        cordon = Self.fit(cordon, n, false)
        lastDeaths = Self.fit(lastDeaths, n, 0)
        if totalDeaths.count != d { totalDeaths = Self.fit(totalDeaths, d, 0) }
        provinceCount = n
    }

    private static func fit<T>(_ a: [T], _ n: Int, _ fill: T) -> [T] {
        if a.count == n { return a }
        if a.count > n { return Array(a.prefix(n)) }
        return a + Array(repeating: fill, count: n - a.count)
    }

    @inline(__always)
    public func slot(_ p: Int, _ d: Disease) -> Int { p * Self.diseaseCount + d.rawValue }

    /// Share of the province's people struck this month by `d` (0 = none).
    public func infection(_ p: Int, _ d: Disease) -> Double {
        let k = slot(p, d)
        guard p >= 0, k < course.count, course[k] > 0 else { return 0 }
        return attack[k] * PlagueModel.courseWeight(months: PlagueModel.rule(d).months, month: course[k] - 1)
    }

    public func hasOutbreak(_ p: Int, _ d: Disease) -> Bool {
        let k = slot(p, d)
        return p >= 0 && k < course.count && course[k] > 0
    }

    public func hasAnyOutbreak(_ p: Int) -> Bool {
        Disease.allCases.contains { hasOutbreak(p, $0) }
    }

    /// Share struck this month by all diseases together.
    public func totalInfection(_ p: Int) -> Double {
        var sum = 0.0
        for d in Disease.allCases { sum += infection(p, d) }
        return sum
    }

    public func immunity(_ p: Int, _ d: Disease) -> Double {
        let k = slot(p, d)
        return p >= 0 && k < immunity.count ? immunity[k] : 0
    }

    public func isQuarantined(_ p: Int) -> Bool { p >= 0 && p < quarantine.count && quarantine[p] }
    public func isCordoned(_ p: Int) -> Bool { p >= 0 && p < cordon.count && cordon[p] }

    /// Tax kept in a province under quarantine and/or cordon (1 = all of it).
    public func taxFactor(_ p: Int) -> Double {
        var f = 1.0
        if isQuarantined(p) { f *= PlagueModel.quarantineTaxFactor }
        if isCordoned(p) { f *= PlagueModel.cordonTaxFactor }
        return f
    }

    public mutating func addNote(_ note: CalamityNote) {
        notes.append(note)
        if notes.count > 60 { notes.removeFirst(notes.count - 60) }
    }
}
