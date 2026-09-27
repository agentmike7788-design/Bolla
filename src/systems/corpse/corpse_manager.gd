class_name CorpseManager
extends Node
## Owns all CorpseRecords and their nodes (WorldRoot/Systems/CorpseManager).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var save_id: String = "corpse_manager"
@export var save_order: int = 0
@export var corpse_scene: PackedScene
@export var container_path: NodePath

func _ready() -> void:
	pass


func records() -> Array[CorpseRecord]:
	push_warning("STUB CorpseManager.records")
	return []


func get_record(id: String) -> CorpseRecord:
	push_warning("STUB CorpseManager.get_record")
	return null


func get_corpse_node(id: String) -> Corpse:
	push_warning("STUB CorpseManager.get_corpse_node")
	return null


func try_daily_delivery(day: int) -> CorpseRecord:
	push_warning("STUB CorpseManager.try_daily_delivery")
	return null


func spawn_corpse(record: CorpseRecord = null, at: Transform3D = Transform3D.IDENTITY, location: StringName = &"dropoff") -> CorpseRecord:
	push_warning("STUB CorpseManager.spawn_corpse")
	return null


func pick_up(id: String, player: Player) -> bool:
	push_warning("STUB CorpseManager.pick_up")
	return false


func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null) -> bool:
	push_warning("STUB CorpseManager.put_down")
	return false


func examine(id: String) -> void:
	push_warning("STUB CorpseManager.examine")


func apply_shroud(id: String, inv: Inventory) -> bool:
	push_warning("STUB CorpseManager.apply_shroud")
	return false


func decide_valuables(id: String, take: bool, inv: Inventory) -> void:
	push_warning("STUB CorpseManager.decide_valuables")


func mark_buried(id: String, grave_id: String) -> void:
	push_warning("STUB CorpseManager.mark_buried")


func unburied_count() -> int:
	push_warning("STUB CorpseManager.unburied_count")
	return 0


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass


func post_load() -> void:
	pass
