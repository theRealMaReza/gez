import Foundation

/// Pure-Swift tactical combat, formation geometry, stance behavior, morale/routing/rallying,
/// flanking, fatigue, and ammunition mechanics. Runs inside `BattleEngine`'s fixed 10 Hz tick.
public enum BattleCombat {

    public struct FormationModifiers {
        public let speed: Double
        public let attack: Double
        public let defence: Double
        public let rangedAttack: Double
        public let rangedIncoming: Double
        public let cavalryDamageTaken: Double
        public let artilleryDamageTaken: Double
        public let flankMoraleMultiplier: Double
        public let marchFatigueMultiplier: Double
    }

    public static func modifiers(for formation: BattleFormation, isWarWagon: Bool = false) -> FormationModifiers {
        switch formation {
        case .line:
            return FormationModifiers(
                speed: 1.0, attack: 1.0, defence: 1.0, rangedAttack: 1.0,
                rangedIncoming: 1.0, cavalryDamageTaken: 1.0, artilleryDamageTaken: 1.0,
                flankMoraleMultiplier: 1.0, marchFatigueMultiplier: 1.0
            )
        case .column:
            return FormationModifiers(
                speed: 1.35, attack: 0.75, defence: 0.78, rangedAttack: 0.70,
                rangedIncoming: 1.18, cavalryDamageTaken: 1.15, artilleryDamageTaken: 1.30,
                flankMoraleMultiplier: 1.20, marchFatigueMultiplier: 0.78
            )
        case .wedge:
            return FormationModifiers(
                speed: 1.14, attack: 1.32, defence: 0.90, rangedAttack: 0.85,
                rangedIncoming: 1.05, cavalryDamageTaken: 0.95, artilleryDamageTaken: 1.10,
                flankMoraleMultiplier: 1.15, marchFatigueMultiplier: 1.15
            )
        case .square:
            return FormationModifiers(
                speed: 0.36, attack: 0.88, defence: 1.15, rangedAttack: 0.85,
                rangedIncoming: 1.25, cavalryDamageTaken: 0.45, artilleryDamageTaken: 1.45,
                flankMoraleMultiplier: 0.35, marchFatigueMultiplier: 1.05
            )
        case .wagonLaager:
            return FormationModifiers(
                speed: isWarWagon ? 0.18 : 0.25, attack: 0.92, defence: 1.45, rangedAttack: 1.22,
                rangedIncoming: 0.62, cavalryDamageTaken: 0.40, artilleryDamageTaken: 1.15,
                flankMoraleMultiplier: 0.30, marchFatigueMultiplier: 0.65
            )
        case .skirmish:
            return FormationModifiers(
                speed: 1.20, attack: 0.76, defence: 0.78, rangedAttack: 1.12,
                rangedIncoming: 0.74, cavalryDamageTaken: 1.35, artilleryDamageTaken: 0.70,
                flankMoraleMultiplier: 0.85, marchFatigueMultiplier: 0.90
            )
        }
    }

    // MARK: - Orders

    public static func issueMoveOrder(engine: inout BattleEngine, unitIndices: [Int], x: Double, y: Double) {
        let clampedX = max(18.0, min(engine.battlefield.width - 18.0, x))
        let clampedY = max(18.0, min(engine.battlefield.height - 18.0, y))
        let valid = filterControllable(engine: engine, unitIndices: unitIndices)
        guard !valid.isEmpty else { return }

        // If multiple units ordered to one point, preserve relative offset or spread slightly around point
        let count = valid.count
        for (idxPos, u) in valid.enumerated() {
            let offsetRow = idxPos / 4
            let offsetCol = idxPos % 4
            let colCount = min(4, count)
            let latOffset = (Double(offsetCol) - Double(colCount - 1) * 0.5) * 44.0
            let depthOffset = Double(offsetRow) * 36.0
            let tx = max(20.0, min(engine.battlefield.width - 20.0, clampedX - depthOffset))
            let ty = max(20.0, min(engine.battlefield.height - 20.0, clampedY + latOffset))
            engine.units.targetX[u] = tx
            engine.units.targetY[u] = ty
            engine.units.waypoints[u] = []
            engine.units.targetUnit[u] = -1
            engine.units.hasMoveOrder[u] = true
            if engine.units.stance[u] == .retreat {
                engine.units.stance[u] = .hold
            }
        }
    }

    public static func issuePathOrder(engine: inout BattleEngine, unitIndices: [Int], points: [TacticalPoint]) {
        guard !points.isEmpty else { return }
        let clamped: [TacticalPoint] = points.map {
            TacticalPoint(
                x: max(18.0, min(engine.battlefield.width - 18.0, $0.x)),
                y: max(18.0, min(engine.battlefield.height - 18.0, $0.y))
            )
        }
        for u in filterControllable(engine: engine, unitIndices: unitIndices) {
            engine.units.waypoints[u] = clamped
            engine.units.targetX[u] = clamped[0].x
            engine.units.targetY[u] = clamped[0].y
            engine.units.targetUnit[u] = -1
            engine.units.hasMoveOrder[u] = true
            if engine.units.stance[u] == .retreat {
                engine.units.stance[u] = .hold
            }
        }
    }

    public static func issueFrontlineOrder(
        engine: inout BattleEngine,
        unitIndices: [Int],
        start: TacticalPoint,
        end: TacticalPoint
    ) {
        let valid = filterControllable(engine: engine, unitIndices: unitIndices)
        guard !valid.isEmpty else { return }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let segLen = sqrt(dx * dx + dy * dy)
        if segLen < 12.0 || valid.count == 1 {
            issueMoveOrder(engine: &engine, unitIndices: valid, x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
            return
        }

        // Frontline normal perpendicular to drag vector, biased toward the enemy side.
        var nx = -dy / segLen
        var ny = dx / segLen
        let uSide = engine.units.side[valid[0]]
        let enemyDirX = (uSide == .attacker) ? 1.0 : -1.0
        if nx * enemyDirX < 0.0 {
            nx = -nx
            ny = -ny
        }
        let targetFacing = atan2(ny, nx)

        for (k, u) in valid.enumerated() {
            let frac = Double(k) / Double(max(1, valid.count - 1))
            let px = max(20.0, min(engine.battlefield.width - 20.0, start.x + dx * frac))
            let py = max(20.0, min(engine.battlefield.height - 20.0, start.y + dy * frac))
            engine.units.targetX[u] = px
            engine.units.targetY[u] = py
            engine.units.waypoints[u] = []
            engine.units.targetUnit[u] = -1
            engine.units.hasMoveOrder[u] = true
            engine.units.facing[u] = targetFacing
            if engine.units.stance[u] == .retreat {
                engine.units.stance[u] = .hold
            }
        }
    }

    public static func issueAttackOrder(engine: inout BattleEngine, unitIndices: [Int], targetUnitIndex: Int) {
        guard targetUnitIndex >= 0, targetUnitIndex < engine.units.count, engine.units.men[targetUnitIndex] > 0 else {
            return
        }
        for u in filterControllable(engine: engine, unitIndices: unitIndices) {
            guard engine.units.side[u] != engine.units.side[targetUnitIndex] else { continue }
            engine.units.targetUnit[u] = targetUnitIndex
            engine.units.waypoints[u] = []
            engine.units.hasMoveOrder[u] = false
            if engine.units.stance[u] == .hold || engine.units.stance[u] == .retreat {
                let isRanged = engine.units.maxAmmo[u] > 0
                engine.units.stance[u] = isRanged ? .volley : .charge
            }
        }
    }

    public static func issueFormationOrder(engine: inout BattleEngine, unitIndices: [Int], formation: BattleFormation) {
        for u in filterControllable(engine: engine, unitIndices: unitIndices) {
            if formation == .wagonLaager && engine.units.unitKey[u] != "war_wagons" && engine.units.category[u] != .infantry {
                continue
            }
            engine.units.formation[u] = formation
            engine.units.updateFootprint(for: u)
        }
    }

    public static func issueStanceOrder(engine: inout BattleEngine, unitIndices: [Int], stance: BattleStance) {
        for u in filterControllable(engine: engine, unitIndices: unitIndices) {
            engine.units.stance[u] = stance
            if stance == .retreat {
                let edgeX = (engine.units.side[u] == .attacker) ? 14.0 : (engine.battlefield.width - 14.0)
                engine.units.targetX[u] = edgeX
                engine.units.targetY[u] = engine.units.posY[u]
                engine.units.waypoints[u] = []
                engine.units.targetUnit[u] = -1
                engine.units.hasMoveOrder[u] = true
            }
        }
    }

    public static func issueRetreatOrder(engine: inout BattleEngine, unitIndices: [Int]) {
        issueStanceOrder(engine: &engine, unitIndices: unitIndices, stance: .retreat)
    }

    private static func filterControllable(engine: BattleEngine, unitIndices: [Int]) -> [Int] {
        unitIndices.filter { u in
            u >= 0 && u < engine.units.count && engine.units.men[u] > 0 && !engine.units.isRouting[u]
        }
    }

    // MARK: - Fixed Tick Simulation

    public static func stepTick(engine: inout BattleEngine) {
        let uCount = engine.units.count
        if uCount == 0 {
            engine.phase = .ended
            return
        }

        // Clear transient melee links before recomputing proximity
        for i in 0..<uCount {
            engine.units.inMeleeWith[i] = -1
            if engine.units.fireCooldownTicks[i] > 0 { engine.units.fireCooldownTicks[i] -= 1 }
            if engine.units.rallyCooldownTicks[i] > 0 { engine.units.rallyCooldownTicks[i] -= 1 }
        }

        // 1. Movement & Stance Kinematics
        stepMovement(engine: &engine)

        // 2. Nearest Enemy Engagement & Ranged Fire
        stepRangedCombat(engine: &engine)

        // 3. Melee Shock Combat & Flanking Morale
        stepMeleeCombat(engine: &engine)

        // 4. Morale, Routing, Rallying, Fatigue Recovery & Withdrawal
        stepMoraleAndRouting(engine: &engine)

        // 5. Evaluate End Condition
        evaluateEndCondition(engine: &engine)
    }

    // MARK: - Movement

    private static func stepMovement(engine: inout BattleEngine) {
        let width = engine.battlefield.width
        let height = engine.battlefield.height
        let dt = BattleEngine.dt

        for i in 0..<engine.units.count {
            guard engine.units.men[i] > 0 else { continue }

            // Routing units flee straight to their friendly map edge
            if engine.units.isRouting[i] {
                let exitX = engine.units.side[i] == .attacker ? 6.0 : (width - 6.0)
                let fleeY = max(25.0, min(height - 25.0, engine.units.posY[i]))
                moveUnitToward(engine: &engine, index: i, destX: exitX, destY: fleeY, speedScale: 1.22, dt: dt)
                continue
            }

            let stance = engine.units.stance[i]
            let mods = modifiers(for: engine.units.formation[i], isWarWagon: engine.units.unitKey[i] == "war_wagons")
            let fatigueMult = max(0.62, 1.0 - engine.units.fatigue[i] * 0.35)

            // Follow target unit if pursuing in Attack/Charge/Advance
            if engine.units.targetUnit[i] >= 0 {
                let t = engine.units.targetUnit[i]
                if t >= engine.units.count || engine.units.men[t] <= 0 || engine.units.isRouting[t] && stance == .hold {
                    engine.units.targetUnit[i] = -1
                } else {
                    let dx = engine.units.posX[t] - engine.units.posX[i]
                    let dy = engine.units.posY[t] - engine.units.posY[i]
                    let dist = sqrt(dx * dx + dy * dy)
                    let desiredRange = desiredEngagementRange(engine: engine, unit: i)
                    if dist > desiredRange {
                        let spdScale = stance == .charge ? 1.25 : 1.0
                        moveUnitToward(
                            engine: &engine,
                            index: i,
                            destX: engine.units.posX[t],
                            destY: engine.units.posY[t],
                            speedScale: mods.speed * fatigueMult * spdScale,
                            dt: dt
                        )
                    } else {
                        engine.units.facing[i] = atan2(dy, dx)
                        engine.units.velX[i] = 0
                        engine.units.velY[i] = 0
                    }
                    continue
                }
            }

            // Explicit waypoint / move order
            if engine.units.hasMoveOrder[i] {
                let destX: Double
                let destY: Double
                if !engine.units.waypoints[i].isEmpty {
                    destX = engine.units.waypoints[i][0].x
                    destY = engine.units.waypoints[i][0].y
                } else {
                    destX = engine.units.targetX[i]
                    destY = engine.units.targetY[i]
                }
                let spdScale = stance == .charge ? 1.25 : (stance == .retreat ? 1.08 : 1.0)
                let arrived = moveUnitToward(
                    engine: &engine,
                    index: i,
                    destX: destX,
                    destY: destY,
                    speedScale: mods.speed * fatigueMult * spdScale,
                    dt: dt
                )
                if arrived {
                    if !engine.units.waypoints[i].isEmpty {
                        engine.units.waypoints[i].removeFirst()
                    }
                    if engine.units.waypoints[i].isEmpty {
                        engine.units.hasMoveOrder[i] = false
                    }
                }
                continue
            }

            // Autonomous Advance / Charge behavior if no explicit move target
            if stance == .advance || stance == .charge {
                if let enemy = nearestActiveEnemy(engine: engine, from: i) {
                    let dx = engine.units.posX[enemy] - engine.units.posX[i]
                    let dy = engine.units.posY[enemy] - engine.units.posY[i]
                    let dist = sqrt(dx * dx + dy * dy)
                    let desiredRange = (stance == .charge) ? 24.0 : desiredEngagementRange(engine: engine, unit: i)
                    if dist > desiredRange {
                        let spdScale = stance == .charge ? 1.25 : 0.95
                        moveUnitToward(
                            engine: &engine,
                            index: i,
                            destX: engine.units.posX[enemy],
                            destY: engine.units.posY[enemy],
                            speedScale: mods.speed * fatigueMult * spdScale,
                            dt: dt
                        )
                    } else {
                        engine.units.facing[i] = atan2(dy, dx)
                        engine.units.velX[i] = 0
                        engine.units.velY[i] = 0
                    }
                    continue
                }
            }

            // Resting / Holding: slow velocity & recover fatigue
            engine.units.velX[i] = 0
            engine.units.velY[i] = 0
            engine.units.fatigue[i] = max(0.0, engine.units.fatigue[i] - 0.014 * dt)
        }
    }

    @discardableResult
    private static func moveUnitToward(
        engine: inout BattleEngine,
        index i: Int,
        destX: Double,
        destY: Double,
        speedScale: Double,
        dt: Double
    ) -> Bool {
        let dx = destX - engine.units.posX[i]
        let dy = destY - engine.units.posY[i]
        let dist = sqrt(dx * dx + dy * dy)
        let terrainMult = engine.battlefield.movementSpeedMultiplier(
            at: engine.units.posX[i],
            engine.units.posY[i],
            category: engine.units.category[i]
        )
        let mods = modifiers(for: engine.units.formation[i], isWarWagon: engine.units.unitKey[i] == "war_wagons")
        let step = engine.units.baseSpeed[i] * terrainMult * speedScale * dt

        if dist <= max(2.5, step) {
            engine.units.posX[i] = max(10.0, min(engine.battlefield.width - 10.0, destX))
            engine.units.posY[i] = max(10.0, min(engine.battlefield.height - 10.0, destY))
            engine.units.velX[i] = 0
            engine.units.velY[i] = 0
            return true
        }
        let nx = dx / dist
        let ny = dy / dist
        engine.units.posX[i] = max(10.0, min(engine.battlefield.width - 10.0, engine.units.posX[i] + nx * step))
        engine.units.posY[i] = max(10.0, min(engine.battlefield.height - 10.0, engine.units.posY[i] + ny * step))
        engine.units.velX[i] = nx * step / dt
        engine.units.velY[i] = ny * step / dt
        engine.units.facing[i] = atan2(ny, nx)

        // Marching accumulates fatigue (scaled by formation & stance)
        let stanceMult = engine.units.stance[i] == .charge ? 1.85 : 1.0
        engine.units.fatigue[i] = min(1.0, engine.units.fatigue[i] + 0.018 * mods.marchFatigueMultiplier * stanceMult * dt)
        return false
    }

    // MARK: - Ranged Combat & Ammunition

    public static func weaponRange(unitKey: String, category: UnitCategory, heightDiff: Double) -> Double {
        let base: Double
        switch category {
        case .artillery: base = 420.0
        case .ranged:
            if unitKey == "longbowmen" { base = 250.0 }
            else if unitKey == "handgunners" { base = 170.0 }
            else { base = 215.0 }
        case .cavalry:
            base = (unitKey == "horse_archers") ? 190.0 : 0.0
        case .infantry:
            base = (unitKey == "war_wagons") ? 165.0 : 0.0
        }
        guard base > 0 else { return 0.0 }
        // Elevation extends effective range slightly
        return base + max(-25.0, min(55.0, heightDiff * 1.4))
    }

    private static func desiredEngagementRange(engine: BattleEngine, unit i: Int) -> Double {
        if engine.units.maxAmmo[i] > 0 && engine.units.ammo[i] > 0 && engine.units.stance[i] != .charge {
            let r = weaponRange(unitKey: engine.units.unitKey[i], category: engine.units.category[i], heightDiff: 0.0)
            if r > 0 { return r * 0.85 }
        }
        return 26.0
    }

    private static func stepRangedCombat(engine: inout BattleEngine) {
        let uCount = engine.units.count
        for i in 0..<uCount {
            guard engine.units.men[i] > 0, !engine.units.isRouting[i] else { continue }
            guard engine.units.ammo[i] > 0 else { continue }
            guard engine.units.stance[i] != .holdFire, engine.units.stance[i] != .retreat else { continue }
            guard engine.units.fireCooldownTicks[i] == 0 else { continue }
            guard engine.units.inMeleeWith[i] < 0 else { continue }

            // Check explicit target first, else nearest enemy in range
            var target = -1
            let explicit = engine.units.targetUnit[i]
            if explicit >= 0, explicit < uCount, engine.units.men[explicit] > 0, engine.units.side[explicit] != engine.units.side[i] {
                target = explicit
            } else {
                target = nearestActiveEnemy(engine: engine, from: i, includeRouting: true) ?? -1
            }
            guard target >= 0 else { continue }

            let dx = engine.units.posX[target] - engine.units.posX[i]
            let dy = engine.units.posY[target] - engine.units.posY[i]
            let dist = sqrt(dx * dx + dy * dy)
            let elevI = engine.battlefield.elevation(at: engine.units.posX[i], engine.units.posY[i])
            let elevT = engine.battlefield.elevation(at: engine.units.posX[target], engine.units.posY[target])
            let range = weaponRange(unitKey: engine.units.unitKey[i], category: engine.units.category[i], heightDiff: elevI - elevT)
            guard dist > 28.0 && dist <= range else { continue }

            // Artillery cannot fire while moving rapidly unless deployed
            if engine.units.category[i] == .artillery && engine.units.hasMoveOrder[i] { continue }

            // Consume 1 ammo & set fire cooldown
            engine.units.ammo[i] = max(0, engine.units.ammo[i] - 1)
            engine.units.facing[i] = atan2(dy, dx)
            let baseCooldown: Int
            switch engine.units.category[i] {
            case .artillery: baseCooldown = 36
            case .ranged: baseCooldown = engine.units.unitKey[i] == "handgunners" ? 26 : 18
            default: baseCooldown = 20
            }
            let volleyMult = (engine.units.stance[i] == .volley) ? 0.80 : 1.0
            engine.units.fireCooldownTicks[i] = max(10, Int((Double(baseCooldown) * volleyMult).rounded()))

            // Compute ranged damage matching auto-resolve BattleModel fire stats
            let atkMods = modifiers(for: engine.units.formation[i], isWarWagon: engine.units.unitKey[i] == "war_wagons")
            let defMods = modifiers(for: engine.units.formation[target], isWarWagon: engine.units.unitKey[target] == "war_wagons")
            let menRatio = Double(engine.units.men[i]) / Double(max(1, engine.units.maxMen[i]))
            let fireMult = BattleModel.fireMultiplier(unitKey: engine.units.unitKey[i], category: engine.units.category[i])
            let sideDisc = engine.units.side[i] == .attacker ? engine.attackerDiscipline : engine.defenderDiscipline
            let targetDisc = engine.units.side[target] == .attacker ? engine.attackerDiscipline : engine.defenderDiscipline
            let cmdMartial = (engine.units.side[i] == .attacker ? engine.attackerCommander?.martial : engine.defenderCommander?.martial) ?? 0
            let cmdMult = 1.0 + Double(cmdMartial / 3) * 0.06
            let fatigueFactor = max(0.65, 1.0 - engine.units.fatigue[i] * 0.30)
            let elevFactor = max(0.75, min(1.30, 1.0 + (elevI - elevT) * 0.012))
            let distFactor = max(0.55, 1.10 - 0.45 * (dist / max(1.0, range)))
            let coverReduction = engine.battlefield.rangedCoverReduction(at: engine.units.posX[target], engine.units.posY[target])
            let formIncoming = engine.units.category[i] == .artillery ? defMods.artilleryDamageTaken : defMods.rangedIncoming
            let rngRoll = Double.random(in: 0.85...1.15, using: &engine.random)

            let mitigation = 10.0 / (5.0 + engine.units.defence[target] * defMods.defence * targetDisc)
            let rawPower = menRatio * engine.units.attack[i] * fireMult * atkMods.rangedAttack * sideDisc * cmdMult * fatigueFactor * elevFactor * distFactor * rngRoll
            let casualties = max(1, Int((rawPower * mitigation * formIncoming * (1.0 - coverReduction) * 4.2).rounded()))
            let actualCas = min(engine.units.men[target], casualties)

            engine.units.men[target] -= actualCas
            engine.units.kills[i] += actualCas

            // Ranged & especially artillery / gunfire hurts morale
            let flankMult = directionalMoraleMultiplier(attackerX: engine.units.posX[i], attackerY: engine.units.posY[i], target: target, engine: engine, defMods: defMods)
            let moraleHit = (Double(actualCas) / Double(max(50, engine.units.initialMen[target]))) * 0.70 * flankMult * (engine.units.category[i] == .artillery ? 1.45 : 1.0)
            engine.units.morale[target] = max(0.0, engine.units.morale[target] - moraleHit)
        }
    }

    // MARK: - Melee Shock Combat & Flanking

    private static func stepMeleeCombat(engine: inout BattleEngine) {
        let uCount = engine.units.count
        let contactDist = 34.0
        let contactDist2 = contactDist * contactDist

        // Determine close-quarters pairs deterministically
        for i in 0..<uCount {
            guard engine.units.men[i] > 0, !engine.units.isRouting[i] else { continue }
            var bestEnemy = -1
            var bestD2 = contactDist2
            for j in 0..<uCount where engine.units.side[j] != engine.units.side[i] && engine.units.men[j] > 0 {
                let dx = engine.units.posX[j] - engine.units.posX[i]
                let dy = engine.units.posY[j] - engine.units.posY[i]
                let d2 = dx * dx + dy * dy
                if d2 <= bestD2 {
                    bestD2 = d2
                    bestEnemy = j
                }
            }
            if bestEnemy >= 0 {
                engine.units.inMeleeWith[i] = bestEnemy
                engine.units.hasMoveOrder[i] = false
                engine.units.velX[i] = 0
                engine.units.velY[i] = 0
                engine.units.fatigue[i] = min(1.0, engine.units.fatigue[i] + 0.032 * BattleEngine.dt)
            }
        }

        // Apply melee exchanges every 5 ticks (0.5s) for clean readability and pacing
        guard engine.tickCount % 5 == 0 else { return }

        var pendingCas = [Int](repeating: 0, count: uCount)
        var pendingMoraleLoss = [Double](repeating: 0.0, count: uCount)

        for i in 0..<uCount {
            let j = engine.units.inMeleeWith[i]
            guard j >= 0, engine.units.men[i] > 0, engine.units.men[j] > 0 else { continue }

            let atkMods = modifiers(for: engine.units.formation[i], isWarWagon: engine.units.unitKey[i] == "war_wagons")
            let defMods = modifiers(for: engine.units.formation[j], isWarWagon: engine.units.unitKey[j] == "war_wagons")

            let shockMult = BattleModel.shockMultiplier(unitKey: engine.units.unitKey[i], category: engine.units.category[i])
            let menRatio = Double(engine.units.men[i]) / Double(max(1, engine.units.maxMen[i]))
            let sideDisc = engine.units.side[i] == .attacker ? engine.attackerDiscipline : engine.defenderDiscipline
            let targetDisc = engine.units.side[j] == .attacker ? engine.attackerDiscipline : engine.defenderDiscipline
            let cmdMartial = (engine.units.side[i] == .attacker ? engine.attackerCommander?.martial : engine.defenderCommander?.martial) ?? 0
            let cmdMult = 1.0 + Double(cmdMartial / 3) * 0.06
            let fatigueFactor = max(0.60, 1.0 - engine.units.fatigue[i] * 0.35)
            let chargeFactor = engine.units.stance[i] == .charge ? 1.25 : 1.0

            // Terrain/elevation & water penalties matching BattleModel
            let elevI = engine.battlefield.elevation(at: engine.units.posX[i], engine.units.posY[i])
            let elevJ = engine.battlefield.elevation(at: engine.units.posX[j], engine.units.posY[j])
            var terrainFactor = max(0.72, min(1.28, 1.0 + (elevI - elevJ) * 0.012))
            let waterI = engine.battlefield.riverState(at: engine.units.posX[i], engine.units.posY[i])
            if waterI.inWater { terrainFactor *= 0.65 } else if waterI.isFord { terrainFactor *= 0.88 }
            if engine.units.category[i] == .cavalry && engine.battlefield.isForest(at: engine.units.posX[i], engine.units.posY[i]) {
                terrainFactor *= 0.70
            }

            // Directional flanking/rear detection
            let flankCasMult = directionalCasualtyMultiplier(attackerX: engine.units.posX[i], attackerY: engine.units.posY[i], target: j, engine: engine, defMods: defMods)
            let flankMoraleMult = directionalMoraleMultiplier(attackerX: engine.units.posX[i], attackerY: engine.units.posY[i], target: j, engine: engine, defMods: defMods)

            // Cavalry vs Square / Wagon-Laager mitigation & pursuing routing penalty
            var specialDef = 1.0
            if engine.units.category[i] == .cavalry {
                specialDef *= defMods.cavalryDamageTaken
            }
            if engine.units.isRouting[j] {
                specialDef *= 1.45 // Pursuing routing troops inflicts extra casualties
            }

            let rngRoll = Double.random(in: 0.85...1.15, using: &engine.random)
            let mitigation = 10.0 / (5.0 + engine.units.defence[j] * defMods.defence * targetDisc)
            let rawPower = menRatio * engine.units.attack[i] * shockMult * atkMods.attack * sideDisc * cmdMult * fatigueFactor * chargeFactor * terrainFactor * rngRoll
            let cas = max(1, Int((rawPower * mitigation * flankCasMult * specialDef * 2.8).rounded()))

            pendingCas[j] += cas
            engine.units.kills[i] += min(engine.units.men[j], cas)

            let ratioLoss = Double(cas) / Double(max(50, engine.units.initialMen[j]))
            let mLoss = ratioLoss * 0.82 * flankMoraleMult * (1.0 + engine.units.fatigue[j] * 0.25)
            pendingMoraleLoss[j] += mLoss
        }

        for k in 0..<uCount where engine.units.men[k] > 0 {
            if pendingCas[k] > 0 {
                engine.units.men[k] = max(0, engine.units.men[k] - pendingCas[k])
            }
            if pendingMoraleLoss[k] > 0 {
                engine.units.morale[k] = max(0.0, engine.units.morale[k] - pendingMoraleLoss[k])
            }
        }
    }

    /// Angle between defender's forward vector and incoming threat direction -> casualty multiplier.
    public static func directionalCasualtyMultiplier(
        attackerX: Double,
        attackerY: Double,
        target j: Int,
        engine: BattleEngine,
        defMods: FormationModifiers
    ) -> Double {
        let angleToAttacker = atan2(attackerY - engine.units.posY[j], attackerX - engine.units.posX[j])
        var diff = abs(angleToAttacker - engine.units.facing[j])
        while diff > Double.pi { diff = abs(diff - 2.0 * Double.pi) }
        if diff > Double.pi * 0.72 { // Rear (>130 deg)
            return 1.0 + 0.55 * defMods.flankMoraleMultiplier
        } else if diff > Double.pi * 0.34 { // Flank (>61 deg)
            return 1.0 + 0.28 * defMods.flankMoraleMultiplier
        }
        return 1.0
    }

    public static func directionalMoraleMultiplier(
        attackerX: Double,
        attackerY: Double,
        target j: Int,
        engine: BattleEngine,
        defMods: FormationModifiers
    ) -> Double {
        let angleToAttacker = atan2(attackerY - engine.units.posY[j], attackerX - engine.units.posX[j])
        var diff = abs(angleToAttacker - engine.units.facing[j])
        while diff > Double.pi { diff = abs(diff - 2.0 * Double.pi) }
        if diff > Double.pi * 0.72 {
            return 1.0 + 1.50 * defMods.flankMoraleMultiplier
        } else if diff > Double.pi * 0.34 {
            return 1.0 + 0.85 * defMods.flankMoraleMultiplier
        }
        return 1.0
    }

    // MARK: - Morale, Routing, Rallying

    private static func stepMoraleAndRouting(engine: inout BattleEngine) {
        let uCount = engine.units.count
        let width = engine.battlefield.width
        let dt = BattleEngine.dt

        // Precompute nearby friendly intact count for passive cohesion
        for i in 0..<uCount {
            let men = engine.units.men[i]
            if men <= 0 { continue }

            let martial = (engine.units.side[i] == .attacker ? engine.attackerCommander?.martial : engine.defenderCommander?.martial) ?? 0
            let rallyBonus = 1.0 + Double(martial) * 0.04

            if !engine.units.isRouting[i] {
                if engine.units.morale[i] <= 0.15 {
                    engine.units.isRouting[i] = true
                    engine.units.rallyCooldownTicks[i] = 45 // 4.5s minimum rout before possible rally
                    engine.units.targetUnit[i] = -1
                    engine.units.hasMoveOrder[i] = false
                } else if engine.units.inMeleeWith[i] < 0 {
                    // Slight morale stabilization out of melee
                    let rec = 0.020 * rallyBonus * dt
                    engine.units.morale[i] = min(engine.units.maxMorale[i], engine.units.morale[i] + rec)
                }
            } else {
                // Check if unit reached edge -> withdrawn/left battlefield
                if engine.units.posX[i] <= 18.0 || engine.units.posX[i] >= width - 18.0 {
                    // Preserve surviving men & low morale on table? Wait: withdrawing unit leaves fighting (mark targetUnit = -1, keep men intact for Part D survivors!)
                    // Wait: stop moving once at edge and stay withdrawn (isRouting == true at edge counts as exited).
                    engine.units.velX[i] = 0
                    engine.units.velY[i] = 0
                    continue
                }

                // Attempt rally if not closely pursued and enough men left
                let nearestEnemyDist = nearestEnemyDistance(engine: engine, from: i)
                let minMenForRally = max(50, engine.units.initialMen[i] / 6)
                if engine.units.rallyCooldownTicks[i] == 0 && nearestEnemyDist > 125.0 && men >= minMenForRally {
                let rec = 0.16 * rallyBonus * dt
                engine.units.morale[i] = min(engine.units.maxMorale[i], engine.units.morale[i] + rec)
                if engine.units.morale[i] >= engine.units.maxMorale[i] * 0.38 {
                    engine.units.isRouting[i] = false
                    engine.units.stance[i] = .hold
                }
                }
            }
        }
    }

    private static func evaluateEndCondition(engine: inout BattleEngine) {
        let attActive = engine.units.activeUnits(on: .attacker)
        let defActive = engine.units.activeUnits(on: .defender)

        if attActive == 0 || defActive == 0 || engine.tickCount >= 1800 {
            engine.phase = .ended
            if defActive == 0 && attActive > 0 {
                engine.winner = .attacker
            } else if attActive == 0 && defActive > 0 {
                engine.winner = .defender
            } else {
                let attMen = engine.units.totalMen(on: .attacker)
                let defMen = engine.units.totalMen(on: .defender)
                engine.winner = (attMen >= defMen) ? .attacker : .defender
            }
            if let win = engine.winner {
                let loserSide = win.opposite
                let loserInit = max(1, engine.units.totalInitialMen(on: loserSide))
                let loserLeft = engine.units.totalMen(on: loserSide)
                engine.wasStackwipe = (Double(loserLeft) / Double(loserInit)) < 0.10
            }
        }
    }

    // MARK: - Spatial Queries

    public static func nearestActiveEnemy(engine: BattleEngine, from i: Int, includeRouting: Bool = false) -> Int? {
        let mySide = engine.units.side[i]
        let mx = engine.units.posX[i]
        let my = engine.units.posY[i]
        var best = -1
        var bestD2 = Double.infinity
        for j in 0..<engine.units.count where engine.units.side[j] != mySide && engine.units.men[j] > 0 {
            if !includeRouting && engine.units.isRouting[j] { continue }
            let dx = engine.units.posX[j] - mx
            let dy = engine.units.posY[j] - my
            let d2 = dx * dx + dy * dy
            if d2 < bestD2 {
                bestD2 = d2
                best = j
            }
        }
        return best >= 0 ? best : nil
    }

    private static func nearestEnemyDistance(engine: BattleEngine, from i: Int) -> Double {
        guard let j = nearestActiveEnemy(engine: engine, from: i, includeRouting: false) else {
            return 9999.0
        }
        let dx = engine.units.posX[j] - engine.units.posX[i]
        let dy = engine.units.posY[j] - engine.units.posY[i]
        return sqrt(dx * dx + dy * dy)
    }
}
