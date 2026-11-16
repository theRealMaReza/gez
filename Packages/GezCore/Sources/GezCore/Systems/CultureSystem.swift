import Foundation

public enum GovernmentRank: String, Sendable, Codable, CaseIterable {
    case duchy
    case kingdom
    case empire

    public var displayName: String {
        switch self {
        case .duchy: return "Duchy"
        case .kingdom: return "Kingdom"
        case .empire: return "Empire"
        }
    }

    public var baseAcceptedSlots: Int {
        switch self {
        case .duchy: return 1
        case .kingdom: return 2
        case .empire: return 3
        }
    }
}

public enum CultureModel {
    /// Tax efficiency multipliers by cultural acceptance tier.
    public static let taxAccepted = 1.0
    public static let taxSameFamily = 0.90
    public static let taxForeign = 0.80

    /// Manpower / levy multipliers by cultural acceptance tier.
    public static let manpowerAccepted = 1.0
    public static let manpowerSameFamily = 0.80
    public static let manpowerForeign = 0.50

    /// Pop satisfaction target offsets (0...1 scale) by cultural acceptance tier.
    public static let moodAccepted = 0.0
    public static let moodSameFamily = -0.04
    public static let moodForeign = -0.09

    /// Monthly satisfaction penalty applied to a culture's pops when revoked.
    public static let revokeSatisfactionHit = 0.08

    /// Slow monthly assimilation settings.
    public static let minAssimilationSatisfaction = 0.55
    public static let baseAssimilationRate = 0.0025
    public static let maxMonthlyAssimilationRate = 0.05

    /// Monthly devastation, famine, and migration rates.
    public static let siegeDevastationGain = 0.08
    public static let battleDevastationGain = 0.05
    public static let peaceDevastationDecay = 0.025
    public static let maxMonthlyMigrationRate = 0.12
    public static let minRemainingPopAfterMigration = 25.0
}

public enum AcceptCultureError: Equatable, Sendable {
    case isPrimaryCulture
    case alreadyAccepted
    case noAvailableSlots
    case notPresentInCountry

    public var reason: String {
        switch self {
        case .isPrimaryCulture: return "This is already your primary culture."
        case .alreadyAccepted: return "This culture is already accepted."
        case .noAvailableSlots: return "No accepted culture slots free."
        case .notPresentInCountry: return "No pops of this culture live in your realm."
        }
    }
}

/// Manages government ranks, accepted cultures & penalties, cultural assimilation,
/// devastation/famine tracking, and population-conserving migration (Phase 11 Part C).
public enum CultureSystem {

    // MARK: - Rank, Slots, & Penalties

    public static func governmentRank(_ world: World, _ country: CountryID) -> GovernmentRank {
        guard country.index < world.countries.count else { return .duchy }
        if world.countries.overlord[country.index] != nil {
            return .duchy
        }
        var totalDev = 0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            totalDev += world.provinces.development[p]
        }
        if totalDev >= 125 { return .empire }
        if totalDev >= 45 { return .kingdom }
        return .duchy
    }

    public static func acceptedCultureSlots(_ world: World, _ country: CountryID) -> Int {
        guard country.index < world.countries.count else { return 1 }
        let base = governmentRank(world, country).baseAcceptedSlots
        let lawBonus = Int(world.government.modifier(country, .acceptedCultures).rounded())
        return max(0, base + lawBonus)
    }

    @inline(__always)
    public static func isAccepted(_ world: World, country: CountryID, culture: CultureID) -> Bool {
        let c = country.index
        guard c < world.countries.count else { return true }
        return culture == world.countries.primaryCulture[c] || world.countries.acceptedCultures[c].contains(culture)
    }

    @inline(__always)
    public static func isSameFamily(_ world: World, country: CountryID, culture: CultureID) -> Bool {
        let c = country.index
        guard c < world.countries.count else { return false }
        let primary = world.countries.primaryCulture[c]
        guard primary.index < world.cultures.count, culture.index < world.cultures.count else { return false }
        return world.cultures.family[culture.index] == world.cultures.family[primary.index]
    }

    @inline(__always)
    public static func taxMultiplier(_ world: World, country: CountryID, culture: CultureID) -> Double {
        if isAccepted(world, country: country, culture: culture) { return CultureModel.taxAccepted }
        if isSameFamily(world, country: country, culture: culture) { return CultureModel.taxSameFamily }
        return CultureModel.taxForeign
    }

    @inline(__always)
    public static func manpowerMultiplier(_ world: World, country: CountryID, culture: CultureID) -> Double {
        if isAccepted(world, country: country, culture: culture) { return CultureModel.manpowerAccepted }
        if isSameFamily(world, country: country, culture: culture) { return CultureModel.manpowerSameFamily }
        return CultureModel.manpowerForeign
    }

    @inline(__always)
    public static func moodPenalty(_ world: World, country: CountryID, culture: CultureID) -> Double {
        if isAccepted(world, country: country, culture: culture) { return CultureModel.moodAccepted }
        if isSameFamily(world, country: country, culture: culture) { return CultureModel.moodSameFamily }
        return CultureModel.moodForeign
    }

    /// Pop-size-weighted manpower efficiency factor (0.50...1.0) in `province` for `country`.
    public static func provinceManpowerFactor(_ world: World, province: ProvinceID, owner: CountryID) -> Double {
        provinceManpowerFactor(world, province: province, owner: owner, standing: CultureStanding(world, only: owner))
    }

    public static func provinceManpowerFactor(_ world: World, province: ProvinceID, owner: CountryID, standing: CultureStanding) -> Double {
        var total = 0.0
        var weighted = 0.0
        for i in world.pops.range(for: province) {
            let s = world.pops.size[i]
            guard s > 0 else { continue }
            total += s
            weighted += s * standing.manpower(world, owner, world.pops.culture[i])
        }
        return total > 0 ? weighted / total : 1.0
    }

    // MARK: - Player Actions

    public static func acceptRefusal(_ world: World, country: CountryID, culture: CultureID) -> AcceptCultureError? {
        let c = country.index
        guard c < world.countries.count, culture.index < world.cultures.count else { return .notPresentInCountry }
        if culture == world.countries.primaryCulture[c] { return .isPrimaryCulture }
        if world.countries.acceptedCultures[c].contains(culture) { return .alreadyAccepted }
        if world.countries.acceptedCultures[c].count >= acceptedCultureSlots(world, country) { return .noAvailableSlots }

        var present = false
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            for i in world.pops.range(for: ProvinceID(p)) where world.pops.culture[i] == culture && world.pops.size[i] > 0 {
                present = true
                break
            }
            if present { break }
        }
        return present ? nil : .notPresentInCountry
    }

    @discardableResult
    public static func acceptCulture(_ world: inout World, country: CountryID, culture: CultureID, date: GameDate) -> AcceptCultureError? {
        if let err = acceptRefusal(world, country: country, culture: culture) {
            return err
        }
        world.countries.acceptedCultures[country.index].insert(culture)
        let name = world.cultures.name[culture.index]
        world.people.record(date, country, "\(name) is now an accepted culture in the realm.")
        return nil
    }

    @discardableResult
    public static func revokeCulture(_ world: inout World, country: CountryID, culture: CultureID, date: GameDate) -> Bool {
        let c = country.index
        guard c < world.countries.count, world.countries.acceptedCultures[c].contains(culture) else { return false }
        world.countries.acceptedCultures[c].remove(culture)
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            for i in world.pops.range(for: ProvinceID(p)) where world.pops.culture[i] == culture {
                world.pops.satisfaction[i] = max(0, world.pops.satisfaction[i] - CultureModel.revokeSatisfactionHit)
            }
        }
        let name = world.cultures.name[culture.index]
        world.people.record(date, country, "\(name) status was revoked.")
        return true
    }

    // MARK: - Monthly Tick

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        let C = world.countries.count
        guard P > 0, C > 0 else { return }

        updateDevastationAndFamine(&world, provinceCount: P)
        runAssimilation(&world, provinceCount: P, countryCount: C)
        runMigration(&world, provinceCount: P, countryCount: C, random: &random)
        world.pops.foldDust(provinceCount: P)
    }

    // MARK: - Devastation & Famine

    private static func updateDevastationAndFamine(_ world: inout World, provinceCount P: Int) {
        var underSiege = Array(repeating: false, count: P)
        for s in world.military.sieges where s.province.index < P {
            underSiege[s.province.index] = true
        }
        var inBattle = Array(repeating: false, count: P)
        for b in world.military.battles where b.province.index < P {
            inBattle[b.province.index] = true
        }

        // Per-market food fulfillment ratio (average `met` across food goods).
        let eco = world.economy
        let M = eco.markets.count
        let G = eco.goods.count
        let foodIndices = (0..<G).filter { eco.goods.category[$0] == .food }
        var marketFoodMet = Array(repeating: 1.0, count: M)
        if !foodIndices.isEmpty {
            for m in 0..<M {
                var sum = 0.0
                for g in foodIndices {
                    sum += eco.markets.met[m * G + g]
                }
                marketFoodMet[m] = sum / Double(foodIndices.count)
            }
        }

        for p in 0..<P {
            if world.provinces.occupiedBy[p] != nil || underSiege[p] {
                world.provinces.devastation[p] = min(1.0, world.provinces.devastation[p] + CultureModel.siegeDevastationGain)
            } else if inBattle[p] {
                world.provinces.devastation[p] = min(1.0, world.provinces.devastation[p] + CultureModel.battleDevastationGain)
            } else {
                world.provinces.devastation[p] = max(0.0, world.provinces.devastation[p] - CultureModel.peaceDevastationDecay)
            }

            if p < eco.provinceMarket.count {
                let m = eco.provinceMarket[p].index
                if m < M && marketFoodMet[m] < 0.85 {
                    let severity = min(1.0, (0.85 - marketFoodMet[m]) * 2.5)
                    world.provinces.famine[p] = max(world.provinces.famine[p], severity)
                } else {
                    world.provinces.famine[p] = max(0.0, world.provinces.famine[p] - 0.15)
                }
            }
        }
    }

    // MARK: - Assimilation

    private static func runAssimilation(_ world: inout World, provinceCount P: Int, countryCount C: Int) {
        var pending: [PopTable.Row] = []
        var anyZero = false
        var dirty: [Int] = []
        dirty.reserveCapacity(128)

        for p in 0..<P {
            let pid = ProvinceID(p)
            guard let owner = world.provinces.owner[p],
                  world.provinces.occupiedBy[p] == nil else {
                world.provinces.assimilationProgress[p] = 0
                continue
            }
            let o = owner.index
            let targetCulture = world.countries.primaryCulture[o]
            let stateRel = world.countries.religion[o]

            let nearTargetCulture = world.provinces.majorityCulture[p] == targetCulture
                || world.provinces.neighbors[p].contains { world.provinces.majorityCulture[$0.index] == targetCulture }
            let canAssimilate = nearTargetCulture && world.provinces.religion[p] == stateRel

            let range = world.pops.range(for: pid)
            var totalPop = 0.0
            var targetPop = 0.0
            var changedHere = false

            if !canAssimilate {
                for i in range {
                    let sz = world.pops.size[i]
                    guard sz > 1e-9 else { continue }
                    totalPop += sz
                    if world.pops.culture[i] == targetCulture { targetPop += sz }
                }
                world.provinces.assimilationProgress[p] = totalPop > 0 ? min(1.0, targetPop / totalPop) : 1.0
                continue
            }

            for i in range {
                let sz = world.pops.size[i]
                guard sz > 1e-9 else { continue }
                let cult = world.pops.culture[i]
                let sat = world.pops.satisfaction[i]

                if cult == targetCulture {
                    totalPop += sz
                    targetPop += sz
                    continue
                }

                guard world.pops.religion[i] == stateRel,
                      sat >= CultureModel.minAssimilationSatisfaction else {
                    totalPop += sz
                    continue
                }

                let satBoost = 1.0 + (sat - CultureModel.minAssimilationSatisfaction) * 2.0
                let devBoost = 1.0 + Double(min(10, world.provinces.development[p])) * 0.04
                let rate = min(CultureModel.maxMonthlyAssimilationRate, CultureModel.baseAssimilationRate * satBoost * devBoost)

                var delta = sz * rate
                if sz - delta < 1.0 {
                    delta = sz
                    anyZero = true
                }

                let popRel = world.pops.religion[i]
                let popSect = world.pops.sect[i]
                let cls = world.pops.socialClass[i]

                var mergedIdx: Int?
                for j in range where world.pops.culture[j] == targetCulture
                    && world.pops.religion[j] == popRel
                    && world.pops.sect[j] == popSect
                    && world.pops.socialClass[j] == cls
                    && world.pops.size[j] > 0 {
                    mergedIdx = j
                    break
                }

                if mergedIdx == nil && delta < PopDust.minNewGroup && delta < sz {
                    totalPop += sz
                    continue
                }
                world.pops.size[i] -= delta
                changedHere = true
                if let j = mergedIdx {
                    let prev = world.pops.size[j]
                    world.pops.satisfaction[j] = (world.pops.satisfaction[j] * prev + sat * delta) / (prev + delta)
                    world.pops.size[j] = prev + delta
                } else {
                    pending.append(PopTable.Row(
                        province: pid,
                        culture: targetCulture,
                        religion: popRel,
                        sect: popSect,
                        socialClass: cls,
                        size: delta,
                        satisfaction: sat
                    ))
                }
                totalPop += sz
                targetPop += delta
            }
            if changedHere { dirty.append(p) }
            world.provinces.assimilationProgress[p] = totalPop > 0 ? min(1.0, targetPop / totalPop) : 1.0
        }

        if !pending.isEmpty || anyZero {
            world.pops.rebuild(provinceCount: P, extraRows: pending)
        }
        if !dirty.isEmpty {
            world.refreshProvinceSummaries(for: dirty)
        }
    }

    // MARK: - Migration (Conserving Total Population)

    private static func runMigration(
        _ world: inout World,
        provinceCount P: Int,
        countryCount C: Int,
        random: inout GameRandom
    ) {
        world.provinces.lastNetMigration = Array(repeating: 0.0, count: P)

        // Precompute faith law per country for persecution & tolerance bonuses.
        let g = world.government
        let faithAreaIdx = g.rules.lawAreas.firstIndex(where: { $0.key == "faith" })
        var countryFaithCode = Array(repeating: 1, count: C) // 0: orthodoxy, 1: tolerance, 2: open
        for c in 0..<min(C, g.count) {
            if let area = faithAreaIdx, area < g.laws[c].count {
                let optIdx = g.laws[c][area]
                let opts = g.rules.lawAreas[area].options
                if optIdx < opts.count {
                    switch opts[optIdx].key {
                    case "orthodoxy": countryFaithCode[c] = 0
                    case "open": countryFaithCode[c] = 2
                    default: countryFaithCode[c] = 1
                    }
                }
            }
        }

        // Precompute per-province attractiveness score.
        var attractiveness = Array(repeating: 0.0, count: P)
        for p in 0..<P {
            var score = Double(world.provinces.development[p]) * 1.2
            score -= world.provinces.devastation[p] * 12.0
            score -= world.provinces.famine[p] * 14.0
            score -= world.provinces.religiousUnrest[p] * 0.25
            // People shun a town where the sick are dying (Phase 12).
            score -= world.calamity.totalInfection(p) * 100.0
            if world.provinces.occupiedBy[p] != nil { score -= 10.0 }
            if let owner = world.provinces.owner[p] {
                let f = countryFaithCode[owner.index]
                if f == 2 { score += 2.0 }
                else if f == 0 { score -= 0.5 }
            }
            attractiveness[p] = score
        }

        // Precompute top 2 attractive provinces per market & trade links between markets.
        let eco = world.economy
        let M = eco.markets.count
        var topInMarket = Array(repeating: [Int](), count: M)
        if eco.provinceMarket.count == P {
            var buckets = Array(repeating: [(prov: Int, score: Double)](), count: M)
            for p in 0..<P where world.provinces.devastation[p] < 0.3 && world.provinces.famine[p] < 0.25 && world.provinces.occupiedBy[p] == nil {
                let m = eco.provinceMarket[p].index
                if m < M {
                    buckets[m].append((p, attractiveness[p]))
                }
            }
            for m in 0..<M {
                buckets[m].sort { $0.score == $1.score ? $0.prov < $1.prov : $0.score > $1.score }
                topInMarket[m] = buckets[m].prefix(2).map(\.prov)
            }
        }

        var marketPartners: [Int: [Int]] = [:]
        for r in eco.routes {
            marketPartners[r.from.index, default: []].append(r.to.index)
            marketPartners[r.to.index, default: []].append(r.from.index)
        }
        let sortedMarketPartners = marketPartners.mapValues { Array(Set($0)).sorted() }

        var pending: [PopTable.Row] = []
        var anyZero = false
        var dirtySet = Array(repeating: false, count: P)

        for p in 0..<P {
            let dev = world.provinces.devastation[p]
            let fam = world.provinces.famine[p]
            let unrest = world.provinces.religiousUnrest[p]
            let devPush = dev > 0.05 ? dev * 0.015 : 0.0
            let famPush = fam > 0.05 ? fam * 0.020 : 0.0
            let faithPush: Double
            if unrest >= 6.0 {
                let fCode = world.provinces.owner[p].map { countryFaithCode[$0.index] } ?? 1
                faithPush = (unrest / 100.0) * 0.012 * (fCode == 0 ? 1.5 : 1.0)
            } else {
                faithPush = 0.0
            }

            // Flight from plague; a cordon keeps people in (and out).
            let sick = world.calamity.totalInfection(p)
            let plaguePush = sick > 0.005 ? sick * 0.5 : 0.0
            if world.calamity.isCordoned(p) { continue }

            let maxPotentialPush = devPush + famPush + faithPush + plaguePush
            guard maxPotentialPush > 0.0005,
                  world.provinces.population[p] > CultureModel.minRemainingPopAfterMigration else {
                continue
            }

            // Collect neighbor + trade-route candidate destinations with higher attractiveness.
            let myAttr = attractiveness[p]
            var seenDest: Set<Int> = []
            var candidates: [(prov: Int, weight: Double)] = []

            for n in world.provinces.neighbors[p] {
                let q = n.index
                if q != p, !seenDest.contains(q),
                   world.provinces.devastation[q] < 0.35,
                   world.provinces.famine[q] < 0.25,
                   world.provinces.occupiedBy[q] == nil,
                   !world.calamity.isCordoned(q),
                   attractiveness[q] > myAttr + 0.1 {
                    seenDest.insert(q)
                    candidates.append((q, max(0.5, attractiveness[q] - myAttr)))
                }
            }
            if p < eco.provinceMarket.count {
                let m = eco.provinceMarket[p].index
                if let partners = sortedMarketPartners[m] {
                    for pm in partners where pm < M {
                        for q in topInMarket[pm] where q != p && !seenDest.contains(q) && attractiveness[q] > myAttr + 0.5
                            && !world.calamity.isCordoned(q) {
                            seenDest.insert(q)
                            candidates.append((q, max(0.5, (attractiveness[q] - myAttr) * 0.6)))
                        }
                    }
                }
            }

            guard !candidates.isEmpty else { continue }
            candidates.sort { $0.weight == $1.weight ? $0.prov < $1.prov : $0.weight > $1.weight }
            let chosen = Array(candidates.prefix(4))
            let weightSum = chosen.reduce(0.0) { $0 + $1.weight }
            guard weightSum > 0 else { continue }

            let ownerRel = world.provinces.owner[p].map { world.countries.religion[$0.index] }
            let pid = ProvinceID(p)
            let range = world.pops.range(for: pid)

            for i in range {
                let sz = world.pops.size[i]
                guard sz > 10.0, world.pops.socialClass[i] != .slaves else { continue }
                let isPersecuted = ownerRel != nil && world.pops.religion[i] != ownerRel!
                let rowRate = min(
                    CultureModel.maxMonthlyMigrationRate,
                    devPush + famPush + plaguePush + (isPersecuted ? faithPush : 0.0)
                )
                guard rowRate > 0.0005 else { continue }

                // Leave a tiny baseline floor so we don't empty whole provinces abruptly.
                let movable = max(0.0, min(sz - 5.0, sz * rowRate))
                guard movable > 0.01 else { continue }

                let cult = world.pops.culture[i]
                let rel = world.pops.religion[i]
                let sect = world.pops.sect[i]
                let cls = world.pops.socialClass[i]
                let sat = world.pops.satisfaction[i]

                // Track the exact sum added to destinations so total world pop is conserved bit-for-bit.
                var actualMoved = 0.0
                for dest in chosen {
                    let jitter = 0.9 + 0.2 * Double.random(in: 0..<1, using: &random)
                    let share = (dest.weight / weightSum) * movable * jitter
                    let clampedShare = min(movable - actualMoved, share)
                    guard clampedShare > 0.001 else { continue }
                    actualMoved += clampedShare
                    let destID = ProvinceID(dest.prov)
                    var mergedIdx: Int?
                    for j in world.pops.range(for: destID) where world.pops.culture[j] == cult
                        && world.pops.religion[j] == rel
                        && world.pops.sect[j] == sect
                        && world.pops.socialClass[j] == cls
                        && world.pops.size[j] > 0 {
                        mergedIdx = j
                        break
                    }
                    if mergedIdx == nil && clampedShare < PopDust.minNewGroup {
                        actualMoved -= clampedShare
                        continue
                    }
                    if let j = mergedIdx {
                        let prev = world.pops.size[j]
                        world.pops.satisfaction[j] = (world.pops.satisfaction[j] * prev + sat * clampedShare) / (prev + clampedShare)
                        world.pops.size[j] = prev + clampedShare
                    } else {
                        pending.append(PopTable.Row(
                            province: destID,
                            culture: cult,
                            religion: rel,
                            sect: sect,
                            socialClass: cls,
                            size: clampedShare,
                            satisfaction: sat
                        ))
                    }
                    dirtySet[dest.prov] = true
                    world.provinces.lastNetMigration[dest.prov] += clampedShare
                }

                if actualMoved > 0 {
                    world.pops.size[i] -= actualMoved
                    if world.pops.size[i] <= 1e-9 { anyZero = true }
                    dirtySet[p] = true
                    world.provinces.lastNetMigration[p] -= actualMoved
                }
            }
        }

        if !pending.isEmpty || anyZero {
            world.pops.rebuild(provinceCount: P, extraRows: pending)
        }
        let dirtyProvs = (0..<P).filter { dirtySet[$0] }
        if !dirtyProvs.isEmpty {
            world.refreshProvinceSummaries(for: dirtyProvs)
        }
    }
}

/// Accepted / same family / foreign for each (country, culture), built once
/// and then read per pop (review speed-up: the per-pop checks compared
/// culture families as strings and passed the whole World each time, which
/// tripled the monthly economy's cost). Same answers as `isAccepted` and
/// `isSameFamily`; anything outside the table falls back to them.
public struct CultureStanding {
    private let k: Int
    private let firstCountry: Int
    private let countryCount: Int
    private var cat: [UInt8]   // 0 accepted, 1 same family, 2 foreign

    /// All countries, or only `only` (for code that works one country at a time).
    public init(_ world: World, only: CountryID? = nil) {
        let K = world.cultures.count
        k = K
        var famID: [String: Int] = [:]
        var fam = [Int](repeating: -1, count: K)
        for x in 0..<K {
            let f = world.cultures.family[x]
            if let id = famID[f] { fam[x] = id } else { let id = famID.count; famID[f] = id; fam[x] = id }
        }
        let range: Range<Int>
        if let one = only, one.index < world.countries.count {
            range = one.index..<(one.index + 1)
        } else if only != nil {
            range = 0..<0
        } else {
            range = 0..<world.countries.count
        }
        firstCountry = range.lowerBound
        countryCount = range.count
        cat = [UInt8](repeating: 2, count: range.count * K)
        for c in range {
            let row = (c - range.lowerBound) * K
            let primary = world.countries.primaryCulture[c].index
            if primary < K {
                let pf = fam[primary]
                for x in 0..<K where fam[x] == pf { cat[row + x] = 1 }
                cat[row + primary] = 0
            }
            for a in world.countries.acceptedCultures[c] where a.index < K {
                cat[row + a.index] = 0
            }
        }
    }

    @inline(__always)
    public func category(_ world: World, _ country: CountryID, _ culture: CultureID) -> UInt8 {
        let c = country.index - firstCountry
        if c >= 0 && c < countryCount && culture.index < k {
            return cat[c * k + culture.index]
        }
        if CultureSystem.isAccepted(world, country: country, culture: culture) { return 0 }
        return CultureSystem.isSameFamily(world, country: country, culture: culture) ? 1 : 2
    }

    @inline(__always)
    public func tax(_ world: World, _ country: CountryID, _ culture: CultureID) -> Double {
        switch category(world, country, culture) {
        case 0: return CultureModel.taxAccepted
        case 1: return CultureModel.taxSameFamily
        default: return CultureModel.taxForeign
        }
    }

    @inline(__always)
    public func manpower(_ world: World, _ country: CountryID, _ culture: CultureID) -> Double {
        switch category(world, country, culture) {
        case 0: return CultureModel.manpowerAccepted
        case 1: return CultureModel.manpowerSameFamily
        default: return CultureModel.manpowerForeign
        }
    }

    @inline(__always)
    public func mood(_ world: World, _ country: CountryID, _ culture: CultureID) -> Double {
        switch category(world, country, culture) {
        case 0: return CultureModel.moodAccepted
        case 1: return CultureModel.moodSameFamily
        default: return CultureModel.moodForeign
        }
    }
}
