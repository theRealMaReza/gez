import Foundation

/// Functional ship classes in Phase 10 (4 core roles).
public enum ShipClass: String, CaseIterable, Sendable, Codable {
    /// Merchant/troop cog: 1 transport slot (1,000 soldiers) per ship.
    case transport
    /// Oared warship: +50% combat bonus and +25% speed in inland seas.
    case galley
    /// Heavy broadside warship: durable hull and heavy cannon battery.
    case heavy
    /// Fast caravel / dhow: trade protection, coastal patrol, scouting.
    case light

    public var displayName: String {
        switch self {
        case .transport: return "Transport"
        case .galley:    return "Galley"
        case .heavy:     return "Heavy Ship"
        case .light:     return "Light Ship"
        }
    }
}

/// Static prototype definition for a ship type loaded from `navy1453.json`.
public struct ShipType: Sendable {
    public var id: ShipTypeID
    public var key: String
    public var name: String
    public var shipClass: ShipClass
    public var speed: Double
    public var maxHull: Double
    public var cannons: Int
    public var maxCrew: Int
    public var buildMonths: Int
    public var cost: Double
    public var upkeep: Double
    /// Troops capacity measured in 1,000-man regiments (1 for Cogs, 0 otherwise).
    public var capacity: Int
    /// Market goods required when starting construction.
    public var goods: [(GoodID, Double)]
    /// Unlock rules using the same clause syntax as `UnitType`.
    public var requires: [UnitUnlock]

    public init(
        id: ShipTypeID,
        key: String,
        name: String,
        shipClass: ShipClass,
        speed: Double,
        maxHull: Double,
        cannons: Int,
        maxCrew: Int,
        buildMonths: Int,
        cost: Double,
        upkeep: Double,
        capacity: Int,
        goods: [(GoodID, Double)],
        requires: [UnitUnlock]
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.shipClass = shipClass
        self.speed = speed
        self.maxHull = maxHull
        self.cannons = cannons
        self.maxCrew = maxCrew
        self.buildMonths = buildMonths
        self.cost = cost
        self.upkeep = upkeep
        self.capacity = capacity
        self.goods = goods
        self.requires = requires
    }
}

/// Struct-of-Arrays storing every individual ship in the world.
public struct ShipTable: Sendable, Codable {
    public var alive: [Bool] = []
    public var type: [ShipTypeID] = []
    public var fleet: [FleetID] = []
    /// Hull integrity percentage (0...100).
    public var hull: [Double] = []
    public var crew: [Int] = []
    public var morale: [Double] = []
    public var originProvince: [ProvinceID?] = []

    public init() {}

    public var count: Int { alive.count }

    @discardableResult
    public mutating func add(
        type: ShipTypeID,
        fleet: FleetID,
        hull: Double = 100.0,
        crew: Int,
        morale: Double = 3.0,
        originProvince: ProvinceID? = nil
    ) -> Int {
        let idx = alive.count
        alive.append(true)
        self.type.append(type)
        self.fleet.append(fleet)
        self.hull.append(hull)
        self.crew.append(crew)
        self.morale.append(morale)
        self.originProvince.append(originProvince)
        return idx
    }
}

/// Where a fleet is stationed: docked inside a coastal province port or at sea.
public enum FleetLocation: Hashable, Sendable, Codable {
    case port(ProvinceID)
    case sea(SeaZoneID)
}

/// Automated/ordered mission of a fleet.
public enum FleetMission: String, Sendable, Codable {
    case idle
    case patrol
    case hunt
    case blockade
    case transport
}

/// Struct-of-Arrays storing every active fleet on the map.
public struct FleetTable: Sendable, Codable {
    public var alive: [Bool] = []
    public var name: [String] = []
    public var owner: [CountryID] = []
    public var admiral: [CharacterID?] = []
    public var location: [FleetLocation] = []
    public var mission: [FleetMission] = []
    /// Remaining sea-zone path hops.
    public var path: [[SeaZoneID]] = []
    /// Optional coastal province to enter once `path` empties.
    public var destinationPort: [ProvinceID?] = []
    public var moveStepDays: [Double] = []
    public var moveProgressDays: [Double] = []
    /// Ship provisions (0...100); depletes slowly away from friendly ports.
    public var supply: [Double] = []
    /// Armies currently embarked aboard this fleet.
    public var embarkedArmies: [[ArmyID]] = []
    /// Index into `Navy.battles` if engaged, else `nil`.
    public var battle: [Int?] = []
    /// Indices into `ShipTable` belonging to this fleet.
    public var shipIndices: [[Int]] = []

    public init() {}

    public var count: Int { alive.count }

    @discardableResult
    public mutating func append(
        name: String,
        owner: CountryID,
        location: FleetLocation,
        admiral: CharacterID? = nil,
        mission: FleetMission = .idle
    ) -> FleetID {
        let id = FleetID(alive.count)
        alive.append(true)
        self.name.append(name)
        self.owner.append(owner)
        self.admiral.append(admiral)
        self.location.append(location)
        self.mission.append(mission)
        self.path.append([])
        self.destinationPort.append(nil)
        self.moveStepDays.append(0)
        self.moveProgressDays.append(0)
        self.supply.append(100.0)
        self.embarkedArmies.append([])
        self.battle.append(nil)
        self.shipIndices.append([])
        return id
    }
}

/// An active ship under construction in a coastal province with a Shipyard / Docks.
public struct ShipConstruction: Equatable, Sendable, Codable {
    public var country: CountryID
    public var province: ProvinceID
    public var shipType: ShipTypeID
    public var targetFleet: FleetID?
    public var monthsTotal: Int
    public var monthsLeft: Int

    public init(
        country: CountryID,
        province: ProvinceID,
        shipType: ShipTypeID,
        targetFleet: FleetID?,
        monthsTotal: Int,
        monthsLeft: Int
    ) {
        self.country = country
        self.province = province
        self.shipType = shipType
        self.targetFleet = targetFleet
        self.monthsTotal = monthsTotal
        self.monthsLeft = monthsLeft
    }
}

/// One side of a multi-day auto-resolved naval battle.
public struct NavalBattleSide: Sendable, Codable {
    public var country: CountryID
    public var fleets: [FleetID]
    public var admiral: CharacterID?
    public var startingShips: Int
    public var shipsSunk: Int = 0
    public var shipsCaptured: Int = 0
    public var sailorsLost: Int = 0

    public init(
        country: CountryID,
        fleets: [FleetID],
        admiral: CharacterID?,
        startingShips: Int
    ) {
        self.country = country
        self.fleets = fleets
        self.admiral = admiral
        self.startingShips = startingShips
    }
}

/// Ongoing multi-day auto-resolved naval battle in a sea zone.
public struct NavalBattle: Sendable, Codable {
    public var id: String
    public var seaZone: SeaZoneID
    public var startDate: GameDate
    public var dayCount: Int = 0
    public var isInlandSea: Bool
    public var attacker: NavalBattleSide
    public var defender: NavalBattleSide

    public init(
        id: String,
        seaZone: SeaZoneID,
        startDate: GameDate,
        isInlandSea: Bool,
        attacker: NavalBattleSide,
        defender: NavalBattleSide
    ) {
        self.id = id
        self.seaZone = seaZone
        self.startDate = startDate
        self.isInlandSea = isInlandSea
        self.attacker = attacker
        self.defender = defender
    }
}

/// Historical summary kept for alerts, war-score breakdowns, and UI history.
public struct NavalBattleReport: Sendable, Codable {
    public var id: String
    public var seaZone: SeaZoneID
    public var seaZoneName: String
    public var date: GameDate
    public var days: Int
    public var attackerCountry: CountryID
    public var defenderCountry: CountryID
    public var winnerCountry: CountryID
    public var attackerStartingShips: Int
    public var defenderStartingShips: Int
    public var attackerShipsLost: Int
    public var defenderShipsLost: Int
    public var attackerShipsCaptured: Int
    public var defenderShipsCaptured: Int
    public var attackerSailorsLost: Int
    public var defenderSailorsLost: Int
    public var warScoreDelta: Double

    public init(
        id: String,
        seaZone: SeaZoneID,
        seaZoneName: String,
        date: GameDate,
        days: Int,
        attackerCountry: CountryID,
        defenderCountry: CountryID,
        winnerCountry: CountryID,
        attackerStartingShips: Int,
        defenderStartingShips: Int,
        attackerShipsLost: Int,
        defenderShipsLost: Int,
        attackerShipsCaptured: Int,
        defenderShipsCaptured: Int,
        attackerSailorsLost: Int,
        defenderSailorsLost: Int,
        warScoreDelta: Double
    ) {
        self.id = id
        self.seaZone = seaZone
        self.seaZoneName = seaZoneName
        self.date = date
        self.days = days
        self.attackerCountry = attackerCountry
        self.defenderCountry = defenderCountry
        self.winnerCountry = winnerCountry
        self.attackerStartingShips = attackerStartingShips
        self.defenderStartingShips = defenderStartingShips
        self.attackerShipsLost = attackerShipsLost
        self.defenderShipsLost = defenderShipsLost
        self.attackerShipsCaptured = attackerShipsCaptured
        self.defenderShipsCaptured = defenderShipsCaptured
        self.attackerSailorsLost = attackerSailorsLost
        self.defenderSailorsLost = defenderSailorsLost
        self.warScoreDelta = warScoreDelta
    }
}

/// All naval state stored on `World`.
public struct Navy: Sendable {
    public var shipTypes: [ShipType] = []
    public var shipByKey: [String: ShipTypeID] = [:]
    public var ships = ShipTable()
    public var fleets = FleetTable()
    public var constructions: [ShipConstruction] = []
    public var sailors: [Double] = []
    public var maxSailors: [Double] = []
    public var lastNavyUpkeep: [Double] = []
    public var lastAttritionLosses: [Int] = []
    public var battles: [NavalBattle] = []
    public var recentBattles: [NavalBattleReport] = []
    /// Coastal provinces currently blockaded by at least one hostile fleet.
    public var blockadedProvinces: Set<ProvinceID> = []

    public init() {}

    public mutating func resize(countries count: Int) {
        sailors = Array(repeating: 0, count: count)
        maxSailors = Array(repeating: 0, count: count)
        lastNavyUpkeep = Array(repeating: 0, count: count)
        lastAttritionLosses = Array(repeating: 0, count: count)
    }

    public func shipType(_ id: ShipTypeID) -> ShipType {
        shipTypes[id.index]
    }

    public func fleets(of country: CountryID) -> [FleetID] {
        var result: [FleetID] = []
        for i in 0..<fleets.count where fleets.alive[i] && fleets.owner[i] == country {
            result.append(FleetID(i))
        }
        return result
    }

    public func fleets(inPort province: ProvinceID) -> [FleetID] {
        let loc = FleetLocation.port(province)
        var result: [FleetID] = []
        for i in 0..<fleets.count where fleets.alive[i] && fleets.location[i] == loc {
            result.append(FleetID(i))
        }
        return result
    }

    public func fleets(inSea sea: SeaZoneID) -> [FleetID] {
        let loc = FleetLocation.sea(sea)
        var result: [FleetID] = []
        for i in 0..<fleets.count where fleets.alive[i] && fleets.location[i] == loc {
            result.append(FleetID(i))
        }
        return result
    }

    public func shipCount(of fleet: FleetID) -> Int {
        let idx = fleet.index
        guard idx >= 0 && idx < fleets.count && fleets.alive[idx] else { return 0 }
        return fleets.shipIndices[idx].count { ships.alive[$0] }
    }

    public func totalShips(of country: CountryID) -> Int {
        var sum = 0
        for fid in fleets(of: country) {
            sum += shipCount(of: fid)
        }
        return sum
    }

    public func transportCapacity(of fleet: FleetID) -> Int {
        let idx = fleet.index
        guard idx >= 0 && idx < fleets.count && fleets.alive[idx] else { return 0 }
        var cap = 0
        for sIdx in fleets.shipIndices[idx] where ships.alive[sIdx] {
            cap += shipType(ships.type[sIdx]).capacity
        }
        return cap
    }

    public func navalBattle(in sea: SeaZoneID) -> NavalBattle? {
        battles.first { $0.seaZone == sea }
    }
}
