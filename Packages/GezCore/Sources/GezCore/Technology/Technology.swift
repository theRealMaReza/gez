import Foundation

/// The three EU4-style technology tracks (Phase 13).
public enum TechTrack: Int, CaseIterable, Sendable, Codable {
    case administrative = 0
    case diplomatic = 1
    case military = 2

    public var key: String {
        switch self {
        case .administrative: return "administrative"
        case .diplomatic:     return "diplomatic"
        case .military:       return "military"
        }
    }

    public var displayName: String {
        switch self {
        case .administrative: return "Administrative"
        case .diplomatic:     return "Diplomatic"
        case .military:       return "Military"
        }
    }

    public var shortName: String {
        switch self {
        case .administrative: return "ADM"
        case .diplomatic:     return "DIP"
        case .military:       return "MIL"
        }
    }

    public var rulerSkill: Skill {
        switch self {
        case .administrative: return .stewardship
        case .diplomatic:     return .diplomacy
        case .military:       return .martial
        }
    }

    public var councilSeat: CouncilSeat {
        switch self {
        case .administrative: return .steward
        case .diplomatic:     return .chancellor
        case .military:       return .marshal
        }
    }

    public init?(key: String) {
        switch key {
        case "administrative": self = .administrative
        case "diplomatic":     self = .diplomatic
        case "military":       self = .military
        default:               return nil
        }
    }
}

/// Player or AI national research focus steering the shared Learning/College/Paper/Books pool.
public enum TechFocus: Int, CaseIterable, Sendable, Codable {
    case balanced = 0
    case administrative = 1
    case diplomatic = 2
    case military = 3

    public var key: String {
        switch self {
        case .balanced:       return "balanced"
        case .administrative: return "administrative"
        case .diplomatic:     return "diplomatic"
        case .military:       return "military"
        }
    }

    public var displayName: String {
        switch self {
        case .balanced:       return "Balanced"
        case .administrative: return "Administrative"
        case .diplomatic:     return "Diplomatic"
        case .military:       return "Military"
        }
    }

    public init?(key: String) {
        switch key {
        case "balanced":       self = .balanced
        case "administrative": self = .administrative
        case "diplomatic":     self = .diplomatic
        case "military":       self = .military
        default:               return nil
        }
    }

    /// Share of the shared learning pool routed to `track`.
    public func share(for track: TechTrack) -> Double {
        switch self {
        case .balanced:
            return 1.0 / 3.0
        case .administrative:
            return track == .administrative ? 0.50 : 0.25
        case .diplomatic:
            return track == .diplomatic ? 0.50 : 0.25
        case .military:
            return track == .military ? 0.50 : 0.25
        }
    }
}

/// Cumulative modifiers granted by a technology level on a track.
public struct TechEffects: Sendable, Equatable {
    public var taxEff: Double = 0
    public var prodEff: Double = 0
    public var tradeEff: Double = 0
    public var tradeRange: Int = 3
    public var adminEff: Double = 0
    public var maxBuilding: Int = 3
    public var maxFort: Int = 1
    public var tactics: Double = 0.50
    public var landMorale: Double = 0
    public var relations: Int = 0
    public var acceptedCultures: Int = 0
    public var reformProgress: Double = 0

    public init() {}
}

/// Static definition of a single level (1...20) on one track.
public struct TechLevelDef: Sendable {
    public let level: Int
    public let targetYear: Int
    public let baseCost: Double
    public let effects: TechEffects
    public let summary: String

    public init(level: Int, targetYear: Int, baseCost: Double, effects: TechEffects, summary: String) {
        self.level = level
        self.targetYear = targetYear
        self.baseCost = baseCost
        self.effects = effects
        self.summary = summary
    }
}

public enum InstitutionOriginRule: Sendable, Equatable {
    case region(String)
    case province(ProvinceID)
    case dynamic(String)
}

/// Static definition of one historical institution.
public struct InstitutionDef: Sendable {
    public let index: Int
    public let key: String
    public let name: String
    public let spawnYear: Int
    public let origin: InstitutionOriginRule
    public let spreadNeighbour: Double
    public let spreadTrade: Double
    public let spreadBurgher: Double
    public let summary: String

    public init(
        index: Int,
        key: String,
        name: String,
        spawnYear: Int,
        origin: InstitutionOriginRule,
        spreadNeighbour: Double,
        spreadTrade: Double,
        spreadBurgher: Double,
        summary: String
    ) {
        self.index = index
        self.key = key
        self.name = name
        self.spawnYear = spawnYear
        self.origin = origin
        self.spreadNeighbour = spreadNeighbour
        self.spreadTrade = spreadTrade
        self.spreadBurgher = spreadBurgher
        self.summary = summary
    }
}

/// Global technology tuning parameters loaded from `technology1453.json`.
public struct TechParams: Sendable {
    public var baseCost: Double = 600
    public var neighbourBonusPerLevel: Double = 0.05
    public var neighbourBonusCap: Double = 0.25
    public var aheadOfTimePerYear: Double = 0.10
    public var aheadOfTimeCap: Double = 2.00
    public var institutionPenaltyPerYear: Double = 0.01
    public var institutionPenaltyCap: Double = 0.50
    public var embracedResearchBonus: Double = 0.05
    public var embraceMinDevShare: Double = 0.10
    public var embraceDucatsPerDev: Double = 2.0
    public var embraceMinCost: Double = 20.0

    public init() {}
}

/// Immutable technology & institution rules loaded from `technology1453.json` (not saved).
public struct TechRules: Sendable {
    public static let minLevel = 1
    public static let maxLevel = 20
    public static let trackCount = TechTrack.allCases.count

    public var params = TechParams()
    /// 3 tracks × 20 levels (`tracks[track.rawValue][level - 1]`).
    public var tracks: [[TechLevelDef]] = []
    public var regionStart: [String: [Int]] = [:]
    public var govCaps: [GovernmentType: [Int]] = [:]
    public var countryStart: [String: [Int]] = [:]
    public var institutions: [InstitutionDef] = []

    public init() {}

    public func levelDef(_ track: TechTrack, level: Int) -> TechLevelDef? {
        let t = track.rawValue
        let i = level - 1
        guard t >= 0, t < tracks.count, i >= 0, i < tracks[t].count else { return nil }
        return tracks[t][i]
    }
}

/// Notable technology or institution event for the UI / alerts.
public struct TechNote: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable {
        case levelUp
        case institutionSpawned
        case institutionEmbraced
    }

    public var date: GameDate
    public var country: CountryID?
    public var kind: Kind
    public var track: TechTrack?
    public var level: Int?
    public var institutionIndex: Int?
    public var province: ProvinceID?
    public var text: String

    public init(
        date: GameDate,
        country: CountryID? = nil,
        kind: Kind,
        track: TechTrack? = nil,
        level: Int? = nil,
        institutionIndex: Int? = nil,
        province: ProvinceID? = nil,
        text: String
    ) {
        self.date = date
        self.country = country
        self.kind = kind
        self.track = track
        self.level = level
        self.institutionIndex = institutionIndex
        self.province = province
        self.text = text
    }
}

/// Mutable technology & institution state stored as struct-of-arrays and saved cleanly.
public struct TechState: Sendable, Codable {
    public var countryCount: Int = 0
    public var provinceCount: Int = 0
    public var institutionCount: Int = 0

    /// Flattened `C * 3`: current tech level (1...20) per country and track.
    public var levels: [Int] = []
    /// Flattened `C * 3`: accumulated research points toward next level.
    public var progress: [Double] = []
    /// Research focus per country (`C`).
    public var focus: [TechFocus] = []
    /// Bitmask of embraced institutions per country (`C`).
    public var embracedMask: [UInt8] = []
    /// Flattened `C * 3`: last monthly research gain for UI display.
    public var lastMonthlyGain: [Double] = []

    /// Per-institution runtime status (`I`).
    public var institutionSpawned: [Bool] = []
    public var institutionSpawnYear: [Int] = []
    public var institutionOrigin: [ProvinceID?] = []
    /// Flattened `P * I`: institution spread presence in `0...1`.
    public var presence: [Double] = []

    /// Recent level-ups and institution notifications.
    public var notes: [TechNote] = []

    /// Dedicated deterministic RNG stream so institution rolls never perturb `Simulation.random`.
    public var rngState: UInt64 = 0
    public var seeded: Bool = false

    public init() {}

    public mutating func resize(countries c: Int, provinces p: Int, institutions i: Int) {
        let trackSlots = c * TechRules.trackCount
        levels = Self.fit(levels, trackSlots, 3)
        progress = Self.fit(progress, trackSlots, 0)
        focus = Self.fit(focus, c, .balanced)
        embracedMask = Self.fit(embracedMask, c, 0)
        lastMonthlyGain = Self.fit(lastMonthlyGain, trackSlots, 0)

        institutionSpawned = Self.fit(institutionSpawned, i, false)
        institutionSpawnYear = Self.fit(institutionSpawnYear, i, 0)
        institutionOrigin = Self.fit(institutionOrigin, i, nil)
        presence = Self.fit(presence, p * i, 0)

        countryCount = c
        provinceCount = p
        institutionCount = i
    }

    private static func fit<T>(_ array: [T], _ count: Int, _ fill: T) -> [T] {
        if array.count == count { return array }
        if array.count > count { return Array(array.prefix(count)) }
        return array + Array(repeating: fill, count: count - array.count)
    }

    @inline(__always)
    public func slot(_ c: CountryID, _ track: TechTrack) -> Int {
        c.index * TechRules.trackCount + track.rawValue
    }

    @inline(__always)
    public func level(_ c: CountryID, _ track: TechTrack) -> Int {
        let idx = slot(c, track)
        guard c.index >= 0, c.index < countryCount, idx < levels.count else { return 3 }
        return levels[idx]
    }

    public mutating func setLevel(_ c: CountryID, _ track: TechTrack, _ value: Int) {
        let idx = slot(c, track)
        guard c.index >= 0, c.index < countryCount, idx < levels.count else { return }
        levels[idx] = max(TechRules.minLevel, min(TechRules.maxLevel, value))
    }

    @inline(__always)
    public func progress(_ c: CountryID, _ track: TechTrack) -> Double {
        let idx = slot(c, track)
        guard c.index >= 0, c.index < countryCount, idx < progress.count else { return 0 }
        return progress[idx]
    }

    @inline(__always)
    public func lastGain(_ c: CountryID, _ track: TechTrack) -> Double {
        let idx = slot(c, track)
        guard c.index >= 0, c.index < countryCount, idx < lastMonthlyGain.count else { return 0 }
        return lastMonthlyGain[idx]
    }

    @inline(__always)
    public func focus(of c: CountryID) -> TechFocus {
        guard c.index >= 0, c.index < focus.count else { return .balanced }
        return focus[c.index]
    }

    public mutating func setFocus(of c: CountryID, to newFocus: TechFocus) {
        guard c.index >= 0, c.index < focus.count else { return }
        focus[c.index] = newFocus
    }

    @inline(__always)
    public func hasEmbraced(_ c: CountryID, institution instIndex: Int) -> Bool {
        guard c.index >= 0, c.index < embracedMask.count, instIndex >= 0, instIndex < 8 else { return false }
        return (embracedMask[c.index] & (1 << UInt8(instIndex))) != 0
    }

    public mutating func setEmbraced(_ c: CountryID, institution instIndex: Int, _ value: Bool = true) {
        guard c.index >= 0, c.index < embracedMask.count, instIndex >= 0, instIndex < 8 else { return }
        let bit = UInt8(1 << instIndex)
        if value {
            embracedMask[c.index] |= bit
        } else {
            embracedMask[c.index] &= ~bit
        }
    }

    public func embracedCount(_ c: CountryID) -> Int {
        guard c.index >= 0, c.index < embracedMask.count else { return 0 }
        return embracedMask[c.index].nonzeroBitCount
    }

    @inline(__always)
    public func presenceSlot(_ p: ProvinceID, _ instIndex: Int) -> Int {
        p.index * institutionCount + instIndex
    }

    @inline(__always)
    public func provincePresence(_ p: ProvinceID, institution instIndex: Int) -> Double {
        guard p.index >= 0, p.index < provinceCount, instIndex >= 0, instIndex < institutionCount else { return 0 }
        let idx = presenceSlot(p, instIndex)
        return idx < presence.count ? presence[idx] : 0
    }

    public mutating func setProvincePresence(_ p: ProvinceID, institution instIndex: Int, _ value: Double) {
        guard p.index >= 0, p.index < provinceCount, instIndex >= 0, instIndex < institutionCount else { return }
        let idx = presenceSlot(p, instIndex)
        if idx < presence.count {
            presence[idx] = max(0.0, min(1.0, value))
        }
    }

    public mutating func addNote(_ note: TechNote) {
        notes.append(note)
        if notes.count > 80 {
            notes.removeFirst(notes.count - 80)
        }
    }
}

extension World {
    /// Technology & institutions' dedicated RNG stream, split off `Simulation.random`
    /// without consuming numbers from the main stream.
    mutating func beginTechRandom(_ random: GameRandom) -> GameRandom {
        if !tech.seeded {
            tech.rngState = random.rawState ^ 0x7EC4_1453_9A2B_C107
            tech.seeded = true
        }
        return GameRandom(seed: tech.rngState)
    }

    mutating func endTechRandom(_ rng: GameRandom) {
        tech.rngState = rng.rawState
    }

    /// Cumulative technology effects for `country` at its current levels.
    public func techEffects(_ country: CountryID, track: TechTrack) -> TechEffects {
        let lvl = tech.level(country, track)
        return techRules.levelDef(track, level: lvl)?.effects ?? TechEffects()
    }
}
