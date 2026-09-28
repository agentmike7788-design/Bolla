class_name GatherManager
extends Node
## Systems/Gathering (docs/PHASE5_DESIGN.md §2.2, §3.1, §3.4, §5.1), groups &"gathering",
## &"saveable": the state of every GatherNode ({charges, last_taken_day, last_refresh_day} per
## node id; the nodes themselves are not saved, their model stage is derived). Nodes register
## themselves (GatherNode._ready) and are collected from group &"gather_node" in _ready.
## Regrowth runs on day_started and in post_load (GatherRules.refreshed, day number only).
## Changes: resource_gathered, gather_node_changed (the nodes update their models from it).

const GROUP := &"gathering"
const NODE_GROUP := &"gather_node"
## Felling this kind counts stats.trees_felled.
const TREE_KIND := &"alder"
const STAT_TREES := &"trees_felled"

@export var save_id: String = "gathering"
@export var save_order: int = 25

## kind -> GatherNodeData; missing kinds come from Database.gather_kind(kind) (tests inject).
var kind_data: Dictionary[StringName, GatherNodeData] = {}

var _data: Dictionary[String, GatherNodeData] = {}
## node id -> state; also keeps the states of saved nodes that are not (yet) registered.
var _state: Dictionary[String, Dictionary] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _enter_tree() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _ready() -> void:
	collect_nodes()


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


## Registers every node of group &"gather_node" (idempotent).
func collect_nodes() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(NODE_GROUP):
		if node is GatherNode and not node.is_queued_for_deletion():
			(node as GatherNode).register_with(self)


## GatherNodeData of `kind` (injected or Database; null = unknown).
func data_for_kind(kind: StringName) -> GatherNodeData:
	if kind_data.has(kind):
		return kind_data[kind]
	return Database.gather_kind(kind) as GatherNodeData if kind != &"" else null


func register(node_id: String, data: GatherNodeData) -> void:
	if node_id == "" or data == null:
		push_warning("[GatherManager] register: node id or data missing")
		return
	_data[node_id] = data
	if not _state.has(node_id):
		_state[node_id] = GatherRules.full_state(data, _today())
	else:
		_state[node_id] = GatherRules.refreshed(_state[node_id], _today(), data)


func is_registered(node_id: String) -> bool:
	return _data.has(node_id)


func data_of(node_id: String) -> GatherNodeData:
	return _data.get(node_id)


func node_ids() -> PackedStringArray:
	return PackedStringArray(_data.keys())


func state_of(node_id: String) -> Dictionary:
	return (_state[node_id] as Dictionary).duplicate() if _state.has(node_id) else {}


func charges(node_id: String) -> int:
	return int(_state[node_id].get("charges", 0)) if _state.has(node_id) else 0


func stage(node_id: String) -> StringName:
	if not _data.has(node_id):
		return GatherRules.STAGE_FULL
	return GatherRules.stage(_state.get(node_id, {}), _today(), _data[node_id])


func days_left(node_id: String) -> int:
	if not _data.has(node_id):
		return 0
	return GatherRules.days_left(_state.get(node_id, {}), _today(), _data[node_id])


## "" | empty / tool / inventory reason (flag and section are the node's, see GatherNode).
func block_reason(node_id: String, inv: Inventory, tier: int) -> String:
	if not _data.has(node_id):
		return GatherRules.TEXT_NOT_OPEN
	return GatherRules.block_reason(_state.get(node_id, {}), _data[node_id], inv, tier, true, true)


## After the timed action; 0 = refused (unknown, empty, tool too low, no room). One charge →
## yield_for(tier) items. resource_gathered, gather_node_changed; alder → stats.trees_felled.
func gather(node_id: String, inv: Inventory, tier: int) -> int:
	if inv == null or block_reason(node_id, inv, tier) != "":
		return 0
	var data := _data[node_id]
	var amount := GatherRules.yield_for(data, tier)
	var rest := inv.add_item(data.item_id, amount)
	var added := amount - rest
	if added <= 0:
		return 0
	var state: Dictionary = _state[node_id]
	state["charges"] = int(state.get("charges", 1)) - 1
	state["last_taken_day"] = _today()
	state["last_refresh_day"] = maxi(int(state.get("last_refresh_day", 0)), _today())
	if data.id == TREE_KIND:
		GameState.add_stat(STAT_TREES, 1)
	EventBus.resource_gathered.emit(node_id, data.item_id, added)
	EventBus.gather_node_changed.emit(node_id, charges(node_id), stage(node_id))
	return added


## Regrowth for `day` (day_started + post_load); gather_node_changed for every node whose
## charges or stage changed.
func refresh(day: int) -> void:
	for node_id: String in _data:
		var data := _data[node_id]
		var before: Dictionary = _state.get(node_id, {})
		var shown_day := _int(before.get("last_refresh_day"), day)
		var old_stage := GatherRules.stage(before, shown_day, data) if not before.is_empty() else &""
		var after := GatherRules.refreshed(before, day, data)
		_state[node_id] = after
		var new_stage := GatherRules.stage(after, day, data)
		if int(before.get("charges", -1)) != int(after.charges) or old_stage != new_stage:
			EventBus.gather_node_changed.emit(node_id, int(after.charges), new_stage)


func save_state() -> Dictionary:
	var out := {}
	var ids: Array = _state.keys()
	ids.sort()
	for node_id: String in ids:
		var s: Dictionary = _state[node_id]
		out[node_id] = {"charges": int(s.get("charges", 0)), "last_taken_day": int(s.get("last_taken_day", GatherRules.NO_DAY)),
				"last_refresh_day": int(s.get("last_refresh_day", 0))}
	return out


## Replaces every state; {} = all nodes full. Tolerant: broken entries are skipped (warning),
## values are clamped by the next refresh.
func load_state(data: Dictionary) -> void:
	_state.clear()
	for key: Variant in data:
		var entry: Variant = data[key]
		if not (key is String or key is StringName) or not entry is Dictionary:
			push_warning("[GatherManager] saved state '%s' is broken – ignored" % str(key))
			continue
		var node_id := String(key)
		var s := {"charges": _int((entry as Dictionary).get("charges"), -1),
				"last_taken_day": _int((entry as Dictionary).get("last_taken_day"), GatherRules.NO_DAY),
				"last_refresh_day": _int((entry as Dictionary).get("last_refresh_day"), 0)}
		if int(s.charges) < 0:
			s.erase("charges")
		_state[node_id] = s
	for node_id: String in _data:
		if not _state.has(node_id):
			_state[node_id] = GatherRules.full_state(_data[node_id], _today())
		else:
			var clamped := GatherRules.refreshed(_state[node_id], _int(_state[node_id].get("last_refresh_day"), 0), _data[node_id])
			_state[node_id] = clamped


## Regrowth for today (a save from an earlier day), then every node shows its stage.
func post_load() -> void:
	var day := _today()
	for node_id: String in _data:
		_state[node_id] = GatherRules.refreshed(_state.get(node_id, {}), day, _data[node_id])
		EventBus.gather_node_changed.emit(node_id, charges(node_id), stage(node_id))


func _on_day_started(day: int) -> void:
	refresh(day)


func _today() -> int:
	return TimeManager.day


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	return fallback
