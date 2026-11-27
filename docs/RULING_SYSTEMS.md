# Ruling systems and formables: guide for Gemini (Phase 20.8)

Claude wrote the shared engine (PR #70, 26 Nov 2026). **Gemini builds
everything on top**: regional flavour, formables, the HRE and the other
ruling systems. This page says where things go, what a system may and may
not change, how it is saved, and which tests it needs.

Order (owner, 26 Nov 2026): **HRE first, then the Shogunate**, then Mandate
of Heaven and the tributary order, Sejm and royal elections, kurultai,
mandala rings. Formables and data-only flavour can go in between.

## 1. What the engine gives you

| File | What it is |
|---|---|
| `Packages/GezCore/Sources/GezCore/Rulings/Rulings.swift` | Data (`RulingSystemDef`, `FormableDef`, `RulingRules`) and saved state (`RulingSystemState`, `RulingState`) |
| `Rulings/RulingEngine.swift` | The `RulingSystem` protocol (hooks), the `RulingSystems.builtIn` list, and `RulingEngine`: roles, values, flags, effects, elections, event words |
| `Rulings/FormableSystem.swift` | Forming a nation in place, AI forming, the offer pop-up for players |
| `Scenario/RulingLoader.swift` | Reads `Resources/rulings1453.json` |
| `tools/rulings/rulinggen.py` | Builds that JSON from `data/rulings/` and checks it |
| `data/rulings/systems/hre.txt` | Starter HRE: emperor, 7 electors, free cities (no rules yet) |
| `data/rulings/formables/01_iberia.txt` | Worked example: Spain (`ai = false`) |

A ruling system is **data first**: members, roles, numbers and role
effects in a text file. Rules that data cannot express (elections,
authority that grows and falls, tribute) go in **one Swift file per
system** that implements the hooks it needs.

Where the engine hooks into the game (already wired, do not move):
- Monthly: `RulingEngine.runMonthly` right before `GovernmentSystem`
  (members who lost all land leave first, then each system's
  `runMonthly` in data order, then formables).
- Yearly: `RulingEngine.runYearly` after `VassalSystem.runYearly`.
- Every succession: `rulerChanged` (from `CharacterSystem.succeed`).
- Every government refresh: role effects + `addEffects`
  (from `GovernmentSystem.refreshEffects`).
- Saves: the whole `RulingState` (`SaveSnapshot.rulings`).

## 2. Where a new system goes

For a system with key `shogunate`:
1. **Data:** `data/rulings/systems/shogunate.txt` (format in §4).
2. **Swift:** `Packages/GezCore/Sources/GezCore/Rulings/Systems/ShogunateSystem.swift`:
   ```swift
   enum ShogunateSystem: RulingSystem {
       static let key = "shogunate"
       static func runMonthly(_ world: inout World, date: GameDate, random: inout GameRandom) { ... }
       static func rulerChanged(_ world: inout World, country: CountryID, oldRuler: CharacterID?,
                                newRuler: CharacterID, date: GameDate, random: inout GameRandom) { ... }
   }
   ```
3. **Register it:** add `ShogunateSystem.self` to `RulingSystems.builtIn`
   in `RulingEngine.swift` (that one line is the only engine edit a system
   may make).
4. **Events:** `data/events/NN_shogunate.txt`, using the words in §5.
5. **Tests:** `Packages/GezCore/Tests/GezCoreTests/ShogunateSystemTests.swift` (§7).
6. Run `python3 tools/rulings/rulinggen.py`, then `python3 tools/events/eventgen.py`;
   commit the data, the JSON and the code.
7. Document the rules and numbers in `docs/DESIGN.md` (a "Ruling systems"
   section per system) and doubtful history in `docs/HISTORY_NOTES.md`.

Hooks (all optional; defaults do nothing): `start` (new game only),
`runMonthly`, `runYearly`, `rulerChanged`, `countryVanished`,
`countryFormed`, `addEffects`. They run only while the system is active
and in the data.

## 3. What a system may and may not change

**May:**
- Its own state through `RulingEngine`: `join`, `leave`, `addRole`,
  `removeRole`, `setLeader`, `setValue`/`addValue`,
  `setCountryValue`/`addCountryValue`, `setFlag`, `modify` (for `stage`
  and anything else in `RulingSystemState`), `dissolve`.
- Read anything in `World`.
- Change the game through existing public calls: stability
  (`GovernmentSystem.changeStability`), events (`EventSystem.trigger` for
  `triggered_only` events in `data/events/`), effects
  (`EventSystem.apply`), opinions, subjects (`overlord`/`subjectType`),
  prestige, treasury, forming (`FormableSystem.form`).
- Give modifiers: role effects in the data, or `addEffects` in Swift
  (keep it cheap: it runs on every refresh of every member).
- Read its constants with `RulingEngine.param(world, key, name)`.
- Hold elections with `RulingEngine.elect` (deterministic; ties by
  total score, then candidate order).

**May not** (these are the shared engine: label the PR `needs-claude`):
- Edit `Rulings.swift`, `RulingEngine.swift` (except the `builtIn` line),
  `FormableSystem.swift`, `RulingLoader.swift`, `SaveGame.swift`,
  `Simulation.swift` or the tick order.
- Add fields to `SaveSnapshot` or `RulingState`; keep everything in the
  system's `RulingSystemState` (values, per-country values, flags, stage).
- Add countries, change a tag, or change the length of `CountryTable`.
- Add a `Modifier` case (it changes the saved effects arrays).
- Draw random numbers from anything but the `random` the hook receives
  (it is the ruling stream, kept apart from the main one).
- Decide anything by iterating a `Set` or `Dictionary` (their order
  changes between runs): use `members`, `holders`, or sort first.
- Call another system's Swift type directly; talk through state
  (`RulingEngine.isMember(world, "hre", c)`) so either can be removed.

## 4. Data format

### Systems: `data/rulings/systems/<key>.txt`
```
system hre
name = Holy Roman Empire
leader = HAB                         # optional; the leader is a member
members = SWI, WUR, ...              # plain members
roles = elector, free_city, prince_bishop   # every role name the system uses
role elector = MAI, TRI, CLN, BOH, PAL, SAX, BRA
role free_city = NUR, ULM, AUG
value authority = 20 | 0..100        # system number: start | min..max (range optional)
country_value favour = 0..100        # a number per country (starts at 0)
param elector_count = 7              # fixed constant for the Swift code
provinces = Vienna, Prague           # optional: the system's lands
effect free_city: trade=0.10, tax=0.05
effect leader scaled authority/100: crown_power=0.10, vassal_opinion=10
```
- Role names are lowercase; `member` and `leader` are built in.
  `effect member:` gives every member the modifiers.
- `scaled VALUE/DIV` multiplies the modifiers by value ÷ DIV.
- Modifier names are the `Modifier` keys (same as `add_modifier` in events).

### Formables: `data/rulings/formables/NN_<region>.txt`
```
formable SPA
name = Spain
text = Flavour text for the offer pop-up.
color = 226 186 34
shield = SPA                # picture key, default = the id
eligible = CAS, ARA         # leave out = any country passing the trigger
government = monarchy       # optional switch (reform tree starts over)
reforms = absolute          # optional reform option keys to set
mission_tree = spain        # Phase 21 key, stored per country
ai = true                   # computer countries form it when they can
unique = true               # only one country ever
trigger:
  owns = Toledo
  culture_family = iberian
effect:
  prestige = 20
  add_core = Granada
```
- The id is 2–8 capitals and **never a 1453 tag** (use `GEO_R`, not `GEO`).
- `trigger` and `effect` use the event words (§5); `can_form` and
  `form_nation` are not allowed inside a formable.
- A country that forms keeps its tag: `tag = CAS` events still find
  Spain. Use `is_formed = SPA` for "this country is Spain".
- Computer countries form at most one formable a month (data order).
  Human players get the event pop-up once per formable ("Proclaim X" /
  "Not now").
- **Shields:** add `SPA | File:...svg` to `data/heraldry/choices.txt`
  with the formable id as the tag; the Heraldry workflow fetches it.
  Until then the game shows a plain banner in the new colour.

## 5. Event and mission words

Conditions (`trigger:`, `ai_mod`, `mtth_mod`):
`ruling_active = hre`, `ruling_member = hre`, `not_ruling_member = hre`,
`ruling_leader = hre`, `not_ruling_leader = hre`,
`ruling_role = hre:elector`, `not_ruling_role = hre:elector`,
`ruling_value_min = hre:authority:50`, `ruling_value_max = ...`,
`ruling_country_value_min = hre:favour:30`, `ruling_country_value_max = ...`,
`ruling_flag = hre:reichsreform`, `not_ruling_flag = ...`,
`formed = SPA`, `not_formed = SPA`, `is_formed = SPA`, `can_form = SPA`.

Effects (`effect:`):
`form_nation = SPA` (skips the requirements), `ruling_join = hre`,
`ruling_leave = hre`, `ruling_set_leader = hre`,
`ruling_add_role = hre:elector`, `ruling_remove_role = hre:elector`,
`ruling_value = hre:authority:5` (adds), `ruling_set_value = hre:authority:50`,
`ruling_country_value = hre:favour:10` (adds, for this country),
`ruling_set_flag = hre:reichsreform`, `ruling_clear_flag = ...`,
`ruling_dissolve = hre`.

The generators check that every system, role, value and formable exists.

## 6. How it is saved

Nothing to do: the engine saves the whole `RulingState`. Rules for keeping
old saves loading:
- State is matched to the data **by system key**. A new system in the
  data starts from its data in an old save; a removed one is dropped.
- Never rename a value, country value, role or flag that has shipped;
  add a new one and read both if you must.
- Per-country numbers are arrays by country index; never store a
  `CountryID` inside a value (use a role, or `leader`).
- Formed nations store the formable **id**; renaming a formable's id
  breaks saves that formed it.

## 7. Tests every system needs

In `<Name>SystemTests.swift` (Swift Testing, `Scenario1453.makeWorld()`):
1. **Data:** the bundled data loads with the right leader, roles and
   numbers (e.g. 7 electors, emperor `HAB`).
2. **Each rule:** one small test per hook with a hand-made situation
   (kill the emperor with `CharacterSystem.kill` → an election picks the
   expected winner; annex a free city → authority falls...).
3. **Limits:** values stay inside their ranges after many months.
4. **Determinism:** two worlds run the same 24 months → `rulings` equal.
5. **Save:** change the state, `SaveSnapshot(capturing:)` → encode →
   decode → `restore()`: state equal; both runs stay equal after 60 days.
6. **Events:** at least one event in `data/events/` uses the system's
   words (the generator then checks them).
7. **Long run:** the existing 10-year run stays green (no crash, no
   runaway numbers). Run the profile job if `runMonthly` loops over all
   countries or provinces.

Formables need: a refusal test (`requirementsNotMet`, `notEligible`),
a forming test (name, colour, shield, government, `formed` record), and
for `ai = true` a check that the AI forms it in a hand-made situation.
`FormableTests.swift` and `RulingEngineTests.swift` show the pattern
(including `TestRingSystem`, a system that exists only in tests).

## 8. The HRE, then the Shogunate (suggested plan)

**HRE** (owner: full Imperial mechanics, research Part VIII):
1. PR 1, data: all members (princes, prince-bishops, free cities, Swiss
   are members in 1453), `authority` start, role effects for free cities,
   `country_value` for imperial favour.
2. PR 2, `HRESystem`: `rulerChanged` on the emperor → election by the
   7 electors with `RulingEngine.elect` (score: opinion, same religion,
   size, dynasty; the Habsburgs usually win); `runMonthly` moves
   authority (internal peace, non-members holding imperial provinces,
   wars between members); `countryVanished` (annexed members cost
   authority).
3. PR 3, Reichstag reforms as `stage` + flags with events
   (Ewiger Landfriede 1495...), each reform a role or leader effect.
4. PR 4, religious leagues after the Reformation (flags + roles).

**Shogunate** (owner: shugo vassal swarm): data `leader = ASH`, the shugo
as `role shugo`, `value bakufu_authority`; Swift: authority falls with
shugo wars and weak shoguns; the Ōnin War (1467) as an event that sets a
flag letting shugo fight each other; a daimyō who takes Kyoto may take the
shogunate (`setLeader`).

## 9. Screens

The owner picked both screens on 26 Nov 2026 (details in `docs/DESIGN.md`,
"Ruling systems and formables"):
- **HRE: the "Imperial Diet" window** (mock-up A): emperor, authority
  bar, the seven electors with their lean, the reform ladder.
- **Formables: the "Crowns to claim" list** (mock-up A): a glowing
  left-column medallion, one card per open formable with a requirement
  checklist and a Proclaim button (`FormableSystem.open`,
  `requirements`, `form`).
Build them with the Phase 20 Theme (HANDOFF "New screens and the Phase 20
look"). Until they exist, formable offers use the event pop-up. The
bridge has `getCountryShieldKey(tag)`; new screen data goes through new
`@Callable`s and any screen is a look change: both are `needs-claude`.
Other systems' screens (Shogunate...): ask Claude for mock-ups first.

## 10. Which pull requests need `needs-claude`

- Data-only systems, formables and flavour, and a new `<Name>System.swift`
  with its one `builtIn` line: **Gemini merges** when CI is green.
- Anything in §3 "May not", any new screen, any `@Callable`:
  **`needs-claude`**.
