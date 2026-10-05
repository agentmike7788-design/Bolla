class_name NightRobber
extends Node
## STUB (P7) – Systems/NightRobber (docs/PHASE8_DESIGN.md §2.6.3, §3.1, §3.3, §3.4, §5.1), groups
## &"night_robber", &"saveable": Lambert Grell – the target grave of the night (fresh ≤ 5 days, no
## mortsafe, no candle, no night watch; the first night for sure, then 35 % with a pause of 2), the visible
## digging 01:50–05:00 (runtime schedule of npc_robber), noticing the gravekeeper ≤ 10 m (flees, the grave
## only dug at), the second encounter (dialogue robber → resolve), 05:00 disturbed, the night watchman
## after the third. A corpse never leaves its grave.
## W0: tonight_target / encounters / fate answer from load_state (§5.1 {"target_day", "target",
## "encounters", "fate"}); everything else is inert.
## W1 (P7) fills the bodies; the signatures are the contract.

const GROUP := &"night_robber"
const FATES: Array[StringName] = [&"", &"reported", &"let_go", &"caught_watch"]
const EVENTS: Array[StringName] = [&"arrived", &"seen", &"fled", &"caught", &"disturbed", &"gone"]

@export var save_id: String = "night_robber"
@export var save_order: int = 77

## Rules; null = data/config/robber_config.tres (resolved lazily).
var config: RobberConfig

## W0 stub store (P7 may rename it – the fixtures use load_state only).
var _target_day: int = 0
var _target: String = ""
var _encounters: int = 0
var _fate: StringName = &""


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Grave id or "" (deterministic, saved from 00:00).
func tonight_target(day: int) -> String:
	return _target if day == _target_day else ""


## Appearance, digging, noticing, 05:00 disturbed.
func apply_minute(_day: int, _minute: int) -> void:
	pass


func encounters() -> int:
	return _encounters


## &"" | &"reported" | &"let_go" | &"caught_watch".
func fate() -> StringName:
	return _fate


## Dialogue robber (second encounter).
func resolve(_choice: StringName) -> void:
	pass


## {target_day, target, encounters, disturbed, last_night, fate} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	var d: Variant = data.get("target_day", 0)
	_target_day = int(d) if d is int or d is float else 0
	_target = str(data.get("target", ""))
	var e: Variant = data.get("encounters", 0)
	_encounters = maxi(0, int(e)) if e is int or e is float else 0
	var f := StringName(str(data.get("fate", "")))
	_fate = f if f in FATES else &""
