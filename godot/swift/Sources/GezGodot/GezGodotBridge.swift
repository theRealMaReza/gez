import Foundation
import GezCore
import SwiftGodotRuntime

/// Pure-Swift controller backing `GezGodotBridge`.
/// Kept separate from the `@Godot` `RefCounted` wrapper so unit tests can exercise
/// all buffer encoding, camera math, labels, and simulation stepping without the
/// Godot engine runtime loaded.
public final class GezGodotController {
    public static let styleTextureWidth = 2048

    public private(set) var session: GameSession?
    public var mapMode: MapModeKind = .political

    public init() {}

    @discardableResult
    public func setup(dataDirectoryPath: String, tag: String = Scenario1453.defaultPlayerTag) -> Bool {
        if !dataDirectoryPath.isEmpty {
            GezResources.dataDirectory = URL(fileURLWithPath: dataDirectoryPath, isDirectory: true)
        }
        do {
            let s = try GameSession(tag: tag)
            s.autosaveFrequency = .never
            self.session = s
            return true
        } catch {
            return false
        }
    }

    public var mapWidth: Int { session?.idMap.width ?? 3936 }
    public var mapHeight: Int { session?.idMap.height ?? 2384 }

    /// Map pixel coordinate for a given `(latitude, longitude)` (e.g. `41.0, 29.0` for Constantinople).
    public func focusPoint(latitude: Double = 41.0, longitude: Double = 29.0) -> (x: Double, y: Double) {
        guard let map = session?.world.map else { return (x: 2150, y: 820) }
        let pt = map.point(for: GeoPoint(latitude: latitude, longitude: longitude))
        return (x: Double(pt.x), y: Double(pt.y))
    }

    // MARK: - Map Modes

    public var mapModeKey: String {
        mapMode.key
    }

    public var shaderModeIndex: Int {
        Self.shaderModeIndex(for: mapMode)
    }

    public static func shaderModeIndex(for mode: MapModeKind) -> Int {
        switch mode {
        case .political, .diplomatic: return 0
        case .states: return 1
        case .terrain: return 2
        case .religion: return 3
        case .culture: return 4
        case .development: return 5
        case .goods: return 6
        case .markets: return 7
        }
    }

    public static func shortcutKey(for mode: MapModeKind) -> String {
        switch mode {
        case .political: return "Q"
        case .diplomatic: return "O"
        case .states: return "W"
        case .terrain: return "E"
        case .religion: return "R"
        case .culture: return "T"
        case .development: return "Y"
        case .goods: return "U"
        case .markets: return "I"
        }
    }

    public func tint(forZoom zoom: Double) -> Double {
        switch mapMode {
        case .political, .diplomatic:
            return min(max(0.72 - 0.2 * zoom, 0.38), 0.66)
        case .terrain:
            return 0.0
        default:
            return 0.8
        }
    }

    @discardableResult
    public func setMapMode(key: String) -> Bool {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let matched = MapModeKind.allCases.first(where: { $0.key == normalized }) else {
            return false
        }
        mapMode = matched
        return true
    }

    public func mapModesList() -> [[String: Any]] {
        MapModeKind.allCases.map { mode in
            [
                "key": mode.key,
                "title": mode.title,
                "shortcut": Self.shortcutKey(for: mode),
                "shaderMode": Self.shaderModeIndex(for: mode)
            ]
        }
    }

    // MARK: - Top Bar & Speed Controls

    public var countryName: String {
        guard let s = session, let p = s.playerCountry else { return "Observer" }
        return s.world.countries.name[p.index]
    }

    public var countryTag: String {
        session?.playerTag ?? "OBS"
    }

    public var treasury: Double {
        guard let s = session, let p = s.playerCountry else { return 0 }
        return s.world.countries.treasury[p.index]
    }

    public var monthlyNet: Double {
        session?.playerTopBarStatus()?.monthlyNet ?? 0
    }

    public var ducatsText: String {
        let d = Int(treasury.rounded(.down))
        let net = monthlyNet
        let sign = net >= 0 ? "+" : ""
        return String(format: "%d (%@%.1f/mo)", d, sign, net)
    }

    public var dateText: String {
        session?.date.description ?? "30 May 1453"
    }

    public var topBarArmiesText: String {
        guard let s = session, let p = s.playerCountry else { return "Armies 0k · MP 0k" }
        let menK = (s.world.military.totalMen(of: p) + 500) / 1_000
        let mpK = Int((s.world.military.manpower[p.index] / 1_000.0).rounded())
        return "Armies \(menK)k · MP \(mpK)k"
    }

    public var isPaused: Bool {
        guard let s = session else { return true }
        return s.speed == .paused
    }

    /// Returns `0` when paused, or `1...5` for speeds 1–5.
    public var speed: Int {
        session?.speed.rawValue ?? 0
    }

    public func togglePause() {
        session?.togglePause()
    }

    public func setSpeed(_ rawSpeed: Int) {
        guard let s = session else { return }
        if rawSpeed <= 0 {
            s.speed = .paused
        } else if let gs = GameSpeed(rawValue: min(max(rawSpeed, 1), 5)) {
            s.speed = gs
        }
    }

    public func faster() {
        session?.faster()
    }

    public func slower() {
        session?.slower()
    }

    /// Advances the simulation clock by `deltaSeconds`.
    /// Returns a bitmask:
    /// - bit 0 (`1`): one or more days advanced
    /// - bit 1 (`2`): month changed
    /// - bit 2 (`4`): wars count or occupation changed (styles/labels should refresh)
    /// - bit 3 (`8`): autosave occurred
    public func tickFrame(deltaSeconds: Double) -> Int {
        guard let s = session else { return 0 }
        let prevOccupiedCount = s.world.provinces.occupiedBy.reduce(0) { $0 + ($1 != nil ? 1 : 0) }
        let outcome = s.advanceTime(elapsedSeconds: deltaSeconds)
        var mask = 0
        if outcome.daysAdvanced > 0 {
            mask |= 1
            let newOccupiedCount = s.world.provinces.occupiedBy.reduce(0) { $0 + ($1 != nil ? 1 : 0) }
            if newOccupiedCount != prevOccupiedCount {
                mask |= 4
            }
        }
        if outcome.monthChanged { mask |= 2 }
        if outcome.warsCountChanged {
            s.rebuildLabels()
            mask |= 4
        }
        if outcome.didAutosave { mask |= 8 }
        return mask
    }

    // MARK: - Game Menu: Saves & Autosave

    public var autosaveFrequencyKey: String {
        session?.autosaveFrequency.rawValue ?? AutosaveFrequency.never.rawValue
    }

    @discardableResult
    public func setAutosaveFrequency(_ key: String) -> Bool {
        guard let s = session,
              let freq = AutosaveFrequency(rawValue: key.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        s.autosaveFrequency = freq
        return true
    }

    public func autosaveOptions() -> [[String: Any]] {
        AutosaveFrequency.allCases.map { freq in
            [
                "key": freq.rawValue,
                "title": freq.displayName
            ]
        }
    }

    public var lastSaveStatus: String {
        session?.lastSaveStatus ?? ""
    }

    @discardableResult
    public func saveGame(named name: String) -> Bool {
        guard let s = session else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "\(s.playerTag ?? "GEZ") - \(s.date.description)"
        let finalName = trimmed.isEmpty ? fallback : trimmed
        return s.saveGame(named: finalName) != nil
    }

    @discardableResult
    public func quickSave() -> Bool {
        guard let s = session else { return false }
        return s.quickSave() != nil
    }

    public func savedGamesList() -> [[String: Any]] {
        guard let s = session else { return [] }
        s.refreshSavedGames()
        return s.savedGames.enumerated().map { index, entry in
            let meta = entry.metadata
            let playerName = meta.playerName ?? meta.playerTag ?? "Unknown"
            return [
                "index": index,
                "id": entry.id,
                "name": meta.name,
                "gameDate": meta.gameDate.description,
                "playerTag": meta.playerTag ?? "",
                "playerName": playerName,
                "isAutosave": meta.isAutosave
            ]
        }
    }

    @discardableResult
    public func loadSavedGame(at index: Int) -> Bool {
        guard let s = session else { return false }
        if s.savedGames.isEmpty {
            s.refreshSavedGames()
        }
        guard index >= 0 && index < s.savedGames.count else { return false }
        return s.loadGame(s.savedGames[index])
    }

    @discardableResult
    public func deleteSavedGame(at index: Int) -> Bool {
        guard let s = session else { return false }
        if s.savedGames.isEmpty {
            s.refreshSavedGames()
        }
        guard index >= 0 && index < s.savedGames.count else { return false }
        s.deleteSave(s.savedGames[index])
        return true
    }

    // MARK: - Nation Picker & New Game

    /// Tag of the country owning the currently selected province (even if owned by the player), or `""`.
    public var selectedProvinceOwnerTag: String {
        guard let s = session,
              let p = s.selectedProvince,
              let owner = s.world.provinces.owner[p.index] else {
            return ""
        }
        return s.world.countries.tag[owner.index]
    }

    public func featuredCountriesList() -> [[String: Any]] {
        guard let s = session else { return [] }
        let summaries = s.countrySummaries()
        let byTag = Dictionary(uniqueKeysWithValues: summaries.map { ($0.tag, $0) })
        return CountrySummaryInfo.featuredTags.compactMap { tag in
            guard let summary = byTag[tag] ?? (tag == "DLH" ? byTag["DEL"] : nil) else { return nil }
            return buildCountryDictionary(summary: summary, session: s)
        }
    }

    public func allCountriesList() -> [[String: Any]] {
        guard let s = session else { return [] }
        return s.countrySummaries().map { summary in
            buildCountryDictionary(summary: summary, session: s)
        }
    }

    public func countryDetails(tag: String) -> [String: Any] {
        guard let s = session else { return [:] }
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let summaries = s.countrySummaries()
        if let summary = summaries.first(where: { $0.tag == normalized }) {
            return buildCountryDictionary(summary: summary, session: s)
        }
        guard let cid = s.world.countries.id(forTag: normalized) else { return [:] }
        let provs = s.world.provinces(ownedBy: cid)
        let dev = provs.reduce(0) { $0 + s.world.provinces.development[$1.index] }
        let fallback = CountrySummaryInfo(
            id: cid,
            tag: s.world.countries.tag[cid.index],
            name: s.world.countries.name[cid.index],
            provinces: provs.count,
            development: dev
        )
        return buildCountryDictionary(summary: fallback, session: s)
    }

    private func buildCountryDictionary(summary: CountrySummaryInfo, session s: GameSession) -> [String: Any] {
        let w = s.world
        let c = w.countries
        let i = summary.id.index
        let rulerName = c.ruler[i].map { w.people.characters.fullName($0) } ?? "Interregnum"
        let treasury = c.treasury[i]
        let treasuryInt = Int(treasury.rounded())
        let rgb = c.color[i]
        var focusX = 2150.0
        var focusY = 820.0
        if let cap = c.capital[i], cap.index < s.provincePositions.count {
            focusX = s.provincePositions[cap.index].x
            focusY = s.provincePositions[cap.index].y
        } else if let firstProv = w.provinces(ownedBy: summary.id).first, firstProv.index < s.provincePositions.count {
            focusX = s.provincePositions[firstProv.index].x
            focusY = s.provincePositions[firstProv.index].y
        }
        return [
            "tag": summary.tag,
            "name": summary.name,
            "ruler": rulerName,
            "treasury": treasury,
            "treasuryText": "\(treasuryInt) ducats",
            "provinces": summary.provinces,
            "development": summary.development,
            "government": c.government[i].displayName,
            "religion": c.religion[i].displayName,
            "status": s.countryStatus(summary.id),
            "colorR": Int(rgb.r),
            "colorG": Int(rgb.g),
            "colorB": Int(rgb.b),
            "focusX": focusX,
            "focusY": focusY
        ]
    }

    @discardableResult
    public func startNewGame(tag: String) -> Bool {
        guard let s = session else { return false }
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard s.world.countries.id(forTag: normalized) != nil else { return false }
        s.startNewGame(tag: normalized)
        return true
    }

    @discardableResult
    public func switchPlayer(tag: String) -> Bool {
        guard let s = session else { return false }
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let cid = s.world.countries.id(forTag: normalized) else { return false }
        s.switchPlayer(to: cid)
        return true
    }

    // MARK: - Selection, Province Panel & Market Panel

    public func clearSelection() {
        session?.select(province: nil)
    }

    public var selectedProvinceValue: Int {
        guard let p = session?.selectedProvince else { return 0 }
        return p.index + 2
    }

    public var selectedSeaValue: Int {
        guard let z = session?.selectedSea else { return 0 }
        return z.index + 1
    }

    /// Selects the province or sea zone at map pixel `(x, y)` and returns the selected ID-map value (`0` if water/none).
    @discardableResult
    public func selectAt(mapX x: Int, mapY y: Int) -> Int {
        guard let s = session else { return 0 }
        if let p = s.idMap.province(x: x, y: y) {
            s.select(province: p)
            return p.index + 2
        } else if let z = s.seaMap.seaZone(x: x, y: y) {
            s.select(sea: z)
            return 0
        } else {
            s.select(province: nil)
            return 0
        }
    }

    /// Name of the country owning the selected province, or "" when nothing
    /// is selected, the province is unowned, or it is already the player's.
    public var selectedOwnerName: String {
        guard let s = session, let p = s.selectedProvince,
              let owner = s.world.provinces.owner[p.index],
              owner != s.playerCountry else { return "" }
        return s.world.countries.name[owner.index]
    }

    /// Makes the owner of the selected province the player's country.
    /// Returns true when the player switched.
    @discardableResult
    public func playAsSelectedOwner() -> Bool {
        guard let s = session, let p = s.selectedProvince,
              let owner = s.world.provinces.owner[p.index],
              owner != s.playerCountry else { return false }
        s.switchPlayer(to: owner)
        return true
    }

    public func provinceSummaryAt(mapX x: Int, mapY y: Int) -> String {
        guard let s = session else { return "" }
        let w = s.world
        if let p = s.idMap.province(x: x, y: y) {
            let pName = w.provinces.name[p.index]
            let dev = w.provinces.development[p.index]
            if let owner = w.provinces.owner[p.index] {
                let cName = w.countries.name[owner.index]
                return "\(pName) — \(cName) (Dev \(dev))"
            }
            return "\(pName) — Unclaimed (Dev \(dev))"
        }
        if let z = s.seaMap.seaZone(x: x, y: y) {
            return w.seaZones.name[z.index]
        }
        return ""
    }

    public func selectedProvinceDetails(peopleShowState: Bool = false) -> [String: Any] {
        guard let s = session, let province = s.selectedProvince else {
            return ["hasSelection": false]
        }
        let w = s.world
        let p = w.provinces
        let c = w.countries
        let eco = w.economy
        let ch = w.people.characters
        let i = province.index
        let owner = p.owner[i]
        let isPlayerOwned = (owner != nil && owner == s.playerCountry)

        let ownerTag = owner.map { c.tag[$0.index] } ?? ""
        let ownerName = owner.map { c.name[$0.index] } ?? "Unclaimed land"
        let ownerRGB = owner.map { c.color[$0.index] } ?? RGB(196, 182, 150)
        let isCapital = owner.map { c.capital[$0.index] == province } ?? false
        let occupiedByName = p.occupiedBy[i].map { c.name[$0.index] } ?? ""
        let countryStatus = owner.map { s.countryStatus($0) } ?? ""

        // Holder & grant candidates
        let holder = p.holder[i]
        let holderName = holder.map { ch.fullName($0) } ?? (owner == nil ? "No one" : "The crown")
        let holderStance: String
        if let h = holder, let o = owner {
            holderStance = VassalSystem.stance(w, h, o).displayName
        } else {
            holderStance = ""
        }
        var grantCandidates: [[String: Any]] = []
        if isPlayerOwned, holder == nil, let player = s.playerCountry {
            let candidates = VassalSystem.grantCandidates(w, player, date: s.date)
                .sorted { ch.skills[$0.index].reduce(0, +) > ch.skills[$1.index].reduce(0, +) }
                .prefix(12)
            for cand in candidates {
                grantCandidates.append([
                    "characterIndex": cand.index,
                    "label": "\(ch.fullName(cand)) (\(ch.age(cand, on: s.date)))"
                ])
            }
        }

        // Overview stats
        let dev = p.development[i]
        let fortLevel = p.fortLevel[i]
        let developmentText = "\(dev) · fort \(fortLevel)"
        let landText = "\(p.terrain[i].rawValue.capitalized)\(p.isCoastal[i] ? ", coast" : "") · \(Int(p.areaKm2[i].rounded())) km²"
        let riverSides = p.neighbors[i].filter { w.isRiverBorder(province, $0) }.count
        let riverBordersText = riverSides > 0 ? "\(riverSides) of \(p.neighbors[i].count) sides" : ""
        let inProv = ArmySystem.soldiersInProvince(w, province)
        let limit = ArmySystem.supplyLimit(w, in: province)
        let supplyText = "\(inProv) / \(limit) men"

        let hasRaisedLevies = ArmySystem.hasRaisedLevies(w, in: province)
        let availLevy = ArmySystem.availableLevyMen(w, in: province)
        let canRaiseLevy = isPlayerOwned && !hasRaisedLevies && availLevy >= ArmyModel.minLevyMen
        let levyRefusal: String
        if !isPlayerOwned {
            levyRefusal = ArmyRefusal.notOwner.reason
        } else if hasRaisedLevies {
            levyRefusal = ArmyRefusal.leviesAlreadyRaised.reason
        } else if let h = holder, w.people.refusing.contains(h) {
            levyRefusal = ArmyRefusal.vassalRefusing.reason
        } else if availLevy < ArmyModel.minLevyMen {
            levyRefusal = ArmyRefusal.tooFewPeople.reason
        } else {
            levyRefusal = ""
        }
        let levyText = hasRaisedLevies ? "Raised" : "\(availLevy) men"
        let canDisbandLevies = isPlayerOwned && s.playerCountry.map { w.military.totalMen(of: $0, origin: .levy) > 0 } == true

        let garrison = p.fortGarrison[i]
        let maxGarrison = p.maxGarrison(of: province)
        let siege = w.military.siege(in: province)
        var siegeText = ""
        var siegeBesiegerTag = ""
        var siegeBesiegerName = ""
        var siegePhaseDaysRemaining = 0
        var siegeProgress = 0
        var siegeBreached = false
        var siegeBlockaded = false
        var siegePortStatusText = ""
        var siegeLastRollText = ""
        var siegeIsPlayerBesieger = false
        var siegeCanAssault = false
        if let siege {
            siegeBesiegerTag = c.tag[siege.besieger.index]
            siegeBesiegerName = c.name[siege.besieger.index]
            siegePhaseDaysRemaining = siege.phaseDaysRemaining
            siegeProgress = siege.progress
            siegeBreached = siege.breached
            siegeBlockaded = siege.blockaded
            siegeText = "Besieged by \(siegeBesiegerName) · Progress \(siege.progress)\(siege.breached ? " (BREACHED)" : "")"
            if p.isCoastal[i] {
                siegePortStatusText = siege.blockaded ? "Blockaded" : "Open port (-2)"
            }
            if let outcome = siege.lastOutcome, let roll = siege.lastRoll {
                let modStr = siege.lastModifier >= 0 ? "+\(siege.lastModifier)" : "\(siege.lastModifier)"
                siegeLastRollText = "Last roll: \(roll) (\(modStr)) · \(outcome.rawValue)"
            }
            siegeIsPlayerBesieger = (siege.besieger == s.playerCountry)
            siegeCanAssault = siegeIsPlayerBesieger && siege.breached
        }

        var assaultResultText = ""
        var assaultResultStatus = ""
        if let last = s.lastAssaultResult, last.province == province {
            if let refusal = last.result.refusalReason {
                assaultResultText = refusal
                assaultResultStatus = "refused"
            } else if last.result.captured {
                assaultResultText = "Assault captured fort (-\(last.result.attackerLosses) attackers)"
                assaultResultStatus = "captured"
            } else {
                assaultResultText = "Assault repelled (-\(last.result.attackerLosses) attackers, -\(last.result.garrisonLosses) garrison)"
                assaultResultStatus = "repelled"
            }
        }

        var recruitUnits: [[String: Any]] = []
        if isPlayerOwned, let player = s.playerCountry {
            recruitUnits = Self.buildRecruitUnitsList(world: w, country: player, province: province)
        }

        // Buildings
        let allTypes = eco.buildingTypes.indices.map(BuildingTypeID.init)
        let built = allTypes.filter { eco.buildings.level(province, $0) > 0 }
        let builtStrings = built.map { t in
            "\(Self.buildingName(t, in: province, world: w)) \(eco.buildings.level(province, t))"
        }
        let constructions: [[String: Any]] = eco.buildings.constructions
            .filter { $0.province == province }
            .map { con in
                [
                    "name": Self.buildingName(con.type, in: province, world: w),
                    "level": con.level,
                    "progress": con.progress,
                    "monthsLeft": con.monthsLeft
                ]
            }
        let slotsUsed = eco.buildings.slotsUsed(province)
        let slotsTotal = BuildingSystem.slots(w, province)
        let slotsText = "\(slotsUsed) / \(slotsTotal) slots"

        let buildCategories: [[String: Any]] = BuildingCategory.allCases.map { cat in
            ["key": cat.rawValue, "title": cat.displayName]
        }
        var buildableOptions: [[String: Any]] = []
        if isPlayerOwned, let player = s.playerCountry {
            let hiddenRefusals: Set<BuildingSystem.Refusal> = [
                .needsCoast, .wrongGood, .wrongTerrain, .wrongReligion, .maxLevel, .notOwner
            ]
            for t in allTypes {
                let placeRefusal = BuildingSystem.refusal(w, player, province, t, checkMoney: false)
                if placeRefusal.map({ !hiddenRefusals.contains($0) }) ?? true {
                    let refusal = BuildingSystem.refusal(w, player, province, t)
                    let nextLevel = BuildingSystem.nextLevel(w, province, t)
                    let bType = eco.buildingTypes[t.index]
                    let cost = Int(BuildingSystem.cost(w, province, t).rounded())
                    let months = bType.months(forLevel: nextLevel)
                    buildableOptions.append([
                        "typeIndex": t.index,
                        "category": bType.category.rawValue,
                        "name": "\(Self.buildingName(t, in: province, world: w)) \(nextLevel)",
                        "level": nextLevel,
                        "cost": cost,
                        "months": months,
                        "canBuild": refusal == nil,
                        "refusalReason": refusal?.reason ?? "",
                        "effectText": Self.buildingEffectText(bType.effect, world: w)
                    ])
                }
            }
        }

        // Economy
        let marketID = w.market(of: province)
        let marketIndex = marketID?.index ?? -1
        let marketName = marketID.map { eco.markets.name[$0.index] } ?? ""
        var goodsProduced: [[String: Any]] = []
        for k in eco.producers.range(for: province) {
            let g = eco.producers.good[k]
            let rgb = eco.goods.color[g.index]
            goodsProduced.append([
                "name": eco.goods.name[g.index],
                "isWorkshop": false,
                "amountText": Self.formatAmount(eco.producers.output[k] * 12),
                "valueText": String(format: "%.1f", eco.producers.value[k] * 12),
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ])
        }
        let typeCount = eco.buildings.typeCount
        for t in eco.buildingTypes.indices where eco.buildings.level(province, BuildingTypeID(t)) > 0 {
            if let r = eco.buildingTypes[t].effect.workshopRecipe {
                let slot = province.index * typeCount + t
                let g = eco.recipes[r].output
                let rgb = eco.goods.color[g.index]
                goodsProduced.append([
                    "name": eco.goods.name[g.index],
                    "isWorkshop": true,
                    "amountText": Self.formatAmount(eco.workshopOutput[slot] * 12),
                    "valueText": String(format: "%.1f", eco.workshopValue[slot] * 12),
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b)
                ])
            }
        }
        let worthText = String(format: "%.1f / year · tax %.1f", p.production[i], p.baseTax[i])
        var classSatisfactions: [[String: Any]] = []
        for cls in [SocialClass.peasants, .burghers, .clergy, .nobles] {
            if let sat = w.satisfaction(of: cls, in: [province]) {
                classSatisfactions.append([
                    "name": cls.displayName,
                    "percentText": "\(Int((sat * 100).rounded()))%"
                ])
            }
        }

        // People
        let stateID = p.state[i]
        let breakdown = peopleShowState ? w.breakdown(ofState: stateID) : w.breakdown(of: province)
        let peopleTitle = peopleShowState ? "People of \(w.states.name[stateID.index])" : "People"
        let populationText = Self.formatPeople(breakdown.total)
        let cultures: [[String: Any]] = breakdown.cultureShares().prefix(4).map { entry in
            [
                "name": w.cultures.name[entry.0.index],
                "share": entry.1,
                "percentText": Self.formatPercent(entry.1)
            ]
        }
        let religions: [[String: Any]] = breakdown.religionShares().prefix(4).map { entry in
            let rgb = entry.0.color
            return [
                "name": Self.religionLabel(entry.0, breakdown),
                "share": entry.1,
                "percentText": Self.formatPercent(entry.1),
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ]
        }
        let classes: [[String: Any]] = breakdown.classShares().map { entry in
            [
                "name": entry.0.displayName,
                "share": entry.1,
                "percentText": Self.formatPercent(entry.1)
            ]
        }
        let orders = peopleShowState ? [] : p.sufiOrders[i]
        let sufiText: String
        if !orders.isEmpty {
            sufiText = "Sufi orders: " + orders.map { "\($0.order.displayName) (\(Self.formatPercent($0.strength)))" }.joined(separator: ", ")
        } else {
            sufiText = ""
        }

        return [
            "hasSelection": true,
            "provinceIndex": i,
            "name": p.name[i],
            "stateName": w.stateName(of: province),
            "regionName": w.regionName(of: province),
            "subtitle": "\(w.stateName(of: province)) · \(w.regionName(of: province))",
            "ownerTag": ownerTag,
            "ownerName": ownerName,
            "ownerColorR": Int(ownerRGB.r),
            "ownerColorG": Int(ownerRGB.g),
            "ownerColorB": Int(ownerRGB.b),
            "isCapital": isCapital,
            "isPlayerOwned": isPlayerOwned,
            "occupiedByName": occupiedByName,
            "countryStatus": countryStatus,
            "holderName": holderName,
            "holderStance": holderStance,
            "hasHolder": holder != nil,
            "grantCandidates": grantCandidates,
            "development": dev,
            "fortLevel": fortLevel,
            "developmentText": developmentText,
            "landText": landText,
            "riverSides": riverSides,
            "riverBordersText": riverBordersText,
            "soldiersInProvince": inProv,
            "supplyLimit": limit,
            "supplyText": supplyText,
            "hasRaisedLevies": hasRaisedLevies,
            "availableLevyMen": availLevy,
            "canRaiseLevy": canRaiseLevy,
            "levyRefusal": levyRefusal,
            "levyText": levyText,
            "canDisbandLevies": canDisbandLevies,
            "recruitUnits": recruitUnits,
            "fortGarrison": garrison,
            "maxGarrison": maxGarrison,
            "isBesieged": siege != nil,
            "siegeText": siegeText,
            "siegeBesiegerTag": siegeBesiegerTag,
            "siegeBesiegerName": siegeBesiegerName,
            "siegePhaseDaysRemaining": siegePhaseDaysRemaining,
            "siegeProgress": siegeProgress,
            "siegeBreached": siegeBreached,
            "siegeIsCoastal": p.isCoastal[i],
            "siegeBlockaded": siegeBlockaded,
            "siegePortStatusText": siegePortStatusText,
            "siegeLastRollText": siegeLastRollText,
            "siegeIsPlayerBesieger": siegeIsPlayerBesieger,
            "siegeCanAssault": siegeCanAssault,
            "assaultResultText": assaultResultText,
            "assaultResultStatus": assaultResultStatus,
            "slotsUsed": slotsUsed,
            "slotsTotal": slotsTotal,
            "slotsText": slotsText,
            "builtBuildings": builtStrings,
            "constructions": constructions,
            "buildCategories": buildCategories,
            "buildableOptions": buildableOptions,
            "marketIndex": marketIndex,
            "marketName": marketName,
            "goodsProduced": goodsProduced,
            "worthText": worthText,
            "classSatisfactions": classSatisfactions,
            "peopleTitle": peopleTitle,
            "populationText": populationText,
            "cultures": cultures,
            "religions": religions,
            "classes": classes,
            "sufiText": sufiText
        ]
    }

    public func selectedSeaDetails() -> [String: Any] {
        guard let s = session, let sea = s.selectedSea else {
            return ["hasSelection": false]
        }
        let w = s.world
        let z = w.seaZones
        let coast = z.coast[sea.index]
        let neighborsText = z.neighbors[sea.index].map { z.name[$0.index] }.joined(separator: ", ")
        let coastText = coast.prefix(12).map { w.provinces.name[$0.index] }.joined(separator: ", ")
            + (coast.count > 12 ? "…" : "")
        return [
            "hasSelection": true,
            "name": z.name[sea.index],
            "neighborsText": neighborsText,
            "coastCount": coast.count,
            "coastText": coastText
        ]
    }

    @discardableResult
    public func buildInSelectedProvince(buildingTypeIndex: Int) -> Bool {
        guard let s = session,
              let province = s.selectedProvince,
              buildingTypeIndex >= 0 && buildingTypeIndex < s.world.economy.buildingTypes.count else {
            return false
        }
        return s.build(BuildingTypeID(buildingTypeIndex), in: province) == nil
    }

    @discardableResult
    public func raiseSelectedProvinceLevies() -> Bool {
        guard let s = session, let province = s.selectedProvince else { return false }
        return s.raiseLevies(in: province) == nil
    }

    @discardableResult
    public func grantSelectedProvince(characterIndex: Int) -> Bool {
        guard let s = session,
              let province = s.selectedProvince,
              let player = s.playerCountry,
              s.world.provinces.owner[province.index] == player,
              characterIndex >= 0 && characterIndex < s.world.people.characters.count else {
            return false
        }
        s.grant(province, to: CharacterID(characterIndex))
        return s.world.provinces.holder[province.index] == CharacterID(characterIndex)
    }

    @discardableResult
    public func revokeSelectedProvince() -> Bool {
        guard let s = session,
              let province = s.selectedProvince,
              let player = s.playerCountry,
              s.world.provinces.owner[province.index] == player,
              s.world.provinces.holder[province.index] != nil else {
            return false
        }
        s.revoke(province)
        return s.world.provinces.holder[province.index] == nil
    }

    public func marketDetails(marketIndex: Int, categoryKey: String = "") -> [String: Any] {
        guard let s = session else { return ["valid": false] }
        let eco = s.world.economy
        let mk = eco.markets
        guard marketIndex >= 0 && marketIndex < mk.count else {
            return ["valid": false]
        }
        let market = MarketID(marketIndex)
        let filterCat = GoodCategory(rawValue: categoryKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        let provinceCount = eco.provinces(in: market).count

        var categories: [[String: Any]] = [["key": "", "title": "All"]]
        for cat in GoodCategory.allCases {
            categories.append(["key": cat.rawValue, "title": cat.displayName])
        }

        var goodsRows: [[String: Any]] = []
        for g in eco.goods.ids {
            let slot = mk.slot(market, g)
            guard (filterCat == nil || eco.goods.category[g.index] == filterCat)
                && (mk.supply[slot] > 0.0005 || mk.demand[slot] > 0.0005) else {
                continue
            }
            let price = mk.price[slot]
            let ratio = price / eco.goods.basePrice[g.index]
            let trend = ratio >= 1.15 ? "▲" : (ratio <= 0.87 ? "▼" : "·")
            let rgb = eco.goods.color[g.index]
            goodsRows.append([
                "goodIndex": g.index,
                "name": eco.goods.name[g.index],
                "priceText": String(format: "%.1f", price),
                "trend": trend,
                "ratioPercent": Int((ratio * 100).rounded()),
                "supplyText": Self.formatAmount(mk.supply[slot] * 12),
                "demandText": Self.formatAmount(mk.demand[slot] * 12),
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ])
        }

        return [
            "valid": true,
            "marketIndex": marketIndex,
            "name": "\(mk.name[marketIndex]) market",
            "provinceCount": provinceCount,
            "subtitle": "\(provinceCount) provinces trade here",
            "categories": categories,
            "goods": goodsRows
        ]
    }

    // MARK: - Step 3b: Armies, Map Counters, Recruitment & Sieges

    @discardableResult
    public func selectProvinceByIndex(_ provinceIndex: Int) -> Int {
        guard let s = session,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return 0
        }
        s.select(province: ProvinceID(provinceIndex))
        return provinceIndex + 2
    }

    public var selectedArmyId: Int {
        guard let s = session, let aid = s.selectedArmy else { return -1 }
        let idx = Int(aid.rawValue)
        guard idx >= 0 && idx < s.world.military.armies.count && s.world.military.armies.alive[idx] else {
            s.selectedArmy = nil
            return -1
        }
        return idx
    }

    public var moveModeArmyId: Int {
        guard let s = session, let aid = s.moveModeForArmy else { return -1 }
        let idx = Int(aid.rawValue)
        guard idx >= 0 && idx < s.world.military.armies.count && s.world.military.armies.alive[idx] else {
            s.moveModeForArmy = nil
            return -1
        }
        return idx
    }

    @discardableResult
    public func selectArmy(armyId: Int) -> Bool {
        guard let s = session else { return false }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId] else {
            return false
        }
        let aid = ArmyID(Int32(armyId))
        s.selectedArmy = aid
        if s.moveModeForArmy != nil && s.moveModeForArmy != aid {
            s.moveModeForArmy = nil
        }
        return true
    }

    public func clearSelectedArmy() {
        session?.selectedArmy = nil
        session?.moveModeForArmy = nil
    }

    @discardableResult
    public func setMoveModeForArmy(armyId: Int) -> Bool {
        guard let s = session else { return false }
        if armyId < 0 {
            s.moveModeForArmy = nil
            return false
        }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              let player = s.playerCountry,
              armies.owner[armyId] == player && !armies.isRebel[armyId],
              !s.world.military.isInBattle(ArmyID(Int32(armyId))),
              !armies.isRetreating[armyId] else {
            s.moveModeForArmy = nil
            return false
        }
        let aid = ArmyID(Int32(armyId))
        s.selectedArmy = aid
        s.moveModeForArmy = aid
        return true
    }

    /// Data for `MapArmiesLayer.gd`: one counter per living army plus active marching routes.
    public func mapArmiesData() -> [String: Any] {
        guard let s = session else {
            return ["selectedArmyId": -1, "moveModeArmyId": -1, "counters": [], "routes": []]
        }
        let w = s.world
        let armies = w.military.armies
        let positions = s.provincePositions
        let curSelectedId = selectedArmyId
        let curMoveId = moveModeArmyId

        var livingByProvince: [Int: [Int]] = [:]
        for i in 0..<armies.count where armies.alive[i] {
            let pIdx = armies.province[i].index
            livingByProvince[pIdx, default: []].append(i)
        }

        var counters: [[String: Any]] = []
        var routes: [[String: Any]] = []

        for i in 0..<armies.count where armies.alive[i] {
            let aid = ArmyID(Int32(i))
            let men = armies.totalMen(of: aid)
            guard men > 0 else { continue }
            let prov = armies.province[i]
            guard prov.index >= 0 && prov.index < positions.count else { continue }
            let pos = positions[prov.index]
            let owner = armies.owner[i]
            let isRebel = armies.isRebel[i]
            let isPlayer = (owner == s.playerCountry && !isRebel)
            let isEnemy = s.playerCountry.map { w.diplomacy.isAtWar($0, owner) } ?? false
            let rgb = w.countries.color[owner.index]

            let inBattle = w.military.isInBattle(aid)
            let isBesieging = !isRebel && w.military.sieges.contains {
                $0.province == prov && $0.besieger == owner
            }
            let isRetreating = armies.isRetreating[i]
            let marker: String
            if inBattle {
                marker = "B"
            } else if isBesieging {
                marker = "S"
            } else if isRetreating {
                marker = "R"
            } else {
                marker = ""
            }

            let menText = men >= 1_000 ? "\((men + 500) / 1_000)k" : "\(men)"
            let stackList = livingByProvince[prov.index] ?? [i]
            let stackIndex = stackList.firstIndex(of: i) ?? 0

            counters.append([
                "armyId": i,
                "name": armies.name[i],
                "provinceIndex": prov.index,
                "x": pos.x,
                "y": pos.y,
                "stackIndex": stackIndex,
                "stackCount": stackList.count,
                "men": men,
                "menText": menText,
                "ownerTag": w.countries.tag[owner.index],
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b),
                "isPlayer": isPlayer,
                "isEnemy": isEnemy,
                "isRebel": isRebel,
                "isSelected": (i == curSelectedId),
                "isInBattle": inBattle,
                "isBesieging": isBesieging,
                "isRetreating": isRetreating,
                "marker": marker
            ])

            let path = armies.path[i]
            if !path.isEmpty {
                var pts: [Double] = [pos.x, pos.y]
                for hop in path where hop.index >= 0 && hop.index < positions.count {
                    pts.append(positions[hop.index].x)
                    pts.append(positions[hop.index].y)
                }
                if pts.count >= 4 {
                    routes.append([
                        "armyId": i,
                        "isPlayer": isPlayer,
                        "isRebel": isRebel,
                        "isSelected": (i == curSelectedId),
                        "points": pts
                    ])
                }
            }
        }

        return [
            "selectedArmyId": curSelectedId,
            "moveModeArmyId": curMoveId,
            "counters": counters,
            "routes": routes
        ]
    }

    /// Detailed breakdown for the currently selected army (`session.selectedArmy`).
    public func selectedArmyDetails() -> [String: Any] {
        guard let s = session else { return ["hasSelection": false] }
        let idx = selectedArmyId
        guard idx >= 0 else { return ["hasSelection": false] }
        let w = s.world
        let armies = w.military.armies
        let aid = ArmyID(Int32(idx))
        let owner = armies.owner[idx]
        let isRebel = armies.isRebel[idx]
        let isPlayerOwned = (owner == s.playerCountry && !isRebel)
        let prov = armies.province[idx]
        let provName = w.provinces.name[prov.index]
        let rgb = w.countries.color[owner.index]

        let regs = armies.regiments[idx]
        var totalMen = 0
        var maxMen = 0
        var weightedMorale = 0.0
        var weightedMaxMorale = 0.0
        var regimentRows: [[String: Any]] = []
        for (rIndex, reg) in regs.enumerated() {
            let u = w.military.unit(reg.type)
            totalMen += reg.men
            maxMen += u.maxMen
            let weight = Double(max(1, reg.men))
            weightedMorale += reg.morale * weight
            weightedMaxMorale += u.morale * weight
            let homeName = reg.homeProvince.map { w.provinces.name[$0.index] } ?? ""
            regimentRows.append([
                "index": rIndex,
                "unitTypeIndex": Int(reg.type.rawValue),
                "unitName": u.name,
                "category": u.category.displayName,
                "origin": reg.origin.displayName,
                "originKey": reg.origin.rawValue,
                "men": reg.men,
                "maxMen": u.maxMen,
                "morale": reg.morale,
                "maxMorale": u.morale,
                "moraleText": String(format: "%.2f / %.2f", reg.morale, u.morale),
                "homeProvinceName": homeName
            ])
        }
        let denom = Double(max(1, totalMen))
        let avgMorale = weightedMorale / denom
        let avgMaxMorale = weightedMaxMorale / denom
        let power = ArmySystem.combatPower(w, aid)
        let upkeep = ArmySystem.armyUpkeep(w, aid)

        let inProv = ArmySystem.soldiersInProvince(w, prov)
        let limit = ArmySystem.supplyLimit(w, in: prov)
        let overSupply = inProv > limit
        let attritionRatePct: Double
        if overSupply {
            let overRatio = Double(inProv - limit) / Double(max(1, limit))
            let terrain = w.provinces.terrain[prov.index]
            let diseaseExtra = (terrain == .desert || terrain == .marsh) ? 0.01 : 0.0
            attritionRatePct = min(0.15, 0.02 + overRatio * 0.05 + diseaseExtra) * 100.0
        } else {
            attritionRatePct = 0.0
        }
        let attritionText = overSupply
            ? String(format: "Over supply! ~%.1f%%/mo attrition", attritionRatePct)
            : "Within supply limit (0% attrition)"

        let inBattle = w.military.isInBattle(aid)
        let siege = w.military.siege(in: prov)
        let isBesieging = !isRebel && siege?.besieger == owner
        let isRetreating = armies.isRetreating[idx]
        let path = armies.path[idx]
        let nextHopName = path.first.map { w.provinces.name[$0.index] } ?? ""
        let destName = path.last.map { w.provinces.name[$0.index] } ?? ""
        let daysLeft = path.isEmpty ? 0 : max(1, Int((armies.moveStepDays[idx] - armies.moveProgressDays[idx]).rounded(.up)))

        let statusText: String
        if inBattle {
            statusText = "Fighting battle in \(provName)"
        } else if isRetreating && !destName.isEmpty {
            statusText = "Retreating to \(destName) (next: \(nextHopName), \(daysLeft)d)"
        } else if !path.isEmpty {
            statusText = "Marching to \(destName) (next: \(nextHopName), \(daysLeft)d)"
        } else if isBesieging, let siege {
            statusText = "Besieging \(provName) (Progress \(siege.progress)\(siege.breached ? ", BREACHED" : ""))"
        } else {
            statusText = "Stationed in \(provName)"
        }

        let cmd = armies.commander[idx]
        let cmdName = cmd.map { w.people.characters.fullName($0) } ?? ""
        let cmdMartial = cmd.map { w.people.characters.skill($0, .martial) } ?? 0
        let cmdText = cmd != nil ? "\(cmdName) (Martial \(cmdMartial))" : "No commander"

        var commanderCandidates: [[String: Any]] = []
        if isPlayerOwned {
            for cand in ArmySystem.commanderCandidates(w, owner, date: s.date) {
                let mSkill = w.people.characters.skill(cand, .martial)
                let cName = w.people.characters.fullName(cand)
                commanderCandidates.append([
                    "characterIndex": cand.index,
                    "name": cName,
                    "martial": mSkill,
                    "label": "\(cName) (Martial \(mSkill))"
                ])
            }
        }

        let othersHere = w.military.armies(in: prov).filter { other in
            let oIdx = Int(other.rawValue)
            return other != aid && armies.owner[oIdx] == owner && !armies.isRebel[oIdx]
        }

        return [
            "hasSelection": true,
            "armyId": idx,
            "name": armies.name[idx],
            "ownerTag": w.countries.tag[owner.index],
            "ownerName": w.countries.name[owner.index],
            "ownerColorR": Int(rgb.r),
            "ownerColorG": Int(rgb.g),
            "ownerColorB": Int(rgb.b),
            "isPlayerOwned": isPlayerOwned,
            "isRebel": isRebel,
            "provinceIndex": prov.index,
            "provinceName": provName,
            "totalMen": totalMen,
            "maxMen": maxMen,
            "strengthText": "\(totalMen) / \(maxMen) men",
            "morale": avgMorale,
            "maxMorale": avgMaxMorale,
            "moraleText": String(format: "%.2f / %.2f", avgMorale, avgMaxMorale),
            "combatPower": power,
            "combatPowerText": String(format: "%.1f", power),
            "upkeep": upkeep,
            "upkeepText": String(format: "%.1f ducats/mo", upkeep),
            "supplyInProvince": inProv,
            "supplyLimit": limit,
            "overSupply": overSupply,
            "supplyText": "\(inProv) / \(limit) men",
            "attritionRatePercent": attritionRatePct,
            "attritionText": attritionText,
            "statusText": statusText,
            "isInBattle": inBattle,
            "isBesieging": isBesieging,
            "isRetreating": isRetreating,
            "isMoving": !path.isEmpty,
            "destinationName": destName,
            "nextHopName": nextHopName,
            "daysLeft": daysLeft,
            "isMoveMode": (moveModeArmyId == idx),
            "commanderIndex": cmd?.index ?? -1,
            "commanderName": cmdName,
            "commanderMartial": cmdMartial,
            "commanderText": cmdText,
            "commanderCandidates": commanderCandidates,
            "regimentSummary": Self.regimentSummary(w, regiments: regs),
            "regiments": regimentRows,
            "canMove": isPlayerOwned && !inBattle && !isRetreating,
            "canSplit": isPlayerOwned && !inBattle && regs.count >= 2,
            "canMerge": isPlayerOwned && !inBattle && !othersHere.isEmpty,
            "mergeCount": othersHere.count,
            "canDisband": isPlayerOwned && !inBattle,
            "canAssignCommander": isPlayerOwned
        ]
    }

    /// Data for the top-bar Armies window (`App/Shared/ArmyView.swift`).
    public func armiesWindowDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let armies = w.military.armies
        let mp = Int(w.military.manpower[player.index].rounded())
        let maxMP = Int(w.military.maxManpower[player.index].rounded())
        let gain = Int(ArmySystem.monthlyManpowerGain(w, player).rounded())
        let standing = w.military.totalMen(of: player, origin: .professional)
        let levies = w.military.totalMen(of: player, origin: .levy)
        let mercs = w.military.totalMen(of: player, origin: .mercenary)
        let mercLimit = ArmySystem.mercenaryLimit(w, player)
        let fieldArmies = w.military.armies(of: player)
        let upkeep = fieldArmies.reduce(0.0) { $0 + ArmySystem.armyUpkeep(w, $1) }
        let attrition = w.military.lastAttritionLosses[player.index]
        let canRaiseAll = w.provinces(ownedBy: player).contains {
            ArmySystem.availableLevyMen(w, in: $0) >= ArmyModel.minLevyMen
        }

        let curSelectedId = selectedArmyId
        let curMoveId = moveModeArmyId
        let moveModeName = (curMoveId >= 0 && curMoveId < armies.count) ? armies.name[curMoveId] : ""

        var commanderCandidates: [[String: Any]] = []
        for cand in ArmySystem.commanderCandidates(w, player, date: s.date) {
            let mSkill = w.people.characters.skill(cand, .martial)
            let cName = w.people.characters.fullName(cand)
            commanderCandidates.append([
                "characterIndex": cand.index,
                "name": cName,
                "martial": mSkill,
                "label": "\(cName) (Martial \(mSkill))"
            ])
        }

        var armyCards: [[String: Any]] = []
        for aid in fieldArmies {
            let i = Int(aid.rawValue)
            let prov = armies.province[i]
            let provName = w.provinces.name[prov.index]
            let men = armies.totalMen(of: aid)
            let limit = ArmySystem.supplyLimit(w, in: prov)
            let inProv = ArmySystem.soldiersInProvince(w, prov)
            let overSupply = inProv > limit
            let path = armies.path[i]
            let nextHopName = path.first.map { w.provinces.name[$0.index] } ?? ""
            let destName = path.last.map { w.provinces.name[$0.index] } ?? ""
            let daysLeft = path.isEmpty ? 0 : max(1, Int((armies.moveStepDays[i] - armies.moveProgressDays[i]).rounded(.up)))
            let cmd = armies.commander[i]
            let cmdName = cmd.map { w.people.characters.fullName($0) } ?? ""
            let cmdMartial = cmd.map { w.people.characters.skill($0, .martial) } ?? 0
            let cmdText = cmd != nil ? "\(cmdName) (Martial \(cmdMartial))" : "Assign commander…"
            let othersHere = w.military.armies(in: prov).filter {
                $0 != aid && armies.owner[Int($0.rawValue)] == player && !armies.isRebel[Int($0.rawValue)]
            }
            let inBattle = w.military.isInBattle(aid)

            armyCards.append([
                "armyId": i,
                "name": armies.name[i],
                "men": men,
                "upkeepText": String(format: "%.1f/mo", ArmySystem.armyUpkeep(w, aid)),
                "provinceIndex": prov.index,
                "provinceName": provName,
                "isMoving": !path.isEmpty,
                "destinationName": destName,
                "nextHopName": nextHopName,
                "daysLeft": daysLeft,
                "supplyInProvince": inProv,
                "supplyLimit": limit,
                "overSupply": overSupply,
                "supplyText": "Supply \(inProv / 1_000)k/\(limit / 1_000)k",
                "commanderIndex": cmd?.index ?? -1,
                "commanderName": cmdName,
                "commanderMartial": cmdMartial,
                "commanderText": cmdText,
                "regimentSummary": Self.regimentSummary(w, regiments: armies.regiments[i]),
                "canMove": !inBattle && !armies.isRetreating[i],
                "canSplit": !inBattle && armies.regiments[i].count >= 2,
                "canMerge": !inBattle && !othersHere.isEmpty,
                "canDisband": !inBattle,
                "isMoveMode": (i == curMoveId),
                "isSelected": (i == curSelectedId)
            ])
        }

        var rebelCards: [[String: Any]] = []
        for rid in w.military.rebelArmies(of: player) {
            let i = Int(rid.rawValue)
            let prov = armies.province[i]
            rebelCards.append([
                "armyId": i,
                "name": armies.name[i],
                "men": armies.totalMen(of: rid),
                "provinceIndex": prov.index,
                "provinceName": w.provinces.name[prov.index]
            ])
        }

        // Target muster province: selected province if player-owned, else player's capital, else first owned province.
        let targetProv: ProvinceID? = {
            if let sel = s.selectedProvince, w.provinces.owner[sel.index] == player {
                return sel
            }
            if let cap = w.countries.capital[player.index], w.provinces.owner[cap.index] == player {
                return cap
            }
            return w.provinces(ownedBy: player).first
        }()

        var musterProvinceIndex = -1
        var musterProvinceName = ""
        var musterAvailableLevy = 0
        var musterCanRaiseLevy = false
        var musterHasRaisedLevies = false
        var musterLevyRefusal = ""
        var recruitUnits: [[String: Any]] = []

        if let p = targetProv, w.provinces.owner[p.index] == player {
            musterProvinceIndex = p.index
            musterProvinceName = w.provinces.name[p.index]
            musterHasRaisedLevies = ArmySystem.hasRaisedLevies(w, in: p)
            musterAvailableLevy = ArmySystem.availableLevyMen(w, in: p)
            musterCanRaiseLevy = !musterHasRaisedLevies && musterAvailableLevy >= ArmyModel.minLevyMen
            if musterHasRaisedLevies {
                musterLevyRefusal = ArmyRefusal.leviesAlreadyRaised.reason
            } else if let h = w.provinces.holder[p.index], w.people.refusing.contains(h) {
                musterLevyRefusal = ArmyRefusal.vassalRefusing.reason
            } else if musterAvailableLevy < ArmyModel.minLevyMen {
                musterLevyRefusal = ArmyRefusal.tooFewPeople.reason
            }
            recruitUnits = Self.buildRecruitUnitsList(world: w, country: player, province: p)
        }

        return [
            "valid": true,
            "manpower": mp,
            "maxManpower": maxMP,
            "monthlyManpowerGain": gain,
            "manpowerText": "\(mp) / \(maxMP) (+\(gain)/mo)",
            "standingMen": standing,
            "levyMen": levies,
            "mercenaryMen": mercs,
            "mercenaryLimit": mercLimit,
            "mercenaryText": "\(mercs) / \(mercLimit) men",
            "totalUpkeep": upkeep,
            "upkeepText": String(format: "−%.1f / month", upkeep),
            "lastAttritionLosses": attrition,
            "canRaiseAllLevies": canRaiseAll,
            "canDisbandLevies": levies > 0,
            "selectedArmyId": curSelectedId,
            "moveModeArmyId": curMoveId,
            "moveModeArmyName": moveModeName,
            "commanderCandidates": commanderCandidates,
            "armies": armyCards,
            "rebelArmies": rebelCards,
            "musterProvinceIndex": musterProvinceIndex,
            "musterProvinceName": musterProvinceName,
            "musterAvailableLevy": musterAvailableLevy,
            "musterCanRaiseLevy": musterCanRaiseLevy,
            "musterHasRaisedLevies": musterHasRaisedLevies,
            "musterLevyRefusal": musterLevyRefusal,
            "recruitUnits": recruitUnits
        ]
    }

    // MARK: - Step 3b: Army & Recruitment Actions

    @discardableResult
    public func orderArmyMove(armyId: Int, provinceIndex: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry else { return false }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count,
              armies.owner[armyId] == player && !armies.isRebel[armyId],
              !s.world.military.isInBattle(ArmyID(Int32(armyId))),
              !armies.isRetreating[armyId] else {
            return false
        }
        let aid = ArmyID(Int32(armyId))
        let dest = ProvinceID(provinceIndex)
        s.orderMove(army: aid, to: dest)
        return s.world.military.armies.province[armyId] == dest
            || !s.world.military.armies.path[armyId].isEmpty
    }

    @discardableResult
    public func orderArmyMoveAt(armyId: Int, mapX: Int, mapY: Int) -> Bool {
        guard let s = session,
              let hit = s.idMap.province(x: mapX, y: mapY) else {
            return false
        }
        return orderArmyMove(armyId: armyId, provinceIndex: hit.index)
    }

    @discardableResult
    public func splitArmy(armyId: Int) -> Int {
        guard let s = session,
              let player = s.playerCountry else { return -1 }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              armies.owner[armyId] == player && !armies.isRebel[armyId],
              armies.regiments[armyId].count >= 2,
              !s.world.military.isInBattle(ArmyID(Int32(armyId))) else {
            return -1
        }
        let countBefore = s.world.military.armies.count
        s.split(army: ArmyID(Int32(armyId)))
        guard s.world.military.armies.count > countBefore,
              let created = s.selectedArmy else {
            return -1
        }
        return Int(created.rawValue)
    }

    @discardableResult
    public func mergeArmies(armyId: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry else { return false }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              armies.owner[armyId] == player && !armies.isRebel[armyId],
              !s.world.military.isInBattle(ArmyID(Int32(armyId))) else {
            return false
        }
        let aid = ArmyID(Int32(armyId))
        let prov = armies.province[armyId]
        let others = s.world.military.armies(in: prov).filter {
            $0 != aid && armies.owner[Int($0.rawValue)] == player && !armies.isRebel[Int($0.rawValue)]
        }
        guard !others.isEmpty else { return false }
        s.mergeArmies(into: aid)
        s.selectedArmy = aid
        return true
    }

    @discardableResult
    public func disbandArmy(armyId: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry else { return false }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              armies.owner[armyId] == player && !armies.isRebel[armyId],
              !s.world.military.isInBattle(ArmyID(Int32(armyId))) else {
            return false
        }
        s.disband(army: ArmyID(Int32(armyId)))
        return !s.world.military.armies.alive[armyId]
    }

    @discardableResult
    public func assignArmyCommander(armyId: Int, characterIndex: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry else { return false }
        let armies = s.world.military.armies
        guard armyId >= 0 && armyId < armies.count && armies.alive[armyId],
              armies.owner[armyId] == player && !armies.isRebel[armyId] else {
            return false
        }
        let aid = ArmyID(Int32(armyId))
        if characterIndex < 0 {
            s.assignCommander(nil, to: aid)
            return s.world.military.armies.commander[armyId] == nil
        }
        guard characterIndex < s.world.people.characters.count else { return false }
        let cid = CharacterID(characterIndex)
        let validCandidates = ArmySystem.commanderCandidates(s.world, player, date: s.date)
        guard validCandidates.contains(cid) else { return false }
        s.assignCommander(cid, to: aid)
        return s.world.military.armies.commander[armyId] == cid
    }

    @discardableResult
    public func raiseAllLevies() -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let before = s.world.military.totalMen(of: player, origin: .levy)
        s.raiseAllLevies()
        let after = s.world.military.totalMen(of: player, origin: .levy)
        return after > before
    }

    @discardableResult
    public func disbandAllLevies() -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let before = s.world.military.totalMen(of: player, origin: .levy)
        guard before > 0 else { return false }
        s.disbandLevies()
        return s.world.military.totalMen(of: player, origin: .levy) == 0
    }

    @discardableResult
    public func raiseLeviesInProvince(provinceIndex: Int) -> Bool {
        guard let s = session,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return false
        }
        return s.raiseLevies(in: ProvinceID(provinceIndex)) == nil
    }

    @discardableResult
    public func recruitProfessionalInProvince(unitTypeIndex: Int, provinceIndex: Int) -> Bool {
        guard let s = session,
              unitTypeIndex >= 0 && unitTypeIndex < s.world.military.unitTypes.count,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return false
        }
        let uid = UnitTypeID(UInt8(unitTypeIndex))
        let pid = ProvinceID(provinceIndex)
        return s.recruitProfessional(uid, in: pid) == nil
    }

    @discardableResult
    public func hireMercenaryInProvince(unitTypeIndex: Int, provinceIndex: Int) -> Bool {
        guard let s = session,
              unitTypeIndex >= 0 && unitTypeIndex < s.world.military.unitTypes.count,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return false
        }
        let uid = UnitTypeID(UInt8(unitTypeIndex))
        guard s.world.military.unit(uid).category != .artillery else { return false }
        let pid = ProvinceID(provinceIndex)
        return s.hireMercenary(uid, in: pid) == nil
    }

    // MARK: - Step 3b: Siege Storm Assault

    public func assaultSelectedProvinceFort() -> [String: Any] {
        guard let s = session, let province = s.selectedProvince else {
            return [
                "captured": false,
                "attackerLosses": 0,
                "garrisonLosses": 0,
                "remainingGarrison": 0,
                "refusalReason": "No province selected",
                "summaryText": "No province selected"
            ]
        }
        return assaultFort(provinceIndex: province.index)
    }

    public func assaultFort(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return [
                "captured": false,
                "attackerLosses": 0,
                "garrisonLosses": 0,
                "remainingGarrison": 0,
                "refusalReason": "Invalid province",
                "summaryText": "Invalid province"
            ]
        }
        let pid = ProvinceID(provinceIndex)
        let res = s.assaultFort(in: pid)
        let summaryText: String
        if let refusal = res.refusalReason {
            summaryText = refusal
        } else if res.captured {
            summaryText = "Assault captured fort (-\(res.attackerLosses) attackers)"
        } else {
            summaryText = "Assault repelled (-\(res.attackerLosses) attackers, -\(res.garrisonLosses) garrison)"
        }
        return [
            "captured": res.captured,
            "attackerLosses": res.attackerLosses,
            "garrisonLosses": res.garrisonLosses,
            "remainingGarrison": res.remainingGarrison,
            "refusalReason": res.refusalReason ?? "",
            "summaryText": summaryText
        ]
    }

    private static func buildRecruitUnitsList(world w: World, country: CountryID, province: ProvinceID) -> [[String: Any]] {
        let units = ArmySystem.availableUnits(w, for: country)
        let currentMercs = w.military.totalMen(of: country, origin: .mercenary)
        let mercLimit = ArmySystem.mercenaryLimit(w, country)
        let treasury = w.countries.treasury[country.index]

        return units.map { u in
            let profCost = Int(ArmySystem.recruitmentCost(w, country, province, u.id).rounded())
            let mercCost = Int(ArmySystem.mercenaryCost(w, country, u.id).rounded())
            let profRefusal = ArmySystem.recruitRefusal(w, country, in: province, unit: u.id)
            let mercAllowed = (u.category != .artillery)
            let mercRefusal: String
            if !mercAllowed {
                mercRefusal = "Artillery cannot be hired as mercenaries"
            } else if currentMercs + u.maxMen > mercLimit {
                mercRefusal = ArmyRefusal.mercenaryCapReached.reason
            } else if treasury < Double(mercCost) {
                mercRefusal = ArmyRefusal.cannotAfford.reason
            } else {
                mercRefusal = ""
            }
            return [
                "unitTypeIndex": Int(u.id.rawValue),
                "key": u.key,
                "name": u.name,
                "category": u.category.displayName,
                "maxMen": u.maxMen,
                "statsText": String(format: "Atk %.0f · Def %.0f · Spd %.2f · %d men", u.attack, u.defence, u.speed, u.maxMen),
                "profCost": profCost,
                "canRecruitProf": profRefusal == nil,
                "profRefusal": profRefusal?.reason ?? "",
                "mercAllowed": mercAllowed,
                "mercCost": mercCost,
                "canHireMerc": mercAllowed && mercRefusal.isEmpty,
                "mercRefusal": mercRefusal
            ]
        }
    }

    public static func regimentSummary(_ w: World, regiments: [Regiment]) -> String {
        var counts: [UnitTypeID: (count: Int, men: Int, origins: Set<RegimentOrigin>)] = [:]
        for r in regiments {
            var entry = counts[r.type] ?? (0, 0, [])
            entry.count += 1
            entry.men += r.men
            entry.origins.insert(r.origin)
            counts[r.type] = entry
        }
        return counts.keys.sorted(by: { $0.rawValue < $1.rawValue }).map { uid in
            let info = counts[uid]!
            let uName = w.military.unit(uid).name
            let tag = info.origins.contains(.levy) ? " [levy]" : (info.origins.contains(.mercenary) ? " [merc]" : "")
            return "\(info.count)× \(uName)\(tag) (\(info.men))"
        }.joined(separator: ", ")
    }

    // MARK: - Formatting Helpers (matching App/Shared/ContentView.swift & EconomyViews.swift)

    public static func buildingName(_ t: BuildingTypeID, in p: ProvinceID, world: World) -> String {
        let type = world.economy.buildingTypes[t.index]
        let family = world.provinces.religion[p.index].family
        switch type.key {
        case "temple":
            switch family {
            case .christian: return "Church"
            case .muslim: return "Mosque"
            case .jewish: return "Synagogue"
            case .dharmic: return "Temple"
            default: return "Shrine"
            }
        case "college":
            return family == .muslim ? "Madrasa" : (family == .christian ? "University" : "College")
        default:
            return type.name
        }
    }

    public static func buildingEffectText(_ e: BuildingEffect, world: World) -> String {
        func pct(_ x: Double) -> String { "+\(Int((x * 100).rounded()))%" }
        switch e {
        case .staple(let x): return "\(pct(x)) staple food per level"
        case .trade(let x): return "\(pct(x)) trade good per level"
        case .fish(let x): return "\(pct(x)) fish per level"
        case .workshop(let r): return "Jobs for 2,500 burghers making \(world.economy.goods.name[world.economy.recipes[r].output.index])"
        case .crafts(let x): return "\(pct(x)) workshop output per level"
        case .tax(let x): return "\(pct(x)) tax per level"
        case .mood(let x): return "\(pct(x)) satisfaction per level"
        case .learning(let x): return "+\(x) learning a year per level"
        case .fort: return "Fort level +1"
        case .manpower(let x): return "+\(Int(x * 1000)) soldiers per level"
        case .ships(let x): return "+\(Int(x)) ships at a time per level"
        case .routes(let x): return "\(pct(x)) overland trade capacity per level"
        }
    }

    public static func formatAmount(_ units: Double) -> String {
        units >= 100 ? String(format: "%.0f u", units) : String(format: "%.1f u", units)
    }

    public static func formatPercent(_ v: Double) -> String {
        v >= 0.095 || v == 0 ? "\(Int((v * 100).rounded()))%" : String(format: "%.1f%%", v * 100)
    }

    public static func formatPeople(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.2f M", v / 1_000_000) }
        if v >= 10_000 { return "\(Int((v / 1000).rounded())) k" }
        return "\(Int(v.rounded()))"
    }

    public static func religionLabel(_ religion: Religion, _ b: PopBreakdown) -> String {
        let sects = b.bySect.filter { $0.key.religion == religion }
        guard let top = sects.max(by: { $0.value < $1.value }),
              let total = b.byReligion[religion],
              total > 0,
              top.value / total > 0.5 else {
            return religion.displayName
        }
        return "\(religion.displayName) (\(top.key.displayName))"
    }

    // MARK: - Map Texture Buffers

    /// Raw little-endian `UInt16` bytes (`width * height * 2`) for `Image.FORMAT_RG8`.
    /// Each pixel has `r = id & 0xFF`, `g = id >> 8`.
    public func provinceIDBytes() -> [UInt8] {
        guard let s = session else { return [] }
        return s.idMap.values.withUnsafeBytes { Array($0) }
    }

    /// Raw little-endian `UInt16` bytes (`width * height * 2`) for `Image.FORMAT_RG8`.
    public func seaIDBytes() -> [UInt8] {
        guard let s = session else { return [] }
        return s.seaMap.values.withUnsafeBytes { Array($0) }
    }

    /// Encodes `ProvinceStyle` for all ID-map values into a `2048 x 2` `RGBA8` image (`16,384` bytes):
    /// - Row 0 (`y = 0`): `(r, g, b, a)` map-mode colour (`a = 0` means no tint).
    /// - Row 1 (`y = 1`): `owner + 4` in `(r, g)` and `state + 4` in `(b, a)` as unsigned 16-bit little-endian integers.
    public func styleBytes() -> [UInt8] {
        let width = Self.styleTextureWidth
        var bytes = [UInt8](repeating: 0, count: width * 2 * 4)
        guard let s = session else { return bytes }
        let colors = MapStyling.colors(for: mapMode, world: s.world, player: s.playerCountry)
        let keys = MapStyling.keys(world: s.world)
        let count = min(colors.count, width)
        for v in 0..<count {
            let c = colors[v]
            let r = UInt8(c & 0xFF)
            let g = UInt8((c >> 8) & 0xFF)
            let b = UInt8((c >> 16) & 0xFF)
            let owner = keys.owner[v]
            let state = keys.state[v]
            var a: UInt8 = 255
            if v < 2 { a = 0 }
            if mapMode == .political && owner == -1 { a = 0 }
            if mapMode == .terrain { a = 0 }

            let row0 = v * 4
            bytes[row0] = r
            bytes[row0 + 1] = g
            bytes[row0 + 2] = b
            bytes[row0 + 3] = a

            let ownerEnc = UInt16(bitPattern: Int16(clamping: owner + 4))
            let stateEnc = UInt16(bitPattern: Int16(clamping: state + 4))
            let row1 = (width + v) * 4
            bytes[row1] = UInt8(ownerEnc & 0xFF)
            bytes[row1 + 1] = UInt8(ownerEnc >> 8)
            bytes[row1 + 2] = UInt8(stateEnc & 0xFF)
            bytes[row1 + 3] = UInt8(stateEnc >> 8)
        }
        return bytes
    }

    // MARK: - Map Labels

    public func countryLabelData() -> (texts: [String], metrics: [Float]) {
        guard let s = session else { return ([], []) }
        return packLabels(s.countryLabels)
    }

    public func provinceLabelData() -> (texts: [String], metrics: [Float]) {
        guard let s = session else { return ([], []) }
        return packLabels(s.provinceLabels)
    }

    public func seaLabelData() -> (texts: [String], metrics: [Float]) {
        guard let s = session else { return ([], []) }
        return packLabels(s.seaLabels)
    }

    private func packLabels(_ labels: [MapLabelInfo]) -> (texts: [String], metrics: [Float]) {
        var texts: [String] = []
        var metrics: [Float] = []
        texts.reserveCapacity(labels.count)
        metrics.reserveCapacity(labels.count * 3)
        for label in labels {
            texts.append(label.text)
            metrics.append(Float(label.x))
            metrics.append(Float(label.y))
            metrics.append(Float(label.pixelArea))
        }
        return (texts, metrics)
    }
}

/// GDExtension class exposed to GDScript (`GezGodotBridge.new()`).
@Godot
public final class GezGodotBridge: RefCounted {
    private let controller = GezGodotController()

    @Callable
    public func setup(dataDirectoryPath: String, tag: String = "TUR") -> Bool {
        controller.setup(dataDirectoryPath: dataDirectoryPath, tag: tag)
    }

    @Callable
    public func getMapWidth() -> Int { controller.mapWidth }

    @Callable
    public func getMapHeight() -> Int { controller.mapHeight }

    @Callable
    public func getFocusPoint(latitude: Double, longitude: Double) -> Vector2 {
        let pt = controller.focusPoint(latitude: latitude, longitude: longitude)
        return Vector2(x: Float(pt.x), y: Float(pt.y))
    }

    @Callable
    public func getCountryName() -> String { controller.countryName }

    @Callable
    public func getCountryTag() -> String { controller.countryTag }

    @Callable
    public func getTreasury() -> Double { controller.treasury }

    @Callable
    public func getMonthlyNet() -> Double { controller.monthlyNet }

    @Callable
    public func getDucatsText() -> String { controller.ducatsText }

    @Callable
    public func getDateText() -> String { controller.dateText }

    @Callable
    public func isPaused() -> Bool { controller.isPaused }

    @Callable
    public func getSpeed() -> Int { controller.speed }

    @Callable
    public func togglePause() { controller.togglePause() }

    @Callable
    public func setSpeed(speed: Int) { controller.setSpeed(speed) }

    @Callable
    public func faster() { controller.faster() }

    @Callable
    public func slower() { controller.slower() }

    @Callable
    public func tickFrame(deltaSeconds: Double) -> Int {
        controller.tickFrame(deltaSeconds: deltaSeconds)
    }

    @Callable
    public func getSelectedProvinceValue() -> Int { controller.selectedProvinceValue }

    @Callable
    public func getSelectedSeaValue() -> Int { controller.selectedSeaValue }

    @Callable
    public func selectAt(mapX: Int, mapY: Int) -> Int {
        controller.selectAt(mapX: mapX, mapY: mapY)
    }

    @Callable
    public func getProvinceSummaryAt(mapX: Int, mapY: Int) -> String {
        controller.provinceSummaryAt(mapX: mapX, mapY: mapY)
    }

    @Callable
    public func getSelectedOwnerName() -> String { controller.selectedOwnerName }

    @Callable
    public func playAsSelectedOwner() -> Bool { controller.playAsSelectedOwner() }

    @Callable
    public func getStyleTextureWidth() -> Int { GezGodotController.styleTextureWidth }

    @Callable
    public func getProvinceIDBytes() -> PackedByteArray {
        PackedByteArray(controller.provinceIDBytes())
    }

    @Callable
    public func getSeaIDBytes() -> PackedByteArray {
        PackedByteArray(controller.seaIDBytes())
    }

    @Callable
    public func getStyleBytes() -> PackedByteArray {
        PackedByteArray(controller.styleBytes())
    }

    @Callable
    public func getCountryLabelTexts() -> PackedStringArray {
        PackedStringArray(controller.countryLabelData().texts)
    }

    @Callable
    public func getCountryLabelMetrics() -> PackedFloat32Array {
        PackedFloat32Array(controller.countryLabelData().metrics)
    }

    @Callable
    public func getProvinceLabelTexts() -> PackedStringArray {
        PackedStringArray(controller.provinceLabelData().texts)
    }

    @Callable
    public func getProvinceLabelMetrics() -> PackedFloat32Array {
        PackedFloat32Array(controller.provinceLabelData().metrics)
    }

    @Callable
    public func getSeaLabelTexts() -> PackedStringArray {
        PackedStringArray(controller.seaLabelData().texts)
    }

    @Callable
    public func getSeaLabelMetrics() -> PackedFloat32Array {
        PackedFloat32Array(controller.seaLabelData().metrics)
    }

    // MARK: - Step 3a: Map Modes

    @Callable
    public func getMapMode() -> String { controller.mapModeKey }

    @Callable
    public func getShaderModeIndex() -> Int { controller.shaderModeIndex }

    @Callable
    public func getTintForZoom(zoom: Double) -> Double { controller.tint(forZoom: zoom) }

    @Callable
    public func setMapMode(key: String) -> Bool { controller.setMapMode(key: key) }

    @Callable
    public func getMapModes() -> VariantArray {
        Self.toVariantArray(controller.mapModesList())
    }

    // MARK: - Step 3a: Game Menu (Saves & Autosave)

    @Callable
    public func getAutosaveFrequency() -> String { controller.autosaveFrequencyKey }

    @Callable
    public func setAutosaveFrequency(key: String) -> Bool {
        controller.setAutosaveFrequency(key)
    }

    @Callable
    public func getAutosaveOptions() -> VariantArray {
        Self.toVariantArray(controller.autosaveOptions())
    }

    @Callable
    public func getLastSaveStatus() -> String { controller.lastSaveStatus }

    @Callable
    public func saveGame(name: String) -> Bool { controller.saveGame(named: name) }

    @Callable
    public func quickSave() -> Bool { controller.quickSave() }

    @Callable
    public func getSavedGames() -> VariantArray {
        Self.toVariantArray(controller.savedGamesList())
    }

    @Callable
    public func loadSavedGame(index: Int) -> Bool {
        controller.loadSavedGame(at: index)
    }

    @Callable
    public func deleteSavedGame(index: Int) -> Bool {
        controller.deleteSavedGame(at: index)
    }

    // MARK: - Step 3a: Nation Picker & New Game

    @Callable
    public func getSelectedProvinceOwnerTag() -> String {
        controller.selectedProvinceOwnerTag
    }

    @Callable
    public func getFeaturedCountries() -> VariantArray {
        Self.toVariantArray(controller.featuredCountriesList())
    }

    @Callable
    public func getAllCountries() -> VariantArray {
        Self.toVariantArray(controller.allCountriesList())
    }

    @Callable
    public func getCountryDetails(tag: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.countryDetails(tag: tag))
    }

    @Callable
    public func startNewGame(tag: String) -> Bool {
        controller.startNewGame(tag: tag)
    }

    @Callable
    public func switchPlayer(tag: String) -> Bool {
        controller.switchPlayer(tag: tag)
    }

    // MARK: - Step 3a: Province Panel, Sea Panel & Market Panel

    @Callable
    public func clearSelection() {
        controller.clearSelection()
    }

    @Callable
    public func getSelectedProvinceDetails(peopleShowState: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.selectedProvinceDetails(peopleShowState: peopleShowState))
    }

    @Callable
    public func getSelectedSeaDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.selectedSeaDetails())
    }

    @Callable
    public func buildInSelectedProvince(buildingTypeIndex: Int) -> Bool {
        controller.buildInSelectedProvince(buildingTypeIndex: buildingTypeIndex)
    }

    @Callable
    public func raiseSelectedProvinceLevies() -> Bool {
        controller.raiseSelectedProvinceLevies()
    }

    @Callable
    public func grantSelectedProvince(characterIndex: Int) -> Bool {
        controller.grantSelectedProvince(characterIndex: characterIndex)
    }

    @Callable
    public func revokeSelectedProvince() -> Bool {
        controller.revokeSelectedProvince()
    }

    @Callable
    public func getMarketDetails(marketIndex: Int, categoryKey: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.marketDetails(marketIndex: marketIndex, categoryKey: categoryKey))
    }

    // MARK: - Step 3b: Armies, Map Counters, Recruitment & Sieges

    @Callable
    public func getTopBarArmiesText() -> String {
        controller.topBarArmiesText
    }

    @Callable
    public func selectProvinceByIndex(provinceIndex: Int) -> Int {
        controller.selectProvinceByIndex(provinceIndex)
    }

    @Callable
    public func getSelectedArmyId() -> Int {
        controller.selectedArmyId
    }

    @Callable
    public func getMoveModeArmyId() -> Int {
        controller.moveModeArmyId
    }

    @Callable
    public func selectArmy(armyId: Int) -> Bool {
        controller.selectArmy(armyId: armyId)
    }

    @Callable
    public func clearSelectedArmy() {
        controller.clearSelectedArmy()
    }

    @Callable
    public func setMoveModeForArmy(armyId: Int) -> Bool {
        controller.setMoveModeForArmy(armyId: armyId)
    }

    @Callable
    public func getMapArmiesData() -> VariantDictionary {
        Self.toVariantDictionary(controller.mapArmiesData())
    }

    @Callable
    public func getSelectedArmyDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.selectedArmyDetails())
    }

    @Callable
    public func getArmiesWindowDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.armiesWindowDetails())
    }

    @Callable
    public func orderArmyMove(armyId: Int, provinceIndex: Int) -> Bool {
        controller.orderArmyMove(armyId: armyId, provinceIndex: provinceIndex)
    }

    @Callable
    public func orderArmyMoveAt(armyId: Int, mapX: Int, mapY: Int) -> Bool {
        controller.orderArmyMoveAt(armyId: armyId, mapX: mapX, mapY: mapY)
    }

    @Callable
    public func splitArmy(armyId: Int) -> Int {
        controller.splitArmy(armyId: armyId)
    }

    @Callable
    public func mergeArmies(armyId: Int) -> Bool {
        controller.mergeArmies(armyId: armyId)
    }

    @Callable
    public func disbandArmy(armyId: Int) -> Bool {
        controller.disbandArmy(armyId: armyId)
    }

    @Callable
    public func assignArmyCommander(armyId: Int, characterIndex: Int) -> Bool {
        controller.assignArmyCommander(armyId: armyId, characterIndex: characterIndex)
    }

    @Callable
    public func raiseAllLevies() -> Bool {
        controller.raiseAllLevies()
    }

    @Callable
    public func disbandAllLevies() -> Bool {
        controller.disbandAllLevies()
    }

    @Callable
    public func raiseLeviesInProvince(provinceIndex: Int) -> Bool {
        controller.raiseLeviesInProvince(provinceIndex: provinceIndex)
    }

    @Callable
    public func recruitProfessionalInProvince(unitTypeIndex: Int, provinceIndex: Int) -> Bool {
        controller.recruitProfessionalInProvince(unitTypeIndex: unitTypeIndex, provinceIndex: provinceIndex)
    }

    @Callable
    public func hireMercenaryInProvince(unitTypeIndex: Int, provinceIndex: Int) -> Bool {
        controller.hireMercenaryInProvince(unitTypeIndex: unitTypeIndex, provinceIndex: provinceIndex)
    }

    @Callable
    public func assaultSelectedProvinceFort() -> VariantDictionary {
        Self.toVariantDictionary(controller.assaultSelectedProvinceFort())
    }

    @Callable
    public func assaultFort(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.assaultFort(provinceIndex: provinceIndex))
    }

    // MARK: - Variant Conversion Helpers

    private static func toVariantDictionary(_ dict: [String: Any]) -> VariantDictionary {
        let out = VariantDictionary()
        for (k, v) in dict {
            out[k] = toVariant(v)
        }
        return out
    }

    private static func toVariantArray(_ array: [[String: Any]]) -> VariantArray {
        let out = VariantArray()
        for item in array {
            out.append(Variant(toVariantDictionary(item)))
        }
        return out
    }

    private static func toVariant(_ value: Any) -> Variant? {
        switch value {
        case let s as String:
            return Variant(s)
        case let i as Int:
            return Variant(i)
        case let d as Double:
            return Variant(d)
        case let f as Float:
            return Variant(f)
        case let b as Bool:
            return Variant(b)
        case let dict as [String: Any]:
            return Variant(toVariantDictionary(dict))
        case let dictArr as [[String: Any]]:
            return Variant(toVariantArray(dictArr))
        case let strArr as [String]:
            let arr = VariantArray()
            for item in strArr {
                arr.append(Variant(item))
            }
            return Variant(arr)
        case let dblArr as [Double]:
            let arr = VariantArray()
            for item in dblArr {
                arr.append(Variant(item))
            }
            return Variant(arr)
        case let anyArr as [Any]:
            let arr = VariantArray()
            for item in anyArr {
                arr.append(toVariant(item))
            }
            return Variant(arr)
        default:
            return nil
        }
    }
}

#initSwiftExtension(cdecl: "gez_godot_entry", types: [GezGodotBridge.self])
