extends TestCase
## G8 Runde 1 on the real world (the v6 fixture slot_p7_day53_neighbor through SaveManager): the gate bell stands on
## the east gate post with its swinging child mesh and rings with the HUD note when a visitor comes up (B8-1); a
## waiting household really stays at the grave (its walk is set again when the wait begins – before, the figure walked
## off right after the look while Visitors still counted her as waiting) and goes a few minutes after the talk.

const SLOT := 94
const FIXTURE := "slot_p7_day53_neighbor"

var saves_dir := TestCase.user_dir("test_saves_g8r1")
var world: WorldRoot
var notes: Array[String] = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _load() -> void:
	assert_eq(Phase8Fixtures.install_save_v6(FIXTURE, saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK, FIXTURE + " loads")
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", TimeManager.day)


func test_gate_bell_on_the_east_post_rings_for_a_visitor() -> void:
	await _load()
	var bell := world.get_node_or_null(^"Entities/gate_bell") as GateBell
	assert_not_null(bell, "Entities/gate_bell (layout phase8.gate_bell)")
	if bell == null:
		return
	var post := Vector2(2.6, 9.6)
	assert_true(Vector2(bell.global_position.x, bell.global_position.z).distance_to(post) <= 0.3, "at the east gate post")
	var swing := bell.bell_node()
	assert_not_null(swing, "the swinging bell mesh")
	world.get_player().set_region(&"graveyard")
	var before := bell.rings
	EventBus.visitor_changed.emit("v_test", &"kin_kehr", "l_04", &"arriving")
	assert_eq(bell.rings, before + 1)
	assert_has(notes, "Am Tor läutet es – Martha Kehr kommt herauf.")
	EventBus.visitor_changed.emit("v_test", &"kin_kehr", "l_04", &"mourning")
	assert_eq(bell.rings, before + 1, "only when she comes up")


func test_a_waiting_household_stays_at_the_grave_and_goes_after_the_talk() -> void:
	await _load()
	var visitors := world.get_node("Systems/Visitors") as Visitors
	TimeManager.set_time(TimeManager.day, 570)
	var r: Dictionary = (tree.root.get_node(^"Debug")).call(&"execute", "visit kehr")
	assert_true(bool(r.get("ok", false)), "debug visit (%s)" % str(r.get("text", "")))
	await tree.process_frame
	var id := str(visitors.visit_of(&"kin_kehr").get("visit_id", ""))
	var kehr := world.find_child("npc_kin_kehr", true, false) as Npc
	for i: int in 200:
		if visitors.visit_state(id).get("phase", &"") == &"waiting":
			break
		TimeManager.advance(1)
	assert_eq(visitors.visit_state(id).get("phase", &""), &"waiting")
	for i: int in 45:
		TimeManager.advance(1)
	await tree.process_frame
	assert_eq(visitors.visit_state(id).get("phase", &""), &"waiting", "45 minutes later she still waits (G8: up to 100)")
	assert_true(kehr.is_present(), "and her figure is still at the grave")
	var gv := world.get_node_or_null("Waypoints/gv_" + str(visitors.visit_state(id).grave_id)) as Node3D
	if gv != null:
		assert_true(Vector2(kehr.global_position.x - gv.global_position.x, kehr.global_position.z - gv.global_position.z).length() < 1.5,
				"at her place gv_%s" % visitors.visit_state(id).grave_id)
	assert_true(visitors.note_talked(id), "the talk is over")
	for i: int in 4:
		TimeManager.advance(1)
	assert_eq(visitors.visit_state(id).get("phase", &""), &"leaving", "she goes 3 minutes after the talk")
