extends RefCounted
## G8 Runde 6 screenshot set of graveyard_shots.gd (--round6; docs/reviews/phase8_round6/bitten.md): „Bitten vom Hügel".
## New game, the clock set silently to day 2 (no corpse waiting – the HUD shows the request lines), Osric's two
## requests pinned (HillRequests.pin: „Unkraut am Tor" and „Drei Scheite für Osric", so the set is the same every run),
## the real systems and the real UI:
##   <out>/tafel<suffix>.jpg     – the notice board at the gate with its two slips and the prompt „[E] Bitten am Tor lesen"
##   <out>/panel<suffix>.jpg     – the docked panel with the open requests (NoticeBoard.interact, the focus on „Annehmen")
##   <out>/annahme<suffix>.jpg   – after „Annehmen" (the button's pressed signal) the HUD goal „Bitte: …" with the note
##   <out>/merkbuch<suffix>.jpg  – the Merkbuch tab „Bitten"
##   <out>/erfuellt<suffix>.jpg  – the weeds at the gate tended: the reward note („Bitte erfüllt: … – 2 Münzen · Ruf +1")
## --shots=tafel,panel,annahme,merkbuch,erfuellt picks shots (the earlier steps run anyway); --suffix (_web …).

const Panels := preload("res://src/world/graveyard/graveyard_shots_panels.gd")
const DAY := 2
const MINUTE := 610
const FIRST := &"hr_kehr_gate"
const SECOND := &"hr_osric_wood"
## In front of the board (board-local +Z = its face) and the camera for the board shot.
const READ_DISTANCE := 1.1
## The gravekeeper a step to the side, so the board stays in view.
const READ_SIDE := 1.0
## The board shot comes closer than the player's zoom (CameraRig.zoom_min 10) – a close-up of the slips; the other shots
## use the game's nearest zoom.
const BOARD_CAMERA := 6.0
const PLAY_CAMERA := 10.0


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var hill := world.get_node(^"Systems/HillRequests")
	var clean := world.get_node(^"Systems/Cleanliness")
	var board := world.get_node(^"Entities/notice_board") as Node3D
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	_bury_waiting(world, player)
	await Panels._settle(tree)
	(ui.get(&"reward_card") as Control).call(&"_hide_card")
	clean.call(&"set_level", "dirt_y01", 2)
	clean.call(&"set_level", "dirt_y02", 1)
	hill.call(&"pin", FIRST)
	hill.call(&"pin", SECOND)
	ui.visible = true
	player.set_physics_process(true)
	var stand := Panels._stand(board, READ_DISTANCE)
	stand.origin += board.global_basis.x.normalized() * READ_SIDE
	player.global_transform = stand
	# the board shot frames the board (an anchor in front of it), the gravekeeper beside it
	var anchor := Node3D.new()
	anchor.name = "ShotAnchorR6"
	world.add_child(anchor)
	anchor.global_position = board.global_position + board.global_basis.z.normalized() * 0.4
	rig.set(&"target", anchor)
	var zoom_min := float(rig.get(&"zoom_min"))
	rig.set(&"zoom_min", BOARD_CAMERA)
	rig.call(&"set_distance", BOARD_CAMERA)
	rig.call(&"snap")
	await Panels._settle(tree)
	player.set_physics_process(false)
	await Panels._settle(tree)
	var hud: Object = ui.get(&"hud")
	print("[ShotsR6] slips %d, prompt „%s“" % [int(board.call(&"slip_count")), str(hud.get(&"prompt_label").get(&"text")) if hud.get(&"prompt_label") != null else "?"])
	_shot(tree, out, "tafel", suffix, only)
	rig.set(&"target", player)
	rig.call(&"snap")
	board.call(&"interact", player)
	await Panels._settle(tree)
	var panel: Object = ui.call(&"get_panel", &"hill_requests")
	_report(ui, "panel")
	_shot(tree, out, "panel", suffix, only)
	var button := panel.call(&"accept_button", FIRST) as Button
	if button != null:
		button.pressed.emit()
	await Panels._settle(tree)
	ui.call(&"close_all")
	rig.set(&"zoom_min", zoom_min)
	rig.call(&"set_distance", PLAY_CAMERA)
	rig.call(&"snap")
	(hud as Object).call(&"refresh_objective")
	await Panels._settle(tree)
	print("[ShotsR6] objective „%s“" % str(hud.get(&"objective_label").get(&"text")))
	_shot(tree, out, "annahme", suffix, only)
	ui.call(&"open_panel", &"journal", {"page": "requests"})
	await Panels._settle(tree)
	_shot(tree, out, "merkbuch", suffix, only)
	ui.call(&"close_all")
	await Panels._settle(tree)
	# the weeds at the gate tended (the clean-up work's result: CleanlinessManager.tend), the reward note
	var inv: Object = player.get(&"inventory")
	for spot: String in ["dirt_y01", "dirt_y02"]:
		clean.call(&"tend", spot, inv)
	(hud as Object).call(&"refresh_objective")
	await Panels._settle(tree)
	print("[ShotsR6] after tending: board %s, objective „%s“" % [str(hill.call(&"board")), str(hud.get(&"objective_label").get(&"text"))])
	_shot(tree, out, "erfuellt", suffix, only)


## Day 1's dead (and any other waiting one) buried under a cross through the Graveyard API – the HUD then has no corpse
## step and shows the request lines.
static func _bury_waiting(world: Node3D, player: Node3D) -> void:
	var manager := world.get_node(^"Systems/CorpseManager")
	var graveyard := world.get_node(^"Systems/Graveyard")
	var inv: Object = player.get(&"inventory")
	for record: Object in manager.call(&"records"):
		if record.get(&"location") == &"buried":
			continue
		record.set(&"examined", true)
		record.set(&"shrouded", true)
		if bool(record.call(&"needs_valuables_decision")):
			record.set(&"valuables_decision", &"left")
		for g: Object in graveyard.call(&"graves"):
			if int(g.get(&"state")) == 0:
				var gid := String(g.get(&"id"))
				graveyard.call(&"dig", gid)
				graveyard.call(&"bury", gid, String(record.get(&"id")))
				inv.call(&"add_item", &"wooden_cross", 1)
				graveyard.call(&"place_marker", gid, &"wooden_cross", inv)
				break


static func _shot(tree: SceneTree, out: String, name: String, suffix: String, only: PackedStringArray) -> void:
	if not only.is_empty() and not name in only:
		return
	Panels._save(tree, out.path_join("%s%s.jpg" % [name, suffix]))


static func _report(ui: Object, name: String) -> void:
	var top: Object = ui.call(&"get_panel", ui.call(&"top")) if not (ui.call(&"open_ids") as Array).is_empty() else null
	var hud: Control = (ui.get(&"hud") as Control).get_node(^"ResourcePanel") as Control
	var rect: Rect2 = (top as Control).get_global_rect() if top != null else Rect2()
	print("[ShotsR6] %s: panel %s  hud %s  overlap=%s" % [name, rect, hud.get_global_rect(), rect.intersects(hud.get_global_rect())])
