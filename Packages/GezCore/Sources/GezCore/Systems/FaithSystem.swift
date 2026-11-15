import Foundation

public enum FaithModel {
    /// Passive base fraction of non-state pops converted per month before multipliers.
    public static let basePassiveConversionRate = 0.0005
    /// Extra base fraction converted per month when a missionary is working in the province.
    public static let missionaryConversionBonus = 0.012
    /// Monthly ducat upkeep per active missionary.
    public static let missionaryMonthlyCost = 0.50
    /// Monthly conversion speed boost per temple level (+35% per level).
    public static let templeConversionBonusPerLevel = 0.35
    /// Maximum fraction of a wrong-faith pop group converted in a single month.
    public static let maxMonthlyConversionRate = 0.25

    /// Prestige gained per month per held holy site of the state religion (+0.6 / year).
    public static let holySiteMonthlyPrestige = 0.05
    /// Monthly natural prestige decay rate toward zero.
    public static let prestigeMonthlyDecay = 0.005
    /// Clergy estate target loyalty bonus per held holy site (capped at 4 sites = +12).
    public static let holySiteClergyLoyalty = 3.0
    public static let maxHolySiteClergyLoyalty = 12.0
    /// Stability cost reduction per held holy site (-5% per site, capped at -25%).
    public static let holySiteStabilityDiscount = 0.05
    public static let maxHolySiteStabilityDiscount = 0.25

    /// Monthly convergence speed of `religiousUnrest` toward its target (0...100).
    public static let unrestConvergence = 0.25
    /// Default starting Sufaviyya monthly progression constants used in Part B.
    public static let minReformationYear = 1500
}

public enum MissionaryRefusal: Equatable, Sendable {
    case notOwned
    case alreadyActive
    case noFreeMissionary
    case blockedByPrivilege(String)
    case nothingToConvert

    public var reason: String {
        switch self {
        case .notOwned: return "Province is not owned by this country."
        case .alreadyActive: return "A missionary is already working here."
        case .noFreeMissionary: return "No free missionary slot available."
        case .blockedByPrivilege(let why): return "Conversion blocked: \(why)."
        case .nothingToConvert: return "Everyone here already follows the state religion."
        }
    }
}

/// Manages holy sites, pop conversion, missionaries, and religious unrest (Phase 11).
public enum FaithSystem {

    // MARK: - Queries & Per-Province / Country Rules

    /// Recomputes `world.faith.holySiteCountHeld` in one O(holySites) pass.
    public static func refreshHolySiteCounts(_ world: inout World) {
        let N = world.countries.count
        var counts = Array(repeating: 0, count: N)
        for site in world.faith.holySites {
            let p = site.province.index
            guard p < world.provinces.count,
                  let owner = world.provinces.owner[p],
                  world.provinces.occupiedBy[p] == nil else { continue }
            if site.isSacred(to: world.countries.religion[owner.index]) {
                counts[owner.index] += 1
            }
        }
        world.faith.holySiteCountHeld = counts
    }

    /// Holy sites currently held by `country` (unoccupied) that are sacred to its state religion.
    public static func holySitesHeld(in world: World, by country: CountryID) -> [HolySite] {
        let rel = world.countries.religion[country.index]
        return world.faith.holySites.filter { site in
            let p = site.province.index
            return p < world.provinces.count
                && world.provinces.owner[p] == country
                && world.provinces.occupiedBy[p] == nil
                && site.isSacred(to: rel)
        }
    }

    /// Holy sites located inside `province` (any religion).
    public static func holySites(in province: ProvinceID, world: World) -> [HolySite] {
        guard let indices = world.faith.holySitesByProvince[province.index] else { return [] }
        return indices.map { world.faith.holySites[$0] }
    }

    /// Maximum simultaneous missionaries available to `country`.
    public static func maxMissionaries(_ world: World, _ country: CountryID) -> Int {
        var totalDev = 0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            totalDev += world.provinces.development[p]
        }
        var slots = 1
        if totalDev >= 180 { slots += 1 }
        if faithLawKey(world, country) == "orthodoxy" { slots += 1 }
        return slots
    }

    public static func activeMissionaries(_ world: World, for country: CountryID) -> [MissionaryAssignment] {
        world.faith.missionaries.filter { $0.country == country }
    }

    public static func hasMissionary(_ world: World, in province: ProvinceID) -> Bool {
        world.faith.missionaries.contains { $0.province == province }
    }

    /// Key of the `faith` law currently active in `country` ("orthodoxy", "tolerance", "open").
    public static func faithLawKey(_ world: World, _ country: CountryID) -> String {
        let g = world.government
        guard country.index < g.count,
              let faithArea = g.rules.lawAreas.firstIndex(where: { $0.key == "faith" }),
              faithArea < g.laws[country.index].count else {
            return "tolerance"
        }
        let optIdx = g.laws[country.index][faithArea]
        let opts = g.rules.lawAreas[faithArea].options
        return optIdx < opts.count ? opts[optIdx].key : "tolerance"
    }

    /// Clergy estate loyalty (0...100), or 50 if the country has no Clergy estate.
    public static func clergyLoyalty(_ world: World, _ country: CountryID) -> Double {
        let g = world.government
        guard country.index < g.count else { return 50 }
        for e in g.estates[country.index] {
            if case .socialClass(.clergy) = g.rules.estates[e.index].source {
                return g.loyalty[country.index][e.index]
            }
        }
        return 50
    }

    /// Privilege slowdown/block summary for converting `popReligion` inside `owner`.
    static func dhimmiStatus(
        owner: CountryID,
        ownerReligion: Religion,
        popReligion: Religion,
        world: World
    ) -> (blocked: Bool, passiveFactor: Double, missionaryFactor: Double, unrestRelief: Double) {
        guard ownerReligion.family == .muslim, popReligion.family != .muslim else {
            return (false, 1.0, 1.0, 0.0)
        }
        let g = world.government
        guard owner.index < g.count else { return (false, 1.0, 1.0, 0.0) }
        var passive = 1.0
        var missionary = 1.0
        var relief = 0.0
        for privIdx in g.privileges[owner.index] {
            let def = g.rules.privileges[privIdx]
            guard g.rules.estates[def.estate.index].source == .dhimmi else { continue }
            switch def.key {
            case "millet":
                return (true, 0.0, 0.0, 4.0)
            case "own_courts":
                passive *= 0.5
                missionary *= 0.7
                relief += 3.0
            case "lower_jizya":
                passive *= 0.55
                missionary *= 0.75
                relief += 3.0
            default:
                break
            }
        }
        return (false, passive, missionary, relief)
    }

    /// True if Catholic <-> Hussite conversion is forbidden by the Basel Compacts.
    static func isBlockedByHussiteCompacts(ownerReligion: Religion, popReligion: Religion, world: World) -> Bool {
        guard world.faith.hussiteCompactsActive else { return false }
        return (ownerReligion == .catholic && popReligion == .hussite)
            || (ownerReligion == .hussite && popReligion == .catholic)
    }

    /// Monthly conversion fraction for one non-state religion in a province (returns 0 if blocked).
    public static func monthlyConversionRate(
        world: World,
        province: ProvinceID,
        from popReligion: Religion,
        hasMissionary: Bool? = nil,
        templeIdx: Int? = nil
    ) -> Double {
        let p = province.index
        guard p < world.provinces.count,
              let owner = world.provinces.owner[p],
              world.provinces.occupiedBy[p] == nil else {
            return 0
        }
        let ownerRel = world.countries.religion[owner.index]
        guard popReligion != ownerRel else { return 0 }

        if isBlockedByHussiteCompacts(ownerReligion: ownerRel, popReligion: popReligion, world: world) {
            return 0
        }
        let dhimmi = dhimmiStatus(owner: owner, ownerReligion: ownerRel, popReligion: popReligion, world: world)
        if dhimmi.blocked { return 0 }

        let activeMiss = hasMissionary ?? self.hasMissionary(world, in: province)
        let law = faithLawKey(world, owner)
        let passiveLawFactor: Double
        let missLawFactor: Double
        switch law {
        case "orthodoxy":
            passiveLawFactor = 1.6
            missLawFactor = 1.25
        case "open":
            passiveLawFactor = 0.2
            missLawFactor = 0.5
        default: // tolerance
            passiveLawFactor = 0.6
            missLawFactor = 0.9
        }

        let loyalty = clergyLoyalty(world, owner)
        let clergyFactor = 0.5 + max(0, min(100, loyalty)) / 100.0

        let tIdx = templeIdx ?? world.economy.buildingTypes.firstIndex(where: { $0.key == "temple" })
        let templeLvl = tIdx.map { world.economy.buildings.level(province, BuildingTypeID($0)) } ?? 0
        let templeFactor = 1.0 + FaithModel.templeConversionBonusPerLevel * Double(templeLvl)

        let familyFactor = (ownerRel.family == popReligion.family) ? 1.25 : 0.85

        let passiveComponent = FaithModel.basePassiveConversionRate * passiveLawFactor * dhimmi.passiveFactor
        let missionaryComponent = activeMiss
            ? FaithModel.missionaryConversionBonus * missLawFactor * dhimmi.missionaryFactor
            : 0.0

        let total = (passiveComponent + missionaryComponent) * clergyFactor * templeFactor * familyFactor
        return min(FaithModel.maxMonthlyConversionRate, max(0, total))
    }

    /// Explains why a missionary cannot be sent, or nil if ready.
    public static func missionaryRefusal(_ world: World, by country: CountryID, in province: ProvinceID) -> MissionaryRefusal? {
        let p = province.index
        guard p < world.provinces.count, world.provinces.owner[p] == country else { return .notOwned }
        if hasMissionary(world, in: province) { return .alreadyActive }
        if activeMissionaries(world, for: country).count >= maxMissionaries(world, country) {
            return .noFreeMissionary
        }
        let stateRel = world.countries.religion[country.index]
        var hasWrongFaith = false
        var hasUnblockedWrongFaith = false
        var blockReason: String?
        for i in world.pops.range(for: province) where world.pops.size[i] > 1e-6 {
            let popRel = world.pops.religion[i]
            guard popRel != stateRel else { continue }
            hasWrongFaith = true
            if isBlockedByHussiteCompacts(ownerReligion: stateRel, popReligion: popRel, world: world) {
                blockReason = blockReason ?? "Hussite Compacts"
                continue
            }
            if dhimmiStatus(owner: country, ownerReligion: stateRel, popReligion: popRel, world: world).blocked {
                blockReason = blockReason ?? "Dhimmi Millet privilege"
                continue
            }
            hasUnblockedWrongFaith = true
        }
        if !hasWrongFaith { return .nothingToConvert }
        if !hasUnblockedWrongFaith { return .blockedByPrivilege(blockReason ?? "Privilege or treaty") }
        return nil
    }

    /// Dispatches a missionary to an owned province if valid.
    @discardableResult
    public static func sendMissionary(_ world: inout World, by country: CountryID, to province: ProvinceID, date: GameDate) -> MissionaryRefusal? {
        if let err = missionaryRefusal(world, by: country, in: province) {
            return err
        }
        world.faith.missionaries.append(MissionaryAssignment(country: country, province: province))
        world.people.record(date, country, "Missionary dispatched to \(world.provinces.name[province.index]).")
        return nil
    }

    @discardableResult
    public static func recallMissionary(_ world: inout World, by country: CountryID, from province: ProvinceID) -> Bool {
        let before = world.faith.missionaries.count
        world.faith.missionaries.removeAll { $0.country == country && $0.province == province }
        return world.faith.missionaries.count < before
    }

    // MARK: - Monthly Update

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        let C = world.countries.count
        guard P > 0, C > 0 else { return }

        // 1. Refresh holy site counts and update prestige.
        refreshHolySiteCounts(&world)
        for c in 0..<C {
            let sites = world.faith.holySiteCountHeld[c]
            var p = world.countries.prestige[c]
            p += Double(sites) * FaithModel.holySiteMonthlyPrestige
            p -= p * FaithModel.prestigeMonthlyDecay
            world.countries.prestige[c] = max(-100, min(100, p))
        }

        // 2. Build once-per-month lookup tables for O(1) checks in the province/pop loop.
        let templeIdx = world.economy.buildingTypes.firstIndex(where: { $0.key == "temple" })
        let T = world.economy.buildings.typeCount

        var countryFaithLaw = Array(repeating: 1, count: C) // 0: orthodoxy, 1: tolerance, 2: open
        let faithAreaIdx = world.government.rules.lawAreas.firstIndex(where: { $0.key == "faith" })
        var countryClergyLoyalty = Array(repeating: 50.0, count: C)
        var countryMillet = Array(repeating: false, count: C)
        var countryDhimmiPassive = Array(repeating: 1.0, count: C)
        var countryDhimmiMiss = Array(repeating: 1.0, count: C)
        var countryDhimmiRelief = Array(repeating: 0.0, count: C)

        let g = world.government
        let rules = g.rules
        for c in 0..<min(C, g.count) {
            if let area = faithAreaIdx, area < g.laws[c].count {
                let optIdx = g.laws[c][area]
                let opts = rules.lawAreas[area].options
                if optIdx < opts.count {
                    switch opts[optIdx].key {
                    case "orthodoxy": countryFaithLaw[c] = 0
                    case "open": countryFaithLaw[c] = 2
                    default: countryFaithLaw[c] = 1
                    }
                }
            }
            for e in g.estates[c] {
                if case .socialClass(.clergy) = rules.estates[e.index].source {
                    countryClergyLoyalty[c] = g.loyalty[c][e.index]
                    break
                }
            }
            for privIdx in g.privileges[c] {
                let def = rules.privileges[privIdx]
                guard rules.estates[def.estate.index].source == .dhimmi else { continue }
                switch def.key {
                case "millet":
                    countryMillet[c] = true
                    countryDhimmiPassive[c] = 0
                    countryDhimmiMiss[c] = 0
                    countryDhimmiRelief[c] = 4.0
                case "own_courts":
                    countryDhimmiPassive[c] *= 0.5
                    countryDhimmiMiss[c] *= 0.7
                    countryDhimmiRelief[c] += 3.0
                case "lower_jizya":
                    countryDhimmiPassive[c] *= 0.55
                    countryDhimmiMiss[c] *= 0.75
                    countryDhimmiRelief[c] += 3.0
                default:
                    break
                }
            }
        }

        // Prune invalid missionaries and pay upkeep for active ones.
        var missionaryInProvince = Array(repeating: false, count: P)
        var keptMissionaries: [MissionaryAssignment] = []
        keptMissionaries.reserveCapacity(world.faith.missionaries.count)
        for m in world.faith.missionaries {
            let p = m.province.index
            let c = m.country.index
            guard p < P, c < C,
                  world.provinces.owner[p] == m.country,
                  world.provinces.occupiedBy[p] == nil else {
                continue
            }
            let stateRel = world.countries.religion[c]
            var hasTarget = false
            for i in world.pops.range(for: m.province) {
                if world.pops.size[i] > 1e-6 && world.pops.religion[i] != stateRel {
                    hasTarget = true
                    break
                }
            }
            guard hasTarget else { continue }
            if !missionaryInProvince[p] {
                missionaryInProvince[p] = true
                keptMissionaries.append(m)
                world.countries.treasury[c] -= FaithModel.missionaryMonthlyCost
                world.countries.lastMonthlyExpenses[c] += FaithModel.missionaryMonthlyCost
            }
        }
        world.faith.missionaries = keptMissionaries

        // 3. Province-by-province conversion and unrest.
        var pendingAdds: [PopTable.Row] = []
        var anyZeroRows = false
        let compactsActive = world.faith.hussiteCompactsActive

        for p in 0..<P {
            let pid = ProvinceID(p)
            guard let owner = world.provinces.owner[p],
                  world.provinces.occupiedBy[p] == nil else {
                world.provinces.religiousUnrest[p] *= 0.85
                world.provinces.conversionProgress[p] = 0
                continue
            }

            let o = owner.index
            let stateRel = world.countries.religion[o]
            let lawCode = countryFaithLaw[o]
            let passiveLawFactor: Double = lawCode == 0 ? 1.6 : (lawCode == 2 ? 0.2 : 0.6)
            let missLawFactor: Double = lawCode == 0 ? 1.25 : (lawCode == 2 ? 0.5 : 0.9)
            let clergyFactor = 0.5 + max(0, min(100, countryClergyLoyalty[o])) / 100.0
            let templeLvl = templeIdx.map { world.economy.buildings.level[p * T + $0] } ?? 0
            let templeFactor = 1.0 + FaithModel.templeConversionBonusPerLevel * Double(templeLvl)
            let hasMiss = missionaryInProvince[p]

            let range = world.pops.range(for: pid)
            // Compute monthly conversions on non-state rows.
            for i in range {
                let sz = world.pops.size[i]
                guard sz > 1e-9 else { continue }
                let popRel = world.pops.religion[i]
                guard popRel != stateRel else { continue }

                if compactsActive &&
                    ((stateRel == .catholic && popRel == .hussite) || (stateRel == .hussite && popRel == .catholic)) {
                    continue
                }
                let isDhimmiAffected = stateRel.family == .muslim && popRel.family != .muslim
                if isDhimmiAffected && countryMillet[o] { continue }

                let pDhimmi = isDhimmiAffected ? countryDhimmiPassive[o] : 1.0
                let mDhimmi = isDhimmiAffected ? countryDhimmiMiss[o] : 1.0
                let famFactor = (stateRel.family == popRel.family) ? 1.25 : 0.85

                let rawRate = (FaithModel.basePassiveConversionRate * passiveLawFactor * pDhimmi
                    + (hasMiss ? FaithModel.missionaryConversionBonus * missLawFactor * mDhimmi : 0.0))
                    * clergyFactor * templeFactor * famFactor
                let rate = min(FaithModel.maxMonthlyConversionRate, max(0, rawRate))
                guard rate > 0 else { continue }

                var delta = sz * rate
                if sz - delta < 1.0 {
                    delta = sz
                    anyZeroRows = true
                }

                let culture = world.pops.culture[i]
                let cls = world.pops.socialClass[i]
                let sat = world.pops.satisfaction[i]

                // Try merging into an already-present target row in this province range.
                var mergedIdx: Int?
                for j in range where world.pops.culture[j] == culture
                    && world.pops.religion[j] == stateRel
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
                    pendingAdds.append(PopTable.Row(
                        province: pid,
                        culture: culture,
                        religion: stateRel,
                        sect: nil,
                        socialClass: cls,
                        size: delta,
                        satisfaction: sat
                    ))
                }
            }

            // Recompute conversion progress & religious unrest inputs from updated pops in this province.
            var totalPop = 0.0
            var statePop = 0.0
            var wrongPop = 0.0
            for i in range {
                let s = world.pops.size[i]
                guard s > 0 else { continue }
                totalPop += s
                if world.pops.religion[i] == stateRel {
                    statePop += s
                } else {
                    wrongPop += s
                }
            }
            for row in pendingAdds where row.province == pid {
                totalPop += row.size
                if row.religion == stateRel { statePop += row.size } else { wrongPop += row.size }
            }
            world.provinces.conversionProgress[p] = totalPop > 0 ? min(1, statePop / totalPop) : 1.0

            // Majority religion check & religious unrest target.
            let wrongShare = totalPop > 0 ? wrongPop / totalPop : 0
            if wrongShare > 0.001 && world.provinces.religion[p] != stateRel {
                let majRel = world.provinces.religion[p]
                let isDiffFamily = majRel.family != stateRel.family
                var target = wrongShare * (isDiffFamily ? 18.0 : 12.0)
                if lawCode == 0 {
                    target += 6.0 * wrongShare
                } else if lawCode == 2 {
                    target -= 6.0 * wrongShare
                } else {
                    target -= 2.0 * wrongShare
                }
                if stateRel.family == .muslim && majRel.family != .muslim {
                    target -= countryDhimmiRelief[o] * wrongShare
                }
                if hasMiss { target += 3.0 }
                if compactsActive && ((stateRel == .catholic && majRel == .hussite) || (stateRel == .hussite && majRel == .catholic)) {
                    target *= 0.4
                }
                target = max(0, min(100, target))
                world.provinces.religiousUnrest[p] += FaithModel.unrestConvergence * (target - world.provinces.religiousUnrest[p])
            } else {
                // Majority follows state religion: unrest fades slowly.
                let minorTarget = wrongShare * (lawCode == 0 ? 4.0 : 1.0)
                world.provinces.religiousUnrest[p] += FaithModel.unrestConvergence * (minorTarget - world.provinces.religiousUnrest[p])
                if world.provinces.religiousUnrest[p] < 0.01 { world.provinces.religiousUnrest[p] = 0 }
            }
        }

        if !pendingAdds.isEmpty || anyZeroRows {
            world.pops.rebuild(provinceCount: P, extraRows: pendingAdds)
        }
        world.refreshProvinceSummaries()
    }
}
