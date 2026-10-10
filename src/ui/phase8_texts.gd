class_name Phase8Texts
extends RefCounted
## Texts and small pure helpers of the Phase-8 UI (docs/PHASE8_DESIGN.md §7): the chalk board (Jakob's work
## list), the wish card, the favour panel, the festival card, the Merkbuch pages „Angehörige" / „Hollerbrück"
## (mood, the three story points, the favour), the HUD (chatter bubbles, festival banner), the objective
## lines, the grave tooltip, the register / day summary additions and the chapter panel „Wer heraufkommt".
## Reads only its arguments and static game data (Database, configs) – never live game state.
## Grief is shown, not said: no sobbing, no gloom for its own sake (§ Regeln „Sprache").

const SEP := " · "
const NONE := "–"
const POINT_DONE := "●"
const POINT_OPEN := "◎"
const POINT_LATER := "○"
const CHECK := "✓"

# --- people -----------------------------------------------------------------------------------------
const APPRENTICE := &"apprentice"
const BEGGAR := &"beggar"
const PEDDLER := &"peddler"
const ROBBER := &"robber"
## Phase-8 people without VillagerData (npc_id → name, short name, role).
const PEOPLE: Dictionary[StringName, Array] = {
	&"apprentice": ["Jakob Wackernagel", "Jakob", "Lehrling, Rosines Sohn"],
	&"beggar": ["Veit Ammer", "Veit", "Bettler"],
	&"peddler": ["Hanne Vogelsang", "Hanne", "Wanderhändlerin"],
	&"robber": ["Lambert Grell", "Lambert", "Nachtgräber"],
}
## The households (KinData.kin_id → „Die Kehrs").
const HOUSEHOLD_NAMES: Dictionary[StringName, String] = {
	&"kin_kehr": "Die Kehrs", &"kin_brandt": "Die Brandts", &"kin_ott": "Die Otts", &"kin_sieber": "Die Siebers",
}
const HOUSE_LABELS: Dictionary[StringName, String] = {
	&"house_kehr": "Haus Kehr", &"house_brandt": "Haus Brandt", &"house_ott": "Haus Ott", &"house_sieber": "Haus Sieber",
	&"cottage_dorn": "Kate Dorn", &"cottage_hagedorn": "Kate Hagedorn",
}

# --- moods (§2.1.1, §7.4) -------------------------------------------------------------------------
const MOOD_WORDS: Dictionary[StringName, String] = {
	&"plain": "heute wie immer", &"cheerful": "heute gut gelaunt", &"low": "heute bedrückt", &"cross": "heute gereizt",
}

# --- goodwill (§2.2.1: a word, never the number) -----------------------------------------------------
const GOODWILL_WORDS: PackedStringArray = ["verbittert", "enttäuscht", "ruhig", "zufrieden", "dankbar"]
## Upper bounds (inclusive) of the five words on the 0…10 scale.
const GOODWILL_STEPS: PackedInt32Array = [1, 3, 5, 7, 10]

# --- wishes (§2.2.5, §7.2) ----------------------------------------------------------------------------
const WISH_KIND_LABELS: Dictionary[StringName, String] = {
	&"tend": "Grabpflege", &"flowers": "Blumen", &"candle": "Kerze", &"line": "Inschrift", &"vase": "Vase",
}
## The kind's symbol: an item icon (Database.icon).
const WISH_KIND_ICONS: Dictionary[StringName, StringName] = {
	&"tend": &"rake", &"flowers": &"flower_seedlings", &"candle": &"grave_candle", &"line": &"ink", &"vase": &"decor_grave_vase",
}
const WISH_TITLE := "Ein Wunsch"
const WISH_GRAVE := "%s, %s"
const WISH_QUOTE := "„%s“"
const WISH_DEADLINE := "bis zum nächsten Besuch (≈ in %d %s)"
const WISH_DEADLINE_SOON := "bis zum nächsten Besuch (bald)"
const WISH_REWARD := "%s werden es dir danken."
const WISH_REWARD_ONE := "%s wird es dir danken."
const WISH_ACCEPT := "Das mache ich."
const WISH_DECLINE := "Ich kann es nicht versprechen."
const WISH_FULL := "Drei Wünsche sind schon offen."
const WISH_ACCEPTED := "Angenommen."
const WISH_LINE := "Zeile: „%s“"
const WISH_SHORT := "Wunsch: %s für %s"
const WISH_SHORT_DAYS := "Wunsch: %s für %s (≈ %d %s)"
const WISH_KIND_SHORT: Dictionary[StringName, String] = {
	&"tend": "Pflege", &"flowers": "Blumen", &"candle": "eine Kerze", &"line": "eine Zeile", &"vase": "eine Vase",
}

# --- chalk board (§2.5.3, §7.1) -----------------------------------------------------------------------
const BOARD_TITLE := "Jakob – Arbeitsliste"
const BOARD_LINE := "Zeile %d"
const BOARD_TASK_NONE := "– nichts –"
const BOARD_NOT_SHOWN := "noch nicht gezeigt"
const BOARD_GREY_HINT := "Grau: noch nicht gezeigt – erst vormachen, dann aufschreiben."
const BOARD_LEVELS := "Was Jakob kann"
const BOARD_LEVEL_NONE := "–"
const BOARD_LEVEL_MARKS: PackedStringArray = ["", "|", "||"]
const BOARD_LEVEL_WORDS: PackedStringArray = ["noch nicht gezeigt", "angelernt", "geübt"]
const BOARD_PRACTICE := "noch %d %s bis Geübt"
const BOARD_PRACTICE_PLACE_ONE := "Stelle"
const BOARD_PRACTICE_PLACE_MANY := "Stellen"
const BOARD_TIN := "Lohndose"
const BOARD_TIN_VALUE := "%d %s (%d %s)"
const BOARD_DEPOSIT := "Münzen einlegen (%d)"
const BOARD_PAID := "bezahlt bis morgen"
const BOARD_PAID_DAYS := "bezahlt für %d Tage"
const BOARD_OWES := "schuldet %d"
const BOARD_EMPTY_TIN := "leer – morgen ohne Lohn"
const BOARD_NO_COINS := "Du hast keine %d Münzen dabei."
const BOARD_ESTIMATE := "≈ %s"
const BOARD_ESTIMATE_NONE := "Heute gibt es nach dieser Liste nichts zu tun."
const BOARD_ESTIMATE_OFF := "Heute hat Jakob frei."
const BOARD_THEN := ", dann "
const BOARD_MISSING := "Es fehlt: %s"
const BOARD_SHOW_DONE := "Zeig mir, was du heute geschafft hast"
const BOARD_BACK := "Zurück zur Liste"
const BOARD_DONE_TITLE := "Heute geschafft"
const BOARD_DONE_NONE := "„Noch nichts. Ich hab erst angefangen.“"
const BOARD_DONE_ROW := "%s  %s%s"
const BOARD_DONE_MISTAKE := "  – ein Fehler"
const BOARD_MORALE := "Jakob ist %s."
const MORALE_WORDS: PackedStringArray = ["verzagt", "kleinlaut", "still", "bei der Sache", "eifrig", "stolz"]
## Task id → the noun of its places („12 Laubstellen").
const TASK_PLACES: Dictionary[StringName, PackedStringArray] = {
	&"rake": ["Laubstelle", "Laubstellen"], &"weed": ["Unkrautstelle", "Unkrautstellen"],
	&"water": ["Grab gießen", "Gräber gießen"], &"candle": ["Kerze", "Kerzen"],
}
const TASK_LABELS: Dictionary[StringName, String] = {
	&"rake": "Laub harken", &"weed": "Unkraut jäten", &"water": "Blumen gießen", &"candle": "Grabkerzen",
	&"refill": "Kanne füllen", &"lunch": "Brotzeit", &"sweep": "Ecke kehren",
}
## ApprenticePlanner areas (Apprentice.AREAS).
const AREA_LABELS: Dictionary[StringName, String] = {
	&"yard": "Alter Hof", &"east": "Ostwiese", &"north": "Birkenhang", &"elder": "Holunderwinkel", &"linden": "Lindenacker",
	&"all": "überall", &"wished": "Gräber mit Wunsch",
}
const AREA_IN: Dictionary[StringName, String] = {
	&"yard": "im Alten Hof", &"east": "auf der Ostwiese", &"north": "am Birkenhang", &"elder": "im Holunderwinkel",
	&"linden": "im Lindenacker", &"all": "", &"wished": "an den Gräbern mit Wunsch",
}

# --- favours (§2.4, §7.3) -----------------------------------------------------------------------------
const FAVOR_TITLE := "Gefallen: %s"
const FAVOR_CHOOSE_GRAVE := "Für wen soll gebetet werden?"
const FAVOR_CHOOSE_ITEM := "Was soll es sein?"
const FAVOR_CHOOSE_NIGHT := "Für welche Nacht?"
const FAVOR_NIGHT := "heute Nacht"
const FAVOR_NIGHT_NEXT := "morgen Nacht"
const FAVOR_NIGHT_DAY := "in der Nacht von Tag %d"
const FAVOR_ASK := "Darum bitten"
const FAVOR_NONE := "Hier gibt es nichts zu wählen."
const FAVOR_DONE := "„Gut. Ich kümmere mich darum.“"
const FAVOR_READY := "Gefallen bereit"
const FAVOR_IN := "Gefallen in %d %s"
const FAVOR_TOMORROW := "Gefallen ab morgen"
const FAVOR_OWED := "wartet auf einen Gegengefallen"
const FAVOR_LINE := "[Gefallen] %s"
const FAVOR_PRICE := "%d %s"
const FAVOR_ITEM_COUNT := "%d× %s"
const FAVOR_GRAVE_META := "%s · %s"

# --- festivals (§2.7) ---------------------------------------------------------------------------------
const FEST_NAMES: Dictionary[StringName, String] = {&"fest_kathrein": "Kathreintanz", &"fest_lights": "Lichtgang"}
const FEST_BANNER: Dictionary[StringName, String] = {
	&"fest_lights": "Heute Abend: Lichtgang", &"fest_kathrein": "Kathreintanz im Holderkrug (ab %s)",
}
const FEST_BANNER_SECONDS := 4.0
## The minutes the banner shows on a festival day (06:00, 15:00).
const FEST_BANNER_MINUTES: PackedInt32Array = [360, 900]
const FEST_TITLE := "%s – Tag %d"
const FEST_WHEN := "%s bis %s"
const FEST_WHERE: Dictionary[StringName, String] = {&"fest_kathrein": "Holderkrug, Gaststube", &"fest_lights": "Friedhof und Kutschweg"}
const FEST_INTRO: Dictionary[StringName, String] = {
	&"fest_kathrein": "„Kathrein stellt den Tanz ein.“ Der letzte Tanz vor dem Advent. Bleib eine halbe Stunde, und tanz, mit wem du magst.",
	&"fest_lights": "Seit dem Fährwinter tragen die Hollerbrücker am Abend vor dem ersten Advent Lichter zu ihren Toten hinauf.",
}
const FEST_LIGHTS := "Kein Grab ohne Licht: %d/%d"
const FEST_LIGHTS_ALL := "Kein Grab ohne Licht."
const FEST_DARK := "Noch ohne Licht"
const FEST_DARK_MORE := "… und %d weitere"
const FEST_DANCE := "Tanzpartner"
const FEST_DANCED := "getanzt"
const FEST_DANCE_OK := "möchte tanzen"
const FEST_PRESENCE := "Eine halbe Stunde dabei"
const FEST_STATE: Dictionary[StringName, String] = {&"announced": "angekündigt", &"running": "läuft", &"ended": "vorbei",
		&"cancelled": "fällt aus"}
const FEST_NOT_TODAY := "Heute ist kein Fest."
const FEST_OPEN := "Festkarte"

# --- chatter bubbles (§7.5) ---------------------------------------------------------------------------
const CHATTER_SECONDS := 3.5

# --- objective lines (§7.5) ---------------------------------------------------------------------------
const OBJ_OSRIC := "Sprich mit Osric"
const OBJ_ROSINE := "Rosine will dich sprechen"
const OBJ_BOARD := "Kreidetafel: Arbeitsliste für Jakob"
const OBJ_TEACH := "Zeig Jakob, wie man %s"
const TEACH_VERBS: Dictionary[StringName, String] = {&"rake": "harkt", &"weed": "jätet", &"water": "gießt", &"candle": "Kerzen setzt"}
const OBJ_WAITING := "%s wartet am Grab"
const OBJ_TIN := "Lohndose leer – Jakob arbeitet morgen umsonst"
const OBJ_PEDDLER := "Hanne Vogelsang ist %s (bis %s)"
const PEDDLER_PLACES: Dictionary[StringName, String] = {&"peddler_gate": "am Tor", &"v_well_peddler": "am Brunnen"}
const OBJ_LIGHTS_EVE := "Heute Abend ist Lichtgang"
const OBJ_KATHREIN := "Heute Abend: Kathreintanz im Holderkrug"
const OBJ_NIGHT_QUESTION := "Merkbuch: Wer geht nachts zu den Kranken?"
const OBJ_SICK_LIGHT := "Bei den %s brennt Licht"
const OBJ_DISTURBED := "Ein Grab ist aufgewühlt"
const OBJ_GOAL := "Wer heraufkommt: %d/%d"
## The candle count of the Lichtgang from this minute on (§2.7.2: the families come up at 16:45).
const LIGHTS_COUNT_FROM := 900
const LIGHTS_UNTIL := 1080
const SICK_HOUSE_NAMES: Dictionary[StringName, String] = {&"house_ott": "Otts", &"house_kehr": "Kehrs",
		&"house_brandt": "Brandts", &"house_sieber": "Siebers"}

# --- grave tooltip (§7.2) -----------------------------------------------------------------------------
const TIP_FLOWERS_FRESH := "Blumen frisch (gießen in ≈ %s)"
const TIP_FLOWERS_DRY := "Blumen frisch – heute gießen"
const TIP_FLOWERS_WILTED := "Blumen welk"
const TIP_WREATH := "Wachskranz"
const TIP_BOUQUET := "ein Strauß liegt da"
const TIP_CANDLE := "Kerze brennt"
const TIP_MORTSAFE := "Grabgitter seit %d %s"
const TIP_MORTSAFE_NEW := "Grabgitter seit heute"
const TIP_DISTURBED := "aufgewühlt"
const TIP_KIN := "%s: %s"
const TIP_WISH := "Wunsch: %s"
const TIP_COINS := "%d %s auf dem Stein (%s)"
const TIP_RESERVED := "vorgemerkt: %s"

# --- register (§7.6) ----------------------------------------------------------------------------------
const REGISTER_KIN := "Angehörige"
const REGISTER_FLOWERS := "✿"
const REGISTER_CANDLE := "¡"
const REGISTER_MORTSAFE := "#"
const REGISTER_DISTURBED := "!"

# --- Merkbuch (§7.4) ----------------------------------------------------------------------------------
const PAGE_KIN := "Angehörige"
const PAGE_KIN_NONE := "Noch kommt niemand herauf, um nach seinen Toten zu sehen."
const PAGE_KIN_GRAVES := "Gräber: %s"
const PAGE_KIN_LAST := "zuletzt: %s"
const PAGE_KIN_LAST_NONE := "noch nicht hier gewesen"
const PAGE_KIN_NEXT := "kommt in ≈ %d %s"
const PAGE_KIN_TODAY := "kommt heute"
const PAGE_KIN_HERE := "ist jetzt hier"
const PAGE_KIN_TOMORROW := "kommt morgen"
const PAGE_KIN_UNKNOWN := "wann, weiß keiner"
const PAGE_KIN_WISH := "%s %s · %s"
const PAGE_KIN_WISH_DONE := "erfüllt"
const PAGE_KIN_WISH_OPEN := "offen"
const PAGE_KIN_FRESH_UNTIL := "frisch bis %s"
const PAGE_KIN_HINT := "Wohlwollen zeigt sich in Worten, nicht in Zahlen."
const PAGE_VILLAGE_MORE := "Neue Gesichter ›"
const PAGE_VILLAGE_BACK := "‹ Die Bewohner"
const PAGE_VILLAGE_NEXT_STEP := "%s  %s"
const PAGE_VILLAGE_STORY_DONE := "Die Geschichte ist erzählt."
const PAGE_JAKOB_LEVELS := "%s %s"
const PAGE_JAKOB_NOT_HIRED := "Noch geht Jakob in Rosines Küche zur Hand."
const PAGE_VEIT_ALMS := "Almosen gegeben: %d"
const PAGE_VEIT_PLACE := "sitzt %s"
const VEIT_PLACES: Dictionary[StringName, String] = {&"v_church_step": "auf der Kirchenstufe", &"veit_gate": "am Friedhofstor",
		&"v_bridge_sit": "an der Brücke", &"v_well_bench": "an der Bank am Brunnen"}
const PAGE_HANNE_TODAY := "heute da (%s)"
const PAGE_HANNE_NEXT := "nächster Besuch in %d %s"
const PAGE_HANNE_TOMORROW := "nächster Besuch morgen"
const PAGE_NOT_MET := "noch nicht begegnet"
const PAGE_ORDERS_FRIEND := "Freundschaft"
const PAGE_ORDERS_OWED := "Was du schuldest"
const PAGE_ORDERS_VILLAGE := "Dorf"
const QUESTION_REQUIRED := "Muss sein: %d/%d"
const QUESTION_ANY := "Zwei von vier: %d/%d"
const QUESTION_ANY_N := "%s von %s: %d/%d"
const NUMBER_WORDS: PackedStringArray = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs"]

# --- day summary (§7.6) -------------------------------------------------------------------------------
const DAY_VISITS := "Besuche"
const DAY_WISHES := "Wünsche"
const DAY_TIPS := "Trinkgeld"
const DAY_JAKOB := "Jakob"
const DAY_NIGHT := "Die Nacht"
const DAY_VISIT := "%s (%s, %s)"
const DAY_WISH_PARTS: Dictionary[StringName, String] = {&"done": "erfüllt", &"offered": "neu", &"accepted": "angenommen",
		&"failed": "verfallen"}
const DAY_JAKOB_JOBS := "%d %s"
const DAY_JAKOB_MISTAKE := "Fehler: %s"
const DAY_JAKOB_WAGE := "Lohn %d"
const DAY_JAKOB_UNPAID := "ohne Lohn heim"
const DAY_JAKOB_TOMORROW := "Morgen: %s"
const DAY_JAKOB_OFF := "frei"
const DAY_NIGHT_PARTS: Dictionary[StringName, String] = {&"seen": "Grabräuber gesehen", &"fled": "verscheucht",
		&"caught": "gestellt", &"disturbed": "ein Grab aufgewühlt"}
const DAY_NIGHT_SICK := "Licht bei den %s"
const VIEW_WORDS: Dictionary[StringName, String] = {&"disturbed": "aufgewühlt", &"neglected": "verwildert", &"bare": "ohne Namen",
		&"kept": "gepflegt", &"bonus": "mit Licht und Blumen", &"specimen": "Gerede"}

# --- chapter „Wer heraufkommt" (§1.5, §7.7) ---------------------------------------------------------
const CHAPTER_ID := &"who_comes_up"
const CHAPTER_TITLE := "Wer heraufkommt"
const CHAPTER_INTRO := "In Phase sieben bist du hinuntergegangen. Jetzt kommen sie herauf: mit Heidekraut, mit einem Rechen, der zu groß ist, mit Lichtern."
const CHAPTER_ROWS: PackedStringArray = ["Tage seit dem ersten Besuch", "Besuche", "Wünsche", "Trinkgeld", "Jakob", "Geschichten",
		"Gefallen", "Feste", "Lichtgang", "Der Nachtgräber", "Nachtwege", "Erkenntnisse"]
const CHAPTER_VISITS := "%d (%s)"
const CHAPTER_WISHES := "erfüllt %d · verfehlt %d"
const CHAPTER_JAKOB := "%s · %d Stellen · %d Fehler · Lohn %d"
const CHAPTER_FAVORS := "genutzt %d · erwidert %d"
const CHAPTER_FESTS := "getanzt %d"
const CHAPTER_LIGHTS_YES := "Kein Grab ohne Licht"
const CHAPTER_LIGHTS_SOME := "Viele Lichter, nicht alle"
const CHAPTER_LIGHTS_NONE := "–"
const CHAPTER_ROBBER := "%d %s · %s"
const ROBBER_FATES: Dictionary[StringName, String] = {&"": "verschwunden", &"reported": "beim Schultheiß", &"let_go": "laufen gelassen",
		&"caught_watch": "vom Nachtwächter gefasst"}
const CHAPTER_FINAL_FALLBACK := "Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist."
const PHASE8_INSIGHTS: Array[StringName] = [&"i_underlined"]


# --- people -----------------------------------------------------------------------------------------

## Display name of anyone the Phase-8 UI names: villagers, Jakob / Veit / Hanne / Lambert, kin, the council.
static func person_name(id: StringName) -> String:
	if PEOPLE.has(id):
		return str(PEOPLE[id][0])
	var kin := Database.kin(id) as KinData if id != &"" else null
	if kin != null and kin.display_name != "":
		return kin.display_name
	return Phase7Texts.person_name(id)


static func short_name(id: StringName) -> String:
	if PEOPLE.has(id):
		return str(PEOPLE[id][1])
	var kin := Database.kin(id) as KinData if id != &"" else null
	if kin != null and kin.villager_id != &"":
		return Phase7Texts.short_name(kin.villager_id)
	if kin != null:
		var parts := kin.display_name.split(" ", false)
		return parts[0] if not parts.is_empty() else kin.display_name
	return Phase7Texts.short_name(id)


## „Die Kehrs" for a household, the villager's short name for a villager kin.
static func household(kin_id: StringName) -> String:
	if HOUSEHOLD_NAMES.has(kin_id):
		return HOUSEHOLD_NAMES[kin_id]
	var kin := Database.kin(kin_id) as KinData if kin_id != &"" else null
	if kin != null and kin.villager_id != &"":
		return Phase7Texts.short_name(kin.villager_id)
	return person_name(kin_id)


## A household is several people („werden"), a villager one („wird").
static func is_household(kin_id: StringName) -> bool:
	return HOUSEHOLD_NAMES.has(kin_id)


static func house_label(house: StringName) -> String:
	return HOUSE_LABELS.get(house, MapConfig.new().labels.get(String(house), String(house)))


## The kin's portrait icon id (households kin_<name>, villagers villager_<id>).
static func kin_portrait(kin_id: StringName) -> StringName:
	var kin := Database.kin(kin_id) as KinData if kin_id != &"" else null
	if kin != null and kin.villager_id != &"":
		return StringName("villager_%s" % kin.villager_id)
	return kin_id


static func mood_word(mood: StringName) -> String:
	return MOOD_WORDS.get(mood, MOOD_WORDS[&"plain"])


## One of the five goodwill words for 0…10.
static func goodwill_word(goodwill: int) -> String:
	var g := clampi(goodwill, 0, 10)
	for i: int in GOODWILL_STEPS.size():
		if g <= GOODWILL_STEPS[i]:
			return GOODWILL_WORDS[i]
	return GOODWILL_WORDS[GOODWILL_WORDS.size() - 1]


static func days_word(n: int) -> String:
	return Phase7Texts.days_word(n)


static func coins(n: int) -> String:
	return Phase7Texts.coins(n)


## „≈ 1 Tag" / „≈ 5 Std." from game minutes.
static func duration_text(minutes: int) -> String:
	if minutes >= 1440:
		var d := roundi(float(minutes) / 1440.0)
		return "%d %s" % [d, days_word(d)]
	return "%d Std." % maxi(1, roundi(float(minutes) / 60.0))


# --- grave & section names ------------------------------------------------------------------------

## „Hedwig Lamprecht, Lindenacker" from the grave's record (name, section) or the grave id.
static func grave_title(dead_name: String, grave_id: String, section: StringName) -> String:
	var s := Database.section(section) as SectionData if section != &"" else null
	var where := s.display_name if s != null else grave_id
	return WISH_GRAVE % [dead_name if dead_name != "" else grave_id, where]


# --- wishes -----------------------------------------------------------------------------------------

static func wish_kind_label(kind: StringName) -> String:
	return WISH_KIND_LABELS.get(kind, String(kind))


static func wish_icon(kind: StringName) -> StringName:
	return WISH_KIND_ICONS.get(kind, &"")


## „bis zum nächsten Besuch (≈ in 3 Tagen)".
static func wish_deadline(days: int) -> String:
	if days <= 0:
		return WISH_DEADLINE_SOON
	return WISH_DEADLINE % [days, "Tag" if days == 1 else "Tagen"]


## „Die Kehrs werden es dir danken." / „Esch wird es dir danken."
static func wish_reward(kin_id: StringName) -> String:
	return (WISH_REWARD if is_household(kin_id) else WISH_REWARD_ONE) % household(kin_id)


## „Wunsch: Blumen für Hedwig Lamprecht (≈ 2 Tage)" (days < 0 = no day count).
static func wish_objective(kind: StringName, dead_name: String, days: int) -> String:
	var what: String = WISH_KIND_SHORT.get(kind, wish_kind_label(kind))
	if days < 0:
		return WISH_SHORT % [what, dead_name]
	return WISH_SHORT_DAYS % [what, dead_name, days, days_word(days)]


# --- chalk board ----------------------------------------------------------------------------------

static func task_label(task: StringName) -> String:
	var data := Database.apprentice_task(task) as ApprenticeTaskData if task != &"" else null
	if data != null and data.label != "":
		return data.label
	return TASK_LABELS.get(task, String(task))


static func area_label(area: StringName) -> String:
	return AREA_LABELS.get(area, String(area))


## „|" / „||" – Jakob's level as chalk strokes.
static func level_marks(level: int) -> String:
	return BOARD_LEVEL_MARKS[clampi(level, 0, BOARD_LEVEL_MARKS.size() - 1)]


static func level_word(level: int) -> String:
	return BOARD_LEVEL_WORDS[clampi(level, 0, BOARD_LEVEL_WORDS.size() - 1)]


## „noch 4 Stellen bis Geübt" ("" unless the task is taught and not practised yet).
static func practice_text(level: int, jobs: int, practice_jobs: int) -> String:
	if level != 1:
		return ""
	var left := maxi(practice_jobs - jobs, 0)
	return BOARD_PRACTICE % [left, BOARD_PRACTICE_PLACE_ONE if left == 1 else BOARD_PRACTICE_PLACE_MANY]


## „9 Münzen (3 Tage)".
static func tin_text(coins_in: int, wage: int) -> String:
	var days := floori(float(coins_in) / float(maxi(wage, 1)))
	return BOARD_TIN_VALUE % [coins_in, coins(coins_in), days, days_word(days)]


## „bezahlt bis morgen" / „bezahlt für 3 Tage" / „schuldet 6" / „leer – morgen ohne Lohn".
static func tin_state(coins_in: int, wage: int, debt: int) -> String:
	if debt > 0:
		return BOARD_OWES % debt
	var days := floori(float(coins_in) / float(maxi(wage, 1)))
	if days <= 0:
		return BOARD_EMPTY_TIN
	return BOARD_PAID if days == 1 else BOARD_PAID_DAYS % days


## „≈ 12 Laubstellen im Alten Hof, dann 4 Unkrautstellen im Lindenacker" from ApprenticeBoard.estimate()
## [{task, count}] and the board lines [{task, area}] (the area of the task's first line).
static func estimate_text(estimate: Array, lines: Array) -> String:
	var parts := PackedStringArray()
	for raw: Variant in estimate:
		if not raw is Dictionary:
			continue
		var task := StringName(str((raw as Dictionary).get("task", "")))
		var n := int((raw as Dictionary).get("count", 0))
		if n <= 0:
			continue
		var nouns: PackedStringArray = TASK_PLACES.get(task, PackedStringArray([String(task), String(task)]))
		var part := "%d %s" % [n, nouns[0] if n == 1 else nouns[1]]
		for line: Variant in lines:
			if line is Dictionary and StringName(str((line as Dictionary).get("task", ""))) == task:
				var where: String = AREA_IN.get(StringName(str((line as Dictionary).get("area", "all"))), "")
				if where != "":
					part += " " + where
				break
		parts.append(part)
	if parts.is_empty():
		return ""
	return BOARD_ESTIMATE % BOARD_THEN.join(parts)


static func morale_text(morale: int) -> String:
	return BOARD_MORALE % MORALE_WORDS[clampi(morale, 0, MORALE_WORDS.size() - 1)]


## „08:30  Laub harken – Alter Hof" rows of the day's finished places.
static func done_row(entry: Dictionary, section_name: String, mistake: bool) -> String:
	var where := " – " + section_name if section_name != "" else ""
	return BOARD_DONE_ROW % [UIKit.clock(int(entry.get("start", 0))), task_label(StringName(str(entry.get("task", "")))),
			where + (BOARD_DONE_MISTAKE if mistake else "")]


# --- story points & favours --------------------------------------------------------------------------

## The three story points: ● done, ◎ possible now, ○ later.
static func story_points(done: int, offerable: bool, steps: int = 3) -> String:
	var out := ""
	for i: int in steps:
		if i < done:
			out += POINT_DONE
		elif i == done and offerable:
			out += POINT_OPEN
		else:
			out += POINT_LATER
	return out


## „Gefallen bereit" / „Gefallen in 2 Tagen" / „wartet auf einen Gegengefallen" ("" before the story is told).
static func favor_state(done: int, reason: String, owed: bool) -> String:
	if done < 3:
		return ""
	if owed:
		return FAVOR_OWED
	if reason == "":
		return FAVOR_READY
	var rx := RegEx.create_from_string("in (\\d+) Tagen")
	var m := rx.search(reason)
	if m != null:
		var n := int(m.get_string(1))
		return FAVOR_IN % [n, "Tag" if n == 1 else "Tagen"]
	if reason == FavorRules.TEXT_COOLDOWN_ONE:
		return FAVOR_TOMORROW
	return ""


static func fest_name(fest_id: StringName) -> String:
	return FEST_NAMES.get(fest_id, String(fest_id))


## The banner text of `fest_id` ("" = none); Kathrein names the start of its window.
static func fest_banner(fest_id: StringName, window_from: int) -> String:
	if not FEST_BANNER.has(fest_id):
		return ""
	var text: String = FEST_BANNER[fest_id]
	return text % UIKit.clock(window_from) if text.contains("%s") else text


# --- objective (§7.5) -------------------------------------------------------------------------------

## The Phase-8 objective line from world_state.p8 = Phase8Status.objective_state() ("" = nothing of Phase 8 to say).
## Order (§7.5, the time-bound lines first): Osric · a waiting visitor (only on the graveyard) · the Lichtgang
## day („Heute Abend ist Lichtgang" → from 15:00 „Kein Grab ohne Licht: 31/34") · Rosine · the board · teaching ·
## the most urgent wish · the empty tin · Hanne · the Kathreintanz evening · the sick light · the night question
## · a disturbed grave · „Wer heraufkommt: n/4".
static func objective(world_state: Dictionary) -> String:
	var raw: Variant = world_state.get("p8", {})
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return ""
	var world := raw as Dictionary
	if not bool(world.get("intro", false)):
		return OBJ_OSRIC
	var waiting := str(world.get("waiting", ""))
	if waiting != "":
		return OBJ_WAITING % waiting
	var fest := StringName(str(world.get("fest_today", "")))
	var minute := int(world.get("minute", 0))
	if fest == &"fest_lights" and minute < LIGHTS_UNTIL:
		var lights: Vector2i = world.get("lights", Vector2i.ZERO)
		if minute >= LIGHTS_COUNT_FROM and lights.y > 0:
			return FEST_LIGHTS % [lights.x, lights.y]
		return OBJ_LIGHTS_EVE
	if not bool(world.get("hired", false)):
		return OBJ_ROSINE if bool(world.get("rosine_ready", false)) else _later(world)
	if bool(world.get("board_empty", false)):
		return OBJ_BOARD
	var teach := StringName(str(world.get("teach", "")))
	if teach != &"":
		return OBJ_TEACH % TEACH_VERBS.get(teach, task_label(teach))
	var wish: Dictionary = world.get("wish", {})
	if not wish.is_empty():
		return wish_objective(StringName(str(wish.get("kind", ""))), str(wish.get("name", "")), int(wish.get("days", -1)))
	if bool(world.get("tin_empty", false)):
		return OBJ_TIN
	return _later(world)


static func _later(world: Dictionary) -> String:
	var peddler: Dictionary = world.get("peddler", {})
	if not peddler.is_empty():
		return OBJ_PEDDLER % [PEDDLER_PLACES.get(StringName(str(peddler.get("place", ""))), "am Tor"), UIKit.clock(int(peddler.get("until", 0)))]
	if StringName(str(world.get("fest_today", ""))) == &"fest_kathrein" and int(world.get("minute", 0)) < 1380:
		return OBJ_KATHREIN
	var sick := StringName(str(world.get("sick_light", "")))
	if sick != &"":
		return OBJ_SICK_LIGHT % SICK_HOUSE_NAMES.get(sick, house_label(sick))
	if bool(world.get("night_question", false)):
		return OBJ_NIGHT_QUESTION
	if bool(world.get("disturbed", false)):
		return OBJ_DISTURBED
	if not bool(world.get("goal_done", false)):
		return OBJ_GOAL % [int(world.get("goal_parts", 0)), int(world.get("goal_total", 4))]
	return ""


# --- grave tooltip ----------------------------------------------------------------------------------

## The Phase-8 tooltip lines of one grave from MapState.grave_info's entry: {flowers, fresh_left, bouquet,
## candle, mortsafe_days, disturbed, kin, goodwill, wish_kind, coins, giver, reserved}.
static func grave_lines(info: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	match StringName(str(info.get("flowers", ""))):
		&"fresh":
			var left := int(info.get("fresh_left", -1))
			out.append(TIP_FLOWERS_FRESH % duration_text(left) if left > 60 else TIP_FLOWERS_DRY)
		&"wilted":
			out.append(TIP_FLOWERS_WILTED)
		&"wreath":
			out.append(TIP_WREATH)
	if bool(info.get("bouquet", false)):
		out.append(TIP_BOUQUET)
	if bool(info.get("candle", false)):
		out.append(TIP_CANDLE)
	var ms := int(info.get("mortsafe_days", -1))
	if ms == 0:
		out.append(TIP_MORTSAFE_NEW)
	elif ms > 0:
		out.append(TIP_MORTSAFE % [ms, days_word(ms)])
	if bool(info.get("disturbed", false)):
		out.append(TIP_DISTURBED)
	var kin := StringName(str(info.get("kin", "")))
	if kin != &"":
		out.append(TIP_KIN % [household(kin), goodwill_word(int(info.get("goodwill", 5)))])
	var wish := StringName(str(info.get("wish_kind", "")))
	if wish != &"":
		out.append(TIP_WISH % wish_kind_label(wish))
	var n := int(info.get("coins", 0))
	if n > 0:
		out.append(TIP_COINS % [n, coins(n), str(info.get("giver", ""))])
	var reserved := str(info.get("reserved", ""))
	if reserved != "":
		out.append(TIP_RESERVED % reserved)
	return out


## Symbols of the register column: ✿ flowers, ¡ candle, # mortsafe, ! disturbed.
static func register_marks(info: Dictionary) -> String:
	var parts := PackedStringArray()
	if StringName(str(info.get("flowers", ""))) != &"":
		parts.append(REGISTER_FLOWERS)
	if bool(info.get("candle", false)):
		parts.append(REGISTER_CANDLE)
	if int(info.get("mortsafe_days", -1)) >= 0:
		parts.append(REGISTER_MORTSAFE)
	if bool(info.get("disturbed", false)):
		parts.append(REGISTER_DISTURBED)
	return " ".join(parts)


# --- Merkbuch helpers -------------------------------------------------------------------------------

## „kommt in ≈ 2 Tagen" / „kommt morgen" / „kommt heute" / „ist jetzt hier" from the next day (−1 unknown).
static func next_visit_text(next_day: int, today: int, here: bool) -> String:
	if here:
		return PAGE_KIN_HERE
	if next_day < 0:
		return PAGE_KIN_UNKNOWN
	var d := next_day - today
	if d <= 0:
		return PAGE_KIN_TODAY
	if d == 1:
		return PAGE_KIN_TOMORROW
	return PAGE_KIN_NEXT % [d, "Tag" if d == 1 else "Tagen"]


## „Tag 55" / „heute" / „gestern".
static func day_text(day: int, today: int) -> String:
	if day == today:
		return "heute"
	if day == today - 1:
		return "gestern"
	return "Tag %d" % day


## The Merkbuch's question card groups of an any-group insight: [„Muss sein: 2/2", „Zwei von vier: 1/2"].
static func question_groups(card: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if int(card.get("any_count", 0)) <= 0:
		return out
	out.append(QUESTION_REQUIRED % [int(card.get("requires_found", 0)), int(card.get("requires_needed", 0))])
	var need := int(card.get("any_count", 0))
	var total := int(card.get("any_total", 0))
	var found := mini(int(card.get("any_found", 0)), need)
	if need == 2 and total == 4:
		out.append(QUESTION_ANY % [found, need])
	else:
		out.append(QUESTION_ANY_N % [_cap(_number(need)), _number(total), found, need])
	return out


static func _number(n: int) -> String:
	return NUMBER_WORDS[n] if n >= 0 and n < NUMBER_WORDS.size() else str(n)


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


# --- day summary ------------------------------------------------------------------------------------

## „Martha Kehr (l_02, gepflegt) · Esch (old_01, kept)" from Phase8DayLog visits [{kin_id, grave, view}].
static func visits_text(visits: Array) -> String:
	var parts := PackedStringArray()
	for raw: Variant in visits:
		if not raw is Dictionary:
			continue
		var v := raw as Dictionary
		parts.append(DAY_VISIT % [person_name(StringName(str(v.get("kin_id", "")))), str(v.get("grave_name", v.get("grave", ""))),
				VIEW_WORDS.get(StringName(str(v.get("view", ""))), str(v.get("view", "")))])
	return SEP.join(parts)


## „1 erfüllt · 2 neu · 1 verfallen" from {state: n}.
static func wishes_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for state: StringName in [&"done", &"offered", &"accepted", &"failed"]:
		var n := int(counts.get(state, counts.get(String(state), 0)))
		if n > 0:
			parts.append("%d %s" % [n, DAY_WISH_PARTS[state]])
	return SEP.join(parts)


## „Laub harken 9 · Unkraut jäten 3 · Fehler: l_04 · Lohn 3 · Morgen: frei" from the Jakob log.
static func jakob_text(log_data: Dictionary) -> String:
	var parts := PackedStringArray()
	var jobs: Dictionary = log_data.get("jobs", {})
	for task: StringName in [&"rake", &"weed", &"water", &"candle"]:
		var n := int(jobs.get(task, jobs.get(String(task), 0)))
		if n > 0:
			parts.append(DAY_JAKOB_JOBS % [task_label(task), n])
	var mistakes: Array = log_data.get("mistakes", [])
	if not mistakes.is_empty():
		var where := PackedStringArray()
		for m: Variant in mistakes:
			where.append(str(m))
		parts.append(DAY_JAKOB_MISTAKE % ", ".join(where))
	if log_data.has("wage"):
		var wage := int(log_data.get("wage", 0))
		parts.append(DAY_JAKOB_WAGE % wage if wage > 0 else DAY_JAKOB_UNPAID)
	var tomorrow := str(log_data.get("tomorrow", ""))
	if tomorrow != "":
		parts.append(DAY_JAKOB_TOMORROW % tomorrow)
	return SEP.join(parts)


## „Grabräuber gesehen · verscheucht · Licht bei den Otts" from {kinds: [..], sick: [house]}.
static func night_text(log_data: Dictionary) -> String:
	var parts := PackedStringArray()
	var kinds: Array = log_data.get("robber", [])
	for kind: StringName in [&"seen", &"fled", &"caught", &"disturbed"]:
		if kinds.has(kind) or kinds.has(String(kind)):
			parts.append(DAY_NIGHT_PARTS[kind])
	for house: Variant in log_data.get("sick", []):
		parts.append(DAY_NIGHT_SICK % SICK_HOUSE_NAMES.get(StringName(str(house)), house_label(StringName(str(house)))))
	return SEP.join(parts)


# --- chapter --------------------------------------------------------------------------------------

## Values of CHAPTER_ROWS from NpcLife.chapter_context() (+ the UI's additions: visits_by_kin, steps_by_npc,
## lights_result, robber_fate, insights).
static func chapter_values(context: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(str(int(context.get("days_open", 0))))
	var by_kin: Dictionary = context.get("visits_by_kin", {})
	var kin_parts := PackedStringArray()
	for k: Variant in by_kin:
		kin_parts.append("%s %d" % [household(StringName(str(k))), int(by_kin[k])])
	var seen := int(context.get("visits_seen", context.get("visits_total", 0)))
	out.append(CHAPTER_VISITS % [seen, SEP.join(kin_parts)] if not kin_parts.is_empty() else str(seen))
	out.append(CHAPTER_WISHES % [int(context.get("wishes_done", 0)), int(context.get("wishes_failed", 0))])
	out.append("%d %s" % [int(context.get("tips_coins", 0)), coins(int(context.get("tips_coins", 0)))])
	var lv: Dictionary = context.get("apprentice_levels", {})
	var lv_parts := PackedStringArray()
	for task: StringName in [&"rake", &"weed", &"water", &"candle"]:
		var l := int(lv.get(String(task), lv.get(task, 0)))
		if l > 0:
			lv_parts.append("%s %s" % [task_label(task), level_marks(l)])
	out.append(CHAPTER_JAKOB % [", ".join(lv_parts) if not lv_parts.is_empty() else NONE, int(context.get("apprentice_jobs", 0)),
			int(context.get("apprentice_mistakes", 0)), int(context.get("apprentice_wage", 0))])
	var steps: Dictionary = context.get("steps_by_npc", {})
	var step_parts := PackedStringArray()
	for id: StringName in Phase7Texts.VILLAGER_ORDER:
		if steps.has(String(id)) or steps.has(id):
			step_parts.append("%s %s" % [Phase7Texts.short_name(id), story_points(int(steps.get(String(id), steps.get(id, 0))), false)])
	out.append(SEP.join(step_parts) if not step_parts.is_empty() else str(int(context.get("friend_steps", 0))))
	out.append(CHAPTER_FAVORS % [int(context.get("favors_used", 0)), int(context.get("favors_returned", 0))])
	out.append(CHAPTER_FESTS % int(context.get("dances", 0)))
	match StringName(str(context.get("lights_result", ""))):
		&"lights_all":
			out.append(CHAPTER_LIGHTS_YES)
		&"lights_some":
			out.append(CHAPTER_LIGHTS_SOME)
		_:
			out.append(CHAPTER_LIGHTS_NONE)
	var enc := int(context.get("robber_encounters", 0))
	out.append(CHAPTER_ROBBER % [enc, "Begegnung" if enc == 1 else "Begegnungen",
			ROBBER_FATES.get(StringName(str(context.get("robber_fate", ""))), NONE)] if enc > 0 else NONE)
	out.append(str(int(context.get("night_visits_observed", 0))))
	var titles := PackedStringArray()
	for id: Variant in context.get("insights", []):
		titles.append(Phase7Texts.insight_title(StringName(str(id))))
	out.append(", ".join(titles) if not titles.is_empty() else NONE)
	return out
