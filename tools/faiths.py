"""The one list of faiths for the Python generators.

Keep in step with Packages/GezCore/Sources/GezCore/Faith/Religion.swift
(religion id -> family id). Tools import it with:
    sys.path.insert(0, str(<repo>/"tools")); from faiths import ...
"""

FAMILY = {
    # Christian
    **{r: "christian" for r in "catholic hussite protestant reformed orthodox bosnian coptic ethiopian "
                               "armenian syriac nestorian".split()},
    # Muslim
    **{r: "muslim" for r in "sunni twelver zaydi ismaili ibadi druze alawite yazidi".split()},
    # Dharmic (Indian and Buddhist)
    **{r: "dharmic" for r in "hindu jain theravada tibetan mahayana".split()},
    # East Asian (Phase 20.7)
    **{r: "eastAsian" for r in "confucian daoist shinto".split()},
    "zoroastrian": "iranian",
    "jewish": "jewish",
    # Old and local traditions; the African, Siberian and Southeast Asian
    # ones split out in Phase 20.7.
    **{r: "pagan" for r in "tengri folk west_african bantu east_african siberian austronesian highland".split()},
}

RELIGIONS = set(FAMILY)
FAMILIES = sorted(set(FAMILY.values()))
# Display names of the families, as ReligionFamily.displayName in Swift.
FAMILY_NAME = {"christian": "Christian", "muslim": "Muslim", "dharmic": "Dharmic", "iranian": "Iranian",
               "jewish": "Jewish", "pagan": "Pagan", "eastAsian": "East Asian"}
