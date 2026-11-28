import Foundation

/// Phase 20.8: Japanese Shogunate ruling system.
///
/// Implements Bakufu Authority dynamics (shogun competence, Kanrei loyalty,
/// internal shugo wars, disloyal shugo, foreign-held provinces), Kanrei rotation
/// among the Sankanrei houses (Hosokawa, Hatakeyama, Shiba — or strongest loyal
/// shugo fallback), the slide into the Sengoku period (bakufu_authority < 25 or
/// Onin War), Kyoto usurpation (taking Kyoto claims the Shogunate and inherits
/// remaining shugo vassals), and Tenka Toitsu unification (75%+ of Japan + Kyoto
/// + 60+ Bakufu Authority).
public enum ShogunateSystem: RulingSystem {
    public static let key = "shogunate"

    // MARK: - Hooks

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard let state = RulingEngine.state(world, key), state.active else { return }

        let members = state.members
        guard !members.isEmpty else {
            RulingEngine.dissolve(&world, key, date: date)
            return
        }

        // 1. Check whether another Japanese lord has seized Kyoto and claimed the Shogunate.
        checkKyotoUsurpation(&world, date: date, random: &random)

        // 2. Ensure a living, non-hostile Kanrei is appointed if eligible shugo remain.
        ensureKanrei(&world, date: date, random: &random)

        // 3. Monthly Bakufu Authority drift.
        let delta = monthlyAuthorityDelta(in: world)
        RulingEngine.addValue(&world, key, "bakufu_authority", delta)

        // 4. Stage & Sengoku / Tenka Toitsu transitions.
        syncStageAndTransitions(&world, date: date)
    }

    public static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard let state = RulingEngine.state(world, key),
              state.active,
              let shogun = state.leader else { return }

        for m in state.members where m != shogun {
            if world.diplomacy.isAtWar(m, shogun) {
                RulingEngine.addCountryValue(&world, key, "loyalty", m, -12)
            } else {
                let op = world.diplomacy.opinion(of: shogun, by: m)
                if op >= 25 {
                    let bonus: Double = state.hasRole(m, "kanrei") ? 5 : 3
                    RulingEngine.addCountryValue(&world, key, "loyalty", m, bonus)
                } else if op <= -30 {
                    RulingEngine.addCountryValue(&world, key, "loyalty", m, -3)
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

        if state.leader == country {
            // Shogunal succession tests Bakufu authority unless Tenka Toitsu is achieved.
            if !state.flags.contains("tenka_toitsu") {
                RulingEngine.addValue(&world, key, "bakufu_authority", -5)
            }
            return
        }

        if state.hasRole(country, "kanrei") {
            appointKanrei(&world, date: date, random: &random)
        }
    }

    public static func countryVanished(_ world: inout World, country: CountryID, date: GameDate) {
        guard let state = RulingEngine.state(world, key), state.active else { return }
        if state.hasRole(country, "shugo") {
            let penalty = RulingEngine.param(world, key, "shugo_annex_penalty", default: 3)
            RulingEngine.addValue(&world, key, "bakufu_authority", -penalty)
        }
    }

    public static func countryFormed(_ world: inout World, country: CountryID, formable: FormableDef, date: GameDate) {
        guard formable.id == "JPN", RulingEngine.isActive(world, key) else { return }
        RulingEngine.setFlag(&world, key, "tenka_toitsu")
        RulingEngine.setFlag(&world, key, "sengoku_active", false)
        RulingEngine.modify(&world, key) { $0.stage = 2 }
        for m in RulingEngine.members(world, key) {
            RulingEngine.refresh(&world, m)
        }
    }

    public static func addEffects(_ world: World, country: CountryID, into fx: inout Effects) {
        guard let state = RulingEngine.state(world, key), state.active else { return }
        let isLeader = state.leader == country
        let isShugoMember = state.hasRole(country, "shugo")
        let flags = state.flags

        if flags.contains("sengoku_active") && !flags.contains("tenka_toitsu") {
            if isShugoMember {
                fx[.armyQuality] += 0.05
                fx[.levySize] += 0.10
            }
            if isLeader {
                fx[.crownPower] -= 0.08
            }
        }

        if flags.contains("tenka_toitsu") {
            fx[.trade] += 0.05
            if isLeader {
                fx[.crownPower] += 0.10
                fx[.tax] += 0.10
                fx[.stabilityCost] -= 0.10
            }
        }
    }

    // MARK: - Queries

    /// True once Sengoku warfare is active (internal shugo wars and marching on Kyoto allowed)
    /// and Tenka Toitsu has not yet pacified the realm.
    public static func internalWarsAllowed(in world: World) -> Bool {
        guard let state = RulingEngine.state(world, key), state.active else { return false }
        return state.flags.contains("sengoku_active") && !state.flags.contains("tenka_toitsu")
    }

    /// True if `country` holds the `shugo` role in an active Shogunate.
    public static func isShugo(_ world: World, _ country: CountryID) -> Bool {
        RulingEngine.isActive(world, key) && RulingEngine.hasRole(world, key, country, "shugo")
    }

    /// True when `attacker` (a shugo vassal) may declare an internal Sengoku war
    /// against `defender` (either another shugo or the Shogun to seize Kyoto).
    public static func canDeclareSengokuWar(
        attacker: CountryID,
        defender: CountryID,
        in world: World
    ) -> Bool {
        guard internalWarsAllowed(in: world),
              isShugo(world, attacker),
              RulingEngine.isMember(world, key, defender) else {
            return false
        }
        return true
    }

    /// Subjects of the Shogun who will rally to defend Kyoto when a shugo marches on the Shogun
    /// during the Sengoku period (loyal shugo with opinion >= 40, or a non-hostile Kanrei).
    public static func shogunDefenders(
        in world: World,
        attacker: CountryID,
        shogun: CountryID
    ) -> [CountryID] {
        let currentKanrei = kanrei(in: world)
        return world.countries.subjects(of: shogun).filter { s in
            guard s != attacker && s != shogun else { return false }
            let op = world.diplomacy.opinion(of: shogun, by: s)
            if s == currentKanrei {
                return op >= 0
            }
            return op >= 40
        }
    }

    /// Returns a Sengoku internal conquest or March on Kyoto CB when `attacker` and `defender`
    /// are neighbouring Shogunate members during `sengoku_active`.
    public static func sengokuCasusBelli(
        attacker: CountryID,
        defender: CountryID,
        defenderProvinces: [ProvinceID],
        in world: World
    ) -> CasusBelliInstance? {
        guard canDeclareSengokuWar(attacker: attacker, defender: defender, in: world),
              !defenderProvinces.isEmpty else { return nil }

        if RulingEngine.leader(world, key) == defender,
           let kyoto = world.provinces.id(named: "Kyoto"),
           world.provinces.owner[kyoto.index] == defender {
            return CasusBelliInstance(
                type: .claim,
                target: defender,
                warGoal: .conquerProvince(kyoto),
                targetProvince: kyoto,
                name: "March on Kyoto",
                description: "Challenge the weakened Bakufu and seize Kyoto to claim the Shogunate."
            )
        }

        guard let targetProv = defenderProvinces.max(by: { a, b in
            let da = world.provinces.development[a.index]
            let db = world.provinces.development[b.index]
            return da == db ? a.index > b.index : da < db
        }) else { return nil }

        let pName = world.provinces.name[targetProv.index]
        return CasusBelliInstance(
            type: .claim,
            target: defender,
            warGoal: .conquerProvince(targetProv),
            targetProvince: targetProv,
            name: "Sengoku Struggle for \(pName)",
            description: "Contest \(pName) in the warring provinces of the Sengoku period."
        )
    }

    /// Immediately checks for Kyoto usurpation after a peace treaty using the rulings RNG stream.
    public static func handleKyotoCaptureInPeace(_ world: inout World, date: GameDate) {
        guard RulingEngine.isActive(world, key) else { return }
        var rng = GameRandom(seed: world.rulings.rngState)
        checkKyotoUsurpation(&world, date: date, random: &rng)
        world.rulings.rngState = rng.rawState
    }

    /// Current holder of the Kanrei (Deputy Shogun) office, if any.
    public static func kanrei(in world: World) -> CountryID? {
        RulingEngine.holders(world, key, "kanrei").first
    }

    /// Fraction (0.0..1.0) of the 60 Shogunate provinces controlled directly by the Shogun
    /// or indirectly through the Shogun's vassals.
    public static func shogunControlledFraction(in world: World) -> Double {
        guard let def = world.rulingRules.system(key),
              !def.provinces.isEmpty,
              let shogun = RulingEngine.leader(world, key) else { return 0 }

        var controlled = 0
        for p in def.provinces {
            guard p.index >= 0 && p.index < world.provinces.owner.count,
                  let owner = world.provinces.owner[p.index] else { continue }
            if owner == shogun || world.countries.overlord[owner.index] == shogun {
                controlled += 1
            }
        }
        return Double(controlled) / Double(def.provinces.count)
    }

    /// True when the Shogun holds Kyoto, controls >= 75% of Shogunate provinces (directly or via vassals),
    /// has >= 60 Bakufu Authority, and has not yet proclaimed Tenka Toitsu.
    public static func canProclaimTenkaToitsu(in world: World) -> Bool {
        guard let state = RulingEngine.state(world, key),
              state.active,
              !state.flags.contains("tenka_toitsu"),
              let shogun = state.leader,
              let kyoto = world.provinces.id(named: "Kyoto"),
              world.provinces.owner[kyoto.index] == shogun else { return false }

        let reqAuth = RulingEngine.param(world, key, "unification_authority", default: 60)
        let reqPct = RulingEngine.param(world, key, "unification_pct", default: 75) / 100.0
        guard RulingEngine.value(world, key, "bakufu_authority") >= reqAuth else { return false }
        return shogunControlledFraction(in: world) >= reqPct
    }

    /// Proclaims Tenka Toitsu (Pacification of the Realm), ending the Sengoku period
    /// and unlocking the unified Japan (`JPN`) formable.
    @discardableResult
    public static func proclaimTenkaToitsu(
        _ world: inout World,
        by country: CountryID,
        date: GameDate
    ) -> Bool {
        guard RulingEngine.leader(world, key) == country,
              canProclaimTenkaToitsu(in: world) else { return false }

        RulingEngine.setFlag(&world, key, "tenka_toitsu")
        RulingEngine.setFlag(&world, key, "sengoku_active", false)
        RulingEngine.modify(&world, key) { $0.stage = 2 }
        GovernmentSystem.changeStability(&world, country, by: 1)
        world.countries.prestige[country.index] = min(100, world.countries.prestige[country.index] + 20)

        for m in RulingEngine.members(world, key) {
            RulingEngine.refresh(&world, m)
        }
        return true
    }

    // MARK: - Kyoto Usurpation

    /// If another Shogunate member (or Shinto Japanese lord) owns Kyoto, they immediately
    /// usurp the Shogunate, inherit the remaining shugo vassals, and reset Bakufu Authority to 40.
    public static func checkKyotoUsurpation(
        _ world: inout World,
        date: GameDate,
        random: inout GameRandom
    ) {
        guard let state = RulingEngine.state(world, key),
              state.active,
              let kyoto = world.provinces.id(named: "Kyoto"),
              let holder = world.provinces.owner[kyoto.index],
              holder != state.leader else { return }

        let isEligibleUsurper = state.isMember(holder)
            || world.countries.religion[holder.index] == .shinto
        guard isEligibleUsurper else { return }

        let oldLeader = state.leader
        let wasKanrei = state.hasRole(holder, "kanrei")

        // Ensure usurper is a member, independent, and no longer a shugo or kanrei.
        RulingEngine.join(&world, key, holder)
        RulingEngine.removeRole(&world, key, holder, "shugo")
        if wasKanrei {
            RulingEngine.removeRole(&world, key, holder, "kanrei")
        }
        world.countries.overlord[holder.index] = nil
        world.countries.subjectType[holder.index] = nil

        // If the deposed Shogun still holds land, demote them to a shugo member.
        if let old = oldLeader, old != holder {
            let oldHasLand = world.provinces.owner.contains(old)
            if oldHasLand {
                RulingEngine.addRole(&world, key, old, "shugo", date: date)
                if !world.diplomacy.isAtWar(old, holder) {
                    world.countries.overlord[old.index] = holder
                    world.countries.subjectType[old.index] = .vassal
                }
            }
        }

        // Transfer remaining shugo vassals of the old Shogun to the new Shogun.
        for s in RulingEngine.holders(world, key, "shugo") where s != holder {
            let curOverlord = world.countries.overlord[s.index]
            if (curOverlord == oldLeader || curOverlord == nil) && !world.diplomacy.isAtWar(s, holder) {
                world.countries.overlord[s.index] = holder
                world.countries.subjectType[s.index] = .vassal
            }
        }

        // Install the new Shogun and reset Bakufu Authority.
        RulingEngine.setLeader(&world, key, holder, date: date)
        let resetAuth = RulingEngine.param(world, key, "usurp_authority", default: 40)
        RulingEngine.setValue(&world, key, "bakufu_authority", resetAuth)

        if wasKanrei || RulingEngine.holders(world, key, "kanrei").isEmpty {
            appointKanrei(&world, date: date, random: &random)
        }

        RulingEngine.refresh(&world, holder)
        if let old = oldLeader {
            RulingEngine.refresh(&world, old)
        }
    }

    // MARK: - Kanrei Rotation

    /// Appoints a new Kanrei (Deputy Shogun), preferring eligible Sankanrei houses
    /// (`HSK`, `HTK`, `SHB`) and falling back to the strongest loyal shugo if none remain.
    public static func appointKanrei(
        _ world: inout World,
        date: GameDate,
        random: inout GameRandom
    ) {
        guard let state = RulingEngine.state(world, key),
              state.active,
              let shogun = state.leader else { return }

        let oldHolders = state.holders("kanrei")
        for old in oldHolders {
            RulingEngine.removeRole(&world, key, old, "kanrei")
        }

        let n = world.countries.count
        var provCount = Array(repeating: 0, count: n)
        for o in world.provinces.owner {
            if let o, o.index >= 0 && o.index < n { provCount[o.index] += 1 }
        }

        let sankanreiPool = state.holders("sankanrei").filter { c in
            c != shogun
                && provCount[c.index] > 0
                && !world.diplomacy.isAtWar(c, shogun)
                && world.diplomacy.opinion(of: shogun, by: c) > -80
        }

        let candidates: [CountryID]
        if !sankanreiPool.isEmpty {
            candidates = sankanreiPool
        } else {
            candidates = state.holders("shugo").filter { c in
                c != shogun
                    && provCount[c.index] > 0
                    && !world.diplomacy.isAtWar(c, shogun)
            }
        }

        guard !candidates.isEmpty else {
            for old in oldHolders { RulingEngine.refresh(&world, old) }
            return
        }

        let election = RulingEngine.elect(
            voters: [shogun],
            candidates: candidates,
            jitter: 3.0,
            random: &random
        ) { _, candidate in
            var score = Double(world.diplomacy.opinion(of: shogun, by: candidate)) * 0.5
            score += RulingEngine.countryValue(world, key, "loyalty", candidate) * 0.6
            score += min(Double(provCount[candidate.index]), 12.0) * 4.0
            if let rulerID = world.countries.ruler[candidate.index],
               rulerID.index >= 0 && rulerID.index < world.people.characters.skills.count {
                let dip = world.people.characters.skills[rulerID.index][Skill.diplomacy.rawValue]
                score += Double(dip) * 3.0
            }
            if state.hasRole(candidate, "sankanrei") {
                score += 20.0
            }
            return score
        }

        if let winner = election?.winner {
            RulingEngine.addRole(&world, key, winner, "kanrei", date: date)
            RulingEngine.refresh(&world, winner)
        }
        for old in oldHolders {
            RulingEngine.refresh(&world, old)
        }
    }

    private static func ensureKanrei(
        _ world: inout World,
        date: GameDate,
        random: inout GameRandom
    ) {
        guard let state = RulingEngine.state(world, key),
              state.active,
              let shogun = state.leader else { return }

        let current = state.holders("kanrei")
        let needsReplacement: Bool
        if let k = current.first {
            let hasLand = world.provinces.owner.contains(k)
            needsReplacement = (k == shogun) || !hasLand || world.diplomacy.isAtWar(k, shogun)
        } else {
            needsReplacement = true
        }

        if needsReplacement {
            appointKanrei(&world, date: date, random: &random)
        }
    }

    // MARK: - Bakufu Authority Dynamics

    /// Computes the monthly change in `bakufu_authority`.
    public static func monthlyAuthorityDelta(in world: World) -> Double {
        guard let def = world.rulingRules.system(key),
              let state = RulingEngine.state(world, key),
              state.active,
              let shogun = state.leader else { return 0 }

        var delta = 0.0

        // 1. Shogun's ruler competence (stewardship + diplomacy).
        if let rulerID = world.countries.ruler[shogun.index],
           rulerID.index >= 0 && rulerID.index < world.people.characters.skills.count {
            let skills = world.people.characters.skills[rulerID.index]
            let adminDip = skills[Skill.stewardship.rawValue] + skills[Skill.diplomacy.rawValue]
            if adminDip >= 14 {
                delta += 0.15
            } else if adminDip <= 8 {
                delta -= 0.12
            }
        }

        // 2. Kanrei loyalty effect: loyal Kanrei props up authority, hostile Kanrei drains it.
        if let k = state.holders("kanrei").first, k != shogun {
            let op = world.diplomacy.opinion(of: shogun, by: k)
            if world.diplomacy.isAtWar(k, shogun) || op < -20 {
                delta -= 0.20
            } else if op >= 20 {
                delta += 0.15
            }
        }

        // 3. Internal wars between Shogunate members.
        let n = world.countries.count
        var isMember = Array(repeating: false, count: n)
        for m in state.members where m.index >= 0 && m.index < n {
            isMember[m.index] = true
        }
        var internalWars = 0
        for war in world.diplomacy.wars {
            let attHas = war.attackers.contains { $0.index >= 0 && $0.index < n && isMember[$0.index] }
            let defHas = war.defenders.contains { $0.index >= 0 && $0.index < n && isMember[$0.index] }
            if attHas && defHas {
                internalWars += 1
            }
        }
        if internalWars > 0 {
            delta -= min(0.72, Double(internalWars) * 0.18)
        } else if !state.flags.contains("sengoku_active") {
            delta += 0.10
        }

        // 4. Disloyal shugo (opinion <= -50 or at war with Shogun).
        var disloyalCount = 0
        for s in state.holders("shugo") where s != shogun {
            if world.diplomacy.isAtWar(s, shogun) || world.diplomacy.opinion(of: shogun, by: s) <= -50 {
                disloyalCount += 1
            }
        }
        if disloyalCount > 0 {
            delta -= min(0.32, Double(disloyalCount) * 0.04)
        }

        // 5. Foreign-held Shogunate provinces.
        var foreignProvs = 0
        for p in def.provinces {
            guard p.index >= 0 && p.index < world.provinces.owner.count,
                  let owner = world.provinces.owner[p.index] else { continue }
            if owner.index < 0 || owner.index >= n || !isMember[owner.index] {
                foreignProvs += 1
            }
        }
        if foreignProvs > 0 {
            delta -= min(0.40, Double(foreignProvs) * 0.04)
        }

        // 6. Tenka Toitsu stability dividend.
        if state.flags.contains("tenka_toitsu") {
            delta += 0.25
        }

        return delta
    }

    // MARK: - Stage Sync & Transitions

    private static func syncStageAndTransitions(_ world: inout World, date: GameDate) {
        guard let state = RulingEngine.state(world, key), state.active else { return }

        if state.flags.contains("tenka_toitsu") {
            let hadSengoku = state.flags.contains("sengoku_active")
            if hadSengoku {
                RulingEngine.setFlag(&world, key, "sengoku_active", false)
            }
            if state.stage != 2 || hadSengoku {
                RulingEngine.modify(&world, key) { $0.stage = 2 }
                for m in RulingEngine.members(world, key) {
                    RulingEngine.refresh(&world, m)
                }
            }
            return
        }

        let threshold = RulingEngine.param(world, key, "sengoku_threshold", default: 25)
        let authority = RulingEngine.value(world, key, "bakufu_authority")

        if !state.flags.contains("sengoku_active") && authority < threshold {
            RulingEngine.setFlag(&world, key, "sengoku_active")
            RulingEngine.modify(&world, key) { $0.stage = 1 }
            for m in RulingEngine.members(world, key) {
                RulingEngine.refresh(&world, m)
            }
            return
        }

        if state.flags.contains("sengoku_active") && state.stage != 1 {
            RulingEngine.modify(&world, key) { $0.stage = 1 }
            for m in RulingEngine.members(world, key) {
                RulingEngine.refresh(&world, m)
            }
        }

        // AI Shogun automatically proclaims Tenka Toitsu once conditions are met.
        if let shogun = state.leader,
           !world.humanCountries.contains(shogun),
           canProclaimTenkaToitsu(in: world) {
            _ = proclaimTenkaToitsu(&world, by: shogun, date: date)
        }
    }
}
