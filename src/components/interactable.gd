class_name Interactable
extends Area3D
## Makes its target (default: parent) interactable for the player's InteractionDetector.
## Physics defaults are set in _init: layer 8 (Layer 4 "interactable"), mask 0,
## monitoring off, monitorable on – it is only ever detected, it never detects.
## Scene authors add a CollisionShape3D child that covers the object's footprint;
## an Interactable without a shape can never be focused.
## The target implements can_interact(player: Player) -> bool,
## get_interaction_prompt(player: Player) -> String and interact(player: Player) -> void.
## Empty prompt = not focusable; can_interact false + prompt = shown dimmed (prompt names
## the reason), E then shows it as a warning. A target without get_interaction_prompt uses
## `prompt`, one without can_interact counts as always usable.
## `priority` (int, default 0; NPC 30, corpse 20, grave 10, stations 5) is Area3D's own
## exported property – GDScript may not redeclare it. It only orders gravity/damp overrides,
## which Interactables never use (space overrides stay disabled), so it is free for ranking.

const LAYER := 8

@export var prompt: String = "Benutzen"
@export var enabled: bool = true
@export var target_path: NodePath = ^".."


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


## The node that implements the interaction (null if target_path does not resolve).
func get_target() -> Node:
	if target_path.is_empty() or (target_path.is_absolute() and not is_inside_tree()):
		return null
	return get_node_or_null(target_path)


## Helper (not part of the contract): the target's prompt for `player`, "" without target.
func prompt_for(player: Player) -> String:
	var target := get_target()
	if target == null:
		return ""
	if not target.has_method(&"get_interaction_prompt"):
		return prompt
	var value: Variant = target.call(&"get_interaction_prompt", player)
	return str(value) if value is String or value is StringName else ""


## Helper (not part of the contract): whether the target accepts `player` right now.
func can_interact_with(player: Player) -> bool:
	var target := get_target()
	if target == null:
		return false
	if not target.has_method(&"can_interact"):
		return true
	var value: Variant = target.call(&"can_interact", player)
	return value is bool and bool(value)


## Helper (not part of the contract): runs the target's interact(player).
func interact_with(player: Player) -> void:
	var target := get_target()
	if target != null and target.has_method(&"interact"):
		target.call(&"interact", player)
	else:
		push_warning("[Interactable] '%s' has no target with interact()" % name)
