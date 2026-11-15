import Foundation

/// Phase 10 Part D: army naval embarkation (1 Cog/transport per 1,000 men),
/// sea transport, amphibious disembarkation (`-2` landing battle penalty),
/// and AI overseas expedition routing.
extension NavySystem {

    /// Number of additional soldiers `fleet` can carry given its transport ships (1 ship per 1,000 men).
    public static func availableTransportMenCapacity(_ world: World, fleet: FleetID) -> Int {
        let fi = fleet.index
        guard fi >= 0 && fi < world.navy.fleets.count && world.navy.fleets.alive[fi] else { return 0 }
        let capMen = world.navy.transportCapacity(of: fleet) * 1000
        let aboardMen = world.navy.fleets.embarkedArmies[fi].reduce(0) { sum, aid in
            sum + world.military.armies.totalMen(of: aid)
        }
        return max(0, capMen - aboardMen)
    }

    /// True when `army` can board `fleet` in its current port.
    public static func canEmbark(_ world: World, army: ArmyID, onto fleet: FleetID) -> Bool {
        let ai = Int(army.rawValue)
        let fi = fleet.index
        guard ai >= 0 && ai < world.military.armies.count && world.military.armies.alive[ai],
              fi >= 0 && fi < world.navy.fleets.count && world.navy.fleets.alive[fi],
              !world.military.armies.isRebel[ai],
              !world.military.armies.isRetreating[ai],
              world.military.armies.embarkedOnFleet[ai] == nil,
              !world.military.isInBattle(army),
              world.navy.fleets.battle[fi] == nil else { return false }

        let aOwner = world.military.armies.owner[ai]
        let fOwner = world.navy.fleets.owner[fi]
        guard aOwner == fOwner || world.diplomacy.areAllies(aOwner, fOwner) else { return false }

        let aProv = world.military.armies.province[ai]
        guard case .port(let portProv) = world.navy.fleets.location[fi], portProv == aProv else {
            return false
        }

        let men = world.military.armies.totalMen(of: army)
        guard men > 0 else { return false }
        let capShips = world.navy.transportCapacity(of: fleet)
        let aboardMen = world.navy.fleets.embarkedArmies[fi].reduce(0) {
            $0 + world.military.armies.totalMen(of: $1)
        }
        let neededShips = (aboardMen + men + 999) / 1000
        return neededShips <= capShips
    }

    /// Embarks `army` onto `fleet` docked in the army's coastal port (1 transport ship per 1,000 men).
    @discardableResult
    public static func embarkArmy(_ world: inout World, army: ArmyID, onto fleet: FleetID) -> Bool {
        guard canEmbark(world, army: army, onto: fleet) else { return false }
        let ai = Int(army.rawValue)
        let fi = fleet.index

        world.military.armies.embarkedOnFleet[ai] = fleet
        world.military.armies.path[ai].removeAll()
        world.military.armies.moveStepDays[ai] = 0
        world.military.armies.moveProgressDays[ai] = 0
        world.military.armies.amphibiousPenaltyDays[ai] = 0
        if !world.navy.fleets.embarkedArmies[fi].contains(army) {
            world.navy.fleets.embarkedArmies[fi].append(army)
        }
        return true
    }

    /// Coastal provinces touching the fleet's current location where `army` may disembark.
    public static func validDisembarkProvinces(_ world: World, for army: ArmyID) -> [ProvinceID] {
        let ai = Int(army.rawValue)
        guard ai >= 0 && ai < world.military.armies.count && world.military.armies.alive[ai],
              let fid = world.military.armies.embarkedOnFleet[ai],
              fid.index >= 0 && fid.index < world.navy.fleets.count && world.navy.fleets.alive[fid.index],
              world.navy.fleets.battle[fid.index] == nil else { return [] }

        let owner = world.military.armies.owner[ai]
        let candidates: [ProvinceID]
        switch world.navy.fleets.location[fid.index] {
        case .port(let p):
            candidates = [p]
        case .sea(let sz):
            candidates = world.seaZones.coast[sz.index].sorted { $0.index < $1.index }
        }

        return candidates.filter { p in
            guard world.hasSeaAccess(p) else { return false }
            guard let ctrl = world.provinces.controller(of: p) else { return false }
            return ctrl == owner
                || world.diplomacy.hasMilitaryAccess(country: owner, through: ctrl)
                || world.diplomacy.isAtWar(owner, ctrl)
        }
    }

    /// Lands an embarked `army` onto `destination` (or the default valid coastal province at the fleet's location).
    /// Landing onto enemy-held ground or straight into enemy forces inflicts an amphibious landing combat penalty (`-2`).
    @discardableResult
    public static func disembarkArmy(
        _ world: inout World,
        army: ArmyID,
        to destination: ProvinceID? = nil
    ) -> Bool {
        let ai = Int(army.rawValue)
        guard ai >= 0 && ai < world.military.armies.count && world.military.armies.alive[ai],
              let fid = world.military.armies.embarkedOnFleet[ai] else { return false }

        let valid = validDisembarkProvinces(world, for: army)
        let target: ProvinceID
        if let dest = destination {
            guard valid.contains(dest) else { return false }
            target = dest
        } else {
            guard let first = valid.first else { return false }
            target = first
        }

        let owner = world.military.armies.owner[ai]
        let ctrl = world.provinces.controller(of: target)
        let enemyArmiesPresent = world.military.armies(in: target).contains { other in
            let oi = Int(other.rawValue)
            return !world.military.armies.isRebel[oi]
                && world.diplomacy.isAtWar(owner, world.military.armies.owner[oi])
        }
        let isHostileLanding = (ctrl != nil && world.diplomacy.isAtWar(owner, ctrl!)) || enemyArmiesPresent

        world.military.armies.province[ai] = target
        world.military.armies.previousProvince[ai] = nil
        world.military.armies.embarkedOnFleet[ai] = nil
        world.military.armies.path[ai].removeAll()
        world.military.armies.moveStepDays[ai] = 0
        world.military.armies.moveProgressDays[ai] = 0
        world.military.armies.amphibiousPenaltyDays[ai] = isHostileLanding ? 3 : 0

        if fid.index >= 0 && fid.index < world.navy.fleets.count {
            world.navy.fleets.embarkedArmies[fid.index].removeAll { $0 == army }
            if world.navy.fleets.embarkedArmies[fid.index].isEmpty {
                world.navy.fleets.transportTarget[fid.index] = nil
                if world.navy.fleets.mission[fid.index] == .transport {
                    world.navy.fleets.mission[fid.index] = .idle
                }
            }
        }
        return true
    }

    /// Orders `fleet` to sail to sea adjacent to coastal `targetProvince` and auto-disembark carried armies there.
    @discardableResult
    public static func orderTransportAndLand(_ world: inout World, fleet: FleetID, to targetProvince: ProvinceID) -> Bool {
        let fi = fleet.index
        guard fi >= 0 && fi < world.navy.fleets.count && world.navy.fleets.alive[fi],
              world.hasSeaAccess(targetProvince),
              !world.navy.fleets.embarkedArmies[fi].isEmpty else { return false }

        let seas = world.provinceSeas[targetProvince.index]
        guard !seas.isEmpty else { return false }

        var bestSea = seas[0]
        var bestPath: [SeaZoneID]?
        for sz in seas {
            if let path = findSeaPath(world, from: world.navy.fleets.location[fi], to: sz) {
                if bestPath == nil || path.count < bestPath!.count {
                    bestPath = path
                    bestSea = sz
                }
            }
        }
        guard bestPath != nil else { return false }
        guard orderMoveFleet(&world, fleet, toSea: bestSea) else { return false }
        world.navy.fleets.mission[fi] = .transport
        world.navy.fleets.transportTarget[fi] = targetProvince
        return true
    }

    /// Called daily during `NavyMovement.runDaily` to auto-disembark armies whose transport reached its shore.
    static func completeTransportArrivalIfReady(_ world: inout World, fleet: FleetID) {
        let fi = fleet.index
        guard fi >= 0 && fi < world.navy.fleets.count && world.navy.fleets.alive[fi],
              let target = world.navy.fleets.transportTarget[fi],
              world.navy.fleets.path[fi].isEmpty,
              world.navy.fleets.battle[fi] == nil else { return }

        let adjacent: Bool
        switch world.navy.fleets.location[fi] {
        case .port(let p): adjacent = p == target
        case .sea(let sz): adjacent = world.provinceSeas[target.index].contains(sz)
        }
        guard adjacent else { return }

        let embarked = world.navy.fleets.embarkedArmies[fi]
        for aid in embarked {
            _ = disembarkArmy(&world, army: aid, to: target)
        }
        world.navy.fleets.transportTarget[fi] = nil
        if world.navy.fleets.mission[fi] == .transport {
            world.navy.fleets.mission[fi] = .idle
        }
    }

    // MARK: - AI Overseas Naval Transport

    /// Coordinates an AI army and a friendly transport fleet when land routes are blocked by water:
    /// marches/docks both at a shared coastal port, embarks the army, and sails to land on an overseas coastal target.
    @discardableResult
    public static func arrangeAITransport(
        _ world: inout World,
        country: CountryID,
        army: ArmyID,
        overseasTargets: [ProvinceID],
        armyLandMass: Int,
        landMass: [Int]
    ) -> Bool {
        let ai = Int(army.rawValue)
        guard ai >= 0 && ai < world.military.armies.count && world.military.armies.alive[ai],
              world.military.armies.embarkedOnFleet[ai] == nil,
              !world.military.armies.isRebel[ai],
              !world.military.armies.isRetreating[ai] else { return false }

        let coastalTargets = overseasTargets.filter { world.hasSeaAccess($0) }
        guard !coastalTargets.isEmpty else { return false }

        let men = world.military.armies.totalMen(of: army)
        guard men > 0 else { return false }
        let curProv = world.military.armies.province[ai]

        // Find a friendly fleet with enough transport capacity.
        let fleets = world.navy.fleets(of: country)
        var chosenFleet: FleetID?
        for fid in fleets {
            let fi = fid.index
            guard world.navy.fleets.battle[fi] == nil,
                  availableTransportMenCapacity(world, fleet: fid) >= men else { continue }
            if case .port(let p) = world.navy.fleets.location[fi], p == curProv {
                chosenFleet = fid
                break
            }
            if world.navy.fleets.mission[fi] != .transport && chosenFleet == nil {
                chosenFleet = fid
            }
        }
        guard let fleet = chosenFleet else { return false }
        let fi = fleet.index

        // Case 1: Army and fleet are already together in port — embark and sail to closest reachable target.
        if case .port(let portProv) = world.navy.fleets.location[fi], portProv == curProv {
            var bestTarget: ProvinceID?
            var bestHops = Int.max
            for t in coastalTargets {
                for sz in world.provinceSeas[t.index] {
                    if let path = findSeaPath(world, from: .port(portProv), to: sz), path.count < bestHops {
                        bestHops = path.count
                        bestTarget = t
                    }
                }
            }
            guard let target = bestTarget,
                  embarkArmy(&world, army: army, onto: fleet) else { return false }
            return orderTransportAndLand(&world, fleet: fleet, to: target)
        }

        // Case 2: Bring army and fleet together at a friendly coastal port on the army's landmass.
        let friendlyPorts = world.provinces(ownedBy: country).filter { p in
            world.hasSeaAccess(p)
                && landMass[p.index] == armyLandMass
                && canDock(world, country, in: p)
        }
        guard !friendlyPorts.isEmpty else { return false }

        let embarkPort: ProvinceID
        if world.hasSeaAccess(curProv) && canDock(world, country, in: curProv) {
            embarkPort = curProv
        } else {
            let armyPt = world.provinces.labelPoint[curProv.index]
            embarkPort = friendlyPorts.min { a, b in
                let ptA = world.provinces.labelPoint[a.index]
                let ptB = world.provinces.labelPoint[b.index]
                let da = DetMath.length(Double(ptA.x - armyPt.x), Double(ptA.y - armyPt.y))
                let db = DetMath.length(Double(ptB.x - armyPt.x), Double(ptB.y - armyPt.y))
                return abs(da - db) > 0.01 ? da < db : a.index < b.index
            }!
        }

        world.navy.fleets.mission[fi] = .transport
        if world.navy.fleets.location[fi] != .port(embarkPort) && world.navy.fleets.destinationPort[fi] != embarkPort {
            _ = orderDockFleet(&world, fleet, inPort: embarkPort)
        }
        if curProv != embarkPort {
            _ = ArmySystem.orderMove(&world, army: army, to: embarkPort)
        }
        return true
    }
}
