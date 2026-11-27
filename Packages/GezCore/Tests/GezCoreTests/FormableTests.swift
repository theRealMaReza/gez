import Testing
import Foundation
@testable import GezCore

@Suite("Formables")
struct FormableTests {
    let date = GameDate(year: 1480, month: 1, day: 1)
    static let spainProvinces = ["Toledo", "Seville", "Zaragoza", "Valencia", "Barcelona"]

    /// Gives every Spanish requirement province to `country`.
    static func giveSpain(_ world: inout World, to country: CountryID) throws {
        for name in spainProvinces {
            let p = try #require(world.provinces.id(named: name))
            if let owner = world.provinces.owner[p.index], owner != country {
                world.transferProvince(p, to: country, from: owner)
            } else {
                world.provinces.owner[p.index] = country
            }
        }
    }

    static func testFormable(_ id: String, for tag: String, in world: World, ai: Bool = true) throws -> FormableDef {
        let c = try #require(world.countries.id(forTag: tag))
        return FormableDef(
            id: id,
            name: "Test Realm \(id)",
            color: RGB(10, 20, 30),
            eligible: [c],
            trigger: [EventCondition(kind: "tag", str: tag)],
            effects: [EventEffect(kind: "prestige", num: 5)],
            missionTree: "test_tree",
            ai: ai
        )
    }

    @Test("Spain is loaded and refused for the right reasons")
    func refusals() throws {
        let world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let fra = try #require(world.countries.id(forTag: "FRA"))
        let spain = try #require(world.rulingRules.formable("SPA"))
        #expect(spain.name == "Spain")
        #expect(spain.shield == "SPA")
        #expect(!spain.ai)
        let spainIndex = try #require(world.rulingRules.formableIndex("SPA"))
        #expect(world.rulingRules.candidates(for: cas).contains(spainIndex))
        #expect(world.rulingRules.candidates(for: fra).isEmpty)

        #expect(FormableSystem.refusal(world, cas, "SPA", date: date) == .requirementsNotMet)
        #expect(FormableSystem.refusal(world, fra, "SPA", date: date) == .notEligible)
        #expect(FormableSystem.refusal(world, cas, "NOPE", date: date) == .unknown)
        #expect(FormableSystem.open(world, cas, date: date).map(\.id) == ["SPA"])
        #expect(FormableSystem.available(world, cas, date: date).isEmpty)
        let reqs = FormableSystem.requirements(world, cas, "SPA", date: date)
        #expect(reqs.count == spain.trigger.count)
        #expect(reqs.contains { !$0.met })
    }

    @Test("Forming Spain transforms Castile in place")
    func formSpain() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let ara = try #require(world.countries.id(forTag: "ARA"))
        let countries = world.countries.count
        let prestige = world.countries.prestige[cas.index]
        try Self.giveSpain(&world, to: cas)

        #expect(FormableSystem.refusal(world, cas, "SPA", date: date) == nil)
        #expect(FormableSystem.available(world, cas, date: date).map(\.id) == ["SPA"])
        #expect(FormableSystem.form(&world, cas, "SPA", date: date) == nil)

        // Identity changes; the tag, slot and country list do not.
        #expect(world.countries.name[cas.index] == "Spain")
        #expect(world.countries.shield[cas.index] == "SPA")
        #expect(world.countries.color[cas.index] == RGB(226, 186, 34))
        #expect(world.countries.tag[cas.index] == "CAS")
        #expect(world.countries.id(forTag: "CAS") == cas)
        #expect(world.countries.count == countries)
        #expect(world.countries.government[cas.index] == .monarchy)
        #expect(world.countries.prestige[cas.index] > prestige)
        #expect(world.rulings.formedAs[cas.index] == "SPA")
        #expect(world.rulings.missionTree[cas.index] == "spain")
        #expect(FormableSystem.formed(world, cas)?.id == "SPA")
        let record = try #require(world.rulings.formed.last)
        #expect(record.country == cas && record.formable == "SPA" && record.previousName == "Castile" && record.date == date)

        // Conditions see it; events written for Castile still find it.
        #expect(EventSystem.evaluate([EventCondition(kind: "is_formed", str: "SPA")], in: world, for: cas, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "formed", str: "SPA")], in: world, for: ara, date: date))
        #expect(!EventSystem.evaluate([EventCondition(kind: "not_formed", str: "SPA")], in: world, for: ara, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "tag", str: "CAS")], in: world, for: cas, date: date))

        // Only once, by one realm.
        #expect(FormableSystem.refusal(world, cas, "SPA", date: date) == .alreadyThis)
        #expect(FormableSystem.refusal(world, ara, "SPA", date: date) == .taken)
        #expect(FormableSystem.form(&world, ara, "SPA", date: date, force: true) == .taken)

        // The Chronicle remembers the old name.
        let last = world.history.events.count - 1
        #expect(world.history.events.eventKind(at: last) == .nationFormed)
        let prose = ChronicleTemplateSet.shared.render(eventIndex: last, in: world)
        #expect(prose.contains("Castile"))
        #expect(prose.contains("Spain"))
    }

    @Test("An event's form_nation skips the requirements but not the refusals")
    func formByEvent() throws {
        var world = Scenario1453.makeWorld()
        let ara = try #require(world.countries.id(forTag: "ARA"))
        let cas = try #require(world.countries.id(forTag: "CAS"))
        #expect(FormableSystem.refusal(world, ara, "SPA", date: date) == .requirementsNotMet)
        #expect(EventSystem.evaluate([EventCondition(kind: "can_form", str: "SPA")], in: world, for: ara, date: date) == false)
        EventSystem.apply([EventEffect(kind: "form_nation", str: "SPA")], to: &world, country: ara, date: date)
        #expect(world.countries.name[ara.index] == "Spain")
        EventSystem.apply([EventEffect(kind: "form_nation", str: "SPA")], to: &world, country: cas, date: date)
        #expect(world.countries.name[cas.index] == "Castile")
        let tip = EventSystem.effectSummary(for: [EventEffect(kind: "form_nation", str: "SPA")], in: world, country: cas)
        #expect(tip == "Become Spain")
    }

    @Test("Computer countries form an AI formable on the monthly tick")
    func aiForms() throws {
        let base = Scenario1453.makeWorld()
        let f = try Self.testFormable("TSTA", for: "POR", in: base)
        var world = try RulingTestSupport.worldWithTestRing(extraFormables: [f])
        let por = try #require(world.countries.id(forTag: "POR"))
        var random = GameRandom(seed: 3)
        RulingEngine.runMonthly(&world, date: date, random: &random)
        #expect(world.countries.name[por.index] == "Test Realm TSTA")
        #expect(world.rulings.missionTree[por.index] == "test_tree")
        // Systems hear about it.
        #expect(RulingEngine.hasFlag(world, TestRingSystem.key, "formed_tsta"))
        // Spain (ai = false) is never formed by the computer.
        let cas = try #require(world.countries.id(forTag: "CAS"))
        try Self.giveSpain(&world, to: cas)
        RulingEngine.runMonthly(&world, date: date.adding(days: 31), random: &random)
        #expect(world.countries.name[cas.index] == "Castile")
    }

    @Test("A human player is offered a formable once, through the event pop-up")
    func humanOffer() throws {
        let base = Scenario1453.makeWorld()
        let f = try Self.testFormable("TSTH", for: "POR", in: base)
        var world = try RulingTestSupport.worldWithTestRing(extraFormables: [f])
        let por = try #require(world.countries.id(forTag: "POR"))
        world.humanCountries = [por]
        var random = GameRandom(seed: 3)

        RulingEngine.runMonthly(&world, date: date, random: &random)
        #expect(world.countries.name[por.index] == "Portugal")
        let offers = world.events.pending.filter { $0.country == por && $0.eventID == "formable_TSTH" }
        #expect(offers.count == 1)
        let offer = try #require(offers.first)
        #expect(offer.options.count == 2)
        #expect(offer.options[0].tooltip == "Become Test Realm TSTH")

        RulingEngine.runMonthly(&world, date: date.adding(days: 31), random: &random)
        #expect(world.events.pending.filter { $0.eventID == "formable_TSTH" }.count == 1)

        #expect(EventSystem.resolvePendingEvent(&world, instanceID: offer.instanceID, optionIndex: 0, date: date))
        #expect(world.countries.name[por.index] == "Test Realm TSTH")
    }

    @Test("Forming can switch government and set reforms by key")
    func governmentAndReforms() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let tree = try #require(world.government.rules.reforms[.monarchy])
        let lastTier = tree.count - 1
        let key = tree[lastTier].options[0].key
        #expect(GovernmentSystem.setReform(&world, cas, key: key))
        #expect(world.government.reforms[cas.index].count == tree.count)
        #expect(world.government.reforms[cas.index][lastTier] == 0)
        #expect(!GovernmentSystem.setReform(&world, cas, key: "no_such_reform"))

        let rep = try #require(world.government.rules.reforms[.republic])
        let repKey = rep[0].options[min(1, rep[0].options.count - 1)].key
        let f = FormableDef(
            id: "TSTG", name: "Test Republic", color: RGB(1, 2, 3),
            eligible: [cas], trigger: [EventCondition(kind: "tag", str: "CAS")],
            government: .republic, reforms: [repKey]
        )
        world.rulingRules = RulingRules(systems: world.rulingRules.systems, formables: world.rulingRules.formables + [f], countryCount: world.countries.count)
        #expect(FormableSystem.form(&world, cas, "TSTG", date: date) == nil)
        #expect(world.countries.government[cas.index] == .republic)
        #expect(world.government.reforms[cas.index].first == min(1, rep[0].options.count - 1))
    }

    @Test("Formed nations and ruling state survive a save; old saves load with the 1453 state")
    func saveRoundTrip() throws {
        let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        sim.advance(days: 40)
        let cas = try #require(sim.world.countries.id(forTag: "CAS"))
        let mai = try #require(sim.world.countries.id(forTag: "MAI"))
        try Self.giveSpain(&sim.world, to: cas)
        #expect(FormableSystem.form(&sim.world, cas, "SPA", date: sim.date) == nil)
        RulingEngine.addValue(&sim.world, "hre", "authority", 12)
        let savedAuthority = RulingEngine.value(sim.world, "hre", "authority")
        RulingEngine.removeRole(&sim.world, "hre", mai, "elector")

        let snapshot = SaveSnapshot(capturing: sim)
        let data = try JSONEncoder().encode(snapshot)
        let back = try JSONDecoder().decode(SaveSnapshot.self, from: data)
        let restored = try back.restore()
        let w = restored.world
        #expect(w.countries.name[cas.index] == "Spain")
        #expect(w.countries.shield[cas.index] == "SPA")
        #expect(w.countries.color[cas.index] == RGB(226, 186, 34))
        #expect(w.rulings == sim.world.rulings)
        #expect(RulingEngine.value(w, "hre", "authority") == savedAuthority)
        #expect(!RulingEngine.hasRole(w, "hre", mai, "elector"))

        // Both games carry on the same way.
        sim.advance(days: 62)
        restored.advance(days: 62)
        #expect(sim.world.rulings == restored.world.rulings)
        #expect(sim.random.rawState == restored.random.rawState)
        #expect(sim.world.countries.name == restored.world.countries.name)

        // A save from before Phase 20.8 has no ruling state.
        var old = SaveSnapshot(capturing: sim)
        old.rulings = nil
        let oldWorld = try old.restore().world
        #expect(RulingEngine.leader(oldWorld, "hre") == oldWorld.countries.id(forTag: "HAB"))
        #expect(oldWorld.countries.name[cas.index] == "Castile")
    }
}
