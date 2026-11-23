import Foundation
import GezCore

/// Phase 17 part 2: data for the 3D models on the campaign map.
///
/// Every town, army and fleet gets a regional building style, picked from the
/// majority religion, the terrain and where it lies:
/// 0 European, 1 Islamic (and Near East, North and East Africa), 2 Indian,
/// 3 East Asian (Tibet, Buddhist south-east), 4 Steppe (nomads).
public enum MapModelStyle: Int, CaseIterable, Sendable {
    case european = 0, islamic, indian, eastAsian, steppe

    public static func of(religion: Religion, terrain: Terrain, location: GeoPoint) -> MapModelStyle {
        let lat = location.latitude
        let lon = location.longitude
        let inIndia = lon >= 66 && lon <= 93 && lat >= 5 && lat <= 31.5
        let farEast = lon > 93
        switch religion {
        case .tibetan, .theravada, .mahayana, .confucian, .daoist, .shinto, .austronesian, .highland:
            return .eastAsian
        case .siberian:
            return .steppe
        case .westAfrican, .bantu, .eastAfrican:
            return .islamic
        case .hindu, .jain:
            return farEast ? .eastAsian : .indian
        case .tengri:
            return .steppe
        case .folk:
            return lat >= 40 ? .steppe : .islamic
        case .sunni, .twelver, .zaydi, .ismaili, .ibadi, .druze, .alawite, .yazidi:
            if inIndia { return .indian }
            if farEast { return .eastAsian }
            if terrain == .steppe && lat >= 38 { return .steppe }
            return .islamic
        case .coptic, .ethiopian, .syriac, .nestorian, .zoroastrian:
            return inIndia ? .indian : .islamic
        case .armenian:
            return .islamic
        case .catholic, .hussite, .protestant, .reformed, .orthodox, .bosnian, .jewish:
            if inIndia { return .indian }
            return .european
        }
    }
}

extension GezGodotController {

    /// Style of one province (index), or European when out of range.
    public func modelStyle(provinceIndex p: Int) -> MapModelStyle {
        guard let w = session?.world, p >= 0, p < w.provinces.religion.count else { return .european }
        return MapModelStyle.of(
            religion: w.provinces.religion[p],
            terrain: w.provinces.terrain[p],
            location: w.provinces.location[p]
        )
    }

    /// Style of a country's soldiers and ships: its capital's style.
    public func modelStyle(countryIndex c: Int) -> MapModelStyle {
        guard let w = session?.world, c >= 0, c < w.countries.capital.count,
              let cap = w.countries.capital[c] else { return .european }
        return modelStyle(provinceIndex: cap.index)
    }

    /// Four floats per town icon, in the same order as `townIconMetrics()`:
    /// `[style, ownerR, ownerG, ownerB]` (colour 0...1, for the capital flag).
    public func townModelData() -> [Float] {
        guard let s = session else { return [] }
        let w = s.world
        var out: [Float] = []
        out.reserveCapacity(s.townIcons.count * 4)
        for icon in s.townIcons {
            out.append(Float(modelStyle(provinceIndex: icon.province).rawValue))
            var rgb: (Float, Float, Float) = (0.85, 0.75, 0.4)
            if icon.province >= 0, icon.province < w.provinces.owner.count, let o = w.provinces.owner[icon.province] {
                let c = w.countries.color[o.index]
                rgb = (Float(c.r) / 255, Float(c.g) / 255, Float(c.b) / 255)
            }
            out.append(rgb.0)
            out.append(rgb.1)
            out.append(rgb.2)
        }
        return out
    }

    /// Extra per-army data for the 3D army figures: style, and where the army
    /// is walking (next stop and how far along it is, 0...1).
    public func mapArmyMotion() -> [[String: Any]] {
        guard let s = session else { return [] }
        let w = s.world
        let armies = w.military.armies
        let positions = s.provincePositions
        var out: [[String: Any]] = []
        for i in 0..<armies.count where armies.alive[i] {
            let owner = armies.owner[i]
            var entry: [String: Any] = [
                "armyId": i,
                "style": modelStyle(countryIndex: owner.index).rawValue,
                "moving": false,
                "frac": 0.0
            ]
            let path = armies.path[i]
            if let next = path.first, next.index >= 0, next.index < positions.count {
                let step = max(armies.moveStepDays[i], 0.001)
                entry["moving"] = true
                entry["nextX"] = positions[next.index].x
                entry["nextY"] = positions[next.index].y
                entry["frac"] = min(1.0, max(0.0, armies.moveProgressDays[i] / step))
            }
            out.append(entry)
        }
        return out
    }

    /// Style per fleet id (owner's capital style).
    public func mapFleetStyles() -> [Int: Int] {
        guard let s = session else { return [:] }
        let fleets = s.world.navy.fleets
        var out: [Int: Int] = [:]
        for i in 0..<fleets.count where fleets.alive[i] {
            out[i] = modelStyle(countryIndex: fleets.owner[i].index).rawValue
        }
        return out
    }

    /// Regional styles for the 3D battle view: each side's soldiers (their
    /// country's style) and the walls (the province's style).
    public func battleModelStyles() -> [String: Any] {
        guard let b = session?.tacticalBattle else { return [:] }
        return [
            "attackerStyle": modelStyle(countryIndex: b.attackerCountry.index).rawValue,
            "defenderStyle": modelStyle(countryIndex: b.defenderCountry.index).rawValue,
            "siteStyle": modelStyle(provinceIndex: b.province.index).rawValue
        ]
    }
}
