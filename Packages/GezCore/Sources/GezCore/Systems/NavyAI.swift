import Foundation

extension NavySystem {

    // MARK: - Fleet AI (Part B)

    /// Evaluates AI fleet missions monthly (or after war changes):
    /// 1. Repairs damaged / low-supply fleets in nearest friendly port.
    /// 2. At war: hunts weaker enemy fleets in reach and blockades enemy ports.
    /// 3. At peace: recalls blockade/hunt fleets home and patrols home waters with light ships.
    public static func runAI(_ world: inout World) {
        for c in world.countries.ids where !world.humanCountries.contains(c) {
            let aliveFleets = world.navy.fleets(of: c)
            guard !aliveFleets.isEmpty else { continue }

            // Compute live owned friendly coastal ports.
            let friendlyPorts = world.provinces(ownedBy: c).filter {
                world.hasSeaAccess($0) && world.provinces.controller(of: $0) == c
            }
            guard !friendlyPorts.isEmpty else { continue }

            // Sort ports preferring Shipyard / capital first for repairs & home stationing.
            let sortedPorts = friendlyPorts.sorted { a, b in
                let da = world.dockCapacity(in: a), db = world.dockCapacity(in: b)
                if da != db { return da > db }
                return a.index < b.index
            }
            let mainPort = sortedPorts[0]

            // Enemies in active wars.
            var enemies = Set<CountryID>()
            for war in world.diplomacy.wars {
                if war.isAttacker(c) {
                    enemies.formUnion(war.defenders)
                } else if war.isDefender(c) {
                    enemies.formUnion(war.attackers)
                }
            }
            let atWar = !enemies.isEmpty

            for fid in aliveFleets {
                let i = fid.index
                if world.navy.fleets.battle[i] != nil { continue }
                if !world.navy.fleets.embarkedArmies[i].isEmpty { continue }

                // Skip fleets already moving on an ordered path unless critically damaged.
                let avgHull = fleetAverageHull(world, fid)
                let supply = world.navy.fleets.supply[i]
                if avgHull < 65.0 || supply < 30.0 {
                    world.navy.fleets.mission[i] = .idle
                    let nearPort = nearestFriendlyPort(world, from: world.navy.fleets.location[i], ports: sortedPorts) ?? mainPort
                    if world.navy.fleets.location[i] != .port(nearPort) && world.navy.fleets.destinationPort[i] == nil {
                        _ = orderDockFleet(&world, fid, inPort: nearPort)
                    }
                    continue
                }

                // Assign an admiral if fleet has >= 3 ships and no admiral yet.
                if world.navy.fleets.admiral[i] == nil && world.navy.shipCount(of: fid) >= 3 {
                    // Quick pick from unused living male courtier/ruler excluded? Prefer non-ruler figure/marshal.
                    let cands = world.people.characters.ids.filter { cid in
                        world.people.characters.court[cid.index] == c
                            && world.people.characters.isAlive(cid)
                            && !world.people.characters.female[cid.index]
                            && world.countries.ruler[c.index] != cid
                            && !(0..<world.navy.fleets.count).contains {
                                world.navy.fleets.alive[$0] && world.navy.fleets.admiral[$0] == cid
                            }
                    }.sorted {
                        world.people.characters.skill($0, .martial) > world.people.characters.skill($1, .martial)
                    }
                    if let pick = cands.first {
                        assignAdmiral(&world, fleet: fid, admiral: pick)
                    }
                }

                if atWar {
                    // Don't interrupt an already sailing war fleet.
                    if !world.navy.fleets.path[i].isEmpty || world.navy.fleets.destinationPort[i] != nil {
                        continue
                    }

                    let ourScore = fleetStrength(world, fid)
                    // 1. Look for a weaker enemy fleet at sea within supply reach to hunt.
                    var huntTarget: SeaZoneID?
                    var bestEnemyScore = 0.0
                    for enemy in enemies.sorted(by: { $0.index < $1.index }) {
                        for efid in world.navy.fleets(of: enemy) {
                            guard case .sea(let eSea) = world.navy.fleets.location[efid.index] else { continue }
                            guard seaSupplyHops(world, from: eSea, for: c) <= NavyModel.supplyRangeHops + 2 else { continue }
                            let eScore = fleetStrength(world, efid, in: eSea)
                            if ourScore >= eScore * 1.15 && eScore > bestEnemyScore {
                                bestEnemyScore = eScore
                                huntTarget = eSea
                            }
                        }
                    }
                    if let targetSea = huntTarget {
                        world.navy.fleets.mission[i] = .hunt
                        if world.navy.fleets.location[i] != .sea(targetSea) {
                            _ = orderMoveFleet(&world, fid, toSea: targetSea)
                        }
                        continue
                    }

                    // 2. Look for an enemy coastal province sea zone to blockade (especially besieged ports).
                    var blockadeSea: SeaZoneID?
                    var bestPortPriority = -1
                    for enemy in enemies.sorted(by: { $0.index < $1.index }) {
                        for p in world.provinces(ownedBy: enemy) where world.hasSeaAccess(p) {
                            let priority = (world.military.siege(in: p) != nil ? 10 : 1)
                                + (world.dockCapacity(in: p) > 0 ? 3 : 0)
                            if priority > bestPortPriority, let adjSea = world.provinceSeas[p.index].first {
                                guard seaSupplyHops(world, from: adjSea, for: c) <= NavyModel.supplyRangeHops + 2 else { continue }
                                // Skip if a stronger enemy fleet sits in that sea zone.
                                let hostilesInSea = world.navy.fleets(inSea: adjSea).filter {
                                    enemies.contains(world.navy.fleets.owner[$0.index])
                                }
                                let hostileStr = hostilesInSea.reduce(0.0) { $0 + fleetStrength(world, $1, in: adjSea) }
                                if hostileStr == 0 || ourScore > hostileStr * 1.15 {
                                    bestPortPriority = priority
                                    blockadeSea = adjSea
                                }
                            }
                        }
                    }
                    if let bSea = blockadeSea {
                        world.navy.fleets.mission[i] = .blockade
                        if world.navy.fleets.location[i] != .sea(bSea) {
                            _ = orderMoveFleet(&world, fid, toSea: bSea)
                        }
                        continue
                    }
                } else {
                    // At peace: keep fleets repaired/supplied in friendly ports; light ships may patrol home waters.
                    if world.navy.fleets.mission[i] == .hunt || world.navy.fleets.mission[i] == .blockade {
                        world.navy.fleets.mission[i] = .idle
                    }
                    let hasMostlyLight = world.navy.fleets.shipIndices[i].contains { sIdx in
                        world.navy.ships.alive[sIdx] && world.navy.shipType(world.navy.ships.type[sIdx]).shipClass == .light
                    }
                    let shipCount = world.navy.shipCount(of: fid)
                    if hasMostlyLight && shipCount <= 6 && avgHull >= 90.0,
                       let homeSea = world.provinceSeas[mainPort.index].first {
                        world.navy.fleets.mission[i] = .patrol
                        if world.navy.fleets.location[i] != .sea(homeSea) && world.navy.fleets.path[i].isEmpty {
                            _ = orderMoveFleet(&world, fid, toSea: homeSea)
                        }
                    } else if case .sea = world.navy.fleets.location[i],
                              world.navy.fleets.destinationPort[i] == nil {
                        _ = orderDockFleet(&world, fid, inPort: mainPort)
                    }
                }
            }
        }
    }

    private static func nearestFriendlyPort(_ world: World, from loc: FleetLocation, ports: [ProvinceID]) -> ProvinceID? {
        guard !ports.isEmpty else { return nil }
        let refSea: SeaZoneID?
        switch loc {
        case .sea(let s): refSea = s
        case .port(let p):
            if ports.contains(p) { return p }
            refSea = world.provinceSeas[p.index].first
        }
        guard let originSea = refSea else { return ports.first }
        var best: ProvinceID?
        var bestDist = Double.infinity
        for p in ports {
            for sz in world.provinceSeas[p.index] {
                let d = seaDistance(world, from: originSea, to: sz)
                if d < bestDist {
                    bestDist = d
                    best = p
                }
            }
        }
        return best
    }
}
