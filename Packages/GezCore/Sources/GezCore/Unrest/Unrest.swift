import Foundation

/// Phase 12 Part C: unrest per province and the rebel factions it feeds.

/// Why a province is restless (or calm). Each cause gives points; the
/// province's unrest (0 to 100) heads for their sum.
public enum UnrestCause: Int, CaseIterable, Sendable {
    case tax, religion, culture, estates, devastation, famine, plague, war, succession, hardship
    /// Calming: soldiers and walls on the spot.
    case garrison
    /// Calming: a recent concession, or fear after a crushed rising.
    case calm

    public var displayName: String {
        switch self {
        case .tax: return "Taxes"
        case .religion: return "Religion"
        case .culture: return "Foreign rule"
        case .estates: return "Disloyal estates"
        case .devastation: return "War damage"
        case .famine: return "Famine"
        case .plague: return "Plague"
        case .war: return "War weariness"
        case .succession: return "Stability and succession"
        case .hardship: return "Unmet needs"
        case .garrison: return "Soldiers and forts"
        case .calm: return "Recent settlement"
        }
    }
}

/// The five kinds of rebels.
public enum RebelKind: Int, CaseIterable, Sendable, Codable {
    case peasants, zealots, separatists, nobles, pretender

    public var displayName: String {
        switch self {
        case .peasants: return "Peasant Rebels"
        case .zealots: return "Religious Zealots"
        case .separatists: return "Cultural Separatists"
        case .nobles: return "Estate Rebels"
        case .pretender: return "Pretender"
        }
    }
}

/// Tuning for unrest and rebels.
public enum UnrestModel {
    /// Unrest moves this share of the way to the sum of its causes each month.
    public static let speed = 0.3
    /// Points per cause.
    public static let taxAbove = 30.0          // per level above normal (weighted by class)
    public static let taxBelow = 12.0          // relief per level below normal
    public static let religionShare = 0.4      // of the province's religious unrest (0–100)
    public static let cultureSameFamily = 6.0  // whole province of an unaccepted kindred culture
    public static let cultureForeign = 14.0    // whole province of an unaccepted foreign culture
    public static let estateScale = 1.2
    public static let estateCap = 20.0
    public static let devastation = 15.0
    public static let famine = 25.0
    public static let plague = 150.0
    public static let plagueCap = 15.0
    public static let warPerMonth = 0.25
    public static let warCap = 12.0
    public static let instability = 4.0        // per point of stability below 0
    public static let stabilityCalm = 2.0      // per point above 0
    public static let minorRuler = 5.0
    public static let noHeir = 2.0
    public static let hardship = 30.0          // per point of satisfaction below 0.6
    public static let soldiersPerThousand = 1.5
    public static let garrisonCap = 12.0
    public static let fortLevel = 1.0
    /// Recent settlements fade by this many points a month.
    public static let calmFade = 0.5

    /// A faction's progress moves by `(pressure − threshold) × rate` a month.
    public static func threshold(_ k: RebelKind) -> Double {
        switch k {
        case .peasants: return 12
        case .zealots: return 30
        case .separatists: return 16
        case .nobles: return 0
        case .pretender: return 12
        }
    }

    public static func rate(_ k: RebelKind) -> Double {
        switch k {
        case .peasants: return 0.15
        case .zealots: return 0.08
        case .separatists: return 0.15
        case .nobles: return 0.10
        case .pretender: return 0.12
        }
    }

    public static let maxMonthlyGain = 2.5
    public static let maxMonthlyLoss = 3.0
    /// A cause needs this share of the realm's people behind it for full speed.
    public static let fullSupportShare = 0.10
    /// Provinces count as supporting a faction from this many points.
    public static let supportPoints = 10.0
    /// After a rising ends, the realm's factions grow this much slower for a while.
    public static let quietFactor = 0.3
    public static let quietMonthsAfterRising = 60
    public static let quietMonthsAfterConcession = 36
    /// Crown soldiers standing among a brewing faction's provinces slow it.
    public static let troopsPerMonthCap = 1.5

    /// Share of the supporting people who take up arms, in the worst provinces.
    public static let risingProvinces = 4
    public static let peasantShare = 0.03
    public static let zealotShare = 0.04
    public static let separatistShare = 0.04
    public static let nobleShare = 0.25
    public static let retinueShare = 0.015
    public static let pretenderShare = 0.02
    public static let minRisingMen = 1_500
    public static let maxRisingMen = 30_000

    /// Rebels win by standing unbeaten this long, or less after a victory.
    public static let monthsToWin = 12
    public static let monthsToWinAfterVictory = 6
    public static let rebelDevastation = 0.04

    /// What victorious (or bought-off) peasants get.
    public static let enforcedPeasantTax = 0.5
    public static let enforcedTaxMonths = 60
    public static let concededPeasantTax = 0.75
    public static let concededTaxMonths = 36
    /// Zealots of a faith this large change the state's religion.
    public static let stateFaithShare = 0.4
    /// Separatists who are this much of the realm get acceptance, not a border.
    public static let maxBreakawayShare = 0.5
    public static let pretenderPayoffMonths = 6.0
    public static let concessionPrestige = 3.0
}

/// One rebel faction of one country.
public struct RebelFaction: Sendable, Equatable, Codable, Identifiable {
    public var id: Int
    public var country: CountryID
    public var kind: RebelKind
    /// What they stand for (one of these, by kind).
    public var religion: Religion?
    public var culture: CultureID?
    public var estate: Int?
    public var pretender: CharacterID?
    /// 0 to 100; at 100 they rise.
    public var progress: Double
    /// Change of progress last month (for the screens).
    public var lastChange: Double
    /// Their grievance last month, in unrest points.
    public var pressure: Double
    /// Provinces behind them, worst first.
    public var provinces: [ProvinceID]
    public var risen: Bool
    /// Indices of their armies in the army table.
    public var armies: [Int]
    public var monthsInField: Int
    public var victories: Int

    public init(id: Int, country: CountryID, kind: RebelKind) {
        self.id = id
        self.country = country
        self.kind = kind
        self.progress = 0
        self.lastChange = 0
        self.pressure = 0
        self.provinces = []
        self.risen = false
        self.armies = []
        self.monthsInField = 0
        self.victories = 0
    }
}

/// Why a response to rebels cannot be ordered.
public enum RebelRefusal: Equatable, Sendable {
    case noSuchFaction
    case noMoney
    case noArmy
    case nothingToDo

    public var reason: String {
        switch self {
        case .noSuchFaction: return "These rebels are no more."
        case .noMoney: return "The treasury cannot pay for it."
        case .noArmy: return "No free army to send."
        case .nothingToDo: return "Nothing more can be done that way."
        }
    }
}

/// Mutable unrest state.
public struct UnrestState: Sendable, Equatable, Codable {
    /// 0 to 100 per province.
    public var unrest: [Double] = []
    /// Calming points per province left over from a settlement (fading).
    public var calm: [Double] = []
    public var factions: [RebelFaction] = []
    public var nextFactionID: Int = 1
    /// Months in a row each country has been at war.
    public var warMonths: [Int] = []
    /// Months left in which a country's factions grow slowly.
    public var quietMonths: [Int] = []
    /// Highest tax on peasants a settlement allows, and for how long.
    public var peasantTaxCap: [Double] = []
    public var peasantTaxCapMonths: [Int] = []
    /// Tallies since the game began (for the ledger and for balancing).
    public var risings: Int = 0
    public var rebelVictories: Int = 0
    public var rebelDefeats: Int = 0
    public var concessions: Int = 0

    public init() {}

    public mutating func resize(provinces p: Int, countries c: Int) {
        if unrest.count != p { unrest = UnrestState.fit(unrest, p, 0) }
        if calm.count != p { calm = UnrestState.fit(calm, p, 0) }
        if warMonths.count != c { warMonths = UnrestState.fit(warMonths, c, 0) }
        if quietMonths.count != c { quietMonths = UnrestState.fit(quietMonths, c, 0) }
        if peasantTaxCap.count != c { peasantTaxCap = UnrestState.fit(peasantTaxCap, c, 0) }
        if peasantTaxCapMonths.count != c { peasantTaxCapMonths = UnrestState.fit(peasantTaxCapMonths, c, 0) }
    }

    private static func fit<T>(_ a: [T], _ n: Int, _ fill: T) -> [T] {
        if a.count >= n { return Array(a.prefix(n)) }
        return a + Array(repeating: fill, count: n - a.count)
    }

    public func unrest(_ p: Int) -> Double { p >= 0 && p < unrest.count ? unrest[p] : 0 }

    public func factions(of country: CountryID) -> [RebelFaction] {
        factions.filter { $0.country == country }
    }

    public func faction(id: Int) -> RebelFaction? {
        factions.first { $0.id == id }
    }

    /// True if the army at this index of the army table belongs to a rebel faction.
    public func isFactionArmy(_ index: Int) -> Bool {
        for f in factions where f.risen && f.armies.contains(index) { return true }
        return false
    }

    public func faction(ofArmy index: Int) -> RebelFaction? {
        factions.first { $0.risen && $0.armies.contains(index) }
    }
}

/// One line of numbers on how hard the world has been hit so far: printed
/// by the tests into the CI log, where it is read for balancing.
public enum CalamityReport {
    public static func line(_ w: World, label: String) -> String {
        let owned = (0..<w.provinces.count).filter { w.provinces.owner[$0] != nil }
        let unrest = owned.map { w.unrest.unrest($0) }.sorted()
        let faith = owned.map { w.provinces.religiousUnrest[$0] }.sorted()
        func pick(_ a: [Double], _ q: Double) -> Int {
            a.isEmpty ? 0 : Int(a[min(a.count - 1, Int(Double(a.count) * q))])
        }
        var byKind = Array(repeating: 0, count: RebelKind.allCases.count)
        for f in w.unrest.factions { byKind[f.kind.rawValue] += 1 }
        var struck = 0
        for p in owned where w.calamity.hasAnyOutbreak(p) { struck += 1 }
        let deaths = w.calamity.totalDeaths.map { Int($0) }
        let starving = owned.filter { w.provinces.famine[$0] >= FamineModel.alertAbove }.count
        let over50 = w.unrest.factions.filter { $0.progress > 50 }.count
        let inArms = w.unrest.factions.filter { $0.risen }.count
        let people = Int(w.provinces.population.reduce(0, +))
        var parts: [String] = []
        parts.append("CALAMITY \(label): people=\(people)")
        parts.append("disease deaths (plague, camp fever, smallpox)=\(deaths) struck now=\(struck)")
        parts.append("famine deaths=\(Int(w.calamity.totalFamineDeaths)) starving now=\(starving)")
        parts.append("quake deaths=\(Int(w.calamity.totalQuakeDeaths))")
        parts.append("unrest median=\(pick(unrest, 0.5)) p90=\(pick(unrest, 0.9)) max=\(pick(unrest, 0.999))")
        parts.append("religious unrest median=\(pick(faith, 0.5)) p90=\(pick(faith, 0.9))")
        parts.append("factions=\(w.unrest.factions.count) by kind=\(byKind) over 50%=\(over50) in arms=\(inArms)")
        parts.append("risings=\(w.unrest.risings) won=\(w.unrest.rebelVictories)")
        parts.append("crushed=\(w.unrest.rebelDefeats) bought off=\(w.unrest.concessions)")
        return parts.joined(separator: "; ")
    }
}
