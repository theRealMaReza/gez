import Foundation

/// One rendered entry in a regnal chapter of the Chronicle Book.
public struct ChronicleRenderedEntry: Sendable, Equatable {
    public var dateText: String
    public var kindKey: String
    public var prose: String

    public init(dateText: String, kindKey: String, prose: String) {
        self.dateText = dateText
        self.kindKey = kindKey
        self.prose = prose
    }
}

/// One ruler's chapter in a country's Chronicle Book.
public struct ChronicleChapterView: Sendable, Equatable {
    public var rulerName: String
    public var dynastyName: String
    public var spanText: String
    public var entries: [ChronicleRenderedEntry]

    public init(rulerName: String, dynastyName: String, spanText: String, entries: [ChronicleRenderedEntry]) {
        self.rulerName = rulerName
        self.dynastyName = dynastyName
        self.spanText = spanText
        self.entries = entries
    }
}

/// Loads `chronicle_templates.json` and renders structured `ChronicleEventTable`
/// records into period prose grouped by regnal chapters.
public struct ChronicleTemplateSet: Sendable, Equatable {
    public var templates: [String: [String]]

    public init(templates: [String: [String]] = [:]) {
        self.templates = templates
    }

    private struct RawPayload: Decodable {
        var templates: [String: [String]]
    }

    public static func loadDefault() -> ChronicleTemplateSet {
        guard let url = GezResources.url(forResource: "chronicle_templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RawPayload.self, from: data) else {
            return ChronicleTemplateSet()
        }
        return ChronicleTemplateSet(templates: decoded.templates)
    }

    public static let shared: ChronicleTemplateSet = loadDefault()

    public static func kindKey(for kind: ChronicleEventKind) -> String {
        switch kind {
        case .warDeclared: return "war_declared"
        case .warEnded: return "war_ended"
        case .majorBattle: return "major_battle"
        case .navalBattle: return "naval_battle"
        case .siegeCaptured: return "siege_captured"
        case .peaceTreaty: return "peace_treaty"
        case .lawChanged: return "law_changed"
        case .reformAdopted: return "reform_adopted"
        case .plagueOutbreak: return "plague_outbreak"
        case .famine: return "famine"
        case .rebellion: return "rebellion"
        case .rulerCrowned: return "ruler_crowned"
        case .rulerDied: return "ruler_died"
        case .marriage: return "marriage"
        case .heirBorn: return "heir_born"
        case .nationFormed: return "nation_formed"
        }
    }

    /// Renders a single event at `index` in `world.history.events` using its deterministic `templateSeed`.
    public func render(eventIndex index: Int, in world: World) -> String {
        let events = world.history.events
        guard index >= 0, index < events.count, let kind = events.eventKind(at: index) else {
            return ""
        }
        let key = Self.kindKey(for: kind)
        let variants = templates[key] ?? []
        guard !variants.isEmpty else { return "" }

        let seed = events.templateSeed[index]
        let template = variants[Int(seed % UInt32(variants.count))]

        let primaryIdx = Int(events.primaryCountry[index])
        let primaryName = (primaryIdx >= 0 && primaryIdx < world.countries.count)
            ? world.countries.name[primaryIdx]
            : "Unknown Realm"

        let secIdx = Int(events.secondaryCountry[index])
        let secondaryName = (secIdx >= 0 && secIdx < world.countries.count)
            ? world.countries.name[secIdx]
            : "a rival power"

        let provIdx = Int(events.province[index])
        let provName = (provIdx >= 0 && provIdx < world.provinces.count)
            ? world.provinces.name[provIdx]
            : "the frontier"

        let charIdx = Int(events.character[index])
        let charName = (charIdx >= 0 && charIdx < world.people.characters.count)
            ? world.people.characters.fullName(CharacterID(charIdx))
            : "the sovereign"

        let secCharIdx = Int(events.secondaryCharacter[index])
        let secCharName = (secCharIdx >= 0 && secCharIdx < world.people.characters.count)
            ? world.people.characters.fullName(CharacterID(secCharIdx))
            : "a noble house"

        let valA = Int(events.valueA[index])
        let valB = Int(events.valueB[index])
        let detail = resolveDetail(kind: kind, primaryCountryIndex: primaryIdx, valueA: valA, valueB: valB, in: world)

        var text = template
        text = text.replacingOccurrences(of: "{primary}", with: primaryName)
        text = text.replacingOccurrences(of: "{secondary}", with: secondaryName)
        text = text.replacingOccurrences(of: "{province}", with: provName)
        text = text.replacingOccurrences(of: "{character}", with: charName)
        text = text.replacingOccurrences(of: "{secondary_character}", with: secCharName)
        text = text.replacingOccurrences(of: "{value_a}", with: "\(valA)")
        text = text.replacingOccurrences(of: "{value_b}", with: "\(valB)")
        text = text.replacingOccurrences(of: "{detail}", with: detail)
        return text
    }

    private func resolveDetail(
        kind: ChronicleEventKind,
        primaryCountryIndex: Int,
        valueA: Int,
        valueB: Int,
        in world: World
    ) -> String {
        switch kind {
        case .warDeclared:
            let all = CasusBelli.allCases
            if valueA >= 0 && valueA < all.count {
                return all[valueA].rawValue.replacingOccurrences(of: "_", with: " ")
            }
            return "border dispute"
        case .lawChanged:
            let areas = world.government.rules.lawAreas
            if valueA >= 0 && valueA < areas.count && valueB >= 0 && valueB < areas[valueA].options.count {
                return areas[valueA].options[valueB].name
            }
            return "a royal statute"
        case .reformAdopted:
            if primaryCountryIndex >= 0 && primaryCountryIndex < world.countries.count {
                let gov = world.countries.government[primaryCountryIndex]
                if let tree = world.government.rules.reforms[gov],
                   valueA >= 0 && valueA < tree.count,
                   valueB >= 0 && valueB < tree[valueA].options.count {
                    return tree[valueA].options[valueB].name
                }
            }
            return "a state reform"
        case .plagueOutbreak:
            if let d = Disease(rawValue: valueA) {
                return d.displayName.lowercased()
            }
            return "pestilence"
        case .rebellion:
            if let rk = RebelKind(rawValue: valueB) {
                return rk.displayName.lowercased()
            }
            return "rebels"
        case .nationFormed:
            // valueB indexes `world.rulings.formed`: the realm's name before.
            if valueB >= 0 && valueB < world.rulings.formed.count {
                return world.rulings.formed[valueB].previousName
            }
            return "the old realm"
        default:
            return ""
        }
    }

    /// Groups all Chronicle events involving `country` into regnal chapters by ruler.
    public func chapters(for country: CountryID, in world: World) -> [ChronicleChapterView] {
        let chaptersTable = world.history.chapters
        let eventsTable = world.history.events
        let cRaw = Int16(clamping: country.index)

        var countryChapterIndices: [Int] = []
        for i in 0..<chaptersTable.count where chaptersTable.country[i] == cRaw {
            countryChapterIndices.append(i)
        }

        // Collect all event indices involving `country`.
        var countryEventIndices: [Int] = []
        for i in 0..<eventsTable.count where eventsTable.involves(country, at: i) {
            countryEventIndices.append(i)
        }

        if countryChapterIndices.isEmpty {
            guard !countryEventIndices.isEmpty else { return [] }
            let entries = countryEventIndices.map { idx in
                let d = eventsTable.date(at: idx)
                let k = eventsTable.eventKind(at: idx).map(Self.kindKey) ?? "event"
                return ChronicleRenderedEntry(dateText: d.description, kindKey: k, prose: render(eventIndex: idx, in: world))
            }
            return [ChronicleChapterView(rulerName: "Annals of the Realm", dynastyName: "", spanText: "", entries: entries)]
        }

        var bucketed: [[ChronicleRenderedEntry]] = Array(repeating: [], count: countryChapterIndices.count)

        for eIdx in countryEventIndices {
            let eDate = eventsTable.date(at: eIdx)
            let k = eventsTable.eventKind(at: eIdx).map(Self.kindKey) ?? "event"
            let entry = ChronicleRenderedEntry(
                dateText: eDate.description,
                kindKey: k,
                prose: render(eventIndex: eIdx, in: world)
            )

            // Match to the latest chapter whose startDate <= eDate (and endDate >= eDate or nil).
            var matchedSlot = countryChapterIndices.count - 1
            for (slot, chIdx) in countryChapterIndices.enumerated() {
                let sDate = chaptersTable.startDate(at: chIdx)
                let eEnd = chaptersTable.endDate(at: chIdx)
                if eDate >= sDate && (eEnd == nil || eDate <= eEnd!) {
                    matchedSlot = slot
                    // If rulerDied/rulerCrowned on exact transition date, put rulerDied in closing chapter and rulerCrowned in opening chapter.
                    if eventsTable.eventKind(at: eIdx) == .rulerDied && eEnd == eDate {
                        break
                    }
                    if eventsTable.eventKind(at: eIdx) == .rulerCrowned && sDate == eDate {
                        break
                    }
                }
            }
            bucketed[matchedSlot].append(entry)
        }

        var result: [ChronicleChapterView] = []
        result.reserveCapacity(countryChapterIndices.count)
        for (slot, chIdx) in countryChapterIndices.enumerated() {
            let rName = chaptersTable.rulerName[chIdx]
            let dName = chaptersTable.dynastyName[chIdx]
            let sYear = Int(chaptersTable.startYear[chIdx])
            let eYear = Int(chaptersTable.endYear[chIdx])
            let span = eYear > 0 ? "\(sYear)–\(eYear)" : "\(sYear)–Present"
            result.append(ChronicleChapterView(
                rulerName: rName,
                dynastyName: dName,
                spanText: span,
                entries: bucketed[slot]
            ))
        }
        return result
    }
}
