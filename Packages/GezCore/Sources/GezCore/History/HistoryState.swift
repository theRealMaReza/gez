import Foundation

/// Event categories recorded in the Chronicle Book (Phase 18).
public enum ChronicleEventKind: UInt8, Codable, Sendable, CaseIterable {
    case warDeclared = 0
    case warEnded = 1
    case majorBattle = 2
    case navalBattle = 3
    case siegeCaptured = 4
    case peaceTreaty = 5
    case lawChanged = 6
    case reformAdopted = 7
    case plagueOutbreak = 8
    case famine = 9
    case rebellion = 10
    case rulerCrowned = 11
    case rulerDied = 12
    case marriage = 13
    case heirBorn = 14
}

/// Struct-of-arrays table of structured historical events for the Chronicle Book.
///
/// Storing compact integer IDs and a deterministic `templateSeed` instead of
/// pre-rendered prose strings keeps 400 years of world history small in saves
/// and allows period prose templates in `data/` to render entries on demand.
public struct ChronicleEventTable: Sendable, Equatable, Codable {
    public var year: [Int16] = []
    public var month: [UInt8] = []
    public var day: [UInt8] = []
    public var kind: [UInt8] = []
    public var primaryCountry: [Int16] = []
    public var secondaryCountry: [Int16] = []
    public var province: [Int16] = []
    public var character: [Int32] = []
    public var secondaryCharacter: [Int32] = []
    public var valueA: [Int32] = []
    public var valueB: [Int32] = []
    public var templateSeed: [UInt32] = []

    public init() {}

    public var count: Int { kind.count }

    public mutating func append(
        date: GameDate,
        kind eventKind: ChronicleEventKind,
        primaryCountry: CountryID,
        secondaryCountry: CountryID? = nil,
        province: ProvinceID? = nil,
        character: CharacterID? = nil,
        secondaryCharacter: CharacterID? = nil,
        valueA: Int = 0,
        valueB: Int = 0,
        templateSeed: UInt32
    ) {
        self.year.append(Int16(clamping: date.year))
        self.month.append(UInt8(clamping: date.month))
        self.day.append(UInt8(clamping: date.day))
        self.kind.append(eventKind.rawValue)
        self.primaryCountry.append(Int16(clamping: primaryCountry.index))
        self.secondaryCountry.append(secondaryCountry.map { Int16(clamping: $0.index) } ?? -1)
        self.province.append(province.map { Int16(clamping: $0.index) } ?? -1)
        self.character.append(character.map { Int32(clamping: $0.index) } ?? -1)
        self.secondaryCharacter.append(secondaryCharacter.map { Int32(clamping: $0.index) } ?? -1)
        self.valueA.append(Int32(clamping: valueA))
        self.valueB.append(Int32(clamping: valueB))
        // Only the low byte is kept: it picks one of a handful of prose variants.
        self.templateSeed.append(templateSeed & 0xFF)
    }

    // Saved as one compact varint blob (not 12 JSON arrays), so a realistic
    // 400-year game with ~200 events a year stays small in the save file.
    private enum CodingKeys: String, CodingKey { case packedData }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var r = HistoryVarintReader(try container.decode(Data.self, forKey: .packedData))
        let n = Int(r.unsigned())
        var lastOrdinal = 0
        for _ in 0..<n {
            // Dates are stored as steps from the previous event (usually 0-2 days).
            lastOrdinal += r.signed()
            let (y, m, d) = Self.dateFromOrdinal(lastOrdinal)
            year.append(Int16(clamping: y))
            month.append(UInt8(truncatingIfNeeded: m))
            day.append(UInt8(truncatingIfNeeded: d))
            kind.append(UInt8(truncatingIfNeeded: r.unsigned()))
            // IDs are stored plus one, so "none" (-1) costs a single byte.
            primaryCountry.append(Int16(clamping: Int(r.unsigned()) - 1))
            secondaryCountry.append(Int16(clamping: Int(r.unsigned()) - 1))
            province.append(Int16(clamping: Int(r.unsigned()) - 1))
            character.append(Int32(clamping: Int(r.unsigned()) - 1))
            secondaryCharacter.append(Int32(clamping: Int(r.unsigned()) - 1))
            valueA.append(Int32(clamping: r.signed()))
            valueB.append(Int32(clamping: r.signed()))
            templateSeed.append(UInt32(r.byte()))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var w = HistoryVarintWriter()
        w.unsigned(UInt64(count))
        var lastOrdinal = 0
        for i in 0..<count {
            let ordinal = Self.ordinal(year: Int(year[i]), month: Int(month[i]), day: Int(day[i]))
            w.signed(ordinal - lastOrdinal)
            lastOrdinal = ordinal
            w.unsigned(UInt64(kind[i]))
            w.unsigned(UInt64(max(0, Int(primaryCountry[i]) + 1)))
            w.unsigned(UInt64(max(0, Int(secondaryCountry[i]) + 1)))
            w.unsigned(UInt64(max(0, Int(province[i]) + 1)))
            w.unsigned(UInt64(max(0, Int(character[i]) + 1)))
            w.unsigned(UInt64(max(0, Int(secondaryCharacter[i]) + 1)))
            w.signed(Int(valueA[i]))
            w.signed(Int(valueB[i]))
            w.byte(UInt8(truncatingIfNeeded: templateSeed[i]))
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(w.data, forKey: .packedData)
    }

    /// A day number used only for the save format: 31 days a month, 12 months a year.
    static func ordinal(year: Int, month: Int, day: Int) -> Int {
        year * 372 + (month - 1) * 31 + (day - 1)
    }

    static func dateFromOrdinal(_ o: Int) -> (Int, Int, Int) {
        let y = o >= 0 ? o / 372 : (o - 371) / 372
        let rest = o - y * 372
        return (y, rest / 31 + 1, rest % 31 + 1)
    }

    public func eventKind(at index: Int) -> ChronicleEventKind? {
        ChronicleEventKind(rawValue: kind[index])
    }

    public func date(at index: Int) -> GameDate {
        GameDate(year: Int(year[index]), month: Int(month[index]), day: Int(day[index]))
    }

    /// True when this event involves `country` as either primary or secondary actor.
    public func involves(_ country: CountryID, at index: Int) -> Bool {
        let raw = Int16(clamping: country.index)
        return primaryCountry[index] == raw || secondaryCountry[index] == raw
    }
}

/// Struct-of-arrays table of ruler reigns, used to group Chronicle entries into regnal chapters.
public struct RegnalChapterTable: Sendable, Equatable, Codable {
    public var country: [Int16] = []
    public var rulerID: [Int32] = []
    public var rulerName: [String] = []
    public var dynastyName: [String] = []
    public var startYear: [Int16] = []
    public var startMonth: [UInt8] = []
    public var startDay: [UInt8] = []
    /// `0` means the reign is still ongoing.
    public var endYear: [Int16] = []
    public var endMonth: [UInt8] = []
    public var endDay: [UInt8] = []

    public init() {}

    public var count: Int { country.count }

    public mutating func openReign(
        country cid: CountryID,
        rulerID rid: CharacterID?,
        rulerName: String,
        dynastyName: String,
        startDate: GameDate
    ) {
        self.country.append(Int16(clamping: cid.index))
        self.rulerID.append(rid.map { Int32(clamping: $0.index) } ?? -1)
        self.rulerName.append(rulerName)
        self.dynastyName.append(dynastyName)
        self.startYear.append(Int16(clamping: startDate.year))
        self.startMonth.append(UInt8(clamping: startDate.month))
        self.startDay.append(UInt8(clamping: startDate.day))
        self.endYear.append(0)
        self.endMonth.append(0)
        self.endDay.append(0)
    }

    public mutating func closeActiveReign(for cid: CountryID, on endDate: GameDate) {
        let raw = Int16(clamping: cid.index)
        for i in stride(from: count - 1, through: 0, by: -1) {
            if country[i] == raw && endYear[i] == 0 {
                endYear[i] = Int16(clamping: endDate.year)
                endMonth[i] = UInt8(clamping: endDate.month)
                endDay[i] = UInt8(clamping: endDate.day)
                return
            }
        }
    }

    public func startDate(at index: Int) -> GameDate {
        GameDate(year: Int(startYear[index]), month: Int(startMonth[index]), day: Int(startDay[index]))
    }

    public func endDate(at index: Int) -> GameDate? {
        guard endYear[index] > 0 else { return nil }
        return GameDate(year: Int(endYear[index]), month: Int(endMonth[index]), day: Int(endDay[index]))
    }
}

/// Struct-of-arrays yearly country statistics for the Ledger & Graphs screen.
///
/// Only countries alive (owning at least 1 province) in a given year are stored,
/// packed into flat parallel arrays indexed by `yearStartOffsets` / `yearCounts`.
/// Encodes as a compact pure-Swift varint binary blob so 400-year saves stay small.
public struct CountryStatsHistory: Sendable, Equatable, Codable {
    public var years: [Int] = []
    public var yearStartOffsets: [Int] = []
    public var yearCounts: [Int] = []

    public var countryIndex: [UInt16] = []
    public var population: [Int] = []
    public var incomeCents: [Int] = []
    public var armySize: [Int] = []
    public var navySize: [Int] = []
    /// Packed as `admin * 10000 + diplo * 100 + mil`.
    public var techPacked: [Int] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case packedData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .packedData)
        var cursor = 0

        func readVarint() -> UInt64 {
            var result: UInt64 = 0
            var shift: UInt64 = 0
            while cursor < data.count {
                let byte = data[cursor]
                cursor += 1
                result |= UInt64(byte & 0x7F) << shift
                if (byte & 0x80) == 0 { break }
                shift += 7
            }
            return result
        }

        func readSigned() -> Int {
            let v = readVarint()
            let signed = (v >> 1) ^ (~(v & 1) &+ 1)
            return Int(bitPattern: UInt(truncatingIfNeeded: signed))
        }

        let yearCount = Int(readVarint())
        years.reserveCapacity(yearCount)
        yearStartOffsets.reserveCapacity(yearCount)
        yearCounts.reserveCapacity(yearCount)
        for _ in 0..<yearCount { years.append(readSigned()) }
        for _ in 0..<yearCount { yearStartOffsets.append(Int(readVarint())) }
        for _ in 0..<yearCount { yearCounts.append(Int(readVarint())) }

        let rowCount = Int(readVarint())
        countryIndex.reserveCapacity(rowCount)
        population.reserveCapacity(rowCount)
        incomeCents.reserveCapacity(rowCount)
        armySize.reserveCapacity(rowCount)
        navySize.reserveCapacity(rowCount)
        techPacked.reserveCapacity(rowCount)
        // Each value is stored as the change from that country's previous row.
        var last: [Int: [Int]] = [:]
        var lastCountry = 0
        for _ in 0..<rowCount {
            let c = lastCountry + readSigned()
            lastCountry = c
            var prev = last[c] ?? [0, 0, 0, 0, 0]
            for k in 0..<5 { prev[k] += readSigned() }
            last[c] = prev
            countryIndex.append(UInt16(truncatingIfNeeded: c))
            population.append(prev[0])
            incomeCents.append(prev[1])
            armySize.append(prev[2])
            navySize.append(prev[3])
            techPacked.append(prev[4])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var data = Data()
        data.reserveCapacity(years.count * 12 + countryIndex.count * 12)

        func writeVarint(_ value: UInt64) {
            var v = value
            while v >= 0x80 {
                data.append(UInt8(v & 0x7F) | 0x80)
                v >>= 7
            }
            data.append(UInt8(v))
        }

        func writeSigned(_ value: Int) {
            let s = Int64(value)
            let zigzag = UInt64(bitPattern: (s << 1) ^ (s >> 63))
            writeVarint(zigzag)
        }

        writeVarint(UInt64(years.count))
        for y in years { writeSigned(y) }
        for o in yearStartOffsets { writeVarint(UInt64(max(0, o))) }
        for c in yearCounts { writeVarint(UInt64(max(0, c))) }

        writeVarint(UInt64(countryIndex.count))
        var last: [Int: [Int]] = [:]
        var lastCountry = 0
        for i in 0..<countryIndex.count {
            let c = Int(countryIndex[i])
            writeSigned(c - lastCountry)
            lastCountry = c
            let row = [population[i], incomeCents[i], armySize[i], navySize[i], techPacked[i]]
            let prev = last[c] ?? [0, 0, 0, 0, 0]
            for k in 0..<5 { writeSigned(row[k] - prev[k]) }
            last[c] = row
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .packedData)
    }

    public static func packTech(admin: Int, diplo: Int, mil: Int) -> Int {
        max(0, admin) * 10000 + max(0, diplo) * 100 + max(0, mil)
    }

    public static func unpackTech(_ packed: Int) -> (admin: Int, diplo: Int, mil: Int, total: Int) {
        let a = packed / 10000
        let d = (packed / 100) % 100
        let m = packed % 100
        return (a, d, m, a + d + m)
    }

    public struct CountryPoint: Sendable, Equatable {
        public var year: Int
        public var population: Int
        public var income: Double
        public var armySize: Int
        public var navySize: Int
        public var adminTech: Int
        public var diploTech: Int
        public var milTech: Int
        public var totalTech: Int
    }

    /// Returns the recorded yearly time series for a given country.
    public func series(for country: CountryID) -> [CountryPoint] {
        let target = UInt16(clamping: country.index)
        var result: [CountryPoint] = []
        result.reserveCapacity(years.count)
        for yIdx in 0..<years.count {
            let start = yearStartOffsets[yIdx]
            let end = start + yearCounts[yIdx]
            // `countryIndex` is appended in ascending country order each year; binary search it.
            var lo = start
            var hi = end - 1
            while lo <= hi {
                let mid = (lo + hi) >> 1
                let val = countryIndex[mid]
                if val == target {
                    let t = Self.unpackTech(techPacked[mid])
                    result.append(CountryPoint(
                        year: years[yIdx],
                        population: population[mid],
                        income: Double(incomeCents[mid]) / 100.0,
                        armySize: armySize[mid],
                        navySize: navySize[mid],
                        adminTech: t.admin,
                        diploTech: t.diplo,
                        milTech: t.mil,
                        totalTech: t.total
                    ))
                    break
                } else if val < target {
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
        }
        return result
    }
}

/// Delta-encoded yearly province owner and religion snapshots for the Map Timelapse.
///
/// Stores one full baseline frame (`initialOwner`, `initialReligion`) and only
/// changed `(provinceIndex, newValue)` pairs for each subsequent year.
public struct TimelapseHistory: Sendable, Equatable, Codable {
    public var years: [Int] = []
    public var initialOwner: [Int16] = []
    public var initialReligion: [UInt8] = []

    /// For `years[i]` with `i >= 1`, `ownerDeltaOffsets[i - 1]`..`+ ownerDeltaCounts[i - 1]`
    /// slices `ownerDeltaPairs` as `[provinceIndex, newOwnerRaw, ...]`.
    public var ownerDeltaOffsets: [Int] = []
    public var ownerDeltaCounts: [Int] = []
    public var ownerDeltaPairs: [Int16] = []

    /// For `years[i]` with `i >= 1`, `religionDeltaOffsets[i - 1]`..`+ religionDeltaCounts[i - 1]`
    /// slices `religionDeltaPairs` as `[provinceIndex, newReligionIndex, ...]`.
    public var religionDeltaOffsets: [Int] = []
    public var religionDeltaCounts: [Int] = []
    public var religionDeltaPairs: [Int16] = []

    /// Cached latest state so yearly diffing is O(provinces) without replaying from `years[0]`.
    public var lastOwner: [Int16] = []
    public var lastReligion: [UInt8] = []

    public init() {}

    /// Reconstructs the `(owner, religion)` arrays for `years[yearIndex]`.
    public func frame(atYearIndex yearIndex: Int) -> (owner: [Int16], religion: [UInt8]) {
        guard !years.isEmpty, yearIndex >= 0, yearIndex < years.count else {
            return ([], [])
        }
        var owner = initialOwner
        var religion = initialReligion
        if yearIndex == 0 {
            return (owner, religion)
        }
        for step in 0..<yearIndex {
            if step < ownerDeltaOffsets.count {
                let start = ownerDeltaOffsets[step]
                let end = start + ownerDeltaCounts[step]
                var idx = start
                while idx + 1 < end {
                    let p = Int(ownerDeltaPairs[idx])
                    let val = ownerDeltaPairs[idx + 1]
                    if p >= 0 && p < owner.count {
                        owner[p] = val
                    }
                    idx += 2
                }
            }
            if step < religionDeltaOffsets.count {
                let start = religionDeltaOffsets[step]
                let end = start + religionDeltaCounts[step]
                var idx = start
                while idx + 1 < end {
                    let p = Int(religionDeltaPairs[idx])
                    let val = religionDeltaPairs[idx + 1]
                    if p >= 0 && p < religion.count && val >= 0 {
                        religion[p] = UInt8(clamping: val)
                    }
                    idx += 2
                }
            }
        }
        return (owner, religion)
    }
}

/// Complete Phase 18 historical recording state stored on `World` and persisted in saves.
public struct HistoryState: Sendable, Equatable, Codable {
    public var isInitialized: Bool = false
    public var rngState: UInt64 = 0x1453_18_0001
    public var events = ChronicleEventTable()
    public var chapters = RegnalChapterTable()
    public var stats = CountryStatsHistory()
    public var timelapse = TimelapseHistory()

    public init() {}
}

/// Little helpers for the compact save format of the history tables.
struct HistoryVarintWriter {
    var data = Data()

    mutating func unsigned(_ value: UInt64) {
        var v = value
        while v >= 0x80 {
            data.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        data.append(UInt8(v))
    }

    mutating func signed(_ value: Int) {
        let s = Int64(value)
        unsigned(UInt64(bitPattern: (s << 1) ^ (s >> 63)))
    }

    mutating func byte(_ value: UInt8) {
        data.append(value)
    }
}

struct HistoryVarintReader {
    let data: Data
    var cursor: Int

    init(_ data: Data) {
        self.data = data
        self.cursor = data.startIndex
    }

    mutating func unsigned() -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while cursor < data.endIndex {
            let byte = data[cursor]
            cursor += 1
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 { break }
            shift += 7
        }
        return result
    }

    mutating func signed() -> Int {
        let v = unsigned()
        return Int(Int64(bitPattern: (v >> 1) ^ (0 &- (v & 1))))
    }

    mutating func byte() -> UInt8 {
        guard cursor < data.endIndex else { return 0 }
        let b = data[cursor]
        cursor += 1
        return b
    }
}
