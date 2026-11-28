import Testing
import Foundation
@testable import GezCore

@Suite("Shogunate System")
struct ShogunateSystemTests {
    @Test("1453 Shogunate data loads Shogun, 15 shugo, Kanrei, Sankanrei, Kamakura Kubo, provinces and effects")
    func bundled1453Data() throws {
        let world = Scenario1453.makeWorld()
        let def = try #require(world.rulingRules.system("shogunate"))
        #expect(def.name == "Japanese Shogunate")
        #expect(def.provinces.count == 60)
        #expect(def.param("sengoku_threshold") == 25)
        #expect(def.param("usurp_authority") == 40)
        #expect(def.param("unification_pct") == 75)
        #expect(def.param("unification_authority") == 60)

        let ash = try #require(world.countries.id(forTag: "ASH"))
        let hsk = try #require(world.countries.id(forTag: "HSK"))
        let ymn = try #require(world.countries.id(forTag: "YMN"))
        let htk = try #require(world.countries.id(forTag: "HTK"))
        let shb = try #require(world.countries.id(forTag: "SHB"))
        let kmk = try #require(world.countries.id(forTag: "KMK"))
        let ryu = try #require(world.countries.id(forTag: "RYU"))
        let ain = try #require(world.countries.id(forTag: "AIN"))

        #expect(RulingEngine.leader(world, "shogunate") == ash)
        #expect(RulingEngine.members(world, "shogunate").count == 16)
        #expect(RulingEngine.holders(world, "shogunate", "shugo").count == 15)
        #expect(RulingEngine.holders(world, "shogunate", "kanrei") == [hsk])
        #expect(Set(RulingEngine.holders(world, "shogunate", "sankanrei")) == Set([hsk, htk, shb]))
        #expect(RulingEngine.holders(world, "shogunate", "kanto_kubo") == [kmk])

        #expect(RulingEngine.hasRole(world, "shogunate", ymn, "shugo"))
        #expect(!RulingEngine.hasRole(world, "shogunate", ymn, "sankanrei"))
        #expect(!RulingEngine.isMember(world, "shogunate", ryu))
        #expect(!RulingEngine.isMember(world, "shogunate", ain))

        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == 40)

        // Per-country loyalty respects 0..100 limits.
        var w = world
        RulingEngine.setCountryValue(&w, "shogunate", "loyalty", hsk, 140)
        #expect(RulingEngine.countryValue(w, "shogunate", "loyalty", hsk) == 100)
        RulingEngine.setCountryValue(&w, "shogunate", "loyalty", hsk, -15)
        #expect(RulingEngine.countryValue(w, "shogunate", "loyalty", hsk) == 0)

        // Role effects apply to Kanrei (shugo + kanrei) and Shogun (base + bakufu_authority/100 scaled).
        var hskFx = Effects(estates: 0)
        RulingEngine.addEffects(world, hsk, into: &hskFx)
        #expect(abs(hskFx[.levySize] - 0.10) < 1e-9)
        #expect(abs(hskFx[.fortDefence] - 0.05) < 1e-9)
        #expect(abs(hskFx[.crownPower] - 0.05) < 1e-9)
        #expect(abs(hskFx[.tax] - 0.08) < 1e-9)
        #expect(abs(hskFx[.stabilityCost] - (-0.05)) < 1e-9)

        var ashFx = Effects(estates: 0)
        RulingEngine.addEffects(world, ash, into: &ashFx)
        // Base leader (manpower +0.10, tax +0.05) + 40/100 scaled (crownPower +0.048, vassalOpinion +8, tax +0.04)
        #expect(abs(ashFx[.manpower] - 0.10) < 1e-9)
        #expect(abs(ashFx[.tax] - 0.09) < 1e-9)
        #expect(abs(ashFx[.crownPower] - 0.048) < 1e-9)
        #expect(abs(ashFx[.vassalOpinion] - 8.0) < 1e-9)
    }

    @Test("Japan (JPN) formable requires Tenka Toitsu and transforms the Shogun in place")
    func japanFormable() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = Scenario1453.startDate
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let ryu = try #require(world.countries.id(forTag: "RYU"))

        // Ineligible country cannot form Japan.
        #expect(FormableSystem.form(&world, country: ryu, formableID: "JPN", date: date, random: &rng) == .notEligible)

        // Ashikaga cannot form Japan before Tenka Toitsu is proclaimed.
        #expect(FormableSystem.form(&world, country: ash, formableID: "JPN", date: date, random: &rng) == .requirementsNotMet)

        // Once Tenka Toitsu is achieved, Ashikaga can form Japan.
        RulingEngine.setFlag(&world, "shogunate", "tenka_toitsu")
        let result = FormableSystem.form(&world, country: ash, formableID: "JPN", date: date, random: &rng)
        #expect(result == .formed)
        #expect(world.countries.name[ash.index] == "Japan")
        #expect(world.countries.color[ash.index] == RGB(185, 45, 55))
        #expect(world.countries.shield[ash.index] == "JPN")
        #expect(world.countries.missionTree[ash.index] == "japan")
        #expect(world.rulings.formed["JPN"]?.country == ash)
        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == 60)
    }

    @Test("AI Shogun automatically forms Japan once Tenka Toitsu is achieved")
    func japanFormableByAI() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = GameDate(year: 1480, month: 1, day: 1)
        let ash = try #require(world.countries.id(forTag: "ASH"))

        RulingEngine.setFlag(&world, "shogunate", "tenka_toitsu")
        FormableSystem.runMonthly(&world, date: date, random: &rng)

        #expect(world.rulings.formed["JPN"]?.country == ash)
        #expect(world.countries.name[ash.index] == "Japan")
    }
}
