import Foundation
import GezCore

/// Phase 18 screens: Chronicle Book, Ledger & Graphs, and Map Timelapse.
extension GezGodotController {

    // MARK: - Chronicle Book

    public func chronicleDetails(countryIndex: Int) -> [String: Any] {
        guard let s = session else {
            return ["hasWorld": false]
        }
        let w = s.world
        let resolvedIndex: Int
        if countryIndex >= 0 && countryIndex < w.countries.count {
            resolvedIndex = countryIndex
        } else if let p = s.playerCountry {
            resolvedIndex = p.index
        } else {
            resolvedIndex = 0
        }
        let cid = CountryID(resolvedIndex)
        let chapters = ChronicleTemplateSet.shared.chapters(for: cid, in: w)

        var chapterDicts: [[String: Any]] = []
        chapterDicts.reserveCapacity(chapters.count)
        for ch in chapters {
            var entryDicts: [[String: Any]] = []
            entryDicts.reserveCapacity(ch.entries.count)
            for e in ch.entries {
                entryDicts.append([
                    "date": e.dateText,
                    "kind": e.kindKey,
                    "prose": e.prose
                ])
            }
            chapterDicts.append([
                "rulerName": ch.rulerName,
                "dynastyName": ch.dynastyName,
                "spanText": ch.spanText,
                "entries": entryDicts
            ])
        }

        // Country filter list: player first, then all countries sorted by name.
        var countries: [[String: Any]] = []
        let playerIdx = s.playerCountry?.index ?? -1
        for i in 0..<w.countries.count {
            countries.append([
                "index": i,
                "tag": w.countries.tag[i],
                "name": w.countries.name[i],
                "isPlayer": i == playerIdx
            ])
        }
        countries.sort {
            let p0 = ($0["isPlayer"] as? Bool) ?? false
            let p1 = ($1["isPlayer"] as? Bool) ?? false
            if p0 != p1 { return p0 }
            let n0 = ($0["name"] as? String) ?? ""
            let n1 = ($1["name"] as? String) ?? ""
            return n0 < n1
        }

        return [
            "hasWorld": true,
            "selectedCountryIndex": resolvedIndex,
            "selectedCountryName": w.countries.name[resolvedIndex],
            "chapters": chapterDicts,
            "countries": countries
        ]
    }

    // MARK: - Ledger & Graphs

    public func ledgerOverview() -> [String: Any] {
        guard let s = session else {
            return ["hasWorld": false]
        }
        let rows = HistoryQueries.ledgerRows(in: s.world)
        let playerIdx = s.playerCountry?.index ?? (rows.first?.countryIndex ?? 0)

        var rowDicts: [[String: Any]] = []
        rowDicts.reserveCapacity(rows.count)
        for r in rows {
            rowDicts.append([
                "countryIndex": r.countryIndex,
                "tag": r.tag,
                "name": r.name,
                "r": Double(r.color.r) / 255.0,
                "g": Double(r.color.g) / 255.0,
                "b": Double(r.color.b) / 255.0,
                "provinces": r.provinces,
                "population": r.population,
                "income": r.income,
                "armySize": r.armySize,
                "navySize": r.navySize,
                "adminTech": r.adminTech,
                "diploTech": r.diploTech,
                "milTech": r.milTech,
                "totalTech": r.totalTech
            ])
        }

        return [
            "hasWorld": true,
            "playerIndex": playerIdx,
            "rows": rowDicts
        ]
    }

    public func ledgerComparison(countryIndices: [Int], pieCountryIndex: Int) -> [String: Any] {
        guard let s = session else {
            return ["hasWorld": false]
        }
        let w = s.world
        let series = HistoryQueries.comparisonSeries(for: countryIndices, in: w)

        var seriesDicts: [[String: Any]] = []
        seriesDicts.reserveCapacity(series.count)
        for item in series {
            seriesDicts.append([
                "countryIndex": item.countryIndex,
                "tag": item.tag,
                "name": item.name,
                "r": Double(item.color.r) / 255.0,
                "g": Double(item.color.g) / 255.0,
                "b": Double(item.color.b) / 255.0,
                "years": item.years,
                "population": item.population,
                "income": item.income,
                "armySize": item.armySize,
                "navySize": item.navySize,
                "tech": item.tech
            ])
        }

        let pieIdx = (pieCountryIndex >= 0 && pieCountryIndex < w.countries.count)
            ? pieCountryIndex
            : (s.playerCountry?.index ?? 0)
        let pies = HistoryQueries.demographicsBreakdown(for: CountryID(pieIdx), in: w)

        func encodeSlices(_ slices: [PieSlice]) -> [[String: Any]] {
            slices.map { sl in
                [
                    "label": sl.label,
                    "value": sl.value,
                    "share": sl.share,
                    "r": Double(sl.color.r) / 255.0,
                    "g": Double(sl.color.g) / 255.0,
                    "b": Double(sl.color.b) / 255.0
                ]
            }
        }

        return [
            "hasWorld": true,
            "series": seriesDicts,
            "pieCountryIndex": pieIdx,
            "pieCountryName": w.countries.name[pieIdx],
            "religionSlices": encodeSlices(pies.religions),
            "cultureSlices": encodeSlices(pies.cultures)
        ]
    }

    // MARK: - Map Timelapse

    public func timelapseInfo() -> [String: Any] {
        guard let s = session else {
            return ["hasWorld": false]
        }
        let years = s.world.history.timelapse.years
        return [
            "hasWorld": true,
            "years": years,
            "minYear": years.first ?? s.date.year,
            "maxYear": years.last ?? s.date.year
        ]
    }

    public func timelapseStyleBytes(yearIndex: Int, showReligion: Bool) -> [UInt8] {
        let width = Self.styleTextureWidth
        var bytes = [UInt8](repeating: 0, count: width * 2 * 4)
        guard let s = session else { return bytes }
        let w = s.world
        let frame = w.history.timelapse.frame(atYearIndex: yearIndex)
        let keys = MapStyling.keys(world: w)
        let count = min(w.provinces.count + 2, width)

        for v in 0..<count {
            var r: UInt8 = 0
            var g: UInt8 = 0
            var b: UInt8 = 0
            var a: UInt8 = 0
            var ownerInt = -1
            let state = (v < keys.state.count) ? keys.state[v] : -1

            if v >= 2 {
                let p = v - 2
                if p < frame.owner.count {
                    ownerInt = Int(frame.owner[p])
                }
                if showReligion {
                    if p < frame.religion.count {
                        let rel = HistorySystem.religion(fromIndex: frame.religion[p])
                        let rgb = HistoryQueries.religionColor(rel)
                        r = rgb.r
                        g = rgb.g
                        b = rgb.b
                        a = 255
                    }
                } else if ownerInt >= 0 && ownerInt < w.countries.count {
                    let rgb = w.countries.color[ownerInt]
                    r = rgb.r
                    g = rgb.g
                    b = rgb.b
                    a = 255
                }
            }

            let row0 = v * 4
            bytes[row0] = r
            bytes[row0 + 1] = g
            bytes[row0 + 2] = b
            bytes[row0 + 3] = a

            let ownerEnc = UInt16(bitPattern: Int16(clamping: ownerInt + 4))
            let stateEnc = UInt16(bitPattern: Int16(clamping: state + 4))
            let row1 = (width + v) * 4
            bytes[row1] = UInt8(ownerEnc & 0xFF)
            bytes[row1 + 1] = UInt8(ownerEnc >> 8)
            bytes[row1 + 2] = UInt8(stateEnc & 0xFF)
            bytes[row1 + 3] = UInt8(stateEnc >> 8)
        }
        return bytes
    }
}
