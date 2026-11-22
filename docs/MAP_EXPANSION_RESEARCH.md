# Gez — 30 May 1453 World Map Expansion & Historical Accuracy Research

> [!IMPORTANT]
> **Research-only:** no game files were changed. This is a reference and design blueprint for future implementation sessions. Read the **Review notes** at the end first: they correct a few points below.

---

## 1. Current Map Baseline (Observed in Repo)

From inspecting [mapgen.py](../tools/mapgen/mapgen.py#L42-L46), [countries.txt](../data/map/countries.txt), [subjects.txt](../data/map/subjects.txt), [seas.txt](../data/map/seas.txt), [barriers.txt](../data/map/barriers.txt), and [provinces/](../data/map/provinces):

| Metric | Current Value | Notes |
|---|---|---|
| **Start date** | **30 May 1453** | Day after the Ottoman capture of Constantinople |
| **Bounds** | `LON -25.0° .. 98.0°`, `LAT -3.0° .. 71.5°` | Europe, North Africa, Horn of Africa, Middle East, Central Asia to modern China border, Indian subcontinent |
| **Grid resolution** | `PPD = 32` (`3936 × 2384` px) | `ProvinceIDMap` stores `UInt16` (`0` water, `1` wasteland, `2+` provinces — max 65,533) |
| **Playable regions / states** | **36 regions**, **238 states** | Plus 1 Wasteland region (`7` wasteland groups, `100` wasteland seeds) |
| **Land provinces** | **1,373** | [DESIGN.md](DESIGN.md#L18-L20) targets **1,500–2,500** for the current scope |
| **Countries (`countries.txt`)** | **266** | All 266 currently own ≥ 1 province |
| **Diplomatic subjects (`subjects.txt`)** | **24** | 4 Personal Unions, 8 Vassals, 12 Tributaries |
| **Internal Great Vassals (`holds:`)** | **43 entries** | Across `people_2_west.txt` – `people_5_south.txt` (40% tax retention, dynastic inheritance) |
| **Sea zones & barriers** | **79 sea zones**, **72 rivers**, **20 ridges**, **3 frontier lines** | Plus 38 land-army straits and 3 sea straits |

### Current Province Distribution by Region

- **Dense regions:** India (`300` provinces across 8 regions, led by Hindustan `67`, South India `50`, Northwest India `46`, Bengal `43`), Germany (`89`), British Isles (`77`), France (`74`), Iberia (`73`), Italy (`73`), Balkans (`71`).
- **Moderate regions:** Scandinavia (`53`), Anatolia (`53`), Poland & Lithuania (`51`), Russia (`46`), Maghreb (`46`), Carpathians & Danube (`39`), Persia (`37`), Horn of Africa (`34`), Arabia (`31`).
- **Coarse / frontier regions:** Caucasus (`25`), Low Countries (`24`), Alps (`23`), Kazakh Steppe (`21`), Baltic (`19`), Egypt (`19`), Khorasan & Afghanistan (`18`), Levant (`17`), Volga Steppe (`12`), Transoxiana (`12`), Mesopotamia (`11`), Pontic Steppe (`8`), Nubia (`7`).

---

## 2. Part I — Historical Border, Ownership & Vassal Audit (30 May 1453)

Gez models sub-polities in **two ways**:
1. **Separate map tags** in `countries.txt` + `subjects.txt` (`vassal`, `tributary`, `personal_union`) — best when a polity had distinct diplomacy, armies, or contested suzerainty.
2. **Internal Great Vassals** (`vassal | ... | holds:Prov1,Prov2` in `data/characters/people_*.txt`) — best when a magnate answered to the crown domestically.

Below are the concrete historical inaccuracies, missing vassals/tributaries, and border refinements found in the current 1453 map.

### 2.1 France, Burgundy & the Low Countries

1. **Free Imperial City of Metz (`LOR` -> `MTZ` or Imperial city):**
   - [01_iberia_france.txt](../data/map/provinces/01_iberia_france.txt#L180) assigns `Metz` to `LOR` (Lorraine). Historically, **Metz** (along with Toul and Verdun, the *Three Bishoprics*) was an autonomous **Free Imperial City** / Prince-Bishopric of the HRE, fiercely independent of the Dukes of Lorraine (France only occupied it in 1552).
2. **Duchy of Bar vs. Lorraine & Anjou (`LOR` / `PRO`):**
   - On 28 February 1453, Isabella, Duchess of Lorraine, died, and her son **John II of Anjou (John of Calabria)** formally entered Nancy in May 1453 as Duke of Lorraine (`LOR`, correctly reflected in [people_1453.txt](../data/characters/people_1453.txt#L333-L336)). However, his father **René of Anjou** (`PRO`) retained the **Duchy of Bar** (`Bar-le-Duc`) and **Duchy of Anjou** (`Angers`), while `Angers` is currently direct `FRA` and `Bar-le-Duc` is `LOR`. At minimum, René of Anjou should hold `Angers` (either as `PRO` or an internal French great vassal alongside Charles of Maine in `Le Mans`), and `Bar-le-Duc` can be `PRO` (in personal union / shared dynasty with `LOR`) or noted as held by René until 1480.
3. **Free Imperial City of Besançon (`BUR`):**
   - [01_iberia_france.txt](../data/map/provinces/01_iberia_france.txt#L176) gives `Besancon` directly to `BUR`. Historically, Besançon was a **Free Imperial City** enclaved within Burgundian Franche-Comté (though under Burgundian protection/influence).
4. **Nevers & Rethel (`BUR`):**
   - `Nevers` ([01_iberia_france.txt](../data/map/provinces/01_iberia_france.txt#L174)) was ruled in 1453 by **Charles I, Count of Nevers and Rethel** (Valois-Burgundy cadet branch, cousin of Philip the Good). In `people_2_west.txt`, John of Burgundy (Count of Nevers later) is listed, but `Nevers` works best as a `BUR` vassal or internal great vassal.
5. **Tournai & Cambrai (Low Countries border):**
   - **Tournai** was a direct **French royal enclave** inside Burgundian Flanders until 1521; **Cambrai** was a **Prince-Bishopric** (HRE buffer between France and Hainaut). Splitting `Tournai` (between `Ghent` and `Lille`) and `Cambrai` (between `Saint-Quentin` and `Mons`) sharply improves the Franco-Burgundian frontier.
6. **Guyenne / Gascony (30 May 1453 campaign accuracy):**
   - `Bordeaux` is rightly `ENG` (John Talbot landed Oct 1452 and held Bordeaux, Libourne, Fronsac, Castillon, Médoc until July 1453). Splitting **Libourne / Périgord-Castillon** (`ENG` or contested) or **Bazas / Landes** makes the final Hundred Years' War campaign in [wars_1453.txt](../data/diplomacy/wars_1453.txt#L14) playable beyond a single-province siege.
7. **French Great Vassals (potential subject tags vs. internal vassals):**
   - Currently `Bourbon`, `Orléans`, `Maine`, `Alençon`, `Armagnac`, `Albret`, and `Angoulême` are internal `holds:` vassals, while `Brittany` (`BRI`) and `Foix-Béarn` (`FOI`) are separate tags. Note that **Béarn** (`Pau`) was legally an allodial sovereign viscounty (not a French fief), while **Foix** (`Foix`) was a French fief; **Armagnac** (`Auch`, `Rodez`) and **Bourbon** (`Moulins`, `Clermont`) acted almost like sovereigns in the 1450s–1460s (League of the Public Weal). Adding **Bresse/Dombes** (Bourbon/Savoy border) and **Auvergne** / **Forez** / **Rouergue** provinces gives these great houses proper territorial shape.
8. **East Frisia (`Emden`):**
   - `Emden` is currently `FRI` (republic). Around **1453**, Hamburg relinquished Emden to **Ulrich I Cirksena**, who unified East Frisia into a lordship/county (`Emden`, `Aurich`) distinct from the West Frisian/Groningen "Frisian Freedom" republics.

### 2.2 Iberia & Atlantic

1. **Canary Islands (`01_iberia_france.txt`):**
   - Currently `Lanzarote | CAS`, `Gran Canaria | GUA`, `Tenerife | GUA`. Adding **La Palma** (`GUA`, conquered 1492–1493) and **Fuerteventura / El Hierro** (`CAS`, held by the Herrera-Peraza lords as Castilian vassals) fixes the archipelago's 1453 split.
2. **Olivenza (`POR` vs `CAS`):**
   - In 1453, **Olivenza** (east of the Guadiana) belonged to **Portugal** (until 1801), whereas `Badajoz` (`CAS`) currently absorbs everything east of `Evora`/`Beja`.
3. **Navarre Civil War (1451–1455):**
   - `Pamplona` and `Tudela` are `NAV`. In May 1453, Navarre was split by civil war between **John II of Aragon** (holding the Ribera/Tudela with the Agramontese) and his son **Charles, Prince of Viana** (holding Pamplona/mountains with the Beaumontese).

### 2.3 British Isles & Ireland

1. **Ireland simplifications ([HISTORY_NOTES.md](HISTORY_NOTES.md#L18-L20)):**
   - Currently `Cavan` is given to `TYC` (Tyrconnell), and `Wexford` + `Tullamore` to `LEI` (Leinster/Kavanagh), and `Limerick` to `DES` (Desmond).
   - **Historically in 1453:**
     - **East Breifne (`Cavan`)** was ruled by the **O'Reillys**, and **Fermanagh (`Enniskillen`)** by the **Maguires** (between Tyrconnell and Tyrone).
     - **West Connacht / Mayo (`Castlebar`)** was ruled by **MacWilliam Íochtar (Lower Burke)**, distinct from Clanricarde (`Galway`), while **Roscommon** was **O'Conor** territory.
     - **Offaly (`Tullamore`)** was **O'Connor Faly** (distinct from MacMurrough-Kavanagh of Leinster at Ferns/Carlow), while **Wexford town** was an Anglo-Irish liberty under the Talbots (Earls of Shrewsbury/Waterford).
     - **Limerick** city was a walled English-chartered royal borough surrounded by Thomond/Desmond lordships.
   - **Suggested new Irish provinces/tags (if increasing density):** `Enniskillen` (Maguire / Fermanagh), `Monaghan` (MacMahon / Oriel), `Carlow` (MacMurrough-Kavanagh seat), `Athlone` (O'Conor / Roscommon), `Maynooth` (Kildare vs Pale).
2. **England & Scotland:**
   - `Roxburgh` (`ENG`) and `Berwick` (`ENG`) are historically spot-on for May 1453 (Scotland retook Roxburgh in 1460 and Berwick in 1461).
   - **Isle of Man** (`ENG`): held by the **Stanley** family as Kings/Lords of Mann — good candidate for an internal `ENG` `holds:Isle_of_Man` vassal!
   - **Highlands / Borders:** Adding **Orkney & Shetland** (`NOR`, pledged 1468/69 — already accurate!), plus splitting **Galloway** (Douglas heartland) and **Moray/Badenoch** or **Caithness/Sutherland** improves Scottish clan/magnate geography.

### 2.4 Holy Roman Empire, Alps & Baltic

1. **Further Austria (`Ensisheim`, `Freiburg`):**
   - Currently assigned to `TIR` (Sigismund of Tyrol). As [HISTORY_NOTES.md](HISTORY_NOTES.md#L419) already flags, in May 1453 **Further Austria** (Breisgau, Sundgau, Alsace-Habsburg) was ruled by **Archduke Albert VI of Austria** (Frederick III's brother); Sigismund only received it in **1458**. Either add a `FUR` (Further Austria) tag or assign `Ensisheim`/`Freiburg` to `HAB` / a new `ALB_H` / `FUR` tag with Albert VI as ruler.
2. **Swiss Confederacy (`SWI`) borders in 1453:**
   - `Basel`, `Sankt Gallen`, and `Sion` (Valais) are currently `SWI`. In May 1453:
     - **Basel** was a **Prince-Bishopric & Free Imperial City** (joined the Confederacy only in **1501**).
     - **St. Gallen** (Imperial City + Prince-Abbey) became an *associate* (`Zugewandter Ort`) in **1454/1451**, not a full canton.
     - **Valais (`Sion`)** was an independent bishopric/republic (Seven Tithings) allied with Bern/Swiss.
     - **Thurgau** (`Konstanz` hinterland) was still **Habsburg** until **1460**!
     - **Aargau** (`Baden/Aarau`) was Swiss condominium (conquered 1415).
3. **Missing HRE States (currently merged per [HISTORY_NOTES.md](HISTORY_NOTES.md#L10-L14)):**
   - **Pomerania (`POM`)**: In 1453, Pomerania was partitioned between **Pomerania-Wolgast** (`Wolgast`, `Stralsund` — Wartislaw IX), **Pomerania-Stettin** (`Stettin` — Joachim/Otto III), and **Pomerania-Stolp** (`Stolp`, `Kolberg` — Eric I of Pomerania, former Kalmar king, reigning in Rügenwalde/Stolp until 1459!).
   - **Schleswig-Holstein (`HOL`)**: Adolf VIII held **Schleswig** (a **Danish fief/vassal**) and **Holstein** (an Imperial county) together until 1459. Making `HOL` a tributary/vassal of `DAN` (or splitting `Schleswig` vs `Kiel`/`Flensburg`) reflects the 1460 Treaty of Ribe crisis!
   - **Saxe-Lauenburg**: Missing between `Lubeck`, `Hamburg`, `Luneburg`, and `Schwerin`.
   - **Anhalt** (Dessau/Bernburg/Köthen — currently merged into `MAG`), **Osnabrück** & **Paderborn** (separate prince-bishoprics, merged into `MUN`), **Fulda** (Prince-Abbey, merged into `HES`), **Nassau** (Wiesbaden/Dillenburg, merged between `MAI`/`HES`/`TRI`), **Konstanz** (Prince-Bishopric, merged into `ULM`), **Bavaria-Ingolstadt** (actually absorbed by **Bavaria-Landshut** `LAN` in 1447 — so `Ingolstadt | LAN` in the current map is **accurate**!), **Palatinate-Neumarkt/Mosbach** (Otto I ruled `Amberg`/Upper Palatinate semi-autonomously as a Wittelsbach cadet).
4. **Bohemia, Silesia & Lusatia:**
   - **Lower Lusatia:** `Cottbus` is `BRA` (Brandenburg acquired Cottbus 1445/1455), while the rest of Lower Lusatia (**Lübben / Guben / Sorau**) belonged to **Bohemia** (`BOH`) until 1462 — adding `Guben` or `Lubben` (`BOH`) fixes the Brandenburg–Bohemia border.
   - **Silesia:** Currently all `BOH` (with Bolko V as internal vassal in `Opole`). In reality, Silesia was a patchwork of Bohemian-vassal Piast duchies: **Teschen (Cieszyn)**, **Oświęcim & Zator** (note: **Oświęcim** became a Polish vassal in 1454 and was bought by Poland 1457!), **Liegnitz (Legnica)**, **Głogów**, **Oleśnica (Oels)**, **Żagań (Sagan)**, and **Opava/Racibórz** (Přemyslid branch).
5. **Baltic Prince-Bishoprics:**
   - `Osel` is currently `LVO` (Livonian Order), whereas the **Bishopric of Ösel-Wiek** (Haapsalu / Kuressaare) was an independent prince-bishopric alongside Riga (`RIG`) and Dorpat (`DOR`). Similarly, **Bishopric of Courland** (Piltene) and **Bishopric of Warmia / Ermland** (in Prussia, under `TEU` protection) can be added as vassals/tags or provinces (`Braunsberg`/`Heilsberg`).

### 2.5 Italy

1. **Rimini (`PAP`):** `Rimini` is currently direct `PAP`, though in 1453 **Sigismondo Pandolfo Malatesta** ruled Rimini, Fano, and Cesena as an autonomous *signoria* / Papal vicar often at war with Urbino (`URB`) and the Papacy.
2. **Missing Minor Italian Polities:**
   - **Lordship of Piombino** (Appiani dynasty, coastal Tuscany between `Pisa` and `Grosseto`).
   - **Papal Benevento** (and Pontecorvo) — Papal enclaves inside `NAP` (between `Naples` and `Foggia`).
   - **Marquisate of Finale** / **Monaco** (Grimaldi) on the Ligurian coast (`GEN`).
   - **Venetian Overseas/Terraferma gaps:** `Crema` (taken by Venice 1449, between `Milan` and `Brescia`); **Tinos & Mykonos** (Venetian Aegean, not Naxos); **Cerigo / Kythira** (Venetian off southern Morea); **Aegina** (Venetian from 1451).

### 2.6 Poland, Lithuania, Rus' & Pontic Steppe

1. **Upper Oka Principalities (`Kozelsk | LIT`):**
   - Between Muscovy (`MOS`) and Lithuania (`LIT`) along the upper Oka stood the **Upper Oka (Verkhovsky) Principalities** (**Vorotynsk, Odoyev, Belyov, Novosil, Kozelsk, Mezetsk**) — autonomous Rurikid buffer vassals of Lithuania. Representing them as a `LIT` vassal tag (`OKA`) and splitting `Kozelsk`/`Odoyev`/`Belyov` makes the Muscovite–Lithuanian frontier much more authentic.
2. **Principality of Rostov (`Rostov | MOS`):**
   - In 1453, **Rostov** was still a distinct Rurikid principality (split into two halves, one slowly bought by Moscow, the final half annexed in **1474**). It should be a `MOS` vassal (`ROS`) or internal vassal rather than direct crown domain.
3. **Novgorod & Shemyaka (May 1453):**
   - Dmitry Shemyaka was sheltered in **Novgorod** (`NOV`) in May 1453 (poisoned there in July 1453). Adding **Veliky Novgorod**'s outer towns (**Toropets** contested with `LIT`, **Bezhichi**, **Demyansk**, **Kola / Ter Coast**, **Dvina Land / Arkhangelsk area**) helps fill the vast Russian North.
4. **Moldavia (`MOL`) & Ochakiv (`CRI`):**
   - `subjects.txt` has `POL MOL vassal`. This is accurate for May 1453 (both Alexăndrel and Petru Aron swore fealty to Poland; Ottoman tribute began only in **1456** under Petru Aron).
   - `Ochakiv` is `CRI` (`03_north_east_europe.txt`), though in the 1450s the lower Dniester–Bug coast (Dashev / Ochakiv) was a sparsely inhabited, contested frontier between **Lithuania** (`LIT`) and **Crimea** (`CRI` only fortified/held Ochakiv firmly in the 1490s).
   - `Tana` (`VEN`): Venice and Genoa actually shared **Tana (Azov)** as twin merchant quarters until the Ottoman conquest of 1475.

### 2.7 Balkans, Anatolia & Caucasus

1. **Anatolian & Kurdish Beyliks/Emirates:**
   - **Alaiye (`Alanya | KAR`):** Alanya was ruled by the **Beylik of Alaiye** (an autonomous Karamanoğlu cadet branch under Mamluk/Karaman influence) until 1471.
   - **Hasankeyf (`Hasankeyf | AKK`):** In 1453, **Hasankeyf** was still ruled by an **Ayyubid** remnant dynasty (the Meliks of Hasankeyf) until Uzun Hasan conquered it in **1462**.
   - **Cizre (`Cizre | AKK`):** Cizre was the seat of the autonomous Kurdish **Emirate of Bohtan** (Azizan dynasty), alongside **Bitlis** (`BIT`), **Hakkari** (`HAK`), and **Çemişgezek / Eğil / Palu**.
   - **Ottoman–Genoese / Aegean islands:** `Old Phocaea` (north of `Izmir`) was held by the **Gattilusi** of Lesbos (`LES`) until 1455! And **Naxos** (`NAX`) / **Chios** (`GEN`) began paying Ottoman tribute right around 1453–1455.
2. **Caucasus (`04_balkans_anatolia_caucasus.txt`):**
   - `SAM` (Samtskhe): [people_1453.txt](../data/characters/people_1453.txt#L444-L446) correctly lists **Qvarqvare II Jaqeli** as ruler in 1453 (note: [HISTORY_NOTES.md](HISTORY_NOTES.md#L222) mentions `Kaikhosro Jaqeli` as uncertain heir birth year).
   - **Georgia (`GEO`)**: George VIII ruled united Georgia in 1453, with `Kutaisi` (Bagrat of Imereti), `Zugdidi` (Dadiani of Mingrelia), and `Ozurgeti` (Gurieli of Guria) already modelled as internal great vassals — very good! Adding **Svaneti** (`Mestia`) and **Abkhazia** (`Sukhumi` Sharvashidze) as internal vassals, plus **Kakheti** (`Telavi`) province detail, strengthens it further.
   - **Ardabil (`QAR`):** Shaykh Junayd of the **Safaviyya** was in exile (in Anatolia/Syria) in 1453; Jahan Shah of Qara Qoyunlu had installed Junayd's uncle **Ja'far** as head of the shrine in Ardabil (`QAR` control is accurate).

### 2.8 Middle East, Arabia, Persia & Central Asia

1. **Yemen on 30 May 1453 (`TAH` vs Rasulids):**
   - Currently `Aden`, `Taizz`, `Zabid`, `Jizan` belong to `TAH` (Tahirid Sultanate). Historically, the **Tahirids** seized **Aden** in **1453–1454**, while the last **Rasulid** sultan (*al-Mas'ud Abu al-Qasim*) did not abdicate until **1454**. A more exact 30 May 1453 split would either show **Rasulids** holding `Zabid`/`Taizz`/`Jizan` and **Tahirids** holding `Aden`/`Lahij` (at war or in crisis), or flag this as an explicit judgment call in `HISTORY_NOTES.md`.
2. **Aq Qoyunlu (`AKK`) & Qara Qoyunlu (`QAR`):**
   - **1453** was the exact year **Uzun Hasan** seized Diyarbakir from his brother **Jahangir** (who kept fighting from Mardin/Urfa until 1457) — representing a `Diyarbakir` vs `Mardin` civil conflict or event in 1453–1457 is very rich.
   - **Qara Qoyunlu (`QAR`):** Jahan Shah's son **Pir Budaq** conquered Isfahan, Shiraz (Fars), Yazd, and Kerman from the Timurids across **1452–1453** — `QAR` holding Persia is accurate for mid-1453 (and Pir Budaq makes a natural internal great vassal `holds:Shiraz,Isfahan`!).
3. **Mazandaran & Rustamdar (`Nur | MZD`):**
   - `MZD` represents the **Mar'ashi Sayyids** of `Sari`/Amol, whereas `Nur` (Rustamdar) was ruled by the **Paduspanids** (a separate ancient Caspian dynasty). Similarly, `GIL` (`Lahijan` = Karkiya Sayyids of Bia-pish; `Rasht` = Ishaqvand of Bia-pas) was two distinct halves.
4. **Hejaz (`HEJ`):**
   - `HEJ` (Sharifate of Mecca) holds `Medina` and `Yanbu` too; historically **Medina** was ruled by a separate **Husaynid** sharifal dynasty (Banu Muhanna / Husaynid Emirs of Medina, also Mamluk-aligned).
5. **Nubia & Horn of Africa (`06_africa.txt`):**
   - `Sennar | JAA` is south of `Soba | ALO`; in 1453 the **Ja'alin** lived along the Nile *north* of Soba (Shendi/Atbara), while the Gezira/Sennar was still under declining **Alodia** (`ALO`) or **Juhayna / Abdallab** Arabs until the Funj Sultanate appeared c. 1504.
   - `Debarwa` & `Massawa | ETH`: **Medri Bahri** (Bahr Negash at Debarwa) was an autonomous march/tributary of Ethiopia, while **Massawa / Dahlak** had its own Muslim island sultanate (Sultanate of Dahlak) paying tribute to Ethiopia/Adal.

### 2.9 India (Audit of Current ~300 Provinces)

India is already the most detailed part of the map (`300` provinces across 8 regions). Key accuracy refinements to consider:
1. **Orissa (`ORI`, Kapilendra Deva) & Telangana/Andhra:**
   - In 1453, Gajapati Orissa was expanding rapidly south along the coast (`Rajahmundry` already `ORI`, `Kondavidu` taken c. 1454) and held tributary **Garhjat** chiefs in Jharkhand/Odisha hills (**Keonjhar, Mayurbhanj, Khukhra/Chota Nagpur** — currently `Sambalpur`/`Mayurbhanj` are direct `ORI`).
2. **Vijayanagara (`VIJ`) & Bahmani (`BAH`) vassals:**
   - **Velamas of Rachakonda/Devarakonda** (between `Golconda`, `Nalgonda`, and `Kondavidu`) acted as contested buffers between Bahmani, Orissa, and Vijayanagara.
   - **Ummattur**, **Tuluva/Barkur**, and **Ikkeri/Keladi** (western Mysore/Kanara) were autonomous feudatories under Vijayanagara.
3. **Malwa–Mewar–Gujarat–Delhi:**
   - **Mewat** (`Mewat | DEL`, held by Khanzada Ahmad Khan Mewati as an internal `DEL` vassal in `people_5_south.txt`) was virtually autonomous in 1453.
   - **Sibi** (`Sibi | BLC`): contested between Sindh (`SND`), Baloch tribes (`BLC`), and Timurid Kandahar (`HRT`).

---

## 3. Part II — Making the Map Bigger: Geographic World Expansion

Notice that [09_wasteland.txt](../data/map/provinces/09_wasteland.txt#L55-L108) **already anticipates off-map regions** under `@ Beyond the Map` (Tibet, Xinjiang/Tarim, Mongolia, Siberia, Burma/Yunnan, Sahel/Chad/Bornu, East Africa), and [build_models.py](ROADMAP.md#L330-L331) already includes an **East Asian** 3D architectural style (pagodas).

### Recommended Geographic Bounding Options

| Option | Bounding Box | Grid Size (at `PPD = 32`) | New Regions Covered | Fit for Gez |
|---|---|---|---|---|
| **Option 1: Full Afro-Eurasia ("Old World")** *(Recommended)* | `LON -25° .. 148°`, `LAT -35° .. 71.5°` | `5536 × 3408` px (~1.9× pixels) | **East Asia, Southeast Asia, Central/East Siberia, Sub-Saharan Africa + Madagascar** | Completes the entire Old World trade network (Silk Road, Spice Islands, Swahili/Zimbabwe gold, West African gold), no Americas colonialism complexity yet |
| **Option 2: Eurasia-Only Expansion (East + SE Asia)** | `LON -25° .. 148°`, `LAT -11° .. 71.5°` | `5536 × 2640` px (~1.5× pixels) | **China, Tibet, Mongolia, Korea, Japan, Mainland & Maritime SE Asia, Siberia** | Smallest RAM/texture increase; closes the eastern border cleanly at the Pacific & Java Sea |
| **Option 3: Full Global Map (incl. Americas)** | `LON -180° .. 180°`, `LAT -58° .. 72°` | `11520 × 4160` px (at 32 PPD; ~5× pixels) | Adds **Mesoamerica (Aztec Triple Alliance, Tarascans, Maya), Andes (Inca under Pachacuti), North/South American polities & colonization** | Huge scope increase: requires naval exploration, Pacific wrap-around, and colonial mechanics; likely pushes M1 8GB RAM if `PPD` isn't tuned |

Below is the **30 May 1453 historical breakdown** of states, vassals, borders, and key provinces for **Afro-Eurasia (Option 1)** so a future session has an immediate blueprint.

---

### 3.1 East Asia on 30 May 1453

1. **Ming China (`MNG` — `monarchy`, Confucian/folk or Mahayana/folk — note religion enum check needed):**
   - **Ruler (30 May 1453):** **Jingtai Emperor (Zhu Qiyu)** (r. 1449–1457), installed after the **1449 Tumu Crisis** when the Oirats captured his elder brother Yingzong (released 1450 and under house arrest in Beijing in 1453).
   - **Borders & Frontier:** Ming controlled China proper (the Two Capitals Beijing & Nanjing, plus 13 provinces), **Liaodong**, and the **Nine Garrisons** along the northern frontier (gradually rebuilding the Great Wall after Tumu), plus **Hami/Kara Del** frontier protectorate and **Dongning/Liaodong** borderlands.
   - **Vassals / Autonomous Borderlands:**
     - **Southwest *Tusi* Chieftaincies** in Yunnan, Guizhou, and western Sichuan (e.g., **Lijiang/Naxi**, **Dali**, **Dehong/Shan *tusi***, **Shuidong/Bo**, **Miao/Yi chiefdoms**) — ideal as Ming vassals/tributaries or high-autonomy provinces.
     - **Ming Imperial Princedoms** (e.g., Prince of Ning, Prince of Chu, Prince of Qin, Prince of Jin) — internal `holds:` great vassals!
     - **Tributaries:** **Joseon Korea**, **Ryukyu**, **Dai Viet**, **Ayutthaya**, **Malacca**, **Hami (Kara Del)**, **Jurchen commanderies**.
2. **Oirat Confederation (`OIR` — currently 2 provinces, expand across Mongolia & Dzungaria):**
   - **Ruler (30 May 1453):** **Esen Taishi** at the **zenith of Oirat power**. Having defeated and killed the Chinggisid Taisun Khan (1452), Esen declared himself **Khagan of the Great Yuan** in **1453** (which provoked Mongol noble backlash and his assassination in 1454–1455).
   - **Territory:** Dzungaria, Western & Central Mongolia (Karakorum), Upper Yenisei/Altai, and suzerainty over **Moghulistan** raids, **Hami**, and the **Uriankhai Three Guards** (Doyan, Fuyu, Taining — eastern Inner Mongolia/Manchuria border, Ming/Oirat-tributary buffer).
   - **Potential Split/Vassals:** **Northern Yuan / Eastern Mongols** (Chahar/Khalkha remnants under Agbarjin/Markörgis), **Uriankhai Three Guards (`URI`)** (tributary buffer between Ming and Oirat).
3. **Moghulistan (`MGH` — expand eastward):**
   - Currently cut off at `Almaty`/`Naryn`, leaving `Kashgar`, `Yarkand`, `Khotan`, `Aksu`, `Turpan` in wasteland. Extending `MGH` across the **Tarim Basin** (with **Dughlat Emirs of Kashgar** as internal great vassal or vassal tag!) and **Turpan** (contested with Oirats/Chagatai) completes Central Asia.
4. **Kara Del / Hami (`HAM` or `KDL`):**
   - Chagatai-descended oasis khanate at **Hami (Kumul)**, Ming tributary contested by the Oirats in 1453.
5. **Manchuria / Jurchens:**
   - **Jianzhou Jurchens** (Yalu/Changbai border, **Li Manzhu** / **Tunggiya**), **Haixi Jurchens** (Hulun confederation, Songhua river), **Wild Jurchens / Nurgan** (Amur basin, Nanai/Nivkh/Evenk tribes) — loose Ming *weisuo* commandery tributaries.
6. **Tibet (1453 fragmentation):**
   - **Phagmodrupa (`PHA`)** in Ü (`Lhasa`, `Nedong`) — nominal rulers of central Tibet (under **Drakpa Jungne / Kunga Lekpa**), steadily losing real power to:
   - **Rinpungpa (`RIN`)** in Tsang (`Shigatse`, `Gyantse`, `Rinpung`) — de facto dominant house in western-central Tibet since 1435!
   - **Guge (`GUG`)** (`Tsaparang`, `Purang`) & **Mangyül Gungthang** in western Tibet (alongside `LDK` Ladakh).
   - **Kham / Derge / Lingtsang** & **Amdo / Tsongkha** tribal/monastic polities in eastern Tibet.
7. **Joseon Korea (`JOS`):**
   - **Ruler (30 May 1453):** **King Danjong** (11 years old), during the exact year of the **Gyeyu Jeongnan** coup (late 1453) by **Grand Prince Suyang** (later King Sejo).
   - **Territory:** Whole Korean peninsula up to the Yalu and Tumen rivers (Six Garrisons established under Sejong), plus **Jeju Island**.
   - **Provinces / States:** Pyongan, Hamgyong, Hwanghae, Gyeonggi (`Hanyang`/Seoul), Gangwon, Chungcheong, Jeolla, Gyeongsang (`Busan`/`Gyeongju`), Jeju.
8. **Ashikaga Japan (`JAP` / `ASH`) & Regional Daimyo/Shugo:**
   - **Ruler (30 May 1453):** **Ashikaga Yoshimasa** (8th Shogun, changed name from Yoshishige in 1453), **Emperor Go-Hanazono** in Kyoto.
   - **Political Reality in 1453 (pre-Ōnin War):** Japan was NOT yet in Sengoku fragmentation, nor was it a single centralized unitary state — it was a **shogunate with powerful *shugo* / *kanrei* great vassals** (either internal `holds:` magnates or Japanese *shugo* vassals!).
   - **Key 1453 Houses:** **Hosokawa** (Katsumoto — *kanrei*, Shikoku + Settsu/Tamba), **Yamana** (Sōzen — Tajima, Inaba, Aki/Harima), **Hatakeyama** (Kawachi/Kii/Etchū — succession crisis starting 1454!), **Shiba** (Echizen/Owari/Tōtōmi), **Ōuchi** (Suō/Nagato/Buzen — major Ming trade port at Yamaguchi/Hakata), **Shimazu** (Satsuma/Ōsumi), **Ōtomo** (Bungo), **Shōni** (Chikuzen/Hizen), **Kōno** (Iyo), **Uesugi & Kamakura Kubō (Ashikaga Shigeuji)** in the Kantō (on the verge of the **Kyōtoku Incident** of **1454–1455**!), **Takeda** (Kai), **Imagawa** (Suruga), **Date** (Mutsu), **Kakizaki/Andō** (southern Ezo/Tsugaru).
   - **Hokkaido (Ezo):** **Ainu tribes** (`AIN`) across central/northern Hokkaido, Sakhalin, and Kurils.
9. **Ryukyu Kingdom (`RYU`):**
   - **30 May 1453 crisis:** Exact year of the **Shiro–Furi Rebellion** after King Shō Kinpuku's death, burning Shuri Castle before **Shō Taikyū** took the throne! Crucial maritime trade entrepôt linking Ming, Japan, Korea, and SE Asia.

---

### 3.2 Mainland & Maritime Southeast Asia on 30 May 1453

1. **Kingdom of Ava (`AVA`, Upper Burma):** Ruler **Narapati I** (r. 1442–1468); Burmese heartland (`Ava`, `Pagan`, `Prome`, `Toungoo` as restless vassal/governorship!).
2. **Hanthawaddy Pegu (`PEG`, Lower Burma):** **Queen Shin Sawbu** ascended **1453/1454** after the death of the last male heir (`Pegu`, `Dagon`/Yangon, `Martaban`, `Bassein`).
3. **Shan States (`SHN` or split `MOG` Mong Mao / `HSE` Hsenwi / `HSI` Hsipaw / `KAL` Kale):** Semi-independent Tai-Shan *sawbwa* principalities in northern/eastern Burma & Yunnan borderlands, balancing between Ming and Ava (after the 1436–1449 Luchuan–Pingmian Ming wars).
4. **Kingdom of Mrauk U / Arakan (`ARK`):** Ruler **Min Khayi (Ali Khan)** (r. 1434–1459), expanded north toward Chittagong (`Ramu`), bridging Bengal and Burma.
5. **Lan Na (`LNA`, Chiang Mai):** Ruler **Tilokarat** (r. 1441–1487), fighting Ayutthaya over Sukhothai/Kamphaeng Phet (`Chiang Mai`, `Chiang Rai`, `Lampang`, `Nan` — conquered 1449!).
6. **Ayutthaya (`AYU`, Siam):** Ruler **Borommatrailokkanat (Trailok)** (r. 1448–1488), with **Sukhothai / Phitsanulok** recently integrated under viceregal rule, plus southern **Tenasserim/Mergui** and Malay tributaries (**Ligor/Nakhon Si Thammarat**, **Pattani**, **Kedah**, and contested suzerainty over **Malacca**!).
7. **Lan Xang (`LXA`, Laos):** Ruler **Chakkaphat Phaen Phaeo** (`Luang Prabang`, `Vientiane`, `Champasak`).
8. **Cambodia / Chaktomuk (`KHM`):** Ruler **Ponhea Yat** (post-Angkor relocation to `Phnom Penh` / `Lovek`).
9. **Dai Viet (`DAI`):** **Emperor Lê Nhân Tông** (assumed personal rule in **1453** at age 12 after regency; `Thang Long`/Hanoi, `Thanh Hoa`, `Nghe An`, `Thuan Hoa`/Hue).
10. **Champa (`CHA`):** Vijaya (`Qui Nhon`), Kauthara (`Nha Trang`), Panduranga (`Phan Rang`) — still holding central/southern coast in 1453 prior to the 1471 Vietnamese conquest.
11. **Maritime Southeast Asia (if extending to `LAT -11°`):**
    - **Malacca Sultanate (`MLC`)**: **Muzaffar Shah** (r. 1445–1459) — dominant Muslim trade entrepôt of the Strait, with vassals **Pahang** (contested with Ayutthaya), **Klang**, and Sumatra ports (**Kampar**, **Siak**, **Indragiri**).
    - **Samudera Pasai (`PSA`)** & **Pedir / Daya / Lamuri (Aceh)** in northern Sumatra.
    - **Pagruyung / Minangkabau** & **Palembang** in central/southern Sumatra.
    - **Majapahit (`MAJ`)**: Eastern/central Java (`Trowulan`, `Surabaya`, `Tuban`, `Bali` as vassal), still holding nominal suzerainty over coastal ports while **Demak/Gresik** Islamic communities rise; **Kingdom of Sunda (`SUN`)** in western Java (`Pakuan Pajajaran`, `Banten`, `Cirebon`).
    - **Brunei (`BRU`)** in northern Borneo; **Sulu (`SUL`)** & **Tondo / Maynila / Cebu / Maguindanao** in the Philippines; **Ternate** & **Tidore** (Spice Islands — clove monopoly!).

---

### 3.3 Sub-Saharan Africa on 30 May 1453

Extending `LAT_MIN` from `-3.0°` down to `-35.0°` (Cape of Good Hope) unlocks:

1. **West Africa & Sahel:**
   - **Mali Empire (`MAL`)**: Centered at `Niani`/`Kangaba`, controlling Bambuk/Bure goldfields, **Kaabu**, and upper Niger, though losing northern Sahel towns (**Timbuktu**, **Walata** held by **Tuareg** `Akil ag Malwal` from c. 1433!).
   - **Songhai (`SON`, Gao)**: Under **Sulaiman Dama** (just before **Sonni Ali**, r. 1464–1492), expanding from `Gao`/`Kukiya` along the Niger bend.
   - **Jolof Empire (`JOL`)**: Senegambia (`Diourbel`, `Cayor`, `Waalo`, `Sine`, `Saloum` vassals; Portuguese caravels already reaching Cape Verde/Senegal coast in the 1440s–1450s!).
   - **Mossi Kingdoms (`MOS_A` / `WAG` Wagadugu, `YAT` Yatenga)** in the Volta basin.
   - **Hausa Bakwai**: **Kano (`KNO`)**, **Katsina (`KTS`)**, **Zazzau (`ZAZ`)**, **Gobir**, **Daura**, **Rano**, **Biram** — walled city-states (`Kano` under Yakubu, 1452–1463!).
   - **Kanem-Bornu (`KBO`)**: Sayfawa **Mohammed III** (c. 1453–1458) based in **Bornu** (`Ngazargamu` region/Yobe), while the **Bulala** held old **Kanem** (`Njimi`) east of Lake Chad, and **Wadai / Bagirmi / Darfur** (`Tunjur` dynasty in Darfur in 1453!) lay further east.
   - **Forest & Guinea Coast States:** **Kingdom of Benin (`BEN`)** under **Oba Ewuare the Great** (r. c. 1440–1473, at peak expansion!), **Oyo Empire (`OYO`)** & **Ife**, **Nupe**, **Akan / Bono Manso** (gold trade), **Dahomey/Allada** precursors.
2. **Central & Southern Africa:**
   - **Kingdom of Kongo (`KON`)**: Centered at `Mbanza Kongo` (with coastal/interior provinces Soyo, Nsundi, Mpangu, Mbata, Mbamba), plus neighbors **Loango**, **Ndongo**, **Tio (Anziku)**, **Luba** / **Lunda** inland.
   - **Great Lakes:** **Bunyoro-Kitara / Buganda / Rwanda / Burundi** (or inland tribal/monarchy clusters).
   - **Swahili Coast (completing `PTE` Pate):** **Mombasa**, **Malindi**, **Zanzibar**, **Kilwa Sultanate (`KIL`)** (premier gold/ivory port), **Sofala**, **Angoche**, **Mogadishu/Lamu**.
   - **Zimbabwe Plateau:** **Mutapa Empire (`MTP`)** under **Matope Nyanhehwe Nebedza** (r. c. 1450–1480, expanding from Great Zimbabwe/Mount Fura to the Zambezi & Sofala hinterland!), plus **Butua (Torwa dynasty)** at Khami.
   - **Madagascar:** **Merina** (`Imerina` highlands), **Sakalava / Betsimisaraka / Antemoro** coastal chiefdoms.

---

### 3.4 Central & Eastern Siberia (Northern Frontier)

- **Khanate of Sibir / Tyumen (`SIB`)**: Western Siberia along the Tobol/Irtysh (`Chimgi-Tura` / Tyumen, `Qashliq`), contested between **Hajji Muhammad's** Shaybanid line and **Taibugids** (note: `Chimgi-Tura` is currently `UZB` in `07_steppe_central_asia.txt`).
- **Principality of Pelym / Kondia (`VOG` / Mansi)** & **Kod / Ob Ostyaks (`KHA` / Khanty)** in the Ob basin.
- **Evenks, Buryats (`BYA`), Yakuts (Sakha)** along the Yenisei, Baikal, and Lena if extending across northern Asia.

---

## 4. Part III — Increasing Density & Resolution Within the Existing Map

Even *before* or *alongside* expanding the geographic bounds, Gez currently sits at **1,373** provinces while [DESIGN.md](DESIGN.md#L19-L20) targets **1,500–2,500** for the western/central Old World alone.

### 4.1 Priority Regions for Subdivision (Adding ~350–650 Provinces)

| Region | Current | Target | Why & Key Splits Needed |
|---|---|---|---|
| **Germany / HRE** | 89 | 140–160 | Needs provinces to separate Anhalt (`Dessau`), Osnabrück, Paderborn, Fulda, Nassau (`Wiesbaden`/`Siegen`), Konstanz, Saxe-Lauenburg, Mark (`Unna`) vs Cleves, Berg (`Solingen`) vs Jülich, Pomerania's 3 duchies (`Rügen`/`Wolgast`, `Stettin`, `Stolp`), Lower Lusatia (`Lubben`), Upper Palatinate (`Neumarkt`), Thuringia (`Eisenach`/`Gotha`), Lower Saxony (`Hildesheim`, `Verden`, `Minden`). |
| **France** | 74 | 100–115 | Split large provinces so great vassals don't overlap: `Bazas`/`Libourne` (Castillon campaign), `Tournai` (French enclave), `Cambrai`, `Bar`/`Verdun`/`Toul` vs `Metz`, `Anjou`/`Saumur` vs `Angers`, `Beaujolais`/`Forez` (Bourbon), `Vivarais`/`Cévennes`, `Perche`, `Brie` (`Meaux`), `Soissons`. |
| **Italy & Alps** | 73 + 23 | 95 + 32 | Add `Piombino`, `Crema`, `Benevento`, `Finale`/`Ventimiglia`, `Massa`, `Forlì`/`Cesena` vs `Rimini`, `Chieti`/`Brindisi`/`Catanzaro`/`Capua`; in Alps split `Basel` city vs `Porrentruy`, `Thurgau` (`Frauenfeld`, HAB), `Neuchâtel`, `Bregenz`, `Vorarlberg`, `Villach`. |
| **Low Countries** | 24 | 32–36 | Add `Breda` (Nassau), `Maastricht`/`Hasselt` (Loon), `Zierikzee`/`Veere`, `Alkmaar`, `Amersfoort`, `Coevorden` (Drenthe), `Aurich` (East Frisia), `Namur`/`Dinant`, `Ypres`, `Kortrijk`. |
| **Iberia** | 73 | 88–95 | Add `Olivenza` (`POR`), `Plasencia`/`Trujillo`/`Mérida`, `Almería`/`Vera`/`Guadix`, `Tarifa`/`Medina Sidonia`, `Gijón`, `Siguenza`, `Lorca`, `Alcañiz`, `Balaguer`/`Urgell`, `La Palma`/`Fuerteventura` (`Canaries`). |
| **British Isles** | 77 | 92–100 | Ireland needs `Enniskillen`, `Monaghan`, `Carlow`, `Athlone`, `Maynooth`, `Belfast`/`Coleraine`, `Dundalk`; England/Wales/Scotland: `Glamorgan`/`Gower`, `Flint`, `Cornwall`/`Plymouth`, `Kent`/`Dover`, `Galloway` (`Wigtown`), `Ross`/`Caithness`. |
| **Poland-Lithuania & Russia** | 51 + 46 | 70 + 68 | Add Silesian duchies (`Cieszyn`/`Teschen`, `Oświęcim`, `Oleśnica`, `Żagań`); `Warmia` (`Heilsberg`); `Mazovia` (`Rawa`, `Ciechanów`); `Podlasie` (`Drohiczyn`); `Verkhovsky` (`Odoyev`, `Belyov`, `Vorotynsk`); `Rostov`/`Uglich`; `Novgorod` (`Toropets`, `Bezhichi`, `Ladoga`/`Kexholm`, `Arkhangelsk`/`Dvina`); `Perm` (`Cherdyn`, `Ust-Vym`). |
| **Balkans & Carpathians** | 71 + 39 | 90 + 48 | Add `Făgăraș`/`Almaș` (Wallachian fiefs in Transylvania!), `Szeklerland` (`Csík`), `Pokuttya` (`Kolomyia`), `Slavonia` (`Varaždin`), `Krk`/`Cres` (`Venice`), `Poljica`, `Prizren`/`Peć`, `Vardar`/`Yenice-i Vardar` (Evrenos seat!), `Morea` (`Kalavryta`, `Kalamata`), `Tinos`, `Phocaea`. |
| **Anatolia, Levant, Persia, Steppe** | 53+17+37+53 | 75+25+55+75 | Add `Eğil`/`Palu`/`Çemişgezek` (Kurdish emirates), `Tarsus` (`RAM`), `Divriği` (`MAM`), `Baalbek`/`Sidon`/`Nablus`/`Hebron`, `Qom`/`Saveh`/`Shahr-e Kord`, `Amol`/`Qazvin`/`Soltaniyeh`, `Quba`/`Kaitag` (`DAG`), `Svaneti`/`Abkhazia`, `Mangyshlak`/`Balkhan`, `Sibi`/`Bost`. |
| **Maghreb, Egypt & Horn** | 46+19+34 | 58+25+45 | Add `Chefchaouen`/`Rif`, `Debdou`, `M'sila`/`Tébessa`, `Taroudant`, `Rosetta`/`Mansoura`/`Qena`, `Qasr Ibrim` (`DOT`), `Shendi` (`JAA`), `Dahlak`, `Kaffa`/`Wolayta`/`Gojjam` (`ETH`). |

### 4.2 New States & Barriers Required for Expansion

If expanding to **Afro-Eurasia**, `data/map/barriers.txt` will need new major geographical dividers so province shapes respect real topography:
- **Rivers (`~`):** Yellow (Huang He), Yangtze (Chang Jiang), Pearl (Xi), Liao, Amur, Red (Hồng), Mekong, Salween, Irrawaddy, Chao Phraya; Niger, Senegal, Gambia, Volta, Congo, Ubangi, Zambezi, Limpopo, Orange; Ob, Irtysh, Yenisei, Lena.
- **Mountain Ridges (`^`):** Tibetan Plateau rims (Kunlun, Qilian, Hengduan, Tangla), Tian Shan, Altai, Greater Khingan, Qinling, Annamite Range (Trường Sơn), Tenasserim Hills, Japanese Alps; Cameroon Line, Ethiopian Highlands/Rift escarpments, Mitumba/Virunga, Drakensberg.

---

## 5. Part IV — Technical & Pipeline Checklist for the Future Commit Session

When a future session implements any part of this research, it should **not** only edit `data/map/provinces/*.txt`. Per [HANDOFF.md](HANDOFF.md#L234-L260) and the codebase search, the following files and invariants are coupled:

### 5.1 Map Resolution & Bounds Considerations
- **Constants to update together if bounding box or `PPD` changes:**
  - [tools/mapgen/mapgen.py](../tools/mapgen/mapgen.py#L42-L46) (`LON_MIN`, `LON_MAX`, `LAT_MIN`, `LAT_MAX`, `PPD`)
  - [tools/terrain/fetch_elevation.py](../tools/terrain/fetch_elevation.py#L26-L30) (`LON_MIN`, `LON_MAX`, `LAT_MIN`, `LAT_MAX`, `PPD`)
  - [tools/icon/make_icon.py](../tools/icon/make_icon.py#L28)
  - Default `map_size` fallbacks in [Map3D.gd](../godot/scripts/Map3D.gd#L20), [Main.gd](../godot/scripts/Main.gd#L208), [MapProjector.gd](../godot/scripts/MapProjector.gd#L20), [MapModels.gd](../godot/scripts/MapModels.gd#L25), and [map3d.gdshader](../godot/shaders/map3d.gdshader#L14) (note: `Main.gd` queries `getMapWidth()`/`getMapHeight()` dynamically, while `Map3D.gd` builds ~1 vertex per 6 map pixels — expanding to `5536 × 3408` at 32 PPD roughly doubles mesh vertices from ~250k to ~520k unless cell step is raised from 6 to ~8–9 on M1 8GB RAM).
- **`PPD` & Hardware Sizing for Full Afro-Eurasia (`173° × 106.5°`) on M1 8 GB RAM / M5 iPad:**
  - **Current baseline (`PPD = 32`, `3936 × 2384` = 9.38M px):** `ProvinceIDMap` is **18.8 MB** in RAM, GPU map textures total ~70 MB uncompressed, and `Map3D.gd` (`GRID_CELL_PX = 6.0`) builds ~261k vertices.
  - **`PPD = 32` (`5536 × 3408` = 18.87M px, `2.01×` current pixels):** `ProvinceIDMap` is **37.7 MB**, GPU textures ~140 MB uncompressed. Raise `GRID_CELL_PX` from `6.0` to `8.0` in [Map3D.gd](../godot/scripts/Map3D.gd#L13) to keep the 3D terrain mesh around **~296k vertices** (same GPU cost as today). Safest for M1 8 GB RAM; micro-provinces in HRE/Italy/Japan stay workable down to ~50 km (`~0.5°`).
  - **`PPD = 40` (`6920 × 4260` = 29.48M px, `3.14×` current pixels) — Optimal if adding many micro-provinces:** `ProvinceIDMap` is **59.0 MB**, GPU textures ~220 MB uncompressed, and width `6920` stays comfortably under the `8192` texture threshold. Raise `GRID_CELL_PX` from `6.0` to `10.0` (`~296k` vertices) so 3D GPU cost stays flat, while giving HRE, Italian, Irish, and Japanese micro-provinces ~56% more pixels so small borders stay crisp and clickable.
  - **`PPD = 48` (`8304 × 5112` = 42.45M px, `4.52×` current pixels) — Chosen Target:** Width `8304` exceeds `8192` (fine on Apple Silicon Metal `16384` max texture size, though future session must verify M5 iPad / cross-platform GPU limits or split/downsample `terrain.jpg`/`height.png` if needed). Uncompressed map textures total ~330–360 MB in unified memory (`ProvinceIDMap` = 84.9 MB). Raise `GRID_CELL_PX` from `6.0` to **`12.0`** in [Map3D.gd](../godot/scripts/Map3D.gd#L13) (`692 × 426` = **~296k vertices**) to keep 3D terrain mesh vertex count identical to today, and budget longer `mapgen.py` / `bake_terrain.py` build times (~4.5×). Gives ultra-crisp borders down to ~25–30 km (`~0.25°`) for HRE, Italian, Irish, and Japanese micro-provinces.
  - **Simulation CPU budget:** Doubling to ~2,800–3,500 provinces and ~450–550 countries roughly doubles daily/monthly tick work (~3.1 ms/day today → ~6–8 ms/day), so monthly AI trade/diplomacy checks may benefit from staggering across days if Speed 5 slows on M1.
- **`ProvinceIDMap` capacity:** [ProvinceIDMap.swift](../Packages/GezCore/Sources/GezCore/World/ProvinceIDMap.swift#L9-L11) uses `UInt16`, supporting up to **65,533** provinces cleanly without changing binary `.idmap` format.

### 5.2 Data Files & Generator Order for the Future Session
1. **Map source edits:**
   - `data/map/countries.txt`, `data/map/subjects.txt`, `data/map/provinces/*.txt`, `data/map/pops/*.txt`, `data/map/population_1453.txt`, `data/map/cultures.txt`, `data/map/lakes.txt`, `data/map/seas.txt`, `data/map/barriers.txt`, `data/map/slavery.txt`.
   - New religions/families (owner chose **granular faiths**: add `confucian`, `daoist`, `mahayana`, `shinto`, and split African/Siberian/SE Asian indigenous traditions in `Religion.swift` and `mapgen.py` `RELIGIONS`).
2. **Downstream data that references province/country names (must be checked after renames/splits/expansions):**
   - `data/economy/` (`markets.txt`, `resources.txt`, `buildings_1453.txt`, `routes_1453.txt`)
   - `data/characters/` (`people_*.txt` — especially `holds:` province lists and new tags!)
   - `data/government/` (`laws_1453.txt`, etc.)
   - `data/military/` & `data/navy/` (`armies_1453.txt`, `fleets_1453.txt`)
   - `data/diplomacy/` (`treaties_1453.txt`, `wars_1453.txt`)
   - `data/calamity/fault_zones.txt`, `data/technology/`, `data/events/*.txt`, `data/ai/goals_1453.txt`, `data/faith/holy_sites.txt`, `data/heraldry/choices.txt`
3. **Generator run order:**
   - `fetch_coastlines.sh` -> `mapgen.py` -> (`fetch_elevation.py` via CI if bounds changed) -> `bake_terrain.py` -> `bake_heightmap.py` -> `econgen.py` -> `chargen.py` -> `govgen.py` -> `milgen.py` -> `navgen.py` -> `dipgen.py` -> `calamitygen.py` -> `techgen.py` -> `eventgen.py` -> `aigen.py` -> `make_icon.py`.

### 5.3 Owner Decisions Locked In (22 Nov 2026)

1. **Expansion Scope:** **Full Afro-Eurasia** (`LON -25..148, LAT -35..71.5`) — adds East Asia, Southeast Asia, Siberia, and Sub-Saharan Africa + Madagascar.
2. **Formables Architecture:** **In-place tag transformation** (keeps `CountryTable` fixed for save safety, swapping name, colour, heraldry, reforms, and mission tree), supporting historical, alt-history, and broad sandbox unions.
3. **Religions (`Religion.swift`):** **Granular faiths** — add `confucian`, `daoist`, `mahayana`, `shinto`, and split African, Siberian, and Southeast Asian indigenous traditions.
4. **Yemen on 30 May 1453:** **Split** between collapsing **Rasulids** (`Zabid`, `Taizz`, `Jizan`) and rising **Tahirids** (`Aden`, `Lahij`).
5. **HRE & Swiss Borders:** **Full historical split** — `Metz`, `Besancon`, and `Basel` as Free Imperial Cities, Further Austria (`Ensisheim`, `Freiburg`) under Archduke Albert VI, and `St. Gallen` / `Valais` as Swiss associates.
6. **Map Resolution (`PPD`):** **`PPD = 48`** (`8304 × 5112` px for Full Afro-Eurasia), paired with `GRID_CELL_PX = 12.0` in [Map3D.gd](../godot/scripts/Map3D.gd#L13) to keep 3D mesh vertices flat (~296k) and texture/RAM checks on M1 8 GB.

---

## 6. Part V — Governance & Flavour Baseline

Right now, Gez models every country through:
- **5 Government Types** ([reforms.txt](../data/government/reforms.txt)): `monarchy`, `republic`, `theocracy`, `steppeHorde`, `tribal` (each with a 4-tier reform tree).
- **4 Core + 5 Regional Estates** ([estates.txt](../data/government/estates.txt)): `nobles`, `clergy`, `burghers`, `peasants`, plus `janissaries` (`TUR`), `mamluks` (`MAM`), `rajputs` (Indian Rajput pops), `tribes`, and `dhimmi`.
- **11 Law Areas** ([laws.txt](../data/government/laws.txt)): succession, crown authority, taxation, army, religious policy, trade, justice, peasants/land, towns, learning, coinage.
- **23 Estate Privileges** ([privileges.txt](../data/government/privileges.txt)) and **Internal Great Vassals** (`holds:` in `data/characters/`).

Where Gez is currently thin is **regional institutional flavour**: an HRE prince-bishopric, Ashikaga Japan, Ming China, and the Kingdom of France all use nearly the same generic laws and reforms, and there are **no dynamic formable nations** yet.

---

## 7. Part VI — Historical Ways of Governing & Regional Flavour

Each system below can be built at two depths:
- **Light (Data-only):** New government reforms, regional estates, estate privileges, laws, and event chains using existing Gez mechanics.
- **Deep (Bespoke Systems):** Dedicated diplomatic/institutional mechanics (e.g., HRE Imperial Diet, Shogunate, Mandate of Heaven).

### 7.1 The Holy Roman Empire (HRE)
In May 1453, **Frederick III** (`HAB`, Inner Austria) is Holy Roman Emperor (crowned in Rome in 1452 — the last emperor crowned there!). The Empire is *not* a centralized state; it is a constitutional web of Electors, Princes, Prince-Bishops, and Free Imperial Cities.
- **Core Mechanics to Consider:**
  - **The 7 Prince-Electors (1453):** 3 spiritual (**Mainz**, **Trier**, **Cologne**) + 4 secular (**Bohemia**, **Palatinate**, **Saxony**, **Brandenburg**). When the Emperor dies, Electors vote based on opinion, dynasty, religion, and diplomatic skill (or bribery).
  - **Imperial Authority & Reichstag Reforms:** Gained from internal peace, defending Imperial land from outsiders (France, Burgundy, Ottomans, Denmark), and religious unity; lost when princes annex each other without claims or when non-HRE powers hold Imperial provinces. Reforms can progress from *Ewiger Landfriede* (banning internal HRE wars) and *Reichskammergericht* (court/stability) up to *Privilegium de Non Appellando* or hereditary centralization (*Erbreich*).
  - **Free Imperial Cities (`city_league`):** `Frankfurt`, `Nuremberg`, `Ulm`, `Augsburg`, `Hamburg`, `Lubeck`, `Strasbourg` (plus `Metz`, `Besancon`, `Basel` if added) get high trade/burgher bonuses and Emperor protection against annexation, in exchange for **Imperial Taxes (*Römermonate*)**.
  - **Imperial Circles & Religious Wars (1517+):** Once Gez's Reformation spawns in Mainz/Wittenberg, Catholic vs. Protestant/Reformed leagues can contest the Empire's official faith (Peace of Augsburg / Thirty Years' War).
- **Light Flavour Additions:** New HRE privileges (`Imperial Immediacy`, `Golden Bull Electorate`, `Hanseatic Kontor Charter`), Tier-1/2 reforms (`Electoral Principality`, `Imperial Free City`), and events for the **Reichsreform** (1495).

### 7.2 Ashikaga Japan (Shogunate & *Bakufu* Governance)
In 1453, **Ashikaga Yoshimasa** is Shōgun in Kyoto, **Emperor Go-Hanazono** sits on the Chrysanthemum Throne (symbolic sovereignty without military power), and the *Muromachi Bakufu* governs through powerful **Kanrei** (deputies: Hosokawa, Shiba, Hatakeyama) and **Shugo** (military governors).
- **Two Ways to Model Japan in Gez:**
  1. **Kyoto *Bakufu* + *Shugo* Vassal Swarm (EU-style):** `ASH` (Ashikaga Shogunate) holds Kyoto/Yamashiro + core domains; major *shugo* (`Hosokawa`, `Yamana`, `Ōuchi`, `Shimazu`, `Uesugi`, `Hatakeyama`, `Shiba`, `Ōtomo`, `Takeda`, `Date`) are `shugo_vassal` subjects. When Shogun authority drops (or during the **1467 Ōnin War** event), *shugo* become *sengoku daimyō* who can fight one another without breaking away from the Emperor's nominal realm until someone marches on Kyoto to claim the Shogunate.
  2. **Unified Shogunate + CK3-style *Shugo* Great Vassals:** Keep Japan as one tag (`ASH`) with `holds:` great vassals, and use a **Bakufu Authority / Gekokujō** disaster to spawn independent *daimyō* civil-war tags if authority collapses.
- **Unique Japanese Flavour:**
  - **Estates & Privileges:** **Samurai / Bushi** estate (replacing generic `nobles`, or `bushi` privilege `Kokujin Land Rights`), **Buddhist Monasteries (*Sōhei* / Enryaku-ji)** (`clergy` with militant levy bonus and high autonomy!), **Za Merchant Guilds** (`burghers`), and **Kugyō** (Kyoto court nobility).
  - **Unique Laws & Reforms:** `Buke Shohatto` (military-house rules), `Kandaka / Kokudaka` land-tax assessment, `Tansen / Munabechisen` extraordinary levies, `Sankin-kōtai` (hostage-attendance system once centralized), and **Nanban Trade / Sakoku** choices in the 1540s+.
  - **Historical Flashpoints (1453+):** **Kyōtoku Incident (1454–1455)** in the Kantō (*Kamakura Kubō* vs. Uesugi), **Hatakeyama succession crisis (1454)**, **Ōnin War (1467–1477)**, **Ikkō-ikki** peasant-monastic uprisings, **Takeda–Uesugi** rivalries, **Oda Nobunaga's** unification.

### 7.3 Ming China & the East Asian Tributary Order
In May 1453, China is ruled by the **Jingtai Emperor (Zhu Qiyu)** in the tense aftermath of the **1449 Tumu Crisis**, while his captive-turned-returned brother (the former Zhengtong Emperor) is under house arrest in Beijing (until the 1457 Restoration coup!).
- **Core Governance Mechanics:**
  - **Mandate of Heaven / Celestial Legitimacy:** Tied to stability, low devastation, treasury health, border security against northern nomads (Oirats/Jurchens), and disaster avoidance (floods of the Yellow River, peasant rebellions). Low Mandate triggers famine/rebel waves and a dynastic crisis.
  - **Ming *Neige* (Grand Secretariat) & Court Factions:** Instead of feudal nobles, Ming China has **Scholar-Officials (*Literati / Jinshi*)** (scaled by `learning` + `burghers`/`clergy`), **Imperial Eunuchs (*Dongchang* / Inner Court)** (high `crown_power` + espionage, huge corruption/stability risk), and **Military Garrisons (*Weisuo*)** (hereditary military households).
  - **Tributary Empire (*Chaogong*):** Neighboring realms (**Joseon Korea**, **Ryukyu**, **Dai Viet**, **Ayutthaya**, **Malacca**, **Hami**, **Jurchen tribes**) pay symbolic tribute to Ming in exchange for **Ming protection** and access to lucrative **tributary trade permits (*Kanhe*)** (boosting Gez's trade routes!).
  - **Laws & Reforms:** `Imperial Examinations (Keju)`, `Haijin (Maritime Ban)` vs. `Open Maritime Trade` (Silver/Manila trade shift), `Single Whip Tax Reform` (1500s silver tax boost), `Lijia` rural registration, and **Tusi** autonomy in the southwest.

### 7.4 Joseon Korea & Tibet
- **Joseon Korea:** **Yangban** literati-aristocracy (`nobles` + `learning` focus), **Censorate (*Samsa*)** (limits `crown_power` but lowers corruption/inflation), **Six Ministries**, **Hangeul** promotion (just promulgated 1446 under Sejong!), and the **1453 *Gyeyu Jeongnan*** coup event (Grand Prince Suyang vs. young King Danjong).
- **Tibet:** **Monastic Patron-Priest (*Chöyön*)** governance (`theocracy` / monastic estates of Gelug, Sakya, Kagyu orders), where secular houses (Phagmodrupa, Rinpungpa) compete for monastic backing and Mongol/Ming patronage.

### 7.5 Western & Central Europe
- **France:** **Compagnies d'Ordonnance**, **Parlements** (judicial privileges vs. royal centralization), **Estates-General**, **Gallican Church** (Pragmatic Sanction of Bourges 1438 — `clergy` loyalty + reduced Papal tax drain), **Appanage Management** (turning internal `holds:` duchies like Bourbon/Orléans/Anjou into royal domain).
- **England:** **Parliament & Magna Carta** (`parliamentary` reform, war-tax approval tied to stability), **Lancaster vs. York Factionalism** (1453 is the exact eve of Henry VI's mental collapse in August 1453 and the **Wars of the Roses**!), **Wool Staple (Calais)** trade privilege.
- **Iberia (Castile, Aragon, Portugal, Granada, Navarre):** **Hermandades** (municipal peacekeeping leagues), **Mesta** (Castilian sheep-grazing guild — huge wool output vs. farmland penalty!), **Cortes of Aragon** (pactism / strong regional *fueros*), **Portuguese Casa da Índia / Sagres Navigation** (exploration/trade range & caravel bonuses), **Granadan *Thaghr*** (frontier fort defence + Silk/Alpujarras tax).
- **Italian City-States & Papacy:** **Condottieri Contracts** (mercenary captain loyalty/betrayal risk), **Signoria vs. Republican Great Council** (Medici banking patronage vs. Venetian *Consiglio dei Dieci* / *Serenissima*), **Papal Curia / Nepotism** (cardinal politics, Papal Bulls, Crusade calls).

### 7.6 Eastern Europe & Steppe
- **Poland & Lithuania:** **Sejm & *Nihil Novi* / Golden Liberty** (huge `nobles` power + `manpower`/`cavalry` bonuses, at the cost of `crown_power` and elective monarchy traps), **Zaporozhian Cossacks** (emerge late 15th–16th c. as a Steppe frontier estate/privilege!).
- **Muscovy / Russia:** **Prikazy** (centralized chancelleries), **Mestnichestvo** (noble precedence — loyalty vs. army quality), **Pomestie** (service-land cavalry estates), **Oprichnina** (1560s crisis/reform), **Veche Republic** (`NOV`, `PSK` — merchant-boyar assembly).
- **Steppe Hordes (`CRI`, `GRH`, `KAZ`, `NOG`, `UZB`, `MGH`, `OIR`):** **Yasa vs. Sharia** tension (steppe tribal law vs. Islamic settled governance), **Kurultai** succession crises (Chinggisid bloodline requirement — directly relevant to Esen Taishi's 1453–1455 downfall!), **Raiding Economy** (loot/slaves for steppe armies vs. low urban tax).

### 7.7 Islamic World (Ottomans, Mamluks, Persia, Arabia)
- **Ottomans (`TUR`):** Already has `janissaries` and `dhimmi`! Can deepen with **Devshirme & Timar System** (cavalry land grants tied to `army` vs. `tax`), **Fratricide / Kafes** succession law (prevents pretender splits at a stability/kin cost), **Enderun Palace School**, **Kapudan Pasha** naval reform, and **Millet** communal autonomy.
- **Mamluks (`MAM`):** **Royal Mamluks vs. *Awlad al-Nas***, **Iqta** rotation (prevents hereditary feudal breakaway but hurts long-term provincial development), **Burji Circassian Succession** (faction clashes between *ashraf*, *zahiri*, and *inali* households on every Sultan's death).
- **Persia / Turkmen (`QAR`, `AKK`, `TIM`, `HRT`, `SHI`):** **Soyurghal / Tiul** hereditary military grants, **Tajik (Persian) Bureaucracy vs. Turk (Nomad) Sword** dual-estate balance (essential for Qara Qoyunlu, Aq Qoyunlu, Timurids, and later Safavids!), **Sufi Order Patronage** (Safaviyya, Naqshbandiyya, Kubrawiyya — linking directly to Gez's existing Sufi order data!).

### 7.8 Indian Subcontinent
- **Delhi / Deccan Sultanates:** **Iqta & Amirs of Sadah** (turbulent Afghan/Turkic clan nobles under Lodi), **Deccani vs. Afaqi (Westerner)** faction rivalry in **Bahmani** (historically tore Bahmani apart in the 1480s!).
- **Vijayanagara & Hindu Kingdoms:** **Amara-Nayaka System** (military governors holding provinces in exchange for troops and tribute — works wonderfully with Gez's great-vassal mechanic!), **Temple Patronage & Mathas**, **Rajput *Watan Jagir* & *Jauhar* / Fort-Holders** (`rajputs` estate already exists!).

### 7.9 Sub-Saharan Africa & Southeast Asia
- **Ethiopia (`ETH`):** **Ketema (Mobile Royal Capital)** & **Chewa** military colonies (already started in `HISTORY_NOTES.md`), **Gult** tribute grants, **Solomonic Monastic Councils** (Zara Yaqob's religious centralization).
- **West Africa (`MAL`, `SON`, `KBO`, `BEN`):** **Mansa / Askia Trans-Saharan Salt–Gold Monopoly**, **Horon vs. Nyamakala** caste/craft guilds, **Benin Palace Guilds (Iwebo/Ibiwe)**, **Kongo *Mwene* Provincial Governors**.
- **Southeast Asia (`AVA`, `PEG`, `AYU`, `DAI`, `MLC`, `MAJ`):** **Mandala Polity** (power radiates from the capital; outer provinces/vassals pay tribute based on ruler prestige & army strength rather than rigid borders), **Sakdina** social-rank system (`AYU`), **Laksamana & Syahbandar** maritime harbor-masters (`MLC` — boosts trade & naval capacity), **Confucian Mandarinat** (`DAI` under Lê dynasty).

---

## 8. Part VII — Historical Formable Nations Catalog

> [!NOTE]
> Gez currently keeps `CountryTable` fixed-length at start ([HISTORY_NOTES.md](HISTORY_NOTES.md#L469)). Implementing formables in a future session can work either by **renaming/re-colouring/re-flagging an existing country tag + switching its mission/reform tier**, or by **adding dormant formable tags** at scenario load.

### 8.1 Western, Northern & Central Europe

| Formable | Historical Basis | Eligible 1453 Tags | Core Requirements (Summary) | Reward / Flavour |
|---|---|---|---|---|
| **Spain** (`SPA`) | Catholic Monarchs' union (1479) & crowns | `CAS`, `ARA`, `NAV`, `POR` (Iberian) | Control Toledo, Madrid, Seville, Zaragoza, Valencia, Barcelona (Granada optional/bonus) | Union/centralization reforms, Iberian trade & colonial/naval buffs |
| **Great Britain** (`GBR`) | Union of Crowns (1603) / Acts of Union (1707) | `ENG`, `SCO`, `WLS` | Control London, York, Edinburgh, Glasgow, Cardiff | Parliamentary/maritime naval doctrine, British culture unification |
| **Angevin Kingdom / Dual Monarchy** | Henry VI's 1422–1453 claim to both crowns | `ENG` (if holding Paris) or `FRA` (holding London) | Hold both London and Paris + Normandy/Guyenne | Alt-history Franco-English union crown & dual accepted cultures |
| **Netherlands / United Provinces** (`NED`) | Dutch Revolt / Union of Utrecht (1579) | `UTR`, `GEL`, `FRI`, `BUR` (Dutch/Flemish) | Control Amsterdam, The Hague, Antwerp, Ghent, Utrecht, Leeuwarden | `Merchant Republic` / `Stadtholder` reform, massive trade & naval boost |
| **Lotharingia** (`LOT`) | Charles the Bold's 1473 royal ambition | `BUR`, `LOR`, `BAR`, `LUX` | Control Dijon, Brussels, Antwerp, Nancy, Metz, Besançon | Elevates Burgundy/Lorraine to a Kingdom bridging France & the HRE |
| **Kingdom of Germany / Holy Roman Empire (Unified)** (`GER` / `HRE`) | German unification / *Renovatio Imperii* | Any German culture state / HRE Emperor | Control Cologne, Frankfurt, Nuremberg, Munich, Berlin, Vienna, Hamburg (or pass final Imperial reform) | Abolishes HRE fragmentation, massive administrative & military buffs |
| **Prussia** (`PRU`) | Secularization of Teutonic Prussia (1525) + Brandenburg union (1618) | `TEU`, `BRA` | Protestant/Reformed (or secularized), control Königsberg, Marienburg, Berlin | `Prussian Military Households` reform, elite standing-army discipline |
| **Kingdom of Italy** (`ITA`) | Renaissance/Napoleonic Italian Kingdom | Any Italian-culture state (except `PAP`? or `PAP` -> Kingdom of God) | Control Milan, Venice, Florence, Genoa, Rome (or Bologna/Naples) | Italian cultural union, university/Renaissance & trade buffs |
| **Two Sicilies** (`TTS`) | Union of Naples and Sicily | `NAP`, `ARA` (if releasing/moving capital) | Control Naples, Palermo, Messina, Bari | Mediterranean naval & southern agricultural centralization |
| **Old Swiss Confederacy -> Helvetia** (`SWI`) | 13-Canton Confederacy (1513) | `SWI`, `GRI` | Control Zurich, Bern, Lucerne, Basel, Geneva, Sion, Chur | Neutrality/mountain defence & elite pike mercenary bonuses |
| **Scandinavia / Kalmar Empire** (`SCA`) | Permanent consolidation of the Kalmar Union | `DAN`, `SWE`, `NOR` | Control Copenhagen, Stockholm, Oslo, Lund, Bergen, Kalmar | Nordic cultural union, Baltic trade Sound Toll mastery |
| **Ireland** (`IRE`) | High Kingship / Kingdom of Ireland | Any Irish lordship (`TYR`, `TYC`, `DES`, `ORM`, `KID`, `LEI`, `TMN`, `CLA`) | Control Dublin, Kilkenny, Cork, Galway, Dungannon | Unifies Gaelic & Anglo-Irish lordships into a recognized Kingdom |
| **Wales** (`WLS`) | Principality of Owain Glyndŵr restored | Released Welsh state or Cornwall/Breton | Control Caernarfon, Cardiff, Pembroke, Brecon | Celtic revival, longbow/hill defence flavour |
| **Celtic Union / Alba–Éire** (`CEL`) | Sandbox pan-Celtic union | `SCO`, `IRE`, `BRI`, `WLS`, `LOI`, Irish tags | Control Edinburgh, Dublin, Cardiff, Nantes/Rennes | Gaelic–Brythonic naval/highland confederation |
| **North Sea Empire** (`NSE`) | Cnut's Anglo-Nordic thalassocracy | `DAN`, `NOR`, `ENG`, `SCO` | Control London, Copenhagen, Oslo, York, Bergen | North Sea maritime trade & amphibious hegemony |
| **Danubian Crown / Austria–Hungary** (`AUH`) | Habsburg Central European union (1526+) | `AUS`, `HAB`, `HUN`, `BOH` | Control Vienna, Graz, Buda, Prague, Pozsony | Multi-ethnic *Dual/Triple Monarchy* estate tolerance & anti-Ottoman frontier |

### 8.2 Eastern Europe, Balkans & Caucasus

| Formable | Historical Basis | Eligible 1453 Tags | Core Requirements (Summary) | Reward / Flavour |
|---|---|---|---|---|
| **Polish–Lithuanian Commonwealth** (`PLC`) | Union of Lublin (1569) | `POL`, `LIT` | Control Krakow, Warsaw, Vilnius, Lwow, Danzig, Smolensk | Dual-crown *Sejm* reform, winged hussar cavalry & multi-faith tolerance |
| **Courland** (`KUR`) | Secularization of Livonian Order (1561) | `LVO`, `RIG` | Reformation active, control Mitau, Goldingen, Riga | Secular duchy transition, Baltic maritime trade focus |
| **Tsardom of Russia** (`RUS`) | Ivan III / Ivan IV centralization (1547) | `MOS`, `NOV`, `TVE`, `RYA`, `YAR`, `PSK`, `OKA` | Control Moscow, Novgorod, Vladimir, Tver, Ryazan, Smolensk | `Tsardom` rank, *Pomestie* & *Prikazy* reforms, steppe/Siberian frontier expansion |
| **Ruthenia** (`RUT`) | Grand Duchy of Rus' (Treaty of Hadiach 1658 concept) | `LIT` (Ruthenian shift), released Kiev/Smolensk | Ruthenian majority, control Kiev, Lwow, Chernigov, Smolensk | Eastern Slavic Orthodox kingdom rivaling Moscow & Poland |
| **Byzantine / Eastern Roman Empire** (`BYZ`) | Restoration after 29 May 1453 | `MOE`, `TRE`, `THE`, `ATH` (Greek/Orthodox) | Control Konstantiniyye, Edirne, Thessaloniki, Mystras | Imperial *Despotate* restoration, Orthodox Patriarchate, claims on Balkans & Anatolia |
| **Roman Empire (Restored)** (`ROM_E`) | Sandbox *Renovatio Imperii* | `BYZ`, `ITA`, `PAP`, `FRA`, `SPA`, `HRE` | Control Rome, Constantinople, Paris, Toledo, Alexandria, Antioch, Vienna | Ultimate endgame Mediterranean imperial restoration |
| **Latin Empire (Empire of Romania)** (`LAT`) | Crusader state restoration (1204–1261) | `VEN`, `NAX`, `ATH`, `KNI`, `CYP`, `NAP` | Catholic, control Konstantiniyye, Thessaloniki, Athens, Negroponte | Catholic Crusader Aegean-Thracian maritime empire |
| **Romania** (`ROM`) | Michael the Brave's 1600 union | `WAL`, `MOL` | Control Targoviste, Bucharest, Suceava, Iasi, Kolozsvar | Danubian unification, Carpathian defence & anti-Ottoman/Hungarian standing |
| **Illyria / South Slavic Union** (`ILY`) | Serbian Empire / Bosnian-Croatian union | `SER`, `BOS`, `HER`, `ZET`, `RAG`, `CRO` | Control Belgrade, Smederevo, Jajce, Zagreb, Dubrovnik | Balkan Slavic consolidation & mining wealth |
| **Kingdom of Georgia (Restored)** (`GEO`) | Re-unification of Georgia | `SAM`, `GEO` (if fractured) | Control Tbilisi, Kutaisi, Akhaltsikhe, Telavi | Caucasian mountain fortification & Bagrationi legitimacy |
| **Armenia (Greater Armenia)** (`ARM`) | Bagratid / Cilician restoration | Released Armenian state or `TRE`/Caucasus shift | Armenian majority/rule, control Yerevan, Kars, Van, Sis | Highland fortresses & Silk Road Armenian merchant diaspora |

### 8.3 Middle East, Persia, Central Asia & Steppe

| Formable | Historical Basis | Eligible 1453 Tags | Core Requirements (Summary) | Reward / Flavour |
|---|---|---|---|---|
| **Persia / Iran (Safavid or Eranshahr)** (`PER`) | Ismail I's 1501 reunification | `QAR`, `AKK`, `GIL`, `MZD`, `LUR`, `MSH`, `SIS`, `LAR`, `SHI`, `BIT`, `TIM`, `HRT` | Control Tabriz, Isfahan, Shiraz, Ray/Qazvin, Herat or Baghdad | Persianate *Diwan* empire; if `twelver`, Qizilbash cavalry; if `zoroastrian`, *Eranshahr* |
| **Sultanate of Rum (Restored)** (`RUM`) | Seljuk Anatolian legacy | Anatolian beyliks (`KAR`, `CND`, `DUL`, `RAM`) if `TUR` falls | Control Konstantiniyye or Konya, Ankara, Bursa, Kayseri, Sivas | Replaces Ottoman hegemony with Seljuk-style Anatolian Empire |
| **Mughal Empire (Gurkani)** (`MUG`) | Babur's 1526 conquest from Kabul | `TIM`, `HRT`, `BDK` (or Afghan/Timurid splinter) | Control Kabul, Lahore, Delhi, Agra | Timurid-Persian-Indian synthesis, *Mansabdari* & gunpowder artillery bonuses |
| **Timurid Empire (Restored)** (`TIM`) | Reuniting Timur's realm (Samarkand + Herat + Persia) | `TIM`, `HRT` | Control Samarkand, Herat, Balkh, Tabriz, Shiraz | Timurid Renaissance patronage & nomadic-settled *diwan* army |
| **Turan / Turkestan** (`TRN`) | Sandbox pan-Turkic / Transoxiana–Steppe union | `UZB`, `TKM`, `KAZ`, `KZK`, `NOG`, `MGH` | Control Samarkand, Bukhara, Urgench, Sighnaq, Merv | Silk Road oasis & steppe cavalry union |
| **Arabia / Caliphate** (`ARB`) | Pan-Arab / Hejazi–Najdi–Levantine unification | Arab culture realms (`MAM` Arabized, `HEJ`, `JAB`, `TAH`, `ZAY`, `OMN`, `SHM`, `NJD`) | Control Mecca, Medina, Damascus, Cairo, Baghdad, Sanaa | Red Sea–Gulf trade dominance & desert logistics |
| **Egypt–Syria (Ayyubid Restoration)** (`AYY`) | Kurdish/Syrian Saladin legacy | `HAS` (Hasankeyf Ayyubids!) or Levant/Kurdish realms | Control Cairo, Damascus, Aleppo, Jerusalem, Hasankeyf | Restores Ayyubid Syro-Egyptian sultanate |
| **Al-Andalus** (`ADU`) | Nasrid / Andalusi reconquest of Iberia | `GRA`, `MOR`, `TLE`, `HIN` | Control Granada, Seville, Cordoba, Toledo, Lisbon | Andalusi learning/architecture golden age & religious toleration mechanics |
| **Maghreb / Almohad Caliphate** (`MGB`) | Re-uniting Morocco, Tlemcen, Tunis | `MOR`, `HIN`, `TLE`, `TUN`, `TGT`, `SUS` | Control Fez, Marrakesh, Tlemcen, Tunis, Bejaia | Trans-Saharan & Western Mediterranean corsair/trade empire |
| **Great Yuan / Mongol Khaganate** (`YUA`) | Esen Taishi's 1453 gamble / Dayan Khan's restoration | `OIR`, `MGH`, `UZB`, `GRH`, `CRI`, `KAZ`, `NOG` | Control Karakorum + Beijing (for Great Yuan) OR Saray + Samarkand + Karakorum (Mongol Empire) | Restores Chinggisid universal empire & massive cavalry horde |
| **Golden Horde (Restored)** (`GLH`) | Re-uniting the Ulus of Jochi | `GRH`, `CRI`, `KAZ`, `NOG`, `UZB`, `AST`, `SIB` | Control Saray, Astrakhan, Kazan, Qirq Yer, Saraychik | Reverses the 15th-century fragmentation of the Jochid steppe |
| **Kazakh Khanate** (`KZK`) | Kerei & Janibek's 1465 secession from Abu'l-Khayr | `UZB` / Kazakh steppe splinters | Control Sighnaq, Yasi, Ulytau, Almaty | Steppe confederation uniting the Three Jüzes |

### 8.4 India & Africa

| Formable | Historical Basis | Eligible 1453 Tags | Core Requirements (Summary) | Reward / Flavour |
|---|---|---|---|---|
| **Hindustan** (`HND`) | Indo-Islamic Sultanate unifying northern/all India | `DEL`, `JNP`, `BNG`, `GUJ`, `MLW`, `BAH`, `MUL`, `SND`, `KSH`, `KHA` | Control Delhi, Lahore, Jaunpur, Gaur, Ahmedabad, Bidar | Imperial Islamic-Indian bureaucracy & Dhimmi/Rajput integration |
| **Bharat / Chakravartin** (`BHA`) | Dharmic pan-Indian empire | `VIJ`, `ORI`, `MEW`, `MAR`, `GWA`, `NEP`, `AHO`, `GON`, `CLT`, `KOT` | Control Delhi, Vijayanagara, Cuttack, Kanchipuram, Chittor, Gaur | Pan-Indian Dharmic cultural union & temple-economy buffs |
| **Deccan Sultanate / Maratha–Deccan Union** (`DEC`) | Unifying the Five Deccan Sultanates | `BAH`, `KHA`, `GUJ` | Control Bidar, Golconda, Bijapur, Daulatabad, Ellichpur | Unites Deccan trade, diamond mines & Afaqi/Deccani elite |
| **Rajputana** (`RJP_F`) | Rana Sanga's Rajput confederacy (1508–1527) | `MEW`, `MAR`, `AMB`, `JSL`, `BUN`, `DGP`, `SRH`, `KRL` | Control Chittor, Mandore, Ajmer, Amber, Ranthambore | Unified Rajput martial confederacy & desert/fort warfare bonuses |
| **Maratha Empire** (`MAR_F`) | Shivaji's Deccan uprising (1674) | Marathi-culture realm (`BAH` splinter / Deccan Hindu revolt) | Control Pune, Satara, Daulatabad, Chaul, Kolhapur | Guerilla hill-warfare & light-cavalry raids (*Chauth*) |
| **Nubia (United)** (`NUB`) | Reuniting Makuria/Dotawo & Alodia (or Funj Sennar) | `DOT`, `ALO`, `JAA`, `BEJ` | Control Dongola, Soba, Sennar, Suakin | Nile trade control & Christian/Islamic Nubian synthesis |
| **Horn / Empire of Axum** (`AXM`) | Expanded Solomonic or Adalite Horn hegemony | `ETH`, `ADA`, `AJU` | Control Aksum, Debre Berhan, Harar, Zeila, Mogadishu | Red Sea & Indian Ocean spice/ivory gatekeeper |
| **Mali / Songhai Hegemony (Western Sudan)** (`WSA`) | Imperial West Africa | `MAL`, `SON`, `JOL`, `KNO`, `KBO` | Control Timbuktu, Gao, Niani, Kano, Bornu | Trans-Saharan gold & Timbuktu scholarship supremacy |
| **Empire of Zimbabwe (Rozwi/Great Mutapa)** (`ZIM`) | Full Mutapa–Butua–Sofala consolidation | `MTP`, `KIL` (or Butua) | Control Great Zimbabwe, Khami, Sena, Sofala | Gold-mining boom & Indian Ocean trade monopoly |
| **Swahili Thalassocracy (Kilwa–Zanj)** (`SWA`) | Unified Swahili coastal trading empire | `KIL`, `PTE`, `MGD` | Control Kilwa, Mombasa, Malindi, Pate, Mogadishu, Sofala | Indian Ocean monsoon trade & naval supremacy |

### 8.5 East & Southeast Asia (With Expanded Map)

| Formable | Historical Basis | Eligible 1453 Tags | Core Requirements (Summary) | Reward / Flavour |
|---|---|---|---|---|
| **Empire of Japan (Unified Shogunate / Imperial)** (`JPN`) | Nobunaga–Hideyoshi–Tokugawa unification (1590–1603) | `ASH` or any Japanese *shugo*/*daimyō* | Control Kyoto + 75%+ of Honshu/Kyushu/Shikoku | Ends Sengoku wars, unlocks `Sakoku` vs. `Open Ports` & centralized *Bakufu* |
| **Later Jin / Qing** (`QNG`) | Nurhaci's Jurchen unification (1616) -> 1644 | Jurchen tribes (`Jianzhou`, `Haixi`, `Wild Jurchens`) | Unite Manchuria (+ Beijing for Qing) | Eight Banners military system & Chinese/Steppe dual administration |
| **Great Tibet** (`TIB`) | 5th Dalai Lama / Ganden Phodrang unification (1642) | `PHA`, `RIN`, `GUG`, `LDK`, Kham/Amdo | Control Lhasa, Shigatse, Tsaparang, Ladakh, Derge | Monastic *Chöyön* unification & Himalayan defence |
| **Toungoo / Burma** (`BRM`) | Tabinshwehti & Bayinnaung (1530s–1550s) | `AVA`, `PEG`, `ARK`, Shan states | Control Ava, Pegu, Toungoo, Prome, Martaban | Massive SE Asian levy/elephant empire |
| **Siam (Rattanakosin / Thonburi)** (`SIA`) | Reunified Siam after Ayutthaya | `AYU`, `LNA` | Control Ayutthaya, Chiang Mai, Phitsanulok, Ligor | Bureaucratic *Sakdina* state & Gulf of Siam trade hub |
| **Dai Nam / Vietnam** (`VIE`) | Lê Thánh Tông & Nguyễn southern expansion | `DAI`, `CHA` | Control Thang Long, Hue, Vijaya, Mekong Delta | Confucian bureaucracy & maritime/delta expansion |
| **Nusantara (Majapahit Restored)** (`NUS`) | Gajah Mada's *Sumpah Palapa* archipelago ideal | `MAJ`, `SUN`, `MLC`, `PSA`, `BRU` | Control Trowulan, Malacca, Pasai, Palembang, Brunei, Makassar | Spice monopoly & unmatched maritime trade network |
| **Malaya / Srivijaya Restored** (`MLY`) | Malay Peninsula + Sumatra maritime thalassocracy | `MLC`, `PSA`, Siak, Palembang | Control Malacca, Pasai, Palembang, Pahang, Kedah | Strait of Malacca toll empire & *Orang Laut* navy |

---

## 9. Part VIII — Locked-In Owner Decisions Summary

The owner decided the following design direction for future sessions:

1. **Holy Roman Empire (HRE):** **Full Imperial mechanics** — 7 Electors voting on Emperor death, Imperial Authority, Reichstag reforms, Free Imperial Cities (`city_league`), and Reformation religious leagues (linking with Gez's existing 1517+ Reformation system).
2. **Ashikaga Japan:** **Shogunate vassal swarm** — `ASH` holds Kyoto/Yamashiro while major *shugo* (`Hosokawa`, `Yamana`, `Hatakeyama`, `Shiba`, `Ōuchi`, `Shimazu`, `Ōtomo`, `Uesugi`, `Takeda`, `Date`, etc.) start as `shugo_vassal` subjects who can fight internal *Sengoku* wars after the Ōnin War trigger while nominally under the Shogun/Emperor.
3. **Regional Governance Depth (History-Led Hybrid):** Build **bespoke systems wherever history had genuinely distinct constitutional machinery**, and use **rich data-driven estates, privileges, reforms, and events** everywhere else:
   - *Bespoke systems warranted:* **HRE Imperial Diet**, **Japanese Shogunate**, **Ming Mandate of Heaven & Tributary Order**, **Polish–Lithuanian *Sejm* & Royal Elections** (once `Jagiellon` union matures / 1572), **Steppe *Kurultai* / Chinggisid Legitimacy** (governing succession crises like Esen Taishi 1453–1455), and **SE Asian *Mandala* Tribute Rings** (prestiged-based outer vassals).
   - *Data-driven regional flavour (estates, privileges, reforms, events):* **Mamluk** Circassian faction succession + *Iqta*, **Ottoman** *Devshirme*/*Timar*/*Millet*, **Persianate** *Tajik Bureaucracy vs. Turkic Sword* + Sufi orders, **Vijayanagara** *Amara-Nayaka* (`holds:` great vassals + privileges), **Italian** *Signoria*/*Condottieri*, **Russian** *Prikazy*/*Pomestie*, **Iberian** *Mesta*/*Cortes*/*Hermandades*, **Ethiopian** *Chewa*/*Gult*, and **West African** Trans-Saharan gold guilds.
4. **Formable Nations:** **Historical + plausible alt-history + broad sandbox unions** (all three tiers above). Technically, Gez can implement this cleanly by allowing a country decision/event to swap a tag's display name, map colour, heraldry path, rank/reforms, and mission tree (or pre-registering dormant formable tags at startup so `CountryTable` length remains fixed for deterministic saves).

### Settled Technical Choices (Synced with Map Research)
- **Map Bounds & `PPD` Resolution:** Full Afro-Eurasia (`LON -25..148, LAT -35..71.5`) at **`PPD = 48`** (`8304 × 5112` px), paired with `GRID_CELL_PX = 12.0` in `Map3D.gd`.
- **Formables Mechanics:** In-place tag transformation (fixed `CountryTable` slot, swapping name, colour, heraldry, reforms, and Phase 21 mission tree).
- **New Religions:** Granular additions to `Religion.swift` (`confucian`, `daoist`, `mahayana`, `shinto`, and split African/Siberian/SE Asian indigenous traditions).

---

## Review notes (Claude, 22 Nov 2026)

Checked against the repo and spot-checked against sources. Most of the
history holds up; fix these before building from it.

**Corrections**
1. **Lower Lusatia (§2.4.4):** in May 1453 it was *not* Bohemian. Elector
   Frederick II of Brandenburg bought the pledge of the Lusatian
   *Landvogtei* in October 1448 (Lübben, Guben and Luckau did homage to
   him) and held it until the Peace of Guben (1462), when Bohemia took it
   back and Brandenburg kept only Cottbus, Peitz and a few lordships. So
   new `Lubben`/`Guben` provinces should be `BRA` (as a pledge) in 1453,
   not `BOH`.
2. **Rimini (§2.5.1):** Sigismondo Malatesta held Rimini and Fano;
   **Cesena** was his brother **Malatesta Novello**'s, ruled alone since
   1433 until his death in 1465. Two Malatesta signorie, not one.
3. **Counts in §1:** `subjects.txt` has 4 personal unions, **10** vassals
   and **10** tributaries (not 8 and 12). The other counts match.
4. **Canaries (§2.2.1):** add **La Gomera** to the seigneurial
   (Herrera-Peraza, Castilian-vassal) islands alongside Lanzarote,
   Fuerteventura and El Hierro.

**Gaps in the expansion plan (§3, §5)**
5. **Australia and New Guinea:** the chosen box (`LON -25..148`,
   `LAT -35..71.5`) takes in almost all of Australia, New Guinea, Timor
   and the Moluccas east of Sulawesi. §3 does not cover them. Decide
   whether they are wasteland, "unknown land" parchment, or populated
   (Aboriginal nations, New Guinea highlands, Makassan trepang trade).
6. **Empty pixels:** much of the new rectangle is open ocean (southern
   Indian Ocean, western Pacific), Sahara, Siberia and Tibet. At
   `PPD = 48` that is a lot of memory spent on water and wasteland.
   Worth measuring before committing to 48; `PPD = 40` keeps the width
   under 8192 and may be the safer first step.
7. **Windows, not iPad:** the owner ships to **Mac and Windows** (no iPad
   for now). The 8304 px texture width needs checking on Windows GPUs
   (Vulkan/D3D12, usually 16384, but older integrated GPUs vary), not
   the M5 iPad.
8. **Where it fits in the roadmap:** none of this is in `ROADMAP.md` yet.
   Suggested order: the in-map fixes from Part I (data only) during or
   right after 20.5; the Afro-Eurasia expansion as its own phase **after
   alpha "Kayser" and before Phase 21**, so mission trees are written
   once for the final set of countries; HRE, Shogunate, Mandate and the
   other bespoke systems as phases after that. Map changes break saves
   and Phase 18 timelapse history, which is fine before a stable release.
9. **Size of the job:** roughly doubling provinces (to ~3,000) and
   countries (to ~500) means new pops, cultures, markets, buildings,
   armies, characters (CK3-style real people for East Asia, SE Asia and
   Africa) and art (shields, portraits, 3D styles). Plan it as several
   pull requests per region, each green in CI on its own.

**Checked and correct** (sample): Isabella of Lorraine's death
(28 Feb 1453) and John II's succession; Metz, Besançon, Basel as imperial
cities; Thurgau Habsburg until 1460; Further Austria under Albert VI until
1458; Pomerania's three-way split incl. Eric of Pomerania at Rügenwalde;
Oświęcim to Poland 1454/1457; Shemyaka in Novgorod (d. July 1453); Yemen
Rasulid–Tahirid transition; Jingtai Emperor; Danjong and the 1453 coup;
Ashikaga Yoshimasa (renamed from Yoshishige in 1453); Ryukyu's 1453
succession crisis; Ava, Arakan, Lan Na, Ayutthaya and Malacca rulers.
