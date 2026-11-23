/// Broad groups of related religions. Religions in the same family tolerate
/// each other more easily and can convert more easily.
public enum ReligionFamily: String, CaseIterable, Sendable, Codable {
    case christian, muslim, dharmic, iranian, jewish, pagan
    /// Confucian, Daoist and Shinto (Phase 20.7).
    case eastAsian

    public var displayName: String {
        switch self {
        case .christian: return "Christian"
        case .muslim: return "Muslim"
        case .dharmic: return "Dharmic"
        case .iranian: return "Iranian"
        case .jewish: return "Jewish"
        case .pagan: return "Pagan"
        case .eastAsian: return "East Asian"
        }
    }
}

public enum Religion: String, CaseIterable, Sendable, Codable {
    // Christian
    case catholic, hussite, protestant, reformed, orthodox, bosnian, coptic, ethiopian, armenian, syriac, nestorian
    // Muslim
    case sunni, twelver, zaydi, ismaili, ibadi, druze, alawite, yazidi
    // Dharmic
    case hindu, jain, theravada, tibetan
    // Others
    case zoroastrian, jewish, tengri, folk
    // Phase 20.7, the Old World map: East Asia, and the African, Siberian
    // and Southeast Asian traditions split out of "folk". Listed last so the
    // older cases keep their order.
    case mahayana, confucian, daoist, shinto
    case westAfrican = "west_african"
    case bantu
    case eastAfrican = "east_african"
    case siberian, austronesian, highland

    public var family: ReligionFamily {
        switch self {
        case .catholic, .hussite, .protestant, .reformed, .orthodox, .bosnian, .coptic, .ethiopian, .armenian, .syriac, .nestorian:
            return .christian
        case .sunni, .twelver, .zaydi, .ismaili, .ibadi, .druze, .alawite, .yazidi:
            return .muslim
        case .hindu, .jain, .theravada, .tibetan, .mahayana:
            return .dharmic
        case .confucian, .daoist, .shinto:
            return .eastAsian
        case .zoroastrian:
            return .iranian
        case .jewish:
            return .jewish
        case .tengri, .folk, .westAfrican, .bantu, .eastAfrican, .siberian, .austronesian, .highland:
            return .pagan
        }
    }

    public var displayName: String {
        switch self {
        case .catholic: return "Catholic"
        case .hussite: return "Hussite"
        case .protestant: return "Protestant"
        case .reformed: return "Reformed"
        case .orthodox: return "Orthodox"
        case .bosnian: return "Bosnian Church"
        case .coptic: return "Coptic"
        case .ethiopian: return "Ethiopian Orthodox"
        case .armenian: return "Armenian Apostolic"
        case .syriac: return "Syriac Orthodox"
        case .nestorian: return "Church of the East"
        case .sunni: return "Sunni"
        case .twelver: return "Twelver Shia"
        case .zaydi: return "Zaydi"
        case .ismaili: return "Ismaili"
        case .ibadi: return "Ibadi"
        case .druze: return "Druze"
        case .alawite: return "Alawite"
        case .yazidi: return "Yazidi"
        case .hindu: return "Hindu"
        case .jain: return "Jain"
        case .theravada: return "Theravada Buddhist"
        case .tibetan: return "Tibetan Buddhist"
        case .zoroastrian: return "Zoroastrian"
        case .jewish: return "Jewish"
        case .tengri: return "Tengri"
        case .folk: return "Folk religion"
        case .mahayana: return "Mahayana Buddhist"
        case .confucian: return "Confucian"
        case .daoist: return "Daoist"
        case .shinto: return "Shinto"
        case .westAfrican: return "West African traditions"
        case .bantu: return "Bantu traditions"
        case .eastAfrican: return "East African traditions"
        case .siberian: return "Siberian shamanism"
        case .austronesian: return "Austronesian traditions"
        case .highland: return "Highland traditions"
        }
    }

    /// Map color for the religion map mode.
    public var color: RGB {
        switch self {
        case .catholic: return RGB(235, 220, 120)
        case .hussite: return RGB(150, 190, 230)
        case .protestant: return RGB(70, 120, 210)
        case .reformed: return RGB(90, 185, 200)
        case .orthodox: return RGB(160, 110, 200)
        case .bosnian: return RGB(110, 150, 210)
        case .coptic: return RGB(205, 140, 205)
        case .ethiopian: return RGB(225, 120, 180)
        case .armenian: return RGB(200, 90, 120)
        case .syriac: return RGB(180, 120, 160)
        case .nestorian: return RGB(120, 90, 150)
        case .sunni: return RGB(70, 160, 80)
        case .twelver: return RGB(30, 105, 70)
        case .zaydi: return RGB(110, 190, 150)
        case .ismaili: return RGB(60, 150, 160)
        case .ibadi: return RGB(160, 200, 90)
        case .druze: return RGB(90, 170, 200)
        case .alawite: return RGB(130, 180, 120)
        case .yazidi: return RGB(200, 200, 140)
        case .hindu: return RGB(240, 150, 60)
        case .jain: return RGB(240, 200, 160)
        case .theravada: return RGB(220, 110, 90)
        case .tibetan: return RGB(190, 80, 60)
        case .zoroastrian: return RGB(230, 90, 40)
        case .jewish: return RGB(70, 110, 200)
        case .tengri: return RGB(170, 140, 100)
        case .folk: return RGB(150, 120, 90)
        case .mahayana: return RGB(235, 170, 70)
        case .confucian: return RGB(200, 60, 60)
        case .daoist: return RGB(110, 160, 140)
        case .shinto: return RGB(230, 120, 130)
        case .westAfrican: return RGB(185, 110, 60)
        case .bantu: return RGB(140, 95, 55)
        case .eastAfrican: return RGB(170, 125, 80)
        case .siberian: return RGB(120, 140, 150)
        case .austronesian: return RGB(80, 150, 120)
        case .highland: return RGB(125, 150, 85)
        }
    }
}

/// A school or tradition inside one religion: Sunni schools of law, Hindu
/// traditions. Optional on each group of people.
public enum Sect: String, CaseIterable, Sendable, Codable {
    case hanafi, maliki, shafii, hanbali
    case vaishnava, shaiva, shakta, lingayat

    public var religion: Religion {
        switch self {
        case .hanafi, .maliki, .shafii, .hanbali: return .sunni
        case .vaishnava, .shaiva, .shakta, .lingayat: return .hindu
        }
    }

    public var displayName: String {
        switch self {
        case .hanafi: return "Hanafi"
        case .maliki: return "Maliki"
        case .shafii: return "Shafi'i"
        case .hanbali: return "Hanbali"
        case .vaishnava: return "Vaishnava"
        case .shaiva: return "Shaiva"
        case .shakta: return "Shakta"
        case .lingayat: return "Lingayat"
        }
    }
}

/// Sufi brotherhoods. They are present in provinces with a strength from
/// 0 to 1 and can carry political weight (the Safaviyya will turn militant).
public enum SufiOrder: String, CaseIterable, Sendable, Codable {
    case safaviyya, naqshbandi, bektashi, hurufi, mevlevi, qadiri, chishti, kubrawi, shadhili

    public var displayName: String {
        switch self {
        case .safaviyya: return "Safaviyya"
        case .naqshbandi: return "Naqshbandi"
        case .bektashi: return "Bektashi"
        case .hurufi: return "Hurufi"
        case .mevlevi: return "Mevlevi"
        case .qadiri: return "Qadiri"
        case .chishti: return "Chishti"
        case .kubrawi: return "Kubrawi"
        case .shadhili: return "Shadhili"
        }
    }
}
