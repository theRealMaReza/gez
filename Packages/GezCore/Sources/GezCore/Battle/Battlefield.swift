import Foundation

/// Smooth elliptical elevation mound on a tactical battlefield.
public struct HillFeature: Sendable, Equatable, Codable {
    public var centerX: Double
    public var centerY: Double
    public var radiusX: Double
    public var radiusY: Double
    public var height: Double
    public var angle: Double

    public init(centerX: Double, centerY: Double, radiusX: Double, radiusY: Double, height: Double, angle: Double = 0.0) {
        self.centerX = centerX
        self.centerY = centerY
        self.radiusX = radiusX
        self.radiusY = radiusY
        self.height = height
        self.angle = angle
    }

    public func contribution(at x: Double, _ y: Double) -> Double {
        let dx = x - centerX
        let dy = y - centerY
        let ca = DetMath.cos(-angle)
        let sa = DetMath.sin(-angle)
        let lx = dx * ca - dy * sa
        let ly = dx * sa + dy * ca
        let nx = lx / max(1.0, radiusX)
        let ny = ly / max(1.0, radiusY)
        let r2 = nx * nx + ny * ny
        if r2 >= 1.0 { return 0.0 }
        // Smooth cosine falloff: 1 at center, 0 at rim
        let falloff = 0.5 * (1.0 + DetMath.cos(Double.pi * sqrt(r2)))
        return height * falloff
    }
}

/// Tree cluster providing cover and slowing cavalry charges.
public struct ForestPatch: Sendable, Equatable, Codable {
    public var centerX: Double
    public var centerY: Double
    public var radiusX: Double
    public var radiusY: Double
    public var density: Double

    public init(centerX: Double, centerY: Double, radiusX: Double, radiusY: Double, density: Double = 0.8) {
        self.centerX = centerX
        self.centerY = centerY
        self.radiusX = radiusX
        self.radiusY = radiusY
        self.density = density
    }

    public func contains(_ x: Double, _ y: Double) -> Bool {
        let nx = (x - centerX) / max(1.0, radiusX)
        let ny = (y - centerY) / max(1.0, radiusY)
        return nx * nx + ny * ny <= 1.0
    }
}

/// A north-south river crossing the battlefield with shallow ford crossings.
public struct RiverCrossing: Sendable, Equatable, Codable {
    /// Ordered polyline points from y=0 down to y=battlefield.height.
    public var centerLine: [TacticalPoint]
    public var halfWidth: Double
    public var fords: [TacticalRect]

    public init(centerLine: [TacticalPoint], halfWidth: Double, fords: [TacticalRect]) {
        self.centerLine = centerLine
        self.halfWidth = halfWidth
        self.fords = fords
    }

    /// Interpolates the river's center X at a given Y coordinate.
    public func centerX(atY y: Double) -> Double {
        guard !centerLine.isEmpty else { return 600.0 }
        if y <= centerLine[0].y { return centerLine[0].x }
        for i in 1..<centerLine.count {
            let a = centerLine[i - 1]
            let b = centerLine[i]
            if y <= b.y {
                let span = max(0.0001, b.y - a.y)
                let t = (y - a.y) / span
                return a.x + (b.x - a.x) * t
            }
        }
        return centerLine[centerLine.count - 1].x
    }

    public func state(at x: Double, _ y: Double) -> (inWater: Bool, isFord: Bool) {
        for f in fords where f.contains(x, y) {
            return (inWater: false, isFord: true)
        }
        let cx = centerX(atY: y)
        if abs(x - cx) <= halfWidth {
            return (inWater: true, isFord: false)
        }
        return (inWater: false, isFord: false)
    }
}

/// Reproducible 2D top-down battlefield built from province data + seed.
public struct Battlefield: Sendable, Equatable, Codable {
    public static let defaultWidth: Double = 1200.0
    public static let defaultHeight: Double = 800.0
    public static let gridCols: Int = 24
    public static let gridRows: Int = 16

    public let province: ProvinceID
    public let terrain: Terrain
    public let seed: UInt64
    public let isRiverCrossing: Bool
    public let isCoastal: Bool
    public let width: Double
    public let height: Double
    public let gridCols: Int
    public let gridRows: Int
    /// Sampled elevation grid (size = gridCols * gridRows).
    public let elevationGrid: [Double]
    public let hills: [HillFeature]
    public let forests: [ForestPatch]
    public let river: RiverCrossing?
    public let structures: [FortStructure]
    public let attackerDeployZone: TacticalRect
    public let defenderDeployZone: TacticalRect
    public let keepZone: TacticalRect?

    public init(
        province: ProvinceID,
        terrain: Terrain,
        seed: UInt64,
        isRiverCrossing: Bool,
        isCoastal: Bool,
        width: Double = Battlefield.defaultWidth,
        height: Double = Battlefield.defaultHeight,
        gridCols: Int = Battlefield.gridCols,
        gridRows: Int = Battlefield.gridRows,
        elevationGrid: [Double],
        hills: [HillFeature],
        forests: [ForestPatch],
        river: RiverCrossing?,
        structures: [FortStructure] = [],
        attackerDeployZone: TacticalRect,
        defenderDeployZone: TacticalRect,
        keepZone: TacticalRect? = nil
    ) {
        self.province = province
        self.terrain = terrain
        self.seed = seed
        self.isRiverCrossing = isRiverCrossing
        self.isCoastal = isCoastal
        self.width = width
        self.height = height
        self.gridCols = gridCols
        self.gridRows = gridRows
        self.elevationGrid = elevationGrid
        self.hills = hills
        self.forests = forests
        self.river = river
        self.structures = structures
        self.attackerDeployZone = attackerDeployZone
        self.defenderDeployZone = defenderDeployZone
        self.keepZone = keepZone
    }

    public func deploymentZone(for side: BattleSide) -> TacticalRect {
        side == .attacker ? attackerDeployZone : defenderDeployZone
    }

    /// Bilinearly interpolated terrain elevation at `(x, y)`.
    public func elevation(at x: Double, _ y: Double) -> Double {
        guard gridCols >= 2, gridRows >= 2, elevationGrid.count == gridCols * gridRows else {
            return 0.0
        }
        let fx = max(0.0, min(Double(gridCols - 1), (x / max(1.0, width)) * Double(gridCols - 1)))
        let fy = max(0.0, min(Double(gridRows - 1), (y / max(1.0, height)) * Double(gridRows - 1)))
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let x1 = min(gridCols - 1, x0 + 1)
        let y1 = min(gridRows - 1, y0 + 1)
        let tx = fx - Double(x0)
        let ty = fy - Double(y0)
        let h00 = elevationGrid[y0 * gridCols + x0]
        let h10 = elevationGrid[y0 * gridCols + x1]
        let h01 = elevationGrid[y1 * gridCols + x0]
        let h11 = elevationGrid[y1 * gridCols + x1]
        let top = h00 + (h10 - h00) * tx
        let bot = h01 + (h11 - h01) * tx
        return top + (bot - top) * ty
    }

    /// Checks whether a point lies inside any forest patch.
    public func isForest(at x: Double, _ y: Double) -> Bool {
        for patch in forests where patch.contains(x, y) {
            return true
        }
        return false
    }

    /// Checks river water / ford status at `(x, y)`.
    public func riverState(at x: Double, _ y: Double) -> (inWater: Bool, isFord: Bool) {
        guard let river else { return (false, false) }
        return river.state(at: x, y)
    }

    /// Terrain speed multiplier at `(x, y)` for a given unit category.
    public func movementSpeedMultiplier(at x: Double, _ y: Double, category: UnitCategory) -> Double {
        var mult = 1.0
        if terrain == .marsh {
            mult *= (category == .cavalry ? 0.65 : 0.80)
        } else if terrain == .mountains {
            mult *= (category == .artillery ? 0.65 : 0.82)
        }
        if isForest(at: x, y) {
            switch category {
            case .cavalry: mult *= 0.60
            case .artillery: mult *= 0.65
            case .infantry, .ranged: mult *= 0.85
            }
        }
        let r = riverState(at: x, y)
        if r.inWater {
            mult *= (category == .artillery ? 0.35 : 0.48)
        } else if r.isFord {
            mult *= 0.82
        }
        return mult
    }

    /// Ranged & defensive cover multiplier granted by terrain at `(x, y)`.
    public func rangedCoverReduction(at x: Double, _ y: Double) -> Double {
        if isForest(at: x, y) {
            return 0.25 // 25% less incoming missile damage in woods
        }
        return 0.0
    }
}
