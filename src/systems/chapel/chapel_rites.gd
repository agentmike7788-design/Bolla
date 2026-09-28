class_name ChapelRites
extends Node
## STUB (P4) – Systems/Chapel (docs/PHASE6_DESIGN.md §2.4, §3.1, §3.4, §5.1), groups
## &"chapel_rites", &"saveable": funeral services on the catafalque and devotions for graves (by
## grave the chapel level they were held at). W1 (P4) fills the bodies; the signatures are the
## contract. Phase 8's priest uses the same hold_service.

const GROUP := &"chapel_rites"

@export var save_id: String = "chapel"
@export var save_order: int = 37

## Rules; null = data/config/chapel_config.tres (resolved lazily).
var config: ChapelConfig


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## = Buildings.level(&"chapel").
func level() -> int:
	return 0


func service_block_reason(_corpse_id: String, _inv: Inventory) -> String:
	return ""


## After the TimedAction: candle, fee (payment_received), reputation, piety, mark_service,
## stats.services_held, funeral_held; the fee | -1.
func hold_service(_corpse_id: String, _inv: Inventory) -> int:
	return -1


func devotion_block_reason(_grave_id: String, _inv: Inventory) -> String:
	return ""


## Candle, _devotions[grave_id] = level, piety once, devotion_held, stats.devotions_held.
func hold_devotion(_grave_id: String, _inv: Inventory) -> bool:
	return false


## Chapel level the devotion for this grave was held at (0 = none).
func devotion_level(_grave_id: String) -> int:
	return 0


## [{grave_id, name, section, mood, held_level, block_reason}].
func eligible_devotions() -> Array[Dictionary]:
	return []


## Corpses with service_held whose grave is MARKED (chapter).
func services_buried() -> int:
	return 0


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
