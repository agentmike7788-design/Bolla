extends Node
## Autoload SaveManager – new game, save, load (docs §5).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

const WORLD_SCENE := "res://src/world/graveyard/graveyard.tscn"
const FORMAT_VERSION := 1

var save_dir: String = "user://saves"
var is_loading: bool = false

func new_game(scene_path: String = WORLD_SCENE) -> void:
	push_warning("STUB save_manager.gd.new_game")


func save_game(slot: int) -> Error:
	push_warning("STUB save_manager.gd.save_game")
	return ERR_UNAVAILABLE


func load_game(slot: int) -> Error:
	push_warning("STUB save_manager.gd.load_game")
	return ERR_UNAVAILABLE


func can_save() -> bool:
	push_warning("STUB save_manager.gd.can_save")
	return false


func has_save(slot: int) -> bool:
	push_warning("STUB save_manager.gd.has_save")
	return false


func delete_save(slot: int) -> void:
	push_warning("STUB save_manager.gd.delete_save")


func get_slot_info(slot: int) -> Dictionary:
	push_warning("STUB save_manager.gd.get_slot_info")
	return {}


func newest_slot() -> int:
	push_warning("STUB save_manager.gd.newest_slot")
	return 0


func collect_state() -> Dictionary:
	push_warning("STUB save_manager.gd.collect_state")
	return {}


func apply_state(data: Dictionary) -> void:
	push_warning("STUB save_manager.gd.apply_state")


func reset() -> void:
	pass
