import Foundation

// MARK: - The hook every ruling system implements

/// The Swift side of one ruling system (the HRE, the Shogunate...).
///
/// A system is data first (`data/rulings/systems/<key>.txt`: members, roles,
/// numbers, role effects) and optionally a Swift type conforming to this
/// protocol for rules data cannot express (elections, authority, tribute).
/// Every hook has a do-nothing default, so a system implements only what it
/// needs. Hooks run only while the system is active and present in the data.
///
/// Rules for a system's code (also in `docs/RULING_SYSTEMS.md`):
/// - Keep state in `world.rulings` through `RulingEngine` (roles, values,
///   per-country values, flags, stage); never add fields to `SaveSnapshot`.
/// - Draw random numbers only from the `random` handed to the hook.
/// - Never iterate a `Set` or `Dictionary` to decide something; use the
///   sorted helpers (`members`, `holders`) or sort first.
public protocol RulingSystem {
    /// Same key as the data file (`hre`, `shogunate`...).
    static var key: String { get }

    /// Once, when a new game starts (after the data set up members and values).
    static func start(_ world: inout World, date: GameDate)

    /// On the 1st of every month, before the government tick.
    static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom)

    /// On 1 January.
    static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom)

    /// A member's (or the leader's) ruler was succeeded: elections, kurultai...
    static func rulerChanged(
        _ world: inout World,
        country: CountryID,
        oldRuler: CharacterID?,
        newRuler: CharacterID,
        date: GameDate,
        random: inout GameRandom
    )

    /// A member lost its last province. Afterwards the engine removes it from
    /// the system (and clears it as leader) unless the hook already did.
    static func countryVanished(_ world: inout World, country: CountryID, date: GameDate)

    /// Any country just formed a formable (forming Germany may end the HRE).
    static func countryFormed(_ world: inout World, country: CountryID, formable: FormableDef, date: GameDate)

    /// Extra modifiers for a member, on top of the data's role effects.
    /// Called whenever the country's government effects are refreshed: keep it cheap.
    static func addEffects(_ world: World, country: CountryID, into fx: inout Effects)
}

public extension RulingSystem {
    static func start(_ world: inout World, date: GameDate) {}
    static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {}
    static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom) {}
    static func rulerChanged(
        _ world: inout World,
        country: CountryID,
        oldRuler: CharacterID?,
        newRuler: CharacterID,
        date: GameDate,
        random: inout GameRandom
    ) {}
    static func countryVanished(_ world: inout World, country: CountryID, date: GameDate) {}
    static func countryFormed(_ world: inout World, country: CountryID, formable: FormableDef, date: GameDate) {}
    static func addEffects(_ world: World, country: CountryID, into fx: inout Effects) {}
}

/// Where the Swift ruling systems are listed.
public enum RulingSystems {
    /// Every ruling system written in Swift, e.g. `HRESystem.self`.
    /// **Add a new system here.** Hooks run in the data's system order
    /// (file name order in `data/rulings/systems/`), not this list's.
    public static let builtIn: [any RulingSystem.Type] = []

    private static let lock = NSLock()
    private static var table: [String: any RulingSystem.Type] = {
        var t: [String: any RulingSystem.Type] = [:]
        for s in builtIn { t[s.key] = s }
        return t
    }()

    /// The Swift type for a system key, if one is written.
    public static func behaviour(for key: String) -> (any RulingSystem.Type)? {
        lock.lock()
        defer { lock.unlock() }
        return table[key]
    }

    /// Adds a system type at run time. Tests use this with keys that exist
    /// only in their own test data, so other tests are not affected.
    public static func register(_ system: any RulingSystem.Type) {
        lock.lock()
        defer { lock.unlock() }
        table[system.key] = system
    }
}

// MARK: - Election helper

/// Result of `RulingEngine.elect`.
public struct RulingElection: Sendable, Equatable {
    public let winner: CountryID
    /// Votes per candidate, same order as the candidates passed in.
    public let votes: [Int]
    /// Which candidate each voter chose, same order as the voters.
    public let ballots: [CountryID]
}

// MARK: - Engine

/// Shared machinery for every ruling system: membership, roles, numbers,
/// flags, effects, hooks, elections, and the event conditions and effects
/// that let data files touch any system without new Swift code.
public enum RulingEngine {

    // MARK: Set-up

    /// Builds the starting state from the data (new game only; saves restore it).
    public static func setUp(_ world: inout World, date: GameDate) {
        let n = world.countries.count
        var state = RulingState()
        for def in world.rulingRules.systems {
            var s = RulingSystemState(key: def.key, countryCount: n)
            for role in def.roleOrder {
                for c in def.roles[role] ?? [] where c.index >= 0 && c.index < n {
                    insert(role, into: &s.roles[c.index])
                    insert("member", into: &s.roles[c.index])
                }
            }
            if let l = def.leader, l.index >= 0, l.index < n {
                s.leader = l
                s.leaderSince = date
                insert("member", into: &s.roles[l.index])
            }
            for k in def.values.keys.sorted() {
                s.values[k] = clamp(def.values[k] ?? 0, def.limits[k])
            }
            state.systems.append(s)
        }
        state.resize(countries: n)
        var land = Array(repeating: false, count: n)
        for o in world.provinces.owner { if let o, o.index < n { land[o.index] = true } }
        state.hadLand = land
        world.rulings = state
        for def in world.rulingRules.systems {
            behaviour(def.key, in: world)?.start(&world, date: date)
        }
    }

    /// Lines saved state up with the current data after loading a save:
    /// systems are matched by key, new systems start from their data, and
    /// systems no longer in the data are dropped.
    public static func adopt(_ saved: RulingState, into world: inout World, date: GameDate) {
        let n = world.countries.count
        let fresh = world.rulings
        var out = saved
        out.systems = world.rulingRules.systems.map { def in
            saved.system(def.key) ?? fresh.system(def.key) ?? RulingSystemState(key: def.key, countryCount: n)
        }
        out.resize(countries: n)
        world.rulings = out
    }

    static func behaviour(_ key: String, in world: World) -> (any RulingSystem.Type)? {
        RulingSystems.behaviour(for: key)
    }

    // MARK: Ticks

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let n = world.countries.count
        guard n > 0, !world.rulingRules.systems.isEmpty || !world.rulingRules.formables.isEmpty else { return }
        if world.rulings.countryCount != n { world.rulings.resize(countries: n) }
        var rng = world.beginRulingRandom(random)
        defer { world.endRulingRandom(rng) }

        var land = Array(repeating: false, count: n)
        for o in world.provinces.owner { if let o, o.index < n { land[o.index] = true } }
        for c in 0..<n where world.rulings.hadLand[c] && !land[c] {
            countryVanished(&world, CountryID(c), date: date)
        }
        world.rulings.hadLand = land

        let defs = world.rulingRules.systems
        for (i, def) in defs.enumerated() where i < world.rulings.systems.count && world.rulings.systems[i].active {
            behaviour(def.key, in: world)?.runMonthly(&world, date: date, random: &rng)
        }
        FormableSystem.runMonthly(&world, date: date, land: land)
    }

    public static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        guard !world.rulingRules.systems.isEmpty else { return }
        var rng = world.beginRulingRandom(random)
        defer { world.endRulingRandom(rng) }
        let defs = world.rulingRules.systems
        for (i, def) in defs.enumerated() where i < world.rulings.systems.count && world.rulings.systems[i].active {
            behaviour(def.key, in: world)?.runYearly(&world, date: date, random: &rng)
        }
    }

    /// Called by `CharacterSystem.succeed` after a new ruler takes the throne.
    static func rulerChanged(_ world: inout World, _ c: CountryID, old: CharacterID?, new: CharacterID, date: GameDate, random: GameRandom) {
        guard !world.rulingRules.systems.isEmpty, world.rulings.systems.count == world.rulingRules.systems.count else { return }
        var rng = world.beginRulingRandom(random)
        defer { world.endRulingRandom(rng) }
        let defs = world.rulingRules.systems
        for (i, def) in defs.enumerated() {
            let s = world.rulings.systems[i]
            guard s.active, s.isMember(c) || s.leader == c else { continue }
            behaviour(def.key, in: world)?.rulerChanged(&world, country: c, oldRuler: old, newRuler: new, date: date, random: &rng)
        }
    }

    static func countryVanished(_ world: inout World, _ c: CountryID, date: GameDate) {
        let defs = world.rulingRules.systems
        for (i, def) in defs.enumerated() where i < world.rulings.systems.count {
            let s = world.rulings.systems[i]
            guard s.isMember(c) || s.leader == c else { continue }
            if s.active {
                behaviour(def.key, in: world)?.countryVanished(&world, country: c, date: date)
            }
            if c.index < world.rulings.systems[i].roles.count {
                world.rulings.systems[i].roles[c.index] = []
            }
            if world.rulings.systems[i].leader == c {
                world.rulings.systems[i].leader = nil
            }
        }
    }

    static func countryFormed(_ world: inout World, _ c: CountryID, _ f: FormableDef, date: GameDate) {
        let defs = world.rulingRules.systems
        for (i, def) in defs.enumerated() where i < world.rulings.systems.count && world.rulings.systems[i].active {
            behaviour(def.key, in: world)?.countryFormed(&world, country: c, formable: f, date: date)
        }
    }

    // MARK: Effects

    /// Adds every system's role effects and Swift effects for `c`
    /// (called from `GovernmentSystem.refreshEffects`).
    static func addEffects(_ world: World, _ c: CountryID, into fx: inout Effects) {
        let defs = world.rulingRules.systems
        guard !defs.isEmpty, world.rulings.systems.count == defs.count else { return }
        for (i, def) in defs.enumerated() {
            let s = world.rulings.systems[i]
            guard s.active, s.isMember(c) || s.leader == c else { continue }
            for re in def.roleEffects where s.hasRole(c, re.role) {
                var k = 1.0
                if let v = re.scaleBy { k = (s.values[v] ?? 0) / max(re.scaleDivisor, 1e-9) }
                for m in fx.values.indices where m < re.values.count {
                    fx.values[m] += re.values[m] * k
                }
            }
            behaviour(def.key, in: world)?.addEffects(world, country: c, into: &fx)
        }
    }

    // MARK: Reading state

    public static func state(_ world: World, _ key: String) -> RulingSystemState? {
        guard let i = world.rulingRules.systemIndex(key), i < world.rulings.systems.count else { return nil }
        return world.rulings.systems[i]
    }

    public static func isActive(_ world: World, _ key: String) -> Bool { state(world, key)?.active ?? false }
    public static func isMember(_ world: World, _ key: String, _ c: CountryID) -> Bool { state(world, key)?.isMember(c) ?? false }
    public static func hasRole(_ world: World, _ key: String, _ c: CountryID, _ role: String) -> Bool { state(world, key)?.hasRole(c, role) ?? false }
    public static func leader(_ world: World, _ key: String) -> CountryID? { state(world, key)?.leader }
    /// Members in country order.
    public static func members(_ world: World, _ key: String) -> [CountryID] { state(world, key)?.members ?? [] }
    /// Holders of `role` in country order.
    public static func holders(_ world: World, _ key: String, _ role: String) -> [CountryID] { state(world, key)?.holders(role) ?? [] }
    public static func value(_ world: World, _ key: String, _ name: String) -> Double { state(world, key)?.values[name] ?? 0 }
    public static func countryValue(_ world: World, _ key: String, _ name: String, _ c: CountryID) -> Double {
        guard let a = state(world, key)?.countryValues[name], c.index >= 0, c.index < a.count else { return 0 }
        return a[c.index]
    }
    public static func hasFlag(_ world: World, _ key: String, _ flag: String) -> Bool { state(world, key)?.flags.contains(flag) ?? false }
    /// A fixed constant from the data file (`param name = value`).
    public static func param(_ world: World, _ key: String, _ name: String, default value: Double = 0) -> Double {
        world.rulingRules.system(key)?.param(name, default: value) ?? value
    }

    // MARK: Changing state

    /// Runs `body` on a system's state; false if the system is not in the data.
    @discardableResult
    public static func modify(_ world: inout World, _ key: String, _ body: (inout RulingSystemState) -> Void) -> Bool {
        guard let i = world.rulingRules.systemIndex(key), i < world.rulings.systems.count else { return false }
        body(&world.rulings.systems[i])
        return true
    }

    public static func join(_ world: inout World, _ key: String, _ c: CountryID) {
        addRole(&world, key, c, "member")
    }

    /// Takes away every role; a leader who leaves stops being leader.
    public static func leave(_ world: inout World, _ key: String, _ c: CountryID) {
        let changed = modify(&world, key) { s in
            guard c.index >= 0, c.index < s.roles.count else { return }
            s.roles[c.index] = []
            if s.leader == c { s.leader = nil }
        }
        if changed { refresh(&world, c) }
    }

    /// Gives a role (and membership). `leader` makes the country leader.
    public static func addRole(_ world: inout World, _ key: String, _ c: CountryID, _ role: String, date: GameDate? = nil) {
        if role == "leader" {
            setLeader(&world, key, c, date: date)
            return
        }
        let changed = modify(&world, key) { s in
            guard c.index >= 0, c.index < s.roles.count else { return }
            insert("member", into: &s.roles[c.index])
            insert(role, into: &s.roles[c.index])
        }
        if changed { refresh(&world, c) }
    }

    /// Takes one role away; taking `member` away is the same as `leave`.
    public static func removeRole(_ world: inout World, _ key: String, _ c: CountryID, _ role: String) {
        if role == "member" {
            leave(&world, key, c)
            return
        }
        let changed = modify(&world, key) { s in
            if role == "leader" {
                if s.leader == c { s.leader = nil }
                return
            }
            guard c.index >= 0, c.index < s.roles.count else { return }
            s.roles[c.index].removeAll { $0 == role }
        }
        if changed { refresh(&world, c) }
    }

    /// Makes `c` the leader (and a member); nil leaves the seat empty.
    public static func setLeader(_ world: inout World, _ key: String, _ c: CountryID?, date: GameDate? = nil) {
        let old = leader(world, key)
        modify(&world, key) { s in
            s.leader = c
            s.leaderSince = date ?? s.leaderSince
            if let c, c.index >= 0, c.index < s.roles.count {
                insert("member", into: &s.roles[c.index])
            }
        }
        if let old { refresh(&world, old) }
        if let c { refresh(&world, c) }
    }

    /// Sets a system number, kept within its data limits.
    public static func setValue(_ world: inout World, _ key: String, _ name: String, _ v: Double) {
        let limit = world.rulingRules.system(key)?.limits[name]
        modify(&world, key) { $0.values[name] = clamp(v, limit) }
    }

    public static func addValue(_ world: inout World, _ key: String, _ name: String, _ delta: Double) {
        setValue(&world, key, name, value(world, key, name) + delta)
    }

    /// Sets a per-country number (kept within the data limits of `name`).
    public static func setCountryValue(_ world: inout World, _ key: String, _ name: String, _ c: CountryID, _ v: Double) {
        let n = world.countries.count
        let limit = world.rulingRules.system(key)?.limits[name]
        modify(&world, key) { s in
            guard c.index >= 0, c.index < n else { return }
            var a = s.countryValues[name] ?? Array(repeating: 0, count: n)
            if a.count < n { a.append(contentsOf: repeatElement(0, count: n - a.count)) }
            a[c.index] = clamp(v, limit)
            s.countryValues[name] = a
        }
    }

    public static func addCountryValue(_ world: inout World, _ key: String, _ name: String, _ c: CountryID, _ delta: Double) {
        setCountryValue(&world, key, name, c, countryValue(world, key, name, c) + delta)
    }

    public static func setFlag(_ world: inout World, _ key: String, _ flag: String, _ on: Bool = true) {
        modify(&world, key) { s in
            if on { s.flags.insert(flag) } else { s.flags.remove(flag) }
        }
    }

    /// Ends a system for good (its hooks stop; members keep their roles for the record).
    public static func dissolve(_ world: inout World, _ key: String, date: GameDate) {
        let list = members(world, key)
        modify(&world, key) { $0.active = false }
        for c in list { refresh(&world, c) }
    }

    /// Re-sums a country's government effects (role effects changed).
    public static func refresh(_ world: inout World, _ c: CountryID) {
        if c.index >= 0, c.index < world.government.count {
            GovernmentSystem.refreshEffects(&world, c)
        }
    }

    // MARK: Elections

    /// Each voter votes for the candidate it scores highest (ties: the
    /// earlier candidate). With `jitter` > 0 each score gets a random bonus
    /// up to `jitter` (drawn in voter, then candidate order). The winner has
    /// the most votes; ties go to the higher total score, then the earlier
    /// candidate. Nil when there are no candidates.
    public static func elect(
        voters: [CountryID],
        candidates: [CountryID],
        jitter: Double = 0,
        random: inout GameRandom,
        score: (_ voter: CountryID, _ candidate: CountryID) -> Double
    ) -> RulingElection? {
        guard !candidates.isEmpty else { return nil }
        var votes = Array(repeating: 0, count: candidates.count)
        var totals = Array(repeating: 0.0, count: candidates.count)
        var ballots: [CountryID] = []
        ballots.reserveCapacity(voters.count)
        for v in voters {
            var best = 0
            var bestScore = -Double.infinity
            for (k, cand) in candidates.enumerated() {
                var sc = score(v, cand)
                if jitter > 0 { sc += random.unit() * jitter }
                totals[k] += sc
                if sc > bestScore {
                    bestScore = sc
                    best = k
                }
            }
            votes[best] += 1
            ballots.append(candidates[best])
        }
        var win = 0
        for k in 1..<candidates.count {
            if votes[k] > votes[win] || (votes[k] == votes[win] && totals[k] > totals[win]) {
                win = k
            }
        }
        return RulingElection(winner: candidates[win], votes: votes, ballots: ballots)
    }

    // MARK: Event and mission vocabulary

    /// Ruling and formable conditions for events, formables and (Phase 21)
    /// missions. Nil when `cond.kind` is not one of them.
    static func matches(_ cond: EventCondition, in world: World, for c: CountryID, date: GameDate) -> Bool? {
        switch cond.kind {
        case "ruling_active":
            return cond.str.map { isActive(world, $0) } ?? false
        case "ruling_member":
            return cond.str.map { isMember(world, $0, c) } ?? false
        case "not_ruling_member":
            return cond.str.map { !isMember(world, $0, c) } ?? true
        case "ruling_leader":
            return cond.str.map { leader(world, $0) == c } ?? false
        case "not_ruling_leader":
            return cond.str.map { leader(world, $0) != c } ?? true
        case "ruling_role":
            guard let p = pair(cond.str) else { return false }
            let (k, r) = p
            return hasRole(world, k, c, r)
        case "not_ruling_role":
            guard let p = pair(cond.str) else { return true }
            let (k, r) = p
            return !hasRole(world, k, c, r)
        case "ruling_value_min":
            guard let p = pair(cond.str) else { return false }
            let (k, v) = p
            return value(world, k, v) >= (cond.num ?? 0)
        case "ruling_value_max":
            guard let p = pair(cond.str) else { return false }
            let (k, v) = p
            return value(world, k, v) <= (cond.num ?? 0)
        case "ruling_country_value_min":
            guard let p = pair(cond.str) else { return false }
            let (k, v) = p
            return countryValue(world, k, v, c) >= (cond.num ?? 0)
        case "ruling_country_value_max":
            guard let p = pair(cond.str) else { return false }
            let (k, v) = p
            return countryValue(world, k, v, c) <= (cond.num ?? 0)
        case "ruling_flag":
            guard let p = pair(cond.str) else { return false }
            let (k, f) = p
            return hasFlag(world, k, f)
        case "not_ruling_flag":
            guard let p = pair(cond.str) else { return true }
            let (k, f) = p
            return !hasFlag(world, k, f)
        case "formed":
            return cond.str.map { id in world.rulings.formed.contains { $0.formable == id } } ?? false
        case "not_formed":
            return cond.str.map { id in !world.rulings.formed.contains { $0.formable == id } } ?? true
        case "is_formed":
            guard c.index < world.rulings.formedAs.count else { return false }
            return world.rulings.formedAs[c.index] == cond.str
        case "can_form":
            guard let id = cond.str else { return false }
            return FormableSystem.refusal(world, c, id, date: date) == nil
        default:
            return nil
        }
    }

    /// Ruling and formable effects. False when `eff.kind` is not one of them.
    static func execute(_ eff: EventEffect, on world: inout World, country c: CountryID, date: GameDate) -> Bool {
        switch eff.kind {
        case "form_nation":
            if let id = eff.str { FormableSystem.form(&world, c, id, date: date, force: true) }
        case "ruling_join":
            if let k = eff.str { join(&world, k, c) }
        case "ruling_leave":
            if let k = eff.str { leave(&world, k, c) }
        case "ruling_add_role":
            if let k = eff.str, let r = eff.str2 { addRole(&world, k, c, r, date: date) }
        case "ruling_remove_role":
            if let k = eff.str, let r = eff.str2 { removeRole(&world, k, c, r) }
        case "ruling_set_leader":
            if let k = eff.str { setLeader(&world, k, c, date: date) }
        case "ruling_value":
            if let k = eff.str, let v = eff.str2 { addValue(&world, k, v, eff.num ?? 0) }
        case "ruling_set_value":
            if let k = eff.str, let v = eff.str2 { setValue(&world, k, v, eff.num ?? 0) }
        case "ruling_country_value":
            if let k = eff.str, let v = eff.str2 { addCountryValue(&world, k, v, c, eff.num ?? 0) }
        case "ruling_set_flag":
            if let k = eff.str, let f = eff.str2 { setFlag(&world, k, f, true) }
        case "ruling_clear_flag":
            if let k = eff.str, let f = eff.str2 { setFlag(&world, k, f, false) }
        case "ruling_dissolve":
            if let k = eff.str { dissolve(&world, k, date: date) }
        default:
            return false
        }
        return true
    }

    /// Short tooltip text for the effects above; nil when not one of them
    /// (the outer optional) or when the effect has nothing to show.
    static func describe(_ eff: EventEffect, in world: World) -> String?? {
        func sysName(_ k: String?) -> String { k.flatMap { world.rulingRules.system($0)?.name } ?? (k ?? "") }
        switch eff.kind {
        case "form_nation":
            let name = eff.str.flatMap { world.rulingRules.formable($0)?.name } ?? (eff.str ?? "")
            return .some("Become \(name)")
        case "ruling_join":
            return .some("Join the \(sysName(eff.str))")
        case "ruling_leave":
            return .some("Leave the \(sysName(eff.str))")
        case "ruling_add_role":
            return .some("\(sysName(eff.str)): become \(label(eff.str2))")
        case "ruling_remove_role":
            return .some("\(sysName(eff.str)): no longer \(label(eff.str2))")
        case "ruling_set_leader":
            return .some("Take the lead of the \(sysName(eff.str))")
        case "ruling_value", "ruling_country_value":
            let v = eff.num ?? 0
            return .some("\(sysName(eff.str)) \(label(eff.str2)) " + String(format: "%+.0f", v))
        case "ruling_set_value":
            return .some("\(sysName(eff.str)) \(label(eff.str2)) set to " + String(format: "%.0f", eff.num ?? 0))
        case "ruling_dissolve":
            return .some("The \(sysName(eff.str)) comes to an end")
        case "ruling_set_flag", "ruling_clear_flag":
            return .some(nil)
        default:
            return nil
        }
    }

    // MARK: Helpers

    static func insert(_ role: String, into roles: inout [String]) {
        guard !roles.contains(role) else { return }
        roles.append(role)
        roles.sort()
    }

    static func clamp(_ v: Double, _ r: ClosedRange<Double>?) -> Double {
        guard let r else { return v }
        return min(max(v, r.lowerBound), r.upperBound)
    }

    /// Splits `"hre:elector"` into `("hre", "elector")`.
    static func pair(_ s: String?) -> (String, String)? {
        guard let s, let i = s.firstIndex(of: ":") else { return nil }
        return (String(s[..<i]), String(s[s.index(after: i)...]))
    }

    /// `free_city` → `free city`.
    static func label(_ s: String?) -> String {
        (s ?? "").replacingOccurrences(of: "_", with: " ")
    }
}

extension World {
    /// Dedicated random stream for ruling systems and formables, split off the
    /// main stream without drawing from it, so adding a system never shifts
    /// battles, plague or events elsewhere.
    mutating func beginRulingRandom(_ random: GameRandom) -> GameRandom {
        if !rulings.seeded {
            rulings.rngState = random.rawState ^ 0x2087_1453_C0DE_9A11
            rulings.seeded = true
        }
        return GameRandom(seed: rulings.rngState)
    }

    mutating func endRulingRandom(_ rng: GameRandom) {
        rulings.rngState = rng.rawState
    }
}
