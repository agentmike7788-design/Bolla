class_name BuildingSite
extends Node3D
## Entities/site_<id> (docs/PHASE6_DESIGN.md §2.1, §3.4, §4), group &"building_site": visible (with
## collision) from buildings_open; the outdoor model of the current level (0 = BuildingData.model_site,
## else the level's model; none yet → no model, the builder adds a grey box) under the child "Model",
## the Interactable at the model's marker "build". Prompt „[E] Bauplatz: Gruft" (level 0) /
## „[E] Gruft ausbauen (Stufe 2)"; fully built: no prompt. [E] opens the building panel
## (&"building", context {building, data, level, site, inventory, player}); request_upgrade runs the
## TimedAction (minutes, not cancellable) → Buildings.upgrade (items + coins at the end, atomically);
## request_fetch fetches the missing building materials from the shed (shed ≥ 2, ShedSupply).

const GROUP := &"building_site"
const PANEL := &"building"
const PROMPT_SITE := "[E] Bauplatz: %s"
const PROMPT_UPGRADE := "[E] %s ausbauen (Stufe %d)"
const BUILDINGS_GROUP := &"buildings"
const MODEL_NAME := "Model"
const BUILD_MARKER := "build"
const ANIM := &"interact"
const LABEL_BUILD := "%s: Stufe %d bauen"
const TEXT_BUILT := "%s: Stufe %d steht."
const TEXT_FAILED := "Bauen fehlgeschlagen."
const TEXT_BUSY := "Gerade nicht möglich."
## free_area(): this far under the ground counts as buried in it (the stair shaft has its own pit).
const BURIED_DEPTH := 0.35

@export var building_id: StringName
## G8 round 2: where someone stands in front of the building (site-local, layout access). After a
## load the gravekeeper / a corpse lying outside that would be inside the building's walls or under
## the ground (a save from before the crypt moved: on its old stair) is put here instead.
@export var access_point: Vector3 = Vector3.ZERO
@export var has_access_point: bool = false

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Player of the last interaction (the panel builds for them).
var _player: Player
## Level whose model is shown (-1 = none yet).
var _shown_level: int = -1


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.time_tick.connect(_on_time_tick)
	refresh()


## Shown (model + collision): from buildings_open, or before it once the building stands (changed
## 04.10.2026: the crypt is at level 1 from the start, its portal and stair are there from day 1).
func is_active() -> bool:
	var b := buildings()
	return b != null and (b.is_open() or b.level(building_id) >= 1)


## The upgrade prompt / panel: only from buildings_open (Phase 6 §1.2).
func can_build() -> bool:
	var b := buildings()
	return b != null and b.is_open()


## The current level (0 = site).
func level() -> int:
	var b := buildings()
	return b.level(building_id) if b != null else 0


## Model of the level, collision, prompt.
func refresh() -> void:
	var on := is_active()
	if visible != on or (process_mode == Node.PROCESS_MODE_DISABLED) != (not on):
		visible = on
		process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_show_model(level())
		_apply_level_shapes(level())


## G7 round 1: collision shapes with meta min_level / max_level (the crypt stair: the plug over the
## passage until level 1, the stair cheeks from level 1) are only enabled within their levels.
func _apply_level_shapes(lvl: int) -> void:
	var body := get_node_or_null(^"Collision")
	if body == null:
		return
	for node: Node in body.get_children():
		var shape := node as CollisionShape3D
		if shape == null or not (shape.has_meta(&"min_level") or shape.has_meta(&"max_level")):
			continue
		var lo := int(shape.get_meta(&"min_level", 0))
		var hi := int(shape.get_meta(&"max_level", 99))
		shape.disabled = lvl < lo or lvl > hi


func can_interact(player: Player) -> bool:
	return player != null and can_build() and _next() != null and not player.is_busy() and not is_instance_valid(player.carried)


func get_interaction_prompt(player: Player) -> String:
	if not can_build() or _next() == null:
		return ""
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	var lvl := level()
	if lvl <= 0:
		return PROMPT_SITE % _name()
	return PROMPT_UPGRADE % [_name(), lvl + 1]


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	EventBus.ui_panel_requested.emit(PANEL, {"building": building_id, "data": building_data(), "level": level(), "site": self,
			"inventory": player.inventory, "player": player})


## "" or why the next level cannot be built now (Buildings.upgrade_block_reason).
func block_reason(inv: Inventory) -> String:
	var b := buildings()
	return b.upgrade_block_reason(building_id, inv) if b != null else TEXT_BUSY


## Panel &"building": TimedAction minutes (not cancellable) → Buildings.upgrade.
func request_upgrade() -> void:
	var player := _acting_player()
	var next := _next()
	if player == null or next == null or player.is_busy() or is_instance_valid(player.carried) or not can_build():
		_warn(TEXT_BUSY)
		return
	var reason := block_reason(player.inventory)
	if reason != "":
		_warn(reason)
		return
	player.start_timed_action(LABEL_BUILD % [_name(), next.level], next.minutes, _finish_upgrade.bind(player.inventory), false,
			ToolAnimConfig.clip_for(&"building_upgrade", ANIM))


## Shed ≥ 2: fetch the missing building materials (ShedSupply; coins are never fetched).
func request_fetch() -> void:
	var next := _next()
	if next == null:
		_warn(TEXT_BUSY)
		return
	ShedSupply.run_fetch(get_tree() if is_inside_tree() else null, _acting_player(), BuildingRules.cost(next))


## The materials of the next level ({} when fully built) – for the panel's shed lines.
func needs() -> Dictionary:
	return BuildingRules.cost(_next())


func _finish_upgrade(inv: Inventory) -> void:
	var b := buildings()
	if b == null or not b.upgrade(building_id, inv):
		_warn(TEXT_FAILED)
		return
	EventBus.notification_requested.emit(TEXT_BUILT % [_name(), b.level(building_id)], &"reward")
	refresh()


## Systems/Buildings (group buildings) or null.
func buildings() -> Buildings:
	return get_tree().get_first_node_in_group(BUILDINGS_GROUP) as Buildings if is_inside_tree() else null


## BuildingData of building_id (Buildings' table / Database) or null.
func building_data() -> BuildingData:
	var b := buildings()
	if b != null:
		return b.building(building_id)
	return Database.building(building_id) as BuildingData


func _next() -> BuildingLevelData:
	return BuildingRules.next_level(building_data(), level())


func _name() -> String:
	var data := building_data()
	return data.display_name if data != null and data.display_name != "" else String(building_id)


## Swaps the child "Model" for the model of `lvl` (nothing when that level has none yet) and moves
## the Interactable to its marker "build".
func _show_model(lvl: int) -> void:
	if lvl == _shown_level:
		return
	_shown_level = lvl
	var old := get_node_or_null(NodePath(MODEL_NAME))
	if old != null:
		remove_child(old)
		old.queue_free()
	var data := building_data()
	var scene: PackedScene = null
	if data != null:
		if lvl <= 0:
			scene = data.model_site
		elif data.level_data(lvl) != null:
			scene = data.level_data(lvl).model
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.name = MODEL_NAME
	add_child(model)
	var marker := model.find_child(BUILD_MARKER, true, false) as Node3D
	if marker != null and interactable != null:
		var local := Transform3D.IDENTITY
		var node: Node = marker
		while node != null and node != self:
			if node is Node3D:
				local = (node as Node3D).transform * local
			node = node.get_parent()
		interactable.transform = Transform3D(Basis.IDENTITY, local.origin)


func _acting_player() -> Player:
	if is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func _on_building_upgraded(id: StringName, _level: int) -> void:
	if id == building_id:
		refresh()


func _on_game_loaded(_slot: int) -> void:
	refresh()
	free_area()


## G8 round 2: after a load, the gravekeeper (outside, on the graveyard) and every corpse lying on the
## ground outside that stand inside a solid shape of this site or more than BURIED_DEPTH under the
## ground (outside the stair shaft) go to the access point – a save from before the crypt moved
## (rotated portal in the south-west corner) may have them on the old stair. Returns how many moved.
func free_area() -> int:
	if not has_access_point or not is_active() or not is_inside_tree():
		return 0
	var moved := 0
	var spot := _access_transform()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null and not bool(player.get(&"in_interior")) and StringName(str(player.get(&"region_id"))) in [&"", &"graveyard"] \
			and stuck_at(player.global_position):
		push_warning("[BuildingSite] %s: the gravekeeper stood in the building / under the ground – moved to its access" % building_id)
		player.global_position = spot.origin
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		moved += 1
	var manager := get_tree().get_first_node_in_group(&"corpse_manager")
	if manager != null and manager.has_method(&"records") and manager.has_method(&"relocate_ground_corpse"):
		var k := 0
		for record: Variant in manager.call(&"records"):
			if StringName(str(record.get(&"location"))) != &"ground" or StringName(str(record.get(&"room"))) != &"":
				continue
			var pos: Vector3 = record.get(&"position")
			if stuck_at(pos):
				k += 1
				# out on the forecourt in front of the stair head, one behind the other
				var xf := Transform3D(spot.basis, spot.origin + spot.basis.z * (0.5 + 0.8 * k))
				var world := get_tree().get_first_node_in_group(&"world")
				if world != null and world.has_method(&"ground_height"):
					xf.origin.y = float(world.call(&"ground_height", Vector2(xf.origin.x, xf.origin.z)))
				manager.call(&"relocate_ground_corpse", String(record.get(&"id")), xf)
				moved += 1
	return moved


## Inside one of the site's solid collision boxes (not the walkable stair parts) or more than
## BURIED_DEPTH under the ground outside the stair shaft.
func stuck_at(p: Vector3) -> bool:
	var body := get_node_or_null(^"Collision")
	if body != null:
		for node: Node in body.get_children():
			var shape := node as CollisionShape3D
			if shape == null or shape.disabled or not shape.shape is BoxShape3D or String(shape.name).begins_with("Stair"):
				continue
			var local := shape.global_transform.affine_inverse() * (p + Vector3(0.0, 0.5, 0.0))
			var half := (shape.shape as BoxShape3D).size * 0.5 + Vector3(0.25, 0.4, 0.25)
			if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
				return true
	var world := get_tree().get_first_node_in_group(&"world")
	if world != null and world.has_method(&"ground_height"):
		var g := float(world.call(&"ground_height", Vector2(p.x, p.z)))
		if p.y < g - BURIED_DEPTH:
			return true
	return false


## The access point on the ground, facing away from the building.
func _access_transform() -> Transform3D:
	var at := to_global(access_point)
	var world := get_tree().get_first_node_in_group(&"world")
	if world != null and world.has_method(&"ground_height"):
		at.y = float(world.call(&"ground_height", Vector2(at.x, at.z)))
	return Transform3D(global_basis.orthonormalized(), at)


func _on_time_tick(_day: int, _minute: int) -> void:
	refresh()


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")
