class_name Relationships
extends Node
## STUB (P2) – Systems/Relationships (docs/PHASE7_DESIGN.md §2.1, §2.4, §3.1, §3.4, §5.1), groups
## &"relationships", &"saveable": one value 0…100 per villager, the first meeting, talk / gift / remark
## once per day, the specimen deltas. Changes come only from direct calls (add, note_talk, give_gift,
## on_specimen_*); every change emits EventBus.relationship_changed.
## W0: value() / met() answer from load_state({"values": {…}, "met": […]}) so W1 tests can set
## relationships (Phase7Fixtures.villager) before P2 is merged; everything else is inert.
## W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"relationships"

@export var save_id: String = "relationships"
@export var save_order: int = 51

## Rules; null = data/config/relationship_config.tres (resolved lazily).
var config: RelationshipConfig

## W0 stub store (P2 may rename it – the fixtures use load_state only).
var _values: Dictionary[StringName, int] = {}
var _met: Array[StringName] = []


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func value(npc_id: StringName) -> int:
	return int(_values.get(npc_id, 0))


func tier(npc_id: StringName) -> StringName:
	return RelationshipRules.tier(value(npc_id), config)


func met(npc_id: StringName) -> bool:
	return _met.has(npc_id)


## First contact: the start value (§2.1), relationship_changed.
func meet(_npc_id: StringName) -> void:
	pass


## Clamped 0…100; relationship_changed; returns the new value.
func add(npc_id: StringName, _delta: int, _reason: String) -> int:
	return value(npc_id)


## +talk once per day.
func note_talk(_npc_id: StringName) -> void:
	pass


func gift_block_reason(_npc_id: StringName, _item_id: StringName, _inv: Inventory) -> String:
	return ""


## 1 item gone, +gift, stats.gifts_given.
func give_gift(_npc_id: StringName, _item_id: StringName, _inv: Inventory) -> bool:
	return false


## Villagers on `tier` or higher (chapter).
func count_at_least(_tier: StringName) -> int:
	return 0


## Once per day; villager_remarked; "" = already said.
func remark(_npc_id: StringName) -> String:
	return ""


## Every villager with specimen_delta / returned_delta.
func on_specimen_sold() -> void:
	pass


func on_specimen_returned() -> void:
	pass


## {values, met, talk_day, gift_day, remark_day} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_values.clear()
	_met.clear()
	var saved: Variant = data.get("values")
	if saved is Dictionary:
		for key: Variant in saved:
			var v: Variant = (saved as Dictionary)[key]
			if v is int or v is float:
				_values[StringName(str(key))] = int(v)
	var met_list: Variant = data.get("met")
	if met_list is Array:
		for id: Variant in met_list:
			_met.append(StringName(str(id)))
