import Foundation

/// New-game setting controlling how non-human countries pick their goals.
public enum AIBehaviourSetting: String, CaseIterable, Sendable, Codable {
    case historical
    case free

    public var displayName: String {
        switch self {
        case .historical: return "Historical"
        case .free: return "Free"
        }
    }

    public var summaryDescription: String {
        switch self {
        case .historical:
            return "AI pursues post-1453 historical goals when feasible, falling back to Free if its list runs out."
        case .free:
            return "AI evaluates opportunities purely from threats, weak neighbours, wealth, alliances, and ruler traits."
        }
    }
}

/// Action type for a historical AI goal.
public enum AIGoalType: String, CaseIterable, Sendable, Codable {
    case conquerProvince = "conquer_province"
    case defendProvince = "defend_province"
    case allyWith = "ally_with"
    case vassalize = "vassalize"
    case keepPeaceWith = "keep_peace_with"
    case buildUp = "build_up"
}

/// Target focus for `build_up` goals.
public enum AIGoalBuildFocus: String, CaseIterable, Sendable, Codable {
    case army
    case economy
}

/// A single historical goal loaded from `ai_goals1453.json`.
public struct AIGoalDef: Sendable, Equatable {
    public let id: String
    public let country: CountryID
    public let type: AIGoalType
    public let target: String
    public let targetProvince: ProvinceID?
    public let targetCountry: CountryID?
    public let buildFocus: AIGoalBuildFocus?
    public let earliestDate: GameDate
    public let giveUpDate: GameDate
    public let priority: Int
    public let note: String

    public init(
        id: String,
        country: CountryID,
        type: AIGoalType,
        target: String,
        targetProvince: ProvinceID? = nil,
        targetCountry: CountryID? = nil,
        buildFocus: AIGoalBuildFocus? = nil,
        earliestDate: GameDate,
        giveUpDate: GameDate,
        priority: Int,
        note: String = ""
    ) {
        self.id = id
        self.country = country
        self.type = type
        self.target = target
        self.targetProvince = targetProvince
        self.targetCountry = targetCountry
        self.buildFocus = buildFocus
        self.earliestDate = earliestDate
        self.giveUpDate = giveUpDate
        self.priority = priority
        self.note = note
    }
}

/// Static historical goal definitions and per-country ordered indices (not saved).
public struct AIGoalRules: Sendable {
    public var goals: [AIGoalDef] = []
    public var goalsByCountry: [[Int]] = []
    private var indexByID: [String: Int] = [:]

    public init() {}

    public mutating func setGoals(_ defs: [AIGoalDef], countryCount: Int) {
        self.goals = defs
        self.goalsByCountry = Array(repeating: [], count: max(0, countryCount))
        self.indexByID = [:]
        for (idx, def) in defs.enumerated() {
            indexByID[def.id] = idx
            if def.country.index >= 0 && def.country.index < goalsByCountry.count {
                goalsByCountry[def.country.index].append(idx)
            }
        }
        // Sort each country's list by priority descending, preserving file order on ties.
        for c in 0..<goalsByCountry.count {
            goalsByCountry[c].sort { a, b in
                let ga = goals[a]
                let gb = goals[b]
                if ga.priority != gb.priority { return ga.priority > gb.priority }
                return a < b
            }
        }
    }

    public func goal(id: String) -> AIGoalDef? {
        indexByID[id].map { goals[$0] }
    }
}

/// Mutable per-country AI setting and goal progress saved in `.gezsave` files.
public struct AIState: Sendable, Codable, Equatable {
    public var setting: AIBehaviourSetting = .historical
    public var completedGoalIDs: [Set<String>] = []
    public var skippedGoalIDs: [Set<String>] = []
    public var currentGoalID: [String?] = []
    public var currentGoalLabel: [String] = []
    public var usingFreeFallback: [Bool] = []

    public init() {}

    public mutating func resize(countries n: Int) {
        let count = max(0, n)
        if completedGoalIDs.count < count {
            completedGoalIDs.append(contentsOf: repeatElement(Set<String>(), count: count - completedGoalIDs.count))
        } else if completedGoalIDs.count > count {
            completedGoalIDs.removeLast(completedGoalIDs.count - count)
        }
        if skippedGoalIDs.count < count {
            skippedGoalIDs.append(contentsOf: repeatElement(Set<String>(), count: count - skippedGoalIDs.count))
        } else if skippedGoalIDs.count > count {
            skippedGoalIDs.removeLast(skippedGoalIDs.count - count)
        }
        if currentGoalID.count < count {
            currentGoalID.append(contentsOf: repeatElement(nil, count: count - currentGoalID.count))
        } else if currentGoalID.count > count {
            currentGoalID.removeLast(currentGoalID.count - count)
        }
        if currentGoalLabel.count < count {
            currentGoalLabel.append(contentsOf: repeatElement("", count: count - currentGoalLabel.count))
        } else if currentGoalLabel.count > count {
            currentGoalLabel.removeLast(currentGoalLabel.count - count)
        }
        if usingFreeFallback.count < count {
            usingFreeFallback.append(contentsOf: repeatElement(false, count: count - usingFreeFallback.count))
        } else if usingFreeFallback.count > count {
            usingFreeFallback.removeLast(usingFreeFallback.count - count)
        }
    }
}
