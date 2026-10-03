class_name Deductions
extends Node
## Systems/Deductions (docs/PHASE7_DESIGN.md §2.6.5, §3.1, §3.4, §5.1), groups &"deductions",
## &"saveable": the cards per dead person (finding cards from inspection / expertise + the revealed
## finds of the examination + the known teachings), the deduction in the journal: choose 2–3 cards and a
## cause → „Deuten". Right (once per deduction): CorpseRecord.revealed_cause, JournalManager.add_clue,
## stats.deductions, cause_deduced. Wrong: „Das passt nicht zusammen." – nothing, not counted, as often
## as one likes. The story's required insight (i_deathbook) needs no specimen; only the optional
## „Verbrennt es" rests on the deduction d_still_heart.

const GROUP := &"deductions"
const STAT_DEDUCTIONS := &"deductions"
const FINDING_PREFIX := "b_"

@export var save_id: String = "deductions"
@export var save_order: int = 56

## Deductions; empty = Database.deductions().
var deductions: Array[DeductionData] = []

var _cards: Dictionary[String, PackedStringArray] = {}
var _done: Dictionary[String, PackedStringArray] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## A finding card (or any card) for this dead person, once.
func add_card(corpse_id: String, card_id: StringName) -> void:
	if corpse_id == "" or card_id == &"":
		return
	var list: PackedStringArray = _cards.get(corpse_id, PackedStringArray())
	if not list.has(String(card_id)):
		list.append(String(card_id))
		_cards[corpse_id] = list


## Findings + revealed finds + teachings (in that order, no duplicates).
func cards(corpse_id: String) -> PackedStringArray:
	var out: PackedStringArray = _cards.get(corpse_id, PackedStringArray()).duplicate()
	var record := _corpse(corpse_id)
	if record != null:
		for f: StringName in record.finds_revealed:
			if not out.has(String(f)):
				out.append(String(f))
	var lectures := _first(&"lectures") as Lectures
	if lectures != null:
		for t: String in lectures.known_teachings():
			if not out.has(t):
				out.append(t)
	return out


## The finding cards of this dead person only.
func finding_cards(corpse_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in _cards.get(corpse_id, PackedStringArray()):
		if _is_finding(id):
			out.append(id)
	return out


## At least one finding card.
func can_deduce(corpse_id: String) -> bool:
	return not finding_cards(corpse_id).is_empty()


## {ok, cause, clue, text} (+ deduction, repeat). The chosen cards must be 2–3 of cards(corpse_id).
func deduce(corpse_id: String, cards_chosen: PackedStringArray, cause: StringName) -> Dictionary:
	var wrong := {"ok": false, "cause": &"", "clue": &"", "text": DeductionRules.TEXT_NO_MATCH}
	if not can_deduce(corpse_id):
		return wrong
	if cards_chosen.size() < DeductionRules.MIN_CARDS or cards_chosen.size() > DeductionRules.MAX_CARDS:
		return wrong
	var held := cards(corpse_id)
	for id: String in cards_chosen:
		if not held.has(id):
			return wrong
	var record := _corpse(corpse_id)
	var shown: StringName = record.cause_id if record != null else &""
	var d := DeductionRules.find_for(_deductions(), cards_chosen, cause, shown)
	if d == null:
		return wrong
	var text := d.text if d.text != "" else DeductionRules.TEXT_MATCH
	var done: PackedStringArray = _done.get(corpse_id, PackedStringArray())
	if done.has(String(d.id)):
		return {"ok": true, "cause": d.cause_id, "clue": &"", "text": text, "deduction": d.id, "repeat": true}
	done.append(String(d.id))
	_done[corpse_id] = done
	if d.reveals_cause and record != null:
		record.revealed_cause = d.cause_id
	var clue := &""
	if d.clue_id != &"":
		var journal := _first(&"journal") as JournalManager
		if journal != null:
			journal.add_clue(d.clue_id, corpse_id)
		clue = d.clue_id
	GameState.add_stat(STAT_DEDUCTIONS, 1)
	EventBus.cause_deduced.emit(corpse_id, d.cause_id)
	EventBus.notification_requested.emit(DeductionRules.TEXT_MATCH, &"info")
	var manager := _first(&"corpse_manager") as CorpseManager
	if manager != null and record != null:
		manager.notify_changed(corpse_id)
	return {"ok": true, "cause": d.cause_id, "clue": clue, "text": text, "deduction": d.id, "repeat": false}


## Deduction ids done for this dead person.
func deduced(corpse_id: String) -> PackedStringArray:
	return _done.get(corpse_id, PackedStringArray()).duplicate()


## {cards: {corpse_id: [...]}, done: {corpse_id: [...]}} (§5.1); {} while empty.
func save_state() -> Dictionary:
	if _cards.is_empty() and _done.is_empty():
		return {}
	return {"cards": _write(_cards), "done": _write(_done)}


func load_state(data: Dictionary) -> void:
	_cards = _read(data.get("cards"))
	_done = _read(data.get("done"))


static func _write(d: Dictionary[String, PackedStringArray]) -> Dictionary:
	var out := {}
	var keys: Array = d.keys()
	keys.sort()
	for key: String in keys:
		out[key] = Array(d[key])
	return out


static func _read(v: Variant) -> Dictionary[String, PackedStringArray]:
	var out: Dictionary[String, PackedStringArray] = {}
	if v is Dictionary:
		for key: Variant in v:
			var list: Variant = (v as Dictionary)[key]
			if list is Array or list is PackedStringArray:
				var ids := PackedStringArray()
				for id: Variant in list:
					if (id is String or id is StringName) and not ids.has(str(id)):
						ids.append(str(id))
				out[str(key)] = ids
	return out


func _is_finding(id: String) -> bool:
	if Database.finding(StringName(id)) != null:
		return true
	return id.begins_with(FINDING_PREFIX)


func _deductions() -> Array[DeductionData]:
	if deductions.is_empty():
		for res: Resource in Database.deductions():
			if res is DeductionData:
				deductions.append(res as DeductionData)
	return deductions


func _corpse(corpse_id: String) -> CorpseRecord:
	var manager := _first(&"corpse_manager") as CorpseManager
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
