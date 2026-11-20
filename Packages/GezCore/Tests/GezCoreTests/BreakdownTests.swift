import Foundation
import Testing
@testable import GezCore

@Suite("Breakdowns")
struct BreakdownTests {
    private static func expectPartsSumToTotal(_ report: BreakdownReport, tolerance: Double = 1e-4) {
        let sum = report.entries.reduce(0.0) { $0 + $1.value }
        #expect(abs(sum - report.total) <= tolerance, "\(report.title): sum \(sum) != total \(report.total)")
    }

    @Test("Every breakdown parts sum equals total after simulating several months")
    func breakdownSumsMatchTotals() {
        let world = Scenario1453.makeWorld()
        let sim = Simulation(world: world, startDate: Scenario1453.startDate, seed: 1453)
        // Run 65 days so at least two monthly ticks (income, upkeep, tech, unrest, sieges) settle.
        sim.advance(days: 65)

        let w = sim.world
        let tur = w.countries.id(forTag: "TUR")!
        let hun = w.countries.id(forTag: "HUN")!
        let ven = w.countries.id(forTag: "VEN")!
        let fra = w.countries.id(forTag: "FRA")!

        // 1. Monthly income breakdown (including debasement & war reparations)
        for tagCountry in [tur, hun, ven, fra] {
            let inc = Breakdowns.monthlyIncome(w, for: tagCountry)
            #expect(!inc.entries.isEmpty)
            Self.expectPartsSumToTotal(inc)
        }

        // Verify with ongoing debasement active
        var debWorld = w
        debWorld.countries.debasing[tur.index] = true
        let debSim = Simulation(restoringWorld: debWorld, date: sim.date, random: sim.random, ticksRun: sim.ticksRun)
        debSim.advance(days: 35)
        let debInc = Breakdowns.monthlyIncome(debSim.world, for: tur)
        #expect(debInc.entries.contains { $0.label.contains("Debased") })
        Self.expectPartsSumToTotal(debInc)

        // 2. Manpower & Sailors
        for tagCountry in [tur, ven, fra] {
            let mp = Breakdowns.manpower(w, for: tagCountry)
            #expect(mp.total > 0)
            Self.expectPartsSumToTotal(mp, tolerance: 0.5)

            let sailors = Breakdowns.sailors(w, for: tagCountry)
            Self.expectPartsSumToTotal(sailors, tolerance: 0.5)
        }

        // 3. Army morale
        let turArmies = w.military.armies(of: tur)
        #expect(!turArmies.isEmpty)
        let morale = Breakdowns.armyMorale(w, army: turArmies[0])
        #expect(morale.total > 0)
        Self.expectPartsSumToTotal(morale)

        // 4. Stability & Province Unrest & Supply
        for tagCountry in [tur, hun, fra] {
            let stab = Breakdowns.stability(w, for: tagCountry)
            #expect(stab.total >= 25.0)
            Self.expectPartsSumToTotal(stab, tolerance: 0.05)
        }
        if let constProv = w.provinces.id(named: "Constantinople") ?? w.provinces(ownedBy: tur).first {
            let unrest = Breakdowns.unrest(w, in: constProv, date: sim.date)
            Self.expectPartsSumToTotal(unrest, tolerance: 0.1)
            let supply = Breakdowns.provinceSupply(w, in: constProv)
            #expect(supply.total >= 3000)
            Self.expectPartsSumToTotal(supply, tolerance: 0.5)
        }

        // 5. Research speed & Tech cost across all 3 tracks
        for track in TechTrack.allCases {
            let speed = Breakdowns.researchSpeed(w, for: tur, track: track, year: sim.date.year)
            #expect(speed.total > 0)
            Self.expectPartsSumToTotal(speed)

            let cost = Breakdowns.techCost(w, for: tur, track: track, year: sim.date.year)
            #expect(cost.total > 0)
            Self.expectPartsSumToTotal(cost, tolerance: 0.5)
        }

        // 6. Relations & Relation slots
        let rel = Breakdowns.relations(w, of: tur, by: hun)
        #expect(Int(rel.total.rounded()) == w.diplomacy.opinion(of: tur, by: hun))
        Self.expectPartsSumToTotal(rel)

        let slots = Breakdowns.relationSlots(w, for: tur)
        #expect(Int(slots.total.rounded()) == w.diplomacy.relationSlots(for: tur, world: w))
        Self.expectPartsSumToTotal(slots)

        // 7. AI goal breakdown
        let aiTur = Breakdowns.aiGoal(w, for: tur, date: sim.date)
        #expect(!aiTur.notes.isEmpty)
        Self.expectPartsSumToTotal(aiTur)

        // 8. War score & Siege breakdown (from active 1453 war or newly created siege)
        if let war = w.diplomacy.wars.first {
            let ws = Breakdowns.warScore(w, war: war)
            Self.expectPartsSumToTotal(ws)
        }
        if let anySiege = w.military.sieges.first {
            let siege = Breakdowns.siege(w, in: anySiege.province)
            Self.expectPartsSumToTotal(siege)
        }
    }

    @Test("Siege breakdown adds up to exact siege phase modifier + progress")
    func siegeBreakdownMatchesPhaseModifiers() {
        var world = Scenario1453.makeWorld()
        let tur = world.countries.id(forTag: "TUR")!
        let hun = world.countries.id(forTag: "HUN")!
        // Put a Turkish army on a Hungarian fort province and create a siege.
        let fortProv = world.provinces(ownedBy: hun).first { world.provinces.fortLevel[$0.index] > 0 }
            ?? world.provinces(ownedBy: hun).first!
        world.provinces.fortLevel[fortProv.index] = 2
        world.provinces.fortGarrison[fortProv.index] = 2000
        let turArmy = world.military.armies(of: tur).first!
        world.military.armies.province[Int(turArmy.rawValue)] = fortProv
        world.military.sieges.append(Siege(
            province: fortProv,
            besieger: tur,
            startDate: Scenario1453.startDate,
            progress: 3,
            breached: true,
            blockaded: false,
            phaseDaysRemaining: 15
        ))

        let report = Breakdowns.siege(world, in: fortProv)
        #expect(!report.entries.isEmpty)
        Self.expectPartsSumToTotal(report)
        let armies = SiegeSystem.besiegers(in: fortProv, attacker: tur, world: world)
        let mods = SiegeSystem.phaseModifiers(world, siege: world.military.sieges.last!, hostileArmies: armies, fortLevel: 2)
        #expect(Int(report.total.rounded()) == mods.effectiveModifier + 3)
    }
}
