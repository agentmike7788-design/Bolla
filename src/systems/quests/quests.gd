class_name Quests
extends Node
## STUB (P1) – Systems/Quests (docs/PHASE9_DESIGN.md §2.1, §1.2, §1.5, §3.1, §3.3, §3.4, §5.1), groups &"quests",
## &"saveable", save_id quests / 81: the slim chain core over the existing systems – the chains q_who_knows,
## q_letters, q_case (QuestData), their steps (done by existing events: flags, clues, insights, orders of category
## quest, notes, choices, endings), choices with DialogueActions, deadlines (06:00, fallback_choice), the pinned
## entry of „Vorhaben", the opening p9_open and the chapter „Wer weiß, wann?".
## W0: is_open()/open_day() read the GameState flags p9_open / p9_open_day; state / current_step / steps_done /
## choice_of / ending / notes / pinned answer from load_state (§5.1 {open_day, open, step, done, step_day, choices,
## ending, settled, notes, pinned, goal_done}) so that W1 tests of other packages can set states (Phase9Fixtures);
## everything else is inert. W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"quests"
const STATE_NONE := &""
const STATE_OPEN := &"open"
const STATE_ENDED := &"ended"
const STATE_SETTLED := &"settled"
const OPEN_FLAG := &"p9_open"
const OPEN_DAY_FLAG := &"p9_open_day"

@export var save_id: String = "quests"
@export var save_order: int = 81

## Rules; null = data/config/quest_config.tres (resolved lazily).
var config: QuestConfig

## W0 stub store (P1 may rename it – the fixtures use load_state only).
var _open: Array[StringName] = []
var _step: Dictionary[StringName, StringName] = {}
var _done: Dictionary[StringName, Array] = {}
var _choices: Dictionary[StringName, Dictionary] = {}
var _ending: Dictionary[StringName, StringName] = {}
var _settled: Array[StringName] = []
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _pinned: StringName = &""


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func is_open() -> bool:
	return GameState.flag_on(OPEN_FLAG)


func open_day() -> int:
	return int(GameState.get_flag(OPEN_DAY_FLAG, -1))


## 06:00: p9_open (idempotent), deadlines, offer the orders of the steps.
func apply_morning(_day: int) -> void:
	pass


## v7 with who_comes_up_complete → p9_open at once.
func post_load() -> void:
	pass


## &"" | &"open" | &"ended" | &"settled"
func state(quest_id: StringName) -> StringName:
	if _settled.has(quest_id):
		return STATE_SETTLED
	if _ending.has(quest_id) and _ending[quest_id] != &"":
		return STATE_ENDED
	if _open.has(quest_id):
		return STATE_OPEN
	return STATE_NONE


func current_step(quest_id: StringName) -> StringName:
	return _step.get(quest_id, &"")


func steps_done(quest_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in _done.get(quest_id, []):
		out.append(StringName(str(s)))
	return out


func choice_of(quest_id: StringName, step_id: StringName) -> StringName:
	var c: Dictionary = _choices.get(quest_id, {})
	return StringName(str(c.get(step_id, c.get(String(step_id), ""))))


func ending(quest_id: StringName) -> StringName:
	return _ending.get(quest_id, &"")


func choose(_quest_id: StringName, _step_id: StringName, _choice_id: StringName) -> bool:
	return false


func note(_key: StringName, _arg: String) -> void:
	pass


func notes(key: StringName) -> PackedStringArray:
	return _notes.get(key, PackedStringArray())


func pin(_entry_id: StringName) -> void:
	pass


func pinned() -> StringName:
	return _pinned


func check_goal() -> bool:
	return false


## {main, letters_step, letters_decided, large}
func goal_progress() -> Dictionary:
	return {"main": false, "letters_step": false, "letters_decided": 0, "large": 0}


## §5.1 {open_day, open, step, done, step_day, choices, ending, settled, notes, pinned, goal_done}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_open = _names(data.get("open", []))
	_settled = _names(data.get("settled", []))
	_step.clear()
	_done.clear()
	_choices.clear()
	_ending.clear()
	_notes.clear()
	var step: Variant = data.get("step", {})
	if step is Dictionary:
		for q: Variant in step:
			_step[StringName(str(q))] = StringName(str(step[q]))
	var done: Variant = data.get("done", {})
	if done is Dictionary:
		for q: Variant in done:
			_done[StringName(str(q))] = Array(_names(done[q]))
	var choices: Variant = data.get("choices", {})
	if choices is Dictionary:
		for q: Variant in choices:
			if choices[q] is Dictionary:
				var c: Dictionary = {}
				for s: Variant in choices[q]:
					c[StringName(str(s))] = StringName(str(choices[q][s]))
				_choices[StringName(str(q))] = c
	var ended: Variant = data.get("ending", {})
	if ended is Dictionary:
		for q: Variant in ended:
			_ending[StringName(str(q))] = StringName(str(ended[q]))
	var notes_raw: Variant = data.get("notes", {})
	if notes_raw is Dictionary:
		for k: Variant in notes_raw:
			var list := PackedStringArray()
			if notes_raw[k] is Array or notes_raw[k] is PackedStringArray:
				for a: Variant in notes_raw[k]:
					list.append(str(a))
			_notes[StringName(str(k))] = list
	_pinned = StringName(str(data.get("pinned", "")))


static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out
