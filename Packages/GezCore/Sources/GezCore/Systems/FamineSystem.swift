import Foundation

/// Harvests and famine (Phase 12 Part B). Once a month:
/// 1. on 1 August the year's harvest is rolled, region by region
/// 2. each province's staple output factor is worked out from the harvest,
///    war devastation, looting by besiegers and occupiers, and levies kept
///    under arms through the harvest months
/// 3. where a market's staple food falls below what it is used to, famine
///    sets in: people starve (the poor first), contentment falls, and the
///    existing migration (`CultureSystem`) carries people away
public enum FamineSystem {

    /// Goods that count as staple food (what the farms of a province grow to eat).
    static func stapleGoods(_ world: World) -> [Int] {
        var seen = Set<Int>()
        let producers = world.economy.producers
        for k in 0..<producers.count where producers.isStaple[k] { seen.insert(producers.good[k].index) }
        return seen.sorted()
    }

    /// Staple supply ÷ demand of each market last month (1 = no demand).
    public static func stapleRatios(_ world: World) -> [Double] {
        let eco = world.economy
        let M = eco.markets.count, G = eco.goods.count
        let staples = stapleGoods(world)
        var out = Array(repeating: 1.0, count: M)
        guard !staples.isEmpty, eco.markets.supply.count == M * G, eco.markets.demand.count == M * G else { return out }
        for m in 0..<M {
            var s = 0.0, d = 0.0
            for g in staples {
                s += eco.markets.supply[m * G + g]
                d += eco.markets.demand[m * G + g]
            }
            if d > 0 { out[m] = s / d }
        }
        return out
    }

    /// Sets this year's harvest for one province (events, tests).
    public static func setHarvest(_ world: inout World, in province: ProvinceID, to value: Double) {
        world.calamity.resize(provinces: world.provinces.count)
        guard province.index >= 0, province.index < world.calamity.harvest.count else { return }
        world.calamity.harvest[province.index] = min(FamineModel.bestHarvest, max(0.05, value))
    }

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let P = world.provinces.count
        guard P > 0 else { return }
        world.calamity.resize(provinces: P)
        var rng = world.beginCalamityRandom(random)
        defer { world.endCalamityRandom(rng) }

        // 1. The harvest.
        if date.month == FamineModel.harvestMonth && world.calamity.harvestYear != date.year {
            rollHarvest(&world, year: date.year, rng: &rng)
        }

        // 2. Levies away at harvest, then the staple factor.
        var underSiege = Array(repeating: false, count: P)
        for s in world.military.sieges where s.province.index < P { underSiege[s.province.index] = true }
        if FamineModel.harvestSeason.contains(date.month) {
            if date.month == FamineModel.harvestSeason.lowerBound {
                world.calamity.levyHarvestLoss = Array(repeating: 0, count: P)
            }
            var leviesAway = Array(repeating: false, count: P)
            let armies = world.military.armies
            for a in 0..<armies.count where armies.alive[a] {
                for reg in armies.regiments[a] where reg.origin == .levy {
                    if let home = reg.homeProvince, home.index < P { leviesAway[home.index] = true }
                }
            }
            for p in 0..<P where leviesAway[p] {
                world.calamity.levyHarvestLoss[p] = min(0.5, world.calamity.levyHarvestLoss[p] + FamineModel.levyLossPerMonth)
            }
        }
        for p in 0..<P {
            var f = world.calamity.harvest[p] * (1 - world.calamity.levyHarvestLoss[p])
            f *= 1 - FamineModel.devastationLoss * min(1, max(0, world.provinces.devastation[p]))
            if underSiege[p] || world.provinces.occupiedBy[p] != nil { f *= FamineModel.lootingFactor }
            world.calamity.stapleFactor[p] = min(1.3, max(0.2, f))
        }

        // 3. Famine.
        let eco = world.economy
        let M = eco.markets.count
        let ratios = stapleRatios(world)
        if world.calamity.stapleNorm.count != M {
            world.calamity.stapleNorm = Array(repeating: 0, count: M)
        }
        for m in 0..<M {
            let norm = world.calamity.stapleNorm[m]
            world.calamity.stapleNorm[m] = norm <= 0 ? ratios[m] : norm + FamineModel.normSpeed * (ratios[m] - norm)
        }
        world.calamity.lastFamineDeaths = Array(repeating: 0, count: P)
        var dirty: [Int] = []
        for p in 0..<P {
            var severity = 0.0
            if p < eco.provinceMarket.count {
                let m = eco.provinceMarket[p].index
                if m < M {
                    let used = max(0.3, min(1, world.calamity.stapleNorm[m]))
                    // A failed harvest at home bites harder than the market's average.
                    let local = ratios[m] / used * (0.6 + 0.4 * min(1, world.calamity.stapleFactor[p]))
                    if local < FamineModel.famineBelow {
                        severity = min(1, (FamineModel.famineBelow - local) * FamineModel.famineSlope)
                    }
                }
            }
            let before = world.provinces.famine[p]
            let now = severity > before ? severity : max(severity, before - FamineModel.famineDecay)
            world.provinces.famine[p] = now
            guard now > 0.05 else { continue }

            var dead = 0.0
            for i in world.pops.range(for: ProvinceID(p)) {
                let size = world.pops.size[i]
                guard size > 0 else { continue }
                let lost = size * now * FamineModel.monthlyDeaths * FamineModel.classDeaths(world.pops.socialClass[i])
                world.pops.size[i] = size - lost
                world.pops.satisfaction[i] = max(0, world.pops.satisfaction[i] - now * FamineModel.moodHit)
                dead += lost
            }
            world.calamity.lastFamineDeaths[p] = dead
            world.calamity.totalFamineDeaths += dead
            if dead > 0 { dirty.append(p) }

            if before < FamineModel.alertAbove && now >= FamineModel.alertAbove {
                let text = "Famine in \(world.provinces.name[p])."
                world.calamity.addNote(CalamityNote(date: date, province: ProvinceID(p), kind: "famine", text: text))
                if let owner = world.provinces.owner[p], world.countries.capital[owner.index] == ProvinceID(p) {
                    world.people.record(date, owner, "Famine reaches the capital, \(world.provinces.name[p]).")
                }
            }
        }
        if !dirty.isEmpty { world.refreshProvinceSummaries(for: dirty) }
    }

    /// One roll per region (the weather), a smaller one per state.
    private static func rollHarvest(_ world: inout World, year: Int, rng: inout GameRandom) {
        let regionCount = world.regions.count
        var region = Array(repeating: 1.0, count: max(1, regionCount))
        for r in 0..<region.count {
            // Three dice added together: mostly near the middle, rarely extreme.
            let dice = rng.unit() + rng.unit() + rng.unit()
            region[r] = 1 + (dice - 1.5) * FamineModel.regionSpread
        }
        var state = Array(repeating: 0.0, count: world.states.count)
        for s in 0..<state.count { state[s] = (rng.unit() - 0.5) * FamineModel.stateSpread }
        for p in 0..<world.provinces.count {
            let s = world.provinces.state[p].index
            let r = s < world.states.count ? world.states.region[s].index : 0
            let value = (r < region.count ? region[r] : 1) + (s < state.count ? state[s] : 0)
            world.calamity.harvest[p] = min(FamineModel.bestHarvest, max(FamineModel.worstHarvest, value))
        }
        world.calamity.harvestYear = year
    }
}
