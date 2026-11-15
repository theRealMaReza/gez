import Foundation

/// Struct-of-Arrays (SoA) storage for all regiments/units on the tactical battlefield.
/// Keeping parallel scalar arrays preserves cache locality and cross-platform determinism.
public struct BattleUnitTable: Sendable, Equatable {
    public private(set) var count: Int = 0

    // Source identity for deterministic write-back to World
    public var sourceArmyID: [ArmyID?] = []
    public var sourceRegimentIndex: [Int] = []
    public var isGarrison: [Bool] = []
    public var side: [BattleSide] = []
    public var country: [CountryID] = []
    public var unitType: [UnitTypeID] = []
    public var unitKey: [String] = []
    public var unitName: [String] = []
    public var category: [UnitCategory] = []
    public var origin: [RegimentOrigin] = []
    public var homeProvince: [ProvinceID?] = []

    // Base stats (directly from World's UnitType & regiment)
    public var attack: [Double] = []
    public var defence: [Double] = []
    public var baseSpeed: [Double] = []
    public var maxMen: [Int] = []
    public var initialMen: [Int] = []
    public var men: [Int] = []
    public var maxMorale: [Double] = []
    public var morale: [Double] = []

    // Tactical state pools
    public var fatigue: [Double] = []          // 0.0 (fresh) ... 1.0 (exhausted)
    public var ammo: [Int] = []
    public var maxAmmo: [Int] = []

    // Kinematics (battlefield coordinates)
    public var posX: [Double] = []
    public var posY: [Double] = []
    public var velX: [Double] = []
    public var velY: [Double] = []
    public var facing: [Double] = []           // radians: 0 = +X (East), pi = -X (West)
    public var width: [Double] = []
    public var depth: [Double] = []

    // Tactical orders & combat flags
    public var formation: [BattleFormation] = []
    public var stance: [BattleStance] = []
    public var hasMoveOrder: [Bool] = []
    public var targetX: [Double] = []
    public var targetY: [Double] = []
    public var waypoints: [[TacticalPoint]] = []
    public var targetUnit: [Int] = []          // -1 = none
    public var targetStructure: [Int] = []     // -1 = none (Part C fort assaults)
    public var siegeEquipment: [SiegeEquipmentKind] = []
    public var isRouting: [Bool] = []
    public var isOnWall: [Bool] = []           // true when climbing or defending ramparts
    public var rallyCooldownTicks: [Int] = []
    public var fireCooldownTicks: [Int] = []
    public var inMeleeWith: [Int] = []         // -1 = none
    public var kills: [Int] = []

    public init() {}

    @discardableResult
    public mutating func append(
        sourceArmyID: ArmyID?,
        sourceRegimentIndex: Int,
        isGarrison: Bool,
        side: BattleSide,
        country: CountryID,
        unitType: UnitTypeID,
        unitKey: String,
        unitName: String,
        category: UnitCategory,
        origin: RegimentOrigin,
        homeProvince: ProvinceID?,
        attack: Double,
        defence: Double,
        baseSpeed: Double,
        maxMen: Int,
        men: Int,
        maxMorale: Double,
        morale: Double,
        ammo: Int,
        x: Double,
        y: Double,
        facing: Double,
        formation: BattleFormation = .line,
        stance: BattleStance = .hold
    ) -> Int {
        let idx = count
        count += 1
        self.sourceArmyID.append(sourceArmyID)
        self.sourceRegimentIndex.append(sourceRegimentIndex)
        self.isGarrison.append(isGarrison)
        self.side.append(side)
        self.country.append(country)
        self.unitType.append(unitType)
        self.unitKey.append(unitKey)
        self.unitName.append(unitName)
        self.category.append(category)
        self.origin.append(origin)
        self.homeProvince.append(homeProvince)

        self.attack.append(attack)
        self.defence.append(defence)
        self.baseSpeed.append(baseSpeed)
        self.maxMen.append(maxMen)
        self.initialMen.append(men)
        self.men.append(men)
        self.maxMorale.append(maxMorale)
        self.morale.append(morale)

        self.fatigue.append(0.0)
        self.ammo.append(ammo)
        self.maxAmmo.append(ammo)

        self.posX.append(x)
        self.posY.append(y)
        self.velX.append(0.0)
        self.velY.append(0.0)
        self.facing.append(facing)
        let dims = Self.footprint(formation: formation, menRatio: Double(max(1, men)) / Double(max(1, maxMen)))
        self.width.append(dims.width)
        self.depth.append(dims.depth)

        self.formation.append(formation)
        self.stance.append(stance)
        self.hasMoveOrder.append(false)
        self.targetX.append(x)
        self.targetY.append(y)
        self.waypoints.append([])
        self.targetUnit.append(-1)
        self.targetStructure.append(-1)
        self.siegeEquipment.append(.none)
        self.isRouting.append(false)
        self.isOnWall.append(false)
        self.rallyCooldownTicks.append(0)
        self.fireCooldownTicks.append(0)
        self.inMeleeWith.append(-1)
        self.kills.append(0)
        return idx
    }

    public static func footprint(formation: BattleFormation, menRatio: Double) -> (width: Double, depth: Double) {
        let scale = 0.65 + 0.35 * max(0.2, min(1.0, menRatio))
        switch formation {
        case .line: return (22.0 * scale, 48.0 * scale)
        case .column: return (42.0 * scale, 22.0 * scale)
        case .wedge: return (36.0 * scale, 34.0 * scale)
        case .square, .wagonLaager: return (34.0 * scale, 34.0 * scale)
        case .skirmish: return (26.0 * scale, 56.0 * scale)
        }
    }

    public mutating func updateFootprint(for index: Int) {
        let ratio = Double(max(1, men[index])) / Double(max(1, maxMen[index]))
        let dims = Self.footprint(formation: formation[index], menRatio: ratio)
        width[index] = dims.width
        depth[index] = dims.depth
    }

    public func isAliveAndFighting(_ index: Int) -> Bool {
        index >= 0 && index < count && men[index] > 0 && !isRouting[index]
    }

    public func totalMen(on side: BattleSide) -> Int {
        var total = 0
        for i in 0..<count where self.side[i] == side {
            total += max(0, men[i])
        }
        return total
    }

    public func totalInitialMen(on side: BattleSide) -> Int {
        var total = 0
        for i in 0..<count where self.side[i] == side {
            total += max(0, initialMen[i])
        }
        return total
    }

    public func averageMorale(on side: BattleSide) -> Double {
        var sum = 0.0
        var active = 0
        for i in 0..<count where self.side[i] == side && men[i] > 0 {
            sum += morale[i]
            active += 1
        }
        return active > 0 ? sum / Double(active) : 0.0
    }

    public func activeUnits(on side: BattleSide) -> Int {
        var c = 0
        for i in 0..<count where self.side[i] == side && men[i] > 0 && !isRouting[i] {
            c += 1
        }
        return c
    }

    /// Two-letter/single-letter compact badge code shown inside unit blocks.
    public static func unitGlyph(key: String, category: UnitCategory) -> String {
        switch key {
        case "war_wagons": return "W"
        case "war_elephants": return "E"
        case "handgunners": return "H"
        case "janissaries": return "J"
        case "horse_archers": return "HA"
        case "swiss_pikemen": return "P"
        case "longbowmen": return "L"
        case "gendarmes": return "G"
        default:
            switch category {
            case .infantry: return "I"
            case .cavalry: return "C"
            case .ranged: return "A"
            case .artillery: return "K"
            }
        }
    }
}
