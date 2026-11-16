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
        #expect(modes.count == 11)
        let keys = modes.compactMap { $0["key"] as? String }
        let shortcuts = modes.compactMap { $0["shortcut"] as? String }
        #expect(keys == ["political", "diplomatic", "states", "terrain", "religion", "culture", "development", "goods", "markets", "plague", "unrest"])
        #expect(shortcuts == ["Q", "O", "W", "E", "R", "T", "Y", "U", "I", "P", "L"])

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
            ("plague", 8),
            ("unrest", 9),
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

    @Test("Army counters, selecting an army, moving, splitting, merging, disbanding, and assigning commanders")
    func mapArmiesSelectionAndActions() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        #expect(controller.topBarArmiesText.hasPrefix("Armies "))

        let mapArmies = controller.mapArmiesData()
        let counters = mapArmies["counters"] as? [[String: Any]] ?? []
        #expect(counters.count >= 30)

        let playerCounters = counters.filter { ($0["isPlayer"] as? Bool) == true }
        #expect(!playerCounters.isEmpty)
        let firstArmyId = playerCounters[0]["armyId"] as? Int ?? -1
        let startProvIdx = playerCounters[0]["provinceIndex"] as? Int ?? -1
        #expect(firstArmyId >= 0)
        #expect(startProvIdx >= 0)

        // Out-of-range army indices are safely rejected.
        #expect(!controller.selectArmy(armyId: -1))
        #expect(!controller.selectArmy(armyId: 999_999))

        // Select the player's army.
        #expect(controller.selectArmy(armyId: firstArmyId))
        #expect(controller.selectedArmyId == firstArmyId)

        let details = controller.selectedArmyDetails()
        #expect(details["hasSelection"] as? Bool == true)
        #expect(details["armyId"] as? Int == firstArmyId)
        #expect(details["isPlayerOwned"] as? Bool == true)
        #expect((details["totalMen"] as? Int ?? 0) > 0)
        #expect((details["regiments"] as? [[String: Any]])?.isEmpty == false)
        #expect((details["supplyLimit"] as? Int ?? 0) > 0)

        // Assign commander (and unassign with -1).
        let candidates = details["commanderCandidates"] as? [[String: Any]] ?? []
        #expect(!candidates.isEmpty)
        if let firstCand = candidates.first, let cIdx = firstCand["characterIndex"] as? Int {
            #expect(controller.assignArmyCommander(armyId: firstArmyId, characterIndex: cIdx))
            #expect(controller.selectedArmyDetails()["commanderIndex"] as? Int == cIdx)
            #expect(controller.assignArmyCommander(armyId: firstArmyId, characterIndex: -1))
            #expect(controller.selectedArmyDetails()["commanderIndex"] as? Int == -1)
        }

        // Toggle move mode and order a march to an adjacent land province.
        #expect(controller.setMoveModeForArmy(armyId: firstArmyId))
        #expect(controller.moveModeArmyId == firstArmyId)
        if let s = controller.session,
           let neighbor = s.world.provinces.neighbors[startProvIdx].first {
            #expect(controller.orderArmyMove(armyId: firstArmyId, provinceIndex: neighbor.index))
            #expect(controller.moveModeArmyId == -1)
            let movingDetails = controller.selectedArmyDetails()
            #expect(movingDetails["isMoving"] as? Bool == true)

            let routes = controller.mapArmiesData()["routes"] as? [[String: Any]] ?? []
            #expect(routes.contains { ($0["armyId"] as? Int) == firstArmyId })
        }

        // Split the army into two in the same province, then merge them back, then disband.
        let splitNewId = controller.splitArmy(armyId: firstArmyId)
        #expect(splitNewId >= 0)
        #expect(controller.selectedArmyId == splitNewId)
        #expect(controller.selectedArmyDetails()["canMerge"] as? Bool == true)

        #expect(controller.mergeArmies(armyId: firstArmyId))
        #expect(controller.selectedArmyId == firstArmyId)

        #expect(controller.disbandArmy(armyId: firstArmyId))
        #expect(controller.selectedArmyId == -1)
        #expect(controller.selectedArmyDetails()["hasSelection"] as? Bool == false)
    }

    @Test("Armies window, raising/disbanding levies, recruiting professionals and mercenaries, and siege Storm Assault")
    func recruitmentAndSiegeAssault() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))

        let win = controller.armiesWindowDetails()
        #expect(win["valid"] as? Bool == true)
        #expect((win["manpower"] as? Int ?? 0) > 0)
        #expect((win["maxManpower"] as? Int ?? 0) > 0)
        let musterProvIdx = win["musterProvinceIndex"] as? Int ?? -1
        #expect(musterProvIdx >= 0)

        let recruitUnits = win["recruitUnits"] as? [[String: Any]] ?? []
        #expect(!recruitUnits.isEmpty)

        // Recruit a professional regiment and hire a mercenary regiment in the muster province.
        if let firstProf = recruitUnits.first(where: { ($0["canRecruitProf"] as? Bool) == true }),
           let uIdx = firstProf["unitTypeIndex"] as? Int {
            let menBefore = win["standingMen"] as? Int ?? 0
            #expect(controller.recruitProfessionalInProvince(unitTypeIndex: uIdx, provinceIndex: musterProvIdx))
            let menAfter = controller.armiesWindowDetails()["standingMen"] as? Int ?? 0
            #expect(menAfter > menBefore)
        }
        if let firstMerc = recruitUnits.first(where: { ($0["canHireMerc"] as? Bool) == true }),
           let uIdx = firstMerc["unitTypeIndex"] as? Int {
            #expect(controller.hireMercenaryInProvince(unitTypeIndex: uIdx, provinceIndex: musterProvIdx))
            let afterWin = controller.armiesWindowDetails()
            #expect((afterWin["mercenaryMen"] as? Int ?? 0) > 0)
        }

        // Raise levies in one province, raise all levies, and disband all levies.
        if (win["musterCanRaiseLevy"] as? Bool) == true {
            #expect(controller.raiseLeviesInProvince(provinceIndex: musterProvIdx))
        }
        #expect(controller.raiseAllLevies())
        #expect((controller.armiesWindowDetails()["levyMen"] as? Int ?? 0) > 0)
        #expect(controller.disbandAllLevies())
        #expect((controller.armiesWindowDetails()["levyMen"] as? Int ?? 0) == 0)

        // Siege inspection & Storm Assault in a besieged fortified province.
        if let s = controller.session, let player = s.playerCountry {
            // Find an enemy or foreign fortified province (or give one a level-1 fort) and start a siege by player.
            let targetIdx = s.world.provinces.ids.first {
                s.world.provinces.owner[$0.index] != nil
                    && s.world.provinces.owner[$0.index] != player
                    && s.world.provinces.fortLevel[$0.index] > 0
            }?.index ?? 10
            let targetPid = ProvinceID(targetIdx)
            let enemy = s.world.provinces.owner[targetIdx]!
            if !s.world.diplomacy.isAtWar(player, enemy) {
                let cbs = s.world.diplomacy.availableCasusBelli(attacker: player, defender: enemy, in: s.world)
                if let cb = cbs.first {
                    _ = s.declareWar(on: enemy, cb: cb, breakTruce: true)
                }
            }
            if s.world.provinces.fortLevel[targetIdx] == 0 {
                s.simulation.world.provinces.fortLevel[targetIdx] = 1
                s.simulation.world.provinces.fortGarrison[targetIdx] = 1_000
            }
            // Place a large player army in targetPid and create a breached siege.
            let inf = s.world.military.unit("infantry")!
            let regs = (0..<8).map { _ in Regiment(type: inf.id, origin: .professional, men: 1_000, morale: inf.morale) }
            _ = s.simulation.world.military.armies.append(
                name: "Siege Host",
                owner: player,
                province: targetPid,
                regiments: regs
            )
            var siege = Siege(
                province: targetPid,
                besieger: player,
                startDate: s.date,
                progress: 5,
                breached: false,
                blockaded: true,
                lastRoll: 6,
                lastModifier: 2,
                lastOutcome: .foodShortage,
                phaseDaysRemaining: 14
            )
            s.simulation.world.military.sieges.removeAll { $0.province == targetPid }
            s.simulation.world.military.sieges.append(siege)

            #expect(controller.selectProvinceByIndex(targetIdx) == targetIdx + 2)
            let siegeDetailsBeforeBreach = controller.selectedProvinceDetails()
            #expect(siegeDetailsBeforeBreach["isBesieged"] as? Bool == true)
            #expect(siegeDetailsBeforeBreach["siegeBreached"] as? Bool == false)
            #expect(siegeDetailsBeforeBreach["siegeCanAssault"] as? Bool == false)
            #expect((siegeDetailsBeforeBreach["siegeLastRollText"] as? String)?.contains("Food Shortage") == true)

            // Breach walls and execute Storm Assault.
            siege.breached = true
            s.simulation.world.military.sieges[s.simulation.world.military.sieges.count - 1] = siege
            let siegeDetailsBreached = controller.selectedProvinceDetails()
            #expect(siegeDetailsBreached["siegeBreached"] as? Bool == true)
            #expect(siegeDetailsBreached["siegeCanAssault"] as? Bool == true)

            let assaultRes = controller.assaultSelectedProvinceFort()
            #expect((assaultRes["summaryText"] as? String)?.isEmpty == false)
            let afterAssault = controller.selectedProvinceDetails()
            #expect((afterAssault["assaultResultText"] as? String)?.isEmpty == false)
        }
    }

    @Test("Budget bridge handles summary, tax sliders, loans, debasement, and bankruptcy checks")
    func budgetBridgeOperations() {
        let controller = GezGodotController()
        let emptyBudget = controller.budgetDetails()
        #expect(emptyBudget["valid"] as? Bool == false)
        let r0 = controller.setTaxLevel(taxClassIndex: 0, level: 0.25)
        let r1 = controller.borrowFromBank(bankIndex: 0, amount: 50.0)
        let r2 = controller.repayLoan(loanIndex: 0)
        let r3 = controller.debaseOnce()
        let r4 = controller.setDebasing(on: true)
        #expect(!r0)
        #expect(!r1)
        #expect(!r2)
        #expect(r3 == 0)
        #expect(!r4)

        let setupOk = controller.setup(dataDirectoryPath: "", tag: "TUR")
        #expect(setupOk)
        let initial = controller.budgetDetails()
        #expect(initial["valid"] as? Bool == true)
        #expect(initial["isBankrupt"] as? Bool == false)
        #expect((initial["bankruptcyWarning"] as? String)?.isEmpty == true)

        let taxes = initial["taxes"] as? [[String: Any]] ?? []
        #expect(taxes.count == TaxClass.allCases.count)
        let banks = initial["banks"] as? [[String: Any]] ?? []
        #expect(!banks.isEmpty)

        // Tax slider range and index checks.
        let badTax1 = controller.setTaxLevel(taxClassIndex: -1, level: 0.2)
        let badTax2 = controller.setTaxLevel(taxClassIndex: 99, level: 0.2)
        let badTax3 = controller.setTaxLevel(taxClassIndex: 0, level: .nan)
        let goodTax = controller.setTaxLevel(taxClassIndex: 0, level: 0.35)
        #expect(!badTax1)
        #expect(!badTax2)
        #expect(!badTax3)
        #expect(goodTax)
        let afterTax = controller.budgetDetails()
        let updatedTaxes = afterTax["taxes"] as? [[String: Any]] ?? []
        #expect(abs((updatedTaxes[0]["level"] as? Double ?? 0.0) - 0.35) < 0.001)

        // Borrowing & repaying loans + out-of-range checks.
        let firstBankIndex = banks[0]["bankIndex"] as? Int ?? 0
        let firstAmount = (banks[0]["amounts"] as? [Double])?.first ?? 50.0
        let badBank1 = controller.borrowFromBank(bankIndex: -1, amount: 50.0)
        let badBank2 = controller.borrowFromBank(bankIndex: 999, amount: 50.0)
        let badAmt1 = controller.borrowFromBank(bankIndex: firstBankIndex, amount: 0.0)
        let badAmt2 = controller.borrowFromBank(bankIndex: firstBankIndex, amount: .infinity)
        #expect(!badBank1)
        #expect(!badBank2)
        #expect(!badAmt1)
        #expect(!badAmt2)

        let treasuryBeforeLoan = afterTax["treasury"] as? Double ?? 0.0
        let initialLoansCount = (afterTax["loans"] as? [[String: Any]] ?? []).count
        let borrowOk = controller.borrowFromBank(bankIndex: firstBankIndex, amount: firstAmount)
        #expect(borrowOk)
        let afterLoan = controller.budgetDetails()
        let loansAfterBorrow = afterLoan["loans"] as? [[String: Any]] ?? []
        #expect(loansAfterBorrow.count == initialLoansCount + 1)
        #expect((afterLoan["treasury"] as? Double ?? 0.0) >= treasuryBeforeLoan + firstAmount - 0.01)

        let badRepay1 = controller.repayLoan(loanIndex: -1)
        let badRepay2 = controller.repayLoan(loanIndex: 999_999)
        let borrowedLoanIdx = loansAfterBorrow.last?["loanIndex"] as? Int ?? -1
        let repayOk = controller.repayLoan(loanIndex: borrowedLoanIdx)
        #expect(!badRepay1)
        #expect(!badRepay2)
        #expect(repayOk)
        let afterRepay = controller.budgetDetails()
        let loansAfterRepay = afterRepay["loans"] as? [[String: Any]] ?? []
        #expect(loansAfterRepay.count == initialLoansCount)

        // Debase once & ongoing debasement toggle.
        let inflationBefore = afterRepay["inflation"] as? Double ?? 0.0
        let treasuryBeforeDebase = afterRepay["treasury"] as? Double ?? 0.0
        let gained = controller.debaseOnce()
        #expect(gained > 0.0)
        let afterDebase = controller.budgetDetails()
        #expect((afterDebase["treasury"] as? Double ?? 0.0) > treasuryBeforeDebase)
        #expect((afterDebase["inflation"] as? Double ?? 0.0) > inflationBefore)

        let debaseOnOk = controller.setDebasing(on: true)
        #expect(debaseOnOk)
        #expect(controller.budgetDetails()["isDebasing"] as? Bool == true)
        let debaseOffOk = controller.setDebasing(on: false)
        #expect(debaseOffOk)
        #expect(controller.budgetDetails()["isDebasing"] as? Bool == false)

        // Bankruptcy warning flag surfaces cleanly.
        if let s = controller.session, let player = s.playerCountry {
            s.simulation.world.countries.bankruptMonthsLeft[player.index] = 10
            let bankruptBudget = controller.budgetDetails()
            #expect(bankruptBudget["isBankrupt"] as? Bool == true)
            #expect(bankruptBudget["bankruptMonthsLeft"] as? Int == 10)
            #expect((bankruptBudget["bankruptcyWarning"] as? String)?.isEmpty == false)
        }
    }

    @Test("Trade bridge handles route estimate/create/cancel, toll policy, embargoes, and map routes")
    func tradeBridgeOperations() {
        let controller = GezGodotController()
        let emptyTrade = controller.tradeWindowDetails()
        #expect(emptyTrade["valid"] as? Bool == false)
        #expect(controller.estimateTradeRoute(goodIndex: 0, fromMarketIndex: 0, toMarketIndex: 1, volume: 25)["hasEstimate"] as? Bool == false)
        #expect(controller.createTradeRoute(goodIndex: 0, fromMarketIndex: 0, toMarketIndex: 1, volume: 25)["created"] as? Bool == false)
        #expect(!controller.cancelTradeRoute(routeIndex: 0))
        #expect(!controller.setTollPolicy(key: "normal"))
        #expect(!controller.toggleEmbargo(countryIndex: 0))

        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        let details = controller.tradeWindowDetails()
        #expect(details["valid"] as? Bool == true)
        let goods = details["goods"] as? [[String: Any]] ?? []
        let markets = details["markets"] as? [[String: Any]] ?? []
        let policies = details["tollPolicies"] as? [[String: Any]] ?? []
        #expect(!goods.isEmpty)
        #expect(markets.count >= 2)
        #expect(!policies.isEmpty)

        // Out-of-range & invalid inputs.
        #expect(controller.estimateTradeRoute(goodIndex: -1, fromMarketIndex: 0, toMarketIndex: 1, volume: 25)["hasEstimate"] as? Bool == false)
        #expect(controller.estimateTradeRoute(goodIndex: 0, fromMarketIndex: -1, toMarketIndex: 1, volume: 25)["hasEstimate"] as? Bool == false)
        #expect(controller.estimateTradeRoute(goodIndex: 0, fromMarketIndex: 0, toMarketIndex: 999, volume: 25)["hasEstimate"] as? Bool == false)
        #expect(controller.estimateTradeRoute(goodIndex: 0, fromMarketIndex: 0, toMarketIndex: 0, volume: 25)["canCreate"] as? Bool == false)
        #expect(!controller.cancelTradeRoute(routeIndex: -1))
        #expect(!controller.cancelTradeRoute(routeIndex: 999_999))
        #expect(!controller.setTollPolicy(key: "invalid_policy"))
        #expect(!controller.toggleEmbargo(countryIndex: -1))
        #expect(!controller.toggleEmbargo(countryIndex: 999_999))

        // Foreign country cannot be cancelled by player, and self cannot be embargoed.
        if let s = controller.session, let player = s.playerCountry {
            #expect(!controller.toggleEmbargo(countryIndex: player.index))
            if let foreignIdx = s.world.economy.routes.firstIndex(where: { $0.owner != player }) {
                #expect(!controller.cancelTradeRoute(routeIndex: foreignIdx))
            }
            if let otherCountry = s.world.countries.ids.first(where: { $0 != player }) {
                #expect(controller.toggleEmbargo(countryIndex: otherCountry.index))
                let afterEmbargo = controller.tradeWindowDetails()
                let embList = afterEmbargo["embargoes"] as? [[String: Any]] ?? []
                #expect(embList.contains { ($0["countryIndex"] as? Int) == otherCountry.index })
                #expect(controller.toggleEmbargo(countryIndex: otherCountry.index))
                let afterLift = controller.tradeWindowDetails()
                let liftList = afterLift["embargoes"] as? [[String: Any]] ?? []
                #expect(!liftList.contains { ($0["countryIndex"] as? Int) == otherCountry.index })
            }
        }

        // Toll policy update.
        if let targetPolicyKey = policies.last?["key"] as? String {
            #expect(controller.setTollPolicy(key: targetPolicyKey))
            #expect(controller.tradeWindowDetails()["tollPolicyKey"] as? String == targetPolicyKey)
        }

        // Find a valid reachable route pair, create it, inspect map route layer data + signature, then cancel it.
        var foundPair: (good: Int, fromM: Int, toM: Int)? = nil
        outer: for g in goods.prefix(10) {
            guard let gIdx = g["goodIndex"] as? Int else { continue }
            let dForGood = controller.tradeWindowDetails(draftGoodIndex: gIdx)
            let sugs = dForGood["sourceSuggestions"] as? [[String: Any]] ?? []
            guard let src = sugs.first?["marketIndex"] as? Int else { continue }
            for m in markets {
                guard let dst = m["marketIndex"] as? Int, dst != src else { continue }
                let est = controller.estimateTradeRoute(goodIndex: gIdx, fromMarketIndex: src, toMarketIndex: dst, volume: 10.0)
                if est["canCreate"] as? Bool == true {
                    foundPair = (gIdx, src, dst)
                    break outer
                }
            }
        }

        if let pair = foundPair {
            let mapBefore = controller.mapTradeRoutesData()
            let sigBefore = mapBefore["signature"] as? String ?? ""
            let routesBeforeCount = (controller.tradeWindowDetails()["routes"] as? [[String: Any]] ?? []).count

            let createdRes = controller.createTradeRoute(
                goodIndex: pair.good,
                fromMarketIndex: pair.fromM,
                toMarketIndex: pair.toM,
                volume: 10.0
            )
            #expect(createdRes["created"] as? Bool == true)

            let afterCreate = controller.tradeWindowDetails()
            let routesAfter = afterCreate["routes"] as? [[String: Any]] ?? []
            #expect(routesAfter.count == routesBeforeCount + 1)

            let mapAfter = controller.mapTradeRoutesData()
            let sigAfter = mapAfter["signature"] as? String ?? ""
            #expect(sigAfter != sigBefore)
            #expect(!(mapAfter["markets"] as? [[String: Any]] ?? []).isEmpty)

            if let createdIdx = routesAfter.last?["routeIndex"] as? Int {
                #expect(controller.cancelTradeRoute(routeIndex: createdIdx))
                let afterCancel = controller.tradeWindowDetails()
                #expect((afterCancel["routes"] as? [[String: Any]] ?? []).count == routesBeforeCount)
                let sigCancelled = controller.mapTradeRoutesData()["signature"] as? String ?? ""
                #expect(sigCancelled != sigAfter)
            }
        }
    }

    @Test("Province building details expose levels, costs, materials, construction progress, and refusals")
    func selectedProvinceBuildingsDetails() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session, let player = s.playerCountry else {
            Issue.record("Missing session or player")
            return
        }
        guard let ownedProv = s.world.provinces.ids.first(where: { s.world.provinces.owner[$0.index] == player }) else {
            Issue.record("No owned province for TUR")
            return
        }
        s.select(province: ownedProv)

        let provDetails = controller.selectedProvinceDetails()
        #expect(provDetails["isPlayerOwned"] as? Bool == true)
        #expect((provDetails["slotsTotal"] as? Int ?? 0) >= 0)
        #expect(!(provDetails["slotsText"] as? String ?? "").isEmpty)

        let options = provDetails["buildableOptions"] as? [[String: Any]] ?? []
        #expect(options.count == s.world.economy.buildingTypes.count)
        let firstWithMaterials = options.first { !($0["materials"] as? [[String: Any]] ?? []).isEmpty }
        #expect(firstWithMaterials != nil)
        #expect((firstWithMaterials?["materialsText"] as? String)?.isEmpty == false)

        if let buildable = options.first(where: { $0["canBuild"] as? Bool == true }),
           let typeIdx = buildable["typeIndex"] as? Int {
            #expect((buildable["effectText"] as? String)?.isEmpty == false)
            let buildOk = controller.buildInSelectedProvince(buildingTypeIndex: typeIdx)
            #expect(buildOk)

            let afterBuild = controller.selectedProvinceDetails()
            let constructions = afterBuild["constructions"] as? [[String: Any]] ?? []
            #expect(!constructions.isEmpty)
            #expect((constructions[0]["totalMonths"] as? Int ?? 0) > 0)
            #expect((constructions[0]["monthsLeft"] as? Int ?? 0) > 0)

            let updatedOptions = afterBuild["buildableOptions"] as? [[String: Any]] ?? []
            let matching = updatedOptions.first { $0["typeIndex"] as? Int == typeIdx }
            #expect(matching?["canBuild"] as? Bool == false)
            #expect((matching?["refusalReason"] as? String)?.isEmpty == false)
        }
    }

    @Test("Court bridge exposes ruler, family tree, council, vassals, marriages, chronicle, and bounds checks")
    func courtBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))

        let topBar = controller.playerTopBarDetails()
        #expect(topBar["tag"] as? String == "TUR")
        #expect((topBar["stabilityText"] as? String)?.hasPrefix("Stability") == true)
        // Inflation for the top bar badge, in whole percent (0 at the start).
        #expect((topBar["inflationPercent"] as? Int).map { $0 >= 0 } == true)

        let court = controller.courtDetails()
        #expect(court["valid"] as? Bool == true)
        #expect(court["playerTag"] as? String == "TUR")
        #expect(court["showingRuler"] as? Bool == true)

        let charDict = court["character"] as? [String: Any] ?? [:]
        #expect(charDict["valid"] as? Bool == true)
        #expect(!(charDict["fullName"] as? String ?? "").isEmpty)
        let skills = charDict["skills"] as? [[String: Any]] ?? []
        #expect(skills.count == 5)
        let familyTree = court["familyTree"] as? [[String: Any]] ?? []
        #expect(!familyTree.isEmpty)

        // Character inspection + back to ruler + out-of-range check
        #expect(!controller.setViewedCharacter(characterIndex: 999_999))
        if let firstNode = familyTree.last,
           let cIdx = firstNode["characterIndex"] as? Int {
            #expect(controller.setViewedCharacter(characterIndex: cIdx))
            let inspected = controller.courtDetails()
            let inspChar = inspected["character"] as? [String: Any] ?? [:]
            #expect(inspChar["characterIndex"] as? Int == cIdx)
        }
        #expect(controller.setViewedCharacter(characterIndex: -1))
        #expect(controller.courtDetails()["showingRuler"] as? Bool == true)

        // Council seats, appoint newcomer, leave empty, appoint candidate
        let seats = court["councilSeats"] as? [[String: Any]] ?? []
        #expect(seats.count == 5)
        #expect(!controller.appointCouncilSeat(seatIndex: 99, characterIndex: 0))
        #expect(!controller.appointCouncilSeat(seatIndex: 0, characterIndex: 999_999))
        #expect(!controller.appointCouncilNewcomer(seatIndex: 99))
        #expect(controller.appointCouncilNewcomer(seatIndex: 0))
        let afterNewcomer = controller.courtDetails()["councilSeats"] as? [[String: Any]] ?? []
        #expect((afterNewcomer[0]["holderIndex"] as? Int ?? -1) >= 0)
        #expect(controller.appointCouncilSeat(seatIndex: 0, characterIndex: -1))
        let afterEmpty = controller.courtDetails()["councilSeats"] as? [[String: Any]] ?? []
        #expect(afterEmpty[0]["holderIndex"] as? Int == -1)

        // Marriage candidates & propose (switch to FRA or check TUR family)
        let family = court["marriageableFamily"] as? [[String: Any]] ?? []
        if let famIdx = family.first?["characterIndex"] as? Int {
            let withCands = controller.courtDetails(marryingCharacterIndex: famIdx)
            let cands = withCands["marriageCandidates"] as? [[String: Any]] ?? []
            if let candIdx = cands.first?["characterIndex"] as? Int {
                #expect(controller.proposeMarriage(familyCharacterIndex: famIdx, candidateCharacterIndex: candIdx))
            }
        }
        #expect(!controller.proposeMarriage(familyCharacterIndex: 999_999, candidateCharacterIndex: 0))

        // Grant and revoke land from Court
        #expect(!controller.grantProvinceToCharacter(provinceIndex: 999_999, characterIndex: 0))
        #expect(!controller.revokeProvinceHolder(provinceIndex: 999_999))
        let unheld = court["unheldProvinces"] as? [[String: Any]] ?? []
        let grantCands = court["grantCandidates"] as? [[String: Any]] ?? []
        if let pIdx = unheld.first?["provinceIndex"] as? Int,
           let cIdx = grantCands.first?["characterIndex"] as? Int {
            #expect(controller.grantProvinceToCharacter(provinceIndex: pIdx, characterIndex: cIdx))
            let afterGrant = controller.courtDetails()
            let vassals = afterGrant["vassals"] as? [[String: Any]] ?? []
            #expect(!vassals.isEmpty)
            #expect(controller.revokeProvinceHolder(provinceIndex: pIdx))
            let afterRevoke = controller.courtDetails()
            let chronicle = afterRevoke["chronicle"] as? [[String: Any]] ?? []
            #expect(!chronicle.isEmpty)
        }
    }

    @Test("Government bridge exposes stability, 11 law areas, estates, privileges, and reforms")
    func governmentBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session, let player = s.playerCountry else {
            Issue.record("Missing session or player")
            return
        }

        // Give enough treasury and reform progress to test actions cleanly
        s.simulation.world.countries.treasury[player.index] = 5_000
        s.simulation.world.government.stability[player.index] = 0
        s.simulation.world.government.reformProgress[player.index] = 500

        let gov = controller.governmentDetails()
        #expect(gov["valid"] as? Bool == true)
        #expect(!(gov["governmentName"] as? String ?? "").isEmpty)
        let laws = gov["laws"] as? [[String: Any]] ?? []
        #expect(laws.count == 11)
        let estates = gov["estates"] as? [[String: Any]] ?? []
        #expect(!estates.isEmpty)

        // Raise stability
        #expect(gov["canRaiseStability"] as? Bool == true)
        #expect(controller.raiseStability())
        #expect(controller.governmentDetails()["stability"] as? Int == 1)

        // Change law + refusal on second change while pending + out-of-range
        let badLaw = controller.changeLaw(areaIndex: 99, optionIndex: 0)
        #expect(badLaw["ok"] as? Bool == false)
        if let area = laws.first,
           let areaIdx = area["areaIndex"] as? Int,
           let opt = (area["options"] as? [[String: Any]])?.first,
           let optIdx = opt["optionIndex"] as? Int {
            let res = controller.changeLaw(areaIndex: areaIdx, optionIndex: optIdx)
            #expect(res["ok"] as? Bool == true)
            let updatedLaws = controller.governmentDetails()["laws"] as? [[String: Any]] ?? []
            #expect(updatedLaws[areaIdx]["hasPending"] as? Bool == true)

            let secondRes = controller.changeLaw(areaIndex: areaIdx, optionIndex: optIdx)
            #expect(secondRes["ok"] as? Bool == false)
            #expect(!(secondRes["reason"] as? String ?? "").isEmpty)
        }

        // Grant and revoke privilege
        #expect(!controller.grantPrivilege(privilegeIndex: 999_999))
        #expect(!controller.revokePrivilege(privilegeIndex: 999_999))
        if let firstEst = estates.first,
           let privs = firstEst["privileges"] as? [[String: Any]],
           let ungranted = privs.first(where: { $0["granted"] as? Bool == false }),
           let pid = ungranted["privilegeIndex"] as? Int {
            #expect(controller.grantPrivilege(privilegeIndex: pid))
            #expect(controller.revokePrivilege(privilegeIndex: pid))
        }

        // Adopt reform
        #expect(!controller.adoptReform(optionIndex: 999_999))
        let nextOpts = gov["nextReformOptions"] as? [[String: Any]] ?? []
        if let firstOptIdx = nextOpts.first?["optionIndex"] as? Int {
            #expect(controller.adoptReform(optionIndex: firstOptIdx))
            let adopted = controller.governmentDetails()["adoptedReforms"] as? [[String: Any]] ?? []
            #expect(!adopted.isEmpty)
        }
    }

    @Test("Diplomacy, War, Peace Negotiation, Pending Peace Offers, and Alerts bridge methods & bounds checks")
    func diplomacyWarsPeaceAndAlertsBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session, let player = s.playerCountry else {
            Issue.record("Missing session or player")
            return
        }

        // Out-of-bounds checks
        #expect(!controller.setSelectedDiplomacyCountry(-1))
        #expect(!controller.setSelectedDiplomacyCountry(999_999))
        #expect(!controller.setSelectedDiplomacyCountry(player.index))
        #expect(!controller.toggleAlliance(countryIndex: 999_999))
        #expect(!controller.toggleGuarantee(countryIndex: 999_999))
        #expect(!controller.toggleNonAggression(countryIndex: 999_999))
        #expect(!controller.toggleMilitaryAccess(countryIndex: 999_999))
        #expect(!controller.improveRelations(countryIndex: 999_999))
        #expect(controller.provinceFocusPoint(provinceIndex: -1)["hasCenter"] as? Bool == false)
        #expect(controller.provinceFocusPoint(provinceIndex: 999_999)["hasCenter"] as? Bool == false)
        #expect((controller.declareWar(targetCountryIndex: 999_999, cbIndex: 0)["ok"] as? Bool) == false)

        // Diplomacy details & actions
        let dip = controller.diplomacyDetails()
        #expect(dip["hasPlayer"] as? Bool == true)
        #expect((dip["relationSlotsCap"] as? Int ?? 0) > 0)
        let countries = dip["countries"] as? [[String: Any]] ?? []
        #expect(!countries.isEmpty)

        // Pick a neighbor NOT at war yet with positive or boostable opinion
        let nonWarCountry = countries.first {
            ($0["isAtWar"] as? Bool == false)
        }
        guard let targetIdx = nonWarCountry?["index"] as? Int else {
            Issue.record("Expected at least one peaceful foreign country")
            return
        }
        #expect(controller.setSelectedDiplomacyCountry(targetIdx))
        let targetDip = controller.diplomacyDetails(targetCountryIndex: targetIdx)
        let targetInfo = targetDip["target"] as? [String: Any] ?? [:]
        #expect(targetInfo["hasTarget"] as? Bool == true)
        #expect(!(targetInfo["casusBelli"] as? [[String: Any]] ?? []).isEmpty)

        // Improve relations, toggle guarantee/access/NAP/alliance
        s.simulation.world.diplomacy.setOpinion(of: player, by: CountryID(targetIdx), value: 10)
        #expect(controller.improveRelations(countryIndex: targetIdx))
        let afterImprove = (controller.diplomacyDetails(targetCountryIndex: targetIdx)["target"] as? [String: Any])?["opinion"] as? Int ?? 0
        #expect(afterImprove == 25)

        #expect(controller.toggleAlliance(countryIndex: targetIdx))
        #expect(((controller.diplomacyDetails(targetCountryIndex: targetIdx)["target"] as? [String: Any])?["isAllied"] as? Bool) == true)
        #expect(controller.toggleAlliance(countryIndex: targetIdx))
        #expect(controller.toggleGuarantee(countryIndex: targetIdx))
        // The treaty list says which way a guarantee goes (as in the Apple app).
        let guaranteeLabels = (((controller.diplomacyDetails(targetCountryIndex: targetIdx)["target"] as? [String: Any])?["treaties"]
            as? [[String: Any]]) ?? []).compactMap { $0["label"] as? String }
        #expect(guaranteeLabels.contains("Guaranteeing them"))
        #expect(controller.toggleGuarantee(countryIndex: targetIdx))
        #expect(controller.toggleNonAggression(countryIndex: targetIdx))
        #expect(controller.toggleNonAggression(countryIndex: targetIdx))
        #expect(controller.toggleMilitaryAccess(countryIndex: targetIdx))
        #expect(controller.toggleMilitaryAccess(countryIndex: targetIdx))

        // Declare war on a fresh country with no truce (remove truce if present to make deterministic)
        s.simulation.world.diplomacy.removeTreaty(.truce, between: player, and: CountryID(targetIdx))
        let warRes = controller.declareWar(targetCountryIndex: targetIdx, cbIndex: 0, breakTruce: true)
        #expect(warRes["ok"] as? Bool == true)
        let warID = warRes["warID"] as? String ?? ""
        #expect(!warID.isEmpty)

        // Top bar & Wars details
        let top = controller.playerTopBarDetails()
        #expect((top["activeWarsCount"] as? Int ?? 0) >= 1)

        // Occupy one province of target so occupiedProvinces & peace negotiation work cleanly
        if let enemyProv = s.world.provinces(ownedBy: CountryID(targetIdx)).first {
            s.simulation.world.provinces.occupiedBy[enemyProv.index] = player
            #expect(controller.provinceFocusPoint(provinceIndex: enemyProv.index)["hasCenter"] as? Bool == true)
        }

        let wars = controller.warsDetails(includeAIWars: false)["wars"] as? [[String: Any]] ?? []
        #expect(wars.contains { ($0["warID"] as? String) == warID })

        // Peace negotiation details
        let peace = controller.peaceNegotiationDetails(warID: warID, indemnityAmount: 50, includeReparations: true)
        #expect(peace["valid"] as? Bool == true)
        #expect((peace["totalCost"] as? Int ?? 0) > 0)
        #expect((peace["cedeProvinces"] as? [[String: Any]] ?? []).isEmpty == false)

        // White peace at 100% battle WS to verify proposePeaceOffer succeeds
        if let idx = s.simulation.world.diplomacy.wars.firstIndex(where: { $0.id == warID }) {
            s.simulation.world.diplomacy.wars[idx].warScore = 1.0
        }
        let propRes = controller.proposePeaceOffer(warID: warID)
        #expect(propRes["ok"] as? Bool == true)
        #expect(s.world.diplomacy.wars.contains { $0.id == warID } == false)

        // Pending peace offer & activeAlerts
        let fakeOffer = PeaceOffer(warID: "fake-offer-1", winner: CountryID(targetIdx), loser: player, demands: [])
        s.simulation.world.diplomacy.pendingPeaceOffers.append(fakeOffer)
        s.simulation.world.government.stability[player.index] = -2
        let alerts = controller.activeAlerts()
        #expect(alerts.contains { ($0["kind"] as? String) == "peaceOffer" })
        #expect(alerts.contains { ($0["kind"] as? String) == "lowStability" })
        #expect(controller.respondToPendingPeaceOffer(warID: "fake-offer-1", accept: false))
        #expect(!controller.respondToPendingPeaceOffer(warID: "missing-offer", accept: false))
    }

    @Test("Map town icons expose coordinates, dev, forts, capitals, ports, and revision tracking")
    func townIconsAndHeraldryMetadata() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        let rev0 = controller.townIconsRevision
        #expect(rev0 >= 1)

        let metrics = controller.townIconMetrics()
        #expect(!metrics.isEmpty)
        #expect(metrics.count % 6 == 0)

        let count = metrics.count / 6
        var hasCapital = false
        var hasPort = false
        var hasFort = false
        for i in 0..<count {
            let base = i * 6
            let dev = metrics[base + 2]
            let fort = metrics[base + 3]
            let isCap = metrics[base + 4] >= 0.5
            let isPort = metrics[base + 5] >= 0.5
            #expect(dev >= 1.0)
            if isCap { hasCapital = true }
            if isPort { hasPort = true }
            if fort >= 2.0 { hasFort = true }
        }
        #expect(hasCapital)
        #expect(hasPort)
        #expect(hasFort)

        let armiesWin = controller.armiesWindowDetails()
        #expect(armiesWin["playerTag"] as? String == "TUR")
        #expect(armiesWin["playerColorR"] as? Int != nil)
    }

    @Test("Top bar details bundle date/speed/alerts signature and map armies signature tracks state")
    func topBarBundleAndArmiesSignature() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        let top = controller.playerTopBarDetails()
        #expect(top["dateText"] as? String == "30 May 1453")
        #expect(top["isPaused"] as? Bool == true)
        #expect(top["alertsSignature"] as? String != nil)

        let sig1 = controller.mapArmiesSignature()
        let sig2 = controller.mapArmiesSignature()
        #expect(sig1 == sig2)
        _ = controller.raiseAllLevies()
        let sig3 = controller.mapArmiesSignature()
        #expect(sig3 != sig1)
    }

    @Test("Phase 9 Part A bridge: battle prompt, lead in person, deploy move, start, speed, tick")
    func phase9PartABattleBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "FRA"))
        guard let s = controller.session,
              let fra = s.world.countries.id(forTag: "FRA"),
              let eng = s.world.countries.id(forTag: "ENG"),
              let bordeaux = s.world.provinces.id(named: "Bordeaux") else {
            Issue.record("Missing FRA/ENG/Bordeaux")
            return
        }

        // Initial state: no prompt, no active battle
        #expect(!controller.hasPendingBattlePrompt())
        #expect(controller.pendingBattlePromptData()["active"] as? Bool == false)
        #expect(!controller.isTacticalBattleActive())
        #expect(controller.battleStateData()["active"] as? Bool == false)

        // Invalid storm assault request reports cleanly
        let badAssault = controller.requestStormAssaultChoice(provinceIndex: bordeaux.index)
        #expect(badAssault["opened"] as? Bool == false)

        // Trigger a player battle in Bordeaux
        for aid in s.world.military.armies(in: bordeaux) {
            s.simulation.world.military.armies.remove(aid)
        }
        let inf = s.world.military.unit("infantry")!
        s.simulation.world.military.armies.append(
            name: "French Guard",
            owner: fra,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        s.simulation.world.military.armies.append(
            name: "English Guard",
            owner: eng,
            province: bordeaux,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0)]
        )
        _ = s.advanceDays(1)
        #expect(controller.hasPendingBattlePrompt())
        let prompt = controller.pendingBattlePromptData()
        #expect(prompt["active"] as? Bool == true)
        #expect(prompt["provinceIndex"] as? Int == bordeaux.index)

        // Lead Battle in Person
        #expect(controller.chooseLeadBattleInPerson())
        #expect(!controller.hasPendingBattlePrompt())
        #expect(controller.isTacticalBattleActive())

        let state1 = controller.battleStateData()
        #expect(state1["active"] as? Bool == true)
        #expect(state1["phase"] as? String == "deployment")
        let units1 = state1["units"] as? [[String: Any]] ?? []
        #expect(units1.count == 2)

        // Move player unit in deployment zone & start battle
        #expect(controller.deployMoveBattleUnit(unitIndex: 0, x: 220.0, y: 310.0, facing: 0.1))
        #expect(controller.startTacticalBattle())
        #expect(controller.setTacticalBattleSpeed(speedIndex: 2))
        let ticked = controller.tickTacticalBattle(deltaSeconds: 0.5)
        #expect(ticked >= 1)

        // Part B tactical orders via controller
        #expect(controller.orderBattleFormation(unitIndices: [0], formationKey: "wedge"))
        #expect(controller.orderBattleStance(unitIndices: [0], stanceKey: "charge"))
        #expect(controller.orderBattlePath(unitIndices: [0], points: [TacticalPoint(x: 420, y: 310), TacticalPoint(x: 560, y: 350)]))
        #expect(controller.orderBattleFrontline(unitIndices: [0], startX: 480, startY: 250, endX: 480, endY: 450))
        #expect(controller.orderBattleMove(unitIndices: [0], x: 520, y: 360))
        #expect(controller.orderBattleAttack(unitIndices: [0], targetUnitIndex: 1))
        #expect(controller.orderBattleRetreat(unitIndices: [0]))
        let afterOrder = controller.battleStateData()
        let uList = afterOrder["units"] as? [[String: Any]] ?? []
        #expect(uList[0]["stance"] as? String == "retreat")
    }

    @Test("Phase 9 Part C bridge: storm assault prompt, siege equipment, attack structure, structures & keepZone")
    func phase9PartCSiegeAssaultBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session,
              let tur = s.world.countries.id(forTag: "TUR"),
              let byz = s.world.countries.id(forTag: "BYZ") ?? s.world.countries.ids.first(where: { $0 != tur }),
              let prov = s.world.provinces.ids.first(where: { s.world.provinces.fortLevel[$0.index] > 0 && s.world.provinces.owner[$0.index] == byz })
                ?? s.world.provinces.ids.first(where: { s.world.provinces.fortLevel[$0.index] > 0 }) else {
            Issue.record("Missing fortified province")
            return
        }

        let ownerCountry = s.world.provinces.owner[prov.index]
        for aid in s.world.military.armies(in: prov) {
            s.simulation.world.military.armies.remove(aid)
        }
        let inf = s.world.military.unit("infantry")!
        let art = s.world.military.unit("bombard") ?? s.world.military.unit("artillery") ?? inf
        s.simulation.world.military.armies.append(
            name: "Assault Force",
            owner: tur,
            province: prov,
            regiments: [
                Regiment(type: inf.id, origin: .professional, men: 1_000, morale: 3.0),
                Regiment(type: art.id, origin: .professional, men: 800, morale: 2.8)
            ]
        )
        s.simulation.world.military.sieges.append(
            Siege(province: prov, besieger: tur, startDate: Scenario1453.startDate, breached: true)
        )
        let req = controller.requestStormAssaultChoice(provinceIndex: prov.index)
        #expect(req["opened"] as? Bool == true)
        #expect(controller.chooseLeadBattleInPerson())

        let st = controller.battleStateData()
        #expect(st["isAssault"] as? Bool == true)
        let structs = st["structures"] as? [[String: Any]] ?? []
        #expect(structs.count >= 7)
        let kz = st["keepZone"] as? [String: Any] ?? [:]
        #expect(!kz.isEmpty)

        #expect(controller.startTacticalBattle())
        #expect(controller.orderBattleSiegeEquipment(unitIndices: [0], equipmentKey: "ram"))
        #expect(controller.orderBattleAttackStructure(unitIndices: [1], structureId: 3))
        let stepped = controller.tickTacticalBattle(deltaSeconds: 1.0)
        #expect(stepped >= 1)
        _ = ownerCountry
    }

    @Test("Phase 9 Part D bridge: finishTacticalBattle writes back results cleanly")
    func phase9PartDWriteBackBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session,
              let tur = s.world.countries.id(forTag: "TUR"),
              let eng = s.world.countries.id(forTag: "ENG"),
              let prov = s.world.provinces.ids.first(where: { s.world.provinces.fortLevel[$0.index] > 0 && s.world.provinces.owner[$0.index] != tur }) else {
            Issue.record("Missing TUR/prov")
            return
        }
        let targetOwner = s.world.provinces.owner[prov.index]
        for aid in s.world.military.armies(in: prov) {
            s.simulation.world.military.armies.remove(aid)
        }
        let inf = s.world.military.unit("infantry")!
        s.simulation.world.military.armies.append(
            name: "Ottoman Vanguard",
            owner: tur,
            province: prov,
            regiments: [
                Regiment(type: inf.id, origin: .professional, men: 2_000, morale: 3.0),
                Regiment(type: inf.id, origin: .professional, men: 2_000, morale: 3.0)
            ]
        )
        s.simulation.world.military.sieges.append(
            Siege(province: prov, besieger: tur, startDate: Scenario1453.startDate, breached: true)
        )
        _ = controller.requestStormAssaultChoice(provinceIndex: prov.index)
        #expect(controller.chooseLeadBattleInPerson())
        #expect(controller.startTacticalBattle())

        // Resolve tactical assault cleanly to completion
        if var b = s.tacticalBattle {
            let allAtt = (0..<b.units.count).filter { b.units.side[$0] == .attacker }
            b.issueStanceOrder(unitIndices: allAtt, stance: .charge)
            b.stepTicks(24_000) // battles last minutes since the pace change
            s.tacticalBattle = b
        }
        let preState = controller.battleStateData()
        let endedPhase = preState["phase"] as? String ?? ""
        #expect(endedPhase == "ended")
        let preview = preState["resultPreview"] as? [String: Any] ?? [:]
        #expect(!preview.isEmpty)

        let res = controller.finishTacticalBattleData()
        let wasApplied = res["applied"] as? Bool ?? false
        let activeAfter = controller.isTacticalBattleActive()
        #expect(wasApplied)
        #expect(!activeAfter)
        _ = (eng, targetOwner)
    }

    @Test("Naval bridge functions cover fleets, shipbuilding, orders, embark/disembark, battles, and blockades")
    func testNavalBridgeFunctions() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "VEN"))
        guard let s = controller.session,
              let ven = s.world.countries.id(forTag: "VEN"),
              let tur = s.world.countries.id(forTag: "TUR"),
              let venice = s.world.countries.capital[ven.index],
              let adriatic = s.world.provinceSeas[venice.index].first else {
            Issue.record("Missing VEN/TUR/capital")
            return
        }

        // Top bar summary & navies window
        #expect(controller.topBarFleetsText.contains("Fleets"))
        let navWin = controller.naviesWindowDetails()
        #expect((navWin["hasPlayer"] as? Bool) == true)
        #expect((navWin["totalShips"] as? Int ?? 0) > 0)

        // Map overlay signature & data
        let sig0 = controller.mapFleetsSignature()
        let mapData = controller.mapFleetsData()
        let counters = mapData["counters"] as? [[String: Any]] ?? []
        #expect(!counters.isEmpty)

        // Province details with Docks -> build a galley
        _ = controller.selectProvinceByIndex(venice.index)
        let provD = controller.selectedProvinceDetails()
        #expect((provD["hasDocks"] as? Bool) == true)
        let buildable = provD["buildableShips"] as? [[String: Any]] ?? []
        #expect(!buildable.isEmpty)
        let galleyIdx = s.world.navy.shipByKey["galley"]!.index
        #expect(controller.buildShipInSelectedProvince(shipTypeIndex: galleyIdx))
        #expect(!(controller.selectedProvinceDetails()["shipConstructions"] as? [[String: Any]] ?? []).isEmpty)

        // Select fleet, inspect details, assign admiral, split, merge
        guard let venFleet = s.world.navy.fleets(of: ven).first else {
            Issue.record("Missing VEN fleet")
            return
        }
        #expect(controller.selectFleet(fleetId: venFleet.index))
        #expect(controller.selectedFleetId == venFleet.index)
        let det = controller.selectedFleetDetails()
        #expect((det["hasSelection"] as? Bool) == true)
        #expect((det["shipCount"] as? Int ?? 0) >= 2)

        if let cand = (det["admiralCandidates"] as? [[String: Any]])?.first,
           let cIdx = cand["characterIndex"] as? Int {
            #expect(controller.assignFleetAdmiral(fleetId: venFleet.index, characterIndex: cIdx))
            #expect((controller.selectedFleetDetails()["admiralIndex"] as? Int) == cIdx)
        }

        let newFid = controller.splitFleet(fleetId: venFleet.index)
        #expect(newFid >= 0)
        // Dock both to same port if needed? Wait: split leaves both at exact same location!
        #expect(controller.mergeFleetsInLocation(fleetId: venFleet.index))
        #expect(controller.mapFleetsSignature() != sig0)

        // Move mode, sea order, coordinate order, dock order, blockade order
        #expect(controller.setMoveModeForFleet(fleetId: venFleet.index))
        #expect(controller.moveModeFleetId == venFleet.index)
        #expect(controller.orderFleetMoveToSea(fleetId: venFleet.index, seaZoneIndex: adriatic.index))
        #expect(controller.moveModeFleetId == -1)
        let sx = Int(s.world.seaZones.centerX[adriatic.index].rounded())
        let sy = Int(s.world.seaZones.centerY[adriatic.index].rounded())
        _ = controller.orderFleetMoveAt(fleetId: venFleet.index, mapX: sx, mapY: sy)
        #expect(controller.orderFleetDock(fleetId: venFleet.index, portProvinceIndex: venice.index))

        // Dock instantly for embark/disembark test
        s.simulation.world.navy.fleets.location[venFleet.index] = .port(venice)
        s.simulation.world.navy.fleets.path[venFleet.index].removeAll()
        let cog = s.world.navy.shipByKey["cog"]!
        for _ in 0..<2 {
            let ship = s.simulation.world.navy.ships.add(type: cog, fleet: venFleet, crew: 80)
            s.simulation.world.navy.fleets.shipIndices[venFleet.index].append(ship)
        }
        let inf = s.world.military.unit("infantry")!
        let testArmy = s.simulation.world.military.armies.append(
            name: "Adriatic Force", owner: ven, province: venice,
            regiments: [Regiment(type: inf.id, origin: .professional, men: 1000, morale: 3.0)]
        )
        #expect(controller.embarkArmyOnFleet(armyId: Int(testArmy.rawValue), fleetId: venFleet.index))
        #expect(controller.disembarkArmyFromFleet(armyId: Int(testArmy.rawValue), provinceIndex: -1))

        // Blockade nearest enemy in war + selectedSeaDetails + warsDetails
        s.simulation.world.diplomacy.wars.append(War(
            id: "ven_tur_bridge", name: "Aegean War", startDate: Scenario1453.startDate,
            casusBelli: .claim, warGoal: .superiority, attackers: [ven], defenders: [tur]
        ))
        #expect(controller.orderFleetBlockadeNearestEnemy(fleetId: venFleet.index))

        s.select(sea: adriatic)
        let seaD = controller.selectedSeaDetails()
        #expect((seaD["hasSelection"] as? Bool) == true)
        #expect(seaD["isInland"] as? Bool == true)

        let warD = controller.warsDetails()
        let rows = warD["wars"] as? [[String: Any]] ?? []
        #expect(!rows.isEmpty)
        #expect(rows[0]["blockadePct"] != nil)
        #expect(rows[0]["recentNavalBattles"] != nil)

        controller.clearSelectedFleet()
        #expect(controller.selectedFleetId == -1)
    }

    @Test("Phase 11 bridge: Religion window, missionaries, Hussites, Reformation adoption, cultures & overlay")
    func religionAndCultureBridge() {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "TUR"))
        guard let s = controller.session else {
            Issue.record("Missing session")
            return
        }

        // 1. Religion window & top bar details for Ottomans
        let top = controller.playerTopBarDetails()
        #expect((top["religionButtonText"] as? String)?.contains("Sunni") == true)

        let relWin = controller.religionWindowDetails()
        #expect((relWin["hasPlayer"] as? Bool) == true)
        #expect((relWin["stateReligion"] as? String) == "Sunni")
        #expect((relWin["primaryCultureName"] as? String) == "Turkish")
        #expect((relWin["acceptedSlotsMax"] as? Int ?? 0) >= 3)
        let allSites = relWin["allHolySites"] as? [[String: Any]] ?? []
        #expect(!allSites.isEmpty) // Holy sites catalog loaded (Rome, Konstantiniyye, Mecca, Jerusalem...)

        // 2. Send missionary to Thessaloniki (Orthodox Balkan province), verify province details & overlay, recall
        let tur = s.playerCountry!
        let thessaloniki = s.world.provinces.id(named: "Thessaloniki")
            ?? (0..<s.world.provinces.count).first(where: {
                s.world.provinces.owner[$0] == tur
                    && FaithSystem.missionaryRefusal(s.world, by: tur, in: ProvinceID($0)) == nil
            }).map(ProvinceID.init)!
        #expect(controller.selectProvinceByIndex(thessaloniki.index) >= 2)
        let beforeProv = controller.selectedProvinceDetails()
        #expect((beforeProv["hasMissionary"] as? Bool) == false)
        #expect(beforeProv["conversionText"] != nil)
        #expect(beforeProv["assimilationText"] != nil)
        #expect(beforeProv["religiousUnrestText"] != nil)

        let sendRes = controller.sendMissionary(provinceIndex: thessaloniki.index)
        #expect((sendRes["ok"] as? Bool) == true)
        let duringProv = controller.selectedProvinceDetails()
        #expect((duringProv["hasMissionary"] as? Bool) == true)

        let overlay = controller.faithOverlayData()
        #expect(!(overlay["holySites"] as? [[String: Any]] ?? []).isEmpty)
        #expect(!(overlay["missionaries"] as? [[String: Any]] ?? []).isEmpty)

        #expect(controller.recallMissionary(provinceIndex: thessaloniki.index))
        #expect((controller.selectedProvinceDetails()["hasMissionary"] as? Bool) == false)

        // 3. Accept & revoke Greek culture via bridge
        let greek = s.world.cultures.id(forKey: "greek")!
        let accRes = controller.acceptCulture(cultureIndex: greek.index)
        #expect((accRes["ok"] as? Bool) == true)
        #expect((controller.religionWindowDetails()["acceptedSlotsUsed"] as? Int ?? 0) >= 1)
        #expect(controller.revokeCulture(cultureIndex: greek.index))

        // 4. Switch to Bohemia (BOH) and resolve Hussite question via bridge
        #expect(controller.startNewGame(tag: "BOH"))
        let bohWin = controller.religionWindowDetails()
        #expect((bohWin["isBohemia"] as? Bool) == true)
        #expect((bohWin["hussiteCompactsActive"] as? Bool) == true)
        #expect(controller.resolveHussiteQuestion(choiceKey: "taboriteRevival"))
        let bohWinAfter = controller.religionWindowDetails()
        #expect((bohWinAfter["hussiteCompactsActive"] as? Bool) == false)
        #expect((bohWinAfter["hussiteOutcome"] as? String) == "taboriteRevival")

        // 5. Reformation adoption callable (verify true once Reformation starts & Protestant exists)
        #expect(controller.startNewGame(tag: "HAB"))
        controller.session?.simulation.world.faith.reformationStarted = true
        controller.session?.simulation.world.faith.reformationReligions.insert(.protestant)
        #expect(controller.adoptReformationReligion(religionKey: "protestant"))
        #expect((controller.religionWindowDetails()["stateReligionKey"] as? String) == "protestant")

        // 6. Verify Papal/Mamluk heldHolySites non-empty in 1453 & advanceSimulationDays
        #expect(controller.startNewGame(tag: "MAM"))
        let mamHeld = controller.religionWindowDetails()["heldHolySites"] as? [[String: Any]] ?? []
        #expect(!mamHeld.isEmpty)
        #expect(controller.advanceSimulationDays(30))
        #expect((controller.playerTopBarDetails()["dateText"] as? String) != "30 May 1453")
    }

    @Test("Phase 12 bridge: plague and famine in the province panel, quarantine, cordon, rebels window, answers & overlay")
    func phase12CalamityAndRebelsBridge() throws {
        let controller = GezGodotController()
        #expect(controller.setup(dataDirectoryPath: "", tag: "VEN"))
        let s = try #require(controller.session)
        let ven = try #require(s.playerCountry)
        let venice = try #require(s.world.provinces.id(named: "Venice"))

        // 1. Province panel: an outbreak, a famine and unrest causes show up.
        #expect((controller.provinceCalamityDetails(provinceIndex: -1)["hasProvince"] as? Bool) == false)
        let quiet = controller.provinceCalamityDetails(provinceIndex: venice.index)
        #expect((quiet["hasProvince"] as? Bool) == true)
        #expect((quiet["isPlayerOwned"] as? Bool) == true)
        #expect((quiet["isPort"] as? Bool) == true)
        #expect((quiet["outbreaks"] as? [[String: Any]] ?? []).isEmpty)

        #expect(PlagueSystem.startOutbreak(&s.simulation.world, in: venice, disease: .plague, date: s.date, severity: 1))
        s.simulation.world.provinces.famine[venice.index] = 0.6
        let struck = controller.provinceCalamityDetails(provinceIndex: venice.index)
        #expect((struck["outbreaks"] as? [[String: Any]] ?? []).count == 1)
        #expect((struck["famineText"] as? String) == "60%")
        #expect(!(struck["unrestCauses"] as? [[String: Any]] ?? []).isEmpty)

        // 2. Quarantine and cordon from the panel; a foreign province is refused.
        s.simulation.world.countries.treasury[ven.index] = 500
        #expect((controller.setQuarantine(provinceIndex: venice.index, on: true)["ok"] as? Bool) == true)
        #expect((controller.setCordon(provinceIndex: venice.index, on: true)["ok"] as? Bool) == true)
        let guarded = controller.provinceCalamityDetails(provinceIndex: venice.index)
        #expect((guarded["isQuarantined"] as? Bool) == true)
        #expect((guarded["isCordoned"] as? Bool) == true)
        let paris = try #require(s.world.provinces.id(named: "Paris"))
        #expect((controller.setQuarantine(provinceIndex: paris.index, on: true)["ok"] as? Bool) == false)
        #expect((controller.setCordon(provinceIndex: 99_999, on: true)["ok"] as? Bool) == false)
        #expect((controller.setQuarantine(provinceIndex: venice.index, on: false)["ok"] as? Bool) == true)
        #expect((controller.provinceCalamityDetails(provinceIndex: venice.index)["isQuarantined"] as? Bool) == false)

        // 3. Alerts and the Plague map mode.
        let kinds = controller.activeAlerts().compactMap { $0["kind"] as? String }
        #expect(kinds.contains("plague"))
        #expect(kinds.contains("famine"))
        #expect(controller.setMapMode(key: "plague"))
        let overlay = controller.calamityOverlayData()
        #expect((overlay["outbreaks"] as? [[String: Any]] ?? []).contains { ($0["provinceIndex"] as? Int) == venice.index })
        #expect((overlay["measures"] as? [[String: Any]] ?? []).contains { ($0["provinceIndex"] as? Int) == venice.index })
        #expect(!(overlay["famines"] as? [[String: Any]] ?? []).isEmpty)
        #expect(controller.styleBytes().count > 8)

        // 4. Rebels window: a brewing faction with its demand and the three answers.
        s.simulation.world.unrest.resize(provinces: s.world.provinces.count, countries: s.world.countries.count)
        var faction = RebelFaction(id: 700, country: ven, kind: .peasants)
        faction.progress = 64
        faction.provinces = [venice]
        s.simulation.world.unrest.factions.append(faction)
        let window = controller.rebelsWindowDetails()
        #expect((window["hasPlayer"] as? Bool) == true)
        let rows = window["factions"] as? [[String: Any]] ?? []
        #expect(rows.count == 1)
        #expect((rows.first?["factionId"] as? Int) == 700)
        #expect((rows.first?["progressText"] as? String) == "64%")
        let demandText: String = (rows.first?["demand"] as? String) ?? ""
        let concessionText: String = (rows.first?["concession"] as? String) ?? ""
        #expect(demandText.count > 5)
        #expect(concessionText.count > 5)
        #expect(controller.topBarRebelsText == "Rebels 1")
        #expect(controller.activeAlerts().contains { ($0["kind"] as? String) == "rebels" })
        #expect(controller.setMapMode(key: "unrest"))
        #expect((controller.calamityOverlayData()["rebels"] as? [[String: Any]] ?? []).count == 1)

        let taxBefore = s.world.countries.taxLevel[ven.index][TaxClass.peasants.rawValue]
        #expect((controller.lowerPeasantTaxes()["ok"] as? Bool) == true)
        #expect(s.world.countries.taxLevel[ven.index][TaxClass.peasants.rawValue] < taxBefore)
        #expect((controller.sendTroopsAgainstRebels(factionId: 12_345)["ok"] as? Bool) == false)
        #expect(controller.sendTroopsAgainstRebels(factionId: 700)["reason"] != nil)
        #expect((controller.concedeToRebels(factionId: 700)["ok"] as? Bool) == true)
        #expect((controller.rebelsWindowDetails()["factions"] as? [[String: Any]] ?? []).isEmpty)
        #expect((controller.concedeToRebels(factionId: 700)["ok"] as? Bool) == false)
        #expect(controller.topBarRebelsText == "Rebels")

        // 5. Time still runs with all of it switched on.
        #expect(controller.advanceSimulationDays(40))
        #expect((controller.playerTopBarDetails()["rebelsButtonText"] as? String) != nil)
    }
}
