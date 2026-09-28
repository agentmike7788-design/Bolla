class_name CorpseCare
extends Node
## Examination steps, preparation and harvesting at the morgue table (docs/PHASE4_DESIGN.md
## §2.1–§2.6, §3.4). Systems/CorpseCare, group &"corpse_care", not saved: the state lives in
## the CorpseRecord. Calls JournalManager.add_clue, Piety.event, Reputation.event and
## CorpseManager.notify_changed directly (group API); the EventBus signals exam_step_done /
## corpse_prepared / corpse_harvested come on top. Every successful preparation emits
## corpse_prepared; the 3rd part (washed ∧ dressed ∧ laid out) → Piety.event(&"full_prep"),
## stats.prepared +1. Timing is the caller's job (MorgueTable runs the timed actions).

const GROUP := &"corpse_care"
const MANAGER_GROUP := &"corpse_manager"
const JOURNAL_GROUP := &"journal"
const PIETY_GROUP := &"piety"
const REPUTATION_GROUP := &"reputation"
const EVENT_FULL_PREP := &"full_prep"
const STAT_PREPARED := &"prepared"
const STAT_UTILIZED := &"utilized"
const FLAG_TRADER_KNOWN := &"trader_known"
const FLAG_PIETY_USED_DAY := &"piety_used_day"
const REASON_FULL_PREP := "Voll hergerichtet"
const REASON_NO_CORPSE := "Auf dem Tisch liegt keine Leiche."
const REASON_BURIED := "Die Leiche ist schon bestattet."
const REASON_DRESSED := "Nach dem Einkleiden nicht mehr möglich."
const REASON_HARVESTED := "Das ist schon genommen."
const REASON_INVENTORY_FULL := "Kein Platz im Inventar."
const REASON_UNKNOWN_KIND := "Das geht hier nicht."

## Injected configs / data (tests); null or empty = data/ via Database on first use.
var exam_config: ExamConfig
var prep_config: PrepConfig
var utilization_config: UtilizationConfig
var tables: CorpseTables
var finds: Array[FindData] = []
## story_id → StoryCorpseData (empty = Database.story_corpse).
var stories: Dictionary[StringName, StoryCorpseData] = {}
## Rule for harvest_block_reason: func(record, kind, inv, cfg, known) -> String.
## Invalid (default) = UtilizationRules.block_reason; tests may inject another rule.
var harvest_rule: Callable


func _init() -> void:
	add_to_group(GROUP, true)


# --- examination ---------------------------------------------------------------------------

func step_block_reason(id: String, step: StringName) -> String:
	var record := get_record(id)
	var live := _live_reason(record)
	if live != "":
		return live
	return CorpseExam.block_reason(record, step, _exam())


## Steps still open for `id` (config order); empty for unknown / buried corpses.
func open_steps(id: String) -> Array[StringName]:
	var record := get_record(id)
	if _live_reason(record) != "":
		return [] as Array[StringName]
	return CorpseExam.open_steps(record, _exam())


## Minutes of all open steps ("Gründlich untersuchen").
func exam_all_minutes(id: String) -> int:
	return CorpseExam.minutes_for(open_steps(id), _exam())


## Resolves the step, sets examined, flags (sets_flag), clues (JournalManager.add_clue),
## exam_step_done, notify_changed. {step, revealed, lost} ({} = refused).
func exam_step(id: String, step: StringName) -> Dictionary:
	if step_block_reason(id, step) != "":
		return {}
	var record := get_record(id)
	var result := _resolve_step(record, step)
	_finish_exam(record, [step] as Array[StringName], result)
	return {"step": step, "revealed": result.revealed, "lost": result.lost}


## All open steps (called after the combined timed action), each resolved with the freshness
## at the end. {steps, revealed, lost} ({} = nothing open).
func exam_all(id: String) -> Dictionary:
	var steps := open_steps(id)
	if steps.is_empty():
		return {}
	var record := get_record(id)
	var revealed: Array[StringName] = []
	var lost: Array[StringName] = []
	for step: StringName in steps:
		var one := _resolve_step(record, step)
		revealed.append_array(one.revealed)
		lost.append_array(one.lost)
		_emit_step(record, step, one)
	_after_exam(record, revealed)
	return {"steps": steps, "revealed": revealed, "lost": lost}


## Debug / Phase-2 API: like exam_all, without time.
func exam_all_instant(id: String) -> Dictionary:
	return exam_all(id)


## Finds a step of `id` still has to resolve (open steps only) – for the panel / next_loss.
func pending_finds(id: String) -> Array[FindData]:
	var out: Array[FindData] = []
	var record := get_record(id)
	if record == null:
		return out
	for step: StringName in open_steps(id):
		out.append_array(CorpseExam.candidates(record, step, _finds(), _story(record), _exam()))
	return out


## The finds `step` of `id` can reveal (resolved or not) – the panel groups its cards with it.
func step_finds(id: String, step: StringName) -> Array[FindData]:
	var record := get_record(id)
	if record == null:
		return [] as Array[FindData]
	return CorpseExam.candidates(record, step, _finds(), _story(record), _exam())


## For the UI hint (CorpseExam.next_loss of the pending finds at the current time).
func next_loss(id: String) -> Dictionary:
	var record := get_record(id)
	if _live_reason(record) != "":
		return {}
	return CorpseExam.next_loss(record, pending_finds(id), TimeManager.total_minutes(),
			CorpseDecay.decay_per_hour(record, _tables()), _prep().balm_factor)


## Card text of a find on `id`: FindData.text, "" = the trait's reveal_text; lost → lost_text.
func find_text(id: String, find_id: StringName) -> String:
	var f := _find(find_id)
	if f == null:
		return ""
	var record := get_record(id)
	if record != null and record.finds_lost.has(find_id):
		return f.lost_text
	if f.text != "":
		return f.text
	var t := _tables()
	if t != null and f.trait_id != &"":
		return String(t.get_trait(f.trait_id).get("reveal_text", ""))
	return ""


# --- preparation ---------------------------------------------------------------------------

func prep_block_reason(id: String, action: StringName, inv: Inventory, kind: StringName = &"") -> String:
	var record := get_record(id)
	var live := _live_reason(record)
	if live != "":
		return live
	return CorpsePrep.block_reason(record, action, inv, _prep(), kind)


func wash(id: String, inv: Inventory) -> bool:
	if prep_block_reason(id, CorpsePrep.ACTION_WASH, inv) != "":
		return false
	var record := get_record(id)
	record.washed = true
	_after_prep(record, CorpsePrep.ACTION_WASH)
	return true


## Takes 1 item; sets shrouded.
func dress(id: String, kind: StringName, inv: Inventory) -> bool:
	if prep_block_reason(id, CorpsePrep.ACTION_DRESS, inv, kind) != "":
		return false
	if not inv.remove_item(_prep().dress_item(kind), 1):
		return false
	var record := get_record(id)
	record.dress = kind
	record.shrouded = true
	_after_prep(record, CorpsePrep.ACTION_DRESS)
	return true


func lay_out(id: String, inv: Inventory) -> bool:
	if prep_block_reason(id, CorpsePrep.ACTION_LAY_OUT, inv) != "":
		return false
	var record := get_record(id)
	record.laid_out = true
	_after_prep(record, CorpsePrep.ACTION_LAY_OUT)
	return true


## Window [now, now + balm_window_minutes].
func apply_balm(id: String, inv: Inventory) -> bool:
	if prep_block_reason(id, CorpsePrep.ACTION_BALM, inv) != "":
		return false
	var cfg := _prep()
	if not inv.remove_item(cfg.balm_item, 1):
		return false
	var record := get_record(id)
	var now := TimeManager.total_minutes()
	record.balm_windows.append(now)
	record.balm_windows.append(now + cfg.balm_window_minutes)
	_after_prep(record, CorpsePrep.ACTION_BALM)
	return true


# --- harvest -------------------------------------------------------------------------------

## Via UtilizationRules.block_reason ("-" = no button: trader not known); then dressed,
## already taken and a full inventory.
func harvest_block_reason(id: String, kind: StringName, inv: Inventory) -> String:
	var record := get_record(id)
	var live := _live_reason(record)
	if live != "":
		return live
	var cfg := _util()
	var known := GameState.has_flag(FLAG_TRADER_KNOWN)
	var reason := String(harvest_rule.call(record, kind, inv, cfg, known)) if harvest_rule.is_valid() \
			else UtilizationRules.block_reason(record, kind, inv, cfg, known)
	if reason != "":
		return reason
	var entry := cfg.kind(kind)
	if entry.is_empty():
		return REASON_UNKNOWN_KIND
	if record.is_dressed():
		return REASON_DRESSED
	if record.is_harvested(kind):
		return REASON_HARVESTED
	if inv == null or not inv.can_add(StringName(entry.get("item", &"")), 1):
		return REASON_INVENTORY_FULL
	return ""


## Item into the inventory (full → refused), Piety.event, Reputation.event, stats.utilized,
## flag piety_used_day (= today), corpse_harvested, the done_text as a quiet note.
func harvest(id: String, kind: StringName, inv: Inventory) -> bool:
	if harvest_block_reason(id, kind, inv) != "":
		return false
	var entry := _util().kind(kind)
	var item := StringName(entry.get("item", &""))
	if inv.add_item(item, 1) > 0:
		return false
	var record := get_record(id)
	record.harvested.append(kind)
	var label := String(entry.get("label", String(kind)))
	var piety := _first(PIETY_GROUP) as Piety
	if piety != null:
		piety.event(StringName(entry.get("piety_event", &"")), label)
	var rep := _first(REPUTATION_GROUP) as Reputation
	if rep != null:
		rep.event(StringName(entry.get("reputation_event", &"")), label)
	GameState.add_stat(STAT_UTILIZED, 1)
	GameState.set_flag(FLAG_PIETY_USED_DAY, TimeManager.day)
	EventBus.corpse_harvested.emit(id, kind, item)
	var text := String(entry.get("done_text", ""))
	if text != "":
		EventBus.notification_requested.emit(text, &"info")
	_notify(id)
	return true


# --- records -------------------------------------------------------------------------------

func get_record(id: String) -> CorpseRecord:
	var manager := _first(MANAGER_GROUP) as CorpseManager
	return manager.get_record(id) if manager != null and id != "" else null


## The loaded StoryCorpseData of a story corpse (null otherwise).
func story_of(id: String) -> StoryCorpseData:
	return _story(get_record(id))


func _live_reason(record: CorpseRecord) -> String:
	if record == null:
		return REASON_NO_CORPSE
	if record.location == CorpseRecord.LOCATION_BURIED:
		return REASON_BURIED
	return ""


func _resolve_step(record: CorpseRecord, step: StringName) -> Dictionary:
	var cands := CorpseExam.candidates(record, step, _finds(), _story(record), _exam())
	var result := CorpseExam.resolve(record, cands)
	record.finds_revealed.append_array(result.revealed)
	record.finds_lost.append_array(result.lost)
	if not record.exam_done.has(step):
		record.exam_done.append(step)
	record.examined = true
	_reveal_traits(record, step, cands, result.revealed)
	return result


## Traits of this step: revealed when their find was revealed; traits without any find at all
## (no data) are revealed by the step itself.
func _reveal_traits(record: CorpseRecord, step: StringName, cands: Array[FindData], revealed: Array[StringName]) -> void:
	var covered := {}
	for f: FindData in cands:
		if f.trait_id == &"":
			continue
		covered[f.trait_id] = true
		if revealed.has(f.id) and not record.traits_revealed.has(f.trait_id):
			record.traits_revealed.append(f.trait_id)
	var cfg := _exam()
	for t: StringName in record.traits:
		if covered.has(t) or record.traits_revealed.has(t):
			continue
		if StringName(cfg.trait_steps.get(t, &"")) == step and not _has_generic_find(t):
			record.traits_revealed.append(t)


func _has_generic_find(trait_id: StringName) -> bool:
	for f: FindData in _finds():
		if f != null and f.trait_id == trait_id:
			return true
	return false


func _finish_exam(record: CorpseRecord, steps: Array[StringName], result: Dictionary) -> void:
	for step: StringName in steps:
		_emit_step(record, step, result)
	_after_exam(record, result.revealed)


func _emit_step(record: CorpseRecord, step: StringName, result: Dictionary) -> void:
	var revealed: Array[StringName] = []
	revealed.assign(result.revealed)
	var lost: Array[StringName] = []
	lost.assign(result.lost)
	EventBus.exam_step_done.emit(record.id, step, revealed, lost)


## Flags and clues of the revealed finds, then corpse_updated.
func _after_exam(record: CorpseRecord, revealed: Array) -> void:
	var journal := _first(JOURNAL_GROUP) as JournalManager
	for fid: StringName in revealed:
		var f := _find(fid)
		if f == null:
			continue
		if f.sets_flag != &"":
			GameState.set_flag(f.sets_flag, true)
		if f.clue_id != &"" and journal != null:
			journal.add_clue(f.clue_id, record.id)
	_notify(record.id)


func _after_prep(record: CorpseRecord, action: StringName) -> void:
	EventBus.corpse_prepared.emit(record.id, action)
	if action != CorpsePrep.ACTION_BALM and record.is_fully_prepared():
		var piety := _first(PIETY_GROUP) as Piety
		if piety != null:
			piety.event(EVENT_FULL_PREP, REASON_FULL_PREP)
		GameState.add_stat(STAT_PREPARED, 1)
	_notify(record.id)


func _notify(id: String) -> void:
	var manager := _first(MANAGER_GROUP) as CorpseManager
	if manager != null:
		manager.notify_changed(id)


# --- data ----------------------------------------------------------------------------------

func get_exam_config() -> ExamConfig:
	return _exam()


func get_prep_config() -> PrepConfig:
	return _prep()


func get_utilization_config() -> UtilizationConfig:
	return _util()


func get_find(id: StringName) -> FindData:
	return _find(id)


func _find(id: StringName) -> FindData:
	for f: FindData in _finds():
		if f != null and f.id == id:
			return f
	return null


func _finds() -> Array[FindData]:
	if finds.is_empty():
		for res: Resource in Database.finds():
			if res is FindData:
				finds.append(res as FindData)
	return finds


func _story(record: CorpseRecord) -> StoryCorpseData:
	if record == null or record.story_id == &"":
		return null
	if stories.has(record.story_id):
		return stories[record.story_id]
	return Database.story_corpse(record.story_id) as StoryCorpseData


func _exam() -> ExamConfig:
	if exam_config == null:
		exam_config = Database.config(&"exam_config") as ExamConfig
		if exam_config == null:
			exam_config = ExamConfig.new()
	return exam_config


func _prep() -> PrepConfig:
	if prep_config == null:
		prep_config = Database.config(&"prep_config") as PrepConfig
		if prep_config == null:
			prep_config = PrepConfig.new()
	return prep_config


func _util() -> UtilizationConfig:
	if utilization_config == null:
		utilization_config = Database.config(&"utilization_config") as UtilizationConfig
		if utilization_config == null:
			utilization_config = UtilizationConfig.new()
	return utilization_config


func _tables() -> CorpseTables:
	if tables == null:
		tables = Database.corpse_tables() as CorpseTables
	return tables


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
