class_name RainBarrel
extends Node3D
## The rain barrel at the hut corner (docs/PHASE8_DESIGN.md §2.3, §3.1, §3.4, §4.3 A4): „[E] Gießkanne füllen
## (2 Min)" → GraveCare.refill (the apprentice refills here too – a visible walk, Apprentice / ApprenticePlanner).
## Needs a watering_can in the pack; a full can shows dimmed.

const PROMPT := "[E] Gießkanne füllen (2 Min)"
const PROMPT_FORMAT := "[E] Gießkanne füllen (%d Min)"
const TEXT_NO_CAN := "Du hast keine Gießkanne."
const TEXT_FULL := "Die Gießkanne ist voll."
const LABEL := "Gießkanne füllen"
const GRAVE_CARE_GROUP := &"grave_care"
const ANIM := &"interact"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or is_instance_valid(player.carried):
		return false
	var care := _care()
	return care != null and _has_can(player, care) and care.can_fill(GraveCare.OWNER_PLAYER) < care.get_config().can_fills


func get_interaction_prompt(player: Player) -> String:
	var care := _care()
	if care == null or player == null:
		return ""
	if is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	if not _has_can(player, care):
		return TEXT_NO_CAN
	if care.can_fill(GraveCare.OWNER_PLAYER) >= care.get_config().can_fills:
		return TEXT_FULL
	return PROMPT_FORMAT % care.get_config().refill_minutes


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	player.start_timed_action(LABEL, _care().get_config().refill_minutes, _finish, true, ToolAnimConfig.clip_for(&"barrel_fill", ANIM))


func _finish() -> void:
	var care := _care()
	if care != null:
		care.refill(GraveCare.OWNER_PLAYER)


func _has_can(player: Player, care: GraveCare) -> bool:
	return player.inventory != null and player.inventory.has(care.get_config().can_item)


func _care() -> GraveCare:
	return get_tree().get_first_node_in_group(GRAVE_CARE_GROUP) as GraveCare if is_inside_tree() else null
