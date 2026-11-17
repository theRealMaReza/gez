import Foundation

/// Per-country numbers the unrest of every province draws on, built once a month.
struct UnrestContext {
    var taxPoints: [Double]
    var estatePoints: [Double]
    var warPoints: [Double]
    var successionPoints: [Double]
    /// Loyal (non-rebel) soldiers of the owner standing in each province.
    var crownSoldiers: [Int]
    var standing: CultureStanding

    init(_ world: World, date: GameDate) {
        let C = world.countries.count
        let P = world.provinces.count
        taxPoints = Array(repeating: 0, count: C)
        estatePoints = Array(repeating: 0, count: C)
        warPoints = Array(repeating: 0, count: C)
        successionPoints = Array(repeating: 0, count: C)
        crownSoldiers = Array(repeating: 0, count: P)
        standing = CultureStanding(world)

        let weights: [(TaxClass, Double)] = [(.peasants, 0.6), (.burghers, 0.2), (.nobles, 0.1), (.clergy, 0.1)]
        let g = world.government
        let ch = world.people.characters
        for c in 0..<C {
            var tax = 0.0
            for (tc, w) in weights {
                let level = world.countries.taxLevel[c][tc.rawValue]
                tax += w * (level > 1 ? (level - 1) * UnrestModel.taxAbove : -(1 - level) * UnrestModel.taxBelow)
            }
            taxPoints[c] = tax

            if c < g.count {
                var estates = 0.0
                for e in g.estates[c] where g.loyalty[c][e.index] < GovernmentModel.disloyalBelow {
                    estates += g.power[c][e.index] * (GovernmentModel.disloyalBelow - g.loyalty[c][e.index]) * UnrestModel.estateScale
                }
                estatePoints[c] = min(UnrestModel.estateCap, estates)

                let stability = Double(g.stability[c])
                var s = stability < 0 ? -stability * UnrestModel.instability : -stability * UnrestModel.stabilityCalm
                if let ruler = world.countries.ruler[c], ch.isAlive(ruler) {
                    if ch.age(ruler, on: date) < CharacterSystem.adultAge { s += UnrestModel.minorRuler }
                } else {
                    s += UnrestModel.minorRuler
                }
                if world.countries.heir[c] == nil { s += UnrestModel.noHeir }
                successionPoints[c] = s
            }
            if c < world.unrest.warMonths.count {
                warPoints[c] = min(UnrestModel.warCap, Double(world.unrest.warMonths[c]) * UnrestModel.warPerMonth)
            }
        }
        let armies = world.military.armies
        for a in 0..<armies.count where armies.alive[a] && !armies.isRebel[a] && armies.embarkedOnFleet[a] == nil {
            let p = armies.province[a].index
            guard p >= 0, p < P, world.provinces.owner[p] == armies.owner[a] else { continue }
            for reg in armies.regiments[a] { crownSoldiers[p] += reg.men }
        }
    }
}

/// Unrest (Phase 12 Part C): one number per province from real causes.
/// Rebel factions (`RebelSystem`) grow from it.
public enum UnrestSystem {

    /// Points per cause for one province (`UnrestCause` order).
    static func points(_ world: World, _ p: Int, _ ctx: UnrestContext) -> [Double] {
        var out = Array(repeating: 0.0, count: UnrestCause.allCases.count)
        guard let owner = world.provinces.owner[p] else { return out }
        let o = owner.index

        var total = 0.0, mood = 0.0, culture = 0.0
        for i in world.pops.range(for: ProvinceID(p)) {
            let size = world.pops.size[i]
            guard size > 0 else { continue }
            total += size
            mood += size * world.pops.satisfaction[i]
            switch ctx.standing.category(world, owner, world.pops.culture[i]) {
            case 1: culture += size * UnrestModel.cultureSameFamily
            case 2: culture += size * UnrestModel.cultureForeign
            default: break
            }
        }
        guard total > 0 else { return out }

        out[UnrestCause.tax.rawValue] = ctx.taxPoints[o]
        out[UnrestCause.religion.rawValue] = world.provinces.religiousUnrest[p] * UnrestModel.religionShare
        out[UnrestCause.culture.rawValue] = culture / total
        out[UnrestCause.estates.rawValue] = ctx.estatePoints[o]
        out[UnrestCause.devastation.rawValue] = world.provinces.devastation[p] * UnrestModel.devastation
        out[UnrestCause.famine.rawValue] = world.provinces.famine[p] * UnrestModel.famine
        out[UnrestCause.plague.rawValue] = min(UnrestModel.plagueCap, world.calamity.totalInfection(p) * UnrestModel.plague)
        out[UnrestCause.war.rawValue] = ctx.warPoints[o]
        out[UnrestCause.succession.rawValue] = ctx.successionPoints[o]
        out[UnrestCause.hardship.rawValue] = max(0, 0.6 - mood / total) * UnrestModel.hardship
        let soldiers = Double(ctx.crownSoldiers[p]) / 1000 * UnrestModel.soldiersPerThousand
        out[UnrestCause.garrison.rawValue] = -min(UnrestModel.garrisonCap,
                                                  soldiers + Double(world.provinces.fortLevel[p]) * UnrestModel.fortLevel)
        out[UnrestCause.calm.rawValue] = p < world.unrest.calm.count ? -world.unrest.calm[p] : 0
        return out
    }

    static func target(_ points: [Double]) -> Double {
        min(100, max(0, points.reduce(0, +)))
    }

    /// The causes of a province's unrest with their points, biggest first
    /// (calming causes are negative). For the province panel.
    public static func causes(_ world: World, in province: ProvinceID, date: GameDate) -> [(cause: UnrestCause, points: Double)] {
        guard province.index >= 0, province.index < world.provinces.count else { return [] }
        let pts = points(world, province.index, UnrestContext(world, date: date))
        return UnrestCause.allCases
            .map { (cause: $0, points: pts[$0.rawValue]) }
            .filter { abs($0.points) >= 0.05 }
            .sorted { abs($0.points) != abs($1.points) ? abs($0.points) > abs($1.points) : $0.cause.rawValue < $1.cause.rawValue }
    }

    /// Average unrest of a country's provinces, weighted by people.
    public static func averageUnrest(_ world: World, of country: CountryID) -> Double {
        var sum = 0.0, people = 0.0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            sum += world.unrest.unrest(p) * world.provinces.population[p]
            people += world.provinces.population[p]
        }
        return people > 0 ? sum / people : 0
    }

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        let C = world.countries.count
        guard P > 0, C > 0 else { return }
        world.unrest.resize(provinces: P, countries: C)
        world.calamity.resize(provinces: P)

        // Months at war (war weariness).
        var atWar = Array(repeating: false, count: C)
        for w in world.diplomacy.wars {
            for c in w.attackers where c.index < C { atWar[c.index] = true }
            for c in w.defenders where c.index < C { atWar[c.index] = true }
        }
        for c in 0..<C {
            world.unrest.warMonths[c] = atWar[c] ? world.unrest.warMonths[c] + 1 : max(0, world.unrest.warMonths[c] - 2)
        }

        // Settlements fade; unrest follows its causes.
        let ctx = UnrestContext(world, date: date)
        var points = Array(repeating: 0.0, count: P * UnrestCause.allCases.count)
        let K = UnrestCause.allCases.count
        for p in 0..<P {
            if world.unrest.calm[p] > 0 {
                world.unrest.calm[p] = max(0, world.unrest.calm[p] - UnrestModel.calmFade)
            } else if world.unrest.calm[p] < 0 {
                world.unrest.calm[p] = min(0, world.unrest.calm[p] + UnrestModel.calmFade)
            }
            guard world.provinces.owner[p] != nil else {
                world.unrest.unrest[p] = 0
                continue
            }
            let pts = Self.points(world, p, ctx)
            for k in 0..<K { points[p * K + k] = pts[k] }
            world.unrest.unrest[p] += UnrestModel.speed * (target(pts) - world.unrest.unrest[p])
        }

        RebelSystem.runMonthly(&world, date: date, random: &random, points: points, context: ctx)
    }
}
