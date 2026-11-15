import XCTest
@testable import GezCore

final class BattleEngineTests: XCTestCase {

    // MARK: - Part A: Battlefield Generation, Deployment, Choice Prompt

    func testBattlefieldGeneratorReproducibilityAndTerrain() {
        let pMountains = ProvinceID(10)
        let bf1 = BattlefieldGenerator.generate(
            province: pMountains,
            terrain: .mountains,
            isRiverCrossing: true,
            isCoastal: false,
            seed: 1453
        )
        let bf2 = BattlefieldGenerator.generate(
            province: pMountains,
            terrain: .mountains,
            isRiverCrossing: true,
            isCoastal: false,
            seed: 1453
        )
        XCTAssertEqual(bf1, bf2, "Same province + seed must generate identical battlefield")
        XCTAssertNotNil(bf1.river)
        XCTAssertFalse(bf1.river!.fords.isEmpty, "River crossing should include at least one ford")
        XCTAssertEqual(bf1.hills.count, 5, "Mountains should generate dense high-relief hills")

        let bfForest = BattlefieldGenerator.generate(
            province: pMountains,
            terrain: .forest,
            isRiverCrossing: false,
            isCoastal: false,
            seed: 1453
        )
        XCTAssertNil(bfForest.river)
        XCTAssertEqual(bfForest.forests.count, 7)
        let avgMountElev = bf1.elevationGrid.reduce(0.0, +) / Double(bf1.elevationGrid.count)
        let avgForestElev = bfForest.elevationGrid.reduce(0.0, +) / Double(bfForest.elevationGrid.count)
        XCTAssertGreaterThan(avgMountElev, avgForestElev)
    }

    func testDeploymentPhasePlacementClampingAndAmbushSkip() {
        var world = Scenario1453.makeWorld()
        guard let fra = world.countries.id(forTag: "FRA"),
              let eng = world.countries.id(forTag: "ENG"),
              let bordeaux = world.provinces.id(named: "Bordeaux") else {
            XCTFail("Missing scenario entities")
            return
        }
        for aid in world.military.armies(in: bordeaux) {
            world.military.armies.remove(aid)
        }

        let inf = world.military.unit("infantry")!
        let cav = world.military.unit("cavalry")!
        let arc = world.military.unit("archers")!

        let attArmy = world.military.armies.append(
            name: "French Army",
            owner: fra,
            province: bordeaux,
            regiments: [
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: cav.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: arc.id, origin: .professional, men: 1_000, morale: 2.8)
            ]
        )
        let defArmy = world.military.armies.append(
            name: "English Army",
            owner: eng,
            province: bordeaux,
            regiments: [
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: arc.id, origin: .professional, men: 1_000, morale: 2.8)
            ]
        )

        let normalBattle = Battle(
            id: "test_normal",
            province: bordeaux,
            startDate: Scenario1453.startDate,
            attackers: [attArmy],
            defenders: [defArmy],
            attackerCountry: fra,
            defenderCountry: eng,
            isRiverCrossing: false,
            attackerInitialMen: 3_000,
            defenderInitialMen: 2_000
        )

        var engine = BattleEngine(world: world, battle: normalBattle, playerSide: .attacker, seed: 99)
        XCTAssertEqual(engine.phase, .deployment)
        XCTAssertEqual(engine.units.count, 5)

        // Clamps player movement to attacker deployment zone
        let attZone = engine.battlefield.attackerDeployZone
        XCTAssertTrue(engine.deployMoveUnit(unitIndex: 0, x: 999.0, y: 250.0, facing: 0.25))
        XCTAssertLessThanOrEqual(engine.units.posX[0], attZone.maxX)
        XCTAssertEqual(engine.units.facing[0], 0.25, accuracy: 0.001)

        // Rejects moving enemy unit
        let enemyUnitIdx = (0..<engine.units.count).first { engine.units.side[$0] == .defender }!
        XCTAssertFalse(engine.deployMoveUnit(unitIndex: enemyUnitIdx, x: 900.0, y: 300.0))

        // Transition to active locks deployment
        XCTAssertTrue(engine.startBattle())
        XCTAssertEqual(engine.phase, .active)
        XCTAssertFalse(engine.deployMoveUnit(unitIndex: 0, x: 150.0, y: 200.0))

        // Ambushed while crossing river skips deployment for crossing player
        let crossingBattle = Battle(
            id: "test_river",
            province: bordeaux,
            startDate: Scenario1453.startDate,
            attackers: [attArmy],
            defenders: [defArmy],
            attackerCountry: fra,
            defenderCountry: eng,
            isRiverCrossing: true,
            attackerInitialMen: 3_000,
            defenderInitialMen: 2_000
        )
        let ambushedEngine = BattleEngine(world: world, battle: crossingBattle, playerSide: .attacker, seed: 99)
        XCTAssertTrue(ambushedEngine.attackerAmbushed)
        XCTAssertEqual(ambushedEngine.phase, .active, "Ambushed crossing player must skip deployment phase")

        // Defender facing a river-crossing attacker still gets deployment phase
        let defenderEngine = BattleEngine(world: world, battle: crossingBattle, playerSide: .defender, seed: 99)
        XCTAssertEqual(defenderEngine.phase, .deployment)
    }

    func testBattleChoiceModalTriggersAndAutoResolvesForHumanButNotAI() throws {
        let session = try GameSession(tag: "FRA", seed: 777)
        session.interactiveBattlesEnabled = true
        session.speed = .three

        guard let fra = session.world.countries.id(forTag: "FRA"),
              let eng = session.world.countries.id(forTag: "ENG"),
              let bordeaux = session.world.provinces.id(named: "Bordeaux") else {
            XCTFail("Missing FRA/ENG/Bordeaux")
            return
        }

        // Clear unrelated wars temporarily by clearing armies in Bordeaux & spawning a clean FRA vs ENG clash
        for aid in session.world.military.armies(in: bordeaux) {
            session.simulation.world.military.armies.remove(aid)
        }
        let inf = session.world.military.unit("infantry")!
        session.simulation.world.military.armies.append(
            name: "Garrison Relief",
            owner: fra,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        session.simulation.world.military.armies.append(
            name: "Lancaster Guard",
            owner: eng,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )

        // Advance days: should pause and open battle prompt on encounter before resolving day 1
        _ = session.advanceDays(3)
        XCTAssertNotNil(session.pendingBattlePrompt, "Encounter involving player country must open battle choice modal")
        XCTAssertEqual(session.speed, .paused, "Campaign speed must pause while modal is open")
        XCTAssertEqual(session.simulation.world.military.battle(in: bordeaux)?.dayCount, 0)

        // Choosing Lead Battle in Person creates the interactive tactical battle
        XCTAssertTrue(session.chooseLeadPendingBattleInPerson())
        XCTAssertNil(session.pendingBattlePrompt)
        XCTAssertNotNil(session.tacticalBattle)
        XCTAssertEqual(session.tacticalBattle?.units.totalMen(on: .attacker), 1_000)

        // Test Auto-Resolve branch separately
        session.tacticalBattle = nil
        session.simulation.activeTacticalBattleID = nil
        let simAuto = try GameSession(tag: "FRA", seed: 777)
        simAuto.interactiveBattlesEnabled = true
        simAuto.speed = .two
        for aid in simAuto.world.military.armies(in: bordeaux) {
            simAuto.simulation.world.military.armies.remove(aid)
        }
        simAuto.simulation.world.military.armies.append(
            name: "French Army",
            owner: fra,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        simAuto.simulation.world.military.armies.append(
            name: "English Army",
            owner: eng,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        _ = simAuto.advanceDays(1)
        XCTAssertNotNil(simAuto.pendingBattlePrompt)
        _ = simAuto.chooseAutoResolvePendingBattle()
        XCTAssertNil(simAuto.pendingBattlePrompt)
        XCTAssertEqual(simAuto.speed, .two, "Auto-resolve restores prior campaign speed")
        _ = simAuto.advanceDays(1)
        XCTAssertGreaterThanOrEqual(simAuto.world.military.battle(in: bordeaux)?.dayCount ?? 1, 1)

        // Verify AI-vs-AI battle never opens modal even with interactiveBattlesEnabled = true
        let aiOnlySession = try GameSession(tag: "TUR", seed: 888)
        aiOnlySession.interactiveBattlesEnabled = true
        aiOnlySession.speed = .three
        for aid in aiOnlySession.world.military.armies(in: bordeaux) {
            aiOnlySession.simulation.world.military.armies.remove(aid)
        }
        aiOnlySession.simulation.world.military.armies.append(
            name: "AI FRA",
            owner: fra,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        aiOnlySession.simulation.world.military.armies.append(
            name: "AI ENG",
            owner: eng,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        _ = aiOnlySession.advanceDays(2)
        XCTAssertNil(aiOnlySession.pendingBattlePrompt, "AI-vs-AI battles must stay auto-resolved")
    }
}
