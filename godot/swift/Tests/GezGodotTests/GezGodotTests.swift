import Foundation
import GezCore
import GezGodot
import Testing

@Suite("GezGodotController Tests")
struct GezGodotTests {
    @Test("Loads 1453 world, encodes map textures, and advances speeds 1-5")
    func controllerLoadsAndAdvances() {
        let controller = GezGodotController()
        let ok = controller.setup(dataDirectoryPath: "", tag: "TUR")
        #expect(ok)
        #expect(controller.mapWidth == 3936)
        #expect(controller.mapHeight == 2384)
        #expect(controller.countryTag == "TUR")
        #expect(controller.countryName.contains("Ottoman"))
        #expect(controller.dateText == "30 May 1453")
        #expect(controller.isPaused)

        // Verify ID map and style texture byte buffers.
        let idBytes = controller.provinceIDBytes()
        #expect(idBytes.count == 3936 * 2384 * 2)
        let seaBytes = controller.seaIDBytes()
        #expect(seaBytes.count == 3936 * 2384 * 2)
        let styleBytes = controller.styleBytes()
        #expect(styleBytes.count == GezGodotController.styleTextureWidth * 2 * 4)

        // Verify water (v = 0) and wasteland (v = 1) owner encodings in row 1.
        let width = GezGodotController.styleTextureWidth
        let waterOwnerEnc = UInt16(styleBytes[width * 4]) | (UInt16(styleBytes[width * 4 + 1]) << 8)
        let wastelandOwnerEnc = UInt16(styleBytes[(width + 1) * 4]) | (UInt16(styleBytes[(width + 1) * 4 + 1]) << 8)
        #expect(Int(waterOwnerEnc) - 4 == -2)
        #expect(Int(wastelandOwnerEnc) - 4 == -3)

        // Verify country labels.
        let (texts, metrics) = controller.countryLabelData()
        #expect(!texts.isEmpty)
        #expect(metrics.count == texts.count * 3)

        // Verify focus point and province selection around Constantinople.
        let focus = controller.focusPoint(latitude: 41.0, longitude: 29.0)
        #expect(focus.x > 0 && focus.x < Double(controller.mapWidth))
        #expect(focus.y > 0 && focus.y < Double(controller.mapHeight))

        // Verify speed 5 advancement.
        controller.setSpeed(5)
        #expect(!controller.isPaused)
        #expect(controller.speed == 5)
        let mask = controller.tickFrame(deltaSeconds: 0.2)
        #expect((mask & 1) != 0)
        #expect(controller.dateText != "30 May 1453")
    }

    @Test("Clicking a foreign province offers it, and Play as switches the player")
    func playAsSelectedOwner() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        #expect(controller.selectedOwnerName.isEmpty)

        // Paris, owned by France.
        let paris = controller.focusPoint(latitude: 48.86, longitude: 2.35)
        controller.selectAt(mapX: Int(paris.x), mapY: Int(paris.y))
        #expect(controller.selectedOwnerName.contains("France"))
        #expect(controller.selectedProvinceOwnerTag == "FRA")

        #expect(controller.playAsSelectedOwner())
        #expect(controller.countryTag == "FRA")
        // Already the player's own province now: selectedOwnerName is empty,
        // while selectedProvinceOwnerTag still reports the owner's tag for Nation Picker.
        #expect(controller.selectedOwnerName.isEmpty)
        #expect(controller.selectedProvinceOwnerTag == "FRA")
        #expect(!controller.playAsSelectedOwner())
    }

    @Test("Map modes Q to I switch mode, shader index, tint, and style buffer")
    func mapModesAndStyling() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))

        let modes = controller.mapModesList()
        #expect(modes.count == 9)
        let keys = modes.compactMap { $0["key"] as? String }
        let shortcuts = modes.compactMap { $0["shortcut"] as? String }
        #expect(keys == ["political", "diplomatic", "states", "terrain", "religion", "culture", "development", "goods", "markets"])
        #expect(shortcuts == ["Q", "O", "W", "E", "R", "T", "Y", "U", "I"])

        let politicalStyles = controller.styleBytes()
        #expect(controller.mapModeKey == "political")
        #expect(controller.shaderModeIndex == 0)
        #expect(controller.tint(forZoom: 1.0) < 0.66)

        // Terrain mode sets province tint alpha to 0 and shaderModeIndex to 2.
        #expect(controller.setMapMode(key: "terrain"))
        #expect(controller.mapModeKey == "terrain")
        #expect(controller.shaderModeIndex == 2)
        #expect(controller.tint(forZoom: 1.0) == 0.0)
        let terrainStyles = controller.styleBytes()
        // Province 0 (v = 2) has alpha at byte 2 * 4 + 3 = 11.
        #expect(politicalStyles[11] == 255)
        #expect(terrainStyles[11] == 0)

        // Test remaining modes.
        for (modeKey, expectedShaderIdx) in [
            ("diplomatic", 0),
            ("states", 1),
            ("religion", 3),
            ("culture", 4),
            ("development", 5),
            ("goods", 6),
            ("markets", 7)
        ] {
            #expect(controller.setMapMode(key: modeKey))
            #expect(controller.mapModeKey == modeKey)
            #expect(controller.shaderModeIndex == expectedShaderIdx)
            let bytes = controller.styleBytes()
            #expect(bytes[11] == 255)
        }

        #expect(!controller.setMapMode(key: "nonexistent_mode"))
        #expect(controller.mapModeKey == "markets")
    }

    @Test("Game menu save, quick save, load, delete, and autosave frequency")
    func gameMenuSaveLoadAndAutosave() throws {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GezGodotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        controller.session?.savesDirectory = tempDir

        // Autosave options & frequency
        let options = controller.autosaveOptions()
        #expect(options.count == 5)
        #expect(controller.setAutosaveFrequency("monthly"))
        #expect(controller.autosaveFrequencyKey == "monthly")
        #expect(!controller.setAutosaveFrequency("invalid_freq"))

        // Named save
        #expect(controller.saveGame(named: "Constantinople 1453"))
        #expect(controller.lastSaveStatus.contains("Constantinople 1453"))
        var saves = controller.savedGamesList()
        #expect(saves.count == 1)
        #expect(saves[0]["name"] as? String == "Constantinople 1453")
        #expect(saves[0]["playerTag"] as? String == "TUR")
        #expect(saves[0]["gameDate"] as? String == "30 May 1453")
        #expect(saves[0]["isAutosave"] as? Bool == false)

        // Quick save
        #expect(controller.quickSave())
        saves = controller.savedGamesList()
        #expect(saves.count == 2)

        // Switch player & advance time (crossing a month boundary also triggers monthly autosave),
        // then load the first save back
        #expect(controller.switchPlayer(tag: "FRA"))
        controller.setSpeed(5)
        _ = controller.tickFrame(deltaSeconds: 0.2)
        #expect(controller.countryTag == "FRA")
        #expect(controller.dateText != "30 May 1453")

        saves = controller.savedGamesList()
        let countBeforeDelete = saves.count
        #expect(countBeforeDelete >= 2)
        let turSaveIndex = saves.firstIndex { ($0["name"] as? String) == "Constantinople 1453" } ?? 0
        #expect(controller.loadSavedGame(at: turSaveIndex))
        #expect(controller.countryTag == "TUR")
        #expect(controller.dateText == "30 May 1453")
        #expect(controller.isPaused)

        // Delete save
        #expect(controller.deleteSavedGame(at: 0))
        #expect(controller.savedGamesList().count == countBeforeDelete - 1)
    }

    @Test("Nation picker featured powers, country details, and starting a new game")
    func nationPickerAndStartNewGame() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))

        let featured = controller.featuredCountriesList()
        #expect(featured.count == CountrySummaryInfo.featuredTags.count)
        let first = featured[0]
        #expect(first["tag"] as? String == "TUR")
        #expect((first["name"] as? String)?.contains("Ottoman") == true)
        #expect((first["ruler"] as? String)?.isEmpty == false)
        #expect((first["provinces"] as? Int ?? 0) > 0)
        #expect((first["treasury"] as? Double ?? 0) > 0)

        let all = controller.allCountriesList()
        #expect(all.count >= 200)

        let venDetails = controller.countryDetails(tag: "VEN")
        #expect(venDetails["tag"] as? String == "VEN")
        #expect((venDetails["name"] as? String)?.contains("Venice") == true)
        #expect((venDetails["provinces"] as? Int ?? 0) > 0)

        // Advance time, then start a fresh 1453 game as Castile.
        controller.setSpeed(5)
        _ = controller.tickFrame(deltaSeconds: 0.2)
        #expect(controller.dateText != "30 May 1453")

        #expect(controller.startNewGame(tag: "CAS"))
        #expect(controller.countryTag == "CAS")
        #expect(controller.dateText == "30 May 1453")
        #expect(controller.isPaused)
    }

    @Test("Province panel tabs (Overview, Economy, People), building, levy, vassal grant/revoke, and Market panel")
    func provinceSeaAndMarketPanels() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        #expect(controller.selectedProvinceDetails()["hasSelection"] as? Bool == false)

        // Select Constantinople (owned by TUR).
        let pt = controller.focusPoint(latitude: 41.0, longitude: 29.0)
        let selVal = controller.selectAt(mapX: Int(pt.x), mapY: Int(pt.y))
        #expect(selVal >= 2)

        let details = controller.selectedProvinceDetails(peopleShowState: false)
        #expect(details["hasSelection"] as? Bool == true)
        #expect(details["ownerTag"] as? String == "TUR")
        #expect(details["isPlayerOwned"] as? Bool == true)
        #expect((details["supplyLimit"] as? Int ?? 0) > 0)
        #expect((details["buildCategories"] as? [[String: Any]])?.count == 4)

        let goodsProduced = details["goodsProduced"] as? [[String: Any]] ?? []
        #expect(!goodsProduced.isEmpty)
        let cultures = details["cultures"] as? [[String: Any]] ?? []
        #expect(!cultures.isEmpty)
        let religions = details["religions"] as? [[String: Any]] ?? []
        #expect(!religions.isEmpty)
        let classes = details["classes"] as? [[String: Any]] ?? []
        #expect(!classes.isEmpty)

        // State-level people breakdown toggle
        let stateDetails = controller.selectedProvinceDetails(peopleShowState: true)
        #expect((stateDetails["peopleTitle"] as? String)?.hasPrefix("People of ") == true)

        // Vassal grant & revoke on a crown-held province
        if (details["hasHolder"] as? Bool) == true {
            #expect(controller.revokeSelectedProvince())
        }
        let refreshedForGrant = controller.selectedProvinceDetails()
        if let candidates = refreshedForGrant["grantCandidates"] as? [[String: Any]],
           let firstCand = candidates.first,
           let charIdx = firstCand["characterIndex"] as? Int {
            #expect(controller.grantSelectedProvince(characterIndex: charIdx))
            #expect(controller.selectedProvinceDetails()["hasHolder"] as? Bool == true)
            #expect(controller.revokeSelectedProvince())
            #expect(controller.selectedProvinceDetails()["hasHolder"] as? Bool == false)
        }

        // Start a building construction in the selected province
        let buildable = (details["buildableOptions"] as? [[String: Any]] ?? []).first {
            ($0["canBuild"] as? Bool) == true
        }
        #expect(buildable != nil)
        if let buildable, let typeIdx = buildable["typeIndex"] as? Int {
            #expect(controller.buildInSelectedProvince(buildingTypeIndex: typeIdx))
            let afterBuild = controller.selectedProvinceDetails()
            let constructions = afterBuild["constructions"] as? [[String: Any]] ?? []
            #expect(!constructions.isEmpty)
        }

        // Raise levies in the selected province if available
        if (details["canRaiseLevy"] as? Bool) == true {
            #expect(controller.raiseSelectedProvinceLevies())
            #expect(controller.selectedProvinceDetails()["hasRaisedLevies"] as? Bool == true)
        }

        // Market panel details for the province's market
        let marketIndex = details["marketIndex"] as? Int ?? -1
        #expect(marketIndex >= 0)
        let market = controller.marketDetails(marketIndex: marketIndex, categoryKey: "")
        #expect(market["valid"] as? Bool == true)
        #expect((market["provinceCount"] as? Int ?? 0) > 0)
        #expect((market["categories"] as? [[String: Any]])?.count == 6)
        let marketGoods = market["goods"] as? [[String: Any]] ?? []
        #expect(!marketGoods.isEmpty)

        let foodMarket = controller.marketDetails(marketIndex: marketIndex, categoryKey: "food")
        #expect(foodMarket["valid"] as? Bool == true)
        let foodGoods = foodMarket["goods"] as? [[String: Any]] ?? []
        #expect(!foodGoods.isEmpty)
        #expect(foodGoods.count < marketGoods.count)

        // Clear selection
        controller.clearSelection()
        #expect(controller.selectedProvinceValue == 0)
        #expect(controller.selectedProvinceDetails()["hasSelection"] as? Bool == false)
    }
}
