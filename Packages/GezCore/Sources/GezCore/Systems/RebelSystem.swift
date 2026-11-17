import Foundation

/// Rebel factions (Phase 12 Part C). Each country can have one faction of
/// each kind: Peasant Rebels, Religious Zealots, Cultural Separatists,
/// Estate Rebels and a Pretender. Once a month:
/// 1. risen factions fight any crown army standing on them; if they hold
///    the field long enough they enforce their demand
/// 2. every faction's progress moves with its grievance; at 100% it raises
///    a real army from its own people (who leave the pops, like levies)
/// 3. computer countries answer: lower taxes, concessions, or troops
public enum RebelSystem {

    // MARK: - Names and demands (for the screens)

    public static func name(_ world: World, _ f: RebelFaction) -> String {
        switch f.kind {
        case .peasants:
            return "Peasant Rebels"
        case .zealots:
            return "\(f.religion?.displayName ?? "Religious") Zealots"
        case .separatists:
            let culture = f.culture.flatMap { $0.index < world.cultures.count ? world.cultures.name[$0.index] : nil }
            return "\(culture ?? "Cultural") Separatists"
        case .nobles:
            let estate = f.estate.flatMap { $0 < world.government.rules.estates.count ? world.government.rules.estates[$0].name : nil }
            return "\(estate ?? "Estate") Rebels"
        case .pretender:
            let who = f.pretender.map { world.people.characters.fullName($0) }
            return who.map { "Pretender \($0)" } ?? "Pretender"
        }
    }

    /// What they will force on the realm if they win.
    public static func demand(_ world: World, _ f: RebelFaction) -> String {
        switch f.kind {
        case .peasants:
            return "Halve the taxes on peasants for five years."
        case .zealots:
            let faith = f.religion?.displayName ?? "their"
            if let r = f.religion, faithShare(world, f.country, r) >= UnrestModel.stateFaithShare {
                return "Make the \(faith) faith the religion of the state."
            }
            return "Freedom for the \(faith) faith: no missionaries, a tolerant law."
        case .separatists:
            switch breakaway(world, f) {
            case .country(let target, _):
                return "Independence: their lands go to \(world.countries.name[target.index])."
            case .acceptance:
                return "Their culture is accepted in the realm."
            }
        case .nobles:
            if let p = wantedPrivilege(world, f) {
                return "The privilege \"\(world.government.rules.privileges[p].name)\"."
            }
            return "Three months of the crown's income."
        case .pretender:
            return "The throne."
        }
    }

    /// What a peaceful concession gives them instead.
    public static func concession(_ world: World, _ f: RebelFaction) -> String {
        switch f.kind {
        case .peasants:
            return "Cut the taxes on peasants by a quarter for three years."
        case .zealots:
            return "Recall the missionaries and let them worship in peace."
        case .separatists:
            return "Accept their culture in the realm."
        case .nobles:
            if let p = wantedPrivilege(world, f) {
                return "Grant \"\(world.government.rules.privileges[p].name)\"."
            }
            return "Pay them two months of income."
        case .pretender:
            return "Buy off the pretender (\(Int(payoff(world, f.country).rounded())) ducats)."
        }
    }

    /// Months until victory if nobody beats them (nil = not risen).
    public static func monthsToVictory(_ f: RebelFaction) -> Int? {
        guard f.risen else { return nil }
        let need = f.victories > 0 ? UnrestModel.monthsToWinAfterVictory : UnrestModel.monthsToWin
        return max(0, need - f.monthsInField)
    }

    public static func men(_ world: World, _ f: RebelFaction) -> Int {
        var sum = 0
        for a in f.armies where a >= 0 && a < world.military.armies.count && world.military.armies.alive[a] {
            sum += world.military.armies.totalMen(of: ArmyID(Int32(a)))
        }
        return sum
    }

    /// How many would take up arms if the faction rose now.
    public static func expectedMen(_ world: World, _ f: RebelFaction) -> Int {
        musterPlan(world, f).reduce(0) { $0 + $1.men }
    }

    static func payoff(_ world: World, _ c: CountryID) -> Double {
        max(50, world.countries.lastMonthlyIncome[c.index] * UnrestModel.pretenderPayoffMonths)
    }

    // MARK: - Player and AI answers

    /// Give the faction a milder form of what it wants; it disbands at once.
    @discardableResult
    public static func concede(_ world: inout World, _ country: CountryID, faction id: Int, date: GameDate) -> RebelRefusal? {
        guard let f = world.unrest.faction(id: id), f.country == country else { return .noSuchFaction }
        let c = country.index
        world.unrest.resize(provinces: world.provinces.count, countries: world.countries.count)
        switch f.kind {
        case .peasants:
            capPeasantTax(&world, country, UnrestModel.concededPeasantTax, months: UnrestModel.concededTaxMonths)
        case .zealots:
            tolerate(&world, f, unrestFactor: 0.5)
        case .separatists:
            if let k = f.culture { world.countries.acceptedCultures[c].insert(k) }
        case .nobles:
            if let p = wantedPrivilege(world, f) {
                world.government.privileges[c].insert(p)
                GovernmentSystem.refreshEffects(&world, country)
            } else {
                let cost = max(20, world.countries.lastMonthlyIncome[c] * 2)
                guard world.countries.treasury[c] >= cost else { return .noMoney }
                world.countries.treasury[c] -= cost
            }
        case .pretender:
            let cost = payoff(world, country)
            guard world.countries.treasury[c] >= cost else { return .noMoney }
            world.countries.treasury[c] -= cost
            if let x = f.pretender { world.people.characters.gold[x.index] += cost }
        }
        world.countries.prestige[c] = max(-100, world.countries.prestige[c] - UnrestModel.concessionPrestige)
        world.people.record(date, country, "The crown gives way to the \(name(world, f)).")
        world.unrest.concessions += 1
        end(&world, id: id, calm: 8, quiet: UnrestModel.quietMonthsAfterConcession, casualties: 0)
        return nil
    }

    /// March the strongest free army to the rebels (or to where they brew).
    @discardableResult
    public static func sendTroops(_ world: inout World, _ country: CountryID, faction id: Int) -> RebelRefusal? {
        guard let f = world.unrest.faction(id: id), f.country == country else { return .noSuchFaction }
        guard let target = Self.target(world, f) else { return .nothingToDo }
        var best: ArmyID?
        var bestMen = 0
        for aid in world.military.armies(of: country) {
            let a = Int(aid.rawValue)
            guard world.military.armies.embarkedOnFleet[a] == nil, !world.military.isInBattle(aid),
                  world.military.armies.province[a] != target,
                  world.military.armies.path[a].last != target else { continue }
            let men = world.military.armies.totalMen(of: aid)
            if men > bestMen {
                best = aid
                bestMen = men
            }
        }
        guard let army = best else {
            // Already there or already marching counts as done.
            let onTheWay = world.military.armies(of: country).contains {
                let a = Int($0.rawValue)
                return world.military.armies.province[a] == target || world.military.armies.path[a].last == target
            }
            return onTheWay ? .nothingToDo : .noArmy
        }
        return ArmySystem.orderMove(&world, army: army, to: target) ? nil : .noArmy
    }

    /// Cut the tax on peasants by a quarter of the normal rate.
    @discardableResult
    public static func lowerTaxes(_ world: inout World, _ country: CountryID) -> RebelRefusal? {
        let k = TaxClass.peasants.rawValue
        let level = world.countries.taxLevel[country.index][k]
        guard level > 0 else { return .nothingToDo }
        world.countries.taxLevel[country.index][k] = max(0, level - 0.25)
        return nil
    }

    /// Where the faction stands (its army) or brews (its angriest province).
    public static func target(_ world: World, _ f: RebelFaction) -> ProvinceID? {
        for a in f.armies where a >= 0 && a < world.military.armies.count && world.military.armies.alive[a] {
            return world.military.armies.province[a]
        }
        return f.provinces.first
    }

    // MARK: - Monthly tick

    static func runMonthly(
        _ world: inout World,
        date: GameDate,
        random: inout GameRandom,
        points: [Double],
        context ctx: UnrestContext
    ) {
        let P = world.provinces.count
        let C = world.countries.count
        var rng = world.beginCalamityRandom(random)
        defer { world.endCalamityRandom(rng) }

        var owned = Array(repeating: [Int](), count: C)
        for p in 0..<P {
            if let o = world.provinces.owner[p] { owned[o.index].append(p) }
        }

        // Settlements that cap the tax on peasants, and the quiet after a rising.
        for c in 0..<C {
            if world.unrest.peasantTaxCapMonths[c] > 0 {
                let k = TaxClass.peasants.rawValue
                world.countries.taxLevel[c][k] = min(world.countries.taxLevel[c][k], world.unrest.peasantTaxCap[c])
                world.unrest.peasantTaxCapMonths[c] -= 1
            }
            if world.unrest.quietMonths[c] > 0 { world.unrest.quietMonths[c] -= 1 }
        }

        // Countries that no longer hold land have no rebels.
        for f in world.unrest.factions where owned[f.country.index].isEmpty {
            end(&world, id: f.id, calm: 0, quiet: 0, casualties: 0)
        }

        // 1. Risen factions.
        for id in world.unrest.factions.filter(\.risen).map(\.id) {
            fight(&world, id: id, date: date, rng: &rng)
        }

        // 2. Progress.
        for c in 0..<C where !owned[c].isEmpty {
            grow(&world, CountryID(c), owned: owned[c], points: points, ctx: ctx, date: date)
        }

        // 3. The AI answers.
        for id in world.unrest.factions.map(\.id) {
            guard let f = world.unrest.faction(id: id), !world.humanCountries.contains(f.country) else { continue }
            answer(&world, f, date: date)
        }
    }

    // MARK: - Grievances

    private struct Grievance {
        var pressure = 0.0
        /// Share of the realm's people behind the faction (0 to 1).
        var support = 0.0
        /// Supporting provinces, worst first.
        var provinces: [Int] = []
    }

    /// Unrest points a province adds to a faction's cause.
    private static func provincePoints(_ world: World, _ f: RebelFaction, _ p: Int, _ points: [Double]) -> Double {
        let K = UnrestCause.allCases.count
        func pt(_ cause: UnrestCause) -> Double { max(0, points[p * K + cause.rawValue]) }
        switch f.kind {
        case .peasants:
            return max(0, points[p * K + UnrestCause.tax.rawValue]) + pt(.famine) + pt(.devastation) + pt(.hardship) + pt(.war) + pt(.plague)
        case .zealots:
            return world.provinces.religion[p] == f.religion ? world.provinces.religiousUnrest[p] : 0
        case .separatists:
            guard world.provinces.majorityCulture[p] == f.culture else { return 0 }
            return pt(.culture) + 0.5 * (pt(.tax) + pt(.religion) + pt(.devastation) + pt(.famine) + pt(.war) + pt(.hardship))
        case .nobles, .pretender:
            return 0
        }
    }

    private static func grievance(
        _ world: World, _ f: RebelFaction, owned: [Int], points: [Double], date: GameDate
    ) -> Grievance {
        var g = Grievance()
        let c = f.country.index
        switch f.kind {
        case .peasants, .zealots, .separatists:
            var people = 0.0, behind = 0.0, weighted = 0.0
            var list: [(Int, Double)] = []
            for p in owned {
                let pop = world.provinces.population[p]
                people += pop
                let pts = provincePoints(world, f, p, points)
                guard pts >= UnrestModel.supportPoints, pop > 0 else { continue }
                behind += pop
                weighted += pop * pts
                list.append((p, pts))
            }
            list.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            g.provinces = list.map { $0.0 }
            g.pressure = behind > 0 ? weighted / behind : 0
            g.support = people > 0 ? behind / people : 0
        case .nobles:
            guard let e = f.estate, c < world.government.count, e < world.government.loyalty[c].count,
                  world.government.estates[c].contains(EstateID(e)) else { return g }
            let loyalty = world.government.loyalty[c][e]
            g.pressure = max(0, GovernmentModel.disloyalBelow - loyalty) * (0.5 + 2 * world.government.power[c][e])
            g.support = 1
            g.provinces = angriest(world, owned)
        case .pretender:
            guard let x = f.pretender, world.people.characters.isAlive(x),
                  world.countries.ruler[c] != x else { return g }
            g.pressure = pretenderPressure(world, f.country, x, date: date)
            g.support = 1
            g.provinces = angriest(world, owned)
        }
        return g
    }

    /// The realm's most restless provinces (not the capital), worst first.
    private static func angriest(_ world: World, _ owned: [Int]) -> [Int] {
        guard let first = owned.first, let owner = world.provinces.owner[first] else { return [] }
        let capital = world.countries.capital[owner.index]?.index
        let rest = owned.filter { $0 != capital }
        let sorted = (rest.isEmpty ? owned : rest).sorted {
            let a = world.unrest.unrest($0), b = world.unrest.unrest($1)
            return a != b ? a > b : $0 < $1
        }
        return Array(sorted.prefix(UnrestModel.risingProvinces))
    }

    private static func pretenderPressure(_ world: World, _ country: CountryID, _ x: CharacterID, date: GameDate) -> Double {
        let c = country.index
        let ch = world.people.characters
        var pressure = 0.0
        if c < world.government.count { pressure += Double(max(0, -world.government.stability[c])) * 8 }
        if let ruler = world.countries.ruler[c], ch.isAlive(ruler) {
            if ch.age(ruler, on: date) < CharacterSystem.adultAge { pressure += 10 }
        } else {
            pressure += 10
        }
        if world.countries.heir[c] == nil { pressure += 4 }
        pressure += Double(max(0, ch.skill(x, .martial) + ch.skill(x, .intrigue) - 10)) * 0.5
        return pressure
    }

    // MARK: - Who they are

    /// The largest unhappy faith that is not the state's.
    private static func zealotFaith(_ world: World, _ country: CountryID, owned: [Int]) -> Religion? {
        let state = world.countries.religion[country.index]
        var people: [Religion: Double] = [:]
        for p in owned where world.provinces.religion[p] != state
            && world.provinces.religiousUnrest[p] >= UnrestModel.supportPoints {
            people[world.provinces.religion[p], default: 0] += world.provinces.population[p]
        }
        return people.max { $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue > $1.key.rawValue }?.key
    }

    /// The largest culture the realm does not accept (outside the capital).
    private static func separatistCulture(_ world: World, _ country: CountryID, owned: [Int], ctx: UnrestContext) -> CultureID? {
        let capital = world.countries.capital[country.index]?.index
        var people: [Int: Double] = [:]
        for p in owned where p != capital {
            let k = world.provinces.majorityCulture[p]
            guard ctx.standing.category(world, country, k) != 0 else { continue }
            people[k.index, default: 0] += world.provinces.population[p]
        }
        return people.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }.map { CultureID($0.key) }
    }

    /// The angriest estate that still matters.
    private static func rebelEstate(_ world: World, _ country: CountryID) -> Int? {
        let c = country.index
        guard c < world.government.count else { return nil }
        var best: Int?
        var bestScore = 0.0
        for e in world.government.estates[c] {
            let loyalty = world.government.loyalty[c][e.index], power = world.government.power[c][e.index]
            guard loyalty < GovernmentModel.disloyalBelow, power >= 0.1 else { continue }
            let score = (GovernmentModel.disloyalBelow - loyalty) * (0.5 + 2 * power)
            if score > bestScore {
                best = e.index
                bestScore = score
            }
        }
        return best
    }

    /// A grown man of the ruler's own house who is neither ruler nor heir:
    /// a brother, uncle or cousin with a claim. Real people only.
    private static func pretenderCandidate(_ world: World, _ country: CountryID, date: GameDate) -> CharacterID? {
        let c = country.index
        let ch = world.people.characters
        guard let ruler = world.countries.ruler[c], let house = ch.dynasty[ruler.index],
              !house.isEmpty, !house.hasPrefix("of ") else { return nil }
        let heir = world.countries.heir[c]
        var best: CharacterID?
        var bestScore = -1
        for i in 0..<ch.count where ch.death[i] == nil && !ch.female[i] && ch.dynasty[i] == house {
            let x = CharacterID(i)
            guard x != ruler, x != heir, ch.age(x, on: date) >= CharacterSystem.adultAge else { continue }
            // Not someone who already rules elsewhere.
            if let court = ch.court[i], court != country, world.countries.ruler[court.index] == x { continue }
            let score = ch.skill(x, .martial) + ch.skill(x, .intrigue)
            if score > bestScore {
                best = x
                bestScore = score
            }
        }
        return best
    }

    // MARK: - Progress

    private static func grow(
        _ world: inout World, _ country: CountryID, owned: [Int], points: [Double], ctx: UnrestContext, date: GameDate
    ) {
        let c = country.index
        for kind in RebelKind.allCases {
            var faction: RebelFaction
            let existing = world.unrest.factions.first { $0.country == country && $0.kind == kind }
            if let existing {
                faction = existing
            } else {
                faction = RebelFaction(id: 0, country: country, kind: kind)
                switch kind {
                case .peasants:
                    break
                case .zealots:
                    guard let r = zealotFaith(world, country, owned: owned) else { continue }
                    faction.religion = r
                case .separatists:
                    guard let k = separatistCulture(world, country, owned: owned, ctx: ctx) else { continue }
                    faction.culture = k
                case .nobles:
                    guard let e = rebelEstate(world, country) else { continue }
                    faction.estate = e
                case .pretender:
                    // Only look for a claimant when the throne is shaky.
                    guard c < world.government.count, world.government.stability[c] < 0 || world.countries.heir[c] == nil,
                          let x = pretenderCandidate(world, country, date: date) else { continue }
                    faction.pretender = x
                }
            }

            let g = grievance(world, faction, owned: owned, points: points, date: date)
            var delta = (g.pressure - UnrestModel.threshold(kind)) * UnrestModel.rate(kind)
            if delta > 0 {
                delta *= min(1, g.support / UnrestModel.fullSupportShare)
                if world.unrest.quietMonths[c] > 0 { delta *= UnrestModel.quietFactor }
            }
            delta = min(UnrestModel.maxMonthlyGain, max(-UnrestModel.maxMonthlyLoss, delta))

            if existing == nil {
                guard delta > 0 else { continue }
                faction.id = world.unrest.nextFactionID
                world.unrest.nextFactionID += 1
                world.unrest.factions.append(faction)
            }
            guard let at = world.unrest.factions.firstIndex(where: { $0.id == faction.id }) else { continue }
            world.unrest.factions[at].pressure = g.pressure
            if world.unrest.factions[at].risen {
                world.unrest.factions[at].lastChange = 0
                continue
            }
            world.unrest.factions[at].provinces = g.provinces.map(ProvinceID.init)

            // Soldiers standing among them slow a brewing faction.
            var soldiers = 0
            for p in g.provinces.prefix(UnrestModel.risingProvinces) { soldiers += ctx.crownSoldiers[p] }
            delta -= min(UnrestModel.troopsPerMonthCap, Double(soldiers) / 5000)

            var progress = world.unrest.factions[at].progress + delta
            // One rising at a time: the others wait.
            if world.unrest.factions.contains(where: { $0.country == country && $0.risen }) { progress = min(progress, 95) }
            world.unrest.factions[at].lastChange = delta
            world.unrest.factions[at].progress = min(100, max(0, progress))

            if progress <= 0 {
                world.unrest.factions.remove(at: at)
            } else if progress >= 100 {
                rise(&world, id: faction.id, date: date)
            }
        }
    }

    // MARK: - Rising

    private struct Muster {
        var province: Int
        var pop: Int
        var men: Int
    }

    /// Who would take up arms: pop rows and how many men each gives.
    private static func musterPlan(_ world: World, _ f: RebelFaction) -> [Muster] {
        var plan: [Muster] = []
        for province in f.provinces.prefix(UnrestModel.risingProvinces) {
            let p = province.index
            guard p >= 0, p < world.provinces.count, world.provinces.owner[p] == f.country else { continue }
            for i in world.pops.range(for: province) {
                let cls = world.pops.socialClass[i]
                var share = 0.0
                switch f.kind {
                case .peasants:
                    if cls == .peasants { share = UnrestModel.peasantShare }
                case .zealots:
                    if cls != .slaves && world.pops.religion[i] == f.religion { share = UnrestModel.zealotShare }
                case .separatists:
                    if cls != .slaves && world.pops.culture[i] == f.culture { share = UnrestModel.separatistShare }
                case .nobles:
                    if cls == .nobles { share = UnrestModel.nobleShare }
                    if cls == .peasants { share = UnrestModel.retinueShare }
                case .pretender:
                    if cls == .peasants || cls == .nobles { share = UnrestModel.pretenderShare }
                }
                let men = Int(world.pops.size[i] * share)
                if men > 0 { plan.append(Muster(province: p, pop: i, men: men)) }
            }
        }
        let total = plan.reduce(0) { $0 + $1.men }
        if total > UnrestModel.maxRisingMen {
            let scale = Double(UnrestModel.maxRisingMen) / Double(total)
            for k in plan.indices { plan[k].men = Int(Double(plan[k].men) * scale) }
        }
        return plan
    }

    private static func rise(_ world: inout World, id: Int, date: GameDate) {
        guard let at = world.unrest.factions.firstIndex(where: { $0.id == id }) else { return }
        let f = world.unrest.factions[at]
        let plan = musterPlan(world, f)
        let total = plan.reduce(0) { $0 + $1.men }
        guard total >= UnrestModel.minRisingMen, let seat = plan.first?.province,
              let infantry = world.military.unit("infantry") else {
            // Too few to make an army: the anger simmers on.
            world.unrest.factions[at].progress = 60
            return
        }
        let archers = world.military.unit("archers") ?? infantry
        let cavalry = world.military.unit("cavalry") ?? infantry

        // The men leave their pops, as levies do.
        var menByProvince: [Int: Int] = [:]
        for m in plan {
            world.pops.size[m.pop] = max(0, world.pops.size[m.pop] - Double(m.men))
            menByProvince[m.province, default: 0] += m.men
        }
        world.refreshProvinceSummaries(for: menByProvince.keys.sorted())

        var regiments: [Regiment] = []
        for p in menByProvince.keys.sorted() {
            var left = menByProvince[p] ?? 0
            while left > 0 {
                // A small remainder joins the last regiment instead of standing alone.
                let chunk = left < 1_300 ? left : 1_000
                left -= chunk
                let mounted = (f.kind == .nobles || f.kind == .pretender) && regiments.count % 3 == 0
                let unit = mounted ? cavalry : (regiments.count % 4 == 1 ? archers : infantry)
                regiments.append(Regiment(type: unit.id, origin: .levy, men: chunk, morale: unit.morale * 0.85,
                                          homeProvince: ProvinceID(p)))
            }
        }
        let leader = f.kind == .pretender ? f.pretender : nil
        let army = world.military.armies.append(
            name: name(world, f),
            owner: f.country,
            province: ProvinceID(seat),
            commander: leader,
            regiments: regiments,
            isRebel: true,
            rebelLeader: leader
        )
        world.unrest.factions[at].risen = true
        world.unrest.risings += 1
        world.unrest.factions[at].progress = 100
        world.unrest.factions[at].armies = [Int(army.rawValue)]
        world.unrest.factions[at].monthsInField = 0
        world.unrest.factions[at].victories = 0
        world.people.record(date, f.country,
                            "\(name(world, f)) rise in arms at \(world.provinces.name[seat]) with \(total) men!")
        EventSystem.trigger(
            &world,
            eventID: "chronicle_rebel_rising",
            for: f.country,
            date: date,
            tokens: [
                "rebels": name(world, f),
                "province": world.provinces.name[seat],
                "men": "\(total)"
            ],
            contextProvince: ProvinceID(seat)
        )
    }

    // MARK: - Fighting and winning

    private static func fight(_ world: inout World, id: Int, date: GameDate, rng: inout GameRandom) {
        guard let at = world.unrest.factions.firstIndex(where: { $0.id == id }) else { return }
        let f = world.unrest.factions[at]
        let country = f.country
        let alive = f.armies.filter { $0 >= 0 && $0 < world.military.armies.count && world.military.armies.alive[$0] }
        guard let first = alive.first else {
            crushed(&world, f, date: date, place: f.provinces.first)
            return
        }
        world.unrest.factions[at].armies = alive
        let province = world.military.armies.province[first]
        let rebels = alive.filter { world.military.armies.province[$0] == province }.map { ArmyID(Int32($0)) }
        let crown = world.military.armies(in: province).filter {
            let a = Int($0.rawValue)
            return !world.military.armies.isRebel[a] && world.military.armies.owner[a] == country && !world.military.isInBattle($0)
        }

        if !crown.isEmpty {
            let rebelPower = rebels.reduce(0.0) { $0 + ArmySystem.combatPower(world, $1) }
            let crownPower = crown.reduce(0.0) { $0 + ArmySystem.combatPower(world, $1) }
            let roll = 0.9 + rng.unit() * 0.2
            let place = world.provinces.name[province.index]
            if crownPower * roll >= rebelPower {
                let loss = min(0.35, 0.15 * rebelPower / max(1, crownPower))
                for a in crown { ArmySystem.applyCasualtyRatio(&world, army: a, ratio: loss) }
                crushed(&world, f, date: date, place: province)
                return
            }
            let loss = min(0.35, 0.15 * crownPower / max(1, rebelPower))
            for a in rebels { ArmySystem.applyCasualtyRatio(&world, army: a, ratio: loss) }
            let retreat = world.countries.capital[country.index].flatMap { $0 != province ? $0 : nil }
                ?? world.provinces.neighbors[province.index].first { world.provinces.owner[$0.index] == country }
            for a in crown {
                ArmySystem.applyCasualtyRatio(&world, army: a, ratio: 0.25)
                let i = Int(a.rawValue)
                if world.military.armies.alive[i], let retreat {
                    world.military.armies.province[i] = retreat
                    world.military.armies.path[i].removeAll()
                }
            }
            world.unrest.factions[at].victories += 1
            world.people.record(date, country, "The \(name(world, f)) rout the royal army at \(place).")
        }

        // Still in the field: the land suffers, and time is on their side.
        world.unrest.factions[at].monthsInField += 1
        world.provinces.devastation[province.index] = min(1, world.provinces.devastation[province.index] + UnrestModel.rebelDevastation)
        let now = world.unrest.factions[at]
        if let left = monthsToVictory(now), left <= 0 {
            enforce(&world, now, date: date)
        }
    }

    private static func crushed(_ world: inout World, _ f: RebelFaction, date: GameDate, place: ProvinceID?) {
        let at = place.map { " at \(world.provinces.name[$0.index])" } ?? ""
        world.people.record(date, f.country, "The \(name(world, f)) are crushed\(at).")
        world.unrest.rebelDefeats += 1
        end(&world, id: f.id, calm: 10, quiet: UnrestModel.quietMonthsAfterRising, casualties: 0.4)
    }

    /// The faction is over (won, lost or bought off): survivors go home,
    /// its provinces calm down and the realm has some quiet years.
    private static func end(_ world: inout World, id: Int, calm: Double, quiet: Int, casualties: Double) {
        guard let at = world.unrest.factions.firstIndex(where: { $0.id == id }) else { return }
        let f = world.unrest.factions.remove(at: at)
        for a in f.armies where a >= 0 && a < world.military.armies.count && world.military.armies.alive[a] {
            let aid = ArmyID(Int32(a))
            if casualties > 0 { ArmySystem.applyCasualtyRatio(&world, army: aid, ratio: casualties) }
            if world.military.armies.alive[a] { ArmySystem.disband(&world, army: aid) }
        }
        for p in f.provinces where p.index < world.unrest.calm.count {
            world.unrest.calm[p.index] = max(world.unrest.calm[p.index], calm)
        }
        let c = f.country.index
        if c < world.unrest.quietMonths.count {
            world.unrest.quietMonths[c] = max(world.unrest.quietMonths[c], quiet)
        }
    }

    // MARK: - Demands

    private static func capPeasantTax(_ world: inout World, _ country: CountryID, _ cap: Double, months: Int) {
        let c = country.index, k = TaxClass.peasants.rawValue
        world.unrest.peasantTaxCap[c] = cap
        world.unrest.peasantTaxCapMonths[c] = months
        world.countries.taxLevel[c][k] = min(world.countries.taxLevel[c][k], cap)
    }

    /// Share of a country's people who follow `religion`.
    static func faithShare(_ world: World, _ country: CountryID, _ religion: Religion) -> Double {
        var total = 0.0, theirs = 0.0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            for i in world.pops.range(for: ProvinceID(p)) {
                total += world.pops.size[i]
                if world.pops.religion[i] == religion { theirs += world.pops.size[i] }
            }
        }
        return total > 0 ? theirs / total : 0
    }

    /// No missionaries among them, less religious unrest, and (if the law
    /// was the harshest) a tolerant law.
    private static func tolerate(_ world: inout World, _ f: RebelFaction, unrestFactor: Double) {
        guard let r = f.religion else { return }
        let country = f.country
        var theirs = Set<Int>()
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country && world.provinces.religion[p] == r {
            theirs.insert(p)
            world.provinces.religiousUnrest[p] *= unrestFactor
        }
        world.faith.missionaries.removeAll { $0.country == country && theirs.contains($0.province.index) }
        let c = country.index
        if c < world.government.count, let area = world.government.rules.lawArea(forKey: "faith"),
           area < world.government.laws[c].count {
            let options = world.government.rules.lawAreas[area].options
            let now = world.government.laws[c][area]
            if now < options.count, options[now].key == "orthodoxy",
               let tolerant = options.firstIndex(where: { $0.key == "tolerance" }) {
                world.government.laws[c][area] = tolerant
                GovernmentSystem.refreshEffects(&world, country)
            }
        }
    }

    /// The strongest privilege the rebel estate does not have yet.
    static func wantedPrivilege(_ world: World, _ f: RebelFaction) -> Int? {
        guard let e = f.estate, f.country.index < world.government.count else { return nil }
        let have = world.government.privileges[f.country.index]
        let rules = world.government.rules
        return rules.privileges(of: EstateID(e)).filter { !have.contains($0) }
            .max { rules.privileges[$0].power != rules.privileges[$1].power
                ? rules.privileges[$0].power < rules.privileges[$1].power : $0 > $1 }
    }

    enum Breakaway {
        /// Their provinces go to this country.
        case country(CountryID, [Int])
        /// Too much of the realm, or nowhere to go: their culture is accepted.
        case acceptance
    }

    /// Where separatists' lands would go. A country that has lost its land
    /// and has a claim (a core) comes back; else one of their own culture;
    /// else a neighbour of their culture. New countries are never invented.
    static func breakaway(_ world: World, _ f: RebelFaction) -> Breakaway {
        guard let k = f.culture else { return .acceptance }
        let country = f.country
        let capital = world.countries.capital[country.index]?.index
        var theirs: [Int] = []
        var ownedCount = 0
        var landed = Array(repeating: false, count: world.countries.count)
        for p in 0..<world.provinces.count {
            guard let o = world.provinces.owner[p] else { continue }
            landed[o.index] = true
            guard o == country else { continue }
            ownedCount += 1
            if p != capital && world.provinces.majorityCulture[p] == k { theirs.append(p) }
        }
        guard !theirs.isEmpty, Double(theirs.count) <= Double(ownedCount) * UnrestModel.maxBreakawayShare else {
            return .acceptance
        }
        var withCore: CountryID?
        var sameCulture: CountryID?
        for c in 0..<world.countries.count where !landed[c] && c != country.index {
            let id = CountryID(c)
            if withCore == nil, theirs.contains(where: { world.provinces.cores[$0].contains(id) }) { withCore = id }
            if sameCulture == nil, world.countries.primaryCulture[c] == k { sameCulture = id }
        }
        if let target = withCore ?? sameCulture { return .country(target, theirs) }
        for p in theirs {
            for n in world.provinces.neighbors[p] {
                if let o = world.provinces.owner[n.index], o != country, world.countries.primaryCulture[o.index] == k {
                    return .country(o, theirs)
                }
            }
        }
        return .acceptance
    }

    private static func handOver(_ world: inout World, _ p: Int, to target: CountryID, from old: CountryID) {
        world.provinces.owner[p] = target
        world.provinces.occupiedBy[p] = nil
        world.provinces.occupationTarget[p] = nil
        world.provinces.occupationProgressDays[p] = 0
        world.provinces.holder[p] = nil
        world.provinces.cores[p].insert(target)
        world.military.sieges.removeAll { $0.province.index == p }
        if p < world.calamity.quarantine.count {
            world.calamity.quarantine[p] = false
            world.calamity.cordon[p] = false
        }
        world.faith.missionaries.removeAll { $0.province.index == p }
    }

    /// The rebels have won: their demand becomes fact.
    private static func enforce(_ world: inout World, _ f: RebelFaction, date: GameDate) {
        let country = f.country
        let c = country.index
        let who = name(world, f)
        let outcome: String
        switch f.kind {
        case .peasants:
            capPeasantTax(&world, country, UnrestModel.enforcedPeasantTax, months: UnrestModel.enforcedTaxMonths)
            outcome = "taxes on peasants are halved for five years"
        case .zealots:
            if let r = f.religion, faithShare(world, country, r) >= UnrestModel.stateFaithShare {
                world.countries.religion[c] = r
                outcome = "the \(r.displayName) faith becomes the religion of the state"
            } else {
                tolerate(&world, f, unrestFactor: 0.3)
                outcome = "their faith is left in peace"
            }
        case .separatists:
            switch breakaway(world, f) {
            case .country(let target, let provinces):
                let hadLand = world.provinces.owner.contains(target)
                for p in provinces { handOver(&world, p, to: target, from: country) }
                if !hadLand {
                    world.countries.overlord[target.index] = nil
                    world.countries.subjectType[target.index] = nil
                    world.countries.capital[target.index] = provinces
                        .max { world.provinces.development[$0] != world.provinces.development[$1]
                            ? world.provinces.development[$0] < world.provinces.development[$1] : $0 > $1 }
                        .map(ProvinceID.init)
                    world.countries.treasury[target.index] = max(world.countries.treasury[target.index], 50)
                }
                outcome = "\(provinces.count) province\(provinces.count == 1 ? "" : "s") break away to \(world.countries.name[target.index])"
                world.people.record(date, target, "\(who) win their freedom from \(world.countries.name[c]).")
            case .acceptance:
                if let k = f.culture { world.countries.acceptedCultures[c].insert(k) }
                outcome = "their culture must be accepted"
            }
        case .nobles:
            if let p = wantedPrivilege(world, f) {
                world.government.privileges[c].insert(p)
                outcome = "they take the privilege \"\(world.government.rules.privileges[p].name)\""
            } else {
                let cost = max(0, world.countries.lastMonthlyIncome[c] * 3)
                world.countries.treasury[c] -= cost
                outcome = "they empty the treasury of \(Int(cost.rounded())) ducats"
            }
        case .pretender:
            if let x = f.pretender, world.people.characters.isAlive(x) {
                world.countries.ruler[c] = x
                world.people.characters.court[x.index] = country
                for seat in CouncilSeat.allCases where world.countries.council[c][seat.rawValue] == x {
                    world.countries.council[c][seat.rawValue] = nil
                }
                world.countries.heir[c] = CharacterSystem.heir(world, country, date: date)
                outcome = "\(world.people.characters.fullName(x)) takes the throne"
            } else {
                outcome = "their claimant is dead and they go home"
            }
        }
        if c < world.government.count {
            GovernmentSystem.changeStability(&world, country, by: -1)
            GovernmentSystem.refreshEffects(&world, country)
        }
        world.people.record(date, country, "The \(who) have won: \(outcome).")
        world.unrest.rebelVictories += 1
        end(&world, id: f.id, calm: 15, quiet: UnrestModel.quietMonthsAfterRising, casualties: 0)
    }

    // MARK: - AI

    /// Computer countries: cheap answers first (taxes), then troops if the
    /// army is clearly stronger, else a concession before it comes to war.
    private static func answer(_ world: inout World, _ f: RebelFaction, date: GameDate) {
        let country = f.country
        let c = country.index
        let crownMen = world.military.totalMen(of: country)
        if f.risen {
            // The army AI (`ArmySystem.runAI`) already marches on rebels and
            // raises levies. Give way only when that is hopeless.
            let rebelMen = men(world, f)
            if f.monthsInField >= 3 && Double(crownMen) < Double(rebelMen) * 0.6 {
                concede(&world, country, faction: f.id, date: date)
            }
            return
        }
        guard f.progress >= 70 else { return }
        let k = TaxClass.peasants.rawValue
        if f.kind == .peasants && world.countries.taxLevel[c][k] > 1 {
            world.countries.taxLevel[c][k] = 1
            return
        }
        guard f.progress >= 85 else { return }
        let expected = expectedMen(world, f)
        if crownMen >= max(2_000, expected * 2) {
            if sendTroops(&world, country, faction: f.id) == nil { return }
            // Troops already there and it still grows: give way near the end.
            if f.progress < 95 { return }
        }
        if concede(&world, country, faction: f.id, date: date) == .noMoney {
            sendTroops(&world, country, faction: f.id)
        }
    }
}
