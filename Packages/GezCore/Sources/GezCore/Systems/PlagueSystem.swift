import Foundation

/// Why a quarantine or cordon cannot be ordered.
public enum PlagueRefusal: Equatable, Sendable {
    case notOwner
    case occupied
    case notAPort
    case noMoney

    public var reason: String {
        switch self {
        case .notOwner: return "This is not your province."
        case .occupied: return "The province is occupied."
        case .notAPort: return "Only provinces on the sea can quarantine their port."
        case .noMoney: return "The treasury cannot pay for it."
        }
    }
}

/// Plague, camp fever and smallpox (Phase 12 Part A). Once a month:
/// 1. fresh outbreaks start by chance in crowded towns, ports, sieges and camps
/// 2. running outbreaks kill people (the poor more) and soldiers, and try to
///    spread to neighbours, along trade routes, between ports and with armies
/// 3. immunity fades a little
/// 4. quarantines and cordons are paid for; the AI orders and lifts its own
public enum PlagueSystem {

    // MARK: - Player and AI actions

    public static func quarantineCost(_ world: World, _ province: ProvinceID) -> Double {
        PlagueModel.quarantineCost(development: world.provinces.development[province.index])
    }

    public static func cordonCost(_ world: World, _ province: ProvinceID) -> Double {
        PlagueModel.cordonCost(development: world.provinces.development[province.index])
    }

    public static func quarantineRefusal(_ world: World, _ country: CountryID, _ province: ProvinceID) -> PlagueRefusal? {
        let p = province.index
        guard p >= 0, p < world.provinces.count, world.provinces.owner[p] == country else { return .notOwner }
        if world.provinces.occupiedBy[p] != nil { return .occupied }
        if !world.hasSeaAccess(province) { return .notAPort }
        if world.countries.treasury[country.index] < quarantineCost(world, province) { return .noMoney }
        return nil
    }

    public static func cordonRefusal(_ world: World, _ country: CountryID, _ province: ProvinceID) -> PlagueRefusal? {
        let p = province.index
        guard p >= 0, p < world.provinces.count, world.provinces.owner[p] == country else { return .notOwner }
        if world.provinces.occupiedBy[p] != nil { return .occupied }
        if world.countries.treasury[country.index] < cordonCost(world, province) { return .noMoney }
        return nil
    }

    /// Orders or lifts a port quarantine. The first month is paid at once.
    @discardableResult
    public static func setQuarantine(_ world: inout World, _ country: CountryID, _ province: ProvinceID, on: Bool) -> PlagueRefusal? {
        world.calamity.resize(provinces: world.provinces.count)
        let p = province.index
        guard p >= 0, p < world.provinces.count, world.provinces.owner[p] == country else { return .notOwner }
        if !on {
            world.calamity.quarantine[p] = false
            return nil
        }
        if world.calamity.quarantine[p] { return nil }
        if let refusal = quarantineRefusal(world, country, province) { return refusal }
        world.countries.treasury[country.index] -= quarantineCost(world, province)
        world.calamity.quarantine[p] = true
        return nil
    }

    /// Orders or lifts a cordon around a province. The first month is paid at once.
    @discardableResult
    public static func setCordon(_ world: inout World, _ country: CountryID, _ province: ProvinceID, on: Bool) -> PlagueRefusal? {
        world.calamity.resize(provinces: world.provinces.count)
        let p = province.index
        guard p >= 0, p < world.provinces.count, world.provinces.owner[p] == country else { return .notOwner }
        if !on {
            world.calamity.cordon[p] = false
            return nil
        }
        if world.calamity.cordon[p] { return nil }
        if let refusal = cordonRefusal(world, country, province) { return refusal }
        world.countries.treasury[country.index] -= cordonCost(world, province)
        world.calamity.cordon[p] = true
        return nil
    }

    /// Starts an outbreak now (events, tests). `severity` 0…1 stands in for
    /// the dice (0.5 = an average outbreak). False if the province is
    /// already struck or too immune.
    @discardableResult
    public static func startOutbreak(
        _ world: inout World,
        in province: ProvinceID,
        disease: Disease,
        date: GameDate,
        severity: Double = 0.5,
        camp: Bool = false
    ) -> Bool {
        world.calamity.resize(provinces: world.provinces.count)
        return begin(&world, province.index, disease, date: date, roll: severity, camp: camp)
    }

    /// Share of people struck over an outbreak starting now (before the dice).
    public static func expectedAttack(_ world: World, _ p: Int, _ d: Disease, camp: Bool = false) -> Double {
        let susceptible = 1 - world.calamity.immunity(p, d)
        let crowd = camp ? 1.0 : PlagueModel.crowding(development: world.provinces.development[p])
        return PlagueModel.rule(d).attack * crowd * susceptible
    }

    private static func begin(_ world: inout World, _ p: Int, _ d: Disease, date: GameDate, roll: Double, camp: Bool) -> Bool {
        guard p >= 0, p < world.provinces.count, p < world.calamity.provinceCount else { return false }
        let k = world.calamity.slot(p, d)
        guard world.calamity.course[k] == 0, world.provinces.population[p] >= 500 else { return false }
        let susceptible = 1 - world.calamity.immunity[k]
        guard susceptible > PlagueModel.minSusceptible else { return false }
        let attack = expectedAttack(world, p, d, camp: camp) * (0.6 + 0.8 * min(1, max(0, roll)))
        world.calamity.attack[k] = min(PlagueModel.maxAttack, attack)
        world.calamity.course[k] = 1
        let name = world.provinces.name[p]
        let text = "\(d.displayName) breaks out in \(name)."
        world.calamity.addNote(CalamityNote(date: date, province: ProvinceID(p), kind: d.key, text: text))
        // The court chronicle is short: only capitals and great towns make it.
        if let owner = world.provinces.owner[p],
           world.countries.capital[owner.index] == ProvinceID(p) || world.provinces.development[p] >= 8 {
            world.people.record(date, owner, text)
        }
        return true
    }

    // MARK: - Monthly tick

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        guard P > 0 else { return }
        world.calamity.resize(provinces: P)
        if !world.calamity.seeded {
            // Reading the state does not use up any of the game's numbers.
            world.calamity.rngState = random.rawState ^ 0x5DEE_CE66_D1CE_4E5B
            world.calamity.seeded = true
        }
        var rng = GameRandom(seed: world.calamity.rngState)
        defer { world.calamity.rngState = rng.rawState }

        let D = CalamityState.diseaseCount
        let diseases = Disease.allCases
        let rules = diseases.map { PlagueModel.rule($0) }

        // Lookups built once.
        var underSiege = Array(repeating: false, count: P)
        for s in world.military.sieges where s.province.index < P { underSiege[s.province.index] = true }
        let armiesHere = world.military.armyIndexByProvince(provinceCount: P)
        var soldiers = Array(repeating: 0, count: P)
        for p in 0..<P where !armiesHere[p].isEmpty {
            for a in armiesHere[p] { soldiers[p] += world.military.armies.totalMen(of: a) }
        }
        let portType = world.economy.buildingType(key: "port")
        var hasSea = Array(repeating: false, count: P)
        for p in 0..<P { hasSea[p] = world.hasSeaAccess(ProvinceID(p)) && p < world.provinceSeas.count && !world.provinceSeas[p].isEmpty }

        // Markets joined by a running trade route, with whether the step is by sea.
        let M = world.economy.markets.count
        var centreMarket = Array(repeating: -1, count: P)
        for m in 0..<M {
            let c = world.economy.markets.centre[m].index
            if c < P { centreMarket[c] = m }
        }
        var partners = Array(repeating: [Int](), count: M)      // other market * 2 + (sea ? 1 : 0)
        for r in world.economy.routes where r.path.count > 1 {
            for s in 1..<r.path.count {
                let a = r.path[s - 1], b = r.path[s]
                guard a.index < M, b.index < M, a != b else { continue }
                let sea = world.isSeaStep(a, b) ? 1 : 0
                if !partners[a.index].contains(b.index * 2 + sea) { partners[a.index].append(b.index * 2 + sea) }
                if !partners[b.index].contains(a.index * 2 + sea) { partners[b.index].append(a.index * 2 + sea) }
            }
        }

        var seeds: [(province: Int, disease: Int, camp: Bool)] = []
        var dirty: [Int] = []
        world.calamity.lastDeaths = Array(repeating: 0, count: P)

        // 1. Fresh outbreaks.
        for p in 0..<P where world.provinces.population[p] >= 500 {
            let dev = world.provinces.development[p]
            let crowded = dev >= PlagueModel.crowdedDevelopment || (hasSea[p] && dev >= PlagueModel.crowdedCoastDevelopment)
            if crowded {
                for d in 0..<D where rules[d].originChance > 0 && world.calamity.course[p * D + d] == 0 {
                    if rng.unit() < rules[d].originChance * Double(dev) / 7 {
                        seeds.append((p, d, false))
                    }
                }
            }
            let t = Disease.typhus.rawValue
            if world.calamity.course[p * D + t] == 0 {
                var chance = 0.0
                var camp = false
                if underSiege[p] { chance += PlagueModel.typhusSiegeChance; camp = true }
                if soldiers[p] >= PlagueModel.typhusCampSoldiers { chance += PlagueModel.typhusCampChance; camp = true }
                if world.provinces.famine[p] > PlagueModel.typhusFamineAbove { chance += PlagueModel.typhusFamineChance }
                if chance > 0 && rng.unit() < chance { seeds.append((p, t, camp)) }
            }
        }

        // 2. Running outbreaks: spread, then deaths.
        for p in 0..<P {
            for d in 0..<D where world.calamity.course[p * D + d] > 0 {
                let k = p * D + d
                let rule = rules[d]
                let share = world.calamity.attack[k] * PlagueModel.courseWeight(months: rule.months, month: world.calamity.course[k] - 1)

                // To the neighbours, by road.
                let landBase = min(PlagueModel.neighbourSpreadCap, PlagueModel.neighbourSpread * share)
                    * (d == Disease.typhus.rawValue ? PlagueModel.typhusNeighbourFactor : 1)
                for n in world.provinces.neighbors[p] {
                    let q = n.index
                    var chance = landBase * (0.5 + 0.07 * Double(world.provinces.development[q]))
                    if world.calamity.cordon[p] || world.calamity.cordon[q] { chance *= PlagueModel.cordonLeak }
                    if rng.unit() < chance { seeds.append((q, d, false)) }
                }
                // Along trade routes, from market town to market town.
                let m = centreMarket[p]
                if m >= 0 && !partners[m].isEmpty && rng.unit() < min(PlagueModel.routeSpreadCap, PlagueModel.routeSpread * share) {
                    let pick = partners[m][Int(rng.next() % UInt64(partners[m].count))]
                    let q = world.economy.markets.centre[pick / 2].index
                    let bySea = pick % 2 == 1
                    let blocked = bySea && (world.calamity.quarantine[p] || (q < P && world.calamity.quarantine[q]))
                    if q < P && (!blocked || rng.unit() < PlagueModel.quarantineLeak) { seeds.append((q, d, false)) }
                }
                // From port to port across the same sea.
                if hasSea[p] {
                    let ports = portType.map { Double(world.economy.buildings.level(ProvinceID(p), $0)) } ?? 0
                    let chance = min(PlagueModel.seaSpreadCap, PlagueModel.seaSpread * share) * (1 + 0.25 * ports)
                    if rng.unit() < chance {
                        let zones = world.provinceSeas[p]
                        let z = zones[Int(rng.next() % UInt64(zones.count))].index
                        let coast = z < world.seaZones.count ? world.seaZones.coast[z] : []
                        if !coast.isEmpty {
                            let q = coast[Int(rng.next() % UInt64(coast.count))].index
                            let blocked = world.calamity.quarantine[p] || (q < P && world.calamity.quarantine[q])
                            if q < P && q != p && (!blocked || rng.unit() < PlagueModel.quarantineLeak) { seeds.append((q, d, false)) }
                        }
                    }
                }

                // The dead, by class.
                var dead = 0.0
                for i in world.pops.range(for: ProvinceID(p)) {
                    let size = world.pops.size[i]
                    guard size > 0 else { continue }
                    let rate = min(0.5, share * rule.lethality * PlagueModel.classLethality(world.pops.socialClass[i]))
                    let lost = size * rate
                    world.pops.size[i] = size - lost
                    world.pops.satisfaction[i] = max(0, world.pops.satisfaction[i] - min(0.08, share * 0.6))
                    dead += lost
                }
                world.calamity.lastDeaths[p] += dead
                world.calamity.totalDeaths[d] += dead
                if dead > 0 { dirty.append(p) }

                // Soldiers and the garrison die too, and the armies carry it away.
                let campRate = min(0.25, share * rule.lethality * PlagueModel.campLethality)
                for aid in armiesHere[p] {
                    let a = Int(aid.rawValue)
                    guard world.military.armies.alive[a] else { continue }
                    // Never the last man: an army is only removed by its own systems.
                    for r in world.military.armies.regiments[a].indices {
                        let men = world.military.armies.regiments[a][r].men
                        let lost = min(max(0, men - 1), Int((Double(men) * campRate).rounded()))
                        world.military.armies.regiments[a][r].men = men - lost
                    }
                    markCarrier(&world.calamity, army: a, disease: d)
                }
                let garrison = world.provinces.fortGarrison[p]
                if garrison > 0 {
                    world.provinces.fortGarrison[p] = max(0, garrison - Int((Double(garrison) * campRate).rounded()))
                }

                // Next month, or the end.
                world.calamity.course[k] += 1
                if world.calamity.course[k] > rule.months {
                    world.calamity.course[k] = 0
                    world.calamity.attack[k] = 0
                    world.calamity.immunity[k] = max(world.calamity.immunity[k], PlagueModel.immunityAfter)
                }
            }
        }

        // 3. Armies that marched on bring it with them.
        var keepArmy: [Int] = [], keepDisease: [Int] = [], keepMonths: [Int] = []
        for c in world.calamity.carrierArmy.indices {
            let a = world.calamity.carrierArmy[c]
            let d = world.calamity.carrierDisease[c]
            let left = world.calamity.carrierMonthsLeft[c] - 1
            guard a >= 0, a < world.military.armies.count, world.military.armies.alive[a], d >= 0, d < D else { continue }
            if world.military.armies.embarkedOnFleet[a] == nil {
                let q = world.military.armies.province[a].index
                if q < P && world.calamity.course[q * D + d] == 0 && rng.unit() < PlagueModel.carrierSpreadChance {
                    seeds.append((q, d, true))
                }
            }
            if left > 0 {
                keepArmy.append(a)
                keepDisease.append(d)
                keepMonths.append(left)
            }
        }
        world.calamity.carrierArmy = keepArmy
        world.calamity.carrierDisease = keepDisease
        world.calamity.carrierMonthsLeft = keepMonths

        // 4. Immunity fades (children are born who never met the sickness).
        for d in 0..<D {
            let keep = 1 - rules[d].immunityFade
            var k = d
            while k < world.calamity.immunity.count {
                world.calamity.immunity[k] *= keep
                k += D
            }
        }

        // 5. New outbreaks take hold where the people can still catch it.
        for s in seeds {
            _ = begin(&world, s.province, diseases[s.disease], date: date, roll: rng.unit(), camp: s.camp)
        }

        if !dirty.isEmpty { world.refreshProvinceSummaries(for: dirty) }

        courtDeaths(&world, date: date, rng: &rng)
        payAndRunAI(&world, hasSea: hasSea)
    }

    private static func markCarrier(_ state: inout CalamityState, army: Int, disease: Int) {
        for c in state.carrierArmy.indices where state.carrierArmy[c] == army && state.carrierDisease[c] == disease {
            state.carrierMonthsLeft[c] = PlagueModel.carrierMonths
            return
        }
        state.carrierArmy.append(army)
        state.carrierDisease.append(disease)
        state.carrierMonthsLeft.append(PlagueModel.carrierMonths)
    }

    /// Plague and smallpox in a capital can carry off rulers and courtiers.
    private static func courtDeaths(_ world: inout World, date: GameDate, rng: inout GameRandom) {
        let C = world.countries.count
        var risk = Array(repeating: 0.0, count: C)
        var cause = Array(repeating: Disease.plague, count: C)
        var any = false
        for c in 0..<C {
            guard let capital = world.countries.capital[c], world.provinces.owner[capital.index] == CountryID(c) else { continue }
            for d in [Disease.plague, Disease.smallpox] {
                let share = world.calamity.infection(capital.index, d)
                if share > risk[c] {
                    risk[c] = share
                    cause[c] = d
                    any = true
                }
            }
        }
        guard any else { return }
        var victims: [(CharacterID, Int)] = []
        let ch = world.people.characters
        for i in 0..<ch.count where ch.death[i] == nil {
            guard let court = ch.court[i], court.index < C, risk[court.index] > 0 else { continue }
            let old = ch.age(CharacterID(i), on: date) >= 50
            if rng.unit() < risk[court.index] * PlagueModel.courtDeathFactor * (old ? 2 : 1) {
                victims.append((CharacterID(i), court.index))
            }
        }
        for (x, c) in victims where world.people.characters.isAlive(x) {
            let name = world.people.characters.fullName(x)
            let wasRuler = world.countries.ruler[c] == x
            CharacterSystem.kill(&world, x, date: date, random: &rng)
            if wasRuler || world.humanCountries.contains(CountryID(c)) {
                world.people.record(date, CountryID(c), "\(name) dies of \(cause[c].displayName.lowercased()).")
            }
        }
    }

    /// Quarantines and cordons cost money every month; the AI orders its own
    /// where plague is near and lifts them when the danger has passed.
    private static func payAndRunAI(_ world: inout World, hasSea: [Bool]) {
        let P = world.provinces.count
        let C = world.countries.count
        let plague = Disease.plague

        // Seas with plague on their shores.
        var seaStruck = Array(repeating: false, count: world.seaZones.count)
        for p in 0..<P where hasSea[p] && world.calamity.hasOutbreak(p, plague) {
            for z in world.provinceSeas[p] where z.index < seaStruck.count { seaStruck[z.index] = true }
        }

        var cordons = Array(repeating: 0, count: C)
        for p in 0..<P {
            guard let owner = world.provinces.owner[p], world.provinces.occupiedBy[p] == nil else {
                // Lost or occupied land: the guards go home.
                world.calamity.quarantine[p] = false
                world.calamity.cordon[p] = false
                continue
            }
            let o = owner.index
            let human = world.humanCountries.contains(owner)
            let struck = world.calamity.hasOutbreak(p, plague)
            let threatened = hasSea[p] && world.provinceSeas[p].contains { $0.index < seaStruck.count && seaStruck[$0.index] }
            let rich = world.countries.treasury[o] > 40
                && world.countries.lastMonthlyIncome[o] - world.countries.lastMonthlyExpenses[o] > 1

            if !human {
                // Quarantine a good port while plague is on its sea; lift it afterwards.
                if world.calamity.quarantine[p] {
                    if !threatened || struck || !rich { world.calamity.quarantine[p] = false }
                } else if threatened && !struck && rich && world.provinces.development[p] >= 6 {
                    world.calamity.quarantine[p] = true
                }
                // Cordon a struck province (a few at most) until the plague has gone.
                if world.calamity.cordon[p] {
                    if !struck || !rich { world.calamity.cordon[p] = false }
                } else if struck && rich && cordons[o] < 3 && world.calamity.course[world.calamity.slot(p, plague)] <= 3 {
                    world.calamity.cordon[p] = true
                }
            }
            if world.calamity.cordon[p] { cordons[o] += 1 }

            var cost = 0.0
            if world.calamity.quarantine[p] { cost += PlagueModel.quarantineCost(development: world.provinces.development[p]) }
            if world.calamity.cordon[p] { cost += PlagueModel.cordonCost(development: world.provinces.development[p]) }
            if cost > 0 {
                world.countries.treasury[o] -= cost
                world.countries.lastMonthlyExpenses[o] += cost
            }
        }
    }
}
