extends TestCase
## G8 Runde 3 QA (user: „also im spiel sah es gerade nicht so aus wie auf den bilder", „er kam ohne karren und hat die
## leiche abgelegt"): the delivery in the real game flow – new game through the SaveManager, the debug console like the
## user (F1, „tp gate", „time HH:MM", F1 closed) and then the clock RUNNING from the frames (TimeManager._process, no
## advance(1) loop, no _accum set by hand). Engine.time_scale only shortens the wait; the frames get longer game steps
## (like a slow browser). Every frame is checked: he pushes the cart with the corpse along the road through the gate,
## stops at the bier, lifts / carries / lowers it in that order, the cart stays at his handles and visible, and only at
## 07:40 the corpse lies on the bier.

const TIME_SCALE := 6.0
## Frames after which a run gives up (the clock should be far past 07:44 by then).
const MAX_FRAMES := 20000
## 07:48: past the gate bell (07:44.8) and his return to the handles (07:46).
const END_MINUTE := 468
## Step to the cart, lift, carry, lower, a moment at the bier (G8 Runde 4: idle) – then to the gate bell, ring it, back to
## the handles.
const UNLOAD_ORDER: Array[StringName] = [&"walk", &"load_lift", &"carry_walk", &"load_lower", &"idle", &"walk", &"ring_bell", &"walk"]
const BELL_NOTE := "Am Tor läutet es – Osric hat eine neue Leiche gebracht."

var world: WorldRoot
var npc: Npc
var manager: CorpseManager
var console: Node
var TEST_SAVES := TestCase.user_dir("test_cart_delivery_live")
const SLOT := 7
var bell: GateBell
var notes: Array[String] = []


func before_each() -> void:
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func after_each() -> void:
	TestCase.remove_user_dir(TEST_SAVES)
	if EventBus.notification_requested.is_connected(_on_note):
		EventBus.notification_requested.disconnect(_on_note)
	Engine.time_scale = 1.0
	TimeManager.running = false
	if console != null and console.has_method(&"reset"):
		console.call(&"reset")


## New game like the title screen (the clock runs afterwards), then the console lines like the user typed them.
func _start(lines: PackedStringArray) -> void:
	await SaveManager.new_game()
	world = tree.current_scene as WorldRoot
	npc = world.get_node_by_layout_id("npc_carter") as Npc
	manager = world.corpse_manager
	console = tree.root.get_node(^"Debug")
	bell = world.get_node_or_null(^"Entities/gate_bell") as GateBell
	assert_not_null(bell, "the gate bell")
	assert_true(TimeManager.running, "the clock runs after a new game")
	assert_true(bool(console.call(&"open")), "F1 opens the console")
	for line: String in lines:
		var res: Dictionary = console.call(&"execute", line)
		assert_true(bool(res.ok), "%s → %s" % [line, res.text])
	console.call(&"close")
	assert_false(TimeManager.paused, "the clock runs again with the console closed")


func _bier_count() -> int:
	var n := 0
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF:
			n += 1
	return n


## Lets the running clock go to END_MINUTE; returns what was seen frame by frame.
func _watch() -> Dictionary:
	Engine.time_scale = TIME_SCALE
	var seen := {"push_with_cargo": 0, "unload": [] as Array[StringName], "cart_hidden": 0, "cart_off": 0.0,
			"early_bier": 0, "carry_off": 0.0, "road_min_z": INF, "frames": 0, "delivered_at": -1, "rang_at": -1.0,
			"bell_off": INF}
	var dropoff := world.get_waypoint(&"dropoff")
	var tables := Database.corpse_tables() as CorpseTables
	var frames := 0
	var rings := bell.delivery_rings
	var hang := bell.bell_node().global_position
	while TimeManager.minute_of_day < END_MINUTE and frames < MAX_FRAMES:
		await tree.process_frame
		frames += 1
		var minute := TimeManager.minute_of_day
		if not npc.is_present():
			continue
		if not npc.cart.is_visible_in_tree():
			seen.cart_hidden += 1
		var pose := npc.unload_pose()
		if bool(pose.get("active", false)):
			# The cart stays where he parked it: the root at the bier waypoint (no swing after a skip).
			seen.cart_off = maxf(seen.cart_off, Vector2(npc.global_position.x - dropoff.x, npc.global_position.z - dropoff.z).length())
			var anim: StringName = pose.anim
			var order: Array[StringName] = seen.unload
			if order.is_empty() or order[order.size() - 1] != anim:
				order.append(anim)
			if anim == CartUnload.ANIM_RING:
				var model := npc.get_node(^"Model") as Node3D
				seen.bell_off = minf(seen.bell_off, Vector2(model.global_position.x - hang.x, model.global_position.z - hang.z).length())
			if anim == CartUnload.ANIM_CARRY:
				var node: Node3D = npc.cargo_nodes()[int(pose.index)]
				var model := npc.get_node(^"Model") as Node3D
				seen.carry_off = maxf(seen.carry_off, Vector2(node.global_position.x - model.global_position.x,
						node.global_position.z - model.global_position.z).length())
		elif npc.current_animation() == &"push_cart":
			if npc.cargo.is_visible_in_tree() and npc.cargo.global_position.distance_to(npc.cart.global_position) < 1.0:
				seen.push_with_cargo += 1
			seen.road_min_z = minf(seen.road_min_z, npc.global_position.z)
		if minute < tables.delivery_minute and _bier_count() > 0:
			seen.early_bier += 1
		if seen.delivered_at < 0 and _bier_count() > 0:
			seen.delivered_at = minute
		if seen.rang_at < 0.0 and bell.delivery_rings > rings:
			seen.rang_at = TimeManager.get_minute_f()
	seen.frames = frames
	return seen


func test_time_0715_then_the_running_clock() -> void:
	await _start(PackedStringArray(["tp gate", "time 07:15"]))
	assert_eq(TimeManager.format_clock(), "07:15")
	var seen := await _watch()
	assert_true(int(seen.push_with_cargo) > 10, "he pushes the cart with the corpse on it (%d frames)" % seen.push_with_cargo)
	assert_true(float(seen.road_min_z) < 9.0, "along the road through the gate up to the bier (z %.2f)" % seen.road_min_z)
	assert_eq(seen.unload, UNLOAD_ORDER, "step to the cart, lift, carry over, lower, to the bell, ring, back")
	assert_eq(int(seen.cart_hidden), 0, "the cart never disappears")
	assert_true(float(seen.cart_off) < 0.05, "the cart stays at the bier while he unloads (%.2f m)" % seen.cart_off)
	assert_true(float(seen.carry_off) < 0.8, "the corpse is in his arms while he carries it (%.2f m)" % seen.carry_off)
	assert_eq(int(seen.early_bier), 0, "nothing on the bier before 07:40")
	assert_eq(int(seen.delivered_at), 460, "on the bier at 07:40")
	assert_eq(npc.cargo_count(), 0, "the cart is empty afterwards")
	# User: „und er soll an der glock klingeln das ich höre wen eine neue leiche da ist".
	assert_eq(bell.delivery_rings, 1, "he rings the gate bell once")
	var cfg := Database.config(&"cart_delivery_config") as CartDeliveryConfig
	assert_almost(float(seen.rang_at), 460.0 + cfg.ring_offset(), 0.5, "after laying it down (%.2f)" % seen.rang_at)
	assert_true(bell.last_heard, "heard – the gravekeeper is outside at the gate")
	assert_has(notes, BELL_NOTE)
	assert_true(float(seen.bell_off) < 0.6, "he stands under the bell (%.2f m)" % seen.bell_off)
	assert_true(npc.is_talkable(), "back at the handles, talkable")


func test_from_the_start_without_time_command() -> void:
	await _start(PackedStringArray(["tp gate"]))
	assert_eq(TimeManager.format_clock(), "06:30")
	var seen := await _watch()
	assert_true(int(seen.push_with_cargo) > 10, "he comes with the cart and the corpse")
	assert_eq(seen.unload, UNLOAD_ORDER)
	assert_eq(int(seen.cart_hidden), 0)
	assert_eq(int(seen.delivered_at), 460)
	assert_eq(bell.delivery_rings, 1, "the bell rings")


## A skip into the unloading (the user's „time 07:35"): he is at the bier at once – the cart where it belongs from the
## first frame, the corpse in his arms, the rest of the unloading and the delivery at 07:40 follow from the clock.
func test_time_into_the_unloading() -> void:
	await _start(PackedStringArray(["tp gate", "time 07:35"]))
	var pose := npc.unload_pose()
	assert_true(bool(pose.get("active", false)), "unloading right after the skip")
	var dropoff := world.get_waypoint(&"dropoff")
	assert_true(Vector2(npc.global_position.x - dropoff.x, npc.global_position.z - dropoff.z).length() < 0.05, "at the bier")
	var cart_at := npc.cart.global_position
	await wait_frames(20)
	assert_true(npc.cart.global_position.distance_to(cart_at) < 0.05,
			"the cart does not swing round after the skip (%.2f m)" % npc.cart.global_position.distance_to(cart_at))
	var seen := await _watch()
	assert_eq(int(seen.cart_hidden), 0)
	assert_eq(int(seen.early_bier), 0)
	assert_eq(int(seen.delivered_at), 460)
	assert_eq(bell.delivery_rings, 1, "the bell rings while the clock runs")


## Skips past 07:40 („time 07:50") end in the delivered state: corpse on the bier, cart empty, Osric at the handles;
## the skip rings nothing – the HUD notes the new corpse.
func test_time_past_the_delivery() -> void:
	await _start(PackedStringArray(["tp gate", "time 07:50"]))
	await wait_frames(3)
	assert_eq(bell.delivery_rings, 0, "a skip rings nothing")
	assert_eq(bell.delivery_notes, 1, "only the note")
	assert_has(notes, "Osric hat am Tor eine neue Leiche gebracht.")
	assert_eq(_bier_count(), 1, "delivered")
	assert_eq(npc.cargo_count(), 0, "cart empty")
	assert_false(bool(npc.unload_pose().get("active", false)), "no unloading any more")
	assert_true(npc.cart.is_visible_in_tree(), "the cart stands at the gate")


## Runs the clock (Engine.time_scale `scale`) until `minute`; returns the frames he pushed his (visible) cart.
func _run_until(minute: int, scale: float) -> int:
	Engine.time_scale = scale
	var pushing := 0
	var frames := 0
	while TimeManager.minute_of_day < minute and frames < MAX_FRAMES:
		await tree.process_frame
		frames += 1
		if npc.is_present() and npc.current_animation() == &"push_cart" and npc.cart.is_visible_in_tree():
			pushing += 1
	Engine.time_scale = 1.0
	return pushing


## Browser version 13 („bringt er die leiche ladet sie ab aber fährt nicht mehr weg"): as in the contract he stays at
## the gate (talk, linen) until 10:00, then pushes the empty cart back up the road and is gone at 10:40; in the evening
## he comes back on foot (18:00–18:30) and smokes at his spot until 21:00.
func test_leaves_at_ten_and_comes_back_in_the_evening() -> void:
	await _start(PackedStringArray(["tp gate", "time 07:50"]))
	await wait_frames(3)
	assert_true(npc.is_present() and npc.is_talkable(), "after the delivery he waits at the gate, talkable")
	var at_gate := npc.global_position
	assert_true(console.call(&"open"))
	console.call(&"execute", "time 09:58")
	console.call(&"close")
	assert_true(npc.global_position.distance_to(at_gate) < 0.05, "still at the gate at 09:58")
	var pushing := await _run_until(625, 30.0)
	assert_true(pushing > 5, "at 10:00 he pushes the cart away (%d frames)" % pushing)
	assert_true(npc.global_position.distance_to(at_gate) > 10.0, "on the road back by 10:25")
	assert_eq(npc.cargo_count(), 0, "the cart is empty on the way back")
	await _run_until(641, 30.0)
	assert_false(npc.is_present(), "gone at 10:40")
	assert_true(console.call(&"open"))
	console.call(&"execute", "time 18:25")
	console.call(&"close")
	await _run_until(1111, 30.0)
	var spot := world.get_waypoint(&"evening_spot")
	assert_true(npc.is_present(), "back in the evening")
	assert_true(Vector2(npc.global_position.x - spot.x, npc.global_position.z - spot.z).length() < 0.1, "at his evening spot")
	assert_false(npc.cart.is_visible_in_tree(), "in the evening without the cart")


## In a room (hut, crypt …) or the village the bell is not heard – only the HUD note.
func test_bell_in_a_room_only_notes() -> void:
	await _start(PackedStringArray(["tp gate", "time 07:43"]))
	world.get_player().set_in_interior(true, &"")
	var rings := bell.delivery_rings
	await _run_until(467, 6.0)
	assert_eq(bell.delivery_rings, rings + 1, "he rings")
	assert_false(bell.last_heard, "not heard inside")
	assert_has(notes, BELL_NOTE)


## A save during the walk back loads without ringing again (a load announces nothing).
func test_a_load_rings_nothing() -> void:
	SaveManager.save_dir = TEST_SAVES
	await _start(PackedStringArray(["tp gate", "time 07:45"]))
	assert_true(bool(npc.unload_pose().get("active", false)), "between the bell and the handles")
	TimeManager.running = false
	assert_eq(SaveManager.save_game(SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK)
	world = tree.current_scene as WorldRoot
	npc = world.get_node_by_layout_id("npc_carter") as Npc
	bell = world.get_node_or_null(^"Entities/gate_bell") as GateBell
	await _run_until(468, 6.0)
	assert_eq(bell.delivery_rings, 0, "no ring after the load")
	assert_eq(bell.delivery_notes, 0, "no note either")
