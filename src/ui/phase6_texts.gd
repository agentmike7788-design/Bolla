class_name Phase6Texts
extends RefCounted
## Texts and small pure helpers of the Phase-6 UI (docs/PHASE6_DESIGN.md §7): building panel (level
## cards, costs, pips), the shed lines of every station / build site / the stone panel (fetch, store,
## „im Schuppen: n"), the chapel panel (service checklist and preview), the devotion panel (graves,
## mood words, the cap of robbed souls), the exam panel's cold line, the HUD chapter and grave lines,
## the objective lines, the day summary additions and the chapter panel „Unter Dach und Erde".
## Reads only its arguments and static game data (Database, configs) – never live game state.

# --- building panel -------------------------------------------------------------------------
const LEVEL_OF := "Stufe %d von %d"
const LEVEL_SITE := "Bauplatz · Stufe 0 von %d"
const PIP_ON := "●"
const PIP_OFF := "○"
const CARD_LEVEL := "Stufe %d"
const CARD_DONE := "✓ steht"
const CARD_NEXT := "als Nächstes"
const CARD_LATER := "später"
const CARD_NEW := "Neu:"
const CARD_BULLET := "· %s"
const COSTS := "Was Stufe %d braucht"
const DURATION := "Dauer"
const BUILD_BUTTON := "Stufe %d bauen (%s)"
const BUILD_MAXED := "Voll ausgebaut"
const BUILD_NOTE := "Verbraucht wird erst, wenn die Stufe steht. Gebaut wird nur auf der vorigen Stufe, nichts wird zurückgebaut."
const MAXED_NOTE := "Alle drei Stufen stehen. Hier gibt es nichts mehr zu bauen."
const COINS_HAVE := "Münzen im Beutel: %d"
const HAVE := "%d / %d"

# --- shed (fetch / store) -----------------------------------------------------------------------
const SHED_HAVE := "im Schuppen: %d"
const FETCH_BUTTON := "Fehlendes aus dem Schuppen holen (%s)"
const FETCH_SHORT := "Fehlendes holen (%s)"
const FETCH_NOW := "sofort"
const STORE_BUTTON := "Überschuss einlagern"
const STORE_HINT := "Rohstoffe und Werkstoffe in den Schuppen – Werkzeug, Münzen, Gebeinkisten und Altarkerzen bleiben bei dir."
const SHED_TITLE := "Lagerschuppen"
const SHED_SIDE := "Regal"
const SHED_STACKS := "Rohstoffe und Werkstoffe stapeln hier doppelt (× %d)."
const SHED_STACK_BADGE := "× %d"
const SHED_STACK_LIMIT := "Stapel bis %d (× %d)"
const SHED_LEVEL := "Schuppen Stufe %d · %d Plätze"

# --- chapel panel -------------------------------------------------------------------------------
const CHAPEL_TITLE := "Aussegnung"
const CHAPEL_FOR := "für %s"
const CHAPEL_INTRO := "Kerze an, ein paar Worte am Katafalk. Die Familie legt etwas auf den Altar, die Leute im Dorf reden gut davon."
const CHAPEL_CONDITIONS := "Bevor es beginnt"
const CHAPEL_PREVIEW := "Was die Aussegnung bringt"
const CHECK_CATAFALQUE := "Liegt auf dem Katafalk"
const CHECK_NO_CATAFALQUE := "Liegt nicht auf dem Katafalk"
const CHECK_DRESSED := "Eingekleidet: %s"
const CHECK_UNDRESSED := "Nicht eingekleidet"
const CHECK_FRESH := "Frische %d %% (mindestens %d %%)"
const CHECK_CANDLE := "Altarkerze (%d da)"
const CHECK_NO_CANDLE := "Keine Altarkerze"
const CHECK_TIME := "Beginn zwischen %s und %s (jetzt %s)"
const CHECK_NOT_HELD := "Noch nicht ausgesegnet"
const CHECK_HELD := "Schon ausgesegnet"
const PREVIEW_REP := "Ruf %s"
const PREVIEW_MOURNERS := "%d Trauergäste in den Bänken"
const PREVIEW_NO_MOURNERS := "Noch keine Trauergäste (erst mit der Glocke)"
const PREVIEW_QUALITY := "Am Grab: „Ausgesegnet“ %s Qualität"
const PREVIEW_DURATION := "Dauer %s · nicht abbrechbar"
const SERVICE_BUTTON := "Aussegnung halten (%s)"
const DRESS_WORDS: Dictionary[StringName, String] = {&"shroud": "Leichentuch", &"gown": "Totenhemd"}

# --- devotion panel -----------------------------------------------------------------------------
const DEVOTION_TITLE := "Andacht"
const DEVOTION_INTRO := "Eine Kerze für ein Grab. Wer darunter liegt, schläft danach ruhiger – auch nachts ist die Kapelle offen."
const DEVOTION_EMPTY := "Noch liegt niemand unter einem Zeichen, für den eine Kerze brennen könnte."
const DEVOTION_BUTTON := "Andacht halten (%s)"
const DEVOTION_ROW_BUTTON := "Wählen"
const DEVOTION_CANDLES := "Altarkerzen: %d"
const DEVOTION_LIT := "Licht brennt (Stufe %d)"
const DEVOTION_NEW := "Stimmung +%d"
const DEVOTION_NONE := "kein Licht"
const DEVOTION_ROBBED := "höchstens gleichmütig"
const DEVOTION_ROBBED_HINT := "Mehr als Ruhe kann eine Kerze nicht geben."
const DEVOTION_SORT_RESTLESS := "Unruhige zuerst"
const CHECK_ON := "✓ %s"
const CHECK_OFF := "%s"
const DEVOTION_CHOSEN := "Gewählt: %s"
const DEVOTION_PICK := "Wähle ein Grab."
const DEVOTION_PAGE := "Seite %d / %d  ·  [ ] blättern"
const MOOD_WORDS: Dictionary[StringName, String] = {&"restless": "unruhig", &"calm": "gleichmütig", &"content": "zufrieden"}
const MOOD_NONE := "–"
## Sort rank of a mood („unruhig zuerst").
const MOOD_RANK: Dictionary[StringName, int] = {&"restless": 0, &"calm": 1, &"content": 2}

# --- exam panel -----------------------------------------------------------------------------------
const COLD_ROOM := "Kühle: × %s (Gruft)"
const COLD_NICHE := "Nische: × %s"

# --- HUD / objective ------------------------------------------------------------------------------
const SHORT_NAMES: Dictionary[StringName, String] = {&"crypt": "Gruft", &"chapel": "Kapelle", &"shed": "Schuppen"}
const CHAPTER_PART := "%s %d/%d"
const CHAPTER_SERVICES := "Aussegnung %d/%d"
const CHAPTER_REINTERRED := "Umbettung %d/%d"
const CHAPTER_LINE_DONE := "Unter Dach und Erde: erreicht"
const GRAVES_LINE := "Gräber %d belegt · %d frei · %s · %d umgebettet"
const GRAVES_OLD := "%d alt"
const GRAVES_OLD_REST := "%d alt (Ruhezeit)"
const OBJ_OSRIC := "Sprich mit Osric über die Gruft"
const OBJ_SITE := "Bauplatz: %s"
const OBJ_BOX := "Gebeinkiste zimmern"
const OBJ_LIFT := "Altes Grab heben: %s"
const OBJ_REINTER := "Gebeine beisetzen (%d %s)"
const OBJ_WAITING_ONE := "wartet"
const OBJ_WAITING_MANY := "warten"
const OBJ_TO_CRYPT := "Bring die Leiche in die Gruft"
const OBJ_CATAFALQUE := "Die Kapelle steht – leg %s auf den Katafalk"
const OBJ_SERVICE := "Aussegnung am Altar halten"
const OBJ_PASSAGE := "Hinter dem Beinhaus zieht es kalt"
const OBJ_DEVOTION := "Eine Andacht für %s?"

# --- day summary -------------------------------------------------------------------------------------
const DAY_SERVICES := "Ausgesegnet"
const DAY_REINTERRED := "Umgebettet"
const BUILT_LEVEL := "%s Stufe %d"
const SPENT_BUILDING := "Gebäude"

# --- chapter „Unter Dach und Erde" ---------------------------------------------------------------------
const CHAPTER_ID := &"roof_and_earth"
const CHAPTER_TITLE := "Unter Dach und Erde"
const CHAPTER_INTRO := "Die Gruft hält die Kühle, die Kapelle hat ein Dach über dem Katafalk, und im Schuppen bleibt das Holz trocken. Wer jetzt wartet, wartet an einem Ort."
const CHAPTER_ROWS: PackedStringArray = ["Tage seit dem Gemeinderat", "Gebäude", "Aussegnungen", "Andachten", "Umbettungen",
		"In der Kühlnische gewartet", "Ausgaben seit dem Gemeinderat", "Zufriedene Geister"]
const CHAPTER_SERVICES_VALUE := "%d (davon %d mit Trauergästen)"
const CHAPTER_REINTERRED_VALUE := "%d/%d · %s"
const CHAPTER_FINAL_FALLBACK := "Die Toten warten jetzt nicht mehr im Regen."
const NONE := "–"
const COIN := &"coin"


# --- building panel -----------------------------------------------------------------------------

## „●●○" for `level` of `max_level`.
static func pips(level: int, max_level: int) -> String:
	var on := clampi(level, 0, maxi(max_level, 0))
	return PIP_ON.repeat(on) + PIP_OFF.repeat(maxi(max_level - on, 0))


## „Stufe 1 von 3" / „Bauplatz · Stufe 0 von 3".
static func level_text(level: int, max_level: int) -> String:
	return LEVEL_SITE % max_level if level <= 0 else LEVEL_OF % [level, max_level]


## One card per level of `data`: {level, title, state (&"done" | &"next" | &"later"), state_text,
## adds (PackedStringArray), icon (StringName)}.
static func level_cards(data: BuildingData, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data == null:
		return out
	for lvl: int in range(1, data.max_level() + 1):
		var ld := data.level_data(lvl)
		if ld == null:
			continue
		var state := &"done" if lvl <= level else (&"next" if lvl == level + 1 else &"later")
		var state_text := CARD_DONE if state == &"done" else (CARD_NEXT if state == &"next" else CARD_LATER)
		out.append({"level": lvl, "title": ld.title, "state": state, "state_text": state_text, "adds": ld.adds,
				"icon": icon_id(data.id, lvl), "text": ld.text})
	return out


## Icon of a building level (icon renderer: building_<id>_<level>).
static func icon_id(building_id: StringName, level: int) -> StringName:
	return StringName("building_%s_%d" % [building_id, clampi(level, 0, 3)])


## Cost rows of a level: [{id, name, need, have, ok, coin, shed}] – items in inputs order, then the
## coins as their own row („Kalk und Mörtel aus Hollerbrück · 20 Münzen"). shed = the amount in the
## shed (-1 = no shed line, e.g. the coins or no shed inventory).
static func cost_rows(ld: BuildingLevelData, inv: Inventory, shed: Inventory = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ld == null:
		return out
	var valid := is_instance_valid(inv)
	for id: StringName in ld.inputs:
		var need := int(ld.inputs[id])
		var have := inv.count(id) if valid else 0
		out.append({"id": id, "name": UIKit.item_name(id), "need": need, "have": have, "ok": have >= need, "coin": false,
				"shed": shed.count(id) if is_instance_valid(shed) else -1})
	if ld.coins > 0:
		var coins := inv.count(COIN) if valid else 0
		var label := ld.coin_part_label if ld.coin_part_label != "" else Phase5Texts.BUILD_COIN_FALLBACK
		out.append({"id": COIN, "name": Phase5Texts.BUILD_COIN_ROW % [label, ld.coins, Phase5Texts.coins(ld.coins)], "need": ld.coins,
				"have": coins, "ok": coins >= ld.coins, "coin": true, "shed": -1})
	return out


## „Stufe 2 bauen (210 Min)".
static func build_button(level: int, minutes: int) -> String:
	return BUILD_BUTTON % [level, UIKit.minutes(minutes)]


# --- shed -------------------------------------------------------------------------------------

## „Fehlendes aus dem Schuppen holen (10 Min)" / „(sofort)" at 0 minutes; `short` = „Fehlendes holen (…)".
static func fetch_button(minutes: int, short: bool = false) -> String:
	var when := UIKit.minutes(minutes) if minutes > 0 else FETCH_NOW
	return (FETCH_SHORT if short else FETCH_BUTTON) % when


## What the shed row of a panel shows, pure: {shown (shed ≥ fetch_min_level and a shed inventory),
## store_shown (shed ≥ store_min_level), reason (ShedSupply.fetch_block_reason), minutes, available}.
static func shed_state(needs: Dictionary, inv: Inventory, shed: Inventory, level: int, cfg: ShedConfig) -> Dictionary:
	var c := cfg if cfg != null else ShedConfig.new()
	var shown := level >= c.fetch_min_level and is_instance_valid(shed)
	return {"shown": shown, "store_shown": shown and level >= c.store_min_level,
			"reason": ShedSupply.fetch_block_reason(needs, inv, shed, level, c) if shown else ShedSupply.TEXT_NO_SHED,
			"minutes": ShedSupply.fetch_minutes(level, c), "available": ShedSupply.available(needs, shed) if shown else {}}


## The live shed state for `needs` of the player's inventory (tree lookups via ShedSupply).
static func shed_state_in(tree: SceneTree, needs: Dictionary, inv: Inventory) -> Dictionary:
	return shed_state(needs, inv, ShedSupply.shed_inventory(tree), ShedSupply.shed_level(tree), ShedSupply.config())


# --- chapel panel ---------------------------------------------------------------------------------

## Checklist of the service: [{id, text, ok}] – catafalque, dressed, fresh, candle, time window, not
## held yet. `minute` = minute of the day.
static func service_checks(record: CorpseRecord, inv: Inventory, minute: int, cfg: ChapelConfig) -> Array[Dictionary]:
	var c := cfg if cfg != null else ChapelConfig.new()
	var out: Array[Dictionary] = []
	var on := record != null and record.location == CorpseRecord.LOCATION_CATAFALQUE
	out.append({"id": &"catafalque", "text": CHECK_CATAFALQUE if on else CHECK_NO_CATAFALQUE, "ok": on})
	var dressed := ChapelRules.is_dressed(record)
	var dress_word: String = DRESS_WORDS.get(record.dress if record != null and record.dress != &"" else &"shroud", "") if dressed else ""
	out.append({"id": &"dressed", "text": CHECK_DRESSED % dress_word if dressed else CHECK_UNDRESSED, "ok": dressed or not c.service_needs_dress})
	var fresh := record.freshness if record != null else 0.0
	out.append({"id": &"fresh", "text": CHECK_FRESH % [roundi(fresh * 100.0), roundi(c.service_min_freshness * 100.0)],
			"ok": record != null and fresh >= c.service_min_freshness})
	var candles := inv.count(c.candle_item) if is_instance_valid(inv) else 0
	out.append({"id": &"candle", "text": CHECK_CANDLE % candles if candles > 0 else CHECK_NO_CANDLE, "ok": ChapelRules.has_candle(inv, c)})
	var in_window := minute >= c.service_start_min and minute <= c.service_start_max
	out.append({"id": &"time", "text": CHECK_TIME % [UIKit.clock(c.service_start_min), UIKit.clock(c.service_start_max), UIKit.clock(minute)],
			"ok": in_window})
	var held := record != null and record.service_held
	out.append({"id": &"held", "text": CHECK_HELD if held else CHECK_NOT_HELD, "ok": not held})
	return out


## Preview lines of a service at chapel `level`: [fee text, reputation, mourners, quality, duration].
static func service_preview(level: int, cfg: ChapelConfig, quality_service: int) -> PackedStringArray:
	var c := cfg if cfg != null else ChapelConfig.new()
	var out := PackedStringArray()
	out.append(ChapelRites.fee_text(ChapelRules.fee(level, c)))
	out.append(PREVIEW_REP % UIKit.signed(ChapelRules.reputation(level, c)))
	var mourners := ChapelRules.mourners(level, c)
	out.append(PREVIEW_MOURNERS % mourners if mourners > 0 else PREVIEW_NO_MOURNERS)
	out.append(PREVIEW_QUALITY % UIKit.signed(quality_service))
	out.append(PREVIEW_DURATION % UIKit.minutes(c.service_minutes))
	return out


# --- devotion panel ----------------------------------------------------------------------------------

static func mood_word(mood: StringName) -> String:
	return MOOD_WORDS.get(mood, MOOD_NONE)


## ChapelRites.eligible_devotions() entries + {robbed, mood_word, lit_text, capped (robbed soul: the
## cap „höchstens gleichmütig"), bonus_text (what a devotion now would give, before the cap)},
## sorted restless first (then by grave order) when `restless_first`.
static func devotion_rows(entries: Array[Dictionary], robbed: Dictionary, level: int, cfg: ChapelConfig, restless_first: bool) -> Array[Dictionary]:
	var c := cfg if cfg != null else ChapelConfig.new()
	var out: Array[Dictionary] = []
	var index := 0
	for entry: Dictionary in entries:
		var row := entry.duplicate()
		var grave_id := str(entry.get("grave_id", ""))
		var r := int(robbed.get(grave_id, 0))
		var held := int(entry.get("held_level", 0))
		row["robbed"] = r
		row["capped"] = r > 0
		row["mood_word"] = mood_word(StringName(str(entry.get("mood", ""))))
		row["lit_text"] = DEVOTION_LIT % held if held > 0 else DEVOTION_NONE
		row["bonus_text"] = DEVOTION_NEW % ChapelRules.at_level(c.devotion_mood_by_level, level) if level > 0 else ""
		row["order"] = index
		index += 1
		out.append(row)
	if restless_first:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra := int(MOOD_RANK.get(StringName(str(a.get("mood", ""))), 3))
			var rb := int(MOOD_RANK.get(StringName(str(b.get("mood", ""))), 3))
			if ra != rb:
				return ra < rb
			return int(a.order) < int(b.order))
	return out


# --- exam panel ----------------------------------------------------------------------------------------

## „Kühle: × 0,7 (Gruft)" / „Nische: × 0,4" for a cold factor < 1, else "".
static func cold_line(location: StringName, factor: float) -> String:
	if factor >= 0.999:
		return ""
	var value := ("%.1f" % factor).replace(".", ",")
	return COLD_NICHE % value if location == CorpseRecord.LOCATION_NICHE else COLD_ROOM % value


# --- HUD ------------------------------------------------------------------------------------------------

## „Gruft 2/2 · Kapelle 1/2 · Schuppen 2/2 · Aussegnung 1/1 · Umbettung 3/1" from
## Buildings.goal_progress() ({} or without levels → "").
static func chapter_line(progress: Dictionary) -> String:
	if progress.is_empty() or not progress.has("levels"):
		return ""
	var parts := PackedStringArray()
	var levels: Dictionary = progress.get("levels", {})
	for id: Variant in levels:
		var pair: Array = levels[id]
		var key := StringName(str(id))
		parts.append(CHAPTER_PART % [SHORT_NAMES.get(key, str(id)), int(pair[0]), int(pair[1])])
	var s: Array = progress.get("services", [0, 0])
	var r: Array = progress.get("reinterred", [0, 0])
	parts.append(CHAPTER_SERVICES % [int(s[0]), int(s[1])])
	parts.append(CHAPTER_REINTERRED % [int(r[0]), int(r[1])])
	return " · ".join(parts)


## „Gräber 21 belegt · 2 frei · 2 alt (Ruhezeit) · 4 umgebettet" from {taken, free, old,
## old_resting, reinterred}; the old part says „(Ruhezeit)" when every old grave left must rest.
static func graves_line(counts: Dictionary) -> String:
	var old := int(counts.get("old", 0))
	var resting := int(counts.get("old_resting", 0))
	var old_text := GRAVES_OLD_REST % old if old > 0 and resting >= old else GRAVES_OLD % old
	return GRAVES_LINE % [int(counts.get("taken", 0)), int(counts.get("free", 0)), old_text, int(counts.get("reinterred", 0))]


## Objective line of Phase 6 from CemeteryStatus.phase6_state() (after the corpse chain and the
## Phase-4/5 goals) or "": Osric → site of the crypt → reinter the waiting boxes → lift (with a box)
## / build a box → the sealed passage → the goal levels → a devotion for the most restless ghost.
static func objective(world: Dictionary) -> String:
	if not bool(world.get("p6", false)):
		return ""
	if not bool(world.get("p6_intro", false)):
		return OBJ_OSRIC
	var levels: Dictionary = world.get("levels", {})
	if int(levels.get(&"crypt", 0)) <= 0:
		return OBJ_SITE % SHORT_NAMES[&"crypt"]
	var waiting := int(world.get("reinter_waiting", 0))
	if waiting > 0 and int(world.get("full_boxes", 0)) > 0:
		return OBJ_REINTER % [waiting, OBJ_WAITING_ONE if waiting == 1 else OBJ_WAITING_MANY]
	var lift := str(world.get("next_lift", ""))
	if lift != "" and bool(world.get("ossuary_free", false)):
		return OBJ_LIFT % lift if int(world.get("boxes", 0)) > 0 else OBJ_BOX
	if bool(world.get("passage_unseen", false)):
		return OBJ_PASSAGE
	if not bool(world.get("goal_done", false)):
		var parts := PackedStringArray()
		var goal: Dictionary = world.get("goal_levels", {})
		var missing := false
		for id: Variant in [&"chapel", &"crypt", &"shed"]:
			if not goal.has(id):
				continue
			parts.append("%s %d" % [SHORT_NAMES.get(id, String(id)), int(goal[id])])
			if int(levels.get(id, 0)) < int(goal[id]):
				missing = true
		if missing:
			return " · ".join(parts)
	var devotion := str(world.get("devotion_name", ""))
	if devotion != "":
		return OBJ_DEVOTION % devotion
	return ""


# --- day summary -------------------------------------------------------------------------------------

## "Gruft Stufe 2, Kapelle Stufe 1" from [[building_id, level], …].
static func buildings_text(built: Array) -> String:
	var parts := PackedStringArray()
	for entry: Variant in built:
		var pair := entry as Array
		if pair == null or pair.size() < 2:
			continue
		var data := Database.building(StringName(str(pair[0]))) as BuildingData
		var name := data.display_name if data != null and data.display_name != "" else str(pair[0])
		parts.append(BUILT_LEVEL % [name, int(pair[1])])
	return ", ".join(parts)


# --- chapter panel -----------------------------------------------------------------------------------

## Values of CHAPTER_ROWS from Buildings.chapter_context().
static func chapter_values(context: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(str(int(context.get("buildings_days", 0))))
	var levels: Dictionary = context.get("levels", {})
	var parts := PackedStringArray()
	for id: StringName in [&"crypt", &"chapel", &"shed"]:
		if levels.has(id) or levels.has(String(id)):
			parts.append("%s %d" % [SHORT_NAMES[id], int(levels.get(id, levels.get(String(id), 0)))])
	out.append(" · ".join(parts) if not parts.is_empty() else NONE)
	var services := int(context.get("services_held", 0))
	if context.has("services_mourners"):
		out.append(CHAPTER_SERVICES_VALUE % [services, int(context.get("services_mourners", 0))])
	else:
		out.append(str(services))
	out.append(str(int(context.get("devotions_held", 0))))
	var names: PackedStringArray = PackedStringArray(context.get("reinterred", PackedStringArray()))
	var total := int(context.get("reinterred_total", names.size()))
	# W3 tone QA: " · " between the names – „Elias Brand, Totengräber" carries its own comma.
	out.append(CHAPTER_REINTERRED_VALUE % [names.size(), total, " · ".join(names)] if not names.is_empty() else "0/%d" % total)
	out.append(str(int(context.get("niche_waits", 0))))
	var spent := Phase5Texts.spent_text(context.get("coins_spent", {}))
	out.append(spent if spent != "" else NONE)
	out.append(Phase5Texts.CHAPTER_GHOSTS % [int(context.get("content_before", 0)), int(context.get("content_now", 0))])
	return out
