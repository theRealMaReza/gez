# Balance report (Phase 20.5)

## Run 1: 22 November 2026, before any fixes

**How it was tested:** six AI-only games from 30 May 1453 to 1 January
1550. Three used the Historical AI setting and three the Free setting,
each with seeds 1, 2 and 3. The map already has the 1453 border fixes
(#19). The CI job is "Balance run" and the test is `BalanceRunTests`.
Each game prints a report every ten years. To run them again:

```
gh api -X POST repos/theRealMaReza/gez/actions/workflows/ci.yml/dispatches \
  -f ref=<branch> -f 'inputs[only]=balance'      # add -f 'inputs[balance_end]=1650' for longer
```

### What works
- **Constantinople stays Ottoman** in all six games.
- **Technology rises steadily.** It goes from about level 3 in 1453 to
  level 11 in 1550, and no country runs far ahead or falls far behind.
- **Plague and famine** come in waves: a heavy first decade, then quieter.
- **The Chronicle fills up.** It records wars, battles, sieges, peace
  treaties, reforms, plagues, rulers, marriages and births. The period
  prose reads well.
- **World population** stays between 194 and 217 million (it starts at
  202 million). Real history grew it by about a quarter by 1550, so this
  is a little low but not broken.
- **No crashes.** All six games reached 1550.

### What is wrong (worst first)

1. **Some populations collapse or explode for no reason.**
   - Hungary falls from 2.7 million to between 0.1 and 0.8 million in
     every game. Lithuania falls from 2.9 to 0.5 million, Crimea to almost
     nobody, and the Ottomans from 5.1 to about 3.4 million.
   - The Mamluks grow from 4.2 million to 12–29 million, Vijayanagara from
     14 to 41 million, and Florence, Naples and Cologne grow 6 to 8 times.
   - Most likely the people are moving or growing far too fast. Someone
     has to look at migration, growth and the steppe and frontier
     regions.
2. **Wars don't end.** In five of six games one war has lasted 60 to 96
   years by 1550. A stalemate needs a forced peace (white peace after
   enough years, or war exhaustion).
3. **The Historical AI doesn't follow history.**
   - Muscovy stays at 12–18 provinces all century (historically it took
     Novgorod in 1478 and Tver in 1485). Novgorod is eaten by others.
   - The Qara Qoyunlu grow to 38–69 provinces, while the Aq Qoyunlu
     usually die. History went the other way: the Aq Qoyunlu destroyed
     the Qara Qoyunlu in 1467.
   - The Ottomans end anywhere between 38 and 84 provinces (they started
     with 47). The Mamluks are often bigger than them by 1550, while
     historically the Ottomans conquered the Mamluks in 1517.
   - Granada survives into the 1520s, and Castile and Aragon never unite.
4. **Treasuries pile up.** By 1550 the middle country holds about 3,400
   in gold and the richest about 150,000, and nobody is ever in debt.
   Money has too little to be spent on (armies are small: the Ottomans
   often have under 10,000 men).
5. **Too many small countries vanish.** About 20 disappear in the first
   seven years, and 83–99 of 287 are gone by 1550. The Holy Roman
   Empire's free cities and small princes are swallowed (Metz, Basel,
   Besançon, Holstein, Augsburg, Jülich and others). Historically almost
   all of them lasted. Some protection is needed for imperial states (the
   Phase 20.8 HRE system will do this properly).
6. **Almost no rebellions:** 0–3 a decade worldwide. Unrest rarely leads
   to revolt.
7. **Laws never change:** the AI never changes a law. Reforms do happen.
8. **Chronicle bug:** "war ended" is never recorded (always 0), although
   peace treaties are.
9. **Speed:** a game day gets about twice as slow over the century (CI:
   about 11 ms in 1460, 22 ms in 1550). Born heirs outnumber deaths about
   six to one, so the number of people in the game keeps growing; that is
   the likely cause. The 1st of each month also costs about 0.16 s and
   1 January about 0.3 s (economy, government, characters), which shows as
   a stutter at top speed.

### Plan (one pull request per area)
1. Population: collapse and explosion (1).
2. Wars that never end (2).
3. Speed: the growing number of people and the monthly and yearly spikes
   (9).
4. Historical AI goals: Muscovy, the Aq Qoyunlu, the Ottomans, Spain (3).
5. Money sinks and army sizes (4).
6. Small states, rebels, laws, and the Chronicle bug (5–8).

After each fix, run the six games again and add the results here as
"Run 2", "Run 3" and so on.
