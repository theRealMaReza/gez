import Testing
import Foundation
@testable import GezCore

@Suite("EventEngine")
struct EventEngineTests {

    @Test("Bundled events1453.json loads and pre-indexes into World")
    func bundledEventsLoad() throws {
        let world = Scenario1453.makeWorld()
        #expect(!world.eventRules.events.isEmpty)
        #expect(world.events.countryCount == world.countries.count)
        let cas = try #require(world.countries.id(forTag: "CAS"))
        #expect(!world.eventRules.eventsByCountry[cas.index].isEmpty)
    }

    @Test("Condition vocabulary evaluates tags, provinces, tech, institutions, ruler, and flags")
    func conditionVocabulary() throws {
        var world = Scenario1453.makeWorld()
        let tur = try #require(world.countries.id(forTag: "TUR"))
        let pap = try #require(world.countries.id(forTag: "PAP"))
        let konst = try #require(world.provinces.id(named: "Konstantiniyye"))
        let date = GameDate(year: 1460, month: 1, day: 1)

        #expect(EventSystem.evaluate([EventCondition(kind: "tag", str: "TUR")], in: world, for: tur, date: date))
        #expect(!EventSystem.evaluate([EventCondition(kind: "tag", str: "CAS")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "owns", int: konst.index)], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "controls", int: konst.index)], in: world, for: tur, date: date))
        #expect(!EventSystem.evaluate([EventCondition(kind: "at_war_with", str: "PAP")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "religion", str: "sunni")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "religion_family", str: "muslim")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "culture", str: "turkish")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "mil_tech", int: 3)], in: world, for: tur, date: date))
        #expect(!EventSystem.evaluate([EventCondition(kind: "mil_tech", int: 19)], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "institution_present", str: "renaissance")], in: world, for: pap, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "ruler_alive", str: "mehmed2")], in: world, for: tur, date: date))
        #expect(EventSystem.evaluate([EventCondition(kind: "ruler_trait", str: "ambitious")], in: world, for: tur, date: date))

        world.countries.treasury[tur.index] = 250
        #expect(EventSystem.evaluate([EventCondition(kind: "treasury_min", num: 200)], in: world, for: tur, date: date))
        world.government.stability[tur.index] = 1
        #expect(EventSystem.evaluate([EventCondition(kind: "stability_min", int: 1)], in: world, for: tur, date: date))

        #expect(!EventSystem.evaluate([EventCondition(kind: "has_flag", str: "test_flag")], in: world, for: tur, date: date))
        world.events.setFlag("test_flag", for: tur)
        #expect(EventSystem.evaluate([EventCondition(kind: "has_flag", str: "test_flag")], in: world, for: tur, date: date))
    }

    @Test("Effect vocabulary mutates treasury, stability, prestige, loyalty, unrest, pops, claims, CBs, units, flags, modifiers, and opinions")
    func effectVocabulary() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let gra = try #require(world.countries.id(forTag: "GRA"))
        let seville = try #require(world.provinces.id(named: "Seville"))
        let granada = try #require(world.provinces.id(named: "Granada"))
        let nobles = try #require(world.government.rules.estate(forKey: "nobles"))
        let date = GameDate(year: 1470, month: 6, day: 1)

        let startDucats = world.countries.treasury[cas.index]
        let startPrestige = world.countries.prestige[cas.index]
        let startLoyalty = world.government.loyalty[cas.index][nobles.index]
        let startOpinion = world.diplomacy.opinion(of: cas, by: gra)
        let startArmies = world.totalSoldiers(of: cas)
        let startArmyQuality = world.government.modifier(cas, .armyQuality)
        world.government.stability[cas.index] = 0

        let effects: [EventEffect] = [
            EventEffect(kind: "ducats", num: 120),
            EventEffect(kind: "stability", int: 1),
            EventEffect(kind: "prestige", num: 15),
            EventEffect(kind: "estate_loyalty", str: "nobles", num: 10),
            EventEffect(kind: "unrest", target: "province", int: seville.index, num: 12),
            EventEffect(kind: "pops_convert", target: "province", str: "catholic", str2: "sunni", int: seville.index, num: 0.25),
            EventEffect(kind: "add_claim", str: "Granada", int: granada.index),
            EventEffect(kind: "add_cb", str: "GRA", str2: "subjugation", int: 24),
            EventEffect(kind: "spawn_units", target: "capital", str: "infantry", int: -1, int2: 2),
            EventEffect(kind: "set_flag", str: "castile_ready"),
            EventEffect(kind: "add_modifier", str: "test_mod", str2: "Test Mod", int: 6, mods: ["army_quality": 0.12]),
            EventEffect(kind: "change_opinion", str: "GRA", int: -30),
        ]

        EventSystem.apply(effects, to: &world, country: cas, date: date)

        #expect(world.countries.treasury[cas.index] == startDucats + 120)
        #expect(world.government.stability[cas.index] == 1)
        #expect(world.countries.prestige[cas.index] == startPrestige + 15)
        #expect(world.government.loyalty[cas.index][nobles.index] == min(100, startLoyalty + 10))
        #expect(world.unrest.unrest(seville.index) >= 12)
        #expect(world.provinces.claims[granada.index].contains(cas))
        #expect(world.diplomacy.availableCasusBelli(attacker: cas, defender: gra, in: world).contains { $0.type == .subjugation })
        #expect(world.totalSoldiers(of: cas) >= startArmies + 2000)
        #expect(world.events.hasFlag("castile_ready", for: cas))
        #expect(abs(world.government.modifier(cas, .armyQuality) - (startArmyQuality + 0.12)) < 1e-6)
        #expect(world.diplomacy.opinion(of: cas, by: gra) == startOpinion - 30)

        let sunniInSeville = world.pops.range(for: seville).filter { world.pops.religion[$0] == .sunni }.reduce(0.0) { $0 + world.pops.size[$1] }
        #expect(sunniInSeville > 0)

        // Modifier expires cleanly after 6 months (200 days); CB expires after 24 months (730 days)
        var rng = GameRandom(seed: 99)
        EventSystem.runMonthly(&world, date: date.adding(days: 200), random: &rng)
        #expect(world.events.activeModifiers.isEmpty)
        #expect(!world.events.grantedCBs.isEmpty)
        EventSystem.runMonthly(&world, date: date.adding(days: 730), random: &rng)
        #expect(world.events.grantedCBs.isEmpty)
    }

    @Test("MTTH firing rate approximates expected half-life over 12 months")
    func mtthFiringRateMatchesExpectation() throws {
        let world = Scenario1453.makeWorld()
        let tur = try #require(world.countries.id(forTag: "TUR"))
        let ev = EventDef(
            id: "test_mtth_ev",
            title: "MTTH Test",
            text: "Test",
            category: .historical,
            countryTags: ["TUR"],
            countryIDs: [tur],
            dateFrom: GameDate(year: 1453, month: 1, day: 1),
            dateTo: GameDate(year: 1500, month: 1, day: 1),
            mtth: 12,
            fireOnce: true,
            options: [
                EventOptionDef(label: "A", aiWeight: 100),
                EventOptionDef(label: "B", aiWeight: 0),
            ]
        )
        var firedInYear = 0
        let trials = 200
        for seed in 1...trials {
            var w = world
            var rules = EventRules()
            rules.events = [ev]
            rules.rebuildIndexes(countryCount: w.countries.count)
            w.eventRules = rules
            var mainRng = GameRandom(seed: UInt64(seed))
            for m in 1...12 {
                let d = GameDate(year: 1454, month: m, day: 1)
                EventSystem.runMonthly(&w, date: d, random: &mainRng)
                if w.events.firedGlobal.contains("test_mtth_ev") {
                    firedInYear += 1
                    break
                }
            }
        }
        // With MTTH = 12 months, theoretical 12-month probability is 50%; expect 75..125 out of 200.
        #expect(firedInYear >= 75 && firedInYear <= 125)
    }

    @Test("Exact-date events fire deterministically and never perturb main Simulation.random")
    func exactDateAndDedicatedRNG() throws {
        let baseA = Scenario1453.makeWorld()
        let baseB = Scenario1453.makeWorld()
        let tur = try #require(baseA.countries.id(forTag: "TUR"))
        let exactEv = EventDef(
            id: "test_exact_ev",
            title: "Exact Event",
            text: "Exact",
            category: .historical,
            countryTags: ["TUR"],
            countryIDs: [tur],
            dateFrom: GameDate(year: 1453, month: 5, day: 30),
            dateTo: GameDate(year: 1454, month: 12, day: 31),
            exactDate: GameDate(year: 1453, month: 8, day: 1),
            mtth: 0,
            fireOnce: true,
            options: [
                EventOptionDef(label: "Gain Prestige", aiWeight: 100, effects: [EventEffect(kind: "prestige", num: 5)]),
                EventOptionDef(label: "Pass", aiWeight: 0),
            ]
        )

        var wA = baseA
        wA.eventRules.events.append(exactEv)
        wA.eventRules.rebuildIndexes(countryCount: wA.countries.count)

        var wB = baseB
        wB.eventRules.events = []
        wB.eventRules.rebuildIndexes(countryCount: wB.countries.count)

        let simA = Simulation(world: wA, startDate: Scenario1453.startDate, seed: 777)
        let simB = Simulation(world: wB, startDate: Scenario1453.startDate, seed: 777)
        simA.advance(days: 90)
        simB.advance(days: 90)

        #expect(simA.world.events.firedGlobal.contains("test_exact_ev"))
        // Adding/firing an event via AI does not consume Simulation.random!
        #expect(simA.random.rawState == simB.random.rawState)
    }

    @Test("AI option weighting responds to situation modifiers")
    func aiWeightingBySituation() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let date = GameDate(year: 1480, month: 1, day: 1)

        let ev = EventDef(
            id: "test_ai_choice",
            title: "AI Choice",
            text: "Test",
            category: .internalAffairs,
            countryTags: ["CAS"],
            countryIDs: [cas],
            options: [
                EventOptionDef(
                    label: "Expensive",
                    aiWeight: 10,
                    aiModifiers: [EventAIWeightModifier(condition: EventCondition(kind: "treasury_min", num: 500), op: .mul, value: 20)]
                ),
                EventOptionDef(
                    label: "Cheap",
                    aiWeight: 20,
                    aiModifiers: [EventAIWeightModifier(condition: EventCondition(kind: "treasury_max", num: 50), op: .mul, value: 10)]
                ),
            ]
        )

        world.countries.treasury[cas.index] = 1000
        var richPicks0 = 0
        var rng = GameRandom(seed: 123)
        for _ in 0..<50 {
            if EventSystem.chooseAIOption(for: ev, in: world, country: cas, date: date, rng: &rng) == 0 {
                richPicks0 += 1
            }
        }
        #expect(richPicks0 >= 38)

        world.countries.treasury[cas.index] = 10
        var poorPicks1 = 0
        for _ in 0..<50 {
            if EventSystem.chooseAIOption(for: ev, in: world, country: cas, date: date, rng: &rng) == 1 {
                poorPicks1 += 1
            }
        }
        #expect(poorPicks1 >= 42)
    }

    @Test("Save/load round-trip preserves event state and flags, and old saves without events still load")
    func saveLoadRoundTripAndBackwardCompat() throws {
        let world = Scenario1453.makeWorld()
        let tur = try #require(world.countries.id(forTag: "TUR"))
        let simA = Simulation(world: world, startDate: Scenario1453.startDate, seed: 1453)
        simA.world.humanCountries = [tur]
        EventSystem.apply([
            EventEffect(kind: "set_flag", str: "saved_flag"),
            EventEffect(kind: "set_global_flag", str: "saved_global"),
            EventEffect(kind: "add_modifier", str: "saved_mod", str2: "Saved Mod", int: 12, mods: ["tax": 0.10]),
        ], to: &simA.world, country: tur, date: simA.date)
        simA.world.events.pending.append(PendingEvent(
            instanceID: 42,
            eventID: "custom_pending",
            country: tur,
            date: simA.date,
            title: "Pending",
            text: "Body",
            category: .historical,
            options: [
                PendingEventOption(label: "Accept", tooltip: "+5 prestige", aiWeight: 100, effects: [EventEffect(kind: "prestige", num: 5)]),
                PendingEventOption(label: "Decline", tooltip: "Nothing", aiWeight: 0, effects: []),
            ]
        ))

        let data = try SaveStorage.encodeArchive(simA, name: "EventSave", playerTag: "TUR")
        let (simB, _) = try SaveStorage.decodeArchive(from: data)

        #expect(simB.world.events.hasFlag("saved_flag", for: tur))
        #expect(simB.world.events.globalFlags.contains("saved_global"))
        #expect(simB.world.events.activeModifiers.count == 1)
        #expect(simB.world.events.pending.count == 1)
        #expect(simB.world.events.pending[0].instanceID == 42)
        #expect(simB.world.events.rngState == simA.world.events.rngState)

        // Backward compatibility: snapshot with `events = nil` still restores cleanly.
        var archive = try JSONDecoder().decode(SaveArchive.self, from: data)
        archive.snapshot.events = nil
        let oldData = try JSONEncoder().encode(archive)
        let (simOld, _) = try SaveStorage.decodeArchive(from: oldData)
        #expect(simOld.world.events.countryCount == simOld.world.countries.count)
    }

    @Test("GameSession pauses on player event when pauseOnEvents is true and honors setting when false")
    func sessionPauseOnEventSetting() throws {
        let session = try GameSession(tag: "TUR", seed: 1453)
        let tur = try #require(session.playerCountry)
        session.simulation.world.eventRules.events.append(EventDef(
            id: "test_session_pause",
            title: "Pause Test",
            text: "Body",
            category: .historical,
            countryTags: ["TUR"],
            countryIDs: [tur],
            dateFrom: GameDate(year: 1453, month: 5, day: 30),
            dateTo: GameDate(year: 1454, month: 1, day: 1),
            exactDate: GameDate(year: 1453, month: 6, day: 1),
            mtth: 0,
            fireOnce: true,
            options: [
                EventOptionDef(label: "Yes", aiWeight: 50, effects: [EventEffect(kind: "prestige", num: 5)]),
                EventOptionDef(label: "No", aiWeight: 50, effects: []),
            ]
        ))
        session.simulation.world.eventRules.rebuildIndexes(countryCount: session.world.countries.count)

        session.pauseOnEvents = true
        session.speed = .three
        let out1 = session.advanceDays(10)
        #expect(out1.daysAdvanced == 2) // 31 May, 1 June -> pauses on 1 June
        #expect(session.speed == .paused)
        let pending = try #require(session.pendingPlayerEvent)
        #expect(pending.eventID == "test_session_pause")
        #expect(session.activeAlerts().contains { $0.kind == .event })

        #expect(session.chooseEventOption(instanceID: pending.instanceID, optionIndex: 0))
        #expect(session.pendingPlayerEvent == nil)

        // Now test with pauseOnEvents = false
        let session2 = try GameSession(tag: "TUR", seed: 1453)
        let tur2 = try #require(session2.playerCountry)
        session2.simulation.world.eventRules.events = session.simulation.world.eventRules.events
        session2.simulation.world.eventRules.rebuildIndexes(countryCount: session2.world.countries.count)
        session2.pauseOnEvents = false
        session2.speed = .three
        let out2 = session2.advanceDays(10)
        #expect(out2.daysAdvanced == 10)
        #expect(session2.speed == .three)
        #expect(session2.pendingPlayerEvent?.country == tur2)
    }
}
