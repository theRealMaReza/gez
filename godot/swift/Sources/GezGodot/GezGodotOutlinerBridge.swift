import Foundation
import GezCore

// Phase 20.6 part 3b: data for the right-hand outliner (godot/scripts/Outliner.gd).
// One lean call: the player's armies, fleets, sieges (theirs and against them)
// and building work, each with a map point to jump to. Read-only.

extension GezGodotController {

    public func outlinerData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let armies = w.military.armies
        let positions = s.provincePositions

        func point(_ p: ProvinceID) -> (Double, Double) {
            guard p.index >= 0 && p.index < positions.count else { return (0, 0) }
            return (positions[p.index].x, positions[p.index].y)
        }

        // Armies
        var armyRows: [[String: Any]] = []
        for aid in w.military.armies(of: player) {
            let i = Int(aid.rawValue)
            let prov = armies.province[i]
            let provName = w.provinces.name[prov.index]
            let path = armies.path[i]
            let besieging = w.military.sieges.contains { $0.province == prov && $0.besieger == player }
            let status: String
            if w.military.isInBattle(aid) {
                status = "In battle at \(provName)"
            } else if armies.embarkedOnFleet[i] != nil {
                status = "Aboard ship"
            } else if armies.isRetreating[i] {
                status = "Retreating"
            } else if let dest = path.last {
                let days = max(1, Int((armies.moveStepDays[i] - armies.moveProgressDays[i]).rounded(.up)))
                status = "To \(w.provinces.name[dest.index]) · \(days) d"
            } else if besieging {
                status = "Besieging \(provName)"
            } else {
                status = provName
            }
            let (x, y) = point(prov)
            armyRows.append([
                "armyId": i,
                "name": armies.name[i],
                "men": armies.totalMen(of: aid),
                "status": status,
                "inBattle": w.military.isInBattle(aid),
                "provinceIndex": prov.index,
                "x": x,
                "y": y
            ])
        }

        // Fleets
        let fleets = w.navy.fleets
        var fleetRows: [[String: Any]] = []
        for fid in w.navy.fleets(of: player) {
            let fi = fid.index
            let status: String
            switch fleets.location[fi] {
            case .port(let p):
                status = "In port, \(w.provinces.name[p.index])"
            case .sea(let sz):
                let seaName = sz.index < w.seaZones.count ? w.seaZones.name[sz.index] : "At sea"
                status = fleets.battle[fi] != nil ? "In battle, \(seaName)" : seaName
            }
            let (x, y) = locationScreenPos(s, location: fleets.location[fi])
            fleetRows.append([
                "fleetId": fi,
                "name": fleets.name[fi],
                "ships": w.navy.shipCount(of: fid),
                "status": status,
                "inBattle": fleets.battle[fi] != nil,
                "x": x,
                "y": y
            ])
        }

        // Sieges: ours, then enemy sieges of our forts.
        var siegeRows: [[String: Any]] = []
        for siege in w.military.sieges {
            let ours = siege.besieger == player
            let against = w.provinces.owner[siege.province.index] == player
            guard ours || against else { continue }
            let (x, y) = point(siege.province)
            var status = "Progress \(siege.progress)"
            if siege.breached { status += " · walls breached" }
            if against { status = "Besieged by \(w.countries.name[siege.besieger.index]) · " + status }
            siegeRows.append([
                "provinceIndex": siege.province.index,
                "name": w.provinces.name[siege.province.index],
                "ours": ours,
                "status": status,
                "x": x,
                "y": y
            ])
        }
        siegeRows = siegeRows.filter { ($0["ours"] as? Bool) == true } + siegeRows.filter { ($0["ours"] as? Bool) != true }

        // Building work: buildings in our provinces, then our ships.
        var buildRows: [[String: Any]] = []
        for con in w.economy.buildings.constructions where w.provinces.owner[con.province.index] == player {
            let (x, y) = point(con.province)
            buildRows.append([
                "provinceIndex": con.province.index,
                "name": Self.buildingName(con.type, in: con.province, world: w),
                "status": "\(w.provinces.name[con.province.index]) · \(con.monthsLeft) mo",
                "percent": Int((con.progress * 100).rounded()),
                "x": x,
                "y": y
            ])
        }
        for job in w.navy.constructions where job.country == player {
            let (x, y) = point(job.province)
            let done = job.monthsTotal > 0 ? 1 - Double(job.monthsLeft) / Double(job.monthsTotal) : 1
            buildRows.append([
                "provinceIndex": job.province.index,
                "name": w.navy.shipType(job.shipType).name,
                "status": "\(w.provinces.name[job.province.index]) · \(job.monthsLeft) mo",
                "percent": Int((done * 100).rounded()),
                "x": x,
                "y": y
            ])
        }

        return [
            "valid": true,
            "armies": armyRows,
            "fleets": fleetRows,
            "sieges": siegeRows,
            "building": buildRows
        ]
    }
}
