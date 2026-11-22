import Foundation

/// Writes tactical battle & siege assault outcomes (survivors, morale, levy pops,
/// commanders, breaches, garrisons, war score, and fort captures) back into the campaign `World`.
public enum BattleWriteBack {

    /// Computes a preview summary without mutating `world` (useful for displaying the Result Panel
    /// before closing the battle screen). Wait: commander fate is resolved deterministically on apply.
    public static func previewResult(engine: BattleEngine) -> TacticalBattleResult {
        let winnerSide = engine.winner ?? .defender
        let winnerCountry = (winnerSide == .attacker) ? engine.attackerCountry : engine.defenderCountry
        let winnerName = (winnerSide == .attacker) ? engine.attackerName : engine.defenderName
        let attInit = engine.units.totalInitialMen(on: .attacker)
        let attSurv = engine.units.totalMen(on: .attacker)
        let defInit = engine.units.totalInitialMen(on: .defender)
        let defSurv = engine.units.totalMen(on: .defender)
        let totalCas = max(0, attInit - attSurv) + max(0, defInit - defSurv)
        let estDelta = min(0.15, (Double(totalCas) / 25_000.0) * 0.12 + 0.025)
        let remainingGarrison = (0..<engine.units.count)
            .filter { engine.units.isGarrison[$0] }
            .reduce(0) { $0 + max(0, engine.units.men[$1]) }
        let anyBreach = engine.structures.contains(where: { ($0.kind == .wall || $0.kind == .gate) && $0.breached })

        return TacticalBattleResult(
            province: engine.province,
            provinceName: engine.provinceName,
            isAssault: engine.isAssault,
            winner: winnerSide,
            winnerCountry: winnerCountry,
            winnerName: winnerName,
            attackerCountry: engine.attackerCountry,
            defenderCountry: engine.defenderCountry,
            attackerName: engine.attackerName,
            defenderName: engine.defenderName,
            attackerInitialMen: attInit,
            attackerSurvivors: attSurv,
            attackerLosses: max(0, attInit - attSurv),
            defenderInitialMen: defInit,
            defenderSurvivors: defSurv,
            defenderLosses: max(0, defInit - defSurv),
            wasStackwipe: engine.wasStackwipe,
            fortCaptured: engine.isAssault && winnerSide == .attacker && engine.keepCaptured,
            newBreachCreated: engine.isAssault && anyBreach,
            remainingGarrison: remainingGarrison,
            warScoreDelta: estDelta,
            elapsedSeconds: engine.elapsedSeconds,
            attackerCommanderName: engine.attackerCommander?.name ?? "Field Captain",
            attackerCommanderFate: engine.attackerCommander?.fate ?? .active,
            defenderCommanderName: engine.defenderCommander?.name ?? "Field Captain",
            defenderCommanderFate: engine.defenderCommander?.fate ?? .active
        )
    }

    @discardableResult
    public static func apply(
        engine: BattleEngine,
        to world: inout World,
        simulation: Simulation,
        date: GameDate
    ) -> TacticalBattleResult {
        var rng = engine.random
        let winnerSide = engine.winner ?? .defender
        let winnerCountry = (winnerSide == .attacker) ? engine.attackerCountry : engine.defenderCountry
        let winnerName = (winnerSide == .attacker) ? engine.attackerName : engine.defenderName

        let attInit = engine.units.totalInitialMen(on: .attacker)
        let attSurv = engine.units.totalMen(on: .attacker)
        let attLosses = max(0, attInit - attSurv)
        let defInit = engine.units.totalInitialMen(on: .defender)
        let defSurv = engine.units.totalMen(on: .defender)
        let defLosses = max(0, defInit - defSurv)

        // 1. Resolve commander fates deterministically (death / capture / wound)
        let attFate = resolveCommanderFate(
            commander: engine.attackerCommander,
            sideWon: winnerSide == .attacker,
            wasStackwipe: engine.wasStackwipe && winnerSide == .defender,
            lossRatio: Double(attLosses) / Double(max(1, attInit)),
            world: &world,
            date: date,
            random: &rng
        )
        let defFate = resolveCommanderFate(
            commander: engine.defenderCommander,
            sideWon: winnerSide == .defender,
            wasStackwipe: engine.wasStackwipe && winnerSide == .attacker,
            lossRatio: Double(defLosses) / Double(max(1, defInit)),
            world: &world,
            date: date,
            random: &rng
        )

        // 2. Write exact surviving men & morale back onto campaign army regiments
        // Collecting army IDs in sorted rawValue order ensures cross-platform determinism.
        var armyRegimentUpdates: [Int32: [Int: (men: Int, morale: Double)]] = [:]
        var armySides: [Int32: BattleSide] = [:]
        for uIdx in 0..<engine.units.count {
            guard let aid = engine.units.sourceArmyID[uIdx], !engine.units.isGarrison[uIdx] else { continue }
            let rIdx = engine.units.sourceRegimentIndex[uIdx]
            var regMap = armyRegimentUpdates[aid.rawValue] ?? [:]
            regMap[rIdx] = (
                men: max(0, engine.units.men[uIdx]),
                morale: max(0.0, min(engine.units.maxMorale[uIdx], engine.units.morale[uIdx]))
            )
            armyRegimentUpdates[aid.rawValue] = regMap
            armySides[aid.rawValue] = engine.units.side[uIdx]
        }

        for rawID in armyRegimentUpdates.keys.sorted() {
            let aid = ArmyID(rawID)
            let aIdx = Int(rawID)
            guard aIdx >= 0, aIdx < world.military.armies.count, world.military.armies.alive[aIdx] else { continue }
            let regMap = armyRegimentUpdates[rawID] ?? [:]
            let uSide = armySides[rawID] ?? .attacker

            var surviving: [Regiment] = []
            for (rIdx, var reg) in world.military.armies.regiments[aIdx].enumerated() {
                if let upd = regMap[rIdx] {
                    reg.men = upd.men
                    reg.morale = upd.morale
                }
                if reg.men > 0 {
                    surviving.append(reg)
                }
            }

            if surviving.isEmpty {
                world.military.armies.remove(aid)
            } else {
                // Surviving losing armies shatter-retreat in field battles (floor morale so they survive retreat)
                if !engine.isAssault && uSide != winnerSide {
                    if engine.wasStackwipe {
                        world.military.armies.remove(aid)
                        continue
                    }
                    for r in surviving.indices {
                        surviving[r].morale = max(0.45, surviving[r].morale)
                    }
                    world.military.armies.regiments[aIdx] = surviving
                    let owner = world.military.armies.owner[aIdx]
                    let retreatProv = BattleSystem.findRetreatProvince(world: world, for: owner, from: engine.province)
                    if retreatProv != engine.province {
                        world.military.armies.isRetreating[aIdx] = true
                        ArmySystem.orderMove(&world, army: aid, to: retreatProv)
                    }
                } else {
                    world.military.armies.regiments[aIdx] = surviving
                }
            }
        }

        // 3. Apply siege assault garrison, breaches & fort capture back into World
        var remainingGarrison = (0..<engine.units.count)
            .filter { engine.units.isGarrison[$0] }
            .reduce(0) { $0 + max(0, engine.units.men[$1]) }
        let anyBreach = engine.structures.contains(where: { ($0.kind == .wall || $0.kind == .gate) && $0.breached })
        var fortCaptured = false

        if engine.isAssault {
            let pIdx = engine.province.index
            if anyBreach, let sIdx = world.military.sieges.firstIndex(where: { $0.province == engine.province && $0.besieger == engine.attackerCountry }) {
                world.military.sieges[sIdx].breached = true
            }
            if winnerSide == .attacker && engine.keepCaptured {
                fortCaptured = true
                SiegeSystem.captureFort(&world, province: engine.province, capturer: engine.attackerCountry, date: date)
                world.military.sieges.removeAll { $0.province == engine.province && $0.besieger == engine.attackerCountry }
                remainingGarrison = world.provinces.fortGarrison[pIdx]
            } else {
                world.provinces.fortGarrison[pIdx] = remainingGarrison
            }
        }

        // 4. Clean up map battle record & update War Score + archives
        let mapBattle: Battle? = engine.mapBattleID.flatMap { bid in
            world.military.battles.first(where: { $0.id == bid })
        }
        if let bid = engine.mapBattleID {
            world.military.battles.removeAll { $0.id == bid }
        }
        if simulation.activeTacticalBattleID == engine.mapBattleID {
            simulation.activeTacticalBattleID = nil
        }
        if simulation.pendingHumanBattleID == engine.mapBattleID {
            simulation.pendingHumanBattleID = nil
        }

        let wsDelta = BattleSystem.applyBattleWarScore(
            &world,
            attacker: engine.attackerCountry,
            defender: engine.defenderCountry,
            winner: winnerCountry,
            totalCasualties: attLosses + defLosses
        )

        let reportID = engine.mapBattleID ?? "tactical_\(engine.province.index)_\(simulation.ticksRun)"
        let daysFought = max(1, (mapBattle?.dayCount ?? 1))
        let report = BattleReport(
            id: reportID,
            province: engine.province,
            startDate: mapBattle?.startDate ?? date,
            endDate: date,
            attackerCountry: engine.attackerCountry,
            defenderCountry: engine.defenderCountry,
            winner: winnerCountry,
            attackerInitialMen: attInit,
            defenderInitialMen: defInit,
            attackerLosses: attLosses,
            defenderLosses: defLosses,
            daysFought: daysFought,
            wasStackwipe: engine.wasStackwipe
        )
        world.military.recentBattles.append(report)
        if world.military.recentBattles.count > 50 {
            world.military.recentBattles.removeFirst(world.military.recentBattles.count - 50)
        }

        let actionNoun = engine.isAssault ? "Storm Assault of" : "Battle of"
        let summary = "\(winnerName) wins the \(actionNoun) \(engine.provinceName) (\(attLosses) attacker / \(defLosses) defender casualties)."
        world.people.record(date, engine.attackerCountry, summary)
        world.people.record(date, engine.defenderCountry, summary)

        let totalMen = attInit + defInit
        let totalLosses = attLosses + defLosses
        if totalMen >= 2000 || totalLosses >= 500 {
            let loseCountry = winnerCountry == engine.attackerCountry ? engine.defenderCountry : engine.attackerCountry
            HistorySystem.recordEvent(
                &world,
                date: date,
                kind: .majorBattle,
                primary: winnerCountry,
                secondary: loseCountry,
                province: engine.province,
                valueA: totalLosses,
                valueB: daysFought
            )
        }

        return TacticalBattleResult(
            province: engine.province,
            provinceName: engine.provinceName,
            isAssault: engine.isAssault,
            winner: winnerSide,
            winnerCountry: winnerCountry,
            winnerName: winnerName,
            attackerCountry: engine.attackerCountry,
            defenderCountry: engine.defenderCountry,
            attackerName: engine.attackerName,
            defenderName: engine.defenderName,
            attackerInitialMen: attInit,
            attackerSurvivors: attSurv,
            attackerLosses: attLosses,
            defenderInitialMen: defInit,
            defenderSurvivors: defSurv,
            defenderLosses: defLosses,
            wasStackwipe: engine.wasStackwipe,
            fortCaptured: fortCaptured,
            newBreachCreated: engine.isAssault && anyBreach,
            remainingGarrison: remainingGarrison,
            warScoreDelta: wsDelta,
            elapsedSeconds: engine.elapsedSeconds,
            attackerCommanderName: engine.attackerCommander?.name ?? "Field Captain",
            attackerCommanderFate: attFate,
            defenderCommanderName: engine.defenderCommander?.name ?? "Field Captain",
            defenderCommanderFate: defFate
        )
    }

    private static func resolveCommanderFate(
        commander: BattleCommanderInfo?,
        sideWon: Bool,
        wasStackwipe: Bool,
        lossRatio: Double,
        world: inout World,
        date: GameDate,
        random: inout GameRandom
    ) -> CommanderFate {
        guard let cmd = commander else { return .active }
        let fate = cmd.fate != .active ? cmd.fate : rollFate(sideWon: sideWon, wasStackwipe: wasStackwipe, lossRatio: lossRatio, random: &random)

        if fate == .killed, let cid = cmd.characterID, world.people.characters.isAlive(cid) {
            CharacterSystem.kill(&world, cid, date: date, random: &random)
            world.people.record(date, cmd.country, "\(cmd.name) fell in battle.")
        } else if fate == .captured, let aid = cmd.armyID {
            let aIdx = Int(aid.rawValue)
            if aIdx >= 0 && aIdx < world.military.armies.count {
                world.military.armies.commander[aIdx] = nil
            }
            world.people.record(date, cmd.country, "\(cmd.name) was captured by the enemy.")
        } else if fate == .wounded {
            world.people.record(date, cmd.country, "\(cmd.name) was wounded in battle.")
        }
        return fate
    }

    private static func rollFate(
        sideWon: Bool,
        wasStackwipe: Bool,
        lossRatio: Double,
        random: inout GameRandom
    ) -> CommanderFate {
        let roll = Double.random(in: 0.0...1.0, using: &random)
        if wasStackwipe && !sideWon {
            if roll < 0.45 { return .captured }
            if roll < 0.75 { return .killed }
            return .wounded
        }
        if !sideWon && lossRatio > 0.45 {
            if roll < 0.08 { return .killed }
            if roll < 0.16 { return .captured }
            if roll < 0.36 { return .wounded }
        } else if sideWon && lossRatio > 0.40 {
            if roll < 0.04 { return .killed }
            if roll < 0.16 { return .wounded }
        }
        return .active
    }
}
