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
        return mask
    }

    // MARK: - Selection & Tooltip

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
}

#initSwiftExtension(cdecl: "gez_godot_entry", types: [GezGodotBridge.self])
