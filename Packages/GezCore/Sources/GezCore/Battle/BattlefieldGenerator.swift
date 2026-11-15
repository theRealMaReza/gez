import Foundation

/// Deterministically generates 2D tactical battlefields from real province attributes + seed.
public enum BattlefieldGenerator {

    public static func combinedSeed(province: ProvinceID, seed: UInt64) -> UInt64 {
        let pMix = UInt64(bitPattern: Int64(province.index + 1)) &* 0x9E3779B97F4A7C15
        let mixed = seed ^ pMix ^ (pMix >> 23)
        return mixed == 0 ? 0x6A09E667F3BCC909 : mixed
    }

    public static func stableHash64(_ string: String) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for b in string.utf8 {
            h ^= UInt64(b)
            h &*= 0x100000001B3
        }
        return h == 0 ? 0x9E3779B97F4A7C15 : h
    }

    public static func generate(
        province: ProvinceID,
        terrain: Terrain,
        isRiverCrossing: Bool,
        isCoastal: Bool,
        fortLevel: Int = 0,
        existingBreach: Bool = false,
        seed: UInt64
    ) -> Battlefield {
        let width = Battlefield.defaultWidth
        let height = Battlefield.defaultHeight
        var rng = GameRandom(seed: combinedSeed(province: province, seed: seed))

        let river = isRiverCrossing
            ? generateRiver(width: width, height: height, rng: &rng)
            : nil

        let hills = generateHills(
            terrain: terrain,
            width: width,
            height: height,
            fortLevel: fortLevel,
            rng: &rng
        )
        let forests = generateForests(
            terrain: terrain,
            width: width,
            height: height,
            river: river,
            fortLevel: fortLevel,
            rng: &rng
        )

        let elevationGrid = sampleElevationGrid(
            cols: Battlefield.gridCols,
            rows: Battlefield.gridRows,
            width: width,
            height: height,
            terrain: terrain,
            hills: hills
        )

        let attackerZone: TacticalRect
        let defenderZone: TacticalRect
        if fortLevel > 0 {
            attackerZone = TacticalRect(x: 40.0, y: 60.0, width: 340.0, height: height - 120.0)
            defenderZone = TacticalRect(x: 755.0, y: 60.0, width: 405.0, height: height - 120.0)
        } else if isRiverCrossing {
            attackerZone = TacticalRect(x: 50.0, y: 50.0, width: 410.0, height: height - 100.0)
            defenderZone = TacticalRect(x: 740.0, y: 50.0, width: 410.0, height: height - 100.0)
        } else {
            attackerZone = TacticalRect(x: 50.0, y: 50.0, width: 350.0, height: height - 100.0)
            defenderZone = TacticalRect(x: 800.0, y: 50.0, width: 350.0, height: height - 100.0)
        }

        let fortLayout = fortLevel > 0
            ? generateFortLayout(fortLevel: fortLevel, existingBreach: existingBreach, height: height)
            : (structures: [FortStructure](), keepZone: nil as TacticalRect?)

        return Battlefield(
            province: province,
            terrain: terrain,
            seed: seed,
            isRiverCrossing: isRiverCrossing,
            isCoastal: isCoastal,
            width: width,
            height: height,
            gridCols: Battlefield.gridCols,
            gridRows: Battlefield.gridRows,
            elevationGrid: elevationGrid,
            hills: hills,
            forests: forests,
            river: river,
            structures: fortLayout.structures,
            attackerDeployZone: attackerZone,
            defenderDeployZone: defenderZone,
            keepZone: fortLayout.keepZone
        )
    }

    private static func generateHills(
        terrain: Terrain,
        width: Double,
        height: Double,
        fortLevel: Int,
        rng: inout GameRandom
    ) -> [HillFeature] {
        let count: Int
        let minH: Double
        let maxH: Double
        switch terrain {
        case .mountains:
            count = 5; minH = 22.0; maxH = 38.0
        case .hills:
            count = 4; minH = 14.0; maxH = 28.0
        case .forest:
            count = 2; minH = 7.0; maxH = 14.0
        case .farmland, .plains, .steppe:
            count = Int.random(in: 1...2, using: &rng); minH = 5.0; maxH = 11.0
        case .desert:
            count = 2; minH = 8.0; maxH = 16.0
        case .marsh:
            count = 1; minH = 3.0; maxH = 6.0
        }

        var hills: [HillFeature] = []
        let maxAllowedX = fortLevel > 0 ? 700.0 : (width - 140.0)
        for idx in 0..<count {
            let cx: Double
            if idx == 0 && (terrain == .hills || terrain == .mountains) {
                // Defender-side high ground feature
                cx = Double.random(in: (width * 0.56)...min(maxAllowedX, width * 0.80), using: &rng)
            } else {
                cx = Double.random(in: 160.0...maxAllowedX, using: &rng)
            }
            let cy = Double.random(in: 110.0...(height - 110.0), using: &rng)
            let rx = Double.random(in: 85.0...175.0, using: &rng)
            let ry = Double.random(in: 75.0...150.0, using: &rng)
            let h = Double.random(in: minH...maxH, using: &rng)
            let ang = Double.random(in: -0.6...0.6, using: &rng)
            hills.append(HillFeature(centerX: cx, centerY: cy, radiusX: rx, radiusY: ry, height: h, angle: ang))
        }
        return hills
    }

    private static func generateForests(
        terrain: Terrain,
        width: Double,
        height: Double,
        river: RiverCrossing?,
        fortLevel: Int,
        rng: inout GameRandom
    ) -> [ForestPatch] {
        let count: Int
        switch terrain {
        case .forest: count = 7
        case .hills: count = 3
        case .farmland, .plains, .marsh: count = 2
        case .mountains, .steppe: count = 1
        case .desert: count = 0
        }

        var patches: [ForestPatch] = []
        let maxX = fortLevel > 0 ? 640.0 : (width - 120.0)
        var attempts = 0
        while patches.count < count && attempts < count * 6 {
            attempts += 1
            let cx = Double.random(in: 130.0...maxX, using: &rng)
            let cy = Double.random(in: 90.0...(height - 90.0), using: &rng)
            let rx = Double.random(in: 55.0...115.0, using: &rng)
            let ry = Double.random(in: 45.0...100.0, using: &rng)
            if let river, abs(cx - river.centerX(atY: cy)) < river.halfWidth + 45.0 {
                continue
            }
            let density = terrain == .forest ? Double.random(in: 0.78...1.0, using: &rng) : Double.random(in: 0.55...0.85, using: &rng)
            patches.append(ForestPatch(centerX: cx, centerY: cy, radiusX: rx, radiusY: ry, density: density))
        }
        return patches
    }

    private static func generateRiver(
        width: Double,
        height: Double,
        rng: inout GameRandom
    ) -> RiverCrossing {
        let segments = 8
        let baseCenterX = width * 0.5 + Double.random(in: -30.0...30.0, using: &rng)
        let halfW = Double.random(in: 24.0...32.0, using: &rng)
        var line: [TacticalPoint] = []
        var drift = 0.0
        for s in 0...segments {
            let y = (Double(s) / Double(segments)) * height
            drift += Double.random(in: -26.0...26.0, using: &rng)
            drift = max(-55.0, min(55.0, drift))
            line.append(TacticalPoint(x: baseCenterX + drift, y: y))
        }

        let fordCount = Int.random(in: 2...3, using: &rng)
        var fords: [TacticalRect] = []
        let helperRiver = RiverCrossing(centerLine: line, halfWidth: halfW, fords: [])
        for i in 0..<fordCount {
            let frac = Double(i + 1) / Double(fordCount + 1)
            let yMid = frac * height + Double.random(in: -35.0...35.0, using: &rng)
            let fy = max(70.0, min(height - 70.0, yMid))
            let fx = helperRiver.centerX(atY: fy)
            let fordH = Double.random(in: 72.0...92.0, using: &rng)
            let fordW = halfW * 2.5
            fords.append(TacticalRect(x: fx - fordW * 0.5, y: fy - fordH * 0.5, width: fordW, height: fordH))
        }
        return RiverCrossing(centerLine: line, halfWidth: halfW, fords: fords)
    }

    private static func sampleElevationGrid(
        cols: Int,
        rows: Int,
        width: Double,
        height: Double,
        terrain: Terrain,
        hills: [HillFeature]
    ) -> [Double] {
        let baseElev: Double
        switch terrain {
        case .mountains: baseElev = 10.0
        case .hills: baseElev = 5.0
        case .marsh: baseElev = 0.0
        default: baseElev = 1.0
        }
        var grid = [Double](repeating: baseElev, count: cols * rows)
        for r in 0..<rows {
            let y = (Double(r) / Double(max(1, rows - 1))) * height
            for c in 0..<cols {
                let x = (Double(c) / Double(max(1, cols - 1))) * width
                var h = baseElev
                for hill in hills {
                    h += hill.contribution(at: x, y)
                }
                grid[r * cols + c] = h
            }
        }
        return grid
    }

    private static func generateFortLayout(
        fortLevel: Int,
        existingBreach: Bool,
        height: Double
    ) -> (structures: [FortStructure], keepZone: TacticalRect) {
        let lvl = max(1, min(6, fortLevel))
        let wallX = 760.0
        let cy = height * 0.5
        let thicknessScale = 1.0 + Double(lvl - 1) * 0.12
        let wallW = 28.0 * thicknessScale
        let towerSize = 42.0 + Double(lvl - 1) * 4.0
        let rampartElev = 14.0 + Double(lvl) * 4.0

        let wallHp = 260.0 + Double(lvl) * 140.0
        let towerHp = 340.0 + Double(lvl) * 170.0
        let gateHp = 180.0 + Double(lvl) * 110.0
        let keepHp = 520.0 + Double(lvl) * 200.0

        var structures: [FortStructure] = [
            FortStructure(
                id: 0, kind: .tower,
                x: wallX, y: 78.0,
                width: towerSize, height: towerSize,
                hp: towerHp, maxHp: towerHp, breached: false, elevation: rampartElev + 4.0
            ),
            FortStructure(
                id: 1, kind: .wall,
                x: wallX, y: 196.0,
                width: wallW, height: 192.0,
                hp: wallHp, maxHp: wallHp, breached: false, elevation: rampartElev
            ),
            FortStructure(
                id: 2, kind: .tower,
                x: wallX, y: 312.0,
                width: towerSize * 0.92, height: towerSize * 0.92,
                hp: towerHp, maxHp: towerHp, breached: false, elevation: rampartElev + 4.0
            ),
            FortStructure(
                id: 3, kind: .gate,
                x: wallX, y: cy,
                width: wallW + 4.0, height: 132.0,
                hp: gateHp, maxHp: gateHp, breached: false, elevation: rampartElev * 0.75
            ),
            FortStructure(
                id: 4, kind: .tower,
                x: wallX, y: 488.0,
                width: towerSize * 0.92, height: towerSize * 0.92,
                hp: towerHp, maxHp: towerHp, breached: false, elevation: rampartElev + 4.0
            ),
            FortStructure(
                id: 5, kind: .wall,
                x: wallX, y: 604.0,
                width: wallW, height: 192.0,
                hp: existingBreach ? 0.0 : wallHp, maxHp: wallHp,
                breached: existingBreach, elevation: rampartElev
            ),
            FortStructure(
                id: 6, kind: .tower,
                x: wallX, y: 722.0,
                width: towerSize, height: towerSize,
                hp: towerHp, maxHp: towerHp, breached: false, elevation: rampartElev + 4.0
            ),
            FortStructure(
                id: 7, kind: .keep,
                x: 1050.0, y: cy,
                width: 120.0 + Double(lvl) * 8.0,
                height: 170.0 + Double(lvl) * 12.0,
                hp: keepHp, maxHp: keepHp, breached: false, elevation: rampartElev + 8.0
            )
        ]

        if lvl >= 4 {
            // Citadel outer bailey bastion keep zone is slightly deeper and better fortified
            structures[1].hp = wallHp * 1.15
            structures[1].maxHp = wallHp * 1.15
        }

        let keepZone = TacticalRect(x: 965.0, y: cy - 110.0, width: 165.0, height: 220.0)
        return (structures, keepZone)
    }
}
