import Foundation

/// Reasons why a country cannot embrace an institution right now.
public enum EmbraceRefusal: Error, Equatable, Sendable {
    case unknownInstitution
    case notSpawned
    case alreadyEmbraced
    case insufficientSpread(currentShare: Double, requiredShare: Double)
    case cannotAfford(cost: Double)

    public var reason: String {
        switch self {
        case .unknownInstitution:
            return "Unknown institution"
        case .notSpawned:
            return "Institution has not appeared yet"
        case .alreadyEmbraced:
            return "Already embraced"
        case .insufficientSpread(let cur, let req):
            return String(format: "Needs %.0f%% spread (currently %.0f%%)", req * 100, cur * 100)
        case .cannotAfford(let cost):
            return String(format: "Costs %.0f ducats", cost)
        }
    }
}

/// Phase 13 Part C: historical institution spawning, monthly spread (neighbours,
/// active trade routes, literate burgher pops & learning buildings), and embracing.
public enum InstitutionSystem {

    // MARK: - Embrace Queries & Action

    /// Weighted share (0...1) of `country`'s development reached by institution `index`.
    public static func spreadShare(_ world: World, for country: CountryID, institution index: Int) -> Double {
        guard index >= 0, index < world.tech.institutionCount else { return 0 }
        var totalDev = 0.0
        var presentDev = 0.0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            let dev = Double(max(1, world.provinces.development[p]))
            totalDev += dev
            let pres = world.tech.provincePresence(ProvinceID(p), institution: index)
            if pres >= 1.0 - 1e-6 {
                presentDev += dev
            } else if pres >= 0.50 {
                presentDev += dev * pres * 0.5
            }
        }
        guard totalDev > 0 else { return 0 }
        return min(1.0, presentDev / totalDev)
    }

    /// Ducat cost for `country` to embrace institution `index` right now.
    public static func embraceCost(_ world: World, for country: CountryID, institution index: Int) -> Double {
        let params = world.techRules.params
        let totalDev = Double(max(1, world.totalDevelopment(of: country)))
        let share = spreadShare(world, for: country, institution: index)
        return max(params.embraceMinCost, ((1.0 - share) * totalDev * params.embraceDucatsPerDev).rounded())
    }

    /// Returns `nil` if `country` can embrace institution `index`, else the refusal reason.
    public static func embraceRefusal(
        _ world: World,
        for country: CountryID,
        institution index: Int,
        checkMoney: Bool = true
    ) -> EmbraceRefusal? {
        guard index >= 0, index < world.techRules.institutions.count else { return .unknownInstitution }
        guard world.tech.institutionSpawned[index] else { return .notSpawned }
        guard !world.tech.hasEmbraced(country, institution: index) else { return .alreadyEmbraced }

        let share = spreadShare(world, for: country, institution: index)
        let req = world.techRules.params.embraceMinDevShare
        if share < req {
            return .insufficientSpread(currentShare: share, requiredShare: req)
        }
        let cost = embraceCost(world, for: country, institution: index)
        if checkMoney && world.countries.treasury[country.index] < cost {
            return .cannotAfford(cost: cost)
        }
        return nil
    }

    /// Pays the embrace cost and unlocks the institution for `country`.
    @discardableResult
    public static func embrace(
        _ world: inout World,
        _ country: CountryID,
        institution index: Int,
        date: GameDate
    ) -> EmbraceRefusal? {
        if let ref = embraceRefusal(world, for: country, institution: index) {
            return ref
        }
        let cost = embraceCost(world, for: country, institution: index)
        world.countries.treasury[country.index] -= cost
        world.tech.setEmbraced(country, institution: index, true)
        let instName = world.techRules.institutions[index].name
        let cname = world.countries.name[country.index]
        world.tech.addNote(TechNote(
            date: date,
            country: country,
            kind: .institutionEmbraced,
            institutionIndex: index,
            text: "\(cname) embraced \(instName)"
        ))
        return nil
    }

    // MARK: - Monthly Spawning, Spread & AI Embracing

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let I = world.techRules.institutions.count
        let P = world.provinces.count
        let C = world.countries.count
        guard I > 0, P > 0, C > 0, world.tech.institutionSpawned.count == I else { return }

        var rng = world.beginTechRandom(random)
        defer { world.endTechRandom(rng) }

        // 1. Spawn institutions whose year has arrived.
        for inst in world.techRules.institutions {
            let idx = inst.index
            guard !world.tech.institutionSpawned[idx], date.year >= inst.spawnYear else { continue }
            spawnInstitution(&world, inst: inst, date: date)
        }

        // 2. Precompute per-province burgher+clergy share and learning/press buildings in one pass.
        var popTotal = [Double](repeating: 0, count: P)
        var literatePop = [Double](repeating: 0, count: P)
        for k in 0..<world.pops.count {
            let p = world.pops.province[k].index
            guard p >= 0, p < P else { continue }
            let sz = world.pops.size[k]
            popTotal[p] += sz
            let cls = world.pops.socialClass[k]
            if cls == .burghers || cls == .clergy {
                literatePop[p] += sz
            }
        }
        var literacyFactor = [Double](repeating: 0.25, count: P)
        let eco = world.economy
        let colID = eco.buildingType(key: "college")
        let pressID = eco.buildingType(key: "bookmakers")
        let paperMillID = eco.buildingType(key: "paper_mill")
        for p in 0..<P {
            let burgherShare = popTotal[p] > 0 ? (literatePop[p] / popTotal[p]) : 0
            var f = min(2.0, burgherShare * 10.0) // 10% burgher+clergy -> 1.0x
            let pid = ProvinceID(p)
            if let c = colID { f += 0.35 * Double(eco.buildings.level(pid, c)) }
            if let pr = pressID { f += 0.30 * Double(eco.buildings.level(pid, pr)) }
            if let pm = paperMillID { f += 0.15 * Double(eco.buildings.level(pid, pm)) }
            let devBoost = Double(max(1, world.provinces.development[p])) / 6.0
            literacyFactor[p] = min(3.0, f * (0.6 + 0.4 * devBoost))
        }

        // 3. Precompute market books supply & active trade route links between market centres.
        let M = eco.markets.count
        let G = eco.goods.count
        var booksByMarket = [Double](repeating: 0, count: M)
        if M > 0, G > 0, let bi = eco.goods.id(forKey: "books")?.index {
            for m in 0..<M {
                let slot = m * G + bi
                if slot < eco.markets.supply.count && eco.markets.supply[slot] > 0 {
                    booksByMarket[m] = max(0, min(1, eco.markets.met[slot]))
                }
            }
        }
        // Adjacency list of active trade-route market partners (undirected for idea flow, weighted by volume).
        var tradePartners = [[(market: Int, weight: Double)]](repeating: [], count: M)
        for r in eco.routes where !r.path.isEmpty {
            let mFrom = r.from.index
            let mTo = r.to.index
            guard mFrom >= 0, mFrom < M, mTo >= 0, mTo < M, mFrom != mTo else { continue }
            let w = min(2.0, max(0.35, r.volume / 30.0))
            tradePartners[mFrom].append((mTo, w))
            tradePartners[mTo].append((mFrom, w))
        }

        // 4. Spread each spawned institution across provinces.
        for inst in world.techRules.institutions {
            let idx = inst.index
            guard world.tech.institutionSpawned[idx] else { continue }

            // Snapshot current presence at start of month so spread is order-independent.
            var cur = [Double](repeating: 0, count: P)
            for p in 0..<P {
                cur[p] = world.tech.presence[p * I + idx]
            }

            // Market centre max presence from trade partners.
            var tradeBoostByMarket = [Double](repeating: 0, count: M)
            for m in 0..<M {
                let centreProv = eco.markets.centre[m].index
                guard centreProv >= 0, centreProv < P else { continue }
                let centrePres = cur[centreProv]
                guard centrePres >= 0.40 else { continue }
                for (partner, weight) in tradePartners[m] {
                    let boost = inst.spreadTrade * centrePres * weight
                    if boost > tradeBoostByMarket[partner] {
                        tradeBoostByMarket[partner] = boost
                    }
                }
            }

            for p in 0..<P {
                let old = cur[p]
                if old >= 1.0 { continue }

                var gain = 0.0
                let owner = world.provinces.owner[p]

                // 4a. Neighbour spread (land borders + straits)
                var maxNb = 0.0
                var hostileBorder = true
                for nb in world.provinces.neighbors[p] {
                    let np = nb.index
                    if cur[np] > maxNb { maxNb = cur[np] }
                    if let o1 = owner, let o2 = world.provinces.owner[np] {
                        if o1 == o2 || !world.diplomacy.isAtWar(o1, o2) {
                            hostileBorder = false
                        }
                    } else {
                        hostileBorder = false
                    }
                }
                if maxNb >= 0.50 {
                    let borderMult = hostileBorder ? 0.5 : 1.0
                    gain += inst.spreadNeighbour * maxNb * borderMult
                }

                // 4b. Active trade-route spread into market centres & local market spillover
                let mIdx = (p < eco.provinceMarket.count) ? eco.provinceMarket[p].index : -1
                if mIdx >= 0 && mIdx < M {
                    if eco.markets.centre[mIdx].index == p {
                        gain += tradeBoostByMarket[mIdx]
                    } else {
                        let centrePres = cur[eco.markets.centre[mIdx].index]
                        if centrePres >= 0.75 {
                            gain += inst.spreadTrade * 0.35 * centrePres
                        }
                    }
                }

                // 4c. Literate burghers + books + local institutions (once province or neighbour has a spark)
                let ownerEmbraced = owner.map { world.tech.hasEmbraced($0, institution: idx) } ?? false
                if old > 0 || maxNb >= 0.25 || ownerEmbraced || gain > 0 {
                    let booksMult = (mIdx >= 0 && mIdx < M) ? (0.7 + 0.6 * booksByMarket[mIdx]) : 0.7
                    let embracedMult = ownerEmbraced ? 1.5 : 1.0
                    let dice = 0.85 + 0.30 * rng.unit()
                    gain += inst.spreadBurgher * literacyFactor[p] * booksMult * embracedMult * dice
                }

                if gain > 0 {
                    world.tech.setProvincePresence(ProvinceID(p), institution: idx, min(1.0, old + gain))
                }
            }
        }

        // 5. AI embraces affordable institutions when ready.
        for c in world.countries.ids where !world.humanCountries.contains(c) {
            let reserve = max(25.0, world.countries.lastMonthlyIncome[c.index] * 3.0)
            for inst in world.techRules.institutions {
                let idx = inst.index
                guard world.tech.institutionSpawned[idx], !world.tech.hasEmbraced(c, institution: idx) else { continue }
                if embraceRefusal(world, for: c, institution: idx, checkMoney: false) == nil {
                    let cost = embraceCost(world, for: c, institution: idx)
                    if world.countries.treasury[c.index] - cost >= reserve {
                        _ = embrace(&world, c, institution: idx, date: date)
                    }
                }
            }
        }
    }

    private static func spawnInstitution(_ world: inout World, inst: InstitutionDef, date: GameDate) {
        let P = world.provinces.count
        var originProv: ProvinceID?

        switch inst.origin {
        case .province(let pid):
            if pid.index >= 0 && pid.index < P {
                originProv = pid
            }
        case .region(let regName):
            var bestDev = -1
            for p in 0..<P where world.regionName(of: ProvinceID(p)) == regName {
                world.tech.setProvincePresence(ProvinceID(p), institution: inst.index, 1.0)
                if world.provinces.development[p] > bestDev {
                    bestDev = world.provinces.development[p]
                    originProv = ProvinceID(p)
                }
            }
        case .dynamic(let kind):
            originProv = pickDynamicOrigin(world, kind: kind)
        }

        world.tech.institutionSpawned[inst.index] = true
        world.tech.institutionSpawnYear[inst.index] = date.year
        world.tech.institutionOrigin[inst.index] = originProv

        if let pid = originProv {
            world.tech.setProvincePresence(pid, institution: inst.index, 1.0)
            let pname = world.provinces.name[pid.index]
            let owner = world.provinces.owner[pid.index]
            world.tech.addNote(TechNote(
                date: date,
                country: owner,
                kind: .institutionSpawned,
                institutionIndex: inst.index,
                province: pid,
                text: "\(inst.name) appeared in \(pname)"
            ))
        }
    }

    private static func pickDynamicOrigin(_ world: World, kind: String) -> ProvinceID? {
        let P = world.provinces.count
        let eco = world.economy
        if kind == "richest_port_market" {
            var routeScoreByMarket = [Double](repeating: 0, count: eco.markets.count)
            for r in eco.routes {
                let val = r.moved * eco.goods.basePrice[r.good.index]
                routeScoreByMarket[r.from.index] += val
                routeScoreByMarket[r.to.index] += val
            }
            var bestProv: ProvinceID?
            var bestScore = -1.0
            for m in 0..<eco.markets.count {
                let pid = eco.markets.centre[m]
                let p = pid.index
                guard p >= 0, p < P, world.hasSeaAccess(pid) else { continue }
                let score = routeScoreByMarket[m] + Double(world.provinces.development[p]) * 10.0
                if score > bestScore || (score == bestScore && bestProv.map { p < $0.index } ?? true) {
                    bestScore = score
                    bestProv = pid
                }
            }
            return bestProv ?? ProvinceID(0)
        } else {
            // top_workshops: highest workshop levels * development
            let T = eco.buildings.typeCount
            var bestProv: ProvinceID?
            var bestScore = -1.0
            for p in 0..<P where world.provinces.owner[p] != nil {
                var wLevels = 0
                for t in 0..<T {
                    if case .workshop = eco.buildingTypes[t].effect {
                        wLevels += eco.buildings.level[p * T + t]
                    }
                }
                let score = Double(wLevels) * Double(max(1, world.provinces.development[p]))
                if score > bestScore || (score == bestScore && bestProv.map { p < $0.index } ?? true) {
                    bestScore = score
                    bestProv = ProvinceID(p)
                }
            }
            return bestProv ?? ProvinceID(0)
        }
    }
}
