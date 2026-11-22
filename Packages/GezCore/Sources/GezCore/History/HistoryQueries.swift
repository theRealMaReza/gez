import Foundation

/// One country's current row in the Ledger table.
public struct LedgerCountryRow: Sendable, Equatable {
    public var countryIndex: Int
    public var tag: String
    public var name: String
    public var color: RGB
    public var provinces: Int
    public var population: Int
    public var income: Double
    public var armySize: Int
    public var navySize: Int
    public var adminTech: Int
    public var diploTech: Int
    public var milTech: Int

    public var totalTech: Int { adminTech + diploTech + milTech }
}

/// One time-series line for a country in the Ledger Graphs view.
public struct LedgerCountrySeries: Sendable, Equatable {
    public var countryIndex: Int
    public var tag: String
    public var name: String
    public var color: RGB
    public var years: [Int]
    public var population: [Double]
    public var income: [Double]
    public var armySize: [Double]
    public var navySize: [Double]
    public var tech: [Double]
}

/// One slice in a Religion or Culture pie chart.
public struct PieSlice: Sendable, Equatable {
    public var label: String
    public var value: Double
    public var share: Double
    public var color: RGB
}

/// Pure-Swift queries backing the Phase 18 Ledger & Graphs screen.
public enum HistoryQueries {

    /// Returns current ledger rows for all countries owning at least one province, sorted by population descending.
    public static func ledgerRows(in world: World) -> [LedgerCountryRow] {
        let cCount = world.countries.count
        var provCount = [Int](repeating: 0, count: cCount)
        var popSum = [Double](repeating: 0.0, count: cCount)
        for p in 0..<world.provinces.count {
            if let owner = world.provinces.owner[p], owner.index < cCount {
                provCount[owner.index] += 1
                popSum[owner.index] += world.provinces.population[p]
            }
        }

        var armySum = [Int](repeating: 0, count: cCount)
        for i in 0..<world.military.armies.count {
            guard world.military.armies.alive[i], !world.military.armies.isRebel[i] else { continue }
            let owner = world.military.armies.owner[i]
            if owner.index < cCount {
                for reg in world.military.armies.regiments[i] {
                    armySum[owner.index] += reg.men
                }
            }
        }

        var navySum = [Int](repeating: 0, count: cCount)
        for i in 0..<world.navy.fleets.count {
            guard world.navy.fleets.alive[i] else { continue }
            let owner = world.navy.fleets.owner[i]
            if owner.index < cCount {
                navySum[owner.index] += world.navy.fleets.shipIndices[i].count { world.navy.ships.alive[$0] }
            }
        }

        var rows: [LedgerCountryRow] = []
        for idx in 0..<cCount where provCount[idx] > 0 {
            let cid = CountryID(idx)
            rows.append(LedgerCountryRow(
                countryIndex: idx,
                tag: world.countries.tag[idx],
                name: world.countries.name[idx],
                color: world.countries.color[idx],
                provinces: provCount[idx],
                population: Int(popSum[idx].rounded()),
                income: world.countries.lastMonthlyIncome[idx],
                armySize: armySum[idx],
                navySize: navySum[idx],
                adminTech: world.tech.level(cid, .administrative),
                diploTech: world.tech.level(cid, .diplomatic),
                milTech: world.tech.level(cid, .military)
            ))
        }

        rows.sort { $0.population > $1.population }
        return rows
    }

    /// Returns historical time series for up to 8 countries.
    public static func comparisonSeries(for countryIndices: [Int], in world: World) -> [LedgerCountrySeries] {
        var unique: [Int] = []
        for idx in countryIndices where idx >= 0 && idx < world.countries.count {
            if !unique.contains(idx) {
                unique.append(idx)
                if unique.count == 8 { break }
            }
        }

        return unique.map { idx in
            let cid = CountryID(idx)
            let pts = world.history.stats.series(for: cid)
            return LedgerCountrySeries(
                countryIndex: idx,
                tag: world.countries.tag[idx],
                name: world.countries.name[idx],
                color: world.countries.color[idx],
                years: pts.map(\.year),
                population: pts.map { Double($0.population) },
                income: pts.map(\.income),
                armySize: pts.map { Double($0.armySize) },
                navySize: pts.map { Double($0.navySize) },
                tech: pts.map { Double($0.totalTech) }
            )
        }
    }

    /// Computes current religion and culture pie slices for `country` from `world.pops`.
    public static func demographicsBreakdown(for country: CountryID, in world: World) -> (religions: [PieSlice], cultures: [PieSlice]) {
        var religionTotals: [Religion: Double] = [:]
        var cultureTotals: [CultureID: Double] = [:]
        var totalPop = 0.0

        for i in 0..<world.pops.count {
            let pid = world.pops.province[i]
            guard pid.index >= 0 && pid.index < world.provinces.count else { continue }
            guard world.provinces.owner[pid.index] == country else { continue }
            let sz = world.pops.size[i]
            guard sz > 0 else { continue }
            totalPop += sz
            religionTotals[world.pops.religion[i], default: 0.0] += sz
            cultureTotals[world.pops.culture[i], default: 0.0] += sz
        }

        guard totalPop > 0 else { return ([], []) }

        let relSlices = collapseSmallSlices(
            religionTotals.map { (rel, val) in
                (rel.displayName, val, religionColor(rel))
            },
            total: totalPop
        )
        let culSlices = collapseSmallSlices(
            cultureTotals.map { (cid, val) in
                let name = (cid.index >= 0 && cid.index < world.cultures.count) ? world.cultures.name[cid.index] : "Unknown"
                let col = cultureColor(cid.index)
                return (name, val, col)
            },
            total: totalPop
        )

        return (relSlices, culSlices)
    }

    private static func collapseSmallSlices(_ raw: [(String, Double, RGB)], total: Double) -> [PieSlice] {
        let sorted = raw.sorted { $0.1 > $1.1 }
        var result: [PieSlice] = []
        var otherVal = 0.0
        for (idx, item) in sorted.enumerated() {
            let share = item.1 / total
            if idx < 7 && (share >= 0.02 || idx < 3) {
                result.append(PieSlice(label: item.0, value: item.1, share: share, color: item.2))
            } else {
                otherVal += item.1
            }
        }
        if otherVal > 0 {
            result.append(PieSlice(
                label: "Other",
                value: otherVal,
                share: otherVal / total,
                color: RGB(130, 130, 130)
            ))
        }
        return result
    }

    public static func cultureColor(_ index: Int) -> RGB {
        let palette: [RGB] = [
            RGB(210, 150, 75), RGB(85, 155, 205), RGB(120, 185, 100),
            RGB(190, 95, 115), RGB(155, 120, 195), RGB(215, 195, 85),
            RGB(95, 180, 175), RGB(180, 125, 95)
        ]
        let idx = abs(index) % palette.count
        return palette[idx]
    }

    public static func religionColor(_ r: Religion) -> RGB {
        switch r {
        case .catholic: return RGB(220, 185, 60)
        case .protestant: return RGB(70, 130, 215)
        case .reformed: return RGB(100, 170, 230)
        case .hussite: return RGB(180, 130, 200)
        case .orthodox: return RGB(165, 85, 165)
        case .coptic, .ethiopian: return RGB(200, 120, 140)
        case .armenian, .syriac, .nestorian, .bosnian: return RGB(190, 145, 100)
        case .sunni: return RGB(65, 165, 75)
        case .twelver, .zaydi, .ismaili: return RGB(95, 195, 120)
        case .ibadi: return RGB(50, 140, 110)
        case .druze, .alawite, .yazidi: return RGB(110, 155, 90)
        case .hindu: return RGB(225, 125, 50)
        case .jain: return RGB(240, 175, 95)
        case .theravada, .tibetan: return RGB(210, 165, 55)
        case .zoroastrian: return RGB(200, 75, 75)
        case .jewish: return RGB(90, 140, 200)
        case .tengri: return RGB(105, 175, 185)
        case .folk: return RGB(145, 125, 95)
        }
    }
}
