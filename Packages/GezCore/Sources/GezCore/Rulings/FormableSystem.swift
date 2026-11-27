import Foundation

/// Why a country cannot form a formable right now.
public enum FormRefusal: String, Sendable, Equatable {
    /// No formable with that id in the data.
    case unknown
    /// The country owns no land.
    case noLand
    /// The country already is this nation.
    case alreadyThis
    /// Someone has formed it already (and it can be formed only once).
    case taken
    /// The country is not on the formable's list.
    case notEligible
    /// Some requirement is not met (see `FormableSystem.requirements`).
    case requirementsNotMet

    public var displayName: String {
        switch self {
        case .unknown: return "No such nation"
        case .noLand: return "Holds no land"
        case .alreadyThis: return "Already formed"
        case .taken: return "Already formed by another realm"
        case .notEligible: return "Not open to this realm"
        case .requirementsNotMet: return "Requirements not met"
        }
    }
}

/// Formable nations, done by transforming a country in place: its shown
/// name, colour, shield, government, reforms and (Phase 21) mission tree
/// change, while its tag and slot in `CountryTable` stay the same. So the
/// country list never grows, saves stay valid, and events written for the
/// old tag (`tag = CAS`) still find the country after it becomes Spain.
public enum FormableSystem {

    // MARK: Queries

    public static func refusal(_ world: World, _ c: CountryID, _ id: String, date: GameDate, force: Bool = false) -> FormRefusal? {
        guard let def = world.rulingRules.formable(id) else { return .unknown }
        guard c.index >= 0, c.index < world.countries.count else { return .unknown }
        guard world.provinces.owner.contains(c) else { return .noLand }
        if c.index < world.rulings.formedAs.count, world.rulings.formedAs[c.index] == id { return .alreadyThis }
        if def.unique, world.rulings.formed.contains(where: { $0.formable == id }) { return .taken }
        if force { return nil }
        if !def.eligible.isEmpty, !def.eligible.contains(c) { return .notEligible }
        if !EventSystem.evaluate(def.trigger, in: world, for: c, date: date) { return .requirementsNotMet }
        return nil
    }

    /// Each requirement of a formable with whether `c` meets it (for tooltips).
    public static func requirements(_ world: World, _ c: CountryID, _ id: String, date: GameDate) -> [(condition: EventCondition, met: Bool)] {
        guard let def = world.rulingRules.formable(id) else { return [] }
        return def.trigger.map { ($0, EventSystem.evaluate([$0], in: world, for: c, date: date)) }
    }

    /// Formables `c` may try (it is eligible and nobody holds them), whether
    /// or not the requirements are met yet: the list a decisions screen shows.
    public static func open(_ world: World, _ c: CountryID, date: GameDate) -> [FormableDef] {
        world.rulingRules.candidates(for: c).compactMap { i in
            let def = world.rulingRules.formables[i]
            let r = refusal(world, c, def.id, date: date)
            return (r == nil || r == .requirementsNotMet) ? def : nil
        }
    }

    /// Formables `c` can form right now.
    public static func available(_ world: World, _ c: CountryID, date: GameDate) -> [FormableDef] {
        world.rulingRules.candidates(for: c).compactMap { i in
            let def = world.rulingRules.formables[i]
            return refusal(world, c, def.id, date: date) == nil ? def : nil
        }
    }

    /// The formable `c` is now, if any.
    public static func formed(_ world: World, _ c: CountryID) -> FormableDef? {
        guard c.index >= 0, c.index < world.rulings.formedAs.count, let id = world.rulings.formedAs[c.index] else { return nil }
        return world.rulingRules.formable(id)
    }

    // MARK: Forming

    /// Turns `c` into the formable `id`. `force` skips the eligible list and
    /// requirements (an event or mission decided it), not the other refusals.
    /// Returns nil on success, otherwise why not.
    @discardableResult
    public static func form(_ world: inout World, _ c: CountryID, _ id: String, date: GameDate, force: Bool = false) -> FormRefusal? {
        if let r = refusal(world, c, id, date: date, force: force) { return r }
        guard let fi = world.rulingRules.formableIndex(id) else { return .unknown }
        let def = world.rulingRules.formables[fi]
        let i = c.index
        if world.rulings.countryCount != world.countries.count {
            world.rulings.resize(countries: world.countries.count)
        }
        let previous = world.countries.name[i]

        world.countries.name[i] = def.name
        world.countries.shield[i] = def.shield
        world.countries.color[i] = def.color
        world.rulings.formedAs[i] = def.id
        world.rulings.formed.append(FormedRecord(country: c, formable: def.id, date: date, previousName: previous))
        if let tree = def.missionTree { world.rulings.missionTree[i] = tree }

        if let g = def.government {
            GovernmentSystem.switchGovernment(&world, c, to: g, date: date)
        }
        for key in def.reforms {
            GovernmentSystem.setReform(&world, c, key: key)
        }

        world.people.record(date, c, "\(previous) is proclaimed \(def.name).")
        HistorySystem.recordEvent(
            &world,
            date: date,
            kind: .nationFormed,
            primary: c,
            valueA: fi,
            valueB: world.rulings.formed.count - 1
        )
        if !def.effects.isEmpty {
            EventSystem.apply(def.effects, to: &world, country: c, date: date)
        }
        RulingEngine.countryFormed(&world, c, def, date: date)
        RulingEngine.refresh(&world, c)
        return nil
    }

    // MARK: Monthly

    /// Computer countries form the first formable they can (one a month);
    /// human players are offered each formable once through the event
    /// pop-up ("Proclaim Spain" / "Not now"). Declined ones stay open for a
    /// decisions screen (`open`, `form`).
    static func runMonthly(_ world: inout World, date: GameDate, land: [Bool]) {
        guard !world.rulingRules.formables.isEmpty else { return }
        world.events.resize(countries: world.countries.count)
        var ctx = EventEvalContext(world)
        for ci in 0..<world.countries.count where ci < land.count && land[ci] {
            let c = CountryID(ci)
            let human = world.humanCountries.contains(c)
            for fi in world.rulingRules.candidates(for: c) {
                let def = world.rulingRules.formables[fi]
                if human {
                    if world.rulings.offered[ci].contains(def.id) { continue }
                } else if !def.ai {
                    continue
                }
                guard quickRefusal(world, c, def, date: date, ctx: ctx) == nil else { continue }
                if human {
                    offer(&world, c, def, date: date)
                } else {
                    form(&world, c, def.id, date: date)
                    ctx = EventEvalContext(world)
                }
                break
            }
        }
    }

    /// `refusal` using the month's cached context.
    static func quickRefusal(_ world: World, _ c: CountryID, _ def: FormableDef, date: GameDate, ctx: EventEvalContext) -> FormRefusal? {
        if c.index < world.rulings.formedAs.count, world.rulings.formedAs[c.index] == def.id { return .alreadyThis }
        if def.unique, world.rulings.formed.contains(where: { $0.formable == def.id }) { return .taken }
        if !def.eligible.isEmpty, !def.eligible.contains(c) { return .notEligible }
        if !EventSystem.evaluate(def.trigger, in: world, for: c, date: date, ctx: ctx) { return .requirementsNotMet }
        return nil
    }

    /// Puts the offer in the player's event queue.
    static func offer(_ world: inout World, _ c: CountryID, _ def: FormableDef, date: GameDate) {
        world.rulings.offered[c.index].insert(def.id)
        let formEffects = [EventEffect(kind: "form_nation", str: def.id)]
        let instanceID = world.events.nextInstanceID
        world.events.nextInstanceID += 1
        let text = def.text.isEmpty
            ? "The lands of \(def.name) are united under \(world.countries.name[c.index]). Shall the realm take the name, colours and arms of \(def.name)?"
            : def.text
        let pending = PendingEvent(
            instanceID: instanceID,
            eventID: "formable_\(def.id)",
            country: c,
            date: date,
            title: "Proclaim \(def.name)?",
            text: text,
            category: .historical,
            options: [
                PendingEventOption(
                    label: "Proclaim \(def.name)",
                    tooltip: EventSystem.effectSummary(for: formEffects, in: world, country: c),
                    aiWeight: 100,
                    effects: formEffects
                ),
                PendingEventOption(label: "Not now", tooltip: "It can still be proclaimed later", aiWeight: 0, effects: [])
            ]
        )
        EventSystem.enqueueHumanPending(&world, pending: pending, date: date)
    }

    // MARK: Loading a save

    /// Puts the formed names and shields back after a save is loaded
    /// (colours, government and reforms are saved with the country).
    public static func reapplyIdentity(_ world: inout World) {
        for i in 0..<min(world.countries.count, world.rulings.formedAs.count) {
            guard let id = world.rulings.formedAs[i], let def = world.rulingRules.formable(id) else { continue }
            world.countries.name[i] = def.name
            world.countries.shield[i] = def.shield
        }
    }
}
