import Testing
import Foundation
@testable import GezCore

@Suite("HistoricalEvents")
struct HistoricalEventsTests {

    @Test("Bundled events1453.json contains ~66 historical events plus 4 chronicle events with 2-4 options")
    func eventCountsAndOptions() {
        let world = Scenario1453.makeWorld()
        let historical = world.eventRules.events.filter { $0.id.hasPrefix("hist_") }
        let chronicle = world.eventRules.events.filter { $0.id.hasPrefix("chronicle_") }
        #expect(historical.count >= 64)
        #expect(chronicle.count == 4)
        for ev in world.eventRules.events {
            #expect(ev.options.count >= 2 && ev.options.count <= 4,
                    "Event \(ev.id) has \(ev.options.count) options")
        }
    }

    @Test("Belgrade 1456 and Ladislaus 1457 fire on exact date windows when conditions hold")
    func exactDateHistoricalEvents() throws {
        var world = Scenario1453.makeWorld()
        let hun = try #require(world.countries.id(forTag: "HUN"))
        world.humanCountries = [hun]
        var rng = GameRandom(seed: 1456)

        // Before 1456-07-21, Belgrade 1456 must not fire.
        EventSystem.runMonthly(&world, date: GameDate(year: 1456, month: 7, day: 1), random: &rng)
        #expect(!world.events.pending.contains { $0.eventID == "hist_belgrade_1456_hun" })

        // On 1456-08-01 (first monthly tick >= 1456-07-21), HUN gets Belgrade event if Hunyadi is alive.
        let hunyadi = world.people.characters.id(forKey: "hunyadi")
        if let hunyadi, !world.people.characters.isAlive(hunyadi) {
            world.people.characters.death[hunyadi.index] = nil
        }
        EventSystem.runMonthly(&world, date: GameDate(year: 1456, month: 8, day: 1), random: &rng)
        #expect(world.events.pending.contains { $0.eventID == "hist_belgrade_1456_hun" && $0.country == hun })

        // Resolving Belgrade marks global flag so Ottoman alternate never fires.
        let belInst = try #require(world.events.pending.first { $0.eventID == "hist_belgrade_1456_hun" }?.instanceID)
        #expect(EventSystem.resolvePendingEvent(&world, instanceID: belInst, optionIndex: 0, date: GameDate(year: 1456, month: 8, day: 1)))
        #expect(world.events.globalFlags.contains("belgrade_1456_resolved"))

        // Ladislaus death 1457-11-23 fires on 1457-12-01 and kills ladislaus5 when chosen.
        let ladislaus = try #require(world.people.characters.id(forKey: "ladislaus5"))
        world.countries.ruler[hun.index] = ladislaus
        world.people.characters.death[ladislaus.index] = nil
        EventSystem.runMonthly(&world, date: GameDate(year: 1457, month: 12, day: 1), random: &rng)
        let ladPending = try #require(world.events.pending.first { $0.eventID == "hist_ladislaus_death_1457" })
        #expect(EventSystem.resolvePendingEvent(&world, instanceID: ladPending.instanceID, optionIndex: 0, date: GameDate(year: 1457, month: 12, day: 1)))
        #expect(!world.people.characters.isAlive(ladislaus))
    }

    @Test("Alternative Fall of Granada and Columbus chain respond to altered history")
    func alternateVersionsAndColumbusChain() throws {
        var world = Scenario1453.makeWorld()
        let cas = try #require(world.countries.id(forTag: "CAS"))
        let por = try #require(world.countries.id(forTag: "POR"))
        let gra = try #require(world.countries.id(forTag: "GRA"))
        let granadaProv = try #require(world.provinces.id(named: "Granada"))
        let malaga = try #require(world.provinces.id(named: "Malaga"))
        let almeria = try #require(world.provinces.id(named: "Almeria"))

        // If GRA no longer exists and CAS already owns Granada, the conquered version matches while war version does not.
        for p in [granadaProv, malaga, almeria] {
            world.provinces.owner[p.index] = cas
        }
        for p in 0..<world.provinces.count where world.provinces.owner[p] == gra {
            world.provinces.owner[p] = cas
        }
        let warEv = try #require(world.eventRules.event(id: "hist_fall_of_granada_war"))
        let conqEv = try #require(world.eventRules.event(id: "hist_fall_of_granada_conquered"))
        let d1490 = GameDate(year: 1490, month: 1, day: 1)
        #expect(!EventSystem.evaluate(warEv.trigger, in: world, for: cas, date: d1490))
        #expect(EventSystem.evaluate(conqEv.trigger, in: world, for: cas, date: d1490))

        // Columbus chain: Portugal declining unlocks Castile; Castile declining unlocks northern courts.
        world.humanCountries = [por, cas]
        #expect(EventSystem.trigger(&world, eventID: "hist_columbus_portugal", for: por, date: GameDate(year: 1484, month: 6, day: 1)))
        let porPending = try #require(world.events.pending.first { $0.eventID == "hist_columbus_portugal" })
        #expect(EventSystem.resolvePendingEvent(&world, instanceID: porPending.instanceID, optionIndex: 0, date: GameDate(year: 1484, month: 6, day: 1)))
        #expect(world.events.globalFlags.contains("columbus_seeks_patron"))

        let colCas = try #require(world.eventRules.event(id: "hist_columbus_castile"))
        #expect(EventSystem.evaluate(colCas.trigger, in: world, for: cas, date: GameDate(year: 1492, month: 1, day: 1)))
    }

    @Test("Luther and Safavid historical events tie into MovementSystem")
    func reformationAndSafavidTieIns() throws {
        var world = Scenario1453.makeWorld()
        let sax = try #require(world.countries.id(forTag: "SAX"))
        let akk = try #require(world.countries.id(forTag: "AKK"))
        let wittenberg = try #require(world.provinces.id(named: "Wittenberg"))
        world.provinces.owner[wittenberg.index] = sax
        world.humanCountries = [sax, akk]

        // Luther 1517
        #expect(!world.faith.reformationStarted)
        #expect(EventSystem.trigger(&world, eventID: "hist_luther_95_theses", for: sax, date: GameDate(year: 1517, month: 11, day: 1)))
        let luther = try #require(world.events.pending.first { $0.eventID == "hist_luther_95_theses" })
        #expect(EventSystem.resolvePendingEvent(&world, instanceID: luther.instanceID, optionIndex: 0, date: GameDate(year: 1517, month: 11, day: 1)))
        #expect(world.faith.reformationStarted)
        #expect(world.faith.reformationCentres.contains { $0.province == wittenberg })

        // Safavid 1501
        let ardabil = try #require(world.provinces.id(named: "Ardabil"))
        world.provinces.owner[ardabil.index] = akk
        #expect(EventSystem.trigger(&world, eventID: "hist_safavid_rise_1501", for: akk, date: GameDate(year: 1501, month: 7, day: 1)))
        let safavid = try #require(world.events.pending.first { $0.eventID == "hist_safavid_rise_1501" })
        #expect(EventSystem.resolvePendingEvent(&world, instanceID: safavid.instanceID, optionIndex: 0, date: GameDate(year: 1501, month: 7, day: 1)))
        #expect(world.faith.safaviyyaPhase == .triumphant)
        #expect(world.countries.religion[akk.index] == .twelver)
    }

    @Test("Chronicle events fire as pop-ups for rebel risings, vassal plots, and ruler deaths without double firing on poison")
    func chronicleEventPopups() throws {
        var world = Scenario1453.makeWorld()
        let eng = try #require(world.countries.id(forTag: "ENG"))
        let fra = try #require(world.countries.id(forTag: "FRA"))
        world.humanCountries = [eng, fra]
        var rng = GameRandom(seed: 99)

        // 1. Ruler death pop-up for human FRA
        let fraRuler = try #require(world.countries.ruler[fra.index])
        CharacterSystem.kill(&world, fraRuler, date: GameDate(year: 1455, month: 3, day: 10), random: &rng)
        let deathPopup = try #require(world.events.pending.first { $0.eventID == "chronicle_ruler_death" && $0.country == fra })
        #expect(!deathPopup.text.contains("{old_ruler}"))
        #expect(!deathPopup.text.contains("{ruler}"))

        // 2. Vassal plot against human ENG: produces either plot_success or plot_uncovered, never also ruler_death on same call
        world.events.pending.removeAll { $0.country == eng }
        let vassal = try #require(world.people.characters.ids.first {
            world.people.characters.isAlive($0) && $0 != world.countries.ruler[eng.index]
        })
        VassalSystem.plot(&world, by: vassal, against: eng, date: GameDate(year: 1456, month: 4, day: 2), random: &rng)
        let plotEvents = world.events.pending.filter { $0.country == eng }
        #expect(plotEvents.count == 1)
        #expect(plotEvents[0].eventID == "chronicle_vassal_plot_success" || plotEvents[0].eventID == "chronicle_vassal_plot_uncovered")

        // 3. Rebel rising pop-up for human ENG triggered via UnrestSystem
        world.events.pending.removeAll { $0.country == eng }
        world.countries.taxLevel[eng.index] = Array(repeating: 2, count: TaxClass.allCases.count)
        for p in world.provinces(ownedBy: eng) {
            world.provinces.famine[p.index] = 0.6
        }
        world.government.stability[eng.index] = -3
        for m in 1...150 {
            let d = GameDate(year: 1456 + (m - 1) / 12, month: ((m - 1) % 12) + 1, day: 1)
            UnrestSystem.runMonthly(&world, date: d, random: &rng)
            if world.events.pending.contains(where: { $0.eventID == "chronicle_rebel_rising" && $0.country == eng }) {
                break
            }
        }
        let rebelPopup = try #require(world.events.pending.first { $0.eventID == "chronicle_rebel_rising" && $0.country == eng })
        #expect(!rebelPopup.title.contains("{province}"))
        #expect(rebelPopup.contextProvince != nil)
    }

    @Test("Historical events fire deterministically over multi-year runs")
    func multiYearDeterminism() {
        func run4Years(seed: UInt64) -> (Int, [String: Int], UInt64, [String]) {
            let sim = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: seed)
            for _ in 0..<(365 * 4) {
                sim.tick()
            }
            let recentIDs = sim.world.events.recent.map(\.eventID)
            return (sim.world.events.firedTotal, sim.world.events.firedByCategory, sim.world.events.rngState, recentIDs)
        }

        let a = run4Years(seed: 2025)
        let b = run4Years(seed: 2025)
        #expect(a.0 > 0)
        #expect(a.0 == b.0)
        #expect(a.1 == b.1)
        #expect(a.2 == b.2)
        #expect(a.3 == b.3)
    }
}
