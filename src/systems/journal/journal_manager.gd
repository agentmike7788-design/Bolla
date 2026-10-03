class_name JournalManager
extends Node
## The journal ("Merkbuch", docs/PHASE4_DESIGN.md §2.12, §3.4, §5.1, §7). Systems/Journal
## (groups &"journal", &"saveable"). Four pages:
##   people   – death notes, derived from the CorpseRecords (never saved)
##   clues    – saved; add_clue also sets the flag clue_<id> (dialogue conditions)
##   insights – saved; linking exactly the required 2–3 clues (a wrong link costs nothing)
##   self     – the piety tier as a sentence plus prepared / utilized counts (derived)
## Callers change the journal directly (CorpseCare, ExpansionManager, dialogue add_clue); the
## only listener (ghost_spoke) caches the heard ghost line for the death note – display only.
##
## UI context API (the panel &"journal" is W-UI's): panel_context(page), people(),
## clue_cards(), open_question_cards(), insight_pages(), self_page(), unread_count(),
## is_unread(id), mark_read(ids), try_link(ids) + LINK_FAIL_TEXT.
##
## Data: clue_data / insight_data / find_data default to Database (data/journal/**, data/finds);
## tests assign fixtures. Save (§5.1): {"clues": {id: {"day", "corpse", "count"}},
## "insights": {id: day}, "unread": [ids]}.

const GROUP := &"journal"
const PANEL := &"journal"
const PAGE_PEOPLE := &"people"
const PAGE_CLUES := &"clues"
const PAGE_INSIGHTS := &"insights"
const PAGE_SELF := &"self"
const PAGES: Array[StringName] = [PAGE_PEOPLE, PAGE_CLUES, PAGE_INSIGHTS, PAGE_SELF]
const CLUE_FLAG_PREFIX := "clue_"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const GHOSTS_GROUP := &"ghosts"
const NOTIFY_INFO := &"info"
const NOTIFY_REWARD := &"reward"
const CLUE_NOTE := "Ins Merkbuch: %s"
const INSIGHT_NOTE := "Erkenntnis: %s"
## Shown by the panel after a link that matches no insight (§2.12) – not counted.
const LINK_FAIL_TEXT := "Diese Hinweise erzählen noch keine gemeinsame Geschichte."
const MINUTES_PER_DAY := 1440

@export var save_id: String = "journal"
@export var save_order: int = 40

## Data sources; empty = Database (resolved lazily).
var clue_data: Array[ClueData] = []
var insight_data: Array[InsightData] = []
var find_data: Array[FindData] = []
## Piety tiers; null = data/config/piety_config.tres.
var piety_config: PietyConfig

## clue id -> {day: int, corpse: String, count: int}
var _clues: Dictionary[StringName, Dictionary] = {}
## insight id -> day unlocked
var _insights: Dictionary[StringName, int] = {}
## Clue / insight ids not yet seen in the panel, oldest first.
var _unread: Array[StringName] = []
## clue id -> {corpse_id: true} – the dead already counted (rebuilt from the records, not saved).
var _counted: Dictionary[StringName, Dictionary] = {}
## grave_id -> ghost line heard this session (display only, not saved).
var _heard_text: Dictionary[String, String] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	if not EventBus.ghost_spoke.is_connected(_on_ghost_spoke):
		EventBus.ghost_spoke.connect(_on_ghost_spoke)


func _exit_tree() -> void:
	if EventBus.ghost_spoke.is_connected(_on_ghost_spoke):
		EventBus.ghost_spoke.disconnect(_on_ghost_spoke)


# --- clues ------------------------------------------------------------------------------------

func has_clue(id: StringName) -> bool:
	return _clues.has(id)


## false = already there (then only the counter of the dead, once per corpse); otherwise sets
## clue_<id>, marks it unread, emits clue_found and notifies "Ins Merkbuch: <Titel>".
## silent (migration / load): no unread mark, no signal, no notification.
func add_clue(id: StringName, corpse_id: String = "", silent: bool = false) -> bool:
	var clue := clue_by_id(id)
	if clue == null:
		push_warning("[Journal] unknown clue '%s' ignored" % id)
		return false
	if _clues.has(id):
		_count(id, corpse_id)
		return false
	_clues[id] = {"day": TimeManager.day, "corpse": corpse_id, "count": 0}
	_count(id, corpse_id)
	GameState.set_flag(StringName(CLUE_FLAG_PREFIX + String(id)), true)
	if not silent:
		_mark_unread(id)
		EventBus.clue_found.emit(id, corpse_id)
		EventBus.notification_requested.emit(CLUE_NOTE % clue.title, NOTIFY_INFO)
	return true


## How many dead carry the (generic) clue; 0 for clues without a corpse (Ilse's).
func clue_count(id: StringName) -> int:
	return int(_clues[id].get("count", 0)) if _clues.has(id) else 0


## Found clues in data order.
func clues() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: ClueData in _clue_list():
		if _clues.has(c.id):
			out.append(c.id)
	for id: StringName in _clues:
		if not out.has(id):
			out.append(id)
	return out


## Day the clue was found (0 = not found).
func clue_day(id: StringName) -> int:
	return int(_clues[id].get("day", 0)) if _clues.has(id) else 0


# --- insights ---------------------------------------------------------------------------------

## Links the selected clues (all must be found). A match unlocks the insight: day, flag
## (sets_flag), unread mark, renaming of the story corpse (rename_story → rename_to, through the
## CorpseManager), insight_unlocked and "Erkenntnis: <Titel>". &"" = no match, no consequences.
func try_link(ids: Array[StringName]) -> StringName:
	for id: StringName in ids:
		if not _clues.has(id):
			return &""
	var match_id := JournalRules.match_insight(ids, _insight_list(), _insights)
	if match_id == &"":
		return &""
	var insight := insight_by_id(match_id)
	_insights[match_id] = TimeManager.day
	if insight.sets_flag != &"":
		GameState.set_flag(insight.sets_flag, true)
	_mark_unread(match_id)
	_apply_rename(insight)
	EventBus.insight_unlocked.emit(match_id)
	EventBus.notification_requested.emit(INSIGHT_NOTE % insight.title, NOTIFY_REWARD)
	return match_id


## Unlocked insights in data order.
func insights() -> Array[StringName]:
	var out: Array[StringName] = []
	for i: InsightData in _insight_list():
		if _insights.has(i.id):
			out.append(i.id)
	for id: StringName in _insights:
		if not out.has(id):
			out.append(id)
	return out


func has_insight(id: StringName) -> bool:
	return _insights.has(id)


## Unlocked main insights (not optional) – "n/5" in the chapter panel and on the page "Ich"
## (QA4-07: the optional Kranichfrau made it 6/5).
func main_insight_count() -> int:
	var n := 0
	for id: StringName in _insights:
		var i := insight_by_id(id)
		if i == null or not i.optional:
			n += 1
	return n


## Insights with a found clue that are not linked yet (column "Offene Fragen").
func open_questions() -> Array[InsightData]:
	return JournalRules.open_questions(_clues, _insight_list(), _insights)


## All clues there, not linked yet (objective line, once per insight until linked).
func ready_insights() -> Array[InsightData]:
	return JournalRules.ready_insights(_clues, _insight_list(), _insights)


# --- the dead (derived) -----------------------------------------------------------------------

## Death notes, newest first: {corpse_id, name, age, cause, cause_label, day, grave_id, story_id,
## finds: [{id, step, label, text, clue}], lost: [{id, step, label, text}], washed, dress,
## laid_out, harvested, heard: String (ghost line heard this session, else ""), heard_any: bool}.
func people() -> Array[Dictionary]:
	var records := _records()
	records.sort_custom(func(a: CorpseRecord, b: CorpseRecord) -> bool:
		if a.arrival_total_minutes != b.arrival_total_minutes:
			return a.arrival_total_minutes > b.arrival_total_minutes
		return a.id > b.id)
	var tables := Database.corpse_tables() as CorpseTables
	var out: Array[Dictionary] = []
	for r: CorpseRecord in records:
		var cause: Dictionary = tables.get_cause(r.cause_id) if tables != null else {}
		var finds: Array[Dictionary] = []
		for fid: StringName in r.finds_revealed:
			var f := find_by_id(fid)
			finds.append({"id": fid, "step": f.step if f != null else &"", "label": f.label if f != null else "",
					"text": _find_text(f, r, tables), "clue": f.clue_id if f != null else &""})
		var lost: Array[Dictionary] = []
		for fid: StringName in r.finds_lost:
			var f := find_by_id(fid)
			lost.append({"id": fid, "step": f.step if f != null else &"", "label": f.label if f != null else "",
					"text": f.lost_text if f != null else ""})
		out.append({
			"corpse_id": r.id, "name": _display_name(r), "age": r.age, "cause": r.cause_id,
			"cause_label": String(cause.get("label", "")), "day": _day_of(r.arrival_total_minutes),
			"grave_id": r.grave_id, "story_id": r.story_id, "finds": finds, "lost": lost,
			"washed": r.washed, "dress": r.dress, "laid_out": r.laid_out, "harvested": r.harvested.duplicate(),
			"heard": _heard_text.get(r.grave_id, "") if r.grave_id != "" else "",
			"heard_any": _was_heard(r.grave_id),
		})
	return out


# --- unread -----------------------------------------------------------------------------------

func unread() -> Array[StringName]:
	return _unread.duplicate()


func unread_count() -> int:
	return _unread.size()


func is_unread(id: StringName) -> bool:
	return _unread.has(id)


func mark_read(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		_unread.erase(id)


# --- UI context -------------------------------------------------------------------------------

## Context for ui_panel_requested(&"journal", …) – §7: {page: StringName} (+ the journal node).
func panel_context(page: StringName = PAGE_PEOPLE) -> Dictionary:
	return {"page": page if page in PAGES else PAGE_PEOPLE, "journal": self}


## Clue cards in data order: {id, title, text, kind, count, day, unread}.
func clue_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in clues():
		var c := clue_by_id(id)
		out.append({"id": id, "title": c.title if c != null else String(id), "text": c.text if c != null else "",
				"kind": c.kind if c != null else &"", "count": clue_count(id), "day": clue_day(id), "unread": is_unread(id)})
	return out


## Open questions: {id, question, found: n, needed: n}.
func open_question_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: InsightData in open_questions():
		var found := 0
		for id: StringName in i.requires:
			if _clues.has(id):
				found += 1
		out.append({"id": i.id, "question": i.question, "found": found, "needed": i.requires.size(), "optional": i.optional})
	return out


## Unlocked insights in data order: {id, title, question, text, day, unread}.
func insight_pages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in insights():
		var i := insight_by_id(id)
		out.append({"id": id, "title": i.title if i != null else String(id), "question": i.question if i != null else "",
				"text": i.text if i != null else "", "day": _insights[id], "unread": is_unread(id)})
	return out


## Page "Ich": {tier, label, sentence, prepared, utilized, insights, insights_total} – no number
## for the piety itself (§7).
func self_page() -> Dictionary:
	var tier := JournalRules.piety_tier(GameState.get_stat(&"piety"), _piety_config())
	var label := PietyRules.label(tier)
	if label == "":
		label = String(PietyRules.LABELS.get(String(tier), ""))
	var main := 0
	for i: InsightData in _insight_list():
		if not i.optional:
			main += 1
	return {"tier": tier, "label": label, "sentence": PietyRules.self_image(tier),
			"prepared": GameState.get_stat(&"prepared"), "utilized": GameState.get_stat(&"utilized"),
			"insights": main_insight_count(), "insights_total": main}


# --- sync / save ------------------------------------------------------------------------------

## Silently: clues of every revealed find of all records (migration, load); idempotent.
## Rebuilds the "counted dead" memory. Returns the number of clues added.
func sync_from_records() -> int:
	var added := 0
	for r: CorpseRecord in _records():
		for fid: StringName in r.finds_revealed:
			var f := find_by_id(fid)
			if f == null or f.clue_id == &"":
				continue
			if not _clues.has(f.clue_id) and clue_by_id(f.clue_id) != null:
				if add_clue(f.clue_id, r.id, true):
					_clues[f.clue_id]["day"] = maxi(1, _day_of(r.arrival_total_minutes))
					added += 1
			else:
				_count(f.clue_id, r.id)
	return added


func save_state() -> Dictionary:
	var clues_out := {}
	for id: StringName in _clues:
		var e: Dictionary = _clues[id]
		clues_out[String(id)] = {"day": int(e.get("day", 0)), "corpse": String(e.get("corpse", "")), "count": int(e.get("count", 0))}
	var insights_out := {}
	for id: StringName in _insights:
		insights_out[String(id)] = _insights[id]
	var unread_out: Array[String] = []
	for id: StringName in _unread:
		unread_out.append(String(id))
	return {"clues": clues_out, "insights": insights_out, "unread": unread_out}


## Replaces everything; tolerant of missing / damaged parts (a bad entry is skipped).
func load_state(data: Dictionary) -> void:
	_clues.clear()
	_insights.clear()
	_unread.clear()
	_counted.clear()
	var saved_clues: Variant = data.get("clues", {})
	if saved_clues is Dictionary:
		for key: Variant in saved_clues:
			var e: Variant = (saved_clues as Dictionary)[key]
			if not (key is String or key is StringName) or not e is Dictionary:
				push_warning("[Journal] damaged clue entry '%s' skipped" % str(key))
				continue
			var id := StringName(str(key))
			var corpse := str((e as Dictionary).get("corpse", ""))
			_clues[id] = {"day": maxi(0, _to_int((e as Dictionary).get("day"), 0)), "corpse": corpse,
					"count": maxi(0, _to_int((e as Dictionary).get("count"), 0))}
			if corpse != "":
				_counted[id] = {corpse: true}
	var saved_insights: Variant = data.get("insights", {})
	if saved_insights is Dictionary:
		for key: Variant in saved_insights:
			if key is String or key is StringName:
				# Phase 7 (P6, fuzzer v6): an unknown insight id of a damaged save is dropped.
				if not _insight_list().is_empty() and insight_by_id(StringName(str(key))) == null:
					push_warning("[Journal] unknown insight '%s' skipped" % str(key))
					continue
				_insights[StringName(str(key))] = maxi(0, _to_int((saved_insights as Dictionary)[key], 0))
	var saved_unread: Variant = data.get("unread", [])
	if saved_unread is Array:
		for v: Variant in saved_unread:
			if (v is String or v is StringName) and not _unread.has(StringName(str(v))):
				var id := StringName(str(v))
				if _clues.has(id) or _insights.has(id):
					_unread.append(id)


## → sync_from_records (§5.2 step 4: a migrated Phase-3 save gets its clues quietly).
func post_load() -> void:
	sync_from_records()


# --- data -------------------------------------------------------------------------------------

func clue_by_id(id: StringName) -> ClueData:
	for c: ClueData in _clue_list():
		if c.id == id:
			return c
	return null


func insight_by_id(id: StringName) -> InsightData:
	for i: InsightData in _insight_list():
		if i.id == id:
			return i
	return null


func find_by_id(id: StringName) -> FindData:
	for f: FindData in _find_list():
		if f.id == id:
			return f
	return null


func _clue_list() -> Array[ClueData]:
	if clue_data.is_empty():
		for res: Resource in Database.clues():
			if res is ClueData:
				clue_data.append(res)
	return clue_data


func _insight_list() -> Array[InsightData]:
	if insight_data.is_empty():
		for res: Resource in Database.insights():
			if res is InsightData:
				insight_data.append(res)
	return insight_data


func _find_list() -> Array[FindData]:
	if find_data.is_empty():
		for res: Resource in Database.finds():
			if res is FindData:
				find_data.append(res)
	return find_data


func _piety_config() -> PietyConfig:
	if piety_config == null:
		piety_config = Database.config(&"piety_config") as PietyConfig
	return piety_config


# --- helpers ----------------------------------------------------------------------------------

## Counts `corpse_id` once for clue `id`.
func _count(id: StringName, corpse_id: String) -> void:
	if corpse_id == "" or not _clues.has(id):
		return
	var seen: Dictionary = _counted.get(id, {})
	if seen.has(corpse_id):
		return
	seen[corpse_id] = true
	_counted[id] = seen
	# The saved count stays the floor after a load; the records (post_load sync) and new corpses
	# only raise it – the same dead is never counted twice.
	_clues[id]["count"] = maxi(int(_clues[id].get("count", 0)), seen.size())


func _mark_unread(id: StringName) -> void:
	if not _unread.has(id):
		_unread.append(id)


func _apply_rename(insight: InsightData) -> void:
	if insight.rename_story == &"" or insight.rename_to == "":
		return
	var manager := _corpse_manager()
	for r: CorpseRecord in _records():
		if r.story_id == insight.rename_story and r.display_name != insight.rename_to:
			r.display_name = insight.rename_to
			if manager != null and manager.has_method(&"notify_changed"):
				manager.call(&"notify_changed", r.id)


## The record name, or the renamed one once the insight is known (§2.11 step 6).
func _display_name(r: CorpseRecord) -> String:
	if r.story_id != &"":
		for id: StringName in _insights:
			var i := insight_by_id(id)
			if i != null and i.rename_story == r.story_id and i.rename_to != "":
				return i.rename_to
	return r.display_name


func _find_text(f: FindData, r: CorpseRecord, tables: CorpseTables) -> String:
	if f == null:
		return ""
	if f.text != "":
		return f.text
	if f.trait_id != &"" and tables != null:
		return String(tables.get_trait(f.trait_id).get("reveal_text", ""))
	if f.cause_id != &"" and tables != null:
		return String(tables.get_cause(r.cause_id).get("description", ""))
	return ""


func _records() -> Array[CorpseRecord]:
	var manager := _corpse_manager()
	if manager == null or not manager.has_method(&"records"):
		return []
	var out: Array[CorpseRecord] = []
	for r: Variant in manager.call(&"records"):
		if r is CorpseRecord:
			out.append(r)
	return out


func _corpse_manager() -> Node:
	return get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP) if is_inside_tree() else null


func _was_heard(grave_id: String) -> bool:
	if grave_id == "":
		return false
	if _heard_text.has(grave_id):
		return true
	var ghosts := get_tree().get_first_node_in_group(GHOSTS_GROUP) if is_inside_tree() else null
	return ghosts != null and ghosts.has_method(&"was_heard") and bool(ghosts.call(&"was_heard", grave_id))


func _on_ghost_spoke(grave_id: String, _mood: StringName, text: String) -> void:
	_heard_text[grave_id] = text


static func _day_of(total_minutes: int) -> int:
	@warning_ignore("integer_division")
	return maxi(0, total_minutes) / MINUTES_PER_DAY + 1


static func _to_int(v: Variant, fallback: int) -> int:
	if v is int or v is float:
		return int(v)
	return fallback
