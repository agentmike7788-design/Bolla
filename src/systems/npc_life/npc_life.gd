class_name NpcLife
extends Node
## Systems/NpcLife (docs/PHASE8_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.4, §5.1), groups &"npc_life",
## &"saveable" (save_order 70):
## - Opening (§1.2): the first minute ≥ intro_minute (06:00) after name_in_village_complete was first seen
##   sets p8_open and p8_open_day (idempotent, like Village); a migrated v6 save (empty state) with the
##   chapter opens at once in post_load, a v7 save keeps the morning rule.
## - Moods (§2.1.1): one per villager and day – MoodRules.roll (day, npc_id), then the precedence rules
##   on mood_events(day). Derived from the clock and the saved events, never saved; moods_rolled at the
##   first tick of a day from 06:00 (only while open). Effects only from p8_open (the greeting text may
##   use the mood before): talk of the day by talk_gain_by_mood (Relationships.note_talk), „gereizt" offers
##   nothing (offer_block_reason), „bedrückt" opens „[Zuhören]" (listen: 10 minutes, relationship
##   gains.listen, piety event listen, once per day and person).
## - Events (§2.1.3): note_event remembers day + event (+ the people who react); reaction_for / valid_events
##   give the remark of the last valid_days (NpcLifeConfig.reactions). Own bookkeeping from signals: story
##   steps (friend_step_completed → step:<npc>), a lecture rumor, a specimen of a village dead sold, a
##   disturbed grave (robber_event).
## - Chatters (§2.1.2): the once-per-day list ChatterRunner reads (chatter_day).
## - The chapter „Wer heraufkommt" (§1.5): check_goal at apprentice_level_changed, wish_changed,
##   friend_step_completed and insight_unlocked – exactly once.
## Listeners only keep NpcLife's own bookkeeping (as Village does); the chapter check sets its flag.

const GROUP := &"npc_life"
const FLAG_OPEN := &"p8_open"
const FLAG_OPEN_DAY := &"p8_open_day"
const MOOD_PLAIN := &"plain"
const MOOD_CHEERFUL := &"cheerful"
const MOOD_LOW := &"low"
const MOOD_CROSS := &"cross"
const MINUTES_PER_DAY := 1440
const SUMMARY_PANEL := &"slice_summary"
## The evening minute at which NightPaths is asked whether a sick light burns on a day (§1.6: 22:00).
const SICK_LIGHT_MINUTE := 1320
const EVENT_LECTURE_RUMOR := &"lecture_rumor"
const EVENT_SPECIMEN_VILLAGER := &"specimen_sold_villager"
const EVENT_GRAVE_DISTURBED := &"grave_disturbed"
const STAT_LISTENS := &"listens"
const REASON_LISTEN := "Zugehört"
const PIETY_LISTEN := &"listen"
const TEXT_OPEN := "Unten reden sie über dich. Diesmal nicht über die Toten."
const TEXT_CROSS := "Heute nicht, Totengräber. Morgen."
const TEXT_NOT_OPEN := "Dafür ist es noch zu früh."
const TEXT_NOT_LOW := "Es gibt heute nichts, was gesagt werden will."
const TEXT_LISTENED := "Heute hast du schon zugehört."
const TEXT_UNKNOWN := "Hier gibt es niemanden, dem du zuhören könntest."
const TEXT_ABSENT := "%s ist nicht da."
## §1.5: last line of the chapter panel by piety tier (P6 may polish).
const FINAL_LINES := {
	&"hardhearted": "Früher kam nur Osric den Hügel herauf. Jetzt kommen mehr. Sie gehen schnell wieder.",
	&"callous": "Früher kam nur Osric den Hügel herauf. Jetzt kommen sie, sehen nach und reden unten darüber.",
	&"indifferent": "Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist.",
	&"considerate": "Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist.",
	&"devout": "Früher kam nur Osric den Hügel herauf. Jetzt bringen sie Lichter mit, und keiner geht, ohne zu grüßen.",
}
const FINAL_LINE_DEFAULT := "Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist."

@export var save_id: String = "npc_life"
@export var save_order: int = 70

## Rules; null = data/config/npc_life_config.tres (resolved lazily).
var config: NpcLifeConfig
## Tests: npc_id → VillagerData; empty = Database.villager / Database.villagers().
var villagers: Dictionary[StringName, VillagerData] = {}
## Tests: forced moods {npc_id: mood} (debug „mood <npc> <mood>" too); cleared on a new day.
var mood_override: Dictionary[StringName, StringName] = {}

var _open_day: int = 0
## event → the day it last happened; event → the people who react ([] = everyone).
var _events: Dictionary[StringName, int] = {}
var _event_npcs: Dictionary[StringName, Array] = {}
## npc_id → day of the last „[Zuhören]"; chatter_id → day it last ran.
var _listened: Dictionary[StringName, int] = {}
var _chatter_day: Dictionary[StringName, int] = {}
var _goal_done: bool = false
## total_minutes when unlock_flag was first seen this session (-1 = not yet; not saved).
var _unlock_seen_total: int = -1
## load_state got a Phase-8 state (not the empty {} of a migrated v6 save).
var _loaded_v7: bool = false
var _rolled_day: int = -1
var _override_day: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.chapter_completed.connect(_on_chapter_completed)
	EventBus.apprentice_level_changed.connect(_on_goal_input.unbind(2))
	EventBus.wish_changed.connect(_on_goal_input.unbind(2))
	EventBus.friend_step_completed.connect(_on_friend_step)
	EventBus.insight_unlocked.connect(_on_goal_input.unbind(1))
	EventBus.lecture_held.connect(_on_lecture)
	EventBus.specimen_changed.connect(_on_specimen)
	EventBus.robber_event.connect(_on_robber_event)


# --- opening --------------------------------------------------------------------------------------

## Flag p8_open.
func is_open() -> bool:
	return GameState.flag_on(_cfg().open_flag)


## Flag p8_open_day (0 = not open).
func open_day() -> int:
	var v: Variant = GameState.get_flag(_cfg().open_day_flag, 0)
	return int(v) if v is int or v is float else 0


## 06:00: p8_open (idempotent – the first minute ≥ intro_minute after the unlock flag was first seen),
## then moods_rolled once per day while open.
func apply_morning(day: int) -> void:
	var cfg := _cfg()
	if not is_open() and GameState.flag_on(cfg.unlock_flag):
		var now := TimeManager.total_minutes()
		if day > TimeManager.day:
			now = maxi(now, (day - 1) * MINUTES_PER_DAY + cfg.intro_minute)
		if _unlock_seen_total < 0:
			_unlock_seen_total = now
		elif now >= _open_at(_unlock_seen_total, cfg.intro_minute):
			open()
	if is_open() and day != _rolled_day and (day > TimeManager.day or TimeManager.minute_of_day >= cfg.intro_minute):
		_rolled_day = day
		EventBus.moods_rolled.emit(day)


## v6 with name_in_village_complete → p8_open at once (§1.2); a v7 state keeps the morning rule.
func post_load() -> void:
	if not is_open() and GameState.flag_on(_cfg().unlock_flag) and not _loaded_v7:
		open()


## Sets p8_open / p8_open_day now (debug „p8 open", post_load, the morning rule). Idempotent.
func open() -> void:
	if is_open():
		return
	var cfg := _cfg()
	GameState.set_flag(cfg.open_flag, true)
	if _open_day <= 0:
		_open_day = TimeManager.day
	if open_day() <= 0:
		GameState.set_flag(cfg.open_day_flag, _open_day)
	else:
		_open_day = open_day()
	EventBus.notification_requested.emit(TEXT_OPEN, &"info")


# --- moods ----------------------------------------------------------------------------------------

## Today's mood (derived from day + saved events, not saved).
func mood(npc_id: StringName) -> StringName:
	return mood_on(npc_id, TimeManager.day)


## The mood of `npc_id` on `day`: debug override (today only) > precedence rules > the roll.
func mood_on(npc_id: StringName, day: int) -> StringName:
	if _override_day != TimeManager.day:
		mood_override.clear()
		_override_day = TimeManager.day
	if day == TimeManager.day and mood_override.has(npc_id):
		return mood_override[npc_id]
	var data := villager(npc_id)
	if data == null:
		return MOOD_PLAIN  # §2.1.1: moods are the villagers'; Osric, Ilse, mourners stay as they are
	var cfg := _cfg()
	var base := MoodRules.roll(npc_id, day, cfg)
	return MoodRules.apply_rules(base, npc_id, day, mood_events(day), cfg, data)


## Debug / tests: forces today's mood of `npc_id` (&"" = back to the rules).
func set_mood(npc_id: StringName, value: StringName) -> void:
	mood(npc_id)  # clears a stale override of another day first
	if value == &"":
		mood_override.erase(npc_id)
	else:
		mood_override[npc_id] = value


## The mood effects apply (§2.1.1: only from p8_open).
func moods_active() -> bool:
	return is_open()


## The relationship gain of the talk of the day (§2.1.1): talk_gain_by_mood while open, else `fallback`.
func talk_gain(npc_id: StringName, fallback: int) -> int:
	if not moods_active():
		return fallback
	return int(_cfg().talk_gain_by_mood.get(mood(npc_id), fallback))


## „Heute nicht, Totengräber. Morgen." while open and the person is „gereizt" (no new order, no story
## step today – shops and turn-ins go on); "" otherwise.
func offer_block_reason(npc_id: StringName) -> String:
	return TEXT_CROSS if moods_active() and mood(npc_id) == MOOD_CROSS else ""


## The greeting of the day by mood (VillagerData.mood_lines, 2 per mood; "" = none).
func greeting(npc_id: StringName) -> String:
	var data := villager(npc_id)
	if data == null:
		return ""
	var pool: PackedStringArray = data.mood_lines.get(mood(npc_id), PackedStringArray())
	return pool[posmod(TimeManager.day, pool.size())] if not pool.is_empty() else ""


## The inputs of the precedence rules on `day` (MoodRules): the saved events, the story steps, the
## festival of the day (Festivals), the mourning ribbons of the day and the day before (Village), a sick
## light that evening (NightPaths).
func mood_events(day: int) -> Dictionary:
	var out := {}
	for ev: StringName in _events:
		out[ev] = _events[ev]
	var fest := _first(&"festivals")
	if fest != null and fest.has_method(&"fest_day"):
		for data: Resource in Database.festivals():
			var id := StringName(str(data.get(&"id")))
			if int(fest.call(&"fest_day", id)) == day:
				out[MoodRules.KEY_FESTIVAL] = day
	if not out.has(MoodRules.KEY_FESTIVAL) and fest != null and fest.has_method(&"today") and day == TimeManager.day \
			and StringName(str(fest.call(&"today"))) != &"":
		out[MoodRules.KEY_FESTIVAL] = day
	var village := _first(&"village")
	if village != null and village.has_method(&"mourning_house"):
		for d: int in [day - 1, day]:
			var house := StringName(str(village.call(&"mourning_house", d)))
			if house != &"":
				var key := StringName(MoodRules.PREFIX_MOURNING + String(house))
				out[key] = _with_day(out.get(key), d)
	var paths := _first(&"night_paths")
	if paths != null and paths.has_method(&"sick_houses"):
		var houses: PackedStringArray = paths.call(&"sick_houses", day, SICK_LIGHT_MINUTE)
		if not houses.is_empty():
			out[MoodRules.KEY_SICK_LIGHT] = day
	return out


# --- events / reactions ---------------------------------------------------------------------------

## Remembers today + event (moods, remarks); `npcs` = the people who react ([] = everyone; merged with the
## people of the same event today).
func note_event(event: StringName, npcs: Array[StringName] = []) -> void:
	if event == &"":
		return
	var day := TimeManager.day
	var who: Array = []
	if int(_events.get(event, -1)) == day and _event_npcs.has(event):
		who = (_event_npcs[event] as Array).duplicate()
		if who.is_empty() or npcs.is_empty():
			who = []
		else:
			for n: StringName in npcs:
				if not who.has(n):
					who.append(n)
	else:
		who = npcs.duplicate()
	_events[event] = day
	_event_npcs[event] = who


## The day `event` was last noted (-1 = never).
func event_day(event: StringName) -> int:
	return int(_events.get(event, -1))


## The newest valid event for the remark of `npc_id` or &"".
func reaction_for(npc_id: StringName) -> StringName:
	var list := valid_events(npc_id)
	return list[0] if not list.is_empty() else &""


## Valid reaction events for `npc_id`, newest first (NpcLifeConfig.reactions: event → days valid; the
## people noted with it, [] = everyone). Nothing before p8_open.
func valid_events(npc_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if not is_open():
		return out
	var cfg := _cfg()
	var day := TimeManager.day
	var found: Array = []
	for ev: StringName in cfg.reactions:
		if not _events.has(ev):
			continue
		var d := _events[ev]
		if d > day or day - d >= maxi(int(cfg.reactions[ev]), 0):
			continue
		var who: Array = _event_npcs.get(ev, [])
		if not who.is_empty() and not who.has(npc_id) and not who.has(String(npc_id)):
			continue
		found.append([d, cfg.reactions.keys().find(ev), ev])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for f: Array in found:
		out.append(f[2])
	return out


# --- listening ------------------------------------------------------------------------------------

## "" = „[Zuhören]" possible (open, a villager, mood low, once per day and person, present in the village).
func listen_block_reason(npc_id: StringName) -> String:
	if not is_open():
		return TEXT_NOT_OPEN
	var data := villager(npc_id)
	if data == null:
		return TEXT_UNKNOWN
	if int(_listened.get(npc_id, -1)) == TimeManager.day:
		return TEXT_LISTENED
	if mood(npc_id) != MOOD_LOW:
		return TEXT_NOT_LOW
	var village := _first(&"village")
	if village != null and village.has_method(&"villager_present") and not bool(village.call(&"villager_present", npc_id)):
		return TEXT_ABSENT % data.display_name.get_slice(" ", 0)
	return ""


## 10 minutes, relationship +3 (gains.listen), piety +1 (event listen), stats.listens; once per day.
func listen(npc_id: StringName) -> bool:
	if listen_block_reason(npc_id) != "":
		return false
	_listened[npc_id] = TimeManager.day
	TimeManager.advance(_cfg().listen_minutes)
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"add"):
		var gain := int(rel.call(&"gain", &"listen")) if rel.has_method(&"gain") else 3
		rel.call(&"add", npc_id, gain, REASON_LISTEN)
	var piety := _first(&"piety")
	if piety != null and piety.has_method(&"event"):
		piety.call(&"event", PIETY_LISTEN, REASON_LISTEN)
	GameState.add_stat(STAT_LISTENS, 1)
	return true


## Listened to `npc_id` today.
func listened_today(npc_id: StringName) -> bool:
	return int(_listened.get(npc_id, -1)) == TimeManager.day


# --- chatters (ChatterRunner) ---------------------------------------------------------------------

## The chatter ran today (§2.1.2: once per day).
func chatter_seen_today(chatter_id: StringName) -> bool:
	return int(_chatter_day.get(chatter_id, -1)) == TimeManager.day


func note_chatter(chatter_id: StringName) -> void:
	_chatter_day[chatter_id] = TimeManager.day


# --- chapter --------------------------------------------------------------------------------------

## §1.5 – exactly once: who_comes_up_complete, chapter_completed(&"who_comes_up"), the summary panel.
func check_goal() -> bool:
	var cfg := _cfg()
	if _goal_done or GameState.flag_on(cfg.goal_flag):
		_goal_done = true
		return false
	if not is_open():
		return false
	var p := goal_progress()
	if int(p.done) < int(p.total):
		return false
	_goal_done = true
	GameState.set_flag(cfg.goal_flag, true)
	EventBus.chapter_completed.emit(cfg.chapter_id)
	EventBus.ui_panel_requested.emit(SUMMARY_PANEL, chapter_context())
	return true


## {hired, levels, levels_goal, wishes, wishes_goal, kin, kin_goal, steps, steps_goal, full, full_goal, insight,
## done, total} for the objective line.
func goal_progress() -> Dictionary:
	var cfg := _cfg()
	var apprentice := _first(&"apprentice")
	var hired := apprentice != null and apprentice.has_method(&"is_hired") and bool(apprentice.call(&"is_hired"))
	var levels := 0
	if hired and apprentice.has_method(&"level"):
		for task: StringName in [&"rake", &"weed", &"water", &"candle"]:
			if int(apprentice.call(&"level", task)) >= 1:
				levels += 1
	var wishes := done_wishes()
	var kin := {}
	for w: Dictionary in wishes:
		kin[str(w.get("kin_id", ""))] = true
	var friendship := _first(&"friendship")
	var steps := int(friendship.call(&"steps_total")) if friendship != null and friendship.has_method(&"steps_total") else 0
	var full := int(friendship.call(&"full_stories")) if friendship != null and friendship.has_method(&"full_stories") else 0
	var insight := _has_insight(cfg.goal_insight)
	var parts := [hired and levels >= cfg.goal_levels, wishes.size() >= cfg.goal_wishes and kin.size() >= cfg.goal_kin,
			steps >= cfg.goal_steps and full >= cfg.goal_full_stories, insight]
	var n := 0
	for part: bool in parts:
		if part:
			n += 1
	return {"hired": hired, "levels": levels, "levels_goal": cfg.goal_levels, "wishes": wishes.size(), "wishes_goal": cfg.goal_wishes,
			"kin": kin.size(), "kin_goal": cfg.goal_kin, "steps": steps, "steps_goal": cfg.goal_steps, "full": full,
			"full_goal": cfg.goal_full_stories, "insight": insight, "done": n, "total": parts.size()}


## The fulfilled wishes (Visitors' saved list §5.1, state done).
func done_wishes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var visitors := _first(&"visitors")
	if visitors == null or not visitors.has_method(&"save_state"):
		return out
	var state: Variant = visitors.call(&"save_state")
	var list: Variant = (state as Dictionary).get("wishes", []) if state is Dictionary else []
	if list is Array:
		for w: Variant in list:
			if w is Dictionary and str((w as Dictionary).get("state", "")) == "done":
				out.append(w)
	return out


## Context of the chapter panel (§1.5): the graveyard's summary_context with variant/chapter who_comes_up,
## the days since p8_open, the Phase-8 statistics, Jakob's levels and the final line by piety tier.
func chapter_context() -> Dictionary:
	var cfg := _cfg()
	var context := {}
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"summary_context"):
		context = graveyard.call(&"summary_context")
	context["variant"] = cfg.chapter_id
	context["chapter"] = cfg.chapter_id
	context["days_open"] = maxi(TimeManager.day - open_day(), 0) if open_day() > 0 else 0
	for stat: StringName in [&"visits_seen", &"visits_total", &"wishes_done", &"wishes_failed", &"tips_coins", &"apprentice_jobs",
			&"apprentice_mistakes", &"apprentice_wage", &"friend_steps", &"favors_used", &"favors_returned", &"dances",
			&"robber_encounters", &"night_visits_observed", &"listens", &"chatters_seen"]:
		context[String(stat)] = GameState.get_stat(stat)
	var apprentice := _first(&"apprentice")
	if apprentice != null and apprentice.has_method(&"level"):
		var lv := {}
		for task: StringName in [&"rake", &"weed", &"water", &"candle"]:
			lv[String(task)] = int(apprentice.call(&"level", task))
		context["apprentice_levels"] = lv
	context["goal"] = goal_progress()
	context["final_line"] = str(FINAL_LINES.get(DialogueConditions.piety_tier(), FINAL_LINE_DEFAULT))
	return context


# --- save -----------------------------------------------------------------------------------------

## {open_day, events, event_npcs, listened, chatter_day, goal_done} (§5.1).
func save_state() -> Dictionary:
	var npcs := {}
	for ev: StringName in _event_npcs:
		npcs[String(ev)] = (_event_npcs[ev] as Array).map(func(n: Variant) -> String: return str(n))
	return {"open_day": maxi(_open_day, open_day()), "events": _days_out(_events), "event_npcs": npcs,
			"listened": _days_out(_listened), "chatter_day": _days_out(_chatter_day), "goal_done": _goal_done}


## Tolerant: missing / damaged keys fall back to the defaults ({} = a migrated v6 save).
func load_state(data: Dictionary) -> void:
	_loaded_v7 = not data.is_empty()
	_unlock_seen_total = -1
	_rolled_day = TimeManager.day if TimeManager.minute_of_day >= _cfg().intro_minute else -1
	mood_override.clear()
	var od: Variant = data.get("open_day", 0)
	_open_day = maxi(int(od), 0) if od is int or od is float else 0
	_events = _days_in(data.get("events"))
	_event_npcs.clear()
	var raw: Variant = data.get("event_npcs", {})
	if raw is Dictionary:
		for key: Variant in raw:
			var list: Variant = (raw as Dictionary)[key]
			if list is Array and _events.has(StringName(str(key))):
				var who: Array = []
				for n: Variant in list:
					if n is String or n is StringName:
						who.append(StringName(str(n)))
				_event_npcs[StringName(str(key))] = who
	_listened = _days_in(data.get("listened"))
	_chatter_day = _days_in(data.get("chatter_day"))
	var done: Variant = data.get("goal_done", false)
	_goal_done = done is bool and done


# --- internals ------------------------------------------------------------------------------------

func villager(npc_id: StringName) -> VillagerData:
	if not villagers.is_empty():
		return villagers.get(npc_id)
	return Database.villager(npc_id) as VillagerData


func _on_time_tick(day: int, _minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_morning(day)


## Records the unlock time (own bookkeeping only; opening follows in apply_morning).
func _on_chapter_completed(chapter_id: StringName) -> void:
	if _unlock_seen_total < 0 and not is_open() and GameState.flag_on(_cfg().unlock_flag) and chapter_id != _cfg().chapter_id:
		_unlock_seen_total = TimeManager.total_minutes()


func _on_goal_input() -> void:
	if not SaveManager.is_loading and is_open():
		check_goal()


func _on_friend_step(npc_id: StringName, _step: int) -> void:
	note_event(StringName(MoodRules.PREFIX_STEP + String(npc_id)))
	_on_goal_input()


func _on_lecture(_day: int, _organ: StringName, _fee: int, rumor: bool) -> void:
	if rumor:
		note_event(EVENT_LECTURE_RUMOR)


## A specimen of a village dead (CorpseRecord.kin_house set) sold → specimen_sold_villager.
func _on_specimen(uid: String, state: StringName) -> void:
	if state != &"sold":
		return
	var specimens := _first(&"specimens")
	var corpses := _first(&"corpse_manager")
	if specimens == null or corpses == null or not specimens.has_method(&"get_record") or not corpses.has_method(&"get_record"):
		return
	var spec := specimens.call(&"get_record", uid) as SpecimenRecord
	var rec := corpses.call(&"get_record", spec.corpse_id) as CorpseRecord if spec != null else null
	if rec != null and rec.kin_house != &"":
		note_event(EVENT_SPECIMEN_VILLAGER)


func _on_robber_event(kind: StringName, _grave_id: String) -> void:
	if kind == &"disturbed":
		note_event(EVENT_GRAVE_DISTURBED)


func _has_insight(id: StringName) -> bool:
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"has_insight"):
		return bool(journal.call(&"has_insight", id))
	var data := Database.insight(id) as InsightData
	return data != null and data.sets_flag != &"" and GameState.flag_on(data.sets_flag)


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _cfg() -> NpcLifeConfig:
	if config == null:
		config = Database.config(&"npc_life_config") as NpcLifeConfig
		if config == null:
			config = NpcLifeConfig.new()
	return config


## The first total minute with the clock at `intro_minute` strictly after `seen_total` (as Village).
static func _open_at(seen_total: int, intro_minute: int) -> int:
	var day_index := floori(float(seen_total - intro_minute) / MINUTES_PER_DAY) + 1
	return day_index * MINUTES_PER_DAY + intro_minute


static func _with_day(raw: Variant, day: int) -> Variant:
	if raw == null:
		return day
	var list: Array = raw if raw is Array else [raw]
	list.append(day)
	return list


static func _days_out(days: Dictionary[StringName, int]) -> Dictionary:
	var out := {}
	for id: StringName in days:
		out[String(id)] = days[id]
	return out


static func _days_in(raw: Variant) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = (raw as Dictionary)[key]
			if v is int or v is float:
				out[StringName(str(key))] = int(v)
	return out
