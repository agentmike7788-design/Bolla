extends Node
## QA director, Phase-4 UI (docs/PHASE4_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase4. Starts a new game in the real graveyard world and stages every state through the
## public APIs of the systems: the story corpse S1 (Marthe Quendel) on the morgue table,
## examined step by step through CorpseCare (the wounds late, so the cause detail is lost),
## washed and smoked with juniper, Ilse known and her shears in the pack; clues and an insight
## through JournalManager; Ilse's trade through NightTrade at 23:30; the chapter panel from
## Graveyard.chapter_context(&"six_pits"). Phase-4 system nodes the world does not have yet
## (CorpseCare, Piety, Journal, NightTrade – W-Welt adds them) are added under Systems first.
## Shots (1280×720, <out>/ui_<name>.jpg):
##   table_exam · table_prep · table_harvest · journal_clues · journal_insight · journal_self ·
##   trade_ilse · chapter_six_pits
## W3 (G4, over the real Phase-4 world – the builder has every system node now): door_note ·
## osric_p4 (his Phase-4 introduction) · ilse_dialogue (her „Abgebrüht“ greeting, Ilse at the
## wall above the dialogue box) · trade_ilse (the panel with Ilse framed beside it) ·
## ghost_robbed (a robbed and a fully prepared ghost side by side, both speaking).
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase4 --out=/abs/dir [--shots=table_exam,trade_ilse]

const SAVE_DIR := "user://ui_shot_saves_p4"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 6
const MORNING := 600
const NIGHT := 1410
const STORY := &"s1_quendel"
const SYSTEMS: Dictionary[String, Script] = {
	"CorpseCare": preload("res://src/systems/corpse/corpse_care.gd"),
	"Piety": preload("res://src/systems/piety/piety.gd"),
	"Journal": preload("res://src/systems/journal/journal_manager.gd"),
	"NightTrade": preload("res://src/systems/utilization/night_trade.gd"),
}
const GROUPS: Dictionary[String, StringName] = {
	"CorpseCare": &"corpse_care", "Piety": &"piety", "Journal": &"journal", "NightTrade": &"night_trade",
}

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _care: CorpseCare
var _journal: JournalManager
var _piety: Piety
var _trade: NightTrade
var _table: MorgueTable
var _record: CorpseRecord
var _anchor: Node3D
var _bounds_were: bool = true
## Nodes hidden for one shot (the old oak between the camera and the west wall – in play the
## foliage cutout frees the gravekeeper there), shown again by _unframe.
var _hidden: Array[Node3D] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP4] --out=<dir> missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveManager.save_dir = SAVE_DIR
	SaveManager.new_game()
	await EventBus.new_game_started
	await get_tree().process_frame
	TimeManager.running = false
	_world = get_tree().current_scene as WorldRoot
	_ui = _world.get_node(^"UI") as UIRoot
	_player = _world.get_player()
	_player.instant_actions = true
	_corpses = _world.corpse_manager
	_graveyard = _world.graveyard
	_ensure_systems()
	await get_tree().process_frame
	_stage()
	await get_tree().process_frame
	await _shot("table_exam", _table_shot.bind(CorpseExamTabs.TAB_EXAM))
	await _shot("table_prep", _table_shot.bind(CorpseExamTabs.TAB_PREP))
	await _shot("table_harvest", _table_shot.bind(CorpseExamTabs.TAB_HARVEST))
	await _shot("journal_clues", _journal_clues_shot)
	await _shot("journal_insight", _journal_insight_shot)
	await _shot("journal_self", _journal_self_shot)
	await _shot("door_note", _door_note_shot)
	await _shot("osric_p4", _osric_shot)
	await _shot("ilse_dialogue", _ilse_dialogue_shot)
	await _shot("trade_ilse", _trade_shot)
	await _shot("ghost_robbed", _ghost_shot)
	await _shot("chapter_six_pits", _chapter_shot)
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name in _only:
		return
	await setup.call()
	_ui.hud.refresh_all()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_%s.jpg" % shot_name)
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP4] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_unframe()
	await get_tree().process_frame


## Missing Phase-4 system nodes (W-Welt's builder adds them now – a no-op in the real world;
## kept for older scene builds) – same classes and groups.
func _ensure_systems() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_care = get_tree().get_first_node_in_group(&"corpse_care") as CorpseCare
	_journal = get_tree().get_first_node_in_group(&"journal") as JournalManager
	_piety = get_tree().get_first_node_in_group(&"piety") as Piety
	_trade = get_tree().get_first_node_in_group(&"night_trade") as NightTrade


# --- staging (real systems only) ----------------------------------------------------------

## Day 6, 10:00: Marthe Quendel (S1) on the table – wounds examined late (the cause detail is
## lost, the mark stays), then pockets (the page → c_page_1); washed and smoked with juniper;
## Ilse known, her shears in the pack, a burial gown but no comb.
func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	_corpses.load_state({"last_delivery_day": DAY})
	_table = _world.get_node_by_layout_id("morgue_table") as MorgueTable
	var story := Database.story_corpse(STORY) as StoryCorpseData
	var rec := StoryDirector.make_record(story, 7)
	rec.arrival_total_minutes = TimeManager.total_minutes()
	_record = _corpses.spawn_corpse(rec, _table.slot_transform(), CorpseRecord.LOCATION_GROUND)
	_corpses.put_down(_record.id, CorpseRecord.LOCATION_TABLE, _table.slot_transform(), _table.slot_node())
	_set_freshness(0.5)
	_care.exam_step(_record.id, CorpseRecord.STEP_WOUNDS)
	_set_freshness(0.71)
	_care.exam_step(_record.id, CorpseRecord.STEP_POCKETS)
	var inv := _player.inventory
	for entry: Array in [[&"scrub_brush", 1], [&"juniper", 2], [&"burial_gown", 1], [&"coin", 14], [&"linen", 1]]:
		inv.add_item(entry[0], entry[1])
	_care.wash(_record.id, inv)
	_care.apply_balm(_record.id, inv)
	GameState.set_flag(&"trader_known", true)
	inv.add_item(&"shears", 1)
	_place_player(_table.global_position + _table.global_basis.z * 1.3)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()


## Freshness by moving the arrival back (as the debug command "corpse fresh" does).
func _set_freshness(value: float) -> void:
	var rate := CorpseDecay.decay_per_hour(_record, Database.corpse_tables() as CorpseTables)
	var now := TimeManager.total_minutes()
	_record.arrival_total_minutes = now - roundi((1.0 - value) / rate * 60.0)
	_record.freshness = CorpseDecay.freshness_at(_record, now, rate)
	_record.last_decay_total = now
	_corpses.notify_changed(_record.id)


## Camera on `focus` (ground) at `distance` instead of the player.
func _frame(focus: Vector3, distance: float) -> void:
	var rig := _world.get_node(^"CameraRig")
	if _anchor == null:
		_anchor = Node3D.new()
		_anchor.name = "ShotAnchor"
		_world.add_child(_anchor)
	_anchor.global_position = Vector3(focus.x, 0.0, focus.z)
	if rig.get(&"target") != _anchor:
		_bounds_were = bool(rig.get(&"bounds_enabled"))
	rig.set("bounds_enabled", false)
	rig.set("zoom_min", minf(float(rig.get(&"zoom_min")), 5.0))
	rig.set("target", _anchor)
	rig.call(&"set_distance", distance)
	rig.call(&"snap")


## Camera at `distance` so that `world_pos` shows at `screen` (pixels of the 1280 × 720 shot;
## the viewport itself may be larger – the content stretches).
func _frame_at(world_pos: Vector3, shot_px: Vector2, distance: float) -> void:
	var screen := shot_px * get_viewport().get_visible_rect().size / Vector2(1280.0, 720.0)
	_frame(world_pos, distance)
	# Two passes: the rig places its camera in its own frame after snap().
	for i: int in 2:
		for f: int in 2:
			await get_tree().process_frame
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var here := _ground_under(cam, cam.unproject_position(world_pos))
		var there := _ground_under(cam, screen)
		_frame(_anchor.global_position + (here - there), distance)
	for f: int in 2:
		await get_tree().process_frame
	var check := get_viewport().get_camera_3d()
	if check != null:
		print("[UiShotsP4] framed %s at %s (wanted %s)" % [world_pos, check.unproject_position(world_pos), screen])


func _hide(path: NodePath) -> void:
	var node := _world.get_node_or_null(path) as Node3D
	if node != null and node.visible:
		node.visible = false
		_hidden.append(node)


static func _ground_under(cam: Camera3D, screen: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	return hit if hit != null else origin


## The camera follows the player again.
func _unframe() -> void:
	if _anchor == null:
		return
	for node: Node3D in _hidden:
		node.visible = true
	_hidden.clear()
	var rig := _world.get_node(^"CameraRig")
	rig.set("bounds_enabled", _bounds_were)
	rig.set("target", _player)
	rig.call(&"set_distance", 22.0)
	rig.call(&"snap")


func _place_player(at: Vector3, facing: float = PI) -> void:
	at.y = _world.ground_height(Vector2(at.x, at.z))
	_player.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
	_player.velocity = Vector3.ZERO
	_world.get_node(^"CameraRig").call(&"snap")


# --- shots ------------------------------------------------------------------------------------

func _table_shot(tab: StringName) -> void:
	_table.interact(_player)
	await get_tree().process_frame
	var panel := _ui.get_panel(&"corpse_exam") as CorpseExamPanel
	panel.tabs.select_tab(tab)
	if tab == CorpseExamTabs.TAB_HARVEST:
		panel.tabs.confirm_seconds = 60.0
		panel.tabs.press_harvest(&"hair")


func _journal_clues_shot() -> void:
	for id: StringName in [&"c_warning_letter", &"c_anchor_snake", &"c_trader_note"]:
		_journal.add_clue(id)
	_ui.notifications.clear()
	_ui.open_journal(&"clues")
	await get_tree().process_frame
	var panel := _ui.get_panel(&"journal") as JournalPanel
	for id: StringName in [&"c_warning_letter", &"c_mark", &"c_page_1"]:
		panel.toggle_clue(id)


func _journal_insight_shot() -> void:
	_ui.open_journal(&"clues")
	await get_tree().process_frame
	var panel := _ui.get_panel(&"journal") as JournalPanel
	panel.reveal_time = 0.0
	panel.toggle_clue(&"c_warning_letter")
	panel.toggle_clue(&"c_page_1")
	panel.link_selected()
	_ui.notifications.clear()


func _journal_self_shot() -> void:
	_piety.change(34 - _piety.value(), "Aufnahme")
	GameState.stats[&"prepared"] = 4
	GameState.stats[&"utilized"] = 1
	_ui.notifications.clear()
	_ui.open_journal(&"self")


## The note at the hut door (trader_known, Ilse not met yet), close.
func _door_note_shot() -> void:
	var door := _world.get_node_by_layout_id("hut_door") as Node3D
	var note := _world.get_node_or_null(^"Decor/DoorNote") as Node3D
	var at := note.global_position if note != null else door.global_position
	_place_player(door.global_position + door.global_basis.z * 1.6 + door.global_basis.x * 1.2, door.global_rotation.y + PI)
	_hide(^"Decor/Tree")
	_frame(Vector3(at.x, 0.0, at.z) + door.global_basis.z * 0.4, 4.5)
	await get_tree().process_frame


## Morning at the gate: Osric's Phase-4 introduction (p4_intro: clothes, hands, wounds, pockets).
func _osric_shot() -> void:
	TimeManager.set_time(TimeManager.day + 1, 480)
	UIState.clear()
	_ui.close_all()
	var npc := _world.get_node_by_layout_id("npc_carter") as Node3D
	for i: int in 5:
		await get_tree().process_frame
	GameState.set_flag(&"met_carter", true)
	GameState.set_flag(&"p3_intro", true)
	_place_player(npc.global_position + Vector3(-1.2, 0.0, -1.0), PI * 0.75)
	await _frame_at(npc.global_position, Vector2(640, 330), 10.0)
	await get_tree().process_frame
	_ui.open_dialogue(&"carter", npc)
	for i: int in 8:
		if _ui.dialogue_box.current_text().contains("Aschau") or not _ui.dialogue_box.is_active():
			break
		_ui.dialogue_box.choose(0)
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0


## 23:30 at the west wall: met before, her tools given – she greets a „callous“ gravekeeper.
func _ilse_dialogue_shot() -> void:
	_ui.dialogue_box.chars_per_second = 110.0
	TimeManager.set_time(TimeManager.day, NIGHT)
	_piety.change(-30 - _piety.value(), "Aufnahme")
	GameState.set_flag(&"trader_met", true)
	GameState.set_flag(&"trader_tools_given", true)
	var ilse := _world.get_node_by_layout_id("npc_trader") as Npc
	for i: int in 5:
		await get_tree().process_frame
	var spot: Vector3 = _world.get_waypoint(&"trader_spot")
	_place_player(spot + Vector3(1.35, 0.0, 0.3), -PI * 0.5)
	_hide(^"Decor/Tree")
	await _frame_at(ilse.global_position, Vector2(560, 380), 9.0)
	await get_tree().process_frame
	_ui.notifications.clear()
	_ui.open_dialogue(&"trader", ilse)
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0


## The trade panel („Handeln.“) with Ilse at the wall framed to the left of it.
func _trade_shot() -> void:
	_ui.dialogue_box.chars_per_second = 110.0
	TimeManager.set_time(TimeManager.day, NIGHT)
	_piety.change(-30 - _piety.value(), "Aufnahme")
	var inv := _player.inventory
	inv.add_item(&"hair_braid", 2)
	inv.add_item(&"teeth_pouch", 1)
	var ilse := _world.get_node_by_layout_id("npc_trader") as Npc
	for i: int in 5:
		await get_tree().process_frame
	var spot: Vector3 = _world.get_waypoint(&"trader_spot")
	_place_player(spot + Vector3(1.35, 0.0, 0.3), -PI * 0.5)
	_hide(^"Decor/Tree")
	await _frame_at(ilse.global_position, Vector2(110, 520), 8.0)
	await get_tree().process_frame
	_ui.notifications.clear()
	_ui.open_panel(&"trader", {"speaker": ilse, "inventory": inv})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"trader") as TraderPanel
	panel.buy(&"juniper")


## Night: a robbed ghost (hair and teeth taken, restless) beside a fully prepared one (content).
func _ghost_shot() -> void:
	_ui.dialogue_box.chars_per_second = 110.0
	_piety.change(10 - _piety.value(), "Aufnahme")
	var inv := _player.inventory
	for spec: Array in [["plot_04", true], ["plot_05", false]]:
		var plot_id: String = spec[0]
		if _graveyard.get_grave(plot_id).state != GraveRecord.State.EMPTY:
			continue
		var plot := _world.get_node_by_layout_id(plot_id) as Node3D
		var record := _corpses.spawn_corpse(null, plot.global_transform, &"ground")
		record.examined = true
		record.exam_done.assign(CorpseRecord.STEPS)
		if record.needs_valuables_decision():
			record.valuables_decision = CorpseRecord.DECISION_LEFT
		if bool(spec[1]):
			record.harvested.assign([CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH])
			record.dress = CorpseRecord.DRESS_SHROUD
		else:
			record.washed = true
			record.laid_out = true
			record.dress = CorpseRecord.DRESS_GOWN
		record.shrouded = true
		_graveyard.dig(plot_id)
		_graveyard.bury(plot_id, record.id)
		inv.add_item(&"gravestone_simple", 1)
		_graveyard.place_marker(plot_id, &"gravestone_simple", inv)
	# Next night, ghost time: both walk and speak.
	TimeManager.set_time(TimeManager.day + 1, 1335)
	var ghosts := _world.get_node(^"Systems/Ghosts") as GhostManager
	var a := _world.get_node_by_layout_id("plot_04") as Node3D
	var b := _world.get_node_by_layout_id("plot_05") as Node3D
	var mid := (a.global_position + b.global_position) * 0.5
	_place_player(mid + Vector3(0.0, 0.0, 1.6), PI)
	for i: int in 5:
		await get_tree().process_frame
	ghosts.reselect()
	ghosts.update_visuals(TimeManager.get_minute_f())
	for g: Ghost in ghosts.active_ghosts():
		if g.grave_id in ["plot_04", "plot_05"]:
			# listen() as [E] on the ghost does; the bubble stays up for the slow software renderer.
			g.say(ghosts.listen(g.grave_id, _player), 600.0)
	_frame(mid, 8.0)
	(_world.get_node(^"Systems/CemeteryScore") as CemeteryScore).refresh(true)
	_ui.notifications.clear()
	await get_tree().process_frame


func _chapter_shot() -> void:
	_piety.change(64 - _piety.value(), "Aufnahme")
	GameState.stats[&"burials"] = 18
	GameState.stats[&"prepared"] = 13
	GameState.stats[&"utilized"] = 1
	# The five main insights linked through the journal (the flag insight_not_lorenz with them).
	for clue: ClueData in _journal._clue_list():
		_journal.add_clue(clue.id, "", true)
	for insight: InsightData in _journal._insight_list():
		if not insight.optional:
			var ids: Array[StringName] = []
			ids.assign(insight.requires)
			_journal.try_link(ids)
	var context := _graveyard.chapter_context(&"six_pits")
	context["days"] = 19
	_ui.notifications.clear()
	_ui.open_panel(&"slice_summary", context)
