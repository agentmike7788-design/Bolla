extends RefCounted
## G8 Runde 5 screenshot set of graveyard_shots.gd (--round5=ui; docs/reviews/phase8_round5/ui_fixes.md): the known UI
## problems of round 4 (user: „bitte die bekannten probleme mal fixen"). New game, day 1, real systems, staged like
## graveyard_shots_panels.gd (Panels: stations built through the Workshop state, a filled grave for the stone, the
## inputs in the pack; the panel opened through the station's interact, the work started with its button's pressed
## signal, the player and his clip stepped at 60 Hz to 70 % of the work).
##   <out>/steinmetz_<tag><suffix>.jpg          – the stone bench while designing (first page / tab)
##   <out>/steinmetz_<tag>_<tab><suffix>.jpg    – nachher only: the tabs form, inschrift, zierde
##   <out>/steinmetz_<tag>_arbeit<suffix>.jpg   – during „Stein hauen" (70 %)
##   <out>/hud_<tag><suffix>.jpg                – the Werkbank panel docked beside the HUD's resource panel
##   <out>/hud_<tag>_steinmetz<suffix>.jpg      – nachher only: the stone bench beside it
## --shots=steinmetz,hud picks sets; --suffix carries the renderer / resolution (_web, _1366, _1024_web …).

const Panels := preload("res://src/world/graveyard/graveyard_shots_panels.gd")
const DAY := 1
const MINUTE := 620
const NAMES: Array[String] = ["steinmetz", "hud"]
## tab id of StoneDesignPanel -> file part
const TABS := {&"shape": "form", &"inscription": "inschrift", &"ornament": "zierde"}


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String, tag: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	Panels._build_stations(world)
	ui.visible = true
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rig.set(&"target", player)
	var inv: Object = player.get(&"inventory")
	var vp := tree.root.get_visible_rect().size
	print("[ShotsR5] window %s, canvas %s" % [tree.root.size, vp])
	var staged := false
	for name: String in NAMES:
		if not only.is_empty() and not name in only:
			continue
		player.call(&"cancel_timed_action")
		player.call(&"reset_tool")
		ui.call(&"close_all")
		clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
		if name == "hud":
			await _open_at(tree, world, player, rig, "werkbank")
			_report(ui, "werkbank")
			Panels._save(tree, out.path_join("hud_%s%s.jpg" % [tag, suffix]))
			if tag != "vorher":
				ui.call(&"close_all")
				if not staged:
					Panels._stage_grave(world, inv)
					staged = true
				await _open_at(tree, world, player, rig, "steinmetz")
				_report(ui, "steinmetz")
				Panels._save(tree, out.path_join("hud_%s_steinmetz%s.jpg" % [tag, suffix]))
			continue
		if not staged:
			Panels._stage_grave(world, inv)
			staged = true
		await _open_at(tree, world, player, rig, "steinmetz")
		var button := Panels._start_button(tree, ui, "steinmetz", inv)
		var panel: Object = ui.call(&"get_panel", &"stone_design")
		if panel.has_method(&"select_tab"):
			panel.call(&"select_tab", &"grave")
		await Panels._settle(tree)
		_report(ui, "steinmetz")
		Panels._save(tree, out.path_join("steinmetz_%s%s.jpg" % [tag, suffix]))
		if panel.has_method(&"select_tab"):
			for tab: StringName in TABS:
				panel.call(&"select_tab", tab)
				await Panels._settle(tree)
				Panels._save(tree, out.path_join("steinmetz_%s_%s%s.jpg" % [tag, TABS[tab], suffix]))
			panel.call(&"select_tab", &"grave")
			await Panels._settle(tree)
		if button == null or button.disabled:
			push_warning("[ShotsR5] steinmetz: no work to start")
			continue
		print("[ShotsR5] steinmetz: pressing '%s'" % button.get(&"text"))
		button.pressed.emit()
		var action: Object = player.get(&"_action")
		var duration := float(action.get(&"duration")) if action != null else 0.0
		var t := 0.0
		while t < duration * 0.7:
			Panels._advance(player, anim)
			t += Panels.STEP
		await Panels._settle(tree)
		print("[ShotsR5] steinmetz: +%.1f s busy=%s panel_visible=%s" % [t, player.call(&"is_busy"), panel.get(&"visible")])
		Panels._save(tree, out.path_join("steinmetz_%s_arbeit%s.jpg" % [tag, suffix]))
		while bool(player.call(&"is_busy")):
			Panels._advance(player, anim)
		await Panels._settle(tree)
	player.set_physics_process(true)


## The gravekeeper in front of the station, its panel opened through interact (the inputs of a recipe in the pack).
static func _open_at(tree: SceneTree, world: Node3D, player: Node3D, rig: Node3D, name: String) -> void:
	var spec: Array = Panels.OUTSIDE[name]
	var place := world.get_node(NodePath(String(spec[0]))) as Node3D
	player.global_transform = Panels._stand(place, float(spec[1]))
	rig.call(&"snap")
	await Panels._settle(tree)
	place.call(&"interact", player)
	await Panels._settle(tree)
	if name == "werkbank":
		Panels._start_button(tree, world.get_node(^"UI"), name, player.get(&"inventory"))
	await Panels._settle(tree)
	rig.call(&"snap")
	await Panels._settle(tree)


## Where the open panel and the HUD's resource panel lie (canvas px) – the log of the shot.
static func _report(ui: Object, name: String) -> void:
	var top: Object = ui.call(&"get_panel", ui.call(&"top")) if not (ui.call(&"open_ids") as Array).is_empty() else null
	var hud: Control = (ui.get(&"hud") as Control).get_node(^"ResourcePanel") as Control
	var rect: Rect2 = (top as Control).get_global_rect() if top != null else Rect2()
	print("[ShotsR5] %s: panel %s  hud %s  overlap=%s" % [name, rect, hud.get_global_rect(), rect.intersects(hud.get_global_rect())])
