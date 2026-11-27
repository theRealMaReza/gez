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
        var hereticPenalty = 0.0
        if let emp = RulingEngine.leader(world, key), emp.index >= 0 && emp.index < n {
            let empFaith = world.countries.religion[emp.index]
            var heretics = 0
            for m in members where m.index >= 0 && m.index < n {
                if world.countries.religion[m.index] != empFaith {
                    heretics += 1
                }
            }
            hereticPenalty = -min(0.30, Double(heretics) * 0.01)
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

        let officialFaith: Religion?
        if state.flags.contains("catholic_official") {
            officialFaith = .catholic
        } else if state.flags.contains("protestant_official") {
            officialFaith = .protestant
        } else {
            officialFaith = nil
        }

        // Prefer independent landed Christian monarchies inside the Empire.
        let monarchies = state.members.filter { c in
            guard c != excluding, c.index >= 0 && c.index < n, provCount[c.index] > 0 else { return false }
            guard world.countries.government[c.index] == .monarchy else { return false }
            guard world.countries.overlord[c.index] == nil || c == state.leader else { return false }
            let faith = world.countries.religion[c.index]
            guard faith.family == .christian else { return false }
            if let officialFaith, faith != officialFaith { return false }
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
