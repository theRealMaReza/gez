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

    // MARK: - Part B: Real-Time Control, Formations, Stances, Morale, Fatigue, Ammo, AI & Equivalence

    private func makeTestBattleEngine(
        attRegiments: [Regiment],
        defRegiments: [Regiment],
        playerSide: BattleSide? = .attacker,
        terrain: Terrain = .plains,
        seed: UInt64 = 1234
    ) -> BattleEngine {
        var world = Scenario1453.makeWorld()
        let fra = world.countries.id(forTag: "FRA")!
        let eng = world.countries.id(forTag: "ENG")!
        let prov = world.provinces.ids.first(where: { world.provinces.terrain[$0.index] == terrain }) ?? world.provinces.id(named: "Bordeaux")!
        for aid in world.military.armies(in: prov) {
            world.military.armies.remove(aid)
        }
        let attArmy = world.military.armies.append(name: "Att Force", owner: fra, province: prov, regiments: attRegiments)
        let defArmy = world.military.armies.append(name: "Def Force", owner: eng, province: prov, regiments: defRegiments)
        let battle = Battle(
            id: "test_partB",
            province: prov,
            startDate: Scenario1453.startDate,
            attackers: [attArmy],
            defenders: [defArmy],
            attackerCountry: fra,
            defenderCountry: eng,
            isRiverCrossing: false,
            attackerInitialMen: attRegiments.reduce(0) { $0 + $1.men },
            defenderInitialMen: defRegiments.reduce(0) { $0 + $1.men }
        )
        return BattleEngine(world: world, battle: battle, playerSide: playerSide, seed: seed)
    }

    func testDeterminismPathFrontlineFormationsAndSpeeds() {
        let world = Scenario1453.makeWorld()
        let inf = world.military.unit("infantry")!
        let wagons = world.military.unit("war_wagons")!

        var e1 = makeTestBattleEngine(
            attRegiments: [
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: wagons.id, origin: .professional, men: 1_000, morale: 3.2)
            ],
            defRegiments: [
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)
            ],
            playerSide: .attacker,
            seed: 4242
        )
        XCTAssertEqual(e1.units.formation[2], .wagonLaager, "Hussite war wagons default to wagonLaager")
        var e2 = e1

        // Speed multipliers step exact proportional tick counts
        XCTAssertTrue(e1.startBattle())
        XCTAssertTrue(e2.startBattle())
        e1.setSpeed(.paused)
        XCTAssertEqual(e1.tick(deltaSeconds: 0.2), 0)
        e1.setSpeed(.half)
        XCTAssertEqual(e1.tick(deltaSeconds: 0.2), 1)
        e1.setSpeed(.fast)
        XCTAssertEqual(e1.tick(deltaSeconds: 0.2), 4)

        // Reset to identical speed and run identical orders -> must match bit-for-bit
        e1.setSpeed(.normal)
        e2.stepTicks(5)
        e1.issueFormationOrder(unitIndices: [0], formation: .column)
        e2.issueFormationOrder(unitIndices: [0], formation: .column)
        e1.issuePathOrder(unitIndices: [0], points: [TacticalPoint(x: 420, y: 200), TacticalPoint(x: 560, y: 320)])
        e2.issuePathOrder(unitIndices: [0], points: [TacticalPoint(x: 420, y: 200), TacticalPoint(x: 560, y: 320)])
        e1.issueFrontlineOrder(unitIndices: [0, 1], start: TacticalPoint(x: 500, y: 180), end: TacticalPoint(x: 500, y: 420))
        e2.issueFrontlineOrder(unitIndices: [0, 1], start: TacticalPoint(x: 500, y: 180), end: TacticalPoint(x: 500, y: 420))

        e1.stepTicks(40)
        e2.stepTicks(40)
        XCTAssertEqual(e1, e2, "Identical orders on same ticks must be bit-for-bit deterministic")

        // Frontline evenly spans dragged line facing enemy (+X -> ~0 rad)
        XCTAssertLessThan(abs(e1.units.targetY[0] - 180.0), 1.0)
        XCTAssertLessThan(abs(e1.units.targetY[1] - 420.0), 1.0)
        XCTAssertLessThan(abs(e1.units.facing[0]), 0.1)
    }

    func testAmmunitionHoldFireVolleyFatigueFlankingMoraleRoutingAndRally() {
        let world = Scenario1453.makeWorld()
        let inf = world.military.unit("infantry")!
        let arc = world.military.unit("archers")!
        let cav = world.military.unit("cavalry")!

        // 1. Hold Fire vs Volley ammo expenditure
        var engHold = makeTestBattleEngine(
            attRegiments: [Regiment(type: arc.id, origin: .professional, men: 1_000, morale: 2.8)],
            defRegiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)],
            playerSide: .attacker,
            seed: 555
        )
        _ = engHold.startBattle()
        engHold.units.posX[0] = 560.0; engHold.units.posY[0] = 400.0
        engHold.units.posX[1] = 740.0; engHold.units.posY[1] = 400.0
        engHold.issueStanceOrder(unitIndices: [0], stance: .holdFire)
        let ammoStart = engHold.units.ammo[0]
        engHold.stepTicks(15)
        XCTAssertEqual(engHold.units.ammo[0], ammoStart, "Hold Fire must conserve all ammunition")

        engHold.issueStanceOrder(unitIndices: [0], stance: .volley)
        engHold.stepTicks(25)
        XCTAssertLessThan(engHold.units.ammo[0], ammoStart, "Volley fire must consume ammunition")
        XCTAssertLessThan(engHold.units.men[1], 1_000, "Ranged volleys must deal casualties")

        // 2. Fatigue rises on long march/charge & recovers at rest
        var engFat = makeTestBattleEngine(
            attRegiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)],
            defRegiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)],
            playerSide: .attacker
        )
        _ = engFat.startBattle()
        engFat.issueStanceOrder(unitIndices: [0], stance: .charge)
        engFat.issueMoveOrder(unitIndices: [0], x: 520, y: 200)
        engFat.stepTicks(80)
        let marchedFatigue = engFat.units.fatigue[0]
        XCTAssertGreaterThan(marchedFatigue, 0.05)

        // 3. Rear flanking deals dramatically higher morale loss than frontal strike
        var flankSim = makeTestBattleEngine(
            attRegiments: [Regiment(type: cav.id, origin: .professional, men: 1_000, morale: 3.0)],
            defRegiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)],
            playerSide: .attacker
        )
        _ = flankSim.startBattle()
        let defMods = BattleCombat.modifiers(for: .line)
        let frontMult = BattleCombat.directionalMoraleMultiplier(attackerX: 100, attackerY: 400, target: 1, engine: flankSim, defMods: defMods)
        let rearMult = BattleCombat.directionalMoraleMultiplier(attackerX: 1100, attackerY: 400, target: 1, engine: flankSim, defMods: defMods)
        XCTAssertGreaterThan(rearMult, frontMult * 2.0, "Rear attack must inflict heavy morale shock multiplier")

        // Square resists cavalry & flanking far better than Line
        let sqMods = BattleCombat.modifiers(for: .square)
        let rearSqMult = BattleCombat.directionalMoraleMultiplier(attackerX: 1100, attackerY: 400, target: 1, engine: flankSim, defMods: sqMods)
        XCTAssertLessThan(sqMods.cavalryDamageTaken, 0.6)
        XCTAssertLessThan(rearSqMult, rearMult)

        // 4. Routing triggers at low morale and rallies once out of pursuit range while battle continues
        var rallyRoom = makeTestBattleEngine(
            attRegiments: [
                Regiment(type: inf.id, origin: .professional, men: 800, morale: 3.0),
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.5)
            ],
            defRegiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)],
            playerSide: .attacker
        )
        _ = rallyRoom.startBattle()
        rallyRoom.units.posX[0] = 650.0; rallyRoom.units.posY[0] = 200.0
        rallyRoom.units.posX[1] = 850.0; rallyRoom.units.posY[1] = 600.0
        rallyRoom.units.posX[2] = 1150.0; rallyRoom.units.posY[2] = 600.0
        rallyRoom.units.morale[0] = 0.10
        rallyRoom.stepTicks(1)
        XCTAssertEqual(rallyRoom.phase, .active)
        XCTAssertTrue(rallyRoom.units.isRouting[0], "Low morale triggers routing")
        rallyRoom.stepTicks(130)
        XCTAssertFalse(rallyRoom.units.isRouting[0], "Safe routed unit with intact strength should rally")
    }

    func testAIVsAITacticalMatchesAutoResolveRange() {
        var autoWorld = Scenario1453.makeWorld()
        guard let fra = autoWorld.countries.id(forTag: "FRA"),
              let eng = autoWorld.countries.id(forTag: "ENG"),
              let prov = autoWorld.provinces.ids.first(where: { autoWorld.provinces.terrain[$0.index] == .plains }) else {
            XCTFail("Missing scenario data")
            return
        }
        for aid in autoWorld.military.armies(in: prov) { autoWorld.military.armies.remove(aid) }
        let inf = autoWorld.military.unit("infantry")!
        let arc = autoWorld.military.unit("archers")!
        let cav = autoWorld.military.unit("cavalry")!

        // Decisive 2:1 advantage (6,000 FRA vs 3,000 ENG)
        let attRegs = [
            Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: arc.id, origin: .professional, men: 1_000, morale: 2.8),
            Regiment(type: cav.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: cav.id, origin: .professional, men: 1_000, morale: 3.0)
        ]
        let defRegs = [
            Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
            Regiment(type: arc.id, origin: .professional, men: 1_000, morale: 2.8)
        ]
        let aArmy = autoWorld.military.armies.append(name: "FRA AI", owner: fra, province: prov, regiments: attRegs)
        let dArmy = autoWorld.military.armies.append(name: "ENG AI", owner: eng, province: prov, regiments: defRegs)

        // 1. Auto-resolve outcome
        let autoSim = Simulation(world: autoWorld, startDate: Scenario1453.startDate, seed: 2026)
        for _ in 0..<25 {
            autoSim.tick()
            if !autoSim.world.military.recentBattles.isEmpty { break }
        }
        guard let autoRep = autoSim.world.military.recentBattles.last else {
            XCTFail("Auto-resolve did not conclude")
            return
        }

        // 2. Tactical AI-vs-AI outcome on identical armies (`playerSide == nil`)
        var tacEngine = makeTestBattleEngine(attRegiments: attRegs, defRegiments: defRegs, playerSide: nil, terrain: .plains, seed: 2026)
        tacEngine.stepTicks(1800)
        XCTAssertEqual(tacEngine.phase, .ended, "AI-vs-AI battle must finish within tick horizon")
        let tacWinnerCountry = tacEngine.winner == .attacker ? fra : eng
        XCTAssertEqual(tacWinnerCountry, autoRep.winner, "AI-vs-AI tactical winner must match auto-resolve for same armies")

        let autoAttLossRatio = Double(autoRep.attackerLosses) / 6000.0
        let tacAttLosses = tacEngine.units.totalInitialMen(on: .attacker) - tacEngine.units.totalMen(on: .attacker)
        let tacAttLossRatio = Double(tacAttLosses) / 6000.0
        XCTAssertLessThan(abs(tacAttLossRatio - autoAttLossRatio), 0.35, "Tactical casualty rate should be in the same range as auto-resolve (auto=\(autoAttLossRatio), tac=\(tacAttLossRatio))")
        _ = (aArmy, dArmy)
    }
}

