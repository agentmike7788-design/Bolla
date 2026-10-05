class_name Festivals
extends Node
## STUB (P4) – Systems/Festivals (docs/PHASE8_DESIGN.md §2.7, §3.1, §3.3, §3.4, §5.1), groups &"festivals",
## &"saveable": the Kathreintanz (day 54, 19:00–23:00 in the inn; dropped when before p8_open_day) and the
## Lichtgang (day 58; once shifted to p8_open_day + 3), the day flags, presence and dances, the 18:00
## evaluation (lights_all / lights_some), Osric's 12 candles, the early ghosts.
## W0: fest_day / today answer from load_state (§5.1 {"days": {fest_id: day}}); everything else is inert.
## W1 (P4) fills the bodies; the signatures are the contract.

const GROUP := &"festivals"
const KATHREIN := &"fest_kathrein"
const LIGHTS := &"fest_lights"
const STATES: Array[StringName] = [&"announced", &"running", &"ended", &"cancelled"]

@export var save_id: String = "festivals"
@export var save_order: int = 75

## W0 stub store (P4 may rename it – the fixtures use load_state only).
var _days: Dictionary[StringName, int] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## The effective day (after the shift) or −1.
func fest_day(fest_id: StringName) -> int:
	return int(_days.get(fest_id, -1))


## The festival of today or &"".
func today() -> StringName:
	for id: StringName in _days:
		if _days[id] == TimeManager.day:
			return id
	return &""


## The festival whose window runs now or &"".
func running() -> StringName:
	return &""


## Day flag, the announcement, Osric's candles (Lichtgang).
func apply_morning(_day: int) -> void:
	pass


## Window, the 18:00 evaluation, the end.
func apply_minute(_day: int, _minute: int) -> void:
	pass


func dance_block_reason(_npc_id: StringName) -> String:
	return "-"


func dance(_npc_id: StringName) -> bool:
	return false


## (burning, occupied) for the objective line.
func lights_count() -> Vector2i:
	return Vector2i.ZERO


## {days, state, presence, danced, lights_result} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_days.clear()
	var days: Variant = data.get("days", {})
	if days is Dictionary:
		for key: Variant in days:
			var v: Variant = days[key]
			if v is int or v is float:
				_days[StringName(str(key))] = int(v)
