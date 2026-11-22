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
    public private(set) var townIconsRevision: Int = 0

    public init() {}

    @discardableResult
    public func setup(dataDirectoryPath: String, tag: String = Scenario1453.defaultPlayerTag) -> Bool {
        if !dataDirectoryPath.isEmpty {
            GezResources.dataDirectory = URL(fileURLWithPath: dataDirectoryPath, isDirectory: true)
        }
        do {
            let s = try GameSession(tag: tag)
            s.autosaveFrequency = .never
            s.interactiveBattlesEnabled = true
            self.session = s
            townIconsRevision &+= 1
            return true
        } catch {
            return false
        }
    }

    private func refreshTownIconsIfChanged() {
        guard let s = session else { return }
        let before = s.townIcons
        s.rebuildTownIcons()
        if s.townIcons != before {
            townIconsRevision &+= 1
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
        case .plague: return 8
        case .unrest: return 9
        case .institutions: return 10
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
        case .plague: return "P"
        case .unrest: return "L"
        case .institutions: return "K"
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

    public var playerColor: RGB {
        guard let s = session, let p = s.playerCountry else { return RGB(180, 140, 80) }
        return s.world.countries.color[p.index]
    }

    public var playerStability: Int {
        guard let s = session, let p = s.playerCountry else { return 0 }
        return s.world.government.stability[p.index]
    }

    public var topBarStabilityText: String {
        String(format: "Stability %+d", playerStability)
    }

    public func playerTopBarDetails() -> [String: Any] {
        let rgb = playerColor
        let status = session?.playerTopBarStatus()
        let alertsSig = activeAlertsSignature()
        let stateReligionName = session.flatMap { s in
            s.playerCountry.map { s.world.countries.religion[$0.index].displayName }
        } ?? "Observer"
        let missUsed = session.flatMap { s in
            s.playerCountry.map { FaithSystem.activeMissionaries(s.world, for: $0).count }
        } ?? 0
        let missMax = session.flatMap { s in
            s.playerCountry.map { FaithSystem.maxMissionaries(s.world, $0) }
        } ?? 0
        let religionBtnText = session?.playerCountry != nil ? "\(stateReligionName) · \(missUsed)/\(missMax)" : "Religion"
        return [
            "playerCountryIndex": session?.playerCountry?.index ?? -1,
            "name": countryName,
            "tag": countryTag,
            "colorR": Int(rgb.r),
            "colorG": Int(rgb.g),
            "colorB": Int(rgb.b),
            "ducatsText": ducatsText,
            "inflationPercent": playerInflationPercent,
            "armiesText": topBarArmiesText,
            "fleetsText": topBarFleetsText,
            "stability": playerStability,
            "stabilityText": topBarStabilityText,
            "religionButtonText": religionBtnText,
            "rebelsButtonText": topBarRebelsText,
            "techButtonText": topBarTechText,
            "activeWarsCount": status?.activeWars ?? 0,
            "pendingPeaceOffersCount": status?.pendingPeaceOffers ?? 0,
            "year": session?.date.year ?? 1453,
            "dateText": dateText,
            "isPaused": isPaused,
            "speed": speed,
            "alertsSignature": alertsSig,
            "pendingEventCount": (session?.pendingPlayerEvent != nil ? 1 : 0),
            "recentEventsSignature": recentEventsSignature,
            "pauseOnEvents": pauseOnEvents
        ]
    }

    public var treasury: Double {
        guard let s = session, let p = s.playerCountry else { return 0 }
        return s.world.countries.treasury[p.index]
    }

    public var monthlyNet: Double {
        session?.playerTopBarStatus()?.monthlyNet ?? 0
    }

    /// Inflation in whole percent (the top bar shows it from 1%, like the Apple app).
    public var playerInflationPercent: Int {
        guard let s = session, let p = s.playerCountry else { return 0 }
        return Int((s.world.countries.inflation[p.index] * 100).rounded())
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
    private static func countOccupiedProvinces(_ occupiedBy: [CountryID?]) -> Int {
        var count = 0
        for occ in occupiedBy where occ != nil {
            count += 1
        }
        return count
    }

    public func tickFrame(deltaSeconds: Double) -> Int {
        guard let s = session else { return 0 }
        let prevOccupiedCount = Self.countOccupiedProvinces(s.world.provinces.occupiedBy)
        let outcome = s.advanceTime(elapsedSeconds: deltaSeconds)
        var mask = 0
        if outcome.daysAdvanced > 0 {
            mask |= 1
            let newOccupiedCount = Self.countOccupiedProvinces(s.world.provinces.occupiedBy)
            if newOccupiedCount != prevOccupiedCount {
                mask |= 4
            }
        }
        if outcome.monthChanged { mask |= 2 }
        if outcome.warsCountChanged {
            s.rebuildLabels()
            mask |= 4
        }
        if (mask & 6) != 0 {
            refreshTownIconsIfChanged()
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
        let ok = s.loadGame(s.savedGames[index])
        if ok {
            townIconsRevision &+= 1
        }
        return ok
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

    public func aiSettingOptions() -> [[String: Any]] {
        AIBehaviourSetting.allCases.map { opt in
            [
                "key": opt.rawValue,
                "title": opt.displayName,
                "description": opt.summaryDescription
            ]
        }
    }

    public var aiSettingKey: String {
        session?.aiSetting.rawValue ?? AIBehaviourSetting.historical.rawValue
    }

    public var aiSettingDisplayName: String {
        session?.aiSetting.displayName ?? AIBehaviourSetting.historical.displayName
    }

    @discardableResult
    public func startNewGame(tag: String, aiSettingKey: String = AIBehaviourSetting.historical.rawValue) -> Bool {
        guard let s = session else { return false }
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard s.world.countries.id(forTag: normalized) != nil else { return false }
        let setting = AIBehaviourSetting(rawValue: aiSettingKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .historical
        s.startNewGame(tag: normalized, aiSetting: setting)
        townIconsRevision &+= 1
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
        let builtBuildingDetails: [[String: Any]] = built.map { t in
            let bType = eco.buildingTypes[t.index]
            let lvl = eco.buildings.level(province, t)
            let monthlyUpkeep = BuildingSystem.yearlyUpkeep(bType, levels: lvl) / 12.0
            return [
                "typeIndex": t.index,
                "name": Self.buildingName(t, in: province, world: w),
                "level": lvl,
                "maxLevel": BuildingType.maxLevel,
                "category": bType.category.displayName,
                "effectText": Self.buildingEffectText(bType.effect, world: w),
                "upkeepMonthly": monthlyUpkeep,
                "upkeepText": monthlyUpkeep > 0 ? String(format: "%.1f/mo", monthlyUpkeep) : ""
            ]
        }
        let constructions: [[String: Any]] = eco.buildings.constructions
            .filter { $0.province == province }
            .map { con in
                [
                    "name": Self.buildingName(con.type, in: province, world: w),
                    "level": con.level,
                    "progress": con.progress,
                    "progressPercent": Int((con.progress * 100).rounded()),
                    "monthsLeft": con.monthsLeft,
                    "totalMonths": con.totalMonths
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
            var applicableOptions: [[String: Any]] = []
            var inapplicableOptions: [[String: Any]] = []
            for t in allTypes {
                let currentLevel = eco.buildings.level(province, t)
                let placeRefusal = BuildingSystem.refusal(w, player, province, t, checkMoney: false)
                let isApplicable = placeRefusal.map { !hiddenRefusals.contains($0) } ?? true
                let refusal = BuildingSystem.refusal(w, player, province, t)
                let nextLevel = min(BuildingType.maxLevel, BuildingSystem.nextLevel(w, province, t))
                let bType = eco.buildingTypes[t.index]
                let ducatsBase = Int(bType.ducats(forLevel: nextLevel).rounded())
                let cost = Int(BuildingSystem.cost(w, province, t).rounded())
                let months = bType.months(forLevel: nextLevel)
                var materialsList: [[String: Any]] = []
                var materialParts: [String] = []
                for (g, amount) in bType.materials {
                    let gName = eco.goods.name[g.index]
                    let amtText = amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
                    materialsList.append([
                        "goodIndex": g.index,
                        "name": gName,
                        "amount": amount,
                        "amountText": amtText
                    ])
                    materialParts.append("\(amtText) \(gName)")
                }
                let materialsText = materialParts.isEmpty ? "None" : materialParts.joined(separator: ", ")
                let baseName = Self.buildingName(t, in: province, world: w)
                let optionDict: [String: Any] = [
                    "typeIndex": t.index,
                    "category": bType.category.rawValue,
                    "name": currentLevel >= BuildingType.maxLevel ? "\(baseName) \(currentLevel)" : "\(baseName) \(nextLevel)",
                    "baseName": baseName,
                    "currentLevel": currentLevel,
                    "maxLevel": BuildingType.maxLevel,
                    "level": nextLevel,
                    "ducatsBase": ducatsBase,
                    "cost": cost,
                    "months": months,
                    "materials": materialsList,
                    "materialsText": materialsText,
                    "canBuild": refusal == nil,
                    "isApplicable": isApplicable,
                    "refusalReason": refusal?.reason ?? "",
                    "effectText": Self.buildingEffectText(bType.effect, world: w)
                ]
                if isApplicable {
                    applicableOptions.append(optionDict)
                } else {
                    inapplicableOptions.append(optionDict)
                }
            }
            let canBuildFirst = applicableOptions.filter { ($0["canBuild"] as? Bool) == true }
            let blockedApplicable = applicableOptions.filter { ($0["canBuild"] as? Bool) != true }
            buildableOptions = canBuildFirst + blockedApplicable + inapplicableOptions
        }

        let dockCap = w.dockCapacity(in: province)
        let buildableShips = buildableShipsList(for: province, world: w, player: s.playerCountry)
        let shipConstructions: [[String: Any]] = w.navy.constructions
            .filter { $0.province == province }
            .map { job in
                let st = w.navy.shipType(job.shipType)
                return [
                    "shipName": st.name,
                    "monthsLeft": job.monthsLeft,
                    "monthsTotal": job.monthsTotal
                ]
            }
        let stationedFleets: [[String: Any]] = w.navy.fleets(inPort: province).map { fid in
            let ownerIdx = w.navy.fleets.owner[fid.index].index
            return [
                "fleetId": fid.index,
                "name": w.navy.fleets.name[fid.index],
                "ownerTag": w.countries.tag[ownerIdx],
                "ships": w.navy.shipCount(of: fid),
                "isPlayer": ownerIdx == s.playerCountry?.index
            ]
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

        // Phase 11: Conversion, Assimilation, Unrest, Holy Sites, & Reformation
        let provB = peopleShowState ? w.breakdown(of: province) : breakdown
        let stateRelShare: Double
        if let owner, provB.total > 0 {
            let sr = w.countries.religion[owner.index]
            stateRelShare = (provB.byReligion[sr] ?? 0) / provB.total
        } else {
            stateRelShare = p.conversionProgress[i]
        }
        let primaryCultShare: Double
        if let owner, provB.total > 0 {
            let pc = w.countries.primaryCulture[owner.index]
            primaryCultShare = (provB.byCulture[pc] ?? 0) / provB.total
        } else {
            primaryCultShare = p.assimilationProgress[i]
        }
        let convProgress = stateRelShare
        let assimProgress = primaryCultShare
        let relUnrest = p.religiousUnrest[i]
        let devastation = p.devastation[i]
        let famine = p.famine[i]
        let netMigration = p.lastNetMigration[i]
        let hasMissionary = FaithSystem.hasMissionary(w, in: province)
        let missRefusal: MissionaryRefusal? = s.playerCountry.flatMap {
            FaithSystem.missionaryRefusal(w, by: $0, in: province)
        }
        let canSendMissionary = isPlayerOwned && (missRefusal == nil)

        var rateText = "—"
        if let owner {
            let ownerRel = w.countries.religion[owner.index]
            let provBreakdown = w.breakdown(of: province)
            let wrongReligions = provBreakdown.byReligion
                .filter { $0.key != ownerRel && $0.value > 0.01 }
                .sorted { $0.value > $1.value }
            if let topWrong = wrongReligions.first {
                let rate = FaithSystem.monthlyConversionRate(world: w, province: province, from: topWrong.key)
                if rate > 0 {
                    rateText = String(format: "+%.2f%%/mo", rate * 100.0)
                } else {
                    rateText = "Blocked"
                }
            } else {
                rateText = "100% state faith"
            }
        }

        let provHolySites: [[String: Any]] = FaithSystem.holySites(in: province, world: w).map { site in
            [
                "name": site.name,
                "religions": site.religions.map(\.displayName).joined(separator: ", ")
            ]
        }
        let refCentreDict: [String: Any]
        if let rc = w.faith.reformationCentres.first(where: { $0.province == province }) {
            refCentreDict = [
                "exists": true,
                "religion": rc.religion.displayName,
                "foundedYear": rc.foundedYear,
                "monthsActive": rc.monthsActive
            ]
        } else {
            refCentreDict = ["exists": false]
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
            "ownerIndex": owner?.index ?? -1,
            "isForeignOwner": (owner != nil && !isPlayerOwned),
            "ownerColorR": Int(ownerRGB.r),
            "ownerColorG": Int(ownerRGB.g),
            "ownerColorB": Int(ownerRGB.b),
            "isCapital": isCapital,
            "isPlayerOwned": isPlayerOwned,
            "occupiedByName": occupiedByName,
            "countryStatus": countryStatus,
            "holderName": holderName,
            "holderIndex": holder?.index ?? -1,
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
            "hasDocks": dockCap > 0,
            "dockCapacity": dockCap,
            "buildableShips": buildableShips,
            "shipConstructions": shipConstructions,
            "stationedFleets": stationedFleets,
            "isPortBlockaded": w.navy.blockadedProvinces.contains(province),
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
            "builtBuildingDetails": builtBuildingDetails,
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
            "sufiText": sufiText,
            "conversionProgress": convProgress,
            "conversionText": Self.formatPercent(convProgress),
            "assimilationProgress": assimProgress,
            "assimilationText": Self.formatPercent(assimProgress),
            "religiousUnrest": relUnrest,
            "religiousUnrestText": String(format: "%.1f", relUnrest),
            "devastation": devastation,
            "devastationText": Self.formatPercent(devastation),
            "famine": famine,
            "famineText": Self.formatPercent(famine),
            "netMigration": netMigration,
            "netMigrationText": (netMigration >= 0 ? "+" : "") + "\(Int(netMigration.rounded()))",
            "hasMissionary": hasMissionary,
            "canSendMissionary": canSendMissionary,
            "missionaryRefusal": missRefusal?.reason ?? "",
            "monthlyConversionRateText": rateText,
            "holySites": provHolySites,
            "reformationCentre": refCentreDict
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
        let isInland = sea.index < z.isInland.count && z.isInland[sea.index]
        let fleetsHere: [[String: Any]] = w.navy.fleets(inSea: sea).map { fid in
            let fo = w.navy.fleets.owner[fid.index]
            return [
                "fleetId": fid.index,
                "name": w.navy.fleets.name[fid.index],
                "ownerTag": w.countries.tag[fo.index],
                "ships": w.navy.shipCount(of: fid),
                "isPlayer": fo == s.playerCountry
            ]
        }
        let activeBattleText: String
        if let b = w.navy.navalBattle(in: sea) {
            let phase = b.dayCount <= 2 ? "Cannon" : "Boarding"
            activeBattleText = "\(w.countries.tag[b.attacker.country.index]) vs \(w.countries.tag[b.defender.country.index]) · Day \(b.dayCount) (\(phase))"
        } else {
            activeBattleText = ""
        }
        return [
            "hasSelection": true,
            "seaZoneIndex": sea.index,
            "name": z.name[sea.index],
            "isInland": isInland,
            "neighborsText": neighborsText,
            "coastCount": coast.count,
            "coastText": coastText,
            "fleets": fleetsHere,
            "activeBattleText": activeBattleText
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
    /// Fast digest of map armies, routes, battles, sieges, and selection so GDScript can skip redundant marshaling.
    public func mapArmiesSignature() -> Int {
        guard let s = session else { return 0 }
        var hasher = Hasher()
        let w = s.world
        let armies = w.military.armies
        hasher.combine(selectedArmyId)
        hasher.combine(moveModeArmyId)
        hasher.combine(s.playerCountry?.index ?? -1)
        hasher.combine(w.diplomacy.wars.count)
        hasher.combine(w.military.battles.count)
        hasher.combine(w.military.sieges.count)
        for i in 0..<armies.count where armies.alive[i] {
            hasher.combine(i)
            hasher.combine(armies.province[i].index)
            hasher.combine(armies.path[i].count)
            hasher.combine(armies.totalMen(of: ArmyID(Int32(i))))
            hasher.combine(armies.isRetreating[i])
            // Whole days walked towards the next stop: moves the 3D figures daily.
            hasher.combine(Int(armies.moveProgressDays[i]))
        }
        return hasher.finalize()
    }

    public func mapArmiesData() -> [String: Any] {
        guard let s = session else {
            return ["selectedArmyId": -1, "moveModeArmyId": -1, "counters": [], "routes": []]
        }
        let w = s.world
        let armies = w.military.armies
        let positions = s.provincePositions
        let curSelectedId = selectedArmyId
        let curMoveId = moveModeArmyId

        var enemyCountries = Set<CountryID>()
        if let player = s.playerCountry {
            for war in w.diplomacy.wars {
                if war.isAttacker(player) {
                    enemyCountries.formUnion(war.defenders)
                } else if war.isDefender(player) {
                    enemyCountries.formUnion(war.attackers)
                }
            }
        }
        let battleProvs = Set(w.military.battles.map(\.province))

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
            let isEnemy = enemyCountries.contains(owner)
            let rgb = w.countries.color[owner.index]

            let inBattle = battleProvs.contains(prov) && w.military.isInBattle(aid)
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
        let techMoraleBonus = w.techEffects(owner, track: .military).landMorale
        var totalMen = 0
        var maxMen = 0
        var weightedMorale = 0.0
        var weightedMaxMorale = 0.0
        var regimentRows: [[String: Any]] = []
        for (rIndex, reg) in regs.enumerated() {
            let u = w.military.unit(reg.type)
            let regMaxMorale = u.morale + techMoraleBonus
            totalMen += reg.men
            maxMen += u.maxMen
            let weight = Double(max(1, reg.men))
            weightedMorale += reg.morale * weight
            weightedMaxMorale += regMaxMorale * weight
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
                "maxMorale": regMaxMorale,
                "moraleText": String(format: "%.2f / %.2f", reg.morale, regMaxMorale),
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

        let playerRGB = Self.countryRGB(w, player)
        return [
            "valid": true,
            "playerTag": w.countries.tag[player.index],
            "playerName": w.countries.name[player.index],
            "playerColorR": Int(playerRGB.r),
            "playerColorG": Int(playerRGB.g),
            "playerColorB": Int(playerRGB.b),
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

    // MARK: - Step 3c: Budget & Trade

    public static func taxLevelName(_ level: Double) -> String {
        switch level {
        case ..<0.01: return "None"
        case ..<0.76: return "Low"
        case ..<1.01: return "Normal"
        case ..<1.51: return "High"
        default: return "Crushing"
        }
    }

    /// Detailed breakdown for the top-bar Budget window (`App/Shared/BudgetView.swift`).
    public func budgetDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let c = player.index
        let tax = w.countries.lastTax[c]
        let isDebasing = w.countries.debasing[c]
        let debaseIncome = c < w.countries.lastDebaseIncome.count ? w.countries.lastDebaseIncome[c] : 0.0
        let income = w.countries.lastMonthlyIncome[c] + debaseIncome
        let spend = w.countries.lastMonthlyExpenses[c]
        let net = Breakdowns.monthlyIncome(w, for: player).total
        let vassalTax = w.countries.lastVassalTax[c]
        let trade = w.countries.lastTrade[c]
        let tolls = w.countries.lastTolls[c]
        let buildingUpkeep = w.countries.lastUpkeep[c]
        let armyUpkeep = w.military.lastArmyUpkeep[c]
        let navyUpkeep = c < w.navy.lastNavyUpkeep.count ? w.navy.lastNavyUpkeep[c] : 0.0
        let interest = w.countries.lastInterest[c]
        let treasury = w.countries.treasury[c]
        let bankruptMonths = w.countries.bankruptMonthsLeft[c]
        let bankruptcyWarning = bankruptMonths > 0
            ? "Bankrupt: no loans, income -25% and unrest for \(bankruptMonths) more months"
            : ""

        var taxBreakdown: [[String: Any]] = []
        var taxes: [[String: Any]] = []
        let ownedProvinces = w.provinces(ownedBy: player)
        for tc in TaxClass.allCases {
            let amount = tax[tc.rawValue]
            taxBreakdown.append([
                "taxClassIndex": tc.rawValue,
                "name": "Tax on \(tc.socialClass.displayName.lowercased())",
                "className": tc.socialClass.displayName,
                "amount": amount,
                "amountText": String(format: "%.1f", amount)
            ])
            let level = w.countries.taxLevel[c][tc.rawValue]
            let sat = w.satisfaction(of: tc.socialClass, in: ownedProvinces)
            let satPct = sat.map { Int(($0 * 100).rounded()) } ?? 0
            taxes.append([
                "taxClassIndex": tc.rawValue,
                "name": tc.socialClass.displayName,
                "level": level,
                "maxLevel": Finance.maxTaxLevel,
                "levelName": Self.taxLevelName(level),
                "hasSatisfaction": sat != nil,
                "satisfactionPercent": satPct,
                "satisfactionText": sat != nil ? "Content: \(satPct)%" : ""
            ])
        }

        let inflation = w.countries.inflation[c]
        let canDebase = GovernmentSystem.canDebase(w, player)
        let quickDebase = max(10.0, w.countries.lastMonthlyIncome[c] * Finance.debaseOnceMonths)
        let debaseOnceInflationPct = Finance.debaseOnceInflation * 100.0
        let canToggleDebasing = (canDebase && bankruptMonths == 0) || isDebasing

        let loans: [[String: Any]] = w.finance.loans.enumerated()
            .filter { $0.element.country == player }
            .map { entry in
                let idx = entry.offset
                let loan = entry.element
                let bankName = loan.bank.index < w.finance.banks.count ? w.finance.banks.name[loan.bank.index] : "Bank"
                return [
                    "loanIndex": idx,
                    "bankIndex": loan.bank.index,
                    "bankName": bankName,
                    "principal": loan.principal,
                    "ratePercent": loan.rate * 100.0,
                    "monthsLeft": loan.monthsLeft,
                    "detailsText": String(format: "%.0f at %.1f%% · %d mo", loan.principal, loan.rate * 100.0, loan.monthsLeft),
                    "canRepay": treasury >= loan.principal
                ]
            }

        let banks: [[String: Any]] = w.finance.banks.ids
            .compactMap { b in w.loanRate(b, for: player).map { (b, $0) } }
            .sorted { $0.1 < $1.1 }
            .map { entry in
                let bank = entry.0
                let rate = entry.1
                let cap = w.finance.banks.capital[bank.index]
                let amounts: [[String: Any]] = Finance.loanSizes.map { amt in
                    [
                        "amount": amt,
                        "label": "+\(Int(amt))",
                        "canBorrow": cap >= amt
                    ]
                }
                return [
                    "bankIndex": bank.index,
                    "name": w.finance.banks.name[bank.index],
                    "rate": rate,
                    "ratePercent": rate * 100.0,
                    "capital": cap,
                    "rateText": String(format: "%.1f%% a year · %.0f to lend", rate * 100.0, cap),
                    "amounts": amounts
                ]
            }

        return [
            "valid": true,
            "treasury": treasury,
            "treasuryText": String(format: "%.1f", treasury),
            "monthlyIncome": income,
            "monthlyExpenses": spend,
            "monthlyNet": net,
            "balanceText": String(format: "%+.1f / month", net),
            "vassalTax": vassalTax,
            "vassalTaxText": String(format: "−%.1f", vassalTax),
            "debaseOngoingIncome": debaseIncome,
            "debaseOngoingIncomeText": String(format: "%.1f", debaseIncome),
            "merchants": trade,
            "merchantsText": String(format: "%+.1f", trade),
            "tolls": tolls,
            "tollsText": String(format: "%.1f", tolls),
            "buildingUpkeep": buildingUpkeep,
            "buildingUpkeepText": String(format: "−%.1f", buildingUpkeep),
            "armyUpkeep": armyUpkeep,
            "armyUpkeepText": String(format: "−%.1f", armyUpkeep),
            "navyUpkeep": navyUpkeep,
            "navyUpkeepText": String(format: "−%.1f", navyUpkeep),
            "interest": interest,
            "interestText": String(format: "−%.1f", interest),
            "taxBreakdown": taxBreakdown,
            "taxes": taxes,
            "inflation": inflation,
            "inflationPercent": inflation * 100.0,
            "inflationText": String(format: "%.1f%%", inflation * 100.0),
            "canDebase": canDebase,
            "canDebaseOnce": canDebase,
            "debaseRefusal": canDebase ? "" : "Your Sound money law forbids debasing the coin.",
            "debaseOnceGain": quickDebase,
            "debaseOnceInflationPercent": debaseOnceInflationPct,
            "debaseOnceText": String(format: "Debase once: +%.0f, +%.0f%% inflation", quickDebase, debaseOnceInflationPct),
            "isDebasing": isDebasing,
            "canToggleDebasing": canToggleDebasing,
            "debaseOngoingText": String(
                format: "Keep debasing (+%.0f%% income, +%.1f%% inflation a month)",
                Finance.debaseOngoingIncome * 100.0,
                Finance.debaseOngoingInflation * 100.0
            ),
            "isBankrupt": bankruptMonths > 0,
            "bankruptMonthsLeft": bankruptMonths,
            "bankruptcyWarning": bankruptcyWarning,
            "loans": loans,
            "banks": banks
        ]
    }

    @discardableResult
    public func setTaxLevel(taxClassIndex: Int, level: Double) -> Bool {
        guard let s = session,
              s.playerCountry != nil,
              taxClassIndex >= 0 && taxClassIndex < TaxClass.allCases.count,
              let tc = TaxClass(rawValue: taxClassIndex),
              level.isFinite else {
            return false
        }
        s.setTax(tc, level: level)
        return true
    }

    @discardableResult
    public func borrowFromBank(bankIndex: Int, amount: Double) -> Bool {
        guard let s = session,
              let player = s.playerCountry,
              bankIndex >= 0 && bankIndex < s.world.finance.banks.count,
              amount > 0 && amount.isFinite else {
            return false
        }
        let bank = BankID(bankIndex)
        guard s.world.loanRate(bank, for: player) != nil,
              s.world.finance.banks.capital[bankIndex] >= amount else {
            return false
        }
        let countBefore = s.world.finance.loans.count
        s.borrow(from: bank, amount: amount)
        return s.world.finance.loans.count > countBefore
    }

    @discardableResult
    public func repayLoan(loanIndex: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry,
              loanIndex >= 0 && loanIndex < s.world.finance.loans.count else {
            return false
        }
        let loan = s.world.finance.loans[loanIndex]
        guard loan.country == player,
              s.world.countries.treasury[player.index] >= loan.principal else {
            return false
        }
        let countBefore = s.world.finance.loans.count
        s.repay(loan: loanIndex)
        return s.world.finance.loans.count < countBefore
    }

    @discardableResult
    public func debaseOnce() -> Double {
        guard let s = session,
              let player = s.playerCountry,
              GovernmentSystem.canDebase(s.world, player) else {
            return 0.0
        }
        return s.debaseOnce()
    }

    @discardableResult
    public func setDebasing(on: Bool) -> Bool {
        guard let s = session, let player = s.playerCountry else {
            return false
        }
        if on && (s.world.countries.bankruptMonthsLeft[player.index] > 0 || !GovernmentSystem.canDebase(s.world, player)) {
            return false
        }
        s.setDebasing(on)
        return s.world.countries.debasing[player.index] == on
    }

    private static func routeTollRateShare(world w: World, owner: CountryID, path: [MarketID]) -> Double {
        guard path.count > 2 else { return 0.0 }
        var share = 0.0
        for s in 1..<(path.count - 1) {
            if let o = w.marketOwner(path[s]), o != owner {
                share += w.countries.tollPolicy[o.index].rate
            }
        }
        return share
    }

    /// Detailed breakdown for the top-bar Trade window (`App/Shared/TradeView.swift`).
    public func tradeWindowDetails(
        draftGoodIndex: Int = -1,
        draftFromMarketIndex: Int = -1,
        draftToMarketIndex: Int = -1,
        draftVolume: Double = 25.0
    ) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let eco = w.economy
        let used = w.tradeCapacityUsed(player)
        let total = w.tradeCapacity(player)

        let playerRoutes: [[String: Any]] = eco.routes.enumerated()
            .filter { $0.element.owner == player }
            .map { entry in
                let idx = entry.offset
                let r = entry.element
                let rgb = eco.goods.color[r.good.index]
                let gName = eco.goods.name[r.good.index]
                let fromName = eco.markets.name[r.from.index]
                let toName = eco.markets.name[r.to.index]
                let isBlocked = r.path.isEmpty
                let isLosing = r.monthsLosing > 0
                let movedYr = r.moved * 12.0
                let profitYr = r.profit * 12.0
                let buyPrice = eco.markets.price(r.from, r.good)
                let tollShare = Self.routeTollRateShare(world: w, owner: player, path: r.path)
                let tollsYr = isBlocked ? 0.0 : movedYr * buyPrice * tollShare
                let pathText = isBlocked
                    ? "Blocked: no open way"
                    : "Via " + r.path.map { eco.markets.name[$0.index] }.joined(separator: " → ")
                let detailsText: String
                if isBlocked {
                    detailsText = "Blocked: no open way"
                } else {
                    let losingSuffix = isLosing ? " · losing money" : ""
                    detailsText = String(
                        format: "%.0f of %.0f/yr · %+.1f/yr · tolls %.1f/yr%@",
                        movedYr, r.volume, profitYr, tollsYr, losingSuffix
                    )
                }
                return [
                    "routeIndex": idx,
                    "goodIndex": r.good.index,
                    "goodName": gName,
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b),
                    "fromMarketIndex": r.from.index,
                    "fromMarketName": fromName,
                    "toMarketIndex": r.to.index,
                    "toMarketName": toName,
                    "titleText": "\(gName): \(fromName) → \(toName)",
                    "movedYearly": movedYr,
                    "volume": r.volume,
                    "profitYearly": profitYr,
                    "tollsYearly": tollsYr,
                    "isBlocked": isBlocked,
                    "isLosing": isLosing,
                    "monthsLosing": r.monthsLosing,
                    "pathText": pathText,
                    "detailsText": detailsText
                ]
            }

        var goodsList: [[String: Any]] = []
        for cat in GoodCategory.allCases {
            for g in eco.goods.ids where eco.goods.category[g.index] == cat {
                let rgb = eco.goods.color[g.index]
                goodsList.append([
                    "goodIndex": g.index,
                    "name": eco.goods.name[g.index],
                    "categoryKey": cat.rawValue,
                    "categoryTitle": cat.displayName,
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b)
                ])
            }
        }

        let categories: [[String: Any]] = [["key": "", "title": "All"]] + GoodCategory.allCases.map {
            ["key": $0.rawValue, "title": $0.displayName]
        }

        let validDraftGood = (draftGoodIndex >= 0 && draftGoodIndex < eco.goods.count) ? GoodID(draftGoodIndex) : nil
        let sortedMarkets = eco.markets.ids.sorted { eco.markets.name[$0.index] < eco.markets.name[$1.index] }
        let marketsList: [[String: Any]] = sortedMarkets.map { m in
            let name = eco.markets.name[m.index]
            let price = validDraftGood.map { eco.markets.price(m, $0) } ?? 0.0
            let priceText = validDraftGood != nil ? String(format: "%.1f", price) : ""
            return [
                "marketIndex": m.index,
                "name": name,
                "price": price,
                "priceText": priceText,
                "label": validDraftGood != nil ? "\(name) (\(priceText))" : name
            ]
        }

        var sourceSuggestions: [[String: Any]] = []
        if let g = validDraftGood {
            let destID = (draftToMarketIndex >= 0 && draftToMarketIndex < eco.markets.count) ? MarketID(draftToMarketIndex) : nil
            let bestSources = eco.markets.ids
                .filter { $0 != destID && eco.markets.supply[eco.markets.slot($0, g)] > 0 }
                .sorted { eco.markets.price($0, g) < eco.markets.price($1, g) }
                .prefix(5)
            for m in bestSources {
                let p = eco.markets.price(m, g)
                let pText = String(format: "%.1f", p)
                sourceSuggestions.append([
                    "marketIndex": m.index,
                    "name": eco.markets.name[m.index],
                    "price": p,
                    "priceText": pText,
                    "label": "\(eco.markets.name[m.index]) (\(pText))"
                ])
            }
        }

        let tollPolicies: [[String: Any]] = TollPolicy.allCases.map { p in
            ["key": p.rawValue, "title": p.displayName]
        }

        let embargoSet = w.countries.embargoes[player.index]
        let embargoes: [[String: Any]] = embargoSet.sorted { $0.index < $1.index }.map { c in
            let rgb = w.countries.color[c.index]
            return [
                "countryIndex": c.index,
                "tag": w.countries.tag[c.index],
                "name": w.countries.name[c.index],
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ]
        }

        let tradingCountries = Set(eco.routes.map(\.owner)).subtracting([player]).subtracting(embargoSet)
            .sorted { w.countries.name[$0.index] < w.countries.name[$1.index] }
        let embargoCandidates: [[String: Any]] = tradingCountries.map { c in
            [
                "countryIndex": c.index,
                "tag": w.countries.tag[c.index],
                "name": w.countries.name[c.index]
            ]
        }

        let estimate = (draftGoodIndex >= 0 && draftFromMarketIndex >= 0 && draftToMarketIndex >= 0)
            ? estimateTradeRoute(
                goodIndex: draftGoodIndex,
                fromMarketIndex: draftFromMarketIndex,
                toMarketIndex: draftToMarketIndex,
                volume: draftVolume
            )
            : ["hasEstimate": false, "canCreate": false, "refusalReason": ""]

        return [
            "valid": true,
            "capacityUsed": used,
            "capacityTotal": total,
            "capacityRatio": min(used, total) / max(total, 1.0),
            "capacityText": String(format: "%.0f / %.0f", used, total),
            "lastTrade": w.countries.lastTrade[player.index],
            "lastTolls": w.countries.lastTolls[player.index],
            "lastMonthText": String(
                format: "Last month: merchants %+.1f, tolls %+.1f",
                w.countries.lastTrade[player.index],
                w.countries.lastTolls[player.index]
            ),
            "routes": playerRoutes,
            "goodCategories": categories,
            "goods": goodsList,
            "markets": marketsList,
            "sourceSuggestions": sourceSuggestions,
            "volumes": TradeSystem.volumes,
            "tollPolicyKey": w.countries.tollPolicy[player.index].rawValue,
            "tollPolicies": tollPolicies,
            "embargoes": embargoes,
            "embargoCandidates": embargoCandidates,
            "estimate": estimate
        ]
    }

    public func estimateTradeRoute(
        goodIndex: Int,
        fromMarketIndex: Int,
        toMarketIndex: Int,
        volume: Double
    ) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasEstimate": false, "canCreate": false, "refusalReason": "No active country"]
        }
        let w = s.world
        let eco = w.economy
        guard goodIndex >= 0 && goodIndex < eco.goods.count,
              fromMarketIndex >= 0 && fromMarketIndex < eco.markets.count,
              toMarketIndex >= 0 && toMarketIndex < eco.markets.count,
              volume > 0 && volume.isFinite else {
            return ["hasEstimate": false, "canCreate": false, "refusalReason": "Invalid route selection"]
        }
        let good = GoodID(goodIndex)
        let fromM = MarketID(fromMarketIndex)
        let toM = MarketID(toMarketIndex)
        if fromM == toM {
            return [
                "hasEstimate": true,
                "canCreate": false,
                "refusalReason": TradeSystem.Refusal.sameMarket.reason,
                "summaryText": "",
                "pathText": ""
            ]
        }
        guard let est = w.routeEstimate(owner: player, good: good, from: fromM, to: toM, volume: volume) else {
            return [
                "hasEstimate": true,
                "canCreate": false,
                "refusalReason": TradeSystem.Refusal.noPath.reason,
                "summaryText": "",
                "pathText": ""
            ]
        }
        let buy = eco.markets.price(fromM, good)
        let sell = eco.markets.price(toM, good)
        let tollShare = Self.routeTollRateShare(world: w, owner: player, path: est.path)
        let tollsYearly = volume * buy * tollShare
        let hasCapacity = (w.tradeCapacityUsed(player) + est.capacity <= w.tradeCapacity(player))
        let refusal = hasCapacity ? "" : TradeSystem.Refusal.noCapacity.reason
        let pathText = "Via " + est.path.map { eco.markets.name[$0.index] }.joined(separator: " → ")
        let summaryText = String(
            format: "Buy at %.1f, sell at %.1f · %+.0f/yr · tolls %.1f/yr · uses %.0f capacity",
            buy, sell, est.profit, tollsYearly, est.capacity
        )
        return [
            "hasEstimate": true,
            "buyPrice": buy,
            "sellPrice": sell,
            "profit": est.profit,
            "estimatedTolls": tollsYearly,
            "capacity": est.capacity,
            "pathText": pathText,
            "summaryText": summaryText,
            "canCreate": hasCapacity,
            "refusalReason": refusal
        ]
    }

    public func createTradeRoute(
        goodIndex: Int,
        fromMarketIndex: Int,
        toMarketIndex: Int,
        volume: Double
    ) -> [String: Any] {
        guard let s = session, s.playerCountry != nil else {
            return ["created": false, "refusalReason": "No active country"]
        }
        let eco = s.world.economy
        guard goodIndex >= 0 && goodIndex < eco.goods.count,
              fromMarketIndex >= 0 && fromMarketIndex < eco.markets.count,
              toMarketIndex >= 0 && toMarketIndex < eco.markets.count,
              volume > 0 && volume.isFinite else {
            return ["created": false, "refusalReason": "Invalid route selection"]
        }
        let refusal = s.createRoute(
            good: GoodID(goodIndex),
            from: MarketID(fromMarketIndex),
            to: MarketID(toMarketIndex),
            volume: volume
        )
        return [
            "created": refusal == nil,
            "refusalReason": refusal?.reason ?? ""
        ]
    }

    @discardableResult
    public func cancelTradeRoute(routeIndex: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry,
              routeIndex >= 0 && routeIndex < s.world.economy.routes.count,
              s.world.economy.routes[routeIndex].owner == player else {
            return false
        }
        s.cancelRoute(routeIndex)
        return true
    }

    @discardableResult
    public func setTollPolicy(key: String) -> Bool {
        guard let s = session,
              s.playerCountry != nil,
              let policy = TollPolicy(rawValue: key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
            return false
        }
        s.setTollPolicy(policy)
        return true
    }

    @discardableResult
    public func toggleEmbargo(countryIndex: Int) -> Bool {
        guard let s = session,
              let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              CountryID(countryIndex) != player else {
            return false
        }
        s.toggleEmbargo(CountryID(countryIndex))
        return true
    }

    /// Data for `MapRoutesLayer.gd`: player's trade routes and market centres.
    public func mapTradeRoutesData() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["signature": "empty", "markets": [], "routes": []]
        }
        let w = s.world
        let eco = w.economy
        let centres = s.marketCentrePoints

        var playerEndpoints = Set<Int>()
        var routesOut: [[String: Any]] = []
        var sigParts: [String] = [w.countries.tag[player.index]]

        for (idx, r) in eco.routes.enumerated() where r.owner == player {
            guard r.from.index < centres.count && r.to.index < centres.count else { continue }
            playerEndpoints.insert(r.from.index)
            playerEndpoints.insert(r.to.index)
            let fromPt = centres[r.from.index]
            let toPt = centres[r.to.index]
            var pts: [Double] = []
            for m in r.path where m.index >= 0 && m.index < centres.count {
                pts.append(centres[m.index].x)
                pts.append(centres[m.index].y)
                playerEndpoints.insert(m.index)
            }
            let isBlocked = r.path.count < 2
            let isLosing = r.monthsLosing > 0
            let value = max(r.moved * 12.0, r.volume * 0.25) * eco.goods.basePrice[r.good.index]
            let rgb = eco.goods.color[r.good.index]
            let pathSig = r.path.map { String($0.index) }.joined(separator: "-")
            sigParts.append("\(idx):\(r.good.index):\(r.from.index):\(r.to.index):\(Int(r.volume)):\(pathSig):\(Int(r.moved * 10)):\(r.monthsLosing)")

            routesOut.append([
                "routeIndex": idx,
                "goodName": eco.goods.name[r.good.index],
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b),
                "isBlocked": isBlocked,
                "isLosing": isLosing,
                "value": value,
                "fromX": fromPt.x,
                "fromY": fromPt.y,
                "toX": toPt.x,
                "toY": toPt.y,
                "points": pts
            ])
        }

        var marketsOut: [[String: Any]] = []
        for m in eco.markets.ids where m.index < centres.count {
            let pt = centres[m.index]
            marketsOut.append([
                "marketIndex": m.index,
                "name": eco.markets.name[m.index],
                "x": pt.x,
                "y": pt.y,
                "isPlayerEndpoint": playerEndpoints.contains(m.index)
            ])
        }

        return [
            "signature": sigParts.joined(separator: "|"),
            "markets": marketsOut,
            "routes": routesOut
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

    // MARK: - Step 3d1: Court & Government

    @discardableResult
    public func setViewedCharacter(characterIndex: Int) -> Bool {
        guard let s = session else { return false }
        if characterIndex < 0 {
            s.viewedCharacter = nil
            return true
        }
        guard characterIndex < s.world.people.characters.count else { return false }
        s.viewedCharacter = CharacterID(characterIndex)
        return true
    }

    public func courtDetails(marryingCharacterIndex: Int = -1) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let ch = w.people.characters
        let date = s.date
        let ruler = w.countries.ruler[player.index]
        if let viewed = s.viewedCharacter, viewed.index < 0 || viewed.index >= ch.count {
            s.viewedCharacter = nil
        }
        let shown = s.viewedCharacter ?? ruler
        let playerRGB = w.countries.color[player.index]

        var characterDict: [String: Any] = [:]
        var familyTree: [[String: Any]] = []

        if let x = shown {
            let age = ch.age(x, on: date)
            var subParts: [String] = []
            if let d = ch.death[x.index] {
                subParts.append("Died \(d.year) aged \(age)")
            } else {
                subParts.append("Age \(age)")
            }
            if let dyn = ch.dynasty[x.index], !dyn.hasPrefix("of ") {
                subParts.append(dyn)
            }
            subParts.append(ch.religion[x.index].displayName)

            let skillsArr: [[String: Any]] = Skill.allCases.map { sk in
                [
                    "key": sk.displayName.lowercased(),
                    "name": sk.displayName,
                    "shortName": String(sk.displayName.prefix(3)),
                    "value": ch.skill(x, sk)
                ]
            }
            let traitNames: [String] = ch.traits[x.index].compactMap { tid in
                guard tid.index >= 0 && tid.index < w.people.traits.count else { return nil }
                return w.people.traits.name[tid.index]
            }

            func charLinkList(_ people: [CharacterID]) -> [[String: Any]] {
                people.map { p in
                    let label = ch.isAlive(p)
                        ? "\(ch.name[p.index]) (\(ch.age(p, on: date)))"
                        : "\(ch.name[p.index]) †"
                    return [
                        "characterIndex": p.index,
                        "label": label,
                        "isAlive": ch.isAlive(p)
                    ]
                }
            }

            let isRuler = (x == ruler)
            let heir = w.countries.heir[player.index]
            let heirIndex = heir?.index ?? -1
            let heirLabel = heir.map { "\(ch.fullName($0)) (\(ch.age($0, on: date)))" } ?? "none"
            let successionText = isRuler
                ? "\(w.countries.succession[player.index].displayName) · heir: \(heirLabel)"
                : ""

            let parents = [ch.father[x.index], ch.mother[x.index]].compactMap { $0 }
            let held = VassalSystem.holdings(w, of: x)
            let holdingsText = held.isEmpty
                ? ""
                : "Holds \(held.map { w.provinces.name[$0.index] }.joined(separator: ", ")) · \(Int(ch.gold[x.index])) ducats"

            characterDict = [
                "valid": true,
                "characterIndex": x.index,
                "name": ch.name[x.index],
                "fullName": ch.fullName(x),
                "initial": String(ch.name[x.index].prefix(1)),
                "female": ch.female[x.index],
                "subtitle": subParts.joined(separator: " · "),
                "isAlive": ch.isAlive(x),
                "age": age,
                "invented": ch.invented[x.index],
                "note": ch.note[x.index] ?? "",
                "illegitimate": ch.illegitimate[x.index],
                "skills": skillsArr,
                "traits": traitNames,
                "isRuler": isRuler,
                "successionText": successionText,
                "heirIndex": heirIndex,
                "heirLabel": heirLabel,
                "spouses": charLinkList(ch.spouses[x.index]),
                "children": charLinkList(ch.children[x.index]),
                "siblings": charLinkList(ch.siblings(x)),
                "parents": charLinkList(parents),
                "holdingsText": holdingsText
            ]
        }

        // Ruling family tree summary (parents -> ruler & siblings -> spouses -> children)
        if let r = ruler {
            func treeNode(_ p: CharacterID, role: String) -> [String: Any] {
                let alive = ch.isAlive(p)
                let ageStr = alive ? "\(ch.age(p, on: date))" : "†"
                return [
                    "characterIndex": p.index,
                    "role": role,
                    "fullName": ch.fullName(p),
                    "ageText": ageStr,
                    "isAlive": alive,
                    "isViewed": shown == p
                ]
            }
            if let f = ch.father[r.index] { familyTree.append(treeNode(f, role: "Father")) }
            if let m = ch.mother[r.index] { familyTree.append(treeNode(m, role: "Mother")) }
            familyTree.append(treeNode(r, role: "Ruler"))
            for sp in ch.spouses[r.index] {
                familyTree.append(treeNode(sp, role: "Spouse"))
            }
            for sib in ch.siblings(r) {
                familyTree.append(treeNode(sib, role: "Sibling"))
            }
            let heir = w.countries.heir[player.index]
            for child in ch.children[r.index] {
                let role = (child == heir) ? "Heir (Child)" : "Child"
                familyTree.append(treeNode(child, role: role))
            }
            if let h = heir, !ch.children[r.index].contains(h) && h != r && !ch.siblings(r).contains(h) {
                familyTree.append(treeNode(h, role: "Heir"))
            }
        }

        // Council seats
        let councilSummary = String(
            format: "Tax %+.0f%% · learning %.1f/yr",
            CharacterSystem.taxBonus(w, player) * 100,
            CharacterSystem.learningPerYear(w, player)
        )
        let councilCands = CharacterSystem.councilCandidates(w, player, date: date)
        let councilSeats: [[String: Any]] = CouncilSeat.allCases.map { seat in
            let who = w.countries.council[player.index][seat.rawValue]
            let holderSkill = who.map { ch.skill($0, seat.skill) } ?? 0
            let hasOpinion = (who != nil && ruler != nil)
            let opinion = (who != nil && ruler != nil) ? CharacterSystem.opinion(w, who!, of: ruler!) : 0
            let sortedCands = councilCands
                .sorted { ch.skill($0, seat.skill) > ch.skill($1, seat.skill) }
                .prefix(12)
            let candsArr: [[String: Any]] = sortedCands.map { cand in
                [
                    "characterIndex": cand.index,
                    "label": "\(ch.fullName(cand)) (\(seat.skill.displayName) \(ch.skill(cand, seat.skill)))"
                ]
            }
            return [
                "seatIndex": seat.rawValue,
                "seatName": seat.displayName,
                "skillName": seat.skill.displayName,
                "effectText": seat.effectText,
                "holderIndex": who?.index ?? -1,
                "holderName": who.map { ch.fullName($0) } ?? "Empty",
                "holderSkill": holderSkill,
                "hasOpinion": hasOpinion,
                "opinion": opinion,
                "candidates": candsArr
            ]
        }

        // Great vassals
        let vassalKeepPct = Int((VassalSystem.keepShare(w, player) * 100).rounded())
        let vassalsSummary = "keep \(vassalKeepPct)% of their tax"
        let vassalList = VassalSystem.vassals(w, of: player).map { v -> [String: Any] in
            let op = VassalSystem.opinionOfLiege(w, v, player)
            let stance = VassalSystem.stance(w, v, player)
            let held = VassalSystem.holdings(w, of: v)
            let holdingsArr: [[String: Any]] = held.map { prov in
                [
                    "provinceIndex": prov.index,
                    "provinceName": w.provinces.name[prov.index]
                ]
            }
            let holdingsText = held.map { w.provinces.name[$0.index] }.joined(separator: ", ")
                + String(format: " · %.0f ducats", ch.gold[v.index])
            return [
                "characterIndex": v.index,
                "name": ch.fullName(v),
                "ducats": Int(ch.gold[v.index].rounded()),
                "stance": stance.displayName,
                "isLoyal": stance == .loyal,
                "opinion": op,
                "holdings": holdingsArr,
                "holdingsText": holdingsText
            ]
        }

        // Unheld crown provinces & grant candidates for land granting inside Court
        let unheldProvinces: [[String: Any]] = w.provinces(ownedBy: player)
            .filter { w.provinces.holder[$0.index] == nil }
            .prefix(25)
            .map { prov in
                [
                    "provinceIndex": prov.index,
                    "name": w.provinces.name[prov.index]
                ]
            }
        let grantCands: [[String: Any]] = VassalSystem.grantCandidates(w, player, date: date)
            .sorted { ch.skills[$0.index].reduce(0, +) > ch.skills[$1.index].reduce(0, +) }
            .prefix(12)
            .map { cand in
                [
                    "characterIndex": cand.index,
                    "label": "\(ch.fullName(cand)) (\(ch.age(cand, on: date)))"
                ]
            }

        // Marriages
        let family = CharacterSystem.marriageableFamily(w, player, date: date)
        let familyArr: [[String: Any]] = family.map { x in
            [
                "characterIndex": x.index,
                "label": "\(ch.name[x.index]), \(ch.age(x, on: date))"
            ]
        }
        var selectedMarryingIndex = -1
        var marriageCandidatesArr: [[String: Any]] = []
        if marryingCharacterIndex >= 0 && marryingCharacterIndex < ch.count {
            let candidate = CharacterID(marryingCharacterIndex)
            if family.contains(candidate) {
                selectedMarryingIndex = candidate.index
                let matches = s.marriageCandidates(for: candidate)
                marriageCandidatesArr = matches.map { m in
                    let court = ch.court[m.index]
                    let courtTag = court.map { w.countries.tag[$0.index] } ?? ""
                    let courtName = court.map { w.countries.name[$0.index] } ?? ""
                    let rgb = court.map { w.countries.color[$0.index] } ?? RGB(180, 140, 80)
                    var roleText = ""
                    if let ct = court {
                        if w.countries.ruler[ct.index] == m { roleText = " · ruler" }
                        else if w.countries.heir[ct.index] == m { roleText = " · heir" }
                    }
                    return [
                        "characterIndex": m.index,
                        "fullName": ch.fullName(m),
                        "age": ch.age(m, on: date),
                        "courtTag": courtTag,
                        "courtName": courtName,
                        "colorR": Int(rgb.r),
                        "colorG": Int(rgb.g),
                        "colorB": Int(rgb.b),
                        "roleText": roleText
                    ]
                }
            }
        }

        // Chronicle
        let chronicleEntries: [[String: Any]] = w.people.chronicle
            .filter { $0.country == player }
            .suffix(8)
            .reversed()
            .map { entry in
                let mon = GameDate.monthNames[entry.date.month - 1].prefix(3)
                return [
                    "text": "\(entry.date.day) \(mon) \(entry.date.year): \(entry.text)"
                ]
            }

        return [
            "valid": true,
            "playerTag": w.countries.tag[player.index],
            "playerName": w.countries.name[player.index],
            "playerColorR": Int(playerRGB.r),
            "playerColorG": Int(playerRGB.g),
            "playerColorB": Int(playerRGB.b),
            "rulerIndex": ruler?.index ?? -1,
            "showingRuler": (shown == ruler),
            "character": characterDict,
            "familyTree": familyTree,
            "councilSummary": councilSummary,
            "councilSeats": councilSeats,
            "vassalsSummary": vassalsSummary,
            "vassals": vassalList,
            "unheldProvinces": unheldProvinces,
            "grantCandidates": grantCands,
            "marriageableFamily": familyArr,
            "selectedMarryingIndex": selectedMarryingIndex,
            "marriageCandidates": marriageCandidatesArr,
            "chronicle": chronicleEntries
        ]
    }

    @discardableResult
    public func appointCouncilSeat(seatIndex: Int, characterIndex: Int) -> Bool {
        guard let s = session,
              let seat = CouncilSeat(rawValue: seatIndex) else { return false }
        if characterIndex < 0 {
            s.appoint(seat, nil)
            return true
        }
        guard characterIndex < s.world.people.characters.count else { return false }
        s.appoint(seat, CharacterID(characterIndex))
        return true
    }

    @discardableResult
    public func appointCouncilNewcomer(seatIndex: Int) -> Bool {
        guard let s = session,
              s.playerCountry != nil,
              let seat = CouncilSeat(rawValue: seatIndex) else { return false }
        s.appointNewcomer(seat)
        return true
    }

    @discardableResult
    public func proposeMarriage(familyCharacterIndex: Int, candidateCharacterIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let ch = s.world.people.characters
        guard familyCharacterIndex >= 0, familyCharacterIndex < ch.count,
              candidateCharacterIndex >= 0, candidateCharacterIndex < ch.count else { return false }
        let a = CharacterID(familyCharacterIndex)
        let b = CharacterID(candidateCharacterIndex)
        let family = CharacterSystem.marriageableFamily(s.world, player, date: s.date)
        guard family.contains(a),
              CharacterSystem.marriageRefusal(s.world, a, b, date: s.date) == nil else { return false }
        s.propose(a, b)
        return true
    }

    @discardableResult
    public func grantProvinceToCharacter(provinceIndex: Int, characterIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        guard provinceIndex >= 0, provinceIndex < s.world.provinces.count,
              characterIndex >= 0, characterIndex < s.world.people.characters.count else { return false }
        let prov = ProvinceID(provinceIndex)
        guard s.world.provinces.owner[prov.index] == player else { return false }
        let before = s.world.provinces.holder[prov.index]
        s.grant(prov, to: CharacterID(characterIndex))
        return s.world.provinces.holder[prov.index] != before
    }

    @discardableResult
    public func revokeProvinceHolder(provinceIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        guard provinceIndex >= 0, provinceIndex < s.world.provinces.count else { return false }
        let prov = ProvinceID(provinceIndex)
        guard s.world.provinces.owner[prov.index] == player,
              s.world.provinces.holder[prov.index] != nil else { return false }
        s.revoke(prov)
        return s.world.provinces.holder[prov.index] == nil
    }

    public func governmentDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false]
        }
        let w = s.world
        let g = w.government
        let gov = w.countries.government[player.index]
        let stab = g.stability[player.index]
        let stabCost = GovernmentSystem.stabilityCost(w, player)
        let treasury = w.countries.treasury[player.index]
        let canRaiseStab = stab < GovernmentModel.maxStability && treasury >= stabCost

        let stabHelp = String(
            format: "Each point: tax %+.0f%%, contentment %+.0f, reforms %+.2f a month. Falls when rulers die without an adult heir, laws of succession change, privileges are revoked, estates seize power or you go bankrupt.",
            GovernmentModel.stabilityTax * 100,
            GovernmentModel.stabilityMood * 100,
            GovernmentModel.stabilityReform
        )

        let sortedEstates = g.estates[player.index].sorted {
            g.power[player.index][$0.index] > g.power[player.index][$1.index]
        }
        let estatesArr: [[String: Any]] = sortedEstates.map { e in
            let def = g.rules.estates[e.index]
            let privs: [[String: Any]] = g.rules.privileges(of: e).map { pid in
                let pd = g.rules.privileges[pid]
                let granted = g.privileges[player.index].contains(pid)
                let goldDelta = w.countries.lastMonthlyIncome[player.index] * pd.gold
                let canGrant = !granted && (treasury + goldDelta >= 0)
                return [
                    "privilegeIndex": pid,
                    "name": pd.name,
                    "description": Self.formatPrivilegeText(pd, w, player),
                    "granted": granted,
                    "canGrant": canGrant
                ]
            }
            return [
                "estateIndex": e.index,
                "name": def.name,
                "power": g.power[player.index][e.index],
                "loyalty": g.loyalty[player.index][e.index],
                "loyaltyTarget": GovernmentSystem.loyaltyTarget(w, player, e),
                "contentment": g.contentment[player.index][e.index],
                "loyalText": Self.formatEffectsText(def.loyal, w),
                "disloyalText": Self.formatEffectsText(def.disloyal, w),
                "privileges": privs
            ]
        }

        let lawChangeCost = GovernmentSystem.lawChangeCost(w, player)
        let lawsArr: [[String: Any]] = g.rules.lawAreas.enumerated().map { a, area in
            let currentIdx = g.laws[player.index][a]
            let currentOpt = area.options[currentIdx]
            let pending = g.pending[player.index].first { $0.area == a }
            let pendingText = pending.map { "Changing to \(area.options[$0.option].name) in \($0.monthsLeft) months" } ?? ""
            let optionsArr: [[String: Any]] = area.options.enumerated().compactMap { o, opt in
                guard o != currentIdx && opt.allowed(for: gov) else { return nil }
                let refusal = GovernmentSystem.lawRefusal(w, player, area: a, option: o)?.reason ?? ""
                return [
                    "optionIndex": o,
                    "name": opt.name,
                    "effects": Self.formatEffectsText(opt.effects, w),
                    "refusalReason": refusal
                ]
            }
            return [
                "areaIndex": a,
                "areaName": area.name,
                "currentOptionIndex": currentIdx,
                "currentOptionName": currentOpt.name,
                "currentEffects": Self.formatEffectsText(currentOpt.effects, w),
                "hasPending": pending != nil,
                "pendingText": pendingText,
                "options": optionsArr
            ]
        }

        let tree = g.rules.reforms[gov] ?? []
        let progress = g.reformProgress[player.index]
        let monthlyProgress = GovernmentSystem.monthlyReformProgress(w, player)
        let adoptedArr: [[String: Any]] = g.reforms[player.index].enumerated().compactMap { t, o in
            guard t < tree.count && o >= 0 && o < tree[t].options.count else { return nil }
            let r = tree[t].options[o]
            return [
                "tier": t + 1,
                "name": r.name,
                "effects": Self.formatEffectsText(r.effects, w)
            ]
        }
        let next = GovernmentSystem.nextTier(w, player)
        let nextOptionsArr: [[String: Any]] = (next?.tier.options ?? []).enumerated().map { o, r in
            var fx = Self.formatEffectsText(r.effects, w)
            if let becomes = r.becomes {
                fx += "; becomes a \(becomes.displayName.lowercased())"
            }
            return [
                "optionIndex": o,
                "name": r.name,
                "effects": fx,
                "canAdopt": progress >= (next?.tier.cost ?? 0)
            ]
        }

        return [
            "valid": true,
            "governmentName": gov.displayName,
            "stability": stab,
            "maxStability": GovernmentModel.maxStability,
            "stabilityCost": stabCost,
            "canRaiseStability": canRaiseStab,
            "stabilityHelpText": stabHelp,
            "crownPower": g.crownPower[player.index],
            "loyalAt": GovernmentModel.loyalAt,
            "disloyalBelow": GovernmentModel.disloyalBelow,
            "estates": estatesArr,
            "lawChangeCost": lawChangeCost,
            "lawChangeMonths": GovernmentModel.lawChangeMonths,
            "laws": lawsArr,
            "reformProgress": progress,
            "monthlyReformProgress": monthlyProgress,
            "adoptedReforms": adoptedArr,
            "hasNextReformTier": next != nil,
            "nextReformTierIndex": (next?.index ?? 0) + 1,
            "nextReformCost": next?.tier.cost ?? 0.0,
            "nextReformOptions": nextOptionsArr
        ]
    }

    @discardableResult
    public func raiseStability() -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let before = s.world.government.stability[player.index]
        s.raiseStability()
        return s.world.government.stability[player.index] > before
    }

    public func changeLaw(areaIndex: Int, optionIndex: Int) -> [String: Any] {
        guard let s = session, s.playerCountry != nil else {
            return ["ok": false, "reason": "No active player country"]
        }
        let areas = s.world.government.rules.lawAreas
        guard areaIndex >= 0, areaIndex < areas.count,
              optionIndex >= 0, optionIndex < areas[areaIndex].options.count else {
            return ["ok": false, "reason": "Invalid law area or option"]
        }
        if let refusal = s.changeLaw(area: areaIndex, option: optionIndex) {
            return ["ok": false, "reason": refusal.reason]
        }
        return ["ok": true, "reason": ""]
    }

    @discardableResult
    public func grantPrivilege(privilegeIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let privs = s.world.government.rules.privileges
        guard privilegeIndex >= 0, privilegeIndex < privs.count else { return false }
        let had = s.world.government.privileges[player.index].contains(privilegeIndex)
        if had { return false }
        s.grantPrivilege(privilegeIndex)
        return s.world.government.privileges[player.index].contains(privilegeIndex)
    }

    @discardableResult
    public func revokePrivilege(privilegeIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        let privs = s.world.government.rules.privileges
        guard privilegeIndex >= 0, privilegeIndex < privs.count else { return false }
        let had = s.world.government.privileges[player.index].contains(privilegeIndex)
        if !had { return false }
        s.revokePrivilege(privilegeIndex)
        return !s.world.government.privileges[player.index].contains(privilegeIndex)
    }

    @discardableResult
    public func adoptReform(optionIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry else { return false }
        guard let next = GovernmentSystem.nextTier(s.world, player),
              optionIndex >= 0, optionIndex < next.tier.options.count,
              s.world.government.reformProgress[player.index] >= next.tier.cost else { return false }
        let beforeCount = s.world.government.reforms[player.index].count
        s.adoptReform(optionIndex)
        return s.world.government.reforms[player.index].count > beforeCount
    }

    // MARK: - Phase 11: Religion, Holy Sites, Movements & Culture

    public func religionWindowDetails() -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasPlayer": false]
        }
        let w = s.world
        let c = w.countries
        let g = w.government
        let stateRel = c.religion[player.index]
        let relRGB = stateRel.color
        let prestige = c.prestige[player.index]
        let faithKey = FaithSystem.faithLawKey(w, player)
        let faithLawTitle: String
        if let area = g.rules.lawAreas.first(where: { $0.key == "faith" }),
           let opt = area.options.first(where: { $0.key == faithKey }) {
            faithLawTitle = opt.name
        } else {
            faithLawTitle = faithKey.capitalized
        }
        let clergyLoyalty = FaithSystem.clergyLoyalty(w, player)

        let activeMiss = FaithSystem.activeMissionaries(w, for: player)
        let maxMiss = FaithSystem.maxMissionaries(w, player)
        let activeMissProvinceIDs = Set(activeMiss.map(\.province))

        let activeMissionariesList: [[String: Any]] = activeMiss.map { m in
            let pi = m.province.index
            let provName = pi < w.provinces.count ? w.provinces.name[pi] : "Province #\(pi)"
            let b = w.breakdown(of: m.province)
            let topWrong = b.byReligion.filter { $0.key != stateRel && $0.value > 0.01 }.max(by: { $0.value < $1.value })
            let rate = topWrong.map {
                FaithSystem.monthlyConversionRate(world: w, province: m.province, from: $0.key, hasMissionary: true)
            } ?? 0.0
            let rateText = rate > 0 ? String(format: "+%.2f%%/mo", rate * 100.0) : "Blocked"
            let majRel = b.religionShares().first?.0.displayName ?? stateRel.displayName
            return [
                "provinceIndex": pi,
                "provinceName": provName,
                "majorityReligion": majRel,
                "conversionText": Self.formatPercent(b.total > 0 ? ((b.byReligion[stateRel] ?? 0) / b.total) : w.provinces.conversionProgress[pi]),
                "rateText": rateText,
                "unrestText": String(format: "%.1f", w.provinces.religiousUnrest[pi])
            ]
        }

        // Owned provinces where non-state pops exist, prioritized by wrong-faith pop count.
        struct ProvRow {
            let index: Int
            let wrongPop: Double
            let dict: [String: Any]
        }
        var provRows: [ProvRow] = []
        for pi in 0..<w.provinces.count where w.provinces.owner[pi] == player {
            let pid = ProvinceID(pi)
            let b = w.breakdown(of: pid)
            let statePop = b.byReligion[stateRel] ?? 0
            let wrongPop = max(0.0, b.total - statePop)
            let convProg = b.total > 0 ? (statePop / b.total) : w.provinces.conversionProgress[pi]
            guard wrongPop >= 10.0 || activeMissProvinceIDs.contains(pid) else { continue }
            let hasMiss = activeMissProvinceIDs.contains(pid)
            let refusal = FaithSystem.missionaryRefusal(w, by: player, in: pid)
            let topWrong = b.byReligion.filter { $0.key != stateRel && $0.value > 0.01 }.max(by: { $0.value < $1.value })
            let rate = topWrong.map {
                FaithSystem.monthlyConversionRate(world: w, province: pid, from: $0.key, hasMissionary: hasMiss)
            } ?? 0.0
            let rateText: String
            if rate > 0 {
                rateText = String(format: "+%.2f%%/mo", rate * 100.0)
            } else if case .blockedByPrivilege(let why)? = refusal {
                rateText = "Blocked (\(why))"
            } else {
                rateText = "Blocked"
            }
            let majRel = b.religionShares().first?.0.displayName ?? stateRel.displayName
            provRows.append(ProvRow(
                index: pi,
                wrongPop: wrongPop,
                dict: [
                    "provinceIndex": pi,
                    "provinceName": w.provinces.name[pi],
                    "majorityReligion": majRel,
                    "wrongPopText": Self.formatPeople(wrongPop),
                    "conversionText": Self.formatPercent(convProg),
                    "rateText": rateText,
                    "unrestText": String(format: "%.1f", w.provinces.religiousUnrest[pi]),
                    "hasMissionary": hasMiss,
                    "canSend": refusal == nil,
                    "refusal": refusal?.reason ?? ""
                ]
            ))
        }
        provRows.sort {
            let aMiss = ($0.dict["hasMissionary"] as? Bool) ?? false
            let bMiss = ($1.dict["hasMissionary"] as? Bool) ?? false
            if aMiss != bMiss { return aMiss && !bMiss }
            if $0.wrongPop != $1.wrongPop { return $0.wrongPop > $1.wrongPop }
            return $0.index < $1.index
        }
        let convertibleProvinces = Array(provRows.prefix(60).map(\.dict))

        // Holy sites held & overview
        let heldSites = FaithSystem.holySitesHeld(in: w, by: player)
        let heldList: [[String: Any]] = heldSites.map { site in
            [
                "name": site.name,
                "provinceIndex": site.province.index,
                "provinceName": w.provinces.name[site.province.index],
                "religions": site.religions.map(\.displayName).joined(separator: ", ")
            ]
        }
        let heldSet = Set(heldSites.map(\.province))
        var allSitesList: [[String: Any]] = w.faith.holySites.map { site in
            let pi = site.province.index
            let owner = pi < w.provinces.count ? w.provinces.owner[pi] : nil
            let ownerTag = owner.map { c.tag[$0.index] } ?? "—"
            let ownerName = owner.map { c.name[$0.index] } ?? "Unclaimed"
            let sacredToPlayer = site.isSacred(to: stateRel)
            let isHeld = heldSet.contains(site.province) && owner == player && sacredToPlayer
            return [
                "name": site.name,
                "provinceIndex": pi,
                "provinceName": pi < w.provinces.count ? w.provinces.name[pi] : "",
                "ownerTag": ownerTag,
                "ownerName": ownerName,
                "religions": site.religions.map(\.displayName).joined(separator: ", "),
                "isSacredToPlayer": sacredToPlayer,
                "isHeldByPlayer": isHeld
            ]
        }
        allSitesList.sort {
            let aHeld = ($0["isHeldByPlayer"] as? Bool) ?? false
            let bHeld = ($1["isHeldByPlayer"] as? Bool) ?? false
            if aHeld != bHeld { return aHeld && !bHeld }
            let aSac = ($0["isSacredToPlayer"] as? Bool) ?? false
            let bSac = ($1["isSacredToPlayer"] as? Bool) ?? false
            if aSac != bSac { return aSac && !bSac }
            return (($0["name"] as? String) ?? "") < (($1["name"] as? String) ?? "")
        }

        let loyaltyBonus = min(
            FaithModel.maxHolySiteClergyLoyalty,
            Double(heldSites.count) * FaithModel.holySiteClergyLoyalty
        )
        let stabDiscount = min(
            FaithModel.maxHolySiteStabilityDiscount,
            Double(heldSites.count) * FaithModel.holySiteStabilityDiscount
        )

        // Historical Movements
        let isBohemia = (c.tag[player.index] == "BOH")
        let canProtestant = w.faith.reformationStarted && (stateRel == .catholic && w.faith.reformationReligions.contains(.protestant))
        let canReformed = w.faith.reformationStarted && ((stateRel == .catholic || stateRel == .protestant) && w.faith.reformationReligions.contains(.reformed))
        let refCentresList: [[String: Any]] = w.faith.reformationCentres.map { rc in
            let pi = rc.province.index
            let ownerTag = (pi < w.provinces.count ? w.provinces.owner[pi].map { c.tag[$0.index] } : nil) ?? "—"
            return [
                "provinceIndex": pi,
                "provinceName": pi < w.provinces.count ? w.provinces.name[pi] : "Province #\(pi)",
                "ownerTag": ownerTag,
                "religion": rc.religion.displayName,
                "religionKey": rc.religion.rawValue,
                "foundedYear": rc.foundedYear,
                "monthsActive": rc.monthsActive
            ]
        }

        // Culture section
        let rank = CultureSystem.governmentRank(w, player)
        let primaryCid = c.primaryCulture[player.index]
        let primaryFamily = primaryCid.index < w.cultures.count ? w.cultures.family[primaryCid.index] : ""
        let acceptedSet = c.acceptedCultures[player.index]
        let slotsMax = CultureSystem.acceptedCultureSlots(w, player)

        var realmPopByCulture: [Int: Double] = [:]
        var totalRealmPop = 0.0
        for pi in 0..<w.provinces.count where w.provinces.owner[pi] == player {
            for k in w.pops.range(for: ProvinceID(pi)) {
                let sz = w.pops.size[k]
                let cidIdx = w.pops.culture[k].index
                realmPopByCulture[cidIdx, default: 0] += sz
                totalRealmPop += sz
            }
        }
        realmPopByCulture[primaryCid.index, default: 0] += 0
        for ac in acceptedSet {
            realmPopByCulture[ac.index, default: 0] += 0
        }

        var cultureRows: [(isPrimary: Bool, isAccepted: Bool, pop: Double, cidIdx: Int, dict: [String: Any])] = []
        for (cidIdx, pop) in realmPopByCulture where cidIdx >= 0 && cidIdx < w.cultures.count {
            let cid = CultureID(cidIdx)
            let isPrimary = (cid == primaryCid)
            let isAccepted = acceptedSet.contains(cid)
            let fam = w.cultures.family[cidIdx]
            let sameFamily = (fam == primaryFamily)
            let taxMult: Double
            let mpMult: Double
            let moodDelta: Double
            if isPrimary || isAccepted {
                taxMult = CultureModel.taxAccepted
                mpMult = CultureModel.manpowerAccepted
                moodDelta = CultureModel.moodAccepted
            } else if sameFamily {
                taxMult = CultureModel.taxSameFamily
                mpMult = CultureModel.manpowerSameFamily
                moodDelta = CultureModel.moodSameFamily
            } else {
                taxMult = CultureModel.taxForeign
                mpMult = CultureModel.manpowerForeign
                moodDelta = CultureModel.moodForeign
            }
            let refusal = CultureSystem.acceptRefusal(w, country: player, culture: cid)
            let share = totalRealmPop > 0 ? pop / totalRealmPop : 0
            cultureRows.append((
                isPrimary: isPrimary,
                isAccepted: isAccepted,
                pop: pop,
                cidIdx: cidIdx,
                dict: [
                    "cultureIndex": cidIdx,
                    "name": w.cultures.name[cidIdx],
                    "family": fam.replacingOccurrences(of: "_", with: " ").capitalized,
                    "populationText": Self.formatPeople(pop),
                    "shareText": Self.formatPercent(share),
                    "isPrimary": isPrimary,
                    "isAccepted": isAccepted,
                    "sameFamily": sameFamily,
                    "taxText": "\(Int((taxMult * 100).rounded()))%",
                    "manpowerText": "\(Int((mpMult * 100).rounded()))%",
                    "moodText": moodDelta == 0 ? "+0%" : String(format: "%+.0f%%", moodDelta * 100.0),
                    "canAccept": refusal == nil,
                    "acceptRefusal": refusal?.reason ?? ""
                ]
            ))
        }
        cultureRows.sort {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            if $0.isAccepted != $1.isAccepted { return $0.isAccepted }
            if $0.pop != $1.pop { return $0.pop > $1.pop }
            return $0.cidIdx < $1.cidIdx
        }

        return [
            "hasPlayer": true,
            "playerTag": c.tag[player.index],
            "playerName": c.name[player.index],
            "stateReligion": stateRel.displayName,
            "stateReligionKey": stateRel.rawValue,
            "stateReligionFamily": stateRel.family.displayName,
            "stateReligionColorR": Int(relRGB.r),
            "stateReligionColorG": Int(relRGB.g),
            "stateReligionColorB": Int(relRGB.b),
            "prestige": prestige,
            "prestigeText": String(format: "%+.1f", prestige),
            "faithLawName": faithLawTitle,
            "clergyLoyaltyText": "\(Int(clergyLoyalty.rounded()))%",
            "missionaryMonthlyCost": FaithModel.missionaryMonthlyCost,
            "missionariesUsed": activeMiss.count,
            "missionariesMax": maxMiss,
            "activeMissionaries": activeMissionariesList,
            "convertibleProvinces": convertibleProvinces,
            "heldHolySites": heldList,
            "allHolySites": allSitesList,
            "holySitePrestigeYearText": String(format: "%+.1f/yr", Double(heldSites.count) * FaithModel.holySiteMonthlyPrestige * 12.0),
            "holySiteClergyBonusText": String(format: "+%.0f%%", loyaltyBonus),
            "holySiteStabilityDiscountText": String(format: "-%.0f%%", stabDiscount * 100.0),
            "isBohemia": isBohemia,
            "hussiteOutcome": w.faith.hussiteOutcome.rawValue,
            "hussiteOutcomeName": w.faith.hussiteOutcome.displayName,
            "hussiteCompactsActive": w.faith.hussiteCompactsActive,
            "safaviyyaPhase": w.faith.safaviyyaPhase.displayName,
            "safaviyyaStrengthText": Self.formatPercent(w.faith.safaviyyaStrength),
            "safaviyyaYear": w.faith.safaviyyaYear ?? 0,
            "reformationStarted": w.faith.reformationStarted,
            "reformationCentres": refCentresList,
            "canAdoptProtestant": canProtestant,
            "canAdoptReformed": canReformed,
            "governmentRank": rank.displayName,
            "primaryCultureIndex": primaryCid.index,
            "primaryCultureName": primaryCid.index < w.cultures.count ? w.cultures.name[primaryCid.index] : "",
            "primaryCultureFamily": primaryFamily.replacingOccurrences(of: "_", with: " ").capitalized,
            "acceptedSlotsUsed": acceptedSet.count,
            "acceptedSlotsMax": slotsMax,
            "cultures": cultureRows.map(\.dict)
        ]
    }

    public func sendMissionary(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return ["ok": false, "reason": "Invalid province."]
        }
        if let refusal = s.sendMissionary(to: ProvinceID(provinceIndex)) {
            return ["ok": false, "reason": refusal.reason]
        }
        return ["ok": true, "reason": ""]
    }

    @discardableResult
    public func recallMissionary(provinceIndex: Int) -> Bool {
        guard let s = session,
              provinceIndex >= 0, provinceIndex < s.world.provinces.count else {
            return false
        }
        return s.recallMissionary(from: ProvinceID(provinceIndex))
    }

    @discardableResult
    public func resolveHussiteQuestion(choiceKey: String) -> Bool {
        guard let s = session,
              let choice = HussiteOutcome(rawValue: choiceKey.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return s.resolveHussiteQuestion(choice)
    }

    @discardableResult
    public func adoptReformationReligion(religionKey: String) -> Bool {
        guard let s = session,
              let rel = Religion(rawValue: religionKey.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return s.adoptReformationReligion(rel)
    }

    public func acceptCulture(cultureIndex: Int) -> [String: Any] {
        guard let s = session,
              cultureIndex >= 0, cultureIndex < s.world.cultures.count else {
            return ["ok": false, "reason": "Invalid culture."]
        }
        if let err = s.acceptCulture(CultureID(cultureIndex)) {
            return ["ok": false, "reason": err.reason]
        }
        return ["ok": true, "reason": ""]
    }

    @discardableResult
    public func revokeCulture(cultureIndex: Int) -> Bool {
        guard let s = session,
              cultureIndex >= 0, cultureIndex < s.world.cultures.count else {
            return false
        }
        return s.revokeCulture(CultureID(cultureIndex))
    }

    @discardableResult
    public func advanceSimulationDays(_ days: Int) -> Bool {
        guard let s = session, days > 0 else { return false }
        let prevInteractive = s.interactiveBattlesEnabled
        s.interactiveBattlesEnabled = false
        s.advanceDays(days)
        s.interactiveBattlesEnabled = prevInteractive
        s.rebuildLabels()
        townIconsRevision &+= 1
        return true
    }

    public func faithOverlayData() -> [String: Any] {
        guard let s = session else {
            return ["holySites": [], "missionaries": [], "centres": [], "migrations": []]
        }
        let w = s.world
        let player = s.playerCountry
        let playerRel = player.map { w.countries.religion[$0.index] }

        let holySites: [[String: Any]] = w.faith.holySites.compactMap { site in
            let pi = site.province.index
            guard pi < s.provincePositions.count, pi < w.provinces.count else { return nil }
            let pos = s.provincePositions[pi]
            let owner = w.provinces.owner[pi]
            let isSacred = playerRel.map { site.isSacred(to: $0) } ?? false
            let isHeld = isSacred && owner != nil && owner == player && w.provinces.occupiedBy[pi] == nil
            return [
                "provinceIndex": pi,
                "name": site.name,
                "x": pos.x,
                "y": pos.y,
                "isSacredToPlayer": isSacred,
                "isHeldByPlayer": isHeld
            ]
        }

        let missionaries: [[String: Any]] = w.faith.missionaries.compactMap { m in
            let pi = m.province.index
            guard pi < s.provincePositions.count else { return nil }
            let pos = s.provincePositions[pi]
            return [
                "provinceIndex": pi,
                "x": pos.x,
                "y": pos.y,
                "isPlayer": m.country == player
            ]
        }

        let centres: [[String: Any]] = w.faith.reformationCentres.compactMap { rc in
            let pi = rc.province.index
            guard pi < s.provincePositions.count else { return nil }
            let pos = s.provincePositions[pi]
            let rgb = rc.religion.color
            return [
                "provinceIndex": pi,
                "x": pos.x,
                "y": pos.y,
                "religion": rc.religion.displayName,
                "religionKey": rc.religion.rawValue,
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ]
        }

        var migEntries: [(absNet: Double, pi: Int, net: Double)] = []
        for pi in 0..<min(w.provinces.count, s.provincePositions.count) {
            let net = w.provinces.lastNetMigration[pi]
            if abs(net) >= 50.0 {
                migEntries.append((abs(net), pi, net))
            }
        }
        migEntries.sort {
            if $0.absNet != $1.absNet { return $0.absNet > $1.absNet }
            return $0.pi < $1.pi
        }
        let migrations: [[String: Any]] = migEntries.prefix(60).map { entry in
            let pos = s.provincePositions[entry.pi]
            let rounded = Int(entry.net.rounded())
            return [
                "provinceIndex": entry.pi,
                "x": pos.x,
                "y": pos.y,
                "netMigration": entry.net,
                "text": (rounded >= 0 ? "+" : "") + "\(rounded)"
            ]
        }

        return [
            "holySites": holySites,
            "missionaries": missionaries,
            "centres": centres,
            "migrations": migrations
        ]
    }

    private static func formatEffectsText(_ fx: Effects, _ w: World) -> String {
        var parts: [String] = []
        for m in Modifier.allCases where fx[m] != 0 {
            let v = fx[m]
            if m == .noDebase {
                parts.append(m.displayName)
            } else if m.isMood {
                parts.append(String(format: "%@ %+.0f", m.displayName, v * 100))
            } else if m == .vassalOpinion {
                parts.append(String(format: "%@ %+.0f", m.displayName, v))
            } else if m.isPoints {
                parts.append(String(format: "%@ %+.1f", m.displayName, v))
            } else if m == .inflationDecay {
                parts.append(String(format: "%@ %+.1f%%", m.displayName, v * 100))
            } else {
                parts.append(String(format: "%@ %+.0f%%", m.displayName, v * 100))
            }
        }
        let estates = w.government.rules.estates
        for (i, v) in fx.loyalty.enumerated() where v != 0 && i < estates.count {
            parts.append(String(format: "%@ loyalty %+.0f", estates[i].name, v))
        }
        for (i, v) in fx.power.enumerated() where v != 0 && i < estates.count {
            parts.append(String(format: "%@ power %+.0f%%", estates[i].name, v * 100))
        }
        return parts.isEmpty ? "nothing else" : parts.joined(separator: ", ")
    }

    private static func formatPrivilegeText(_ p: PrivilegeDef, _ w: World, _ c: CountryID) -> String {
        var parts = [String(format: "loyalty %+.0f, power %+.0f%%", p.loyalty, p.power * 100)]
        let fx = formatEffectsText(p.effects, w)
        if fx != "nothing else" { parts.append(fx) }
        if p.gold != 0 {
            let ducats = w.countries.lastMonthlyIncome[c.index] * p.gold
            parts.append(String(format: "%@ %.0f ducats once", ducats > 0 ? "gain" : "costs", abs(ducats)))
        }
        return parts.joined(separator: "; ")
    }

    // MARK: - Step 3d2: Diplomacy, Wars, Peace & Alerts

    public private(set) var selectedDiplomacyCountryIndex: Int = -1

    public func provinceFocusPoint(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0 && provinceIndex < s.provincePositions.count else {
            return ["hasCenter": false]
        }
        let pos = s.provincePositions[provinceIndex]
        return [
            "hasCenter": true,
            "x": pos.x,
            "y": pos.y
        ]
    }

    public func activeAlertsSignature() -> String {
        guard let s = session else { return "" }
        return s.activeAlerts().map { "\($0.id):\($0.label)" }.joined(separator: ";")
    }

    public func activeAlerts() -> [[String: Any]] {
        guard let s = session else { return [] }
        return s.activeAlerts().map { info in
            [
                "id": info.id,
                "kind": info.kind.rawValue,
                "label": info.label,
                "provinceIndex": info.province?.index ?? -1,
                "seaZoneIndex": info.seaZone?.index ?? -1,
                "warID": info.warID ?? ""
            ]
        }
    }

    @discardableResult
    public func setSelectedDiplomacyCountry(_ countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else {
            return false
        }
        selectedDiplomacyCountryIndex = countryIndex
        return true
    }

    public func diplomacyDetails(targetCountryIndex: Int = -1, searchQuery: String = "", breakTruce: Bool = false) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasPlayer": false]
        }
        let w = s.world
        let d = w.diplomacy
        let usedSlots = d.usedRelationSlots(for: player, world: w)
        let capSlots = d.relationSlots(for: player, world: w)
        let coalitionSet = d.coalitions[player] ?? []

        let allSovereigns = w.countries.ids
            .filter { $0 != player && !w.provinces(ownedBy: $0).isEmpty }
            .sorted { a, b in
                let warA = d.isAtWar(player, a) ? 0 : 1
                let warB = d.isAtWar(player, b) ? 0 : 1
                if warA != warB { return warA < warB }
                let allyA = d.areAllies(player, a) ? 0 : 1
                let allyB = d.areAllies(player, b) ? 0 : 1
                if allyA != allyB { return allyA < allyB }
                return w.countries.name[a.index] < w.countries.name[b.index]
            }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredSovereigns = allSovereigns.filter { cid in
            trimmedQuery.isEmpty
                || w.countries.name[cid.index].lowercased().contains(trimmedQuery)
                || w.countries.tag[cid.index].lowercased().contains(trimmedQuery)
        }

        let countryRows: [[String: Any]] = filteredSovereigns.map { cid in
            let rgb = Self.countryRGB(w, cid)
            let isAtWar = d.isAtWar(player, cid)
            let isAlly = d.areAllies(player, cid)
            let prefix = isAtWar ? "[WAR] " : (isAlly ? "[ALLY] " : "")
            return [
                "index": cid.index,
                "name": w.countries.name[cid.index],
                "tag": w.countries.tag[cid.index],
                "displayName": "\(prefix)\(w.countries.name[cid.index]) (\(w.countries.tag[cid.index]))",
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b),
                "isAtWar": isAtWar,
                "isAlly": isAlly,
                "inCoalition": coalitionSet.contains(cid),
                "opinion": d.opinion(of: player, by: cid)
            ]
        }

        var resolvedTarget: CountryID? = nil
        if targetCountryIndex >= 0 && targetCountryIndex < w.countries.count && targetCountryIndex != player.index {
            resolvedTarget = CountryID(targetCountryIndex)
            selectedDiplomacyCountryIndex = targetCountryIndex
        } else if selectedDiplomacyCountryIndex >= 0 && selectedDiplomacyCountryIndex < w.countries.count && selectedDiplomacyCountryIndex != player.index {
            resolvedTarget = CountryID(selectedDiplomacyCountryIndex)
        } else if let first = filteredSovereigns.first ?? allSovereigns.first {
            resolvedTarget = first
            selectedDiplomacyCountryIndex = first.index
        } else {
            selectedDiplomacyCountryIndex = -1
        }

        var targetInfo: [String: Any] = ["hasTarget": false]
        if let target = resolvedTarget {
            let ti = target.index
            let rgb = Self.countryRGB(w, target)
            let opinion = d.opinion(of: player, by: target)
            let trust = d.trust(of: player, by: target)
            let ae = Int(d.aggressiveExpansion(of: player, by: target).rounded())
            let atWar = d.isAtWar(player, target)
            let activeWar = d.activeWar(between: player, and: target)
            let inCoalition = coalitionSet.contains(target)

            let treaties: [[String: Any]] = d.treaties.filter { $0.involves(player, target) }.map { tr in
                [
                    "type": tr.type.rawValue,
                    "label": Self.treatyLabel(tr, player: player),
                    "expiry": tr.expiry?.description ?? ""
                ]
            }

            let cbs = d.availableCasusBelli(attacker: player, defender: target, in: w).enumerated().map { idx, cb in
                let costNote: String = (cb.type == .noCB) ? "Costs: -2 Stability, +20 AE" : "No stability penalty"
                return [
                    "index": idx,
                    "type": cb.type.rawValue,
                    "name": cb.name,
                    "description": cb.description,
                    "costNote": costNote,
                    "warGoalLabel": Self.warGoalLabel(cb.warGoal, world: w),
                    "targetProvinceIndex": cb.targetProvince?.index ?? -1
                ] as [String: Any]
            }

            let validation = d.canDeclareWar(attacker: player, defender: target, breakTruce: breakTruce, world: w)
            let validationStatus: String
            let validationMessage: String
            switch validation {
            case .valid:
                validationStatus = "valid"
                validationMessage = ""
            case .requiresTruceBreak(let until):
                validationStatus = "requiresTruceBreak"
                validationMessage = "Break active truce (expires \(until.description)): -5 Stability, +50 AE, -30 Trust"
            case .invalid(let reason):
                validationStatus = "invalid"
                validationMessage = reason
            }

            targetInfo = [
                "hasTarget": true,
                "index": ti,
                "name": w.countries.name[ti],
                "tag": w.countries.tag[ti],
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b),
                "government": w.countries.government[ti].displayName,
                "religion": w.countries.religion[ti].rawValue.capitalized,
                "aiGoalText": s.aiGoalSummary(for: target),
                "aiSetting": w.ai.setting.displayName,
                "opinion": opinion,
                "trust": trust,
                "ae": ae,
                "atWar": atWar,
                "warID": activeWar?.id ?? "",
                "inCoalition": inCoalition,
                "treaties": treaties,
                "isAllied": d.areAllies(player, target),
                "isGuaranteed": d.hasTreaty(.guarantee, between: player, and: target),
                "hasNonAggression": d.hasTreaty(.nonAggression, between: player, and: target),
                "hasMilitaryAccess": d.hasTreaty(.militaryAccess, between: player, and: target),
                "isEmbargoed": w.countries.embargoes[player.index].contains(target),
                "canImproveRelations": opinion < 100,
                "casusBelli": cbs,
                "warValidationStatus": validationStatus,
                "warValidationMessage": validationMessage
            ]
        }

        let coalitionNames = coalitionSet.sorted { $0.index < $1.index }.map { w.countries.name[$0.index] }

        return [
            "hasPlayer": true,
            "usedRelationSlots": usedSlots,
            "relationSlotsCap": capSlots,
            "overSlotLimit": usedSlots > capSlots,
            "coalitionCount": coalitionSet.count,
            "coalitionSummary": coalitionNames.joined(separator: ", "),
            "countries": countryRows,
            "selectedTargetIndex": resolvedTarget?.index ?? -1,
            "target": targetInfo
        ]
    }

    @discardableResult
    public func toggleAlliance(countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else { return false }
        s.toggleAlliance(with: CountryID(countryIndex))
        return true
    }

    @discardableResult
    public func toggleGuarantee(countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else { return false }
        s.toggleGuarantee(with: CountryID(countryIndex))
        return true
    }

    @discardableResult
    public func toggleNonAggression(countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else { return false }
        s.toggleNonAggression(with: CountryID(countryIndex))
        return true
    }

    @discardableResult
    public func toggleMilitaryAccess(countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else { return false }
        s.toggleMilitaryAccess(with: CountryID(countryIndex))
        return true
    }

    @discardableResult
    public func improveRelations(countryIndex: Int) -> Bool {
        guard let s = session, let player = s.playerCountry,
              countryIndex >= 0 && countryIndex < s.world.countries.count,
              countryIndex != player.index else { return false }
        let before = s.world.diplomacy.opinion(of: player, by: CountryID(countryIndex))
        s.improveRelations(with: CountryID(countryIndex))
        let after = s.world.diplomacy.opinion(of: player, by: CountryID(countryIndex))
        return after > before
    }

    @discardableResult
    public func declareWar(targetCountryIndex: Int, cbIndex: Int, breakTruce: Bool = false) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["ok": false, "error": "No active game.", "warID": ""]
        }
        let w = s.world
        guard targetCountryIndex >= 0 && targetCountryIndex < w.countries.count,
              targetCountryIndex != player.index else {
            return ["ok": false, "error": "Invalid target country.", "warID": ""]
        }
        let target = CountryID(targetCountryIndex)
        let cbs = w.diplomacy.availableCasusBelli(attacker: player, defender: target, in: w)
        guard cbIndex >= 0 && cbIndex < cbs.count else {
            return ["ok": false, "error": "Invalid Casus Belli.", "warID": ""]
        }
        let res = s.declareWar(on: target, cb: cbs[cbIndex], breakTruce: breakTruce)
        switch res {
        case .success(let war):
            return ["ok": true, "error": "", "warID": war.id]
        case .failure(let err):
            return ["ok": false, "error": err.description, "warID": ""]
        }
    }

    public func warsDetails(includeAIWars: Bool = false) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["hasPlayer": false, "pendingOffers": [[String: Any]](), "wars": [[String: Any]]()]
        }
        let w = s.world
        let d = w.diplomacy

        let pendingOffers: [[String: Any]] = d.pendingPeaceOffers
            .filter { $0.loser == player }
            .map { offer in
                let rgb = Self.countryRGB(w, offer.winner)
                return [
                    "warID": offer.warID,
                    "senderIndex": offer.winner.index,
                    "senderName": w.countries.name[offer.winner.index],
                    "senderTag": w.countries.tag[offer.winner.index],
                    "senderColorR": Int(rgb.r),
                    "senderColorG": Int(rgb.g),
                    "senderColorB": Int(rgb.b),
                    "isWhitePeace": offer.demands.isEmpty,
                    "demandLabels": offer.demands.map { Self.describeDemand($0, world: w) }
                ]
            }

        let wars = includeAIWars ? d.wars : d.activeWars(for: player)
        let warRows: [[String: Any]] = wars.map { war in
            let wsPct = Int((war.warScore * 100.0).rounded())
            let battlePct = Int((war.battleWarScore * 100.0).rounded())
            let blockadePct = Int((war.blockadeWarScore * 100.0).rounded())
            let tickingPct = Int((war.tickingWarScore * 100.0).rounded())
            let occPct = wsPct - battlePct - blockadePct - tickingPct

            let recentNavalBattles: [[String: Any]] = w.navy.recentBattles
                .filter { b in war.areEnemies(b.attackerCountry, b.defenderCountry) }
                .suffix(6)
                .reversed()
                .map { b in
                    [
                        "seaZoneIndex": b.seaZone.index,
                        "seaZoneName": b.seaZoneName,
                        "date": b.date.description,
                        "days": b.days,
                        "attackerTag": w.countries.tag[b.attackerCountry.index],
                        "defenderTag": w.countries.tag[b.defenderCountry.index],
                        "winnerTag": w.countries.tag[b.winnerCountry.index],
                        "attackerShipsLost": b.attackerShipsLost,
                        "defenderShipsLost": b.defenderShipsLost,
                        "shipsCaptured": b.attackerShipsCaptured + b.defenderShipsCaptured,
                        "warScoreDeltaPct": Int((b.warScoreDelta * 100.0).rounded())
                    ]
                }

            let attackersList: [[String: Any]] = war.attackers.map { Self.countryPill($0, world: w) }
            let defendersList: [[String: Any]] = war.defenders.map { Self.countryPill($0, world: w) }

            var occupiedList: [[String: Any]] = []
            for pIdx in 0..<w.provinces.count {
                guard let owner = w.provinces.owner[pIdx],
                      let occ = w.provinces.occupiedBy[pIdx],
                      war.areEnemies(owner, occ) else { continue }
                occupiedList.append([
                    "provinceIndex": pIdx,
                    "provinceName": w.provinces.name[pIdx],
                    "ownerTag": w.countries.tag[owner.index],
                    "occupierTag": w.countries.tag[occ.index],
                    "byAttacker": war.isAttacker(occ)
                ])
            }

            let isParticipant = war.isParticipant(player)
            let isAttacker = war.isAttacker(player)
            let enemyLeader = isAttacker ? war.primaryDefender : war.primaryAttacker
            var uncalledAllies: [[String: Any]] = []
            if isParticipant {
                for cid in w.countries.ids where cid != player && !war.isParticipant(cid) && d.areAllies(player, cid) {
                    let eval = d.evaluateCallToArms(
                        ally: cid,
                        caller: player,
                        enemy: enemyLeader,
                        isDefensive: war.isDefender(player),
                        in: w
                    )
                    let rgb = Self.countryRGB(w, cid)
                    uncalledAllies.append([
                        "countryIndex": cid.index,
                        "name": w.countries.name[cid.index],
                        "tag": w.countries.tag[cid.index],
                        "colorR": Int(rgb.r),
                        "colorG": Int(rgb.g),
                        "colorB": Int(rgb.b),
                        "willAccept": eval.willAccept,
                        "score": eval.score,
                        "reasonsText": eval.reasons.joined(separator: ", ")
                    ])
                }
            }

            return [
                "warID": war.id,
                "name": war.name,
                "startDate": war.startDate.description,
                "casusBelli": war.casusBelli.rawValue,
                "warGoal": Self.warGoalLabel(war.warGoal, world: w),
                "playerIsParticipant": isParticipant,
                "playerIsAttacker": isAttacker,
                "warScorePct": wsPct,
                "battlePct": battlePct,
                "blockadePct": blockadePct,
                "occupationPct": occPct,
                "tickingPct": tickingPct,
                "recentNavalBattles": recentNavalBattles,
                "attackersText": war.attackers.map { w.countries.tag[$0.index] }.joined(separator: ", "),
                "defendersText": war.defenders.map { w.countries.tag[$0.index] }.joined(separator: ", "),
                "attackers": attackersList,
                "defenders": defendersList,
                "occupiedProvinces": occupiedList,
                "primaryEnemyIndex": enemyLeader.index,
                "primaryEnemyTag": w.countries.tag[enemyLeader.index],
                "uncalledAllies": uncalledAllies
            ]
        }

        return [
            "hasPlayer": true,
            "pendingOffers": pendingOffers,
            "wars": warRows
        ]
    }

    @discardableResult
    public func callAllyToWar(allyCountryIndex: Int, warID: String) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["accepted": false, "message": "No active game."]
        }
        guard allyCountryIndex >= 0 && allyCountryIndex < s.world.countries.count,
              allyCountryIndex != player.index else {
            return ["accepted": false, "message": "Invalid ally."]
        }
        let ally = CountryID(allyCountryIndex)
        let allyName = s.world.countries.name[allyCountryIndex]
        let res = s.callAllyToWar(ally, warID: warID)
        switch res {
        case .accepted:
            return ["accepted": true, "message": "\(allyName) joined the war."]
        case .declined(let reasons):
            let why = reasons.isEmpty ? "Declined" : reasons.joined(separator: "; ")
            return ["accepted": false, "message": "\(allyName) declined: \(why)"]
        }
    }

    public func peaceNegotiationDetails(
        warID: String,
        provinceIndices: [Int] = [],
        indemnityAmount: Double = 0.0,
        includeReparations: Bool = false,
        subjectMode: Int = 0,
        releaseCountryIndices: [Int] = [],
        annulPartnerIndices: [Int] = []
    ) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["valid": false, "error": "No active game."]
        }
        let w = s.world
        let d = w.diplomacy
        guard let war = d.wars.first(where: { $0.id == warID }), war.isParticipant(player) else {
            return ["valid": false, "error": "War not found."]
        }
        let loser = war.isAttacker(player) ? war.primaryDefender : war.primaryAttacker
        let loserRGB = Self.countryRGB(w, loser)

        let loserProvs = w.provinces(ownedBy: loser).sorted { a, b in
            let aOcc = w.provinces.occupiedBy[a.index].map { war.areEnemies($0, loser) } ?? false
            let bOcc = w.provinces.occupiedBy[b.index].map { war.areEnemies($0, loser) } ?? false
            if aOcc != bOcc { return aOcc }
            return w.provinces.name[a.index] < w.provinces.name[b.index]
        }

        let cedeRows: [[String: Any]] = loserProvs.map { pid in
            let cost = d.peaceDemandCost(.cedeProvince(province: pid, to: player), loser: loser, war: war, in: w)
            let isOcc = w.provinces.occupiedBy[pid.index].map { war.areEnemies($0, loser) } ?? false
            let isCore = w.provinces.cores[pid.index].contains(player)
            let isClaim = w.provinces.claims[pid.index].contains(player)
            return [
                "provinceIndex": pid.index,
                "name": w.provinces.name[pid.index],
                "development": w.provinces.development[pid.index],
                "isOccupied": isOcc,
                "isCore": isCore,
                "isClaim": isClaim,
                "cost": cost
            ]
        }

        var coreHolders = Set<CountryID>()
        for pid in loserProvs {
            for cid in w.provinces.cores[pid.index] where cid != loser && cid != player {
                coreHolders.insert(cid)
            }
        }
        let releaseRows: [[String: Any]] = coreHolders
            .sorted { w.countries.name[$0.index] < w.countries.name[$1.index] }
            .map { cid in
                let rgb = Self.countryRGB(w, cid)
                let coreCount = loserProvs.filter { w.provinces.cores[$0.index].contains(cid) }.count
                let cost = d.peaceDemandCost(.releaseNation(country: cid), loser: loser, war: war, in: w)
                return [
                    "countryIndex": cid.index,
                    "name": w.countries.name[cid.index],
                    "tag": w.countries.tag[cid.index],
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b),
                    "provinceCount": coreCount,
                    "cost": cost
                ]
            }

        var annulSet = Set<CountryID>()
        for tr in d.treaties where tr.type == .alliance || tr.type == .guarantee || tr.type == .nonAggression {
            if tr.first == loser && tr.second != player {
                annulSet.insert(tr.second)
            } else if tr.second == loser && tr.first != player {
                annulSet.insert(tr.first)
            }
        }
        let annulRows: [[String: Any]] = annulSet
            .sorted { w.countries.name[$0.index] < w.countries.name[$1.index] }
            .map { cid in
                let rgb = Self.countryRGB(w, cid)
                let cost = d.peaceDemandCost(.annulTreaty(with: cid), loser: loser, war: war, in: w)
                return [
                    "countryIndex": cid.index,
                    "name": w.countries.name[cid.index],
                    "tag": w.countries.tag[cid.index],
                    "colorR": Int(rgb.r),
                    "colorG": Int(rgb.g),
                    "colorB": Int(rgb.b),
                    "cost": cost
                ]
            }

        let demands = Self.buildPeaceDemands(
            world: w,
            player: player,
            loser: loser,
            provinceIndices: provinceIndices,
            indemnityAmount: indemnityAmount,
            includeReparations: includeReparations,
            subjectMode: subjectMode,
            releaseCountryIndices: releaseCountryIndices,
            annulPartnerIndices: annulPartnerIndices
        )
        let offer = PeaceOffer(warID: war.id, winner: player, loser: loser, demands: demands)
        let eval = d.evaluatePeaceOffer(offer, date: s.date, in: w)
        let truceYears = d.truceDurationYears(forPeaceCost: eval.totalCost)
        let ae = Int(d.aggressiveExpansionForPeace(offer, war: war, in: w).rounded())

        let factors: [[String: Any]] = eval.factors.map { f in
            [
                "name": f.name,
                "score": f.score,
                "scoreText": f.score >= 0 ? "+\(f.score)" : "\(f.score)"
            ]
        }

        let indemnityCost = indemnityAmount > 0 ? d.peaceDemandCost(.ducatIndemnity(amount: indemnityAmount), loser: loser, war: war, in: w) : 0
        let reparationsCost = d.peaceDemandCost(.warReparations, loser: loser, war: war, in: w)
        let vassalCost = d.peaceDemandCost(.makeVassal, loser: loser, war: war, in: w)
        let tributaryCost = d.peaceDemandCost(.makeTributary, loser: loser, war: war, in: w)

        return [
            "valid": true,
            "warID": war.id,
            "warName": war.name,
            "warScorePct": Int((war.warScore * 100.0).rounded()),
            "loserIndex": loser.index,
            "loserName": w.countries.name[loser.index],
            "loserTag": w.countries.tag[loser.index],
            "loserColorR": Int(loserRGB.r),
            "loserColorG": Int(loserRGB.g),
            "loserColorB": Int(loserRGB.b),
            "cedeProvinces": cedeRows,
            "releaseCandidates": releaseRows,
            "annulCandidates": annulRows,
            "reparationsCost": reparationsCost,
            "indemnityCost": indemnityCost,
            "vassalCost": vassalCost,
            "tributaryCost": tributaryCost,
            "totalCost": eval.totalCost,
            "exceedsCost": eval.totalCost > 100,
            "truceYears": truceYears,
            "ae": ae,
            "willAccept": eval.willAccept,
            "score": eval.score,
            "factors": factors
        ]
    }

    @discardableResult
    public func proposePeaceOffer(
        warID: String,
        provinceIndices: [Int] = [],
        indemnityAmount: Double = 0.0,
        includeReparations: Bool = false,
        subjectMode: Int = 0,
        releaseCountryIndices: [Int] = [],
        annulPartnerIndices: [Int] = []
    ) -> [String: Any] {
        guard let s = session, let player = s.playerCountry else {
            return ["ok": false, "error": "No active game."]
        }
        let w = s.world
        guard let war = w.diplomacy.wars.first(where: { $0.id == warID }), war.isParticipant(player) else {
            return ["ok": false, "error": "War not found."]
        }
        let loser = war.isAttacker(player) ? war.primaryDefender : war.primaryAttacker
        let demands = Self.buildPeaceDemands(
            world: w,
            player: player,
            loser: loser,
            provinceIndices: provinceIndices,
            indemnityAmount: indemnityAmount,
            includeReparations: includeReparations,
            subjectMode: subjectMode,
            releaseCountryIndices: releaseCountryIndices,
            annulPartnerIndices: annulPartnerIndices
        )
        let offer = PeaceOffer(warID: war.id, winner: player, loser: loser, demands: demands)
        let res = s.proposePeace(offer)
        switch res {
        case .success(let totalCost):
            townIconsRevision &+= 1
            return ["ok": true, "error": "", "totalCost": totalCost]
        case .failure(let err):
            let msg: String
            switch err {
            case .warNotFound: msg = "War not found."
            case .notBelligerents: msg = "Invalid belligerents."
            case .exceedsMaxCost(let c): msg = "Demand cost (\(c)%) exceeds 100%."
            case .invalidDemand(let r): msg = r
            case .rejected(let eval): msg = "Peace offer refused (score \(eval.score))."
            }
            return ["ok": false, "error": msg]
        }
    }

    @discardableResult
    public func respondToPendingPeaceOffer(warID: String, accept: Bool) -> Bool {
        guard let s = session, let player = s.playerCountry,
              let offer = s.world.diplomacy.pendingPeaceOffers.first(where: { $0.warID == warID && $0.loser == player }) else {
            return false
        }
        s.respondToPendingPeaceOffer(offer, accept: accept)
        if accept {
            townIconsRevision &+= 1
        }
        return true
    }

    private static func buildPeaceDemands(
        world w: World,
        player: CountryID,
        loser: CountryID,
        provinceIndices: [Int],
        indemnityAmount: Double,
        includeReparations: Bool,
        subjectMode: Int,
        releaseCountryIndices: [Int],
        annulPartnerIndices: [Int]
    ) -> [PeaceDemand] {
        var demands: [PeaceDemand] = []
        let cleanProvs = Array(Set(provinceIndices.filter {
            $0 >= 0 && $0 < w.provinces.count && w.provinces.owner[$0] == loser
        })).sorted()
        for pIdx in cleanProvs {
            demands.append(.cedeProvince(province: ProvinceID(pIdx), to: player))
        }
        if includeReparations {
            demands.append(.warReparations)
        }
        if indemnityAmount > 0 {
            demands.append(.ducatIndemnity(amount: indemnityAmount))
        }
        if subjectMode == 1 {
            demands.append(.makeVassal)
        } else if subjectMode == 2 {
            demands.append(.makeTributary)
        }
        let cleanReleases = Array(Set(releaseCountryIndices.filter {
            $0 >= 0 && $0 < w.countries.count && $0 != loser.index && $0 != player.index
        })).sorted()
        for cIdx in cleanReleases {
            demands.append(.releaseNation(country: CountryID(cIdx)))
        }
        let cleanAnnuls = Array(Set(annulPartnerIndices.filter {
            $0 >= 0 && $0 < w.countries.count && $0 != loser.index && $0 != player.index
        })).sorted()
        for cIdx in cleanAnnuls {
            demands.append(.annulTreaty(with: CountryID(cIdx)))
        }
        return demands
    }

    private static func countryPill(_ cid: CountryID, world w: World) -> [String: Any] {
        let rgb = countryRGB(world: w, cid)
        return [
            "index": cid.index,
            "name": w.countries.name[cid.index],
            "tag": w.countries.tag[cid.index],
            "colorR": Int(rgb.r),
            "colorG": Int(rgb.g),
            "colorB": Int(rgb.b)
        ]
    }

    private static func countryRGB(world w: World, _ cid: CountryID) -> RGB {
        guard cid.index >= 0 && cid.index < w.countries.color.count else {
            return RGB(196, 182, 150)
        }
        return w.countries.color[cid.index]
    }

    private static func countryRGB(_ w: World, _ cid: CountryID) -> RGB {
        countryRGB(world: w, cid)
    }

    private static func treatyLabel(_ treaty: Treaty, player: CountryID) -> String {
        switch treaty.type {
        case .alliance: return "Alliance"
        case .guarantee: return treaty.first == player ? "Guaranteeing them" : "Guaranteed by them"
        case .nonAggression: return "Non-Aggression Pact"
        case .militaryAccess: return treaty.first == player ? "Granting Military Access" : "Have Military Access"
        case .truce: return "Truce"
        }
    }

    private static func warGoalLabel(_ goal: WarGoal, world w: World) -> String {
        switch goal {
        case .conquerProvince(let pid):
            if pid.index >= 0 && pid.index < w.provinces.count {
                return "Conquer \(w.provinces.name[pid.index])"
            }
            return "Conquer province"
        case .defendCapital(let pid):
            if pid.index >= 0 && pid.index < w.provinces.count {
                return "Defend \(w.provinces.name[pid.index])"
            }
            return "Defend capital"
        case .superiority:
            return "Superiority"
        }
    }

    private static func describeDemand(_ demand: PeaceDemand, world: World) -> String {
        switch demand {
        case .cedeProvince(let pid, let to):
            return "Cede \(world.provinces.name[pid.index]) to \(world.countries.name[to.index])"
        case .returnCore(let pid, let to):
            return "Return core \(world.provinces.name[pid.index]) to \(world.countries.name[to.index])"
        case .ducatIndemnity(let amount):
            return "\(Int(amount)) Ducats Indemnity"
        case .warReparations:
            return "War Reparations (10% income, 10 years)"
        case .makeVassal:
            return "Force Vassalization"
        case .makeTributary:
            return "Force Tributary"
        case .annulTreaty(let with):
            return "Annul treaties with \(world.countries.name[with.index])"
        case .releaseNation(let country):
            return "Release \(world.countries.name[country.index])"
        }
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

    // MARK: - Step 3f: Map Town Icons (Development, Capitals, Forts, Ports)

    /// Packs `TownIconInfo` entries as stride-6 floats:
    /// `[x, y, development, fortLevel, isCapital (0/1), isPort (0/1), ...]`.
    public func townIconMetrics() -> [Float] {
        guard let s = session else { return [] }
        let icons = s.townIcons
        var out: [Float] = []
        out.reserveCapacity(icons.count * 6)
        for icon in icons {
            out.append(Float(icon.x))
            out.append(Float(icon.y))
            out.append(Float(icon.development))
            out.append(Float(icon.fortLevel))
            out.append(icon.isCapital ? 1.0 : 0.0)
            out.append(icon.isPort ? 1.0 : 0.0)
        }
        return out
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

    // MARK: - Phase 9 Part A: Tactical Battle Prompts, Battlefield & Deployment

    public func hasPendingBattlePrompt() -> Bool {
        session?.pendingBattlePrompt != nil
    }

    public func pendingBattlePromptData() -> [String: Any] {
        guard let prompt = session?.pendingBattlePrompt else { return ["active": false] }
        return [
            "active": true,
            "id": prompt.id,
            "isAssault": prompt.isAssault,
            "provinceIndex": prompt.province.index,
            "provinceName": prompt.provinceName,
            "terrainKey": prompt.terrain.rawValue,
            "terrainName": prompt.terrain.rawValue.capitalized,
            "isRiverCrossing": prompt.isRiverCrossing,
            "attackerAmbushed": prompt.attackerAmbushed,
            "attackerName": prompt.attackerName,
            "attackerTag": prompt.attackerTag,
            "defenderName": prompt.defenderName,
            "defenderTag": prompt.defenderTag,
            "attackerMen": prompt.attackerMen,
            "defenderMen": prompt.defenderMen,
            "attackerCommander": prompt.attackerCommanderName,
            "attackerMartial": prompt.attackerCommanderMartial,
            "defenderCommander": prompt.defenderCommanderName,
            "defenderMartial": prompt.defenderCommanderMartial,
            "playerSide": prompt.playerSide == .attacker ? "attacker" : "defender",
            "fortLevel": prompt.fortLevel,
            "breached": prompt.breached
        ]
    }

    public func requestStormAssaultChoice(provinceIndex: Int) -> [String: Any] {
        guard let s = session,
              provinceIndex >= 0 && provinceIndex < s.world.provinces.count else {
            return ["opened": false, "refusalReason": "Invalid province"]
        }
        let pid = ProvinceID(provinceIndex)
        let res = s.requestStormAssaultPrompt(in: pid)
        if let prompt = res.prompt {
            return ["opened": true, "promptId": prompt.id, "refusalReason": ""]
        }
        return ["opened": false, "refusalReason": res.refusalReason ?? "Cannot start assault"]
    }

    public func chooseAutoResolveBattle() -> [String: Any] {
        guard let s = session else { return ["resolved": false] }
        let wasAssault = s.pendingBattlePrompt?.isAssault ?? false
        if let assaultRes = s.chooseAutoResolvePendingBattle() {
            let text: String
            if let refusal = assaultRes.refusalReason {
                text = refusal
            } else if assaultRes.captured {
                text = "Assault captured fort (-\(assaultRes.attackerLosses) attackers)"
            } else {
                text = "Assault repelled (-\(assaultRes.attackerLosses) attackers, -\(assaultRes.garrisonLosses) garrison)"
            }
            return [
                "resolved": true,
                "wasAssault": true,
                "captured": assaultRes.captured,
                "attackerLosses": assaultRes.attackerLosses,
                "garrisonLosses": assaultRes.garrisonLosses,
                "remainingGarrison": assaultRes.remainingGarrison,
                "summaryText": text
            ]
        }
        return ["resolved": true, "wasAssault": wasAssault, "summaryText": "Auto-resolve battle engaged on campaign map"]
    }

    @discardableResult
    public func chooseLeadBattleInPerson() -> Bool {
        session?.chooseLeadPendingBattleInPerson() ?? false
    }

    public func isTacticalBattleActive() -> Bool {
        session?.tacticalBattle != nil
    }

    @discardableResult
    public func deployMoveBattleUnit(unitIndex: Int, x: Double, y: Double, facing: Double) -> Bool {
        session?.deployMoveBattleUnit(unitIndex: unitIndex, x: x, y: y, facing: facing) ?? false
    }

    @discardableResult
    public func startTacticalBattle() -> Bool {
        session?.startTacticalBattle() ?? false
    }

    @discardableResult
    public func setTacticalBattleSpeed(speedIndex: Int) -> Bool {
        session?.setTacticalBattleSpeed(speedIndex) ?? false
    }

    @discardableResult
    public func tickTacticalBattle(deltaSeconds: Double) -> Int {
        session?.tickTacticalBattle(deltaSeconds: deltaSeconds) ?? 0
    }

    // MARK: - Phase 9 Part B: Real-time Tactical Orders

    @discardableResult
    public func orderBattleMove(unitIndices: [Int], x: Double, y: Double) -> Bool {
        session?.orderBattleMove(unitIndices: unitIndices, x: x, y: y) ?? false
    }

    @discardableResult
    public func orderBattlePath(unitIndices: [Int], points: [TacticalPoint]) -> Bool {
        session?.orderBattlePath(unitIndices: unitIndices, points: points) ?? false
    }

    @discardableResult
    public func orderBattleFrontline(unitIndices: [Int], startX: Double, startY: Double, endX: Double, endY: Double) -> Bool {
        session?.orderBattleFrontline(
            unitIndices: unitIndices,
            start: TacticalPoint(x: startX, y: startY),
            end: TacticalPoint(x: endX, y: endY)
        ) ?? false
    }

    @discardableResult
    public func orderBattleAttack(unitIndices: [Int], targetUnitIndex: Int) -> Bool {
        session?.orderBattleAttack(unitIndices: unitIndices, targetUnitIndex: targetUnitIndex) ?? false
    }

    @discardableResult
    public func orderBattleFormation(unitIndices: [Int], formationKey: String) -> Bool {
        guard let form = BattleFormation(rawValue: formationKey) else { return false }
        return session?.orderBattleFormation(unitIndices: unitIndices, formation: form) ?? false
    }

    @discardableResult
    public func orderBattleStance(unitIndices: [Int], stanceKey: String) -> Bool {
        guard let st = BattleStance(rawValue: stanceKey) else { return false }
        return session?.orderBattleStance(unitIndices: unitIndices, stance: st) ?? false
    }

    @discardableResult
    public func orderBattleRetreat(unitIndices: [Int]) -> Bool {
        session?.orderBattleRetreat(unitIndices: unitIndices) ?? false
    }

    // MARK: - Phase 9 Part C: Siege Assault Orders

    @discardableResult
    public func orderBattleSiegeEquipment(unitIndices: [Int], equipmentKey: String) -> Bool {
        guard let eq = SiegeEquipmentKind(rawValue: equipmentKey) else { return false }
        return session?.orderBattleSiegeEquipment(unitIndices: unitIndices, equipment: eq) ?? false
    }

    @discardableResult
    public func orderBattleAttackStructure(unitIndices: [Int], structureId: Int) -> Bool {
        session?.orderBattleAttackStructure(unitIndices: unitIndices, structureID: structureId) ?? false
    }

    // MARK: - Phase 9 Part D: Battle Result Write-Back

    public func finishTacticalBattleData() -> [String: Any] {
        guard let res = session?.finishTacticalBattle() else {
            return ["applied": false]
        }
        return Self.resultDict(res, applied: true)
    }

    private static func resultDict(_ r: TacticalBattleResult, applied: Bool) -> [String: Any] {
        [
            "applied": applied,
            "provinceIndex": r.province.index,
            "provinceName": r.provinceName,
            "isAssault": r.isAssault,
            "winner": r.winner == .attacker ? "attacker" : "defender",
            "winnerName": r.winnerName,
            "attackerName": r.attackerName,
            "defenderName": r.defenderName,
            "attackerInitialMen": r.attackerInitialMen,
            "attackerSurvivors": r.attackerSurvivors,
            "attackerLosses": r.attackerLosses,
            "defenderInitialMen": r.defenderInitialMen,
            "defenderSurvivors": r.defenderSurvivors,
            "defenderLosses": r.defenderLosses,
            "wasStackwipe": r.wasStackwipe,
            "fortCaptured": r.fortCaptured,
            "newBreachCreated": r.newBreachCreated,
            "remainingGarrison": r.remainingGarrison,
            "warScoreDelta": r.warScoreDelta,
            "elapsedSeconds": r.elapsedSeconds,
            "attackerCommanderName": r.attackerCommanderName,
            "attackerCommanderFate": r.attackerCommanderFate.rawValue.capitalized,
            "defenderCommanderName": r.defenderCommanderName,
            "defenderCommanderFate": r.defenderCommanderFate.rawValue.capitalized
        ]
    }

    public func battleStateData() -> [String: Any] {
        guard let b = session?.tacticalBattle else {
            return ["active": false]
        }
        let bf = b.battlefield

        let hillRows: [[String: Any]] = bf.hills.map { h in
            [
                "x": h.centerX, "y": h.centerY,
                "rx": h.radiusX, "ry": h.radiusY,
                "height": h.height, "angle": h.angle
            ]
        }
        let forestRows: [[String: Any]] = bf.forests.map { f in
            [
                "x": f.centerX, "y": f.centerY,
                "rx": f.radiusX, "ry": f.radiusY,
                "density": f.density
            ]
        }
        var riverPts: [[String: Any]] = []
        var fordRows: [[String: Any]] = []
        var riverHalfWidth = 0.0
        if let r = bf.river {
            riverHalfWidth = r.halfWidth
            riverPts = r.centerLine.map { ["x": $0.x, "y": $0.y] }
            fordRows = r.fords.map { ["x": $0.x, "y": $0.y, "w": $0.width, "h": $0.height] }
        }
        let structureRows: [[String: Any]] = b.structures.map { st in
            [
                "id": st.id,
                "kind": st.kind.rawValue,
                "x": st.x, "y": st.y,
                "w": st.width, "h": st.height,
                "hp": st.hp, "maxHp": st.maxHp,
                "breached": st.breached,
                "elevation": st.elevation
            ]
        }

        let u = b.units
        var unitRows: [[String: Any]] = []
        unitRows.reserveCapacity(u.count)
        for i in 0..<u.count {
            let sideInt = u.side[i].rawValue
            let rgb = u.side[i] == .attacker ? b.attackerColor : b.defenderColor
            let wpList: [[String: Any]] = u.waypoints[i].map { ["x": $0.x, "y": $0.y] }
            unitRows.append([
                "index": i,
                "side": sideInt,
                "name": u.unitName[i],
                "key": u.unitKey[i],
                "glyph": BattleUnitTable.unitGlyph(key: u.unitKey[i], category: u.category[i]),
                "category": u.category[i].rawValue,
                "men": u.men[i],
                "initialMen": u.initialMen[i],
                "maxMen": u.maxMen[i],
                "morale": u.morale[i],
                "maxMorale": u.maxMorale[i],
                "fatigue": u.fatigue[i],
                "ammo": u.ammo[i],
                "maxAmmo": u.maxAmmo[i],
                "x": u.posX[i],
                "y": u.posY[i],
                "w": u.width[i],
                "h": u.depth[i],
                "facing": u.facing[i],
                "formation": u.formation[i].rawValue,
                "stance": u.stance[i].rawValue,
                "hasMoveOrder": u.hasMoveOrder[i],
                "targetX": u.targetX[i],
                "targetY": u.targetY[i],
                "targetUnit": u.targetUnit[i],
                "targetStructure": u.targetStructure[i],
                "siegeEquipment": u.siegeEquipment[i].rawValue,
                "waypoints": wpList,
                "isRouting": u.isRouting[i],
                "isOnWall": u.isOnWall[i],
                "inMelee": u.inMeleeWith[i] >= 0,
                "colorR": Int(rgb.r),
                "colorG": Int(rgb.g),
                "colorB": Int(rgb.b)
            ])
        }

        let attMen = u.totalMen(on: .attacker)
        let defMen = u.totalMen(on: .defender)
        let attInit = u.totalInitialMen(on: .attacker)
        let defInit = u.totalInitialMen(on: .defender)

        var keepZoneDict: [String: Any] = [:]
        if let kz = bf.keepZone {
            keepZoneDict = ["x": kz.x, "y": kz.y, "w": kz.width, "h": kz.height]
        }

        return [
            "active": true,
            "provinceIndex": b.province.index,
            "provinceName": b.provinceName,
            "terrainKey": bf.terrain.rawValue,
            "terrainName": bf.terrain.rawValue.capitalized,
            "isAssault": b.isAssault,
            "isRiverCrossing": bf.isRiverCrossing,
            "attackerAmbushed": b.attackerAmbushed,
            "phase": b.phase.rawValue,
            "speedIndex": b.speed.rawValue,
            "speedLabel": b.speed.label,
            "tickCount": b.tickCount,
            "elapsedSeconds": b.elapsedSeconds,
            "playerSide": b.playerSide == .defender ? "defender" : "attacker",
            "winner": b.winner == .attacker ? "attacker" : (b.winner == .defender ? "defender" : ""),
            "fieldW": bf.width,
            "fieldH": bf.height,
            "attDeployX": bf.attackerDeployZone.x,
            "attDeployY": bf.attackerDeployZone.y,
            "attDeployW": bf.attackerDeployZone.width,
            "attDeployH": bf.attackerDeployZone.height,
            "defDeployX": bf.defenderDeployZone.x,
            "defDeployY": bf.defenderDeployZone.y,
            "defDeployW": bf.defenderDeployZone.width,
            "defDeployH": bf.defenderDeployZone.height,
            "attackerName": b.attackerName,
            "attackerTag": b.attackerTag,
            "attackerColorR": Int(b.attackerColor.r),
            "attackerColorG": Int(b.attackerColor.g),
            "attackerColorB": Int(b.attackerColor.b),
            "attackerMen": attMen,
            "attackerInitialMen": attInit,
            "attackerAvgMorale": u.averageMorale(on: .attacker),
            "attackerCommander": b.attackerCommander?.name ?? "Field Captain",
            "attackerMartial": b.attackerCommander?.martial ?? 0,
            "defenderName": b.defenderName,
            "defenderTag": b.defenderTag,
            "defenderColorR": Int(b.defenderColor.r),
            "defenderColorG": Int(b.defenderColor.g),
            "defenderColorB": Int(b.defenderColor.b),
            "defenderMen": defMen,
            "defenderInitialMen": defInit,
            "defenderAvgMorale": u.averageMorale(on: .defender),
            "defenderCommander": b.defenderCommander?.name ?? "Castellan",
            "defenderMartial": b.defenderCommander?.martial ?? 0,
            "hills": hillRows,
            "forests": forestRows,
            "hasRiver": bf.river != nil,
            "riverHalfWidth": riverHalfWidth,
            "riverPoints": riverPts,
            "fords": fordRows,
            "structures": structureRows,
            "keepZone": keepZoneDict,
            "keepCaptureProgress": b.keepCaptureProgress,
            "resultPreview": (b.phase == .ended) ? Self.resultDict(BattleWriteBack.previewResult(engine: b), applied: false) : [:],
            "units": unitRows
        ]
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
    public func getPlayerTopBarDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.playerTopBarDetails())
    }

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

    @Callable
    public func getTownIconsRevision() -> Int {
        controller.townIconsRevision
    }

    @Callable
    public func getTownIconsData() -> PackedFloat32Array {
        PackedFloat32Array(controller.townIconMetrics())
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
    public func getAISettingOptions() -> VariantArray {
        Self.toVariantArray(controller.aiSettingOptions())
    }

    @Callable
    public func getAISetting() -> String {
        controller.aiSettingKey
    }

    @Callable
    public func getAISettingDisplayName() -> String {
        controller.aiSettingDisplayName
    }

    @Callable
    public func startNewGame(tag: String) -> Bool {
        controller.startNewGame(tag: tag)
    }

    @Callable
    public func startNewGameWithAI(tag: String, aiSetting: String) -> Bool {
        controller.startNewGame(tag: tag, aiSettingKey: aiSetting)
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
    public func getMapArmiesSignature() -> Int {
        controller.mapArmiesSignature()
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

    // MARK: - Phase 10: Navies, Ship Construction, Blockades & Sea Transport

    @Callable
    public func getSelectedFleetId() -> Int {
        controller.selectedFleetId
    }

    @Callable
    public func getMoveModeFleetId() -> Int {
        controller.moveModeFleetId
    }

    @Callable
    public func selectFleet(fleetId: Int) -> Bool {
        controller.selectFleet(fleetId: fleetId)
    }

    @Callable
    public func clearSelectedFleet() {
        controller.clearSelectedFleet()
    }

    @Callable
    public func setMoveModeForFleet(fleetId: Int) -> Bool {
        controller.setMoveModeForFleet(fleetId: fleetId)
    }

    @Callable
    public func getMapFleetsSignature() -> Int {
        controller.mapFleetsSignature()
    }

    @Callable
    public func getMapFleetsData() -> VariantDictionary {
        Self.toVariantDictionary(controller.mapFleetsData())
    }

    @Callable
    public func getNaviesWindowDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.naviesWindowDetails())
    }

    @Callable
    public func getSelectedFleetDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.selectedFleetDetails())
    }

    @Callable
    public func buildShipInSelectedProvince(shipTypeIndex: Int) -> Bool {
        controller.buildShipInSelectedProvince(shipTypeIndex: shipTypeIndex)
    }

    @Callable
    public func assignFleetAdmiral(fleetId: Int, characterIndex: Int) -> Bool {
        controller.assignFleetAdmiral(fleetId: fleetId, characterIndex: characterIndex)
    }

    @Callable
    public func mergeFleetsInLocation(fleetId: Int) -> Bool {
        controller.mergeFleetsInLocation(fleetId: fleetId)
    }

    @Callable
    public func splitFleet(fleetId: Int) -> Int {
        controller.splitFleet(fleetId: fleetId)
    }

    @Callable
    public func orderFleetMoveToSea(fleetId: Int, seaZoneIndex: Int) -> Bool {
        controller.orderFleetMoveToSea(fleetId: fleetId, seaZoneIndex: seaZoneIndex)
    }

    @Callable
    public func orderFleetDock(fleetId: Int, portProvinceIndex: Int) -> Bool {
        controller.orderFleetDock(fleetId: fleetId, portProvinceIndex: portProvinceIndex)
    }

    @Callable
    public func orderFleetMoveAt(fleetId: Int, mapX: Int, mapY: Int) -> Bool {
        controller.orderFleetMoveAt(fleetId: fleetId, mapX: mapX, mapY: mapY)
    }

    @Callable
    public func orderFleetBlockadeNearestEnemy(fleetId: Int) -> Bool {
        controller.orderFleetBlockadeNearestEnemy(fleetId: fleetId)
    }

    @Callable
    public func embarkArmyOnFleet(armyId: Int, fleetId: Int) -> Bool {
        controller.embarkArmyOnFleet(armyId: armyId, fleetId: fleetId)
    }

    @Callable
    public func disembarkArmyFromFleet(armyId: Int, provinceIndex: Int) -> Bool {
        controller.disembarkArmyFromFleet(armyId: armyId, provinceIndex: provinceIndex)
    }

    @Callable
    public func getSeaZoneFocusPoint(seaZoneIndex: Int) -> Vector2 {
        guard let s = controller.session,
              seaZoneIndex >= 0 && seaZoneIndex < s.world.seaZones.centerX.count else {
            return Vector2(x: 0, y: 0)
        }
        return Vector2(
            x: Float(s.world.seaZones.centerX[seaZoneIndex]),
            y: Float(s.world.seaZones.centerY[seaZoneIndex])
        )
    }

    @Callable
    public func assaultFort(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.assaultFort(provinceIndex: provinceIndex))
    }

    // MARK: - Step 3c: Budget & Trade

    @Callable
    public func getBudgetDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.budgetDetails())
    }

    @Callable
    public func setTaxLevel(taxClassIndex: Int, level: Double) -> Bool {
        controller.setTaxLevel(taxClassIndex: taxClassIndex, level: level)
    }

    @Callable
    public func borrowFromBank(bankIndex: Int, amount: Double) -> Bool {
        controller.borrowFromBank(bankIndex: bankIndex, amount: amount)
    }

    @Callable
    public func repayLoan(loanIndex: Int) -> Bool {
        controller.repayLoan(loanIndex: loanIndex)
    }

    @Callable
    public func debaseOnce() -> Double {
        controller.debaseOnce()
    }

    @Callable
    public func setDebasing(on: Bool) -> Bool {
        controller.setDebasing(on: on)
    }

    @Callable
    public func getTradeWindowDetails(
        draftGoodIndex: Int,
        draftFromMarketIndex: Int,
        draftToMarketIndex: Int,
        draftVolume: Double
    ) -> VariantDictionary {
        Self.toVariantDictionary(
            controller.tradeWindowDetails(
                draftGoodIndex: draftGoodIndex,
                draftFromMarketIndex: draftFromMarketIndex,
                draftToMarketIndex: draftToMarketIndex,
                draftVolume: draftVolume
            )
        )
    }

    @Callable
    public func estimateTradeRoute(
        goodIndex: Int,
        fromMarketIndex: Int,
        toMarketIndex: Int,
        volume: Double
    ) -> VariantDictionary {
        Self.toVariantDictionary(
            controller.estimateTradeRoute(
                goodIndex: goodIndex,
                fromMarketIndex: fromMarketIndex,
                toMarketIndex: toMarketIndex,
                volume: volume
            )
        )
    }

    @Callable
    public func createTradeRoute(
        goodIndex: Int,
        fromMarketIndex: Int,
        toMarketIndex: Int,
        volume: Double
    ) -> VariantDictionary {
        Self.toVariantDictionary(
            controller.createTradeRoute(
                goodIndex: goodIndex,
                fromMarketIndex: fromMarketIndex,
                toMarketIndex: toMarketIndex,
                volume: volume
            )
        )
    }

    @Callable
    public func cancelTradeRoute(routeIndex: Int) -> Bool {
        controller.cancelTradeRoute(routeIndex: routeIndex)
    }

    @Callable
    public func setTollPolicy(key: String) -> Bool {
        controller.setTollPolicy(key: key)
    }

    @Callable
    public func toggleEmbargo(countryIndex: Int) -> Bool {
        controller.toggleEmbargo(countryIndex: countryIndex)
    }

    @Callable
    public func getMapTradeRoutesData() -> VariantDictionary {
        Self.toVariantDictionary(controller.mapTradeRoutesData())
    }

    // MARK: - Step 3d1: Court & Government

    @Callable
    public func setViewedCharacter(characterIndex: Int) -> Bool {
        controller.setViewedCharacter(characterIndex: characterIndex)
    }

    @Callable
    public func getCourtDetails(marryingCharacterIndex: Int = -1) -> VariantDictionary {
        Self.toVariantDictionary(controller.courtDetails(marryingCharacterIndex: marryingCharacterIndex))
    }

    @Callable
    public func appointCouncilSeat(seatIndex: Int, characterIndex: Int) -> Bool {
        controller.appointCouncilSeat(seatIndex: seatIndex, characterIndex: characterIndex)
    }

    @Callable
    public func appointCouncilNewcomer(seatIndex: Int) -> Bool {
        controller.appointCouncilNewcomer(seatIndex: seatIndex)
    }

    @Callable
    public func proposeMarriage(familyCharacterIndex: Int, candidateCharacterIndex: Int) -> Bool {
        controller.proposeMarriage(familyCharacterIndex: familyCharacterIndex, candidateCharacterIndex: candidateCharacterIndex)
    }

    @Callable
    public func grantProvinceToCharacter(provinceIndex: Int, characterIndex: Int) -> Bool {
        controller.grantProvinceToCharacter(provinceIndex: provinceIndex, characterIndex: characterIndex)
    }

    @Callable
    public func revokeProvinceHolder(provinceIndex: Int) -> Bool {
        controller.revokeProvinceHolder(provinceIndex: provinceIndex)
    }

    @Callable
    public func getGovernmentDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.governmentDetails())
    }

    @Callable
    public func raiseStability() -> Bool {
        controller.raiseStability()
    }

    @Callable
    public func changeLaw(areaIndex: Int, optionIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.changeLaw(areaIndex: areaIndex, optionIndex: optionIndex))
    }

    @Callable
    public func grantPrivilege(privilegeIndex: Int) -> Bool {
        controller.grantPrivilege(privilegeIndex: privilegeIndex)
    }

    @Callable
    public func revokePrivilege(privilegeIndex: Int) -> Bool {
        controller.revokePrivilege(privilegeIndex: privilegeIndex)
    }

    @Callable
    public func adoptReform(optionIndex: Int) -> Bool {
        controller.adoptReform(optionIndex: optionIndex)
    }

    // MARK: - Phase 11: Religion, Missionaries, Movements & Culture Callables

    @Callable
    public func getReligionWindowDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.religionWindowDetails())
    }

    @Callable
    public func sendMissionary(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.sendMissionary(provinceIndex: provinceIndex))
    }

    @Callable
    public func recallMissionary(provinceIndex: Int) -> Bool {
        controller.recallMissionary(provinceIndex: provinceIndex)
    }

    @Callable
    public func resolveHussiteQuestion(choiceKey: String) -> Bool {
        controller.resolveHussiteQuestion(choiceKey: choiceKey)
    }

    @Callable
    public func adoptReformationReligion(religionKey: String) -> Bool {
        controller.adoptReformationReligion(religionKey: religionKey)
    }

    @Callable
    public func acceptCulture(cultureIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.acceptCulture(cultureIndex: cultureIndex))
    }

    @Callable
    public func revokeCulture(cultureIndex: Int) -> Bool {
        controller.revokeCulture(cultureIndex: cultureIndex)
    }

    @Callable
    public func advanceSimulationDays(days: Int) -> Bool {
        controller.advanceSimulationDays(days)
    }

    @Callable
    public func getFaithOverlayData() -> VariantDictionary {
        Self.toVariantDictionary(controller.faithOverlayData())
    }

    // MARK: - Phase 12: Plague, Famine, Unrest & Rebels Callables

    @Callable
    public func getProvinceCalamityDetails(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.provinceCalamityDetails(provinceIndex: provinceIndex))
    }

    @Callable
    public func setProvinceQuarantine(provinceIndex: Int, on: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.setQuarantine(provinceIndex: provinceIndex, on: on))
    }

    @Callable
    public func setProvinceCordon(provinceIndex: Int, on: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.setCordon(provinceIndex: provinceIndex, on: on))
    }

    @Callable
    public func getRebelsWindowDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.rebelsWindowDetails())
    }

    @Callable
    public func concedeToRebels(factionId: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.concedeToRebels(factionId: factionId))
    }

    @Callable
    public func sendTroopsAgainstRebels(factionId: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.sendTroopsAgainstRebels(factionId: factionId))
    }

    @Callable
    public func lowerPeasantTaxes() -> VariantDictionary {
        Self.toVariantDictionary(controller.lowerPeasantTaxes())
    }

    @Callable
    public func getCalamityOverlayData() -> VariantDictionary {
        Self.toVariantDictionary(controller.calamityOverlayData())
    }

    // MARK: - Phase 13: Technology & Institutions Callables

    @Callable
    public func getTechnologyWindowDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.technologyWindowDetails())
    }

    @Callable
    public func setTechFocus(focusKey: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.setTechFocus(key: focusKey))
    }

    @Callable
    public func embraceInstitution(institutionIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.embraceInstitution(index: institutionIndex))
    }

    @Callable
    public func getProvinceTechDetails(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.provinceTechDetails(provinceIndex: provinceIndex))
    }

    @Callable
    public func getTechOverlayData() -> VariantDictionary {
        Self.toVariantDictionary(controller.techOverlayData())
    }

    // MARK: - Phase 18: Chronicle, Ledger & Timelapse Callables

    @Callable
    public func getChronicleDetails(countryIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.chronicleDetails(countryIndex: countryIndex))
    }

    // MARK: - Step 3d2: Diplomacy, Wars, Peace & Alerts Callables

    @Callable
    public func getProvinceFocusPoint(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.provinceFocusPoint(provinceIndex: provinceIndex))
    }

    @Callable
    public func getActiveAlerts() -> VariantArray {
        Self.toVariantArray(controller.activeAlerts())
    }

    // MARK: - Phase 14: Historical & Chronicle Events Callables

    @Callable
    public func hasPendingEvent() -> Bool {
        controller.hasPendingEvent()
    }

    @Callable
    public func getPendingEventDetails() -> VariantDictionary {
        Self.toVariantDictionary(controller.pendingEventDetails())
    }

    @Callable
    public func chooseEventOption(instanceID: Int, optionIndex: Int) -> Bool {
        controller.chooseEventOption(instanceID: instanceID, optionIndex: optionIndex)
    }

    @Callable
    public func getRecentEvents() -> VariantArray {
        Self.toVariantArray(controller.recentEventsList())
    }

    @Callable
    public func getPauseOnEvents() -> Bool {
        controller.pauseOnEvents
    }

    @Callable
    public func setPauseOnEvents(enabled: Bool) -> Bool {
        controller.setPauseOnEvents(enabled)
    }

    @Callable
    public func setSelectedDiplomacyCountry(countryIndex: Int) -> Bool {
        controller.setSelectedDiplomacyCountry(countryIndex)
    }

    @Callable
    public func getDiplomacyDetails(targetCountryIndex: Int, searchQuery: String, breakTruce: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.diplomacyDetails(targetCountryIndex: targetCountryIndex, searchQuery: searchQuery, breakTruce: breakTruce))
    }

    @Callable
    public func toggleAlliance(countryIndex: Int) -> Bool {
        controller.toggleAlliance(countryIndex: countryIndex)
    }

    @Callable
    public func toggleGuarantee(countryIndex: Int) -> Bool {
        controller.toggleGuarantee(countryIndex: countryIndex)
    }

    @Callable
    public func toggleNonAggression(countryIndex: Int) -> Bool {
        controller.toggleNonAggression(countryIndex: countryIndex)
    }

    @Callable
    public func toggleMilitaryAccess(countryIndex: Int) -> Bool {
        controller.toggleMilitaryAccess(countryIndex: countryIndex)
    }

    @Callable
    public func improveRelations(countryIndex: Int) -> Bool {
        controller.improveRelations(countryIndex: countryIndex)
    }

    @Callable
    public func declareWar(targetCountryIndex: Int, cbIndex: Int, breakTruce: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.declareWar(targetCountryIndex: targetCountryIndex, cbIndex: cbIndex, breakTruce: breakTruce))
    }

    @Callable
    public func getWarsDetails(includeAIWars: Bool) -> VariantDictionary {
        Self.toVariantDictionary(controller.warsDetails(includeAIWars: includeAIWars))
    }

    @Callable
    public func callAllyToWar(allyCountryIndex: Int, warID: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.callAllyToWar(allyCountryIndex: allyCountryIndex, warID: warID))
    }

    @Callable
    public func getPeaceNegotiationDetails(
        warID: String,
        provinceIndicesCSV: String,
        indemnityAmount: Double,
        includeReparations: Bool,
        subjectMode: Int,
        releaseCountryIndicesCSV: String,
        annulPartnerIndicesCSV: String
    ) -> VariantDictionary {
        Self.toVariantDictionary(controller.peaceNegotiationDetails(
            warID: warID,
            provinceIndices: Self.parseIntCSV(provinceIndicesCSV),
            indemnityAmount: indemnityAmount,
            includeReparations: includeReparations,
            subjectMode: subjectMode,
            releaseCountryIndices: Self.parseIntCSV(releaseCountryIndicesCSV),
            annulPartnerIndices: Self.parseIntCSV(annulPartnerIndicesCSV)
        ))
    }

    @Callable
    public func proposePeaceOffer(
        warID: String,
        provinceIndicesCSV: String,
        indemnityAmount: Double,
        includeReparations: Bool,
        subjectMode: Int,
        releaseCountryIndicesCSV: String,
        annulPartnerIndicesCSV: String
    ) -> VariantDictionary {
        Self.toVariantDictionary(controller.proposePeaceOffer(
            warID: warID,
            provinceIndices: Self.parseIntCSV(provinceIndicesCSV),
            indemnityAmount: indemnityAmount,
            includeReparations: includeReparations,
            subjectMode: subjectMode,
            releaseCountryIndices: Self.parseIntCSV(releaseCountryIndicesCSV),
            annulPartnerIndices: Self.parseIntCSV(annulPartnerIndicesCSV)
        ))
    }

    @Callable
    public func respondToPendingPeaceOffer(warID: String, accept: Bool) -> Bool {
        controller.respondToPendingPeaceOffer(warID: warID, accept: accept)
    }

    // MARK: - Phase 9 Part A: Tactical Battle Bridge

    @Callable
    public func hasPendingBattlePrompt() -> Bool {
        controller.hasPendingBattlePrompt()
    }

    @Callable
    public func getPendingBattlePrompt() -> VariantDictionary {
        Self.toVariantDictionary(controller.pendingBattlePromptData())
    }

    @Callable
    public func requestStormAssaultChoice(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.requestStormAssaultChoice(provinceIndex: provinceIndex))
    }

    @Callable
    public func chooseAutoResolveBattle() -> VariantDictionary {
        Self.toVariantDictionary(controller.chooseAutoResolveBattle())
    }

    @Callable
    public func chooseLeadBattleInPerson() -> Bool {
        controller.chooseLeadBattleInPerson()
    }

    @Callable
    public func isTacticalBattleActive() -> Bool {
        controller.isTacticalBattleActive()
    }

    @Callable
    public func getBattleState() -> VariantDictionary {
        var data = controller.battleStateData()
        // Phase 17: regional styles for the 3D soldiers and walls.
        data.merge(controller.battleModelStyles()) { old, _ in old }
        return Self.toVariantDictionary(data)
    }

    @Callable
    public func deployMoveBattleUnit(unitIndex: Int, x: Double, y: Double, facing: Double) -> Bool {
        controller.deployMoveBattleUnit(unitIndex: unitIndex, x: x, y: y, facing: facing)
    }

    @Callable
    public func startTacticalBattle() -> Bool {
        controller.startTacticalBattle()
    }

    @Callable
    public func setTacticalBattleSpeed(speedIndex: Int) -> Bool {
        controller.setTacticalBattleSpeed(speedIndex: speedIndex)
    }

    @Callable
    public func tickTacticalBattle(deltaSeconds: Double) -> Int {
        controller.tickTacticalBattle(deltaSeconds: deltaSeconds)
    }

    @Callable
    public func orderBattleMove(unitIndicesCSV: String, x: Double, y: Double) -> Bool {
        controller.orderBattleMove(unitIndices: Self.parseIntCSV(unitIndicesCSV), x: x, y: y)
    }

    @Callable
    public func orderBattlePath(unitIndicesCSV: String, pointsCSV: String) -> Bool {
        controller.orderBattlePath(unitIndices: Self.parseIntCSV(unitIndicesCSV), points: Self.parsePointCSV(pointsCSV))
    }

    @Callable
    public func orderBattleFrontline(unitIndicesCSV: String, startX: Double, startY: Double, endX: Double, endY: Double) -> Bool {
        controller.orderBattleFrontline(unitIndices: Self.parseIntCSV(unitIndicesCSV), startX: startX, startY: startY, endX: endX, endY: endY)
    }

    @Callable
    public func orderBattleAttack(unitIndicesCSV: String, targetUnitIndex: Int) -> Bool {
        controller.orderBattleAttack(unitIndices: Self.parseIntCSV(unitIndicesCSV), targetUnitIndex: targetUnitIndex)
    }

    @Callable
    public func orderBattleFormation(unitIndicesCSV: String, formationKey: String) -> Bool {
        controller.orderBattleFormation(unitIndices: Self.parseIntCSV(unitIndicesCSV), formationKey: formationKey)
    }

    @Callable
    public func orderBattleStance(unitIndicesCSV: String, stanceKey: String) -> Bool {
        controller.orderBattleStance(unitIndices: Self.parseIntCSV(unitIndicesCSV), stanceKey: stanceKey)
    }

    @Callable
    public func orderBattleRetreat(unitIndicesCSV: String) -> Bool {
        controller.orderBattleRetreat(unitIndices: Self.parseIntCSV(unitIndicesCSV))
    }

    @Callable
    public func orderBattleSiegeEquipment(unitIndicesCSV: String, equipmentKey: String) -> Bool {
        controller.orderBattleSiegeEquipment(unitIndices: Self.parseIntCSV(unitIndicesCSV), equipmentKey: equipmentKey)
    }

    @Callable
    public func orderBattleAttackStructure(unitIndicesCSV: String, structureId: Int) -> Bool {
        controller.orderBattleAttackStructure(unitIndices: Self.parseIntCSV(unitIndicesCSV), structureId: structureId)
    }

    @Callable
    public func finishTacticalBattle() -> VariantDictionary {
        Self.toVariantDictionary(controller.finishTacticalBattleData())
    }

    // MARK: - Phase 16: Breakdowns & Audio Events

    @Callable
    public func getMonthlyIncomeBreakdown() -> VariantDictionary {
        Self.toVariantDictionary(controller.monthlyIncomeBreakdownData())
    }

    @Callable
    public func getManpowerBreakdown() -> VariantDictionary {
        Self.toVariantDictionary(controller.manpowerBreakdownData())
    }

    @Callable
    public func getSailorsBreakdown() -> VariantDictionary {
        Self.toVariantDictionary(controller.sailorsBreakdownData())
    }

    @Callable
    public func getArmyMoraleBreakdown(armyId: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.armyMoraleBreakdownData(armyId: armyId))
    }

    @Callable
    public func getSiegeBreakdown(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.siegeBreakdownData(provinceIndex: provinceIndex))
    }

    @Callable
    public func getStabilityBreakdown() -> VariantDictionary {
        Self.toVariantDictionary(controller.stabilityBreakdownData())
    }

    @Callable
    public func getUnrestBreakdown(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.unrestBreakdownData(provinceIndex: provinceIndex))
    }

    @Callable
    public func getResearchSpeedBreakdown(trackKey: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.researchSpeedBreakdownData(trackKey: trackKey))
    }

    @Callable
    public func getTechCostBreakdown(trackKey: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.techCostBreakdownData(trackKey: trackKey))
    }

    @Callable
    public func getRelationsBreakdown(targetCountryIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.relationsBreakdownData(targetCountryIndex: targetCountryIndex))
    }

    @Callable
    public func getRelationSlotsBreakdown() -> VariantDictionary {
        Self.toVariantDictionary(controller.relationSlotsBreakdownData())
    }

    @Callable
    public func getAIGoalBreakdown(countryIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.aiGoalBreakdownData(countryIndex: countryIndex))
    }

    @Callable
    public func getProvinceSupplyBreakdown(provinceIndex: Int) -> VariantDictionary {
        Self.toVariantDictionary(controller.provinceSupplyBreakdownData(provinceIndex: provinceIndex))
    }

    @Callable
    public func getWarScoreBreakdown(warID: String) -> VariantDictionary {
        Self.toVariantDictionary(controller.warScoreBreakdownData(warID: warID))
    }

    @Callable
    public func consumeAudioEvents() -> VariantArray {
        let out = VariantArray()
        for cue in controller.consumeAudioEvents() {
            out.append(Variant(cue))
        }
        return out
    }

    @Callable
    public func getAmbienceContext(mapX: Int, mapY: Int, zoom: Double) -> VariantDictionary {
        Self.toVariantDictionary(controller.ambienceContext(mapX: mapX, mapY: mapY, zoom: zoom))
    }

    private static func parsePointCSV(_ csv: String) -> [TacticalPoint] {
        guard !csv.isEmpty else { return [] }
        var pts: [TacticalPoint] = []
        for token in csv.split(separator: ";") {
            let parts = token.split(separator: ",")
            if parts.count == 2,
               let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let y = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                pts.append(TacticalPoint(x: x, y: y))
            }
        }
        return pts
    }

    private static func parseIntCSV(_ csv: String) -> [Int] {
        guard !csv.isEmpty else { return [] }
        return csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Variant Conversion Helpers

    // MARK: - Phase 17: 3D map models

    /// Per town icon (same order as `getTownIconsData`), stride 4:
    /// `[style, ownerR, ownerG, ownerB]`; style 0 European, 1 Islamic,
    /// 2 Indian, 3 East Asian, 4 Steppe.
    @Callable
    public func getTownModelData() -> PackedFloat32Array {
        PackedFloat32Array(controller.townModelData())
    }

    /// `{"armies": [{armyId, style, moving, nextX, nextY, frac}]}` for the 3D army figures.
    @Callable
    public func getMapArmyMotion() -> VariantDictionary {
        Self.toVariantDictionary(["armies": controller.mapArmyMotion()])
    }

    /// `{"fleetIds": [...], "styles": [...]}`: regional style of each fleet's ships.
    @Callable
    public func getMapFleetStyles() -> VariantDictionary {
        let styles = controller.mapFleetStyles()
        let ids = styles.keys.sorted()
        return Self.toVariantDictionary(["fleetIds": ids, "styles": ids.map { styles[$0] ?? 0 }])
    }

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
        case let intArr as [Int]:
            let arr = VariantArray()
            for item in intArr {
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
