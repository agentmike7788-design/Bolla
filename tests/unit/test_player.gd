extends TestCase
## M5: Player – scene, configs, movement/carry speed, states (LOCKED while modal),
## interaction input, focus prompt reporting, timed actions, carrying, drop position,
## start inventory, save/load (§3.4, §2.1).

const SCENE := "res://src/entities/player/player.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const DT := 1.0 / 60.0
const PHYSICS_FRAMES := 3
const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]
## TimeManager start after reset (data/config/time_config.tres): day 1, 06:30.
const START_MINUTE := 390


## Interaction target double.
class Target extends Node3D:
	var prompt: String = "Benutzen"
	var usable: bool = true
	var interactions: int = 0
	var last_player: Player

	func can_interact(_player: Player) -> bool:
		return usable

	func get_interaction_prompt(_player: Player) -> String:
		return prompt

	func interact(player: Player) -> void:
		interactions += 1
		last_player = player


## CorpseManager double (group corpse_manager): records put_down, re-parents like M3 would.
class FakeCorpseManager extends Node:
	var player: Player
	var accept: bool = true
	var calls: Array = []

	func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null) -> bool:
		calls.append([id, location, xform, parent])
		if not accept:
			return false
		var node := player.detach_carried()
		add_child(node)
		return true


var events: Array = []


func before_each() -> void:
	events.clear()
	EventBus.interaction_focus_changed.connect(_on_focus)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.timed_action_started.connect(_on_started)
	EventBus.timed_action_progress.connect(_on_progress)
	EventBus.timed_action_finished.connect(_on_finished)


func after_each() -> void:
	EventBus.interaction_focus_changed.disconnect(_on_focus)
	EventBus.notification_requested.disconnect(_on_notification)
	EventBus.timed_action_started.disconnect(_on_started)
	EventBus.timed_action_progress.disconnect(_on_progress)
	EventBus.timed_action_finished.disconnect(_on_finished)
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)


# --- scene & config -----------------------------------------------------------------------

func test_scene_structure_matches_contract() -> void:
	var p := await _player(false)
	assert_true(p.is_in_group(&"player"))
	assert_true(p.is_in_group(&"saveable"))
	assert_eq(p.save_id, "player")
	assert_eq(p.save_order, 100)
	assert_eq(p.collision_layer, 2, "layer 2 player")
	assert_eq(p.collision_mask, 5, "mask world | npc")
	var col := p.get_node("Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D
	assert_not_null(capsule)
	assert_almost(capsule.radius, 0.3)
	assert_almost(capsule.height, 1.7)
	assert_almost(col.position.y, 0.85)
	assert_eq(p.model.scene_file_path, "res://assets/models/characters/ph_chr_gravekeeper.glb")
	assert_almost(p.carry_socket.position.y, 0.9, 0.05, "chest height")
	assert_true(p.carry_socket.position.z > 0.2, "in front (+Z)")
	assert_true(p.detector is InteractionDetector)
	assert_eq(p.detector.collision_layer, 0)
	assert_eq(p.detector.collision_mask, 8)
	var reach := p.detector.get_child(0) as CollisionShape3D
	assert_almost((reach.shape as SphereShape3D).radius, 1.4)
	assert_true(reach.position.z > 0.0, "slightly in front")
	assert_eq(p.detector.player, p)
	assert_true(p.inventory is Inventory)
	assert_eq(p.inventory.slot_count, p.config.inventory_slots)
	assert_eq(p.state, Player.State.FREE)
	assert_false(p.is_busy())
	assert_null(p.carried)
	assert_eq(p.carried_id, "")
	assert_eq(p._anim, _anim_player(p), "rig AnimationPlayer found anywhere under Model")
	var rigged := (load("res://assets/models/characters/ph_chr_gravekeeper.glb") as PackedScene).instantiate()
	var has_rig := rigged.find_children("*", "AnimationPlayer", true, false).size() > 0
	rigged.free()
	assert_eq(p._anim != null, has_rig, "animation mode follows the model")


func test_configs_come_from_data() -> void:
	var p := await _player()
	assert_eq(p.config.resource_path, "res://data/config/player_config.tres")
	assert_almost(p.config.move_speed, 3.2)
	assert_almost(p.config.carry_speed, 2.0)
	assert_almost(p.config.drop_distance, 0.8)
	assert_eq(p.config.inventory_slots, 20, "Phase 5 §2.3: 16 → 20")
	assert_eq(p.config.start_items, {&"coin": 5, &"wood": 2, &"linen": 1})
	assert_eq(p.actions.resource_path, "res://data/config/action_config.tres")
	assert_eq([p.actions.examine_minutes, p.actions.shroud_minutes, p.actions.dig_minutes,
			p.actions.bury_minutes, p.actions.marker_minutes, p.actions.gather_minutes], [20, 10, 60, 30, 10, 10])
	assert_almost(p.actions.real_seconds_for(20), 1.5, 0.0001, "clamped to minimum")
	assert_almost(p.actions.real_seconds_for(60), 3.0)
	assert_almost(p.actions.real_seconds_for(200), 4.0, 0.0001, "clamped to maximum")
	assert_eq(Array(p.actions.tool_tier_factors), [1.0, 0.8, 0.6], "Phase 5 §2.3")
	assert_eq(p.actions.action_tools, {&"dig": &"shovel", &"bury": &"shovel"})
	assert_eq(p.actions.tool_minute_step, 5)
	assert_true(p.inventory.tool_belt, "the player carries the tool belt")
	assert_eq(p.inventory.slot_count, 20)


func test_injected_configs_are_kept() -> void:
	var cfg := PlayerConfig.new()
	cfg.move_speed = 7.0
	var act := ActionConfig.new()
	var p := await _player(true, Vector3.ZERO, cfg, act)
	assert_eq(p.config, cfg)
	assert_eq(p.actions, act)


func test_lantern_rides_on_rig_marker() -> void:
	var p := await _player()
	var marker := p.model.find_child("light_lantern", true, false)
	if marker == null:
		return  # model without marker: the light stays where the scene put it
	var lantern := marker.get_node_or_null("Lantern") as OmniLight3D
	assert_not_null(lantern, "Lantern moved onto the light_lantern marker")
	assert_true(lantern.is_in_group(&"warm_lights"))
	assert_true(lantern.transform.is_equal_approx(Transform3D.IDENTITY))


## UI-01: the player is the target of the foliage occlusion cutout – their chest, every frame
## (global shader uniform occlusion_target; the headless renderer cannot read it back).
func test_publishes_the_occlusion_target() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	assert_true(p.has_method(&"occlusion_point"), "Player.occlusion_point()")
	if not p.has_method(&"occlusion_point"):
		return
	assert_true(p.is_processing(), "updated every rendered frame")
	var chest := float(p.get(&"occlusion_height"))
	assert_true(chest > 0.9 and chest < 1.4, "chest height of the 1.77 m figure (%.2f)" % chest)
	var point: Vector3 = p.call(&"occlusion_point")
	assert_true(point.is_equal_approx(p.global_position + Vector3(0, chest, 0)), str(point))
	var global: Variant = RenderingServer.global_shader_parameter_get(&"occlusion_target")
	if global != null:
		await tree.process_frame
		assert_true((RenderingServer.global_shader_parameter_get(&"occlusion_target") as Vector3).is_equal_approx(point))
	assert_true(ProjectSettings.has_setting("shader_globals/occlusion_target"), "global uniform declared (project.godot)")


# --- movement -----------------------------------------------------------------------------

func test_moves_with_move_speed() -> void:
	var p := await _player()
	p.set_physics_process(false)
	Input.action_press(&"move_right")
	p._physics_process(DT)
	assert_almost(p.velocity.x, 3.2, 0.01)
	assert_almost(p.velocity.z, 0.0, 0.01)
	assert_true(p.position.x > 0.0, "moved")
	Input.action_release(&"move_right")
	Input.action_press(&"move_up")
	p._physics_process(DT)
	assert_almost(p.velocity.z, -3.2, 0.01, "camera yaw 0: move_up = -Z")
	assert_almost(p.velocity.x, 0.0, 0.01)


func test_diagonal_is_not_faster() -> void:
	var p := await _player()
	p.set_physics_process(false)
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	p._physics_process(DT)
	assert_almost(Vector2(p.velocity.x, p.velocity.z).length(), 3.2, 0.01)


func test_stands_still_without_input() -> void:
	var p := await _player()
	p.set_physics_process(false)
	p._physics_process(DT)
	assert_almost(p.velocity.x, 0.0)
	assert_almost(p.velocity.z, 0.0)


func test_carrying_uses_carry_speed() -> void:
	var p := await _player()
	p.set_physics_process(false)
	p.attach_carried(Node3D.new(), "c1")
	assert_eq(p.state, Player.State.CARRYING)
	Input.action_press(&"move_left")
	p._physics_process(DT)
	assert_almost(p.velocity.x, -2.0, 0.01)


func test_turns_toward_movement() -> void:
	var p := await _player()
	p.set_physics_process(false)
	Input.action_press(&"move_right")
	for i: int in 60:
		p._physics_process(DT)
	assert_almost(p.rotation.y, PI / 2.0, 0.01, "faces +X")
	assert_true(p.global_basis.z.dot(Vector3.RIGHT) > 0.99, "model/detector/socket turn along")


func test_falls_with_gravity_without_ground() -> void:
	var p := await _player(true, Vector3(100, 5, 100))
	p.set_physics_process(false)
	p._physics_process(DT)
	assert_true(p.velocity.y < 0.0)


# --- states -------------------------------------------------------------------------------

func test_locked_while_modal_open() -> void:
	var p := await _player()
	p.set_physics_process(false)
	UIState.push_modal(&"test")
	assert_eq(p.state, Player.State.LOCKED)
	Input.action_press(&"move_right")
	p._physics_process(DT)
	assert_almost(p.velocity.x, 0.0, 0.0001, "no movement while locked")
	UIState.pop_modal(&"test")
	assert_eq(p.state, Player.State.FREE)
	p._physics_process(DT)
	assert_almost(p.velocity.x, 3.2, 0.01)


func test_modal_restores_carrying() -> void:
	var p := await _player()
	p.attach_carried(Node3D.new(), "c1")
	UIState.push_modal(&"test")
	assert_eq(p.state, Player.State.LOCKED)
	UIState.pop_modal(&"test")
	assert_eq(p.state, Player.State.CARRYING)


func test_attach_while_modal_stays_locked() -> void:
	var p := await _player()
	UIState.push_modal(&"corpse_exam")
	p.attach_carried(Node3D.new(), "c1")
	assert_eq(p.state, Player.State.LOCKED, "panel button picked it up – still locked")
	UIState.pop_modal(&"corpse_exam")
	assert_eq(p.state, Player.State.CARRYING)


func test_spawned_during_modal_starts_locked() -> void:
	UIState.push_modal(&"test")
	var p := await _player()
	assert_eq(p.state, Player.State.LOCKED)
	UIState.clear()
	assert_eq(p.state, Player.State.FREE)


# --- interaction input & focus prompt -----------------------------------------------------

func test_interact_uses_focused_target() -> void:
	var p := await _player()
	var target := _target(Vector3(0, 0, 0.9))
	await _physics()
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(target.interactions, 1)
	assert_eq(target.last_player, p)
	assert_eq(_events_of("notify"), [])


func test_interact_on_unusable_target_warns_with_prompt() -> void:
	var p := await _player()
	var target := _target(Vector3(0, 0, 0.9), "Hände frei nötig – [Q] ablegen")
	target.usable = false
	await _physics()
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(target.interactions, 0)
	assert_eq(_events_of("notify"), [["notify", "Hände frei nötig – [Q] ablegen", &"warning"]])


func test_interact_without_focus_does_nothing() -> void:
	var p := await _player()
	await _physics()
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(_events_of("notify"), [])


func test_interact_blocked_while_locked_or_busy() -> void:
	var p := await _player()
	var target := _target(Vector3(0, 0, 0.9))
	await _physics()
	UIState.push_modal(&"test")
	p._unhandled_input(_action_event(&"interact"))
	UIState.pop_modal(&"test")
	assert_true(p.start_timed_action("Graben", 60, func() -> void: pass))
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(target.interactions, 0)
	p.cancel_timed_action()
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(target.interactions, 1)


func test_carrying_player_can_still_interact() -> void:
	var p := await _player()
	p.attach_carried(Node3D.new(), "c1")
	var target := _target(Vector3(0, 0, 0.9), "Leiche ablegen")
	await _physics()
	p._unhandled_input(_action_event(&"interact"))
	assert_eq(target.interactions, 1, "the target decides via can_interact")


func test_focus_prompt_reported_on_change_only() -> void:
	var p := await _player()
	var target := _target(Vector3(0, 0, 0.9), "Grab ausheben (60 Min)")
	await _physics()
	assert_eq(_events_of("focus"), [["focus", "Grab ausheben (60 Min)", true]])
	await _physics()
	assert_eq(_events_of("focus").size(), 1, "polled every frame, emitted on change only")
	target.usable = false
	await _physics()
	target.prompt = "Schaufel fehlt"
	await _physics()
	target.prompt = ""
	await _physics()
	assert_eq(_events_of("focus"), [
		["focus", "Grab ausheben (60 Min)", true],
		["focus", "Grab ausheben (60 Min)", false],
		["focus", "Schaufel fehlt", false],
		["focus", "", false],
	])
	assert_not_null(p)


func test_focus_switch_between_equal_prompts_is_reported() -> void:
	var p := await _player()
	var a := _target(Vector3(0, 0, 0.9), "Grab ausheben (60 Min)")
	await _physics()
	_target(Vector3(0, 0, 0.4), "Grab ausheben (60 Min)")
	await _physics()
	assert_eq(_events_of("focus").size(), 2, "new target, same text → reported")
	a.queue_free()
	await _physics()
	assert_eq(_events_of("focus").size(), 2, "focus stayed on the nearer one")
	assert_not_null(p)


func test_focus_hidden_while_locked_and_busy() -> void:
	var p := await _player()
	_target(Vector3(0, 0, 0.9))
	await _physics()
	UIState.push_modal(&"test")
	await _physics()
	UIState.pop_modal(&"test")
	await _physics()
	p.start_timed_action("Sammeln", 10, func() -> void: pass, false)
	await _physics()
	p.cancel_timed_action()
	await _physics()
	assert_eq(_events_of("focus"), [
		["focus", "Benutzen", true], ["focus", "", false],
		["focus", "Benutzen", true], ["focus", "", false],
		["focus", "Benutzen", true],
	])


func test_leaving_the_tree_clears_the_prompt() -> void:
	var p := await _player()
	_target(Vector3(0, 0, 0.9))
	await _physics()
	tree.root.remove_child(p)
	assert_eq(_events_of("focus").back(), ["focus", "", false])
	p.free()


# --- timed actions ------------------------------------------------------------------------

func test_timed_action_advances_time_progressively() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [0]
	assert_true(p.start_timed_action("Untersuchen", 20, func() -> void: done[0] += 1))
	assert_true(p.is_busy())
	assert_true(TimeManager.paused, "clock paused by &\"action\"")
	assert_eq(_events_of("started"), [["started", "Untersuchen", 1.5]])
	p._physics_process(0.75)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 10, "half the bar = half the minutes")
	assert_eq(done[0], 0)
	assert_almost(float(_events_of("progress").back()[1]), 0.5)
	p._physics_process(0.75)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20)
	assert_eq(done[0], 1, "on_done once")
	assert_false(p.is_busy())
	assert_false(TimeManager.paused)
	assert_eq(_events_of("finished"), [["finished", true]])
	p._physics_process(1.0)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20, "nothing after completion")
	assert_eq(done[0], 1)


func test_timed_action_minutes_are_whole_and_monotonic() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var ticks: Array[int] = []
	var on_tick := func(_d: int, m: int) -> void: ticks.append(m)
	EventBus.time_tick.connect(on_tick)
	p.start_timed_action("Graben", 60, func() -> void: pass, true, &"dig")  # 3.0 s
	for i: int in 10:
		p._physics_process(0.1)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20, "1 s of 3 s = 20 of 60 minutes")
	p._physics_process(0.05)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 21)
	while p.is_busy():
		p._physics_process(0.1)
	EventBus.time_tick.disconnect(on_tick)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 60)
	for i: int in range(1, ticks.size()):
		assert_true(ticks[i] > ticks[i - 1], "clock only moves forward")
	assert_true(ticks.size() > 10, "visible fast-forward in many steps")


func test_start_refused_while_busy() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var second := [false]
	assert_true(p.start_timed_action("Graben", 60, func() -> void: pass))
	assert_false(p.start_timed_action("Sammeln", 10, func() -> void: second[0] = true))
	assert_eq(_events_of("started").size(), 1)
	while p.is_busy():
		p._physics_process(0.5)
	assert_false(second[0])
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 60)


func test_cancel_keeps_minutes_and_skips_on_done() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [false]
	p.start_timed_action("Untersuchen", 20, func() -> void: done[0] = true)
	p._physics_process(0.75)
	p.cancel_timed_action()
	assert_false(p.is_busy())
	assert_false(TimeManager.paused)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 10, "advanced minutes stay")
	assert_eq(_events_of("finished"), [["finished", false]])
	p._physics_process(2.0)
	assert_false(done[0], "on_done never called")
	p.cancel_timed_action()
	assert_eq(_events_of("finished").size(), 1, "cancel without action is a no-op")


func test_movement_cancels_cancellable_action() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [false]
	p.start_timed_action("Sammeln", 10, func() -> void: done[0] = true)
	p._physics_process(DT)
	assert_true(p.is_busy(), "standing still keeps it running")
	Input.action_press(&"move_up")
	p._physics_process(DT)
	assert_false(p.is_busy())
	assert_eq(_events_of("finished"), [["finished", false]])
	assert_false(done[0])
	assert_almost(p.velocity.z, -3.2, 0.01, "walks off right away")


func test_movement_does_not_cancel_non_cancellable_action() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [false]
	p.start_timed_action("Leichentuch anlegen", 10, func() -> void: done[0] = true, false)
	Input.action_press(&"move_up")
	p._physics_process(DT)
	assert_true(p.is_busy())
	assert_almost(p.velocity.z, 0.0, 0.0001, "held in place")
	while p.is_busy():
		p._physics_process(0.5)
	assert_true(done[0])


func test_action_allowed_while_locked() -> void:
	var p := await _player()
	p.set_physics_process(false)
	UIState.push_modal(&"corpse_exam")
	var done := [false]
	assert_true(p.start_timed_action("Untersuchen", 20, func() -> void: done[0] = true, false))
	Input.action_press(&"move_right")
	while p.is_busy():
		p._physics_process(0.5)
	assert_true(done[0])
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20)
	assert_true(TimeManager.paused, "modal pause remains")
	UIState.pop_modal(&"corpse_exam")
	assert_false(TimeManager.paused)


func test_locked_input_does_not_cancel_action() -> void:
	var p := await _player()
	p.set_physics_process(false)
	p.start_timed_action("Sammeln", 10, func() -> void: pass)
	UIState.push_modal(&"debug")
	Input.action_press(&"move_right")  # e.g. typing into the debug console
	p._physics_process(DT)
	assert_true(p.is_busy())


func test_instant_actions_finish_in_the_call() -> void:
	var p := await _player()
	p.instant_actions = true
	var done := [0]
	assert_true(p.start_timed_action("Graben", 60, func() -> void: done[0] += 1))
	assert_eq(done[0], 1)
	assert_false(p.is_busy())
	assert_false(TimeManager.paused)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 60)
	assert_eq(_events_of("started"), [["started", "Graben", 0.0]])
	assert_eq(_events_of("finished"), [["finished", true]])


func test_on_done_may_start_the_next_action() -> void:
	var p := await _player()
	p.instant_actions = true
	var chained := [false]
	p.start_timed_action("Graben", 60, func() -> void:
		chained[0] = p.start_timed_action("Bestatten", 30, func() -> void: pass))
	assert_true(chained[0])
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 90)


func test_busy_during_instant_time_advance() -> void:
	var p := await _player()
	p.instant_actions = true
	var busy_seen := [false]
	var on_tick := func(_d: int, _m: int) -> void: busy_seen[0] = p.is_busy()
	EventBus.time_tick.connect(on_tick)
	p.start_timed_action("Sammeln", 10, func() -> void: pass)
	EventBus.time_tick.disconnect(on_tick)
	assert_true(busy_seen[0], "listeners of the advance see a busy player")


func test_zero_and_negative_minutes() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [0]
	assert_true(p.start_timed_action("Nichts", 0, func() -> void: done[0] += 1))
	assert_eq(_events_of("started"), [["started", "Nichts", 1.5]], "minimum bar length")
	while p.is_busy():
		p._physics_process(0.5)
	assert_true(p.start_timed_action("Negativ", -5, func() -> void: done[0] += 1))
	while p.is_busy():
		p._physics_process(0.5)
	assert_eq(done[0], 2)
	assert_eq(TimeManager.minute_of_day, START_MINUTE, "no time passes")


func test_invalid_on_done_is_tolerated() -> void:
	var p := await _player()
	p.instant_actions = true
	assert_true(p.start_timed_action("Leer", 10, Callable()))
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 10)


func test_leaving_the_tree_cancels_the_action() -> void:
	var p := await _player()
	p.start_timed_action("Graben", 60, func() -> void: pass)
	tree.root.remove_child(p)
	assert_false(TimeManager.paused, "no pause left behind")
	assert_eq(_events_of("finished"), [["finished", false]])
	p.free()


func test_action_plays_its_animation() -> void:
	var p := await _player()
	var anim := _anim_player(p)
	if anim == null:
		return  # rig not merged: procedural fallback (see test_waddle_fallback)
	p.set_physics_process(false)
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"idle")
	p.start_timed_action("Untersuchen", 20, func() -> void: pass, true, &"interact")
	assert_eq(anim.current_animation, &"interact")
	p.cancel_timed_action()
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"idle")
	# G7 Runde 2: dig draws the shovel first (test_player_shovel.gd covers the tool phases)
	p.start_timed_action("Graben", 60, func() -> void: pass, true, &"dig")
	assert_eq(anim.current_animation, &"shovel_draw")
	p.cancel_timed_action()
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"shovel_stow")
	p.reset_tool()
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"idle")
	p.start_timed_action("Untersuchen", 20, func() -> void: pass, true, &"no_such_anim")
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"idle", "unknown animation → state animation")


func test_animations_follow_state() -> void:
	var p := await _player()
	var anim := _anim_player(p)
	if anim == null:
		return
	p.set_physics_process(false)
	Input.action_press(&"move_right")
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"walk")
	p.attach_carried(Node3D.new(), "c1")
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"carry_walk")
	Input.action_release(&"move_right")
	p._physics_process(DT)
	assert_eq(anim.current_animation, &"carry_idle")


func test_waddle_fallback_without_animation_player() -> void:
	var p := (load(SCENE) as PackedScene).instantiate() as Player
	for n: Node in p.get_node("Model").find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	tree.root.add_child(p)
	p.set_physics_process(false)
	Input.action_press(&"move_right")
	for i: int in 10:
		p._physics_process(DT)
	assert_true(absf(p.model.rotation.z) > 0.0001 or p.model.position.y > 0.0001, "procedural waddle")


# --- carrying -----------------------------------------------------------------------------

func test_attach_puts_node_into_socket_and_disables_interactables() -> void:
	var p := await _player()
	var corpse := _corpse()
	var own := corpse.get_node("Interactable") as Interactable
	var nested := corpse.get_node("Part/Interactable") as Interactable
	var off := corpse.get_node("Off") as Interactable
	p.attach_carried(corpse, "c1")
	assert_eq(corpse.get_parent(), p.carry_socket)
	assert_true(corpse.transform.is_equal_approx(Transform3D.IDENTITY))
	assert_eq(p.carried, corpse)
	assert_eq(p.carried_id, "c1")
	assert_eq(p.state, Player.State.CARRYING)
	assert_false(own.enabled)
	assert_false(nested.enabled)
	await tree.process_frame
	assert_false(own.monitorable, "deferred monitorable = false")
	assert_false(nested.monitorable)
	var node := p.detach_carried()
	assert_eq(node, corpse)
	assert_null(corpse.get_parent(), "caller re-parents")
	assert_null(p.carried)
	assert_eq(p.carried_id, "")
	assert_eq(p.state, Player.State.FREE)
	assert_true(own.enabled)
	assert_true(nested.enabled)
	assert_false(off.enabled, "was disabled before – stays disabled")
	await tree.process_frame
	assert_true(own.monitorable)
	corpse.free()


func test_attach_node_outside_the_tree() -> void:
	var p := await _player()
	var node := Node3D.new()
	p.attach_carried(node, "c2")
	assert_eq(node.get_parent(), p.carry_socket)
	assert_true(node.is_inside_tree())


func test_carried_interactable_is_not_focused() -> void:
	var p := await _player()
	var corpse := _corpse()
	await _physics()
	p.attach_carried(corpse, "c1")
	await _physics()
	assert_null(p.detector.focused, "own load never takes the focus")


func test_attach_refused_while_carrying_another() -> void:
	var p := await _player()
	var first := Node3D.new()
	var second := Node3D.new()
	p.attach_carried(first, "a")
	p.attach_carried(second, "b")
	assert_eq(p.carried, first)
	assert_eq(p.carried_id, "a")
	assert_null(second.get_parent())
	p.attach_carried(null, "x")
	assert_eq(p.carried, first)
	second.free()


func test_detach_without_carried_returns_null() -> void:
	var p := await _player()
	assert_null(p.detach_carried())
	assert_eq(p.state, Player.State.FREE)


func test_freed_carried_node_releases_the_hands() -> void:
	var p := await _player()
	var corpse := _corpse()
	p.attach_carried(corpse, "c1")
	corpse.queue_free()  # e.g. buried and removed by the CorpseManager
	await _physics()
	assert_eq(p.state, Player.State.FREE)
	assert_null(p.carried)
	assert_eq(p.carried_id, "")


# --- drop ---------------------------------------------------------------------------------

func test_drop_position_in_front_on_the_ground() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	var xf := p.drop_position()
	assert_true(xf.origin.is_equal_approx(Vector3(2, 0, 3.8)), "0.8 m in front: %s" % xf.origin)
	assert_true(xf.basis.is_equal_approx(Basis()), "lies across the facing direction")
	p.rotation.y = PI / 2.0
	xf = p.drop_position()
	assert_true(xf.origin.is_equal_approx(Vector3(2.8, 0, 3)), "turned to +X: %s" % xf.origin)
	assert_true(xf.basis.z.is_equal_approx(Vector3.RIGHT))


func test_drop_position_follows_ground_height() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	_box(Vector3(2, 0.1, 5), Vector3(3, 0.2, 3))  # 20 cm step in front
	await _physics()
	var xf := p.drop_position()
	assert_almost(xf.origin.y, 0.2, 0.001)


func test_drop_position_falls_back_to_feet() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	_box(Vector3(2, 1, 4.2), Vector3(4, 2, 0.4))  # wall 1 m ahead
	await _physics()
	var xf := p.drop_position()
	assert_true(xf.origin.is_equal_approx(Vector3(2, 0, 3)), "at the feet: %s" % xf.origin)


func test_drop_position_rejects_low_obstacle() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	_box(Vector3(2, 0.15, 3.8), Vector3(0.3, 0.3, 0.3))  # small crate in front
	await _physics()
	var xf := p.drop_position()
	assert_true(xf.origin.is_equal_approx(Vector3(2, 0, 3)), "crate blocks the front spot: %s" % xf.origin)


func test_drop_position_invalid_when_boxed_in() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	_box(Vector3(2, 1, 4.2), Vector3(4, 2, 0.4))  # wall ahead: front spot blocked
	_box(Vector3(2.55, 1, 3), Vector3(0.2, 2, 4))  # fence 5 cm beside the shoulder: feet blocked
	await _physics()
	assert_eq(p.drop_position(), Transform3D())


func test_drop_position_ignores_ground_out_of_step_range() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	_box(Vector3(2, 0.2, 5), Vector3(3, 0.4, 3))  # 40 cm ledge ahead: too high to put down on
	await _physics()
	var xf := p.drop_position()
	assert_true(xf.origin.is_equal_approx(Vector3(2, 0, 3)), "falls back to the feet: %s" % xf.origin)


func test_drop_position_invalid_without_ground() -> void:
	var p := await _player(true, Vector3(100, 0, 100))
	assert_eq(p.drop_position(), Transform3D())


func test_valid_drop_at_origin_is_not_the_invalid_marker() -> void:
	var p := await _player(true, Vector3.ZERO)
	_box(Vector3(0, 1, 1.2), Vector3(4, 2, 0.4))
	await _physics()
	var xf := p.drop_position()
	assert_ne(xf, Transform3D(), "feet spot at the world origin must still read as valid")
	assert_almost(xf.origin.y, 0.0, 0.01)


func test_drop_action_puts_corpse_down() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	var manager := _manager(p)
	var corpse := _corpse()
	p.attach_carried(corpse, "c7")
	var expected := p.drop_position()
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls.size(), 1)
	assert_eq(manager.calls[0][0], "c7")
	assert_eq(manager.calls[0][1], &"ground")
	assert_true((manager.calls[0][2] as Transform3D).is_equal_approx(expected))
	assert_eq(corpse.get_parent(), manager)
	assert_eq(p.state, Player.State.FREE)
	assert_eq(_events_of("notify"), [])


func test_drop_action_warns_on_invalid_spot() -> void:
	var p := await _player(true, Vector3(100, 0, 100))
	var manager := _manager(p)
	p.attach_carried(Node3D.new(), "c7")
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls, [])
	assert_eq(_events_of("notify"), [["notify", "Hier nicht ablegen.", &"warning"]])
	assert_eq(p.state, Player.State.CARRYING)


func test_drop_action_ignored_when_not_allowed() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	var manager := _manager(p)
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls, [], "hands empty")
	p.attach_carried(Node3D.new(), "c7")
	UIState.push_modal(&"test")
	p._unhandled_input(_action_event(&"drop"))
	UIState.pop_modal(&"test")
	assert_eq(manager.calls, [], "locked")
	p.start_timed_action("Bestatten", 30, func() -> void: pass)
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls, [], "busy")
	p.cancel_timed_action()
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls.size(), 1)


func test_drop_refused_by_manager_keeps_carrying() -> void:
	var p := await _player(true, Vector3(2, 0, 3))
	var manager := _manager(p)
	manager.accept = false
	p.attach_carried(Node3D.new(), "c7")
	p._unhandled_input(_action_event(&"drop"))
	assert_eq(manager.calls.size(), 1)
	assert_eq(p.state, Player.State.CARRYING)


# --- start inventory & save/load ----------------------------------------------------------

func test_apply_start_inventory_replaces_contents() -> void:
	var p := await _player()
	p.inventory.add_item(&"stone", 9)
	p.apply_start_inventory()
	assert_eq((p.inventory as FakeInventory).items, {&"coin": 5, &"wood": 2, &"linen": 1})


func test_start_inventory_on_new_game_started() -> void:
	var p := await _player()
	EventBus.new_game_started.emit()
	assert_eq(p.inventory.count(&"coin"), 5)
	assert_eq(p.inventory.count(&"wood"), 2)
	assert_eq(p.inventory.count(&"linen"), 1)


func test_start_inventory_with_real_inventory() -> void:
	var p := await _player(false)
	p.apply_start_inventory()
	assert_eq(p.inventory.count(&"coin"), 5)
	assert_eq(p.inventory.count(&"wood"), 2)
	assert_eq(p.inventory.count(&"linen"), 1)


func test_ready_grants_no_start_content() -> void:
	var p := await _player()
	assert_eq((p.inventory as FakeInventory).items, {}, "start content only on new_game_started")


func test_save_load_round_trip_through_json() -> void:
	var a := await _player(true, Vector3(1.5, 0, -2.25))
	a.rotation.y = 1.25
	a.inventory.add_item(&"wood", 3)
	a.attach_carried(Node3D.new(), "c1")
	var saved := a.save_state()
	assert_false(saved.has("carried_id"), "carried corpse is the CorpseManager's business")
	var text := JSON.stringify(JSON.from_native(saved))
	var restored: Dictionary = JSON.to_native(JSON.parse_string(text))
	var b := await _player(true, Vector3(9, 0, 9))
	b.set_physics_process(false)
	b.load_state(restored)
	assert_true(b.position.is_equal_approx(Vector3(1.5, 0, -2.25)))
	assert_almost(b.rotation.y, 1.25)
	assert_eq(b.save_state(), saved, "save → JSON → load → save is identical")
	assert_true(restored["position"] is Vector3, "typed through JSON.from_native")


func test_load_state_resets_timed_action_and_carry() -> void:
	var p := await _player()
	p.set_physics_process(false)
	var done := [false]
	var corpse := Node3D.new()
	p.attach_carried(corpse, "c1")
	p.start_timed_action("Graben", 60, func() -> void: done[0] = true)
	p.load_state({"position": Vector3(1, 0, 1), "rot_y": 0.5, "inventory": {"items": {&"coin": 2}}})
	assert_false(p.is_busy())
	assert_false(TimeManager.paused)
	assert_eq(_events_of("finished"), [["finished", false]])
	assert_false(done[0])
	assert_null(p.carried)
	assert_eq(p.carried_id, "")
	assert_eq(p.state, Player.State.FREE)
	assert_eq(p.inventory.count(&"coin"), 2)
	assert_almost(p.velocity.length(), 0.0)


func test_load_state_tolerates_missing_and_bad_values() -> void:
	var p := await _player(true, Vector3(4, 0, 4))
	p.inventory.add_item(&"coin", 3)
	p.load_state({"position": "nonsense", "rot_y": null})
	assert_true(p.position.is_equal_approx(Vector3(4, 0, 4)), "keeps the scene position")
	assert_eq(p.inventory.count(&"coin"), 0, "inventory replaced completely")
	p.load_state({"rot_y": 2})
	assert_almost(p.rotation.y, 2.0, 0.0001, "int accepted")


func test_is_saveable_by_save_manager() -> void:
	var p := await _player()
	p.inventory.add_item(&"coin", 4)
	var nodes: Dictionary = SaveManager.collect_state()["nodes"]
	assert_true(nodes.has("player"))
	assert_eq(nodes["player"], p.save_state())


# --- Phase 5: tool belt & tiers (P3, docs/PHASE5_DESIGN.md §2.3, §3.4) --------------------------

func test_real_inventory_has_20_slots_and_a_belt() -> void:
	var p := await _player(false)
	assert_true(p.inventory.tool_belt)
	assert_eq(p.inventory.get_slots().size(), 20)
	p.inventory.add_item(&"rake", 1)
	assert_eq(p.inventory.tools(), {&"rake": 1} as Dictionary[StringName, int], "tools hang on the belt")


func test_tool_tier_from_the_belt() -> void:
	var p := await _player(false)
	assert_eq([p.tool_tier(&"shovel"), p.tool_tier(&"axe"), p.tool_tier(&"pickaxe")], [0, 0, 0])
	p.inventory.add_item(&"shovel_iron", 1)
	p.inventory.add_item(&"pickaxe_master", 1)
	assert_eq([p.tool_tier(&"shovel"), p.tool_tier(&"axe"), p.tool_tier(&"pickaxe")], [1, 0, 2])


func test_tool_tier_survives_save_and_load_without_a_signal() -> void:
	var a := await _player(false)
	a.inventory.add_item(&"axe_iron", 1)
	a.inventory.add_item(&"wood", 2)
	var saved := a.save_state()
	assert_eq(saved["inventory"]["tools"], {&"axe_iron": 1})
	var text := JSON.stringify(JSON.from_native(saved))
	var b := await _player(false, Vector3(3, 0, 3))
	b.set_physics_process(false)
	var heard: Array = []
	var on_tier := func(kind: StringName, tier: int) -> void: heard.append([kind, tier])
	EventBus.tool_tier_changed.connect(on_tier)
	b.load_state(JSON.to_native(JSON.parse_string(text)))
	EventBus.tool_tier_changed.disconnect(on_tier)
	assert_eq(b.tool_tier(&"axe"), 1)
	assert_eq(b.inventory.count(&"wood"), 2)
	assert_eq(b.save_state(), saved, "identical after the roundtrip")
	assert_eq(heard, [], "no tool_tier_changed when loading (§3.3)")


func test_old_save_with_tools_in_slots_loads_onto_the_belt() -> void:
	var p := await _player(false)
	p.set_physics_process(false)
	var slots: Array = []
	for i: int in 16:
		slots.append({})
	slots[1] = {"id": "comb", "amount": 1}
	slots[3] = {"id": "linen", "amount": 2}
	p.load_state({"position": Vector3.ZERO, "rot_y": 0.0, "inventory": {"slots": slots, "currency": {"coin": 7}}})
	assert_eq(p.inventory.tools(), {&"comb": 1} as Dictionary[StringName, int])
	assert_eq(p.inventory.get_slots().size(), 20)
	assert_eq(p.inventory.get_slots()[3], {"id": &"linen", "amount": 2})
	assert_eq(p.inventory.count(&"coin"), 7)


func test_dig_and_bury_minutes_follow_the_shovel_tier() -> void:
	var world := await _grave_world()
	var p: Player = world.get_node("Player")
	var plot: GravePlot = world.get_node("Plot")
	assert_eq(plot.get_interaction_prompt(p), "[E] Grab ausheben (60 Min)")
	assert_eq([GravePlot._dig_minutes(p), GravePlot._bury_minutes(p)], [60, 30])
	p.inventory.add_item(&"shovel_iron", 1)
	assert_eq(plot.get_interaction_prompt(p), "[E] Grab ausheben (50 Min)")
	assert_eq([GravePlot._dig_minutes(p), GravePlot._bury_minutes(p)], [50, 25])
	p.inventory.add_item(&"shovel_master", 1)
	assert_eq(plot.get_interaction_prompt(p), "[E] Grab ausheben (35 Min)")
	assert_eq([GravePlot._dig_minutes(p), GravePlot._bury_minutes(p)], [35, 20])
	var before := TimeManager.total_minutes()
	plot.interact(p)
	var graveyard: Graveyard = world.get_node("Graveyard")
	assert_eq(graveyard.get_grave("plot_01").state, GraveRecord.State.DUG)
	assert_eq(TimeManager.total_minutes() - before, 35, "digging with the master shovel takes 35 game minutes")


## Small world: Graveyard (fixture economy/tables), one plot, the real player (instant actions).
func _grave_world() -> Node3D:
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var world := Node3D.new()
	var graveyard := Graveyard.new()
	graveyard.name = "Graveyard"
	graveyard.economy = load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig
	graveyard.tables = load("res://tests/fixtures/corpse_tables_fixture.tres") as CorpseTables
	world.add_child(graveyard)
	var plot := (load("res://src/entities/grave/grave_plot.tscn") as PackedScene).instantiate() as GravePlot
	plot.name = "Plot"
	plot.grave_id = "plot_01"
	plot.position = Vector3(6, 0, 0)
	world.add_child(plot)
	var p := (load(SCENE) as PackedScene).instantiate() as Player
	p.name = "Player"
	p.position = Vector3(0, 0, 4)
	world.add_child(p)
	tree.root.add_child(world)
	p.instant_actions = true
	await tree.process_frame
	return world


# --- helpers ------------------------------------------------------------------------------

func _player(fake_inventory: bool = true, at: Vector3 = Vector3.ZERO, cfg: PlayerConfig = null,
		act: ActionConfig = null) -> Player:
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))  # floor (layer 1)
	var p := (load(SCENE) as PackedScene).instantiate() as Player
	if fake_inventory:
		var old := p.get_node("Inventory")
		p.remove_child(old)
		old.free()
		var inv := FakeInventory.new()
		inv.name = "Inventory"
		p.add_child(inv)
	p.config = cfg
	p.actions = act
	p.position = at
	tree.root.add_child(p)
	await tree.physics_frame
	return p


func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	tree.root.add_child(body)
	return body


func _target(pos: Vector3, prompt: String = "Benutzen") -> Target:
	var target := Target.new()
	target.prompt = prompt
	tree.root.add_child(target)
	target.global_position = pos
	target.add_child(_interactable())
	return target


## Corpse double: own Interactable, a nested one, and one that is already disabled.
func _corpse() -> Node3D:
	var corpse := Target.new()
	tree.root.add_child(corpse)
	corpse.global_position = Vector3(0, 0, 0.9)
	corpse.add_child(_interactable())
	var part := Node3D.new()
	part.name = "Part"
	corpse.add_child(part)
	part.add_child(_interactable())
	var off := _interactable()
	off.name = "Off"
	off.enabled = false
	corpse.add_child(off)
	return corpse


func _interactable() -> Interactable:
	var ia := Interactable.new()
	ia.name = "Interactable"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	ia.add_child(shape)
	return ia


func _manager(p: Player) -> FakeCorpseManager:
	var manager := FakeCorpseManager.new()
	manager.player = p
	manager.add_to_group(&"corpse_manager")
	tree.root.add_child(manager)
	return manager


func _anim_player(p: Player) -> AnimationPlayer:
	var found := p.model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func _action_event(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _physics(frames: int = PHYSICS_FRAMES) -> void:
	for i: int in frames:
		await tree.physics_frame


func _events_of(kind: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == kind)


func _on_focus(prompt: String, enabled: bool) -> void:
	events.append(["focus", prompt, enabled])


func _on_notification(text: String, kind: StringName) -> void:
	events.append(["notify", text, kind])


func _on_started(label: String, duration: float) -> void:
	events.append(["started", label, duration])


func _on_progress(ratio: float) -> void:
	events.append(["progress", ratio])


func _on_finished(completed: bool) -> void:
	events.append(["finished", completed])
