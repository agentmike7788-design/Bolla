class_name HutDoor
extends Node3D
## Portal into the hut (docs §11, group hut_door): at the hut's door_outside marker, facing
## away from the hut (+Z). "[E] Hütte betreten" fades, puts the gravekeeper at the interior's
## spawn (group hut_interior) and switches the camera. A carried corpse stays outside:
## prompt "Leiche draußen ablegen", entry refused. Resting and sleeping moved to the Bed.

const GROUP := &"hut_door"
const PROMPT_ENTER := "[E] Hütte betreten"
const TEXT_CORPSE_OUTSIDE := "Leiche draußen ablegen"
## Where the gravekeeper appears when leaving (door-local, in front of the door).
const EXIT_OFFSET := Vector3(0.0, 0.0, 0.15)

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not _is_carrying(player) \
			and _interior() != null and not HutPortal.is_travelling(player)


func get_interaction_prompt(player: Player) -> String:
	if _interior() == null:
		return ""
	if player != null and _is_carrying(player):
		return TEXT_CORPSE_OUTSIDE
	return PROMPT_ENTER


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var interior := _interior()
	HutPortal.travel(player, interior.spawn_transform(), true, interior.config.fade_seconds)


## Where a gravekeeper leaving the hut stands: in front of the door, facing away from it.
func exit_transform() -> Transform3D:
	var xform := global_transform if is_inside_tree() else transform
	return Transform3D(xform.basis.orthonormalized(), xform * EXIT_OFFSET)


func _interior() -> HutInterior:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
