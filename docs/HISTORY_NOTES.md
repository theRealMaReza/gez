# 1453 map: judgment calls and open questions

The start date is **30 May 1453**. These are the places where the history is
unclear, sources disagree, or the map simplifies things. Each item says what
the map currently does. Change the data in `data/map/` (or tell Claude) to
decide differently.

## Simplifications (on purpose)

1. **Holy Roman Empire.** Hundreds of small counties, abbeys, imperial
   knights and free cities are merged into about 45 states. Examples:
   Anhalt is part of Magdeburg; Osnabrück and Paderborn are part of Münster;
   Fulda is part of Hesse; Konstanz is grouped with Ulm. (Since Phase 20.5
   Basel, Metz and Besançon are free cities, St Gallen and Valais are Swiss
   allies, and Further Austria is Albert VI's.)
2. **French great vassals.** Anjou, Maine, Bourbon, Orléans, Alençon,
   Armagnac and Albret are inside France. Only Brittany, Burgundy, Provence
   and Foix-Béarn are separate. (Since Phase 20.5 René of Anjou's Provence
   also holds Anjou (Angers) and Bar.)
3. **Ireland.** Gaelic and Anglo-Irish lordships are reduced to fourteen
   (Kildare, Leinster, Ormond, Desmond, Thomond, Clanricarde, Mac William
   Íochtar, O'Conor Don, O'Connor Faly, East Breifne, Fermanagh,
   Tyrconnell, Tyrone, plus English Dublin, Meath, Wexford, Waterford and
   Ulster towns). Smaller ones (MacMahon of Oriel, O'Rourke, O'Kelly and
   others) are still merged.
4. **Rajput, Gond and Himalayan states.** Only the larger ones are
   separate. Smaller chiefdoms (Sirohi, Dungarpur, Jammu, Jumla and others)
   are unclaimed or merged.
5. **Kurdish emirates and Arab tribes.** Only Bitlis is a separate Kurdish
   state; Hakkari is unclaimed. Najd, Qatar and the Hejaz interior are
   unclaimed tribal land.
6. **Steppe.** The central Kazakh steppe, the Wild Fields of Ukraine and
   Bashkiria are unclaimed land or loosely held by hordes.
7. **Religion is set per state, not per town.** Mixed areas (Bosnia, Albania,
   Transylvania, Lebanon, Egypt's Copts, Armenia) show the majority or the
   ruler's religion.

8. **Borders follow geography, not surveyed frontiers.** Province shapes stop
   at 73 rivers, 20 mountain ridges and three hand-drawn frontier lines (the
   Granada frontier, the 1422 Melno line between Prussia and Lithuania, and
   the Prussia–Mazovia frontier). Elsewhere a border lies between
   neighbouring towns. River and ridge lines are hand-drawn and accurate to
   roughly 10–30 km.
9. **1453 coastlines.** The Zuiderzee and the enlarged Dollart are open
   water; the Aral Sea is at its full size. Smaller changes (deltas, lagoons)
   are not modelled.

## Population and religion estimates

- **All population mixes are estimates.** No censuses exist for 1453. Shares
  for cities and frontier zones are educated guesses from later Ottoman
  registers, travellers and modern scholarship.
- **Region totals** (`data/map/population_1453.txt`) are middle estimates;
  sources disagree by 20–40%. India is about 100 million, Europe (with
  Russia) about 65 million.
- **India was split into about 280 provinces** (session 3, owner's choice),
  adding small states the first map left out: Kangra, Chamba, Kullu, Doti,
  Palpa, Lamjung, the Kirat tribes, Dungarpur, Sirohi, Jalore, Karauli,
  Rajpipla, Deogarh, Mallabhum, Chandradwip, the Bhuyan chiefs of Assam,
  the Chutia kingdom, the Khasi chiefs and Jaintia. Their 1453 status is
  approximate; most were local dynasties paying tribute to bigger neighbours.
- **City provinces include their countryside.** Konstantiniyye shows about
  300,000 people, though the city itself had perhaps 50,000 after the siege.
- **Persia is shown as mostly Sunni (Shafi'i)** with Twelver pockets, as it
  was before the Safavids.
- **Bohemia's ruler is counted as Hussite** because the kingdom was run by
  Utraquists under George of Poděbrady, though King Ladislaus was Catholic.
- **Bosnia** is split between the Bosnian Church, Catholics and Orthodox
  Vlachs; King Stephen Thomas had converted to Catholicism.

## Decisions made by the owner (settled; don't change without asking)

Blank land: **tribal countries** (government type `tribal`) now hold land
that had no single ruler in 1453: Baloch Tribes, Pashtun Tribes, Hazara
Tribes, Najdi Tribes, Shammar, Asir Tribes, Yam Tribes (Najran),
Cyrenaican Bedouin, Fezzan, Sous Confederation, Zenata Tribes, Ja'alin
Arabs, Beja Tribes, Somali Clans, Hakkari Emirate, Mordvins, Komi, Sami,
Oirats, Turkmen Tribes, Khokhars, Dard Tribes, Jat Tribes, Guanche Tribes,
Kabarda, Alania, Vainakh Tribes (Circassia itself is now tribal). The Wild
Fields went to Crimea (Zaporizhia, Azov Steppe) and the Great Horde
(Kharkiv, Voronezh); Samara to the Nogai; the central steppe to the Uzbeks,
Oirats and Moghulistan. No province is unclaimed any more.

| # | Question | Decision |
|---|---|---|
| 1 | Bordeaux and Guyenne | **England** (lost after Castillon, July 1453) |
| 2 | Mandore | **Rao Jodha (Marwar)** |
| 3 | Timurids | **Two states; Balkh and Kunduz to Samarkand** (Abu Sa'id); Kabul to Herat; Khwarazm to Samarkand |
| 4 | Otrar | **Timurids (Samarkand)** |
| 5 | Qara Qoyunlu | **Hold all of it** (Iraq, Azerbaijan, Isfahan, Fars, Kerman, Yazd) |
| 6 | Aq Qoyunlu | **As drawn** (Diyarbakır, Mardin, Urfa, Harput, Erzincan, Bayburt, Erzurum) |
| 7 | Kayseri and Kırşehir | **Kayseri to Dulkadir**, Kırşehir stays Karaman |
| 8 | Niš and Vrhbosna | **Niš Serbian**, Vrhbosna Ottoman |
| 9 | Upper Hungary | **Jiskra's Brotherhood** as a Hussite state (Kassa, Bártfa, Besztercebánya) |
| 10 | Kilia | **Hungary** (its garrison) |
| 11 | Ochakiv coast | **Crimea** |
| 12 | Lower Lusatia | **Brandenburg** |
| 13 | Velikiye Luki | **Lithuania** |
| 14 | Marrakesh | **Hintata Emirate, a vassal of Morocco** (Marrakesh, Mogador) |
| 15 | Algiers | **Tlemcen** |
| 16 | Cyrenaica and Fezzan | **Tribal countries** |
| 17 | Yemen | **Zaydi imams hold the highlands** (Sanaa, Sadah, Marib); **the Tahirid Sultanate holds the rest it held then** (Aden, Taizz, Zabid, Jizan); Najran (Yam) and Asir tribal |
| 18 | Al-Hasa, Qatif, Bahrain | **Jabrids hold Bahrain too** (and Qatar) |
| 19 | Dhofar | **Kathiri** |
| 20 | Dongola | **Dotawo**, a Christian Nubian kingdom |
| 21 | Ethiopian south | **Tributaries of Ethiopia**: Hadiya, Bali, Dawaro, Ifat, Ennarea, Damot |
| 22 | Somali coast | **As drawn** (Ajuran, separate Mogadishu) |
| 23 | Rajahmundry | **Orissa** |
| 24 | Goa | **Vijayanagara** |
| 25 | Chittagong | **Bengal** |
| 26 | Etawah, Kannauj, Kalpi | **Jaunpur** |
| 27 | Ranthambore | **Mewar** |
| 28 | Kaffa | **As drawn** (independent, folk religion) |
| 29 | North Caucasus | **Split into tribal states**: Circassia, Kabarda, Alania, Vainakh |
| 30 | Armenia | **Armenian Christian majority (about 70%)** |
| + | Ladislaus the Posthumous | **Personal union**: Austria and Bohemia under the King of Hungary |
| Phase 13 | 1453 starting tech spread | **Wider 2–4 spread**: core Italian, Western European, Ottoman and major Islamic centres start at 3–4 (specific overrides up to 4 on strengths); settled realms at 3; steppe/tribal periphery at 2 |
| Phase 13 | Printing Press origin year | **1462 in Mainz**: starts in Mainz in 1462 after the Sack of Mainz dispersed Gutenberg's printers across Europe, rather than 1450 when Gutenberg kept movable type secret |
| Phase 13 | Renaissance in 1453 | **Active across `Italy`**: all Italian regions start with Renaissance present and embraced by Italian states in 1453 (before spreading north over the Alps) |

Subject countries at the start are listed in `data/map/subjects.txt`
(personal unions, vassals, tributaries), including well-known ones the
owner didn't have to decide: Aragon–Naples and Denmark–Norway unions;
Ottoman vassal Serbia and tributaries Wallachia, Morea, Athens, Lesbos;
Mamluk vassals Mecca, Dulkadir, Ramadanids; Polish vassals Mazovia and
Moldavia; French vassals Brittany and Foix; Muscovite vassal Kasimov.

## Other notes

- **Constantinople** is Ottoman (taken 29 May). Galata/Pera surrendered
  within days and is merged into Konstantiniyye.
- **Genoese colonies:** Kaffa, Cembalo, Matrega, Chios (the Maona) and
  Famagusta are Genoese. Corsica went to the Bank of St George in 1453 and
  is shown as Genoa.
- **Kalmar Union:** Denmark and Norway share King Christian I but are
  separate countries; Sweden is under Charles VIII Knutsson.
- **Ladislaus the Posthumous** is King of Hungary and Bohemia and Duke of
  Austria at once. The map shows Hungary, Bohemia and Austria as separate
  countries. Inner Austria (Frederick III, the Emperor) and Tyrol are also
  separate. A personal-union mechanic can link them later.
- **Novgorod, Pskov and Vyatka** are independent republics; Yaroslavl, Tver
  and Ryazan are independent but close to Moscow.


## People of 1453 (Phase 4)

Real people are in `data/characters/people_*.txt` (rulers in
`people_1453.txt`; whole families, dead parents and great vassals by region
in `people_2_west.txt` … `people_5_south.txt`). Only people history records
are added; invented people fill gaps only. Which provinces each great vassal
holds is simplified to the map's provinces (e.g. Hunyadi: Temesvár, Szörény,
Szeben). These facts are uncertain (mostly birth years, some 1453
office-holders and lordships). Countries with no
recorded ruler got an invented ruler and an invented sibling heir (owner's
rule); they are marked "invented" in the game.

| Country | Person | What is uncertain |
|---|---|---|
| TUR | Gülbahar Hatun | origin disputed? |
| TUR | Sitti Şah Hatun | birth year? |
| TUR | Zağanos Pasha | birth year? |
| TUR | Turahan Bey | birth year? |
| TUR | İshak Pasha | birth year? |
| MOE | Catherine Zaccaria | birth year? |
| MOE | Theodora Asanina | birth year? |
| TRE | John IV Megas Komnenos | birth year? |
| TRE | Theodora Komnene | later wife of Uzun Hasan; birth year? |
| CYP | James the Bastard | illegitimate; birth year? |
| KNI | Jacques de Milly | birth year? |
| NAX | Giacomo II Crispo | died 1453; birth year? |
| LES | Dorino I Gattilusio | birth year? |
| LES | Domenico Gattilusio | birth year? |
| TOC | Leonardo III Tocco | birth year? |
| ATH | Francesco I Acciaioli | child duke, mother Chiara Zorzi regent? |
| ATH | Chiara Zorzi | regent? |
| ZET | Stefan Crnojević | birth year? |
| ZET | Ivan Crnojević | birth year? |
| ALB | Donika Arianiti | birth year? |
| ALB | Hamza Kastrioti | nephew; defected 1456; birth year? |
| ALB | Moisi Golemi | birth year? |
| ALB | Lekë Dukagjini | birth year? |
| HUN | Elizabeth Szilágyi | birth year? |
| HUN | Ladislaus Garai | palatine; birth year? |
| JIS | Jan Jiskra | birth year? |
| WAL | Vladislav II | birth year? |
| WAL | Vlad Dracula | in exile; birth year? |
| MOL | Alexăndrel | birth year? |
| MOL | Peter Aron | rival claimant; birth year? |
| MOL | Stephen of Moldavia | in exile; later Stephen the Great; birth year? |
| SAL | Sigismund of Volkersdorf | archbishop; birth year? |
| BAD | Catherine of Lorraine | birth year? |
| BAD | Markus of Baden | birth year? |
| POM | Eric II of Pomerania | birth year? |
| UTR | Rudolf van Diepholt | bishop; birth year? |
| GEN | Pietro di Campofregoso | Doge; birth year? |
| GRA | Muhammad XI | 1453 rulers of Granada uncertain? |
| GRA | Sa'd of Granada | rival, king 1454; birth year? |
| ENG | Richard of York | heir presumptive? |
| TYR | Eoghan Ó Néill | birth year? |
| TYR | Énrí Ó Néill | birth year? |
| TMN | Toirdhealbhach Bóg Ó Briain | birth year? |
| DAN | Knud of Denmark | birth year? |
| MAZ | Bolesław IV of Warsaw | birth year? |
| TVE | Mikhail of Tver | birth date? |
| RYA | Ivan Fyodorovich | dies 1456; birth year? |
| KAS | Qasim Khan | birth year? |
| KAZ | Mahmud of Kazan | birth year? |
| CRI | Nur Devlet | birth year? |
| CRI | Meñli Giray | birth year? |
| GRH | Küchük Muhammad | birth year? |
| GRH | Mahmud of the Great Horde | birth year? |
| GRH | Akhmat Khan | birth year? |
| UZB | Shah Budaq | birth year? |
| MGH | Esen Buqa II | birth year? |
| AKK | Khalil Mirza | birth year? |
| AKK | Jahangir Mirza | elder brother, deposed? |
| QAR | Hasan Ali | birth year? |
| QAR | Pir Budaq | birth year? |
| KAR | İbrahim II of Karaman | birth year? |
| KAR | Pir Ahmed | birth year? |
| KAR | Kasım Bey | birth year? |
| CND | İsmail Bey | birth year? |
| DUL | Süleyman Bey | birth year? |
| DUL | Malik Arslan | birth year? |
| SHI | Khalilullah I | birth year? |
| SHI | Farrukh Yasar | birth year? |
| SAM | Kaikhosro Jaqeli | birth year? |
| MAM | Ahmad ibn Inal | Mamluk succession is not hereditary in practice? |
| ZAY | Al-Mutawakkil al-Mutahhar | imam; birth year? |
| MSH | Muhammad ibn Falah | founder; birth year? |
| MOR | Yahya al-Wattasi | vizier; birth year? |
| ETH | Eleni | birth year? |
| ADA | Muhammad ibn Badlay | birth year? |
| DEL | Barbak Shah | birth year? |
| JNP | Mahmud Shah Sharqi | birth year? |
| JNP | Muhammad Shah Sharqi | birth year? |
| JNP | Husain Shah Sharqi | birth year? |
| KSH | Adam Khan | birth year? |
| KSH | Haji Khan | birth year? |
| MUL | Rai Sahra Langah | birth year? |
| GUJ | Qutb-ud-din Ahmad Shah II | birth year? |
| MLW | Ghiyath Shah | birth year? |
| KHA | Miran Mubarak Khan | birth year? |
| BNG | Nasiruddin Mahmud Shah | birth year? |
| BNG | Rukunuddin Barbak Shah | birth year? |
| BAH | Ala-ud-din Ahmad Shah II | birth year? |
| BAH | Humayun Shah | birth year? |
| ORI | Kapilendra Deva | birth year? |
| ORI | Hamvira | birth year? |
| ORI | Purushottama Deva | birth year? |
| VIJ | Mallikarjuna Raya | birth year? |
| VIJ | Virupaksha Raya | cousin; birth year? |
| MEW | Rana Kumbha | birth year? |
| MEW | Udai Singh | birth year? |
| MEW | Raimal | birth year? |
| AHO | Susenphaa | birth year? |
| TPR | Dharma Manikya I | birth year? |
| ENG | Owen Tudor | second husband of Catherine of Valois; birth year? |
| ENG | Edmund Beaufort | birth year? |
| ENG | John Beaufort | birth year? |
| ENG | Margaret Beauchamp of Bletso | birth year? |
| ENG | Thomas Neville | birth year? |
| ENG | Eleanor Neville | birth year? |
| ENG | Ralph Percy | birth year? |
| ENG | Anne Neville, Duchess of Buckingham | birth year? |
| ENG | Humphrey Stafford, Earl of Stafford | birth year? |
| ENG | Margaret Beaufort, Countess of Devon | birth year? |
| SCO | Isabella Stewart | widow of Francis I of Brittany; birth year? |
| SCO | Joan Stewart | deaf; birth year? |
| SCO | Annabella Stewart | birth year? |
| SCO | Archibald Douglas, Earl of Moray | brother of the 9th Earl; birth year? |
| SCO | Alexander Gordon, Earl of Huntly | birth year? |
| SCO | William Crichton | Lord Chancellor; birth year? |
| FRA | Charles II of Albret | birth year? |
| BUR | John of Burgundy, Count of Nevers | cousin; birth year? |
| BUR | Cornelius of Burgundy | killed 1452? |
| POR | Afonso, Count of Ourém | birth year? |
| POR | John of Coimbra | husband of Charlotte of Cyprus later; birth year? |
| CAS | Juan Ponce de León | Count of Arcos; birth year? |
| CAS | Beltrán de la Cueva | Henry's favourite; birth year? |
| ARA | Alfonso of Aragon | later Duke of Villahermosa; birth year? |
| ARA | Juan of Aragon | later archbishop of Zaragoza; birth year? |
| ARA | Joan Ramon Folc of Cardona | Count of Cardona; birth year? |
| NAP | Maria of Aragon | wife of Lionello d'Este (widowed); birth year? |
| NAP | Eleanor of Aragon | birth year? |
| NAP | Marino Marzano | Prince of Rossano; birth year? |
| NAP | Tristan of Clermont | birth year? |
| MLO | Tristano Sforza | birth year? |
| MLO | Sforza Secondo | birth year? |
| MLO | Elisabetta Sforza | birth year? |
| FLO | Ginevra degli Alessandri | birth year? |
| FLO | Carlo de' Medici | birth year? |
| SAV | Aimon of Savoy | birth year? |
| HUN | Michael Szilágyi | brother of Elizabeth; birth year? |
| HUN | János Rozgonyi | voivode of Transylvania?; birth year? |
| HUN | Dénes Szécsi | archbishop of Esztergom; birth year? |
| BOH | Johana of Rožmitál | birth year? |
| BOH | Bolko V the Hussite | Duke of Opole-Głogówek; birth year? |
| BRA | Margaret of Brandenburg | birth year? |
| GEL | Margaret of Egmond | birth year? |
| GEL | Catherine of Egmond | birth year? |
| DAN | Maurice of Oldenburg | birth year? |
| SWE | Sten Sture | nephew of Charles VIII?; later regent |
| SWE | Erik Axelsson Tott | birth year? |
| POL | Jan Tęczyński | castellan; birth year? |
| POL | Piotr Odrowąż | voivode of Ruthenia?; birth year? |
| LIT | Semen Olelkovich | birth year? |
| LIT | Mikhail Olelkovich | birth year? |
| LIT | Jonas Goštautas | birth year? |
| MAZ | Barbara Olelkovna | birth year? |
| MAZ | Konrad III the Red | birth year? |
| MAZ | Kazimierz III | birth year? |
| MAZ | Bolesław V | birth year? |
| MOS | Ivan Andreyevich of Mozhaysk | flees to Lithuania 1454; birth year? |
| MOS | Mikhail Andreyevich of Vereya | birth year? |
| MOS | Vasily Yaroslavich of Serpukhov | jailed by Vasily II in 1456; birth year? |
| NOV | Sophia of Zaozerye | birth year? |
| NOV | Ivan Dmitrievich | birth year? |
| NOV | Isaak Boretsky | posadnik; birth year? |
| NOV | Marfa Boretskaya | Marfa the Posadnitsa; birth year? |
| TUR | Hüma Hatun | origin disputed? |
| TUR | Fatma Hatun | daughter of Murad II, wife of Zağanos?; birth year? |
| TUR | Şehzade Hatun | birth year? |
| TUR | Evrenosoğlu Ali Bey | march lord; seat at Yenice-i Vardar?; birth year? |
| TUR | Mihaloğlu Ali Bey | raider lord; birth year? |
| TUR | Ömer Bey | birth year? |
| TUR | İshak Bey | march lord of Skopje; birth year? |
| TUR | Isa-Beg Ishaković | founder of Sarajevo; birth year? |
| SER | Jelena Branković | later Queen of Bosnia; birth year? |
| SER | Milica Branković | birth year? |
| SER | Irina Branković | birth year? |
| SER | Vuk Grgurević | "Vuk the Fiery Dragon"; birth year? |
| SER | Mihailo Anđelović | brother of Mahmud Pasha; birth year? |
| BOS | Vojača | first wife of Stephen Thomas, set aside 1445; birth year? |
| BOS | Catherine Tomašević | birth year? |
| HER | Jelena Balšić | dies late 1453?; birth year? |
| HER | Katarina Hercegović | birth year? |
| ALB | Voisava | origin disputed; death date unknown? |
| ALB | Mamica Kastrioti | sister of Skanderbeg; birth year? |
| WAL | Radu the Fair | hostage at the Ottoman court; birth year? |
| WAL | Vlad the Monk | birth year? |
| MOL | Oltea | mother of Stephen; birth year? |
| KAR | Sultan Hatun | daughter of Mehmed I; birth year? |
| KAR | İshak Bey | eldest son, mother not Sultan Hatun?; birth year? |
| DUL | Şah Budak | birth year? |
| DUL | Şehsuvar Bey | birth year? |
| TRE | Helena Kantakouzene | birth year? |
| TRE | Basil Megas Komnenos | birth year? |
| TRE | Manuel Megas Komnenos | birth year? |
| AKK | Seljuk Shah Begum | birth year? |
| AKK | Ughurlu Muhammad | birth year? |
| QAR | Bigim Khatun | birth year? |
| GEO | Nestan-Darejan | birth year? |
| GEO | Alexander | birth year? |
| GEO | Liparit I Dadiani | prince of Mingrelia; birth year? |
| GEO | Mamia Gurieli | prince of Guria; dates uncertain? |
| MAM | Khawand Zaynab | wife of Inal; birth year? |
| ETH | Seyon Mogesa | mother of Baeda Maryam; birth year? |
| DEL | Daria Khan Lodi | governor of Sambhal?; birth year? |
| DEL | Ahmad Khan Mewati | Khanzada chief of Mewat?; birth year? |
| DEL | Qutb Khan Lodi | cousin of Bahlul; birth year? |
| JNP | Bibi Raji | birth year? |
| GUJ | Bibi Mughli | mother of Fath Khan; birth year? |
| MEW | Ramabai | birth year? |
| MAR | Satal | birth year? |
| MAR | Suja | birth year? |

## Government in 1453 (Phase 5)

Laws, reforms and stability on 30 May 1453 are set in
`data/government/laws_1453.txt`. Most countries get defaults by government
and religion (feudal crown, customary taxes, levies; Christian realms
"state faith only", Muslim and Hindu realms "protected minorities"). These
are judgment calls, change them freely:

| Country | Choice | Why / doubt |
|---|---|---|
| TUR | Centralised crown, royal tax collectors, standing army (Janissaries), serfdom | Timar land is close to serfdom only loosely? |
| MAM | Standing army, tax collectors; Mamluk emirs 35% power | |
| FRA | Standing army, tax collectors, royal domain | Compagnies d'ordonnance 1445, taille permanente |
| ENG, CAS, ARA, POL, FRA | "Diet of the estates" reform | Parliament, Cortes, Sejm, Estates-General |
| HUN, BOH | "Elective crown" reform | Both elected kings in practice |
| VEN | Sound money, free markets, chartered towns, Great Council, State arsenal | |
| LIT, MOS | Serfdom | Serfdom tightens later (15th–16th c.)? |
| ETH | Serfdom | gult land tenure is not quite serfdom? |
| KSH, VIJ | Open tolerance | Zain-ul-Abidin's and Vijayanagara's tolerance |
| Stability | TUR +2, FRA +2, VEN +2, KSH +2; MOE, MOL, NAV −2; WAL, MOR −1; ENG, CAS, TRE, HUN, BOH, MOS 0; others +1 | Morea: Albanian revolt of 1453; Moldavia and Navarre: civil wars |
| Cossacks | Not an estate | They appear decades after 1453 |

## Standing armies on 30 May 1453 (Phase 6)

Starting standing armies live in `data/military/armies_1453.txt` (built into
`military1453.json` by `tools/military/milgen.py`). Seasonal feudal and
tribal levies stay unraised in their home provinces at game start; only
standing professional forces, household guards, and active campaign hosts of
May 1453 start on the map:

| Country | Army & Location | Commander | Notes / judgment calls |
|---|---|---|---|
| TUR | Imperial Army of Constantinople (`Konstantiniyye`), Army of Rumelia (`Edirne`) | Mehmed II, Zağanos Pasha | Day after the fall of Constantinople (29 May 1453); Janissaries, sipahi cavalry, azab infantry, handgunners and Urban's bombards |
| FRA | Compagnies d'Ordonnance (`Paris`), Army of Normandy (`Rouen`) | Jean de Dunois, Jean Bureau | Charles VII's standing *Compagnies d'Ordonnance* (1445) and Bureau's artillery train preparing for the final Castillon campaign |
| ENG | Army of Aquitaine (`Bordeaux`), Royal Retinue (`London`) | John Talbot, Edmund Beaufort | Talbot's Gascon expedition (fought at Castillon in July 1453) and the royal household retinue |
| MAM | Royal Mamluks of Cairo (`Cairo`), Army of Damascus (`Damascus`) | Sultan Inal, Khushqadam | Purchased *julban* and veteran *qarani* Mamluk household cavalry |
| HUN, BOH, JIS | Royal Banderium (`Buda`), Landfrieden Host (`Prague`), Black Brethren (`Kassa`) | John Hunyadi, George of Poděbrady, Jan Jiskra | Hunyadi's banderium, Hussite *vozová hradba* war wagons, and Jiskra's Czech mercenaries in Upper Hungary |
| ALB | League of Lezhë (`Kruje`) | Skanderbeg | Standing mountain retinue of the League of Lezhë |
| QAR, AKK, TIM, HRT | Tabriz, Diyarbakir, Samarkand, Herat | Jahan Shah, Uzun Hasan, Abu Sa'id Mirza, Abul-Qasim Babur | Turkmen and Timurid standing household *nöker* horse-archer hosts |
| DEL, VIJ, ORI, MEW, BAH, BNG, GUJ | Delhi, Vijayanagara, Cuttack, Chittor, Bidar, Gaur, Ahmedabad | Bahlul Lodi, Saluva Narasimha, Kapilendra Deva, Rana Kumbha, Humayun Shah, Nasiruddin Mahmud, Qutb-ud-din Ahmad | Standing sultanate, Rajput and Gajapati hosts with war elephants (`pil-khana`) |
| ETH | Chewa Regiments (`Debre Berhan`) | Zara Yaqob | Zara Yaqob's royal *chewa* military colonies |

Review fixes (Claude, session 6), and points still open for the owner:
- **Fixed:** Castile's army was led by Álvaro de Luna, but he was arrested
  in April 1453 and executed on 2 June; Juan Pacheco leads it instead.
- **Fixed:** Burgundy's "Ducal Ordonnance" with gendarmes: Burgundy's
  ordonnance companies date from 1471. In May 1453 Philip the Good was
  fighting the Ghent revolt (Gavere, July 1453), so it is now Philip's
  "Ducal Host" of ordinary cavalry and infantry.
- **Fixed:** the Papal Guard was led by Cardinal Alfonso de Borja (later
  Callixtus III), a churchman, not a commander; it now starts without one.
- **Fixed:** the "Army of Damascus" stood in Aleppo; moved to Damascus.
- Open: Venice, Herat and Morocco use invented marshals although real
  figures are known (Venetian condottieri such as Gentile da Leonessa;
  Abul-Qasim Babur ruled Herat; Fez was run by Wattasid viziers). Replace
  them with real people when those characters are added.
- **Fixed (Phase 20.5):** Albert VI now rules Further Austria; the guard
  at Graz starts without a commander. Jean Bureau's artillery stands at
  Rouen, though by spring 1453 he was preparing the Guyenne campaign.
- Open: army sizes are game-scaled; Mehmed's host at Constantinople was
  far larger than 16,500 historically.

## Treaties and wars on 30 May 1453 (Phase 7 review)

- Added by Claude's review: the **Albanian–Ottoman war** (Skanderbeg beat
  Ibrahim Pasha at Polog in April 1453) and the **Delhi–Jaunpur war**
  (Mahmud Shah Sharqi besieged Delhi in 1452; start date approximate?).
- Scotland as an active co-belligerent of France in the Hundred Years' War
  in May 1453? The Auld Alliance stood, but Anglo-Scottish truces were in
  force at times.
- Ottoman–Genoese truce: Galata surrendered on 1 June 1453, two days after
  the game starts?
- Possibly missing: Malwa–Mewar and Bahmani–Vijayanagara hostilities in the
  early 1450s?

## Fleets & Admirals on 30 May 1453 (Phase 10)

Starting squadrons live in `data/navy/fleets_1453.txt` (generated into
`navy1453.json` by `tools/navy/navgen.py`). Ship counts are game-scaled
squadron equivalents rather than literal 1453 boat tallies (the Ottoman
Bosporus/Marmara armada during the siege numbered well over 100 hulls
including small transport fustas):

| Tag | Fleet & Port | Admiral | Notes / uncertain history (`?`) |
|---|---|---|---|
| TUR | Imperial Fleet of Gallipoli (`Gallipoli`), Bosporus Flotilla (`Konstantiniyye`) | `hamza_bey` (Grand Admiral at Gallipoli in late May 1453 after Baltaoğlu's dismissal?) | Exact ship split between Gallipoli and the Golden Horn on 30 May 1453? |
| VEN | Armada da Mar (`Venice`), Aegean Guard (`Negroponte`) | `loredan_alvise` (*Capitano Generale da Mar*, ordered toward Constantinople in spring 1453) | Exact date Loredan reached Negroponte/Chios (may still have been en route from Corfu on 30 May 1453)? |
| NAP, ARA | Royal Armada (`Naples`), Catalan Armada (`Barcelona`) | `vilamari` (Bernat de Vilamarí for Naples) | Exact division between Alfonso V's Catalan and Neapolitan squadrons in May 1453? |
| FRA, ENG | Normandy Fleet (`Caen`), Channel Fleet (`London`) | `bueil` (Jean V de Bueil, Admiral of France), `henry_holland` (Duke of Exeter) | Channel squadrons on station in May 1453 before the Castillon summer crossing? |
| POR, CAS | Armada of Lisbon (`Lisbon`), Castilian Armada (`Jerez`) | `henry_nav` (Henry the Navigator — patron/organizer rather than sea admiral?), `enriquez` (Almirante Fadrique Enríquez) | Using Henry the Navigator as Portugal's fleet commander is a convenience stand-in for an overseas captain? |
| GEN, LUB, DAN, MAM, GUJ, CLT | Genoa/Chios, Lübeck, Copenhagen, Alexandria/Suez, Cambay, Calicut | `inv_*_marshal` (invented admirals where 1453 fleet captains are not clearly documented in the roster) | Individual Genoese, Hanseatic, Danish, Mamluk and Indian Ocean admirals on 30 May 1453 remain unverified and use placeholder marshals? |

Claude's review (session 7): the Venetian captain-general sent toward
Constantinople in spring 1453 is usually named as **Giacomo** Loredan, not
Alvise Loredan (Alvise held the post in other years). The data keeps
`loredan_alvise` until the owner decides: swap to Giacomo Loredan?

## Religion, Holy Sites & Historical Movements (Phase 11)

- **Holy sites list** (`data/faith/holy_sites.txt`):
  - Multi-confessional sharing of **Constantinople** (`Konstantiniyye` shared among Orthodox, Armenian, Syriac?) and **Jerusalem** (shared across Christian sects, Muslim sects, and Judaism?).
  - **Mount Athos** mapped to `Thessaloniki` province and **Lalish** to `Sinjar` province because the map topology has no separate peninsular or temple-valley province for them?
  - Regional holy sites for smaller faiths (**Kandy** for Theravada, **Kathmandu** for Tibetan Buddhism alongside Bodh Gaya, **Mount Abu** and **Mount Girnar** for Jainism, **Kairouan** for Sunni Maghreb, **Antioch** for Alawites, **Safed** for Druze and Jewish mysticism, **Yerevan**/Etchmiadzin for Armenian) — weights/tiers are equal rather than graded?
- **Bohemia & the Hussite Compacts (1453+)**:
  - The Basel Compacts (`hussiteCompactsActive`) block Catholic–Hussite conversion throughout Bohemia/Compacts domains until the Utraquist/Taborite question is resolved (Pope Pius II revoked them historically in 1462 under George of Poděbrady, while the Peace of Kutná Hora in 1485 restored toleration — exact AI weights between `utraquistCompacts`, `taboriteRevival`, and `catholicSubmission` are probabilistic approximations?).
- **Safaviyya & Qizilbash movement**:
  - Shaykh Junayd and Shaykh Haydar began militarising the Ardabil Safaviyya order in the 1450s–1480s before Ismail I's capture of Tabriz (1501). Converting Ardabil's non-Ottoman/non-Mamluk owner to `twelver` represents an internal Qizilbash coup rather than spawning a brand-new `SAF` tag mid-game (since `CountryTable` count stays fixed for save/diplomacy arrays — revisit if dynamic country creation is added later?).
- **Reformation Centres (~1517, never before 1500)**:
  - Eligible centre provinces favor historical German, Swiss, Nordic, British, Czech, Dutch, and French urban centers (`Wittenberg`, `Geneva`, `Zurich`, etc.) weighted by development and excluded from Rome (`PAP`); non-European / Orthodox realms do not spark Protestant/Reformed centres directly unless via trade-route minorities?.
  - `Reformation` window (`1512–1529`, forced guarantee by `1529`) models structural reform pressures stochastically via `GameRandom` rather than fixed script dates; Calvinist/Reformed emergence is weighted to follow ~1519+ (`Zwingli`/`Calvin` windows approximated?).

## Plague, Famine, Earthquakes & Rebels (Phase 12)

- **Diseases**: the numbers are game rules fitted to rough history, not
  records. Later plague waves (after the Black Death) usually killed 10–20%
  of a struck city and came back every decade or two; the game gives about
  13% in a great city and 3–6% in the countryside. Camp fever (typhus) is
  first clearly described at the siege of Granada (1489); the game lets it
  appear in sieges from 1453 as "camp fever" in the older, looser sense?
  Smallpox as a once-a-generation killer of the young is modelled only by
  slowly fading immunity (no ages in the pops)?
- **Harvest**: every province is judged on 1 August, although India's and
  the Horn of Africa's main harvests follow the monsoon (autumn)?
- **Fault zones** (`data/calamity/fault_zones.txt`): circles drawn by hand
  around well-known earthquake country; chances and strengths are guesses
  from how often history records great earthquakes there (Anatolia, the
  Aegean and southern Italy most often; Lisbon, the Rhine and Catalonia
  rarely but badly)?
- **Known earthquakes** (they strike on their date whatever happens, since
  no ruler causes them): 5 December 1456 Naples (the great earthquake of
  the Kingdom of Naples, tens of thousands dead); 3 May 1481 Rhodes;
  10 September 1509 Constantinople ("the Lesser Judgment Day"); 26 January
  1531 Lisbon. The owner may want them left to chance instead? Others
  could be added (Erzincan 1458?, Kabul/Agra 1505, Kashmir 1555).
- **Separatists never create a new country**: their provinces go to a
  country that has lost its land, or to a neighbour of their culture; if
  there is none, their culture is accepted instead (the country list is
  fixed, as with the Safavids in Phase 11). Revisit if new countries can be
  created later?
- **Pretenders** are always real, living men of the ruler's own house (a
  brother, uncle or cousin in the character data); a realm whose dynasty
  has no such man gets no pretender?

## Historical Events (Phase 14)

- **66 historical events + 4 chronicle events** (`data/events/*.txt` -> `events1453.json`):
  - **1453 character roster limits**: historical figures born after 1453 or absent from `data/characters/1453.txt` (e.g., Christopher Columbus, Vasco da Gama, Martin Luther, Zahir-ud-din Muhammad Babur, Shah Ismail I, Hernán Cortés, Gustav Vasa) act through event text, choices, and `MovementSystem` effects rather than being spawned mid-game as scripted `CharacterID` entries. Should post-1453 named historical figures later be added as spawnable characters?
  - **Abul-Qasim Babur (`babur_m`, HRT, 1453) vs Mughal Babur (1504/1526)**: carefully distinguished — `hist_babur_kabul_1504` and `hist_babur_panipat_1526` target Kabul/Punjab owners (`TIM`, `HRT`, `KHO`, `AFG`) rather than requiring the 1453 Herat ruler `babur_m`?
  - **Otranto (1480)** (`hist_otranto_1480`): mapped to province `Lecce` (which encompasses the Salento peninsula and Otranto in the province graph) rather than splitting a separate Otranto province?
  - **Ladislaus the Posthumous (23 November 1457)** (`hist_ladislaus_death_1457`): fired for `HUN` on `exact_date = 1457-11-23` (first monthly tick thereafter) while `ladislaus5` is still living ruler, representing his sudden death in Prague and clearing the way for `hist_matthias_corvinus_black_army` (`1458+`); date-exact vs MTTH is a design choice?
  - **Columbus patron chain**: `hist_columbus_portugal` (1484–1488) -> if declined, sets `columbus_seeks_patron` enabling `hist_columbus_castile` (1491–1495) -> if also declined, sets `columbus_castile_refused` enabling `hist_columbus_fallback` (`FRA`, `ENG`, `GEN`, `VEN`); overseas New World provinces are not yet on the map, so Columbus rewards diplomatic tech, prestige, and Atlantic trade modifiers rather than spawning colonies yet?
  - **Vasco da Gama (1498)** (`hist_vasco_da_gama_calicut`): triggers for `POR` (1497–1504) if Lisbon is owned, paired with `hist_zamorin_calicut_1498` for Calicut's holder; trade modifiers model the Cape route spice boom without an off-map Atlantic/Indian lane simulation yet?
  - **Luther's Theses (31 October 1517) & Safavid Rise (1501)**:
    - `hist_luther_95_theses` (`SAX`, or `hist_luther_95_theses_alt` if another Catholic realm holds `Wittenberg`) calls `spawn_reformation = Wittenberg:protestant` into `MovementSystem` when `reformation_started = false`, letting historical triggers start the Reformation early or cleanly coordinate with the 1512–1529 structural Reformation check?
    - `hist_safavid_rise_1501` (`Ardabil` owner, non-`TUR`/non-`MAM` Muslim realm, 1500–1518) calls `advance_safaviyya = triumphant` and switches state religion to `twelver` in line with the Phase 11 Safaviyya rule (fixed country tags)?
  - **Alternate-history fallbacks**: key flashpoints include explicit counterfactual variants (`hist_fall_of_granada_conquered` vs `_war`, `hist_belgrade_1456_alt` for Ottoman-held Belgrade, `hist_end_hundred_years_war_eng`, `hist_constantinople_mosque` vs Christian-recovered `Konstantiniyye` via `not_tag` triggers, `hist_luther_95_theses_alt`), while rare non-historical borders simply suppress events whose preconditions no longer make sense?
  - **Exact-date vs MTTH trade-off**: events tied to sharply dated historical shocks (`hist_belgrade_1456_hun` 1456-07-21, `hist_ladislaus_death_1457` 1457-11-23, `hist_vasco_da_gama_calicut` 1498-05-20) use `exact_date`, whereas structural developments use `mtth = 6..36` months; exact MTTH weights and AI option weights are initial balance estimates?



## 1453 border fixes (Phase 20.5, 22 Nov 2026)

From `docs/MAP_EXPANSION_RESEARCH.md` Part I and the owner's locked
choices. New provinces: Frauenfeld (Thurgau), Cesena, Lahij, Carlow,
Enniskillen.

- **Yemen (owner's choice):** Tahirids hold Aden and Lahij, Rasulids hold
  Zabid, Taizz and Jizan. Strictly, Lahij was Tahirid from 1443 but Aden
  fell only in 1454, and al-Mas'ud Abu al-Qasim still used it as a refuge.
  Rasulid ruler: al-Mas'ud, with al-Mu'ayyad Husayn as rival claimant;
  their birth years are unknown.
- **Pomerania:** three duchies. Wolgast (Wartislaw IX, with Stralsund),
  Stettin (Otto III, a boy of nine) and Stolp (Eric of Pomerania, the old
  Kalmar king). Kolberg was really the Bishop of Cammin's town; it is
  given to Stolp.
- **Schleswig:** its own country, ruled by Adolf VIII of Holstein (the
  same man as Holstein), as a Danish vassal. Christian I is heir to both.
- **Thurgau:** Habsburg, under Sigismund of Tyrol, until the Swiss took it
  in 1460.
- **Saint Gall and Valais:** shown as church states allied to the Swiss
  (associates, not members). Saint Gall's town and abbey were separate;
  the abbot (Kaspar von Breitenlandenberg) stands for both. Valais is
  shown under its bishop (Heinrich Asperlin), though its seven districts
  (Zenden) governed with him.
- **Metz, Besançon, Basel:** free cities with invented leaders (the
  city councils changed every year). Basel's prince-bishop is not modelled.
- **Malatesta:** Sigismondo (Rimini, Fano) and his brother Malatesta
  Novello (Cesena) as two papal vassals.
- **Ireland:** Wexford is English (the Talbot liberty). Roscommon is
  O'Conor Don under Aedh (King of Connacht, d. 1461); the O'Conor Roe
  branch is not modelled. Carlow is the new seat of the MacMurrough
  Kavanaghs (Leinster). Birth years of the Irish lords are estimates.
- **Rostov:** a Muscovite vassal. Who exactly ruled the two halves of
  Rostov in 1453 is unclear; Vladimir Andreyevich and Ivan Ivanovich
  Dolgiy are the princes who sold the last half in 1474.
- **Upper Oka princes:** one Lithuanian vassal at Kozelsk, led by Fyodor
  Lvovich Vorotynsky. Odoyev, Belyov, Novosil and Vorotynsk are not
  separate provinces.
- **Ösel-Wiek:** a prince-bishopric of its own (Bishop Ludolf Grove), not
  the Livonian Order's.
- **Alaiye:** Karaman's vassal under Lütfi Bey. Alaiye was sold to the
  Mamluks in 1427 and retaken with Karaman's help in 1448; who was its
  overlord in 1453 is debatable.
- **Great vassals added:** Charles I of Nevers (Burgundy), Thomas Stanley,
  King of Mann (England), Pir Budaq in Shiraz and Isfahan (Qara Qoyunlu).
- **Not done yet (Phase 20.7 or later):** Tournai, Cambrai, East Frisia,
  Olivenza, the Canaries, Navarre's civil war, Silesian duchies, Lower
  Lusatia, Saxe-Lauenburg, Anhalt and the other merged HRE states, Italian
  minor lords, Hasankeyf, Bohtan, Medina, Medri Bahri, Dahlak, Gilan's two
  halves, Rustamdar, and the Indian feudatories.

## Old World faiths (Phase 20.7, 23 Nov 2026)
- The Oromo, Sidama and Kafa (and the kingdoms of Kaffa, Ennarea and Damot)
  move from generic "folk" to **East African traditions**. For the Oromo
  this is Waaqeffanna (worship of Waaqa); Kafa and Ennarea had their own
  sacred kingship and spirit cults (Omotic rather than Cushitic), grouped
  here for want of finer data. Damot's faith in 1453 is uncertain: it may
  already have been partly Christian or Muslim after Ethiopian and Adal
  raids.
- "Highland traditions" is a game label for the spirit cults of mainland
  Southeast Asia's hill peoples (Tai *phi* worship outside Buddhist courts,
  Karen, Hmong, Mon-Khmer hill groups); it is not one historical religion.

## East Asia core (Phase 20.7, 23 Nov 2026)

- **Yellow River course:** drawn on its 1194–1855 southern course (past
  Kaifeng and Xuzhou into the Yellow Sea near Huai'an), not its modern
  Shandong channel.
- **Ming China (`MNG`):** Jingtai Emperor rules; former Emperor Yingzong
  (`zhu_qizhen`) is a court figure under house arrest in Beijing; Zhu Jianji
  is Crown Prince on 30 May 1453 (died late 1453). Ten imperial princes
  (Jin, Qin, Zhou, Chu, Shu, Lu, Ning, Dai, Su, Qing) plus Duke Mu Lin of
  Yunnan are internal great vassals (`holds:`). Birth years of Empresses
  Wang, Hang, and Qian, Chen Xun, Shi Heng, Wang Wen, and Princes Zhu
  Zhigeng and Zhu Youjie are approximate (`?`).
- **Southwest *tusi* (`BOZ`, `SHX`, `LIJ`, `CHL`):** Bozhou (Yang Hui),
  Shuixi (An Long), and Lijiang (Mu Chu) are Ming vassals; Cheli /
  Sipsongpanna (Dao Ba) is a Theravada tributary. Whether An Long and Dao
  Ba were the exact ruling chiefs in May 1453 and the birth years of the
  *tusi* leaders are uncertain (`?`).
- **Joseon Korea (`JOS`):** 11-year-old King Danjong rules; Grand Prince
  Suyang is a court figure ahead of the late-1453 *Gyeyu Jeongnan* coup.
  Birth years of Hwangbo In and Princess Gyeonghye are estimates (`?`).
  Joseon's hereditary *nobi* are approximated at 3% in `slavery.txt`
  (distinct from chattel slavery).
- **Ashikaga Japan (`ASH` + 15 *shugo* vassals):** modelled with `ASH`
  holding Kyoto and central domains (with Rokkaku, Toki, and Kyōgoku as
  internal `holds:` vassals) and the 15 named *shugo* houses as vassal
  tags (`HSK`, `YMN`, `HTK`, `SHB`, `OUC`, `SMZ`, `OTM`, `SHN`, `KNO`,
  `KMK`, `UES`, `TKD`, `IMG`, `DTE`, `AND`). State faith is `shinto` with
  mixed `shinto` and `mahayana` pops (*shinbutsu-shūgō*). Birth years of
  several *shugo* (Shiba Yoshitoshi, Kai Jōji, Hatakeyama Yoshinari and
  Masanaga, Shōni Noriyori, Sō Shigemoto, Kōno Norimichi and Michiharu,
  Ashikaga Shigeuji, Uesugi Fusasada, Takeda Nobumori, Andō Masasue,
  Rokkaku Hisayori) and the exact year Andō Masasue consolidated Tsugaru
  and southern Ezo in the 1450s are uncertain (`?`).
- **Ryukyu (`RYU`):** Shō Kinpuku's death date (4th lunar month / May
  1453?) and the mid-crisis succession during the 1453 Shiro–Furi Rebellion
  (modelled with Shiro as ruler, Shō Taikyū as heir, Furi as rival figure,
  and `-2` stability) are uncertain (`?`), as are Shiro and Furi's birth
  years.
- **Ainu (`AIN`):** Koshamain (recorded in the 1457 rising) is placed as
  chieftain in 1453; his birth year and 1453 leadership are uncertain (`?`).
  Ainu animism is grouped under `siberian`, and Ryukyu's state faith under
  `mahayana` with `mahayana`/`shinto`/`confucian` pops.

## Tarim Basin and Moghulistan (Phase 20.7, 23 Nov 2026)

- **Dughlat Emirate of Kashgar (`DUG`):** modelled as a vassal tag of
  Moghulistan (`MGH`) under Amir Sayyid Ali Dughlat (r. 1435–1457), who
  held Kashgar, Yarkand, and Khotan semi-independently while acknowledging
  Esen Buqa II (owner's pick, 23 Nov 2026). Birth years of Sayyid Ali,
  Sayyid Ahmad Mirza, Saniz Mirza, and Muhammad Haidar Mirza are
  approximate (`?`).
- **Moghulistan (`MGH`):** capital moved to Aksu (Esen Buqa II's Tarim
  base in the 1450s); Yunus Khan is included as a court figure (in exile
  in Persia until 1456). Birth years of Uwais Khan, Dost Muhammad, Yunus
  Khan, and Mir Karim Berdi (and Mir Karim Berdi's exact 1453 holding in
  Turpan) are uncertain (`?`).
- **Kara Del / Hami (`KDL`):** modelled as a Mahayana Buddhist Ming
  tributary under Dawadashiri (r. 1439–1457) with younger brother Buliege
  as heir (owner's pick, 23 Nov 2026). Hami and Turpan in 1453 were in
  religious transition between older Uyghur Mahayana Buddhism and Sunni
  Islam; pops reflect this mix. Dunhuang (evacuated by the Ming Shazhou
  Guard in 1446) is assigned to `KDL`, while Yumen forms the Ming Gansu
  frontier link to Jiuquan. Birth years of Budashiri, Dawadashiri, and
  Buliege are approximate (`?`).
- **Shields:** `MGH` keeps its Wikimedia Commons Chagatai banner; `DUG`
  and `KDL` use plain map-colour banners as no 1453 arms exist on
  Wikimedia Commons (owner's pick, 23 Nov 2026).

## Tibet and Bhutan (Phase 20.7, 23 Nov 2026)

- **Phagmodrupa (`PHA`) and Rinpungpa (`RIN`):** Gongma Kunga Lekpa
  (b. 1433, aged 20 in 1453; corrected from 1443 by Claude, 24 Nov 2026) rules Ü from Nedong while his father Sangye
  Gyaltsen resides at Tsetang (d. 1457); Norzang of Rinpungpa (1403–1466)
  rules Tsang as a powerful `PHA` vassal (owner's pick, 23 Nov 2026).
  Birth years of Dzompama and Tsokye Dorje are approximate (`?`).
- **Western Tibet (`GUG`, `GNT`, `LDK`):** Tri Lhawang Gyaltsen
  (1404–1464) rules Mangyül Gungthang (including allied Mustang); Lodrö
  Chokden rules Ladakh ahead of Lhachen Bhagan's c. 1460 Namgyal coup.
  Exact 1453 reign dates of Tri Namgyal De of Guge and birth years of
  Lobzang Rabten, Tri Namgyal De of Gungthang, Lodrö Chokden, and Lhachen
  Bhagan are uncertain (`?`).
- **Eastern Tibet (`DRG`, `AMD`) and Ming Xining:** Derge under Botar
  Tashi Senge (patron of Tangtong Gyalpo's 1448 monastery) represents the
  Kham principalities; `AMD` represents the Amdo/Tsongkha tribes and
  monasteries around Rebkong and Kokonor, with Ming holding the frontier
  garrison of `Xining` (*Xining Wei*). Birth years of Botar Tashi Senge
  and Amdo's 1453 chief (`Sonam Gyaltsen`) are uncertain (`?`).
- **Bhutan and Sikkim (`BHU`):** in 1453 Bhutan was a cluster of Drukpa
  Kagyu and Nyingma valleys rather than a unified state (unified 1616);
  grouped here as `BHU` (theocracy) under 2nd Gyalwang Drukpa Kunga
  Paljor (1428–1476), with young Pema Lingpa (b. 1450) in Bumthang.
- **Shields:** `PHA` uses the later-era Tibetan Snow Lion flag, `DRG` the
  historical Derge banner, `BHU` the 1949–1956 Bhutan dragon banner, and
  `LDK` the Ladakh regional banner from Wikimedia Commons; `RIN`, `GUG`,
  `GNT`, and `AMD` use plain map-colour banners where no Commons arms
  exist (owner's pick, 23 Nov 2026).

## Mongols and Oirats (Phase 20.7, 23 Nov 2026)

- **Three-tag 1453 Mongolia (`OIR`, `NYU`, `URI`):** on 30 May 1453 Esen
  Taishi of the Oirats (`OIR`, upgraded from `tribal` to `steppeHorde`,
  capital `Karakorum`) dominated Dzungaria and western/central Mongolia
  after killing Taisun Khan in 1452, months before proclaiming himself
  Great Khan in autumn 1453; the Eastern Mongols / Northern Yuan (`NYU`,
  under Agbarjin Jinong at `Shangdu`, with Kharghuchug, young Markörgis,
  and Manduul) are modelled as a restless `OIR` vassal at `-2` stability;
  and the Uriankhai Three Guards (`URI`: Doyan, Taining, Fuyu) form a
  Ming tributary buffer along the Liaodong–Mongolia frontier (owner's
  pick, 23 Nov 2026).
- **Doubtful dates and chiefs:** birth years of Togon Taishi, Amasanj,
  Öshtömör, Alag Chingsang, and Kharghuchug are approximate (`?`), as is
  the 1453 Uriankhai Three Guards chief (`Toqto'a of Doyan`). The exact
  month of Esen's banquet purge of Agbarjin in 1453 is uncertain (`?`).
- **Shields:** `OIR` keeps its Wikimedia Commons Dzungar banner; `NYU`
  uses the 1911–1921 Mongol Soyombo banner from Wikimedia Commons; `URI`
  uses a plain map-colour banner where no Commons arms exist (owner's
  pick, 23 Nov 2026).

## Manchuria and the Jurchens (Phase 20.7, 23 Nov 2026)

- **Three Jurchen groups (`JZH`, `HXI`, `WJR`):** modelled along Ming's
  15th-century division into **Jianzhou Jurchens** (`JZH`, Ming
  tributary), **Haixi Jurchens** (`HXI`, Ming tributary), and **Wild
  Jurchens** (`WJR`, independent Amur–Ussuri–Sakhalin tribes after the
  1434 closure of the Ming Nurgan Commission). Jurchen shamanism is
  grouped under `siberian`.
- **Jianzhou leaders:** Li Manzhu (chief of Jianzhou Guard, d. 1467)
  rules `JZH` with son Li Gunaha (d. 1467) as heir, while Aisin Gioro
  Dongshan (`holds:Hetu_Ala`, Jianzhou Left Guard, d. 1466) and his uncle
  Fanca (`holds:Changbai`, Jianzhou Right Guard, d. c. 1458) are modelled
  as internal great vassals. Birth years of Ahachu, Li Manzhu, Li Gunaha,
  Dongshan, and Fanca are approximate (`?`).
- **Haixi and Wild Jurchens:** in 1453 the Haixi and Wild Jurchens were
  divided into dozens of local *weisuo* guard chieftaincies prior to the
  late-16th-century Four Hulun consolidation; `Tala of Haixi` and `Boji
  of Nurgan` are placeholder 1453 chiefs (`?`).
- **Shields:** `JZH` uses the 1601+ Manchu Plain Yellow Banner and `HXI`
  uses the earlier Jurchen Jin banner from Wikimedia Commons; `WJR` uses
  a plain map-colour banner where no Commons arms exist (owner's pick,
  23 Nov 2026).

### Burma and Shan States (Phase 20.7, May 1453)
- **Hanthawaddy Pegu (`PEG`)**: chronicles differ on whether Queen Shin
  Sawbu ascended in 1453 or early 1454 (after the brief 7-month reign of
  Leik Munhtaw). Placed Shin Sawbu on the throne in May 1453 with
  Dhammazedi as heir (owner's pick).
- **Shan States (`MOG`, `HSE`, `HSI`, `KAL`)**: split into four major
  *sawbwa* polities (owner's pick). Mong Mao (`MOG`, rump Mengyang after
  the 1449 Ming campaigns) is a Ming tributary; Hsenwi (`HSE`) and Hsipaw
  (`HSI`) are Ava tributaries; Kale (`KAL`) is an Ava vassal. Exact 1453
  *sawbwa* names and birth years for `HSE`, `HSI`, and `KAL` (and birth
  years for `Si Lufa`, `Si Hongfa`, `Atula Thiri`, `Minye Kyawswa of
  Prome`, `Minkhaung of Toungoo`, and `Mi Pakahtaw`) are approximate (`?`).
- **Toungoo and Prome**: modelled as Ava provinces held by internal great
  vassals (`Minkhaung of Toungoo` and `Minye Kyawswa of Prome`).
- **Shields:** `AVA` uses the Burmese Peacock banner, `PEG` uses the Mon
  Hintha bird banner, and `ARK` uses the Rakhine regional emblem from
  Wikimedia Commons; `MOG`, `HSE`, `HSI`, and `KAL` use plain map-colour
  banners where no 1453 Commons arms exist (owner's pick).

### Siam, Lan Na, Lan Xang, Cambodia, Dai Viet, and Champa (Phase 20.7, May 1453)
- **Ayutthaya's Malay Peninsula tributaries**: `PAT` (Pattani) and `KED`
  (Kedah) are separate tributaries of `AYU`, while `Ligor` (Nakhon Si
  Thammarat) is an `AYU` province held by a great vassal (`Phraya Si
  Thammarat`), alongside `Phitsanulok` held by `Phraya Yutthisthira`
  (owner's pick).
- **Dai Viet (`DAI`)**: Emperor Le Nhan Tong assumed personal rule in
  1453 at age 12 after the regency of Empress Dowager Nguyen Thi Anh;
  his younger half-brother Le Tu Thanh (future Emperor Le Thanh Tong) is
  placed as heir, with eldest half-brother Le Nghi Dan as a court figure.
- **Approximate (`?`) dates**: birth years of `Borommarachathirat III`,
  `Phraya Yutthisthira`, `Phraya Si Thammarat`, `Thao Bunruang`,
  `Narayanaraja I`, `Maha Quy Do`, `Maha Ban La Tra Toan`, `Phaya Tu
  Nakpa` (and exact 1453 Pattani ruler), and `Sulaiman Shah I`.
- **Shields:** `AYU`, `LNA`, `LXA`, `KHM`, `DAI`, and `KED` use
  Wikimedia Commons historical/regional banners; `CHA` and `PAT` use
  plain map-colour banners where no 1453 Commons arms exist (owner's pick).

### Maritime Southeast Asia (Phase 20.7, May 1453)
- **Majapahit vassals**: `BAL` (Bali / Gelgel) is a Majapahit vassal and
  `PLB` (Palembang, under Arya Damar) is a Majapahit tributary, while
  `SUN` (Sunda / Pakuan Pajajaran) is independent in West Java (owner's pick).
- **Off-map spice imports**: lowered off-map `fine_spices` imports at
  `Calicut`, `Kotte`, `Aden`, `Hormuz`, and `Sonargaon` in
  `data/economy/imports.txt` now that Ternate, Tidore, Ambon, and Malacca
  are on the map.
- **Approximate (`?`) dates**: birth years for most 1453 island rulers
  (`Muzaffar Shah`, `Mansur Shah`, `Tun Perak`, `Abu Zaid`, `Rajasawardhana`,
  `Girishawardhana`, `Susuk Tunggal`, `Dalem Ketut Ngulesir`, `Sulaiman of
  Brunei`, `Sharif ul-Hashim`, `Tunatangka Lopi`, `Marhum of Ternate`),
  and exact 1453 rulers for `ACE`, `PGR`, `TND`, `CEB`, `MGN`, and `TID`.
- **Shields:** `MAJ`, `MLC`, `BNI`, `SUL`, `TER`, `TID`, `ACE`, and
  `PGR` use Wikimedia Commons historical/regional banners; `PSA`, `PLB`,
  `SUN`, `BAL`, `TND`, `CEB`, `MGN`, and `MKS` use plain map-colour
  banners where no 1453 Commons arms exist (owner's pick).

### West Africa, Sahel, and Guinea Coast (Phase 20.7, May 1453)
- **Timbuktu and Walata (`TRG`)**: held by an independent Tuareg
  sultanate under `Akil ag Malwal` (captured from Mali c. 1433), with
  Mali (`MAL`) centered on Niani/Bambuk/Jenne/Kaabu and Songhai (`SON`)
  at Gao under `Sulaiman Dama` with `Sonni Ali` as heir (owner's pick).
- **Off-map gold imports**: lowered off-map `gold` imports at `Fez`,
  `Tunis`, and `Cairo` in `data/economy/imports.txt` now that Bambuk,
  Upper Niger, and Akan goldfields are on the map.
- **Approximate (`?`) dates**: birth years for all 1453 Sahel/Guinea
  rulers and exact 1453 rulers for `YAT`, `ZAZ`, `BUL`, `DFR`, and `NUP`.
- **Shields:** `MAL`, `BEN`, and `KBO` use verified Wikimedia Commons
  banners; remaining West African tags use plain map-colour banners where
  no 1453 Commons arms exist (owner's pick).

### East Africa, Great Lakes, and Swahili Coast (Phase 20.7, May 1453)
- **Swahili Coast (`KIL`, `MBA`, `MLD`)**: Kilwa Sultanate (`Sultan
  Sulaiman al-Malik al-Adil`, r. 1442–1454) holds Kilwa, Zanzibar,
  Mozambique, Angoche, Quelimane, Sofala, Inhambane, and Comoros, with
  independent Mombasa and Malindi alongside existing Pate (owner's pick).
- **Off-map ivory and gold imports**: lowered off-map imports at
  `Mogadishu`, `Aden`, and `Cairo` in `data/economy/imports.txt` now that
  Kilwa and Sofala are on the map.
- **Approximate (`?`) dates**: birth years for 1453 East African rulers
  (`Sulaiman`, `Wamara`, `Kiggala`, `Mibambwe I Mutabazi`, `Nyikang`),
  and exact 1453 rulers for `MBA`, `MLD`, `BRD`, and `ORO`.
- **Shields:** `BGD` and `KIL` use verified Wikimedia Commons banners;
  remaining East African tags use plain map-colour banners (owner's pick).

### Central Africa, Southern Africa, and Madagascar (Phase 20.7, May 1453)
- **Southern Africa**: Kalahari and Namib kept as permanent wasteland in
  `data/map/provinces/09_wasteland.txt`; habitable lands south of Mutapa
  and Butua populated with Sotho-Tswana (`SOT`), Nguni (`NGU`), and
  Khoikhoi (`KHO`) down to the Cape of Good Hope (owner's pick).
- **Mutapa and Great Zimbabwe**: `MTP` under `Matope Nyanhehwe Nebedza`
  (r. c. 1450–1480) holds Mount Fura, Great Zimbabwe, Tete, Manyika, and
  Maravi, with Torwa Butua (`BTW`) at Khami and Mapungubwe.
- **Approximate (`?`) dates**: birth years for `Nkuwu a Ntinu`, `Nzinga
  a Nkuwu`, `Matope`, `Nyahuma`, and exact 1453 rulers for `LOA`, `NDG`,
  `TIO`, `LBA`, `LND`, `BTW`, `SOT`, `NGU`, `KHO`, `MER`, `SAK`, `ANT`,
  and `BTS`.
- **Shields:** `KON` and `MER` use verified Wikimedia Commons banners;
  remaining tags use plain map-colour banners (owner's pick).

### Siberia (Phase 20.7, May 1453)
- **Khanate of Sibir (`SIB`)**: Starts independent at `Qashliq` (Isker)
  under Taibugid Khan `Mar`, holding `Chimgi-Tura` (Tyumen), `Ishim`,
  `Qashliq`, `Tara`, `Baraba`, and `Kulunda` (owner's pick; `Chimgi-Tura`
  and `Ishim` moved from `UZB` to `SIB`, with Shaybanid prince `Ibak`
  present as a court figure).
- **Arctic tundra and deep taiga**: High-latitude Arctic tundra and
  mountain ranges (Yamal, Taz, Taimyr, Putorana, Verkhoyansk, Indigirka,
  Kolyma, Stanovoy, Dzhugdzhur) are kept as permanent wasteland in
  `data/map/provinces/09_wasteland.txt`, while the Ob, Irtysh, Yenisei,
  Baikal, and Middle Lena basins are populated (`SIB`, `PEL`, `KOD`,
  `BYA`, `EVK`, `YAK`, plus `Minusinsk` under `OIR`).
- **Approximate (`?`) dates and invented 1453 figures**: Birth years are
  approximate for `Mar`, `Obder`, `Abalak`, `Ibak`, `Asyka` (recorded
  leading Pelym raids on Perm in 1455), `Yumshan`, and `Moldan` (recorded
  in 1483 chronicles). No dated 1453 personal names are recorded for the
  Buryats, Evenks, or Sakha/Yakuts; `BYA` (`Barga Baatar`/`Khoridoi`) and
  `YAK` (`Omogoi Baai`/`Elley Bootur`) use traditional clan-ancestor
  names, and `EVK` (`Toron`/`Amakan`) are invented 1453 chiefs.
- **Shields:** `SIB` uses `File:Flag of Siberian Khanate.svg` from
  Wikimedia Commons; `PEL`, `KOD`, `BYA`, `EVK`, and `YAK` use plain
  map-colour banners (owner's pick).
### HRE & Alps Detail (Phase 20.7 Part III, May 1453)
- **New independent HRE tags (8)**: `ANH` (Anhalt-Dessau under George I),
  `OSN` (Osnabrück & Minden under Albert of Hoya), `PAD` (Paderborn in
  personal union under Archbishop Dietrich II of Moers of Cologne `CLN`),
  `FLD` (Prince-Abbey of Fulda under Reinhard von Weilnau), `NAS`
  (Nassau-Wiesbaden under John II), `KNZ` (Prince-Bishopric of Konstanz
  under Heinrich von Hewen), `LAU` (Saxe-Lauenburg under Bernard II), and
  `HLD` (Prince-Bishopric of Hildesheim under Bernhard II of
  Brunswick-Lüneburg) (owner's pick).
- **Lower Lusatia (`Lubben`)**: Assigned to `BRA` (Elector Frederick II
  of Brandenburg held the Lower Lusatian *Landvogtei* pledge from 1448
  until the Peace of Guben in 1462, per `MAP_EXPANSION_RESEARCH.md`
  review note #1).
- **Silesian duchies**: Added `Cieszyn` (Teschen), `Oswiecim`, `Olesnica`
  (Oels), and `Zagan` (Sagan) as `BOH` provinces held by real 1453 Piast
  dukes (`Przemyslaus II`, `Jan IV`, `Conrad IX`, `Balthasar`) as
  internal `BOH` great vassals (matching Opole).
- **Approximate (`?`) birth years**: Birth years are approximate for
  `George I of Anhalt-Dessau`, `Albert of Hoya`, `Reinhard von Weilnau`,
  `Heinrich von Hewen`, `Bernard II of Saxe-Lauenburg`, `Bernhard II of
  Hildesheim`, and the four Silesian Piast dukes.
