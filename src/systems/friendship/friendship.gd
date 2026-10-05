class_name Friendship
extends Node
## STUB (P4) – Systems/Friendship (docs/PHASE8_DESIGN.md §2.4, §3.1, §3.3, §3.4, §5.1), groups
## &"friendship", &"saveable": the three-step story of each living villager (FriendStoryData; thresholds
## 40 / 55 / 70, a day between, not when „gereizt"), the friend orders (OrderData.category friend, their
## own limit), the favours (once per 5 days) and the return favours (+4 / −6 and 7 days rest).
## W0: step_done / steps_total / full_stories answer from load_state (§5.1 {"steps": {npc: n}});
## everything else is inert.
## W1 (P4) fills the bodies; the signatures are the contract.

const GROUP := &"friendship"
const FAVOR_USED := &"used"
const FAVOR_RETURNED := &"returned"
const FAVOR_UNRETURNED := &"unreturned"
const STEPS := 3

@export var save_id: String = "friendship"
@export var save_order: int = 74

## W0 stub store (P4 may rename it – the fixtures use load_state only).
var _steps: Dictionary[StringName, int] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## 0…3.
func step_done(npc_id: StringName) -> int:
	return clampi(int(_steps.get(npc_id, 0)), 0, STEPS)


## 0 = none (threshold, mood cross, gap).
func offerable_step(_npc_id: StringName) -> int:
	return 0


## Takes the order of_*.
func accept_step(_npc_id: StringName) -> bool:
	return false


## Orders → the step done → friend_step_completed, the reward.
func note_order_done(_order_id: StringName) -> void:
	pass


func steps_total() -> int:
	var n := 0
	for npc: StringName in _steps:
		n += step_done(npc)
	return n


func full_stories() -> int:
	var n := 0
	for npc: StringName in _steps:
		if step_done(npc) >= STEPS:
			n += 1
	return n


func favor_block_reason(_npc_id: StringName) -> String:
	return "-"


func use_favor(_npc_id: StringName, _choice: StringName = &"") -> bool:
	return false


## Rosine's „Ein Wort im Krug".
func favor_shield_active() -> bool:
	return false


func consume_shield(_event: StringName) -> bool:
	return false


## Fenner's night watchman.
func night_watch_tonight() -> bool:
	return false


## Offer / let lapse the return favours.
func apply_morning(_day: int) -> void:
	pass


## {steps, step_day, favor_day, owed, locked_until, shield, watch_night} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_steps.clear()
	var steps: Variant = data.get("steps", {})
	if steps is Dictionary:
		for key: Variant in steps:
			var v: Variant = steps[key]
			if v is int or v is float:
				_steps[StringName(str(key))] = int(v)
