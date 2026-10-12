extends TestCase
## G8 Runde 4 (user: „ja die sollen eigene arbeitsbewegungen bekommen"): the real Npc with the real data schedules and
## the real models at their work places (a small stand-in world gives the waypoints and the layout facings): at the
## work minute the figure plays its own work clip with its props, faces the counter / altar / desk / stones
## (layout facing or NpcWorkConfig.work_facing); the gravekeeper stepping close pauses the work (idle, the figure
## turns to him, the props are put away), talking to it plays talk until the dialogue ends; once he walks off the
## work goes on. Osric's evening pipe puffs smoke at the marker pipe_smoke.

const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const MODELS := "res://assets/models/characters/%s.glb"
const DAY := 3
const FAR := Vector3(0.0, 0.0, 9.0)
const NEAR := Vector3(0.4, 0.0, 1.5)
## npc_id, model, region, minute, waypoint, its layout facing (deg), clip, working heading (deg), a prop shown with it
const CASES := [
	[&"innkeeper", "ph_chr_v_innkeeper", &"village", 630, &"v_in_inn_bar", 0.0, &"polish_mug", 0.0, "prop_mug"],
	[&"priest", "ph_chr_v_priest", &"village", 990, &"v_in_church_altar", 0.0, &"pray_altar", 180.0, ""],
	[&"priest", "ph_chr_v_priest", &"village", 520, &"v_church_door", 0.0, &"read_breviary", 0.0, ""],
	[&"mayor", "ph_chr_v_mayor", &"village", 600, &"v_in_office_desk", 0.0, &"desk_files", 0.0, "prop_stamp"],
	[&"mayor", "ph_chr_v_mayor", &"village", 760, &"v_board", 0.0, &"proclaim", 0.0, "prop_notice"],
	[&"surgeon", "ph_chr_v_surgeon", &"village", 570, &"v_in_surgery_desk", 90.0, &"desk_write", 90.0, "prop_quill"],
	[&"surgeon", "ph_chr_v_surgeon", &"village", 900, &"v_in_surgery_desk", 90.0, &"mix_vial", 90.0, "prop_vial"],
	[&"washer", "ph_chr_v_washer", &"village", 480, &"v_wash", 120.0, &"wash_brook", -90.0, "prop_washcloth"],
	[&"carter", "ph_chr_carter", &"graveyard", 1115, &"evening_spot", 15.0, &"smoke", 15.0, ""],
]


## Every waypoint at the origin; the facing of the work place as the layout has it.
class WorkWorld extends Node3D:
	var facing: Dictionary = {}

	func get_waypoint(_id: StringName) -> Vector3:
		return Vector3.ZERO

	func get_waypoint_facing(id: StringName) -> float:
		return deg_to_rad(float(facing[id])) if facing.has(id) else NAN


var world: WorkWorld
var player: Player
var dialogues: Array = []


func before_each() -> void:
	dialogues.clear()
	EventBus.dialogue_requested.connect(_on_dialogue)


func after_each() -> void:
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	if is_instance_valid(world):
		world.free()


func test_villagers_work_face_their_work_and_pause_for_the_gravekeeper() -> void:
	for c: Array in CASES:
		await _case(c)


func test_osric_puffs_smoke_from_the_pipe() -> void:
	var npc := await _setup(CASES[CASES.size() - 1])
	assert_eq(npc.current_animation(), &"smoke")
	var anim := npc.animation_player()
	var marks := npc._work_config().puffs(&"smoke")
	# step the cycle over the first puff moment
	anim.seek(anim.current_animation_length * (marks[0] - 0.05), true)
	npc.refresh()
	anim.seek(anim.current_animation_length * (marks[0] + 0.02), true)
	npc.refresh()
	var smoke := npc.get_node_or_null("PipeSmoke") as CPUParticles3D
	assert_not_null(smoke, "a puff left the pipe")
	if smoke != null:
		var marker := npc.find_child("pipe_smoke", true, false) as Node3D
		assert_not_null(marker, "the marker pipe_smoke")
		if marker != null:
			assert_true(smoke.global_position.distance_to(marker.global_position) < 0.01, "at the pipe bowl")
			assert_true(marker.global_position.y > 1.2 and marker.global_position.y < 1.55, "at his mouth (%.2f)" % marker.global_position.y)
		assert_true(smoke.emitting and smoke.one_shot and smoke.gravity.y > 0.0, "a one-shot puff drifting up")
	world.free()


func _case(c: Array) -> void:
	var npc := await _setup(c)
	var where := "%s %02d:%02d at %s" % [c[0], int(c[3]) / 60, int(c[3]) % 60, c[4]]
	assert_eq(npc.current_animation(), c[6], where + ": the work clip")
	assert_eq(npc.animation_player().current_animation, String(c[6]), where + ": playing")
	assert_true(npc.is_working() and not npc.is_attending(), where + ": working, the gravekeeper away")
	assert_true(absf(angle_difference(npc.rotation.y, deg_to_rad(float(c[7])))) < 0.02,
			where + ": faces its work (%.0f° wanted %.0f°)" % [rad_to_deg(npc.rotation.y), c[7]])
	var model := npc.get_node("Model") as Node3D
	assert_true(absf(model.rotation.y) < 0.001, where + ": the figure itself not turned")
	if String(c[8]) != "":
		assert_true(npc.prop_shown(String(c[8])), where + ": %s in the hand" % c[8])
	# the gravekeeper steps up: the work pauses, the figure turns to him
	player.global_position = npc.global_position + NEAR
	npc.refresh()
	assert_true(npc.is_attending(), where + ": attending the gravekeeper")
	assert_eq(npc.current_animation(), &"idle", where + ": the work pauses")
	var to := NEAR
	var want := wrapf(atan2(to.x, to.z) - npc.rotation.y, -PI, PI)
	assert_true(absf(angle_difference(model.rotation.y, want)) < 0.02, where + ": turned to him")
	if String(c[8]) != "":
		assert_false(npc.prop_shown(String(c[8])), where + ": %s put away" % c[8])
	# talking: talk until the dialogue ends
	assert_true(npc.can_interact(player), where + ": talkable")
	npc.interact(player)
	assert_eq(dialogues.size(), 1, where + ": the dialogue was asked for")
	assert_eq(npc.current_animation(), &"talk", where + ": talks")
	EventBus.dialogue_ended.emit(dialogues[0] if not dialogues.is_empty() else &"")
	assert_eq(npc.current_animation(), &"idle", where + ": the dialogue over, he still stands close")
	# he walks off: back to work, facing it again
	player.global_position = npc.global_position + FAR
	npc.refresh()
	assert_eq(npc.current_animation(), c[6], where + ": back to work")
	assert_false(npc.is_attending(), where + ": not attending")
	assert_true(absf(model.rotation.y) < 0.001, where + ": facing the work again")
	dialogues.clear()
	world.free()


func _setup(c: Array) -> Npc:
	if is_instance_valid(world):
		world.free()
	world = WorkWorld.new()
	world.name = "WorkWorld"
	world.facing = {c[4]: float(c[5])}
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.region_id = c[2]
	player.position = FAR
	world.add_child(player)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.npc_id = c[0]
	npc.region_id = c[2]
	npc.model = load(MODELS % c[1])
	world.add_child(npc)
	tree.root.add_child(world)
	TimeManager.set_time(DAY, int(c[3]))
	await tree.process_frame
	npc.refresh()
	return npc


func _on_dialogue(id: StringName, _speaker: Node) -> void:
	dialogues.append(id)
