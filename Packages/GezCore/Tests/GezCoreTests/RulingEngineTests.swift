import Testing
import Foundation
@testable import GezCore

/// A ruling system that exists only in these tests (key `test_ring`), to
/// check every hook the engine offers. Its data lives in the test world only,
/// so registering it globally does not touch other tests.
enum TestRingSystem: RulingSystem {
    static let key = "test_ring"

    static func start(_ world: inout World, date: GameDate) {
        RulingEngine.setValue(&world, key, "started", 1)
    }

    static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        RulingEngine.addValue(&world, key, "ticks", 1)
        // Draws from the ruling stream only.
        RulingEngine.setValue(&world, key, "roll", random.unit())
    }

    static func runYearly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        RulingEngine.addValue(&world, key, "years", 1)
    }

    static func rulerChanged(
        _ world: inout World,
        country: CountryID,
        oldRuler: CharacterID?,
        newRuler: CharacterID,
        date: GameDate,
        random: inout GameRandom
    ) {
        RulingEngine.addCountryValue(&world, key, "successions", country, 1)
    }

    static func countryVanished(_ world: inout World, country: CountryID, date: GameDate) {
        RulingEngine.addValue(&world, key, "vanished", 1)
    }

    static func countryFormed(_ world: inout World, country: CountryID, formable: FormableDef, date: GameDate) {
        RulingEngine.setFlag(&world, key, "formed_\(formable.id.lowercased())")
    }

    static func addEffects(_ world: World, country: CountryID, into fx: inout Effects) {
        if RulingEngine.leader(world, key) == country {
            fx[.tax] += 0.05
        }
    }
}

enum RulingTestSupport {
    static let date = Scenario1453.startDate

    static func mods(_ pairs: [Modifier: Double]) -> [Double] {
        var v = Array(repeating: 0.0, count: Modifier.allCases.count)
        for (m, x) in pairs { v[m.rawValue] = x }
        return v
    }

    /// The bundled world with the test ring added after the bundled systems.
    static func worldWithTestRing(extraFormables: [FormableDef] = []) throws -> World {
        RulingSystems.register(TestRingSystem.self)
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let ara = try #require(world.countries.id(forTag: "ARA"))
        let nav = try #require(world.countries.id(forTag: "NAV"))
        let ring = RulingSystemDef(
            key: TestRingSystem.key,
            name: "Test Ring",
            leader: cas,
            roles: ["member": [ara], "envoy": [nav]],
            roleOrder: ["member", "envoy"],
            values: ["ticks": 0, "power": 50],
            limits: ["power": 0...100, "favour": 0...10],
            params: ["seats": 3],
            roleEffects: [
                RulingRoleEffect(role: "envoy", values: mods([.trade: 0.10])),
                RulingRoleEffect(role: "leader", values: mods([.crownPower: 0.20]), scaleBy: "power", scaleDivisor: 100),
            ]
        )
        world.rulingRules = RulingRules(
            systems: world.rulingRules.systems + [ring],
            formables: world.rulingRules.formables + extraFormables,
            countryCount: world.countries.count
        )
        RulingEngine.setUp(&world, date: date)
        for c in world.countries.ids { GovernmentSystem.refreshEffects(&world, c) }
        return world
    }
}

@Suite("RulingEngine")
struct RulingEngineTests {
    let date = RulingTestSupport.date

    @Test("Bundled rulings1453.json loads the HRE with its emperor, electors and free cities")
    func bundledHRE() throws {
        let world = Scenario1453.makeWorld()
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let cas = try #require(world.countries.id(forTag: "CAS"))
        #expect(world.rulingRules.system("hre")?.name == "Holy Roman Empire")
        #expect(world.rulings.systems.count == world.rulingRules.systems.count)
        #expect(world.rulings.countryCount == world.countries.count)
        #expect(RulingEngine.leader(world, "hre") == hab)
        #expect(RulingEngine.isMember(world, "hre", hab))
        #expect(RulingEngine.hasRole(world, "hre", mai, "elector"))
        #expect(RulingEngine.hasRole(world, "hre", mai, "member"))
        #expect(RulingEngine.hasRole(world, "hre", nur, "free_city"))
        #expect(!RulingEngine.isMember(world, "hre", cas))
        #expect(RulingEngine.holders(world, "hre", "elector").count == 7)
        #expect(RulingEngine.value(world, "hre", "authority") == 20)
        let members = RulingEngine.members(world, "hre")
        #expect(members == members.sorted { $0.index < $1.index })
    }

    @Test("Roles, leaders and membership change through the engine")
    func rolesAndLeaders() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let hab = try #require(world.countries.id(forTag: "HAB"))

        RulingEngine.join(&world, "hre", cas)
        #expect(RulingEngine.isMember(world, "hre", cas))
        RulingEngine.addRole(&world, "hre", cas, "prince_bishop")
        #expect(RulingEngine.hasRole(world, "hre", cas, "prince_bishop"))
        RulingEngine.removeRole(&world, "hre", cas, "prince_bishop")
        #expect(!RulingEngine.hasRole(world, "hre", cas, "prince_bishop"))
        #expect(RulingEngine.isMember(world, "hre", cas))

        RulingEngine.addRole(&world, "hre", cas, "leader", date: date)
        #expect(RulingEngine.leader(world, "hre") == cas)
        #expect(RulingEngine.state(world, "hre")?.leaderSince == date)
        RulingEngine.leave(&world, "hre", cas)
        #expect(!RulingEngine.isMember(world, "hre", cas))
        #expect(RulingEngine.leader(world, "hre") == nil)

        RulingEngine.setLeader(&world, "hre", hab, date: date)
        #expect(RulingEngine.leader(world, "hre") == hab)
        // Unknown systems are ignored, not created.
        RulingEngine.join(&world, "no_such_system", cas)
        #expect(!RulingEngine.isMember(world, "no_such_system", cas))
        #expect(!RulingEngine.modify(&world, "no_such_system") { $0.stage = 9 })
    }

    @Test("System and per-country numbers stay within their data limits")
    func valuesAndLimits() throws {
        var world = try RulingTestSupport.worldWithTestRing()
        let ara = try #require(world.countries.id(forTag: "ARA"))
        let key = TestRingSystem.key

        #expect(RulingEngine.value(world, key, "power") == 50)
        RulingEngine.setValue(&world, key, "power", 150)
        #expect(RulingEngine.value(world, key, "power") == 100)
        RulingEngine.addValue(&world, key, "power", -250)
        #expect(RulingEngine.value(world, key, "power") == 0)
        RulingEngine.addValue(&world, key, "free_number", 7.5)
        #expect(RulingEngine.value(world, key, "free_number") == 7.5)

        #expect(RulingEngine.countryValue(world, key, "favour", ara) == 0)
        RulingEngine.addCountryValue(&world, key, "favour", ara, 4)
        RulingEngine.addCountryValue(&world, key, "favour", ara, 40)
        #expect(RulingEngine.countryValue(world, key, "favour", ara) == 10)
        #expect(RulingEngine.state(world, key)?.countryValues["favour"]?.count == world.countries.count)

        RulingEngine.setFlag(&world, key, "crisis")
        #expect(RulingEngine.hasFlag(world, key, "crisis"))
        RulingEngine.setFlag(&world, key, "crisis", false)
        #expect(!RulingEngine.hasFlag(world, key, "crisis"))
        #expect(RulingEngine.param(world, key, "seats") == 3)
        #expect(RulingEngine.param(world, key, "missing", default: 2) == 2)
    }

    @Test("Role effects from data and Swift effects reach the government modifiers")
    func roleEffects() throws {
        let plain = Scenario1453.makeWorld()
        var world = try RulingTestSupport.worldWithTestRing()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let nav = try #require(world.countries.id(forTag: "NAV"))

        // Envoy: +10% trade. Leader: crown power 0.20 × power/100 (power 50) and +5% tax from Swift.
        #expect(abs(world.government.modifier(nav, .trade) - plain.government.modifier(nav, .trade) - 0.10) < 1e-9)
        #expect(abs(world.government.modifier(cas, .crownPower) - plain.government.modifier(cas, .crownPower) - 0.10) < 1e-9)
        #expect(abs(world.government.modifier(cas, .tax) - plain.government.modifier(cas, .tax) - 0.05) < 1e-9)

        // Losing the role takes the effect away at once.
        RulingEngine.removeRole(&world, TestRingSystem.key, nav, "envoy")
        #expect(abs(world.government.modifier(nav, .trade) - plain.government.modifier(nav, .trade)) < 1e-9)

        // A dissolved system gives nothing.
        RulingEngine.dissolve(&world, TestRingSystem.key, date: date)
        #expect(!RulingEngine.isActive(world, TestRingSystem.key))
        #expect(abs(world.government.modifier(cas, .tax) - plain.government.modifier(cas, .tax)) < 1e-9)
    }

    @Test("Hooks: start, monthly, yearly, succession and a member vanishing")
    func hooks() throws {
        var world = try RulingTestSupport.worldWithTestRing()
        let key = TestRingSystem.key
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let ara = try #require(world.countries.id(forTag: "ARA"))
        #expect(RulingEngine.value(world, key, "started") == 1)

        var random = GameRandom(seed: 99)
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 6, day: 1), random: &random)
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 7, day: 1), random: &random)
        #expect(RulingEngine.value(world, key, "ticks") == 2)
        RulingEngine.runYearly(&world, date: GameDate(year: 1454, month: 1, day: 1), random: &random)
        #expect(RulingEngine.value(world, key, "years") == 1)
        // The ruling stream never draws from the main one.
        #expect(random.rawState == GameRandom(seed: 99).rawState)

        let ruler = try #require(world.countries.ruler[cas.index])
        CharacterSystem.kill(&world, ruler, date: GameDate(year: 1454, month: 2, day: 1), random: &random, suppressEvent: true)
        #expect(RulingEngine.countryValue(world, key, "successions", cas) == 1)

        // Aragon loses every province: the hook runs once and Aragon leaves the ring.
        for p in world.provinces(ownedBy: ara) {
            world.transferProvince(p, to: cas, from: ara)
        }
        RulingEngine.runMonthly(&world, date: GameDate(year: 1454, month: 3, day: 1), random: &random)
        RulingEngine.runMonthly(&world, date: GameDate(year: 1454, month: 4, day: 1), random: &random)
        #expect(RulingEngine.value(world, key, "vanished") == 1)
        #expect(!RulingEngine.isMember(world, key, ara))
    }

    @Test("The ruling random stream is deterministic")
    func rulingRandomDeterministic() throws {
        var a = try RulingTestSupport.worldWithTestRing()
        var b = try RulingTestSupport.worldWithTestRing()
        var ra = GameRandom(seed: 7)
        var rb = GameRandom(seed: 7)
        for m in 6...12 {
            RulingEngine.runMonthly(&a, date: GameDate(year: 1453, month: m, day: 1), random: &ra)
            RulingEngine.runMonthly(&b, date: GameDate(year: 1453, month: m, day: 1), random: &rb)
        }
        #expect(a.rulings == b.rulings)
        let roll = RulingEngine.value(a, TestRingSystem.key, "roll")
        #expect(roll > 0 && roll < 1)
    }

    @Test("Elections: most votes win, ties go to the higher total, then the earlier candidate")
    func elections() throws {
        let v = (0..<5).map(CountryID.init)
        let a = CountryID(10), b = CountryID(11), c = CountryID(12)
        var rng = GameRandom(seed: 1)

        // Voters 0–2 like b, 3–4 like c.
        let e1Opt = RulingEngine.elect(voters: v, candidates: [a, b, c], random: &rng) { voter, cand in
            if cand == b { return voter.index < 3 ? 10 : 0 }
            if cand == c { return voter.index >= 3 ? 10 : 0 }
            return 1
        }
        let r1 = try #require(e1Opt)
        #expect(r1.winner == b)
        #expect(r1.votes == [0, 3, 2])
        #expect(r1.ballots == [b, b, b, c, c])
        #expect(rng.rawState == GameRandom(seed: 1).rawState)

        // Equal scores: everyone votes for the first candidate.
        let e2Opt = RulingEngine.elect(voters: v, candidates: [a, b], random: &rng) { _, _ in 1 }
        let r2 = try #require(e2Opt)
        #expect(r2.winner == a)

        // Vote tie (1–1): the higher total score wins.
        let e3Opt = RulingEngine.elect(voters: [CountryID(0), CountryID(1)], candidates: [a, b], random: &rng) { voter, cand in
            if voter.index == 0 { return cand == a ? 5 : 4 }
            return cand == b ? 9 : 0
        }
        let r3 = try #require(e3Opt)
        #expect(r3.winner == b)

        let none = RulingEngine.elect(voters: v, candidates: [], random: &rng) { _, _ in 0 }
        #expect(none == nil)

        // Jitter is reproducible from the same seed.
        var j1 = GameRandom(seed: 42)
        var j2 = GameRandom(seed: 42)
        let e1 = RulingEngine.elect(voters: v, candidates: [a, b, c], jitter: 5, random: &j1) { _, _ in 0 }
        let e2 = RulingEngine.elect(voters: v, candidates: [a, b, c], jitter: 5, random: &j2) { _, _ in 0 }
        #expect(e1 == e2)
        #expect(j1.rawState == j2.rawState)
    }

    @Test("Event conditions and effects reach ruling systems")
    func eventVocabulary() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let hab = try #require(world.countries.id(forTag: "HAB"))
        func holds(_ c: EventCondition, _ who: CountryID) -> Bool {
            EventSystem.evaluate([c], in: world, for: who, date: date)
        }

        #expect(holds(EventCondition(kind: "ruling_active", str: "hre"), cas))
        #expect(holds(EventCondition(kind: "ruling_member", str: "hre"), mai))
        #expect(holds(EventCondition(kind: "not_ruling_member", str: "hre"), cas))
        #expect(holds(EventCondition(kind: "ruling_leader", str: "hre"), hab))
        #expect(holds(EventCondition(kind: "not_ruling_leader", str: "hre"), mai))
        #expect(holds(EventCondition(kind: "ruling_role", str: "hre:elector"), mai))
        #expect(holds(EventCondition(kind: "not_ruling_role", str: "hre:elector"), hab))
        #expect(!holds(EventCondition(kind: "ruling_value_min", str: "hre:authority", num: 30), hab))

        EventSystem.apply([
            EventEffect(kind: "ruling_join", str: "hre"),
            EventEffect(kind: "ruling_add_role", str: "hre", str2: "prince_bishop"),
            EventEffect(kind: "ruling_value", str: "hre", str2: "authority", num: 25),
            EventEffect(kind: "ruling_set_flag", str: "hre", str2: "reichsreform"),
        ], to: &world, country: cas, date: date)

        #expect(holds(EventCondition(kind: "ruling_member", str: "hre"), cas))
        #expect(holds(EventCondition(kind: "ruling_role", str: "hre:prince_bishop"), cas))
        #expect(holds(EventCondition(kind: "ruling_value_min", str: "hre:authority", num: 40), cas))
        #expect(holds(EventCondition(kind: "ruling_value_max", str: "hre:authority", num: 45), cas))
        #expect(holds(EventCondition(kind: "ruling_flag", str: "hre:reichsreform"), cas))

        EventSystem.apply([
            EventEffect(kind: "ruling_set_value", str: "hre", str2: "authority", num: 500),
            EventEffect(kind: "ruling_clear_flag", str: "hre", str2: "reichsreform"),
            EventEffect(kind: "ruling_set_leader", str: "hre"),
        ], to: &world, country: cas, date: date)
        #expect(RulingEngine.value(world, "hre", "authority") == 100)
        #expect(holds(EventCondition(kind: "not_ruling_flag", str: "hre:reichsreform"), cas))
        #expect(RulingEngine.leader(world, "hre") == cas)

        EventSystem.apply([EventEffect(kind: "ruling_leave", str: "hre")], to: &world, country: cas, date: date)
        #expect(!RulingEngine.isMember(world, "hre", cas))
        #expect(RulingEngine.leader(world, "hre") == nil)

        let summary = EventSystem.effectSummary(for: [
            EventEffect(kind: "ruling_join", str: "hre"),
            EventEffect(kind: "ruling_value", str: "hre", str2: "authority", num: 5),
        ], in: world, country: cas)
        #expect(summary.contains("Holy Roman Empire"))
        #expect(summary.contains("+5"))

        EventSystem.apply([EventEffect(kind: "ruling_dissolve", str: "hre")], to: &world, country: cas, date: date)
        #expect(!holds(EventCondition(kind: "ruling_active", str: "hre"), cas))
    }
}
