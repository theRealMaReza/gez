import Foundation
import XCTest
@testable import GezCore

final class GameSessionTests: XCTestCase {
    private var tempSavesDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempSavesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GezSessionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempSavesDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        GezResources.dataDirectory = nil
        if let dir = tempSavesDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }

    func testNewGameAndCountryQueries() throws {
        let session = try GameSession(tag: "TUR", savesDirectory: tempSavesDir)
        XCTAssertEqual(session.playerTag, "TUR")
        XCTAssertEqual(session.date, Scenario1453.startDate)
        XCTAssertFalse(session.countryLabels.isEmpty)
        XCTAssertFalse(session.provinceLabels.isEmpty)
        XCTAssertFalse(session.seaLabels.isEmpty)
        XCTAssertEqual(session.townIcons.count, session.world.provinces.count)

        let topBar = try XCTUnwrap(session.playerTopBarStatus())
        XCTAssertEqual(topBar.name, "Ottoman Empire")
        XCTAssertGreaterThan(topBar.treasury, 0)
        XCTAssertGreaterThan(topBar.armyMen, 0)

        let summaries = session.countrySummaries()
        XCTAssertGreaterThan(summaries.count, 200)
        XCTAssertTrue(summaries.contains { $0.tag == "TUR" })

        session.startNewGame(tag: "FRA", seed: 99)
        XCTAssertEqual(session.playerTag, "FRA")
        XCTAssertEqual(session.speed, .paused)
    }

    func testPauseSpeedAndClockAdvance() throws {
        let session = try GameSession(tag: "TUR", savesDirectory: tempSavesDir)
        XCTAssertEqual(session.speed, .paused)

        // Unpause defaults to speed 2 (1 day/sec)
        session.togglePause()
        XCTAssertEqual(session.speed, .two)

        session.faster()
        XCTAssertEqual(session.speed, .three)
        session.slower()
        XCTAssertEqual(session.speed, .two)

        let outcome = session.advanceTime(elapsedSeconds: 3.0)
        XCTAssertEqual(outcome.daysAdvanced, 3)
        XCTAssertEqual(session.date, GameDate(year: 1453, month: 6, day: 2))
        XCTAssertTrue(outcome.monthChanged)

        session.togglePause()
        XCTAssertEqual(session.speed, .paused)
        let pausedOutcome = session.advanceTime(elapsedSeconds: 5.0)
        XCTAssertEqual(pausedOutcome.daysAdvanced, 0)
    }

    func testSaveLoadAndAutosave() throws {
        let session = try GameSession(tag: "VEN", savesDirectory: tempSavesDir)
        session.autosaveFrequency = .monthly
        _ = session.advanceDays(3) // Crosses 1 June 1453 -> triggers monthly autosave
        XCTAssertTrue(session.savedGames.contains { $0.metadata.isAutosave })

        let savedURL = try XCTUnwrap(session.saveGame(named: "Venice Test"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(session.savedGames.count, 2)

        let savedDate = session.date
        let savedTreasury = session.world.countries.treasury[session.playerCountry!.index]

        session.startNewGame(tag: "ENG")
        XCTAssertEqual(session.playerTag, "ENG")

        let manualEntry = try XCTUnwrap(session.savedGames.first { !$0.metadata.isAutosave })
        XCTAssertTrue(session.loadGame(manualEntry))
        XCTAssertEqual(session.playerTag, "VEN")
        XCTAssertEqual(session.date, savedDate)
        XCTAssertEqual(session.world.countries.treasury[session.playerCountry!.index], savedTreasury, accuracy: 0.001)

        session.deleteSave(manualEntry)
        XCTAssertEqual(session.savedGames.count, 1)
    }

    func testPlayerEconomyMilitaryGovernmentAndDiplomacyActions() throws {
        let session = try GameSession(tag: "TUR", savesDirectory: tempSavesDir)
        let tur = try XCTUnwrap(session.playerCountry)
        let capital = try XCTUnwrap(session.world.countries.capital[tur.index])

        // Tax & finance
        session.setTax(.peasants, level: 1.5)
        XCTAssertEqual(session.world.countries.taxLevel[tur.index][TaxClass.peasants.rawValue], 1.5, accuracy: 0.001)
        let beforeDebase = session.world.countries.treasury[tur.index]
        session.debaseOnce()
        XCTAssertGreaterThan(session.world.countries.treasury[tur.index], beforeDebase)

        // Building
        session.simulation.world.countries.treasury[tur.index] += 5_000
        if let workshopType = session.world.economy.buildingTypes.indices.first(where: {
            BuildingSystem.refusal(session.world, tur, capital, BuildingTypeID($0)) == nil
        }) {
            let refusal = session.build(BuildingTypeID(workshopType), in: capital)
            XCTAssertNil(refusal)
        }

        // Levies & recruitment
        let initialArmies = session.world.military.armies(of: tur).count
        session.raiseAllLevies()
        XCTAssertGreaterThan(session.world.military.armies(of: tur).count, initialArmies)
        session.disbandLevies()
        XCTAssertEqual(session.world.military.totalMen(of: tur, origin: .levy), 0)

        if let footmen = session.world.military.unitByKey["infantry"] {
            let refusal = session.recruitProfessional(footmen, in: capital)
            XCTAssertNil(refusal)
        }

        // Laws & stability
        session.simulation.world.government.stability[tur.index] = 0
        session.raiseStability()
        XCTAssertEqual(session.world.government.stability[tur.index], 1)

        let lawRefusal = session.changeLaw(area: 1, option: 1)
        XCTAssertNil(lawRefusal)

        // Diplomacy, war declaration & peace offer
        let candar = try XCTUnwrap(session.world.countries.id(forTag: "CND"))
        session.improveRelations(with: candar)
        let cbs = session.world.diplomacy.availableCasusBelli(attacker: tur, defender: candar, in: session.world)
        let cb = try XCTUnwrap(cbs.first)
        let warRes = session.declareWar(on: candar, cb: cb)
        let war = try warRes.get()
        XCTAssertTrue(session.world.diplomacy.isAtWar(tur, candar))

        // White peace when war score / acceptance allows or via pending response
        let offer = PeaceOffer(warID: war.id, winner: tur, loser: candar, demands: [])
        session.respondToPendingPeaceOffer(offer, accept: true)
        XCTAssertFalse(session.world.diplomacy.isAtWar(tur, candar))
    }

    func testCustomResourceDirectoryFallback() throws {
        let customDir = tempSavesDir.appendingPathComponent("CustomData", isDirectory: true)
        try FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)

        // Copy scenario1453.json into customDir and verify GezResources resolves it there
        let bundledScenario = try XCTUnwrap(Bundle.module.url(forResource: "scenario1453", withExtension: "json"))
        let copiedScenario = customDir.appendingPathComponent("scenario1453.json")
        try FileManager.default.copyItem(at: bundledScenario, to: copiedScenario)

        GezResources.dataDirectory = customDir
        let resolved = try XCTUnwrap(GezResources.url(forResource: "scenario1453", withExtension: "json"))
        XCTAssertEqual(resolved.standardizedFileURL, copiedScenario.standardizedFileURL)

        // Other files not in customDir still fall back to Bundle.module
        let fallbackEconomy = GezResources.url(forResource: "economy1453", withExtension: "json")
        XCTAssertNotNil(fallbackEconomy)

        let world = try Scenario1453.loadBundled()
        XCTAssertGreaterThanOrEqual(world.provinces.count, 1378)  // grows with the Old World regions
    }
}
