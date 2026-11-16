import Foundation
import GezCore

/// Phase 12 screens: plague, famine, unrest and rebels.
extension GezGodotController {

    // MARK: - Top bar

    /// Text of the Rebels button: how many factions the player faces.
    public var topBarRebelsText: String {
        guard let s = session, let p = s.playerCountry else { return "Rebels" }
        let factions = s.world.unrest.factions(of: p)
        if factions.contains(where: { $0.risen }) { return "Rebels!" }
        return factions.isEmpty ? "Rebels" : "Rebels \(factions.count)"
    }

    // MARK: - Province panel

    /// Plague, immunity, famine, unrest with its causes and rebel progress
    /// for one province (the People tab of the province panel).
    public func provinceCalamityDetails(provinceIndex: Int) -> [String: Any] {
        guard let s = session, provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return ["hasProvince": false]
        }
        let w = s.world
        let p = provinceIndex
        let province = ProvinceID(p)
        let cal = w.calamity
        let owner = w.provinces.owner[p]
        let isMine = owner != nil && owner == s.playerCountry

        var outbreaks: [[String: Any]] = []
        var immunities: [[String: Any]] = []
        for d in Disease.allCases {
            let rule = PlagueModel.rule(d)
            if cal.hasOutbreak(p, d) {
                let k = cal.slot(p, d)
                let month = k < cal.course.count ? cal.course[k] : 0
                outbreaks.append([
                    "name": d.displayName,
                    "key": d.key,
                    "struckText": Self.formatPercent(cal.infection(p, d)),
                    "monthsLeft": max(0, rule.months - month + 1),
                    "text": "\(d.displayName): \(Self.formatPercent(cal.infection(p, d))) struck this month, "
                        + "\(max(0, rule.months - month + 1)) months to run"
                ])
            }
            let immune = cal.immunity(p, d)
            if immune >= 0.05 {
                immunities.append(["name": d.displayName, "text": Self.formatPercent(immune)])
            }
        }
        let deaths = p < cal.lastDeaths.count ? cal.lastDeaths[p] : 0
        let starved = p < cal.lastFamineDeaths.count ? cal.lastFamineDeaths[p] : 0
        let harvest = p < cal.harvest.count ? cal.harvest[p] : 1
        let crop = cal.stapleYieldFactor(p)

        var quarantineRefusal = ""
        var cordonRefusal = ""
        if let player = s.playerCountry {
            quarantineRefusal = PlagueSystem.quarantineRefusal(w, player, province)?.reason ?? ""
            cordonRefusal = PlagueSystem.cordonRefusal(w, player, province)?.reason ?? ""
        }

        var causes: [[String: Any]] = []
        if owner != nil {
            for item in UnrestSystem.causes(w, in: province, date: s.date) {
                causes.append([
                    "name": item.cause.displayName,
                    "points": item.points,
                    "text": String(format: "%+.1f", item.points)
                ])
            }
        }
        var rebels: [[String: Any]] = []
        if let owner {
            for f in w.unrest.factions(of: owner) where f.provinces.contains(province)
                || (f.risen && RebelSystem.target(w, f) == province) {
                rebels.append([
                    "factionId": f.id,
                    "name": RebelSystem.name(w, f),
                    "progress": f.progress,
                    "risen": f.risen,
                    "text": f.risen ? "\(RebelSystem.name(w, f)): in arms" : "\(RebelSystem.name(w, f)): \(Int(f.progress))%"
                ])
            }
        }
        let quake = cal.quakes.last { $0.epicentre == province }

        return [
            "hasProvince": true,
            "provinceIndex": p,
            "isPlayerOwned": isMine,
            "outbreaks": outbreaks,
            "immunities": immunities,
            "plagueDeathsText": deaths >= 1 ? Self.formatPeople(deaths) : "",
            "isQuarantined": cal.isQuarantined(p),
            "isCordoned": cal.isCordoned(p),
            "isPort": w.hasSeaAccess(province),
            "canQuarantine": isMine && (cal.isQuarantined(p) || quarantineRefusal.isEmpty),
            "canCordon": isMine && (cal.isCordoned(p) || cordonRefusal.isEmpty),
            "quarantineRefusal": quarantineRefusal,
            "cordonRefusal": cordonRefusal,
            "quarantineCostText": String(format: "%.1f", PlagueSystem.quarantineCost(w, province)),
            "cordonCostText": String(format: "%.1f", PlagueSystem.cordonCost(w, province)),
            "famine": w.provinces.famine[p],
            "famineText": Self.formatPercent(w.provinces.famine[p]),
            "famineDeathsText": starved >= 1 ? Self.formatPeople(starved) : "",
            "harvestText": Self.formatPercent(harvest),
            "cropText": Self.formatPercent(crop),
            "unrest": w.unrest.unrest(p),
            "unrestText": String(format: "%.0f", w.unrest.unrest(p)),
            "unrestCauses": causes,
            "rebels": rebels,
            "lastQuakeText": quake.map { "\($0.name), \($0.date)" } ?? ""
        ]
    }

    public func setQuarantine(provinceIndex: Int, on: Bool) -> [String: Any] {
        guard let s = session, provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return ["ok": false, "reason": "Invalid province."]
        }
        if let refusal = s.setQuarantine(in: ProvinceID(provinceIndex), on: on) {
            return ["ok": false, "reason": refusal.reason]
        }
        return ["ok": true, "reason": ""]
    }

    public func setCordon(provinceIndex: Int, on: Bool) -> [String: Any] {
        guard let s = session, provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return ["ok": false, "reason": "Invalid province."]
        }
        if let refusal = s.setCordon(in: ProvinceID(provinceIndex), on: on) {
            return ["ok": false, "reason": refusal.reason]
        }
        return ["ok": true, "reason": ""]
    }

    // MARK: - Rebels window

    public func rebelsWindowDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else { return ["hasPlayer": false] }
        let w = s.world
        let c = player.index
        let peasantTax = w.countries.taxLevel[c][TaxClass.peasants.rawValue]

        var factions: [[String: Any]] = []
        let mine = w.unrest.factions(of: player).sorted {
            $0.risen != $1.risen ? $0.risen : ($0.progress != $1.progress ? $0.progress > $1.progress : $0.id < $1.id)
        }
        for f in mine {
            let target = RebelSystem.target(w, f)
            let men = f.risen ? RebelSystem.men(w, f) : RebelSystem.expectedMen(w, f)
            let places = f.provinces.prefix(4).map { w.provinces.name[$0.index] }
            var status: String
            if f.risen {
                let left = RebelSystem.monthsToVictory(f) ?? 0
                status = "In arms with \(Self.formatPeople(Double(men))) men"
                if let target { status += " at \(w.provinces.name[target.index])" }
                let plural: String = left == 1 ? "" : "s"
                status += ". They win in \(left) month\(plural) unless beaten."
            } else {
                let trend: String = f.lastChange >= 0.05 ? "growing" : (f.lastChange <= -0.05 ? "fading" : "steady")
                let change: String = String(format: "%+.1f", f.lastChange)
                status = "\(Int(f.progress))% (\(trend), \(change) a month)"
                if men > 0 { status += "; about \(Self.formatPeople(Double(men))) would rise" }
            }
            var provincesText = "the whole realm"
            if !places.isEmpty {
                provincesText = places.joined(separator: ", ")
                if f.provinces.count > 4 { provincesText += " and \(f.provinces.count - 4) more" }
            }
            let targetIndex: Int = target?.index ?? -1
            let canLowerTaxes: Bool = f.kind == .peasants && peasantTax > 0
            factions.append([
                "factionId": f.id,
                "name": RebelSystem.name(w, f),
                "kind": f.kind.displayName,
                "kindKey": "\(f.kind)",
                "progress": f.progress,
                "progressText": "\(Int(f.progress))%",
                "change": f.lastChange,
                "risen": f.risen,
                "men": men,
                "status": status,
                "demand": RebelSystem.demand(w, f),
                "concession": RebelSystem.concession(w, f),
                "provincesText": provincesText,
                "targetProvinceIndex": targetIndex,
                "canLowerTaxes": canLowerTaxes
            ])
        }

        // The most restless provinces, with their biggest cause.
        var restless: [(Int, Double)] = []
        for p in 0..<w.provinces.count where w.provinces.owner[p] == player && w.unrest.unrest(p) >= 1 {
            restless.append((p, w.unrest.unrest(p)))
        }
        restless.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        var provinces: [[String: Any]] = []
        for (p, unrest) in restless.prefix(12) {
            let top = UnrestSystem.causes(w, in: ProvinceID(p), date: s.date).first { $0.points > 0 }
            var causeText = ""
            if let top { causeText = top.cause.displayName + " " + String(format: "%+.0f", top.points) }
            provinces.append([
                "provinceIndex": p,
                "name": w.provinces.name[p],
                "unrest": unrest,
                "unrestText": String(format: "%.0f", unrest),
                "causeText": causeText
            ])
        }

        let capMonths = c < w.unrest.peasantTaxCapMonths.count ? w.unrest.peasantTaxCapMonths[c] : 0
        let quiet = c < w.unrest.quietMonths.count ? w.unrest.quietMonths[c] : 0
        var notes: [String] = []
        if capMonths > 0 {
            notes.append(String(format: "A settlement keeps the tax on peasants at %.0f%% or less for %d more months.",
                                w.unrest.peasantTaxCap[c] * 100, capMonths))
        }
        if quiet > 0 { notes.append("After the last troubles, discontent grows slowly for \(quiet) more months.") }

        return [
            "hasPlayer": true,
            "playerTag": w.countries.tag[c],
            "averageUnrestText": String(format: "%.0f", UnrestSystem.averageUnrest(w, of: player)),
            "restlessCount": restless.count,
            "factions": factions,
            "provinces": provinces,
            "peasantTaxText": String(format: "%.0f%%", peasantTax * 100),
            "notes": notes,
            "ralliesText": "Risings so far in the world: \(w.unrest.risings) "
                + "(\(w.unrest.rebelVictories) won, \(w.unrest.rebelDefeats) crushed, \(w.unrest.concessions) bought off)"
        ]
    }

    public func concedeToRebels(factionId: Int) -> [String: Any] {
        guard let s = session else { return ["ok": false, "reason": "No game."] }
        if let refusal = s.concedeToRebels(faction: factionId) { return ["ok": false, "reason": refusal.reason] }
        return ["ok": true, "reason": ""]
    }

    public func sendTroopsAgainstRebels(factionId: Int) -> [String: Any] {
        guard let s = session else { return ["ok": false, "reason": "No game."] }
        if let refusal = s.sendTroopsAgainstRebels(faction: factionId) { return ["ok": false, "reason": refusal.reason] }
        return ["ok": true, "reason": ""]
    }

    public func lowerPeasantTaxes() -> [String: Any] {
        guard let s = session else { return ["ok": false, "reason": "No game."] }
        if let refusal = s.lowerPeasantTaxes() { return ["ok": false, "reason": refusal.reason] }
        return ["ok": true, "reason": ""]
    }

    // MARK: - Map overlay (Plague and Unrest map modes)

    /// Markers for the Plague map mode (outbreaks, quarantines, cordons,
    /// famine, recent earthquakes) and the Unrest map mode (factions).
    public func calamityOverlayData() -> [String: Any] {
        guard let s = session else { return ["outbreaks": [], "measures": [], "famines": [], "quakes": [], "rebels": []] }
        let w = s.world
        let cal = w.calamity
        let positions = s.provincePositions
        var outbreaks: [[String: Any]] = []
        var measures: [[String: Any]] = []
        var famines: [[String: Any]] = []
        for p in 0..<min(w.provinces.count, positions.count) {
            let pos = positions[p]
            var worst: Disease?
            var share = 0.0
            for d in Disease.allCases where cal.hasOutbreak(p, d) && cal.infection(p, d) >= share {
                worst = d
                share = cal.infection(p, d)
            }
            if let worst {
                outbreaks.append(["provinceIndex": p, "x": pos.x, "y": pos.y, "disease": worst.key,
                                  "letter": String(worst.displayName.prefix(1)), "share": share])
            }
            if cal.isQuarantined(p) || cal.isCordoned(p) {
                measures.append(["provinceIndex": p, "x": pos.x, "y": pos.y,
                                 "quarantine": cal.isQuarantined(p), "cordon": cal.isCordoned(p)])
            }
            if w.provinces.famine[p] >= FamineModel.alertAbove {
                famines.append(["provinceIndex": p, "x": pos.x, "y": pos.y, "severity": w.provinces.famine[p]])
            }
        }
        var quakes: [[String: Any]] = []
        for q in cal.quakes where s.date.ordinal - q.date.ordinal <= 365 && q.epicentre.index < positions.count {
            let pos = positions[q.epicentre.index]
            quakes.append(["provinceIndex": q.epicentre.index, "x": pos.x, "y": pos.y,
                           "name": q.name, "strength": q.strength])
        }
        var rebels: [[String: Any]] = []
        for f in w.unrest.factions {
            guard let target = RebelSystem.target(w, f), target.index < positions.count else { continue }
            let pos = positions[target.index]
            rebels.append(["factionId": f.id, "provinceIndex": target.index, "x": pos.x, "y": pos.y,
                           "name": RebelSystem.name(w, f), "progress": f.progress, "risen": f.risen,
                           "isPlayer": f.country == s.playerCountry])
        }
        return ["outbreaks": outbreaks, "measures": measures, "famines": famines, "quakes": quakes, "rebels": rebels]
    }
}
