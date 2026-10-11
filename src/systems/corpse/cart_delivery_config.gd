class_name CartDeliveryConfig
extends Resource
## G8 Runde 3 (user: „ich dachte die neuen leichen werden mit dem holz wagen hergebracht"): how Osric unloads the
## day's corpse from his handcart onto the bier at the gate (data/config/cart_delivery_config.tres; CartUnload,
## Npc, CorpseManager.cart_load). The unloading ends at CorpseTables.delivery_minute – only then the corpse lies on
## the bier and counts as delivered (contract §2.5). Osric's schedule (data/npc/carter_schedule.tres) stops at the
## bier unload_minutes before that (morning_unload) – tests/unit/test_cart_delivery.gd keeps both in step.

## Game minutes the unloading of all the day's corpses takes; it ends at the delivery minute.
@export var unload_minutes: int = 8
## Shares of one corpse's unloading (they add up to 1): step from the handles to the cart's side, lift the dead
## off the cart, carry them over to the bier, lay them down.
@export var step_share: float = 0.2
@export var lift_share: float = 0.22
@export var carry_share: float = 0.28
@export var lower_share: float = 0.3
## After the delivery he walks back to the handles in this many game minutes (no prompt meanwhile) – from the gate
## bell when he rings it (ring_bell), else from the bier.
@export var return_minutes: int = 3
## Where he stands (m): beside the cart's long axis, and in front of the bier's slot.
@export var cart_side_distance: float = 0.8
@export var bier_side_distance: float = 0.72
## The dead in his arms (figure space, like the gravekeeper's CarrySocket): height and distance in front.
@export var carry_height: float = 0.9
@export var carry_forward: float = 0.42
## Extra height (m) of the corpse at the middle of the lift and of the lowering (a small arc over the edges).
@export var arc_height: float = 0.1
## Parts of the lift / lower clip in which the corpse moves (before: he bends and grips; after: he lets go).
@export var lift_move_from: float = 0.35
@export var lift_move_to: float = 0.9
@export var lower_move_from: float = 0.1
@export var lower_move_to: float = 0.78
## The dead lie on the cart with the head at the handles (towards Osric) – so they come down onto the bier
## head first as everywhere else (slot_corpse +X = head).
@export var head_to_handles: bool = true
## More than one corpse: side by side on the cart (m apart), at most max_cargo shown.
@export var cargo_spacing: float = 0.42
@export var max_cargo: int = 3
# G8 Runde 3 (user: „und er soll an der glock klingeln das ich höre wen eine neue leiche da ist"): after laying the
# dead onto the bier he walks round the bier's end to the gate bell (GateBell, east gate post), rings it and goes
# back to the handles. Only while the clock runs past it – a skip, sleep or load rings nothing (GateBell).
@export var ring_bell: bool = true
## Game minutes: from the bier to the spot under the bell, and the ringing (clip ring_bell, played over them).
@export var bell_walk_minutes: float = 3.0
@export var bell_ring_minutes: float = 2.0
## Part of the ringing at which the bell sounds and swings (the first pull of the clip).
@export var bell_ring_at: float = 0.4
## Where he stands (m): this far from the bell's hanging point towards the handles; the corner he walks round
## first – this far from his place at the bier along the bier's long axis (past its end, towards the bell).
@export var bell_stand_distance: float = 0.42
@export var bell_corner_offset: float = 1.3
## Extra volume (dB) of the bell for a delivery – heard all over the graveyard (cue VisitorConfig.bell_cue).
@export var bell_volume_db: float = 8.0
## HUD notes (%s = the carter's first name): the bell rang (also in the crypt, a room or the village, where it
## is not heard); a time skip / sleep went past the delivery (no sound).
@export var bell_note: String = "Am Tor läutet es – %s hat eine neue Leiche gebracht."
@export var skipped_note: String = "%s hat am Tor eine neue Leiche gebracht."


## Shares normalised to a sum of 1 (a broken config falls back to equal parts).
func shares() -> PackedFloat32Array:
	var raw := PackedFloat32Array([maxf(step_share, 0.0), maxf(lift_share, 0.0), maxf(carry_share, 0.0), maxf(lower_share, 0.0)])
	var total := raw[0] + raw[1] + raw[2] + raw[3]
	if total <= 0.0001:
		return PackedFloat32Array([0.25, 0.25, 0.25, 0.25])
	for i: int in 4:
		raw[i] /= total
	return raw


## Game minutes from the delivery until he is back at the handles (the bell walk and ringing, then return_minutes).
func after_minutes(with_bell: bool = true) -> float:
	var bell := maxf(bell_walk_minutes, 0.0) + maxf(bell_ring_minutes, 0.0) if with_bell and ring_bell else 0.0
	return bell + float(maxi(return_minutes, 0))


## Minutes after the delivery at which the bell sounds (-1 = he does not ring).
func ring_offset() -> float:
	if not ring_bell:
		return -1.0
	return maxf(bell_walk_minutes, 0.0) + maxf(bell_ring_minutes, 0.0) * clampf(bell_ring_at, 0.0, 1.0)


## Game minute (of day) at which the unloading starts for a delivery at `delivery_minute`.
func unload_start(delivery_minute: int) -> int:
	return delivery_minute - maxi(unload_minutes, 1)
