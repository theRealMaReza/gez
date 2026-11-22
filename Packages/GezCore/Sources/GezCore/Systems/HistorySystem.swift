import Foundation

/// Records Chronicle events, regnal chapters, yearly country statistics,
/// and yearly map timelapse snapshots into `world.history` (Phase 18).
public enum HistorySystem {

    private static let religionIndexMap: [Religion: UInt8] = {
        var map: [Religion: UInt8] = [:]
        for (i, r) in Religion.allCases.enumerated() {
            map[r] = UInt8(i)
        }
        return map
    }()

    public static func religionIndex(_ religion: Religion) -> UInt8 {
        religionIndexMap[religion] ?? 0
    }

    public static func religion(fromIndex idx: UInt8) -> Religion {
        let i = Int(idx)
        let all = Religion.allCases
        guard i >= 0 && i < all.count else { return .catholic }
        return all[i]
    }

    /// Initializes history recording for a new game or a legacy save loaded in Phase 18.
    /// Safe to call multiple times; does nothing once `world.history.isInitialized` is true.
    public static func ensureInitialized(_ world: inout World, date: GameDate) {
        guard !world.history.isInitialized else { return }
        world.history.isInitialized = true

        // Open initial regnal chapters for all countries that have a ruler.
        if world.history.chapters.count == 0 {
            for c in world.countries.ids {
                guard let rid = world.countries.ruler[c.index] else { continue }
                let rName = world.people.characters.fullName(rid)
                let dName = world.people.characters.dynasty[rid.index] ?? ""
                world.history.chapters.openReign(
                    country: c,
                    rulerID: rid,
                    rulerName: rName,
                    dynastyName: dName,
                    startDate: date
                )
            }
        }

        // Record the initial year baseline if no year has been recorded yet.
        if world.history.stats.years.isEmpty {
            appendYearlyStats(&world, year: date.year)
        }
        if world.history.timelapse.years.isEmpty {
            appendYearlyTimelapse(&world, year: date.year)
        }
    }

    /// Called on 1 January of each year from `Simulation.tick()`.
    public static func recordYearlySnapshot(_ world: inout World, date: GameDate) {
        ensureInitialized(&world, date: date)

        if world.history.stats.years.last != date.year {
            appendYearlyStats(&world, year: date.year)
        }
        if world.history.timelapse.years.last != date.year {
            appendYearlyTimelapse(&world, year: date.year)
        }
    }

    /// Records a structured Chronicle event using `world.history`'s dedicated RNG stream.
    public static func recordEvent(
        _ world: inout World,
        date: GameDate,
        kind: ChronicleEventKind,
        primary: CountryID,
        secondary: CountryID? = nil,
        province: ProvinceID? = nil,
        character: CharacterID? = nil,
        secondaryCharacter: CharacterID? = nil,
        valueA: Int = 0,
        valueB: Int = 0
    ) {
        var rng = GameRandom(seed: world.history.rngState)
        let seed = UInt32(truncatingIfNeeded: rng.next())
        world.history.rngState = rng.rawState

        world.history.events.append(
            date: date,
            kind: kind,
            primaryCountry: primary,
            secondaryCountry: secondary,
            province: province,
            character: character,
            secondaryCharacter: secondaryCharacter,
            valueA: valueA,
            valueB: valueB,
            templateSeed: seed
        )
    }

    /// Updates regnal chapters and records `rulerDied` / `rulerCrowned` events on succession.
    public static func recordSuccession(
        _ world: inout World,
        country: CountryID,
        oldRuler: CharacterID?,
        newRuler: CharacterID,
        date: GameDate
    ) {
        if let oldRuler {
            recordEvent(
                &world,
                date: date,
                kind: .rulerDied,
                primary: country,
                character: oldRuler
            )
        }
        world.history.chapters.closeActiveReign(for: country, on: date)

        let rName = world.people.characters.fullName(newRuler)
        let dName = world.people.characters.dynasty[newRuler.index] ?? ""
        world.history.chapters.openReign(
            country: country,
            rulerID: newRuler,
            rulerName: rName,
            dynastyName: dName,
            startDate: date
        )
        recordEvent(
            &world,
            date: date,
            kind: .rulerCrowned,
            primary: country,
            character: newRuler
        )
    }

    // MARK: - Private Snapshot Helpers

    private static func appendYearlyStats(_ world: inout World, year: Int) {
        let cCount = world.countries.count
        guard cCount > 0 else { return }

        var provCount = [Int](repeating: 0, count: cCount)
        var popSum = [Double](repeating: 0.0, count: cCount)
        for p in 0..<world.provinces.count {
            if let owner = world.provinces.owner[p], owner.index < cCount {
                provCount[owner.index] += 1
                popSum[owner.index] += world.provinces.population[p]
            }
        }

        var armySum = [Int](repeating: 0, count: cCount)
        for i in 0..<world.military.armies.count {
            guard world.military.armies.alive[i], !world.military.armies.isRebel[i] else { continue }
            let owner = world.military.armies.owner[i]
            if owner.index < cCount {
                var men = 0
                for reg in world.military.armies.regiments[i] {
                    men += reg.men
                }
                armySum[owner.index] += men
            }
        }

        var navySum = [Int](repeating: 0, count: cCount)
        for i in 0..<world.navy.fleets.count {
            guard world.navy.fleets.alive[i] else { continue }
            let owner = world.navy.fleets.owner[i]
            if owner.index < cCount {
                navySum[owner.index] += world.navy.fleets.shipIndices[i].count { world.navy.ships.alive[$0] }
            }
        }

        let startOffset = world.history.stats.countryIndex.count
        var recordedCount = 0

        for idx in 0..<cCount {
            guard provCount[idx] > 0 else { continue }
            let cid = CountryID(idx)
            let admin = world.tech.level(cid, .administrative)
            let diplo = world.tech.level(cid, .diplomatic)
            let mil = world.tech.level(cid, .military)

            world.history.stats.countryIndex.append(UInt16(clamping: idx))
            world.history.stats.population.append(Int(popSum[idx].rounded()))
            world.history.stats.incomeCents.append(Int((world.countries.lastMonthlyIncome[idx] * 100.0).rounded()))
            world.history.stats.armySize.append(armySum[idx])
            world.history.stats.navySize.append(navySum[idx])
            world.history.stats.techPacked.append(CountryStatsHistory.packTech(admin: admin, diplo: diplo, mil: mil))
            recordedCount += 1
        }

        world.history.stats.years.append(year)
        world.history.stats.yearStartOffsets.append(startOffset)
        world.history.stats.yearCounts.append(recordedCount)
    }

    private static func appendYearlyTimelapse(_ world: inout World, year: Int) {
        let pCount = world.provinces.count
        var currentOwner = [Int16](repeating: -1, count: pCount)
        var currentReligion = [UInt8](repeating: 0, count: pCount)

        for p in 0..<pCount {
            currentOwner[p] = world.provinces.owner[p].map { Int16(clamping: $0.index) } ?? -1
            currentReligion[p] = religionIndex(world.provinces.religion[p])
        }

        if world.history.timelapse.years.isEmpty {
            world.history.timelapse.years.append(year)
            world.history.timelapse.initialOwner = currentOwner
            world.history.timelapse.initialReligion = currentReligion
            world.history.timelapse.lastOwner = currentOwner
            world.history.timelapse.lastReligion = currentReligion
            return
        }

        // Diff against lastOwner / lastReligion
        let prevOwner = world.history.timelapse.lastOwner
        let prevReligion = world.history.timelapse.lastReligion

        let ownerStart = world.history.timelapse.ownerDeltaPairs.count
        var ownerPairCount = 0
        for p in 0..<pCount {
            let prev = p < prevOwner.count ? prevOwner[p] : -1
            if currentOwner[p] != prev {
                world.history.timelapse.ownerDeltaPairs.append(Int16(clamping: p))
                world.history.timelapse.ownerDeltaPairs.append(currentOwner[p])
                ownerPairCount += 2
            }
        }
        world.history.timelapse.ownerDeltaOffsets.append(ownerStart)
        world.history.timelapse.ownerDeltaCounts.append(ownerPairCount)

        let relStart = world.history.timelapse.religionDeltaPairs.count
        var relPairCount = 0
        for p in 0..<pCount {
            let prev = p < prevReligion.count ? prevReligion[p] : 0
            if currentReligion[p] != prev {
                world.history.timelapse.religionDeltaPairs.append(Int16(clamping: p))
                world.history.timelapse.religionDeltaPairs.append(Int16(currentReligion[p]))
                relPairCount += 2
            }
        }
        world.history.timelapse.religionDeltaOffsets.append(relStart)
        world.history.timelapse.religionDeltaCounts.append(relPairCount)

        world.history.timelapse.years.append(year)
        world.history.timelapse.lastOwner = currentOwner
        world.history.timelapse.lastReligion = currentReligion
    }
}
