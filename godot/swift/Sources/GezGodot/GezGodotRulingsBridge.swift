import Foundation
import GezCore

// Phase 20.8: ruling systems and formables. For now only the shield key, so
// a country that formed Spain shows Spain's arms everywhere the interface
// asks for a shield. Screens for the HRE and formables come later (Gemini,
// from mock-ups the owner picks).

extension GezGodotController {

    /// Picture key for a country's shield: its tag, or the formable's shield
    /// once it has formed one. Unknown tags come back unchanged.
    public func countryShieldKey(tag: String) -> String {
        guard let w = session?.world, let c = w.countries.id(forTag: tag) else { return tag }
        return w.countries.shield[c.index]
    }
}
