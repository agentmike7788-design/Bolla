extends TestCase
## W2 integration: title screen buttons drive the SaveManager (new game, continue with the
## newest slot, failed load) and the pause menu saves, loads and leaves to the title –
## all against the save_world fixture scene.

const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const UI_SCENE := "res://src/ui/ui_root.tscn"
const SAVE_WORLD := "res://tests/fixtures/save_world/save_world.tscn"
const TEST_SAVE_DIR := "user://test_saves_ui_flow"
const WORLD_TIMEOUT := 3.0


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVE_DIR
	SaveManager.world_ready_timeout_sec = WORLD_TIMEOUT
	_wipe_saves()


func after_each() -> void:
	_wipe_saves()
	tree.paused = false


func test_title_without_saves() -> void:
	var title := await _title()
	assert_eq(title.continue_slot, -1)
	assert_false(title.continue_button.visible, "Fortsetzen hidden without a save")
	assert_true(title.new_game_button.visible)
	assert_true(title.quit_button.visible)
	assert_eq(title.world_scene, SaveManager.WORLD_SCENE, "default world")
	var quits := [0]
	title.quit_handler = func() -> void: quits[0] += 1
	title.quit_button.pressed.emit()
	assert_eq(quits[0], 1, "Beenden quits")


func test_title_new_game_starts_the_world() -> void:
	var title := await _title()
	title.world_scene = SAVE_WORLD
	title.new_game_button.pressed.emit()
	assert_true(title.new_game_button.disabled, "locked after the choice")
	title.new_game_button.pressed.emit()
	assert_true(await wait_for_signal(EventBus.new_game_started, WORLD_TIMEOUT + 1.0), "new_game_started")
	await wait_frames(1)
	assert_eq(tree.current_scene.scene_file_path, SAVE_WORLD)
	assert_true(TimeManager.running)
	assert_eq((tree.current_scene as Node).get_node("Player").get("count"), 5, "start content applied once")


func test_title_continue_loads_the_newest_slot() -> void:
	await _new_game()
	TimeManager.set_time(1, 600)
	assert_eq(SaveManager.save_game(1), OK)
	var title := await _title()
	assert_eq(title.continue_slot, 1)
	assert_true(title.continue_button.visible)
	assert_eq(title.continue_button.text, "Fortsetzen – Tag 1, 10:00")
	title.continue_button.pressed.emit()
	assert_true(await wait_for_signal(EventBus.game_loaded, WORLD_TIMEOUT + 1.0), "game_loaded")
	await wait_frames(1)
	assert_eq(tree.current_scene.scene_file_path, SAVE_WORLD)
	assert_eq(TimeManager.minute_of_day, 600)


func test_title_failed_load_unlocks_buttons() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var file := FileAccess.open(TEST_SAVE_DIR.path_join("slot_1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 1, "data": {"type": "nope"}, "meta": {"game_version": "x",
			"day": 2, "minute_of_day": 360, "saved_unix": 1, "scene": SAVE_WORLD}}))
	file.close()
	var title := await _title()
	assert_eq(title.continue_slot, 1, "meta is readable")
	title.continue_button.pressed.emit()
	await wait_frames(1)
	assert_eq(title.status_label.text, SaveManager.TEXT_CORRUPT)
	assert_false(title.continue_button.disabled, "buttons unlocked again")
	assert_eq(tree.current_scene, title, "still on the title")


func test_pause_menu_saves_with_a_world() -> void:
	await _new_game()
	var ui := await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	assert_true(SaveManager.can_save(), "pause menu on top allows saving")
	assert_false(menu.save_button.disabled)
	menu.save_button.pressed.emit()
	assert_true(SaveManager.has_save(1))
	assert_eq(menu.status_label.text, "Gespeichert (Schnellspeicher).")
	assert_false(menu.slot_buttons[1].disabled, "slot list refreshed")


func test_pause_menu_loads_a_slot() -> void:
	await _new_game()
	TimeManager.set_time(1, 720)
	assert_eq(SaveManager.save_game(1), OK)
	TimeManager.set_time(1, 900)
	var ui := await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"pause", {})
	assert_true(tree.paused)
	var menu := ui.get_panel(&"pause") as PauseMenu
	menu.load_button.pressed.emit()
	menu.slot_buttons[1].pressed.emit()
	assert_eq(ui.open_ids(), [], "loading clears the UI")
	assert_false(tree.paused, "loading unpauses")
	assert_true(await wait_for_signal(EventBus.game_loaded, WORLD_TIMEOUT + 1.0), "game_loaded")
	assert_eq(TimeManager.minute_of_day, 720)
	assert_false(UIState.is_modal())


func test_pause_menu_back_to_title() -> void:
	await _new_game()
	var ui := await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	menu.title_button.pressed.emit()
	await wait_frames(1)
	assert_eq(tree.current_scene.scene_file_path, SAVE_WORLD, "first press only asks")
	menu.title_button.pressed.emit()
	await wait_frames(2)
	assert_eq(tree.current_scene.scene_file_path, TITLE_SCENE)
	assert_false(tree.paused)
	assert_false(UIState.is_modal())
	assert_false(TimeManager.running, "clock stopped on the title")
	assert_false(SaveManager.can_save(), "no world any more")


func test_slice_summary_back_to_title() -> void:
	await _new_game()
	var ui := await add_scene(UI_SCENE) as UIRoot
	EventBus.ui_panel_requested.emit(&"slice_summary", {"days": 6, "burials": 6, "total": 50, "rating": &"dignified", "reputation": 0})
	var panel := ui.get_panel(&"slice_summary")
	var to_title: Button = null
	for button: Node in panel.find_children("*", "Button", true, false):
		if (button as Button).text == SliceSummaryPanel.TEXT_TITLE_SCREEN:
			to_title = button
	assert_not_null(to_title)
	# UI-02: the safe action has the default focus, "Zum Titel" asks once like the pause menu.
	var resume: Button = null
	for button: Node in panel.find_children("*", "Button", true, false):
		if (button as Button).text == SliceSummaryPanel.TEXT_CONTINUE:
			resume = button
	assert_eq(ui.get_viewport().gui_get_focus_owner(), resume, "Weiterspielen focused")
	to_title.pressed.emit()
	await wait_frames(2)
	assert_eq(tree.current_scene.scene_file_path, SAVE_WORLD, "first press only asks")
	assert_true(to_title.text.contains("wirklich"), to_title.text)
	to_title.pressed.emit()
	await wait_frames(2)
	assert_eq(tree.current_scene.scene_file_path, TITLE_SCENE)
	assert_false(UIState.is_modal())


## UI-02: one ui_accept on the freshly opened slice summary never leaves the world.
func test_slice_summary_accept_keeps_playing() -> void:
	await _new_game()
	var ui := await add_scene(UI_SCENE) as UIRoot
	EventBus.ui_panel_requested.emit(&"slice_summary", {"days": 6, "burials": 6, "total": 30, "rating": &"tended", "reputation": 0})
	await wait_frames(1)
	var focused := ui.get_viewport().gui_get_focus_owner() as Button
	assert_not_null(focused)
	focused.pressed.emit()
	await wait_frames(2)
	assert_eq(tree.current_scene.scene_file_path, SAVE_WORLD, "still in the world")
	assert_false(ui.is_open(&"slice_summary"), "Weiterspielen closed the summary")


## ARCH-01: F9/F5 on the title screen (no world, no quicksave) show a visible warning.
func test_title_shows_quick_save_warnings() -> void:
	var title := await _title()
	for action: StringName in [&"quick_load", &"quick_save"]:
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = action
			ev.pressed = pressed
			tree.root.push_input(ev)
	await wait_frames(1)
	var shown := title.notification_texts()
	assert_true(SaveManager.TEXT_NO_QUICKSAVE in shown, str(shown))
	assert_true(SaveManager.TEXT_CANNOT_SAVE in shown, str(shown))
	assert_true(title.notifications.is_visible_in_tree())
	assert_false(title.new_game_button.disabled, "a warning does not lock the menu")


## Phase 7 (docs/PHASE7_DESIGN.md §7): a veil that was down when a slot is loaded does not survive the
## load; the region name of the arrival is shown over the new world.
func test_phase7_veil_does_not_survive_a_load() -> void:
	await _new_game()
	assert_eq(SaveManager.save_game(1), OK)
	var ui := await add_scene(UI_SCENE) as UIRoot
	EventBus.screen_veil_changed.emit(true)
	assert_true(ui.veil.active and ui.veil.visible)
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	menu.load_button.pressed.emit()
	menu.slot_buttons[1].pressed.emit()
	assert_true(await wait_for_signal(EventBus.game_loaded, WORLD_TIMEOUT + 1.0), "game_loaded")
	assert_false(ui.veil.active)
	assert_false(ui.veil.visible, "the veil is gone after the load")
	EventBus.region_changed.emit(&"village")
	assert_eq(ui.region_label.shown_text, "Hollerbrück · Anger")


# --- helpers --------------------------------------------------------------------------------

## The title screen as the current scene (like src/boot/main.gd will do).
func _title() -> TitleScreen:
	tree.change_scene_to_file(TITLE_SCENE)
	await wait_frames(2)
	return tree.current_scene as TitleScreen


func _new_game() -> void:
	SaveManager.new_game(SAVE_WORLD)
	assert_true(await wait_for_signal(EventBus.new_game_started, WORLD_TIMEOUT + 1.0), "world started")
	await wait_frames(1)


func _wipe_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
