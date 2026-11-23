/// Monthly income and spending. Income now comes from the market model
/// (`MarketSystem`); expenses (armies, buildings, loans) come later.
public enum EconomySystem {
    public static func runMonthly(_ world: inout World) {
        MarketSystem.runMonthly(&world)
    }
}

/// Monthly population growth towards each province's carrying capacity
/// (Phase 20.5). Land below its capacity (after war, plague or famine)
/// refills quickly; crowded land stops growing and slowly sheds people.
/// Capacity starts 25% above the 1453 population and rises 0.2% a year, so
/// a peaceful province grows about 0.4% a year at first.
public enum PopulationSystem {
    /// Growth in 1453 conditions (a province at 80% of its capacity).
    public static let yearlyGrowthRate = 0.004
    /// Yearly growth of nearly empty land.
    public static let maxYearlyGrowth = 0.02
    /// Yearly loss of land far over its capacity.
    public static let maxYearlyDecline = 0.01
    /// Capacity in 1453 relative to the 1453 population.
    public static let startHeadroom = 1.25
    /// Yearly rise of capacity (better farming, new land).
    public static let capacityGrowthPerYear = 0.002

    /// Number of people the province can feed in `year`.
    public static func capacity(_ world: World, _ p: Int, year: Int) -> Double {
        let start = p < world.provinces.startPopulation.count ? world.provinces.startPopulation[p] : world.provinces.population[p]
        let years = Double(max(0, year - 1453))
        return max(1_000, start * startHeadroom * (1 + capacityGrowthPerYear * years))
    }

    public static func runMonthly(_ world: inout World, date: GameDate? = nil) {
        let year = date?.year ?? 1453
        for p in 0..<world.provinces.count {
            let range = world.pops.range(for: ProvinceID(p))
            var total = 0.0
            for i in range { total += world.pops.size[i] }
            let ratio = total / capacity(world, p, year: year)
            let yearly = min(maxYearlyGrowth, max(-maxYearlyDecline, maxYearlyGrowth * (1 - ratio)))
            let factor = 1 + yearly / 12
            var after = 0.0
            for i in range {
                world.pops.size[i] *= factor
                after += world.pops.size[i]
            }
            world.provinces.population[p] = after
        }
    }
}
