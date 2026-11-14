import CoreGraphics
import Foundation
import GezCore
import Observation

/// A town icon at a province's main town, in map-pixel coordinates.
struct TownIcon {
    let province: Int
    let position: CGPoint
    let development: Int
    let fortLevel: Int
    let isCapital: Bool
    /// Coastal town big enough to keep a harbour (development 3 or more).
    let isPort: Bool
}

/// A name to draw on the map, in map-pixel coordinates.
struct MapLabel: Identifiable {
    let id: Int
    let text: String
    let position: CGPoint
    /// Rough size of the thing being labelled, in map pixels.
    let pixelArea: Double
}

/// Bridges `GameSession` (in `GezCore`) to SwiftUI. Runs a ~60 fps loop on the
/// main actor, turns real elapsed time into daily ticks via `GameSession`, and
/// publishes a `revision` counter so views redraw after each batch of ticks.
@MainActor
@Observable
final class GameModel {
    let session: GameSession
    /// GPU map renderer; nil only if Metal is unavailable (then the CPU
    /// picture in `mapImage` is used instead).
    let metal: MetalMapRenderer?

    private(set) var date: GameDate
    private(set) var revision: Int = 0

    var speed: GameSpeed = .paused {
        didSet {
            session.speed = speed
        }
    }
    var playerCountry: CountryID? {
        get {
            let _ = revision
            return session.playerCountry
        }
        set {
            session.playerCountry = newValue
            revision &+= 1
        }
    }

    // Map display
    var mapMode: MapMode = .political {
        didSet { if mapMode != oldValue { renderMap() } }
    }
    private(set) var mapImage: CGImage?
    /// Tests only: a pre-rendered Metal map shown instead of the live view,
    /// because SwiftUI snapshots can't capture Metal views.
    var snapshotMapImage: CGImage?
    private(set) var selectedProvince: ProvinceID?
    private(set) var selectedSea: SeaZoneID?
    /// Market whose prices are shown, if any.
    var openMarket: MarketID?
    var showBudget = false
    var showTrade = false
    var showCourt = false
    var showGovernment = false
    var showArmies = false
    var showDiplomacy = false
    var showWars = false
    var showGameMenu = false
    var showNationPicker = false
    var pickNationFromMap = false
    var selectedDiplomacyCountry: CountryID? {
        get {
            let _ = revision
            return session.selectedDiplomacyCountry
        }
        set {
            session.selectedDiplomacyCountry = newValue
            revision &+= 1
        }
    }
    var showPeaceForWarID: String?
    var savedGames: [SaveEntry] = []
    var lastSaveStatus: String? {
        get {
            let _ = revision
            return session.lastSaveStatus
        }
        set {
            session.lastSaveStatus = newValue
            revision &+= 1
        }
    }
    var lastAssaultResult: (province: ProvinceID, result: AssaultResult)? {
        get {
            let _ = revision
            return session.lastAssaultResult
        }
        set {
            session.lastAssaultResult = newValue
            revision &+= 1
        }
    }
    var autosaveFrequency: AutosaveFrequency = {
        if let raw = UserDefaults.standard.string(forKey: "gez.autosaveFrequency"),
           let parsed = AutosaveFrequency(rawValue: raw) {
            return parsed
        }
        return .yearly
    }() {
        didSet {
            session.autosaveFrequency = autosaveFrequency
            UserDefaults.standard.set(autosaveFrequency.rawValue, forKey: "gez.autosaveFrequency")
        }
    }
    /// Selected army in the Armies panel or on the map.
    var selectedArmy: ArmyID? {
        get {
            let _ = revision
            return session.selectedArmy
        }
        set {
            session.selectedArmy = newValue
            revision &+= 1
        }
    }
    /// When set, tapping a province on the map orders this army to march there.
    var moveModeForArmy: ArmyID? {
        get {
            let _ = revision
            return session.moveModeForArmy
        }
        set {
            session.moveModeForArmy = newValue
            revision &+= 1
        }
    }
    /// Person shown in the court window (nil = your ruler).
    var viewedCharacter: CharacterID? {
        get {
            let _ = revision
            return session.viewedCharacter
        }
        set {
            session.viewedCharacter = newValue
            revision &+= 1
        }
    }
    /// Map positions of market towns, for drawing trade routes.
    private(set) var marketCentrePoints: [CGPoint] = []
    /// Map positions of each province's main town, indexed by `ProvinceID.index`.
    private(set) var provincePositions: [CGPoint] = []
    /// A route being planned in the trade window.
    var draftGood: GoodID?
    var draftFrom: MarketID?
    var draftTo: MarketID?
    var draftVolume: Double = 25
    private(set) var seaLabels: [MapLabel] = []
    private(set) var selectionOverlay: (image: CGImage, box: CGRect)?
    private(set) var countryLabels: [MapLabel] = []
    private(set) var provinceLabels: [MapLabel] = []
    private(set) var townIcons: [TownIcon] = []

    @ObservationIgnored private var lastUpdate: Date?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var renderGeneration = 0

    /// `useMetal: false` forces the CPU-drawn map (tests use it).
    init(useMetal: Bool = true) {
        let sess: GameSession
        do {
            sess = try GameSession()
        } catch {
            preconditionFailure("Could not start GameSession: \(error)")
        }
        self.session = sess
        self.metal = useMetal ? MetalMapRenderer.makeDevice().flatMap { MetalMapRenderer(device: $0, idMap: sess.idMap, seaMap: sess.seaMap) } : nil
        self.date = sess.date
        sess.autosaveFrequency = autosaveFrequency
        self.savedGames = sess.savedGames
        syncLabelsFromSession()
        renderMap()
        startLoop()
    }

    var simulation: Simulation { session.simulation }
    var idMap: ProvinceIDMap { session.idMap }
    var seaMap: ProvinceIDMap { session.seaMap }
    var geometry: MapGeometry { session.geometry }
    var playerTag: String? { session.playerTag }
    var world: World { session.world }

    // MARK: - Time

    func togglePause() {
        session.togglePause()
        speed = session.speed
    }

    func faster() {
        session.faster()
        speed = session.speed
    }

    func slower() {
        session.slower()
        speed = session.speed
    }

    private func startLoop() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                self?.update()
            }
        }
    }

    private func update() {
        let now = Date()
        defer { lastUpdate = now }
        guard let last = lastUpdate else { return }
        let outcome = session.advanceTime(elapsedSeconds: now.timeIntervalSince(last))
        guard outcome.daysAdvanced > 0 else { return }
        date = session.date
        if outcome.didAutosave {
            savedGames = session.savedGames
        }
        if outcome.monthChanged || outcome.warsCountChanged {
            renderMap()
        }
        revision &+= 1
    }

    // MARK: - Map

    func select(sea: SeaZoneID?) {
        session.select(sea: sea)
        selectedSea = session.selectedSea
        metal?.selectedSeaValue = sea.map { UInt32($0.index + 1) } ?? 0
        if sea != nil { select(province: nil, keepSea: true) }
    }

    /// Orders a building for the player. Returns why not, if it can't.
    @discardableResult
    func build(_ type: BuildingTypeID, in province: ProvinceID) -> BuildingSystem.Refusal? {
        let result = session.build(type, in: province)
        revision &+= 1
        return result
    }

    // MARK: Budget actions (player only)

    func setTax(_ c: TaxClass, level: Double) {
        session.setTax(c, level: level)
        revision &+= 1
    }

    func borrow(from bank: BankID, amount: Double) {
        session.borrow(from: bank, amount: amount)
        revision &+= 1
    }

    func repay(loan index: Int) {
        session.repay(loan: index)
        revision &+= 1
    }

    func debaseOnce() {
        session.debaseOnce()
        revision &+= 1
    }

    func setDebasing(_ on: Bool) {
        session.setDebasing(on)
        revision &+= 1
    }

    // MARK: Court actions (player only)

    func appoint(_ seat: CouncilSeat, _ who: CharacterID?) {
        session.appoint(seat, who)
        revision &+= 1
    }

    func appointNewcomer(_ seat: CouncilSeat) {
        session.appointNewcomer(seat)
        revision &+= 1
    }

    /// Best foreign matches (bigger realms first).
    func marriageCandidates(for x: CharacterID) -> [CharacterID] {
        session.marriageCandidates(for: x)
    }

    func propose(_ a: CharacterID, _ b: CharacterID) {
        session.propose(a, b)
        revision &+= 1
    }

    // MARK: Government actions (player only)

    func raiseStability() {
        session.raiseStability()
        revision &+= 1
    }

    @discardableResult
    func changeLaw(area: Int, option: Int) -> GovernmentSystem.LawRefusal? {
        let r = session.changeLaw(area: area, option: option)
        revision &+= 1
        return r
    }

    func grantPrivilege(_ privilege: Int) {
        session.grantPrivilege(privilege)
        revision &+= 1
    }

    func revokePrivilege(_ privilege: Int) {
        session.revokePrivilege(privilege)
        revision &+= 1
    }

    func adoptReform(_ option: Int) {
        session.adoptReform(option)
        revision &+= 1
    }

    // MARK: Vassal actions (player only)

    func grant(_ province: ProvinceID, to x: CharacterID) {
        session.grant(province, to: x)
        revision &+= 1
    }

    func revoke(_ province: ProvinceID) {
        session.revoke(province)
        revision &+= 1
    }

    // MARK: Military actions (player only)

    @discardableResult
    func recruitProfessional(_ unit: UnitTypeID, in province: ProvinceID, into army: ArmyID? = nil) -> ArmyRefusal? {
        let res = session.recruitProfessional(unit, in: province, into: army)
        revision &+= 1
        return res
    }

    @discardableResult
    func hireMercenary(_ unit: UnitTypeID, in province: ProvinceID, into army: ArmyID? = nil) -> ArmyRefusal? {
        let res = session.hireMercenary(unit, in: province, into: army)
        revision &+= 1
        return res
    }

    @discardableResult
    func raiseLevies(in province: ProvinceID) -> ArmyRefusal? {
        let res = session.raiseLevies(in: province)
        revision &+= 1
        return res
    }

    func raiseAllLevies() {
        session.raiseAllLevies()
        revision &+= 1
    }

    func disbandLevies() {
        session.disbandLevies()
        revision &+= 1
    }

    func disband(army: ArmyID) {
        session.disband(army: army)
        revision &+= 1
    }

    func assignCommander(_ commander: CharacterID?, to army: ArmyID) {
        session.assignCommander(commander, to: army)
        revision &+= 1
    }

    func mergeArmies(into army: ArmyID) {
        session.mergeArmies(into: army)
        revision &+= 1
    }

    func split(army: ArmyID) {
        session.split(army: army)
        revision &+= 1
    }

    func orderMove(army: ArmyID, to destination: ProvinceID) {
        session.orderMove(army: army, to: destination)
        revision &+= 1
    }

    // MARK: Trade actions (player only)

    @discardableResult
    func createRoute() -> TradeSystem.Refusal? {
        guard let g = draftGood, let a = draftFrom, let b = draftTo else { return .noPath }
        let r = session.createRoute(good: g, from: a, to: b, volume: draftVolume)
        revision &+= 1
        return r
    }

    func cancelRoute(_ index: Int) {
        session.cancelRoute(index)
        revision &+= 1
    }

    func setTollPolicy(_ policy: TollPolicy) {
        session.setTollPolicy(policy)
        revision &+= 1
    }

    func toggleEmbargo(_ c: CountryID) {
        session.toggleEmbargo(c)
        revision &+= 1
    }

    /// Opens the trade window with a route into this market planned.
    func planImport(_ good: GoodID, into market: MarketID) {
        draftGood = good
        draftTo = market
        draftFrom = nil
        showTrade = true
    }

    // MARK: Diplomacy & War actions (player only)

    func openDiplomacy(with target: CountryID? = nil) {
        showBudget = false
        showTrade = false
        showCourt = false
        showGovernment = false
        showArmies = false
        showWars = false
        if let target {
            session.selectedDiplomacyCountry = target
        } else if session.selectedDiplomacyCountry == nil {
            session.selectedDiplomacyCountry = world.countries.ids.first(where: { $0 != playerCountry && !world.provinces(ownedBy: $0).isEmpty })
        }
        showDiplomacy = true
        revision &+= 1
    }

    func toggleAlliance(with target: CountryID) {
        session.toggleAlliance(with: target)
        renderMap()
        revision &+= 1
    }

    func toggleGuarantee(with target: CountryID) {
        session.toggleGuarantee(with: target)
        renderMap()
        revision &+= 1
    }

    func toggleNonAggression(with target: CountryID) {
        session.toggleNonAggression(with: target)
        revision &+= 1
    }

    func toggleMilitaryAccess(with target: CountryID) {
        session.toggleMilitaryAccess(with: target)
        revision &+= 1
    }

    func improveRelations(with target: CountryID) {
        session.improveRelations(with: target)
        revision &+= 1
    }

    @discardableResult
    func declareWar(on target: CountryID, cb: CasusBelliInstance, breakTruce: Bool = false) -> Result<War, WarDeclarationError> {
        let res = session.declareWar(on: target, cb: cb, breakTruce: breakTruce)
        if case .success = res {
            showDiplomacy = false
            showWars = true
            renderMap()
        }
        revision &+= 1
        return res
    }

    @discardableResult
    func callAllyToWar(_ ally: CountryID, warID: String) -> CallToArmsResult {
        let res = session.callAllyToWar(ally, warID: warID)
        renderMap()
        revision &+= 1
        return res
    }

    @discardableResult
    func proposePeace(_ offer: PeaceOffer) -> Result<Int, PeaceTreatyError> {
        let res = session.proposePeace(offer)
        if case .success = res {
            showPeaceForWarID = nil
            rebuildTownIcons()
            renderMap()
        }
        revision &+= 1
        return res
    }

    func respondToPendingPeaceOffer(_ offer: PeaceOffer, accept: Bool) {
        session.respondToPendingPeaceOffer(offer, accept: accept)
        if accept {
            rebuildTownIcons()
            renderMap()
        }
        revision &+= 1
    }

    // MARK: - Sieges, Saves & Nation Selection

    @discardableResult
    func assaultFort(in province: ProvinceID) -> AssaultResult {
        let result = session.assaultFort(in: province)
        if result.captured {
            renderMap()
        }
        revision &+= 1
        return result
    }

    func switchPlayer(to country: CountryID) {
        session.switchPlayer(to: country)
        pickNationFromMap = false
        showNationPicker = false
        renderMap()
        revision &+= 1
    }

    func startNewGame(tag: String, seed: UInt64 = 1453) {
        session.startNewGame(tag: tag, seed: seed)
        speed = session.speed
        date = session.date
        resetPanelsAndSelection()
        syncLabelsFromSession()
        renderMap()
        revision &+= 1
    }

    func refreshSavedGames() {
        session.refreshSavedGames()
        savedGames = session.savedGames
    }

    func saveGame(named name: String) {
        session.saveGame(named: name)
        savedGames = session.savedGames
        revision &+= 1
    }

    func quickSave() {
        session.quickSave()
        savedGames = session.savedGames
        revision &+= 1
    }

    func loadGame(_ entry: SaveEntry) {
        if session.loadGame(entry) {
            speed = session.speed
            date = session.date
            resetPanelsAndSelection()
            syncLabelsFromSession()
            renderMap()
        }
        revision &+= 1
    }

    func deleteSave(_ entry: SaveEntry) {
        session.deleteSave(entry)
        savedGames = session.savedGames
        revision &+= 1
    }

    private func resetPanelsAndSelection() {
        showBudget = false
        showTrade = false
        showCourt = false
        showGovernment = false
        showArmies = false
        showDiplomacy = false
        showWars = false
        showGameMenu = false
        showNationPicker = false
        pickNationFromMap = false
        showPeaceForWarID = nil
        openMarket = nil
        select(province: nil)
    }

    func select(province: ProvinceID?, keepSea: Bool = false) {
        if !keepSea && selectedSea != nil {
            selectedSea = nil
            metal?.selectedSeaValue = 0
        }
        session.select(province: province, keepSea: keepSea)
        selectedProvince = session.selectedProvince
        metal?.selectedValue = province.map { UInt32($0.index + 2) } ?? 0
        if let province {
            selectionOverlay = MapRenderer.selectionOverlay(province: province, map: idMap, geometry: geometry)
                .map { (image: $0.0, box: $0.1) }
        } else {
            selectionOverlay = nil
        }
    }

    func select(mapX x: Int, y: Int) {
        if let hit = idMap.province(x: x, y: y) {
            if pickNationFromMap {
                if let owner = world.provinces.owner[hit.index] {
                    switchPlayer(to: owner)
                }
                return
            }
            if let moving = moveModeForArmy {
                orderMove(army: moving, to: hit)
                return
            }
            select(province: hit == selectedProvince ? nil : hit)
        } else if let sea = seaMap.seaZone(x: x, y: y) {
            select(sea: sea == selectedSea ? nil : sea)
        } else {
            select(province: nil)
        }
    }

    /// Redraws the whole map image in the background. Call after a map mode
    /// change or when provinces change owner.
    func renderMap() {
        if let metal {
            metal.updateStyles(world: world, mode: mapMode, player: playerCountry)
            return
        }
        renderGeneration += 1
        let generation = renderGeneration
        let keys = MapRenderer.keys(world: world)
        let input = MapRenderer.Input(
            map: idMap,
            colors: MapPalette.colors(for: mapMode, world: world, player: playerCountry),
            ownerKey: keys.owner,
            stateKey: keys.state,
            rivers: world.rivers.map { river in river.points.map { CGPoint(x: $0.x, y: $0.y) } }
        )
        Task.detached(priority: .userInitiated) {
            let image = MapRenderer.render(input)
            await MainActor.run { [weak self] in
                guard let self, generation == self.renderGeneration else { return }
                self.mapImage = image
            }
        }
    }

    /// Rebuild town icons (call when development, forts or owners change).
    func rebuildTownIcons() {
        session.rebuildTownIcons()
        syncTownIconsFromSession()
    }

    private func syncTownIconsFromSession() {
        townIcons = session.townIcons.map {
            TownIcon(
                province: $0.province,
                position: CGPoint(x: $0.x, y: $0.y),
                development: $0.development,
                fortLevel: $0.fortLevel,
                isCapital: $0.isCapital,
                isPort: $0.isPort
            )
        }
        provincePositions = session.provincePositions.map { CGPoint(x: $0.x, y: $0.y) }
        marketCentrePoints = session.marketCentrePoints.map { CGPoint(x: $0.x, y: $0.y) }
    }

    private func syncLabelsFromSession() {
        syncTownIconsFromSession()
        countryLabels = session.countryLabels.map {
            MapLabel(id: $0.id, text: $0.text, position: CGPoint(x: $0.x, y: $0.y), pixelArea: $0.pixelArea)
        }
        provinceLabels = session.provinceLabels.map {
            MapLabel(id: $0.id, text: $0.text, position: CGPoint(x: $0.x, y: $0.y), pixelArea: $0.pixelArea)
        }
        seaLabels = session.seaLabels.map {
            MapLabel(id: $0.id, text: $0.text, position: CGPoint(x: $0.x, y: $0.y), pixelArea: $0.pixelArea)
        }
    }
}
