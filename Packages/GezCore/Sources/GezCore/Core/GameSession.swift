import Foundation

/// Pure-Swift session controller shared between the Apple app and the Godot
/// GDExtension. Owns the running `Simulation`, `GameClock`, speed/pause state,
/// player country, map ID maps, labels, saves, player actions, and screen queries.
public final class GameSession {
    public private(set) var simulation: Simulation
    public let idMap: ProvinceIDMap
    public let seaMap: ProvinceIDMap
    public let geometry: MapGeometryData

    public private(set) var date: GameDate
    public private(set) var revision: Int = 0

    public var speed: GameSpeed = .paused {
        didSet {
            clock.speed = speed
            if speed != .paused { lastRunningSpeed = speed }
        }
    }
    public var playerCountry: CountryID?

    public private(set) var selectedProvince: ProvinceID?
    public private(set) var selectedSea: SeaZoneID?
    public var selectedArmy: ArmyID?
    public var moveModeForArmy: ArmyID?
    public var selectedFleet: FleetID?
    public var moveModeForFleet: FleetID?
    public var viewedCharacter: CharacterID?
    public var selectedDiplomacyCountry: CountryID?

    public var savedGames: [SaveEntry] = []
    public var lastSaveStatus: String?
    public var lastAssaultResult: (province: ProvinceID, result: AssaultResult)?
    public var autosaveFrequency: AutosaveFrequency = .yearly
    public var savesDirectory: URL?

    public private(set) var townIcons: [TownIconInfo] = []
    public private(set) var provincePositions: [(x: Double, y: Double)] = []
    public private(set) var marketCentrePoints: [(x: Double, y: Double)] = []
    public private(set) var countryLabels: [MapLabelInfo] = []
    public private(set) var provinceLabels: [MapLabelInfo] = []
    public private(set) var seaLabels: [MapLabelInfo] = []

    private var clock = GameClock()
    private var lastRunningSpeed: GameSpeed = .two
    private var speedBeforeBattlePrompt: GameSpeed?
    /// When true (default), newly arriving historical or chronicle events pause the game.
    public var pauseOnEvents: Bool = true
    private var pausedForEventIDs: Set<Int> = []

    /// Interactive battle view support (enabled by Godot front-end; left false for App/ and pure simulation tests).
    public var interactiveBattlesEnabled: Bool = false {
        didSet {
            simulation.interceptHumanBattles = interactiveBattlesEnabled
        }
    }
    public private(set) var pendingBattlePrompt: PendingBattlePrompt?
    public var tacticalBattle: BattleEngine?
    public private(set) var lastTacticalBattleResult: TacticalBattleResult?

    public struct AdvanceOutcome: Sendable {
        public let daysAdvanced: Int
        public let monthChanged: Bool
        public let warsCountChanged: Bool
        public let didAutosave: Bool
    }

    public init(
        tag: String = Scenario1453.defaultPlayerTag,
        seed: UInt64 = 1453,
        savesDirectory: URL? = nil,
        aiSetting: AIBehaviourSetting = .historical
    ) throws {
        var initialWorld = Scenario1453.makeWorld()
        initialWorld.ai.setting = aiSetting
        let sim = Simulation(world: initialWorld, startDate: Scenario1453.startDate, seed: seed)
        let map = try ProvinceIDMap.loadBundled()
        let seas = try ProvinceIDMap.loadBundledSeas()
        self.simulation = sim
        self.idMap = map
        self.seaMap = seas
        self.geometry = MapGeometryData(map: map, provinceCount: sim.world.provinces.count)
        self.date = sim.date
        self.savesDirectory = savesDirectory
        let picked = sim.world.countries.id(forTag: tag) ?? sim.world.countries.id(forTag: Scenario1453.defaultPlayerTag)
        self.playerCountry = picked
        if let picked {
            sim.world.humanCountries = [picked]
        }
        AIGoalSystem.updateGoals(&sim.world, date: sim.date)
        refreshSavedGames()
        rebuildLabels()
    }

    public var aiSetting: AIBehaviourSetting {
        simulation.world.ai.setting
    }

    public func aiGoalSummary(for country: CountryID) -> String {
        AIGoalSystem.goalSummaryText(for: country, in: world)
    }

    public var playerTag: String? {
        playerCountry.map { world.countries.tag[$0.index] }
    }

    public var world: World { simulation.world }

    // MARK: - Time & Game Loop

    public func togglePause() {
        speed = (speed == .paused) ? lastRunningSpeed : .paused
    }

    public func faster() {
        if let next = GameSpeed(rawValue: min(speed.rawValue + 1, GameSpeed.five.rawValue)) {
            speed = next
        }
    }

    public func slower() {
        if let next = GameSpeed(rawValue: max(speed.rawValue - 1, GameSpeed.one.rawValue)) {
            speed = next
        }
    }

    /// Advances the simulation based on real elapsed seconds and current `speed`.
    @discardableResult
    public func advanceTime(elapsedSeconds: Double) -> AdvanceOutcome {
        let days = clock.daysToAdvance(elapsedSeconds: elapsedSeconds)
        return advanceDays(days)
    }

    /// Advances the simulation by an explicit number of days.
    @discardableResult
    public func advanceDays(_ days: Int) -> AdvanceOutcome {
        guard days > 0, pendingBattlePrompt == nil, tacticalBattle == nil else {
            return AdvanceOutcome(daysAdvanced: 0, monthChanged: false, warsCountChanged: false, didAutosave: false)
        }
        simulation.interceptHumanBattles = interactiveBattlesEnabled
        let prevMonth = simulation.date.month
        let prevWars = simulation.world.diplomacy.wars.count
        var didAutosave = false
        var actualDays = 0
        for _ in 0..<days {
            simulation.tick()
            actualDays += 1
            if autosaveFrequency.shouldAutosave(on: simulation.date) {
                if (try? SaveStorage.autosave(simulation, playerTag: playerTag, in: savesDirectory)) != nil {
                    didAutosave = true
                }
            }
            if interactiveBattlesEnabled, let bid = simulation.pendingHumanBattleID {
                refreshPendingPrompt(forBattleID: bid)
                if pendingBattlePrompt != nil {
                    speedBeforeBattlePrompt = speed
                    speed = .paused
                    break
                } else {
                    simulation.pendingHumanBattleID = nil
                }
            }
            if pauseOnEvents,
               let player = playerCountry,
               let ev = simulation.world.events.pendingEvent(for: player),
               !pausedForEventIDs.contains(ev.instanceID) {
                pausedForEventIDs.insert(ev.instanceID)
                speed = .paused
                break
            }
        }
        date = simulation.date
        if didAutosave {
            lastSaveStatus = "Autosaved (\(date))"
            refreshSavedGames()
        }
        revision &+= 1
        return AdvanceOutcome(
            daysAdvanced: actualDays,
            monthChanged: date.month != prevMonth,
            warsCountChanged: simulation.world.diplomacy.wars.count != prevWars,
            didAutosave: didAutosave
        )
    }

    // MARK: - Map Selection & Labels

    public func select(province: ProvinceID?, keepSea: Bool = false) {
        if !keepSea && selectedSea != nil {
            selectedSea = nil
        }
        selectedProvince = province
    }

    public func select(sea: SeaZoneID?) {
        selectedSea = sea
        if sea != nil {
            select(province: nil, keepSea: true)
        }
    }

    public func rebuildTownIcons() {
        let built = MapStyling.buildTownIcons(world: world, idMap: idMap)
        townIcons = built.townIcons
        provincePositions = built.provincePositions
        marketCentrePoints = built.marketCentres
    }

    public func rebuildLabels() {
        rebuildTownIcons()
        let built = MapStyling.buildLabels(world: world, idMap: idMap, seaMap: seaMap, geometry: geometry)
        countryLabels = built.countryLabels
        provinceLabels = built.provinceLabels
        seaLabels = built.seaLabels
    }

    // MARK: - Buildings

    @discardableResult
    public func build(_ type: BuildingTypeID, in province: ProvinceID) -> BuildingSystem.Refusal? {
        guard let player = playerCountry else { return .notOwner }
        let result = BuildingSystem.start(&simulation.world, player, province, type)
        revision &+= 1
        return result
    }

    // MARK: - Budget & Finance

    public func setTax(_ c: TaxClass, level: Double) {
        guard let p = playerCountry else { return }
        simulation.world.countries.taxLevel[p.index][c.rawValue] = min(Finance.maxTaxLevel, max(0, level))
        revision &+= 1
    }

    public func borrow(from bank: BankID, amount: Double) {
        guard let p = playerCountry else { return }
        FinanceSystem.borrow(&simulation.world, p, from: bank, amount: amount)
        revision &+= 1
    }

    public func repay(loan index: Int) {
        FinanceSystem.repay(&simulation.world, loan: index)
        revision &+= 1
    }

    @discardableResult
    public func debaseOnce() -> Double {
        guard let p = playerCountry else { return 0 }
        let amount = FinanceSystem.debaseOnce(&simulation.world, p)
        revision &+= 1
        return amount
    }

    public func setDebasing(_ on: Bool) {
        guard let p = playerCountry,
              simulation.world.countries.bankruptMonthsLeft[p.index] == 0 || !on,
              GovernmentSystem.canDebase(simulation.world, p) || !on else { return }
        simulation.world.countries.debasing[p.index] = on
        revision &+= 1
    }

    // MARK: - Court & Characters

    public func appoint(_ seat: CouncilSeat, _ who: CharacterID?) {
        guard let p = playerCountry else { return }
        CharacterSystem.appoint(&simulation.world, p, seat, who)
        revision &+= 1
    }

    public func appointNewcomer(_ seat: CouncilSeat) {
        guard let p = playerCountry else { return }
        var rng = GameRandom(seed: UInt64(simulation.world.people.characters.count) &* 7919 &+ UInt64(date.ordinal))
        let home = simulation.world.provinces(ownedBy: p).first.map { "of \(simulation.world.provinces.name[$0.index])" }
        let who = CharacterSystem.invent(&simulation.world, court: p, date: date, random: &rng, dynasty: home)
        CharacterSystem.appoint(&simulation.world, p, seat, who)
        revision &+= 1
    }

    public func marriageCandidates(for x: CharacterID) -> [CharacterID] {
        guard let p = playerCountry else { return [] }
        let w = world
        var pool: [CharacterID] = []
        for c in w.countries.ids where c != p {
            pool += CharacterSystem.marriageableFamily(w, c, date: date)
        }
        return pool
            .filter { CharacterSystem.marriageRefusal(w, x, $0, date: date) == nil }
            .sorted { a, b in
                let pa = w.people.characters.court[a.index].map { w.provinces(ownedBy: $0).count } ?? 0
                let pb = w.people.characters.court[b.index].map { w.provinces(ownedBy: $0).count } ?? 0
                return pa != pb ? pa > pb : a.index < b.index
            }
            .prefix(10).map { $0 }
    }

    public func propose(_ a: CharacterID, _ b: CharacterID) {
        guard CharacterSystem.marriageRefusal(world, a, b, date: date) == nil else { return }
        CharacterSystem.marry(&simulation.world, a, b)
        revision &+= 1
    }

    // MARK: - Government, Laws & Estates

    public func raiseStability() {
        guard let p = playerCountry else { return }
        GovernmentSystem.raiseStability(&simulation.world, p)
        revision &+= 1
    }

    @discardableResult
    public func changeLaw(area: Int, option: Int) -> GovernmentSystem.LawRefusal? {
        guard let p = playerCountry else { return .notAllowed }
        let r = GovernmentSystem.changeLaw(&simulation.world, p, area: area, option: option, date: date)
        revision &+= 1
        return r
    }

    public func grantPrivilege(_ privilege: Int) {
        guard let p = playerCountry else { return }
        GovernmentSystem.grantPrivilege(&simulation.world, p, privilege, date: date)
        revision &+= 1
    }

    public func revokePrivilege(_ privilege: Int) {
        guard let p = playerCountry else { return }
        GovernmentSystem.revokePrivilege(&simulation.world, p, privilege, date: date)
        revision &+= 1
    }

    public func adoptReform(_ option: Int) {
        guard let p = playerCountry else { return }
        GovernmentSystem.adoptReform(&simulation.world, p, option: option, date: date)
        revision &+= 1
    }

    // MARK: - Vassals

    public func grant(_ province: ProvinceID, to x: CharacterID) {
        guard let p = playerCountry, world.provinces.owner[province.index] == p else { return }
        VassalSystem.grant(&simulation.world, province, to: x, date: date)
        revision &+= 1
    }

    public func revoke(_ province: ProvinceID) {
        guard let p = playerCountry, world.provinces.owner[province.index] == p else { return }
        VassalSystem.revoke(&simulation.world, province, date: date)
        revision &+= 1
    }

    // MARK: - Military

    @discardableResult
    public func recruitProfessional(_ unit: UnitTypeID, in province: ProvinceID, into army: ArmyID? = nil) -> ArmyRefusal? {
        guard let p = playerCountry else { return .notOwner }
        let res = ArmySystem.recruitProfessional(&simulation.world, p, in: province, unit: unit, intoArmy: army)
        revision &+= 1
        switch res {
        case .success(let aid):
            selectedArmy = aid
            return nil
        case .failure(let err):
            return err
        }
    }

    @discardableResult
    public func hireMercenary(_ unit: UnitTypeID, in province: ProvinceID, into army: ArmyID? = nil) -> ArmyRefusal? {
        guard let p = playerCountry else { return .notOwner }
        let res = ArmySystem.hireMercenary(&simulation.world, p, in: province, unit: unit, intoArmy: army)
        revision &+= 1
        switch res {
        case .success(let aid):
            selectedArmy = aid
            return nil
        case .failure(let err):
            return err
        }
    }

    @discardableResult
    public func raiseLevies(in province: ProvinceID) -> ArmyRefusal? {
        guard let p = playerCountry else { return .notOwner }
        let res = ArmySystem.raiseLevies(&simulation.world, p, in: province)
        revision &+= 1
        switch res {
        case .success(let aid):
            selectedArmy = aid
            return nil
        case .failure(let err):
            return err
        }
    }

    public func raiseAllLevies() {
        guard let p = playerCountry else { return }
        ArmySystem.raiseAllLevies(&simulation.world, p)
        revision &+= 1
    }

    public func disbandLevies() {
        guard let p = playerCountry else { return }
        ArmySystem.disbandLevies(&simulation.world, of: p)
        revision &+= 1
    }

    public func disband(army: ArmyID) {
        guard let p = playerCountry else { return }
        let i = Int(army.rawValue)
        guard i >= 0 && i < world.military.armies.count && world.military.armies.owner[i] == p else { return }
        ArmySystem.disband(&simulation.world, army: army)
        if selectedArmy == army { selectedArmy = nil }
        if moveModeForArmy == army { moveModeForArmy = nil }
        revision &+= 1
    }

    public func assignCommander(_ commander: CharacterID?, to army: ArmyID) {
        guard let p = playerCountry else { return }
        let i = Int(army.rawValue)
        guard i >= 0 && i < world.military.armies.count && world.military.armies.owner[i] == p else { return }
        ArmySystem.assignCommander(&simulation.world, army: army, commander: commander)
        revision &+= 1
    }

    public func mergeArmies(into army: ArmyID) {
        guard let p = playerCountry else { return }
        let i = Int(army.rawValue)
        guard i >= 0 && i < world.military.armies.count && world.military.armies.owner[i] == p else { return }
        ArmySystem.mergeArmiesInProvince(&simulation.world, into: army)
        revision &+= 1
    }

    public func split(army: ArmyID) {
        guard let p = playerCountry else { return }
        let i = Int(army.rawValue)
        guard i >= 0 && i < world.military.armies.count && world.military.armies.owner[i] == p else { return }
        if let created = ArmySystem.splitArmy(&simulation.world, army: army) {
            selectedArmy = created
        }
        revision &+= 1
    }

    public func orderMove(army: ArmyID, to destination: ProvinceID) {
        guard let p = playerCountry else { return }
        let i = Int(army.rawValue)
        guard i >= 0 && i < world.military.armies.count && world.military.armies.owner[i] == p
            && !world.military.armies.isRebel[i] else { return }
        ArmySystem.orderMove(&simulation.world, army: army, to: destination)
        moveModeForArmy = nil
        revision &+= 1
    }

    // MARK: - Navies (Phase 10)

    @discardableResult
    public func buildShip(_ type: ShipTypeID, in province: ProvinceID, into fleet: FleetID? = nil) -> NavyRefusal? {
        guard let p = playerCountry else { return .notOwner }
        let res = NavySystem.startShipConstruction(&simulation.world, p, in: province, type: type, targetFleet: fleet)
        revision &+= 1
        switch res {
        case .success: return nil
        case .failure(let err): return err
        }
    }

    public func assignAdmiral(_ admiral: CharacterID?, to fleet: FleetID) {
        guard let p = playerCountry else { return }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return }
        NavySystem.assignAdmiral(&simulation.world, fleet: fleet, admiral: admiral)
        revision &+= 1
    }

    @discardableResult
    public func mergeFleets(into fleet: FleetID) -> Int {
        guard let p = playerCountry else { return 0 }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return 0 }
        let merged = NavySystem.mergeFleetsInLocation(&simulation.world, into: fleet)
        revision &+= 1
        return merged
    }

    @discardableResult
    public func split(fleet: FleetID) -> FleetID? {
        guard let p = playerCountry else { return nil }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return nil }
        let created = NavySystem.splitFleet(&simulation.world, fleet: fleet)
        if let created {
            selectedFleet = created
        }
        revision &+= 1
        return created
    }

    @discardableResult
    public func orderMoveFleet(_ fleet: FleetID, toSea sea: SeaZoneID) -> Bool {
        guard let p = playerCountry else { return false }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return false }
        let ok = NavySystem.orderMoveFleet(&simulation.world, fleet, toSea: sea)
        if ok {
            simulation.world.navy.fleets.mission[i] = .patrol
        }
        moveModeForFleet = nil
        revision &+= 1
        return ok
    }

    @discardableResult
    public func orderDockFleet(_ fleet: FleetID, inPort port: ProvinceID) -> Bool {
        guard let p = playerCountry else { return false }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return false }
        let ok = NavySystem.orderDockFleet(&simulation.world, fleet, inPort: port)
        if ok {
            simulation.world.navy.fleets.mission[i] = .idle
        }
        moveModeForFleet = nil
        revision &+= 1
        return ok
    }

    @discardableResult
    public func orderBlockadeFleet(_ fleet: FleetID, inSea sea: SeaZoneID) -> Bool {
        guard let p = playerCountry else { return false }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return false }
        let ok = NavySystem.orderMoveFleet(&simulation.world, fleet, toSea: sea)
        if ok {
            simulation.world.navy.fleets.mission[i] = .blockade
        }
        moveModeForFleet = nil
        revision &+= 1
        return ok
    }

    @discardableResult
    public func embarkArmy(_ army: ArmyID, onto fleet: FleetID) -> Bool {
        let ok = NavySystem.embarkArmy(&simulation.world, army: army, onto: fleet)
        revision &+= 1
        return ok
    }

    @discardableResult
    public func disembarkArmy(_ army: ArmyID, to destination: ProvinceID? = nil) -> Bool {
        let ok = NavySystem.disembarkArmy(&simulation.world, army: army, to: destination)
        revision &+= 1
        return ok
    }

    @discardableResult
    public func orderTransportAndLand(fleet: FleetID, to destination: ProvinceID) -> Bool {
        guard let p = playerCountry else { return false }
        let i = fleet.index
        guard i >= 0 && i < world.navy.fleets.count && world.navy.fleets.alive[i] && world.navy.fleets.owner[i] == p else { return false }
        let ok = NavySystem.orderTransportAndLand(&simulation.world, fleet: fleet, to: destination)
        moveModeForFleet = nil
        revision &+= 1
        return ok
    }

    // MARK: - Trade

    @discardableResult
    public func createRoute(good: GoodID, from: MarketID, to: MarketID, volume: Double) -> TradeSystem.Refusal? {
        guard let p = playerCountry else { return .noPath }
        let r = TradeSystem.create(&simulation.world, owner: p, good: good, from: from, to: to, volume: volume)
        revision &+= 1
        return r
    }

    public func cancelRoute(_ index: Int) {
        TradeSystem.cancel(&simulation.world, route: index)
        revision &+= 1
    }

    public func setTollPolicy(_ policy: TollPolicy) {
        guard let p = playerCountry else { return }
        simulation.world.countries.tollPolicy[p.index] = policy
        TradeSystem.refreshPaths(&simulation.world)
        revision &+= 1
    }

    public func toggleEmbargo(_ c: CountryID) {
        guard let p = playerCountry, c != p else { return }
        if simulation.world.countries.embargoes[p.index].contains(c) {
            simulation.world.countries.embargoes[p.index].remove(c)
        } else {
            simulation.world.countries.embargoes[p.index].insert(c)
        }
        TradeSystem.refreshPaths(&simulation.world)
        revision &+= 1
    }

    // MARK: - Diplomacy & War

    public func toggleAlliance(with target: CountryID) {
        guard let p = playerCountry, target != p else { return }
        if world.diplomacy.areAllies(p, target) {
            simulation.world.diplomacy.removeTreaty(.alliance, between: p, and: target)
        } else {
            guard world.diplomacy.opinion(of: p, by: target) >= 0,
                  !world.diplomacy.isAtWar(p, target),
                  !world.diplomacy.hasTruce(p, target) else { return }
            simulation.world.diplomacy.addTreaty(Treaty(first: p, second: target, type: .alliance, note: "Player Alliance"))
        }
        revision &+= 1
    }

    public func toggleGuarantee(with target: CountryID) {
        guard let p = playerCountry, target != p else { return }
        if world.diplomacy.hasTreaty(.guarantee, between: p, and: target) {
            simulation.world.diplomacy.removeTreaty(.guarantee, between: p, and: target)
        } else {
            simulation.world.diplomacy.addTreaty(Treaty(first: p, second: target, type: .guarantee, note: "Guarantee"))
        }
        revision &+= 1
    }

    public func toggleNonAggression(with target: CountryID) {
        guard let p = playerCountry, target != p else { return }
        if world.diplomacy.hasTreaty(.nonAggression, between: p, and: target) {
            simulation.world.diplomacy.removeTreaty(.nonAggression, between: p, and: target)
        } else if world.diplomacy.opinion(of: p, by: target) >= -10 {
            simulation.world.diplomacy.addTreaty(Treaty(first: p, second: target, type: .nonAggression, note: "Non-Aggression Pact"))
        }
        revision &+= 1
    }

    public func toggleMilitaryAccess(with target: CountryID) {
        guard let p = playerCountry, target != p else { return }
        if world.diplomacy.hasTreaty(.militaryAccess, between: p, and: target) {
            simulation.world.diplomacy.removeTreaty(.militaryAccess, between: p, and: target)
        } else {
            simulation.world.diplomacy.addTreaty(Treaty(first: p, second: target, type: .militaryAccess, note: "Military Access"))
        }
        revision &+= 1
    }

    public func improveRelations(with target: CountryID) {
        guard let p = playerCountry, target != p else { return }
        let cur = world.diplomacy.opinion(of: p, by: target)
        guard cur < 100 else { return }
        simulation.world.diplomacy.modifyOpinion(of: p, by: target, delta: 15)
        revision &+= 1
    }

    @discardableResult
    public func declareWar(on target: CountryID, cb: CasusBelliInstance, breakTruce: Bool = false) -> Result<War, WarDeclarationError> {
        guard let p = playerCountry else { return .failure(.invalid(reason: "No player country")) }
        let res = simulation.world.declareWar(
            attacker: p,
            defender: target,
            casusBelli: cb.type,
            warGoal: cb.warGoal,
            breakTruce: breakTruce,
            date: date
        )
        if case .success(let war) = res {
            for other in simulation.world.countries.ids where other != p && other != target {
                if simulation.world.diplomacy.areAllies(target, other)
                    || simulation.world.diplomacy.hasTreaty(.guarantee, between: other, and: target) {
                    _ = simulation.world.callToArms(caller: target, ally: other, warID: war.id)
                }
            }
            if let latest = simulation.world.diplomacy.wars.first(where: { $0.id == war.id }) {
                for def in latest.defenders where !simulation.world.humanCountries.contains(def) {
                    _ = ArmySystem.raiseAllLevies(&simulation.world, def)
                }
            }
        }
        revision &+= 1
        return res
    }

    @discardableResult
    public func callAllyToWar(_ ally: CountryID, warID: String) -> CallToArmsResult {
        guard let p = playerCountry else { return .declined(reasons: ["No player country"]) }
        let res = simulation.world.callToArms(caller: p, ally: ally, warID: warID)
        revision &+= 1
        return res
    }

    @discardableResult
    public func proposePeace(_ offer: PeaceOffer) -> Result<Int, PeaceTreatyError> {
        let res = simulation.world.executePeaceTreaty(offer, date: date, forceAccept: false)
        if case .success = res {
            rebuildTownIcons()
        }
        revision &+= 1
        return res
    }

    public func respondToPendingPeaceOffer(_ offer: PeaceOffer, accept: Bool) {
        if accept {
            _ = simulation.world.executePeaceTreaty(offer, date: date, forceAccept: true)
            rebuildTownIcons()
        } else {
            simulation.world.diplomacy.pendingPeaceOffers.removeAll { $0.warID == offer.warID }
        }
        revision &+= 1
    }

    // MARK: - Sieges, Saves & Nation Selection

    @discardableResult
    public func assaultFort(in province: ProvinceID) -> AssaultResult {
        guard let player = playerCountry else {
            return AssaultResult(
                captured: false,
                attackerLosses: 0,
                garrisonLosses: 0,
                remainingGarrison: world.provinces.fortGarrison[province.index],
                refusalReason: "No player country"
            )
        }
        let result = simulation.assaultFort(in: province, attacker: player)
        lastAssaultResult = (province, result)
        revision &+= 1
        return result
    }

    public func switchPlayer(to country: CountryID) {
        playerCountry = country
        simulation.world.humanCountries = [country]
        AIGoalSystem.updateGoals(&simulation.world, date: date)
        selectedArmy = nil
        moveModeForArmy = nil
        selectedFleet = nil
        moveModeForFleet = nil
        revision &+= 1
    }

    public func startNewGame(tag: String, seed: UInt64 = 1453, aiSetting: AIBehaviourSetting = .historical) {
        speed = .paused
        var freshWorld = Scenario1453.makeWorld()
        freshWorld.ai.setting = aiSetting
        let sim = Simulation(world: freshWorld, startDate: Scenario1453.startDate, seed: seed)
        simulation = sim
        simulation.interceptHumanBattles = interactiveBattlesEnabled
        pendingBattlePrompt = nil
        tacticalBattle = nil
        speedBeforeBattlePrompt = nil
        pausedForEventIDs.removeAll()
        date = sim.date
        let picked = sim.world.countries.id(forTag: tag) ?? sim.world.countries.id(forTag: Scenario1453.defaultPlayerTag)
        playerCountry = picked
        if let picked {
            simulation.world.humanCountries = [picked]
        }
        AIGoalSystem.updateGoals(&simulation.world, date: date)
        resetSelection()
        lastSaveStatus = nil
        rebuildLabels()
        revision &+= 1
    }

    public func refreshSavedGames() {
        savedGames = SaveStorage.listSaves(in: savesDirectory)
    }

    @discardableResult
    public func saveGame(named name: String) -> URL? {
        do {
            let url = try SaveStorage.save(simulation, name: name, playerTag: playerTag, in: savesDirectory)
            lastSaveStatus = "Saved '\(name)'"
            refreshSavedGames()
            revision &+= 1
            return url
        } catch {
            lastSaveStatus = "Save failed: \(error.localizedDescription)"
            revision &+= 1
            return nil
        }
    }

    @discardableResult
    public func quickSave() -> URL? {
        let tag = playerTag ?? "GEZ"
        return saveGame(named: "Quick Save - \(tag)")
    }

    @discardableResult
    public func loadGame(_ entry: SaveEntry) -> Bool {
        speed = .paused
        do {
            let loaded = try SaveStorage.load(from: entry.url)
            simulation = loaded.simulation
            simulation.interceptHumanBattles = interactiveBattlesEnabled
            pendingBattlePrompt = nil
            tacticalBattle = nil
            speedBeforeBattlePrompt = nil
            date = loaded.simulation.date
            if let tag = loaded.metadata.playerTag,
               let id = loaded.simulation.world.countries.id(forTag: tag) {
                playerCountry = id
            } else {
                playerCountry = loaded.simulation.world.humanCountries.first
                    ?? loaded.simulation.world.countries.id(forTag: Scenario1453.defaultPlayerTag)
            }
            if let player = playerCountry {
                simulation.world.humanCountries = [player]
            }
            resetSelection()
            lastSaveStatus = "Loaded '\(entry.metadata.name)'"
            rebuildLabels()
            revision &+= 1
            return true
        } catch {
            lastSaveStatus = "Load failed: \(error.localizedDescription)"
            revision &+= 1
            return false
        }
    }

    public func deleteSave(_ entry: SaveEntry) {
        do {
            try SaveStorage.deleteSave(at: entry.url)
            lastSaveStatus = "Deleted '\(entry.metadata.name)'"
            refreshSavedGames()
        } catch {
            lastSaveStatus = "Delete failed: \(error.localizedDescription)"
        }
        revision &+= 1
    }

    private func resetSelection() {
        selectedDiplomacyCountry = nil
        selectedArmy = nil
        moveModeForArmy = nil
        selectedFleet = nil
        moveModeForFleet = nil
        viewedCharacter = nil
        lastAssaultResult = nil
        select(province: nil)
    }

    // MARK: - Queries for Screens

    /// Playable country summaries sorted by development descending.
    public func countrySummaries() -> [CountrySummaryInfo] {
        let w = world
        var provCount = [Int](repeating: 0, count: w.countries.count)
        var devSum = [Int](repeating: 0, count: w.countries.count)
        for p in 0..<w.provinces.count {
            if let owner = w.provinces.owner[p] {
                provCount[owner.index] += 1
                devSum[owner.index] += w.provinces.development[p]
            }
        }
        return (0..<w.countries.count).compactMap { idx in
            guard provCount[idx] > 0 else { return nil }
            return CountrySummaryInfo(
                id: CountryID(idx),
                tag: w.countries.tag[idx],
                name: w.countries.name[idx],
                provinces: provCount[idx],
                development: devSum[idx]
            )
        }
        .sorted { lhs, rhs in
            if lhs.development != rhs.development { return lhs.development > rhs.development }
            return lhs.name < rhs.name
        }
    }

    /// Active alerts for the player country.
    public func activeAlerts() -> [GameAlertInfo] {
        guard let player = playerCountry else { return [] }
        let w = world
        var out: [GameAlertInfo] = []

        // 1. Pending peace offers to player
        let peaceOffers = w.diplomacy.pendingPeaceOffers.filter { $0.loser == player }
        if !peaceOffers.isEmpty {
            out.append(GameAlertInfo(
                id: "peace-offer",
                kind: .peaceOffer,
                label: "Peace Offer (\(peaceOffers.count))",
                warID: peaceOffers.first?.warID
            ))
        }

        // 2. Breached enemy fort ready to assault
        if let breachedSiege = w.military.sieges.first(where: { $0.besieger == player && $0.breached }) {
            let name = w.provinces.name[breachedSiege.province.index]
            out.append(GameAlertInfo(
                id: "breach-\(breachedSiege.province.index)",
                kind: .breach,
                label: "Breach: \(name)",
                province: breachedSiege.province
            ))
        }

        // 3. Friendly forts / provinces under enemy siege
        let friendlySieges = w.military.sieges.filter { w.provinces.owner[$0.province.index] == player }
        if let firstBesieged = friendlySieges.first {
            let name = w.provinces.name[firstBesieged.province.index]
            let label = friendlySieges.count == 1
                ? "Under Siege: \(name)"
                : "\(friendlySieges.count) Provinces Under Siege"
            out.append(GameAlertInfo(
                id: "under-siege",
                kind: .underSiege,
                label: label,
                province: firstBesieged.province
            ))
        }

        // 4. Coalition formed against player
        if let coalition = w.diplomacy.coalitions[player], !coalition.isEmpty {
            out.append(GameAlertInfo(
                id: "coalition",
                kind: .coalition,
                label: "Coalition (\(coalition.count))"
            ))
        }

        // 5. Low stability (< 0)
        if w.government.stability[player.index] < 0 {
            out.append(GameAlertInfo(
                id: "low-stability",
                kind: .lowStability,
                label: "Low Stability (\(w.government.stability[player.index]))"
            ))
        }

        // 6. Disloyal estates (< 30%)
        let estates = w.government.estates[player.index]
        let disloyalEstates = estates.indices.filter { w.government.loyalty[player.index][$0] < 0.30 }
        if !disloyalEstates.isEmpty {
            out.append(GameAlertInfo(
                id: "disloyal-estate",
                kind: .disloyalEstate,
                label: "Disloyal Estate\(disloyalEstates.count > 1 ? "s" : "")"
            ))
        }

        // 7. Refusing internal vassals
        var refusingVassals = 0
        for idx in 0..<w.provinces.count where w.provinces.owner[idx] == player {
            if let holder = w.provinces.holder[idx], w.people.refusing.contains(holder) {
                refusingVassals += 1
            }
        }
        if refusingVassals > 0 {
            out.append(GameAlertInfo(
                id: "refusing-vassal",
                kind: .refusingVassal,
                label: "\(refusingVassals) Defiant Vassal\(refusingVassals > 1 ? "s" : "")"
            ))
        }

        // 8. Bankruptcy or High Inflation
        if w.countries.bankruptMonthsLeft[player.index] > 0 {
            out.append(GameAlertInfo(
                id: "bankrupt",
                kind: .bankrupt,
                label: "Bankrupt (\(w.countries.bankruptMonthsLeft[player.index])m)"
            ))
        } else if w.countries.inflation[player.index] >= 0.10 {
            out.append(GameAlertInfo(
                id: "inflation",
                kind: .highInflation,
                label: String(format: "High Inflation %.0f%%", w.countries.inflation[player.index] * 100)
            ))
        }

        // 9. Active Naval Battles involving player fleets
        for b in w.navy.battles {
            let playerInBattle = b.attacker.fleets.contains { w.navy.fleets.owner[$0.index] == player }
                || b.defender.fleets.contains { w.navy.fleets.owner[$0.index] == player }
            if playerInBattle {
                let szName = w.seaZones.name[b.seaZone.index]
                out.append(GameAlertInfo(
                    id: "naval-battle-\(b.seaZone.index)",
                    kind: .navalBattle,
                    label: "Naval Battle: \(szName)",
                    seaZone: b.seaZone
                ))
            }
        }

        // 10. Player coastal ports under enemy blockade
        let blockadedHome = w.navy.blockadedProvinces
            .filter { w.provinces.controller(of: $0) == player }
            .sorted { $0.index < $1.index }
        if let firstBlockaded = blockadedHome.first {
            let name = w.provinces.name[firstBlockaded.index]
            let label = blockadedHome.count == 1
                ? "Blockaded: \(name)"
                : "\(blockadedHome.count) Ports Blockaded"
            out.append(GameAlertInfo(
                id: "blockaded-port",
                kind: .blockadedPort,
                label: label,
                province: firstBlockaded
            ))
        }

        // 11. Phase 12: plague, famine, earthquakes and rebels in the player's land.
        let cal = w.calamity
        var struck: [(Int, Double, Disease)] = []
        var hungry: [(Int, Double)] = []
        for p in 0..<w.provinces.count where w.provinces.owner[p] == player {
            for d in Disease.allCases where cal.hasOutbreak(p, d) {
                struck.append((p, cal.infection(p, d) * w.provinces.population[p], d))
            }
            if w.provinces.famine[p] >= FamineModel.alertAbove { hungry.append((p, w.provinces.famine[p])) }
        }
        if let worst = struck.max(by: { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 > $1.0 }) {
            let provinces = Set(struck.map { $0.0 }).count
            out.append(GameAlertInfo(
                id: "plague",
                kind: .plague,
                label: provinces == 1
                    ? "\(worst.2.displayName): \(w.provinces.name[worst.0])"
                    : "\(worst.2.displayName) in \(provinces) Provinces",
                province: ProvinceID(worst.0)
            ))
        }
        if let worst = hungry.max(by: { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 > $1.0 }) {
            out.append(GameAlertInfo(
                id: "famine",
                kind: .famine,
                label: hungry.count == 1 ? "Famine: \(w.provinces.name[worst.0])" : "Famine in \(hungry.count) Provinces",
                province: ProvinceID(worst.0)
            ))
        }
        if let quake = cal.quakes.last(where: {
            date.ordinal - $0.date.ordinal <= 90 && w.provinces.owner[$0.epicentre.index] == player
        }) {
            out.append(GameAlertInfo(
                id: "earthquake-\(quake.epicentre.index)-\(quake.date.ordinal)",
                kind: .earthquake,
                label: "Earthquake: \(w.provinces.name[quake.epicentre.index])",
                province: quake.epicentre
            ))
        }
        for f in w.unrest.factions(of: player) where f.risen || f.progress >= 50 {
            let name = RebelSystem.name(w, f)
            out.append(GameAlertInfo(
                id: "rebels-\(f.id)",
                kind: .rebels,
                label: f.risen ? "Rising: \(name)" : "\(name) \(Int(f.progress))%",
                province: RebelSystem.target(w, f)
            ))
        }

        // 12. Phase 13: recent technology advance and institutions (ready to embrace or newly spawned).
        if let recentTech = w.tech.notes.last(where: {
            $0.kind == .levelUp && $0.country == player && date.ordinal - $0.date.ordinal <= 90
        }), let tr = recentTech.track, let lvl = recentTech.level {
            out.append(GameAlertInfo(
                id: "tech-\(tr.key)-\(lvl)",
                kind: .techLevel,
                label: "\(tr.shortName) Tech \(lvl)"
            ))
        }

        var alertedInstitution = false
        for inst in w.techRules.institutions where inst.index < w.tech.institutionCount && w.tech.institutionSpawned[inst.index] {
            if !w.tech.hasEmbraced(player, institution: inst.index) {
                let refusal = InstitutionSystem.embraceRefusal(w, for: player, institution: inst.index, checkMoney: false)
                if refusal == nil {
                    out.append(GameAlertInfo(
                        id: "inst-embrace-\(inst.index)",
                        kind: .institution,
                        label: "Embrace: \(inst.name)",
                        province: w.tech.institutionOrigin[inst.index]
                    ))
                    alertedInstitution = true
                    break
                }
            }
        }
        if !alertedInstitution, let recentSpawn = w.tech.notes.last(where: {
            $0.kind == .institutionSpawned && date.ordinal - $0.date.ordinal <= 90
        }), let instIdx = recentSpawn.institutionIndex, instIdx < w.techRules.institutions.count {
            let inst = w.techRules.institutions[instIdx]
            out.append(GameAlertInfo(
                id: "inst-spawn-\(instIdx)",
                kind: .institution,
                label: "Institution: \(inst.name)",
                province: recentSpawn.province
            ))
        }

        if let pendingEv = w.events.pendingEvent(for: player) {
            out.insert(GameAlertInfo(
                id: "event-\(pendingEv.instanceID)",
                kind: .event,
                label: "Event: \(pendingEv.title)",
                province: pendingEv.contextProvince
            ), at: 0)
        }

        return out
    }

    /// Top bar status values for the active player country.
    public func playerTopBarStatus() -> (name: String, treasury: Double, monthlyNet: Double, stability: Int, armyMen: Int, manpower: Double, activeWars: Int, pendingPeaceOffers: Int, inflation: Double)? {
        guard let player = playerCountry else { return nil }
        let w = world
        let c = w.countries
        let name = c.name[player.index]
        let treasury = c.treasury[player.index]
        let net = c.lastMonthlyIncome[player.index] - c.lastMonthlyExpenses[player.index]
        let stability = w.government.stability[player.index]
        let armyMen = w.military.totalMen(of: player)
        let manpower = w.military.manpower[player.index]
        let wars = w.diplomacy.activeWars(for: player).count
        let peace = w.diplomacy.pendingPeaceOffers.filter { $0.loser == player }.count
        let inflation = c.inflation[player.index]
        return (name, treasury, net, stability, armyMen, manpower, wars, peace, inflation)
    }

    /// Country status string such as "Monarchy · Vassal of Morocco".
    public func countryStatus(_ country: CountryID) -> String {
        let c = world.countries
        var parts = [c.government[country.index].displayName]
        if let lord = c.overlord[country.index], let kind = c.subjectType[country.index] {
            switch kind {
            case .personalUnion: parts.append("Personal union with \(c.name[lord.index])")
            case .vassal: parts.append("Vassal of \(c.name[lord.index])")
            case .tributary: parts.append("Tributary of \(c.name[lord.index])")
            }
        }
        let subjects = c.subjects(of: country)
        if !subjects.isEmpty {
            parts.append("\(subjects.count) subject\(subjects.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Interactive Tactical Battles (Phase 9)

    private func bestCommanderSummary(for armies: [ArmyID]) -> (name: String, martial: Int) {
        var bestName = "Field Captain"
        var bestMartial = 0
        for aid in armies {
            let idx = Int(aid.rawValue)
            guard idx >= 0, idx < world.military.armies.count, world.military.armies.alive[idx] else { continue }
            if let cmd = world.military.armies.commander[idx], world.people.characters.isAlive(cmd) {
                let m = world.people.characters.skill(cmd, .martial)
                if m > bestMartial || bestName == "Field Captain" {
                    bestMartial = m
                    bestName = world.people.characters.name[cmd.index]
                }
            }
        }
        return (bestName, bestMartial)
    }

    private func refreshPendingPrompt(forBattleID battleID: String) {
        guard let battle = world.military.battles.first(where: { $0.id == battleID }) else {
            pendingBattlePrompt = nil
            return
        }
        let attC = battle.attackerCountry
        let defC = battle.defenderCountry
        let pSide: BattleSide
        if let p = playerCountry {
            pSide = (p == defC || world.diplomacy.areAllies(p, defC)) ? .defender : .attacker
        } else {
            pSide = .attacker
        }
        let attCmd = bestCommanderSummary(for: battle.attackers)
        let defCmd = bestCommanderSummary(for: battle.defenders)
        let attMen = battle.attackers.reduce(0) { $0 + world.military.armies.totalMen(of: $1) }
        let defMen = battle.defenders.reduce(0) { $0 + world.military.armies.totalMen(of: $1) }
        let pIdx = battle.province.index
        pendingBattlePrompt = PendingBattlePrompt(
            id: battle.id,
            kind: .field(battleID: battle.id),
            province: battle.province,
            provinceName: world.provinces.name[pIdx],
            terrain: world.provinces.terrain[pIdx],
            isRiverCrossing: battle.isRiverCrossing,
            attackerCountry: attC,
            defenderCountry: defC,
            attackerName: world.countries.name[attC.index],
            defenderName: world.countries.name[defC.index],
            attackerTag: world.countries.tag[attC.index],
            defenderTag: world.countries.tag[defC.index],
            attackerMen: max(battle.attackerInitialMen, attMen),
            defenderMen: max(battle.defenderInitialMen, defMen),
            attackerCommanderName: attCmd.name,
            attackerCommanderMartial: attCmd.martial,
            defenderCommanderName: defCmd.name,
            defenderCommanderMartial: defCmd.martial,
            playerSide: pSide,
            fortLevel: world.provinces.fortLevel[pIdx],
            breached: false,
            attackerAmbushed: battle.isRiverCrossing
        )
    }

    /// Requests the "Lead Battle in Person vs Auto-Resolve" choice for a fort storm assault.
    /// Returns nil (with prompt unset) if preconditions fail; check `assaultFort` refusal reason.
    @discardableResult
    public func requestStormAssaultPrompt(in province: ProvinceID) -> (prompt: PendingBattlePrompt?, refusalReason: String?) {
        guard pendingBattlePrompt == nil, tacticalBattle == nil else {
            return (nil, "Another battle dialog is already open")
        }
        guard let player = playerCountry else {
            return (nil, "No player country")
        }
        let pIdx = province.index
        guard pIdx >= 0 && pIdx < world.provinces.count else {
            return (nil, "Invalid province")
        }
        guard let siege = world.military.sieges.first(where: { $0.province == province }) else {
            return (nil, "No active siege in \(world.provinces.name[pIdx])")
        }
        guard siege.besieger == player else {
            return (nil, "Only the siege leader can order a Storm Assault")
        }
        guard siege.breached else {
            return (nil, "Walls are not breached yet")
        }
        guard world.military.battle(in: province) == nil else {
            return (nil, "Field battle in progress.")
        }
        let attackers = SiegeSystem.besiegers(in: province, attacker: player, world: world)
        let attMen = attackers.reduce(0) { $0 + world.military.armies.totalMen(of: $1) }
        guard attMen >= 500 else {
            return (nil, "Insufficient besiegers to assault.")
        }
        guard let defOwner = world.provinces.controller(of: province) else {
            return (nil, "No defender holds the fort")
        }
        let garrison = max(1, world.provinces.fortGarrison[pIdx])
        let attCmd = bestCommanderSummary(for: attackers)

        speedBeforeBattlePrompt = speed
        speed = .paused
        let prompt = PendingBattlePrompt(
            id: "assault_\(pIdx)_\(simulation.ticksRun)",
            kind: .assault(province: province),
            province: province,
            provinceName: world.provinces.name[pIdx],
            terrain: world.provinces.terrain[pIdx],
            isRiverCrossing: false,
            attackerCountry: player,
            defenderCountry: defOwner,
            attackerName: world.countries.name[player.index],
            defenderName: world.countries.name[defOwner.index],
            attackerTag: world.countries.tag[player.index],
            defenderTag: world.countries.tag[defOwner.index],
            attackerMen: attMen,
            defenderMen: garrison,
            attackerCommanderName: attCmd.name,
            attackerCommanderMartial: attCmd.martial,
            defenderCommanderName: "Castellan of \(world.provinces.name[pIdx])",
            defenderCommanderMartial: 4 + min(4, world.provinces.fortLevel[pIdx]),
            playerSide: .attacker,
            fortLevel: world.provinces.fortLevel[pIdx],
            breached: siege.breached,
            attackerAmbushed: false
        )
        pendingBattlePrompt = prompt
        revision &+= 1
        return (prompt, nil)
    }

    /// Resolves the open battle prompt by choosing "Auto-Resolve" (existing BattleSystem / SiegeSystem).
    @discardableResult
    public func chooseAutoResolvePendingBattle() -> AssaultResult? {
        guard let prompt = pendingBattlePrompt else { return nil }
        pendingBattlePrompt = nil
        switch prompt.kind {
        case .field(let battleID):
            simulation.autoResolveBattleIDs.insert(battleID)
            if simulation.pendingHumanBattleID == battleID {
                simulation.pendingHumanBattleID = nil
            }
            if let prevSpeed = speedBeforeBattlePrompt, prevSpeed != .paused {
                speed = prevSpeed
            }
            speedBeforeBattlePrompt = nil
            revision &+= 1
            return nil
        case .assault(let province):
            speedBeforeBattlePrompt = nil
            return assaultFort(in: province)
        }
    }

    /// Resolves the open battle prompt by choosing "Lead Battle in Person".
    @discardableResult
    public func chooseLeadPendingBattleInPerson() -> Bool {
        guard let prompt = pendingBattlePrompt else { return false }
        let battleSeed = UInt64(max(1, simulation.ticksRun))
            ^ UInt64(prompt.province.index + 1) &* 0x517CC1B727220A95
            ^ BattlefieldGenerator.stableHash64(prompt.id)

        switch prompt.kind {
        case .field(let battleID):
            guard let battle = world.military.battles.first(where: { $0.id == battleID }) else {
                pendingBattlePrompt = nil
                simulation.pendingHumanBattleID = nil
                return false
            }
            pendingBattlePrompt = nil
            if simulation.pendingHumanBattleID == battleID {
                simulation.pendingHumanBattleID = nil
            }
            simulation.activeTacticalBattleID = battleID
            speed = .paused
            tacticalBattle = BattleEngine(
                world: world,
                battle: battle,
                playerSide: prompt.playerSide,
                seed: battleSeed
            )
            revision &+= 1
            return true
        case .assault(let province):
            guard let siege = world.military.sieges.first(where: { $0.province == province }) else {
                pendingBattlePrompt = nil
                return false
            }
            let attackers = SiegeSystem.besiegers(in: province, attacker: siege.besieger, world: world)
            pendingBattlePrompt = nil
            speed = .paused
            tacticalBattle = BattleEngine(
                world: world,
                province: province,
                attackerCountry: prompt.attackerCountry,
                defenderCountry: prompt.defenderCountry,
                attackerArmies: attackers,
                fortLevel: max(1, prompt.fortLevel),
                existingBreach: siege.breached,
                garrisonMen: max(100, world.provinces.fortGarrison[province.index]),
                playerSide: .attacker,
                seed: battleSeed
            )
            revision &+= 1
            return true
        }
    }

    /// Moves a player unit inside its deployment zone during Deployment phase.
    @discardableResult
    public func deployMoveBattleUnit(unitIndex: Int, x: Double, y: Double, facing: Double? = nil) -> Bool {
        guard var battle = tacticalBattle else { return false }
        let ok = battle.deployMoveUnit(unitIndex: unitIndex, x: x, y: y, facing: facing)
        tacticalBattle = battle
        if ok { revision &+= 1 }
        return ok
    }

    /// Ends the deployment phase and starts the real-time tactical battle.
    @discardableResult
    public func startTacticalBattle() -> Bool {
        guard var battle = tacticalBattle else { return false }
        let ok = battle.startBattle()
        tacticalBattle = battle
        if ok { revision &+= 1 }
        return ok
    }

    /// Sets speed (`0` paused, `1` 0.5x, `2` 1x, `3` 2x) for the active tactical battle.
    @discardableResult
    public func setTacticalBattleSpeed(_ speedRaw: Int) -> Bool {
        guard var battle = tacticalBattle, let spd = BattleSpeed(rawValue: speedRaw) else { return false }
        battle.setSpeed(spd)
        tacticalBattle = battle
        revision &+= 1
        return true
    }

    /// Advances the active tactical battle by real-time `deltaSeconds`. Returns ticks stepped.
    @discardableResult
    public func tickTacticalBattle(deltaSeconds: Double) -> Int {
        guard var battle = tacticalBattle else { return 0 }
        let ticks = battle.tick(deltaSeconds: deltaSeconds)
        tacticalBattle = battle
        return ticks
    }

    // MARK: - Tactical Orders (Part B)

    private func playerControlledIndices(from requested: [Int], in battle: BattleEngine) -> [Int] {
        guard let pSide = battle.playerSide else { return requested }
        return requested.filter { idx in
            idx >= 0 && idx < battle.units.count && battle.units.side[idx] == pSide
        }
    }

    @discardableResult
    public func orderBattleMove(unitIndices: [Int], x: Double, y: Double) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueMoveOrder(unitIndices: owned, x: x, y: y)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattlePath(unitIndices: [Int], points: [TacticalPoint]) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active, !points.isEmpty else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issuePathOrder(unitIndices: owned, points: points)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleFrontline(unitIndices: [Int], start: TacticalPoint, end: TacticalPoint) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueFrontlineOrder(unitIndices: owned, start: start, end: end)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleAttack(unitIndices: [Int], targetUnitIndex: Int) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueAttackOrder(unitIndices: owned, targetUnitIndex: targetUnitIndex)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleFormation(unitIndices: [Int], formation: BattleFormation) -> Bool {
        guard var battle = tacticalBattle, battle.phase != .ended else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueFormationOrder(unitIndices: owned, formation: formation)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleStance(unitIndices: [Int], stance: BattleStance) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueStanceOrder(unitIndices: owned, stance: stance)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleRetreat(unitIndices: [Int]) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueRetreatOrder(unitIndices: owned)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleSiegeEquipment(unitIndices: [Int], equipment: SiegeEquipmentKind) -> Bool {
        guard var battle = tacticalBattle, battle.phase != .ended, battle.isAssault else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueSiegeEquipmentOrder(unitIndices: owned, equipment: equipment)
        tacticalBattle = battle
        return true
    }

    @discardableResult
    public func orderBattleAttackStructure(unitIndices: [Int], structureID: Int) -> Bool {
        guard var battle = tacticalBattle, battle.phase == .active, battle.isAssault else { return false }
        let owned = playerControlledIndices(from: unitIndices, in: battle)
        guard !owned.isEmpty else { return false }
        battle.issueAttackStructureOrder(unitIndices: owned, structureID: structureID)
        tacticalBattle = battle
        return true
    }

    // MARK: - Phase 9 Part D: Campaign Write-Back

    public func previewTacticalBattleResult() -> TacticalBattleResult? {
        guard let battle = tacticalBattle, battle.phase == .ended else { return nil }
        return BattleWriteBack.previewResult(engine: battle)
    }

    @discardableResult
    public func finishTacticalBattle() -> TacticalBattleResult? {
        guard let battle = tacticalBattle, battle.phase == .ended else { return nil }
        let res = BattleWriteBack.apply(
            engine: battle,
            to: &simulation.world,
            simulation: simulation,
            date: simulation.date
        )
        tacticalBattle = nil
        lastTacticalBattleResult = res
        speed = .paused
        revision &+= 1
        return res
    }

    // MARK: - Phase 11: Faith & Culture

    @discardableResult
    public func sendMissionary(to province: ProvinceID) -> MissionaryRefusal? {
        guard let player = playerCountry else { return .notOwned }
        let err = FaithSystem.sendMissionary(&simulation.world, by: player, to: province, date: date)
        if err == nil { revision &+= 1 }
        return err
    }

    @discardableResult
    public func recallMissionary(from province: ProvinceID) -> Bool {
        guard let player = playerCountry else { return false }
        let ok = FaithSystem.recallMissionary(&simulation.world, by: player, from: province)
        if ok { revision &+= 1 }
        return ok
    }

    @discardableResult
    public func resolveHussiteQuestion(_ choice: HussiteOutcome) -> Bool {
        let ok = MovementSystem.resolveHussiteQuestion(&simulation.world, choice: choice, by: playerCountry, date: date)
        if ok { revision &+= 1 }
        return ok
    }

    @discardableResult
    public func adoptReformationReligion(_ religion: Religion) -> Bool {
        guard let player = playerCountry else { return false }
        let ok = MovementSystem.adoptReformationReligion(&simulation.world, country: player, religion: religion, date: date)
        if ok { revision &+= 1 }
        return ok
    }

    @discardableResult
    public func acceptCulture(_ culture: CultureID) -> AcceptCultureError? {
        guard let player = playerCountry else { return .notPresentInCountry }
        let err = CultureSystem.acceptCulture(&simulation.world, country: player, culture: culture, date: date)
        if err == nil { revision &+= 1 }
        return err
    }

    @discardableResult
    public func revokeCulture(_ culture: CultureID) -> Bool {
        guard let player = playerCountry else { return false }
        let ok = CultureSystem.revokeCulture(&simulation.world, country: player, culture: culture, date: date)
        if ok { revision &+= 1 }
        return ok
    }

    // MARK: - Phase 12: Plague

    /// Orders (or lifts) a port quarantine in one of the player's provinces.
    @discardableResult
    public func setQuarantine(in province: ProvinceID, on: Bool) -> PlagueRefusal? {
        guard let player = playerCountry else { return .notOwner }
        let refusal = PlagueSystem.setQuarantine(&simulation.world, player, province, on: on)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    /// Orders (or lifts) a cordon around one of the player's provinces.
    @discardableResult
    public func setCordon(in province: ProvinceID, on: Bool) -> PlagueRefusal? {
        guard let player = playerCountry else { return .notOwner }
        let refusal = PlagueSystem.setCordon(&simulation.world, player, province, on: on)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    // MARK: - Phase 12: Rebels

    /// Give a rebel faction a milder form of what it wants; it disbands.
    @discardableResult
    public func concedeToRebels(faction id: Int) -> RebelRefusal? {
        guard let player = playerCountry else { return .noSuchFaction }
        let refusal = RebelSystem.concede(&simulation.world, player, faction: id, date: date)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    /// March the strongest free army against a rebel faction.
    @discardableResult
    public func sendTroopsAgainstRebels(faction id: Int) -> RebelRefusal? {
        guard let player = playerCountry else { return .noSuchFaction }
        let refusal = RebelSystem.sendTroops(&simulation.world, player, faction: id)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    /// Cut the tax on peasants by a quarter of the normal rate.
    @discardableResult
    public func lowerPeasantTaxes() -> RebelRefusal? {
        guard let player = playerCountry else { return .noSuchFaction }
        let refusal = RebelSystem.lowerTaxes(&simulation.world, player)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    // MARK: - Phase 13: Technology

    /// Sets the player's national research focus (Administrative, Diplomatic, Military, or Balanced).
    @discardableResult
    public func setTechFocus(_ focus: TechFocus) -> Bool {
        guard let player = playerCountry else { return false }
        simulation.world.tech.setFocus(of: player, to: focus)
        revision &+= 1
        return true
    }

    /// Embraces a spawned institution for the player's country.
    @discardableResult
    public func embraceInstitution(_ index: Int) -> EmbraceRefusal? {
        guard let player = playerCountry else { return .unknownInstitution }
        let refusal = InstitutionSystem.embrace(&simulation.world, player, institution: index, date: date)
        if refusal == nil { revision &+= 1 }
        return refusal
    }

    // MARK: - Phase 14: Historical & Chronicle Events

    /// First pending event awaiting a decision from the current player country.
    public var pendingPlayerEvent: PendingEvent? {
        guard let player = playerCountry else { return nil }
        return simulation.world.events.pendingEvent(for: player)
    }

    /// Resolves a pending event for the player by choosing `optionIndex` (`0..<options.count`).
    @discardableResult
    public func chooseEventOption(instanceID: Int, optionIndex: Int) -> Bool {
        guard let player = playerCountry,
              let pending = simulation.world.events.pending.first(where: { $0.instanceID == instanceID }),
              pending.country == player else {
            return false
        }
        let ok = EventSystem.resolvePendingEvent(&simulation.world, instanceID: instanceID, optionIndex: optionIndex, date: date)
        if ok {
            pausedForEventIDs.remove(instanceID)
            revision &+= 1
        }
        return ok
    }
}
