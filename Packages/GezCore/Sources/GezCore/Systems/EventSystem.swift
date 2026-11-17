import Foundation

/// Per-month precomputed country/war cache so evaluating events across 266 countries stays O(1) per check.
struct EventEvalContext {
    let countryCount: Int
    var ownedCount: [Int]
    var totalDev: [Int]
    var hasCoast: [Bool]
    var atWar: [Bool]
    var warPairs: Set<UInt64>
    var capitalRegion: [String]

    init(_ world: World) {
        let C = world.countries.count
        self.countryCount = C
        self.ownedCount = Array(repeating: 0, count: C)
        self.totalDev = Array(repeating: 0, count: C)
        self.hasCoast = Array(repeating: false, count: C)
        self.atWar = Array(repeating: false, count: C)
        self.warPairs = []
        self.capitalRegion = Array(repeating: "", count: C)

        for p in 0..<world.provinces.count {
            guard let owner = world.provinces.owner[p], owner.index < C else { continue }
            let ci = owner.index
            ownedCount[ci] += 1
            totalDev[ci] += world.provinces.development[p]
            if world.hasSeaAccess(ProvinceID(p)) {
                hasCoast[ci] = true
            }
        }
        for c in 0..<C {
            if let cap = world.countries.capital[c], cap.index < world.provinces.count {
                capitalRegion[c] = world.regionName(of: cap)
            }
        }
        for war in world.diplomacy.wars {
            for a in war.attackers where a.index < C {
                atWar[a.index] = true
                for d in war.defenders where d.index < C {
                    warPairs.insert(Self.pairKey(a, d))
                }
            }
            for d in war.defenders where d.index < C {
                atWar[d.index] = true
            }
        }
    }

    @inline(__always)
    static func pairKey(_ a: CountryID, _ b: CountryID) -> UInt64 {
        let lo = UInt64(min(a.index, b.index))
        let hi = UInt64(max(a.index, b.index))
        return (lo << 32) | hi
    }

    func isAtWar(_ a: CountryID, _ b: CountryID) -> Bool {
        warPairs.contains(Self.pairKey(a, b))
    }
}

/// Monthly evaluation, condition checking, effect execution, AI weighting, and chronicle pop-ups (Phase 14).
public enum EventSystem {
    public static let maxPendingPerCountry = 6

    // MARK: - Public Condition & Effect API (reusable by missions)

    /// Returns `true` if every condition in `conditions` holds for `country` on `date`.
    public static func evaluate(
        _ conditions: [EventCondition],
        in world: World,
        for country: CountryID,
        date: GameDate
    ) -> Bool {
        evaluate(conditions, in: world, for: country, date: date, ctx: nil)
    }

    static func evaluate(
        _ conditions: [EventCondition],
        in world: World,
        for country: CountryID,
        date: GameDate,
        ctx: EventEvalContext?
    ) -> Bool {
        guard country.index >= 0, country.index < world.countries.count else { return false }
        for cond in conditions {
            if !matches(cond, in: world, for: country, date: date, ctx: ctx) {
                return false
            }
        }
        return true
    }

    /// Executes `effects` on `world` for `country`.
    public static func apply(
        _ effects: [EventEffect],
        to world: inout World,
        country: CountryID,
        date: GameDate,
        contextProvince: ProvinceID? = nil
    ) {
        var rng = world.beginEventRandom(GameRandom(seed: UInt64(date.ordinal) &+ 1))
        defer { world.endEventRandom(rng) }
        apply(effects, to: &world, country: country, date: date, contextProvince: contextProvince, rng: &rng)
    }

    static func apply(
        _ effects: [EventEffect],
        to world: inout World,
        country: CountryID,
        date: GameDate,
        contextProvince: ProvinceID?,
        rng: inout GameRandom
    ) {
        guard country.index >= 0, country.index < world.countries.count else { return }
        world.events.resize(countries: world.countries.count)
        for eff in effects {
            execute(eff, on: &world, country: country, date: date, contextProvince: contextProvince, rng: &rng)
        }
    }

    // MARK: - Monthly Tick

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let C = world.countries.count
        guard C > 0 else { return }
        world.events.resize(countries: C)

        var rng = world.beginEventRandom(random)
        defer { world.endEventRandom(rng) }

        // 1. Prune expired event modifiers and granted CBs.
        var dirtyModifierCountries: Set<CountryID> = []
        world.events.activeModifiers.removeAll { mod in
            if mod.expiry <= date {
                dirtyModifierCountries.insert(mod.country)
                return true
            }
            return false
        }
        for cid in dirtyModifierCountries where cid.index < world.government.count {
            GovernmentSystem.refreshEffects(&world, cid)
        }
        world.events.grantedCBs.removeAll { $0.expiry <= date }

        // 2. Resolve any pending AI events queued earlier in the tick (e.g. chronicle events).
        resolvePendingAI(&world, date: date, rng: &rng)

        guard !world.eventRules.events.isEmpty else { return }

        let events = world.eventRules.events
        let activeGlobals = world.eventRules.globalCandidateIndices.filter { idx in
            let ev = events[idx]
            if ev.fireOnce && world.events.firedGlobal.contains(ev.id) { return false }
            if let from = ev.dateFrom, date < from { return false }
            if let to = ev.dateTo, date > to { return false }
            if let exact = ev.exactDate, date < exact { return false }
            return true
        }
        let hasActiveCountryEvent = (0..<C).contains { c in
            c < world.eventRules.eventsByCountry.count && world.eventRules.eventsByCountry[c].contains { idx in
                let ev = events[idx]
                if ev.fireOnce && world.events.firedGlobal.contains(ev.id) { return false }
                if let from = ev.dateFrom, date < from { return false }
                if let to = ev.dateTo, date > to { return false }
                if let exact = ev.exactDate, date < exact { return false }
                return true
            }
        }
        guard !activeGlobals.isEmpty || hasActiveCountryEvent else { return }

        // 3. Build single-pass context and check monthly candidate events.
        let ctx = EventEvalContext(world)

        for c in 0..<C {
            guard ctx.ownedCount[c] > 0 else { continue }
            let cid = CountryID(c)

            // Evaluate country-specific events first, then pre-filtered global candidates.
            if c < world.eventRules.eventsByCountry.count {
                for evIdx in world.eventRules.eventsByCountry[c] {
                    tryCandidate(events[evIdx], for: cid, world: &world, date: date, ctx: ctx, rng: &rng)
                }
            }
            for evIdx in activeGlobals {
                tryCandidate(events[evIdx], for: cid, world: &world, date: date, ctx: ctx, rng: &rng)
            }
        }
    }

    // MARK: - Triggering & Resolution

    /// Triggers an event directly (for system/chronicle events or scripts).
    @discardableResult
    public static func trigger(
        _ world: inout World,
        eventID: String,
        for country: CountryID,
        date: GameDate,
        tokens: [String: String] = [:],
        contextProvince: ProvinceID? = nil
    ) -> Bool {
        guard country.index >= 0, country.index < world.countries.count,
              let ev = world.eventRules.event(id: eventID) else {
            return false
        }
        world.events.resize(countries: world.countries.count)
        if ev.fireOnce && world.events.firedGlobal.contains(ev.id) { return false }
        if ev.perCountry && world.events.firedPerCountry[country.index].contains(ev.id) { return false }

        if ev.fireOnce {
            world.events.firedGlobal.insert(ev.id)
        }
        if ev.perCountry || ev.fireOnce {
            world.events.firedPerCountry[country.index].insert(ev.id)
        }

        let pending = makePending(ev, for: country, date: date, world: &world, tokens: tokens, contextProvince: contextProvince)
        world.events.firedTotal += 1
        world.events.firedByCategory[ev.category.rawValue, default: 0] += 1

        if world.humanCountries.contains(country) {
            enqueueHumanPending(&world, pending: pending, date: date)
        } else {
            // Queue for EventSystem.runMonthly or resolve immediately if already mid-month.
            var rng = world.beginEventRandom(GameRandom(seed: UInt64(date.ordinal) &+ 7))
            resolvePending(pending, in: &world, optionIndex: chooseAIOption(for: pending, rng: &rng), date: date, major: ev.major, rng: &rng)
            world.endEventRandom(rng)
        }
        return true
    }

    /// Resolves a player's pending event choice by `instanceID` and `optionIndex`.
    @discardableResult
    public static func resolvePendingEvent(
        _ world: inout World,
        instanceID: Int,
        optionIndex: Int,
        date: GameDate
    ) -> Bool {
        guard let idx = world.events.pending.firstIndex(where: { $0.instanceID == instanceID }) else {
            return false
        }
        let pending = world.events.pending.remove(at: idx)
        let chosen = min(max(0, optionIndex), max(0, pending.options.count - 1))
        let major = world.eventRules.event(id: pending.eventID)?.major ?? false
        var rng = world.beginEventRandom(GameRandom(seed: UInt64(date.ordinal) &+ 13))
        resolvePending(pending, in: &world, optionIndex: chosen, date: date, major: major, rng: &rng)
        world.endEventRandom(rng)
        return true
    }

    /// Picks an AI option index weighted by situation-adjusted `aiWeight`.
    public static func chooseAIOption(
        for ev: EventDef,
        in world: World,
        country: CountryID,
        date: GameDate,
        rng: inout GameRandom
    ) -> Int {
        let weights = ev.options.map { effectiveAIWeight($0, in: world, for: country, date: date, ctx: nil) }
        return pickWeightedIndex(weights, rng: &rng)
    }

    static func chooseAIOption(for pending: PendingEvent, rng: inout GameRandom) -> Int {
        let weights = pending.options.map(\.aiWeight)
        return pickWeightedIndex(weights, rng: &rng)
    }

    static func pickWeightedIndex(_ weights: [Double], rng: inout GameRandom) -> Int {
        guard !weights.isEmpty else { return 0 }
        let clean = weights.map { max(0.0, $0) }
        let total = clean.reduce(0, +)
        guard total > 0 else { return 0 }
        var roll = rng.unit() * total
        for (i, w) in clean.enumerated() {
            if roll < w || i == clean.count - 1 {
                return i
            }
            roll -= w
        }
        return 0
    }

    // MARK: - Candidate Dispatch

    private static func tryCandidate(
        _ ev: EventDef,
        for cid: CountryID,
        world: inout World,
        date: GameDate,
        ctx: EventEvalContext,
        rng: inout GameRandom
    ) {
        if ev.fireOnce && world.events.firedGlobal.contains(ev.id) { return }
        if ev.perCountry && world.events.firedPerCountry[cid.index].contains(ev.id) { return }
        if let from = ev.dateFrom, date < from { return }
        if let to = ev.dateTo, date > to { return }
        if let exact = ev.exactDate, date < exact { return }
        if world.events.pending.contains(where: { $0.country == cid && $0.eventID == ev.id }) { return }
        guard evaluate(ev.trigger, in: world, for: cid, date: date, ctx: ctx) else { return }

        let shouldFire: Bool
        if ev.exactDate != nil || ev.mtth <= 0 {
            shouldFire = true
        } else {
            var mult = 1.0
            for m in ev.mtthModifiers {
                if matches(m.condition, in: world, for: cid, date: date, ctx: ctx) {
                    mult *= m.factor
                }
            }
            let effectiveMTTH = max(1.0, ev.mtth * mult)
            let prob = 1.0 - pow(0.5, 1.0 / effectiveMTTH)
            shouldFire = rng.unit() < prob
        }
        guard shouldFire else { return }

        if ev.fireOnce {
            world.events.firedGlobal.insert(ev.id)
        }
        if ev.perCountry || ev.fireOnce {
            world.events.firedPerCountry[cid.index].insert(ev.id)
        }

        let pending = makePending(ev, for: cid, date: date, world: &world, tokens: [:], contextProvince: nil, ctx: ctx)
        world.events.firedTotal += 1
        world.events.firedByCategory[ev.category.rawValue, default: 0] += 1

        if world.humanCountries.contains(cid) {
            enqueueHumanPending(&world, pending: pending, date: date)
        } else {
            let optIdx = chooseAIOption(for: pending, rng: &rng)
            resolvePending(pending, in: &world, optionIndex: optIdx, date: date, major: ev.major, rng: &rng)
        }
    }

    private static func resolvePendingAI(_ world: inout World, date: GameDate, rng: inout GameRandom) {
        var remaining: [PendingEvent] = []
        for p in world.events.pending {
            if world.humanCountries.contains(p.country) {
                remaining.append(p)
            } else {
                let optIdx = chooseAIOption(for: p, rng: &rng)
                let major = world.eventRules.event(id: p.eventID)?.major ?? false
                resolvePending(p, in: &world, optionIndex: optIdx, date: date, major: major, rng: &rng)
            }
        }
        world.events.pending = remaining
    }

    private static func enqueueHumanPending(_ world: inout World, pending: PendingEvent, date: GameDate) {
        let countryQueue = world.events.pending.filter { $0.country == pending.country }
        if countryQueue.count >= maxPendingPerCountry, let oldest = countryQueue.first {
            // Auto-resolve oldest unanswered event so queue cannot grow unbounded when auto-pause is off.
            _ = resolvePendingEvent(&world, instanceID: oldest.instanceID, optionIndex: 0, date: date)
        }
        world.events.pending.append(pending)
    }

    private static func resolvePending(
        _ pending: PendingEvent,
        in world: inout World,
        optionIndex: Int,
        date: GameDate,
        major: Bool,
        rng: inout GameRandom
    ) {
        guard !pending.options.isEmpty else { return }
        let safeIdx = min(max(0, optionIndex), pending.options.count - 1)
        let opt = pending.options[safeIdx]
        apply(opt.effects, to: &world, country: pending.country, date: date, contextProvince: pending.contextProvince, rng: &rng)
        world.events.recordRecent(RecentEventEntry(
            date: date,
            country: pending.country,
            eventID: pending.eventID,
            title: pending.title,
            category: pending.category,
            chosenLabel: opt.label,
            effectSummary: opt.tooltip,
            major: major
        ))
        if major {
            world.people.record(date, pending.country, "\(pending.title): \(opt.label).")
        }
    }

    // MARK: - Pending Construction & Tooltips

    private static func makePending(
        _ ev: EventDef,
        for country: CountryID,
        date: GameDate,
        world: inout World,
        tokens: [String: String],
        contextProvince: ProvinceID?,
        ctx: EventEvalContext? = nil
    ) -> PendingEvent {
        let instanceID = world.events.nextInstanceID
        world.events.nextInstanceID += 1
        let resolvedTitle = substituteTokens(ev.title, world: world, country: country, tokens: tokens, contextProvince: contextProvince)
        let resolvedText = substituteTokens(ev.text, world: world, country: country, tokens: tokens, contextProvince: contextProvince)
        let opts = ev.options.map { opt in
            PendingEventOption(
                label: substituteTokens(opt.label, world: world, country: country, tokens: tokens, contextProvince: contextProvince),
                tooltip: effectSummary(for: opt.effects, in: world, country: country, contextProvince: contextProvince),
                aiWeight: effectiveAIWeight(opt, in: world, for: country, date: date, ctx: ctx),
                effects: opt.effects
            )
        }
        return PendingEvent(
            instanceID: instanceID,
            eventID: ev.id,
            country: country,
            date: date,
            title: resolvedTitle,
            text: resolvedText,
            category: ev.category,
            contextProvince: contextProvince,
            options: opts
        )
    }

    private static func effectiveAIWeight(
        _ opt: EventOptionDef,
        in world: World,
        for country: CountryID,
        date: GameDate,
        ctx: EventEvalContext?
    ) -> Double {
        var w = opt.aiWeight
        for m in opt.aiModifiers {
            if matches(m.condition, in: world, for: country, date: date, ctx: ctx) {
                switch m.op {
                case .mul: w *= m.value
                case .add: w += m.value
                }
            }
        }
        if AIGoalSystem.isFreeMode(for: country, in: world) && w > 0 {
            let traits = AIGoalSystem.traitProfile(for: country, in: world)
            w = w * 0.55 + 22.5
            for eff in opt.effects {
                switch eff.kind {
                case "manpower", "spawn_units", "add_cb", "add_claim":
                    w *= (0.7 + 0.3 * traits.warMultiplier)
                case "ducats", "province_dev":
                    w *= (0.7 + 0.3 * traits.economyWeight)
                case "change_opinion", "change_opinion_both":
                    w *= (0.7 + 0.3 * traits.diplomacyWeight)
                default:
                    break
                }
            }
        }
        return max(0.0, w)
    }

    private static func substituteTokens(
        _ raw: String,
        world: World,
        country: CountryID,
        tokens: [String: String],
        contextProvince: ProvinceID?
    ) -> String {
        var s = raw
        if s.contains("{country}") {
            s = s.replacingOccurrences(of: "{country}", with: world.countries.name[country.index])
        }
        if s.contains("{capital}") {
            let capName = world.countries.capital[country.index].map { world.provinces.name[$0.index] } ?? "the capital"
            s = s.replacingOccurrences(of: "{capital}", with: capName)
        }
        if s.contains("{ruler}") {
            let rName = world.countries.ruler[country.index].map { world.people.characters.fullName($0) } ?? "the Ruler"
            s = s.replacingOccurrences(of: "{ruler}", with: rName)
        }
        if s.contains("{heir}") {
            let hName = world.countries.heir[country.index].map { world.people.characters.fullName($0) } ?? "the Heir"
            s = s.replacingOccurrences(of: "{heir}", with: hName)
        }
        if s.contains("{province}") {
            let pName = tokens["province"] ?? contextProvince.map { world.provinces.name[$0.index] } ?? "the province"
            s = s.replacingOccurrences(of: "{province}", with: pName)
        }
        for (k, v) in tokens {
            s = s.replacingOccurrences(of: "{\(k)}", with: v)
        }
        return s
    }

    /// Concise, human-readable summary of option effects for tooltips and recent-events log.
    public static func effectSummary(
        for effects: [EventEffect],
        in world: World,
        country: CountryID,
        contextProvince: ProvinceID? = nil
    ) -> String {
        var parts: [String] = []
        for eff in effects {
            if let s = describeEffect(eff, in: world, country: country, contextProvince: contextProvince) {
                parts.append(s)
            }
        }
        return parts.isEmpty ? "No direct realm change" : parts.joined(separator: " · ")
    }

    private static func describeEffect(
        _ eff: EventEffect,
        in world: World,
        country: CountryID,
        contextProvince: ProvinceID?
    ) -> String? {
        switch eff.kind {
        case "ducats":
            let v = Int((eff.num ?? 0).rounded())
            return String(format: "%+d ducats", v)
        case "months_income":
            let m = eff.num ?? 0
            return String(format: "%+.1f mo income", m)
        case "stability":
            return String(format: "%+d stability", eff.int ?? 0)
        case "prestige":
            return String(format: "%+.0f prestige", eff.num ?? 0)
        case "estate_loyalty":
            let est = eff.str ?? "estate"
            let name = world.government.rules.estate(forKey: est).map { world.government.rules.estates[$0.index].name } ?? est.capitalized
            return String(format: "%@ loyalty %+.0f", name, eff.num ?? 0)
        case "unrest":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            return String(format: "%+.0f unrest in %@", eff.num ?? 0, pname)
        case "pops_convert":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            let toRel = Religion(rawValue: eff.str2 ?? "")?.displayName ?? (eff.str2 ?? "")
            let pct = Int(((eff.num ?? 0) * 100).rounded())
            return "\(pct)% of \(pname) convert to \(toRel)"
        case "add_claim":
            return "Claim on \(eff.str ?? "province")"
        case "add_core":
            return "Core on \(eff.str ?? "province")"
        case "add_cb":
            let cname = eff.str.flatMap { world.countries.id(forTag: $0) }.map { world.countries.name[$0.index] } ?? (eff.str ?? "")
            return "Casus Belli vs \(cname)"
        case "declare_war":
            let cname = eff.str.flatMap { world.countries.id(forTag: $0) }.map { world.countries.name[$0.index] } ?? (eff.str ?? "")
            return "War with \(cname)"
        case "spawn_units":
            let uname = world.military.unitTypes.first(where: { $0.key == eff.str })?.name ?? (eff.str ?? "Regiments")
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            return "+\(eff.int2 ?? 1) \(uname) in \(pname)"
        case "add_modifier":
            let mname = eff.str2 ?? (eff.str ?? "Modifier")
            let months = eff.int ?? 12
            let statsText = (eff.mods ?? [:]).sorted(by: { $0.key < $1.key }).map { k, v in
                if let m = Modifier(key: k) {
                    if m.isPoints || m.isMood {
                        return "\(m.displayName) \(String(format: "%+.0f", m.isMood ? v * 100 : v))"
                    }
                    return "\(m.displayName) \(String(format: "%+.0f%%", v * 100))"
                }
                return "\(k) \(v)"
            }.joined(separator: ", ")
            return "\(mname) (\(months) mo: \(statsText))"
        case "change_opinion", "change_opinion_both":
            let cname = eff.str.flatMap { world.countries.id(forTag: $0) }.map { world.countries.name[$0.index] } ?? (eff.str ?? "")
            return String(format: "%+d opinion with %@", eff.int ?? 0, cname)
        case "change_religion":
            let rname = Religion(rawValue: eff.str ?? "")?.displayName ?? (eff.str ?? "")
            return "State religion becomes \(rname)"
        case "accept_culture":
            let cid = world.cultures.id(forKey: eff.str ?? "")
            let cname = cid.map { world.cultures.name[$0.index] } ?? (eff.str ?? "")
            return "Accept \(cname) culture"
        case "manpower":
            return String(format: "%+.0f manpower", eff.num ?? 0)
        case "sailors":
            return String(format: "%+.0f sailors", eff.num ?? 0)
        case "tech_progress":
            let tr = TechTrack(key: eff.str ?? "")?.shortName ?? (eff.str ?? "")
            return String(format: "%+.0f %@ research", eff.num ?? 0, tr)
        case "ruler_skill":
            return String(format: "%+d ruler %@", eff.int ?? 0, (eff.str ?? "").capitalized)
        case "add_ruler_trait":
            return "Ruler gains \((eff.str ?? "").capitalized) trait"
        case "kill_character":
            return "Character dies"
        case "add_vassal_favour":
            return String(format: "%+d vassal favour", eff.int ?? 0)
        case "province_dev":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            return String(format: "%+d development in %@", eff.int2 ?? 0, pname)
        case "province_fort":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            return String(format: "%+d fort level in %@", eff.int2 ?? 0, pname)
        case "institution_spread":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            let iname = world.techRules.institutions.first(where: { $0.key == eff.str })?.name ?? (eff.str ?? "")
            return "\(iname) spread +\(Int(((eff.num ?? 0) * 100).rounded()))% in \(pname)"
        case "spawn_reformation":
            let pname = targetName(eff.target, pidx: eff.int, in: world, country: country, contextProvince: contextProvince)
            return "Centre of Reformation in \(pname)"
        case "advance_safaviyya":
            return "Safaviyya movement advances"
        case "cede_province":
            let pname = (eff.int ?? -1) >= 0 && (eff.int ?? -1) < world.provinces.count ? world.provinces.name[eff.int!] : "province"
            return "Cede \(pname) to \(eff.str ?? "")"
        case "set_flag", "clear_flag", "set_global_flag", "clear_global_flag":
            return nil
        default:
            return nil
        }
    }

    private static func targetName(
        _ target: String?,
        pidx: Int?,
        in world: World,
        country: CountryID,
        contextProvince: ProvinceID?
    ) -> String {
        switch target {
        case "all":
            return "all provinces"
        case "capital":
            return world.countries.capital[country.index].map { world.provinces.name[$0.index] } ?? "capital"
        case "context":
            return contextProvince.map { world.provinces.name[$0.index] } ?? "province"
        default:
            if let pidx, pidx >= 0, pidx < world.provinces.count {
                return world.provinces.name[pidx]
            }
            return contextProvince.map { world.provinces.name[$0.index] } ?? "province"
        }
    }

    // MARK: - Condition Matching

    private static func matches(
        _ cond: EventCondition,
        in world: World,
        for country: CountryID,
        date: GameDate,
        ctx: EventEvalContext?
    ) -> Bool {
        let c = country.index
        switch cond.kind {
        case "tag":
            return world.countries.tag[c] == cond.str
        case "not_tag":
            return world.countries.tag[c] != cond.str
        case "exists":
            guard let t = cond.str.flatMap({ world.countries.id(forTag: $0) }) else { return false }
            if let ctx { return ctx.ownedCount[t.index] > 0 }
            return world.provinces.owner.contains(t)
        case "not_exists":
            guard let t = cond.str.flatMap({ world.countries.id(forTag: $0) }) else { return true }
            if let ctx { return ctx.ownedCount[t.index] == 0 }
            return !world.provinces.owner.contains(t)
        case "owns":
            guard let p = cond.int, p >= 0, p < world.provinces.count else { return false }
            return world.provinces.owner[p] == country
        case "not_owns":
            guard let p = cond.int, p >= 0, p < world.provinces.count else { return true }
            return world.provinces.owner[p] != country
        case "controls":
            guard let p = cond.int, p >= 0, p < world.provinces.count else { return false }
            return world.provinces.controller(of: ProvinceID(p)) == country
        case "province_owner":
            guard let p = cond.int, p >= 0, p < world.provinces.count,
                  let t = cond.str.flatMap({ world.countries.id(forTag: $0) }) else { return false }
            return world.provinces.owner[p] == t
        case "province_religion":
            guard let p = cond.int, p >= 0, p < world.provinces.count,
                  let rel = cond.str.flatMap({ Religion(rawValue: $0) }) else { return false }
            return world.provinces.religion[p] == rel
        case "at_war_with":
            guard let t = cond.str.flatMap({ world.countries.id(forTag: $0) }) else { return false }
            if let ctx { return ctx.isAtWar(country, t) }
            return world.diplomacy.isAtWar(country, t)
        case "at_war":
            let warNow = ctx?.atWar[c] ?? !world.diplomacy.activeWars(for: country).isEmpty
            return warNow == (cond.bool ?? true)
        case "religion":
            return world.countries.religion[c].rawValue == cond.str
        case "not_religion":
            return world.countries.religion[c].rawValue != cond.str
        case "religion_family":
            return world.countries.religion[c].family.rawValue == cond.str
        case "culture":
            let cid = world.countries.primaryCulture[c]
            return cid.index < world.cultures.count && world.cultures.key[cid.index] == cond.str
        case "culture_family":
            let cid = world.countries.primaryCulture[c]
            return cid.index < world.cultures.count && world.cultures.family[cid.index] == cond.str
        case "government":
            return world.countries.government[c].rawValue == cond.str
        case "is_subject":
            return (world.countries.overlord[c] != nil) == (cond.bool ?? true)
        case "is_vassal_of":
            guard let ov = cond.str.flatMap({ world.countries.id(forTag: $0) }) else { return false }
            return world.countries.overlord[c] == ov
        case "adm_tech":
            return world.tech.level(country, .administrative) >= (cond.int ?? 1)
        case "dip_tech":
            return world.tech.level(country, .diplomatic) >= (cond.int ?? 1)
        case "mil_tech":
            return world.tech.level(country, .military) >= (cond.int ?? 1)
        case "institution_spawned":
            guard let idx = world.techRules.institutions.firstIndex(where: { $0.key == cond.str }) else { return false }
            return idx < world.tech.institutionSpawned.count && world.tech.institutionSpawned[idx]
        case "institution_embraced":
            guard let idx = world.techRules.institutions.firstIndex(where: { $0.key == cond.str }) else { return false }
            return world.tech.hasEmbraced(country, institution: idx)
        case "institution_present":
            guard let idx = world.techRules.institutions.firstIndex(where: { $0.key == cond.str }) else { return false }
            if world.tech.hasEmbraced(country, institution: idx) { return true }
            return InstitutionSystem.spreadShare(world, for: country, institution: idx) > 0
        case "stability_min":
            return c < world.government.stability.count && world.government.stability[c] >= (cond.int ?? -3)
        case "stability_max":
            return c < world.government.stability.count && world.government.stability[c] <= (cond.int ?? 3)
        case "treasury_min":
            return world.countries.treasury[c] >= (cond.num ?? 0)
        case "treasury_max":
            return world.countries.treasury[c] <= (cond.num ?? 0)
        case "development_min":
            let dev = ctx?.totalDev[c] ?? world.totalDevelopment(of: country)
            return dev >= (cond.int ?? 0)
        case "provinces_min":
            let cnt = ctx?.ownedCount[c] ?? world.provinces(ownedBy: country).count
            return cnt >= (cond.int ?? 0)
        case "is_coastal":
            let coastal: Bool
            if let ctx {
                coastal = ctx.hasCoast[c]
            } else {
                coastal = (0..<world.provinces.count).contains {
                    world.provinces.owner[$0] == country && world.hasSeaAccess(ProvinceID($0))
                }
            }
            return coastal == (cond.bool ?? true)
        case "capital_region":
            let reg: String
            if let ctx {
                reg = ctx.capitalRegion[c]
            } else if let cap = world.countries.capital[c] {
                reg = world.regionName(of: cap)
            } else {
                reg = ""
            }
            return reg == cond.str
        case "ruler_alive":
            guard let r = world.countries.ruler[c],
                  let target = cond.str.flatMap({ world.people.characters.id(forKey: $0) }) else { return false }
            return r == target && world.people.characters.isAlive(r)
        case "not_ruler_alive":
            guard let target = cond.str.flatMap({ world.people.characters.id(forKey: $0) }) else { return true }
            if !world.people.characters.isAlive(target) { return true }
            return world.countries.ruler[c] != target
        case "character_alive":
            guard let target = cond.str.flatMap({ world.people.characters.id(forKey: $0) }) else { return false }
            return world.people.characters.isAlive(target)
        case "ruler_trait":
            guard let r = world.countries.ruler[c],
                  let tid = cond.str.flatMap({ world.people.traits.id(forKey: $0) }) else { return false }
            return world.people.characters.traits[r.index].contains(tid)
        case "ruler_skill_min":
            guard let r = world.countries.ruler[c],
                  let skill = skillFromKey(cond.str) else {
                return false
            }
            return world.people.characters.skill(r, skill) >= (cond.int ?? 0)
        case "has_flag":
            return cond.str.map { world.events.hasFlag($0, for: country) } ?? false
        case "not_flag":
            return cond.str.map { !world.events.hasFlag($0, for: country) } ?? true
        case "global_flag":
            return cond.str.map { world.events.globalFlags.contains($0) } ?? false
        case "not_global_flag":
            return cond.str.map { !world.events.globalFlags.contains($0) } ?? true
        case "reformation_started":
            return world.faith.reformationStarted == (cond.bool ?? true)
        case "safaviyya_phase":
            return world.faith.safaviyyaPhase.rawValue == cond.str
        case "year_min":
            return date.year >= (cond.int ?? 1453)
        case "year_max":
            return date.year <= (cond.int ?? 9999)
        default:
            return false
        }
    }

    private static func skillFromKey(_ key: String?) -> Skill? {
        switch key {
        case "diplomacy": return .diplomacy
        case "martial": return .martial
        case "stewardship": return .stewardship
        case "intrigue": return .intrigue
        case "learning": return .learning
        default: return nil
        }
    }

    // MARK: - Effect Execution

    private static func execute(
        _ eff: EventEffect,
        on world: inout World,
        country: CountryID,
        date: GameDate,
        contextProvince: ProvinceID?,
        rng: inout GameRandom
    ) {
        let c = country.index
        switch eff.kind {
        case "ducats":
            world.countries.treasury[c] += (eff.num ?? 0)

        case "months_income":
            let monthly = max(8.0, world.countries.lastMonthlyIncome[c])
            world.countries.treasury[c] += monthly * (eff.num ?? 0)

        case "stability":
            if c < world.government.count {
                GovernmentSystem.changeStability(&world, country, by: eff.int ?? 0)
            }

        case "prestige":
            world.countries.prestige[c] = max(-100.0, min(100.0, world.countries.prestige[c] + (eff.num ?? 0)))

        case "estate_loyalty":
            if let key = eff.str,
               let eid = world.government.rules.estate(forKey: key),
               c < world.government.loyalty.count,
               eid.index < world.government.loyalty[c].count {
                let cur = world.government.loyalty[c][eid.index]
                world.government.loyalty[c][eid.index] = max(0.0, min(100.0, cur + (eff.num ?? 0)))
                GovernmentSystem.refreshEffects(&world, country)
            }

        case "unrest":
            let delta = eff.num ?? 0
            let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
            world.unrest.resize(provinces: world.provinces.count, countries: world.countries.count)
            for pid in targets {
                let p = pid.index
                // Negative calm raises unrest; positive calm calms unrest. Both fade at 0.5/month in UnrestSystem.
                world.unrest.calm[p] = max(-50.0, min(50.0, world.unrest.calm[p] - delta))
                world.unrest.unrest[p] = max(0.0, min(100.0, world.unrest.unrest[p] + delta))
            }

        case "pops_convert":
            guard let toRel = eff.str2.flatMap({ Religion(rawValue: $0) }) else { break }
            let frac = eff.num ?? 0
            let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
            guard !targets.isEmpty, frac > 0 else { break }
            var pending: [PopTable.Row] = []
            var anyZero = false
            for pid in targets {
                if eff.str == "*" {
                    for rel in Religion.allCases where rel != toRel {
                        MovementSystem.shiftReligion(in: pid, from: rel, to: toRel, fraction: frac, world: &world, pending: &pending, anyZero: &anyZero)
                    }
                } else if let fromRel = eff.str.flatMap({ Religion(rawValue: $0) }) {
                    MovementSystem.shiftReligion(in: pid, from: fromRel, to: toRel, fraction: frac, world: &world, pending: &pending, anyZero: &anyZero)
                }
            }
            if !pending.isEmpty || anyZero {
                world.pops.rebuild(provinceCount: world.provinces.count, extraRows: pending)
            }
            world.refreshProvinceSummaries()

        case "add_claim":
            if let p = eff.int, p >= 0, p < world.provinces.count {
                world.provinces.claims[p].insert(country)
            }

        case "add_core":
            if let p = eff.int, p >= 0, p < world.provinces.count {
                world.provinces.cores[p].insert(country)
            }

        case "add_cb":
            if let tag = eff.str,
               let target = world.countries.id(forTag: tag),
               let cb = eff.str2.flatMap({ CasusBelli(rawValue: $0) }) {
                let months = max(1, eff.int ?? 60)
                let expiry = date.adding(days: months * 30)
                world.events.grantedCBs.removeAll { $0.country == country && $0.target == target && $0.casusBelli == cb }
                world.events.grantedCBs.append(GrantedEventCB(country: country, target: target, casusBelli: cb, expiry: expiry))
            }

        case "declare_war":
            if let tag = eff.str,
               let target = world.countries.id(forTag: tag),
               let cb = eff.str2.flatMap({ CasusBelli(rawValue: $0) }),
               !world.provinces(ownedBy: target).isEmpty {
                let goal: WarGoal
                if let cap = world.countries.capital[target.index], cb != .holyWar && cb != .tribute && cb != .coalition && cb != .noCB {
                    goal = .conquerProvince(cap)
                } else {
                    goal = .superiority
                }
                _ = world.declareWar(attacker: country, defender: target, casusBelli: cb, warGoal: goal, breakTruce: false, date: date)
            }

        case "spawn_units":
            let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
            if let pid = targets.first ?? world.countries.capital[c] ?? world.provinces(ownedBy: country).first,
               let ut = world.military.unitTypes.first(where: { $0.key == eff.str }) {
                let count = max(1, min(20, eff.int2 ?? 1))
                let regs = (0..<count).map { _ in
                    Regiment(type: ut.id, origin: .professional, men: ut.maxMen, morale: ut.morale, homeProvince: pid)
                }
                if let existing = world.military.armies(in: pid).first(where: {
                    let i = Int($0.rawValue)
                    return world.military.armies.owner[i] == country && !world.military.armies.isRebel[i]
                }) {
                    world.military.armies.regiments[Int(existing.rawValue)].append(contentsOf: regs)
                } else {
                    let aname = "\(world.countries.name[c]) Host"
                    _ = world.military.armies.append(name: aname, owner: country, province: pid, commander: nil, regiments: regs)
                }
            }

        case "set_flag":
            if let f = eff.str { world.events.setFlag(f, for: country, active: true) }

        case "clear_flag":
            if let f = eff.str { world.events.setFlag(f, for: country, active: false) }

        case "set_global_flag":
            if let f = eff.str { world.events.globalFlags.insert(f) }

        case "clear_global_flag":
            if let f = eff.str { world.events.globalFlags.remove(f) }

        case "add_modifier":
            if let key = eff.str {
                let months = max(1, eff.int ?? 12)
                var values = Array(repeating: 0.0, count: Modifier.allCases.count)
                for (mk, mv) in (eff.mods ?? [:]) {
                    if let m = Modifier(key: mk) {
                        values[m.rawValue] = mv
                    }
                }
                world.events.activeModifiers.removeAll { $0.country == country && $0.key == key }
                world.events.activeModifiers.append(ActiveEventModifier(
                    country: country,
                    key: key,
                    name: eff.str2 ?? key,
                    expiry: date.adding(days: months * 30),
                    values: values
                ))
                if c < world.government.count {
                    GovernmentSystem.refreshEffects(&world, country)
                }
            }

        case "change_opinion":
            if let tag = eff.str, let other = world.countries.id(forTag: tag) {
                world.diplomacy.modifyOpinion(of: country, by: other, delta: eff.int ?? 0)
            }

        case "change_opinion_both":
            if let tag = eff.str, let other = world.countries.id(forTag: tag) {
                let d = eff.int ?? 0
                world.diplomacy.modifyOpinion(of: country, by: other, delta: d)
                world.diplomacy.modifyOpinion(of: other, by: country, delta: d)
            }

        case "change_religion":
            if let rel = eff.str.flatMap({ Religion(rawValue: $0) }) {
                world.countries.religion[c] = rel
                if c < world.government.count {
                    GovernmentSystem.refreshEffects(&world, country)
                }
            }

        case "accept_culture":
            if let key = eff.str, let cid = world.cultures.id(forKey: key) {
                world.countries.acceptedCultures[c].insert(cid)
            }

        case "manpower":
            if c < world.military.manpower.count {
                let cap = max(1000.0, world.military.maxManpower[c] * 1.5)
                world.military.manpower[c] = max(0.0, min(cap, world.military.manpower[c] + (eff.num ?? 0)))
            }

        case "sailors":
            if c < world.navy.sailors.count {
                let cap = max(500.0, world.navy.maxSailors[c] * 1.5)
                world.navy.sailors[c] = max(0.0, min(cap, world.navy.sailors[c] + (eff.num ?? 0)))
            }

        case "tech_progress":
            if let track = TechTrack(key: eff.str ?? ""),
               c < world.tech.countryCount {
                let slot = world.tech.slot(country, track)
                if slot < world.tech.progress.count {
                    world.tech.progress[slot] = max(0.0, world.tech.progress[slot] + (eff.num ?? 0))
                }
            }

        case "ruler_skill":
            if let r = world.countries.ruler[c],
               let sk = skillFromKey(eff.str) {
                let cur = world.people.characters.skills[r.index][sk.rawValue]
                world.people.characters.skills[r.index][sk.rawValue] = max(0, min(20, cur + (eff.int ?? 0)))
            }

        case "add_ruler_trait":
            if let r = world.countries.ruler[c],
               let tid = eff.str.flatMap({ world.people.traits.id(forKey: $0) }),
               !world.people.characters.traits[r.index].contains(tid) {
                world.people.characters.traits[r.index].append(tid)
            }

        case "kill_character":
            let victim: CharacterID?
            if eff.str == "ruler" {
                victim = world.countries.ruler[c]
            } else if eff.str == "heir" {
                victim = world.countries.heir[c]
            } else {
                victim = eff.str.flatMap { world.people.characters.id(forKey: $0) }
            }
            if let victim, world.people.characters.isAlive(victim) {
                CharacterSystem.kill(&world, victim, date: date, random: &rng)
            }

        case "add_vassal_favour":
            let d = eff.int ?? 0
            for v in VassalSystem.vassals(world, of: country) {
                world.people.characters.favour[v.index] = max(-100, min(100, world.people.characters.favour[v.index] + d))
            }

        case "province_dev":
            let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
            for pid in targets {
                let cur = world.provinces.development[pid.index]
                world.provinces.development[pid.index] = max(1, min(15, cur + (eff.int2 ?? 0)))
            }

        case "province_fort":
            let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
            for pid in targets {
                let cur = world.provinces.fortLevel[pid.index]
                let next = max(0, min(5, cur + (eff.int2 ?? 0)))
                world.provinces.fortLevel[pid.index] = next
                world.provinces.fortGarrison[pid.index] = min(next * 1000, world.provinces.fortGarrison[pid.index] + max(0, eff.int2 ?? 0) * 1000)
            }

        case "institution_spread":
            if let idx = world.techRules.institutions.firstIndex(where: { $0.key == eff.str }) {
                let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
                for pid in targets {
                    let cur = world.tech.provincePresence(pid, institution: idx)
                    world.tech.setProvincePresence(pid, institution: idx, cur + (eff.num ?? 0))
                }
            }

        case "spawn_reformation":
            if let rel = eff.str.flatMap({ Religion(rawValue: $0) }),
               (rel == .protestant || rel == .reformed) {
                let targets = resolveTargetProvinces(eff.target, pidx: eff.int, world: world, country: country, contextProvince: contextProvince)
                if let pid = targets.first ?? world.countries.capital[c] {
                    if !world.faith.reformationCentres.contains(where: { $0.province == pid && $0.religion == rel }) {
                        MovementSystem.spawnCentre(in: pid, religion: rel, world: &world, date: date)
                    }
                    world.faith.reformationStarted = true
                }
            }

        case "advance_safaviyya":
            if let phase = eff.str.flatMap({ MovementPhase(rawValue: $0) }) {
                world.faith.safaviyyaPhase = phase
                if phase == .militant || phase == .triumphant {
                    world.faith.safaviyyaYear = world.faith.safaviyyaYear ?? date.year
                    world.faith.safaviyyaStrength = max(world.faith.safaviyyaStrength, 0.75)
                }
            }

        case "cede_province":
            if let p = eff.int, p >= 0, p < world.provinces.count,
               let tag = eff.str,
               let recipient = world.countries.id(forTag: tag),
               let fromOwner = world.provinces.owner[p],
               fromOwner != recipient {
                world.transferProvince(ProvinceID(p), to: recipient, from: fromOwner)
            }

        default:
            break
        }
    }

    private static func resolveTargetProvinces(
        _ target: String?,
        pidx: Int?,
        world: World,
        country: CountryID,
        contextProvince: ProvinceID?
    ) -> [ProvinceID] {
        switch target {
        case "all":
            return world.provinces(ownedBy: country)
        case "capital":
            if let cap = world.countries.capital[country.index] { return [cap] }
            return world.provinces(ownedBy: country).first.map { [$0] } ?? []
        case "context":
            if let cp = contextProvince { return [cp] }
            return world.countries.capital[country.index].map { [$0] } ?? []
        default:
            if let pidx, pidx >= 0, pidx < world.provinces.count {
                return [ProvinceID(pidx)]
            }
            if let cp = contextProvince { return [cp] }
            return []
        }
    }
}

/// Concise summary line printed by the 10-year CI run and tests.
public enum EventReport {
    public static func line(_ world: World) -> String {
        let parts = EventCategory.allCases.compactMap { cat -> String? in
            let n = world.events.firedByCategory[cat.rawValue] ?? 0
            return n > 0 ? "\(cat.rawValue)=\(n)" : nil
        }.joined(separator: " ")
        return "EVENTS fired=\(world.events.firedTotal) by type \(parts.isEmpty ? "none" : parts)"
    }
}
