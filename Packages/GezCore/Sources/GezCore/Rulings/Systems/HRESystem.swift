import Foundation

/// Phase 20.8: Holy Roman Empire ruling system.
///
/// Implements Imperial elections by the 7 Prince-Electors (`RulingEngine.elect`),
/// monthly Imperial Authority dynamics (internal peace, member count, free cities,
/// foreign-held Imperial provinces, religious disunity), Imperial favour drift,
/// electorate replenishment, and authority penalties when members are annexed.
public enum HRESystem: RulingSystem {
    public static let key = "hre"

    // MARK: - Hooks

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard let def = world.rulingRules.system(key),
              let state = RulingEngine.state(world, key),
              state.active else { return }

        let n = world.countries.count
        let members = state.members
        guard !members.isEmpty else {
            RulingEngine.dissolve(&world, key, date: date)
            return
        }

        // Fast membership lookup for this tick.
        var isMember = Array(repeating: false, count: n)
        for m in members where m.index >= 0 && m.index < n {
            isMember[m.index] = true
        }

        // Count landed provinces per country once in O(provinces).
        var provCount = Array(repeating: 0, count: n)
        for o in world.provinces.owner {
            if let o, o.index >= 0 && o.index < n {
                provCount[o.index] += 1
            }
        }

        // Ensure there is always a living Emperor while members exist.
        if state.leader == nil || (state.leader.map { provCount[$0.index] == 0 } ?? true) {
            holdElection(&world, oldEmperor: state.leader, oldRuler: nil, date: date, random: &random)
        }

        // Replenish vacated electorates up to elector_count (default 7).
        replenishElectors(&world, provCount: provCount, date: date)

        // Monthly Imperial Authority calculation.
        let delta = monthlyAuthorityDelta(
            world: world,
            def: def,
            isMember: isMember,
            members: members
        )
        RulingEngine.addValue(&world, key, "authority", delta)

        // Sync stage with any reform flags set by historical events.
        syncReformStage(&world)

        // Update Reformation religious leagues (1517+ Reformation).
        updateReligiousLeagues(&world, date: date)

        // AI Emperor automatically convenes the Reichstag when authority is sufficient.
        if let emp = RulingEngine.leader(world, key),
           !world.humanCountries.contains(emp),
           let next = nextReform(in: world) {
            let isHistorical = !AIGoalSystem.isFreeMode(for: emp, in: world)
            let earliestYear = (isHistorical && next.stage == 1) ? 1490 : 1453
            if date.year >= earliestYear && RulingEngine.value(world, key, "authority") >= next.cost + 5 {
                _ = enactNextReform(&world, by: emp, date: date)
            }
        }
    }

    public static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard let state = RulingEngine.state(world, key),
              state.active,
              let emperor = state.leader else { return }

        // Yearly Imperial favour drift based on relations and war with the Emperor.
        for m in state.members where m != emperor {
            if world.diplomacy.isAtWar(m, emperor) {
                RulingEngine.addCountryValue(&world, key, "favour", m, -10)
            } else {
                let op = world.diplomacy.opinion(of: emperor, by: m)
                if op >= 20 {
                    RulingEngine.addCountryValue(&world, key, "favour", m, 2)
                } else if op <= -40 {
                    RulingEngine.addCountryValue(&world, key, "favour", m, -2)
                }
            }
        }
    }

    public static func rulerChanged(
        _ world: inout World,
        country: CountryID,
        oldRuler: CharacterID?,
        newRuler: CharacterID,
        date: GameDate,
        random: inout GameRandom
    ) {
        guard let state = RulingEngine.state(world, key), state.active else { return }
        guard state.leader == country else { return }

        // If hereditary succession has been enacted, the crown stays with the current ruler's house.
        if state.flags.contains("hereditary_empire") {
            RulingEngine.setLeader(&world, key, country, date: date)
            RulingEngine.addValue(&world, key, "authority", 5)
            return
        }

        holdElection(&world, oldEmperor: country, oldRuler: oldRuler, date: date, random: &random)
    }

    public static func countryVanished(_ world: inout World, country: CountryID, date: GameDate) {
        guard let state = RulingEngine.state(world, key), state.active else { return }

        let penalty: Double
        if state.hasRole(country, "free_city") {
            penalty = RulingEngine.param(world, key, "free_city_annex_penalty", default: 8)
        } else {
            penalty = RulingEngine.param(world, key, "member_annex_penalty", default: 5)
        }
        RulingEngine.addValue(&world, key, "authority", -penalty)
    }

    public static func countryFormed(_ world: inout World, country: CountryID, formable: FormableDef, date: GameDate) {
        if formable.id == "GER" {
            RulingEngine.dissolve(&world, key, date: date)
        }
    }

    // MARK: - Imperial protection (Historical Imperial shield)

    /// Returns the Emperor if the Emperor will automatically join a defensive war
    /// to protect `defender` from `attacker`:
    /// - Always when `attacker` is an outsider (non-HRE) attacking any HRE member.
    /// - Always when `defender` is a Free Imperial City (even against another HRE member).
    public static func imperialDefender(
        in world: World,
        attacker: CountryID,
        defender: CountryID
    ) -> CountryID? {
        guard RulingEngine.isActive(world, key),
              RulingEngine.isMember(world, key, defender),
              let emperor = RulingEngine.leader(world, key),
              emperor != attacker,
              emperor != defender,
              !world.diplomacy.isAtWar(emperor, defender) else {
            return nil
        }
        let attackerIsMember = RulingEngine.isMember(world, key, attacker)
        if !attackerIsMember || RulingEngine.hasRole(world, key, defender, "free_city") {
            return emperor
        }
        return nil
    }

    /// True once Ewiger Landfriede has been proclaimed, forbidding wars between HRE members.
    public static func internalWarsForbidden(in world: World) -> Bool {
        RulingEngine.isActive(world, key) && RulingEngine.hasFlag(world, key, "ewiger_landfriede")
    }

    // MARK: - Reichstag Reforms

    public struct ReformDef: Sendable, Equatable {
        public let stage: Int
        public let flag: String
        public let name: String
        public let summary: String
        public let cost: Double
    }

    /// The six historical Reichstag reforms in enactment order.
    public static let reforms: [ReformDef] = [
        ReformDef(
            stage: 1,
            flag: "reichsreform",
            name: "Reichsreform",
            summary: "Members: -5% build cost, +5% reform progress; Emperor: +5% tax",
            cost: 50
        ),
        ReformDef(
            stage: 2,
            flag: "reichskammergericht",
            name: "Reichskammergericht",
            summary: "Members: -8% stability cost; Emperor: +5% crown power",
            cost: 50
        ),
        ReformDef(
            stage: 3,
            flag: "gemeiner_pfennig",
            name: "Gemeiner Pfennig",
            summary: "Members: +5% tax; Emperor: +10% tax, +10% manpower",
            cost: 50
        ),
        ReformDef(
            stage: 4,
            flag: "ewiger_landfriede",
            name: "Ewiger Landfriede",
            summary: "Forbids internal HRE wars; Members: +5% trade, +5% learning",
            cost: 50
        ),
        ReformDef(
            stage: 5,
            flag: "privilegium_de_non_appellando",
            name: "Privilegium de Non Appellando",
            summary: "Members: +10% fort defence, +5% army quality; Emperor: +10 vassal opinion",
            cost: 50
        ),
        ReformDef(
            stage: 6,
            flag: "hereditary_empire",
            name: "Erbreich (Hereditary Crown)",
            summary: "Abolishes elections; Emperor: +10% crown power, +15% levy size, +10% tax",
            cost: 60
        ),
    ]

    /// The next unpassed Reichstag reform, or nil if all 6 have been enacted.
    public static func nextReform(in world: World) -> ReformDef? {
        guard let state = RulingEngine.state(world, key), state.active else { return nil }
        return reforms.first { !state.flags.contains($0.flag) }
    }

    /// Whether `country` (must be the Emperor) can enact the next Reichstag reform right now.
    public static func canEnactNextReform(in world: World, by country: CountryID) -> Bool {
        guard let state = RulingEngine.state(world, key),
              state.active,
              state.leader == country,
              !state.flags.contains("league_war_active"),
              let next = nextReform(in: world) else {
            return false
        }
        return RulingEngine.value(world, key, "authority") >= next.cost
    }

    /// Enacts the next Reichstag reform, spending Imperial Authority and refreshing member effects.
    @discardableResult
    public static func enactNextReform(_ world: inout World, by country: CountryID, date: GameDate) -> Bool {
        guard canEnactNextReform(in: world, by: country),
              let next = nextReform(in: world) else {
            return false
        }
        RulingEngine.addValue(&world, key, "authority", -next.cost)
        RulingEngine.setFlag(&world, key, next.flag, true)
        RulingEngine.modify(&world, key) { s in
            s.stage = max(s.stage, next.stage)
        }
        for m in RulingEngine.members(world, key) {
            RulingEngine.refresh(&world, m)
        }
        return true
    }

    public static func addEffects(_ world: World, country: CountryID, into fx: inout Effects) {
        guard let state = RulingEngine.state(world, key), state.active else { return }
        let isLeader = state.leader == country
        let flags = state.flags

        if flags.contains("reichsreform") {
            fx[.buildCost] -= 0.05
            fx[.reformProgress] += 0.05
            if isLeader { fx[.tax] += 0.05 }
        }
        if flags.contains("reichskammergericht") {
            fx[.stabilityCost] -= 0.08
            if isLeader { fx[.crownPower] += 0.05 }
        }
        if flags.contains("gemeiner_pfennig") {
            fx[.tax] += 0.05
            if isLeader {
                fx[.tax] += 0.10
                fx[.manpower] += 0.10
            }
        }
        if flags.contains("ewiger_landfriede") {
            fx[.trade] += 0.05
            fx[.learning] += 0.05
        }
        if flags.contains("privilegium_de_non_appellando") {
            fx[.fortDefence] += 0.10
            fx[.armyQuality] += 0.05
            if isLeader { fx[.vassalOpinion] += 10 }
        }
        if flags.contains("hereditary_empire") && isLeader {
            fx[.crownPower] += 0.10
            fx[.levySize] += 0.15
            fx[.tax] += 0.10
        }
    }

    private static func syncReformStage(_ world: inout World) {
        guard let state = RulingEngine.state(world, key) else { return }
        var highest = state.stage
        for r in reforms where state.flags.contains(r.flag) {
            if r.stage > highest { highest = r.stage }
        }
        if highest != state.stage {
            RulingEngine.modify(&world, key) { $0.stage = highest }
            for m in RulingEngine.members(world, key) {
                RulingEngine.refresh(&world, m)
            }
        }
    }

    // MARK: - Religious Leagues (1517+ Reformation)

    public static let catholicLeagueRole = "catholic_league"
    public static let protestantLeagueRole = "protestant_league"

    /// Joins `country` to either `catholic_league` or `protestant_league` while leagues are active.
    @discardableResult
    public static func joinLeague(
        _ world: inout World,
        country: CountryID,
        league: String,
        date: GameDate
    ) -> Bool {
        guard league == catholicLeagueRole || league == protestantLeagueRole,
              RulingEngine.isActive(world, key),
              RulingEngine.hasFlag(world, key, "leagues_active"),
              RulingEngine.isMember(world, key, country) else {
            return false
        }
        let other = (league == catholicLeagueRole) ? protestantLeagueRole : catholicLeagueRole
        if RulingEngine.hasRole(world, key, country, other) {
            RulingEngine.removeRole(&world, key, country, other)
        }
        RulingEngine.addRole(&world, key, country, league, date: date)
        return true
    }

    /// Removes `country` from both religious leagues.
    public static func leaveLeague(_ world: inout World, country: CountryID) {
        if RulingEngine.hasRole(world, key, country, catholicLeagueRole) {
            RulingEngine.removeRole(&world, key, country, catholicLeagueRole)
        }
        if RulingEngine.hasRole(world, key, country, protestantLeagueRole) {
            RulingEngine.removeRole(&world, key, country, protestantLeagueRole)
        }
    }

    /// Settles the Imperial religious question (`catholic_official`, `protestant_official`,
    /// or `religious_peace`), disbands the leagues, and triggers an election if the current
    /// Emperor's faith is no longer eligible.
    public static func settleReligiousPeace(
        _ world: inout World,
        outcome: String,
        date: GameDate,
        random: inout GameRandom
    ) {
        guard outcome == "catholic_official" || outcome == "protestant_official" || outcome == "religious_peace",
              RulingEngine.isActive(world, key) else { return }

        RulingEngine.setFlag(&world, key, "leagues_active", false)
        RulingEngine.setFlag(&world, key, "league_war_active", false)
        RulingEngine.setFlag(&world, key, "catholic_official", outcome == "catholic_official")
        RulingEngine.setFlag(&world, key, "protestant_official", outcome == "protestant_official")
        RulingEngine.setFlag(&world, key, "religious_peace", outcome == "religious_peace")

        for m in RulingEngine.members(world, key) {
            leaveLeague(&world, country: m)
        }

        if let emp = RulingEngine.leader(world, key), emp.index < world.countries.religion.count {
            let faith = world.countries.religion[emp.index]
            let ineligible = (outcome == "catholic_official" && faith != .catholic)
                || (outcome == "protestant_official" && faith != .protestant && faith != .reformed)
            if ineligible {
                holdElection(&world, oldEmperor: emp, oldRuler: nil, date: date, random: &random)
            }
        }
    }

    private static func updateReligiousLeagues(_ world: inout World, date: GameDate) {
        guard let state = RulingEngine.state(world, key), state.active else { return }
        let settled = state.flags.contains("catholic_official")
            || state.flags.contains("protestant_official")
            || state.flags.contains("religious_peace")

        if settled {
            // Ensure no stale league roles linger after an event-driven settlement (e.g. Peace of Augsburg).
            for m in RulingEngine.holders(world, key, catholicLeagueRole) {
                RulingEngine.removeRole(&world, key, m, catholicLeagueRole)
            }
            for m in RulingEngine.holders(world, key, protestantLeagueRole) {
                RulingEngine.removeRole(&world, key, m, protestantLeagueRole)
            }
            return
        }

        // Activate leagues once the 1517+ Reformation takes hold among Imperial estates (1530+).
        if !state.flags.contains("leagues_active") {
            guard world.faith.reformationStarted && date.year >= 1530 else { return }
            let electors = RulingEngine.holders(world, key, "elector")
            let hasProtestantElector = electors.contains { e in
                let f = world.countries.religion[e.index]
                return f == .protestant || f == .reformed
            }
            let protestantMembers = state.members.filter { m in
                let f = world.countries.religion[m.index]
                return f == .protestant || f == .reformed
            }.count
            if hasProtestantElector || protestantMembers >= 4 {
                RulingEngine.setFlag(&world, key, "leagues_active", true)
            } else {
                return
            }
        }

        // AI members align with the league matching their state faith.
        for m in RulingEngine.members(world, key) where !world.humanCountries.contains(m) {
            let faith = world.countries.religion[m.index]
            if faith == .catholic {
                if !RulingEngine.hasRole(world, key, m, catholicLeagueRole) {
                    _ = joinLeague(&world, country: m, league: catholicLeagueRole, date: date)
                }
            } else if faith == .protestant || faith == .reformed || faith == .hussite {
                if !RulingEngine.hasRole(world, key, m, protestantLeagueRole) {
                    _ = joinLeague(&world, country: m, league: protestantLeagueRole, date: date)
                }
            }
        }
    }

    // MARK: - Authority breakdown (public for UI and tests)

    /// Computes the monthly Imperial Authority change for the current world state.
    public static func monthlyAuthorityDelta(in world: World) -> Double {
        guard let def = world.rulingRules.system(key),
              let state = RulingEngine.state(world, key),
              state.active else { return 0 }
        let n = world.countries.count
        let members = state.members
        var isMember = Array(repeating: false, count: n)
        for m in members where m.index >= 0 && m.index < n {
            isMember[m.index] = true
        }
        return monthlyAuthorityDelta(world: world, def: def, isMember: isMember, members: members)
    }

    private static func monthlyAuthorityDelta(
        world: World,
        def: RulingSystemDef,
        isMember: [Bool],
        members: [CountryID]
    ) -> Double {
        let n = world.countries.count

        // 1. Internal peace vs internal Imperial wars.
        var internalWars = 0
        for war in world.diplomacy.wars {
            let hasMemberAttacker = war.attackers.contains { $0.index >= 0 && $0.index < n && isMember[$0.index] }
            let hasMemberDefender = war.defenders.contains { $0.index >= 0 && $0.index < n && isMember[$0.index] }
            if hasMemberAttacker && hasMemberDefender {
                internalWars += 1
            }
        }
        let peaceDelta: Double = internalWars == 0
            ? 0.25
            : -min(0.40, Double(internalWars) * 0.08)

        // 2. Healthy number of Imperial estates and Free Imperial Cities.
        let memberBonus = 0.004 * Double(max(0, members.count - 20))
        let freeCityCount = RulingEngine.holders(world, key, "free_city").count
        let freeCityBonus = 0.015 * Double(freeCityCount)

        // 3. Imperial provinces held by non-members (France, Burgundy, Ottomans, Denmark...).
        var foreignProvinces = 0
        for pid in def.provinces where pid.index >= 0 && pid.index < world.provinces.count {
            if let owner = world.provinces.owner[pid.index],
               owner.index >= 0 && owner.index < n,
               !isMember[owner.index] {
                foreignProvinces += 1
            }
        }
        let foreignPenalty = -min(0.60, Double(foreignProvinces) * 0.03)

        // 4. Religious disunity (heretic princes vs Emperor's faith, active after Reformation).
        // Peace of Augsburg halves religious disunity drain.
        var hereticPenalty = 0.0
        if let emp = RulingEngine.leader(world, key), emp.index >= 0 && emp.index < n {
            let empFaith = world.countries.religion[emp.index]
            var heretics = 0
            for m in members where m.index >= 0 && m.index < n {
                if world.countries.religion[m.index] != empFaith {
                    heretics += 1
                }
            }
            let perHeretic = RulingEngine.hasFlag(world, key, "religious_peace") ? 0.005 : 0.01
            hereticPenalty = -min(0.30, Double(heretics) * perHeretic)
        }

        return peaceDelta + memberBonus + freeCityBonus + foreignPenalty + hereticPenalty
    }

    // MARK: - Elections (public helpers for UI and tests)

    /// Eligible candidates for the Imperial crown (sorted by CountryID.index).
    public static func eligibleCandidates(in world: World, excluding: CountryID? = nil) -> [CountryID] {
        guard let state = RulingEngine.state(world, key), state.active else { return [] }
        let n = world.countries.count
        var provCount = Array(repeating: 0, count: n)
        for o in world.provinces.owner {
            if let o, o.index >= 0 && o.index < n { provCount[o.index] += 1 }
        }

        let catholicOnly = state.flags.contains("catholic_official")
        let protestantOnly = state.flags.contains("protestant_official")

        // Prefer independent landed Christian monarchies inside the Empire.
        let monarchies = state.members.filter { c in
            guard c != excluding, c.index >= 0 && c.index < n, provCount[c.index] > 0 else { return false }
            guard world.countries.government[c.index] == .monarchy else { return false }
            guard world.countries.overlord[c.index] == nil || c == state.leader else { return false }
            let faith = world.countries.religion[c.index]
            guard faith.family == .christian else { return false }
            if catholicOnly && faith != .catholic { return false }
            if protestantOnly && faith != .protestant && faith != .reformed { return false }
            return true
        }
        if !monarchies.isEmpty { return monarchies }

        // Fallback: any landed member if no eligible monarchy remains.
        return state.members.filter { c in
            c != excluding && c.index >= 0 && c.index < n && provCount[c.index] > 0
        }
    }

    /// Deterministic score a given elector gives a candidate.
    public static func electorScore(
        voter: CountryID,
        candidate: CountryID,
        in world: World,
        oldEmperor: CountryID? = nil,
        oldRuler: CharacterID? = nil,
        provCount: [Int]? = nil
    ) -> Double {
        let n = world.countries.count
        guard voter.index >= 0, voter.index < n, candidate.index >= 0, candidate.index < n else {
            return -1000
        }

        if world.diplomacy.isAtWar(voter, candidate) {
            return -200
        }

        var score = 0.0

        // 1. Bilateral opinion (-200..+200 -> -120..+120).
        score += Double(world.diplomacy.opinion(of: candidate, by: voter)) * 0.6

        // 2. Shared religion.
        let vFaith = world.countries.religion[voter.index]
        let cFaith = world.countries.religion[candidate.index]
        if vFaith == cFaith {
            score += 30
        } else if cFaith.family == .christian {
            score -= 40
        } else {
            score -= 100
        }

        // 3. Diplomatic ties (alliance).
        if world.diplomacy.areAllies(voter, candidate) {
            score += 25
        }

        // 4. Dynasty ties & incumbent continuity (Habsburg incumbency).
        let currentEmp = oldEmperor ?? RulingEngine.leader(world, key)
        if candidate == currentEmp {
            score += 35
        }
        let vDyn = rulerDynasty(of: voter, in: world)
        let cDyn = rulerDynasty(of: candidate, in: world)
        if let vDyn, let cDyn, vDyn == cDyn {
            score += 15
        }
        if let oldRuler, oldRuler.index >= 0 && oldRuler.index < world.people.characters.dynasty.count,
           let oldDyn = world.people.characters.dynasty[oldRuler.index],
           let cDyn, oldDyn == cDyn {
            score += 20
        }

        // 5. Ruler diplomacy skill (0..20 -> 0..60).
        if let rulerID = world.countries.ruler[candidate.index],
           rulerID.index >= 0 && rulerID.index < world.people.characters.skills.count {
            let dip = world.people.characters.skills[rulerID.index][Skill.diplomacy.rawValue]
            score += Double(dip) * 3.0
        }

        // 6. Realm size (provinces, capped at 15 -> 0..30).
        let count: Int
        if let provCount {
            count = provCount[candidate.index]
        } else {
            count = world.provinces.owner.reduce(0) { $0 + ($1 == candidate ? 1 : 0) }
        }
        score += min(Double(count), 15.0) * 2.0

        // 7. Imperial favour (0..100 -> 0..25).
        score += RulingEngine.countryValue(world, key, "favour", candidate) * 0.25

        // 8. Secular electors may back themselves if strong.
        if voter == candidate {
            score += 15
        }

        return score
    }

    /// Returns each active elector and the candidate it currently leans toward (no jitter).
    public static func electorLeans(in world: World) -> [(elector: CountryID, lean: CountryID?)] {
        let electors = RulingEngine.holders(world, key, "elector")
        let candidates = eligibleCandidates(in: world)
        let n = world.countries.count
        var provCount = Array(repeating: 0, count: n)
        for o in world.provinces.owner {
            if let o, o.index >= 0 && o.index < n { provCount[o.index] += 1 }
        }
        guard !candidates.isEmpty else {
            return electors.map { ($0, nil) }
        }
        return electors.map { elector in
            var best: CountryID = candidates[0]
            var bestScore = -Double.infinity
            for cand in candidates {
                let sc = electorScore(voter: elector, candidate: cand, in: world, provCount: provCount)
                if sc > bestScore {
                    bestScore = sc
                    best = cand
                }
            }
            return (elector, best)
        }
    }

    // MARK: - Private helpers

    private static func holdElection(
        _ world: inout World,
        oldEmperor: CountryID?,
        oldRuler: CharacterID?,
        date: GameDate,
        random: inout GameRandom
    ) {
        let n = world.countries.count
        var provCount = Array(repeating: 0, count: n)
        for o in world.provinces.owner {
            if let o, o.index >= 0 && o.index < n { provCount[o.index] += 1 }
        }

        let candidates = eligibleCandidates(in: world)
        guard !candidates.isEmpty else {
            RulingEngine.setLeader(&world, key, nil, date: date)
            return
        }

        var voters = RulingEngine.holders(world, key, "elector").filter {
            $0.index >= 0 && $0.index < n && provCount[$0.index] > 0
        }
        if voters.isEmpty {
            voters = candidates
        }

        let election = RulingEngine.elect(
            voters: voters,
            candidates: candidates,
            jitter: 5.0,
            random: &random
        ) { voter, cand in
            electorScore(
                voter: voter,
                candidate: cand,
                in: world,
                oldEmperor: oldEmperor,
                oldRuler: oldRuler,
                provCount: provCount
            )
        }

        guard let result = election else { return }
        RulingEngine.setLeader(&world, key, result.winner, date: date)
        let authorityGain: Double = (result.winner == oldEmperor) ? 5 : 2
        RulingEngine.addValue(&world, key, "authority", authorityGain)
    }

    private static func replenishElectors(_ world: inout World, provCount: [Int], date: GameDate) {
        let targetCount = Int(RulingEngine.param(world, key, "elector_count", default: 7))
        let current = RulingEngine.holders(world, key, "elector")
        guard current.count < targetCount else { return }
        guard let emperor = RulingEngine.leader(world, key) else { return }

        let currentSet = Set(current)
        let members = RulingEngine.members(world, key)
        let eligible = members.filter { c in
            !currentSet.contains(c)
                && c != emperor
                && !RulingEngine.hasRole(world, key, c, "free_city")
                && c.index >= 0 && c.index < provCount.count
                && provCount[c.index] > 0
        }
        let sorted = eligible.sorted { a, b in
            let fa = RulingEngine.countryValue(world, key, "favour", a)
                + Double(world.diplomacy.opinion(of: emperor, by: a)) * 0.5
            let fb = RulingEngine.countryValue(world, key, "favour", b)
                + Double(world.diplomacy.opinion(of: emperor, by: b)) * 0.5
            if fa != fb { return fa > fb }
            return a.index < b.index
        }

        let needed = targetCount - current.count
        for cand in sorted.prefix(needed) {
            RulingEngine.addRole(&world, key, cand, "elector", date: date)
        }
    }

    private static func rulerDynasty(of country: CountryID, in world: World) -> String? {
        guard country.index >= 0, country.index < world.countries.ruler.count,
              let ruler = world.countries.ruler[country.index],
              ruler.index >= 0, ruler.index < world.people.characters.dynasty.count else {
            return nil
        }
        return world.people.characters.dynasty[ruler.index]
    }
}
