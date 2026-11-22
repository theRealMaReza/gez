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
}
