extends Node
## QA director (started by src/ui/tools/ui_screenshots.gd): renders every UI screen over the
## frozen art prototype (HUD day/night, reward card, all panels incl. the hut's chest and
## grave register, dialogue, debug console, icon sheet, title screen) with test doubles. A Node so it may use the autoloads.

const BACKDROP := "res://src/world/art_prototype/art_prototype.tscn"
const UI_SCENE := "res://src/ui/ui_root.tscn"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const SAVE_DIR := "user://ui_screenshot_saves"
const SETTLE_FRAMES := 24
const JPG_QUALITY := 0.9


class FakeCorpses extends Node:
	var list: Array[CorpseRecord] = []

	func records() -> Array[CorpseRecord]:
		return list

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in list:
			if r.id == id:
				return r
		return null


class FakeGraveyard extends Node:
	var list: Array[GraveRecord] = []

	func graves() -> Array[GraveRecord]:
		return list

	func total_quality() -> int:
		var total := 0
		for g: GraveRecord in list:
			total += g.quality
		return total

	func rating() -> StringName:
		return CemeteryRating.rating(total_quality(), Database.config(&"economy_config") as EconomyConfig)


class FakeStation extends Node3D:
	func request_examine() -> void:
		pass

	func request_shroud() -> void:
		pass

	func decide_valuables(_take: bool) -> void:
		pass

	func request_pick_up() -> void:
		pass

	func request_craft(_id: StringName) -> void:
		pass

	func request_marker(_id: StringName) -> void:
		pass


var _out: String = ""
var _only: PackedStringArray = []
var _backdrop: Node
var _ui: UIRoot
var _player: FakePlayer
## Extra node of the current shot (freed afterwards).
var _extra: Node
var _inv: Inventory
var _corpses: FakeCorpses
var _graveyard: FakeGraveyard
var _station: FakeStation


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiScreenshots] --out=<dir> missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_setup_world()
	await _shot("01_hud_day", _hud_day)
	await _shot("02_hud_night", _hud_night)
	await _shot("03_reward_card", _reward)
	await _shot("04_inventory", _panel.bind(&"inventory"))
	await _shot("05_corpse_exam", _corpse_exam.bind(false))
	await _shot("06_corpse_exam_examined", _corpse_exam.bind(true))
	await _shot("07_crafting", _panel.bind(&"crafting"))
	await _shot("08_marker_choice", _panel.bind(&"marker_choice"))
	await _shot("09_day_summary", _panel.bind(&"day_summary"))
	await _shot("10_slice_summary", _panel.bind(&"slice_summary"))
	await _shot("11_pause", _pause)
	await _shot("12_dialogue", _dialogue.bind(0))
	await _shot("13_dialogue_shop", _dialogue.bind(3))
	await _shot("14_debug_console", _debug)
	await _shot("15_icons", _icons)
	await _shot("17_slice_summary_after_reward", _slice_after_reward)
	await _shot("18_hud_slice_complete", _hud_complete)
	await _shot("20_chest", _chest)
	await _shot("21_grave_register", _grave_register)
	_backdrop.queue_free()
	_ui.queue_free()
	await get_tree().process_frame
	await _shot("16_title", _title)
	await _shot("19_title_warning", _title_warning)
	_cleanup_saves()
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name.left(2) in _only:
		return
	await setup.call()
	if is_instance_valid(_ui) and not _ui.is_queued_for_deletion():
		_ui.hud.refresh_objective()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join(shot_name + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiScreenshots] ", path)
	_reset_ui()
	await get_tree().process_frame


func _setup_world() -> void:
	_backdrop = (load(BACKDROP) as PackedScene).instantiate()
	get_tree().root.add_child(_backdrop)
	(_backdrop.get_node(^"HUD") as CanvasLayer).visible = false
	_player = FakePlayer.new()
	_player.name = "FakePlayer"
	_player.add_to_group(&"player")
	_inv = Inventory.new()
	_inv.name = "Inventory"
	_player.add_child(_inv)
	_player.inventory = _inv
	get_tree().root.add_child(_player)
	_corpses = FakeCorpses.new()
	_corpses.add_to_group(&"corpse_manager")
	get_tree().root.add_child(_corpses)
	_graveyard = FakeGraveyard.new()
	_graveyard.add_to_group(&"graveyard")
	get_tree().root.add_child(_graveyard)
	_station = FakeStation.new()
	get_tree().root.add_child(_station)
	_ui = (load(UI_SCENE) as PackedScene).instantiate() as UIRoot
	get_tree().root.add_child(_ui)
	_fill_inventory()
	_make_graves()


class FakePlayer extends Node3D:
	var inventory: Inventory
	var instant_actions: bool = false

	func is_busy() -> bool:
		return false


func _fill_inventory() -> void:
	_inv.clear()
	for entry: Array in [[&"coin", 14], [&"wood", 7], [&"stone", 3], [&"linen", 1], [&"shroud", 1], [&"wooden_cross", 1]]:
		_inv.add_item(entry[0], entry[1])


func _make_graves() -> void:
	for i: int in 6:
		var g := GraveRecord.new()
		g.id = "plot_%02d" % (i + 1)
		g.state = GraveRecord.State.MARKED if i < 2 else GraveRecord.State.EMPTY
		g.quality = 9 if i == 0 else (6 if i == 1 else 0)
		g.marker_id = &"wooden_cross" if i < 2 else &""
		_graveyard.list.append(g)


func _set_time(day: int, minute: int) -> void:
	TimeManager.day = day
	TimeManager.minute_of_day = minute
	EventBus.time_tick.emit(day, minute)


func _atmosphere(index: int) -> void:
	(_backdrop.get_node(^"Atmosphere") as AtmosphereController).apply(index)


func _reset_ui() -> void:
	if _ui == null or not is_instance_valid(_ui):
		return
	_ui.close_all()
	_corpses.list = []
	_ui.hud.refresh_all()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	EventBus.interaction_focus_changed.emit("", false)
	EventBus.timed_action_finished.emit(true)
	Debug.reset()
	if is_instance_valid(_extra):
		_extra.queue_free()
	_extra = null
	get_tree().paused = false


func _corpse(examined: bool) -> CorpseRecord:
	var c := CorpseRecord.new()
	c.id = "corpse_0002"
	c.display_name = "Hedwig Rabenstein"
	c.age = 67
	c.cause_id = &"drowned_millpond"
	c.traits = [&"valuables", &"letter"]
	c.valuables_coins = 6
	c.freshness = 0.81
	c.location = &"table"
	c.examined = examined
	return c


# --- shots --------------------------------------------------------------------------------

func _hud_day() -> void:
	_atmosphere(0)
	_corpses.list = [_corpse(false)]
	_corpses.list[0].location = &"dropoff"
	_set_time(2, 472)
	_ui.hud.refresh_all()
	EventBus.cemetery_quality_changed.emit(15, &"orderly")
	EventBus.interaction_focus_changed.emit("Leiche aufnehmen", true)
	EventBus.notification_requested.emit("Osric hat eine Leiche auf die Bahre gelegt.", &"info")
	EventBus.notification_requested.emit("+1 Leinen", &"reward")


func _hud_night() -> void:
	_atmosphere(1)
	_corpses.list = [_corpse(true)]
	_corpses.list[0].location = &"carried"
	_set_time(3, 1300)
	_ui.hud.refresh_all()
	EventBus.cemetery_quality_changed.emit(15, &"orderly")
	EventBus.delivery_skipped.emit(3, "Die Bahre ist noch belegt.")
	EventBus.interaction_focus_changed.emit("Hände frei nötig – [Q] ablegen", false)
	EventBus.timed_action_started.emit("Grab ausheben", 3.0)
	EventBus.timed_action_progress.emit(0.6)
	EventBus.notification_requested.emit("Hier nicht ablegen.", &"warning")


func _reward() -> void:
	_atmosphere(0)
	_corpses.list = [_corpse(true)]
	_set_time(2, 700)
	var breakdown: Array = [{"label": "Bestattet", "points": 2}, {"label": "Leichentuch", "points": 2},
			{"label": "Grabstein", "points": 3}, {"label": "Frisch", "points": 1}, {"label": "Untersucht", "points": 1}]
	EventBus.grave_completed.emit("plot_03", "corpse_0002", 9, breakdown)
	EventBus.payment_received.emit(7, "Bestattung von Hedwig Rabenstein")
	EventBus.notification_requested.emit("Grabzeichen gesetzt.", &"info")


func _panel(id: StringName) -> void:
	_atmosphere(0)
	_set_time(2, 640)
	var contexts: Dictionary[StringName, Dictionary] = {
		&"inventory": {"inventory": _inv},
		&"crafting": {"station": &"workbench", "inventory": _inv, "workbench": _station, "player": _ui.player},
		&"marker_choice": {"grave_id": "plot_03", "plot": _station, "options": [&"wooden_cross", &"gravestone_simple"]},
		&"day_summary": {"day": 2, "burials_today": 1, "coins_today": 9, "total": 15, "rating": &"orderly"},
		&"slice_summary": {"days": 6, "burials": 6, "total": 49, "rating": &"dignified", "reputation": -1},
	}
	_ui.open_panel(id, contexts[id])


func _corpse_exam(examined: bool) -> void:
	_atmosphere(0)
	_set_time(2, 500)
	_corpses.list = [_corpse(examined)]
	_ui.open_panel(&"corpse_exam", {"corpse_id": "corpse_0002", "table": _station, "player": _ui.player})


func _pause() -> void:
	_atmosphere(1)
	SaveManager.save_dir = SAVE_DIR
	_set_time(2, 360)
	SaveManager.save_game(0)
	_set_time(3, 865)
	SaveManager.save_game(1)
	_ui.open_panel(&"pause", {})


func _dialogue(steps: int) -> void:
	_atmosphere(0)
	_set_time(2, 470)
	GameState.reset()
	_ui.open_dialogue(&"carter", _station)
	# intro → intro_linen → menu → shop
	var path: Array[int] = [0, 1, 0]
	for i: int in mini(steps, path.size()):
		_ui.dialogue_box.choose(path[i])
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0


func _debug() -> void:
	_atmosphere(1)
	_ui.dialogue_box.chars_per_second = 110.0
	Debug.reset()
	Debug.open()
	for command: String in ["time 07:30", "give wood 5", "tp moon", "flags", "fps"]:
		Debug.execute(command)


func _icons() -> void:
	_atmosphere(0)
	var layer := CanvasLayer.new()
	layer.layer = 5
	_ui.add_child(layer)
	var sheet := Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.theme = UIKit.theme()
	layer.add_child(sheet)
	var box := UIKit.vbox(24)
	for variation: StringName in [&"HudPanel", &"CardPanel", &"SlotPanel"]:
		var row := UIKit.panel(variation)
		var icons := UIKit.hbox(24)
		for id: StringName in [&"coin", &"wood", &"stone", &"linen", &"shroud", &"wooden_cross", &"gravestone_simple"]:
			icons.add_child(UIKit.icon(Database.icon(id), 128.0))
		row.add_child(icons)
		box.add_child(row)
	sheet.add_child(UIKit.centered(box))
	_extra = layer


func _title() -> void:
	var title := (load(TITLE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(title)


## The last grave: reward card, then the slice summary opens at once (card must wait).
func _slice_after_reward() -> void:
	await _reward()
	_ui.open_panel(&"slice_summary", {"days": 6, "burials": 6, "total": 30, "rating": &"tended", "reputation": 0})


## After "Weiterspielen": objective line with the goal missed (graves total 15).
func _hud_complete() -> void:
	_atmosphere(0)
	_set_time(7, 600)
	GameState.set_flag(&"slice_complete", true)
	_ui.hud.refresh_all()


## Hut chest: storage with a few stacks next to the filled bag.
func _chest() -> void:
	_atmosphere(1)
	_set_time(2, 1230)
	EventBus.cemetery_quality_changed.emit(24, &"orderly")
	var storage := Inventory.new()
	storage.name = "ChestStorage"
	for entry: Array in [[&"wood", 24], [&"stone", 12], [&"linen", 3], [&"gravestone_simple", 1], [&"shroud", 2]]:
		storage.add_item(entry[0], entry[1])
	_ui.add_child(storage)
	_extra = storage
	_ui.open_panel(&"chest", {"storage": storage, "inventory": _inv, "chest": storage})


## Grave register at the desk: four burials.
func _grave_register() -> void:
	_atmosphere(1)
	_set_time(4, 1250)
	EventBus.cemetery_quality_changed.emit(24, &"orderly")
	var entries: Array[Dictionary] = [
		{"name": "Hedwig Rabenstein", "age": 67, "cause_label": "Ertrunken im Mühlteich", "day_buried": 1,
				"grave_id": "plot_03", "quality": 9, "marker_label": "Grabstein"},
		{"name": "Egbert Kornblum", "age": 54, "cause_label": "Fieber", "day_buried": 2,
				"grave_id": "plot_01", "quality": 6, "marker_label": "Holzkreuz"},
		{"name": "Margarete Eschenbach", "age": 31, "cause_label": "Vom Pferd getreten", "day_buried": 3,
				"grave_id": "plot_05", "quality": 7, "marker_label": "Holzkreuz"},
		{"name": "Anselm Grauwert", "age": 78, "cause_label": "Altersschwäche", "day_buried": 3,
				"grave_id": "plot_02", "quality": 2, "marker_label": ""},
	]
	_ui.open_panel(&"grave_register", {"entries": entries, "total": 24, "rating": &"orderly"})


func _title_warning() -> void:
	for node: Node in get_tree().root.get_children():
		if node is TitleScreen:
			node.queue_free()
	await get_tree().process_frame
	_title()
	await get_tree().process_frame
	EventBus.notification_requested.emit(SaveManager.TEXT_NO_QUICKSAVE, &"warning")


func _cleanup_saves() -> void:
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
