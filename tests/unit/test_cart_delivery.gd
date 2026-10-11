extends TestCase
## G8 Runde 3 (user: „ich dachte die neuen leichen werden mit dem holz wagen hergebracht"): Osric's unloading at the bier.
## The values live in data/config/cart_delivery_config.tres and fit his schedule and the delivery minute; CartUnload is
## a pure function of the clock (step to the cart, lift, carry, lay down – one corpse after the other, then back to the
## handles); his new clips sit on the unchanged body and old clips.

const CHARACTERS := preload("res://tests/unit/test_assets_characters.gd")
const ASSETS8 := preload("res://tests/unit/test_assets_phase8.gd")
const CARTER := "res://assets/models/characters/ph_chr_carter.glb"
## Body mesh and the four old clips before G8 round 3 (_mesh_hash / _anim_hash of test_assets_phase8.gd on e23b6ae).
const CARTER_MESH := "1000b3fb5f047602"
const CARTER_CLIPS := {"idle": "76952bfff6005617", "push_cart": "4638107ff1b48cb1", "talk": "c44ebce7aabd6fb5",
		"walk": "9c894870eab35336"}
const BONES: Array[String] = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const DELIVERY := 460
## A cart standing north of its handles, a bier 2.6 m east of the handles (the gate of the real world).
const HANDLES := Vector3(1.75, 0.0, 8.4)
const ROOT_YAW := PI
const CART_CENTER := Vector3(1.75, 0.63, 6.8)
const BIER := Vector3(4.4, 0.58, 8.3)


func _cfg() -> CartDeliveryConfig:
	var cfg := Database.config(&"cart_delivery_config") as CartDeliveryConfig
	assert_not_null(cfg, "data/config/cart_delivery_config.tres")
	return cfg if cfg != null else CartDeliveryConfig.new()


## On the cart head to the handles (slot +X towards the front board → turned round).
func _on_cart(lateral: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5 + PI), CART_CENTER + Vector3(lateral, 0.0, 0.0))


func _bier(dx: float = 0.0) -> Transform3D:
	return Transform3D.IDENTITY.translated(BIER + Vector3(dx, 0.0, 0.0))


func _pose(minute_f: float, cargo: Array[Transform3D], biers: Array[Transform3D], delivered: int = 0) -> Dictionary:
	return CartUnload.pose(_cfg(), minute_f, DELIVERY, cargo, biers, HANDLES, ROOT_YAW, CART_CENTER, Vector3(0, 0, -1),
			delivered, _bier(), _on_cart())


func _one() -> Array:
	var cargo: Array[Transform3D] = [_on_cart()]
	var biers: Array[Transform3D] = [_bier()]
	return [cargo, biers]


# --- data --------------------------------------------------------------------------------------------------

func test_values_in_data() -> void:
	var cfg := _cfg()
	assert_true(cfg.unload_minutes >= 4 and cfg.unload_minutes <= 15, "a few game minutes (%d)" % cfg.unload_minutes)
	var sh := cfg.shares()
	assert_almost(sh[0] + sh[1] + sh[2] + sh[3], 1.0, 0.0001, "shares add up")
	for v: float in sh:
		assert_true(v > 0.05, "every part is visible")
	assert_true(cfg.return_minutes >= 1)
	assert_true(cfg.head_to_handles, "the dead come down head first onto the bier")
	var tables := Database.corpse_tables() as CorpseTables
	assert_eq(tables.delivery_minute, DELIVERY, "§2.5: the corpse counts as delivered at 07:40")
	assert_eq(cfg.unload_start(tables.delivery_minute), DELIVERY - cfg.unload_minutes)


## Osric is at the bier when the unloading starts, without a prompt until the delivery minute.
func test_schedule_fits_the_unloading() -> void:
	var cfg := _cfg()
	var tables := Database.corpse_tables() as CorpseTables
	var s := Database.schedule(&"carter") as NpcSchedule
	var arrive: ScheduleEntry = null
	var unload: ScheduleEntry = null
	var stay: ScheduleEntry = null
	for e: ScheduleEntry in s.entries:
		if e.region != &"":
			continue
		if e.with_cart and e.travel_minutes > 0 and e.path.size() > 0 and e.path[e.path.size() - 1] == "dropoff":
			arrive = e
		elif e.activity == &"unload":
			unload = e
		elif e.with_cart and e.dialogue_id == &"carter" and e.travel_minutes == 0:
			stay = e
	assert_not_null(arrive, "morning_arrive")
	assert_not_null(unload, "morning_unload")
	assert_not_null(stay, "morning_dropoff")
	if arrive == null or unload == null or stay == null:
		return
	assert_eq(arrive.start_minute + arrive.travel_minutes, cfg.unload_start(tables.delivery_minute), "at the bier when he unloads")
	assert_eq(unload.start_minute, cfg.unload_start(tables.delivery_minute))
	assert_true(unload.with_cart and unload.dialogue_id == &"", "unloading: with the cart, no prompt")
	assert_eq(PackedStringArray(unload.path), PackedStringArray(["dropoff"]), "unloads at the bier")
	assert_eq(stay.start_minute, tables.delivery_minute, "talks once the corpse is on the bier")
	assert_eq(arrive.travel_minutes, 40, "pushes as fast as before (G8 Runde 3 sets off 8 min earlier)")


# --- CartUnload ----------------------------------------------------------------------------------------------

func test_inactive_outside_the_window() -> void:
	var one := _one()
	var start := float(_cfg().unload_start(DELIVERY))
	for m: float in [400.0, start - 0.01, float(DELIVERY), DELIVERY + 30.0]:
		assert_false(bool(_pose(m, one[0], one[1]).active), "minute %.2f" % m)
	var none: Array[Transform3D] = []
	assert_false(bool(_pose(start + 1.0, none, one[1]).active), "nothing to unload")
	assert_false(bool(_pose(start + 1.0, one[0], none).active), "no bier")


func test_phases_in_order() -> void:
	var cfg := _cfg()
	var one := _one()
	var start := float(cfg.unload_start(DELIVERY))
	var seen: Array[StringName] = []
	for k: int in 200:
		var p := _pose(start + cfg.unload_minutes * (k + 0.5) / 200.0, one[0], one[1])
		assert_true(bool(p.active))
		if seen.is_empty() or seen[seen.size() - 1] != p.anim:
			seen.append(p.anim)
	assert_eq(seen, [CartUnload.ANIM_WALK, CartUnload.ANIM_LIFT, CartUnload.ANIM_CARRY, CartUnload.ANIM_LOWER] as Array[StringName])


func test_corpse_goes_from_the_cart_to_the_bier() -> void:
	var cfg := _cfg()
	var one := _one()
	var sh := cfg.shares()
	var start := float(cfg.unload_start(DELIVERY))
	var at := func(u: float) -> Dictionary: return _pose(start + cfg.unload_minutes * u, one[0], one[1])
	# while he steps over it stays on the cart (index -1 = at rest)
	assert_eq(int(at.call(sh[0] * 0.5).index), -1)
	var lift0: Dictionary = at.call(sh[0] + 0.0001)
	assert_eq(int(lift0.index), 0)
	assert_true((lift0.corpse as Transform3D).origin.distance_to(_on_cart().origin) < 0.01, "lift starts on the cart")
	var carry: Dictionary = at.call(sh[0] + sh[1] + sh[2] * 0.5)
	var c := carry.corpse as Transform3D
	assert_almost(c.origin.y, HANDLES.y + cfg.carry_height, 0.001, "in his arms")
	assert_almost(CartUnload._flat(c.origin - (carry.figure as Vector3)).length(), cfg.carry_forward, 0.001, "in front of him")
	var end: Dictionary = at.call(0.9999)
	assert_eq(end.anim, CartUnload.ANIM_LOWER)
	assert_true((end.corpse as Transform3D).origin.distance_to(BIER) < 0.01, "laid onto the bier slot")
	assert_true((end.corpse as Transform3D).basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY) < 0.02, "lies as the bier wants it")
	# the figure: beside the cart facing it while lifting, in front of the bier facing it while lowering
	var f_lift: Vector3 = lift0.figure
	assert_almost(absf(f_lift.x - CART_CENTER.x), cfg.cart_side_distance, 0.001, "beside the cart")
	assert_true(f_lift.x > CART_CENTER.x, "on the side towards the bier")
	var f_low: Vector3 = end.figure
	assert_almost(CartUnload._flat(f_low - BIER).length(), cfg.bier_side_distance, 0.001, "at the bier")
	assert_true(CartUnload.forward(float(end.yaw)).dot(CartUnload._flat(BIER - f_low).normalized()) > 0.99, "faces the bier")


## No spin: in his arms the dead keep the orientation they had on the cart, and they reach the bier with it.
func test_no_turn_in_the_hands() -> void:
	var cfg := _cfg()
	var one := _one()
	var sh := cfg.shares()
	var start := float(cfg.unload_start(DELIVERY))
	var lift_end: Dictionary = _pose(start + cfg.unload_minutes * (sh[0] + sh[1] - 0.0001), one[0], one[1])
	var q_cart := _on_cart().basis.get_rotation_quaternion()
	assert_true((lift_end.corpse as Transform3D).basis.get_rotation_quaternion().angle_to(q_cart) < deg_to_rad(25.0),
			"lifted without turning round")
	var lower_start: Dictionary = _pose(start + cfg.unload_minutes * (1.0 - sh[3] + 0.0001), one[0], one[1])
	assert_true((lower_start.corpse as Transform3D).basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY) < deg_to_rad(25.0),
			"head first onto the bier, no half turn while lowering")


func test_two_corpses_one_after_the_other() -> void:
	var cfg := _cfg()
	var cargo: Array[Transform3D] = [_on_cart(-0.2), _on_cart(0.2)]
	var biers: Array[Transform3D] = [_bier(), _bier(2.4)]
	var start := float(cfg.unload_start(DELIVERY))
	var first := _pose(start + cfg.unload_minutes * 0.4, cargo, biers)
	assert_eq([int(first.laid), int(first.index)], [0, 0], "the first one in his hands")
	var second := _pose(start + cfg.unload_minutes * 0.9, cargo, biers)
	assert_eq(int(second.laid), 1, "the first one lies on its bier")
	assert_eq(int(second.index), 1, "then the second")
	var walk := _pose(start + cfg.unload_minutes * 0.51, cargo, biers)
	assert_eq(walk.anim, CartUnload.ANIM_WALK, "walks back to the cart between them")
	var last := _pose(start + cfg.unload_minutes * 0.9999, cargo, biers)
	assert_true((last.corpse as Transform3D).origin.distance_to(biers[1].origin) < 0.01, "the second onto the second bier")


func test_walks_back_after_the_delivery() -> void:
	var cfg := _cfg()
	var one := _one()
	var none: Array[Transform3D] = []
	var p := _pose(DELIVERY + 0.01, none, none, 1)
	assert_true(bool(p.active), "walks back")
	assert_eq(p.anim, CartUnload.ANIM_WALK)
	assert_true(CartUnload._flat((p.figure as Vector3) - BIER).length() < cfg.bier_side_distance + 0.05, "from the bier")
	var near := _pose(DELIVERY + cfg.return_minutes - 0.01, none, none, 1)
	assert_true(CartUnload._flat((near.figure as Vector3) - HANDLES).length() < 0.05, "to the handles")
	assert_false(bool(_pose(DELIVERY + cfg.return_minutes, none, none, 1).active), "then the clock places him as before")
	assert_false(bool(_pose(DELIVERY + 1.0, one[0], one[1], 0).active), "nothing delivered: nothing to walk back from")


func test_pose_is_a_function_of_the_clock() -> void:
	var one := _one()
	var a := _pose(455.37, one[0], one[1])
	var b := _pose(455.37, one[0], one[1])
	assert_eq(a, b, "same clock, same pose (loads and skips show the same)")


# --- the carter's clips --------------------------------------------------------------------------------------

func test_carter_keeps_body_and_old_clips() -> void:
	var rig: Object = CHARACTERS.Rig.new(CARTER)
	assert_eq(ASSETS8._mesh_hash(rig.mesh_instance), CARTER_MESH, "Osric's body unchanged")
	for clip: String in CARTER_CLIPS:
		assert_eq(ASSETS8._anim_hash(rig.animation(StringName(clip))), String(CARTER_CLIPS[clip]), "%s unchanged" % clip)
	var names: Array = []
	for n: StringName in (rig.player as AnimationPlayer).get_animation_list():
		names.append(String(n))
	names.sort()
	assert_eq(names, ["carry_walk", "idle", "load_lift", "load_lower", "push_cart", "ring_bell", "talk", "walk"])
	rig.call(&"free_scene")


## load_lift starts at rest and ends where load_lower starts (the carry pose, carry_walk in between); load_lower ends at rest.
func test_unload_clips_join_up() -> void:
	var rig: Object = CHARACTERS.Rig.new(CARTER)
	var sk: Skeleton3D = rig.skeleton
	var lift: Animation = rig.animation(&"load_lift")
	var lower: Animation = rig.animation(&"load_lower")
	var carry: Animation = rig.animation(&"carry_walk")
	assert_eq(lift.loop_mode, Animation.LOOP_NONE)
	assert_eq(lower.loop_mode, Animation.LOOP_NONE)
	assert_ne(carry.loop_mode, Animation.LOOP_NONE)
	for b: String in BONES:
		var bi := sk.find_bone(b)
		var rest := sk.get_bone_rest(bi)
		assert_true(_close(rig.local_pose(lift, bi, 0.0), rest), "load_lift starts at rest (%s)" % b)
		assert_true(_close(rig.local_pose(lower, bi, lower.length), rest), "load_lower ends at rest (%s)" % b)
		assert_true(_close(rig.local_pose(lift, bi, lift.length), rig.local_pose(lower, bi, 0.0)), "carry pose joins (%s)" % b)
	# he really bows over the cart: the spine bends forward by more than 30° in the middle of the lift
	var spine := sk.find_bone("spine")
	var bent: Transform3D = rig.local_pose(lift, spine, lift.length * 0.4)
	assert_true(bent.basis.get_rotation_quaternion().angle_to(sk.get_bone_rest(spine).basis.get_rotation_quaternion()) > deg_to_rad(30.0),
			"bows over the cart")
	rig.call(&"free_scene")


func _close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.004 and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) < 0.015
