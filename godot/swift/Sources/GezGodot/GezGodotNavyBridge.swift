import Foundation
import GezCore

extension GezGodotController {

    // MARK: - Top Bar & Selection Helpers

    public var selectedFleetId: Int {
        guard let s = session,
              let fid = s.selectedFleet,
              fid.index >= 0 && fid.index < s.world.navy.fleets.count,
              s.world.navy.fleets.alive[fid.index] else {
            return -1
        }
        return fid.index
    }

    public var moveModeFleetId: Int {
        guard let s = session,
              let fid = s.moveModeForFleet,
              fid.index >= 0 && fid.index < s.world.navy.fleets.count,
              s.world.navy.fleets.alive[fid.index] else {
            return -1
        }
        return fid.index
    }

    public var topBarFleetsText: String {
        guard let s = session, let p = s.playerCountry else { return "Fleets 0" }
        let ships = s.world.navy.totalShips(of: p)
        let sailors = Int(s.world.navy.sailors[p.index].rounded())
        return "Fleets \(ships) · Sailors \(Self.compactCount(sailors))"
    }

    @discardableResult
    public func selectFleet(fleetId: Int) -> Bool {
        guard let s = session else { return false }
        let fleets = s.world.navy.fleets
        guard fleetId >= 0 && fleetId < fleets.count && fleets.alive[fleetId] else {
            return false
        }
        let fid = FleetID(fleetId)
        s.selectedFleet = fid
        if s.moveModeForFleet != nil && s.moveModeForFleet != fid {
            s.moveModeForFleet = nil
        }
        return true
    }

    public func clearSelectedFleet() {
        session?.selectedFleet = nil
        session?.moveModeForFleet = nil
    }

    @discardableResult
    public func setMoveModeForFleet(fleetId: Int) -> Bool {
        guard let s = session else { return false }
        if fleetId < 0 {
            s.moveModeForFleet = nil
            return false
        }
        let fleets = s.world.navy.fleets
        guard fleetId >= 0 && fleetId < fleets.count && fleets.alive[fleetId],
              let player = s.playerCountry,
              fleets.owner[fleetId] == player,
              fleets.battle[fleetId] == nil else {
            s.moveModeForFleet = nil
            return false
        }
        let fid = FleetID(fleetId)
        s.selectedFleet = fid
        s.moveModeForFleet = fid
        return true
    }

    // MARK: - Map Layer Overlay (Fleets, Sea Routes, Naval Battles & Blockades)

    public func mapFleetsSignature() -> Int {
        guard let s = session else { return 0 }
        var hasher = Hasher()
        let w = s.world
        let fleets = w.navy.fleets
        hasher.combine(selectedFleetId)
        hasher.combine(moveModeFleetId)
        hasher.combine(s.playerCountry?.index ?? -1)
        hasher.combine(w.diplomacy.wars.count)
        hasher.combine(w.navy.battles.count)
        hasher.combine(w.navy.blockadedProvinces.count)
        for i in 0..<fleets.count where fleets.alive[i] {
            hasher.combine(i)
            switch fleets.location[i] {
            case .port(let p): hasher.combine(p.index + 10000)
            case .sea(let sz): hasher.combine(sz.index)
            }
            hasher.combine(fleets.path[i].count)
            hasher.combine(fleets.destinationPort[i]?.index ?? -1)
            hasher.combine(fleets.mission[i].rawValue)
            hasher.combine(w.navy.shipCount(of: FleetID(i)))
            hasher.combine(fleets.embarkedArmies[i].count)
            hasher.combine(fleets.battle[i] ?? -1)
        }
        return hasher.finalize()
    }

    func locationScreenPos(_ s: GameSession, location: FleetLocation) -> (Double, Double) {
        let w = s.world
        switch location {
        case .sea(let sz):
            if sz.index >= 0 && sz.index < w.seaZones.centerX.count {
                return (w.seaZones.centerX[sz.index], w.seaZones.centerY[sz.index])
            }
            return (0, 0)
        case .port(let p):
            if p.index >= 0 && p.index < s.provincePositions.count {
                let pt = s.provincePositions[p.index]
                return (pt.x + 12.0, pt.y + 18.0)
            }
            return (0, 0)
        }
    }

    public func mapFleetsData() -> [String: Any] {
        guard let s = session else {
            return [
                "selectedFleetId": -1,
                "moveModeFleetId": -1,
                "counters": [],
                "routes": [],
                "battles": [],
                "blockades": []
            ]
        }
        let w = s.world
        let fleets = w.navy.fleets
        let curSelectedId = selectedFleetId
        let curMoveId = moveModeFleetId

        var enemyCountries = Set<CountryID>()
        if let player = s.playerCountry {
            for war in w.diplomacy.wars {
                if war.isAttacker(player) {
                    enemyCountries.formUnion(war.defenders)
                } else if war.isDefender(player) {
                    enemyCountries.formUnion(war.attackers)
                }
            }
        }

        // Group stacks cleanly so multiple fleets in the same port or sea zone stagger vertically.
        var byLocKey: [Int: [Int]] = [:]
        for i in 0..<fleets.count where fleets.alive[i] {
            let key: Int
            switch fleets.location[i] {
            case .port(let p): key = 100000 + p.index
            case .sea(let sz): key = sz.index
            }
            byLocKey[key, default: []].append(i)
        }

        var counters: [[String: Any]] = []
        var routes: [[String: Any]] = []

        for key in byLocKey.keys.sorted() {
            let group = byLocKey[key] ?? []
            for (slot, fi) in group.enumerated() {
                let fid = FleetID(fi)
                let owner = fleets.owner[fi]
                let rgb = w.countries.color[owner.index]
                let (bx, by) = locationScreenPos(s, location: fleets.location[fi])
                let offsetY = Double(slot) * 18.0
                let ships = w.navy.shipCount(of: fid)
                let embarkedMen = fleets.embarkedArmies[fi].reduce(0) { $0 + w.military.armies.totalMen(of: $1) }
                let isDocked: Bool
                if case .port = fleets.location[fi] { isDocked = true } else { isDocked = false }
                let isPlayer = owner == s.playerCountry
                let isEnemy = enemyCountries.contains(owner)

                counters.append([
                    "fleetId": fi,
                    "name": fleets.name[fi],
                    "ownerTag": w.countries.tag[owner.index],
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b),
                    "shipCount": ships,
                    "embarkedMen": embarkedMen,
                    "isDocked": isDocked,
                    "mission": fleets.mission[fi].rawValue,
                    "inBattle": fleets.battle[fi] != nil,
                    "isPlayer": isPlayer,
                    "isEnemy": isEnemy,
                    "isSelected": fi == curSelectedId,
                    "x": bx,
                    "y": by + offsetY
                ])

                let path = fleets.path[fi]
                if !path.isEmpty || fleets.destinationPort[fi] != nil {
                    var pts: [Double] = [bx, by + offsetY]
                    for sz in path where sz.index < w.seaZones.centerX.count {
                        pts.append(w.seaZones.centerX[sz.index])
                        pts.append(w.seaZones.centerY[sz.index])
                    }
                    if let destPort = fleets.destinationPort[fi], destPort.index < s.provincePositions.count {
                        let pt = s.provincePositions[destPort.index]
                        pts.append(pt.x)
                        pts.append(pt.y)
                    }
                    if pts.count >= 4 {
                        routes.append([
                            "fleetId": fi,
                            "isPlayer": isPlayer,
                            "isSelected": fi == curSelectedId,
                            "points": pts
                        ])
                    }
                }
            }
        }

        // Naval battle markers
        let battles: [[String: Any]] = w.navy.battles.map { b in
            let z = b.seaZone.index
            let bx = z < w.seaZones.centerX.count ? w.seaZones.centerX[z] : 0
            let by = z < w.seaZones.centerY.count ? w.seaZones.centerY[z] : 0
            return [
                "seaZoneIndex": z,
                "seaZoneName": w.seaZones.name[z],
                "attackerTag": w.countries.tag[b.attacker.country.index],
                "defenderTag": w.countries.tag[b.defender.country.index],
                "dayCount": b.dayCount,
                "x": bx,
                "y": by - 18.0
            ]
        }

        // Blockaded coastal port markers
        let blockades: [[String: Any]] = w.navy.blockadedProvinces.sorted { $0.index < $1.index }.map { p in
            let pt = p.index < s.provincePositions.count ? s.provincePositions[p.index] : (0.0, 0.0)
            return [
                "provinceIndex": p.index,
                "provinceName": w.provinces.name[p.index],
                "x": pt.0 - 12.0,
                "y": pt.1 + 14.0
            ]
        }

        return [
            "selectedFleetId": curSelectedId,
            "moveModeFleetId": curMoveId,
            "counters": counters,
            "routes": routes,
            "battles": battles,
            "blockades": blockades
        ]
    }

    // MARK: - Navies Window & Selected Fleet Details

    public func naviesWindowDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasPlayer": false]
        }
        let w = s.world
        let c = w.countries
        let rgb = c.color[player.index]
        let sailors = Int(w.navy.sailors[player.index].rounded())
        let maxSailors = Int(w.navy.maxSailors[player.index].rounded())
        let monthlySailors = Int(NavySystem.monthlySailorGain(w, player).rounded())
        let totalShips = w.navy.totalShips(of: player)

        var upkeep = 0.0
        for sIdx in 0..<w.navy.ships.count where w.navy.ships.alive[sIdx] {
            let fi = w.navy.ships.fleet[sIdx].index
            if fi >= 0 && fi < w.navy.fleets.count && w.navy.fleets.alive[fi] && w.navy.fleets.owner[fi] == player {
                upkeep += w.navy.shipType(w.navy.ships.type[sIdx]).upkeep * NavyModel.upkeepScale
            }
        }

        let fleetRows: [[String: Any]] = w.navy.fleets(of: player).map { fid in
            let fi = fid.index
            let locText: String
            switch w.navy.fleets.location[fi] {
            case .port(let p): locText = "Port of \(w.provinces.name[p.index])"
            case .sea(let sz): locText = w.seaZones.name[sz.index]
            }
            let ships = w.navy.shipCount(of: fid)
            let avgHull = Int(NavySystem.fleetAverageHull(w, fid).rounded())
            let supply = Int(w.navy.fleets.supply[fi].rounded())
            let admName = w.navy.fleets.admiral[fi].flatMap {
                w.people.characters.isAlive($0) ? w.people.characters.fullName($0) : nil
            } ?? "No admiral"
            let inBattle = w.navy.fleets.battle[fi] != nil
            return [
                "fleetId": fi,
                "name": w.navy.fleets.name[fi],
                "locationText": locText,
                "ships": ships,
                "avgHull": avgHull,
                "supply": supply,
                "mission": w.navy.fleets.mission[fi].rawValue.capitalized,
                "admiralName": admName,
                "inBattle": inBattle,
                "embarkedArmiesCount": w.navy.fleets.embarkedArmies[fi].count
            ]
        }

        let constructions: [[String: Any]] = w.navy.constructions
            .filter { $0.country == player }
            .map { job in
                let st = w.navy.shipType(job.shipType)
                return [
                    "shipName": st.name,
                    "provinceIndex": job.province.index,
                    "provinceName": w.provinces.name[job.province.index],
                    "monthsLeft": job.monthsLeft,
                    "monthsTotal": job.monthsTotal
                ]
            }

        return [
            "hasPlayer": true,
            "countryName": c.name[player.index],
            "tag": c.tag[player.index],
            "colorR": Int(rgb.r),
            "colorG": Int(rgb.g),
            "colorB": Int(rgb.b),
            "totalShips": totalShips,
            "sailors": sailors,
            "maxSailors": maxSailors,
            "monthlySailors": monthlySailors,
            "upkeepText": String(format: "%.2f d/mo", upkeep),
            "fleets": fleetRows,
            "constructions": constructions
        ]
    }

    public func selectedFleetDetails() -> [String: Any] {
        guard let s = session else { return ["hasSelection": false] }
        let fi = selectedFleetId
        guard fi >= 0 else { return ["hasSelection": false] }

        let w = s.world
        let fid = FleetID(fi)
        let owner = w.navy.fleets.owner[fi]
        let isPlayerOwned = owner == s.playerCountry
        let rgb = w.countries.color[owner.index]

        var portProvIndex = -1
        var seaZoneIndex = -1
        var isDocked = false
        var isInland = false
        let locationText: String
        switch w.navy.fleets.location[fi] {
        case .port(let p):
            isDocked = true
            portProvIndex = p.index
            locationText = "Port of \(w.provinces.name[p.index])"
            if let sz = w.provinceSeas[p.index].first {
                seaZoneIndex = sz.index
                isInland = sz.index < w.seaZones.isInland.count && w.seaZones.isInland[sz.index]
            }
        case .sea(let sz):
            seaZoneIndex = sz.index
            locationText = w.seaZones.name[sz.index]
            isInland = sz.index < w.seaZones.isInland.count && w.seaZones.isInland[sz.index]
        }

        // Ship summary by class & individual ships
        var classCounts: [ShipClass: Int] = [:]
        var shipRows: [[String: Any]] = []
        var totalCrew = 0
        var totalMaxCrew = 0
        var hullSum = 0.0
        for sIdx in w.navy.fleets.shipIndices[fi] where w.navy.ships.alive[sIdx] {
            let st = w.navy.shipType(w.navy.ships.type[sIdx])
            classCounts[st.shipClass, default: 0] += 1
            let hull = Int(w.navy.ships.hull[sIdx].rounded())
            let crew = w.navy.ships.crew[sIdx]
            totalCrew += crew
            totalMaxCrew += st.maxCrew
            hullSum += w.navy.ships.hull[sIdx]
            shipRows.append([
                "shipIndex": sIdx,
                "name": st.name,
                "shipClass": st.shipClass.rawValue.capitalized,
                "hull": hull,
                "crew": crew,
                "maxCrew": st.maxCrew,
                "cannons": st.cannons,
                "moraleText": String(format: "%.1f", w.navy.ships.morale[sIdx])
            ])
        }
        let shipCount = shipRows.count
        let avgHull = shipCount > 0 ? Int((hullSum / Double(shipCount)).rounded()) : 0
        let supply = Int(w.navy.fleets.supply[fi].rounded())

        let classOrder: [(ShipClass, String)] = [
            (.heavy, "Heavy"),
            (.galley, "Galley"),
            (.light, "Light"),
            (.transport, "Cog"),
        ]
        let classSummaryText = classOrder.compactMap { cls, label -> String? in
            let n = classCounts[cls] ?? 0
            return n > 0 ? "\(n) \(label)" : nil
        }.joined(separator: " · ")

        // Movement & Battle state
        let inBattleIdx = w.navy.fleets.battle[fi]
        let inBattle = inBattleIdx != nil
        var battleSummaryText = ""
        var statusText = ""
        if let bi = inBattleIdx, bi >= 0 && bi < w.navy.battles.count {
            let b = w.navy.battles[bi]
            let phaseLabel = b.dayCount <= 2 ? "Cannon Phase" : "Boarding Phase"
            let szName = w.seaZones.name[b.seaZone.index]
            let attTag = w.countries.tag[b.attacker.country.index]
            let defTag = w.countries.tag[b.defender.country.index]
            battleSummaryText = "\(attTag) vs \(defTag) in \(szName) · Day \(b.dayCount) (\(phaseLabel))"
            statusText = "Engaged in Naval Battle"
        } else if !w.navy.fleets.path[fi].isEmpty {
            let destName: String
            if let dp = w.navy.fleets.destinationPort[fi] {
                destName = "Port of \(w.provinces.name[dp.index])"
            } else if let tt = w.navy.fleets.transportTarget[fi] {
                destName = "Landing at \(w.provinces.name[tt.index])"
            } else if let last = w.navy.fleets.path[fi].last {
                destName = w.seaZones.name[last.index]
            } else {
                destName = locationText
            }
            let daysLeft = max(1, Int((w.navy.fleets.moveStepDays[fi] - w.navy.fleets.moveProgressDays[fi]).rounded(.up)))
            statusText = "Sailing to \(destName) (\(daysLeft)d)"
        } else if w.navy.fleets.mission[fi] == .blockade, case .sea(let sz) = w.navy.fleets.location[fi] {
            let blockadedCount = w.seaZones.coast[sz.index].count { w.navy.blockadedProvinces.contains($0) }
            statusText = blockadedCount > 0 ? "Blockading \(blockadedCount) port\(blockadedCount == 1 ? "" : "s")" : "Blockade patrol"
        } else {
            statusText = isDocked ? "Docked in Port" : "At Sea (\(w.navy.fleets.mission[fi].rawValue.capitalized))"
        }

        // Admiral & candidates
        let adm = w.navy.fleets.admiral[fi].flatMap { w.people.characters.isAlive($0) ? $0 : nil }
        let admName = adm.map { w.people.characters.fullName($0) } ?? ""
        let admMartial = adm.map { w.people.characters.skill($0, .martial) } ?? 0
        let admText = adm != nil ? "\(admName) (Martial \(admMartial))" : "No admiral"
        var admCandidates: [[String: Any]] = []
        if isPlayerOwned {
            for c in NavySystem.admiralCandidates(w, owner, date: s.date).prefix(10) {
                let m = w.people.characters.skill(c, .martial)
                admCandidates.append([
                    "characterIndex": c.index,
                    "label": "\(w.people.characters.fullName(c)) (M \(m))"
                ])
            }
        }

        // Embarked armies & available dockside armies
        let capMen = w.navy.transportCapacity(of: fid) * 1000
        let embarkedArmies: [[String: Any]] = w.navy.fleets.embarkedArmies[fi].compactMap { aid in
            let ai = Int(aid.rawValue)
            guard ai >= 0 && ai < w.military.armies.count && w.military.armies.alive[ai] else { return nil }
            return [
                "armyId": ai,
                "name": w.military.armies.name[ai],
                "men": w.military.armies.totalMen(of: aid)
            ]
        }
        let embarkedMen = embarkedArmies.reduce(0) { $0 + ($1["men"] as? Int ?? 0) }

        var embarkableArmies: [[String: Any]] = []
        if isPlayerOwned && isDocked && portProvIndex >= 0 && !inBattle {
            let p = ProvinceID(portProvIndex)
            for aid in w.military.armies(in: p) {
                let ai = Int(aid.rawValue)
                guard w.military.armies.owner[ai] == owner, !w.military.armies.isRebel[ai] else { continue }
                let men = w.military.armies.totalMen(of: aid)
                embarkableArmies.append([
                    "armyId": ai,
                    "name": w.military.armies.name[ai],
                    "men": men,
                    "canEmbark": NavySystem.canEmbark(w, army: aid, onto: fid)
                ])
            }
        }

        var disembarkTargets: [[String: Any]] = []
        if isPlayerOwned && !embarkedArmies.isEmpty && !inBattle,
           let firstArmy = w.navy.fleets.embarkedArmies[fi].first {
            for p in NavySystem.validDisembarkProvinces(w, for: firstArmy) {
                let ctrl = w.provinces.controller(of: p)
                let hostile = ctrl != nil && w.diplomacy.isAtWar(owner, ctrl!)
                disembarkTargets.append([
                    "provinceIndex": p.index,
                    "name": w.provinces.name[p.index],
                    "isHostile": hostile
                ])
            }
        }

        // Can merge with another fleet at same location?
        let canMerge = isPlayerOwned && !inBattle && w.navy.fleets(of: owner).contains { other in
            other != fid
                && w.navy.fleets.location[other.index] == w.navy.fleets.location[fi]
                && w.navy.fleets.battle[other.index] == nil
        }
        let canSplit = isPlayerOwned && !inBattle && shipCount >= 2

        let speedZone = seaZoneIndex >= 0 ? SeaZoneID(seaZoneIndex) : SeaZoneID(0)
        let speedVal = seaZoneIndex >= 0 ? NavySystem.fleetSpeed(w, fid, in: speedZone) : 1.0

        // Is country at war -> allow "Blockade Enemy Port" quick action
        let atWar = !w.diplomacy.activeWars(for: owner).isEmpty

        return [
            "hasSelection": true,
            "fleetId": fi,
            "name": w.navy.fleets.name[fi],
            "ownerTag": w.countries.tag[owner.index],
            "ownerName": w.countries.name[owner.index],
            "colorR": Int(rgb.r),
            "colorG": Int(rgb.g),
            "colorB": Int(rgb.b),
            "isPlayerOwned": isPlayerOwned,
            "locationText": locationText,
            "isDocked": isDocked,
            "isInlandSea": isInland,
            "portProvinceIndex": portProvIndex,
            "seaZoneIndex": seaZoneIndex,
            "statusText": statusText,
            "mission": w.navy.fleets.mission[fi].rawValue,
            "supply": supply,
            "avgHull": avgHull,
            "speedText": String(format: "%.2fx", speedVal),
            "shipCount": shipCount,
            "totalCrew": totalCrew,
            "totalMaxCrew": totalMaxCrew,
            "classSummaryText": classSummaryText,
            "admiralIndex": adm?.index ?? -1,
            "admiralText": admText,
            "admiralCandidates": admCandidates,
            "inBattle": inBattle,
            "battleSummaryText": battleSummaryText,
            "transportCapacityMen": capMen,
            "embarkedMen": embarkedMen,
            "embarkedArmies": embarkedArmies,
            "embarkableArmies": embarkableArmies,
            "disembarkTargets": disembarkTargets,
            "canMerge": canMerge,
            "canSplit": canSplit,
            "canBlockadeEnemy": isPlayerOwned && atWar && !inBattle,
            "isMoveMode": fi == moveModeFleetId,
            "ships": shipRows
        ]
    }

    // MARK: - Orders & Shipbuilding

    @discardableResult
    public func buildShipInSelectedProvince(shipTypeIndex: Int) -> Bool {
        guard let s = session,
              let province = s.selectedProvince,
              shipTypeIndex >= 0 && shipTypeIndex < s.world.navy.shipTypes.count else {
            return false
        }
        return s.buildShip(ShipTypeID(shipTypeIndex), in: province) == nil
    }

    @discardableResult
    public func assignFleetAdmiral(fleetId: Int, characterIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let fleets = s.world.navy.fleets
        guard fleetId >= 0 && fleetId < fleets.count && fleets.alive[fleetId],
              fleets.owner[fleetId] == player else { return false }
        let charID: CharacterID?
        if characterIndex >= 0 {
            guard characterIndex < s.world.people.characters.count else { return false }
            charID = CharacterID(characterIndex)
        } else {
            charID = nil
        }
        s.assignAdmiral(charID, to: FleetID(fleetId))
        return true
    }

    @discardableResult
    public func mergeFleetsInLocation(fleetId: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let fleets = s.world.navy.fleets
        guard fleetId >= 0 && fleetId < fleets.count && fleets.alive[fleetId],
              fleets.owner[fleetId] == player,
              fleets.battle[fleetId] == nil else { return false }
        let merged = s.mergeFleets(into: FleetID(fleetId)) > 0
        if merged {
            s.selectedFleet = FleetID(fleetId)
        }
        return merged
    }

    @discardableResult
    public func splitFleet(fleetId: Int) -> Int {
        guard let s = session, let player = s.playerCountry else { return -1 }
        let fleets = s.world.navy.fleets
        guard fleetId >= 0 && fleetId < fleets.count && fleets.alive[fleetId],
              fleets.owner[fleetId] == player,
              fleets.battle[fleetId] == nil else { return -1 }
        return s.split(fleet: FleetID(fleetId))?.index ?? -1
    }

    @discardableResult
    public func orderFleetMoveToSea(fleetId: Int, seaZoneIndex: Int) -> Bool {
        guard let s = session,
              seaZoneIndex >= 0 && seaZoneIndex < s.world.seaZones.count else { return false }
        return s.orderMoveFleet(FleetID(fleetId), toSea: SeaZoneID(seaZoneIndex))
    }

    @discardableResult
    public func orderFleetDock(fleetId: Int, portProvinceIndex: Int) -> Bool {
        guard let s = session,
              portProvinceIndex >= 0 && portProvinceIndex < s.world.provinces.count else { return false }
        return s.orderDockFleet(FleetID(fleetId), inPort: ProvinceID(portProvinceIndex))
    }

    @discardableResult
    public func orderFleetMoveAt(fleetId: Int, mapX: Int, mapY: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        guard fleetId >= 0 && fleetId < s.world.navy.fleets.count && s.world.navy.fleets.alive[fleetId] else {
            return false
        }
        let fid = FleetID(fleetId)
        if let prov = s.idMap.province(x: mapX, y: mapY), s.world.hasSeaAccess(prov) {
            if NavySystem.canDock(s.world, player, in: prov) {
                return s.orderDockFleet(fid, inPort: prov)
            }
            if !s.world.navy.fleets.embarkedArmies[fleetId].isEmpty,
               let ctrl = s.world.provinces.controller(of: prov),
               s.world.diplomacy.isAtWar(player, ctrl) {
                return s.orderTransportAndLand(fleet: fid, to: prov)
            }
            if let sz = s.world.provinceSeas[prov.index].first {
                return s.orderBlockadeFleet(fid, inSea: sz)
            }
        }
        if let sea = s.seaMap.seaZone(x: mapX, y: mapY) {
            return s.orderMoveFleet(fid, toSea: sea)
        }
        return false
    }

    @discardableResult
    public func orderFleetBlockadeNearestEnemy(fleetId: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              fleetId >= 0 && fleetId < s.world.navy.fleets.count && s.world.navy.fleets.alive[fleetId] else {
            return false
        }
        let w = s.world
        let fid = FleetID(fleetId)
        var enemies = Set<CountryID>()
        for war in w.diplomacy.activeWars(for: player) {
            if war.isAttacker(player) { enemies.formUnion(war.defenders) }
            else { enemies.formUnion(war.attackers) }
        }
        guard !enemies.isEmpty else { return false }

        // Pick closest sea zone touching an enemy coastal province
        let curLoc = w.navy.fleets.location[fleetId]
        var bestSea: SeaZoneID?
        var bestLen = Int.max
        for z in 0..<w.seaZones.count {
            let sz = SeaZoneID(z)
            let touchesEnemyPort = w.seaZones.coast[z].contains { p in
                guard w.hasSeaAccess(p), let ctrl = w.provinces.controller(of: p) else { return false }
                return enemies.contains(ctrl)
            }
            guard touchesEnemyPort else { continue }
            if let path = NavySystem.findSeaPath(w, from: curLoc, to: sz), path.count < bestLen {
                bestLen = path.count
                bestSea = sz
            }
        }
        guard let targetSea = bestSea else { return false }
        return s.orderBlockadeFleet(fid, inSea: targetSea)
    }

    @discardableResult
    public func embarkArmyOnFleet(armyId: Int, fleetId: Int) -> Bool {
        guard let s = session else { return false }
        return s.embarkArmy(ArmyID(Int32(armyId)), onto: FleetID(fleetId))
    }

    @discardableResult
    public func disembarkArmyFromFleet(armyId: Int, provinceIndex: Int) -> Bool {
        guard let s = session else { return false }
        let dest: ProvinceID? = provinceIndex >= 0 ? ProvinceID(provinceIndex) : nil
        return s.disembarkArmy(ArmyID(Int32(armyId)), to: dest)
    }

    // MARK: - Helpers for Province Panel Dockyard & War Breakdown

    func buildableShipsList(for province: ProvinceID, world w: World, player: CountryID?) -> [[String: Any]] {
        guard let owner = w.provinces.owner[province.index], owner == player,
              w.dockCapacity(in: province) > 0 else {
            return []
        }
        return w.navy.shipTypes.enumerated().compactMap { idx, st in
            let unlocked = NavySystem.canBuildShip(w, owner, st.id)
            guard unlocked else { return nil }
            let refusal = NavySystem.buildShipRefusal(w, owner, in: province, type: st.id)
            let cost = Int(NavySystem.shipBuildCost(w, owner, in: province, type: st.id).rounded())
            let matsText = st.goods.isEmpty ? "None" : st.goods.map { g, amt in
                "\(String(format: "%.1f", amt)) \(w.economy.goods.name[g.index])"
            }.joined(separator: ", ")
            return [
                "shipTypeIndex": idx,
                "name": st.name,
                "shipClass": st.shipClass.rawValue.capitalized,
                "hull": Int(st.maxHull.rounded()),
                "cannons": st.cannons,
                "crew": st.maxCrew,
                "months": st.buildMonths,
                "cost": cost,
                "sailorsCost": st.maxCrew,
                "materialsText": matsText,
                "canBuild": refusal == nil,
                "refusalReason": refusal?.reason ?? ""
            ]
        }
    }

    private static func compactCount(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1fk", Double(n) / 1000.0) }
        return "\(n)"
    }
}
