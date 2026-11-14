import Foundation
import GezCore
import GezGodot
import Testing

@Suite("GezGodotController Tests")
struct GezGodotTests {
    @Test("Loads 1453 world, encodes map textures, and advances speeds 1-5")
    func controllerLoadsAndAdvances() {
        let controller = GezGodotController()
        let ok = controller.setup(dataDirectoryPath: "", tag: "TUR")
        #expect(ok)
        #expect(controller.mapWidth == 3936)
        #expect(controller.mapHeight == 2384)
        #expect(controller.countryTag == "TUR")
        #expect(controller.countryName.contains("Ottoman"))
        #expect(controller.dateText == "30 May 1453")
        #expect(controller.isPaused)

        // Verify ID map and style texture byte buffers.
        let idBytes = controller.provinceIDBytes()
        #expect(idBytes.count == 3936 * 2384 * 2)
        let seaBytes = controller.seaIDBytes()
        #expect(seaBytes.count == 3936 * 2384 * 2)
        let styleBytes = controller.styleBytes()
        #expect(styleBytes.count == GezGodotController.styleTextureWidth * 2 * 4)

        // Verify water (v = 0) and wasteland (v = 1) owner encodings in row 1.
        let width = GezGodotController.styleTextureWidth
        let waterOwnerEnc = UInt16(styleBytes[width * 4]) | (UInt16(styleBytes[width * 4 + 1]) << 8)
        let wastelandOwnerEnc = UInt16(styleBytes[(width + 1) * 4]) | (UInt16(styleBytes[(width + 1) * 4 + 1]) << 8)
        #expect(Int(waterOwnerEnc) - 4 == -2)
        #expect(Int(wastelandOwnerEnc) - 4 == -3)

        // Verify country labels.
        let (texts, metrics) = controller.countryLabelData()
        #expect(!texts.isEmpty)
        #expect(metrics.count == texts.count * 3)

        // Verify focus point and province selection around Constantinople.
        let focus = controller.focusPoint(latitude: 41.0, longitude: 29.0)
        #expect(focus.x > 0 && focus.x < Double(controller.mapWidth))
        #expect(focus.y > 0 && focus.y < Double(controller.mapHeight))

        // Verify speed 5 advancement.
        controller.setSpeed(5)
        #expect(!controller.isPaused)
        #expect(controller.speed == 5)
        let mask = controller.tickFrame(deltaSeconds: 0.2)
        #expect((mask & 1) != 0)
        #expect(controller.dateText != "30 May 1453")
    }
}
