extends RefCounted
## P2 test harness (not a test file): a small graveyard world for test_visitors / test_wishes / test_grave_view
## – a real Graveyard, GraveCare and Visitors, doubles for the corpses (records only), the care spots, the
## reputation, the relationships, NpcLife, the decorations and Specimens (read through their groups).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class CorpsesDouble extends CorpseManager:
	var recs: Dictionary = {}

	func _ready() -> void:
		pass

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord

	func records() -> Array[CorpseRecord]:
		var out: Array[CorpseRecord] = []
		for r: Variant in recs.values():
			out.append(r as CorpseRecord)
		return out


class CleanDouble extends Node:
	var levels: Dictionary = {}

	func _init() -> void:
		add_to_group(&"cleanliness")

	func level(spot_id: String) -> int:
		return int(levels.get(spot_id, 0))

	func set_level(spot_id: String, lvl: int) -> void:
		levels[spot_id] = lvl


class RepDouble extends Node:
	var events: Array = []

	func _init() -> void:
		add_to_group(&"reputation")

	func event(kind: StringName, _reason: String) -> void:
		events.append(kind)

	func count(kind: StringName) -> int:
		return events.count(kind)


class RelDouble extends Node:
	var adds: Array = []

	func _init() -> void:
		add_to_group(&"relationships")

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		adds.append([npc_id, delta])
		return delta


class LifeDouble extends Node:
	var events: Array = []
	var goal_checks: int = 0

	func _init() -> void:
		add_to_group(&"npc_life")

	func note_event(event: StringName, npcs: Array[StringName] = []) -> void:
		events.append([event, npcs])

	func check_goal() -> bool:
		goal_checks += 1
		return false


class ShieldDouble extends Node:
	var shields: int = 0

	func _init() -> void:
		add_to_group(&"friendship")

	func consume_shield(_event: StringName) -> bool:
		if shields > 0:
			shields -= 1
			return true
		return false


class Placement extends RefCounted:
	var decor_id: StringName = &""
	var at: Vector2 = Vector2.ZERO


class DecorDouble extends Node:
	var list: Array = []

	func _init() -> void:
		add_to_group(&"decorations")

	func placements() -> Array:
		return list

	func centre_of(p: Variant) -> Vector2:
		return (p as Placement).at


class PlotDouble extends Node3D:
	var grave_id: String = ""

	func _init() -> void:
		add_to_group(&"grave_plot")


var tree: SceneTree
var root: Node3D
var graveyard: Graveyard
var corpses: CorpsesDouble
var care: GraveCare
var clean: CleanDouble
var rep: RepDouble
var rel: RelDouble
var life: LifeDouble
var decor: DecorDouble
var visitors: Visitors
var inv: Inventory
var _counter: int = 0


## Opens Phase 8 on `open_day` and builds the world (plots: plot_01…, l_01…, old_01, old_08 3 m apart).
func setup(t: SceneTree, open_day: int = 53, plots: PackedStringArray = []) -> void:
	tree = t
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", open_day)
	root = Node3D.new()
	root.name = "VisitWorld"
	var ids := plots if not plots.is_empty() else PackedStringArray(["l_01", "l_02", "l_03", "l_04", "l_05", "l_09", "l_10",
			"old_01", "old_08"])
	for i: int in ids.size():
		var plot := PlotDouble.new()
		plot.grave_id = ids[i]
		plot.name = ids[i]
		plot.position = Vector3(i * 3.0, 0.0, 0.0)
		root.add_child(plot)
	corpses = CorpsesDouble.new()
	root.add_child(corpses)
	graveyard = Graveyard.new()
	root.add_child(graveyard)
	clean = CleanDouble.new()
	root.add_child(clean)
	rep = RepDouble.new()
	root.add_child(rep)
	rel = RelDouble.new()
	root.add_child(rel)
	life = LifeDouble.new()
	root.add_child(life)
	decor = DecorDouble.new()
	root.add_child(decor)
	care = GraveCare.new()
	care.config = Phase8Fixtures.grave_care_config()
	root.add_child(care)
	visitors = Visitors.new()
	visitors.config = Phase8Fixtures.visitor_config()
	visitors.kin_data = Phase8Fixtures.kin_list()
	for id: StringName in Phase8Fixtures.VILLAGER_IDS:
		visitors.villager_data[id] = Phase8Fixtures.villager_data(id)
	root.add_child(visitors)
	tree.root.add_child(root)
	for id: String in ids:
		var g := graveyard.get_grave(id)
		if id.begins_with("old_"):
			g.state = GraveRecord.State.OLD
	inv = FakeInventory.new()


## Only the four households visit (no Esch / Theres / Liesel).
func households_only() -> void:
	var list: Array[KinData] = []
	for id: StringName in Phase8Fixtures.HOUSEHOLD_KIN:
		list.append(Phase8Fixtures.kin(id))
	visitors.kin_data = list


## Everyone visits (households and villagers).
func all_kin() -> void:
	visitors.kin_data = Phase8Fixtures.kin_list()


func teardown() -> void:
	if is_instance_valid(root):
		root.queue_free()


## A dead of house `house` (kin_house) buried in `plot` on `day`, MARKED with a cross (quality `quality`).
func bury(plot: String, house: StringName, day: int, quality: int = 9, story: StringName = &"") -> CorpseRecord:
	_counter += 1
	var r := CorpseRecord.new()
	r.id = "c_%s_%d" % [plot, _counter]
	r.display_name = "Hedwig Lamprecht"
	r.kin_house = house
	r.story_id = story
	r.location = CorpseRecord.LOCATION_BURIED
	r.grave_id = plot
	r.buried_day = day
	r.seed = 1000 + _counter
	corpses.recs[r.id] = r
	var g := graveyard.get_grave(plot)
	g.state = GraveRecord.State.MARKED
	g.corpse_id = r.id
	g.marker_id = &"wooden_cross"
	g.quality = quality
	g.completed_day = day
	return r


## A designed stone with `lines` carved lines on `plot`.
func design_stone(plot: String, lines: int) -> void:
	var text: Array = []
	for i: int in lines:
		text.append("Zeile %d" % (i + 1))
	graveyard.get_grave(plot).design = {"shape": "stone_round", "inscription": "", "ornament": "", "gilded": false, "text": text}


## A grave vase centred at the plot's position + `offset` (XZ).
func vase(plot: String, offset: Vector2) -> void:
	var p := Placement.new()
	p.decor_id = &"decor_grave_vase"
	var node := root.get_node(plot) as Node3D
	p.at = Vector2(node.position.x, node.position.z) + offset
	decor.list.append(p)


## Plans `day` at 06:00 (the clock set there) and returns the plan.
func plan(day: int) -> Array[Dictionary]:
	TimeManager.load_state({"day": day, "minute_of_day": 360})
	return visitors.plan_day(day)


## Advances the clock to `minute` of the current day (time_tick drives the visits).
func clock(minute: int) -> void:
	var target := (TimeManager.day - 1) * 1440 + minute
	if target > TimeManager.total_minutes():
		TimeManager.advance(target - TimeManager.total_minutes())


## Advances minute by minute up to `minute` (every phase change is announced).
func walk_clock(minute: int) -> void:
	while TimeManager.minute_of_day < minute:
		TimeManager.advance(1)


func visit_id(kin: StringName) -> String:
	return str(visitors.visit_of(kin).get("visit_id", ""))
