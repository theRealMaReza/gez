/// Province data stored as a struct of arrays: one array per field, indexed
/// by `ProvinceID.index`. Systems that loop over thousands of provinces each
/// tick only touch the arrays they need, which keeps memory access fast.
public struct ProvinceTable: Sendable {
    // Fixed geography (never changes during a game).
    public private(set) var name: [String] = []
    public private(set) var location: [GeoPoint] = []
    public private(set) var state: [StateID] = []
    public private(set) var terrain: [Terrain] = []
    public private(set) var isCoastal: [Bool] = []
    public private(set) var areaKm2: [Double] = []
    /// Best spot on the map image to draw the province name.
    public private(set) var labelPoint: [MapPoint] = []
    /// Provinces an army can walk to directly (land borders plus straits).
    public private(set) var neighbors: [[ProvinceID]] = []

    // Changing state.
    public var owner: [CountryID?] = []
    /// 1 (empty) to 10 (great city).
    public var development: [Int] = []
    /// Number of people.
    public var population: [Double] = []
    /// Yearly tax value in ducats.
    public var baseTax: [Double] = []
    /// Yearly production value in ducats.
    public var production: [Double] = []
    /// Majority religion of the people (kept up to date from the pops).
    public var religion: [Religion] = []
    /// Majority culture of the people (kept up to date from the pops).
    public var majorityCulture: [CultureID] = []
    /// Sufi brotherhoods active in the province.
    public var sufiOrders: [[SufiPresence]] = []
    /// 0 = no fort. Higher levels take longer to siege.
    public var fortLevel: [Int] = []
    /// Current defending garrison inside the fort (up to `fortLevel * 1000`).
    public var fortGarrison: [Int] = []
    /// The great vassal who holds this province for its owner (nil = the crown's own land).
    public var holder: [CharacterID?] = []
    /// Countries that consider this province their lawful core.
    public var cores: [Set<CountryID>] = []
    /// Countries that have an active territorial claim on this province.
    public var claims: [Set<CountryID>] = []
    /// Country currently occupying this province in a war (nil = controlled by legal owner).
    public var occupiedBy: [CountryID?] = []
    /// Hostile country currently advancing unfortified takeover or liberation in this province.
    public var occupationTarget: [CountryID?] = []
    /// Days accumulated toward unfortified occupation or liberation.
    public var occupationProgressDays: [Int] = []
    /// Religious unrest in provinces whose majority faith differs from the owner's (0 to 100; Phase 12 rebels use this).
    public var religiousUnrest: [Double] = []
    /// Share of the province's population matching the owner's state religion (0 to 1), or conversion wave tracker.
    public var conversionProgress: [Double] = []
    /// Cultural assimilation progress toward the dominant/owner culture (0 to 1).
    public var assimilationProgress: [Double] = []
    /// War/siege devastation (0 to 1), decaying slowly over peace and driving migration.
    public var devastation: [Double] = []
    /// Shortfall-driven famine intensity (0 to 1), driving migration.
    public var famine: [Double] = []
    /// Net population moved in (+) or out (−) during the most recent monthly migration tick.
    public var lastNetMigration: [Double] = []

    public init() {}

    public var count: Int { name.count }
    public var ids: [ProvinceID] { (0..<count).map(ProvinceID.init) }

    @discardableResult
    public mutating func add(
        name: String,
        location: GeoPoint,
        state: StateID,
        terrain: Terrain,
        isCoastal: Bool = false,
        areaKm2: Double = 0,
        labelPoint: MapPoint = MapPoint(x: 0, y: 0),
        owner: CountryID?,
        development: Int,
        population: Double,
        baseTax: Double,
        production: Double,
        religion: Religion,
        fortLevel: Int
    ) -> ProvinceID {
        let id = ProvinceID(count)
        self.name.append(name)
        self.location.append(location)
        self.state.append(state)
        self.terrain.append(terrain)
        self.isCoastal.append(isCoastal)
        self.areaKm2.append(areaKm2)
        self.labelPoint.append(labelPoint)
        self.neighbors.append([])
        self.owner.append(owner)
        self.development.append(development)
        self.population.append(population)
        self.baseTax.append(baseTax)
        self.production.append(production)
        self.religion.append(religion)
        self.majorityCulture.append(CultureID(0))
        self.sufiOrders.append([])
        self.fortLevel.append(fortLevel)
        self.fortGarrison.append(max(0, fortLevel) * 1000)
        self.holder.append(nil)
        self.cores.append(owner != nil ? [owner!] : [])
        self.claims.append([])
        self.occupiedBy.append(nil)
        self.occupationTarget.append(nil)
        self.occupationProgressDays.append(0)
        self.religiousUnrest.append(0)
        self.conversionProgress.append(0)
        self.assimilationProgress.append(0)
        self.devastation.append(0)
        self.famine.append(0)
        self.lastNetMigration.append(0)
        return id
    }

    /// Current military/administrative controller of `province` (occupier if occupied, else legal owner).
    public func controller(of province: ProvinceID) -> CountryID? {
        occupiedBy[province.index] ?? owner[province.index]
    }

    /// Maximum fort garrison capacity for `province` (1,000 per fort level).
    public func maxGarrison(of province: ProvinceID) -> Int {
        max(0, fortLevel[province.index]) * 1000
    }

    /// Neighbours are set once all provinces exist. Links are made two-way.
    public mutating func connect(_ a: ProvinceID, _ b: ProvinceID) {
        guard a != b else { return }
        if !neighbors[a.index].contains(b) { neighbors[a.index].append(b) }
        if !neighbors[b.index].contains(a) { neighbors[b.index].append(a) }
    }

    public func id(named name: String) -> ProvinceID? {
        self.name.firstIndex(of: name).map(ProvinceID.init)
    }
}

/// A state is a named group of neighbouring provinces (e.g. "Thrace").
/// A region groups states (e.g. "Balkans").
public struct StateTable: Sendable {
    public private(set) var name: [String] = []
    public private(set) var region: [RegionID] = []
    public private(set) var provinces: [[ProvinceID]] = []

    public init() {}

    public var count: Int { name.count }

    @discardableResult
    public mutating func add(name: String, region: RegionID) -> StateID {
        let id = StateID(count)
        self.name.append(name)
        self.region.append(region)
        self.provinces.append([])
        return id
    }

    mutating func attach(_ province: ProvinceID, to state: StateID) {
        provinces[state.index].append(province)
    }
}

/// Named areas of sea (Aegean, Malabar Coast...). Fleets, trade and plague
/// travel through them.
public struct SeaZoneTable: Sendable {
    public private(set) var name: [String] = []
    /// Sea zones you can sail to directly.
    public var neighbors: [[SeaZoneID]] = []
    /// Land provinces touching this sea.
    public var coast: [[ProvinceID]] = []
    /// True for inland seas (Mediterranean, Black Sea, Baltic, Red Sea) where galleys get bonuses.
    public var isInland: [Bool] = []
    /// Visual/geometric center X on the map grid.
    public var centerX: [Double] = []
    /// Visual/geometric center Y on the map grid.
    public var centerY: [Double] = []

    public init() {}

    public var count: Int { name.count }

    @discardableResult
    public mutating func add(name: String) -> SeaZoneID {
        let id = SeaZoneID(count)
        self.name.append(name)
        neighbors.append([])
        coast.append([])
        isInland.append(false)
        centerX.append(0)
        centerY.append(0)
        return id
    }

    public func id(named name: String) -> SeaZoneID? {
        self.name.firstIndex(of: name).map(SeaZoneID.init)
    }
}

public struct CountryTable: Sendable {
    public private(set) var tag: [String] = []
    public private(set) var name: [String] = []
    public var color: [RGB] = []
    public var government: [GovernmentType] = []
    public var religion: [Religion] = []
    public var capital: [ProvinceID?] = []
    /// Share of the population that is enslaved (0 to 1).
    public var slavery: [Double] = []
    /// The country this one is subject to, if any.
    public var overlord: [CountryID?] = []
    public var subjectType: [SubjectType?] = []
    /// Ducats.
    public var treasury: [Double] = []
    /// Income from the most recent monthly update.
    public var lastMonthlyIncome: [Double] = []
    /// Spending (building upkeep, later armies and loans) in the most recent month.
    public var lastMonthlyExpenses: [Double] = []
    /// Learning points gathered so far (spent on technology later).
    public var learning: [Double] = []
    /// Tax level per class (`TaxClass` order): 1 normal, 0 none, up to 2.
    public var taxLevel: [[Double]] = []
    /// Tax collected last month per class (`TaxClass` order).
    public var lastTax: [[Double]] = []
    public var lastUpkeep: [Double] = []
    public var lastInterest: [Double] = []
    /// 0 = none; 0.1 = everything the state buys costs 10% more.
    public var inflation: [Double] = []
    /// Debasing the coinage every month.
    public var debasing: [Bool] = []
    /// Months of bankruptcy penalties left.
    public var bankruptMonthsLeft: [Int] = []
    /// Countries whose merchants may not trade in or pass through this one's markets.
    public var embargoes: [Set<CountryID>] = []
    public var tollPolicy: [TollPolicy] = []
    public var ruler: [CharacterID?] = []
    public var heir: [CharacterID?] = []
    /// Council seats (`CouncilSeat` order).
    public var council: [[CharacterID?]] = []
    public var succession: [SuccessionLaw] = []
    /// Merchants' profit and tolls collected last month.
    public var lastTrade: [Double] = []
    public var lastTolls: [Double] = []
    /// Tax kept (or withheld) by vassals last month.
    public var lastVassalTax: [Double] = []
    /// Ongoing debasement income minted last month.
    public var lastDebaseIncome: [Double] = []
    /// War reparations received and paid last month.
    public var lastWarRepsIn: [Double] = []
    public var lastWarRepsOut: [Double] = []
    /// Diplomatic relation slot upkeep paid last month.
    public var lastSlotUpkeep: [Double] = []
    /// State prestige (from held holy sites, etc.; -100 to 100).
    public var prestige: [Double] = []
    /// Primary culture of the country.
    public var primaryCulture: [CultureID] = []
    /// Additional accepted cultures beyond the primary culture.
    public var acceptedCultures: [Set<CultureID>] = []

    private var indexByTag: [String: CountryID] = [:]

    public init() {}

    public var count: Int { tag.count }
    public var ids: [CountryID] { (0..<count).map(CountryID.init) }

    public func id(forTag tag: String) -> CountryID? {
        indexByTag[tag]
    }

    /// Countries directly subject to this one.
    public func subjects(of country: CountryID) -> [CountryID] {
        ids.filter { overlord[$0.index] == country }
    }

    @discardableResult
    public mutating func add(
        tag: String,
        name: String,
        color: RGB,
        government: GovernmentType,
        religion: Religion,
        treasury: Double
    ) -> CountryID {
        precondition(indexByTag[tag] == nil, "duplicate country tag \(tag)")
        let id = CountryID(count)
        self.tag.append(tag)
        self.name.append(name)
        self.color.append(color)
        self.government.append(government)
        self.religion.append(religion)
        self.capital.append(nil)
        self.slavery.append(0)
        self.overlord.append(nil)
        self.subjectType.append(nil)
        self.treasury.append(treasury)
        self.lastMonthlyIncome.append(0)
        self.lastMonthlyExpenses.append(0)
        self.learning.append(0)
        self.taxLevel.append(Array(repeating: 1, count: TaxClass.allCases.count))
        self.lastTax.append(Array(repeating: 0, count: TaxClass.allCases.count))
        self.lastUpkeep.append(0)
        self.lastInterest.append(0)
        self.inflation.append(0)
        self.debasing.append(false)
        self.bankruptMonthsLeft.append(0)
        self.embargoes.append([])
        self.ruler.append(nil)
        self.heir.append(nil)
        self.council.append(Array(repeating: nil, count: CouncilSeat.allCases.count))
        self.succession.append(.primogeniture)
        self.tollPolicy.append(.open)
        self.lastTrade.append(0)
        self.lastTolls.append(0)
        self.lastVassalTax.append(0)
        self.lastDebaseIncome.append(0)
        self.lastWarRepsIn.append(0)
        self.lastWarRepsOut.append(0)
        self.lastSlotUpkeep.append(0)
        self.prestige.append(0)
        self.primaryCulture.append(CultureID(0))
        self.acceptedCultures.append([])
        indexByTag[tag] = id
        return id
    }
}

public struct World: Sendable {
    public var map: MapInfo
    public var regions: [String] = []
    public var states = StateTable()
    public var provinces = ProvinceTable()
    public var countries = CountryTable()
    public var cultures = CultureTable()
    public var seaZones = SeaZoneTable()
    /// Sea zones touching each province (empty for inland provinces).
    public var provinceSeas: [[SeaZoneID]] = []
    /// Every group of people, split by culture, religion, sect and class.
    public var pops = PopTable()
    /// Major rivers, for drawing.
    public var rivers: [MapPolyline] = []
    /// Neighbouring provinces whose shared border is mostly a river.
    /// Crossing these is slower and gives the defender an edge in battle.
    public var riverBorders: Set<ProvincePair> = []
    /// Straits mapped to the sea zones that guard crossing between the two shores.
    public var straitSeas: [ProvincePair: [SeaZoneID]] = [:]
    /// Goods, markets, producers and prices.
    public var economy = Economy()
    /// Banks and loans.
    public var finance = Finance()
    /// Rulers, families and courts.
    public var people = People()
    /// Countries played by people; the AI leaves them alone.
    public var humanCountries: Set<CountryID> = []
    /// Laws, estates, stability and reforms (Phase 5).
    public var government = Government()
    /// Armies, regiments, unit types and national manpower (Phase 6).
    public var military = Military()
    /// Fleets, ships, sailors, blockades, and naval battles (Phase 10).
    public var navy = Navy()
    /// Diplomatic relations, treaties, opinions, and wars (Phase 7).
    public var diplomacy = Diplomacy()
    /// Holy sites, missionaries, and religious movements (Phase 11).
    public var faith = FaithState()
    /// Plague, famine and earthquakes (Phase 12).
    public var calamity = CalamityState()
    /// Fault zones and known earthquakes (fixed data, not saved).
    public var calamityRules = CalamityRules()
    /// Unrest per province and rebel factions (Phase 12).
    public var unrest = UnrestState()
    /// Technology levels, research progress and institutions (Phase 13).
    public var tech = TechState()
    /// Technology tracks, starting levels and institution rules (fixed data, not saved).
    public var techRules = TechRules()
    /// Historical & chronicle events state, flags, modifiers and pending choices (Phase 14).
    public var events = EventsState()
    /// Event definitions and pre-filtered indices (fixed data, not saved).
    public var eventRules = EventRules()
    /// AI behaviour setting and per-country goal progress (Phase 15).
    public var ai = AIState()
    /// Historical AI goal lists loaded from `ai_goals1453.json` (fixed data, not saved).
    public var aiRules = AIGoalRules()
    /// Chronicle events, regnal chapters, yearly stats, and map timelapse (Phase 18).
    public var history = HistoryState()

    public init(map: MapInfo = MapInfo(width: 1, height: 1, pixelsPerDegree: 1, longitudeMin: 0, latitudeMax: 0)) {
        self.map = map
    }

    public func provinces(ownedBy country: CountryID) -> [ProvinceID] {
        provinces.ids.filter { provinces.owner[$0.index] == country }
    }

    public func areNeighbors(_ a: CountryID, _ b: CountryID) -> Bool {
        guard a != b else { return false }
        for p in provinces(ownedBy: a) {
            for n in provinces.neighbors[p.index] {
                if provinces.owner[n.index] == b {
                    return true
                }
            }
        }
        return false
    }

    public func totalDevelopment(of country: CountryID) -> Int {
        var dev = 0
        for p in provinces(ownedBy: country) {
            dev += provinces.development[p.index]
        }
        return dev
    }

    public func totalSoldiers(of country: CountryID) -> Int {
        var total = 0
        for aid in military.armies(of: country) {
            let i = Int(aid.rawValue)
            for reg in military.armies.regiments[i] {
                total += reg.men
            }
        }
        return total
    }

    public func isRiverBorder(_ a: ProvinceID, _ b: ProvinceID) -> Bool {
        riverBorders.contains(ProvincePair(a, b))
    }

    public func isStrait(_ a: ProvinceID, _ b: ProvinceID) -> Bool {
        straitSeas[ProvincePair(a, b)] != nil
    }

    public func straitSeaZones(between a: ProvinceID, and b: ProvinceID) -> [SeaZoneID] {
        straitSeas[ProvincePair(a, b)] ?? []
    }

    /// True if `province` borders at least one navigable sea zone (excludes inland lakes).
    public func hasSeaAccess(_ province: ProvinceID) -> Bool {
        let p = province.index
        guard p >= 0 && p < provinces.count && provinces.isCoastal[p] else { return false }
        if p < provinceSeas.count {
            return !provinceSeas[p].isEmpty
        }
        return true
    }

    /// Concurrent ship building slots in `province` (0 if inland or lacking Shipyard/Docks).
    public func dockCapacity(in province: ProvinceID) -> Int {
        guard hasSeaAccess(province) else { return 0 }
        var slots = 0
        for t in 0..<economy.buildings.typeCount {
            if case .ships(let x) = economy.buildingTypes[t].effect {
                let lvl = economy.buildings.level(province, BuildingTypeID(t))
                if lvl > 0 {
                    slots += lvl * max(1, Int(x.rounded()))
                }
            }
        }
        return slots
    }

    public func stateName(of province: ProvinceID) -> String {
        states.name[provinces.state[province.index].index]
    }

    public func regionName(of province: ProvinceID) -> String {
        regions[states.region[provinces.state[province.index].index].index]
    }

    /// Adds a province and records it in its state's province list.
    @discardableResult
    public mutating func addProvince(
        name: String,
        location: GeoPoint,
        state: StateID,
        terrain: Terrain,
        isCoastal: Bool = false,
        areaKm2: Double = 0,
        labelPoint: MapPoint = MapPoint(x: 0, y: 0),
        owner: CountryID?,
        development: Int,
        population: Double,
        baseTax: Double,
        production: Double,
        religion: Religion,
        fortLevel: Int
    ) -> ProvinceID {
        let id = provinces.add(
            name: name, location: location, state: state, terrain: terrain,
            isCoastal: isCoastal, areaKm2: areaKm2, labelPoint: labelPoint,
            owner: owner, development: development, population: population,
            baseTax: baseTax, production: production, religion: religion,
            fortLevel: fortLevel
        )
        states.attach(id, to: state)
        return id
    }
}
