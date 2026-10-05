class_name NightPaths
extends Node
## STUB (P7) – Systems/NightPaths (docs/PHASE8_DESIGN.md §1.6, §3.1, §3.3, §3.4, §5.1), groups
## &"night_paths", &"saveable": the two sick-light sequences (NightPathData np_ott, np_kehr) relative to
## p8_open_day – the sick lights, the night visits of Quast / Lenz / Liesel (runtime schedules in the
## village), observing them on the way out (≤ 12 m, region village) → clues, Gerhard Ott's death (02:10,
## flag ott_dead).
## W0: observed answers from load_state (§5.1 {"observed": [clue ids]}); everything else is inert.
## W1 (P7) fills the bodies; the signatures are the contract.

const GROUP := &"night_paths"
const PHASES: Array[StringName] = [&"enter", &"leave", &"observed"]

@export var save_id: String = "night_paths"
@export var save_order: int = 78

## W0 stub store (P7 may rename it – the fixtures use load_state only).
var _observed: PackedStringArray = []


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## For SickLight, the map (from c_n_veit on), the moods.
func sick_houses(_day: int, _minute: int) -> PackedStringArray:
	return PackedStringArray()


## {} | {npc_id, enter_minute, leave_minute, night, clue_id}.
func next_visit(_path_id: StringName, _day: int, _minute: int) -> Dictionary:
	return {}


## WatchSpot: until 10 minutes before the next visit, ≤ 120.
func wait_minutes(_spot_id: StringName) -> int:
	return 0


## Death (flag), observing on the way out (≤ 12 m, region village).
func apply_minute(_day: int, _minute: int) -> void:
	pass


func observed(clue_id: StringName) -> bool:
	return _observed.has(String(clue_id))


## {observed, deaths} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_observed = PackedStringArray()
	var o: Variant = data.get("observed", [])
	if o is Array or o is PackedStringArray:
		for id: Variant in o:
			_observed.append(str(id))
