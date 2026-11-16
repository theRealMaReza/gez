import Foundation

/// Pure-Swift deterministic tactical battle & siege assault engine (fixed 10 ticks per battle second).
public struct BattleEngine: Sendable, Equatable {
    public static let ticksPerSecond: Int = 10
    public static let dt: Double = 1.0 / Double(ticksPerSecond)
    /// Battle pace (owner's choice, session 7: a battle led in person lasts
    /// about 2-4 minutes at 1x). Casualties per hit and melee fatigue are
    /// multiplied by this; ammunition is divided by it so archers and guns keep
    /// the same share of the fighting. Wall damage is not scaled.
    public static let pace: Double = 0.125
    /// Safety time limits (then the side with more men left wins): 10 minutes
    /// for a field battle, 15 for an assault, well above the 2-4 minutes a
    /// battle normally takes, so fights end on the field, not on the clock.
    public static let fieldTimeLimitTicks = 10 * 60 * ticksPerSecond
    public static let assaultTimeLimitTicks = 15 * 60 * ticksPerSecond

    public let seed: UInt64
    public let province: ProvinceID
    public let provinceName: String
    public let kind: BattleKind
    public let playerSide: BattleSide?
    public let mapBattleID: String?
    public let isAssault: Bool
    public let attackerAmbushed: Bool
    public let defenderAmbushed: Bool

    public let attackerCountry: CountryID
    public let defenderCountry: CountryID
    public let attackerName: String
    public let defenderName: String
    public let attackerTag: String
    public let defenderTag: String
    public let attackerColor: RGB
    public let defenderColor: RGB
    public let attackerDiscipline: Double
    public let defenderDiscipline: Double

    public var battlefield: Battlefield
    public var units: BattleUnitTable
    public var structures: [FortStructure]
    public var attackerCommander: BattleCommanderInfo?
    public var defenderCommander: BattleCommanderInfo?

    public var phase: BattleControlPhase
    public var speed: BattleSpeed
    public var tickCount: Int
    public var winner: BattleSide?
    public var wasStackwipe: Bool
    public var keepCaptured: Bool
    public var keepCaptureProgress: Double
    public var random: GameRandom

    private var timeAccumulator: Double = 0.0

    public var elapsedSeconds: Double {
        Double(tickCount) * Self.dt
    }

    public var assaultFortLevel: Int {
        if case .assault(let lvl, _) = kind { return max(1, lvl) }
        return 0
    }

    public init(
        world: World,
        battle: Battle,
        playerSide: BattleSide?,
        seed: UInt64
    ) {
        self.seed = seed
        self.province = battle.province
        self.provinceName = world.provinces.name[battle.province.index]
        self.kind = .field
        self.playerSide = playerSide
        self.mapBattleID = battle.id
        self.isAssault = false
        self.attackerAmbushed = battle.isRiverCrossing
        self.defenderAmbushed = false

        self.attackerCountry = battle.attackerCountry
        self.defenderCountry = battle.defenderCountry
        self.attackerName = world.countries.name[battle.attackerCountry.index]
        self.defenderName = world.countries.name[battle.defenderCountry.index]
        self.attackerTag = world.countries.tag[battle.attackerCountry.index]
        self.defenderTag = world.countries.tag[battle.defenderCountry.index]
        self.attackerColor = world.countries.color[battle.attackerCountry.index]
        self.defenderColor = world.countries.color[battle.defenderCountry.index]
        self.attackerDiscipline = 1.0 + world.government.modifier(battle.attackerCountry, .armyQuality)
        self.defenderDiscipline = 1.0 + world.government.modifier(battle.defenderCountry, .armyQuality)

        let pIdx = battle.province.index
        let terrain = world.provinces.terrain[pIdx]
        let isCoastal = world.provinces.isCoastal[pIdx]
        let bf = BattlefieldGenerator.generate(
            province: battle.province,
            terrain: terrain,
            isRiverCrossing: battle.isRiverCrossing,
            isCoastal: isCoastal,
            fortLevel: 0,
            existingBreach: false,
            seed: seed
        )
        self.battlefield = bf
        self.structures = bf.structures

        var unitTable = BattleUnitTable()
        self.attackerCommander = Self.populateSideUnits(
            world: world,
            armyIDs: battle.attackers,
            side: .attacker,
            into: &unitTable
        )
        self.defenderCommander = Self.populateSideUnits(
            world: world,
            armyIDs: battle.defenders,
            side: .defender,
            into: &unitTable
        )
        self.units = unitTable

        self.random = GameRandom(seed: BattlefieldGenerator.combinedSeed(province: battle.province, seed: seed) ^ 0xA5A5A5A5A5A5A5A5)
        self.tickCount = 0
        self.winner = nil
        self.wasStackwipe = false
        self.keepCaptured = false
        self.keepCaptureProgress = 0.0
        self.speed = .normal

        // Ambushed river crossing skips deployment if player was caught crossing.
        let playerAmbushed = (playerSide == .attacker && battle.isRiverCrossing)
        self.phase = (playerSide == nil || playerAmbushed) ? .active : .deployment

        if self.attackerAmbushed {
            placeAmbushedCrossingSide(.attacker)
        } else {
            autoDeploySide(.attacker)
        }
        autoDeploySide(.defender)
    }

    public init(
        world: World,
        province: ProvinceID,
        attackerCountry: CountryID,
        defenderCountry: CountryID,
        attackerArmies: [ArmyID],
        fortLevel: Int,
        existingBreach: Bool,
        garrisonMen: Int,
        playerSide: BattleSide?,
        seed: UInt64
    ) {
        self.seed = seed
        self.province = province
        self.provinceName = world.provinces.name[province.index]
        self.kind = .assault(fortLevel: fortLevel, existingBreach: existingBreach)
        self.playerSide = playerSide
        self.mapBattleID = nil
        self.isAssault = true
        self.attackerAmbushed = false
        self.defenderAmbushed = false

        self.attackerCountry = attackerCountry
        self.defenderCountry = defenderCountry
        self.attackerName = world.countries.name[attackerCountry.index]
        self.defenderName = world.countries.name[defenderCountry.index]
        self.attackerTag = world.countries.tag[attackerCountry.index]
        self.defenderTag = world.countries.tag[defenderCountry.index]
        self.attackerColor = world.countries.color[attackerCountry.index]
        self.defenderColor = world.countries.color[defenderCountry.index]
        self.attackerDiscipline = 1.0 + world.government.modifier(attackerCountry, .armyQuality)
        self.defenderDiscipline = 1.0 + world.government.modifier(defenderCountry, .armyQuality)

        let pIdx = province.index
        let bf = BattlefieldGenerator.generate(
            province: province,
            terrain: world.provinces.terrain[pIdx],
            isRiverCrossing: false,
            isCoastal: world.provinces.isCoastal[pIdx],
            fortLevel: fortLevel,
            existingBreach: existingBreach,
            seed: seed
        )
        self.battlefield = bf
        self.structures = bf.structures

        var unitTable = BattleUnitTable()
        self.attackerCommander = Self.populateSideUnits(
            world: world,
            armyIDs: attackerArmies,
            side: .attacker,
            into: &unitTable
        )
        Self.populateGarrisonUnits(
            world: world,
            defenderCountry: defenderCountry,
            garrisonMen: garrisonMen,
            province: province,
            into: &unitTable
        )
        self.defenderCommander = BattleCommanderInfo(
            characterID: nil,
            name: "Castellan of \(world.provinces.name[province.index])",
            martial: 4 + min(4, fortLevel),
            country: defenderCountry,
            armyID: nil,
            fate: .active
        )
        self.units = unitTable

        self.random = GameRandom(seed: BattlefieldGenerator.combinedSeed(province: province, seed: seed) ^ 0x5A5A5A5A5A5A5A5A)
        self.tickCount = 0
        self.winner = nil
        self.wasStackwipe = false
        self.keepCaptured = false
        self.keepCaptureProgress = 0.0
        self.speed = .normal
        self.phase = playerSide == nil ? .active : .deployment

        autoDeploySide(.attacker)
        autoDeploySide(.defender)
        assignInitialAssaultEquipment(existingBreach: existingBreach)
    }

    // MARK: - Unit Population

    private static func populateSideUnits(
        world: World,
        armyIDs: [ArmyID],
        side: BattleSide,
        into table: inout BattleUnitTable
    ) -> BattleCommanderInfo? {
        var bestCommander: BattleCommanderInfo?
        let defaultFacing = (side == .attacker) ? 0.0 : Double.pi

        for aid in armyIDs {
            let aIdx = Int(aid.rawValue)
            guard aIdx >= 0, aIdx < world.military.armies.count, world.military.armies.alive[aIdx] else { continue }
            let country = world.military.armies.owner[aIdx]

            if let cmdID = world.military.armies.commander[aIdx], world.people.characters.isAlive(cmdID) {
                let martial = world.people.characters.skill(cmdID, .martial)
                if bestCommander == nil || martial > bestCommander!.martial {
                    bestCommander = BattleCommanderInfo(
                        characterID: cmdID,
                        name: world.people.characters.name[cmdID.index],
                        martial: martial,
                        country: country,
                        armyID: aid
                    )
                }
            }

            let regiments = world.military.armies.regiments[aIdx]
            for (rIdx, reg) in regiments.enumerated() where reg.men > 0 {
                let unit = world.military.unit(reg.type)
                let form: BattleFormation
                if unit.key == "war_wagons" {
                    form = .wagonLaager
                } else if unit.category == .ranged {
                    form = .skirmish
                } else {
                    form = .line
                }
                let maxM = max(1.0, unit.morale)
                let curM = max(0.1, min(maxM, reg.morale))
                table.append(
                    sourceArmyID: aid,
                    sourceRegimentIndex: rIdx,
                    isGarrison: false,
                    side: side,
                    country: country,
                    unitType: reg.type,
                    unitKey: unit.key,
                    unitName: unit.name,
                    category: unit.category,
                    origin: reg.origin,
                    homeProvince: reg.homeProvince,
                    attack: unit.attack,
                    defence: unit.defence,
                    baseSpeed: defaultBaseSpeed(category: unit.category, unitKey: unit.key),
                    maxMen: max(1, unit.maxMen),
                    men: reg.men,
                    maxMorale: maxM,
                    morale: curM,
                    ammo: defaultAmmo(unitKey: unit.key, category: unit.category),
                    x: 100.0,
                    y: 400.0,
                    facing: defaultFacing,
                    formation: form,
                    stance: .hold
                )
            }
        }
        return bestCommander
    }

    private static func populateGarrisonUnits(
        world: World,
        defenderCountry: CountryID,
        garrisonMen: Int,
        province: ProvinceID,
        into table: inout BattleUnitTable
    ) {
        let total = max(100, garrisonMen)
        let infType = world.military.unitByKey["infantry"] ?? UnitTypeID(0)
        let archType = world.military.unitByKey["archers"] ?? infType
        let infUnit = world.military.unit(infType)
        let archUnit = world.military.unit(archType)

        // Split garrison ~65% infantry defenders, ~35% archers
        let archTotal = max(0, Int(Double(total) * 0.35))
        let infTotal = max(1, total - archTotal)

        func addChunks(remaining: Int, unit: UnitType, typeID: UnitTypeID, form: BattleFormation) {
            var left = remaining
            while left > 0 {
                let chunk = min(max(100, unit.maxMen), left)
                left -= chunk
                table.append(
                    sourceArmyID: nil,
                    sourceRegimentIndex: -1,
                    isGarrison: true,
                    side: .defender,
                    country: defenderCountry,
                    unitType: typeID,
                    unitKey: unit.key,
                    unitName: "\(unit.name) (Garrison)",
                    category: unit.category,
                    origin: .professional,
                    homeProvince: province,
                    attack: unit.attack,
                    defence: unit.defence,
                    baseSpeed: defaultBaseSpeed(category: unit.category, unitKey: unit.key),
                    maxMen: max(1, unit.maxMen),
                    men: chunk,
                    maxMorale: max(1.0, unit.morale),
                    morale: max(0.5, unit.morale),
                    ammo: defaultAmmo(unitKey: unit.key, category: unit.category),
                    x: 920.0,
                    y: 400.0,
                    facing: Double.pi,
                    formation: form,
                    stance: .hold
                )
            }
        }

        addChunks(remaining: infTotal, unit: infUnit, typeID: infType, form: .line)
        if archTotal > 0 {
            addChunks(remaining: archTotal, unit: archUnit, typeID: archType, form: .skirmish)
        }
    }

    public static func defaultAmmo(unitKey: String, category: UnitCategory) -> Int {
        let volleys: Int
        switch category {
        case .ranged:
            if unitKey == "handgunners" { volleys = 12 }
            else if unitKey == "musketeers" { volleys = 16 }
            else if unitKey == "longbowmen" { volleys = 18 }
            else { volleys = 16 }
        case .artillery:
            volleys = 12
        case .cavalry:
            volleys = (unitKey == "horse_archers" || unitKey == "dragoons") ? 16 : 0
        case .infantry:
            if unitKey == "war_wagons" { volleys = 14 }
            else if unitKey == "maurician_infantry" || unitKey == "line_infantry" { volleys = 14 }
            else { volleys = 0 }
        }
        return Int((Double(volleys) / pace).rounded())
    }

    public static func defaultBaseSpeed(category: UnitCategory, unitKey: String) -> Double {
        if unitKey == "war_wagons" { return 24.0 }
        if unitKey == "war_elephants" { return 34.0 }
        switch category {
        case .infantry: return 32.0
        case .ranged: return 33.0
        case .cavalry: return 54.0
        case .artillery: return 18.0
        }
    }

    // MARK: - Deployment

    /// Places a side's regiments in a structured battle line inside its deployment zone.
    public mutating func autoDeploySide(_ side: BattleSide) {
        if isAssault && side == .defender {
            autoDeployAssaultDefenders()
            return
        }

        let zone = battlefield.deploymentZone(for: side)
        let facing = (side == .attacker) ? 0.0 : Double.pi
        let dirSign = (side == .attacker) ? 1.0 : -1.0

        var frontline: [Int] = []
        var ranged: [Int] = []
        var cavalry: [Int] = []
        var artillery: [Int] = []

        for i in 0..<units.count where units.side[i] == side {
            switch units.category[i] {
            case .infantry: frontline.append(i)
            case .ranged: ranged.append(i)
            case .cavalry: cavalry.append(i)
            case .artillery: artillery.append(i)
            }
        }

        let frontX = side == .attacker ? (zone.maxX - 48.0) : (zone.minX + 48.0)
        let midX = frontX - dirSign * 64.0
        let rearX = frontX - dirSign * 128.0

        placeRank(frontline, x: frontX, yMin: zone.minY + 120.0, yMax: zone.maxY - 120.0, zone: zone, facing: facing)
        placeRank(ranged, x: midX, yMin: zone.minY + 110.0, yMax: zone.maxY - 110.0, zone: zone, facing: facing)
        placeRank(artillery, x: rearX, yMin: zone.minY + 160.0, yMax: zone.maxY - 160.0, zone: zone, facing: facing)

        // Cavalry distributed onto top & bottom flanks
        if !cavalry.isEmpty {
            let half = (cavalry.count + 1) / 2
            let north = Array(cavalry.prefix(half))
            let south = Array(cavalry.dropFirst(half))
            placeRank(north, x: frontX - dirSign * 16.0, yMin: zone.minY + 25.0, yMax: zone.minY + 115.0, zone: zone, facing: facing)
            placeRank(south, x: frontX - dirSign * 16.0, yMin: zone.maxY - 115.0, yMax: zone.maxY - 25.0, zone: zone, facing: facing)
        }
    }

    private mutating func placeRank(
        _ indices: [Int],
        x: Double,
        yMin: Double,
        yMax: Double,
        zone: TacticalRect,
        facing: Double
    ) {
        guard !indices.isEmpty else { return }
        let span = max(40.0, yMax - yMin)
        for (k, uIdx) in indices.enumerated() {
            let frac = indices.count == 1 ? 0.5 : (Double(k) / Double(indices.count - 1))
            let rawY = yMin + frac * span
            let pt = zone.clamped(x, rawY, margin: 18.0)
            units.posX[uIdx] = pt.x
            units.posY[uIdx] = pt.y
            units.targetX[uIdx] = pt.x
            units.targetY[uIdx] = pt.y
            units.facing[uIdx] = facing
            units.hasMoveOrder[uIdx] = false
        }
    }

    /// Places an ambushed side mid-river-crossing at the fords in column formation.
    public mutating func placeAmbushedCrossingSide(_ side: BattleSide) {
        let sideUnits = (0..<units.count).filter { units.side[$0] == side }
        guard !sideUnits.isEmpty else { return }
        let facing = (side == .attacker) ? 0.0 : Double.pi

        if let river = battlefield.river, !river.fords.isEmpty {
            for (k, uIdx) in sideUnits.enumerated() {
                let ford = river.fords[k % river.fords.count]
                let rowInFord = k / river.fords.count
                let jitterX = Double((rowInFord % 3) - 1) * 26.0 - 20.0
                let jitterY = Double((rowInFord / 3) - 0) * 18.0
                let px = max(40.0, min(battlefield.width - 40.0, ford.centerX + jitterX))
                let py = max(40.0, min(battlefield.height - 40.0, ford.centerY + jitterY))
                units.posX[uIdx] = px
                units.posY[uIdx] = py
                units.targetX[uIdx] = px
                units.targetY[uIdx] = py
                units.facing[uIdx] = facing
                units.formation[uIdx] = .column
                units.updateFootprint(for: uIdx)
            }
        } else {
            autoDeploySide(side)
        }
    }

    /// Moves and rotates a player unit within its deployment zone during `.deployment`.
    @discardableResult
    public mutating func deployMoveUnit(unitIndex: Int, x: Double, y: Double, facing: Double? = nil) -> Bool {
        guard phase == .deployment,
              unitIndex >= 0, unitIndex < units.count,
              units.men[unitIndex] > 0 else { return false }

        let uSide = units.side[unitIndex]
        if let pSide = playerSide, uSide != pSide {
            return false
        }
        if (uSide == .attacker && attackerAmbushed) || (uSide == .defender && defenderAmbushed) {
            return false
        }

        let zone = battlefield.deploymentZone(for: uSide)
        let clamped = zone.clamped(x, y, margin: 16.0)
        units.posX[unitIndex] = clamped.x
        units.posY[unitIndex] = clamped.y
        units.targetX[unitIndex] = clamped.x
        units.targetY[unitIndex] = clamped.y
        units.hasMoveOrder[unitIndex] = false
        if let facing {
            units.facing[unitIndex] = facing
        }
        return true
    }

    private mutating func autoDeployAssaultDefenders() {
        let zone = battlefield.deploymentZone(for: .defender)
        var rampart: [Int] = []
        var reserve: [Int] = []
        for i in 0..<units.count where units.side[i] == .defender {
            if units.category[i] == .ranged || rampart.count < 2 {
                rampart.append(i)
            } else {
                reserve.append(i)
            }
        }
        placeRank(rampart, x: 768.0, yMin: zone.minY + 80.0, yMax: zone.maxY - 80.0, zone: zone, facing: Double.pi)
        for i in rampart {
            units.isOnWall[i] = true
        }
        placeRank(reserve, x: 940.0, yMin: zone.minY + 180.0, yMax: zone.maxY - 180.0, zone: zone, facing: Double.pi)
        for i in reserve {
            units.isOnWall[i] = false
        }
    }

    private mutating func assignInitialAssaultEquipment(existingBreach: Bool) {
        var infUnits: [Int] = []
        var artUnits: [Int] = []
        for i in 0..<units.count where units.side[i] == .attacker {
            if units.category[i] == .infantry && units.unitKey[i] != "war_wagons" {
                infUnits.append(i)
            } else if units.category[i] == .artillery {
                artUnits.append(i)
            }
        }
        if !infUnits.isEmpty {
            // Assign battering ram to first infantry regiment targeting the main gate, others ladders (or breach storm if already breached)
            let ramTarget = structures.first(where: { $0.kind == .gate && !$0.breached })?.id ?? -1
            let wallTarget = structures.first(where: { $0.kind == .wall && !$0.breached })?.id ?? -1
            for (idx, u) in infUnits.enumerated() {
                if !existingBreach {
                    if idx == 0 && ramTarget >= 0 {
                        units.siegeEquipment[u] = .ram
                        units.targetStructure[u] = ramTarget
                    } else if wallTarget >= 0 {
                        units.siegeEquipment[u] = .ladders
                        units.targetStructure[u] = wallTarget
                    }
                } else {
                    units.siegeEquipment[u] = .none
                    units.targetStructure[u] = -1
                }
            }
        }
        if !artUnits.isEmpty && !existingBreach {
            let targetID = structures.first(where: { ($0.kind == .wall || $0.kind == .gate) && !$0.breached })?.id ?? -1
            for u in artUnits {
                units.targetStructure[u] = targetID
                units.stance[u] = .volley
            }
        }
    }

    /// Transitions from Deployment into real-time combat.
    @discardableResult
    public mutating func startBattle() -> Bool {
        guard phase == .deployment else { return false }
        phase = .active
        return true
    }

    public mutating func setSpeed(_ newSpeed: BattleSpeed) {
        speed = newSpeed
    }

    // MARK: - Tactical Orders (Part B)

    public mutating func issueMoveOrder(unitIndices: [Int], x: Double, y: Double) {
        BattleCombat.issueMoveOrder(engine: &self, unitIndices: unitIndices, x: x, y: y)
    }

    public mutating func issuePathOrder(unitIndices: [Int], points: [TacticalPoint]) {
        BattleCombat.issuePathOrder(engine: &self, unitIndices: unitIndices, points: points)
    }

    public mutating func issueFrontlineOrder(unitIndices: [Int], start: TacticalPoint, end: TacticalPoint) {
        BattleCombat.issueFrontlineOrder(engine: &self, unitIndices: unitIndices, start: start, end: end)
    }

    public mutating func issueAttackOrder(unitIndices: [Int], targetUnitIndex: Int) {
        BattleCombat.issueAttackOrder(engine: &self, unitIndices: unitIndices, targetUnitIndex: targetUnitIndex)
    }

    public mutating func issueFormationOrder(unitIndices: [Int], formation: BattleFormation) {
        BattleCombat.issueFormationOrder(engine: &self, unitIndices: unitIndices, formation: formation)
    }

    public mutating func issueStanceOrder(unitIndices: [Int], stance: BattleStance) {
        BattleCombat.issueStanceOrder(engine: &self, unitIndices: unitIndices, stance: stance)
    }

    public mutating func issueRetreatOrder(unitIndices: [Int]) {
        BattleCombat.issueRetreatOrder(engine: &self, unitIndices: unitIndices)
    }

    // MARK: - Tactical Orders (Part C: Siege Assaults)

    public mutating func issueSiegeEquipmentOrder(unitIndices: [Int], equipment: SiegeEquipmentKind) {
        BattleCombat.issueSiegeEquipmentOrder(engine: &self, unitIndices: unitIndices, equipment: equipment)
    }

    public mutating func issueAttackStructureOrder(unitIndices: [Int], structureID: Int) {
        BattleCombat.issueAttackStructureOrder(engine: &self, unitIndices: unitIndices, structureID: structureID)
    }

    // MARK: - Fixed-Timestep Simulation

    /// Advances real-time elapsed seconds into fixed 10 Hz battle ticks.
    /// Returns the number of fixed simulation ticks stepped.
    @discardableResult
    public mutating func tick(deltaSeconds: Double) -> Int {
        guard phase == .active, speed != .paused, deltaSeconds > 0 else {
            return 0
        }
        timeAccumulator += min(0.25, deltaSeconds) * speed.multiplier
        var steps = 0
        while timeAccumulator >= Self.dt && steps < 10 {
            timeAccumulator -= Self.dt
            stepOneTick()
            steps += 1
        }
        return steps
    }

    /// Steps an exact number of fixed battle ticks (`0.1s` each), ignoring pause/speed.
    public mutating func stepTicks(_ count: Int) {
        guard count > 0, phase == .active else { return }
        for _ in 0..<count {
            if phase != .active { break }
            stepOneTick()
        }
    }

    private mutating func stepOneTick() {
        guard phase == .active else { return }
        tickCount += 1
        BattleAI.update(engine: &self)
        BattleCombat.stepTick(engine: &self)
    }

    public static func == (lhs: BattleEngine, rhs: BattleEngine) -> Bool {
        lhs.seed == rhs.seed
            && lhs.province == rhs.province
            && lhs.kind == rhs.kind
            && lhs.phase == rhs.phase
            && lhs.speed == rhs.speed
            && lhs.tickCount == rhs.tickCount
            && lhs.winner == rhs.winner
            && lhs.wasStackwipe == rhs.wasStackwipe
            && lhs.keepCaptured == rhs.keepCaptured
            && lhs.keepCaptureProgress == rhs.keepCaptureProgress
            && lhs.random.rawState == rhs.random.rawState
            && lhs.battlefield == rhs.battlefield
            && lhs.units == rhs.units
            && lhs.structures == rhs.structures
            && lhs.attackerCommander == rhs.attackerCommander
            && lhs.defenderCommander == rhs.defenderCommander
    }
}
