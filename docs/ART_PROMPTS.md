# Gez: painting prompts (Phase 20)

Paintings the owner makes in the free Gemini app. One prompt per picture.
Written 22 Nov 2026 for Phase 20 (main menu, loading screen, the 70 events
of Phase 14, and 29 painted portraits). Phase 21 will add mission
pictures at the end of this file.

## How to make one

1. In the Gemini app, paste **the style line** and then the picture's
   prompt, as one message.
2. Download the picture (PNG or JPG are both fine) and rename it to the
   **file name** given (lower case, exactly as written).
3. Drop it in the folder below. That is all: the game shows it the next
   time it starts. Until then it shows a plain parchment placeholder.

**Folder:** `godot/assets/paintings/` in the game folder on your Mac
(`~/Developer/Gez/godot/assets/paintings/`), in the sub-folder given
(`menu/`, `events/` or `portraits/`). You can also just attach the
pictures in a chat with Claude, and Claude will put them in the repo so
everyone's copy gets them.

**Sizes:** the game only cares about the shape, not the exact pixels.
- **Wide** = landscape 16:9 (for example 1344 × 768 or larger).
- **Tall** = portrait 3:4 (for example 896 × 1152 or larger).

If Gemini makes a square picture, add "wide 16:9 landscape" or "tall 3:4
portrait" at the end of the message and ask again.

## The style line (paste before every prompt)

```
Oil painting in the style of a 15th-century master (Flemish and Italian
panel painting, Persian and Indian court painting where the subject is
from there), rich glazes, warm natural light, historically accurate
costume, armour and buildings of the 1450s–1520s. No text, no letters,
no signatures, no frames, no borders, no modern objects.
```

---

## Main menu and loading screen (folder `menu/`)

| File | Shape | Prompt |
|---|---|---|
| `main_menu.png` | Wide | Constantinople in 1453 seen from the hills of Galata at golden dawn: the Golden Horn in front, crowded with Ottoman galleys and merchant ships; across the water the domes of Hagia Sophia and the city's churches, the sea walls and the long Theodosian land walls on the left, smoke still rising from a few towers. Calm sea, soft mist, a great sky. Keep the left third of the picture quiet (sky and water) so menu buttons can sit there. |
| `loading.png` | Wide | The Theodosian land walls of Constantinople during the siege of 1453, seen from the Ottoman camp: rows of tents and banners, Janissaries, a great bronze bombard on a wooden cradle firing with a cloud of white smoke, the triple walls and towers of the city beyond, evening light. |

---

## Event pictures (folder `events/`, all **Wide**)

The file name is the event's name. Four events share a picture with
another (marked "uses …"), so there are 66 pictures for 70 events. Keep
the main subject in the middle: the top and bottom may be trimmed to fit
the pop-up.

### Iberia and Western Europe

| File | Prompt |
|---|---|
| `hist_end_hundred_years_war_fra.png` | The Battle of Castillon, 1453: French cannon in earthwork trenches firing on charging English knights under the banners of John Talbot, smoke over a river meadow in Gascony, French men-at-arms with fleur-de-lis banners. |
| `hist_end_hundred_years_war_eng.png` | King Henry VI of England, young and pale in dark robes, sitting downcast at Westminster as a weary messenger kneels with news from Gascony; worried lords whisper behind him in a stone hall. |
| `hist_wars_of_the_roses.png` | Two armies of English knights in plate armour clashing in a misty field, one side under red-rose banners, the other under white-rose banners, longbowmen behind them. |
| `hist_louis_xi_pragmatic.png` | King Louis XI of France, a shrewd man in a plain dark coat and felt hat with small lead pilgrim badges, at a table with clerks sealing royal ordinances by candlelight. |
| `hist_league_public_weal.png` | French dukes and lords in rich armour and furs gathering in a war camp, the Burgundian red saltire banner among theirs, swearing an oath together over a sword. |
| `hist_nancy_charles_bold.png` | Duke Charles the Bold of Burgundy in gilded armour on a warhorse leading his army through snow before the walls of Nancy, Swiss pikemen waiting at the edge of a frozen wood. |
| `hist_burgundian_inheritance.png` | A young Burgundian duchess, Mary of Burgundy, in a rich gown standing between French envoys and Habsburg envoys in a Flemish council chamber with tall windows and tapestries. |
| `hist_henry_navigator_guinea.png` | Two Portuguese caravels with lateen sails and red crosses sailing past the cliffs of the West African coast, Prince Henry the Navigator in a dark hat watching from a headland at Sagres. |
| `hist_union_of_crowns_iberia.png` | The secret wedding of young Isabella of Castile and Ferdinand of Aragon in a candlelit palace chapel in Valladolid, a priest joining their hands, a few nobles as witnesses. |
| `hist_castilian_succession_war.png` | Castilian and Portuguese knights fighting on the dry plains of the meseta near Toro, banners of castles and lions against Portuguese shields, a stone town on a hill. |
| `hist_spanish_inquisition.png` | A solemn tribunal of Dominican friars in black and white habits seated at a long table under a crucifix in a dim Spanish hall, a royal envoy presenting a sealed papal letter. |
| `hist_fall_of_granada_war.png` | A Castilian army camp below the red walls of the Alhambra and the snowy Sierra Nevada, knights, crossbowmen and bombards, the green banner of Granada on the towers. |
| `hist_fall_of_granada_conquered.png` | The last Nasrid emir handing the keys of the Alhambra to the Castilian king and queen on horseback, Moorish courtiers in white robes, Castilian knights with banners, the red palace behind. |
| `hist_columbus_portugal.png` | A Genoese mariner, Christopher Columbus, unrolling a sea chart before the King of Portugal and sceptical learned advisers in a Lisbon palace hall, a globe and astrolabe on the table. |
| `hist_columbus_castile.png` | Christopher Columbus pleading his case before Queen Isabella and King Ferdinand at a Castilian court, pointing at a chart of the western ocean, friars and courtiers listening. (Also used by `hist_columbus_fallback`.) |
| `hist_treaty_of_tordesillas.png` | Castilian and Portuguese envoys at a long table signing a treaty, a large map of the Atlantic with a single line drawn down the ocean, a papal legate in red blessing it. |
| `hist_vasco_da_gama_calicut.png` | Portuguese carracks anchored off the palm-lined shore of Calicut in India, Vasco da Gama stepping from a rowing boat to meet the Zamorin's officials in white cotton, merchants and elephants on the beach. |

### Central Europe, Italy and the North

| File | Prompt |
|---|---|
| `hist_peace_of_lodi.png` | Envoys of Milan, Venice and Florence in rich Italian Renaissance dress clasping hands around a table in a frescoed hall, a treaty with wax seals before them. |
| `hist_printing_press_mainz.png` | A German print shop in the 1460s: craftsmen working a wooden screw press, setting metal type and hanging freshly printed pages to dry, a burning town glimpsed through the window. |
| `hist_ladislaus_death_1457.png` | The deathbed of the young King Ladislaus V, a pale seventeen-year-old in a canopied bed in a Prague palace, physicians and grieving nobles around him, a wedding gown laid aside on a chest. |
| `hist_matthias_corvinus_black_army.png` | King Matthias Corvinus of Hungary reviewing his Black Army of mercenaries in dark armour, handgunners, pikemen and hussars, black banners with a raven, on a plain near Buda. |
| `hist_podebrady_bohemia.png` | George of Poděbrady being acclaimed king by Bohemian lords in the Old Town Hall of Prague, Utraquist priests holding a chalice, townsmen cheering. |
| `hist_alfonso_magnanimous_death.png` | The funeral of King Alfonso V of Aragon in Naples, a catafalque draped in red and gold under a vaulted cathedral, his brother and his son Ferrante standing on opposite sides. |
| `hist_medici_golden_age.png` | Lorenzo de' Medici among artists, scholars and bankers in a Florentine palace courtyard, an unfinished marble statue, painters at work, the dome of Florence cathedral against a blue sky. |
| `hist_pazzi_conspiracy.png` | Conspirators with daggers attacking the Medici brothers during High Mass in Florence cathedral, worshippers fleeing, candles and incense smoke under the great dome. |
| `hist_savonarola_bonfire.png` | The friar Savonarola in a black Dominican habit preaching beside a huge bonfire in the Piazza della Signoria of Florence, citizens throwing books, mirrors and paintings into the flames. |
| `hist_thirteen_years_war_thorn.png` | Burghers and knights of the Prussian towns before the brick walls of Thorn on the Vistula, offering homage to the King of Poland, the black cross of the Teutonic Order on a toppled banner. |
| `hist_venetian_ottoman_negroponte.png` | Venetian war galleys with the lion of Saint Mark fighting Ottoman galleys off the walled island town of Negroponte, cannon smoke over the Aegean, a bridge to the mainland. |
| `hist_italian_wars_charles8.png` | A French royal army crossing an Alpine pass with heavy bronze cannon on carriages, knights with fleur-de-lis banners, Swiss pikemen, snowy peaks above Italy. |
| `hist_stockholm_bloodbath.png` | A grim winter square in Stockholm before a castle, Danish soldiers holding back crowds while Swedish nobles and bishops are led out under guard, dark sky, snow. |
| `hist_luther_95_theses.png` | A young Augustinian friar, Martin Luther, nailing a sheet of paper to the wooden door of the castle church in Wittenberg, townsfolk and students gathering to read it. (Also used by `hist_luther_95_theses_alt`.) |
| `hist_diet_of_worms.png` | Martin Luther standing before the young Emperor Charles V and the princes of the Empire in a crowded hall at Worms, a table piled with his books, churchmen in red. |

### The Balkans, the East and Russia

| File | Prompt |
|---|---|
| `hist_belgrade_1456_hun.png` | The siege of Belgrade, 1456: the fortress on its hill above the meeting of the Danube and Sava, Hungarian defenders and crusaders with crosses led by John Hunyadi and a friar holding a cross aloft, Ottoman river galleys burning below. |
| `hist_belgrade_1456_alt.png` | Ottoman engineers and soldiers rebuilding the walls of Belgrade above the Danube and Sava under crescent banners, river boats unloading timber and stone. |
| `hist_skanderbeg_lezhe.png` | Skanderbeg, a bearded Albanian lord in armour with a goat-horned helmet, leading mountain warriors in an ambush from rocky heights above a narrow pass, a stone castle on a crag behind. |
| `hist_trebizond_1461.png` | The Ottoman army and fleet arriving before Trebizond, a walled Greek city between green mountains and the Black Sea, the last Komnenian emperor watching from the citadel. (Also used by `hist_trebizond_legacy_alt`.) |
| `hist_otranto_1480_nap.png` | Ottoman soldiers storming ashore from galleys at Otranto in southern Italy, the walled coastal town and castle under attack, smoke over the white houses and the blue Adriatic. (Also used by `hist_otranto_1480_alt`.) |
| `hist_mehmed_kanunname.png` | Sultan Mehmed II enthroned in a newly built palace pavilion at Constantinople, viziers and scholars presenting books of law, the domes of the city and the Bosphorus beyond. |
| `hist_cem_sultan_crisis.png` | Prince Cem, a young Ottoman prince in a turban, stepping aboard a ship of the Knights of Rhodes at night, loyal followers on the shore with torches, the island fortress ahead. |
| `hist_vlad_targoviste_1462.png` | A night attack: Wallachian horsemen with torches charging through the Ottoman camp, tents on fire, Janissaries scrambling for arms, Voivode Vlad III in a fur hat at their head. |
| `hist_stephen_vaslui_1475.png` | Stephen the Great of Moldavia on horseback directing his soldiers in a foggy marsh by a wooden bridge, an Ottoman army trapped in the mist, horns blowing from the woods. |
| `hist_knights_rhodes_1480.png` | The great siege of Rhodes: Ottoman sails filling the sea before the harbour fortress, the Knights Hospitaller in red surcoats with white crosses defending the walls, the Grand Master directing them. |
| `hist_fall_of_kaffa_1475.png` | Ottoman war galleys arriving before the Genoese walled port of Kaffa in Crimea, Genoese merchants on the walls, Tatar horsemen watching from the steppe hills. |
| `hist_novgorod_annexation.png` | The great bell of Novgorod being lowered from its tower by Muscovite soldiers, merchants and boyars of the city watching in sorrow, the Saint Sophia cathedral and the Volkhov river behind. |
| `hist_stand_on_the_ugra.png` | Two armies facing each other across the Ugra river in autumn: Muscovite soldiers with cannon and handguns on one bank, Tatar horse archers of the Great Horde on the other, Grand Prince Ivan III on a hill. |
| `hist_ottoman_mamluk_marj_dabiq.png` | Ottoman Janissaries with muskets and cannon behind chained wagons facing a charge of Mamluk cavalry in shining mail on a plain in northern Syria, banners of both sides. |

### Persia, India and Africa

| File | Prompt |
|---|---|
| `hist_uzun_hasan_otlukbeli.png` | Uzun Hasan, a tall Turkmen ruler in a tall cap, receiving Venetian envoys who bring cannon in his tent camp in the highlands of eastern Anatolia, white sheep banners, horsemen behind. Persian court painting style. |
| `hist_safaviyya_ardabil.png` | Sufi warriors in red twelve-gored caps gathered around their shaykh in the courtyard of the shrine of Ardabil, a domed tomb tower with blue tiles, swords and prayer beads. Persian court painting style. |
| `hist_safavid_rise_1501.png` | Young Shah Ismail, about fourteen, entering Tabriz on horseback with Qizilbash warriors in red caps, crowds and blue-tiled mosques of the city. Persian court painting style. |
| `hist_chaldiran_1514.png` | The battle of Chaldiran: Ottoman cannon and Janissaries behind chained carts firing on charging Safavid cavalry in red caps across a high plain, mountains behind. |
| `hist_uzbek_transoxiana.png` | Uzbek horsemen under Muhammad Shaybani Khan riding toward Samarkand, the turquoise domes of the city on the horizon across the Zarafshan valley. Persian court painting style. |
| `hist_babur_kabul_1504.png` | Young Babur and his small band of horsemen crossing a snowy pass of the Hindu Kush and looking down on the walled town of Kabul in a green valley. Mughal miniature style. |
| `hist_babur_panipat_1526.png` | The First Battle of Panipat: Babur's cannon and matchlockmen behind lashed carts firing on the war elephants and cavalry of the Delhi sultan on a dusty plain. Mughal miniature style. |
| `hist_mamluk_qaitbay_monopoly.png` | Sultan Qaitbay in Cairo inspecting bales of pepper and spices brought by Red Sea merchants in a busy caravanserai, a tall stone minaret and dome behind. |
| `hist_chaul_diu_1509.png` | A sea battle off the Indian coast: Mamluk and Gujarati galleys fighting Portuguese carracks, cannon smoke, the walled port of Diu on the shore. |
| `hist_bahlul_lodi_delhi.png` | Sultan Bahlul Lodi with Afghan horsemen in steel helmets riding out of the gates of Delhi, domed tombs and the old Qutb minaret behind. Indian court painting style. |
| `hist_rana_kumbha_chittor.png` | Rana Kumbha of Mewar before the newly built tower of victory at Chittor, a tall carved stone tower on a fortress hill, musicians and Rajput warriors around him. Rajput painting style. |
| `hist_mahmud_begada_gujarat.png` | Sultan Mahmud Begada, with a long beard and moustache, leading his army up to the hill fortress of Champaner, war elephants and banners, the Gulf of Cambay in the distance. Indian court painting style. |
| `hist_krishnadevaraya_vijayanagara.png` | Emperor Krishnadevaraya enthroned in the stone halls of Vijayanagara among poets and musicians, carved temple towers and boulder hills behind, Arabian horses being presented. South Indian painting style. |
| `hist_husain_shahi_bengal.png` | Sultan Husain Shah of Bengal in a terracotta brick mosque courtyard among scholars, river boats on the Ganges delta, weavers with fine muslin. Indian court painting style. |
| `hist_zara_yaqob_debre_berhan.png` | Emperor Zara Yaqob of Ethiopia seated under a canopy among bishops and monks in white with processional crosses, a church on a green highland. Ethiopian church painting style. |
| `hist_ahmad_gragn_adal.png` | Imam Ahmad ibn Ibrahim raising a banner before Somali and Harari warriors with matchlocks and spears in a dry highland, the walled town of Harar behind. |

### Chronicle pop-ups (any country, any year)

These four appear for every country, so keep them general (no flags or
famous faces).

| File | Prompt |
|---|---|
| `chronicle_rebel_rising.png` | Peasants and townsmen with pitchforks, scythes, spears and crude banners marching out of a burning village at dusk, an angry crowd under a stormy sky. |
| `chronicle_vassal_plot_success.png` | A great noble slumped over a banquet table after drinking from a gold cup, guests rising in horror, a shadowy figure slipping out of a door in a candlelit hall. |
| `chronicle_vassal_plot_uncovered.png` | A spymaster in dark robes laying intercepted letters with broken wax seals and a small glass phial on a table before a stern ruler, by candlelight. |
| `chronicle_ruler_death.png` | A new ruler being crowned in a dim cathedral, the old ruler's funeral bier with candles in the background, nobles, clergy and burghers kneeling. |

---

## Painted portraits (folder `portraits/`, all **Tall**)

Head-and-shoulders portraits, three-quarter view, plain dark background,
as a court painter of 1453 would have made them. The file name is the
person's name in the game. Everyone else gets a portrait from our own
generator (part 3), so these 29 are all that is needed.

| File | Who | Prompt |
|---|---|---|
| `mehmed2.png` | Ottoman sultan, 21 | Sultan Mehmed II at 21: a young man with a thin beard, a strong hooked nose, a large white turban with a red cap, a fur-lined kaftan of gold brocade, holding a rose. |
| `ladislaus5.png` | King of Hungary and Bohemia, Duke of Austria, 13 | King Ladislaus V at 13: a slim fair-haired boy with a pale face, a gold crown on long hair, red and gold robes trimmed with ermine. |
| `hunyadi.png` | Hungarian captain-general, 47 | John Hunyadi at 47: a weathered Hungarian warlord with a long moustache, plate armour under a fur-lined cloak, a raven badge. |
| `frederick3.png` | Holy Roman Emperor, 37 | Emperor Frederick III at 37: a long face, shoulder-length hair, an imperial mitre-crown, a rich brocade mantle, a calm patient look. |
| `charles7.png` | King of France, 50 | King Charles VII of France at 50: a long melancholy face, a heavy nose, a tall dark felt hat, a red velvet coat with fur, as in Jean Fouquet's style. |
| `henry6.png` | King of England, 31 | King Henry VI of England at 31: a gentle, pale, beardless face, a simple black hat, a dark robe with a gold collar, hands joined as in prayer. |
| `philip_good.png` | Duke of Burgundy, 56 | Duke Philip the Good of Burgundy at 56: a long face, short cropped hair, dressed all in black with the gold Order of the Golden Fleece collar, in the style of Rogier van der Weyden. |
| `alfonso5.png` | King of Aragon and Naples, 57 | King Alfonso V the Magnanimous at 57: clean-shaven with short grey hair, a scholar-king in dark armour with a red mantle, a book beside him. |
| `john2_c2.png` | King of Castile, 48 | King John II of Castile at 48: a tall fair man with a short beard, a gold crown, a rich red and gold Castilian robe with castles and lions. |
| `afonso5_p.png` | King of Portugal, 21 | King Afonso V of Portugal at 21: a young man with a dark beard and long dark hair, plate armour, a red mantle, a gold chain. |
| `f_sforza.png` | Duke of Milan, 52 | Duke Francesco Sforza at 52: a broad strong face, short hair, a soldier's neck, a red cap and a dark brocade doublet, in profile as in Italian portraits. |
| `foscari.png` | Doge of Venice, 80 | Doge Francesco Foscari at 80: an old man with a hooked nose in the gold doge's horned cap (corno) and a gold brocade mantle. |
| `cosimo.png` | Ruler of Florence, 64 | Cosimo de' Medici at 64: a shrewd elderly banker with a long nose, a red cap and a red robe, in profile. |
| `nicholas5.png` | Pope, 55 | Pope Nicholas V at 55: a clean-shaven scholarly churchman in a white and gold papal tiara and a red cope, holding a book. |
| `casimir4.png` | King of Poland, Grand Duke of Lithuania, 25 | King Casimir IV Jagiellon at 25: a young man with long brown hair, a gold crown, a fur cloak over a red robe, a serious face. |
| `christian1.png` | King of Denmark and Norway, 27 | King Christian I of Denmark at 27: a tall young man with a short beard, a gold crown, a blue and red robe trimmed with fur. |
| `vasily2.png` | Grand Prince of Moscow, 38 | Grand Prince Vasily II the Blind of Moscow at 38: a bearded Russian prince with closed, blinded eyes, a fur-trimmed Monomakh cap, a rich brocade robe, painted like a Russian icon. |
| `skanderbeg.png` | Lord of Albania, 48 | Skanderbeg at 48: a long grey-black beard, a stern face, a steel helmet topped with a goat's head and horns, armour under a red cloak. |
| `durad.png` | Despot of Serbia, 76 | Despot Đurađ Branković at 76: an old Serbian ruler with a long white beard, a Byzantine-style crown, a heavy brocade robe, painted like a Serbian fresco. |
| `james2_s.png` | King of Scots, 22 | King James II of Scotland at 22: a young man with a bright red birthmark across one side of his face, a gold crown, a red and gold robe. |
| `karl8.png` | King of Sweden, 44 | King Charles VIII Knutsson of Sweden at 44: a fair-bearded Scandinavian king with a gold crown, a blue robe with fur, a sword. |
| `inal.png` | Mamluk sultan of Egypt, 72 | Sultan Inal at 72: an old Mamluk sultan with a white beard, a large white turban with horn-like folds, a silk robe, in the style of Cairo court painting. |
| `uzun_hasan.png` | Lord of the Aq Qoyunlu, 30 | Uzun Hasan at 30: a tall Turkmen chief with a black beard and moustache, a tall red Turkmen cap, a patterned silk kaftan. Persian court painting style. |
| `jahan_shah.png` | Lord of the Qara Qoyunlu, 56 | Jahan Shah at 56: a Turkmen ruler with a greying beard, a jewelled turban, a rich blue silk robe, holding a book of poetry. Persian court painting style. |
| `abu_said.png` | Timurid sultan at Samarkand, 29 | Abu Sa'id Mirza at 29: a Timurid prince with a dark beard, a white turban, a fur-collared robe, a bow at his side. Persian court painting style. |
| `bahlul.png` | Sultan of Delhi, 52 | Sultan Bahlul Lodi at 52: an Afghan ruler with a full black beard, a white turban, a plain white robe and a sword. Indian court painting style. |
| `mahmud_kh.png` | Sultan of Malwa, 49 | Sultan Mahmud Khalji of Malwa at 49: a strong-faced ruler with a short beard, a jewelled turban, a gold-embroidered robe. Indian court painting style. |
| `kumbha.png` | Rana of Mewar, 36 | Rana Kumbha of Mewar at 36: a Rajput king with a curled moustache, a jewelled turban, pearl necklaces, a white jama. Rajput painting style. |
| `zara_yaqob.png` | Emperor of Ethiopia, 54 | Emperor Zara Yaqob of Ethiopia at 54: a dignified ruler with a short beard, a gold crown, white robes, holding a hand cross. Ethiopian painting style. |
