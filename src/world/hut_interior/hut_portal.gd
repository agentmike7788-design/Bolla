class_name HutPortal
extends RefCounted
## Moves the gravekeeper between the graveyard and the hut interior (docs §11): a short black
## fade (EventBus.screen_fade_requested, drawn by the UI), at its midpoint the teleport and
## Player.set_in_interior (camera profile, sun, environment follow EventBus.interior_changed).
## The world keeps running – no pause, no scene change. One trip at a time per player.

const META_TRAVELLING := &"portal_travelling"


## Whether a trip of `player` is under way (the fade has not reached its midpoint yet).
static func is_travelling(player: Player) -> bool:
	return player != null and player.has_meta(META_TRAVELLING)


## Fades, then places `player` at `destination`. fade_seconds <= 0 (or outside the tree) =
## immediately. Returns false when refused (no player, already travelling).
## Phase 6 (§3.4; P6): `room` = the interior room (empty + inside → &"hut").
static func travel(player: Player, destination: Transform3D, inside: bool, fade_seconds: float, room: StringName = &"") -> bool:
	if player == null or is_travelling(player):
		return false
	if fade_seconds <= 0.0 or not player.is_inside_tree():
		arrive(player, destination, inside, room)
		return true
	player.set_meta(META_TRAVELLING, true)
	EventBus.screen_fade_requested.emit(fade_seconds)
	_arrive_later(player, destination, inside, fade_seconds * 0.5, room)
	return true


## The teleport itself: position + facing, no leftover velocity, then the inside/outside state.
static func arrive(player: Player, destination: Transform3D, inside: bool, room: StringName = &"") -> void:
	player.global_transform = Transform3D(destination.basis.orthonormalized(), destination.origin)
	player.velocity = Vector3.ZERO
	player.set_in_interior(inside, room)


static func _arrive_later(player: Player, destination: Transform3D, inside: bool, delay: float, room: StringName = &"") -> void:
	await player.get_tree().create_timer(delay).timeout
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	player.remove_meta(META_TRAVELLING)
	arrive(player, destination, inside, room)
