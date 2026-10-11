extends TestCase
## G8 Runde 3 (user: „und er soll an der glock klingeln das ich höre wen eine neue leiche da ist"): after laying the
## dead onto the bier Osric walks round the bier's end to the gate bell, rings it and goes back to the handles –
## CartUnload as a pure function of the clock, values in data/config/cart_delivery_config.tres; GateBell rings loud
## outside on the graveyard and only notes it in a room or the village.

const DELIVERY := 460
## The gate of the real world: handles, cart north of them, the bier 2.6 m east, the bell on the east gate post.
const HANDLES := Vector3(1.75, 0.0, 8.4)
const ROOT_YAW := PI
const CART_CENTER := Vector3(1.75, 0.63, 6.8)
const BIER := Vector3(4.4, 0.58, 8.3)
## Half the bier's footprint (ph_prop_dropoff_bier 2.06 × 0.78 m) – he must not walk through it.
const BIER_HALF := Vector2(1.03, 0.39)
const BELL := Vector3(1.98, 1.78, 9.6)
const DOUBLE := preload("res://tests/unit/test_g8_round1.gd")

var notes: Array[String] = []


func before_each() -> void:
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	if EventBus.notification_requested.is_connected(_on_note):
		EventBus.notification_requested.disconnect(_on_note)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _cfg() -> CartDeliveryConfig:
	var cfg := Database.config(&"cart_delivery_config") as CartDeliveryConfig
	assert_not_null(cfg)
	return cfg if cfg != null else CartDeliveryConfig.new()


func _pose(minute_f: float, bell: Variant = BELL) -> Dictionary:
	var none: Array[Transform3D] = []
	var cargo_rest := Transform3D(Basis(Vector3.UP, PI * 1.5), CART_CENTER)
	return CartUnload.pose(_cfg(), minute_f, DELIVERY, none, none, HANDLES, ROOT_YAW, CART_CENTER, Vector3(0, 0, -1), 1,
			Transform3D.IDENTITY.translated(BIER), cargo_rest, bell)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_bell_values_in_data() -> void:
	var cfg := _cfg()
	assert_true(cfg.ring_bell, "he rings after every delivery")
	assert_true(cfg.bell_note.contains("%s") and cfg.skipped_note.contains("%s"), "notes name him")
	assert_true(cfg.bell_volume_db > 0.0, "louder than a visitor's ring – heard all over the graveyard")
	var off := cfg.ring_offset()
	assert_true(off > cfg.bell_walk_minutes and off < cfg.bell_walk_minutes + cfg.bell_ring_minutes, "sounds while he rings")
	# The rest of the schedule stays: back at the handles a few minutes after 07:40, at the gate until 10:00.
	assert_true(cfg.after_minutes() <= 8.0, "back at the handles by 07:48 (%.1f min)" % cfg.after_minutes())
	var sched := Database.schedule(&"carter") as NpcSchedule
	var leave := -1
	for e: ScheduleEntry in sched.entries:
		if e.with_cart and e.start_minute > DELIVERY and e.travel_minutes > 0:
			leave = e.start_minute
	assert_eq(leave, 600, "he leaves at 10:00 as before")


func test_walks_round_the_bier_to_the_bell_and_rings() -> void:
	var cfg := _cfg()
	var start := _pose(DELIVERY + 0.01)
	assert_true(bool(start.active))
	assert_eq(start.anim, CartUnload.ANIM_WALK, "walks off from the bier")
	var spot := CartUnload.bell_spot(cfg, BELL, HANDLES)
	assert_almost(_flat_dist(spot.spot, BELL), cfg.bell_stand_distance, 0.01, "under the bell")
	var steps := 60
	for i: int in steps + 1:
		var p := _pose(DELIVERY + cfg.bell_walk_minutes * float(i) / float(steps) * 0.9999)
		var f: Vector3 = p.figure
		var inside := absf(f.x - BIER.x) < BIER_HALF.x + 0.15 and absf(f.z - BIER.z) < BIER_HALF.y + 0.15
		assert_false(inside, "not through the bier (%.2f, %.2f)" % [f.x, f.z])
	var at := _pose(DELIVERY + cfg.bell_walk_minutes + cfg.bell_ring_minutes * 0.5)
	assert_eq(at.anim, CartUnload.ANIM_RING, "rings")
	assert_true(bool(at.ringing))
	assert_true(_flat_dist(at.figure, spot.spot) < 0.01, "at the bell")
	var facing := CartUnload.forward(float(at.yaw))
	var to_bell := Vector3(BELL.x - spot.spot.x, 0.0, BELL.z - spot.spot.z).normalized()
	assert_true(facing.dot(to_bell) > 0.95, "faces the bell")
	assert_almost(float(at.anim_t), 0.5, 0.01, "the clip follows the clock")
	var back := _pose(DELIVERY + cfg.after_minutes() - 0.01)
	assert_eq(back.anim, CartUnload.ANIM_WALK)
	assert_true(_flat_dist(back.figure, HANDLES) < 0.05, "back to the handles")
	assert_false(bool(_pose(DELIVERY + cfg.after_minutes()).active), "then the clock places him as before")


func test_without_a_bell_he_walks_straight_back() -> void:
	var cfg := _cfg()
	var p := _pose(DELIVERY + 0.01, null)
	assert_eq(p.anim, CartUnload.ANIM_WALK)
	assert_false(bool(_pose(DELIVERY + cfg.after_minutes(false), null).active), "no bell: only return_minutes")


func test_gate_bell_heard_outside_noted_inside() -> void:
	var bell := GateBell.new()
	tree.root.add_child(bell)
	var player := DOUBLE.PlayerRegion.new()
	player.add_to_group(&"player")
	tree.root.add_child(player)
	assert_true(bell.ring_delivery("Osric"), "heard on the graveyard")
	assert_has(notes, "Am Tor läutet es – Osric hat eine neue Leiche gebracht.")
	notes.clear()
	player.set(&"in_interior", true)
	assert_false(bell.ring_delivery("Osric"), "not heard in a room")
	assert_has(notes, "Am Tor läutet es – Osric hat eine neue Leiche gebracht.", "the note instead")
	player.set(&"in_interior", false)
	player.set(&"region_id", &"village")
	assert_false(bell.ring_delivery("Osric"), "not heard in the village")
	notes.clear()
	bell.note_delivery("Osric")
	assert_eq(notes, ["Osric hat am Tor eine neue Leiche gebracht."] as Array[String], "after a skip only the note")
	assert_eq(bell.delivery_rings, 3)
	assert_eq(bell.rings, 0, "visitor rings unchanged")
	player.queue_free()
	bell.queue_free()
