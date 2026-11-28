import Foundation
import GezCore

// Phase 20.8: ruling systems and formables bridge for Godot screens.

extension GezGodotController {

    /// Picture key for a country's shield: its tag, or the formable's shield
    /// once it has formed one. Unknown tags come back unchanged.
    public func countryShieldKey(tag: String) -> String {
        guard let w = session?.world, let c = w.countries.id(forTag: tag) else { return tag }
        return w.countries.shield[c.index]
    }

    /// Data snapshot for the Holy Roman Empire "Imperial Diet" window (mock-up A).
    public func imperialDietData() -> [String: Any] {
        guard let session else { return ["active": false] }
        let w = session.world
        let date = session.date
        guard let state = RulingEngine.state(w, HRESystem.key) else {
            return ["active": false]
        }

        let player = session.playerCountry
        let playerIsMember = player.map { state.isMember($0) } ?? false
        let playerIsLeader = player != nil && state.leader == player
        let playerFavour = player.map { RulingEngine.countryValue(w, HRESystem.key, "favour", $0) } ?? 0.0
        var out: [String: Any] = [
            "active": state.active,
            "authority": RulingEngine.value(w, HRESystem.key, "authority"),
            "monthlyAuthority": HRESystem.monthlyAuthorityDelta(in: w),
            "memberCount": state.members.count,
            "freeCityCount": state.holders("free_city").count,
            "playerIsMember": playerIsMember,
            "playerIsLeader": playerIsLeader,
            "playerFavour": playerFavour,
            "stage": state.stage,
            "leaguesActive": state.flags.contains("leagues_active"),
            "catholicLeagueCount": state.holders(HRESystem.catholicLeagueRole).count,
            "protestantLeagueCount": state.holders(HRESystem.protestantLeagueRole).count,
        ]

        // Emperor details.
        if let emp = state.leader, emp.index >= 0 && emp.index < w.countries.count {
            let tag = w.countries.tag[emp.index]
            let realm = w.countries.name[emp.index]
            let col = w.countries.color[emp.index]
            let rulerName: String
            if let rid = w.countries.ruler[emp.index], rid.index >= 0 && rid.index < w.people.characters.name.count {
                rulerName = w.people.characters.name[rid.index]
            } else {
                rulerName = "Regency Council"
            }
            let sinceYear = state.leaderSince?.year ?? Scenario1453.startDate.year
            let years = max(1, date.year - sinceYear + (date.year == sinceYear ? 0 : 0))
            out["emperorTag"] = tag
            out["emperorName"] = realm
            out["emperorRuler"] = rulerName
            out["emperorYears"] = years
            out["emperorR"] = Int(col.r)
            out["emperorG"] = Int(col.g)
            out["emperorB"] = Int(col.b)
        } else {
            out["emperorTag"] = ""
            out["emperorName"] = "Vacant"
            out["emperorRuler"] = "Interregnum"
            out["emperorYears"] = 0
            out["emperorR"] = 180
            out["emperorG"] = 140
            out["emperorB"] = 80
        }

        // Religious status line.
        let religiousStatus: String
        if state.flags.contains("catholic_official") {
            religiousStatus = "Catholic Imperial Faith"
        } else if state.flags.contains("protestant_official") {
            religiousStatus = "Protestant Imperial Faith"
        } else if state.flags.contains("religious_peace") {
            religiousStatus = "Peace of Augsburg (Cuius Regio, Eius Religio)"
        } else if state.flags.contains("leagues_active") {
            let cCount = state.holders(HRESystem.catholicLeagueRole).count
            let pCount = state.holders(HRESystem.protestantLeagueRole).count
            religiousStatus = "Religious Leagues Active (Catholic: \(cCount), Protestant: \(pCount))"
        } else {
            religiousStatus = ""
        }
        out["religiousStatus"] = religiousStatus

        // The 7 electors and each elector's current lean.
        let leans = HRESystem.electorLeans(in: w)
        let electors: [[String: Any]] = leans.map { pair in
            let e = pair.elector
            let eTag = w.countries.tag[e.index]
            let eName = w.countries.name[e.index]
            let eCol = w.countries.color[e.index]
            let leanTag = pair.lean.map { w.countries.tag[$0.index] } ?? "—"
            let leanName = pair.lean.map { w.countries.name[$0.index] } ?? "Undecided"
            return [
                "tag": eTag,
                "name": eName,
                "leanTag": leanTag,
                "leanName": leanName,
                "r": Int(eCol.r),
                "g": Int(eCol.g),
                "b": Int(eCol.b),
            ]
        }
        out["electors"] = electors

        // Reichstag reform ladder.
        let next = HRESystem.nextReform(in: w)
        let canEnact = player.map { HRESystem.canEnactNextReform(in: w, by: $0) } ?? false
        let reforms: [[String: Any]] = HRESystem.reforms.map { r in
            let passed = state.flags.contains(r.flag)
            let isNext = (next?.flag == r.flag)
            return [
                "stage": r.stage,
                "flag": r.flag,
                "name": r.name,
                "summary": r.summary,
                "cost": r.cost,
                "passed": passed,
                "isNext": isNext,
                "canEnact": isNext && canEnact,
            ]
        }
        out["reforms"] = reforms

        return out
    }

    /// Enacts the next Reichstag reform if the player is Emperor and has enough Imperial Authority.
    public func enactNextHREReform() -> Bool {
        guard let session, let player = session.playerCountry else { return false }
        return HRESystem.enactNextReform(&session.simulation.world, by: player, date: session.date)
    }
}
