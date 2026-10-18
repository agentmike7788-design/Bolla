class_name LightRules
extends RefCounted
## Pure rules of the list (docs/PHASE9_DESIGN.md §2.2.1, §2.2.2, §3.4): the light day of an entry from the saved records
## (death = arrival day − 1 – died in the night before the delivery, Phase 2; D2 from night_paths.deaths.np_ott; light =
## death − 21), the date text (StoneCalendar.date_text; days before game day 1 – S1 −16, S3 −9 – are counted back here
## with the same calendar, StoneCalendar stays as it is), the open light (reading day of the Kladde − 12, QA9-07), Johann's death
## (light + 21) and the deadline (light + 17). Fixed (e_dorn) or missing dead → NO_DAY; a missing dead shows the
## substitute date StoryCorpseData.earliest_day − 22 and counts in H2 through Lenz' death register.
## Reads the CorpseManager (group corpse_manager: records()), NightPaths (group night_paths: death_day) and the journal
## (i_not_lorenz) of `tree`; changes nothing.

## „INT_MIN" of §3.4.
const NO_DAY := -9223372036854775807 - 1
## Died in the night before the delivery (Phase 2): death day = arrival day − 1.
const DEATH_BEFORE_ARRIVAL := 1
## §2.2.1: a missing dead → substitute date earliest_day − 22.
const SUBSTITUTE_OFFSET := -22
## The dead whose death a night path knows: WhoKnowsConfig.death_paths / death_flags (D2 Gerhard Ott:
## night_paths.deaths.np_ott, else the flag ott_dead).
## §2.2.3 H2: Kaspar's entry – „Kaspar Dorn" with i_not_lorenz, else the dead from the moor.
const MOOR_STORY := &"s5_moor"
const MOOR_INSIGHT := &"i_not_lorenz"
const MOOR_NAME := "der Tote aus dem Moor (S5)"
## §2.2.1 the register compare of a dead not on the hill (Lenz' death register).
const TEXT_NOT_HERE := "Im Sterbebuch steht er. Bei dir liegt er nicht."
## The open entry: „Unter diesem Datum liegt noch keiner."
const TEXT_OPEN := "Unter diesem Datum liegt noch keiner."
const MINUTES_PER_DAY := 1440
const CORPSE_GROUP := &"corpse_manager"
const NIGHT_GROUP := &"night_paths"
const JOURNAL_GROUP := &"journal"
const OPEN_DAY_FLAG := &"p9_open_day"


## Death − 21; fixed / missing → NO_DAY. The open entry: the light of q_light_day (else the light of a list read today,
## reading_light_day – G9 Benutzerentscheidung QA9-07: q_light_day is set when the Kladde is read).
static func light_day(entry: LightEntryData, tree: SceneTree, cfg: WhoKnowsConfig) -> int:
	if entry == null:
		return NO_DAY
	var c := _cfg(cfg)
	if entry.open:
		var light := flag_day(c.light_flag)
		return light if light != NO_DAY else reading_light_day(flag_day(OPEN_DAY_FLAG), TimeManager.day, c)
	if entry.fixed_text != "" or entry.story_id == &"":
		return NO_DAY
	var death := death_of(entry.story_id, tree, c)
	return death - c.death_offset if death != NO_DAY else NO_DAY


## Over StoneCalendar.date_text: the fixed text, the light day, or the substitute date of a missing dead.
static func entry_text(entry: LightEntryData, tree: SceneTree, cfg: WhoKnowsConfig) -> String:
	if entry == null:
		return ""
	if entry.fixed_text != "":
		return entry.fixed_text
	var day := light_day(entry, tree, cfg)
	if day == NO_DAY:
		day = substitute_day(entry)
	return date_text(day) if day != NO_DAY else ""


## p9_open_day + open_light_offset (−12); no opening day → NO_DAY.
static func open_light_day(open_day: int, cfg: WhoKnowsConfig) -> int:
	if open_day == NO_DAY or open_day <= 0:
		return NO_DAY
	return open_day + _cfg(cfg).open_light_offset


## G9 Benutzerentscheidung 18.10.2026 (QA9-07): the open light counts from the day Lorenz' Kladde is read – the reading
## day (never before p9_open_day) + open_light_offset (−12). Read on the opening day it is the light of before
## (p9_open_day − 12); read later, the light, the deadline (light + 17) and Johann's death (light + 21) move with it, so
## the list's dates stay consistent and the light always lies in the past. No opening day → NO_DAY.
static func reading_light_day(open_day: int, read_day: int, cfg: WhoKnowsConfig) -> int:
	if open_day == NO_DAY or open_day <= 0:
		return NO_DAY
	return open_light_day(maxi(open_day, read_day), cfg)


## Light + 21 (Johann dies at 02:10).
static func death_day(light_day: int, cfg: WhoKnowsConfig) -> int:
	return light_day + _cfg(cfg).death_offset if light_day != NO_DAY else NO_DAY


## Light + 17 (the last day of H6, 23:59).
static func decide_day(light_day: int, cfg: WhoKnowsConfig) -> int:
	return light_day + _cfg(cfg).decide_offset if light_day != NO_DAY else NO_DAY


# --- helpers (also for the journal page „Die Liste", P6) ---------------------------------------------

## The death day of the story dead `story_id` (NO_DAY = not delivered): a night path's death, else arrival − 1.
## `cfg` null = data/config/who_knows_config.tres (death_paths, death_flags).
static func death_of(story_id: StringName, tree: SceneTree, cfg: WhoKnowsConfig = null) -> int:
	var c := _cfg(cfg)
	if c.death_paths.has(story_id):
		var paths := _first(tree, NIGHT_GROUP)
		if paths != null and paths.has_method(&"death_day"):
			var d := int(paths.call(&"death_day", c.death_paths[story_id]))
			if d > 0:
				return d
		var flag := flag_day(c.death_flags.get(story_id, &""))
		if flag != NO_DAY:
			return flag
	var r := record_of(story_id, tree)
	if r == null or r.arrival_total_minutes <= 0:
		return NO_DAY
	return floori(float(r.arrival_total_minutes) / MINUTES_PER_DAY) + 1 - DEATH_BEFORE_ARRIVAL


## The record of the story dead (CorpseManager.records), null = never delivered.
static func record_of(story_id: StringName, tree: SceneTree) -> CorpseRecord:
	if story_id == &"":
		return null
	var manager := _first(tree, CORPSE_GROUP)
	if manager == null or not manager.has_method(&"records"):
		return null
	for r: Variant in manager.call(&"records"):
		if r is CorpseRecord and (r as CorpseRecord).story_id == story_id:
			return r
	return null


## The grave of the entry's dead ("" = not buried on the hill – H2 through the death register).
static func grave_of(entry: LightEntryData, tree: SceneTree) -> String:
	if entry == null or entry.open:
		return ""
	var r := record_of(entry.story_id, tree)
	if r == null or r.location != CorpseRecord.LOCATION_BURIED or r.grave_id == "":
		return ""
	return r.grave_id


## The name beside the entry once matched: the record's name; Kaspar only with i_not_lorenz (§2.2.3 H2); "" = no dead.
static func entry_name(entry: LightEntryData, tree: SceneTree) -> String:
	if entry == null or entry.open:
		return ""
	var r := record_of(entry.story_id, tree)
	var name := r.display_name if r != null else ""
	if name == "":
		var story := Database.story_corpse(entry.story_id) as StoryCorpseData
		name = story.display_name if story != null else ""
	if entry.story_id == MOOR_STORY:
		var journal := _first(tree, JOURNAL_GROUP)
		var known := journal != null and journal.has_method(&"has_insight") and bool(journal.call(&"has_insight", MOOR_INSIGHT))
		if not known:
			return MOOR_NAME
	return name


## §2.2.1: earliest_day − 22 of the entry's story (NO_DAY without one).
static func substitute_day(entry: LightEntryData) -> int:
	if entry == null or entry.story_id == &"":
		return NO_DAY
	var story := Database.story_corpse(entry.story_id) as StoryCorpseData
	return story.earliest_day + SUBSTITUTE_OFFSET if story != null else NO_DAY


## StoneCalendar.date_text, also for days before game day 1 (counted back over the same month names / lengths).
static func date_text(day: int, stone: StoneConfig = null) -> String:
	var cfg := stone if stone != null else Database.config(&"stone_config") as StoneConfig
	if day >= 1:
		return StoneCalendar.date_text(day, cfg)
	var d := date_before(day, cfg)
	return "%d. %s %d" % [d.day, _month_names(cfg)[int(d.month) - 1], d.year]


## {year, month, day} of a game day < 1 (day 0 = the day before the calendar start).
static func date_before(day: int, cfg: StoneConfig) -> Dictionary:
	var start := StoneCalendar.date_of(1, cfg)
	var lengths := _month_days(cfg)
	var year := int(start.year)
	var month := int(start.month)
	var d := int(start.day)
	var back := 1 - mini(day, 1)
	while back > 0:
		if back < d:
			d -= back
			break
		back -= d
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		d = lengths[month - 1]
	return {"year": year, "month": month, "day": d}


## A GameState flag holding a day (int / float; else NO_DAY – a damaged save's text or bool).
static func flag_day(flag: StringName) -> int:
	if flag == &"" or not GameState.has_flag(flag):
		return NO_DAY
	var v: Variant = GameState.get_flag(flag)
	return int(v) if (v is int or v is float) else NO_DAY


static func _month_names(cfg: StoneConfig) -> PackedStringArray:
	var raw: Variant = cfg.calendar.get("month_names", []) if cfg != null else []
	var out := PackedStringArray()
	if raw is Array or raw is PackedStringArray:
		for n: Variant in raw:
			out.append(str(n))
	return out if out.size() == 12 else StoneCalendar.FALLBACK_NAMES


static func _month_days(cfg: StoneConfig) -> PackedInt32Array:
	var raw: Variant = cfg.calendar.get("month_days", []) if cfg != null else []
	var out := PackedInt32Array()
	if raw is Array or raw is PackedInt32Array:
		for n: Variant in raw:
			out.append(maxi(1, int(n)))
	return out if out.size() == 12 else StoneCalendar.FALLBACK_DAYS


static func _cfg(cfg: WhoKnowsConfig) -> WhoKnowsConfig:
	if cfg != null:
		return cfg
	var c := Database.config(&"who_knows_config") as WhoKnowsConfig
	return c if c != null else WhoKnowsConfig.new()


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
