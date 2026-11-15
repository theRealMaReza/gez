public struct CultureID: Hashable, Sendable, Codable {
    public let index: Int
    public init(_ index: Int) { self.index = index }
}

public struct CultureTable: Sendable {
    public private(set) var key: [String] = []
    public private(set) var name: [String] = []
    /// Culture family, e.g. "south_slavic", "turkic".
    public private(set) var family: [String] = []
    private var indexByKey: [String: CultureID] = [:]

    public init() {}

    public var count: Int { key.count }

    @discardableResult
    public mutating func add(key: String, name: String, family: String) -> CultureID {
        let id = CultureID(count)
        self.key.append(key)
        self.name.append(name)
        self.family.append(family)
        indexByKey[key] = id
        return id
    }

    public func id(forKey key: String) -> CultureID? { indexByKey[key] }

    /// All family names, in first-seen order.
    public var families: [String] {
        var seen = Set<String>()
        return family.filter { seen.insert($0).inserted }
    }
}

public enum SocialClass: String, CaseIterable, Sendable, Codable {
    case nobles, clergy, burghers, peasants, slaves

    public var displayName: String {
        switch self {
        case .nobles: return "Nobles"
        case .clergy: return "Clergy"
        case .burghers: return "Burghers"
        case .peasants: return "Peasants"
        case .slaves: return "Slaves"
        }
    }
}

/// A Sufi brotherhood's presence in a province, strength 0 to 1.
public struct SufiPresence: Hashable, Sendable, Codable {
    public var order: SufiOrder
    public var strength: Double
    public init(order: SufiOrder, strength: Double) {
        self.order = order
        self.strength = strength
    }
}

/// Every group of people in the world: one row per (province, culture,
/// religion, sect, social class). Rows for a province are stored together;
/// `range(for:)` gives them.
public struct PopTable: Sendable {
    public private(set) var province: [ProvinceID] = []
    public var culture: [CultureID] = []
    public var religion: [Religion] = []
    public var sect: [Sect?] = []
    public var socialClass: [SocialClass] = []
    public var size: [Double] = []
    /// How well the group's needs are met, 0 to 1 (moves slowly).
    public var satisfaction: [Double] = []
    private var ranges: [Range<Int>] = []

    public init() {}

    public var count: Int { size.count }

    public func range(for p: ProvinceID) -> Range<Int> {
        p.index < ranges.count ? ranges[p.index] : 0..<0
    }

    /// Pops must be added province by province, in province order.
    public mutating func beginProvince(_ p: ProvinceID) {
        precondition(p.index == ranges.count, "pops must be added in province order")
        ranges.append(count..<count)
    }

    public mutating func add(culture: CultureID, religion: Religion, sect: Sect?, socialClass: SocialClass, size: Double) {
        precondition(!ranges.isEmpty, "call beginProvince first")
        let p = ProvinceID(ranges.count - 1)
        province.append(p)
        self.culture.append(culture)
        self.religion.append(religion)
        self.sect.append(sect)
        self.socialClass.append(socialClass)
        self.size.append(size)
        self.satisfaction.append(MarketModel.startingSatisfaction)
        let r = ranges[ranges.count - 1]
        ranges[ranges.count - 1] = r.lowerBound..<(r.upperBound + 1)
    }

    public struct Row: Sendable {
        public var province: ProvinceID
        public var culture: CultureID
        public var religion: Religion
        public var sect: Sect?
        public var socialClass: SocialClass
        public var size: Double
        public var satisfaction: Double

        public init(
            province: ProvinceID,
            culture: CultureID,
            religion: Religion,
            sect: Sect?,
            socialClass: SocialClass,
            size: Double,
            satisfaction: Double
        ) {
            self.province = province
            self.culture = culture
            self.religion = religion
            self.sect = sect
            self.socialClass = socialClass
            self.size = size
            self.satisfaction = satisfaction
        }
    }

    /// Rebuilds the SoA pop table deterministically from live rows plus any newly split rows,
    /// pruning depleted rows (`size <= 1e-9`) and merging matching identities cleanly per province.
    public mutating func rebuild(provinceCount: Int, extraRows: [Row] = []) {
        struct LocalKey: Hashable {
            let culture: Int
            let religion: Religion
            let sect: Sect?
            let socialClass: SocialClass
        }
        var extrasByProv: [Int: [Row]] = [:]
        if !extraRows.isEmpty {
            extrasByProv.reserveCapacity(min(provinceCount, extraRows.count))
            for row in extraRows where row.size > 1e-9 && row.province.index < provinceCount {
                extrasByProv[row.province.index, default: []].append(row)
            }
        }

        var newProvince: [ProvinceID] = []
        var newCulture: [CultureID] = []
        var newReligion: [Religion] = []
        var newSect: [Sect?] = []
        var newClass: [SocialClass] = []
        var newSize: [Double] = []
        var newSatisfaction: [Double] = []
        let est = count + extraRows.count
        newProvince.reserveCapacity(est)
        newCulture.reserveCapacity(est)
        newReligion.reserveCapacity(est)
        newSect.reserveCapacity(est)
        newClass.reserveCapacity(est)
        newSize.reserveCapacity(est)
        newSatisfaction.reserveCapacity(est)

        var newRanges = Array(repeating: 0..<0, count: provinceCount)
        for p in 0..<provinceCount {
            let start = newProvince.count
            let pid = ProvinceID(p)
            let range = self.range(for: pid)

            if let extras = extrasByProv[p] {
                var grouped: [LocalKey: (size: Double, satWeighted: Double)] = [:]
                grouped.reserveCapacity(range.count + extras.count)
                for i in range {
                    let sz = size[i]
                    guard sz > 1e-9 else { continue }
                    let key = LocalKey(culture: culture[i].index, religion: religion[i], sect: sect[i], socialClass: socialClass[i])
                    if let cur = grouped[key] {
                        grouped[key] = (cur.size + sz, cur.satWeighted + satisfaction[i] * sz)
                    } else {
                        grouped[key] = (sz, satisfaction[i] * sz)
                    }
                }
                for row in extras {
                    let key = LocalKey(culture: row.culture.index, religion: row.religion, sect: row.sect, socialClass: row.socialClass)
                    if let cur = grouped[key] {
                        grouped[key] = (cur.size + row.size, cur.satWeighted + row.satisfaction * row.size)
                    } else {
                        grouped[key] = (row.size, row.satisfaction * row.size)
                    }
                }
                let sorted = grouped.sorted { lhs, rhs in
                    if lhs.key.culture != rhs.key.culture { return lhs.key.culture < rhs.key.culture }
                    if lhs.key.religion.rawValue != rhs.key.religion.rawValue { return lhs.key.religion.rawValue < rhs.key.religion.rawValue }
                    if (lhs.key.sect?.rawValue ?? "") != (rhs.key.sect?.rawValue ?? "") {
                        return (lhs.key.sect?.rawValue ?? "") < (rhs.key.sect?.rawValue ?? "")
                    }
                    return lhs.key.socialClass.rawValue < rhs.key.socialClass.rawValue
                }
                for item in sorted {
                    newProvince.append(pid)
                    newCulture.append(CultureID(item.key.culture))
                    newReligion.append(item.key.religion)
                    newSect.append(item.key.sect)
                    newClass.append(item.key.socialClass)
                    newSize.append(item.value.size)
                    newSatisfaction.append(item.value.size > 0 ? item.value.satWeighted / item.value.size : 0.5)
                }
            } else {
                for i in range {
                    let sz = size[i]
                    guard sz > 1e-9 else { continue }
                    newProvince.append(pid)
                    newCulture.append(culture[i])
                    newReligion.append(religion[i])
                    newSect.append(sect[i])
                    newClass.append(socialClass[i])
                    newSize.append(sz)
                    newSatisfaction.append(satisfaction[i])
                }
            }
            newRanges[p] = start..<newProvince.count
        }

        self.province = newProvince
        self.culture = newCulture
        self.religion = newReligion
        self.sect = newSect
        self.socialClass = newClass
        self.size = newSize
        self.satisfaction = newSatisfaction
        self.ranges = newRanges
    }

    /// Restores full SoA pop rows from a save snapshot and rebuilds province ranges.
    public mutating func restore(
        provinceCount: Int,
        province: [ProvinceID],
        culture: [CultureID],
        religion: [Religion],
        sect: [Sect?],
        socialClass: [SocialClass],
        size: [Double],
        satisfaction: [Double]
    ) {
        self.province = province
        self.culture = culture
        self.religion = religion
        self.sect = sect
        self.socialClass = socialClass
        self.size = size
        self.satisfaction = satisfaction
        var rebuiltRanges = Array(repeating: 0..<0, count: provinceCount)
        var idx = 0
        for p in 0..<provinceCount {
            let start = idx
            while idx < province.count && province[idx].index == p {
                idx += 1
            }
            rebuiltRanges[p] = start..<idx
        }
        self.ranges = rebuiltRanges
    }
}

/// Who lives somewhere, summed up.
public struct PopBreakdown: Sendable {
    public var total: Double = 0
    public var byCulture: [CultureID: Double] = [:]
    public var byReligion: [Religion: Double] = [:]
    public var bySect: [Sect: Double] = [:]
    public var byClass: [SocialClass: Double] = [:]

    public init() {}

    /// Largest first, as fractions of the total.
    public func cultureShares() -> [(CultureID, Double)] {
        sortedShares(byCulture)
    }

    public func religionShares() -> [(Religion, Double)] {
        sortedShares(byReligion)
    }

    public func classShares() -> [(SocialClass, Double)] {
        SocialClass.allCases.compactMap { c in
            guard let v = byClass[c], v > 0, total > 0 else { return nil }
            return (c, v / total)
        }
    }

    private func sortedShares<K: Hashable>(_ d: [K: Double]) -> [(K, Double)] {
        guard total > 0 else { return [] }
        return d.map { ($0.key, $0.value / total) }.sorted { $0.1 > $1.1 }
    }
}

extension World {
    public func breakdown(of provinceIDs: [ProvinceID]) -> PopBreakdown {
        var b = PopBreakdown()
        for p in provinceIDs {
            for i in pops.range(for: p) {
                let s = pops.size[i]
                b.total += s
                b.byCulture[pops.culture[i], default: 0] += s
                b.byReligion[pops.religion[i], default: 0] += s
                if let sect = pops.sect[i] { b.bySect[sect, default: 0] += s }
                b.byClass[pops.socialClass[i], default: 0] += s
            }
        }
        return b
    }

    public func breakdown(of province: ProvinceID) -> PopBreakdown {
        breakdown(of: [province])
    }

    public func breakdown(ofState state: StateID) -> PopBreakdown {
        breakdown(of: states.provinces[state.index])
    }

    public func breakdown(ofCountry country: CountryID) -> PopBreakdown {
        breakdown(of: provinces(ownedBy: country))
    }

    /// Recomputes each province's cached population and majority religion
    /// and culture from its pops.
    public mutating func refreshProvinceSummaries() {
        refreshProvinceSummaries(for: 0..<provinces.count)
    }

    /// Recomputes cached population and majority religion/culture only for the specified province indices.
    public mutating func refreshProvinceSummaries<S: Sequence>(for provinceIndices: S) where S.Element == Int {
        for p in provinceIndices where p >= 0 && p < provinces.count {
            let id = ProvinceID(p)
            var total = 0.0
            var byReligion: [Religion: Double] = [:]
            var byCulture: [CultureID: Double] = [:]
            for i in pops.range(for: id) {
                let sz = pops.size[i]
                guard sz > 0 else { continue }
                total += sz
                byReligion[pops.religion[i], default: 0] += sz
                byCulture[pops.culture[i], default: 0] += sz
            }
            provinces.population[p] = total
            if let top = byReligion.max(by: { a, b in a.value == b.value ? a.key.rawValue > b.key.rawValue : a.value < b.value }) {
                provinces.religion[p] = top.key
            }
            if let top = byCulture.max(by: { a, b in a.value == b.value ? a.key.index > b.key.index : a.value < b.value }) {
                provinces.majorityCulture[p] = top.key
            }
        }
    }
}

/// How a province's people divide into social classes at the start.
public enum ClassSplit {
    public struct Targets: Sendable {
        public var nobles: Double
        public var clergy: Double
        public var burghers: Double
        public var slaves: Double
    }

    /// Fractions of the whole population for each class except peasants
    /// (peasants are everyone left).
    public static func targets(development: Int, government: GovernmentType?, slavery: Double) -> Targets {
        let nobles: Double = (government == .steppeHorde || government == .tribal) ? 0.04 : 0.015
        let clergy: Double = government == .theocracy ? 0.04 : 0.015
        let burghers = 0.02 + 0.016 * Double(min(max(development, 1), 10))
        return Targets(nobles: nobles, clergy: clergy, burghers: burghers, slaves: max(0, slavery))
    }

    /// Splits each group into classes. Nobles come mostly from the ruler's
    /// religion; merchant diasporas (Jewish, Armenian, Italian) are more
    /// often burghers; slaves are more often from outside the ruler's faith.
    public static func split(
        groups: [(culture: CultureID, family: String, religion: Religion, sect: Sect?, size: Double)],
        targets: Targets,
        rulerReligion: Religion?
    ) -> [(group: Int, socialClass: SocialClass, size: Double)] {
        let total = groups.reduce(0) { $0 + $1.size }
        guard total > 0 else { return [] }
        var remaining = groups.map(\.size)
        var out: [(Int, SocialClass, Double)] = []

        func allocate(_ socialClass: SocialClass, fraction: Double, weight: (Int) -> Double) {
            let want = total * fraction
            guard want > 0 else { return }
            let weights = groups.indices.map { weight($0) * groups[$0].size }
            let sum = weights.reduce(0, +)
            guard sum > 0 else { return }
            for g in groups.indices where weights[g] > 0 {
                let amount = min(want * weights[g] / sum, remaining[g] * 0.9)
                if amount > 0 {
                    out.append((g, socialClass, amount))
                    remaining[g] -= amount
                }
            }
        }

        allocate(.nobles, fraction: targets.nobles) { g in
            groups[g].religion == rulerReligion ? 4 : 1
        }
        allocate(.clergy, fraction: targets.clergy) { _ in 1 }
        allocate(.burghers, fraction: targets.burghers) { g in
            switch groups[g].family {
            case "jewish", "armenian": return 3
            case "italian": return 2
            default: return 1
            }
        }
        allocate(.slaves, fraction: targets.slaves) { g in
            guard let ruler = rulerReligion else { return 1 }
            return groups[g].religion.family == ruler.family ? 0.5 : 2
        }
        for g in groups.indices where remaining[g] > 0 {
            out.append((g, .peasants, remaining[g]))
        }
        return out
    }
}
