import Foundation

/// A sacred city or shrine attached to a province and one or more religions.
public struct HolySite: Sendable, Equatable, Codable {
    public let name: String
    public let province: ProvinceID
    public let religions: [Religion]

    public init(name: String, province: ProvinceID, religions: [Religion]) {
        self.name = name
        self.province = province
        self.religions = religions
    }

    public func isSacred(to religion: Religion) -> Bool {
        religions.contains(religion)
    }
}

/// An active state missionary converting non-state pops in an owned province.
public struct MissionaryAssignment: Sendable, Equatable, Codable {
    public var country: CountryID
    public var province: ProvinceID

    public init(country: CountryID, province: ProvinceID) {
        self.country = country
        self.province = province
    }
}

/// A Reformation hub spreading Protestant or Reformed ideas to nearby provinces
/// and along trade routes.
public struct ReformationCentre: Sendable, Equatable, Codable {
    public var province: ProvinceID
    public var religion: Religion
    public var foundedYear: Int
    public var monthsActive: Int

    public init(province: ProvinceID, religion: Religion, foundedYear: Int, monthsActive: Int = 0) {
        self.province = province
        self.religion = religion
        self.foundedYear = foundedYear
        self.monthsActive = monthsActive
    }
}

/// Resolution of the Utraquist / Taborite question in Bohemia after 1453.
public enum HussiteOutcome: String, Sendable, Codable, CaseIterable {
    case unresolved
    case utraquistCompacts
    case taboriteRevival
    case catholicSubmission

    public var displayName: String {
        switch self {
        case .unresolved: return "Debate in Bohemia"
        case .utraquistCompacts: return "Compacts upheld"
        case .taboriteRevival: return "Taborite zealotry"
        case .catholicSubmission: return "Submitted to Rome"
        }
    }
}

/// Trajectory of a historical religious movement.
public enum MovementPhase: String, Sendable, Codable, CaseIterable {
    case dormant
    case growing
    case militant
    case triumphant

    public var displayName: String {
        switch self {
        case .dormant: return "Quiet"
        case .growing: return "Growing"
        case .militant: return "Qizilbash uprising"
        case .triumphant: return "Safavid triumph"
        }
    }
}

/// Mutable world state for holy sites, missionaries, and religious movements (Phase 11).
public struct FaithState: Sendable, Equatable, Codable {
    public var holySites: [HolySite] = []
    /// Province indices that host a holy site, mapping to indices into `holySites`.
    public var holySitesByProvince: [Int: [Int]] = [:]
    /// Active country missionaries (at most one per province; capped per country).
    public var missionaries: [MissionaryAssignment] = []
    /// While true, Catholic <-> Hussite pop conversion is blocked by the Compacts of Basel.
    public var hussiteCompactsActive: Bool = true
    public var hussiteOutcome: HussiteOutcome = .unresolved
    /// Ardabil Safaviyya -> Qizilbash -> Safavid state-faith rise.
    public var safaviyyaPhase: MovementPhase = .growing
    public var safaviyyaStrength: Double = 0.25
    /// Year when Safaviyya rose or converted its realm (nil until militant/triumphant).
    public var safaviyyaYear: Int? = nil
    /// Whether the Protestant / Reformed Reformation has begun (never before 1500).
    public var reformationStarted: Bool = false
    public var reformationCentres: [ReformationCentre] = []
    public var reformationReligions: Set<Religion> = []
    /// Cached prestige per country from held holy sites (for UI readouts).
    public var holySiteCountHeld: [Int] = []

    public init() {}
}
