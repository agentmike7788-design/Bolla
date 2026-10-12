extends RefCounted
## G8 Runde 4 screenshot set of graveyard_shots.gd (--round4=panels; docs/reviews/phase8_round4/panels.md): the work
## panels the gravekeeper starts a timed work from (user: „Ja" – Präparierpult und Werkbank wie der Leichentisch).
## New game, day 1, real systems. Per panel the station is made usable the way the game would (Workshop state +
## refresh_built for the built stations, the inputs of one recipe in the pack, a grave filled for the stone, an organ
## taken from Osric's first dead for the pult); the panel is opened the way the player opens it (the station's
## interact, the pult's second card through its button), one work is started with its button's pressed signal, and
## the player and his clip are stepped at 60 Hz to 70 % of the work (past the tool draw):
##   <out>/panel_<name>_<tag><suffix>.jpg         – the panel open, before the work
##   <out>/panel_<name>_<tag>_arbeit<suffix>.jpg  – during the work (70 %)
## Names: werkbank (Workbench, crafting), schmiede (Esse, crafting), steinmetz (stone_design), pult (crafting → pult).
## --shots=werkbank,pult picks panels.

const PORTAL := "res://src/world/hut_interior/hut_portal.gd"
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 12
const JPG_QUALITY := 0.9
const DAY := 1
const MINUTE := 620
const NAMES: Array[String] = ["werkbank", "schmiede", "steinmetz", "pult"]
## name -> [node path in the world, distance in front of it along its +Z]
const OUTSIDE := {
	"werkbank": ["Entities/workbench", 0.95],
	"schmiede": ["Entities/station_forge", 1.0],
	"steinmetz": ["Entities/station_mason", 1.0],
}
const BUILT: Array[String] = ["forge", "mason", "pult"]
## The pult: the organ taken (as a bundle) and what sealing it needs.
const ORGAN := &"liver"
const BUNDLE := &"bundle"
const PULT_GIFTS := {&"prep_jar": 1, &"spirits": 2, &"herbs": 2}
const PULT_STAND := 0.9


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String, tag: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	_build_stations(world)
	ui.visible = true
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rig.set(&"target", player)
	var inv: Object = player.get(&"inventory")
	for name: String in NAMES:
		if not only.is_empty() and not name in only:
			continue
		player.call(&"cancel_timed_action")
		player.call(&"reset_tool")
		ui.call(&"close_all")
		clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
		var button: BaseButton = null
		if name == "pult":
			button = await _open_pult(tree, world, player, rig)
		else:
			var spec: Array = OUTSIDE[name]
			var place := world.get_node(NodePath(String(spec[0]))) as Node3D
			player.global_transform = _stand(place, float(spec[1]))
			rig.call(&"snap")
			await _settle(tree)
			if name == "steinmetz":
				_stage_grave(world, inv)
			place.call(&"interact", player)
			await _settle(tree)
			button = _start_button(tree, ui, name, inv)
		await _settle(tree)
		rig.call(&"snap")
		await _settle(tree)
		_save(tree, out.path_join("panel_%s_%s%s.jpg" % [name, tag, suffix]))
		if button == null or button.disabled:
			push_warning("[ShotsPanels] %s: no work to start" % name)
			continue
		print("[ShotsPanels] %s: pressing '%s'" % [name, button.get(&"text")])
		button.pressed.emit()
		var action: Object = player.get(&"_action")
		var duration := float(action.get(&"duration")) if action != null else 0.0
		print("[ShotsPanels] %s: work %.2f s real, clip %s" % [name, duration, anim.current_animation])
		var t := 0.0
		while t < duration * 0.7:
			_advance(player, anim)
			t += STEP
		await _settle(tree)
		var top: Object = ui.call(&"get_panel", ui.call(&"top")) if not (ui.call(&"open_ids") as Array).is_empty() else null
		print("[ShotsPanels] %s: +%.1f s busy=%s panel_visible=%s" % [name, t, player.call(&"is_busy"),
				top.get(&"visible") if top != null else "-"])
		_save(tree, out.path_join("panel_%s_%s_arbeit%s.jpg" % [name, tag, suffix]))
		while bool(player.call(&"is_busy")):
			_advance(player, anim)
		await _settle(tree)
	player.set_physics_process(true)


## forge, mason and pult built (as the build would leave them).
static func _build_stations(world: Node3D) -> void:
	var workshop := world.get_node(^"Systems/Workshop")
	var state: Dictionary = workshop.call(&"save_state")
	var built: Array = state.get("built", [])
	for id: String in BUILT:
		if not id in built:
			built.append(id)
	state["built"] = built
	workshop.call(&"load_state", state)
	for node: Node in world.find_children("*", "", true, false):
		if node.has_method(&"refresh_built"):
			node.call(&"refresh_built")
		elif String(node.name).begins_with("site_") and node.has_method(&"refresh"):
			node.call(&"refresh")


## The work button of the open panel, its inputs put into the pack first.
static func _start_button(tree: SceneTree, ui: Object, name: String, inv: Object) -> BaseButton:
	var panel: Object = ui.call(&"get_panel", ui.call(&"top"))
	var db := tree.root.get_node(^"Database")
	if name == "steinmetz":
		var graves: Array = panel.call(&"graves")
		if graves.is_empty():
			return null
		panel.call(&"select_grave", String((graves[0] as Dictionary).get("grave_id", "")))
		var preview: Dictionary = panel.get(&"current_preview")
		_give(inv, preview.get("inputs", {}))
		panel.call(&"refresh")
		print("[ShotsPanels] steinmetz: grave %s, reason '%s'" % [(graves[0] as Dictionary).get("grave_id", ""), panel.call(&"block_reason")])
		return panel.get(&"carve_button") as BaseButton
	for id: StringName in panel.call(&"recipe_ids"):
		var recipe: Resource = db.call(&"recipe", id)
		if recipe == null or bool(recipe.get(&"background")):
			continue
		var output: Resource = db.call(&"item", recipe.get(&"output_id")) if bool(db.call(&"has_item", recipe.get(&"output_id"))) else null
		if output != null and output.get(&"tool_kind") != &"":
			continue
		_give(inv, recipe.get(&"inputs"))
		panel.call(&"refresh")
		var b := panel.call(&"craft_button", id) as BaseButton
		if b != null and not b.disabled:
			print("[ShotsPanels] %s: recipe %s" % [name, id])
			return b
	return null


## Osric's first dead on the crypt table, an organ taken as a bundle, the pult's crafting card, then its second card.
static func _open_pult(tree: SceneTree, world: Node3D, player: Node3D, rig: Node3D) -> BaseButton:
	var clock := tree.root.get_node(^"TimeManager")
	var manager := world.get_node(^"Systems/CorpseManager")
	var ui := world.get_node(^"UI")
	var inv: Object = player.get(&"inventory")
	clock.call(&"load_state", {"day": DAY, "minute_of_day": 470})
	var record: Object = manager.call(&"try_daily_delivery", DAY)
	if record == null:
		var bier := world.get_node(^"Entities/dropoff")
		record = manager.call(&"spawn_corpse", null, bier.call(&"slot_transform"), &"dropoff")
	var id := String(record.get(&"id"))
	var room: Node3D = null
	for node: Node in tree.get_nodes_in_group(&"building_door"):
		if node.get(&"building_id") == &"crypt":
			room = node.call(&"room") as Node3D
	var table := room.get_node(^"Entities/MorgueTable") as Node3D
	manager.call(&"pick_up", id, player)
	(load(PORTAL) as GDScript).call(&"arrive", player, room.call(&"spawn_transform"), true, &"crypt")
	player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), room.global_transform * Vector3(0.95, 0.0, 0.6))
	table.call(&"interact", player)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	ui.call(&"close_all")
	var specimens := tree.get_first_node_in_group(&"specimens")
	var cfg: Object = specimens.call(&"get_config")
	_give(inv, (load("res://src/systems/anatomy/specimen_rules.gd") as GDScript).call(&"harvest_inputs", ORGAN, BUNDLE, cfg))
	var uid := String(specimens.call(&"harvest", id, ORGAN, BUNDLE, inv))
	print("[ShotsPanels] pult: organ %s -> '%s'" % [ORGAN, uid])
	_give(inv, PULT_GIFTS)
	var station := room.get_node(^"Entities/PultPlace/station_pult") as Node3D
	player.global_transform = _stand(station, PULT_STAND)
	rig.call(&"set_distance", float((room.call(&"room_config") as Object).get(&"camera_distance")))
	rig.call(&"snap")
	await _settle(tree)
	station.call(&"interact", player)
	await _settle(tree)
	var crafting: Object = ui.call(&"get_panel", &"crafting")
	(crafting.get(&"pult_button") as BaseButton).pressed.emit()
	await _settle(tree)
	var pult: Object = ui.call(&"get_panel", &"pult")
	var rows: Dictionary = pult.get(&"action_rows")
	var b := (rows.get(&"seal", {}) as Dictionary).get("button") as BaseButton
	print("[ShotsPanels] pult: seal reason '%s'" % pult.call(&"action_reason", &"seal"))
	return b


## A grave of the first section dug, filled with a dead (the Graveyard API) – the stone bench lists it.
static func _stage_grave(world: Node3D, _inv: Object) -> void:
	var graveyard := world.get_node(^"Systems/Graveyard")
	var manager := world.get_node(^"Systems/CorpseManager")
	for gid: String in ["plot_02", "plot_01", "plot_03"]:
		var grave: Object = graveyard.call(&"get_grave", gid)
		if grave == null:
			continue
		if int(grave.get(&"state")) == 0:
			graveyard.call(&"dig", gid)
		var plot := world.get_node_or_null(NodePath("Entities/" + gid)) as Node3D
		var record: Object = manager.call(&"spawn_corpse", null, plot.global_transform if plot != null else Transform3D.IDENTITY, &"ground")
		record.set(&"examined", true)
		record.set(&"shrouded", true)
		graveyard.call(&"bury", gid, record.get(&"id"))
		print("[ShotsPanels] steinmetz: %s filled (state %d)" % [gid, int(grave.get(&"state"))])
		return
	push_warning("[ShotsPanels] steinmetz: no grave to fill")


static func _give(inv: Object, items: Variant) -> void:
	var d := items as Dictionary
	for id: Variant in d:
		inv.call(&"add_item", StringName(id), int(d[id]))


static func _stand(place: Node3D, distance: float) -> Transform3D:
	var spot := place.global_position + place.global_basis.z.normalized() * distance
	var d := place.global_position - spot
	d.y = 0.0
	spot.y = place.global_position.y
	return Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), spot)


static func _settle(tree: SceneTree) -> void:
	for i: int in SETTLE_FRAMES:
		await tree.process_frame


static func _save(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[ShotsPanels] ", path)


static func _advance(player: Node, anim: AnimationPlayer) -> void:
	player.call(&"_physics_process", STEP)
	anim.advance(STEP)
