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
        let date = Scenario1453.startDate
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let ryu = try #require(world.countries.id(forTag: "RYU"))

        // Ineligible country cannot form Japan.
        #expect(FormableSystem.form(&world, ryu, "JPN", date: date) == .notEligible)

        // Ashikaga cannot form Japan before Tenka Toitsu is proclaimed.
        #expect(FormableSystem.form(&world, ash, "JPN", date: date) == .requirementsNotMet)

        // Once Tenka Toitsu is achieved, Ashikaga can form Japan.
        RulingEngine.setFlag(&world, "shogunate", "tenka_toitsu")
        let result = FormableSystem.form(&world, ash, "JPN", date: date)
        #expect(result == nil)
        #expect(world.countries.name[ash.index] == "Japan")
        #expect(world.countries.color[ash.index] == RGB(185, 45, 55))
        #expect(world.countries.shield[ash.index] == "JPN")
        #expect(world.rulings.missionTree[ash.index] == "japan")
        #expect(world.rulings.formedAs[ash.index] == "JPN")
        let record = try #require(world.rulings.formed.last)
        #expect(record.country == ash && record.formable == "JPN")
        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == 60)
    }

    @Test("AI Shogun automatically forms Japan once Tenka Toitsu is achieved")
    func japanFormableByAI() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = GameDate(year: 1480, month: 1, day: 1)
        let ash = try #require(world.countries.id(forTag: "ASH"))

        RulingEngine.setFlag(&world, "shogunate", "tenka_toitsu")
        RulingEngine.runMonthly(&world, date: date, random: &rng)

        #expect(world.rulings.formedAs[ash.index] == "JPN")
        #expect(world.countries.name[ash.index] == "Japan")
    }

    @Test("Bakufu Authority falls with hostile Kanrei and triggers Sengoku below 25")
    func authorityAndSengokuTrigger() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let hsk = try #require(world.countries.id(forTag: "HSK"))
        let ymn = try #require(world.countries.id(forTag: "YMN"))

        // Loyal Kanrei + peace gives positive delta when ruler is capable.
        world.diplomacy.setOpinion(of: ash, by: hsk, value: 80)
        let loyalDelta = ShogunateSystem.monthlyAuthorityDelta(in: world)

        // Hostile Kanrei drains authority.
        world.diplomacy.setOpinion(of: ash, by: hsk, value: -60)
        let hostileDelta = ShogunateSystem.monthlyAuthorityDelta(in: world)
        #expect(hostileDelta < loyalDelta)

        // Drop authority below 25 -> monthly tick activates Sengoku (stage 1) and applies effects.
        RulingEngine.setValue(&world, "shogunate", "bakufu_authority", 22)
        RulingEngine.runMonthly(&world, date: GameDate(year: 1454, month: 6, day: 1), random: &rng)
        #expect(ShogunateSystem.internalWarsAllowed(in: world))
        #expect(RulingEngine.hasFlag(world, "shogunate", "sengoku_active"))
        #expect(RulingEngine.state(world, "shogunate")?.stage == 1)

        var ymnFx = Effects(estates: 0)
        ShogunateSystem.addEffects(world, country: ymn, into: &ymnFx)
        #expect(abs(ymnFx[.armyQuality] - 0.05) < 1e-9)
        #expect(abs(ymnFx[.levySize] - 0.10) < 1e-9)

        var ashFx = Effects(estates: 0)
        ShogunateSystem.addEffects(world, country: ash, into: &ashFx)
        #expect(abs(ashFx[.crownPower] - (-0.08)) < 1e-9)
    }

    @Test("Kanrei rotates among Sankanrei on ruler death and falls back to strongest loyal shugo")
    func kanreiRotation() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = Scenario1453.startDate
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let hsk = try #require(world.countries.id(forTag: "HSK"))
        let htk = try #require(world.countries.id(forTag: "HTK"))
        let shb = try #require(world.countries.id(forTag: "SHB"))

        // Make HSK hostile and HTK strongly favoured -> killing HSK's ruler rotates Kanrei to HTK.
        world.diplomacy.setOpinion(of: ash, by: hsk, value: -120)
        world.diplomacy.setOpinion(of: ash, by: htk, value: 150)
        world.diplomacy.setOpinion(of: ash, by: shb, value: -20)
        RulingEngine.setCountryValue(&world, "shogunate", "loyalty", htk, 90)

        let hskRuler = try #require(world.countries.ruler[hsk.index])
        CharacterSystem.kill(&world, hskRuler, date: date, random: &rng, suppressEvent: true)
        #expect(ShogunateSystem.kanrei(in: world) == htk)

        // If all three Sankanrei are hostile (<= -80), fallback picks a loyal non-Sankanrei shugo.
        world.diplomacy.setOpinion(of: ash, by: hsk, value: -120)
        world.diplomacy.setOpinion(of: ash, by: htk, value: -120)
        world.diplomacy.setOpinion(of: ash, by: shb, value: -120)
        let ouc = try #require(world.countries.id(forTag: "OUC"))
        world.diplomacy.setOpinion(of: ash, by: ouc, value: 180)
        RulingEngine.setCountryValue(&world, "shogunate", "loyalty", ouc, 100)

        ShogunateSystem.appointKanrei(&world, date: date, random: &rng)
        #expect(ShogunateSystem.kanrei(in: world) == ouc)
    }

    @Test("Taking Kyoto usurps the Shogunate, transfers shugo vassals, and resets Bakufu Authority to 40")
    func kyotoUsurpation() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = GameDate(year: 1470, month: 3, day: 1)
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let ymn = try #require(world.countries.id(forTag: "YMN"))
        let ouc = try #require(world.countries.id(forTag: "OUC"))
        let kyoto = try #require(world.provinces.id(named: "Kyoto"))

        RulingEngine.setValue(&world, "shogunate", "bakufu_authority", 12)
        world.transferProvince(kyoto, to: ymn, from: ash)
        ShogunateSystem.checkKyotoUsurpation(&world, date: date, random: &rng)

        #expect(RulingEngine.leader(world, "shogunate") == ymn)
        #expect(!RulingEngine.hasRole(world, "shogunate", ymn, "shugo"))
        #expect(world.countries.overlord[ymn.index] == nil)
        #expect(RulingEngine.hasRole(world, "shogunate", ash, "shugo"))
        #expect(world.countries.overlord[ouc.index] == ymn)
        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == 40)
    }

    @Test("Shogun death and shugo annexation reduce Bakufu Authority")
    func successionAndAnnexPenalties() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = Scenario1453.startDate
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let shn = try #require(world.countries.id(forTag: "SHN"))

        let before = RulingEngine.value(world, "shogunate", "bakufu_authority")
        let shogunRuler = try #require(world.countries.ruler[ash.index])
        CharacterSystem.kill(&world, shogunRuler, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == before - 5)

        ShogunateSystem.countryVanished(&world, country: shn, date: date)
        #expect(RulingEngine.value(world, "shogunate", "bakufu_authority") == before - 8)
    }

    @Test("Tenka Toitsu ends Sengoku when Shogun holds Kyoto, 75%+ of Japan, and 60+ Bakufu Authority")
    func tenkaToitsu() throws {
        var world = Scenario1453.makeWorld()
        let date = GameDate(year: 1490, month: 1, day: 1)
        let ash = try #require(world.countries.id(forTag: "ASH"))

        // In 1453 ASH + its 15 shugo vassals control 100% of the 60 Shogunate provinces.
        #expect(ShogunateSystem.shogunControlledFraction(in: world) >= 0.99)

        // Authority is 40 (< 60), so Tenka Toitsu is not yet available.
        #expect(!ShogunateSystem.canProclaimTenkaToitsu(in: world))

        RulingEngine.setFlag(&world, "shogunate", "sengoku_active")
        RulingEngine.setValue(&world, "shogunate", "bakufu_authority", 65)
        #expect(ShogunateSystem.canProclaimTenkaToitsu(in: world))

        let proclaimed = ShogunateSystem.proclaimTenkaToitsu(&world, by: ash, date: date)
        #expect(proclaimed)
        #expect(RulingEngine.hasFlag(world, "shogunate", "tenka_toitsu"))
        #expect(!RulingEngine.hasFlag(world, "shogunate", "sengoku_active"))
        #expect(!ShogunateSystem.internalWarsAllowed(in: world))
        #expect(RulingEngine.state(world, "shogunate")?.stage == 2)
    }

    @Test("Shogunate simulation is deterministic and survives save/load round-trip")
    func determinismAndSaveLoad() throws {
        let sim1 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 2026)
        let sim2 = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 2026)

        // Run 24 months (730 days) and verify identical ruling state and clamped bounds.
        sim1.advance(days: 730)
        sim2.advance(days: 730)
        #expect(sim1.world.rulings == sim2.world.rulings)
        let auth = RulingEngine.value(sim1.world, "shogunate", "bakufu_authority")
        #expect(auth >= 0 && auth <= 100)

        // Mutate Shogunate state, round-trip via SaveSnapshot, and run 60 more days.
        let hsk = try #require(sim1.world.countries.id(forTag: "HSK"))
        RulingEngine.setFlag(&sim1.world, "shogunate", "sengoku_active")
        RulingEngine.setValue(&sim1.world, "shogunate", "bakufu_authority", 18)
        RulingEngine.setCountryValue(&sim1.world, "shogunate", "loyalty", hsk, 42)

        let snap = SaveSnapshot(capturing: sim1)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(SaveSnapshot.self, from: data)
        let restored = try decoded.restore()
        #expect(restored.world.rulings == sim1.world.rulings)

        sim1.advance(days: 60)
        restored.advance(days: 60)
        #expect(sim1.world.rulings == restored.world.rulings)
    }

    @Test("Internal shugo wars unlock during Sengoku, exclude the Shogun, and re-lock after Tenka Toitsu")
    func sengokuInternalWarsAndKyotoMarch() throws {
        var world = Scenario1453.makeWorld()
        let date = GameDate(year: 1468, month: 5, day: 1)
        let ash = try #require(world.countries.id(forTag: "ASH"))
        let hsk = try #require(world.countries.id(forTag: "HSK"))
        let ymn = try #require(world.countries.id(forTag: "YMN"))
        let ouc = try #require(world.countries.id(forTag: "OUC"))
        let kyoto = try #require(world.provinces.id(named: "Kyoto"))

        // 1. Pre-Sengoku: shugo vassals cannot declare war on each other.
        let preCheck = world.diplomacy.canDeclareWar(attacker: hsk, defender: ymn, world: world)
        #expect(!preCheck.isValid)

        // 2. Activate Sengoku: HSK can declare war on neighbouring YMN with Sengoku CB, without calling in ASH.
        RulingEngine.setFlag(&world, "shogunate", "sengoku_active")
        let sengokuCheck = world.diplomacy.canDeclareWar(attacker: hsk, defender: ymn, world: world)
        #expect(sengokuCheck.isValid)

        let cbs = world.diplomacy.availableCasusBelli(attacker: hsk, defender: ymn, in: world)
        let sengokuCB = try #require(cbs.first)
        let shugoWar = try world.declareWar(
            attacker: hsk,
            defender: ymn,
            casusBelli: sengokuCB.type,
            warGoal: sengokuCB.warGoal,
            date: date
        ).get()
        #expect(shugoWar.attackers.contains(hsk))
        #expect(shugoWar.defenders.contains(ymn))
        #expect(!shugoWar.defenders.contains(ash))

        // 3. March on Kyoto: YMN attacks ASH; loyal Kanrei (HSK) defends ASH, disloyal shugo (OUC) does not.
        var w2 = Scenario1453.makeWorld()
        RulingEngine.setFlag(&w2, "shogunate", "sengoku_active")
        w2.diplomacy.setOpinion(of: ash, by: hsk, value: 30)
        w2.diplomacy.setOpinion(of: ash, by: ouc, value: -10)
        let marchCBs = w2.diplomacy.availableCasusBelli(attacker: ymn, defender: ash, in: w2)
        #expect(marchCBs.contains { $0.targetProvince == kyoto })
        let kyotoWar = try w2.declareWar(
            attacker: ymn,
            defender: ash,
            casusBelli: .claim,
            warGoal: .conquerProvince(kyoto),
            date: date
        ).get()
        #expect(kyotoWar.defenders.contains(ash))
        #expect(kyotoWar.defenders.contains(hsk))
        #expect(!kyotoWar.defenders.contains(ouc))

        // 4. Peace treaty transferring Kyoto immediately usurps the Shogunate.
        let offer = PeaceOffer(
            warID: kyotoWar.id,
            winner: ymn,
            loser: ash,
            demands: [.cedeProvince(kyoto)]
        )
        _ = try w2.executePeaceTreaty(offer, date: date, forceAccept: true).get()
        #expect(RulingEngine.leader(w2, "shogunate") == ymn)
        #expect(world.provinces.owner[kyoto.index] == ash)
        #expect(w2.provinces.owner[kyoto.index] == ymn)
        #expect(RulingEngine.value(w2, "shogunate", "bakufu_authority") == 40)

        // 5. After Tenka Toitsu, internal shugo wars are forbidden again.
        RulingEngine.setFlag(&w2, "shogunate", "tenka_toitsu")
        RulingEngine.setFlag(&w2, "shogunate", "sengoku_active", false)
        let postCheck = w2.diplomacy.canDeclareWar(attacker: hsk, defender: ouc, world: w2)
        #expect(!postCheck.isValid)
    }
}
