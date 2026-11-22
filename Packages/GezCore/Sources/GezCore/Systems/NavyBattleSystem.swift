import Foundation

/// Phase 10 Part C: multi-day auto-resolved naval battles, naval blockades,
/// and strait control checks.
public enum NavyBattleSystem {

    public static let galleyInlandCombatMultiplier = 1.50
    public static let captureChanceOnDisable = 0.18
    public static let maxBlockadeTradeCut = 0.75

    // MARK: - Blockades

    /// Recomputes `world.navy.blockadedProvinces` from fleets currently at sea
    /// whose owner is at war with each coastal province's controller.
    public static func updateBlockades(_ world: inout World) {
        var blockaded = Set<ProvinceID>()
        for fIdx in 0..<world.navy.fleets.count where world.navy.fleets.alive[fIdx] {
            guard world.navy.fleets.battle[fIdx] == nil,
                  case .sea(let sz) = world.navy.fleets.location[fIdx] else { continue }
            let fleetOwner = world.navy.fleets.owner[fIdx]
            guard world.navy.shipCount(of: FleetID(fIdx)) > 0 else { continue }

            for p in world.seaZones.coast[sz.index] {
                guard world.hasSeaAccess(p),
                      let ctrl = world.provinces.controller(of: p),
                      world.diplomacy.isAtWar(fleetOwner, ctrl) else { continue }
                blockaded.insert(p)
            }
        }
        world.navy.blockadedProvinces = blockaded
    }

    /// True if `country` or its allies maintain a hostile fleet in at least one sea
    /// zone touching `province`.
    public static func isBlockadedBySide(_ world: World, province: ProvinceID, blockaders: [CountryID]) -> Bool {
        guard world.hasSeaAccess(province) else { return false }
        for sz in world.provinceSeas[province.index] {
            for fid in world.navy.fleets(inSea: sz) {
                guard world.navy.fleets.battle[fid.index] == nil,
                      world.navy.shipCount(of: fid) > 0 else { continue }
                if blockaders.contains(world.navy.fleets.owner[fid.index]) {
                    return true
                }
            }
        }
        return false
    }

    /// Sea-trade capacity multiplier (`0.25...1.0`) for each market when coastal ports
    /// in that market are blockaded. Returns `nil` quickly when no blockades exist.
    public static func marketSeaTradeMultipliers(_ world: World) -> [Double]? {
        let blockaded = world.navy.blockadedProvinces
        guard !blockaded.isEmpty else { return nil }

        let M = world.economy.markets.count
        var coastalCount = Array(repeating: 0, count: M)
        var blockadedCount = Array(repeating: 0, count: M)
        var centreBlockaded = Array(repeating: false, count: M)

        for p in 0..<world.provinces.count {
            let pid = ProvinceID(p)
            guard world.hasSeaAccess(pid), let m = world.market(of: pid) else { continue }
            coastalCount[m.index] += 1
            if blockaded.contains(pid) {
                blockadedCount[m.index] += 1
                if world.economy.markets.centre[m.index] == pid {
                    centreBlockaded[m.index] = true
                }
            }
        }

        return (0..<M).map { m in
            guard blockadedCount[m] > 0 else { return 1.0 }
            let frac = Double(blockadedCount[m]) / Double(max(1, coastalCount[m]))
            let cut = min(maxBlockadeTradeCut, (centreBlockaded[m] ? 0.50 : 0.0) + 0.50 * frac)
            return max(1.0 - maxBlockadeTradeCut, 1.0 - cut)
        }
    }

    // MARK: - Daily Naval Battle Loop

    public static func runDaily(_ world: inout World, date: GameDate, random: inout GameRandom) {
        updateBlockades(&world)
        detectAndReinforce(&world, date: date)
        advanceBattles(&world, date: date, random: &random)
        updateBlockades(&world)
    }

    private static func detectAndReinforce(_ world: inout World, date: GameDate) {
        // Reinforce already active naval battles first.
        for bIdx in 0..<world.navy.battles.count {
            let sz = world.navy.battles[bIdx].seaZone
            for fid in world.navy.fleets(inSea: sz) where world.navy.fleets.battle[fid.index] == nil {
                guard world.navy.shipCount(of: fid) > 0 else { continue }
                let owner = world.navy.fleets.owner[fid.index]
                let att = world.navy.battles[bIdx].attacker.country
                let def = world.navy.battles[bIdx].defender.country
                if world.diplomacy.isAtWar(owner, def) {
                    var side = world.navy.battles[bIdx].attacker
                    joinSide(&side, fleet: fid, world: &world, battleIndex: bIdx)
                    world.navy.battles[bIdx].attacker = side
                } else if world.diplomacy.isAtWar(owner, att) {
                    var side = world.navy.battles[bIdx].defender
                    joinSide(&side, fleet: fid, world: &world, battleIndex: bIdx)
                    world.navy.battles[bIdx].defender = side
                }
            }
        }

        // Start new naval battles in sea zones where opposing war fleets meet.
        for z in 0..<world.seaZones.count {
            let sz = SeaZoneID(z)
            if world.navy.navalBattle(in: sz) != nil { continue }
            let present = world.navy.fleets(inSea: sz).filter {
                world.navy.fleets.battle[$0.index] == nil && world.navy.shipCount(of: $0) > 0
            }
            guard present.count >= 2 else { continue }

            var firstHostile: (FleetID, FleetID)?
            outer: for i in 0..<present.count {
                let o1 = world.navy.fleets.owner[present[i].index]
                for j in (i + 1)..<present.count {
                    let o2 = world.navy.fleets.owner[present[j].index]
                    if world.diplomacy.isAtWar(o1, o2) {
                        firstHostile = (present[i], present[j])
                        break outer
                    }
                }
            }
            guard let (fA, fB) = firstHostile else { continue }

            let ownerA = world.navy.fleets.owner[fA.index]
            let ownerB = world.navy.fleets.owner[fB.index]
            let attSideFleets = present.filter { f in
                let o = world.navy.fleets.owner[f.index]
                return o == ownerA || (!world.diplomacy.isAtWar(o, ownerA) && world.diplomacy.isAtWar(o, ownerB))
            }
            let defSideFleets = present.filter { f in
                let o = world.navy.fleets.owner[f.index]
                return o == ownerB || (!world.diplomacy.isAtWar(o, ownerB) && world.diplomacy.isAtWar(o, ownerA))
            }

            let attShips = attSideFleets.reduce(0) { $0 + world.navy.shipCount(of: $1) }
            let defShips = defSideFleets.reduce(0) { $0 + world.navy.shipCount(of: $1) }
            let attAdm = bestAdmiral(in: attSideFleets, world: world)
            let defAdm = bestAdmiral(in: defSideFleets, world: world)
            let isInland = z < world.seaZones.isInland.count && world.seaZones.isInland[z]

            let bIdx = world.navy.battles.count
            let battle = NavalBattle(
                id: "naval_\(date.year)-\(date.month)-\(date.day)_\(z)_\(bIdx)",
                seaZone: sz,
                startDate: date,
                isInlandSea: isInland,
                attacker: NavalBattleSide(country: ownerA, fleets: attSideFleets, admiral: attAdm, startingShips: attShips),
                defender: NavalBattleSide(country: ownerB, fleets: defSideFleets, admiral: defAdm, startingShips: defShips)
            )
            world.navy.battles.append(battle)
            for f in attSideFleets + defSideFleets {
                world.navy.fleets.battle[f.index] = bIdx
                world.navy.fleets.path[f.index].removeAll()
                world.navy.fleets.destinationPort[f.index] = nil
                world.navy.fleets.moveStepDays[f.index] = 0
                world.navy.fleets.moveProgressDays[f.index] = 0
            }
        }
    }

    private static func joinSide(_ side: inout NavalBattleSide, fleet: FleetID, world: inout World, battleIndex: Int) {
        if !side.fleets.contains(fleet) {
            side.fleets.append(fleet)
            side.startingShips += world.navy.shipCount(of: fleet)
        }
        world.navy.fleets.battle[fleet.index] = battleIndex
        world.navy.fleets.path[fleet.index].removeAll()
        world.navy.fleets.destinationPort[fleet.index] = nil
        if let fAdm = world.navy.fleets.admiral[fleet.index], world.people.characters.isAlive(fAdm) {
            let fM = world.people.characters.skill(fAdm, .martial)
            let curM = side.admiral.flatMap {
                world.people.characters.isAlive($0) ? world.people.characters.skill($0, .martial) : nil
            } ?? -1
            if fM > curM { side.admiral = fAdm }
        }
    }

    private static func bestAdmiral(in fleets: [FleetID], world: World) -> CharacterID? {
        var best: CharacterID?
        var bestSkill = -1
        for f in fleets {
            if let adm = world.navy.fleets.admiral[f.index], world.people.characters.isAlive(adm) {
                let s = world.people.characters.skill(adm, .martial)
                if s > bestSkill {
                    bestSkill = s
                    best = adm
                }
            }
        }
        return best
    }

    private static func advanceBattles(_ world: inout World, date: GameDate, random: inout GameRandom) {
        var idx = world.navy.battles.count - 1
        while idx >= 0 {
            var battle = world.navy.battles[idx]
            battle.dayCount += 1

            let attShips = aliveShips(in: battle.attacker.fleets, world: world)
            let defShips = aliveShips(in: battle.defender.fleets, world: world)

            if attShips.isEmpty || defShips.isEmpty {
                concludeBattle(&world, battleIndex: idx, battle: battle, date: date)
                idx -= 1
                continue
            }

            // Admiral Martial rolls (1...10 + Martial / 2 via GameRandom)
            let attMartial = battle.attacker.admiral.flatMap {
                world.people.characters.isAlive($0) ? world.people.characters.skill($0, .martial) : nil
            } ?? 0
            let defMartial = battle.defender.admiral.flatMap {
                world.people.characters.isAlive($0) ? world.people.characters.skill($0, .martial) : nil
            } ?? 0
            let daySalt = UInt64(max(1, date.year) &* 4096 &+ date.month &* 32 &+ date.day)
            var battleRng = GameRandom(
                seed: random.rawState
                    ^ (UInt64(idx &+ 1) &* 0x9E37_79B9_7F4A_7C15)
                    ^ (UInt64(battle.dayCount) &* 0xBF58_476D_1CE4_E5B9)
                    ^ daySalt
            )
            let attRoll = Int.random(in: 1...10, using: &battleRng) + attMartial / 2
            let defRoll = Int.random(in: 1...10, using: &battleRng) + defMartial / 2

            let attFactor = max(0.45, min(2.2, 1.0 + Double(attRoll - defRoll) * 0.12))
            let defFactor = max(0.45, min(2.2, 1.0 + Double(defRoll - attRoll) * 0.12))

            // Cannon phase dominates days 1-2; Boarding phase intensifies from day 2+
            let cannonWeight = battle.dayCount <= 2 ? 1.0 : 0.45
            let boardingWeight = battle.dayCount == 1 ? 0.35 : 1.0

            let attOffense = sideOffense(attShips, world: world, isInland: battle.isInlandSea,
                                         cannonW: cannonWeight, boardingW: boardingWeight) * attFactor
            let defOffense = sideOffense(defShips, world: world, isInland: battle.isInlandSea,
                                         cannonW: cannonWeight, boardingW: boardingWeight) * defFactor

            // Deal simultaneous daily damage to ships.
            let isBoardingDay = battle.dayCount >= 2
            let attLeadFleet = battle.attacker.fleets.first { world.navy.shipCount(of: $0) > 0 }
            let defLeadFleet = battle.defender.fleets.first { world.navy.shipCount(of: $0) > 0 }

            applySideDamage(
                &world,
                targets: defShips,
                incomingFire: attOffense,
                victorLeadFleet: attLeadFleet,
                dayCount: battle.dayCount,
                isBoardingDay: isBoardingDay,
                allowCapture: attRoll >= defRoll,
                defenderSide: &battle.defender,
                attackerSide: &battle.attacker,
                random: &battleRng
            )
            applySideDamage(
                &world,
                targets: attShips,
                incomingFire: defOffense,
                victorLeadFleet: defLeadFleet,
                dayCount: battle.dayCount,
                isBoardingDay: isBoardingDay,
                allowCapture: defRoll >= attRoll,
                defenderSide: &battle.attacker,
                attackerSide: &battle.defender,
                random: &battleRng
            )

            // Check termination: no ships or broken morale after day >= 2.
            let attAfter = aliveShips(in: battle.attacker.fleets, world: world)
            let defAfter = aliveShips(in: battle.defender.fleets, world: world)
            let attMorale = avgMorale(attAfter, world: world)
            let defMorale = avgMorale(defAfter, world: world)

            let ended = attAfter.isEmpty || defAfter.isEmpty
                || (battle.dayCount >= 2 && (attMorale <= 0.35 || defMorale <= 0.35))
                || battle.dayCount >= 14

            if ended {
                concludeBattle(&world, battleIndex: idx, battle: battle, date: date)
            } else {
                world.navy.battles[idx] = battle
            }
            idx -= 1
        }
    }

    private static func aliveShips(in fleets: [FleetID], world: World) -> [Int] {
        var out: [Int] = []
        for f in fleets {
            let fi = f.index
            guard fi >= 0 && fi < world.navy.fleets.count && world.navy.fleets.alive[fi] else { continue }
            for s in world.navy.fleets.shipIndices[fi] where world.navy.ships.alive[s] {
                out.append(s)
            }
        }
        return out
    }

    private static func avgMorale(_ ships: [Int], world: World) -> Double {
        guard !ships.isEmpty else { return 0 }
        let sum = ships.reduce(0.0) { $0 + world.navy.ships.morale[$1] }
        return sum / Double(ships.count)
    }

    private static func sideOffense(
        _ ships: [Int],
        world: World,
        isInland: Bool,
        cannonW: Double,
        boardingW: Double
    ) -> Double {
        var total = 0.0
        for sIdx in ships {
            let st = world.navy.shipType(world.navy.ships.type[sIdx])
            let hullFrac = max(0.2, world.navy.ships.hull[sIdx] / 100.0)
            let crewFrac = Double(max(1, world.navy.ships.crew[sIdx])) / Double(max(1, st.maxCrew))
            let cannons = Double(st.cannons) * 0.95 * cannonW
            var boarding = Double(st.maxCrew) * 0.075 * boardingW
            if st.shipClass == .galley && isInland {
                boarding *= galleyInlandCombatMultiplier
            }
            total += (cannons + boarding) * hullFrac * (0.4 + 0.6 * crewFrac)
        }
        return total
    }

    private static func applySideDamage(
        _ world: inout World,
        targets: [Int],
        incomingFire: Double,
        victorLeadFleet: FleetID?,
        dayCount: Int,
        isBoardingDay: Bool,
        allowCapture: Bool,
        defenderSide: inout NavalBattleSide,
        attackerSide: inout NavalBattleSide,
        random: inout GameRandom
    ) {
        guard !targets.isEmpty else { return }
        let perShipRaw = (incomingFire * 1.45) / Double(max(2, targets.count))
        let maxDailyHullHit = dayCount == 1 ? 42.0 : 55.0

        for sIdx in targets where world.navy.ships.alive[sIdx] {
            let st = world.navy.shipType(world.navy.ships.type[sIdx])
            let toughness = max(0.6, st.maxHull / 100.0)
            let rawHit = (perShipRaw / toughness) * Double.random(in: 0.75...1.30, using: &random)
            let hullHit = min(maxDailyHullHit, rawHit)
            world.navy.ships.hull[sIdx] -= hullHit

            let crewHit = max(1, Int((hullHit * Double(st.maxCrew) * 0.008).rounded()))
            let lostCrew = min(world.navy.ships.crew[sIdx], crewHit)
            world.navy.ships.crew[sIdx] -= lostCrew
            defenderSide.sailorsLost += lostCrew

            let moraleHit = (hullHit / 48.0) + 0.12
            world.navy.ships.morale[sIdx] = max(0, world.navy.ships.morale[sIdx] - moraleHit)

            // Capture chance in close action when a disabled ship surrenders before sinking.
            if world.navy.ships.hull[sIdx] <= 18.0 {
                if isBoardingDay && allowCapture,
                   let vFleet = victorLeadFleet,
                   world.navy.fleets.alive[vFleet.index],
                   Double.random(in: 0..<1, using: &random) < captureChanceOnDisable {
                    transferShip(&world, shipIndex: sIdx, toFleet: vFleet)
                    world.navy.ships.hull[sIdx] = 25.0
                    world.navy.ships.morale[sIdx] = 1.5
                    attackerSide.shipsCaptured += 1
                    continue
                }
                if world.navy.ships.hull[sIdx] <= 0 {
                    world.navy.ships.alive[sIdx] = false
                    defenderSide.sailorsLost += world.navy.ships.crew[sIdx]
                    world.navy.ships.crew[sIdx] = 0
                    defenderSide.shipsSunk += 1
                }
            }
        }
    }

    private static func transferShip(_ world: inout World, shipIndex: Int, toFleet: FleetID) {
        let oldFleet = world.navy.ships.fleet[shipIndex]
        if oldFleet.index >= 0 && oldFleet.index < world.navy.fleets.count {
            world.navy.fleets.shipIndices[oldFleet.index].removeAll { $0 == shipIndex }
        }
        world.navy.ships.fleet[shipIndex] = toFleet
        world.navy.fleets.shipIndices[toFleet.index].append(shipIndex)
    }

    private static func concludeBattle(
        _ world: inout World,
        battleIndex: Int,
        battle: NavalBattle,
        date: GameDate
    ) {
        for f in battle.attacker.fleets + battle.defender.fleets {
            NavySystem.cleanupIfEmpty(&world, fleet: f)
            if f.index < world.navy.fleets.count {
                world.navy.fleets.battle[f.index] = nil
            }
        }
        // Shift later battle indices on other active battles after removing `battleIndex`.
        world.navy.battles.remove(at: battleIndex)
        for fi in 0..<world.navy.fleets.count where world.navy.fleets.alive[fi] {
            if let b = world.navy.fleets.battle[fi], b > battleIndex {
                world.navy.fleets.battle[fi] = b - 1
            }
        }

        let attShips = aliveShips(in: battle.attacker.fleets, world: world)
        let defShips = aliveShips(in: battle.defender.fleets, world: world)
        let attScore = Double(attShips.count) * avgMorale(attShips, world: world) - Double(battle.attacker.shipsSunk)
        let defScore = Double(defShips.count) * avgMorale(defShips, world: world) - Double(battle.defender.shipsSunk)

        let attackerWon: Bool
        if attShips.isEmpty != defShips.isEmpty {
            attackerWon = defShips.isEmpty
        } else {
            attackerWon = attScore >= defScore
        }

        let winnerCountry = attackerWon ? battle.attacker.country : battle.defender.country
        let loserFleets = attackerWon ? battle.defender.fleets : battle.attacker.fleets

        // Retreat defeated surviving fleets to nearest friendly port (one hop away or docked).
        for lf in loserFleets where world.navy.fleets.alive[lf.index] && world.navy.shipCount(of: lf) > 0 {
            retreatFleetToPort(&world, fleet: lf, from: battle.seaZone)
        }

        let totalSailorsLost = battle.attacker.sailorsLost + battle.defender.sailorsLost
        let totalShipsLost = battle.attacker.shipsSunk + battle.defender.shipsSunk
            + battle.attacker.shipsCaptured + battle.defender.shipsCaptured
        let effectiveCasualties = totalSailorsLost + totalShipsLost * 600

        let wsDelta = BattleSystem.applyBattleWarScore(
            &world,
            attacker: battle.attacker.country,
            defender: battle.defender.country,
            winner: winnerCountry,
            totalCasualties: effectiveCasualties
        )

        let szName = world.seaZones.name[battle.seaZone.index]
        world.navy.recentBattles.append(NavalBattleReport(
            id: battle.id,
            seaZone: battle.seaZone,
            seaZoneName: szName,
            date: date,
            days: battle.dayCount,
            attackerCountry: battle.attacker.country,
            defenderCountry: battle.defender.country,
            winnerCountry: winnerCountry,
            attackerStartingShips: battle.attacker.startingShips,
            defenderStartingShips: battle.defender.startingShips,
            attackerShipsLost: battle.attacker.shipsSunk + battle.attacker.shipsCaptured,
            defenderShipsLost: battle.defender.shipsSunk + battle.defender.shipsCaptured,
            attackerShipsCaptured: battle.attacker.shipsCaptured,
            defenderShipsCaptured: battle.defender.shipsCaptured,
            attackerSailorsLost: battle.attacker.sailorsLost,
            defenderSailorsLost: battle.defender.sailorsLost,
            warScoreDelta: wsDelta
        ))

        let attLost = battle.attacker.shipsSunk + battle.attacker.shipsCaptured
        let defLost = battle.defender.shipsSunk + battle.defender.shipsCaptured
        if battle.attacker.startingShips + battle.defender.startingShips >= 8 || (attLost + defLost) >= 2 {
            let loseCountry = winnerCountry == battle.attacker.country ? battle.defender.country : battle.attacker.country
            HistorySystem.recordEvent(
                &world,
                date: date,
                kind: .navalBattle,
                primary: winnerCountry,
                secondary: loseCountry,
                valueA: attLost + defLost,
                valueB: battle.dayCount
            )
        }
    }

    private static func retreatFleetToPort(_ world: inout World, fleet: FleetID, from battleSea: SeaZoneID) {
        let owner = world.navy.fleets.owner[fleet.index]
        let friendlyPorts = (0..<world.provinces.count).compactMap { p -> ProvinceID? in
            let pid = ProvinceID(p)
            return NavySystem.canDock(world, owner, in: pid) ? pid : nil
        }
        guard !friendlyPorts.isEmpty else { return }

        // If a friendly port touches a neighboring sea zone (or this zone), move/dock toward nearest.
        var bestPort = friendlyPorts[0]
        var bestDist = Double.infinity
        for p in friendlyPorts {
            for sz in world.provinceSeas[p.index] {
                let d = NavySystem.seaDistance(world, from: battleSea, to: sz)
                if d < bestDist {
                    bestDist = d
                    bestPort = p
                }
            }
        }
        // Step defeated fleet one safe neighboring sea zone toward home so it doesn't stay trapped in battle loops.
        if let route = NavySystem.findSeaPath(world, from: .sea(battleSea), to: world.provinceSeas[bestPort.index].first ?? battleSea),
           let firstStep = route.first {
            world.navy.fleets.location[fleet.index] = .sea(firstStep)
        }
        _ = NavySystem.orderDockFleet(&world, fleet, inPort: bestPort)
    }
}
