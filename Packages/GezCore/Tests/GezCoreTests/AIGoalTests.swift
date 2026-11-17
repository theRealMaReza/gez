import Testing
import Foundation
@testable import GezCore

@Suite("AIGoals")
struct AIGoalTests {

    @Test("Goal lists load for all 28 key 1453 tags with Historical as default")
    func goalDataLoadsForAllKeyCountries() throws {
        let world = Scenario1453.makeWorld()
        #expect(world.ai.setting == .historical)

        let requiredTags = [
            "TUR", "HUN", "VEN", "GEN", "MLO", "FLO", "NAP", "ARA", "PAP",
            "FRA", "ENG", "BUR", "CAS", "POR", "HAB", "AUS", "POL", "LIT",
            "MOS", "SER", "BOS", "WAL", "MOL", "ALB", "MOE", "TRE", "MAM", "KNI"
        ]
        for tag in requiredTags {
            let cid = try #require(world.countries.id(forTag: tag), "Missing tag \(tag)")
            let goals = world.aiRules.goalsByCountry[cid.index]
            #expect(!goals.isEmpty, "Expected historical goals for \(tag)")
        }

        // Ottoman list starts after 29 May 1453 and includes Serbia, Morea, Trebizond, Bosnia, Black Sea, Rhodes, Otranto.
        let tur = try #require(world.countries.id(forTag: "TUR"))
        let turGoals = world.aiRules.goalsByCountry[tur.index].map { world.aiRules.goals[$0] }
        #expect(turGoals.allSatisfy { $0.earliestDate > GameDate(year: 1453, month: 5, day: 30) || $0.type == .keepPeaceWith })
        let turTargets = Set(turGoals.map(\.target))
        for expected in ["Smederevo", "Mystras", "Trebizond", "Jajce", "Kaffa", "Rhodes", "Lecce"] {
            #expect(turTargets.contains(expected), "Ottomans missing goal target \(expected)")
        }

        // Hungary must try to hold Belgrade in 1456 (linked to hist_belgrade_1456_hun).
        let hun = try #require(world.countries.id(forTag: "HUN"))
        #expect(world.ai.currentGoalID[hun.index] == "hun_belgrade_1456")
        #expect(AIGoalSystem.goalSummaryText(for: hun, in: world) == "Defend Belgrade")
    }

    @Test("Goals are skipped when target is gone, date passed, or country is too weak")
    func goalSkippingCases() throws {
        var world = Scenario1453.makeWorld()
        let hun = try #require(world.countries.id(forTag: "HUN"))
        let pap = try #require(world.countries.id(forTag: "PAP"))
        let tur = try #require(world.countries.id(forTag: "TUR"))

        // 1. Hungary Belgrade goal resolves cleanly once hist_belgrade_1456_hun global flag is set and peace holds
        world.events.globalFlags.insert("belgrade_1456_resolved")
        AIGoalSystem.updateGoals(&world, date: GameDate(year: 1456, month: 8, day: 1))
        #expect(world.ai.completedGoalIDs[hun.index].contains("hun_belgrade_1456"))
        #expect(world.ai.currentGoalID[hun.index] != "hun_belgrade_1456")

        // 2. Target gone: if Papal States loses all provinces, hun_ally_papacy is skipped
        for p in 0..<world.provinces.count where world.provinces.owner[p] == pap {
            world.provinces.owner[p] = tur
        }
        AIGoalSystem.updateGoals(&world, date: GameDate(year: 1458, month: 1, day: 1))
        #expect(world.ai.skippedGoalIDs[hun.index].contains("hun_ally_papacy"))

        // 3. Date passed: advance past 1468-12-31 -> hun_black_army is skipped and Hungary moves on
        AIGoalSystem.updateGoals(&world, date: GameDate(year: 1470, month: 1, day: 1))
        #expect(world.ai.skippedGoalIDs[hun.index].contains("hun_black_army"))

        // 4. Too weak: make Castile bankrupt with tiny manpower/soldiers in 1483 -> skips Granada conquer goal
        let cas = try #require(world.countries.id(forTag: "CAS"))
        world.countries.bankruptMonthsLeft[cas.index] = 12
        world.military.maxManpower[cas.index] = 100
        for idx in 0..<world.military.armies.count where world.military.armies.owner[idx] == cas {
            world.military.armies.alive[idx] = false
        }
        AIGoalSystem.updateGoals(&world, date: GameDate(year: 1483, month: 1, day: 1))
        #expect(world.ai.skippedGoalIDs[cas.index].contains("cas_granada"))
        #expect(world.ai.currentGoalID[cas.index] != "cas_granada")
    }

    @Test("Historical AI falls back to Free behaviour when its goal list runs out")
    func fallbackToFreeWhenListRunsOut() throws {
        var world = Scenario1453.makeWorld()
        let alb = try #require(world.countries.id(forTag: "ALB"))

        #expect(!AIGoalSystem.isFreeMode(for: alb, in: world))
        #expect(world.ai.currentGoalID[alb.index] == "alb_defend_kruje")

        // Advance well past all of Albania's historical give-up dates (1479)
        AIGoalSystem.updateGoals(&world, date: GameDate(year: 1485, month: 1, day: 1))
        #expect(AIGoalSystem.isFreeMode(for: alb, in: world))
        #expect(world.ai.usingFreeFallback[alb.index])
        #expect(world.ai.currentGoalID[alb.index] == nil)
        #expect(AIGoalSystem.goalSummaryText(for: alb, in: world).contains("Free AI (list complete)"))
    }

    @Test("Free AI setting disables historical goal scripts from day one")
    func freeSettingUsesSituationalGoals() throws {
        var world = Scenario1453.makeWorld()
        world.ai.setting = .free
        AIGoalSystem.updateGoals(&world, date: Scenario1453.startDate)

        let tur = try #require(world.countries.id(forTag: "TUR"))
        let hun = try #require(world.countries.id(forTag: "HUN"))
        #expect(AIGoalSystem.isFreeMode(for: tur, in: world))
        #expect(AIGoalSystem.isFreeMode(for: hun, in: world))
        #expect(world.ai.currentGoalID[tur.index] == nil)
        #expect(AIGoalSystem.activePeaceTargets(for: tur, date: Scenario1453.startDate, in: world).isEmpty)
        #expect(AIGoalSystem.goalSummaryText(for: hun, in: world).hasPrefix("Free AI:"))
    }

    @Test("Save and load preserves AI setting, progress, and defaults old saves to Historical")
    func saveLoadSettingProgressAndLegacyCompatibility() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GezAISaveTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Free setting round-trip + determinism
        var freeWorld = Scenario1453.makeWorld()
        freeWorld.ai.setting = .free
        AIGoalSystem.updateGoals(&freeWorld, date: Scenario1453.startDate)
        let simFreeA = Simulation(world: freeWorld, startDate: Scenario1453.startDate, seed: 2026)
        simFreeA.advance(days: 60)

        let freeData = try SaveStorage.encodeArchive(simFreeA, name: "FreeAI", playerTag: "FRA")
        let (simFreeB, _) = try SaveStorage.decodeArchive(from: freeData)
        #expect(simFreeB.world.ai.setting == .free)
        #expect(simFreeB.world.ai.usingFreeFallback == simFreeA.world.ai.usingFreeFallback)
        simFreeA.advance(days: 60)
        simFreeB.advance(days: 60)
        #expect(simFreeA.world.provinces.owner == simFreeB.world.provinces.owner)
        #expect(simFreeA.world.diplomacy.wars == simFreeB.world.diplomacy.wars)

        // 2. Historical progress round-trip
        let simHistA = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 1453)
        simHistA.advance(days: 60)
        let histData = try SaveStorage.encodeArchive(simHistA, name: "HistAI", playerTag: "ENG")
        let (simHistB, _) = try SaveStorage.decodeArchive(from: histData)
        #expect(simHistB.world.ai == simHistA.world.ai)

        // 3. Old save without `ai` key in snapshot defaults to Historical cleanly
        var rawJSON = try #require(JSONSerialization.jsonObject(with: histData) as? [String: Any])
        var snapshotObj = try #require(rawJSON["snapshot"] as? [String: Any])
        snapshotObj.removeValue(forKey: "ai")
        rawJSON["snapshot"] = snapshotObj
        let legacyData = try JSONSerialization.data(withJSONObject: rawJSON)

        let (legacySim, _) = try SaveStorage.decodeArchive(from: legacyData)
        #expect(legacySim.world.ai.setting == .historical)
        let hun = try #require(legacySim.world.countries.id(forTag: "HUN"))
        #expect(legacySim.world.ai.currentGoalID[hun.index] == "hun_belgrade_1456")
    }

    @Test("One-year headless run stays stable under both Historical and Free AI settings")
    func oneYearHeadlessRunsBothSettingsStayStable() {
        for setting in [AIBehaviourSetting.historical, AIBehaviourSetting.free] {
            var world = Scenario1453.makeWorld()
            world.ai.setting = setting
            AIGoalSystem.updateGoals(&world, date: Scenario1453.startDate)
            let sim = Simulation(world: world, startDate: Scenario1453.startDate, seed: 1453)
            sim.advance(days: 365)

            #expect(sim.date == GameDate(year: 1454, month: 5, day: 30))
            #expect(sim.world.ai.setting == setting)
            for p in 0..<sim.world.provinces.count {
                #expect(sim.world.provinces.population[p].isFinite && sim.world.provinces.population[p] >= 0)
            }
            for c in 0..<sim.world.countries.count {
                #expect(sim.world.countries.treasury[c].isFinite)
            }
        }
    }
}
