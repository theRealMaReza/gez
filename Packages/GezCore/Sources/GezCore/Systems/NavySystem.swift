import Foundation

/// Tuning constants for Phase 10 (Navies).
public enum NavyModel {
    /// Share of coastal peasant + burgher pops forming the national sailor pool.
    public static let sailorCoastalPopShare = 0.008
    /// Bonus sailors per Shipyard / Docks building level in owned coastal provinces.
    public static let sailorsPerDockLevel = 250.0
    /// Months to refill an empty national sailor pool from 0 to max.
    public static let sailorRecoveryMonths = 60.0
    /// Global naval upkeep scale aligned with army upkeep balance.
    public static let upkeepScale = 0.55
    /// Monthly hull repair rate (percentage points) when docked in a friendly port.
    public static let portRepairPerMonth = 15.0
    /// Monthly crew reinforcement rate (fraction of maxCrew) in a friendly port.
    public static let crewReinforcePerMonth = 0.25
}

/// Reasons why starting ship construction in a province is refused.
public enum NavyRefusal: Error, Equatable, Sendable {
    case notOwner
    case provinceOccupied
    case notCoastal
    case noDocks
    case dockBusy
    case shipLocked
    case notEnoughSailors
    case cannotAfford

    public var reason: String {
        switch self {
        case .notOwner:          return "Not your province"
        case .provinceOccupied:  return "Province is occupied"
        case .notCoastal:        return "Province is landlocked"
        case .noDocks:           return "Requires a Shipyard / Docks"
        case .dockBusy:          return "All slipways in this port are busy"
        case .shipLocked:        return "Ship class not available to your realm"
        case .notEnoughSailors:  return "Not enough sailors"
        case .cannotAfford:      return "Not enough ducats"
        }
    }
}

/// Phase 10 naval simulation system (Part A: sailors, docks, shipbuilding, upkeep).
public enum NavySystem {

    // MARK: - Settle & Sailors

    /// Recomputes `maxSailors` from coastal peasant/burgher pops and docks,
    /// seeding or clamping national `sailors`.
    public static func settle(_ world: inout World, seedPool: Bool = false) {
        let C = world.countries.count
        if world.navy.sailors.count != C {
            world.navy.resize(countries: C)
        }
        for c in world.countries.ids {
            let maxS = calculateMaxSailors(world, c)
            world.navy.maxSailors[c.index] = maxS
            if seedPool {
                world.navy.sailors[c.index] = (maxS * 0.75).rounded()
            } else {
                world.navy.sailors[c.index] = min(world.navy.sailors[c.index], maxS)
            }
        }
    }

    /// Computes national maximum sailors from owned coastal provinces' peasant
    /// and burgher populations plus Shipyard / Docks bonuses.
    public struct SailorComponents: Sendable, Equatable {
        public let hasCoast: Bool
        public let coastalPopBase: Double
        public let dockBonus: Double
        public let floorDelta: Double
        public let maxSailors: Double
    }

    public static func sailorComponents(_ world: World, _ country: CountryID) -> SailorComponents {
        let owned = world.provinces(ownedBy: country)
        guard !owned.isEmpty else {
            return SailorComponents(hasCoast: false, coastalPopBase: 0, dockBonus: 0, floorDelta: 0, maxSailors: 0)
        }

        var coastalWorkforce = 0.0
        var dockBonus = 0.0
        var hasCoast = false
        let T = world.economy.buildings.typeCount

        for pid in owned {
            let p = pid.index
            guard world.hasSeaAccess(pid) else { continue }
            guard world.provinces.occupiedBy[p] == nil else { continue }
            if let holder = world.provinces.holder[p], world.people.refusing.contains(holder) {
                continue
            }
            hasCoast = true
            let range = world.pops.range(for: pid)
            var provMaritimePop = 0.0
            for k in range {
                let cls = world.pops.socialClass[k]
                if cls == .peasants || cls == .burghers {
                    let weight = (cls == .burghers) ? 1.5 : 1.0
                    provMaritimePop += world.pops.size[k] * weight
                }
            }
            if range.isEmpty {
                provMaritimePop = world.provinces.population[p]
            }
            coastalWorkforce += provMaritimePop

            for t in 0..<T {
                if case .ships(let x) = world.economy.buildingTypes[t].effect {
                    let lvl = world.economy.buildings.level(pid, BuildingTypeID(t))
                    if lvl > 0 {
                        dockBonus += Double(lvl) * max(1.0, x * 0.5) * NavyModel.sailorsPerDockLevel
                    }
                }
            }
        }

        guard hasCoast else {
            return SailorComponents(hasCoast: false, coastalPopBase: 0, dockBonus: 0, floorDelta: 0, maxSailors: 0)
        }
        let popBase = coastalWorkforce * NavyModel.sailorCoastalPopShare
        let raw = popBase + dockBonus
        let total = max(200.0, raw.rounded())
        return SailorComponents(
            hasCoast: true,
            coastalPopBase: popBase,
            dockBonus: dockBonus,
            floorDelta: total - raw,
            maxSailors: total
        )
    }

    public static func calculateMaxSailors(_ world: World, _ country: CountryID) -> Double {
        sailorComponents(world, country).maxSailors
    }

    public static func monthlySailorGain(_ world: World, _ country: CountryID) -> Double {
        let maxS = world.navy.maxSailors[country.index]
        guard world.navy.sailors[country.index] < maxS else { return 0 }
        return (maxS / NavyModel.sailorRecoveryMonths).rounded()
    }

    // MARK: - Ship Unlocks, Costs & Construction

    public static func canBuildShip(_ world: World, _ country: CountryID, _ shipType: ShipTypeID) -> Bool {
        let s = world.navy.shipType(shipType)
        guard world.tech.level(country, .diplomatic) >= s.minDipTech else { return false }
        return UnitUnlock.matches(s.requires, in: world, for: country)
    }

    /// Explains why `shipType` is locked for `country`, or `nil` if unlocked.
    public static func shipLockReason(_ world: World, _ country: CountryID, _ shipType: ShipTypeID) -> String? {
        let s = world.navy.shipType(shipType)
        if world.tech.level(country, .diplomatic) < s.minDipTech {
            return "Requires Diplomatic Tech \(s.minDipTech)"
        }
        if !UnitUnlock.matches(s.requires, in: world, for: country) {
            return NavyRefusal.shipLocked.reason
        }
        return nil
    }

    public static func availableShipTypes(_ world: World, for country: CountryID) -> [ShipType] {
        world.navy.shipTypes.filter { canBuildShip(world, country, $0.id) }
    }

    /// Ducat cost to lay down a ship of `shipType` in `province`
    /// (base cost + local market price of required goods, scaled by inflation).
    public static func shipBuildCost(
        _ world: World,
        _ country: CountryID,
        in province: ProvinceID,
        type shipType: ShipTypeID
    ) -> Double {
        let s = world.navy.shipType(shipType)
        var total = s.cost
        if let m = world.market(of: province) {
            for (g, amount) in s.goods {
                total += amount * world.economy.markets.price(m, g)
            }
        }
        total *= (1.0 + world.countries.inflation[country.index])
        return total.rounded()
    }

    /// Active ship constructions currently occupying slipways in `province`.
    public static func activeConstructions(in province: ProvinceID, world: World) -> Int {
        world.navy.constructions.count { $0.province == province }
    }

    public static func buildShipRefusal(
        _ world: World,
        _ country: CountryID,
        in province: ProvinceID,
        type shipType: ShipTypeID,
        checkMoney: Bool = true
    ) -> NavyRefusal? {
        if world.provinces.owner[province.index] != country { return .notOwner }
        if world.provinces.occupiedBy[province.index] != nil { return .provinceOccupied }
        if !world.hasSeaAccess(province) { return .notCoastal }
        let cap = world.dockCapacity(in: province)
        if cap <= 0 { return .noDocks }
        if activeConstructions(in: province, world: world) >= cap { return .dockBusy }
        if !canBuildShip(world, country, shipType) { return .shipLocked }
        let s = world.navy.shipType(shipType)
        if world.navy.sailors[country.index] < Double(s.maxCrew) { return .notEnoughSailors }
        if checkMoney && world.countries.treasury[country.index] < shipBuildCost(world, country, in: province, type: shipType) {
            return .cannotAfford
        }
        return nil
    }

    /// Starts building a ship in a coastal province with Docks/Shipyard,
    /// charging ducats and sailors and adding wood/naval_supplies/cloth/cannons
    /// to the local market's `pendingDemand`.
    @discardableResult
    public static func startShipConstruction(
        _ world: inout World,
        _ country: CountryID,
        in province: ProvinceID,
        type shipType: ShipTypeID,
        targetFleet: FleetID? = nil
    ) -> Result<ShipConstruction, NavyRefusal> {
        if let ref = buildShipRefusal(world, country, in: province, type: shipType) {
            return .failure(ref)
        }
        let s = world.navy.shipType(shipType)
        let cost = shipBuildCost(world, country, in: province, type: shipType)
        world.countries.treasury[country.index] -= cost
        world.navy.sailors[country.index] = max(0, world.navy.sailors[country.index] - Double(s.maxCrew))

        if let m = world.market(of: province) {
            for (g, amount) in s.goods {
                world.economy.markets.pendingDemand[world.economy.markets.slot(m, g)] += amount
            }
        }

        let job = ShipConstruction(
            country: country,
            province: province,
            shipType: shipType,
            targetFleet: targetFleet,
            monthsTotal: s.buildMonths,
            monthsLeft: s.buildMonths
        )
        world.navy.constructions.append(job)
        return .success(job)
    }

    /// Cancels a queued ship construction in `province` (returns partial ducats and sailors).
    @discardableResult
    public static func cancelShipConstruction(_ world: inout World, at index: Int) -> Bool {
        guard index >= 0 && index < world.navy.constructions.count else { return false }
        let job = world.navy.constructions.remove(at: index)
        let s = world.navy.shipType(job.shipType)
        world.countries.treasury[job.country.index] += (s.cost * 0.5).rounded()
        let maxS = world.navy.maxSailors[job.country.index]
        world.navy.sailors[job.country.index] = min(maxS, world.navy.sailors[job.country.index] + Double(s.maxCrew))
        return true
    }

    // MARK: - Monthly Tick (Constructions, Sailors, Repairs, Upkeep)

    public static func runMonthly(_ world: inout World) {
        let C = world.countries.count
        settle(&world, seedPool: false)

        // 1. Progress active ship constructions; launch finished hulls into port.
        var remaining: [ShipConstruction] = []
        remaining.reserveCapacity(world.navy.constructions.count)
        for var job in world.navy.constructions {
            // Cancel if province changed owner or was occupied.
            guard world.provinces.owner[job.province.index] == job.country,
                  world.provinces.occupiedBy[job.province.index] == nil else {
                continue
            }
            job.monthsLeft -= 1
            if job.monthsLeft <= 0 {
                launchShip(&world, country: job.country, in: job.province, type: job.shipType, preferredFleet: job.targetFleet)
            } else {
                remaining.append(job)
            }
        }
        world.navy.constructions = remaining

        // 2. Replenish national sailor pools.
        for c in world.countries.ids {
            let gain = monthlySailorGain(world, c)
            if gain > 0 {
                world.navy.sailors[c.index] = min(world.navy.maxSailors[c.index], world.navy.sailors[c.index] + gain)
            }
        }

        // 3. Repair hull & reinforce crew in friendly ports, and resupply docked fleets.
        for fIdx in 0..<world.navy.fleets.count where world.navy.fleets.alive[fIdx] {
            let owner = world.navy.fleets.owner[fIdx]
            if case .port(let portProv) = world.navy.fleets.location[fIdx] {
                let portOwner = world.provinces.controller(of: portProv)
                let friendly = portOwner == owner
                    || (portOwner != nil && world.diplomacy.hasMilitaryAccess(country: owner, through: portOwner!))
                if friendly {
                    world.navy.fleets.supply[fIdx] = 100.0
                    for sIdx in world.navy.fleets.shipIndices[fIdx] where world.navy.ships.alive[sIdx] {
                        if world.navy.ships.hull[sIdx] < 100.0 {
                            world.navy.ships.hull[sIdx] = min(100.0, world.navy.ships.hull[sIdx] + NavyModel.portRepairPerMonth)
                        }
                        let sType = world.navy.shipType(world.navy.ships.type[sIdx])
                        let missing = sType.maxCrew - world.navy.ships.crew[sIdx]
                        if missing > 0 && world.navy.sailors[owner.index] > 0 {
                            let step = max(1, Int((Double(sType.maxCrew) * NavyModel.crewReinforcePerMonth).rounded()))
                            let transfer = min(missing, min(step, Int(world.navy.sailors[owner.index])))
                            world.navy.ships.crew[sIdx] += transfer
                            world.navy.sailors[owner.index] -= Double(transfer)
                        }
                        if world.navy.ships.morale[sIdx] < 3.0 {
                            world.navy.ships.morale[sIdx] = min(3.0, world.navy.ships.morale[sIdx] + 0.5)
                        }
                    }
                }
            }
        }

        // 4. Deduct monthly naval upkeep.
        var upkeep = Array(repeating: 0.0, count: C)
        for sIdx in 0..<world.navy.ships.count where world.navy.ships.alive[sIdx] {
            let fIdx = world.navy.ships.fleet[sIdx].index
            guard fIdx >= 0 && fIdx < world.navy.fleets.count && world.navy.fleets.alive[fIdx] else { continue }
            let cid = world.navy.fleets.owner[fIdx].index
            let u = world.navy.shipType(world.navy.ships.type[sIdx]).upkeep * NavyModel.upkeepScale
            upkeep[cid] += u
        }
        for c in 0..<C {
            world.countries.treasury[c] -= upkeep[c]
            world.navy.lastNavyUpkeep[c] = upkeep[c]
            world.countries.lastMonthlyExpenses[c] += upkeep[c]
        }
    }

    /// Launches a newly completed ship into an existing docked fleet in `province`
    /// or creates a new fleet stationed at `.port(province)`.
    @discardableResult
    public static func launchShip(
        _ world: inout World,
        country: CountryID,
        in province: ProvinceID,
        type shipType: ShipTypeID,
        preferredFleet: FleetID? = nil
    ) -> FleetID {
        let target: FleetID
        if let pf = preferredFleet,
           pf.index < world.navy.fleets.count,
           world.navy.fleets.alive[pf.index],
           world.navy.fleets.owner[pf.index] == country,
           world.navy.fleets.location[pf.index] == .port(province) {
            target = pf
        } else if let docked = world.navy.fleets(inPort: province).first(where: {
            world.navy.fleets.owner[$0.index] == country
        }) {
            target = docked
        } else {
            let cname = world.countries.name[country.index]
            let pname = world.provinces.name[province.index]
            target = world.navy.fleets.append(
                name: "\(cname) Fleet of \(pname)",
                owner: country,
                location: .port(province)
            )
        }
        let stype = world.navy.shipType(shipType)
        let sIdx = world.navy.ships.add(
            type: shipType,
            fleet: target,
            hull: 100.0,
            crew: stype.maxCrew,
            morale: 3.0,
            originProvince: province
        )
        world.navy.fleets.shipIndices[target.index].append(sIdx)
        return target
    }

    /// Monthly upkeep in ducats for a single fleet.
    public static func fleetUpkeep(_ world: World, _ fleet: FleetID) -> Double {
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] else { return 0 }
        var sum = 0.0
        for sIdx in world.navy.fleets.shipIndices[i] where world.navy.ships.alive[sIdx] {
            sum += world.navy.shipType(world.navy.ships.type[sIdx]).upkeep * NavyModel.upkeepScale
        }
        return sum
    }
}
