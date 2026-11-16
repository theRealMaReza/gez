import Foundation

/// Phase 12 state: plague (Part A), famine and earthquakes (Part B).
/// Everything is stored per province in flat arrays, like `ProvinceTable`.
/// The fixed earthquake data (`CalamityRules`) comes from
/// `Resources/calamity1453.json` (built by `tools/calamity/calamitygen.py`
/// from `data/calamity/fault_zones.txt`).

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

/// Tuning for harvests and famine.
public enum FamineModel {
    /// The harvest is judged once a year, on 1 August.
    public static let harvestMonth = 8
    /// Months when men away with the levies leave crops standing in the field.
    public static let harvestSeason = 7...9
    /// A region's harvest: 1 on average, about 0.10 up or down in most years.
    public static let regionSpread = 0.20
    public static let stateSpread = 0.10
    public static let worstHarvest = 0.6
    public static let bestHarvest = 1.2
    /// Each harvest month the levies stay raised costs this share of the crop.
    public static let levyLossPerMonth = 0.08
    /// Fully devastated land grows this much less.
    public static let devastationLoss = 0.5
    /// Besiegers and occupiers take their share of the crop.
    public static let lootingFactor = 0.7
    /// Famine starts when staple food falls below this share of what the
    /// market is used to; each point further below adds `famineSlope` points.
    public static let famineBelow = 0.9
    public static let famineSlope = 3.0
    public static let famineDecay = 0.15
    /// How fast "what the market is used to" follows the real supply.
    public static let normSpeed = 0.02
    /// Share of peasants dying per month in the worst famine.
    public static let monthlyDeaths = 0.006
    public static let moodHit = 0.04
    /// A famine this bad is worth an alert.
    public static let alertAbove = 0.35

    /// The poor starve first.
    public static func classDeaths(_ c: SocialClass) -> Double {
        switch c {
        case .nobles: return 0.2
        case .clergy: return 0.4
        case .burghers: return 0.8
        case .peasants: return 1.0
        case .slaves: return 1.3
        }
    }
}

/// Tuning for earthquakes.
public enum QuakeModel {
    /// Neighbours of the epicentre feel this share of the shock.
    public static let neighbourShare = 0.5
    /// At full strength each building level falls with this chance.
    public static let buildingLoss = 0.45
    /// Share of the people killed at full strength.
    public static let deaths = 0.03
    public static let devastation = 0.25
}

/// Land where the earth shakes.
public struct FaultZone: Sendable, Equatable {
    public let name: String
    /// Chance of a damaging earthquake in a year.
    public let yearlyChance: Double
    /// 0 to 1: how bad the worst earthquake here can be.
    public let strength: Double
    public let provinces: [ProvinceID]

    public init(name: String, yearlyChance: Double, strength: Double, provinces: [ProvinceID]) {
        self.name = name
        self.yearlyChance = yearlyChance
        self.strength = strength
        self.provinces = provinces
    }
}

/// An earthquake history records; it strikes on its date.
public struct HistoricalQuake: Sendable, Equatable {
    public let name: String
    public let date: GameDate
    public let province: ProvinceID
    public let strength: Double

    public init(name: String, date: GameDate, province: ProvinceID, strength: Double) {
        self.name = name
        self.date = date
        self.province = province
        self.strength = strength
    }
}

/// Fixed data (the same in every game, not saved).
public struct CalamityRules: Sendable, Equatable {
    public var faultZones: [FaultZone] = []
    public var historicalQuakes: [HistoricalQuake] = []
    public init() {}
}

/// What an earthquake did.
public struct QuakeRecord: Sendable, Equatable, Codable {
    public var date: GameDate
    public var name: String
    public var epicentre: ProvinceID
    public var strength: Double
    public var deaths: Double
    public var buildingLevelsLost: Int
    public var fortLevelsLost: Int
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

    // Famine (Part B).
    /// This year's harvest per province (1 = a normal year).
    public var harvest: [Double] = []
    /// Share of this year's crop lost because the levies were away at harvest.
    public var levyHarvestLoss: [Double] = []
    /// Staple food grown compared to normal, all causes together; the
    /// market multiplies farm output by it.
    public var stapleFactor: [Double] = []
    /// Staple supply ÷ demand each market is used to (0 = not yet measured).
    public var stapleNorm: [Double] = []
    /// People who starved in the most recent month, per province.
    public var lastFamineDeaths: [Double] = []
    public var totalFamineDeaths: Double = 0
    /// Year of the last harvest roll.
    public var harvestYear: Int = 0

    // Earthquakes (Part B).
    public var totalQuakeDeaths: Double = 0
    /// Newest last, kept short.
    public var quakes: [QuakeRecord] = []
    /// Names of the historical earthquakes that have already struck.
    public var pastHistoricalQuakes: [String] = []

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
        harvest = Self.fit(harvest, n, 1)
        levyHarvestLoss = Self.fit(levyHarvestLoss, n, 0)
        stapleFactor = Self.fit(stapleFactor, n, 1)
        lastFamineDeaths = Self.fit(lastFamineDeaths, n, 0)
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

    /// Farm output of staple food compared to normal (1 until measured).
    @inline(__always)
    public func stapleYieldFactor(_ p: Int) -> Double {
        p >= 0 && p < stapleFactor.count ? stapleFactor[p] : 1
    }

    public mutating func addNote(_ note: CalamityNote) {
        notes.append(note)
        if notes.count > 60 { notes.removeFirst(notes.count - 60) }
    }
}

extension World {
    /// The calamities' own stream of random numbers: split off the game's
    /// stream the first time (reading its state uses up none of its
    /// numbers), then carried on from month to month.
    mutating func beginCalamityRandom(_ random: GameRandom) -> GameRandom {
        if !calamity.seeded {
            calamity.rngState = random.rawState ^ 0x5DEE_CE66_D1CE_4E5B
            calamity.seeded = true
        }
        return GameRandom(seed: calamity.rngState)
    }

    mutating func endCalamityRandom(_ rng: GameRandom) {
        calamity.rngState = rng.rawState
    }
}
