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
    /// - bit 2 (`4`): wars count changed (styles/labels should refresh)
    public func tickFrame(deltaSeconds: Double) -> Int {
        guard let s = session else { return 0 }
        let outcome = s.advanceTime(elapsedSeconds: deltaSeconds)
        var mask = 0
        if outcome.daysAdvanced > 0 { mask |= 1 }
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
        let levyText = hasRaisedLevies ? "Raised" : "\(availLevy) men"

        let garrison = p.fortGarrison[i]
        let maxGarrison = p.maxGarrison(of: province)
        let siege = w.military.siege(in: province)
        var siegeText = ""
        if let siege {
            let besiegerName = c.name[siege.besieger.index]
            siegeText = "Besieged by \(besiegerName) · Progress \(siege.progress)\(siege.breached ? " (BREACHED)" : "")"
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
            "levyText": levyText,
            "fortGarrison": garrison,
            "maxGarrison": maxGarrison,
            "isBesieged": siege != nil,
            "siegeText": siegeText,
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
