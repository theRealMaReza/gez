import Foundation

/// Evaluates per-country Historical AI goal lists and Free AI situational priorities (Phase 15).
public enum AIGoalSystem {

    public struct RulerTraitProfile: Sendable {
        public var warMultiplier: Double = 1.0
        public var ratioDelta: Double = 0.0
        public var economyWeight: Double = 1.0
        public var diplomacyWeight: Double = 1.0
    }

    /// True if `country` should use Free AI logic right now (either Free setting or Historical list exhausted/absent).
    public static func isFreeMode(for country: CountryID, in world: World) -> Bool {
        if world.ai.setting == .free { return true }
        guard country.index >= 0 && country.index < world.ai.usingFreeFallback.count else { return true }
        return world.ai.usingFreeFallback[country.index]
    }

    /// Currently active historical goal for `country`, if any.
    public static func activeGoal(for country: CountryID, in world: World) -> AIGoalDef? {
        guard world.ai.setting == .historical,
              country.index >= 0 && country.index < world.ai.currentGoalID.count,
              let gid = world.ai.currentGoalID[country.index] else {
            return nil
        }
        return world.aiRules.goal(id: gid)
    }

    /// Human-readable goal line for the Country View UI.
    public static func goalSummaryText(for country: CountryID, in world: World) -> String {
        let ci = country.index
        guard ci >= 0 && ci < world.countries.count else { return "None" }
        if world.humanCountries.contains(country) {
            return "Player-controlled"
        }
        if ci < world.ai.currentGoalLabel.count {
            let label = world.ai.currentGoalLabel[ci]
            if !label.isEmpty { return label }
        }
        return world.ai.setting == .free ? "Free AI: Evaluating situation" : "Consolidating"
    }

    /// Returns the ruler's personality bias used by Free AI and event weighting.
    public static func traitProfile(for country: CountryID, in world: World) -> RulerTraitProfile {
        var profile = RulerTraitProfile()
        let ci = country.index
        guard ci >= 0 && ci < world.countries.count,
              let rulerID = world.countries.ruler[ci],
              rulerID.index >= 0 && rulerID.index < world.people.characters.count else {
            return profile
        }
        let traitTable = world.people.traits
        for tid in world.people.characters.traits[rulerID.index] {
            guard tid.index >= 0 && tid.index < traitTable.count else { continue }
            switch traitTable.key[tid.index] {
            case "brave", "ambitious", "wrathful", "strategist", "zealous", "cruel":
                profile.warMultiplier += 0.16
                profile.ratioDelta -= 0.05
            case "content", "craven", "calm", "patient", "kind":
                profile.warMultiplier -= 0.16
                profile.ratioDelta += 0.07
                profile.diplomacyWeight += 0.15
            case "administrator", "diligent", "greedy", "scholar":
                profile.economyWeight += 0.25
            case "diplomat", "honest", "tolerant", "just":
                profile.diplomacyWeight += 0.25
            case "schemer", "deceitful", "arbitrary":
                profile.warMultiplier += 0.08
                profile.diplomacyWeight -= 0.10
            default:
                break
            }
        }
        profile.warMultiplier = max(0.45, min(1.65, profile.warMultiplier))
        profile.ratioDelta = max(-0.15, min(0.25, profile.ratioDelta))
        profile.economyWeight = max(0.5, min(1.8, profile.economyWeight))
        profile.diplomacyWeight = max(0.5, min(1.8, profile.diplomacyWeight))
        return profile
    }

    // MARK: - Active Goal Filters (Historical Mode)

    /// Active `keep_peace_with` targets for `country` on `date` (returns empty in Free mode).
    public static func activePeaceTargets(for country: CountryID, date: GameDate, in world: World) -> Set<CountryID> {
        guard world.ai.setting == .historical,
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count,
              !isFreeMode(for: country, in: world) else {
            return []
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        var out: Set<CountryID> = []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            guard g.type == .keepPeaceWith,
                  let tid = g.targetCountry,
                  !skipped.contains(g.id),
                  !completed.contains(g.id),
                  date >= g.earliestDate,
                  date <= g.giveUpDate else { continue }
            out.insert(tid)
        }
        return out
    }

    /// All currently active `conquer_province` goal targets in `[earliestDate, giveUpDate]` (top active goal prioritized first).
    public static func activeConquerProvinces(for country: CountryID, date: GameDate, in world: World) -> [ProvinceID] {
        guard !isFreeMode(for: country, in: world),
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count else {
            return []
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        var out: [ProvinceID] = []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            guard g.type == .conquerProvince,
                  let pid = g.targetProvince,
                  !skipped.contains(g.id),
                  !completed.contains(g.id),
                  date >= g.earliestDate,
                  date <= g.giveUpDate else { continue }
            out.append(pid)
        }
        return out
    }

    /// Currently active `defend_province` goal targets in `[earliestDate, giveUpDate]`.
    public static func activeDefendProvinces(for country: CountryID, date: GameDate, in world: World) -> [ProvinceID] {
        guard !isFreeMode(for: country, in: world),
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count else {
            return []
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        var out: [ProvinceID] = []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            guard g.type == .defendProvince,
                  let pid = g.targetProvince,
                  !skipped.contains(g.id),
                  !completed.contains(g.id),
                  date >= g.earliestDate,
                  date <= g.giveUpDate else { continue }
            out.append(pid)
        }
        return out
    }

    /// Currently active `ally_with` goal targets in `[earliestDate, giveUpDate]`.
    public static func activeAllyTargets(for country: CountryID, date: GameDate, in world: World) -> [CountryID] {
        guard !isFreeMode(for: country, in: world),
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count else {
            return []
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        var out: [CountryID] = []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            guard g.type == .allyWith,
                  let tid = g.targetCountry,
                  !skipped.contains(g.id),
                  !completed.contains(g.id),
                  date >= g.earliestDate,
                  date <= g.giveUpDate else { continue }
            out.append(tid)
        }
        return out
    }

    /// Currently active `vassalize` goal targets in `[earliestDate, giveUpDate]`.
    public static func activeVassalizeTargets(for country: CountryID, date: GameDate, in world: World) -> [CountryID] {
        guard !isFreeMode(for: country, in: world),
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count else {
            return []
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        var out: [CountryID] = []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            guard g.type == .vassalize,
                  let tid = g.targetCountry,
                  !skipped.contains(g.id),
                  !completed.contains(g.id),
                  date >= g.earliestDate,
                  date <= g.giveUpDate else { continue }
            out.append(tid)
        }
        return out
    }

    /// Active `build_up` focus if the top active goal (or any active goal) is a build-up goal.
    public static func activeBuildFocus(for country: CountryID, date: GameDate, in world: World) -> AIGoalBuildFocus? {
        guard !isFreeMode(for: country, in: world),
              country.index >= 0 && country.index < world.aiRules.goalsByCountry.count else {
            return nil
        }
        if let top = activeGoal(for: country, in: world), top.type == .buildUp {
            return top.buildFocus
        }
        let ci = country.index
        let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci] : []
        let completed = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci] : []
        for idx in world.aiRules.goalsByCountry[ci] {
            let g = world.aiRules.goals[idx]
            if g.type == .buildUp,
               !skipped.contains(g.id),
               !completed.contains(g.id),
               date >= g.earliestDate,
               date <= g.giveUpDate {
                return g.buildFocus
            }
        }
        return nil
    }

    // MARK: - Goal Evaluation & Advancement

    /// Recomputes goal progress, skips impossible goals, falls back to Free if exhausted,
    /// and updates `world.ai.currentGoalID` / `currentGoalLabel` for every country.
    public static func updateGoals(
        _ world: inout World,
        date: GameDate,
        ownedProvinces passedOwned: [[ProvinceID]]? = nil,
        landNeighbors passedNeighbors: [Set<CountryID>]? = nil,
        soldiersByCountry passedSoldiers: [Int]? = nil
    ) {
        let n = world.countries.count
        guard n > 0 else { return }
        world.ai.resize(countries: n)

        let ownedProvinces: [[ProvinceID]]
        if let passedOwned {
            ownedProvinces = passedOwned
        } else {
            var tmp = Array(repeating: [ProvinceID](), count: n)
            for p in 0..<world.provinces.count {
                if let owner = world.provinces.owner[p], owner.index < n {
                    tmp[owner.index].append(ProvinceID(p))
                }
            }
            ownedProvinces = tmp
        }

        let landNeighbors: [Set<CountryID>]
        if let passedNeighbors {
            landNeighbors = passedNeighbors
        } else {
            var tmp = Array(repeating: Set<CountryID>(), count: n)
            for p in 0..<world.provinces.count {
                guard let ownerA = world.provinces.owner[p], ownerA.index < n else { continue }
                for nb in world.provinces.neighbors[p] {
                    if let ownerB = world.provinces.owner[nb.index], ownerB != ownerA, ownerB.index < n {
                        tmp[ownerA.index].insert(ownerB)
                    }
                }
            }
            landNeighbors = tmp
        }

        let soldiersByCountry: [Int]
        if let passedSoldiers {
            soldiersByCountry = passedSoldiers
        } else {
            var tmp = Array(repeating: 0, count: n)
            for idx in 0..<world.military.armies.count {
                guard world.military.armies.alive[idx], !world.military.armies.isRebel[idx] else { continue }
                let owner = world.military.armies.owner[idx]
                if owner.index < n {
                    tmp[owner.index] += world.military.armies.totalMen(of: ArmyID(Int32(idx)))
                }
            }
            soldiersByCountry = tmp
        }

        // Precompute country coast & loan presence once for fast O(1) checks
        var hasCoast = Array(repeating: false, count: n)
        for p in 0..<world.provinces.count {
            if let owner = world.provinces.owner[p], owner.index < n, world.hasSeaAccess(ProvinceID(p)) {
                hasCoast[owner.index] = true
            }
        }
        var hasLoan = Array(repeating: false, count: n)
        for loan in world.finance.loans where loan.country.index < n {
            hasLoan[loan.country.index] = true
        }
        let turID = world.countries.id(forTag: "TUR")

        for c in world.countries.ids {
            let ci = c.index
            if world.humanCountries.contains(c) {
                world.ai.currentGoalID[ci] = nil
                world.ai.usingFreeFallback[ci] = false
                world.ai.currentGoalLabel[ci] = "Player-controlled"
                continue
            }
            if ownedProvinces[ci].isEmpty {
                world.ai.currentGoalID[ci] = nil
                world.ai.usingFreeFallback[ci] = false
                world.ai.currentGoalLabel[ci] = "No territory"
                continue
            }

            if world.ai.setting == .free {
                world.ai.currentGoalID[ci] = nil
                world.ai.usingFreeFallback[ci] = true
                world.ai.currentGoalLabel[ci] = computeFreeGoalLabel(
                    world,
                    country: c,
                    ownedProvinces: ownedProvinces,
                    landNeighbors: landNeighbors[ci],
                    soldiersByCountry: soldiersByCountry,
                    hasLoan: hasLoan[ci],
                    listCompleted: false
                )
                continue
            }

            // Historical mode: walk ordered goals
            let goalIndices = ci < world.aiRules.goalsByCountry.count ? world.aiRules.goalsByCountry[ci] : []
            var activeGoal: AIGoalDef?
            var fallbackPeaceGoal: AIGoalDef?
            var hasPendingFutureGoal = false

            // Precompute active peace targets among goals that are not skipped/completed yet
            for gIdx in goalIndices {
                let g = world.aiRules.goals[gIdx]
                if world.ai.completedGoalIDs[ci].contains(g.id) || world.ai.skippedGoalIDs[ci].contains(g.id) {
                    continue
                }

                // 1. Check completion or loss/impossibility of target
                switch g.type {
                case .conquerProvince:
                    guard let pid = g.targetProvince, pid.index < world.provinces.count else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.provinces.owner[pid.index] == c {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }

                case .defendProvince:
                    guard let pid = g.targetProvince, pid.index < world.provinces.count else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.provinces.owner[pid.index] != c {
                        // Lost the province -> defending goal failed/impossible
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if g.id == "hun_belgrade_1456",
                       world.events.globalFlags.contains("belgrade_1456_resolved"),
                       !(turID.map { world.diplomacy.isAtWar(c, $0) } ?? false) {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if date > g.giveUpDate {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }

                case .allyWith:
                    guard let tid = g.targetCountry, tid.index < n else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.diplomacy.areAllies(c, tid) {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if ownedProvinces[tid.index].isEmpty {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }

                case .vassalize:
                    guard let tid = g.targetCountry, tid.index < n else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.countries.overlord[tid.index] == c {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if ownedProvinces[tid.index].isEmpty {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }

                case .keepPeaceWith:
                    guard let tid = g.targetCountry, tid.index < n else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if ownedProvinces[tid.index].isEmpty {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if date > g.giveUpDate {
                        world.ai.completedGoalIDs[ci].insert(g.id)
                        continue
                    }

                case .buildUp:
                    let daysElapsed = date.ordinal - max(Scenario1453.startDate.ordinal, g.earliestDate.ordinal)
                    if g.buildFocus == .economy {
                        let income = world.countries.lastMonthlyIncome[ci]
                        let expenses = world.countries.lastMonthlyExpenses[ci]
                        let targetCash = max(120.0, income * 9.0)
                        if daysElapsed >= 180 && !hasLoan[ci] && income >= expenses && world.countries.treasury[ci] >= targetCash {
                            world.ai.completedGoalIDs[ci].insert(g.id)
                            continue
                        }
                    } else {
                        let targetMen = max(2000, Int((world.military.maxManpower[ci] * 0.50).rounded()))
                        if daysElapsed >= 180 && soldiersByCountry[ci] >= targetMen {
                            world.ai.completedGoalIDs[ci].insert(g.id)
                            continue
                        }
                    }
                }

                // 2. Date passed -> skip
                if date > g.giveUpDate {
                    world.ai.skippedGoalIDs[ci].insert(g.id)
                    continue
                }

                // 3. Too early -> remains pending
                if date < g.earliestDate {
                    hasPendingFutureGoal = true
                    continue
                }

                // 4. Feasibility & impossibility checks (too weak, unreachable, hostile/blocked)
                switch g.type {
                case .conquerProvince:
                    guard let pid = g.targetProvince, let targetOwner = world.provinces.owner[pid.index] else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    // Cannot attack our overlord or an active ally/peace-pact target right now
                    if world.countries.overlord[ci] == targetOwner {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.diplomacy.areAllies(c, targetOwner) {
                        continue
                    }
                    // If target is our personal union, skip; if vassal/tributary, feasible (we can break vassalage)
                    if world.countries.overlord[targetOwner.index] == c && world.countries.subjectType[targetOwner.index] == .personalUnion {
                        continue
                    }
                    // Reachability: must either border targetOwner or both have sea access
                    if !landNeighbors[ci].contains(targetOwner) && !(hasCoast[ci] && hasCoast[targetOwner.index]) {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    // Strength check: if hopelessly weaker or bankrupt, skip
                    let ourPotential = max(soldiersByCountry[ci], Int((world.military.maxManpower[ci] * 0.75).rounded()))
                    let enemyStrength = alliancePotentialStrength(
                        of: targetOwner,
                        excluding: c,
                        soldiersByCountry: soldiersByCountry,
                        world: world
                    )
                    if world.countries.bankruptMonthsLeft[ci] > 0
                        || Double(ourPotential) < Double(max(1000, enemyStrength)) * 0.45 {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if activeGoal == nil {
                        activeGoal = g
                    }

                case .vassalize:
                    guard let tid = g.targetCountry else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if ownedProvinces[tid.index].count > 10 {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if !landNeighbors[ci].contains(tid) && !(hasCoast[ci] && hasCoast[tid.index]) {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    let ourPotential = max(soldiersByCountry[ci], Int((world.military.maxManpower[ci] * 0.75).rounded()))
                    let enemyStrength = alliancePotentialStrength(
                        of: tid,
                        excluding: c,
                        soldiersByCountry: soldiersByCountry,
                        world: world
                    )
                    if world.countries.bankruptMonthsLeft[ci] > 0
                        || Double(ourPotential) < Double(max(1000, enemyStrength)) * 0.45 {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if activeGoal == nil {
                        activeGoal = g
                    }

                case .allyWith:
                    guard let tid = g.targetCountry else {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if world.diplomacy.isAtWar(c, tid) {
                        continue
                    }
                    if world.diplomacy.opinion(of: c, by: tid) < -75 {
                        world.ai.skippedGoalIDs[ci].insert(g.id)
                        continue
                    }
                    if activeGoal == nil {
                        activeGoal = g
                    }

                case .keepPeaceWith:
                    if let tid = g.targetCountry, !world.diplomacy.isAtWar(c, tid) {
                        if fallbackPeaceGoal == nil {
                            fallbackPeaceGoal = g
                        }
                    }

                case .defendProvince, .buildUp:
                    if activeGoal == nil {
                        activeGoal = g
                    }
                }
            }

            if let chosen = activeGoal ?? fallbackPeaceGoal {
                world.ai.currentGoalID[ci] = chosen.id
                world.ai.usingFreeFallback[ci] = false
                world.ai.currentGoalLabel[ci] = formatGoalLabel(chosen, world: world)
            } else {
                world.ai.currentGoalID[ci] = nil
                world.ai.usingFreeFallback[ci] = true
                if hasPendingFutureGoal {
                    world.ai.currentGoalLabel[ci] = "Free AI (awaiting next historical window)"
                } else {
                    world.ai.currentGoalLabel[ci] = computeFreeGoalLabel(
                        world,
                        country: c,
                        ownedProvinces: ownedProvinces,
                        landNeighbors: landNeighbors[ci],
                        soldiersByCountry: soldiersByCountry,
                        hasLoan: hasLoan[ci],
                        listCompleted: !goalIndices.isEmpty
                    )
                }
            }
        }
    }

    // MARK: - Formatting & Situational Evaluation

    public static func formatGoalLabel(_ goal: AIGoalDef, world: World) -> String {
        switch goal.type {
        case .conquerProvince:
            let pName = goal.targetProvince.map { world.provinces.name[$0.index] } ?? goal.target
            return "Conquer \(pName)"
        case .defendProvince:
            let pName = goal.targetProvince.map { world.provinces.name[$0.index] } ?? goal.target
            return "Defend \(pName)"
        case .allyWith:
            let cName = goal.targetCountry.map { world.countries.name[$0.index] } ?? goal.target
            return "Ally with \(cName)"
        case .vassalize:
            let cName = goal.targetCountry.map { world.countries.name[$0.index] } ?? goal.target
            return "Vassalize \(cName)"
        case .keepPeaceWith:
            let cName = goal.targetCountry.map { world.countries.name[$0.index] } ?? goal.target
            return "Keep peace with \(cName)"
        case .buildUp:
            return goal.buildFocus == .army ? "Build up army" : "Build up economy"
        }
    }

    private static func alliancePotentialStrength(
        of target: CountryID,
        excluding attacker: CountryID,
        soldiersByCountry: [Int],
        world: World
    ) -> Int {
        var total = target.index < soldiersByCountry.count ? soldiersByCountry[target.index] : 0
        var counted = Set<CountryID>([attacker, target])
        for t in world.diplomacy.treaties {
            let helper: CountryID?
            switch t.type {
            case .alliance: helper = t.first == target ? t.second : (t.second == target ? t.first : nil)
            case .guarantee: helper = t.second == target ? t.first : nil
            default: helper = nil
            }
            if let h = helper, h.index < soldiersByCountry.count, counted.insert(h).inserted {
                total += soldiersByCountry[h.index]
            }
        }
        if let ov = world.countries.overlord[target.index], ov.index < soldiersByCountry.count, counted.insert(ov).inserted {
            total += soldiersByCountry[ov.index]
        }
        return total
    }

    private static func computeFreeGoalLabel(
        _ world: World,
        country c: CountryID,
        ownedProvinces: [[ProvinceID]],
        landNeighbors: Set<CountryID>,
        soldiersByCountry: [Int],
        hasLoan: Bool,
        listCompleted: Bool
    ) -> String {
        let prefix = listCompleted ? "Free AI (list complete)" : "Free AI"
        let ci = c.index
        if !world.diplomacy.activeWars(for: c).isEmpty {
            return "\(prefix): Wage active war"
        }
        let ourSoldiers = soldiersByCountry[ci]
        let traits = traitProfile(for: c, in: world)

        // Check for strongest hostile neighbor (threat) vs weak target neighbor
        var strongestThreat: (CountryID, Int)?
        var weakestNeighbor: (CountryID, Int)?
        for nb in landNeighbors.sorted(by: { $0.index < $1.index }) {
            guard !ownedProvinces[nb.index].isEmpty else { continue }
            let nbMen = soldiersByCountry[nb.index]
            let op = world.diplomacy.opinion(of: c, by: nb)
            if !world.diplomacy.areAllies(c, nb) && op < -10 && nbMen > Int(Double(max(1000, ourSoldiers)) * 1.4) {
                if strongestThreat == nil || nbMen > strongestThreat!.1 {
                    strongestThreat = (nb, nbMen)
                }
            }
            if world.countries.overlord[ci] == nil,
               !world.diplomacy.areAllies(c, nb),
               !world.diplomacy.hasTruce(c, nb),
               world.countries.overlord[nb.index] != c,
               Double(ourSoldiers) >= max(1000.0, Double(nbMen) * 1.35) {
                if weakestNeighbor == nil || nbMen < weakestNeighbor!.1 {
                    weakestNeighbor = (nb, nbMen)
                }
            }
        }

        if let threat = strongestThreat, traits.diplomacyWeight >= 1.0 {
            return "\(prefix): Counter threat from \(world.countries.name[threat.0.index])"
        }
        if hasLoan || world.countries.treasury[ci] < max(60.0, world.countries.lastMonthlyIncome[ci] * 6.0) {
            return "\(prefix): Build up economy"
        }
        if let weak = weakestNeighbor, traits.warMultiplier >= 0.9 {
            return "\(prefix): Expand vs \(world.countries.name[weak.0.index])"
        }
        if ourSoldiers < Int((world.military.maxManpower[ci] * 0.45).rounded()) {
            return "\(prefix): Build up army"
        }
        if let threat = strongestThreat {
            return "\(prefix): Seek allies vs \(world.countries.name[threat.0.index])"
        }
        if traits.economyWeight > 1.15 {
            return "\(prefix): Develop trade & economy"
        }
        return "\(prefix): Seek alliances & opportunity"
    }
}
