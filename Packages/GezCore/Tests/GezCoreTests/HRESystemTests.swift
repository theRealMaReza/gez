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
        let baseFreeCity = Effects(estates: 0)
        var withHREFreeCity = Effects(estates: 0)
        RulingEngine.addEffects(world, nur, into: &withHREFreeCity)
        #expect(abs(withHREFreeCity[.trade] - baseFreeCity[.trade] - 0.10) < 1e-9)
        #expect(abs(withHREFreeCity[.tax] - baseFreeCity[.tax] - 0.05) < 1e-9)
        #expect(abs(withHREFreeCity[.fortDefence] - baseFreeCity[.fortDefence] - 0.15) < 1e-9)

        var empFx = Effects(estates: 0)
        RulingEngine.addEffects(world, hab, into: &empFx)
        // Base leader (tax +0.05, manpower +0.10) + authority 20/100 scaled (crownPower +0.02, vassalOpinion +3, tax +0.02)
        #expect(abs(empFx[.manpower] - 0.10) < 1e-9)
        #expect(abs(empFx[.tax] - 0.07) < 1e-9)
        #expect(abs(empFx[.crownPower] - 0.02) < 1e-9)
        #expect(abs(empFx[.vassalOpinion] - 3.0) < 1e-9)
    }

    @Test("Emperor death triggers election by the 7 electors and shifts when electors favour another prince")
    func imperialElection() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1453)
        let date = Scenario1453.startDate
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let bra = try #require(world.countries.id(forTag: "BRA"))
        let electors = RulingEngine.holders(world, "hre", "elector")
        #expect(electors.count == 7)

        // Default 1453: Habsburgs are favoured to retain the crown on Frederick III's death.
        let frederick = try #require(world.countries.ruler[hab.index])
        CharacterSystem.kill(&world, frederick, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.leader(world, "hre") == hab)
        #expect(RulingEngine.value(world, "hre", "authority") == 25)

        // Now turn all 7 electors strongly against HAB and strongly in favour of Brandenburg.
        for e in electors {
            world.diplomacy.setOpinion(of: hab, by: e, value: -180)
            world.diplomacy.setOpinion(of: bra, by: e, value: 180)
        }
        RulingEngine.setCountryValue(&world, "hre", "favour", bra, 100)

        let leans = HRESystem.electorLeans(in: world)
        #expect(leans.count == 7)
        // A strong majority of electors (all Catholic electors) lean toward Brandenburg.
        #expect(leans.filter { $0.lean == bra }.count >= 5)

        let nextHabRuler = try #require(world.countries.ruler[hab.index])
        CharacterSystem.kill(&world, nextHabRuler, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.leader(world, "hre") == bra)
    }

    @Test("Monthly Imperial Authority rises in peace and falls with internal wars or foreign-held Imperial provinces")
    func authorityDynamics() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 77)
        let date = GameDate(year: 1453, month: 7, day: 1)

        // In 1453 peace, monthly delta is positive.
        let peaceDelta = HRESystem.monthlyAuthorityDelta(in: world)
        #expect(peaceDelta > 0.3)

        let before = RulingEngine.value(world, "hre", "authority")
        RulingEngine.runMonthly(&world, date: date, random: &rng)
        #expect(RulingEngine.value(world, "hre", "authority") > before)

        // Hand 25 Imperial provinces to France -> authority delta turns negative.
        let fra = try #require(world.countries.id(forTag: "FRA"))
        let def = try #require(world.rulingRules.system("hre"))
        for pid in def.provinces.prefix(25) {
            world.provinces.owner[pid.index] = fra
        }
        let foreignDelta = HRESystem.monthlyAuthorityDelta(in: world)
        #expect(foreignDelta < peaceDelta)

        // Authority stays within 0..100 after many months.
        RulingEngine.setValue(&world, "hre", "authority", 99)
        var wPeace = Scenario1453.makeWorld()
        RulingEngine.setValue(&wPeace, "hre", "authority", 99)
        for m in 1...40 {
            RulingEngine.runMonthly(&wPeace, date: GameDate(year: 1454 + m / 12, month: (m % 12) + 1, day: 1), random: &rng)
        }
        #expect(RulingEngine.value(wPeace, "hre", "authority") <= 100)
        #expect(RulingEngine.value(wPeace, "hre", "authority") >= 0)
    }

    @Test("Annexing an HRE member or Free City costs Imperial Authority and replenishes vacated electorates")
    func annexedMembersAndElectorReplenishment() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 99)
        let date = GameDate(year: 1453, month: 7, day: 1)
        let bav = try #require(world.countries.id(forTag: "BAV"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let mai = try #require(world.countries.id(forTag: "MAI"))
        let ans = try #require(world.countries.id(forTag: "ANS"))

        // Annex Free Imperial City Nuremberg -> -8 authority.
        RulingEngine.setValue(&world, "hre", "authority", 50)
        for p in world.provinces.owner.indices where world.provinces.owner[p] == nur {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: date, random: &rng)
        #expect(!RulingEngine.isMember(world, "hre", nur))
        #expect(RulingEngine.value(world, "hre", "authority") < 43)

        // Annex prince Ansbach -> -5 authority.
        RulingEngine.setValue(&world, "hre", "authority", 50)
        for p in world.provinces.owner.indices where world.provinces.owner[p] == ans {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 8, day: 1), random: &rng)
        #expect(!RulingEngine.isMember(world, "hre", ans))
        #expect(RulingEngine.value(world, "hre", "authority") < 46)

        // Annex elector Mainz -> electorate is automatically replenished back to 7.
        for p in world.provinces.owner.indices where world.provinces.owner[p] == mai {
            world.provinces.owner[p] = bav
        }
        RulingEngine.runMonthly(&world, date: GameDate(year: 1453, month: 9, day: 1), random: &rng)
        #expect(!RulingEngine.hasRole(world, "hre", mai, "elector"))
        #expect(RulingEngine.holders(world, "hre", "elector").count == 7)
    }

    @Test("HRE simulation is deterministic over 24 months and survives save/restore identically")
    func determinismAndSaveRoundTrip() throws {
        let simA = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 208)
        let simB = Simulation(world: Scenario1453.makeWorld(), startDate: Scenario1453.startDate, seed: 208)
        simA.advance(days: 730)
        simB.advance(days: 730)
        #expect(simA.world.rulings == simB.world.rulings)

        // Save/restore round-trip after modifying authority and favour.
        let sax = try #require(simA.world.countries.id(forTag: "SAX"))
        RulingEngine.setValue(&simA.world, "hre", "authority", 42)
        RulingEngine.setCountryValue(&simA.world, "hre", "favour", sax, 35)

        let snap = SaveSnapshot(capturing: simA)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(SaveSnapshot.self, from: data)
        let restored = try decoded.restore()
        #expect(restored.world.rulings == simA.world.rulings)

        simA.advance(days: 60)
        restored.advance(days: 60)
        #expect(simA.world.rulings == restored.world.rulings)
    }

    @Test("Historical Imperial shield: Emperor defends members from outsiders and Free Cities from everyone")
    func imperialShieldProtection() throws {
        var world = Scenario1453.makeWorld()
        let date = Scenario1453.startDate
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let fra = try #require(world.countries.id(forTag: "FRA"))
        let bav = try #require(world.countries.id(forTag: "BAV"))
        let ans = try #require(world.countries.id(forTag: "ANS"))
        let nur = try #require(world.countries.id(forTag: "NUR"))
        let lor = try #require(world.countries.id(forTag: "LOR"))

        // 1. Outsider (France) attacking HRE prince (Lorraine) -> Emperor HAB joins defenders.
        #expect(HRESystem.imperialDefender(in: world, attacker: fra, defender: lor) == hab)
        let lorCap = try #require(world.countries.capital[lor.index])
        let resOut = world.declareWar(
            attacker: fra,
            defender: lor,
            casusBelli: .claim,
            warGoal: .conquerProvince(lorCap),
            date: date
        )
        let outWar = try resOut.get()
        #expect(outWar.defenders.contains(hab))

        // 2. HRE prince (Bavaria) attacking Free Imperial City (Nuremberg) -> Emperor HAB joins defenders.
        var w2 = Scenario1453.makeWorld()
        #expect(HRESystem.imperialDefender(in: w2, attacker: bav, defender: nur) == hab)
        let nurCap = try #require(w2.countries.capital[nur.index])
        let resFC = w2.declareWar(
            attacker: bav,
            defender: nur,
            casusBelli: .claim,
            warGoal: .conquerProvince(nurCap),
            date: date
        )
        let fcWar = try resFC.get()
        #expect(fcWar.defenders.contains(hab))

        // 3. HRE prince (Bavaria) attacking another HRE prince (Ansbach) -> Emperor does NOT auto-join.
        var w3 = Scenario1453.makeWorld()
        #expect(HRESystem.imperialDefender(in: w3, attacker: bav, defender: ans) == nil)
        let ansCap = try #require(w3.countries.capital[ans.index])
        let resInt = w3.declareWar(
            attacker: bav,
            defender: ans,
            casusBelli: .claim,
            warGoal: .conquerProvince(ansCap),
            date: date
        )
        let intWar = try resInt.get()
        #expect(!intWar.defenders.contains(hab))

        // 4. Ewiger Landfriede forbids internal HRE wars.
        var w4 = Scenario1453.makeWorld()
        RulingEngine.setFlag(&w4, "hre", "ewiger_landfriede")
        let check = w4.diplomacy.canDeclareWar(attacker: bav, defender: ans, world: w4)
        if case .invalid = check {
            // Expected
        } else {
            Issue.record("Expected Ewiger Landfriede to block internal HRE war declaration")
        }

        // 5. Annexing an HRE estate deals +50% AE and drops opinion with fellow HRE members.
        var w5 = Scenario1453.makeWorld()
        let sax = try #require(w5.countries.id(forTag: "SAX"))
        let opBefore = w5.diplomacy.opinion(of: bav, by: sax)
        RulingEngine.setCountryValue(&w5, "hre", "favour", bav, 40)
        let w5War = try w5.declareWar(
            attacker: bav,
            defender: nur,
            casusBelli: .claim,
            warGoal: .conquerProvince(nurCap),
            date: date
        ).get()
        w5.provinces.occupiedBy[nurCap.index] = bav
        let offer = PeaceOffer(
            warID: w5War.id,
            winner: bav,
            loser: nur,
            demands: [.cedeProvince(province: nurCap, to: bav)]
        )
        _ = w5.executePeaceTreaty(offer, date: date, forceAccept: true)
        #expect(w5.diplomacy.opinion(of: bav, by: sax) <= opBefore - 40)
        #expect(RulingEngine.countryValue(w5, "hre", "favour", bav) == 20)
    }

    @Test("Reichstag reforms spend authority, advance stage, apply modifiers, ban internal wars, and enact Erbreich")
    func reichstagReformsAndEvents() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1495)
        let date = GameDate(year: 1495, month: 8, day: 7)
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let bav = try #require(world.countries.id(forTag: "BAV"))
        let ans = try #require(world.countries.id(forTag: "ANS"))

        // Bundled HRE events exist in eventRules.
        #expect(world.eventRules.events.contains { $0.id == "hre_diet_of_worms_1495" })
        #expect(world.eventRules.events.contains { $0.id == "hre_ewiger_landfriede_diet" })
        #expect(world.eventRules.events.contains { $0.id == "hre_swabian_war_1499" })

        // Cannot enact reform 1 at starting authority 20; non-leader cannot enact even at 100.
        #expect(!HRESystem.canEnactNextReform(in: world, by: hab))
        RulingEngine.setValue(&world, "hre", "authority", 100)
        #expect(!HRESystem.canEnactNextReform(in: world, by: bav))
        #expect(HRESystem.canEnactNextReform(in: world, by: hab))

        // Enact all 6 reforms step by step.
        for expectedStage in 1...6 {
            RulingEngine.setValue(&world, "hre", "authority", 80)
            let ok = HRESystem.enactNextReform(&world, by: hab, date: date)
            #expect(ok)
            #expect(RulingEngine.state(world, "hre")?.stage == expectedStage)
        }
        #expect(HRESystem.nextReform(in: world) == nil)
        #expect(HRESystem.internalWarsForbidden(in: world))

        // Reform modifiers apply to both members and the Emperor.
        var bavFx = Effects(estates: 0)
        RulingEngine.addEffects(world, bav, into: &bavFx)
        #expect(abs(bavFx[.buildCost] - (-0.05)) < 1e-9)
        #expect(abs(bavFx[.stabilityCost] - (-0.08)) < 1e-9)
        #expect(abs(bavFx[.trade] - 0.05) < 1e-9)
        #expect(abs(bavFx[.fortDefence] - 0.10) < 1e-9)

        // Internal war is blocked by Ewiger Landfriede.
        if case .invalid = world.diplomacy.canDeclareWar(attacker: bav, defender: ans, world: world) {
            // Expected
        } else {
            Issue.record("Expected Ewiger Landfriede reform to forbid internal war")
        }

        // Erbreich (hereditary_empire) keeps HAB as Emperor even if every elector hates HAB.
        for e in RulingEngine.holders(world, "hre", "elector") {
            world.diplomacy.setOpinion(of: hab, by: e, value: -100)
        }
        let empRuler = try #require(world.countries.ruler[hab.index])
        CharacterSystem.kill(&world, empRuler, date: date, random: &rng, suppressEvent: true)
        #expect(RulingEngine.leader(world, "hre") == hab)
    }

    @Test("Reformation religious leagues activate, assign league roles, and settle via official faith or Peace of Augsburg")
    func religiousLeaguesAndPeaceOfAugsburg() throws {
        var world = Scenario1453.makeWorld()
        var rng = GameRandom(seed: 1531)
        let date = GameDate(year: 1531, month: 3, day: 1)
        let hab = try #require(world.countries.id(forTag: "HAB"))
        let sax = try #require(world.countries.id(forTag: "SAX"))
        let bra = try #require(world.countries.id(forTag: "BRA"))

        // League events load in eventRules.
        #expect(world.eventRules.events.contains { $0.id == "hre_schmalkaldic_league" })
        #expect(world.eventRules.events.contains { $0.id == "hre_peace_of_augsburg" })

        // Trigger Reformation and convert Saxony & Brandenburg to Protestant.
        world.faith.reformationStarted = true
        world.countries.religion[sax.index] = .protestant
        world.countries.religion[bra.index] = .protestant

        // Monthly tick in 1531 activates leagues and aligns AI estates by faith.
        RulingEngine.runMonthly(&world, date: date, random: &rng)
        #expect(RulingEngine.hasFlag(world, "hre", "leagues_active"))
        #expect(RulingEngine.hasRole(world, "hre", hab, HRESystem.catholicLeagueRole))
        #expect(RulingEngine.hasRole(world, "hre", sax, HRESystem.protestantLeagueRole))
        #expect(RulingEngine.hasRole(world, "hre", bra, HRESystem.protestantLeagueRole))

        // League role effect grants +5% army quality.
        var saxFx = Effects(estates: 0)
        RulingEngine.addEffects(world, sax, into: &saxFx)
        #expect(abs(saxFx[.armyQuality] - 0.05) < 1e-9)

        // Settling Protestant official faith disbands leagues and elects a Protestant Emperor.
        HRESystem.settleReligiousPeace(&world, outcome: "protestant_official", date: date, random: &rng)
        #expect(!RulingEngine.hasFlag(world, "hre", "leagues_active"))
        #expect(RulingEngine.hasFlag(world, "hre", "protestant_official"))
        #expect(RulingEngine.holders(world, "hre", HRESystem.catholicLeagueRole).isEmpty)
        #expect(RulingEngine.holders(world, "hre", HRESystem.protestantLeagueRole).isEmpty)
        let newEmp = try #require(RulingEngine.leader(world, "hre"))
        let newFaith = world.countries.religion[newEmp.index]
        #expect(newFaith == .protestant || newFaith == .reformed)

        // Peace of Augsburg halves the religious disunity authority penalty.
        var wPeace = Scenario1453.makeWorld()
        wPeace.faith.reformationStarted = true
        for m in RulingEngine.members(wPeace, "hre").prefix(20) where m != hab {
            wPeace.countries.religion[m.index] = .protestant
        }
        let deltaBefore = HRESystem.monthlyAuthorityDelta(in: wPeace)
        HRESystem.settleReligiousPeace(&wPeace, outcome: "religious_peace", date: date, random: &rng)
        let deltaAfter = HRESystem.monthlyAuthorityDelta(in: wPeace)
        #expect(deltaAfter > deltaBefore)
    }
}
