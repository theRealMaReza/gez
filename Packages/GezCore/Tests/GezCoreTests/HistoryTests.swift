import Foundation
import Testing
@testable import GezCore

@Suite("History Recording (Phase 18)")
struct HistoryTests {

    private func makeTestSimulation(seed: UInt64 = 1453) -> Simulation {
        let world = Scenario1453.makeWorld()
        return Simulation(world: world, startDate: GameDate(year: 1453, month: 5, day: 30), seed: seed)
    }

    @Test("Initialization records 1453 baseline stats, timelapse, and ruler chapters")
    func initializationBaseline() {
        let sim = makeTestSimulation()
        HistorySystem.ensureInitialized(&sim.world, date: sim.date)

        #expect(sim.world.history.isInitialized)
        #expect(sim.world.history.stats.years == [1453])
        #expect(sim.world.history.timelapse.years == [1453])
        #expect(sim.world.history.timelapse.initialOwner.count == sim.world.provinces.count)
        #expect(sim.world.history.timelapse.initialReligion.count == sim.world.provinces.count)
        #expect(sim.world.history.chapters.count > 0)

        let ott = sim.world.countries.id(forTag: "TUR")!
        let ottSeries = sim.world.history.stats.series(for: ott)
        #expect(ottSeries.count == 1)
        #expect(ottSeries[0].year == 1453)
        #expect(ottSeries[0].population > 0)
    }

    @Test("Chronicle events record deterministically and regnal chapters track successions")
    func chronicleEventsAndSuccession() {
        let sim1 = makeTestSimulation(seed: 42)
        let sim2 = makeTestSimulation(seed: 42)

        let ott = sim1.world.countries.id(forTag: "TUR")!
        let hun = sim1.world.countries.id(forTag: "HUN")!
        let prov = sim1.world.provinces(ownedBy: ott).first!
        let date = GameDate(year: 1454, month: 3, day: 15)

        for kind in ChronicleEventKind.allCases {
            HistorySystem.recordEvent(
                &sim1.world,
                date: date,
                kind: kind,
                primary: ott,
                secondary: hun,
                province: prov,
                valueA: 1200,
                valueB: 5
            )
            HistorySystem.recordEvent(
                &sim2.world,
                date: date,
                kind: kind,
                primary: ott,
                secondary: hun,
                province: prov,
                valueA: 1200,
                valueB: 5
            )
        }

        #expect(sim1.world.history.events.count == ChronicleEventKind.allCases.count)
        #expect(sim1.world.history.events == sim2.world.history.events)
        #expect(sim1.world.history.events.involves(ott, at: 0))
        #expect(sim1.world.history.events.involves(hun, at: 0))

        // Succession closes old reign and opens new reign
        HistorySystem.ensureInitialized(&sim1.world, date: sim1.date)
        let oldRuler = sim1.world.countries.ruler[ott.index]
        var rng = GameRandom(seed: 99)
        let newRuler = CharacterSystem.invent(&sim1.world, court: ott, date: date, random: &rng, dynasty: nil)
        HistorySystem.recordSuccession(&sim1.world, country: ott, oldRuler: oldRuler, newRuler: newRuler, date: date)

        let ottChapters = (0..<sim1.world.history.chapters.count).filter {
            sim1.world.history.chapters.country[$0] == Int16(ott.index)
        }
        #expect(ottChapters.count == 2)
        #expect(sim1.world.history.chapters.endDate(at: ottChapters[0]) == date)
        #expect(sim1.world.history.chapters.endDate(at: ottChapters[1]) == nil)
    }

    @Test("Timelapse delta encoding reconstructs owner and religion changes accurately")
    func timelapseDeltaReconstruction() {
        let sim = makeTestSimulation()
        HistorySystem.ensureInitialized(&sim.world, date: sim.date)

        let ott = sim.world.countries.id(forTag: "TUR")!
        let hun = sim.world.countries.id(forTag: "HUN")!
        let targetProv = sim.world.provinces(ownedBy: ott).first!
        let originalOwner = sim.world.provinces.owner[targetProv.index]
        let originalReligion = sim.world.provinces.religion[targetProv.index]

        // Mutate owner and religion before 1454 snapshot
        sim.world.provinces.owner[targetProv.index] = hun
        sim.world.provinces.religion[targetProv.index] = .orthodox
        HistorySystem.recordYearlySnapshot(&sim.world, date: GameDate(year: 1454, month: 1, day: 1))

        #expect(sim.world.history.timelapse.years == [1453, 1454])

        let frame1453 = sim.world.history.timelapse.frame(atYearIndex: 0)
        #expect(frame1453.owner[targetProv.index] == Int16(originalOwner!.index))
        #expect(HistorySystem.religion(fromIndex: frame1453.religion[targetProv.index]) == originalReligion)

        let frame1454 = sim.world.history.timelapse.frame(atYearIndex: 1)
        #expect(frame1454.owner[targetProv.index] == Int16(hun.index))
        #expect(HistorySystem.religion(fromIndex: frame1454.religion[targetProv.index]) == .orthodox)
    }

    @Test("Save and load preserves history, and legacy saves initialize on load")
    func saveAndLoadRoundtrip() throws {
        let sim = makeTestSimulation()
        sim.advance(days: 220) // Crosses 1454-01-01

        #expect(sim.world.history.stats.years.contains(1453))
        #expect(sim.world.history.stats.years.contains(1454))

        let data = try SaveStorage.encodeArchive(sim, name: "Phase18Test", playerTag: "TUR")
        let (restored, _) = try SaveStorage.decodeArchive(from: data)

        #expect(restored.world.history == sim.world.history)

        // Legacy save simulation: strip `history` from snapshot and restore
        var snapshot = SaveSnapshot(capturing: sim)
        snapshot.history = nil
        let legacySim = try snapshot.restore()
        #expect(legacySim.world.history.isInitialized)
        #expect(legacySim.world.history.stats.years == [sim.date.year])
        #expect(legacySim.world.history.timelapse.years == [sim.date.year])
    }

    @Test("400 years of recorded history keeps full save file well under 5 MB")
    func fourHundredYearSaveSize() throws {
        let sim = makeTestSimulation()
        HistorySystem.ensureInitialized(&sim.world, date: sim.date)

        let pCount = sim.world.provinces.count
        let cCount = min(150, sim.world.countries.count)
        var rng = GameRandom(seed: 18)

        // Simulate 400 yearly snapshots + 2,000 chronicle events + 1,000 regnal chapters
        for yOffset in 1...400 {
            let year = 1453 + yOffset
            // Mutate ~30 province owners and ~10 religions per year
            for _ in 0..<30 {
                let p = Int(rng.next() % UInt64(pCount))
                let c = CountryID(Int(rng.next() % UInt64(cCount)))
                sim.world.provinces.owner[p] = c
            }
            for _ in 0..<10 {
                let p = Int(rng.next() % UInt64(pCount))
                let r = Religion.allCases[Int(rng.next() % UInt64(Religion.allCases.count))]
                sim.world.provinces.religion[p] = r
            }
            HistorySystem.recordYearlySnapshot(&sim.world, date: GameDate(year: year, month: 1, day: 1))

            for _ in 0..<5 {
                let c1 = CountryID(Int(rng.next() % UInt64(cCount)))
                let c2 = CountryID(Int(rng.next() % UInt64(cCount)))
                let p = ProvinceID(Int(rng.next() % UInt64(pCount)))
                let kind = ChronicleEventKind.allCases[Int(rng.next() % UInt64(ChronicleEventKind.allCases.count))]
                HistorySystem.recordEvent(&sim.world, date: GameDate(year: year, month: 6, day: 1), kind: kind, primary: c1, secondary: c2, province: p, valueA: 2500, valueB: 12)
            }
        }

        let data = try SaveStorage.encodeArchive(sim, name: "400Years", playerTag: "TUR")
        let sizeBytes = data.count
        let limitBytes = 5 * 1024 * 1024
        print("400-year save size: \(sizeBytes) bytes (\(String(format: "%.2f", Double(sizeBytes) / 1048576.0)) MB)")
        #expect(sizeBytes < limitBytes, "Save size \(sizeBytes) bytes exceeded 5 MB limit (\(limitBytes))")
    }
}
