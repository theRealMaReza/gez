import Testing
import Foundation
@testable import GezCore

@Suite("HRE System")
struct HRESystemTests {
    @Test("1453 HRE data loads emperor, electors, free cities, prince-bishops, princes, provinces and effects")
    func bundled1453Data() throws {
        let world = Scenario1453.makeWorld()
        let def = try #require(world.rulingRules.system("hre"))
        #expect(def.name == "Holy Roman Empire")
        #expect(def.provinces.count == 157)
        #expect(def.param("elector_count") == 7)

        let hab = try #require(world.countries.id(forTag: "HAB"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let sal = try #require(world.countries.id(forTag: "SAL"))
        let swi = try #require(world.countries.id(forTag: "SWI"))
        let ham = try #require(world.countries.id(forTag: "HAM"))
        let bur = try #require(world.countries.id(forTag: "BUR"))
        let fra = try #require(world.countries.id(forTag: "FRA"))

        #expect(RulingEngine.leader(world, "hre") == hab)
        #expect(RulingEngine.members(world, "hre").count == 63)
        #expect(RulingEngine.holders(world, "hre", "elector").count == 7)
        #expect(RulingEngine.holders(world, "hre", "free_city").count == 9)
        #expect(RulingEngine.holders(world, "hre", "prince_bishop").count == 18)

        #expect(RulingEngine.isMember(world, "hre", swi))
        #expect(RulingEngine.isMember(world, "hre", ham))
        #expect(!RulingEngine.hasRole(world, "hre", ham, "free_city"))
        #expect(RulingEngine.hasRole(world, "hre", mai, "elector"))
        #expect(RulingEngine.hasRole(world, "hre", mai, "prince_bishop"))
        #expect(RulingEngine.hasRole(world, "hre", sal, "prince_bishop"))
        #expect(!RulingEngine.isMember(world, "hre", bur))
        #expect(!RulingEngine.isMember(world, "hre", fra))

        #expect(RulingEngine.value(world, "hre", "authority") == 20)

        // Favour per-country value respects 0..100 limits.
        var w = world
        RulingEngine.setCountryValue(&w, "hre", "favour", swi, 150)
        #expect(RulingEngine.countryValue(w, "hre", "favour", swi) == 100)
        RulingEngine.setCountryValue(&w, "hre", "favour", swi, -25)
        #expect(RulingEngine.countryValue(w, "hre", "favour", swi) == 0)

        // Role effects apply to Free Imperial Cities and Emperor (scaled by authority).
        var baseFreeCity = Effects()
        var withHREFreeCity = Effects()
        RulingEngine.addEffects(world, nur, into: &withHREFreeCity)
        #expect(abs(withHREFreeCity[.trade] - baseFreeCity[.trade] - 0.10) < 1e-9)
        #expect(abs(withHREFreeCity[.tax] - baseFreeCity[.tax] - 0.05) < 1e-9)
        #expect(abs(withHREFreeCity[.fortDefence] - baseFreeCity[.fortDefence] - 0.15) < 1e-9)

        var empFx = Effects()
        RulingEngine.addEffects(world, hab, into: &empFx)
        // Base leader (tax +0.05, manpower +0.10) + authority 20/100 scaled (crownPower +0.02, vassalOpinion +3, tax +0.02)
        #expect(abs(empFx[.manpower] - 0.10) < 1e-9)
        #expect(abs(empFx[.tax] - 0.07) < 1e-9)
        #expect(abs(empFx[.crownPower] - 0.02) < 1e-9)
        #expect(abs(empFx[.vassalOpinion] - 3.0) < 1e-9)
    }
}
