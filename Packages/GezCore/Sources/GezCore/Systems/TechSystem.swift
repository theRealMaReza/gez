import Foundation

/// Tuning constants for monthly research speed (Phase 13, Part A).
public enum TechModel {
    /// Base monthly research per track even under a weak regency.
    public static let baseTrackGain = 0.50
    /// Monthly gain per point of the matching ruler skill (Stewardship / Diplomacy / Martial).
    public static let rulerSkillWeight = 0.25
    /// Monthly gain per point of the matching council seat (Steward / Chancellor / Marshal).
    public static let seatSkillWeight = 0.20
    /// Scale turning `CharacterSystem.learningPerYear` into shared monthly research points.
    public static let charLearningWeight = 0.50
    /// Shared monthly research points per College level (`bonus.learning`).
    public static let collegeLearningWeight = 0.30
    /// Shared monthly research bonus when capital market has 100% `paper` supply met.
    public static let paperSupplyWeight = 0.60
    /// Shared monthly research bonus when capital market has 100% `books` supply met.
    public static let booksSupplyWeight = 0.90
}

/// Breakdown of monthly research speed and effective cost for one track of one country.
public struct TechTrackBreakdown: Sendable, Equatable {
    public let track: TechTrack
    public let level: Int
    public let progress: Double
    public let baseGain: Double
    public let rulerSkillContrib: Double
    public let seatSkillContrib: Double
    public let sharedCharContrib: Double
    public let sharedCollegeContrib: Double
    public let sharedPaperContrib: Double
    public let sharedBooksContrib: Double
    public let govLearningMod: Double
    public let focusShare: Double
    public let sharedTrackGain: Double
    public let embracedInstitutions: Int
    public let institutionSpeedBonus: Double
    public let totalMonthlyGain: Double

    public let baseCost: Double
    public let neighbourLevelsAhead: Int
    public let neighbourBonusFraction: Double
    public let aheadOfTimeYears: Int
    public let aheadOfTimePenalty: Double
    public let institutionPenalty: Double
    public let effectiveCost: Double
}

/// Phase 13 technology research system: monthly progress per track, neighbour bonus,
/// ahead-of-time & institution cost modifiers, automatic advancement, and AI focus.
public enum TechSystem {

    // MARK: - Queries (Single-country breakdown for UI & tests)

    /// Supply fulfillment (0...1) of `goodKey` in `country`'s capital market.
    public static func capitalMarketSupply(_ world: World, for country: CountryID, goodKey: String) -> Double {
        guard let cap = world.countries.capital[country.index],
              let m = world.market(of: cap),
              let g = world.economy.goods.id(forKey: goodKey) else {
            return 0
        }
        let G = world.economy.goods.count
        let slot = m.index * G + g.index
        guard slot >= 0, slot < world.economy.markets.supply.count else { return 0 }
        let supply = world.economy.markets.supply[slot]
        guard supply > 0 else { return 0 }
        return max(0.0, min(1.0, world.economy.markets.met[slot]))
    }

    /// Sum of `learning` building bonuses (Colleges/Universities) in unoccupied provinces of `country`.
    public static func collegeLearningTotal(_ world: World, for country: CountryID) -> Double {
        let eco = world.economy
        let T = eco.buildings.typeCount
        var total = 0.0
        for p in 0..<world.provinces.count {
            guard world.provinces.owner[p] == country, world.provinces.occupiedBy[p] == nil else { continue }
            for t in 0..<T {
                if case .learning(let amount) = eco.buildingTypes[t].effect {
                    let lvl = eco.buildings.level[p * T + t]
                    if lvl > 0 {
                        total += amount * Double(lvl)
                    }
                }
            }
        }
        return total
    }

    /// Maximum levels any land/strait neighbour country is ahead of `country` in `track`.
    public static func neighbourLevelsAhead(_ world: World, for country: CountryID, track: TechTrack) -> Int {
        let myLevel = world.tech.level(country, track)
        var best = 0
        for p in 0..<world.provinces.count where world.provinces.owner[p] == country {
            for nb in world.provinces.neighbors[p] {
                if let nbOwner = world.provinces.owner[nb.index], nbOwner != country {
                    let diff = world.tech.level(nbOwner, track) - myLevel
                    if diff > best { best = diff }
                }
            }
        }
        return best
    }

    /// Cost penalty from active institutions that `country` has not embraced yet.
    public static func institutionCostPenalty(_ world: World, for country: CountryID, year: Int) -> Double {
        let params = world.techRules.params
        var total = 0.0
        for i in 0..<world.tech.institutionCount {
            guard world.tech.institutionSpawned[i] else { continue }
            guard !world.tech.hasEmbraced(country, institution: i) else { continue }
            let years = max(1, year - world.tech.institutionSpawnYear[i] + 1)
            let p = min(params.institutionPenaltyCap, Double(years) * params.institutionPenaltyPerYear)
            total += p
        }
        return total
    }

    /// Computes full research speed and cost breakdown for `country` on `track`.
    public static func breakdown(
        _ world: World,
        for country: CountryID,
        track: TechTrack,
        year: Int
    ) -> TechTrackBreakdown {
        let colLearning = collegeLearningTotal(world, for: country)
        let paper = capitalMarketSupply(world, for: country, goodKey: "paper")
        let books = capitalMarketSupply(world, for: country, goodKey: "books")
        let ahead = neighbourLevelsAhead(world, for: country, track: track)
        return computeBreakdown(
            world,
            country: country,
            track: track,
            year: year,
            collegeLearning: colLearning,
            paperMet: paper,
            booksMet: books,
            neighbourAhead: ahead
        )
    }

    private static func computeBreakdown(
        _ world: World,
        country: CountryID,
        track: TechTrack,
        year: Int,
        collegeLearning: Double,
        paperMet: Double,
        booksMet: Double,
        neighbourAhead: Int
    ) -> TechTrackBreakdown {
        let c = country.index
        let ch = world.people.characters
        let rulerSkill: Double
        if let r = world.countries.ruler[c] {
            rulerSkill = Double(ch.skill(r, track.rulerSkill))
        } else {
            rulerSkill = 0
        }
        let seatSkill: Double
        if let s = world.countries.council[c][track.councilSeat.rawValue], ch.isAlive(s) {
            seatSkill = Double(ch.skill(s, track.rulerSkill))
        } else {
            seatSkill = 0
        }

        let baseGain = TechModel.baseTrackGain
        let rulerContrib = rulerSkill * TechModel.rulerSkillWeight
        let seatContrib = seatSkill * TechModel.seatSkillWeight

        let sharedChar = CharacterSystem.learningPerYear(world, country) * TechModel.charLearningWeight
        let sharedCol = collegeLearning * TechModel.collegeLearningWeight
        let sharedPaper = paperMet * TechModel.paperSupplyWeight
        let sharedBooks = booksMet * TechModel.booksSupplyWeight

        let govMod = max(-0.5, world.government.modifier(country, .learning))
        let focusShare = world.tech.focus(of: country).share(for: track)
        let sharedPool = max(0, (sharedChar + sharedCol + sharedPaper + sharedBooks) * (1.0 + govMod))
        let sharedTrack = sharedPool * focusShare

        let embraced = world.tech.embracedCount(country)
        let instSpeedBonus = Double(embraced) * world.techRules.params.embracedResearchBonus
        let totalGain = (baseGain + rulerContrib + seatContrib + sharedTrack) * (1.0 + instSpeedBonus)

        let curLevel = world.tech.level(country, track)
        let params = world.techRules.params
        let nextDef = curLevel < TechRules.maxLevel ? world.techRules.levelDef(track, level: curLevel + 1) : nil
        let baseCost = nextDef?.baseCost ?? params.baseCost
        let clampedAhead = max(0, neighbourAhead)
        let nbBonus = min(params.neighbourBonusCap, Double(clampedAhead) * params.neighbourBonusPerLevel)
        let aotYears = nextDef.map { max(0, $0.targetYear - year) } ?? 0
        let aotPenalty = min(params.aheadOfTimeCap, Double(aotYears) * params.aheadOfTimePerYear)
        let instPenalty = institutionCostPenalty(world, for: country, year: year)
        let costMult = max(0.25, 1.0 - nbBonus + aotPenalty + instPenalty)
        let effectiveCost = (baseCost * costMult).rounded()

        return TechTrackBreakdown(
            track: track,
            level: curLevel,
            progress: world.tech.progress(country, track),
            baseGain: baseGain,
            rulerSkillContrib: rulerContrib,
            seatSkillContrib: seatContrib,
            sharedCharContrib: sharedChar,
            sharedCollegeContrib: sharedCol,
            sharedPaperContrib: sharedPaper,
            sharedBooksContrib: sharedBooks,
            govLearningMod: govMod,
            focusShare: focusShare,
            sharedTrackGain: sharedTrack,
            embracedInstitutions: embraced,
            institutionSpeedBonus: instSpeedBonus,
            totalMonthlyGain: totalGain,
            baseCost: baseCost,
            neighbourLevelsAhead: clampedAhead,
            neighbourBonusFraction: nbBonus,
            aheadOfTimeYears: aotYears,
            aheadOfTimePenalty: aotPenalty,
            institutionPenalty: instPenalty,
            effectiveCost: effectiveCost
        )
    }

    // MARK: - Monthly Tick

    /// Monthly technology tick: computes research speed, advances tracks, levels up when full,
    /// and updates AI research focus.
    public static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) {
        let C = world.countries.count
        let P = world.provinces.count
        guard C > 0, world.tech.countryCount == C, !world.techRules.tracks.isEmpty else { return }

        // 1. Precompute per-country College learning in one province pass.
        var collegeLearning = [Double](repeating: 0, count: C)
        let eco = world.economy
        let T = eco.buildings.typeCount
        let learningBuildingTypes: [(index: Int, amount: Double)] = (0..<T).compactMap { t in
            if case .learning(let amount) = eco.buildingTypes[t].effect { return (t, amount) }
            return nil
        }
        if !learningBuildingTypes.isEmpty {
            for p in 0..<P {
                guard let owner = world.provinces.owner[p], world.provinces.occupiedBy[p] == nil else { continue }
                let c = owner.index
                for item in learningBuildingTypes {
                    let lvl = eco.buildings.level[p * T + item.index]
                    if lvl > 0 {
                        collegeLearning[c] += item.amount * Double(lvl)
                    }
                }
            }
        }

        // 2. Precompute per-country max neighbour level per track in one province-edge pass.
        var neighbourMax = [Int](repeating: 0, count: C * TechRules.trackCount)
        for c in 0..<C {
            for t in 0..<TechRules.trackCount {
                neighbourMax[c * TechRules.trackCount + t] = world.tech.levels[c * TechRules.trackCount + t]
            }
        }
        for p in 0..<P {
            guard let owner = world.provinces.owner[p] else { continue }
            let o = owner.index
            for nb in world.provinces.neighbors[p] {
                guard let nbOwner = world.provinces.owner[nb.index], nbOwner != owner else { continue }
                let no = nbOwner.index
                for t in 0..<TechRules.trackCount {
                    let nbLvl = world.tech.levels[no * TechRules.trackCount + t]
                    let slot = o * TechRules.trackCount + t
                    if nbLvl > neighbourMax[slot] {
                        neighbourMax[slot] = nbLvl
                    }
                }
            }
        }

        // 3. Precompute paper & books fulfillment per market once.
        let M = eco.markets.count
        let G = eco.goods.count
        var paperByMarket = [Double](repeating: 0, count: M)
        var booksByMarket = [Double](repeating: 0, count: M)
        if M > 0, G > 0 {
            let paperIdx = eco.goods.id(forKey: "paper")?.index
            let booksIdx = eco.goods.id(forKey: "books")?.index
            for m in 0..<M {
                if let pi = paperIdx {
                    let s = m * G + pi
                    if s < eco.markets.supply.count && eco.markets.supply[s] > 0 {
                        paperByMarket[m] = max(0, min(1, eco.markets.met[s]))
                    }
                }
                if let bi = booksIdx {
                    let s = m * G + bi
                    if s < eco.markets.supply.count && eco.markets.supply[s] > 0 {
                        booksByMarket[m] = max(0, min(1, eco.markets.met[s]))
                    }
                }
            }
        }

        // 4. Determine countries currently at war (for AI focus).
        var atWar = [Bool](repeating: false, count: C)
        for w in world.diplomacy.wars {
            for a in w.attackers where a.index < C { atWar[a.index] = true }
            for d in w.defenders where d.index < C { atWar[d.index] = true }
        }

        // 5. Advance each country's three tracks.
        for c in world.countries.ids {
            let ci = c.index
            let paperMet: Double
            let booksMet: Double
            if let cap = world.countries.capital[ci], let m = world.market(of: cap), m.index < M {
                paperMet = paperByMarket[m.index]
                booksMet = booksByMarket[m.index]
            } else {
                paperMet = 0
                booksMet = 0
            }

            var leveledUp = false
            for track in TechTrack.allCases {
                let slot = ci * TechRules.trackCount + track.rawValue
                let curLvl = world.tech.levels[slot]
                let ahead = max(0, neighbourMax[slot] - curLvl)
                let bd = computeBreakdown(
                    world,
                    country: c,
                    track: track,
                    year: date.year,
                    collegeLearning: collegeLearning[ci],
                    paperMet: paperMet,
                    booksMet: booksMet,
                    neighbourAhead: ahead
                )
                world.tech.lastMonthlyGain[slot] = bd.totalMonthlyGain
                if curLvl >= TechRules.maxLevel {
                    world.tech.progress[slot] = 0
                    continue
                }
                world.tech.progress[slot] += bd.totalMonthlyGain
                if world.tech.progress[slot] >= bd.effectiveCost {
                    let newLevel = curLvl + 1
                    world.tech.levels[slot] = newLevel
                    let excess = max(0, world.tech.progress[slot] - bd.effectiveCost)
                    world.tech.progress[slot] = min(excess, bd.baseCost * 0.5)
                    leveledUp = true
                    let summary = world.techRules.levelDef(track, level: newLevel)?.summary ?? ""
                    let cname = world.countries.name[ci]
                    world.tech.addNote(TechNote(
                        date: date,
                        country: c,
                        kind: .levelUp,
                        track: track,
                        level: newLevel,
                        text: "\(cname) reached \(track.displayName) Tech \(newLevel): \(summary)"
                    ))
                }
            }

            // AI chooses a sensible research focus periodically or on level-up.
            if !world.humanCountries.contains(c) && (leveledUp || ci % 12 == date.month % 12) {
                chooseAIFocus(&world, country: c, atWar: atWar[ci], neighbourMax: neighbourMax)
            }
        }
    }

    private static func chooseAIFocus(
        _ world: inout World,
        country: CountryID,
        atWar: Bool,
        neighbourMax: [Int]
    ) {
        let ci = country.index
        let adm = world.tech.level(country, .administrative)
        let dip = world.tech.level(country, .diplomatic)
        let mil = world.tech.level(country, .military)

        let milAhead = neighbourMax[ci * TechRules.trackCount + TechTrack.military.rawValue] - mil
        let dipAhead = neighbourMax[ci * TechRules.trackCount + TechTrack.diplomatic.rawValue] - dip
        let admAhead = neighbourMax[ci * TechRules.trackCount + TechTrack.administrative.rawValue] - adm

        if atWar || milAhead >= 1 || mil < adm && mil < dip {
            world.tech.setFocus(of: country, to: .military)
        } else if (dipAhead >= 1 || !world.navy.fleets(of: country).isEmpty) && dip <= adm {
            world.tech.setFocus(of: country, to: .diplomatic)
        } else if admAhead >= 1 || adm < mil || adm < dip {
            world.tech.setFocus(of: country, to: .administrative)
        } else {
            world.tech.setFocus(of: country, to: .balanced)
        }
    }
}
