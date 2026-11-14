import GezCore
import SwiftUI

enum MapMode: String, CaseIterable, Identifiable {
    case political, diplomatic, states, terrain, religion, culture, development, goods, markets

    var id: String { rawValue }

    var title: String {
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

    var systemImage: String {
        switch self {
        case .political: return "flag"
        case .diplomatic: return "globe.europe.africa"
        case .states: return "square.grid.3x3"
        case .terrain: return "mountain.2"
        case .religion: return "building.columns"
        case .culture: return "person.3"
        case .development: return "chart.bar"
        case .goods: return "shippingbox"
        case .markets: return "scalemass"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .political: return "q"
        case .diplomatic: return "o"
        case .states: return "w"
        case .terrain: return "e"
        case .religion: return "r"
        case .culture: return "t"
        case .development: return "y"
        case .goods: return "u"
        case .markets: return "i"
        }
    }
    var kind: MapModeKind {
        switch self {
        case .political: return .political
        case .diplomatic: return .diplomatic
        case .states: return .states
        case .terrain: return .terrain
        case .religion: return .religion
        case .culture: return .culture
        case .development: return .development
        case .goods: return .goods
        case .markets: return .markets
        }
    }
}

/// Colors as packed RGBA (red in the lowest byte), one entry per ID-map value:
/// index 0 = water, 1 = wasteland, n + 2 = province n.
enum MapPalette {
    static let water = MapStyling.water
    static let wasteland = MapStyling.wasteland
    static let wastelandStripe = MapStyling.wastelandStripe
    static let unowned = MapStyling.unowned
    static let border = MapStyling.border

    static func pack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> UInt32 {
        MapStyling.pack(r, g, b)
    }

    static func pack(_ rgb: RGB) -> UInt32 {
        MapStyling.pack(rgb)
    }

    static func colors(for mode: MapMode, world: World, player: CountryID? = nil) -> [UInt32] {
        MapStyling.colors(for: mode.kind, world: world, player: player)
    }

    static func cultureColor(_ culture: CultureID, world: World) -> UInt32 {
        MapStyling.cultureColor(culture, world: world)
    }
}
