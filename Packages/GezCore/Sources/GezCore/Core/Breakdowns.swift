import Foundation

/// A single signed line item inside a simulation breakdown tooltip.
public struct BreakdownEntry: Sendable, Equatable {
    public let label: String
    public let value: Double
    public let formattedValue: String

    public init(label: String, value: Double, formattedValue: String) {
        self.label = label
        self.value = value
        self.formattedValue = formattedValue
    }
}

/// Complete, simulation-backed breakdown report whose `entries` sum to `total`.
public struct BreakdownReport: Sendable, Equatable {
    public let title: String
    public let entries: [BreakdownEntry]
    public let total: Double
    public let formattedTotal: String
    public let notes: [String]

    public init(
        title: String,
        entries: [BreakdownEntry],
        total: Double,
        formattedTotal: String,
        notes: [String] = []
    ) {
        self.title = title
        self.entries = entries
        self.total = total
        self.formattedTotal = formattedTotal
        self.notes = notes
    }
}

/// Pure-Swift query helpers producing exact, self-consistent breakdowns from live `World` state.
public enum Breakdowns {

    // MARK: - Formatting helpers

    private static func signedDucats(_ v: Double) -> String {
        if abs(v) < 0.005 { return "0.0" }
        return String(format: "%+.1f", v)
    }

    private static func signedInt(_ v: Double) -> String {
        let r = Int(v.rounded())
        return r >= 0 ? "+\(r)" : "\(r)"
    }

    private static func signedTwoDecimals(_ v: Double) -> String {
        if abs(v) < 0.0005 { return "+0.00" }
        return String(format: "%+.2f", v)
    }

    private static func signedOneDecimal(_ v: Double) -> String {
        if abs(v) < 0.05 { return "+0.0" }
        return String(format: "%+.1f", v)
    }

    // MARK: - 1. Monthly Income & Balance

    public static func monthlyIncome(_ world: World, for country: CountryID) -> BreakdownReport {
        let c = country.index
        guard c >= 0, c < world.countries.count else {
            return BreakdownReport(title: "Monthly Balance", entries: [], total: 0, formattedTotal: "0.0 / mo")
        }

        let tax = world.countries.lastTax[c]
        let vassalTax = world.countries.lastVassalTax[c]
        let trade = world.countries.lastTrade[c]
        let tolls = world.countries.lastTolls[c]
        let debase = c < world.countries.lastDebaseIncome.count ? world.countries.lastDebaseIncome[c] : 0.0
        let warRepsIn = c < world.countries.lastWarRepsIn.count ? world.countries.lastWarRepsIn[c] : 0.0

        let buildingUpkeep = world.countries.lastUpkeep[c]
        let armyUpkeep = world.military.lastArmyUpkeep[c]
        let navyUpkeep = c < world.navy.lastNavyUpkeep.count ? world.navy.lastNavyUpkeep[c] : 0.0
        let interest = world.countries.lastInterest[c]
        let warRepsOut = c < world.countries.lastWarRepsOut.count ? world.countries.lastWarRepsOut[c] : 0.0
        let slotUpkeep = c < world.countries.lastSlotUpkeep.count ? world.countries.lastSlotUpkeep[c] : 0.0

        let totalIncome = world.countries.lastMonthlyIncome[c] + debase
        let totalExpenses = world.countries.lastMonthlyExpenses[c]
        let net = totalIncome - totalExpenses

        var entries: [BreakdownEntry] = []
        for tc in TaxClass.allCases {
            let amt = tax[tc.rawValue]
            entries.append(BreakdownEntry(
                label: "Tax: \(tc.socialClass.displayName)",
                value: amt,
                formattedValue: signedDucats(amt)
            ))
        }
        if vassalTax > 0.001 {
            entries.append(BreakdownEntry(
                label: "Kept by vassals",
                value: -vassalTax,
                formattedValue: signedDucats(-vassalTax)
            ))
        }
        entries.append(BreakdownEntry(label: "Merchants (trade)", value: trade, formattedValue: signedDucats(trade)))
        entries.append(BreakdownEntry(label: "Market tolls", value: tolls, formattedValue: signedDucats(tolls)))
        if debase > 0.001 {
            entries.append(BreakdownEntry(label: "Debased coin", value: debase, formattedValue: signedDucats(debase)))
        }
        if warRepsIn > 0.001 {
            entries.append(BreakdownEntry(label: "War reparations received", value: warRepsIn, formattedValue: signedDucats(warRepsIn)))
        }
        entries.append(BreakdownEntry(label: "Building upkeep", value: -buildingUpkeep, formattedValue: signedDucats(-buildingUpkeep)))
        entries.append(BreakdownEntry(label: "Army upkeep", value: -armyUpkeep, formattedValue: signedDucats(-armyUpkeep)))
        if navyUpkeep > 0.001 {
            entries.append(BreakdownEntry(label: "Navy upkeep", value: -navyUpkeep, formattedValue: signedDucats(-navyUpkeep)))
        }
        if interest > 0.001 {
            entries.append(BreakdownEntry(label: "Loan interest", value: -interest, formattedValue: signedDucats(-interest)))
        }
        if warRepsOut > 0.001 {
            entries.append(BreakdownEntry(label: "War reparations paid", value: -warRepsOut, formattedValue: signedDucats(-warRepsOut)))
        }
        if slotUpkeep > 0.001 {
            entries.append(BreakdownEntry(label: "Over relation limit", value: -slotUpkeep, formattedValue: signedDucats(-slotUpkeep)))
        }

        // Reconcile any residual from legacy saves so parts always sum to net.
        let sumSoFar = entries.reduce(0.0) { $0 + $1.value }
        let residual = net - sumSoFar
        if abs(residual) > 0.001 {
            entries.append(BreakdownEntry(
                label: "Other adjustments",
                value: residual,
                formattedValue: signedDucats(residual)
            ))
        }

        var notes = [
            String(format: "Treasury: %.1f ducats", world.countries.treasury[c]),
            String(format: "Gross income: +%.1f · Expenses: -%.1f", totalIncome, totalExpenses)
        ]
        if world.countries.bankruptMonthsLeft[c] > 0 {
            notes.append("Bankrupt: -25% income for \(world.countries.bankruptMonthsLeft[c]) more months")
        }
        if world.countries.inflation[c] >= 0.005 {
            notes.append(String(format: "Inflation: %.1f%% (raises building & recruitment costs)", world.countries.inflation[c] * 100.0))
        }

        return BreakdownReport(
            title: "Monthly Balance",
            entries: entries,
            total: net,
            formattedTotal: String(format: "%+.1f / mo", net),
            notes: notes
        )
    }

    // MARK: - 2. Manpower & Sailors

    public static func manpower(_ world: World, for country: CountryID) -> BreakdownReport {
        let c = country.index
        guard c >= 0, c < world.countries.count else {
            return BreakdownReport(title: "Manpower Cap", entries: [], total: 0, formattedTotal: "0")
        }
        let comp = ArmySystem.manpowerComponents(world, country)
        var entries: [BreakdownEntry] = []
        if comp.maxManpower > 0 {
            entries.append(BreakdownEntry(
                label: "From population (culture-weighted)",
                value: comp.popBase,
                formattedValue: signedInt(comp.popBase)
            ))
            if comp.barracksMen > 0 {
                entries.append(BreakdownEntry(
                    label: "Barracks & military buildings",
                    value: comp.barracksMen,
                    formattedValue: signedInt(comp.barracksMen)
                ))
            }
            if abs(comp.govMod) > 0.0005 {
                let delta = comp.rawBase * comp.govMod
                entries.append(BreakdownEntry(
                    label: String(format: "Laws, estates & reforms (%+.0f%%)", comp.govMod * 100.0),
                    value: delta,
                    formattedValue: signedInt(delta)
                ))
            }
            if abs(comp.marshalMod) > 0.0005 {
                let delta = comp.rawBase * comp.marshalMod
                entries.append(BreakdownEntry(
                    label: String(format: "Marshal skill (%+.1f%%)", comp.marshalMod * 100.0),
                    value: delta,
                    formattedValue: signedInt(delta)
                ))
            }
            if comp.clampedFactor > comp.combinedFactor + 0.0005 {
                let clampAdj = comp.rawBase * (comp.clampedFactor - comp.combinedFactor)
                entries.append(BreakdownEntry(
                    label: "Minimum 25% manpower floor",
                    value: clampAdj,
                    formattedValue: signedInt(clampAdj)
                ))
            }
            let floorAdj = comp.maxManpower - comp.unroundedMax
            if abs(floorAdj) > 0.01 {
                entries.append(BreakdownEntry(
                    label: comp.unroundedMax < 500 ? "Minimum realm floor (500)" : "Rounding",
                    value: floorAdj,
                    formattedValue: signedInt(floorAdj)
                ))
            }
        }

        let currentPool = Int(world.military.manpower[c].rounded())
        let maxStored = Int(world.military.maxManpower[c].rounded())
        let gain = Int(ArmySystem.monthlyManpowerGain(world, country).rounded())
        var notes = [
            "Current pool: \(currentPool) / \(maxStored) men",
            gain > 0
                ? "Monthly recovery: +\(gain)/mo (refills over \(Int(ArmyModel.manpowerRecoveryMonths)) months)"
                : "Monthly recovery: +0/mo (pool at maximum)"
        ]
        if comp.excludedVassalProvinces > 0 {
            notes.append("\(comp.excludedVassalProvinces) province(s) held by tax-refusing vassals excluded")
        }

        return BreakdownReport(
            title: "Maximum Manpower",
            entries: entries,
            total: comp.maxManpower,
            formattedTotal: "\(Int(comp.maxManpower.rounded())) men",
            notes: notes
        )
    }

    public static func sailors(_ world: World, for country: CountryID) -> BreakdownReport {
        let c = country.index
        guard c >= 0, c < world.countries.count else {
            return BreakdownReport(title: "Sailors Cap", entries: [], total: 0, formattedTotal: "0")
        }
        let comp = NavySystem.sailorComponents(world, country)
        var entries: [BreakdownEntry] = []
        if comp.hasCoast {
            entries.append(BreakdownEntry(
                label: "Coastal peasants & burghers",
                value: comp.coastalPopBase,
                formattedValue: signedInt(comp.coastalPopBase)
            ))
            if comp.dockBonus > 0 {
                entries.append(BreakdownEntry(
                    label: "Docks & shipyards",
                    value: comp.dockBonus,
                    formattedValue: signedInt(comp.dockBonus)
                ))
            }
            if abs(comp.floorDelta) > 0.01 {
                entries.append(BreakdownEntry(
                    label: comp.maxSailors <= 200.5 ? "Minimum coastal floor" : "Rounding",
                    value: comp.floorDelta,
                    formattedValue: signedInt(comp.floorDelta)
                ))
            }
        }
        let pool = Int(world.navy.sailors[c].rounded())
        let maxS = Int(world.navy.maxSailors[c].rounded())
        let gain = Int(NavySystem.monthlySailorGain(world, country).rounded())
        let notes = comp.hasCoast ? [
            "Current pool: \(pool) / \(maxS) sailors",
            gain > 0 ? "Monthly recovery: +\(gain)/mo" : "Monthly recovery: +0/mo (at maximum)"
        ] : ["No un-occupied coastal provinces"]

        return BreakdownReport(
            title: "Maximum Sailors",
            entries: entries,
            total: comp.maxSailors,
            formattedTotal: "\(Int(comp.maxSailors.rounded())) sailors",
            notes: notes
        )
    }

    // MARK: - 3. Army Morale

    public static func armyMorale(_ world: World, army armyID: ArmyID) -> BreakdownReport {
        let idx = Int(armyID.rawValue)
        guard idx >= 0, idx < world.military.armies.count, world.military.armies.alive[idx] else {
            return BreakdownReport(title: "Army Morale", entries: [], total: 0, formattedTotal: "0.00")
        }
        let owner = world.military.armies.owner[idx]
        let techBonus = world.techEffects(owner, track: .military).landMorale
        let regs = world.military.armies.regiments[idx]

        var totalMen = 0
        var weightedCurrent = 0.0
        var weightedBase = 0.0
        var routingCount = 0
        for reg in regs {
            let u = world.military.unit(reg.type)
            let w = max(1, reg.men)
            totalMen += reg.men
            weightedCurrent += reg.morale * Double(w)
            weightedBase += u.morale * Double(w)
            if reg.morale <= 0.15 { routingCount += 1 }
        }
        let denom = Double(regs.reduce(0) { $0 + max(1, $1.men) })
        let avgCurrent = denom > 0 ? weightedCurrent / denom : 0.0
        let avgBase = denom > 0 ? weightedBase / denom : 0.0
        let maxMorale = avgBase + techBonus

        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Regiment base morale (weighted)", value: avgBase, formattedValue: String(format: "%.2f", avgBase))
        ]
        if abs(techBonus) > 0.0005 {
            entries.append(BreakdownEntry(
                label: "Military Technology bonus",
                value: techBonus,
                formattedValue: signedTwoDecimals(techBonus)
            ))
        }

        var notes = [
            String(format: "Current morale: %.2f / %.2f (%.0f%%)", avgCurrent, maxMorale, maxMorale > 0 ? (avgCurrent / maxMorale) * 100.0 : 0.0),
            "Recovers +0.50/mo when within supply limit outside battle",
            "Total men: \(totalMen) across \(regs.count) regiment(s)"
        ]
        if routingCount > 0 {
            notes.append("\(routingCount) regiment(s) shattered / low morale")
        }

        return BreakdownReport(
            title: "Maximum Army Morale",
            entries: entries,
            total: maxMorale,
            formattedTotal: String(format: "%.2f", maxMorale),
            notes: notes
        )
    }

    // MARK: - 4. Siege Progress

    public static func siege(_ world: World, in province: ProvinceID) -> BreakdownReport {
        let p = province.index
        guard p >= 0, p < world.provinces.count,
              let siege = world.military.siege(in: province) else {
            return BreakdownReport(title: "Siege Progress", entries: [], total: 0, formattedTotal: "0")
        }
        let fortLevel = world.provinces.fortLevel[p]
        let armies = SiegeSystem.besiegers(in: province, attacker: siege.besieger, world: world)
        let mods = SiegeSystem.phaseModifiers(world, siege: siege, hostileArmies: armies, fortLevel: fortLevel)

        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Accumulated siege progress", value: Double(siege.progress), formattedValue: signedInt(Double(siege.progress))),
            BreakdownEntry(label: "Fort level (-\(fortLevel))", value: Double(mods.fortLevelPenalty), formattedValue: signedInt(Double(mods.fortLevelPenalty)))
        ]
        if mods.artilleryBonus != 0 {
            entries.append(BreakdownEntry(label: "Artillery bombardment", value: Double(mods.artilleryBonus), formattedValue: signedInt(Double(mods.artilleryBonus))))
        }
        if mods.commanderBonus != 0 {
            entries.append(BreakdownEntry(label: "Commander Martial", value: Double(mods.commanderBonus), formattedValue: signedInt(Double(mods.commanderBonus))))
        }
        if mods.breachBonus != 0 {
            entries.append(BreakdownEntry(label: "Walls breached", value: Double(mods.breachBonus), formattedValue: signedInt(Double(mods.breachBonus))))
        }
        if mods.coastalPenalty != 0 {
            entries.append(BreakdownEntry(label: "Unblockaded coastal port", value: Double(mods.coastalPenalty), formattedValue: signedInt(Double(mods.coastalPenalty))))
        }
        if mods.clampDelta != 0 {
            entries.append(BreakdownEntry(label: "Minimum modifier floor (-7)", value: Double(mods.clampDelta), formattedValue: signedInt(Double(mods.clampDelta))))
        }

        let totalBonus = Double(mods.effectiveModifier + siege.progress)
        let garrison = world.provinces.fortGarrison[p]
        let maxGarrison = world.provinces.maxGarrison(of: province)
        var notes = [
            "Next phase in \(siege.phaseDaysRemaining) days (rolls 1–14 + \(Int(totalBonus)); surrenders at \(SiegeSystem.surrenderThreshold)+)",
            "Garrison: \(garrison) / \(maxGarrison) men"
        ]
        if let outcome = siege.lastOutcome, let roll = siege.lastRoll {
            notes.append("Last phase roll: \(roll) (\(siege.lastModifier >= 0 ? "+\(siege.lastModifier)" : "\(siege.lastModifier)")) -> \(outcome.rawValue)")
        }

        return BreakdownReport(
            title: "Siege Roll Modifier",
            entries: entries,
            total: totalBonus,
            formattedTotal: signedInt(totalBonus),
            notes: notes
        )
    }

    // MARK: - 5. Stability & Unrest

    public static func stability(_ world: World, for country: CountryID) -> BreakdownReport {
        let c = country.index
        guard c >= 0, c < world.government.count else {
            return BreakdownReport(title: "Stability", entries: [], total: 0, formattedTotal: "0")
        }
        let s = world.government.stability[c]
        let comp = GovernmentSystem.stabilityCostComponents(world, country)

        let rawAfterStab = comp.base * comp.stabilityScaling
        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Base cost (2 mo income, min 25)", value: comp.base, formattedValue: String(format: "%.1f", comp.base))
        ]
        let stabDelta = rawAfterStab - comp.base
        if abs(stabDelta) > 0.01 {
            entries.append(BreakdownEntry(
                label: "Current stability (+\(max(0, s) * 50)%)",
                value: stabDelta,
                formattedValue: signedDucats(stabDelta)
            ))
        }
        if abs(comp.lawMod) > 0.0005 {
            let delta = rawAfterStab * comp.lawMod
            entries.append(BreakdownEntry(
                label: String(format: "Laws & reforms (%+.0f%%)", comp.lawMod * 100.0),
                value: delta,
                formattedValue: signedDucats(delta)
            ))
        }
        if comp.holyDiscount > 0.0005 {
            let delta = -rawAfterStab * comp.holyDiscount
            entries.append(BreakdownEntry(
                label: "Held holy sites (\(comp.holySiteCount), -\(Int((comp.holyDiscount * 100).rounded()))%)",
                value: delta,
                formattedValue: signedDucats(delta)
            ))
        }
        let unClamped = rawAfterStab * (1.0 + comp.lawMod - comp.holyDiscount)
        let clampAdj = comp.total - unClamped
        if abs(clampAdj) > 0.01 {
            entries.append(BreakdownEntry(
                label: "Minimum 30% cost floor",
                value: clampAdj,
                formattedValue: signedDucats(clampAdj)
            ))
        }

        let taxPct = Double(s) * GovernmentModel.stabilityTax * 100.0
        let moodPct = Double(s) * GovernmentModel.stabilityMood * 100.0
        let refRate = Double(s) * GovernmentModel.stabilityReform
        let notes = [
            "Current Stability: \(s > 0 ? "+\(s)" : "\(s)") (range -3 to +3)",
            String(format: "Active effects: Tax %+.0f%% · Contentment %+.0f%% · Reform %+.2f/mo", taxPct, moodPct, refRate),
            "Drops on: minor/no heir succession, succession law change, revoked privilege, estate seizure, bankruptcy"
        ]

        return BreakdownReport(
            title: "Cost to Raise Stability",
            entries: entries,
            total: comp.total,
            formattedTotal: String(format: "%.0f ducats", comp.total),
            notes: notes
        )
    }

    public static func unrest(_ world: World, in province: ProvinceID, date: GameDate) -> BreakdownReport {
        let p = province.index
        guard p >= 0, p < world.provinces.count else {
            return BreakdownReport(title: "Province Unrest", entries: [], total: 0, formattedTotal: "0.0")
        }
        let pts = UnrestSystem.points(world, p, UnrestContext(world, date: date))
        let target = UnrestSystem.target(pts)
        let rawSum = pts.reduce(0, +)

        var entries: [BreakdownEntry] = UnrestCause.allCases
            .map { (cause: $0, val: pts[$0.rawValue]) }
            .filter { abs($0.val) >= 0.05 }
            .sorted { abs($0.val) > abs($1.val) }
            .map { BreakdownEntry(label: $0.cause.displayName, value: $0.val, formattedValue: signedOneDecimal($0.val)) }

        let clampAdj = target - entries.reduce(0.0) { $0 + $1.value }
        if abs(clampAdj) >= 0.05 {
            entries.append(BreakdownEntry(
                label: rawSum < 0 ? "0 minimum floor" : (rawSum > 100 ? "100 maximum cap" : "Minor causes"),
                value: clampAdj,
                formattedValue: signedOneDecimal(clampAdj)
            ))
        }

        let current = world.unrest.unrest(p)
        let notes = [
            String(format: "Current unrest: %.1f / 100 (drifts 30%%/mo toward %.1f)", current, target)
        ]

        return BreakdownReport(
            title: "Target Unrest",
            entries: entries,
            total: target,
            formattedTotal: String(format: "%.1f / 100", target),
            notes: notes
        )
    }

    // MARK: - 6. Research Speed & Tech Cost

    public static func researchSpeed(
        _ world: World,
        for country: CountryID,
        track: TechTrack,
        year: Int
    ) -> BreakdownReport {
        let b = TechSystem.breakdown(world, for: country, track: track, year: year)
        let f = b.focusShare
        let rawShared = b.sharedCharContrib + b.sharedCollegeContrib + b.sharedPaperContrib + b.sharedBooksContrib
        let sharedAfterLaw = max(0.0, rawShared * (1.0 + b.govLearningMod))
        let preInstSum = b.baseGain + b.rulerSkillContrib + b.seatSkillContrib + b.sharedTrackGain

        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Base research", value: b.baseGain, formattedValue: signedTwoDecimals(b.baseGain)),
            BreakdownEntry(label: "Ruler \(track.rulerSkill.displayName)", value: b.rulerSkillContrib, formattedValue: signedTwoDecimals(b.rulerSkillContrib)),
            BreakdownEntry(label: "Council (\(track.councilSeat.displayName))", value: b.seatSkillContrib, formattedValue: signedTwoDecimals(b.seatSkillContrib))
        ]
        if b.sharedCharContrib > 1e-6 {
            let v = b.sharedCharContrib * f
            entries.append(BreakdownEntry(label: "Court Learning (\(Int((f * 100).rounded()))% focus)", value: v, formattedValue: signedTwoDecimals(v)))
        }
        if b.sharedCollegeContrib > 1e-6 {
            let v = b.sharedCollegeContrib * f
            entries.append(BreakdownEntry(label: "Colleges & Universities", value: v, formattedValue: signedTwoDecimals(v)))
        }
        if b.sharedPaperContrib > 1e-6 {
            let v = b.sharedPaperContrib * f
            entries.append(BreakdownEntry(label: "Capital Paper supply", value: v, formattedValue: signedTwoDecimals(v)))
        }
        if b.sharedBooksContrib > 1e-6 {
            let v = b.sharedBooksContrib * f
            entries.append(BreakdownEntry(label: "Capital Books supply", value: v, formattedValue: signedTwoDecimals(v)))
        }
        let lawDelta = (sharedAfterLaw - rawShared) * f
        if abs(lawDelta) > 1e-6 {
            entries.append(BreakdownEntry(
                label: String(format: "Learning laws (%+.0f%%)", b.govLearningMod * 100.0),
                value: lawDelta,
                formattedValue: signedTwoDecimals(lawDelta)
            ))
        }
        if b.institutionSpeedBonus > 1e-6 {
            let instDelta = preInstSum * b.institutionSpeedBonus
            entries.append(BreakdownEntry(
                label: "Embraced institutions (\(b.embracedInstitutions) × +5%)",
                value: instDelta,
                formattedValue: signedTwoDecimals(instDelta)
            ))
        }

        let notes = [
            String(format: "Current level: %d / %d (%.1f / %.0f pts)", b.level, TechRules.maxLevel, b.progress, b.effectiveCost),
            "Focus share on \(track.shortName): \(Int((b.focusShare * 100).rounded()))%"
        ]

        return BreakdownReport(
            title: "\(track.displayName) Research Speed",
            entries: entries,
            total: b.totalMonthlyGain,
            formattedTotal: String(format: "+%.2f / mo", b.totalMonthlyGain),
            notes: notes
        )
    }

    public static func techCost(
        _ world: World,
        for country: CountryID,
        track: TechTrack,
        year: Int
    ) -> BreakdownReport {
        let b = TechSystem.breakdown(world, for: country, track: track, year: year)
        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Base level cost", value: b.baseCost, formattedValue: String(format: "%.0f", b.baseCost))
        ]
        if b.neighbourBonusFraction > 0.0005 {
            let val = -b.baseCost * b.neighbourBonusFraction
            entries.append(BreakdownEntry(
                label: "Neighbour bonus (\(b.neighbourLevelsAhead) ahead, -\(Int((b.neighbourBonusFraction * 100).rounded()))%)",
                value: val,
                formattedValue: signedOneDecimal(val)
            ))
        }
        if b.aheadOfTimePenalty > 0.0005 {
            let val = b.baseCost * b.aheadOfTimePenalty
            entries.append(BreakdownEntry(
                label: "Ahead of time (\(b.aheadOfTimeYears) yr, +\(Int((b.aheadOfTimePenalty * 100).rounded()))%)",
                value: val,
                formattedValue: signedOneDecimal(val)
            ))
        }
        if b.institutionPenalty > 0.0005 {
            let val = b.baseCost * b.institutionPenalty
            entries.append(BreakdownEntry(
                label: "Unembraced institutions (+\(Int((b.institutionPenalty * 100).rounded()))%)",
                value: val,
                formattedValue: signedOneDecimal(val)
            ))
        }
        let sumSoFar = entries.reduce(0.0) { $0 + $1.value }
        let adj = b.effectiveCost - sumSoFar
        if abs(adj) > 0.001 {
            entries.append(BreakdownEntry(
                label: adj > 0 ? "Minimum cost floor / rounding" : "Rounding",
                value: adj,
                formattedValue: signedOneDecimal(adj)
            ))
        }

        return BreakdownReport(
            title: "\(track.displayName) Tech Cost",
            entries: entries,
            total: b.effectiveCost,
            formattedTotal: String(format: "%.0f pts", b.effectiveCost),
            notes: []
        )
    }

    // MARK: - 7. Diplomatic Relations & Relation Slots

    public static func relations(_ world: World, of target: CountryID, by observer: CountryID) -> BreakdownReport {
        let actual = world.diplomacy.opinion(of: target, by: observer)
        guard observer != target,
              observer.index < world.countries.count,
              target.index < world.countries.count else {
            return BreakdownReport(title: "Relations", entries: [], total: Double(actual), formattedTotal: "\(actual)")
        }

        var entries: [BreakdownEntry] = []
        for factor in Diplomacy.baselineOpinionFactors(of: target, by: observer, in: world) {
            entries.append(BreakdownEntry(
                label: factor.label,
                value: Double(factor.value),
                formattedValue: signedInt(Double(factor.value))
            ))
        }

        if world.diplomacy.areAllies(observer, target) {
            entries.append(BreakdownEntry(label: "Alliance", value: 50, formattedValue: "+50"))
        }
        if world.diplomacy.hasTreaty(.guarantee, between: observer, and: target)
            || world.diplomacy.hasTreaty(.guarantee, between: target, and: observer) {
            entries.append(BreakdownEntry(label: "Guarantee", value: 25, formattedValue: "+25"))
        }
        if world.diplomacy.hasTreaty(.nonAggression, between: observer, and: target) {
            entries.append(BreakdownEntry(label: "Non-Aggression Pact", value: 15, formattedValue: "+15"))
        }
        if world.diplomacy.hasTreaty(.militaryAccess, between: observer, and: target)
            || world.diplomacy.hasTreaty(.militaryAccess, between: target, and: observer) {
            entries.append(BreakdownEntry(label: "Military Access", value: 10, formattedValue: "+10"))
        }
        if world.diplomacy.hasTruce(observer, target) {
            entries.append(BreakdownEntry(label: "Truce", value: -15, formattedValue: "-15"))
        }

        let baselineSum = Int(entries.reduce(0.0) { $0 + $1.value }.rounded())
        let residual = actual - baselineSum
        if residual != 0 {
            let ae = Int(world.diplomacy.aggressiveExpansion(of: target, by: observer).rounded())
            let label: String
            if world.diplomacy.isAtWar(observer, target) {
                label = "At war, AE & diplomatic history"
            } else if ae > 0 {
                label = "Diplomatic actions, events & AE (\(ae))"
            } else {
                label = "Diplomatic actions & events"
            }
            entries.append(BreakdownEntry(
                label: label,
                value: Double(residual),
                formattedValue: signedInt(Double(residual))
            ))
        }

        let trust = world.diplomacy.trust(of: target, by: observer)
        let ae = Int(world.diplomacy.aggressiveExpansion(of: target, by: observer).rounded())
        let obsName = world.countries.name[observer.index]
        let tgtName = world.countries.name[target.index]
        var notes = [
            "\(obsName)'s Trust of \(tgtName): \(trust) / 100",
            "Aggressive Expansion: \(ae) (coalitions form at 50+ with 4+ outraged realms)"
        ]
        if world.diplomacy.isAtWar(observer, target) {
            notes.append("Currently at war")
        }

        return BreakdownReport(
            title: "\(obsName) Opinion of \(tgtName)",
            entries: entries,
            total: Double(actual),
            formattedTotal: actual >= 0 ? "+\(actual)" : "\(actual)",
            notes: notes
        )
    }

    public static func relationSlots(_ world: World, for country: CountryID) -> BreakdownReport {
        let comp = world.diplomacy.relationSlotsComponents(for: country, world: world)
        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Base diplomatic slots", value: Double(comp.base), formattedValue: "+\(comp.base)")
        ]
        if comp.rulerDiplomacy != 0 {
            entries.append(BreakdownEntry(label: "Ruler Diplomacy (÷5)", value: Double(comp.rulerDiplomacy), formattedValue: "+\(comp.rulerDiplomacy)"))
        }
        if comp.chancellorDiplomacy != 0 {
            entries.append(BreakdownEntry(label: "Chancellor Diplomacy (÷10)", value: Double(comp.chancellorDiplomacy), formattedValue: "+\(comp.chancellorDiplomacy)"))
        }
        if comp.diplomaticTech != 0 {
            entries.append(BreakdownEntry(label: "Diplomatic Technology", value: Double(comp.diplomaticTech), formattedValue: "+\(comp.diplomaticTech)"))
        }

        let used = world.diplomacy.usedRelationSlots(for: country, world: world)
        let excess = max(0, used - comp.total)
        var notes = [
            "Used: \(used) / \(comp.total) slots (alliances, non-aggression, guarantees, foreign royal marriages, vassals)"
        ]
        if excess > 0 {
            notes.append("Over limit by \(excess): costs \(excess).0 ducats/mo upkeep")
        }

        return BreakdownReport(
            title: "Diplomatic Relation Slots",
            entries: entries,
            total: Double(comp.total),
            formattedTotal: "\(comp.total) slots",
            notes: notes
        )
    }

    // MARK: - 8. AI Current Goal

    public static func aiGoal(_ world: World, for country: CountryID, date: GameDate) -> BreakdownReport {
        let ci = country.index
        guard ci >= 0, ci < world.countries.count else {
            return BreakdownReport(title: "AI Goal", entries: [], total: 0, formattedTotal: "None")
        }
        if world.humanCountries.contains(country) {
            return BreakdownReport(
                title: "Country Control",
                entries: [],
                total: 0,
                formattedTotal: "Player-controlled",
                notes: ["Controlled by the human player."]
            )
        }

        let traits = AIGoalSystem.traitProfile(for: country, in: world)
        let isFree = AIGoalSystem.isFreeMode(for: country, in: world)
        let summary = AIGoalSystem.goalSummaryText(for: country, in: world)

        let entries: [BreakdownEntry] = [
            BreakdownEntry(
                label: "Ruler war willingness",
                value: traits.warMultiplier,
                formattedValue: String(format: "%.2fx", traits.warMultiplier)
            ),
            BreakdownEntry(
                label: "Ruler economy focus",
                value: traits.economyWeight,
                formattedValue: String(format: "%.2fx", traits.economyWeight)
            ),
            BreakdownEntry(
                label: "Ruler diplomacy focus",
                value: traits.diplomacyWeight,
                formattedValue: String(format: "%.2fx", traits.diplomacyWeight)
            )
        ]

        var notes: [String] = []
        notes.append("Mode: \(world.ai.setting.displayName)\(world.ai.setting == .historical && isFree ? " (Historical goals finished -> Free AI)" : "")")
        notes.append("Current focus: \(summary)")

        if let goal = AIGoalSystem.activeGoal(for: country, in: world) {
            notes.append("Window: \(goal.earliestDate) to \(goal.giveUpDate) (Priority \(goal.priority))")
            if !goal.note.isEmpty {
                notes.append("Note: \(goal.note)")
            }
        }
        let totalGoals = ci < world.aiRules.goalsByCountry.count ? world.aiRules.goalsByCountry[ci].count : 0
        if world.ai.setting == .historical && totalGoals > 0 {
            let done = ci < world.ai.completedGoalIDs.count ? world.ai.completedGoalIDs[ci].count : 0
            let skipped = ci < world.ai.skippedGoalIDs.count ? world.ai.skippedGoalIDs[ci].count : 0
            let remaining = max(0, totalGoals - done - skipped)
            notes.append("Historical queue: \(done) completed · \(skipped) skipped · \(remaining) remaining")
        }

        let totalWeights = traits.warMultiplier + traits.economyWeight + traits.diplomacyWeight
        return BreakdownReport(
            title: "AI Behaviour & Current Goal",
            entries: entries,
            total: totalWeights,
            formattedTotal: summary,
            notes: notes
        )
    }

    // MARK: - 9. Province Supply Limit & War Score

    public static func provinceSupply(_ world: World, in province: ProvinceID) -> BreakdownReport {
        let p = province.index
        guard p >= 0, p < world.provinces.count else {
            return BreakdownReport(title: "Supply Limit", entries: [], total: 0, formattedTotal: "0")
        }
        let c = ArmySystem.supplyLimitComponents(world, in: province)
        var entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Base capacity", value: c.base, formattedValue: signedInt(c.base)),
            BreakdownEntry(label: "Population", value: c.population, formattedValue: signedInt(c.population)),
            BreakdownEntry(label: "Terrain (\(world.provinces.terrain[p].rawValue.capitalized))", value: c.terrain, formattedValue: signedInt(c.terrain))
        ]
        if c.stapleFood > 0 {
            entries.append(BreakdownEntry(label: "Local staple food output", value: c.stapleFood, formattedValue: signedInt(c.stapleFood)))
        }
        if c.coastal > 0 {
            entries.append(BreakdownEntry(label: "Coastal access", value: c.coastal, formattedValue: signedInt(c.coastal)))
        }
        if c.port > 0 {
            entries.append(BreakdownEntry(label: "Port buildings", value: c.port, formattedValue: signedInt(c.port)))
        }
        if c.caravanserai > 0 {
            entries.append(BreakdownEntry(label: "Caravanserai", value: c.caravanserai, formattedValue: signedInt(c.caravanserai)))
        }
        if c.fort > 0 {
            entries.append(BreakdownEntry(label: "Fortifications", value: c.fort, formattedValue: signedInt(c.fort)))
        }
        if abs(c.roundingDelta) > 0.01 {
            entries.append(BreakdownEntry(label: "Rounding (to 100)", value: c.roundingDelta, formattedValue: signedInt(c.roundingDelta)))
        }

        let inProv = ArmySystem.soldiersInProvince(world, province)
        let notes = [
            "Soldiers currently here: \(inProv) / \(c.total)",
            inProv > c.total ? "Over supply limit: armies suffer monthly attrition!" : "Within supply limit (0% attrition)"
        ]
        return BreakdownReport(
            title: "Province Supply Limit",
            entries: entries,
            total: Double(c.total),
            formattedTotal: "\(c.total) men",
            notes: notes
        )
    }

    public static func warScore(_ world: World, war: War) -> BreakdownReport {
        let wsPct = (war.warScore * 100.0).rounded()
        let battlePct = (war.battleWarScore * 100.0).rounded()
        let blockadePct = (war.blockadeWarScore * 100.0).rounded()
        let tickingPct = (war.tickingWarScore * 100.0).rounded()
        let occPct = wsPct - battlePct - blockadePct - tickingPct

        let entries: [BreakdownEntry] = [
            BreakdownEntry(label: "Field & naval battles (max ±40%)", value: battlePct, formattedValue: "\(signedInt(battlePct))%"),
            BreakdownEntry(label: "Province & capital occupation", value: occPct, formattedValue: "\(signedInt(occPct))%"),
            BreakdownEntry(label: "Naval blockades (max ±15%)", value: blockadePct, formattedValue: "\(signedInt(blockadePct))%"),
            BreakdownEntry(label: "Ticking war goal (max ±25%)", value: tickingPct, formattedValue: "\(signedInt(tickingPct))%")
        ]
        return BreakdownReport(
            title: "War Score (Attacker Side)",
            entries: entries,
            total: wsPct,
            formattedTotal: "\(signedInt(wsPct))%",
            notes: ["Positive favors attackers; negative favors defenders."]
        )
    }
}
