import Foundation

/// A point in tactical battlefield coordinates (meters / world units).
public struct TacticalPoint: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distanceSquared(to other: TacticalPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }

    public func distance(to other: TacticalPoint) -> Double {
        sqrt(distanceSquared(to: other))
    }
}

/// Axis-aligned rectangle in tactical battlefield coordinates.
public struct TacticalRect: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var centerX: Double { x + width * 0.5 }
    public var centerY: Double { y + height * 0.5 }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(_ px: Double, _ py: Double) -> Bool {
        px >= minX && px <= maxX && py >= minY && py <= maxY
    }

    public func clamped(_ px: Double, _ py: Double, margin: Double = 0.0) -> TacticalPoint {
        let loX = min(maxX, minX + margin)
        let hiX = max(minX, maxX - margin)
        let loY = min(maxY, minY + margin)
        let hiY = max(minY, maxY - margin)
        return TacticalPoint(
            x: max(loX, min(hiX, px)),
            y: max(loY, min(hiY, py))
        )
    }
}

/// Which side of a tactical engagement a participant belongs to.
public enum BattleSide: Int, CaseIterable, Sendable, Codable {
    case attacker = 0
    case defender = 1

    public var opposite: BattleSide {
        self == .attacker ? .defender : .attacker
    }
}

/// Field engagement vs siege storm assault.
public enum BattleKind: Sendable, Equatable, Codable {
    case field
    case assault(fortLevel: Int, existingBreach: Bool)

    public var isAssault: Bool {
        if case .assault = self { return true }
        return false
    }
}

/// Lifecycle phase of an interactive tactical battle.
public enum BattleControlPhase: String, CaseIterable, Sendable, Codable {
    case deployment
    case active
    case ended
}

/// Real-time speed multiplier for the tactical battle simulation.
public enum BattleSpeed: Int, CaseIterable, Sendable, Codable {
    case paused = 0
    case half = 1
    case normal = 2
    case fast = 3

    public var multiplier: Double {
        switch self {
        case .paused: return 0.0
        case .half: return 0.5
        case .normal: return 1.0
        case .fast: return 2.0
        }
    }

    public var label: String {
        switch self {
        case .paused: return "Pause"
        case .half: return "0.5x"
        case .normal: return "1x"
        case .fast: return "2x"
        }
    }
}

/// Tactical unit formations matching historic 15th-century doctrines.
public enum BattleFormation: String, CaseIterable, Sendable, Codable {
    case line
    case column
    case wedge
    case square
    case wagonLaager
    case skirmish

    public var displayName: String {
        switch self {
        case .line: return "Line"
        case .column: return "Column"
        case .wedge: return "Wedge"
        case .square: return "Square"
        case .wagonLaager: return "Wagon-Laager"
        case .skirmish: return "Skirmish"
        }
    }
}

/// Unit behavioral stances.
public enum BattleStance: String, CaseIterable, Sendable, Codable {
    case hold
    case advance
    case charge
    case volley
    case holdFire
    case retreat

    public var displayName: String {
        switch self {
        case .hold: return "Hold"
        case .advance: return "Advance"
        case .charge: return "Charge"
        case .volley: return "Volley"
        case .holdFire: return "Hold Fire"
        case .retreat: return "Retreat"
        }
    }
}

/// Explicit UI order tools for touch/Apple Pencil/mouse compatibility.
public enum BattleOrderTool: String, CaseIterable, Sendable, Codable {
    case select
    case move
    case attack
    case drawPath
    case dragFrontline
}

/// Siege equipment assigned to an attacking infantry regiment during fort assaults.
public enum SiegeEquipmentKind: String, CaseIterable, Sendable, Codable {
    case none
    case ladders
    case ram
}

/// Fortified structures generated for siege assaults (Part C).
public enum FortStructureKind: String, CaseIterable, Sendable, Codable {
    case wall
    case tower
    case gate
    case keep
}

/// Structural piece of a fort on a tactical assault battlefield.
public struct FortStructure: Sendable, Equatable, Codable {
    public var id: Int
    public var kind: FortStructureKind
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var hp: Double
    public var maxHp: Double
    public var breached: Bool
    public var elevation: Double

    public var rect: TacticalRect {
        TacticalRect(x: x - width * 0.5, y: y - height * 0.5, width: width, height: height)
    }

    public init(
        id: Int,
        kind: FortStructureKind,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        hp: Double,
        maxHp: Double,
        breached: Bool = false,
        elevation: Double = 10.0
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.hp = hp
        self.maxHp = maxHp
        self.breached = breached
        self.elevation = elevation
    }
}

/// Post-battle or mid-battle commander fate.
public enum CommanderFate: String, Sendable, Codable {
    case active
    case wounded
    case killed
    case captured
}

/// Summary of an army commander participating in a tactical battle.
public struct BattleCommanderInfo: Sendable, Equatable, Codable {
    public var characterID: CharacterID?
    public var name: String
    public var martial: Int
    public var country: CountryID
    public var armyID: ArmyID?
    public var fate: CommanderFate

    public init(
        characterID: CharacterID?,
        name: String,
        martial: Int,
        country: CountryID,
        armyID: ArmyID?,
        fate: CommanderFate = .active
    ) {
        self.characterID = characterID
        self.name = name
        self.martial = martial
        self.country = country
        self.armyID = armyID
        self.fate = fate
    }
}

/// Distinguishes field battle encounters vs player-requested fort storm assaults.
public enum PendingBattleKind: Sendable, Equatable, Codable {
    case field(battleID: String)
    case assault(province: ProvinceID)
}

/// Choice prompt presented when the player can either Lead Battle in Person or Auto-Resolve.
public struct PendingBattlePrompt: Sendable, Equatable {
    public let id: String
    public let kind: PendingBattleKind
    public let province: ProvinceID
    public let provinceName: String
    public let terrain: Terrain
    public let isRiverCrossing: Bool
    public let attackerCountry: CountryID
    public let defenderCountry: CountryID
    public let attackerName: String
    public let defenderName: String
    public let attackerTag: String
    public let defenderTag: String
    public let attackerMen: Int
    public let defenderMen: Int
    public let attackerCommanderName: String
    public let attackerCommanderMartial: Int
    public let defenderCommanderName: String
    public let defenderCommanderMartial: Int
    public let playerSide: BattleSide
    public let fortLevel: Int
    public let breached: Bool
    public let attackerAmbushed: Bool

    public var isAssault: Bool {
        if case .assault = kind { return true }
        return false
    }
}
