import Foundation

/// Deterministic tactical AI for any AI-controlled side in `BattleEngine`
/// (and both sides when calibrating against auto-resolve with `playerSide == nil`).
public enum BattleAI {

    /// Re-evaluates tactical orders for AI-controlled regiments once per battle second (`tickCount % 10 == 1`).
    public static func update(engine: inout BattleEngine) {
        guard engine.phase == .active else { return }
        guard engine.tickCount % BattleEngine.ticksPerSecond == 1 else { return }

        if engine.playerSide != .attacker {
            updateSide(.attacker, engine: &engine)
        }
        if engine.playerSide != .defender {
            updateSide(.defender, engine: &engine)
        }
    }

    private static func updateSide(_ side: BattleSide, engine: inout BattleEngine) {
        if engine.isAssault {
            updateAssaultSide(side, engine: &engine)
            return
        }

        let ownInit = max(1, engine.units.totalInitialMen(on: side))
        let ownMen = engine.units.totalMen(on: side)
        let enemyMen = engine.units.totalMen(on: side.opposite)
        let ownMorale = engine.units.averageMorale(on: side)

        // General army retreat check when severely beaten & losing morale
        let lossFrac = 1.0 - (Double(ownMen) / Double(ownInit))
        let heavilyOutnumbered = ownMen * 2 < enemyMen
        if (lossFrac > 0.65 && ownMorale < 0.70) || (heavilyOutnumbered && ownMorale < 0.45 && engine.tickCount > 100) {
            let activeIds = (0..<engine.units.count).filter {
                engine.units.side[$0] == side && engine.units.men[$0] > 0 && !engine.units.isRouting[$0]
            }
            BattleCombat.issueRetreatOrder(engine: &engine, unitIndices: activeIds)
            return
        }

        // Evaluate whether this AI side prefers holding favorable terrain initially
        let bf = engine.battlefield
        let isDefending = (side == .defender)
        let favorableTerrain = bf.terrain == .mountains || bf.terrain == .hills || bf.isRiverCrossing
        let holdEarlyDefensiveLine = isDefending && favorableTerrain && engine.tickCount < 220

        for i in 0..<engine.units.count {
            guard engine.units.side[i] == side,
                  engine.units.men[i] > 0,
                  !engine.units.isRouting[i],
                  engine.units.stance[i] != .retreat else { continue }

            guard let target = BattleCombat.nearestActiveEnemy(engine: engine, from: i) else { continue }
            let dx = engine.units.posX[target] - engine.units.posX[i]
            let dy = engine.units.posY[target] - engine.units.posY[i]
            let dist = sqrt(dx * dx + dy * dy)
            let cat = engine.units.category[i]
            let key = engine.units.unitKey[i]

            if key == "war_wagons" {
                engine.units.formation[i] = .wagonLaager
                engine.units.updateFootprint(for: i)
                engine.units.stance[i] = dist <= 165.0 ? .volley : .hold
                engine.units.targetUnit[i] = target
                continue
            }

            switch cat {
            case .artillery:
                engine.units.formation[i] = .line
                engine.units.stance[i] = .volley
                engine.units.targetUnit[i] = target

            case .ranged:
                // Step back briefly if enemy melee closes within danger zone
                if dist < 68.0 && engine.units.inMeleeWith[i] < 0 {
                    let backX = side == .attacker ? max(40.0, engine.units.posX[i] - 90.0) : min(bf.width - 40.0, engine.units.posX[i] + 90.0)
                    engine.units.targetX[i] = backX
                    engine.units.targetY[i] = engine.units.posY[i]
                    engine.units.hasMoveOrder[i] = true
                    engine.units.stance[i] = .hold
                    engine.units.formation[i] = .skirmish
                } else if engine.units.ammo[i] > 0 {
                    engine.units.formation[i] = .skirmish
                    engine.units.stance[i] = holdEarlyDefensiveLine ? .volley : (dist <= 200.0 ? .volley : .advance)
                    engine.units.targetUnit[i] = target
                } else {
                    engine.units.formation[i] = .line
                    engine.units.stance[i] = .advance
                    engine.units.targetUnit[i] = target
                }
                engine.units.updateFootprint(for: i)

            case .cavalry:
                if key == "horse_archers" && engine.units.ammo[i] > 0 {
                    engine.units.formation[i] = .skirmish
                    engine.units.stance[i] = dist <= 170.0 ? .volley : .advance
                    engine.units.targetUnit[i] = target
                    engine.units.updateFootprint(for: i)
                    continue
                }
                // Flank via upper or lower wing before charging into enemy rear/flank
                let onWing = engine.units.posY[i] < bf.height * 0.28 || engine.units.posY[i] > bf.height * 0.72
                if dist > 160.0 && !onWing {
                    let targetY = engine.units.posY[i] < bf.height * 0.5 ? (bf.height * 0.16) : (bf.height * 0.84)
                    let forwardX = side == .attacker
                        ? min(bf.width - 140.0, engine.units.posX[i] + 180.0)
                        : max(140.0, engine.units.posX[i] - 180.0)
                    engine.units.targetX[i] = forwardX
                    engine.units.targetY[i] = targetY
                    engine.units.hasMoveOrder[i] = true
                    engine.units.formation[i] = .column
                    engine.units.stance[i] = .advance
                } else {
                    engine.units.formation[i] = .wedge
                    engine.units.stance[i] = .charge
                    engine.units.targetUnit[i] = target
                }
                engine.units.updateFootprint(for: i)

            case .infantry:
                if holdEarlyDefensiveLine && dist > 130.0 {
                    // Brace in line (or square if threatened closely by cavalry)
                    let enemyIsCavalry = engine.units.category[target] == .cavalry && dist < 110.0
                    engine.units.formation[i] = enemyIsCavalry ? .square : .line
                    engine.units.stance[i] = .hold
                } else {
                    engine.units.formation[i] = dist < 85.0 ? .line : (dist > 260.0 ? .column : .line)
                    engine.units.stance[i] = dist < 90.0 ? .charge : .advance
                    engine.units.targetUnit[i] = target
                }
                engine.units.updateFootprint(for: i)
            }
        }
    }

    private static func updateAssaultSide(_ side: BattleSide, engine: inout BattleEngine) {
        let kz = engine.battlefield.keepZone ?? TacticalRect(x: 965.0, y: 290.0, width: 165.0, height: 220.0)
        let firstBreach = engine.structures.first(where: { $0.kind != .keep && $0.breached })

        if side == .defender {
            // Garrison holds ramparts and intercepts climbers or attackers pouring through breaches/into keep.
            for i in 0..<engine.units.count {
                guard engine.units.side[i] == .defender,
                      engine.units.men[i] > 0,
                      !engine.units.isRouting[i],
                      engine.units.stance[i] != .retreat else { continue }

                if engine.units.isOnWall[i] {
                    engine.units.stance[i] = .volley
                    if let target = BattleCombat.nearestActiveEnemy(engine: engine, from: i) {
                        engine.units.targetUnit[i] = target
                    }
                    continue
                }

                // Interior reserve: intercept enemies already inside bailey (>760) or guard keep entrance
                if let enemyInside = (0..<engine.units.count).first(where: {
                    engine.units.side[$0] == .attacker && engine.units.men[$0] > 0 && !engine.units.isRouting[$0] && engine.units.posX[$0] > 760.0
                }) {
                    engine.units.targetUnit[i] = enemyInside
                    engine.units.stance[i] = .charge
                } else {
                    engine.units.targetX[i] = kz.minX - 24.0
                    engine.units.targetY[i] = kz.centerY
                    engine.units.hasMoveOrder[i] = true
                    engine.units.stance[i] = .hold
                }
            }
            return
        }

        // Attacker AI in assault mode
        for i in 0..<engine.units.count {
            guard engine.units.side[i] == .attacker,
                  engine.units.men[i] > 0,
                  !engine.units.isRouting[i],
                  engine.units.stance[i] != .retreat else { continue }

            let cat = engine.units.category[i]
            let px = engine.units.posX[i]
            let alreadyInside = px > 784.0

            if cat == .artillery {
                if let intact = engine.structures.first(where: { ($0.kind == .gate || $0.kind == .wall) && !$0.breached }), engine.units.ammo[i] > 0 {
                    engine.units.targetStructure[i] = intact.id
                    engine.units.targetUnit[i] = -1
                    engine.units.stance[i] = .volley
                } else if let target = BattleCombat.nearestActiveEnemy(engine: engine, from: i) {
                    engine.units.targetStructure[i] = -1
                    engine.units.targetUnit[i] = target
                    engine.units.stance[i] = .volley
                }
                continue
            }

            if alreadyInside {
                // Once past walls, push toward keep or nearest defender blocking the keep
                if let target = BattleCombat.nearestActiveEnemy(engine: engine, from: i) {
                    let tDist = DetMath.length(engine.units.posX[target] - px, engine.units.posY[target] - engine.units.posY[i])
                    if tDist < 120.0 {
                        engine.units.targetUnit[i] = target
                        engine.units.stance[i] = cat == .ranged && engine.units.ammo[i] > 0 ? .volley : .charge
                        continue
                    }
                }
                engine.units.targetUnit[i] = -1
                engine.units.targetStructure[i] = -1
                engine.units.targetX[i] = kz.centerX
                engine.units.targetY[i] = kz.centerY
                engine.units.hasMoveOrder[i] = true
                engine.units.stance[i] = .advance
                continue
            }

            if cat == .cavalry {
                if let breach = firstBreach {
                    engine.units.targetUnit[i] = -1
                    engine.units.targetX[i] = breach.x + 120.0
                    engine.units.targetY[i] = breach.y
                    engine.units.hasMoveOrder[i] = true
                    engine.units.formation[i] = .wedge
                    engine.units.stance[i] = .charge
                } else {
                    engine.units.targetX[i] = 630.0
                    engine.units.targetY[i] = engine.units.posY[i]
                    engine.units.hasMoveOrder[i] = true
                    engine.units.stance[i] = .hold
                }
                continue
            }

            if cat == .ranged && engine.units.ammo[i] > 0 {
                if let target = BattleCombat.nearestActiveEnemy(engine: engine, from: i) {
                    engine.units.targetUnit[i] = target
                    engine.units.stance[i] = .volley
                }
                continue
            }

            // Infantry: if a breach exists, funnel into breach (unless holding intact gate target with ram)
            if engine.units.siegeEquipment[i] == .ram {
                if let gate = engine.structures.first(where: { $0.kind == .gate && !$0.breached }) {
                    engine.units.targetStructure[i] = gate.id
                    engine.units.stance[i] = .advance
                    continue
                } else {
                    engine.units.siegeEquipment[i] = .none
                }
            }
            if let breach = firstBreach {
                engine.units.targetStructure[i] = -1
                engine.units.targetUnit[i] = -1
                engine.units.targetX[i] = breach.x + 80.0
                engine.units.targetY[i] = breach.y
                engine.units.hasMoveOrder[i] = true
                engine.units.stance[i] = .advance
            } else if engine.units.siegeEquipment[i] == .ladders,
                      let intactWall = engine.structures.first(where: { $0.kind == .wall && !$0.breached }) {
                engine.units.targetStructure[i] = intactWall.id
                engine.units.stance[i] = .advance
            }
        }
    }
}
