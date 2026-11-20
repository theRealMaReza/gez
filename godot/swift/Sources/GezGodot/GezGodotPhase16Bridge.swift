import Foundation
import GezCore

/// Phase 16 bridge extension: simulation-backed breakdown tooltips and event/ambience audio queries.
extension GezGodotController {

    private static func reportToDict(_ report: BreakdownReport) -> [String: Any] {
        let entryDicts: [[String: Any]] = report.entries.map { entry in
            [
                "label": entry.label,
                "value": entry.value,
                "valueText": entry.formattedValue
            ]
        }
        return [
            "valid": true,
            "title": report.title,
            "total": report.total,
            "totalText": report.formattedTotal,
            "entries": entryDicts,
            "notes": report.notes
        ]
    }

    public func monthlyIncomeBreakdownData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.monthlyIncome(s.world, for: player))
    }

    public func manpowerBreakdownData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.manpower(s.world, for: player))
    }

    public func sailorsBreakdownData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.sailors(s.world, for: player))
    }

    public func armyMoraleBreakdownData(armyId: Int) -> [String: Any] {
        guard let s = session,
              armyId >= 0,
              armyId < s.world.military.armies.count,
              s.world.military.armies.alive[armyId] else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.armyMorale(s.world, army: ArmyID(Int32(armyId))))
    }

    public func siegeBreakdownData(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0,
              provinceIndex < s.world.provinces.count else {
            return ["valid": false]
        }
        let pid = ProvinceID(provinceIndex)
        guard s.world.military.siege(in: pid) != nil else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.siege(s.world, in: pid))
    }

    public func stabilityBreakdownData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.stability(s.world, for: player))
    }

    public func unrestBreakdownData(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0,
              provinceIndex < s.world.provinces.count else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.unrest(s.world, in: ProvinceID(provinceIndex), date: s.date))
    }

    public func researchSpeedBreakdownData(trackKey: String) -> [String: Any] {
        guard let s = session,
              let player = s.playerCountry,
              let track = TechTrack.allCases.first(where: { $0.key == trackKey }) else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.researchSpeed(s.world, for: player, track: track, year: s.date.year))
    }

    public func techCostBreakdownData(trackKey: String) -> [String: Any] {
        guard let s = session,
              let player = s.playerCountry,
              let track = TechTrack.allCases.first(where: { $0.key == trackKey }) else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.techCost(s.world, for: player, track: track, year: s.date.year))
    }

    public func relationsBreakdownData(targetCountryIndex: Int) -> [String: Any] {
        guard let s = session,
              let player = s.playerCountry,
              targetCountryIndex >= 0,
              targetCountryIndex < s.world.countries.count,
              targetCountryIndex != player.index else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.relations(s.world, of: player, by: CountryID(targetCountryIndex)))
    }

    public func relationSlotsBreakdownData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["valid": false] }
        return Self.reportToDict(Breakdowns.relationSlots(s.world, for: player))
    }

    public func aiGoalBreakdownData(countryIndex: Int) -> [String: Any] {
        guard let s = session,
              countryIndex >= 0,
              countryIndex < s.world.countries.count else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.aiGoal(s.world, for: CountryID(countryIndex), date: s.date))
    }

    public func provinceSupplyBreakdownData(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0,
              provinceIndex < s.world.provinces.count else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.provinceSupply(s.world, in: ProvinceID(provinceIndex)))
    }

    public func warScoreBreakdownData(warID: String) -> [String: Any] {
        guard let s = session,
              let war = s.world.diplomacy.wars.first(where: { $0.id == warID }) else {
            return ["valid": false]
        }
        return Self.reportToDict(Breakdowns.warScore(s.world, war: war))
    }

    public func consumeAudioEvents() -> [String] {
        session?.consumePendingAudioEvents() ?? []
    }

    public func ambienceContext(mapX: Int, mapY: Int, zoom: Double) -> [String: Any] {
        guard let s = session else {
            return ["seaWeight": 0.0, "windWeight": 0.45, "cityWeight": 0.0]
        }
        let w = s.world
        let cx = max(0, min(s.idMap.width - 1, mapX))
        let cy = max(0, min(s.idMap.height - 1, mapY))
        let provRaw = Int(s.idMap.value(x: cx, y: cy))
        let seaRaw = Int(s.seaMap.value(x: cx, y: cy))
        let provIdx = provRaw >= 2 ? provRaw - 2 : -1
        let zoomNorm = max(0.0, min(1.0, (zoom - 0.45) / 3.5))

        var windWeight = 0.72 * (1.0 - 0.65 * zoomNorm)
        var seaWeight = 0.0
        var cityWeight = 0.0

        if provIdx >= 0 && provIdx < w.provinces.count {
            let terrain = w.provinces.terrain[provIdx]
            if terrain == .mountains || terrain == .hills || terrain == .steppe {
                windWeight += 0.22 * zoomNorm
            }
            if w.provinces.isCoastal[provIdx] {
                seaWeight = 0.08 + 0.42 * zoomNorm
            }
            let dev = Double(w.provinces.development[provIdx])
            let devFactor = max(0.15, min(1.0, dev / 10.0))
            cityWeight = zoomNorm * (0.22 + 0.78 * devFactor)
        } else if seaRaw >= 1 {
            seaWeight = 0.14 + 0.82 * zoomNorm
        }

        return [
            "seaWeight": max(0.0, min(1.0, seaWeight)),
            "windWeight": max(0.0, min(1.0, windWeight)),
            "cityWeight": max(0.0, min(1.0, cityWeight))
        ]
    }
}
