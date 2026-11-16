import GezCore
import SwiftUI

// MARK: - Alerts banner

private struct GameAlert: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

struct AlertsBanner: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        let _ = model.revision
        let alerts = collectAlerts()
        if !alerts.isEmpty || model.pickNationFromMap {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if model.pickNationFromMap {
                        Button {
                            model.pickNationFromMap = false
                        } label: {
                            Label("Click any country on the map to play as it · Cancel", systemImage: "hand.tap")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.9), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(alerts) { alert in
                        Button(action: alert.action) {
                            Label(alert.label, systemImage: alert.systemImage)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(alert.tint.opacity(0.92), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: 820)
        }
    }

    private func collectAlerts() -> [GameAlert] {
        model.session.activeAlerts().map { info in
            let systemImage: String
            let tint: Color
            let action: () -> Void
            switch info.kind {
            case .peaceOffer:
                systemImage = "envelope.badge"
                tint = .orange
                action = {
                    model.showWars = true
                    model.showPeaceForWarID = info.warID
                }
            case .breach:
                systemImage = "flame.fill"
                tint = .orange
                action = {
                    if let p = info.province { model.select(province: p) }
                }
            case .underSiege:
                systemImage = "shield.slash.fill"
                tint = .red
                action = {
                    if let p = info.province { model.select(province: p) }
                }
            case .coalition:
                systemImage = "exclamationmark.triangle.fill"
                tint = .red
                action = {
                    model.openDiplomacy()
                }
            case .lowStability:
                systemImage = "building.columns"
                tint = .brown
                action = {
                    model.showGovernment = true
                }
            case .disloyalEstate:
                systemImage = "person.2.slash"
                tint = .orange
                action = {
                    model.showGovernment = true
                }
            case .refusingVassal:
                systemImage = "crown"
                tint = .brown
                action = {
                    model.showCourt = true
                }
            case .bankrupt:
                systemImage = "dollarsign.circle.fill"
                tint = .red
                action = {
                    model.showBudget = true
                }
            case .highInflation:
                systemImage = "chart.line.uptrend.xyaxis"
                tint = .brown
                action = {
                    model.showBudget = true
                }
            case .navalBattle:
                systemImage = "water.waves"
                tint = .blue
                action = {
                    model.showWars = true
                }
            case .blockadedPort:
                systemImage = "anchor.circle.fill"
                tint = .red
                action = {
                    if let p = info.province { model.select(province: p) }
                }
            case .plague, .famine, .earthquake, .rebels, .techLevel, .institution:
                // Phase 12 alerts: the old Apple app only jumps to the province
                // (the plague and rebel screens live in the Godot game).
                systemImage = "exclamationmark.triangle.fill"
                tint = .red
                action = {
                    if let p = info.province { model.select(province: p) }
                }
            }
            return GameAlert(
                id: info.id,
                label: info.label,
                systemImage: systemImage,
                tint: tint,
                action: action
            )
        }
    }
}

// MARK: - Province siege & garrison section

struct ProvinceSiegeSection: View {
    @Environment(GameModel.self) private var model
    let province: ProvinceID

    var body: some View {
        let _ = model.revision
        let world = model.world
        let i = province.index
        let fortLevel = world.provinces.fortLevel[i]
        let garrison = world.provinces.fortGarrison[i]
        let maxGarrison = world.provinces.maxGarrison(of: province)
        let siege = world.military.siege(in: province)

        if fortLevel > 0 || siege != nil {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fortLevel > 0 ? "Fortress (Lv \(fortLevel))" : "Siege")
                        .font(.callout.bold())
                    Spacer()
                    if fortLevel > 0 {
                        Text("\(garrison) / \(maxGarrison) garrison")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.ink.opacity(0.75))
                    }
                }

                if let siege {
                    let besiegerName = world.countries.name[siege.besieger.index]
                    HStack {
                        Text("Besieged by \(besiegerName)")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(siege.phaseDaysRemaining)d")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.ink.opacity(0.7))
                    }

                    HStack(spacing: 10) {
                        Text("Progress: \(siege.progress)")
                            .font(.caption.monospacedDigit())
                        if siege.breached {
                            Text("WALLS BREACHED")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.25), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                        if world.provinces.isCoastal[i] {
                            Text(siege.blockaded ? "Blockaded" : "Open port (-2)")
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.65))
                        }
                    }

                    if let outcome = siege.lastOutcome, let roll = siege.lastRoll {
                        Text("Last roll: \(roll) (\(siege.lastModifier >= 0 ? "+\(siege.lastModifier)" : "\(siege.lastModifier)")) · \(outcome.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.7))
                    }

                    if siege.besieger == model.playerCountry {
                        HStack {
                            Button {
                                _ = model.assaultFort(in: province)
                            } label: {
                                Text("Storm Assault")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        siege.breached ? Color.red.opacity(0.85) : Palette.ink.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(siege.breached ? .white : Palette.ink.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .disabled(!siege.breached)

                            if !siege.breached {
                                Text("Needs breach")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.ink.opacity(0.6))
                            }
                        }
                        .padding(.top, 2)
                    }

                    if let last = model.lastAssaultResult, last.province == province {
                        if let refusal = last.result.refusalReason {
                            Text(refusal)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else if last.result.captured {
                            Text("Assault captured fort (-\(last.result.attackerLosses) attackers)")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("Assault repelled (-\(last.result.attackerLosses) attackers, -\(last.result.garrisonLosses) garrison)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Game Menu (New / Save / Load / Settings)

struct GameMenuPanel: View {
    @Environment(GameModel.self) private var model
    @State private var saveName = ""

    var body: some View {
        let _ = model.revision
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Game Menu").font(.title3.bold())
                Spacer()
                Button {
                    model.showGameMenu = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }

            if let player = model.playerCountry {
                HStack(spacing: 8) {
                    CountryArmsView(world: model.world, country: player)
                        .frame(height: 24)
                    Text("Playing as \(model.world.countries.name[player.index]) · \(model.date.description)")
                        .font(.callout.bold())
                    Spacer()
                }
            }

            if let status = model.lastSaveStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Button {
                    model.showGameMenu = false
                    model.showNationPicker = true
                } label: {
                    Label("New Game / Choose Nation", systemImage: "globe")
                        .font(.callout.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.ink.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    model.showGameMenu = false
                    model.pickNationFromMap = true
                } label: {
                    Label("Pick Nation on Map", systemImage: "hand.tap")
                        .font(.callout.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.ink.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Save Game
            VStack(alignment: .leading, spacing: 6) {
                Text("Save Game").font(.callout.bold())
                HStack(spacing: 8) {
                    TextField("Save name", text: $saveName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        let fallback = "\(model.playerTag ?? "GEZ") - \(model.date)"
                        model.saveGame(named: saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : saveName)
                        saveName = ""
                    }
                    Button("Quick Save") {
                        model.quickSave()
                    }
                }
                HStack {
                    Text("Autosave schedule").font(.caption).foregroundStyle(Palette.ink.opacity(0.75))
                    Spacer()
                    Picker("Autosave", selection: Binding(
                        get: { model.autosaveFrequency },
                        set: { model.autosaveFrequency = $0 }
                    )) {
                        ForEach(AutosaveFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Divider()

            // Load Game
            HStack {
                Text("Load Game (\(model.savedGames.count))").font(.callout.bold())
                Spacer()
                Button("Refresh") {
                    model.refreshSavedGames()
                }
                .font(.caption)
            }

            ScrollView {
                if model.savedGames.isEmpty {
                    Text("No saved games found yet.")
                        .font(.caption)
                        .foregroundStyle(Palette.ink.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.savedGames) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(entry.metadata.name).font(.callout.bold())
                                        if entry.metadata.isAutosave {
                                            Text("AUTO")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 4)
                                                .background(Color.orange.opacity(0.2), in: Capsule())
                                        }
                                    }
                                    let realm = entry.metadata.playerName ?? entry.metadata.playerTag ?? "Unknown"
                                    Text("\(realm) · \(entry.metadata.gameDate.description)")
                                        .font(.caption)
                                        .foregroundStyle(Palette.ink.opacity(0.7))
                                }
                                Spacer()
                                Button("Load") {
                                    model.loadGame(entry)
                                }
                                Button {
                                    model.deleteSave(entry)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(16)
        .frame(width: 480)
        .foregroundStyle(Palette.ink)
        .background(Palette.parchment.opacity(0.98), in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
        .onAppear {
            model.refreshSavedGames()
        }
    }
}

// MARK: - Nation Picker

struct NationPickerPanel: View {
    @Environment(GameModel.self) private var model
    @State private var search = ""
    @State private var selectedTag: String = Scenario1453.defaultPlayerTag

    private static let featuredTags = CountrySummaryInfo.featuredTags

    private typealias CountrySummary = CountrySummaryInfo

    var body: some View {
        let summaries = model.session.countrySummaries()
        let filtered = summaries.filter { entry in
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return q.isEmpty || entry.name.lowercased().contains(q) || entry.tag.lowercased().contains(q)
        }
        let chosen = summaries.first { $0.tag == selectedTag } ?? summaries.first

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose Nation (1453)").font(.title3.bold())
                Spacer()
                Button {
                    model.showNationPicker = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }

            Text("Featured 1453 Powers").font(.caption.bold()).foregroundStyle(Palette.ink.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.featuredTags, id: \.self) { tag in
                        if let country = model.world.countries.id(forTag: tag) {
                            Button {
                                selectedTag = tag
                            } label: {
                                HStack(spacing: 4) {
                                    CountryArmsView(world: model.world, country: country)
                                        .frame(height: 16)
                                    Text(model.world.countries.name[country.index])
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    selectedTag == tag ? Palette.ink.opacity(0.85) : Palette.ink.opacity(0.10),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedTag == tag ? Palette.parchment : Palette.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Search all \(summaries.count) countries by name or tag…", text: $search)
                    .textFieldStyle(.roundedBorder)
                Button("Pick on Map") {
                    model.showNationPicker = false
                    model.pickNationFromMap = true
                }
                .font(.caption.bold())
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filtered) { item in
                        Button {
                            selectedTag = item.tag
                        } label: {
                            HStack(spacing: 8) {
                                CountryArmsView(world: model.world, country: item.id)
                                    .frame(height: 18)
                                Text(item.name).font(.callout.bold())
                                Text(item.tag).font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                                Spacer()
                                Text("\(item.provinces) prov · \(item.development) dev")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Palette.ink.opacity(0.75))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                selectedTag == item.tag ? Palette.ink.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 240)

            Divider()

            if let chosen {
                let c = model.world.countries
                HStack {
                    CountryArmsView(world: model.world, country: chosen.id)
                        .frame(height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(chosen.name) (\(chosen.tag))").font(.headline)
                        Text("\(c.government[chosen.id.index].displayName) · \(c.religion[chosen.id.index].displayName) · \(chosen.provinces) provinces · \(chosen.development) dev")
                            .font(.caption)
                            .foregroundStyle(Palette.ink.opacity(0.75))
                    }
                    Spacer()
                }
            }

            HStack {
                Button {
                    if let chosen {
                        model.switchPlayer(to: chosen.id)
                    }
                } label: {
                    Text("Switch Nation Now")
                        .font(.callout.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Palette.ink.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    model.startNewGame(tag: selectedTag)
                } label: {
                    Text("Start New 1453 Game")
                        .font(.callout.bold())
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Palette.parchment)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 560)
        .foregroundStyle(Palette.ink)
        .background(Palette.parchment.opacity(0.98), in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
        .onAppear {
            if let current = model.playerTag {
                selectedTag = current
            }
        }
    }
}
