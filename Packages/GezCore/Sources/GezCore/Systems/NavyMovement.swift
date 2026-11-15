import Foundation

extension NavyModel {
    /// Base sea travel speed in map pixels per day (~32 px per degree).
    public static let baseSeaPixelsPerDay = 30.0
    /// Minimum days required to cross from one sea zone to a neighbor.
    public static let minSeaStepDays = 1.0
    /// Speed multiplier bonus per Martial point above 5 (+4% per point).
    public static let admiralSpeedPerMartial = 0.04
    /// Galley speed multiplier inside inland seas (Med, Black, Baltic, Red).
    public static let galleyInlandSpeedMultiplier = 1.25
    /// Sea-zone hops from nearest friendly controlled port that remain supplied.
    public static let supplyRangeHops = 2
    /// Daily supply loss beyond supply range.
    public static let deepSeaSupplyDrainPerDay = 4.0
    /// Extra daily supply drain for oared galleys sailing outside inland seas.
    public static let galleyOpenOceanDrainPerDay = 5.0
    /// Daily hull damage percentage when fleet supply reaches 0 at sea.
    public static let attritionHullLossPerDay = 1.5
    /// Daily crew attrition fraction when fleet supply reaches 0 at sea.
    public static let attritionCrewFractionPerDay = 0.015
}

extension NavySystem {

    // MARK: - Admiral Assignment & Fleet Organization

    /// Living adult candidates in `country`'s court sorted by Martial descending.
    public static func admiralCandidates(_ world: World, _ country: CountryID, date: GameDate) -> [CharacterID] {
        let rebelLeaders: Set<CharacterID> = Set(
            world.military.rebelArmies(of: country).compactMap { world.military.armies.rebelLeader[Int($0.rawValue)] }
        )
        return ArmySystem.commanderCandidates(
            world, country, date: date, courtPool: world.people.characters.ids, rebelLeaders: rebelLeaders
        )
    }

    /// Assigns `admiral` to `fleet` (unassigning them from any other fleet first).
    public static func assignAdmiral(_ world: inout World, fleet: FleetID, admiral: CharacterID?) {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return }
        if let adm = admiral {
            for j in 0..<world.navy.fleets.count where world.navy.fleets.alive[j] {
                if world.navy.fleets.admiral[j] == adm {
                    world.navy.fleets.admiral[j] = nil
                }
            }
        }
        world.navy.fleets.admiral[i] = admiral
    }

    /// Merges all other same-owner alive fleets at the exact same location into `fleet`.
    @discardableResult
    public static func mergeFleetsInLocation(_ world: inout World, into fleet: FleetID) -> Int {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i],
              world.navy.fleets.battle[i] == nil else { return 0 }
        let owner = world.navy.fleets.owner[i]
        let loc = world.navy.fleets.location[i]
        var merged = 0

        for j in 0..<world.navy.fleets.count where j != i && world.navy.fleets.alive[j] {
            guard world.navy.fleets.owner[j] == owner,
                  world.navy.fleets.location[j] == loc,
                  world.navy.fleets.battle[j] == nil else { continue }
            for sIdx in world.navy.fleets.shipIndices[j] where world.navy.ships.alive[sIdx] {
                world.navy.ships.fleet[sIdx] = fleet
                world.navy.fleets.shipIndices[i].append(sIdx)
            }
            world.navy.fleets.shipIndices[j].removeAll()
            world.navy.fleets.embarkedArmies[i].append(contentsOf: world.navy.fleets.embarkedArmies[j])
            world.navy.fleets.embarkedArmies[j].removeAll()
            if world.navy.fleets.admiral[i] == nil {
                world.navy.fleets.admiral[i] = world.navy.fleets.admiral[j]
            }
            world.navy.fleets.admiral[j] = nil
            world.navy.fleets.path[j].removeAll()
            world.navy.fleets.destinationPort[j] = nil
            world.navy.fleets.alive[j] = false
            merged += 1
        }
        return merged
    }

    /// Splits the specified alive `shipIndices` (or half of the fleet if `nil`) into a new fleet at the same location.
    public static func splitFleet(_ world: inout World, fleet: FleetID, shipIndices: [Int]? = nil) -> FleetID? {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i],
              world.navy.fleets.battle[i] == nil else { return nil }
        let aliveShips = world.navy.fleets.shipIndices[i].filter { world.navy.ships.alive[$0] }
        guard aliveShips.count >= 2 else { return nil }

        let chosen: [Int]
        if let explicit = shipIndices {
            let set = Set(explicit)
            chosen = aliveShips.filter { set.contains($0) }
        } else {
            chosen = Array(aliveShips[(aliveShips.count / 2)..<aliveShips.count])
        }
        guard !chosen.isEmpty && chosen.count < aliveShips.count else { return nil }

        let chosenSet = Set(chosen)
        let kept = aliveShips.filter { !chosenSet.contains($0) }
        world.navy.fleets.shipIndices[i] = kept

        let owner = world.navy.fleets.owner[i]
        let loc = world.navy.fleets.location[i]
        let splitName = "Squadron of \(world.navy.fleets.name[i])"
        let newId = world.navy.fleets.append(
            name: splitName,
            owner: owner,
            location: loc,
            admiral: nil,
            mission: .idle
        )
        world.navy.fleets.supply[newId.index] = world.navy.fleets.supply[i]
        for sIdx in chosen {
            world.navy.ships.fleet[sIdx] = newId
            world.navy.fleets.shipIndices[newId.index].append(sIdx)
        }
        return newId
    }

    // MARK: - Speed, Pathfinding & Movement Orders

    /// Deterministic Euclidean distance in map pixels between two sea zones via `DetMath`.
    public static func seaDistance(_ world: World, from a: SeaZoneID, to b: SeaZoneID) -> Double {
        let dx = world.seaZones.centerX[b.index] - world.seaZones.centerX[a.index]
        let dy = world.seaZones.centerY[b.index] - world.seaZones.centerY[a.index]
        let d = DetMath.length(dx, dy)
        return d > 1.0 ? d : 30.0
    }

    /// True if `country` can peacefully dock at `port`.
    public static func canDock(_ world: World, _ country: CountryID, in port: ProvinceID) -> Bool {
        guard world.hasSeaAccess(port) else { return false }
        guard let ctrl = world.provinces.controller(of: port) else { return false }
        if ctrl == country { return true }
        if world.diplomacy.hasMilitaryAccess(country: country, through: ctrl) { return true }
        // Allies in the same war can dock in each other's friendly ports.
        return world.diplomacy.wars.contains { war in
            (war.isAttacker(country) && war.isAttacker(ctrl)) ||
            (war.isDefender(country) && war.isDefender(ctrl))
        }
    }

    /// Effective speed multiplier of `fleet` when traversing `sea` (slowest ship,
    /// galley inland bonus, plus admiral Martial bonus).
    public static func fleetSpeed(_ world: World, _ fleet: FleetID, in sea: SeaZoneID) -> Double {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return 1.0 }
        let inland = sea.index < world.seaZones.isInland.count && world.seaZones.isInland[sea.index]
        var slowest = Double.greatestFiniteMagnitude
        var anyAlive = false
        for sIdx in world.navy.fleets.shipIndices[i] where world.navy.ships.alive[sIdx] {
            anyAlive = true
            let st = world.navy.shipType(world.navy.ships.type[sIdx])
            var spd = st.speed
            if st.shipClass == .galley && inland {
                spd *= NavyModel.galleyInlandSpeedMultiplier
            }
            if spd < slowest { slowest = spd }
        }
        var speed = anyAlive ? slowest : 1.0
        if let adm = world.navy.fleets.admiral[i], world.people.characters.isAlive(adm) {
            let martial = world.people.characters.skill(adm, .martial)
            let bonus = 1.0 + Double(martial - 5) * NavyModel.admiralSpeedPerMartial
            speed *= max(0.75, bonus)
        }
        return max(0.35, speed)
    }

    /// Days required for `fleet` to sail from `sea` to neighbor `next`.
    public static func seaStepDays(_ world: World, from sea: SeaZoneID, to next: SeaZoneID, fleet: FleetID) -> Double {
        let dist = seaDistance(world, from: sea, to: next)
        let pxPerDay = NavyModel.baseSeaPixelsPerDay * fleetSpeed(world, fleet, in: sea)
        return max(NavyModel.minSeaStepDays, (dist / pxPerDay * 10.0).rounded() / 10.0)
    }

    /// Shortest sea-zone path from `start` to `goal` using Dijkstra over `SeaZoneTable.neighbors`.
    /// Includes the starting sea zone only if launching from a port; does not include `currentSea` if already at sea.
    public static func findSeaPath(_ world: World, from start: FleetLocation, to goal: SeaZoneID) -> [SeaZoneID]? {
        let Z = world.seaZones.count
        guard goal.index >= 0 && goal.index < Z else { return nil }

        let starts: [SeaZoneID]
        switch start {
        case .sea(let cur):
            if cur == goal { return [] }
            starts = [cur]
        case .port(let portProv):
            let adj = world.provinceSeas[portProv.index]
            if adj.isEmpty { return nil }
            if adj.contains(goal) { return [goal] }
            starts = adj
        }

        var dist = Array(repeating: Double.infinity, count: Z)
        var prev = Array(repeating: -1, count: Z)
        var unvisited: [SeaZoneID] = []

        switch start {
        case .port:
            // Stepping from port into adjacent sea zone costs 1 day baseline.
            for s in starts {
                dist[s.index] = 1.0
                unvisited.append(s)
            }
        case .sea(let cur):
            dist[cur.index] = 0.0
            unvisited.append(cur)
        }

        var visited = Array(repeating: false, count: Z)
        while !unvisited.isEmpty {
            unvisited.sort {
                let d0 = dist[$0.index], d1 = dist[$1.index]
                return d0 != d1 ? d0 < d1 : $0.index < $1.index
            }
            let u = unvisited.removeFirst()
            if visited[u.index] { continue }
            visited[u.index] = true
            if u == goal { break }

            for v in world.seaZones.neighbors[u.index] where !visited[v.index] {
                let alt = dist[u.index] + seaDistance(world, from: u, to: v)
                if alt < dist[v.index] {
                    dist[v.index] = alt
                    prev[v.index] = u.index
                    unvisited.append(v)
                }
            }
        }

        guard dist[goal.index].isFinite else { return nil }
        var route: [SeaZoneID] = []
        var curIdx = goal.index
        while curIdx != -1 {
            if case .sea(let s) = start, curIdx == s.index { break }
            route.append(SeaZoneID(curIdx))
            curIdx = prev[curIdx]
        }
        route.reverse()
        return route
    }

    /// Orders `fleet` to sail to `targetSea` (cancelling any prior docking order).
    @discardableResult
    public static func orderMoveFleet(_ world: inout World, _ fleet: FleetID, toSea target: SeaZoneID) -> Bool {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i],
              world.navy.fleets.battle[i] == nil else { return false }
        let curLoc = world.navy.fleets.location[i]
        guard let route = findSeaPath(world, from: curLoc, to: target) else { return false }
        world.navy.fleets.path[i] = route
        world.navy.fleets.destinationPort[i] = nil
        world.navy.fleets.moveProgressDays[i] = 0
        if let firstHop = route.first {
            if case .sea(let curSea) = curLoc {
                world.navy.fleets.moveStepDays[i] = seaStepDays(world, from: curSea, to: firstHop, fleet: fleet)
            } else {
                world.navy.fleets.moveStepDays[i] = 1.0
            }
        } else {
            world.navy.fleets.moveStepDays[i] = 0
        }
        return true
    }

    /// Orders `fleet` to sail to and anchor inside `port` (must be friendly & coastal).
    @discardableResult
    public static func orderDockFleet(_ world: inout World, _ fleet: FleetID, inPort port: ProvinceID) -> Bool {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i],
              world.navy.fleets.battle[i] == nil else { return false }
        let owner = world.navy.fleets.owner[i]
        guard canDock(world, owner, in: port) else { return false }
        let curLoc = world.navy.fleets.location[i]
        if curLoc == .port(port) {
            world.navy.fleets.path[i].removeAll()
            world.navy.fleets.destinationPort[i] = nil
            world.navy.fleets.moveStepDays[i] = 0
            world.navy.fleets.moveProgressDays[i] = 0
            return true
        }
        let portSeas = world.provinceSeas[port.index]
        guard !portSeas.isEmpty else { return false }

        // Pick the shortest path among sea zones touching `port`.
        var bestRoute: [SeaZoneID]?
        for sz in portSeas {
            guard let r = findSeaPath(world, from: curLoc, to: sz) else { continue }
            if bestRoute == nil || r.count < bestRoute!.count {
                bestRoute = r
            }
        }
        guard let chosen = bestRoute else { return false }
        world.navy.fleets.path[i] = chosen
        world.navy.fleets.destinationPort[i] = port
        world.navy.fleets.moveProgressDays[i] = 0
        if let firstHop = chosen.first {
            if case .sea(let curSea) = curLoc {
                world.navy.fleets.moveStepDays[i] = seaStepDays(world, from: curSea, to: firstHop, fleet: fleet)
            } else {
                world.navy.fleets.moveStepDays[i] = 1.0
            }
        } else {
            // Already standing in an adjacent sea zone: dock takes 1 day.
            world.navy.fleets.moveStepDays[i] = 1.0
        }
        return true
    }

    // MARK: - Supply Range, Daily Movement & Attrition

    /// Shortest sea-zone distance (in hops, `Int.max` if unreachable) from `sea`
    /// to any sea zone adjacent to a port friendly to `country`.
    public static func seaSupplyHops(_ world: World, from sea: SeaZoneID, for country: CountryID) -> Int {
        var friendlyZones = Set<SeaZoneID>()
        for p in 0..<world.provinces.count where world.hasSeaAccess(ProvinceID(p)) {
            if canDock(world, country, in: ProvinceID(p)) {
                for sz in world.provinceSeas[p] {
                    friendlyZones.insert(sz)
                }
            }
        }
        if friendlyZones.contains(sea) { return 0 }
        var visited: Set<SeaZoneID> = [sea]
        var frontier: [SeaZoneID] = [sea]
        var depth = 0
        while !frontier.isEmpty && depth <= NavyModel.supplyRangeHops + 1 {
            depth += 1
            var nextFrontier: [SeaZoneID] = []
            for cur in frontier {
                for nb in world.seaZones.neighbors[cur.index] where !visited.contains(nb) {
                    if friendlyZones.contains(nb) { return depth }
                    visited.insert(nb)
                    nextFrontier.append(nb)
                }
            }
            frontier = nextFrontier
        }
        return Int.max
    }

    /// Average hull percentage across alive ships in `fleet`.
    public static func fleetAverageHull(_ world: World, _ fleet: FleetID) -> Double {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return 0 }
        var total = 0.0
        var cnt = 0
        for sIdx in world.navy.fleets.shipIndices[i] where world.navy.ships.alive[sIdx] {
            total += world.navy.ships.hull[sIdx]
            cnt += 1
        }
        return cnt > 0 ? total / Double(cnt) : 0
    }

    /// Relative naval combat score of `fleet` (used by Fleet AI to evaluate engagements).
    public static func fleetStrength(_ world: World, _ fleet: FleetID, in sea: SeaZoneID? = nil) -> Double {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return 0 }
        let inland: Bool
        if let sea {
            inland = sea.index < world.seaZones.isInland.count && world.seaZones.isInland[sea.index]
        } else if case .sea(let curSea) = world.navy.fleets.location[i] {
            inland = curSea.index < world.seaZones.isInland.count && world.seaZones.isInland[curSea.index]
        } else {
            inland = true
        }
        var score = 0.0
        for sIdx in world.navy.fleets.shipIndices[i] where world.navy.ships.alive[sIdx] {
            let st = world.navy.shipType(world.navy.ships.type[sIdx])
            let hullMult = max(0.1, world.navy.ships.hull[sIdx] / 100.0)
            var sPower = st.maxHull * 0.4 + Double(st.cannons) * 8.0 + Double(world.navy.ships.crew[sIdx]) * 0.25
            if st.shipClass == .galley && inland {
                sPower *= 1.5
            }
            score += sPower * hullMult
        }
        if let adm = world.navy.fleets.admiral[i], world.people.characters.isAlive(adm) {
            let m = world.people.characters.skill(adm, .martial)
            score *= max(0.8, 1.0 + Double(m - 5) * 0.05)
        }
        return score
    }

    /// Marks `fleet` sunk if no ships remain alive.
    static func cleanupIfEmpty(_ world: inout World, fleet: FleetID) {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return }
        let aliveCount = world.navy.fleets.shipIndices[i].count { world.navy.ships.alive[$0] }
        if aliveCount == 0 {
            world.navy.fleets.alive[i] = false
            world.navy.fleets.path[i].removeAll()
            world.navy.fleets.destinationPort[i] = nil
            world.navy.fleets.admiral[i] = nil
            // Any armies trapped aboard a sunk fleet are destroyed.
            for aid in world.navy.fleets.embarkedArmies[i] {
                let ai = Int(aid.rawValue)
                if ai >= 0 && ai < world.military.armies.count && world.military.armies.alive[ai] {
                    world.military.armies.remove(aid)
                }
            }
            world.navy.fleets.embarkedArmies[i].removeAll()
        }
    }

    /// Advances all fleets by one day: dead admiral cleanup, hostile-port ejection,
    /// daily movement & docking, sea supply/attrition, and carried army locations.
    public static func runDaily(_ world: inout World, date: GameDate, random: inout GameRandom) {
        for c in 0..<world.navy.lastAttritionLosses.count {
            if date.day == 1 {
                world.navy.lastAttritionLosses[c] = 0
            }
        }

        for i in 0..<world.navy.fleets.count where world.navy.fleets.alive[i] {
            let fid = FleetID(i)
            let owner = world.navy.fleets.owner[i]

            if let adm = world.navy.fleets.admiral[i], !world.people.characters.isAlive(adm) {
                world.navy.fleets.admiral[i] = nil
            }

            if world.navy.fleets.battle[i] != nil { continue }

            // Eject fleet from a port if the port is no longer friendly (e.g. occupied in war).
            if case .port(let p) = world.navy.fleets.location[i], !canDock(world, owner, in: p) {
                if let adjSea = world.provinceSeas[p.index].first {
                    world.navy.fleets.location[i] = .sea(adjSea)
                    world.navy.fleets.destinationPort[i] = nil
                    world.navy.fleets.path[i].removeAll()
                }
            }

            // Advance movement along sea path or dock into destinationPort.
            if let nextHop = world.navy.fleets.path[i].first {
                if world.navy.fleets.moveStepDays[i] <= 0 {
                    if case .sea(let curSea) = world.navy.fleets.location[i] {
                        world.navy.fleets.moveStepDays[i] = seaStepDays(world, from: curSea, to: nextHop, fleet: fid)
                    } else {
                        world.navy.fleets.moveStepDays[i] = 1.0
                    }
                }
                world.navy.fleets.moveProgressDays[i] += 1.0
                if world.navy.fleets.moveProgressDays[i] >= world.navy.fleets.moveStepDays[i] {
                    world.navy.fleets.location[i] = .sea(nextHop)
                    world.navy.fleets.path[i].removeFirst()
                    world.navy.fleets.moveProgressDays[i] = 0
                    if let following = world.navy.fleets.path[i].first {
                        world.navy.fleets.moveStepDays[i] = seaStepDays(world, from: nextHop, to: following, fleet: fid)
                    } else if let destPort = world.navy.fleets.destinationPort[i] {
                        if canDock(world, owner, in: destPort) && world.provinceSeas[destPort.index].contains(nextHop) {
                            world.navy.fleets.moveStepDays[i] = 1.0
                        } else {
                            world.navy.fleets.destinationPort[i] = nil
                            world.navy.fleets.moveStepDays[i] = 0
                        }
                    } else {
                        world.navy.fleets.moveStepDays[i] = 0
                    }
                }
            } else if let destPort = world.navy.fleets.destinationPort[i],
                      case .sea(let curSea) = world.navy.fleets.location[i] {
                if canDock(world, owner, in: destPort) && world.provinceSeas[destPort.index].contains(curSea) {
                    world.navy.fleets.moveProgressDays[i] += 1.0
                    if world.navy.fleets.moveProgressDays[i] >= max(1.0, world.navy.fleets.moveStepDays[i]) {
                        world.navy.fleets.location[i] = .port(destPort)
                        world.navy.fleets.destinationPort[i] = nil
                        world.navy.fleets.moveStepDays[i] = 0
                        world.navy.fleets.moveProgressDays[i] = 0
                    }
                } else {
                    world.navy.fleets.destinationPort[i] = nil
                    world.navy.fleets.moveStepDays[i] = 0
                    world.navy.fleets.moveProgressDays[i] = 0
                }
            }

            // Sea supply & attrition when at sea.
            if case .sea(let seaZone) = world.navy.fleets.location[i] {
                let hops = seaSupplyHops(world, from: seaZone, for: owner)
                let inRange = hops <= NavyModel.supplyRangeHops
                let hasGalley = world.navy.fleets.shipIndices[i].contains { sIdx in
                    world.navy.ships.alive[sIdx] && world.navy.shipType(world.navy.ships.type[sIdx]).shipClass == .galley
                }
                let isInland = seaZone.index < world.seaZones.isInland.count && world.seaZones.isInland[seaZone.index]

                if !inRange {
                    world.navy.fleets.supply[i] = max(0, world.navy.fleets.supply[i] - NavyModel.deepSeaSupplyDrainPerDay)
                }
                if hasGalley && !isInland {
                    world.navy.fleets.supply[i] = max(0, world.navy.fleets.supply[i] - NavyModel.galleyOpenOceanDrainPerDay)
                }
                if inRange && !(hasGalley && !isInland) {
                    world.navy.fleets.supply[i] = min(100.0, world.navy.fleets.supply[i] + 1.0)
                }

                if world.navy.fleets.supply[i] <= 0 {
                    var crewLost = 0
                    for sIdx in world.navy.fleets.shipIndices[i] where world.navy.ships.alive[sIdx] {
                        let st = world.navy.shipType(world.navy.ships.type[sIdx])
                        // Galleys in open ocean take heavier storm wear.
                        let mult = (st.shipClass == .galley && !isInland) ? 1.5 : 1.0
                        world.navy.ships.hull[sIdx] -= NavyModel.attritionHullLossPerDay * mult
                        let cLoss = max(1, Int((Double(world.navy.ships.crew[sIdx]) * NavyModel.attritionCrewFractionPerDay).rounded()))
                        let actualLoss = min(world.navy.ships.crew[sIdx], cLoss)
                        world.navy.ships.crew[sIdx] -= actualLoss
                        crewLost += actualLoss
                        if world.navy.ships.hull[sIdx] <= 0 {
                            world.navy.ships.alive[sIdx] = false
                            crewLost += world.navy.ships.crew[sIdx]
                            world.navy.ships.crew[sIdx] = 0
                        }
                    }
                    if owner.index < world.navy.lastAttritionLosses.count {
                        world.navy.lastAttritionLosses[owner.index] += crewLost
                    }
                    cleanupIfEmpty(&world, fleet: fid)
                }
            }
        }
    }
}
