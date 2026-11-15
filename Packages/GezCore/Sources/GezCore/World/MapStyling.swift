import Foundation

/// Map modes shared across front-ends.
public enum MapModeKind: Int, CaseIterable, Sendable, Codable {
    case political = 0
    case diplomatic
    case states
    case terrain
    case religion
    case culture
    case development
    case goods
    case markets

    public var key: String {
        switch self {
        case .political: return "political"
        case .diplomatic: return "diplomatic"
        case .states: return "states"
        case .terrain: return "terrain"
        case .religion: return "religion"
        case .culture: return "culture"
        case .development: return "development"
        case .goods: return "goods"
        case .markets: return "markets"
        }
    }

    public var title: String {
        switch self {
        case .political: return "Political"
        case .diplomatic: return "Diplomatic"
        case .states: return "States"
        case .terrain: return "Terrain"
        case .religion: return "Religion"
        case .culture: return "Culture"
        case .development: return "Development"
        case .goods: return "Goods"
        case .markets: return "Markets"
        }
    }
}

/// Per-province facts about the ID map: pixel bounding boxes and pixel counts.
public struct MapGeometryData: Sendable {
    public var minX: [Int]
    public var minY: [Int]
    public var maxX: [Int]
    public var maxY: [Int]
    public var pixelCount: [Int]

    public init(map: ProvinceIDMap, provinceCount n: Int) {
        var minX = [Int](repeating: Int.max, count: n)
        var minY = [Int](repeating: Int.max, count: n)
        var maxX = [Int](repeating: -1, count: n)
        var maxY = [Int](repeating: -1, count: n)
        var count = [Int](repeating: 0, count: n)
        let w = map.width
        map.values.withUnsafeBufferPointer { ids in
            for y in 0..<map.height {
                let row = y * w
                for x in 0..<w {
                    let v = Int(ids[row + x])
                    guard v >= 2 else { continue }
                    let p = v - 2
                    guard p < n else { continue }
                    if x < minX[p] { minX[p] = x }
                    if x > maxX[p] { maxX[p] = x }
                    if y < minY[p] { minY[p] = y }
                    if y > maxY[p] { maxY[p] = y }
                    count[p] += 1
                }
            }
        }
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
        self.pixelCount = count
    }

    public func pixelBounds(of province: ProvinceID) -> (x: Int, y: Int, width: Int, height: Int)? {
        let i = province.index
        guard i >= 0, i < maxX.count, maxX[i] >= 0 else { return nil }
        return (x: minX[i], y: minY[i], width: maxX[i] - minX[i] + 1, height: maxY[i] - minY[i] + 1)
    }
}

/// A town icon at a province's main town, in map-pixel coordinates.
public struct TownIconInfo: Sendable, Equatable {
    public let province: Int
    public let x: Double
    public let y: Double
    public let development: Int
    public let fortLevel: Int
    public let isCapital: Bool
    /// Coastal town big enough to keep a harbour (development 3 or more).
    public let isPort: Bool

    public init(province: Int, x: Double, y: Double, development: Int, fortLevel: Int, isCapital: Bool, isPort: Bool) {
        self.province = province
        self.x = x
        self.y = y
        self.development = development
        self.fortLevel = fortLevel
        self.isCapital = isCapital
        self.isPort = isPort
    }
}

/// A name to draw on the map, in map-pixel coordinates.
public struct MapLabelInfo: Identifiable, Sendable, Equatable {
    public let id: Int
    public let text: String
    public let x: Double
    public let y: Double
    /// Rough size of the thing being labelled, in map pixels.
    public let pixelArea: Double

    public init(id: Int, text: String, x: Double, y: Double, pixelArea: Double) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.pixelArea = pixelArea
    }
}

/// Summary of a playable country for the nation picker.
public struct CountrySummaryInfo: Identifiable, Sendable, Equatable {
    public static let featuredTags = [
        "TUR", "FRA", "ENG", "CAS", "ARA", "HAB", "POL", "VEN",
        "MLO", "MAM", "TIM", "DLH", "VIJ", "MOS", "HUN", "POR"
    ]

    public let id: CountryID
    public let tag: String
    public let name: String
    public let provinces: Int
    public let development: Int

    public init(id: CountryID, tag: String, name: String, provinces: Int, development: Int) {
        self.id = id
        self.tag = tag
        self.name = name
        self.provinces = provinces
        self.development = development
    }
}

/// Active alert item for the top alerts banner.
public struct GameAlertInfo: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case peaceOffer
        case breach
        case underSiege
        case coalition
        case lowStability
        case disloyalEstate
        case refusingVassal
        case bankrupt
        case highInflation
        case navalBattle
        case blockadedPort
    }

    public let id: String
    public let kind: Kind
    public let label: String
    public let province: ProvinceID?
    public let seaZone: SeaZoneID?
    public let warID: String?

    public init(id: String, kind: Kind, label: String, province: ProvinceID? = nil, seaZone: SeaZoneID? = nil, warID: String? = nil) {
        self.id = id
        self.kind = kind
        self.label = label
        self.province = province
        self.seaZone = seaZone
        self.warID = warID
    }
}

/// Colors as packed RGBA (red in the lowest byte), one entry per ID-map value:
/// index 0 = water, 1 = wasteland, n + 2 = province n.
public enum MapStyling {
    public static let water = pack(104, 140, 158)
    public static let wasteland = pack(112, 100, 86)
    public static let wastelandStripe = pack(96, 85, 72)
    public static let unowned = pack(196, 182, 150)
    public static let border = pack(32, 26, 20)

    public static func pack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> UInt32 {
        UInt32(r) | UInt32(g) << 8 | UInt32(b) << 16 | 0xFF00_0000
    }

    public static func pack(_ rgb: RGB) -> UInt32 {
        pack(rgb.r, rgb.g, rgb.b)
    }

    public static func keys(world: World) -> (owner: [Int32], state: [Int32]) {
        let n = world.provinces.count
        var owner = [Int32](repeating: -1, count: n + 2)
        var state = [Int32](repeating: -1, count: n + 2)
        owner[0] = -2
        owner[1] = -3
        state[0] = -2
        state[1] = -3
        for i in 0..<n {
            owner[i + 2] = world.provinces.owner[i].map { Int32($0.index) } ?? -1
            state[i + 2] = Int32(world.provinces.state[i].index)
        }
        return (owner, state)
    }

    public static func colors(for mode: MapModeKind, world: World, player: CountryID? = nil) -> [UInt32] {
        let p = world.provinces
        var out = [UInt32](repeating: unowned, count: p.count + 2)
        out[0] = water
        out[1] = wasteland
        for i in 0..<p.count {
            out[i + 2] = provinceColor(i, mode: mode, world: world, player: player)
        }
        return out
    }

    private static func provinceColor(_ i: Int, mode: MapModeKind, world: World, player: CountryID?) -> UInt32 {
        let p = world.provinces
        switch mode {
        case .political:
            guard let owner = p.owner[i] else { return unowned }
            return pack(world.countries.color[owner.index])
        case .diplomatic:
            guard let owner = p.owner[i] else { return unowned }
            let ref = player ?? world.humanCountries.first ?? world.countries.ids.first
            guard let ref else { return pack(world.countries.color[owner.index]) }
            if owner == ref {
                if let occ = p.occupiedBy[i], world.diplomacy.isAtWar(ref, occ) {
                    return pack(220, 95, 75) // occupied player province
                }
                return pack(58, 168, 86) // player green
            }
            if world.diplomacy.isAtWar(ref, owner) {
                if p.occupiedBy[i] == ref {
                    return pack(150, 210, 120) // occupied by player
                }
                return pack(205, 56, 56) // enemy red
            }
            if world.diplomacy.areAllies(ref, owner)
                || world.countries.overlord[owner.index] == ref
                || world.countries.overlord[ref.index] == owner {
                return pack(72, 130, 205) // ally or subject blue
            }
            if world.diplomacy.hasTruce(ref, owner) {
                return pack(98, 192, 206) // truce cyan
            }
            if p.cores[i].contains(ref) || p.claims[i].contains(ref) {
                return pack(222, 188, 66) // core or claim amber
            }
            return pack(182, 174, 154) // neutral beige
        case .states:
            let s = p.state[i].index
            let region = world.states.region[s].index
            let hue = (Double(s) * 0.618_034 + Double(region) * 0.137).truncatingRemainder(dividingBy: 1)
            let light = 0.62 + 0.12 * Double(s % 3) / 2
            return hsl(hue, 0.45, light)
        case .terrain:
            switch p.terrain[i] {
            case .farmland: return pack(150, 180, 90)
            case .plains: return pack(190, 200, 120)
            case .hills: return pack(170, 150, 100)
            case .mountains: return pack(130, 115, 100)
            case .forest: return pack(70, 120, 70)
            case .marsh: return pack(110, 140, 120)
            case .desert: return pack(225, 200, 140)
            case .steppe: return pack(205, 190, 120)
            }
        case .religion:
            return pack(p.religion[i].color)
        case .culture:
            return cultureColor(p.majorityCulture[i], world: world)
        case .development:
            let t = Double(min(max(p.development[i], 1), 10) - 1) / 9
            return pack(
                UInt8(240 - 60 * t),
                UInt8(230 - 170 * t),
                UInt8(170 - 130 * t)
            )
        case .goods:
            return pack(world.economy.goods.color[world.tradeGood(of: ProvinceID(i)).index])
        case .markets:
            guard i < world.economy.provinceMarket.count else { return unowned }
            let m = world.economy.provinceMarket[i].index
            let hue = (Double(m) * 0.618_034).truncatingRemainder(dividingBy: 1)
            let isCentre = world.economy.markets.centre[m].index == i
            return hsl(hue, isCentre ? 0.75 : 0.5, isCentre ? 0.45 : 0.62)
        }
    }

    public static func cultureColor(_ culture: CultureID, world: World) -> UInt32 {
        let families = world.cultures.families
        let family = world.cultures.family[culture.index]
        let f = families.firstIndex(of: family) ?? 0
        let members = (0..<world.cultures.count).filter { world.cultures.family[$0] == family }
        let k = members.firstIndex(of: culture.index) ?? 0
        let hue = (Double(f) * 0.618_034).truncatingRemainder(dividingBy: 1)
        let light = 0.45 + 0.3 * Double(k % 4) / 3
        let sat = 0.35 + 0.25 * Double((k / 4) % 2)
        return hsl(hue, sat, light)
    }

    private static func hsl(_ h: Double, _ s: Double, _ l: Double) -> UInt32 {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h * 6
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var r = 0.0, g = 0.0, b = 0.0
        switch Int(hp) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        return pack(UInt8((r + m) * 255), UInt8((g + m) * 255), UInt8((b + m) * 255))
    }

    /// Computes town icons, province positions, and market centre positions in map pixels.
    public static func buildTownIcons(
        world: World,
        idMap: ProvinceIDMap
    ) -> (townIcons: [TownIconInfo], provincePositions: [(x: Double, y: Double)], marketCentres: [(x: Double, y: Double)]) {
        let p = world.provinces
        let capitals = Set(world.countries.capital.compactMap { $0?.index })
        var icons: [TownIconInfo] = []
        icons.reserveCapacity(p.count)
        for i in 0..<p.count {
            var point = world.map.point(for: p.location[i])
            if idMap.province(x: point.x, y: point.y)?.index != i { point = p.labelPoint[i] }
            icons.append(TownIconInfo(
                province: i,
                x: Double(point.x),
                y: Double(point.y),
                development: p.development[i],
                fortLevel: p.fortLevel[i],
                isCapital: capitals.contains(i),
                isPort: p.isCoastal[i] && p.development[i] >= 3 && !world.provinceSeas[i].isEmpty
            ))
        }
        let provincePositions = icons.map { (x: $0.x, y: $0.y) }
        let marketCentres = world.economy.markets.centre.map { (x: icons[$0.index].x, y: icons[$0.index].y) }
        let sortedIcons = icons.sorted { $0.development < $1.development }
        return (sortedIcons, provincePositions, marketCentres)
    }

    /// Computes country, province, and sea zone labels in map pixels.
    public static func buildLabels(
        world: World,
        idMap: ProvinceIDMap,
        seaMap: ProvinceIDMap,
        geometry: MapGeometryData
    ) -> (countryLabels: [MapLabelInfo], provinceLabels: [MapLabelInfo], seaLabels: [MapLabelInfo]) {
        let p = world.provinces
        var provinceLabels: [MapLabelInfo] = []
        provinceLabels.reserveCapacity(p.count)
        for i in 0..<p.count {
            let point = p.labelPoint[i]
            provinceLabels.append(MapLabelInfo(
                id: i,
                text: p.name[i],
                x: Double(point.x),
                y: Double(point.y),
                pixelArea: Double(geometry.pixelCount[i])
            ))
        }

        let c = world.countries
        var countryLabels: [MapLabelInfo] = []
        var visited = [Bool](repeating: false, count: p.count)
        var bestBlock = [[Int]](repeating: [], count: c.count)
        var bestArea = [Double](repeating: 0, count: c.count)
        var bestScore = [Double](repeating: -1, count: c.count)
        for start in 0..<p.count {
            guard !visited[start], let owner = p.owner[start]?.index else { continue }
            var block: [Int] = []
            var area = 0.0
            var score = 0.0
            var stack = [start]
            visited[start] = true
            while let i = stack.popLast() {
                block.append(i)
                area += Double(geometry.pixelCount[i])
                score += Double(p.development[i])
                for n in p.neighbors[i] where !visited[n.index] && p.owner[n.index]?.index == owner {
                    visited[n.index] = true
                    stack.append(n.index)
                }
            }
            if score > bestScore[owner] {
                bestScore[owner] = score
                bestArea[owner] = area
                bestBlock[owner] = block
            }
        }
        for k in 0..<c.count where !bestBlock[k].isEmpty {
            var sx = 0.0, sy = 0.0
            for i in bestBlock[k] {
                let a = Double(geometry.pixelCount[i])
                sx += Double(p.labelPoint[i].x) * a
                sy += Double(p.labelPoint[i].y) * a
            }
            let cx = sx / bestArea[k]
            let cy = sy / bestArea[k]
            var bestX = cx
            var bestY = cy
            if idMap.province(x: Int(cx), y: Int(cy)).flatMap({ p.owner[$0.index]?.index }) != k {
                var bestDistance = Double.infinity
                for i in bestBlock[k] {
                    let lpx = Double(p.labelPoint[i].x)
                    let lpy = Double(p.labelPoint[i].y)
                    let d = hypot(lpx - cx, lpy - cy)
                    if d < bestDistance {
                        bestDistance = d
                        bestX = lpx
                        bestY = lpy
                    }
                }
            }
            countryLabels.append(MapLabelInfo(id: k, text: c.name[k], x: bestX, y: bestY, pixelArea: bestArea[k]))
        }

        var sx = [Double](repeating: 0, count: world.seaZones.count)
        var sy = [Double](repeating: 0, count: world.seaZones.count)
        var sn = [Double](repeating: 0, count: world.seaZones.count)
        seaMap.values.withUnsafeBufferPointer { values in
            let w = seaMap.width
            for y in stride(from: 0, to: seaMap.height, by: 4) {
                for x in stride(from: 0, to: w, by: 4) {
                    let v = Int(values[y * w + x])
                    guard v > 0, v - 1 < sx.count else { continue }
                    sx[v - 1] += Double(x); sy[v - 1] += Double(y); sn[v - 1] += 1
                }
            }
        }
        var seaLabels: [MapLabelInfo] = []
        for k in 0..<world.seaZones.count where sn[k] > 0 {
            var cx = sx[k] / sn[k]
            var cy = sy[k] / sn[k]
            if seaMap.seaZone(x: Int(cx), y: Int(cy))?.index != k {
                var bestX = cx, bestY = cy, bestD = Double.infinity
                for y in stride(from: 0, to: seaMap.height, by: 8) {
                    for x in stride(from: 0, to: seaMap.width, by: 8) where seaMap.seaZone(x: x, y: y)?.index == k {
                        let d = hypot(Double(x) - cx, Double(y) - cy)
                        if d < bestD {
                            bestD = d
                            bestX = Double(x)
                            bestY = Double(y)
                        }
                    }
                }
                cx = bestX
                cy = bestY
            }
            seaLabels.append(MapLabelInfo(id: k, text: world.seaZones.name[k], x: cx, y: cy, pixelArea: sn[k] * 16))
        }
        seaLabels.sort { $0.pixelArea > $1.pixelArea }
        countryLabels.sort { $0.pixelArea > $1.pixelArea }
        provinceLabels.sort { $0.pixelArea > $1.pixelArea }
        return (countryLabels, provinceLabels, seaLabels)
    }
}
