import Foundation

/// Earthquakes (Phase 12 Part B). Each month every fault zone may shake by
/// chance, and the earthquakes history records strike on their dates. An
/// earthquake knocks down building and fort levels, kills people and leaves
/// devastation at the epicentre and, more weakly, in the provinces around it.
public enum QuakeSystem {

    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let rules = world.calamityRules
        guard !rules.faultZones.isEmpty || !rules.historicalQuakes.isEmpty else { return }
        world.calamity.resize(provinces: world.provinces.count)
        var rng = world.beginCalamityRandom(random)
        defer { world.endCalamityRandom(rng) }

        // Known earthquakes: this runs on the first of the month, so one
        // dated the 5th strikes on the 1st of the next month at the latest.
        for q in rules.historicalQuakes where q.date <= date && !world.calamity.pastHistoricalQuakes.contains(q.name) {
            world.calamity.pastHistoricalQuakes.append(q.name)
            // Only if the game was already running on that day.
            if date.ordinal - q.date.ordinal <= 31 {
                strike(&world, epicentre: q.province, strength: q.strength, name: q.name, date: date, rng: &rng)
            }
        }

        for zone in rules.faultZones where !zone.provinces.isEmpty {
            guard rng.unit() < zone.yearlyChance / 12 else { continue }
            let epicentre = zone.provinces[Int(rng.next() % UInt64(zone.provinces.count))]
            // Most earthquakes are moderate; a few are terrible.
            let roll = rng.unit()
            let strength = zone.strength * (0.35 + 0.65 * roll * roll)
            strike(&world, epicentre: epicentre, strength: strength, name: "Earthquake in \(zone.name)", date: date, rng: &rng)
        }
    }

    /// An earthquake now (events, tests). Returns what it did.
    @discardableResult
    public static func strike(
        _ world: inout World,
        epicentre: ProvinceID,
        strength: Double,
        name: String,
        date: GameDate,
        rng: inout GameRandom
    ) -> QuakeRecord {
        let P = world.provinces.count
        var record = QuakeRecord(date: date, name: name, epicentre: epicentre, strength: min(1, max(0, strength)),
                                 deaths: 0, buildingLevelsLost: 0, fortLevelsLost: 0)
        guard epicentre.index >= 0, epicentre.index < P else { return record }
        world.calamity.resize(provinces: P)

        var shaken: [(Int, Double)] = [(epicentre.index, record.strength)]
        for n in world.provinces.neighbors[epicentre.index] {
            shaken.append((n.index, record.strength * QuakeModel.neighbourShare))
        }
        let T = world.economy.buildings.typeCount
        let besieged = Set(world.military.sieges.map(\.province.index))
        var dirty: [Int] = []
        for (p, s) in shaken where s > 0 {
            // Buildings and walls.
            for t in 0..<T {
                let type = BuildingTypeID(t)
                let level = world.economy.buildings.level(ProvinceID(p), type)
                guard level > 0, rng.unit() < s * QuakeModel.buildingLoss else { continue }
                let isFort = world.economy.buildingTypes[t].effect == .fort
                // The last wall of a besieged fort stands: the siege goes on.
                if isFort && level == 1 && besieged.contains(p) { continue }
                world.economy.buildings.setLevel(ProvinceID(p), type, level - 1)
                if isFort {
                    world.provinces.fortLevel[p] = level - 1
                    world.provinces.fortGarrison[p] = min(world.provinces.fortGarrison[p], max(0, level - 1) * 1000)
                    record.fortLevelsLost += 1
                } else {
                    record.buildingLevelsLost += 1
                }
            }
            // People.
            var dead = 0.0
            for i in world.pops.range(for: ProvinceID(p)) {
                let lost = world.pops.size[i] * s * QuakeModel.deaths
                world.pops.size[i] -= lost
                dead += lost
            }
            record.deaths += dead
            if dead > 0 { dirty.append(p) }
            world.provinces.devastation[p] = min(1, world.provinces.devastation[p] + s * QuakeModel.devastation)
        }
        if !dirty.isEmpty { world.refreshProvinceSummaries(for: dirty) }

        world.calamity.totalQuakeDeaths += record.deaths
        world.calamity.quakes.append(record)
        if world.calamity.quakes.count > 30 { world.calamity.quakes.removeFirst(world.calamity.quakes.count - 30) }
        let place = world.provinces.name[epicentre.index]
        let lost = record.buildingLevelsLost + record.fortLevelsLost
        let text = "\(name): the earth shakes at \(place); \(Int(record.deaths.rounded())) dead"
            + (lost > 0 ? ", \(lost) building level\(lost == 1 ? "" : "s") in ruins." : ".")
        world.calamity.addNote(CalamityNote(date: date, province: epicentre, kind: "earthquake", text: text))
        if let owner = world.provinces.owner[epicentre.index] {
            world.people.record(date, owner, text)
        }
        return record
    }
}
