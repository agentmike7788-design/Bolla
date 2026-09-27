class_name PlayerCarry
extends RefCounted
## Carry helpers of the Player: switches the Interactables of a carried node off (and back on
## when it is detached) and probes the ground for a spot to put a carried corpse down.

## Interactables of the carried node that disable_interactables switched off.
var disabled: Array[Interactable] = []


func disable_interactables(node: Node) -> void:
	for area: Interactable in interactables_under(node):
		if area.enabled and not area in disabled:
			area.enabled = false
			area.set_deferred(&"monitorable", false)
			disabled.append(area)


func restore_interactables() -> void:
	for area: Interactable in disabled:
		if is_instance_valid(area):
			area.enabled = true
			area.set_deferred(&"monitorable", true)
	disabled.clear()


static func interactables_under(node: Node) -> Array[Interactable]:
	var out: Array[Interactable] = []
	if node is Interactable:
		out.append(node as Interactable)
	for child: Node in node.get_children():
		out.append_array(interactables_under(child))
	return out


# --- drop placement probe -----------------------------------------------------------------

## Player.drop_position for a player inside the tree (Transform3D() = no valid spot).
static func drop_position(player: Player) -> Transform3D:
	var forward := forward_of(player)
	var basis := Basis(Vector3.UP, atan2(forward.x, forward.z))
	for spot: Vector3 in [player.global_position + forward * player.config.drop_distance, player.global_position]:
		var hit := _ground_below(player, spot)
		if hit.is_empty():
			continue
		var xform := Transform3D(basis, hit.position as Vector3)
		if not _drop_space_free(player, xform):
			continue
		if xform.is_equal_approx(Transform3D()):
			xform.origin.y += Player.IDENTITY_NUDGE
		return xform
	return Transform3D()


## Horizontal facing of the player (Vector3.BACK if it has none).
static func forward_of(player: Player) -> Vector3:
	var forward := player.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > Player.INPUT_DEADZONE_SQ else Vector3.BACK


static func _ground_below(player: Player, spot: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * player.drop_step_up,
			spot + Vector3.DOWN * player.drop_step_down, Player.WORLD_MASK, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)


static func _drop_space_free(player: Player, xform: Transform3D) -> bool:
	var box := BoxShape3D.new()
	box.size = player.drop_box_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(xform.basis, xform.origin + Vector3.UP * (player.drop_box_size.y * 0.5 + player.drop_box_clearance))
	query.collision_mask = Player.WORLD_MASK
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
