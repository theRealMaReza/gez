import Foundation

/// Historical religious movements in Phase 11 Part B:
/// - Bohemia: the Utraquist / Taborite question from 1453
/// - Persia & Anatolia: Sufi orders and the Safaviyya -> Qizilbash -> Safavid rise
/// - Europe: the Protestant & Reformed Reformation (~1517, never before 1500)
public enum MovementSystem {

    // MARK: - Player Decisions

    /// Resolves the Utraquist/Taborite debate in Bohemia (`BOH`).
    @discardableResult
    public static func resolveHussiteQuestion(
        _ world: inout World,
        choice: HussiteOutcome,
        by actor: CountryID?,
        date: GameDate
    ) -> Bool {
        guard world.faith.hussiteOutcome == .unresolved, choice != .unresolved else { return false }
        guard let boh = world.countries.id(forTag: "BOH") else { return false }
        if let actor, actor != boh { return false }

        world.faith.hussiteOutcome = choice
        let pap = world.countries.id(forTag: "PAP")

        switch choice {
        case .utraquistCompacts:
            world.faith.hussiteCompactsActive = true
            for p in 0..<world.provinces.count where world.provinces.owner[p] == boh {
                world.provinces.religiousUnrest[p] *= 0.5
            }
            world.people.record(date, boh, "Bohemia upholds the Compacts of Basel between Utraquists and Catholics.")

        case .taboriteRevival:
            world.faith.hussiteCompactsActive = false
            world.countries.religion[boh.index] = .hussite
            world.countries.prestige[boh.index] = min(100, world.countries.prestige[boh.index] + 10)
            for p in 0..<world.provinces.count where world.provinces.owner[p] == boh {
                if world.provinces.religion[p] == .catholic {
                    world.provinces.religiousUnrest[p] = min(100, world.provinces.religiousUnrest[p] + 8)
                }
            }
            if let pap {
                world.diplomacy.modifyOpinion(of: boh, by: pap, delta: -20)
            }
            // Zeal converts a portion of Catholic minorities in Bohemia immediately.
            var pending: [PopTable.Row] = []
            var anyZero = false
            for p in 0..<world.provinces.count where world.provinces.owner[p] == boh {
                shiftReligion(in: ProvinceID(p), from: .catholic, to: .hussite, fraction: 0.15, world: &world, pending: &pending, anyZero: &anyZero)
            }
            if !pending.isEmpty || anyZero {
                world.pops.rebuild(provinceCount: world.provinces.count, extraRows: pending)
            }
            world.refreshProvinceSummaries()
            world.people.record(date, boh, "Taborite zealots overturn the Basel Compacts in Bohemia.")

        case .catholicSubmission:
            world.faith.hussiteCompactsActive = false
            world.countries.religion[boh.index] = .catholic
            for p in 0..<world.provinces.count where world.provinces.owner[p] == boh {
                if world.provinces.religion[p] == .hussite {
                    world.provinces.religiousUnrest[p] = min(100, world.provinces.religiousUnrest[p] + 12)
                }
            }
            if let pap {
                world.diplomacy.modifyOpinion(of: boh, by: pap, delta: 20)
            }
            world.people.record(date, boh, "The Bohemian crown submits to Rome and revokes the Compacts.")

        case .unresolved:
            break
        }
        return true
    }

    /// Allows a Christian realm to embrace Protestantism or the Reformed faith once the Reformation has begun.
    @discardableResult
    public static func adoptReformationReligion(
        _ world: inout World,
        country: CountryID,
        religion: Religion,
        date: GameDate
    ) -> Bool {
        guard world.faith.reformationStarted,
              (religion == .protestant || religion == .reformed),
              world.faith.reformationReligions.contains(religion) ||
              world.faith.reformationCentres.contains(where: { $0.religion == religion }),
              country.index < world.countries.count else {
            return false
        }
        let current = world.countries.religion[country.index]
        guard current.family == .christian, current != religion, world.countries.tag[country.index] != "PAP" else {
            return false
        }
        world.countries.religion[country.index] = religion
        world.countries.prestige[country.index] = min(100, world.countries.prestige[country.index] + 5)
        // Adopting the new confession nudges minorities in the capital.
        if let cap = world.countries.capital[country.index] {
            var pending: [PopTable.Row] = []
            var anyZero = false
            shiftReligion(in: cap, from: .catholic, to: religion, fraction: 0.25, world: &world, pending: &pending, anyZero: &anyZero)
            if !pending.isEmpty || anyZero {
                world.pops.rebuild(provinceCount: world.provinces.count, extraRows: pending)
            }
            world.refreshProvinceSummaries()
        }
        world.people.record(date, country, "\(world.countries.name[country.index]) embraces the \(religion.displayName) faith.")
        return true
    }

    // MARK: - Monthly Tick

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        updateHussites(&world, date: date, random: &random)
        updateSufiAndSafaviyya(&world, date: date, random: &random)
        updateReformation(&world, date: date, random: &random)
    }

    // MARK: - Hussites (1453+)

    private static func updateHussites(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard world.faith.hussiteOutcome == .unresolved,
              let boh = world.countries.id(forTag: "BOH") else {
            return
        }
        // Let human-played Bohemia decide; AI evaluates in a weighted 1454-1471 window.
        guard !world.humanCountries.contains(boh), date.year >= 1454 else { return }
        let monthlyChance: Double
        if date.year < 1463 {
            monthlyChance = 0.025
        } else if date.year < 1471 {
            monthlyChance = 0.06
        } else {
            monthlyChance = 0.25
        }
        guard Double.random(in: 0..<1, using: &random) < monthlyChance else { return }

        let roll = Double.random(in: 0..<1, using: &random)
        let choice: HussiteOutcome
        if roll < 0.55 {
            choice = .utraquistCompacts
        } else if roll < 0.80 {
            choice = .taboriteRevival
        } else {
            choice = .catholicSubmission
        }
        resolveHussiteQuestion(&world, choice: choice, by: boh, date: date)
    }

    // MARK: - Sufi Orders & Safaviyya / Qizilbash

    private static func updateSufiAndSafaviyya(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        var newSeeds: [(province: Int, order: SufiOrder)] = []
        var anyChanged = false

        // 1. Sufi orders gain influence slowly in Muslim lands and spread along borders.
        for p in 0..<P {
            let orders = world.provinces.sufiOrders[p]
            guard !orders.isEmpty else { continue }
            let isMuslimProv = world.provinces.religion[p].family == .muslim
            let ownerMuslim = world.provinces.owner[p].map { world.countries.religion[$0.index].family == .muslim } ?? false
            guard isMuslimProv || ownerMuslim else { continue }

            var updated = orders
            for idx in updated.indices {
                let growth = updated[idx].order == .safaviyya ? 0.004 : 0.0025
                if updated[idx].strength < 1.0 {
                    updated[idx].strength = min(1.0, updated[idx].strength + growth)
                    anyChanged = true
                }
                if updated[idx].strength >= 0.45 && Double.random(in: 0..<1, using: &random) < 0.004 {
                    let neighbors = world.provinces.neighbors[p]
                    if !neighbors.isEmpty {
                        let pick = neighbors[Int.random(in: 0...(neighbors.count - 1), using: &random)].index
                        let targetMuslim = world.provinces.religion[pick].family == .muslim
                            || (world.provinces.owner[pick].map { world.countries.religion[$0.index].family == .muslim } ?? false)
                        if targetMuslim {
                            newSeeds.append((pick, updated[idx].order))
                        }
                    }
                }
            }
            world.provinces.sufiOrders[p] = updated
        }

        for (provIdx, ord) in newSeeds {
            if !world.provinces.sufiOrders[provIdx].contains(where: { $0.order == ord }) &&
                world.provinces.sufiOrders[provIdx].count < 3 {
                world.provinces.sufiOrders[provIdx].append(SufiPresence(order: ord, strength: 0.15))
                anyChanged = true
            }
        }

        // 2. Safaviyya in Ardabil -> Qizilbash movement -> Safavid Twelver rise.
        guard let ardabil = world.provinces.id(named: "Ardabil") else { return }
        let ardOwner = world.provinces.owner[ardabil.index]
        let ardOwnerRel = ardOwner.map { world.countries.religion[$0.index] }

        switch world.faith.safaviyyaPhase {
        case .dormant:
            world.faith.safaviyyaPhase = .growing

        case .growing:
            let boost = (ardOwnerRel == .sunni ? 0.004 : 0.0025) + (date.year >= 1470 ? 0.003 : 0.0)
            world.faith.safaviyyaStrength = min(1.0, world.faith.safaviyyaStrength + boost)
            guard date.year >= 1470, world.faith.safaviyyaStrength >= 0.40 else { break }

            let militantProb: Double
            if date.year < 1485 { militantProb = 0.015 }
            else if date.year < 1502 { militantProb = 0.055 }
            else { militantProb = 0.25 }

            if Double.random(in: 0..<1, using: &random) < militantProb {
                world.faith.safaviyyaPhase = .militant
                world.faith.safaviyyaYear = date.year

                let targets = [ardabil] + world.provinces.neighbors[ardabil.index]
                var pending: [PopTable.Row] = []
                var anyZero = false
                for pid in targets {
                    if !world.provinces.sufiOrders[pid.index].contains(where: { $0.order == .safaviyya }) {
                        world.provinces.sufiOrders[pid.index].append(SufiPresence(order: .safaviyya, strength: 0.65))
                    } else {
                        for idx in world.provinces.sufiOrders[pid.index].indices where world.provinces.sufiOrders[pid.index][idx].order == .safaviyya {
                            world.provinces.sufiOrders[pid.index][idx].strength = max(world.provinces.sufiOrders[pid.index][idx].strength, 0.75)
                        }
                    }
                    shiftReligion(in: pid, from: .sunni, to: .twelver, fraction: 0.25, world: &world, pending: &pending, anyZero: &anyZero)
                    world.provinces.religiousUnrest[pid.index] = min(100, world.provinces.religiousUnrest[pid.index] + 8)
                }
                if !pending.isEmpty || anyZero {
                    world.pops.rebuild(provinceCount: P, extraRows: pending)
                }
                world.refreshProvinceSummaries()
                if let ardOwner {
                    world.people.record(date, ardOwner, "The Safaviyya of Ardabil raise the Qizilbash movement across Azerbaijan.")
                }
            }

        case .militant:
            world.faith.safaviyyaStrength = min(1.0, world.faith.safaviyyaStrength + 0.004)
            // Monthly Qizilbash preaching in Ardabil and neighbors.
            var pending: [PopTable.Row] = []
            var anyZero = false
            shiftReligion(in: ardabil, from: .sunni, to: .twelver, fraction: 0.025, world: &world, pending: &pending, anyZero: &anyZero)
            for n in world.provinces.neighbors[ardabil.index] {
                shiftReligion(in: n, from: .sunni, to: .twelver, fraction: 0.012, world: &world, pending: &pending, anyZero: &anyZero)
            }
            if !pending.isEmpty || anyZero {
                world.pops.rebuild(provinceCount: P, extraRows: pending)
                anyChanged = true
            }

            guard date.year >= 1488 else { break }
            let triumphProb: Double = date.year < 1500 ? 0.03 : (date.year < 1510 ? 0.09 : 0.25)
            if Double.random(in: 0..<1, using: &random) < triumphProb {
                world.faith.safaviyyaPhase = .triumphant
                world.faith.safaviyyaYear = date.year
                if let ardOwner, !world.humanCountries.contains(ardOwner) {
                    let tag = world.countries.tag[ardOwner.index]
                    if tag != "TUR" && tag != "MAM" && world.countries.religion[ardOwner.index] != .twelver {
                        world.countries.religion[ardOwner.index] = .twelver
                        world.countries.prestige[ardOwner.index] = min(100, world.countries.prestige[ardOwner.index] + 15)
                        world.people.record(date, ardOwner, "The Qizilbash triumph: \(world.countries.name[ardOwner.index]) proclaims Twelver Shi'ism.")
                    }
                }
                var risePending: [PopTable.Row] = []
                var riseZero = false
                for pid in [ardabil] + world.provinces.neighbors[ardabil.index] {
                    shiftReligion(in: pid, from: .sunni, to: .twelver, fraction: 0.35, world: &world, pending: &risePending, anyZero: &riseZero)
                }
                if !risePending.isEmpty || riseZero {
                    world.pops.rebuild(provinceCount: P, extraRows: risePending)
                }
                anyChanged = true
            }

        case .triumphant:
            // Ongoing Twelver preaching in Ardabil/Azerbaijan for the first 25 years.
            if let year = world.faith.safaviyyaYear, date.year - year < 25 {
                var pending: [PopTable.Row] = []
                var anyZero = false
                for pid in [ardabil] + world.provinces.neighbors[ardabil.index] {
                    shiftReligion(in: pid, from: .sunni, to: .twelver, fraction: 0.015, world: &world, pending: &pending, anyZero: &anyZero)
                }
                if !pending.isEmpty || anyZero {
                    world.pops.rebuild(provinceCount: P, extraRows: pending)
                    anyChanged = true
                }
            }
        }

        if anyChanged {
            world.refreshProvinceSummaries()
        }
    }

    // MARK: - Reformation (Never before 1500; ~1517)

    private static func updateReformation(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard date.year >= FaithModel.minReformationYear else { return }

        let P = world.provinces.count

        // 1. Potentially spark the Reformation if not yet started.
        if !world.faith.reformationStarted {
            let startProb: Double
            switch date.year {
            case ..<1512: startProb = 0.002
            case 1512...1515: startProb = 0.015
            case 1516...1520: startProb = 0.07
            case 1521...1526: startProb = 0.16
            case 1527...1528: startProb = 0.40
            default: startProb = 1.0 // guarantees Reformation arrives by ~1530 in every run
            }
            if Double.random(in: 0..<1, using: &random) < startProb {
                if let origin = pickReformationProvince(world: world, religion: .protestant, random: &random) {
                    spawnCentre(in: origin, religion: .protestant, world: &world, date: date)
                    world.faith.reformationStarted = true
                }
            }
        } else {
            // 2. Spawn additional Protestant (up to 3) and Reformed (up to 3) Centres.
            let protCount = world.faith.reformationCentres.filter { $0.religion == .protestant }.count
            let refCount = world.faith.reformationCentres.filter { $0.religion == .reformed }.count

            if protCount < 3 && Double.random(in: 0..<1, using: &random) < 0.035 {
                if let p = pickReformationProvince(world: world, religion: .protestant, random: &random) {
                    spawnCentre(in: p, religion: .protestant, world: &world, date: date)
                }
            }
            if date.year >= 1519 && refCount < 3 {
                let refProb = refCount == 0 ? (date.year >= 1526 ? 0.25 : 0.06) : 0.035
                if Double.random(in: 0..<1, using: &random) < refProb {
                    if let p = pickReformationProvince(world: world, religion: .reformed, random: &random) {
                        spawnCentre(in: p, religion: .reformed, world: &world, date: date)
                    }
                }
            }
        }

        guard !world.faith.reformationCentres.isEmpty else { return }

        // 3. Build market-and-trade lookup tables once per month for active centres.
        var marketPartners: [Int: [Int]] = [:]
        for r in world.economy.routes {
            marketPartners[r.from.index, default: []].append(r.to.index)
            marketPartners[r.to.index, default: []].append(r.from.index)
        }
        var provsByMarket: [Int: [ProvinceID]] = [:]
        if !marketPartners.isEmpty && world.economy.provinceMarket.count == P {
            for p in 0..<P where world.provinces.religion[p] == .catholic {
                let m = world.economy.provinceMarket[p].index
                provsByMarket[m, default: []].append(ProvinceID(p))
            }
        }

        var pending: [PopTable.Row] = []
        var anyZero = false

        for idx in world.faith.reformationCentres.indices {
            let months = world.faith.reformationCentres[idx].monthsActive
            guard months < 360 else { continue }
            world.faith.reformationCentres[idx].monthsActive += 1

            let centre = world.faith.reformationCentres[idx]
            let home = centre.province
            let targetRel = centre.religion

            // Strong home conversion
            shiftReligion(in: home, from: .catholic, to: targetRel, fraction: 0.05, world: &world, pending: &pending, anyZero: &anyZero)
            if targetRel == .reformed {
                shiftReligion(in: home, from: .protestant, to: .reformed, fraction: 0.015, world: &world, pending: &pending, anyZero: &anyZero)
            }

            // Neighbouring provinces (1st ring)
            for n in world.provinces.neighbors[home.index] {
                guard let owner = world.provinces.owner[n.index],
                      world.countries.tag[owner.index] != "PAP" else { continue }
                shiftReligion(in: n, from: .catholic, to: targetRel, fraction: 0.018, world: &world, pending: &pending, anyZero: &anyZero)
                // Occasional 2nd-ring spill
                if Double.random(in: 0..<1, using: &random) < 0.20 {
                    for n2 in world.provinces.neighbors[n.index] where n2 != home {
                        if let o2 = world.provinces.owner[n2.index], world.countries.tag[o2.index] != "PAP" {
                            shiftReligion(in: n2, from: .catholic, to: targetRel, fraction: 0.006, world: &world, pending: &pending, anyZero: &anyZero)
                        }
                    }
                }
            }

            // Spread along trade routes to linked markets
            if home.index < world.economy.provinceMarket.count {
                let m = world.economy.provinceMarket[home.index].index
                if let partners = marketPartners[m] {
                    // Deterministic order: sorted unique partner market IDs
                    let uniquePartners = Set(partners).sorted()
                    for partnerMarket in uniquePartners {
                        guard let candidates = provsByMarket[partnerMarket], !candidates.isEmpty else { continue }
                        let pick = candidates[Int.random(in: 0...(candidates.count - 1), using: &random)]
                        if let o = world.provinces.owner[pick.index], world.countries.tag[o.index] != "PAP" {
                            shiftReligion(in: pick, from: .catholic, to: targetRel, fraction: 0.008, world: &world, pending: &pending, anyZero: &anyZero)
                        }
                    }
                }
            }
        }

        if !pending.isEmpty || anyZero {
            world.pops.rebuild(provinceCount: P, extraRows: pending)
            world.refreshProvinceSummaries()
        }

        // 4. AI countries whose capital turns Protestant or Reformed can embrace the Reformation.
        for c in 0..<world.countries.count {
            let cid = CountryID(c)
            guard !world.humanCountries.contains(cid),
                  world.countries.tag[c] != "PAP",
                  world.countries.religion[c] == .catholic,
                  let cap = world.countries.capital[c] else {
                continue
            }
            let capRel = world.provinces.religion[cap.index]
            if (capRel == .protestant || capRel == .reformed) && Double.random(in: 0..<1, using: &random) < 0.25 {
                adoptReformationReligion(&world, country: cid, religion: capRel, date: date)
            }
        }
    }

    static func spawnCentre(in province: ProvinceID, religion: Religion, world: inout World, date: GameDate) {
        world.faith.reformationCentres.append(ReformationCentre(province: province, religion: religion, foundedYear: date.year))
        world.faith.reformationReligions.insert(religion)

        var pending: [PopTable.Row] = []
        var anyZero = false
        shiftReligion(in: province, from: .catholic, to: religion, fraction: 0.30, world: &world, pending: &pending, anyZero: &anyZero)
        if !pending.isEmpty || anyZero {
            world.pops.rebuild(provinceCount: world.provinces.count, extraRows: pending)
            world.refreshProvinceSummaries()
        }
        if let owner = world.provinces.owner[province.index] {
            world.people.record(date, owner, "A \(religion.displayName) Centre of Reformation rises in \(world.provinces.name[province.index]).")
        }
    }

    private static func pickReformationProvince(world: World, religion: Religion, random: inout GameRandom) -> ProvinceID? {
        let existing = Set(world.faith.reformationCentres.map(\.province))
        let preferredNames: [String] = religion == .protestant
            ? ["Wittenberg", "Augsburg", "Nuremberg", "Hamburg", "Lubeck", "Prague", "Uppsala", "London", "Copenhagen"]
            : ["Geneva", "Zurich", "Basel", "Bern", "Strasbourg", "Amsterdam", "Utrecht", "Edinburgh", "Lyon"]
        let preferredFamilies: Set<String> = religion == .protestant
            ? ["germanic", "nordic", "west_slavic", "british", "baltic"]
            : ["germanic", "french", "dutch", "british", "celtic"]

        var scored: [(prov: ProvinceID, weight: Int)] = []
        for p in 0..<world.provinces.count {
            let pid = ProvinceID(p)
            guard !existing.contains(pid),
                  world.provinces.religion[p] == .catholic,
                  let owner = world.provinces.owner[p],
                  world.countries.tag[owner.index] != "PAP",
                  world.provinces.development[p] >= 3 else {
                continue
            }
            let cultIdx = world.provinces.majorityCulture[p].index
            let fam = cultIdx < world.cultures.count ? world.cultures.family[cultIdx] : ""
            guard preferredFamilies.contains(fam) || preferredNames.contains(world.provinces.name[p]) else {
                continue
            }
            var w = world.provinces.development[p]
            if let idx = preferredNames.firstIndex(of: world.provinces.name[p]) {
                w += max(10, 40 - idx * 4)
            }
            scored.append((pid, w))
        }
        guard !scored.isEmpty else { return nil }
        // Sort by weight descending, then index ascending for complete determinism, and lottery from top 10.
        scored.sort { $0.weight == $1.weight ? $0.prov.index < $1.prov.index : $0.weight > $1.weight }
        let pool = Array(scored.prefix(min(10, scored.count)))
        let totalW = pool.reduce(0) { $0 + $1.weight }
        guard totalW > 0 else { return pool[0].prov }
        var draw = Int.random(in: 0...(totalW - 1), using: &random)
        for item in pool {
            if draw < item.weight { return item.prov }
            draw -= item.weight
        }
        return pool[0].prov
    }

    // MARK: - Helpers

    /// Transfers `fraction` of pops matching `fromReligion` in `province` to `toReligion`.
    static func shiftReligion(
        in province: ProvinceID,
        from fromReligion: Religion,
        to toReligion: Religion,
        fraction: Double,
        world: inout World,
        pending: inout [PopTable.Row],
        anyZero: inout Bool
    ) {
        guard fromReligion != toReligion, fraction > 0 else { return }
        let range = world.pops.range(for: province)
        for i in range {
            guard world.pops.religion[i] == fromReligion, world.pops.size[i] > 1e-9 else { continue }
            var delta = world.pops.size[i] * min(1.0, fraction)
            if world.pops.size[i] - delta < 1.0 {
                delta = world.pops.size[i]
                anyZero = true
            }
            let culture = world.pops.culture[i]
            let cls = world.pops.socialClass[i]
            let sat = world.pops.satisfaction[i]

            var mergedIdx: Int?
            for j in range where world.pops.culture[j] == culture
                && world.pops.religion[j] == toReligion
                && world.pops.sect[j] == nil
                && world.pops.socialClass[j] == cls
                && world.pops.size[j] > 0 {
                mergedIdx = j
                break
            }

            world.pops.size[i] -= delta
            if let j = mergedIdx {
                let prev = world.pops.size[j]
                world.pops.satisfaction[j] = (world.pops.satisfaction[j] * prev + sat * delta) / (prev + delta)
                world.pops.size[j] = prev + delta
            } else {
                pending.append(PopTable.Row(
                    province: province,
                    culture: culture,
                    religion: toReligion,
                    sect: nil,
                    socialClass: cls,
                    size: delta,
                    satisfaction: sat
                ))
            }
        }
    }
}
