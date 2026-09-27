extends TestCase
## Change round 2 (docs §11) building blocks: InteriorConfig daylight keyframes, the CameraRig
## place profile, the portal fade overlay, HutPortal without fade, Chest save / load and the
## Desk / InteriorDoor edge cases – without the world.

const CHEST_SCENE := "res://src/entities/chest/chest.tscn"
const DESK_SCENE := "res://src/entities/desk/desk.tscn"
const INTERIOR_DOOR_SCENE := "res://src/entities/interior_door/interior_door.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const CONFIG := "res://data/config/interior_config.tres"


func test_config_values_match_the_brief() -> void:
	var cfg := load(CONFIG) as InteriorConfig
	assert_eq(InteriorConfig.resolve(), Database.config(&"interior_config"), "resolved from the Database")
	assert_true(cfg.window_night_color.is_equal_approx(Color("#8fa2d0")))
	assert_almost(cfg.window_night_energy, 0.35)
	assert_true(cfg.window_day_color.is_equal_approx(Color("#ffe2b0")))
	assert_almost(cfg.window_day_energy, 1.3)
	assert_true(cfg.lantern_color.is_equal_approx(Color("#ffae55")))
	assert_almost(cfg.lantern_night_energy, 1.1)
	assert_almost(cfg.lantern_day_energy, 0.3)
	assert_true(cfg.candle_color.is_equal_approx(Color("#ffa040")))
	assert_almost(cfg.candle_night_energy, 0.5)
	assert_almost(cfg.candle_day_energy, 0.0)
	assert_true(cfg.stove_color.is_equal_approx(Color("#ff8a3c")))
	assert_almost(cfg.stove_range, 6.0)
	assert_almost(cfg.stove_night_energy, 3.0)
	assert_almost(cfg.stove_day_energy, 1.6)
	assert_almost(cfg.sun_day_energy, 0.9)
	assert_almost(cfg.camera_distance, 9.0)
	assert_eq(cfg.chest_slots, 16)
	assert_true(cfg.fade_seconds > 0.0 and cfg.fade_seconds <= 1.0, "short fade")


func test_daylight_keyframes() -> void:
	var cfg := InteriorConfig.new()
	assert_almost(cfg.daylight(0.0), 0.0)
	assert_almost(cfg.daylight(240.0), 0.0, 0.0001, "night held until 04:00")
	assert_almost(cfg.daylight(330.0), 0.45)
	assert_almost(cfg.daylight(405.0), 0.725, 0.0001, "halfway dawn → day")
	assert_almost(cfg.daylight(720.0), 1.0)
	assert_almost(cfg.daylight(1140.0), 0.45)
	assert_almost(cfg.daylight(1380.0), 0.0)
	assert_almost(cfg.daylight(1440.0 + 720.0), 1.0, 0.0001, "wraps")


func test_camera_profile_set_and_clear() -> void:
	var rig := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	var target := Node3D.new()
	tree.root.add_child(target)
	rig.target = target
	rig.distance = 22.0
	rig.zoom_min = 12.0
	rig.zoom_max = 24.0
	rig.bounds_enabled = true
	rig.bounds_min = Vector2(-7, -8)
	rig.bounds_max = Vector2(7, 23)
	tree.root.add_child(rig)
	var env := Environment.new()
	var p := CameraProfile.new()
	p.distance = 9.0
	p.zoom_min = 7.0
	p.zoom_max = 11.0
	p.bounds_enabled = true
	p.bounds_min = Vector2(-0.5, -200.3)
	p.bounds_max = Vector2(0.5, -199.7)
	p.environment = env
	rig.set_profile(p)
	assert_eq(rig.profile, p)
	assert_almost(rig.distance, 9.0)
	assert_eq([rig.zoom_min, rig.zoom_max], [7.0, 11.0])
	assert_eq(rig.camera.environment, env)
	target.global_position = Vector3(3.0, 0.0, -150.0)
	rig.snap()
	var focus := rig.camera.global_position - Vector3.BACK.rotated(Vector3.RIGHT, -deg_to_rad(rig.pitch_deg)) * rig.distance - rig.look_offset
	assert_almost(focus.x, 0.5, 0.001, "clamped x")
	assert_almost(focus.z, -199.7, 0.001, "clamped z")
	rig.set_distance(30.0)
	assert_almost(rig.distance, 11.0, 0.001, "interior zoom range")
	rig.clear_profile()
	assert_null(rig.profile)
	assert_almost(rig.distance, 22.0, 0.001, "outdoor distance back")
	assert_eq([rig.zoom_min, rig.zoom_max], [12.0, 24.0])
	assert_eq(rig.bounds_max, Vector2(7, 23))
	assert_null(rig.camera.environment)
	rig.clear_profile()
	assert_almost(rig.distance, 22.0, 0.001, "clear twice is a no-op")
	rig.free()
	target.free()


func test_screen_fade_out_and_in() -> void:
	var fade := ScreenFade.new()
	tree.root.add_child(fade)
	assert_eq(fade.opacity(), 0.0)
	assert_eq(fade.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	EventBus.screen_fade_requested.emit(0.4)
	assert_true(fade.visible)
	await tree.create_timer(0.2).timeout
	assert_true(fade.opacity() > 0.8, "black around the midpoint (%.2f)" % fade.opacity())
	await tree.create_timer(0.35).timeout
	assert_false(fade.visible, "gone afterwards")
	fade.free()


func test_portal_without_fade_moves_at_once() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	tree.root.add_child(player)
	var events: Array = []
	var on_changed := func(inside: bool) -> void: events.append(inside)
	EventBus.interior_changed.connect(on_changed)
	var dest := Transform3D(Basis(Vector3.UP, PI), Vector3(-0.9, 0.0, -199.0))
	assert_true(HutPortal.travel(player, dest, true, 0.0))
	EventBus.interior_changed.disconnect(on_changed)
	assert_eq(events, [true])
	assert_true(player.in_interior)
	assert_true(player.global_position.is_equal_approx(dest.origin))
	assert_almost(absf(player.rotation.y), PI, 0.001, "faces into the room")
	assert_false(HutPortal.travel(null, dest, true, 0.0))
	var saved := player.save_state()
	assert_eq(saved.in_interior, true)
	player.load_state({"position": Vector3.ZERO})
	assert_false(player.in_interior, "missing = outside (older saves)")
	player.load_state(JSON.to_native(JSON.from_native(saved)))
	assert_true(player.in_interior, "JSON round trip")
	player.free()


func test_chest_save_load_standalone() -> void:
	var chest := (load(CHEST_SCENE) as PackedScene).instantiate() as Chest
	tree.root.add_child(chest)
	assert_eq(chest.storage.slot_count, 16)
	chest.storage.add_item(&"wood", 12)
	var saved := chest.save_state()
	var other := (load(CHEST_SCENE) as PackedScene).instantiate() as Chest
	tree.root.add_child(other)
	other.load_state(JSON.to_native(JSON.from_native(saved)))
	assert_eq(other.storage.count(&"wood"), 12)
	assert_eq(other.save_state(), saved)
	other.load_state({})
	assert_eq(other.storage.count(&"wood"), 0, "load replaces")
	chest.free()
	other.free()


func test_desk_and_door_without_a_world() -> void:
	assert_eq(Desk.register_entries(null, null), [])
	var desk := (load(DESK_SCENE) as PackedScene).instantiate() as Desk
	tree.root.add_child(desk)
	var ctx := desk.register_context()
	assert_eq(ctx.entries, [])
	assert_eq(ctx.total, 0)
	desk.free()
	var door := (load(INTERIOR_DOOR_SCENE) as PackedScene).instantiate() as InteriorDoor
	tree.root.add_child(door)
	assert_eq(door.get_interaction_prompt(null), "", "no outside door: nothing offered")
	assert_false(door.can_interact(null))
	door.free()
