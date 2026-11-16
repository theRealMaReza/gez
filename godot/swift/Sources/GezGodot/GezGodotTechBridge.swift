import Foundation
import GezCore

/// Phase 13 screens: Technology window, institutions, focus, and Institutions map overlay.
extension GezGodotController {

    // MARK: - Top bar

    /// Compact summary text for the top-bar Tech button: e.g. `Tech 4/4/4`.
    public var topBarTechText: String {
        guard let s = session, let p = s.playerCountry else { return "Tech" }
        let adm = s.world.tech.level(p, .administrative)
        let dip = s.world.tech.level(p, .diplomatic)
        let mil = s.world.tech.level(p, .military)
        return "Tech \(adm)/\(dip)/\(mil)"
    }

    // MARK: - Technology window

    public func technologyWindowDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasPlayer": false]
        }
        let w = s.world
        let year = s.date.year
        let focus = w.tech.focus(of: player)

        var focusOptions: [[String: Any]] = []
        for f in TechFocus.allCases {
            focusOptions.append([
                "key": f.key,
                "name": f.displayName,
                "selected": f == focus
            ])
        }

        let admFx = w.techEffects(player, track: .administrative)
        let dipFx = w.techEffects(player, track: .diplomatic)
        let milFx = w.techEffects(player, track: .military)
        let summary = String(
            format: "Max Building Lv %d · Max Fort Lv %d · Trade Range %d · Tactics %.2f · Morale +%.1f · Admin Eff +%.0f%%",
            admFx.maxBuilding,
            milFx.maxFort,
            dipFx.tradeRange,
            milFx.tactics,
            milFx.landMorale,
            admFx.adminEff * 100
        )

        var tracks: [[String: Any]] = []
        for track in TechTrack.allCases {
            let b = TechSystem.breakdown(w, for: player, track: track, year: year)
            let atMax = b.level >= TechRules.maxLevel
            let fraction = atMax ? 1.0 : min(1.0, max(0.0, b.progress / max(1.0, b.effectiveCost)))
            let remaining = max(0.0, b.effectiveCost - b.progress)
            let monthsToNext = (!atMax && b.totalMonthlyGain > 0.001)
                ? Int(ceil(remaining / b.totalMonthlyGain))
                : 0

            var sourceParts: [String] = [
                String(format: "Base +%.2f", b.baseGain),
                String(format: "Ruler +%.2f", b.rulerSkillContrib),
                String(format: "Council +%.2f", b.seatSkillContrib),
                String(format: "Learning +%.2f", b.sharedCharContrib * b.focusShare),
                String(format: "Colleges +%.2f", b.sharedCollegeContrib * b.focusShare)
            ]
            if b.sharedPaperContrib > 0.001 {
                sourceParts.append(String(format: "Paper +%.2f", b.sharedPaperContrib * b.focusShare))
            }
            if b.sharedBooksContrib > 0.001 {
                sourceParts.append(String(format: "Books +%.2f", b.sharedBooksContrib * b.focusShare))
            }
            if abs(b.govLearningMod) > 0.001 {
                sourceParts.append(String(format: "Laws %+.0f%%", b.govLearningMod * 100))
            }
            sourceParts.append(String(format: "Focus %.0f%%", b.focusShare * 100))
            if b.institutionSpeedBonus > 0.001 {
                sourceParts.append(String(format: "Inst +%.0f%%", b.institutionSpeedBonus * 100))
            }

            let nbPct = Int((b.neighbourBonusFraction * 100).rounded())
            let aheadPct = Int((b.aheadOfTimePenalty * 100).rounded())
            let instPct = Int((b.institutionPenalty * 100).rounded())
            let costModifiersText = String(
                format: "Base %.0f · Neighbour -%d%% · Ahead +%d%% · Inst +%d%%",
                b.baseCost, nbPct, aheadPct, instPct
            )

            let currentSummary = w.techRules.levelDef(track, level: b.level)?.summary ?? ""
            let nextLevel = atMax ? TechRules.maxLevel : b.level + 1
            let nextDef = w.techRules.levelDef(track, level: nextLevel)
            var nextSummary = atMax ? "Maximum level reached." : (nextDef?.summary ?? "")
            if !atMax {
                var extraUnlocks: [String] = []
                if track == .military {
                    for ut in w.military.unitTypes where ut.minMilTech == nextLevel && UnitUnlock.matches(ut.requires, in: w, for: player) {
                        extraUnlocks.append(ut.name)
                    }
                } else if track == .diplomatic {
                    for st in w.navy.shipTypes where st.minDipTech == nextLevel && UnitUnlock.matches(st.requires, in: w, for: player) {
                        extraUnlocks.append(st.name)
                    }
                }
                if !extraUnlocks.isEmpty {
                    let prefix = nextSummary.isEmpty ? "" : "\(nextSummary) · "
                    nextSummary = prefix + "Units: " + extraUnlocks.joined(separator: ", ")
                }
            }

            tracks.append([
                "key": track.key,
                "name": track.displayName,
                "shortName": track.shortName,
                "level": b.level,
                "maxLevel": TechRules.maxLevel,
                "progress": b.progress,
                "effectiveCost": b.effectiveCost,
                "baseCost": b.baseCost,
                "fraction": fraction,
                "monthsToNext": monthsToNext,
                "totalMonthlyGain": b.totalMonthlyGain,
                "sourcesText": sourceParts.joined(separator: " · "),
                "costModifiersText": costModifiersText,
                "neighbourLevelsAhead": b.neighbourLevelsAhead,
                "neighbourBonusPercent": nbPct,
                "aheadOfTimeYears": b.aheadOfTimeYears,
                "aheadOfTimePercent": aheadPct,
                "institutionPenaltyPercent": instPct,
                "embracedSpeedPercent": Int((b.institutionSpeedBonus * 100).rounded()),
                "currentSummary": currentSummary,
                "nextLevel": nextLevel,
                "nextTargetYear": nextDef?.targetYear ?? year,
                "nextSummary": nextSummary,
                "atMax": atMax
            ])
        }

        let params = w.techRules.params
        var institutions: [[String: Any]] = []
        for inst in w.techRules.institutions {
            let idx = inst.index
            let spawned = idx < w.tech.institutionSpawned.count && w.tech.institutionSpawned[idx]
            let originProv = idx < w.tech.institutionOrigin.count ? w.tech.institutionOrigin[idx] : nil
            let spawnedYear = idx < w.tech.institutionSpawnYear.count ? w.tech.institutionSpawnYear[idx] : inst.spawnYear
            let embraced = w.tech.hasEmbraced(player, institution: idx)
            let share = InstitutionSystem.spreadShare(w, for: player, institution: idx)
            let cost = Int(InstitutionSystem.embraceCost(w, for: player, institution: idx).rounded())
            let refusal = InstitutionSystem.embraceRefusal(w, for: player, institution: idx)

            let penaltyPct: Int
            if spawned && !embraced {
                let yearsSince = max(0, year - spawnedYear)
                let pen = min(params.institutionPenaltyCap, Double(yearsSince) * params.institutionPenaltyPerYear)
                penaltyPct = Int((pen * 100).rounded())
            } else {
                penaltyPct = 0
            }

            let originName: String
            if let op = originProv {
                originName = w.provinces.name[op.index]
            } else {
                switch inst.origin {
                case .region(let reg): originName = reg
                case .province(let p): originName = w.provinces.name[p.index]
                case .dynamic(let rule):
                    originName = rule == "richest_port_market" ? "Richest Port Market" : "Top Workshop Province"
                }
            }

            institutions.append([
                "index": idx,
                "key": inst.key,
                "name": inst.name,
                "spawnYear": inst.spawnYear,
                "spawnedYear": spawnedYear,
                "spawned": spawned,
                "originProvinceIndex": originProv?.index ?? -1,
                "originName": originName,
                "embraced": embraced,
                "spreadShare": share,
                "spreadPercentText": String(format: "%.0f%%", share * 100),
                "embraceCost": cost,
                "canEmbrace": refusal == nil,
                "embraceReason": refusal?.reason ?? "",
                "penaltyPercent": penaltyPct,
                "summary": inst.summary
            ])
        }

        var notes: [[String: Any]] = []
        for n in w.tech.notes.suffix(10).reversed() {
            if n.country == nil || n.country == player {
                notes.append([
                    "dateText": n.date.description,
                    "kind": n.kind.rawValue,
                    "text": n.text,
                    "provinceIndex": n.province?.index ?? -1
                ])
                if notes.count >= 6 { break }
            }
        }

        return [
            "hasPlayer": true,
            "playerTag": w.countries.tag[player.index],
            "playerName": w.countries.name[player.index],
            "focusKey": focus.key,
            "focusName": focus.displayName,
            "treasury": Int(w.countries.treasury[player.index].rounded(.down)),
            "summary": summary,
            "focusOptions": focusOptions,
            "tracks": tracks,
            "institutions": institutions,
            "notes": notes
        ]
    }

    public func setTechFocus(key: String) -> [String: Any] {
        guard let s = session else { return ["ok": false, "reason": "No game."] }
        guard let focus = TechFocus(key: key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
            return ["ok": false, "reason": "Unknown research focus."]
        }
        guard s.setTechFocus(focus) else {
            return ["ok": false, "reason": "No active country."]
        }
        return ["ok": true, "reason": ""]
    }

    public func embraceInstitution(index: Int) -> [String: Any] {
        guard let s = session else { return ["ok": false, "reason": "No game."] }
        if let refusal = s.embraceInstitution(index) {
            return ["ok": false, "reason": refusal.reason]
        }
        return ["ok": true, "reason": ""]
    }

    // MARK: - Province panel

    /// Institution presence and origin flags for one province (shown in the People tab).
    public func provinceTechDetails(provinceIndex: Int) -> [String: Any] {
        guard let s = session, provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return ["hasProvince": false]
        }
        let w = s.world
        let pid = ProvinceID(provinceIndex)
        let owner = w.provinces.owner[provinceIndex]
        var list: [[String: Any]] = []
        for inst in w.techRules.institutions {
            let idx = inst.index
            let spawned = idx < w.tech.institutionSpawned.count && w.tech.institutionSpawned[idx]
            let pres = w.tech.provincePresence(pid, institution: idx)
            let isOrigin = idx < w.tech.institutionOrigin.count && w.tech.institutionOrigin[idx] == pid
            let ownerEmbraced = owner.map { w.tech.hasEmbraced($0, institution: idx) } ?? false
            list.append([
                "index": idx,
                "name": inst.name,
                "spawnYear": inst.spawnYear,
                "spawned": spawned,
                "presence": pres,
                "percentText": spawned ? String(format: "%.0f%%", pres * 100) : "From \(inst.spawnYear)",
                "isOrigin": isOrigin,
                "ownerEmbraced": ownerEmbraced
            ])
        }
        return [
            "hasProvince": true,
            "provinceIndex": provinceIndex,
            "provinceName": w.provinces.name[provinceIndex],
            "institutions": list
        ]
    }

    // MARK: - Map overlay (Institutions map mode)

    /// Origin badges for the Institutions map mode.
    public func techOverlayData() -> [String: Any] {
        guard let s = session else { return ["origins": []] }
        let w = s.world
        let positions = s.provincePositions
        var origins: [[String: Any]] = []
        for inst in w.techRules.institutions {
            let idx = inst.index
            guard idx < w.tech.institutionSpawned.count,
                  w.tech.institutionSpawned[idx],
                  let op = w.tech.institutionOrigin[idx],
                  op.index < positions.count else { continue }
            let pos = positions[op.index]
            origins.append([
                "index": idx,
                "name": inst.name,
                "letter": String(inst.name.prefix(1)),
                "provinceIndex": op.index,
                "provinceName": w.provinces.name[op.index],
                "year": w.tech.institutionSpawnYear[idx],
                "x": pos.x,
                "y": pos.y
            ])
        }
        return ["origins": origins]
    }
}
