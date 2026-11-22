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
}
