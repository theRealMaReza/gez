import Foundation
import Testing
@testable import GezCore

/// Phase 20.5: long AI-only games for balance checks. Runs only in the
/// "Balance runs" CI job (GEZ_BALANCE=1), never in ordinary test runs.
/// Prints `BALANCE ...` lines every 10 years and a summary at the end, so
/// Claude reads a few hundred lines instead of a whole log.
///
///   GEZ_BALANCE=1 GEZ_BALANCE_SEED=1 GEZ_BALANCE_AI=historical GEZ_BALANCE_END=1550
@Suite("Balance runs (Phase 20.5)")
struct BalanceRunTests {
    static let env = ProcessInfo.processInfo.environment
    static var enabled: Bool { env["GEZ_BALANCE"] == "1" }

    /// Countries whose fate is checked against history.
    static let watch = ["TUR", "MAM", "FRA", "ENG", "BUR", "CAS", "ARA", "POR", "GRA",
                        "HUN", "HAB", "BOH", "POL", "LIT", "MOS", "NOV", "VEN", "MLO",
                        "NAP", "PAP", "DAN", "SWE", "TEU", "CRI", "KAZ",
                        "QAR", "AKK", "TIM", "HRT", "DEL", "BAH", "VIJ", "ORI", "GUJ",
                        "ETH", "ADA", "MOR", "TLE", "TUN"]

    @Test("AI-only game from 1453 with balance report", .enabled(if: BalanceRunTests.enabled))
    func balanceRun() throws {
        let seed = UInt64(Self.env["GEZ_BALANCE_SEED"] ?? "1") ?? 1
        let ai = AIBehaviourSetting(rawValue: Self.env["GEZ_BALANCE_AI"] ?? "historical") ?? .historical
        let endYear = Int(Self.env["GEZ_BALANCE_END"] ?? "1550") ?? 1550
        let tag = "seed=\(seed) ai=\(ai.rawValue)"

        var world = Scenario1453.makeWorld()
        world.ai.setting = ai
        let start = GameDate(year: 1453, month: 5, day: 30)
        let sim = Simulation(world: world, startDate: start, seed: seed)
        HistorySystem.ensureInitialized(&sim.world, date: start)

        let clock = ContinuousClock()
        let began = clock.now
        var lastEvent = 0
        var nextReport = 1460
        report(sim, tag: tag, eventsFrom: 0)
        while sim.date.year < endYear {
            let t0 = clock.now
            let days0 = sim.ticksRun
            while sim.date.year < nextReport { sim.advance(days: 30) }
            let ms = Double((clock.now - t0).components.attoseconds) / 1e15
                + Double((clock.now - t0).components.seconds) * 1000
            let days = max(1, sim.ticksRun - days0)
            print("BALANCE \(tag) year=\(sim.date.year) speed_ms_per_day=\(String(format: "%.2f", ms / Double(days)))")
            report(sim, tag: tag, eventsFrom: lastEvent)
            lastEvent = sim.world.history.events.count
            nextReport += 10
        }
        let total = clock.now - began
        print("BALANCE \(tag) done in \(total.components.seconds) s")
        summary(sim, tag: tag)
    }

    private func report(_ sim: Simulation, tag: String, eventsFrom: Int) {
        let w = sim.world
        let rows = HistoryQueries.ledgerRows(in: w).filter { $0.provinces > 0 }
        let pop = rows.reduce(0) { $0 + $1.population }
        let y = sim.date.year
        let p = "BALANCE \(tag) year=\(y)"
        let wars = w.diplomacy.wars
        let oldest = wars.map { y - $0.startDate.year }.max() ?? 0
        print("\(p) alive=\(rows.count) pop_m=\(String(format: "%.1f", Double(pop) / 1e6)) wars=\(wars.count) oldest_war_years=\(oldest)")
        if let k = w.provinces.id(named: "Konstantiniyye") {
            let o = w.provinces.owner[k.index].map { w.countries.tag[$0.index] } ?? "none"
            print("\(p) Konstantiniyye=\(o)")
        }
        let top = rows.sorted { $0.provinces > $1.provinces }.prefix(12)
            .map { "\($0.tag):\($0.provinces)" }.joined(separator: " ")
        print("\(p) top=\(top)")
        let byTag = Dictionary(rows.map { ($0.tag, $0) }, uniquingKeysWith: { a, _ in a })
        var parts: [String] = []
        for t in Self.watch {
            if let r = byTag[t] {
                parts.append("\(t):\(r.provinces)p/\(r.population / 1000)k/\(Int(r.income))$/\(r.armySize / 1000)ka/t\(r.adminTech).\(r.diploTech).\(r.milTech)")
            } else {
                parts.append("\(t):gone")
            }
        }
        print("\(p) watch=\(parts.joined(separator: " "))")
        let treasuries = rows.compactMap { w.countries.id(forTag: $0.tag) }.map { w.countries.treasury[$0.index] }.sorted()
        if !treasuries.isEmpty {
            let neg = treasuries.filter { $0 < 0 }.count
            print("\(p) treasury_median=\(Int(treasuries[treasuries.count / 2])) treasury_max=\(Int(treasuries.last!)) in_debt=\(neg)")
        }
        let techs = rows.map { $0.totalTech }.sorted()
        if !techs.isEmpty {
            print("\(p) tech_total_min=\(techs.first!) median=\(techs[techs.count / 2]) max=\(techs.last!)")
        }
        var counts = [Int](repeating: 0, count: ChronicleEventKind.allCases.count)
        let ev = w.history.events
        for i in eventsFrom..<ev.count { counts[Int(ev.kind[i])] += 1 }
        let c = ChronicleEventKind.allCases.map { "\(ChronicleTemplateSet.kindKey(for: $0))=\(counts[Int($0.rawValue)])" }
        print("\(p) chronicle_10y \(c.joined(separator: " "))")
    }

    private func summary(_ sim: Simulation, tag: String) {
        let w = sim.world
        let p = "BALANCE \(tag) end"
        let ev = w.history.events
        // Biggest movers over the whole run, from the Ledger's yearly stats.
        let s = w.history.stats
        if let first = s.years.first, let last = s.years.last,
           let i0 = s.years.firstIndex(of: first), let i1 = s.years.lastIndex(of: last) {
            var startProv: [Int: Int] = [:]
            for r in s.yearStartOffsets[i0]..<(s.yearStartOffsets[i0] + s.yearCounts[i0]) {
                startProv[Int(s.countryIndex[r])] = s.population[r]
            }
            var endPop: [Int: Int] = [:]
            for r in s.yearStartOffsets[i1]..<(s.yearStartOffsets[i1] + s.yearCounts[i1]) {
                endPop[Int(s.countryIndex[r])] = s.population[r]
            }
            let grown = endPop.map { ($0.key, Double($0.value) / Double(max(1, startProv[$0.key] ?? 1))) }
                .filter { (startProv[$0.0] ?? 0) > 200_000 }
                .sorted { $0.1 > $1.1 }.prefix(10)
                .map { "\(w.countries.tag[$0.0])x\(String(format: "%.1f", $0.1))" }
            print("\(p) pop_growth_top=\(grown.joined(separator: " "))")
            let died = startProv.keys.filter { endPop[$0] == nil }.map { w.countries.tag[$0] }.sorted()
            print("\(p) countries_gone=\(died.count) \(died.prefix(60).joined(separator: ","))")
        }
        // Chronicle: a sample of Ottoman entries in period prose.
        if let tur = w.countries.id(forTag: "TUR") {
            let templates = ChronicleTemplateSet.shared
            var shown = 0
            for i in 0..<ev.count where ev.involves(tur, at: i) {
                guard let k = ev.eventKind(at: i), k == .warDeclared || k == .peaceTreaty || k == .siegeCaptured || k == .rulerCrowned else { continue }
                print("\(p) chronicle_TUR \(ev.date(at: i).year): \(templates.render(eventIndex: i, in: w))")
                shown += 1
                if shown >= 25 { break }
            }
        }
        print("\(p) chronicle_total=\(ev.count) timelapse_years=\(w.history.timelapse.years.count)")
    }
}
