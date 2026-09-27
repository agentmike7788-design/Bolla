extends TestCase
## W2: UIRoot (panels, modal stack, pause, Esc / I / E input), HUD reactions to EventBus
## signals, every panel of docs §7 with test doubles, the dialogue box walking
## data/dialogue/carter.tres with a fake inventory, and the debug console (parser, commands,
## toggle, disabled without GameConfig.debug_enabled).

const UI_SCENE := "res://src/ui/ui_root.tscn"
const THEME_PATH := "res://src/ui/theme/gravekeeper_theme.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const TEST_SAVE_DIR := "user://test_saves_ui_unit"
const WAIT_TEXT := "Der Leichenkutscher kommt gegen 07:40"


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false
	var instant_actions: bool = false
	var interacts: int = 0
	var drop_xform: Transform3D = Transform3D(Basis(), Vector3(2.0, 0.0, 3.0))

	func is_busy() -> bool:
		return busy

	func drop_position() -> Transform3D:
		return drop_xform

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"interact"):
			interacts += 1


class FakeCorpseManager extends Node:
	var list: Array[CorpseRecord] = []
	var spawned: Array = []

	func records() -> Array[CorpseRecord]:
		return list

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in list:
			if r.id == id:
				return r
		return null

	func spawn_corpse(_record: CorpseRecord = null, at: Transform3D = Transform3D.IDENTITY, location: StringName = &"dropoff") -> CorpseRecord:
		var r := CorpseRecord.new()
		r.id = "corpse_%04d" % (list.size() + 1)
		r.display_name = "Egbert Kornblum"
		r.age = 54
		r.cause_id = &"fever"
		r.location = location
		r.position = at.origin
		list.append(r)
		spawned.append([at, location])
		return r


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


## Table / workbench / plot double: records every request.
class FakeStation extends Node3D:
	var calls: Array = []
	var record: CorpseRecord

	func request_examine() -> void:
		calls.append("examine")

	func request_shroud() -> void:
		calls.append("shroud")

	func decide_valuables(take: bool) -> void:
		calls.append(["decide", take])

	func request_pick_up() -> void:
		calls.append("pick_up")
		if record != null:
			record.location = &"carried"

	func request_craft(recipe_id: StringName) -> void:
		calls.append(recipe_id)

	func request_marker(marker_id: StringName) -> void:
		calls.append(marker_id)


class FakeDropoff extends Node3D:
	var free_slot: bool = true

	func is_free() -> bool:
		return free_slot

	func slot_transform() -> Transform3D:
		return Transform3D(Basis(), Vector3(0.0, 0.5, 9.0))


class FakeNpc extends Node3D:
	var npc_id: StringName = &"carter"


class FakeWorld extends Node3D:
	var waypoints: Dictionary = {&"road_mid": Vector3(0.0, 0.0, 18.0)}

	func get_waypoint(id: StringName) -> Vector3:
		return waypoints.get(id, Vector3.ZERO)

	func get_node_by_layout_id(id: String) -> Node:
		return get_node_or_null(NodePath(id))


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var corpses: FakeCorpseManager
var graveyard: FakeGraveyard
var station: FakeStation
var _debug_before: bool = true
var _events: Array = []


func before_each() -> void:
	_debug_before = GameConfig.debug_enabled
	GameConfig.debug_enabled = true
	Debug.reset()
	_events.clear()
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func after_each() -> void:
	EventBus.dialogue_ended.disconnect(_on_dialogue_ended)
	Debug.reset()
	GameConfig.debug_enabled = _debug_before
	for slot: int in [0, 1, 2]:
		if SaveManager.save_dir == TEST_SAVE_DIR:
			SaveManager.delete_save(slot)
	if DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR)
	tree.paused = false


# --- scene & modal stack --------------------------------------------------------------------

func test_scene_contract() -> void:
	await _setup()
	assert_true(ui is CanvasLayer)
	assert_true(ui.is_in_group(&"ui_root"))
	assert_eq(ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(ui.root_control.theme.resource_path, THEME_PATH)
	assert_true(ui.hud is GameHud)
	assert_true(ui.dialogue_box is DialogueBox)
	assert_true(ui.notifications is NotificationStack)
	assert_true(ui.reward_card is RewardCard)
	assert_eq(ui.player, player, "player found via group on _ready")
	assert_eq(tree.get_first_node_in_group(&"ui_root"), ui)
	assert_false(ui.dim.visible)
	assert_eq(ui.open_ids(), [])


func test_theme_marks_placeholder_font() -> void:
	var text := FileAccess.get_file_as_string(THEME_PATH)
	assert_true(text.contains("PLACEHOLDER"), "theme comment names the placeholder font")
	var theme := load(THEME_PATH) as Theme
	assert_null(theme.default_font, "Godot default font until a final font is chosen")
	for variation: StringName in [&"HeaderLabel", &"WindowPanel", &"HudPanel", &"CardPanel", &"AccentButton",
			&"DangerButton", &"ChoiceButton", &"FreshBar", &"WiltedBar", &"DecayBar", &"NoteWarning"]:
		assert_ne(theme.get_type_variation_base(variation), &"", String(variation))
	for type: StringName in [&"Button", &"LineEdit", &"ProgressBar", &"TooltipPanel", &"PanelContainer"]:
		assert_false(theme.get_stylebox_list(type).is_empty(), String(type))


func test_every_panel_opens_and_closes() -> void:
	await _setup()
	var contexts := _contexts()
	for id: StringName in contexts:
		ui.open_panel(id, contexts[id])
		await wait_frames(1)
		assert_eq(ui.top(), id, String(id))
		assert_eq(UIState.top(), id, String(id))
		assert_true(TimeManager.paused, "modal pauses the clock: " + String(id))
		var panel := ui.get_panel(id)
		assert_true(panel.is_open and panel.is_visible_in_tree(), String(id) + " visible")
		assert_true(ui.dim.visible, String(id) + " dims the world")
		assert_eq(tree.paused, id == &"pause", String(id) + " tree pause only for the pause menu")
		ui.close_top_panel()
		await wait_frames(1)
		assert_false(ui.is_open(id), String(id))
		assert_false(UIState.is_modal(), String(id))
		assert_false(panel.visible, String(id))
		assert_false(tree.paused, String(id))
		assert_false(ui.dim.visible)


func test_panels_open_via_event_bus_and_close_button() -> void:
	await _setup()
	EventBus.ui_panel_requested.emit(&"day_summary", _contexts()[&"day_summary"])
	assert_eq(ui.top(), &"day_summary")
	ui.get_panel(&"day_summary").request_close()
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())


func test_unknown_panel_is_ignored() -> void:
	await _setup()
	ui.open_panel(&"no_such_panel", {})
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())


func test_close_panel_is_idempotent() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": inv})
	ui.close_panel(&"inventory")
	ui.close_panel(&"inventory")
	ui.close_top_panel()
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())


func test_stack_shows_only_the_top_panel_and_esc_unwinds() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": inv})
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	await wait_frames(1)
	assert_eq(ui.open_ids(), [&"inventory", &"crafting"])
	assert_false(ui.get_panel(&"inventory").is_visible_in_tree(), "lower panel hidden")
	assert_true(ui.get_panel(&"crafting").is_visible_in_tree())
	_press(&"pause")
	assert_eq(ui.open_ids(), [&"inventory"], "Esc closes the top panel")
	assert_true(ui.get_panel(&"inventory").is_visible_in_tree())
	assert_eq(UIState.top(), &"inventory")
	_press(&"pause")
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())
	_press(&"pause")
	assert_eq(ui.top(), &"pause", "Esc with nothing open opens the pause menu")
	assert_true(tree.paused)
	assert_eq(UIState.top(), &"pause")
	_press(&"pause")
	assert_eq(ui.open_ids(), [])
	assert_false(tree.paused)
	assert_false(TimeManager.paused)


func test_reopening_a_panel_moves_it_to_the_top() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": inv})
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	ui.open_panel(&"inventory", {"inventory": inv})
	assert_eq(ui.open_ids(), [&"crafting", &"inventory"])
	assert_eq(UIState.top(), &"inventory")
	ui.open_panel(&"inventory", {"inventory": inv})
	assert_eq(ui.open_ids(), [&"crafting", &"inventory"], "already on top: only refreshed")


func test_inventory_key_toggles() -> void:
	await _setup()
	_press(&"inventory")
	assert_eq(ui.top(), &"inventory")
	assert_eq(ui.get_panel(&"inventory").context.get("inventory"), inv, "player's inventory")
	_press(&"inventory")
	assert_eq(ui.open_ids(), [])
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	_press(&"inventory")
	assert_eq(ui.open_ids(), [&"crafting"], "I does nothing while another panel is open")


func test_interact_is_swallowed_while_modal() -> void:
	await _setup()
	_press(&"interact")
	assert_eq(player.interacts, 1, "E reaches the player without UI")
	ui.open_panel(&"inventory", {"inventory": inv})
	_press(&"interact")
	assert_eq(player.interacts, 1, "E consumed while a panel is open")
	ui.close_top_panel()
	_press(&"interact")
	assert_eq(player.interacts, 2)


func test_ui_state_clear_closes_everything() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": inv})
	ui.open_dialogue(&"carter", station)
	assert_eq(ui.open_ids(), [&"inventory", &"dialogue"])
	UIState.clear()
	assert_eq(ui.open_ids(), [])
	assert_false(ui.get_panel(&"inventory").visible)
	assert_false(ui.dialogue_box.visible)
	assert_false(ui.dialogue_box.is_active())
	assert_eq(_events, [&"carter"], "an aborted dialogue still ends")
	assert_false(UIState.is_modal())


func test_pause_menu_is_released_when_ui_is_freed() -> void:
	await _setup()
	ui.open_panel(&"pause", {})
	assert_true(tree.paused)
	ui.free()
	assert_false(tree.paused)
	assert_false(UIState.is_modal())


# --- HUD ------------------------------------------------------------------------------------

func test_hud_initial_values() -> void:
	await _setup()
	var hud := ui.hud
	assert_eq(hud.day_text(), "Tag 1")
	assert_eq(hud.clock_text(), "06:30")
	assert_false(hud.day_icon.night)
	assert_eq(hud.objective_text(), WAIT_TEXT)
	assert_eq(hud.resource_text(&"coin"), "5")
	assert_eq(hud.resource_text(&"wood"), "2")
	assert_eq(hud.resource_text(&"stone"), "0", "base resources always shown")
	assert_eq(hud.resource_text(&"linen"), "1")
	assert_eq(hud.resource_text(&"shroud"), "", "crafted items hidden at 0")
	assert_eq(hud.quality_text(), "0 · Verwahrlost")
	assert_eq(hud.prompt_text(), "")
	assert_false(hud.action_visible())
	assert_eq(hud.notice_text(), "")


func test_hud_clock_and_sun_moon_follow_time() -> void:
	await _setup()
	TimeManager.set_time(1, 1300)
	assert_eq(ui.hud.clock_text(), "21:40")
	assert_true(ui.hud.day_icon.night)
	TimeManager.set_time(2, 420)
	assert_eq(ui.hud.day_text(), "Tag 2")
	assert_eq(ui.hud.clock_text(), "07:00")
	assert_false(ui.hud.day_icon.night)


func test_hud_resources_follow_inventory() -> void:
	await _setup()
	inv.add_item(&"wood", 3)
	assert_eq(ui.hud.resource_text(&"wood"), "5")
	inv.add_item(&"shroud", 1)
	assert_eq(ui.hud.resource_text(&"shroud"), "1")
	inv.add_item(&"gravestone_simple", 2)
	assert_eq(ui.hud.resource_text(&"gravestone_simple"), "2")
	inv.remove_item(&"shroud", 1)
	assert_eq(ui.hud.resource_text(&"shroud"), "")
	inv.remove_item(&"coin", 5)
	assert_eq(ui.hud.resource_text(&"coin"), "0")


func test_hud_prompt_states() -> void:
	await _setup()
	var hud := ui.hud
	EventBus.interaction_focus_changed.emit("Grab ausheben (60 Min)", true)
	assert_eq(hud.prompt_text(), "Grab ausheben (60 Min)")
	assert_true(hud.prompt_enabled())
	assert_true(hud.prompt_key.visible)
	EventBus.interaction_focus_changed.emit("[E] Leiche aufnehmen", true)
	assert_eq(hud.prompt_text(), "Leiche aufnehmen", "leading [E] dropped – the keycap shows it")
	EventBus.interaction_focus_changed.emit("Hände frei nötig – [Q] ablegen", false)
	assert_eq(hud.prompt_text(), "Hände frei nötig – [Q] ablegen")
	assert_false(hud.prompt_enabled())
	assert_false(hud.prompt_key.visible, "dimmed: no key")
	assert_eq(hud.prompt_label.theme_type_variation, &"HudDimLabel")
	EventBus.interaction_focus_changed.emit("", false)
	assert_eq(hud.prompt_text(), "")
	assert_false(hud.prompt_panel.visible)


func test_hud_prompt_and_action_hidden_while_modal() -> void:
	await _setup()
	EventBus.interaction_focus_changed.emit("Holz nehmen (10 Min)", true)
	EventBus.timed_action_started.emit("Holz sammeln", 1.5)
	assert_true(ui.hud.action_visible())
	ui.open_panel(&"inventory", {"inventory": inv})
	assert_eq(ui.hud.prompt_text(), "")
	assert_false(ui.hud.action_visible(), "panels show their own progress")
	ui.close_top_panel()
	assert_eq(ui.hud.prompt_text(), "Holz nehmen (10 Min)")
	assert_true(ui.hud.action_visible())


func test_hud_timed_action_bar() -> void:
	await _setup()
	EventBus.timed_action_started.emit("Grab ausheben", 3.0)
	assert_true(ui.hud.action_visible())
	assert_eq(ui.hud.action_label.text, "Grab ausheben …")
	assert_almost(ui.hud.action_ratio(), 0.0)
	EventBus.timed_action_progress.emit(0.5)
	assert_almost(ui.hud.action_ratio(), 0.5)
	EventBus.timed_action_finished.emit(true)
	assert_false(ui.hud.action_visible())
	EventBus.timed_action_started.emit("Bestatten", 1.5)
	EventBus.timed_action_finished.emit(false)
	assert_false(ui.hud.action_visible(), "cancelled actions hide the bar too")


func test_hud_quality_and_next_tier() -> void:
	await _setup()
	var thresholds := (Database.config(&"economy_config") as EconomyConfig).rating_thresholds
	EventBus.cemetery_quality_changed.emit(thresholds[0], &"orderly")
	assert_eq(ui.hud.quality_text(), "%d · Ordentlich" % thresholds[0])
	assert_eq(ui.hud.next_tier_label.text, "Gepflegt ab %d" % thresholds[1])
	EventBus.cemetery_quality_changed.emit(50, &"dignified")
	assert_eq(ui.hud.quality_text(), "50 · Würdevoll")
	assert_eq(ui.hud.next_tier_label.text, "Ehrwürdig ab %d" % thresholds[3])
	EventBus.cemetery_quality_changed.emit(thresholds[3], &"venerable")
	assert_eq(ui.hud.quality_text(), "%d · Ehrwürdig" % thresholds[3])
	assert_false(ui.hud.next_tier_label.visible, "top tier: no next tier")


func test_hud_quality_pulled_from_graveyard() -> void:
	await _setup()
	graveyard.list = [_grave("plot_01", GraveRecord.State.MARKED, 9), _grave("plot_02", GraveRecord.State.MARKED, 8)]
	ui.hud.refresh_all()
	assert_eq(ui.hud.quality_text(), "17 · Ordentlich")


func test_hud_delivery_skipped_notice() -> void:
	await _setup()
	EventBus.delivery_skipped.emit(1, "Die Bahre ist noch belegt.")
	# UI-09: same wording as CorpseManager's notification of the same skip.
	assert_eq(ui.hud.notice_text(), "Heute keine Leiche: Die Bahre ist noch belegt.")
	EventBus.day_started.emit(1)
	assert_ne(ui.hud.notice_text(), "", "same day keeps it")
	EventBus.day_started.emit(2)
	assert_eq(ui.hud.notice_text(), "")


func test_hud_delivery_notice_restored_after_load() -> void:
	await _setup()
	GameState.set_flag(&"delivery_skipped", TimeManager.day)
	EventBus.game_loaded.emit(1)
	assert_ne(ui.hud.notice_text(), "")
	GameState.set_flag(&"delivery_skipped", TimeManager.day - 1)
	ui.hud.refresh_all()
	assert_eq(ui.hud.notice_text(), "", "skip of another day is not shown")


func test_hud_objective_follows_world_signals() -> void:
	await _setup()
	assert_eq(ui.hud.objective_text(), WAIT_TEXT)
	corpses.list = [_record(&"dropoff")]
	EventBus.corpse_arrived.emit("corpse_0001")
	await wait_frames(1)
	assert_eq(ui.hud.objective_text(), "Leiche zum Leichentisch bringen")
	corpses.list[0].location = &"table"
	EventBus.corpse_updated.emit("corpse_0001")
	await wait_frames(1)
	assert_eq(ui.hud.objective_text(), "Leiche untersuchen")
	corpses.list[0].location = &"buried"
	graveyard.list = [_grave("plot_01", GraveRecord.State.FILLED, 0)]
	EventBus.grave_state_changed.emit("plot_01", GraveRecord.State.FILLED)
	await wait_frames(1)
	assert_eq(ui.hud.objective_text(), "Grabzeichen setzen (Werkbank: Holzkreuz = 3 Holz)")
	inv.add_item(&"wooden_cross", 1)
	await wait_frames(1)
	assert_eq(ui.hud.objective_text(), "Grabzeichen setzen", "inventory changes refresh it")


func test_hud_rebinds_player_on_world_ready() -> void:
	await _setup()
	var other := FakePlayer.new()
	other.inventory = Inventory.new()
	other.add_child(other.inventory)
	other.inventory.add_item(&"coin", 42)
	player.remove_from_group(&"player")
	other.add_to_group(&"player")
	tree.root.add_child(other)
	EventBus.world_ready.emit(other)
	assert_eq(ui.player, other)
	assert_eq(ui.hud.resource_text(&"coin"), "42")
	inv.add_item(&"coin", 1)
	assert_eq(ui.hud.resource_text(&"coin"), "42", "old inventory disconnected")


func test_notifications_by_kind() -> void:
	await _setup()
	var notes := ui.notifications
	EventBus.notification_requested.emit("Gespeichert.", &"info")
	EventBus.notification_requested.emit("+1 Leinen", &"reward")
	EventBus.notification_requested.emit("Hier nicht ablegen.", &"warning")
	EventBus.notification_requested.emit("Seltsam", &"unknown_kind")
	EventBus.notification_requested.emit("   ", &"info")
	assert_eq(notes.texts(), PackedStringArray(["Gespeichert.", "+1 Leinen", "Hier nicht ablegen.", "Seltsam"]))
	assert_eq(notes.kinds(), [&"info", &"reward", &"warning", &"unknown_kind"])
	var styles: Array[StringName] = []
	for child: Node in notes.get_children():
		styles.append((child as Control).theme_type_variation)
	assert_eq(styles, [&"NoteInfo", &"NoteReward", &"NoteWarning", &"NoteInfo"])


func test_notifications_merge_limit_and_fade() -> void:
	await _setup()
	var notes := ui.notifications
	EventBus.notification_requested.emit("Hier nicht ablegen.", &"warning")
	EventBus.notification_requested.emit("Hier nicht ablegen.", &"warning")
	assert_eq(notes.texts().size(), 1, "repeat within the merge window refreshes")
	notes.clear()
	await wait_frames(1)
	for i: int in notes.max_entries + 2:
		notes.push("Meldung %d" % i)
	assert_eq(notes.texts().size(), notes.max_entries)
	assert_eq(notes.texts()[0], "Meldung 2", "oldest dropped first")
	notes.clear()
	await wait_frames(1)
	notes.lifetime = 0.05
	notes.fade_time = 0.05
	notes.push("Kurz")
	assert_eq(notes.texts(), PackedStringArray(["Kurz"]))
	await tree.create_timer(0.4).timeout
	assert_eq(notes.texts(), PackedStringArray([]), "faded out and removed")


func test_reward_card_breakdown_and_payment() -> void:
	await _setup()
	corpses.list = [_record(&"buried")]
	var card := ui.reward_card
	card.show_seconds = 0.05
	card.fade_time = 0.05
	var breakdown := [{"label": "Bestattet", "points": 2}, {"label": "Leichentuch", "points": 2},
			{"label": "Grabstein", "points": 3}, {"label": "Verwesend", "points": -1}]
	EventBus.grave_completed.emit("plot_01", "corpse_0001", 6, breakdown)
	assert_true(card.visible)
	assert_eq(card._subtitle.text, "Hedwig Rabenstein")
	assert_eq(card.line_texts(), PackedStringArray(["Bestattet +2", "Leichentuch +2", "Grabstein +3", "Verwesend −1"]))
	assert_eq(card.quality_text(), "6/10")
	assert_eq(card.payment_text(), "")
	EventBus.payment_received.emit(7, "Bestattung von Hedwig Rabenstein")
	assert_eq(card.payment_text(), "+7 Münzen")
	await tree.create_timer(0.4).timeout
	assert_false(card.visible, "hidden after show_seconds")
	EventBus.payment_received.emit(3, "anders")
	assert_false(card.visible, "a payment alone shows no card")


func test_reward_card_default_duration_is_four_seconds() -> void:
	await _setup()
	assert_almost(ui.reward_card.show_seconds, 4.0)


# --- inventory panel ------------------------------------------------------------------------

func test_inventory_panel_slots_coins_reputation() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": inv})
	var panel := ui.get_panel(&"inventory") as InventoryPanel
	var slots := panel.shown_slots()
	assert_eq(slots.size(), 16)
	assert_eq(slots[0], {"id": &"wood", "amount": 2})
	assert_eq(slots[1], {"id": &"linen", "amount": 1})
	assert_eq(slots[2], {})
	assert_eq(panel.coins_text(), "5", "coins outside the slots")
	assert_eq(panel.reputation_text(), "Verrufen –", "Phase 3: tier + trend arrow, no raw value")
	var first := panel._grid.get_child(0) as Control
	assert_true(first.tooltip_text.begins_with("Holz\n"), first.tooltip_text)
	assert_true(first.tooltip_text.contains("Scheite"), "description in the tooltip")
	inv.add_item(&"stone", 3)
	assert_eq(panel.shown_slots()[2], {"id": &"stone", "amount": 3}, "live refresh")
	GameState.add_stat(&"reputation", -3)
	panel.refresh()
	assert_eq(panel.reputation_text(), "Verrufen –")
	GameState.stats[&"reputation"] = 40
	panel.refresh()
	assert_eq(panel.reputation_text(), "Geachtet –")
	assert_true(panel._reputation.tooltip_text.begins_with("Ruf 40 von 100 · Geachtet"), panel._reputation.tooltip_text)
	ui.close_top_panel()
	inv.add_item(&"stone", 1)
	assert_false(inv.changed.is_connected(panel.refresh), "disconnected when closed")


# --- corpse exam ------------------------------------------------------------------------------

func test_corpse_exam_before_examination() -> void:
	await _setup()
	var panel := await _open_exam(_record(&"table"))
	assert_eq(panel.title_label.text, "Hedwig Rabenstein")
	assert_eq(panel.age_label.text, "67 Jahre")
	assert_eq(panel.cause_label.text, "Ertrunken im Mühlteich")
	assert_eq(panel.cause_text.text, CorpseExamPanel.TEXT_CAUSE_HIDDEN)
	assert_eq(panel.freshness_label.text, "Frisch · 81 %")
	assert_eq(panel.freshness_bar.theme_type_variation, &"FreshBar")
	assert_almost(panel.freshness_bar.value, 0.81)
	assert_eq(panel.shown_traits(), PackedStringArray([]), "traits hidden until examined")
	assert_eq(panel.findings_note.text, CorpseExamPanel.TEXT_TRAITS_HIDDEN)
	assert_false(panel.decision_box.visible)
	assert_eq(panel.examine_button.text, "Untersuchen (20 Min)")
	assert_false(panel.examine_button.disabled)
	assert_eq(panel.shroud_button.text, "Leichentuch anlegen (10 Min)")
	assert_true(panel.shroud_button.disabled, "no shroud in the inventory")
	assert_eq(panel.reason_label.text, "Kein Leichentuch im Inventar (Werkbank: 2 Leinen).")
	assert_false(panel.pick_up_button.disabled)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.examine_button, "safe default focus")
	panel.examine_button.pressed.emit()
	assert_eq(station.calls, ["examine"])


func test_corpse_exam_examined_with_valuables() -> void:
	await _setup()
	var record := _record(&"table")
	var panel := await _open_exam(record)
	record.examined = true
	EventBus.corpse_updated.emit(record.id)
	assert_eq(panel.cause_text.text, (Database.corpse_tables() as CorpseTables).get_cause(&"drowned_millpond").description)
	assert_eq(panel.shown_traits(), PackedStringArray(["valuables", "letter"]))
	assert_false(panel.findings_note.visible)
	assert_true(panel.decision_box.visible)
	assert_eq(panel.take_button.text, "Nehmen: +6 Münzen · Grabqualität −2 · Ruf sinkt")
	assert_eq(panel.leave_button.text, "Liegen lassen: Grabqualität +1")
	assert_true(panel.examine_button.disabled)
	assert_eq(panel.examine_button.text, "Untersucht")
	inv.add_item(&"shroud", 1)
	panel.refresh()
	assert_true(panel.shroud_button.disabled, "shroud blocked until decided")
	assert_eq(panel.reason_label.text, "Leichentuch: erst über die Wertsachen entscheiden.")
	panel.take_button.pressed.emit()
	panel.leave_button.pressed.emit()
	assert_eq(station.calls, [["decide", true], ["decide", false]])
	record.valuables_decision = &"taken"
	EventBus.corpse_updated.emit(record.id)
	assert_false(panel.decision_box.visible)
	assert_eq(panel.decided_label.text, "Wertsachen genommen (+6 Münzen).")
	assert_false(panel.shroud_button.disabled)
	panel.shroud_button.pressed.emit()
	assert_eq(station.calls.back(), "shroud")
	record.shrouded = true
	EventBus.corpse_updated.emit(record.id)
	assert_eq(panel.shroud_button.text, "Eingehüllt")
	assert_true(panel.shroud_button.disabled)


func test_corpse_exam_without_traits() -> void:
	await _setup()
	var record := _record(&"table")
	record.traits = []
	record.examined = true
	var panel := await _open_exam(record)
	assert_eq(panel.shown_traits(), PackedStringArray([]))
	assert_eq(panel.findings_note.text, CorpseExamPanel.TEXT_NO_TRAITS)
	assert_true(panel.findings_note.visible)
	assert_false(panel._traits_scroll.visible, "no empty scroll column")
	assert_false(panel.decision_box.visible)


func test_corpse_exam_buttons_disabled_during_action() -> void:
	await _setup()
	var panel := await _open_exam(_record(&"table"))
	EventBus.timed_action_started.emit("Untersuchen", 1.5)
	assert_true(panel.action_running)
	assert_true(panel.examine_button.disabled)
	assert_true(panel.shroud_button.disabled)
	assert_true(panel.pick_up_button.disabled)
	assert_eq(panel.reason_label.text, "Arbeit läuft …")
	assert_true(panel._action_box.visible, "own progress bar")
	EventBus.timed_action_progress.emit(0.5)
	assert_almost(panel._action_ratio(), 0.5)
	EventBus.timed_action_finished.emit(true)
	assert_false(panel.action_running)
	assert_false(panel.examine_button.disabled)
	assert_false(panel._action_box.visible)


func test_corpse_exam_opened_while_player_busy() -> void:
	await _setup()
	player.busy = true
	var panel := await _open_exam(_record(&"table"))
	assert_true(panel.examine_button.disabled)


func test_corpse_exam_pick_up_closes() -> void:
	await _setup()
	var record := _record(&"table")
	station.record = record
	var panel := await _open_exam(record)
	panel.pick_up_button.pressed.emit()
	assert_eq(station.calls, ["pick_up"])
	assert_false(ui.is_open(&"corpse_exam"))
	assert_false(UIState.is_modal())


func test_corpse_exam_closes_when_corpse_leaves() -> void:
	await _setup()
	var record := _record(&"table")
	await _open_exam(record)
	record.location = &"ground"
	EventBus.corpse_updated.emit(record.id)
	await wait_frames(2)
	assert_false(ui.is_open(&"corpse_exam"))
	assert_false(UIState.is_modal())


func test_corpse_exam_unknown_corpse_closes() -> void:
	await _setup()
	ui.open_panel(&"corpse_exam", {"corpse_id": "nobody", "table": station, "player": player})
	await wait_frames(2)
	assert_false(ui.is_open(&"corpse_exam"))


func test_corpse_exam_freshness_stages() -> void:
	await _setup()
	var record := _record(&"table")
	var panel := await _open_exam(record)
	record.freshness = 0.45
	EventBus.corpse_updated.emit(record.id)
	assert_eq(panel.freshness_label.text, "Welk · 45 %")
	assert_eq(panel.freshness_bar.theme_type_variation, &"WiltedBar")
	record.freshness = 0.2
	EventBus.time_tick.emit(1, 400)
	assert_eq(panel.freshness_label.text, "Verwesend · 20 %", "time ticks refresh the bar")
	assert_eq(panel.freshness_bar.theme_type_variation, &"DecayBar")


# --- crafting & marker ------------------------------------------------------------------------

func test_crafting_rows_have_need_and_reasons() -> void:
	await _setup()
	inv.add_item(&"wood", 1)
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	var grave_ids := panel.recipe_ids().filter(func(id: StringName) -> bool: return (Database.recipe(id) as RecipeData).category == &"grave")
	assert_eq(grave_ids, [&"shroud", &"wooden_cross", &"gravestone_simple"], "quick to slow (grave recipes)")
	assert_true(panel.craft_button(&"shroud").disabled)
	assert_eq(panel.reason_text(&"shroud"), "Fehlt: 1 Leinen")
	assert_false(panel.craft_button(&"wooden_cross").disabled)
	assert_eq(panel.reason_text(&"wooden_cross"), "")
	assert_eq(panel.reason_text(&"gravestone_simple"), "Fehlt: 4 Stein")
	panel.craft_button(&"wooden_cross").pressed.emit()
	assert_eq(station.calls, [&"wooden_cross"])
	panel.craft_button(&"shroud").pressed.emit()
	assert_eq(station.calls, [&"wooden_cross"], "a blocked recipe is never requested")
	inv.add_item(&"linen", 1)
	assert_false(panel.craft_button(&"shroud").disabled, "inventory changes refresh")


func test_crafting_disabled_while_busy() -> void:
	await _setup()
	inv.add_item(&"wood", 5)
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	EventBus.timed_action_started.emit("Holzkreuz herstellen", 1.5)
	assert_true(panel.craft_button(&"wooden_cross").disabled)
	assert_eq(panel.reason_text(&"wooden_cross"), "Arbeit läuft …")
	EventBus.timed_action_finished.emit(true)
	assert_false(panel.craft_button(&"wooden_cross").disabled)


func test_crafting_no_room() -> void:
	await _setup()
	inv.clear()
	inv.add_item(&"stone", 750)
	inv.add_item(&"wood", 50)
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	assert_true(panel.craft_button(&"wooden_cross").disabled)
	assert_eq(panel.reason_text(&"wooden_cross"), "Kein Platz im Inventar")


func test_marker_choice() -> void:
	await _setup()
	ui.open_panel(&"marker_choice", _contexts()[&"marker_choice"])
	var panel := ui.get_panel(&"marker_choice") as MarkerChoicePanel
	assert_eq(panel.options(), [&"wooden_cross", &"gravestone_simple"])
	assert_eq(panel.option_button(&"wooden_cross").text, "Holzkreuz   +1 Qualität")
	assert_eq(panel.option_button(&"gravestone_simple").text, "Grabstein   +3 Qualität")
	panel.option_button(&"gravestone_simple").pressed.emit()
	assert_eq(station.calls, [&"gravestone_simple"])
	assert_false(ui.is_open(&"marker_choice"), "closes after choosing")
	assert_false(UIState.is_modal())


# --- summaries & pause ----------------------------------------------------------------------

func test_day_summary() -> void:
	await _setup()
	ui.open_panel(&"day_summary", _contexts()[&"day_summary"])
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.title_label.text, "Tag 2 ist vorüber")
	assert_eq(panel.burials_label.text, "1")
	assert_eq(panel.coins_label.text, "+9")
	assert_eq(panel.total_label.text, "9 · Verwahrlost")
	assert_eq(DaySummaryPanel.rating_label("Gepflegt"), "Gepflegt", "labels pass through")


func test_slice_summary_goal() -> void:
	await _setup()
	ui.open_panel(&"slice_summary", _contexts()[&"slice_summary"])
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.days_label.text, "6")
	assert_eq(panel.burials_label.text, "6")
	assert_eq(panel.total_label.text, "48 · Würdevoll")
	assert_eq(panel.reputation_label.text, "Verrufen", "tier only (Phase 3)")
	assert_false(panel.decor_label.visible, "Phase-2 context: no decor row")
	var goal := (Database.config(&"economy_config") as EconomyConfig).rating_thresholds[2]
	var reached := "Ziel „Würdevoll“ (ab %d) erreicht." % goal
	assert_eq(panel.goal_label.text, reached if 48 >= goal else "Ziel „Würdevoll“ (ab %d) verfehlt – es fehlen %d Punkte." % [goal, goal - 48])
	ui.open_panel(&"slice_summary", {"days": 7, "burials": 6, "total": goal - 5, "rating": &"tended", "reputation": -1})
	assert_eq(panel.goal_label.text, "Ziel „Würdevoll“ (ab %d) verfehlt – es fehlen 5 Punkte." % goal)


func test_pause_menu_without_world_or_saves() -> void:
	await _setup()
	SaveManager.save_dir = TEST_SAVE_DIR
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	assert_true(menu.save_button.disabled, "no world: cannot save")
	assert_true(menu.load_button.disabled, "no saves")
	assert_eq(menu.slot_buttons[0].text, "Autosave – leer")
	assert_eq(menu.slot_buttons[1].text, "Schnellspeicher – leer")
	assert_true(menu.slot_buttons[0].disabled)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), menu.resume_button)
	menu.resume_button.pressed.emit()
	assert_eq(ui.open_ids(), [])
	assert_false(tree.paused)


func test_pause_menu_slot_info() -> void:
	await _setup()
	SaveManager.save_dir = TEST_SAVE_DIR
	TimeManager.set_time(2, 360)
	assert_eq(SaveManager.save_game(0), OK)
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	assert_eq(menu.slot_buttons[0].text, "Autosave – Tag 2, 06:00")
	assert_false(menu.slot_buttons[0].disabled)
	assert_true(menu.slot_buttons[1].disabled)
	assert_false(menu.load_button.disabled)
	menu.load_button.pressed.emit()
	assert_true(menu._load_box.visible)
	assert_false(menu._main_box.visible)
	assert_eq(PauseMenu.slot_text({"exists": true, "day": 3, "minute_of_day": 865}), "Tag 3, 14:25")
	assert_eq(PauseMenu.slot_text({"exists": false}), "leer")


func test_pause_menu_confirms_quit() -> void:
	await _setup()
	var quits := [0]
	ui.quit_handler = func() -> void: quits[0] += 1
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	menu.quit_button.pressed.emit()
	assert_eq(quits[0], 0, "first press only asks")
	assert_true(menu.quit_button.text.contains("wirklich"))
	menu.title_button.pressed.emit()
	assert_false(menu.quit_button.text.contains("wirklich"), "another button resets the question")
	menu.quit_button.pressed.emit()
	menu.quit_button.pressed.emit()
	assert_eq(quits[0], 1)


func test_pause_save_refused_without_world() -> void:
	await _setup()
	SaveManager.save_dir = TEST_SAVE_DIR
	ui.open_panel(&"pause", {})
	var menu := ui.get_panel(&"pause") as PauseMenu
	menu._on_save_pressed()
	assert_eq(menu.status_label.text, "Speichern gerade nicht möglich.")
	assert_true(menu.status_label.visible)
	assert_false(SaveManager.has_save(1))


# --- dialogue -------------------------------------------------------------------------------

func test_dialogue_walks_carter_with_fake_inventory() -> void:
	await _setup()
	GameState.stats[&"reputation"] = 25  # Phase-3 new-game value; below 15 Osric remarks on "Verrufen" (P6)
	var fake := FakeInventory.new()
	fake.add_item(&"coin", 5)
	tree.root.add_child(fake)
	player.inventory = fake
	ui.player = player
	EventBus.dialogue_requested.emit(&"carter", station)
	var box := ui.dialogue_box
	assert_true(box.is_active())
	assert_true(box.visible)
	assert_eq(UIState.top(), &"dialogue")
	assert_eq(ui.top(), &"dialogue")
	assert_false(ui.dim.visible, "no dim behind the dialogue")
	assert_eq(box.speaker_label.text, "Osric Faulhaber")
	assert_true(box.current_text().begins_with("Sieh an"))
	assert_true(GameState.has_flag(&"met_carter"), "node actions ran")
	assert_eq(box.choice_texts(), PackedStringArray(["Was macht ein Grab denn würdig?"]))
	box.choose(0)
	assert_eq(box.choice_texts().size(), 2)
	box.choose(1)
	assert_eq(box.current_text(), "Also – was brauchst du?", "skipped/rep remarks fall through to the menu")
	assert_eq(box.choice_texts().size(), 4)
	box.choose(0)
	assert_eq(box.choice_texts(), PackedStringArray(["Eine Elle, bitte. (3 Münzen)", "Heute nicht."]), "6 coins not affordable")
	box.choose(0)
	assert_eq(fake.count(&"coin"), 2)
	assert_eq(fake.count(&"linen"), 1)
	assert_eq(box.choice_texts(), PackedStringArray(["Danke."]))
	box.choose(0)
	box.choose(3)
	assert_true(box.current_text().begins_with("Ich muss weiter"), "morning goodbye")
	assert_eq(_events, [])
	box.choose(0)
	assert_false(box.is_active())
	assert_false(box.visible)
	assert_eq(_events, [&"carter"], "dialogue_ended at the end")
	assert_false(UIState.is_modal())
	assert_eq(ui.open_ids(), [])


func test_dialogue_choice_keys() -> void:
	await _setup()
	GameState.stats[&"reputation"] = 25  # Phase-3 new-game value; below 15 Osric remarks on "Verrufen" (P6)
	ui.open_dialogue(&"carter", station)
	_press(&"dialogue_choice_1")
	assert_eq(ui.dialogue_box.choice_texts().size(), 2, "key 1 picked the only choice")
	_press(&"dialogue_choice_4")
	assert_eq(ui.dialogue_box.choice_texts().size(), 2, "no fourth choice: ignored")
	_press(&"dialogue_choice_2")
	assert_eq(ui.dialogue_box.current_text(), "Also – was brauchst du?")


func test_dialogue_esc_ends_instead_of_pausing() -> void:
	await _setup()
	ui.open_dialogue(&"carter", station)
	_press(&"pause")
	assert_false(ui.dialogue_box.is_active())
	assert_eq(_events, [&"carter"])
	assert_eq(ui.open_ids(), [])
	assert_false(tree.paused)


func test_dialogue_unknown_id_ends_immediately() -> void:
	await _setup()
	EventBus.dialogue_requested.emit(&"nobody", station)
	assert_false(ui.dialogue_box.is_active())
	assert_eq(_events, [&"nobody"])
	assert_false(UIState.is_modal())


func test_second_dialogue_is_ignored() -> void:
	await _setup()
	ui.open_dialogue(&"carter", station)
	ui.open_dialogue(&"carter", station)
	assert_eq(ui.open_ids(), [&"dialogue"])
	ui.close_top_panel()
	assert_eq(_events, [&"carter"])


func test_panel_over_dialogue_returns_to_it() -> void:
	await _setup()
	ui.open_dialogue(&"carter", station)
	ui.open_panel(&"inventory", {"inventory": inv})
	assert_false(ui.dialogue_box.visible)
	_press(&"pause")
	assert_eq(ui.open_ids(), [&"dialogue"])
	assert_true(ui.dialogue_box.visible)


# --- debug console --------------------------------------------------------------------------

func test_debug_parse_clock() -> void:
	var cases := {"07:30": 450, "7:30": 450, "00:00": 0, "23:59": 1439, "24:00": -1, "07:60": -1,
			"0730": -1, "-1:00": -1, "07:5": -1, "ab:cd": -1, "": -1, "7:30:00": -1, "123:00": -1}
	for text: String in cases:
		assert_eq(DebugConsole.parse_clock(text), cases[text], text)


func test_debug_time_and_day() -> void:
	assert_true(_ok("time 07:30"))
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 450])
	assert_true(_ok("time 06:00"), "earlier = next day")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_true(_ok("day +1"))
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [3, 360])
	assert_true(_ok("day 2"))
	assert_eq(TimeManager.day, 5)
	for bad: String in ["time", "time 25:00", "time 07:30 08:00", "day +0", "day +31", "day x", "day +1 +2"]:
		assert_false(_ok(bad), bad)
	assert_eq(TimeManager.day, 5, "errors change nothing")


func test_debug_pause_toggle() -> void:
	assert_false(TimeManager.paused)
	assert_true(_ok("pause"))
	assert_true(TimeManager.paused)
	assert_true(_ok("pause"))
	assert_false(TimeManager.paused)
	assert_false(_ok("pause now"))


func test_debug_commands_without_world() -> void:
	for command: String in ["give wood 5", "spawn corpse", "npc carter here", "tp hut", "save", "quality", "instant on"]:
		var result := Debug.execute(command)
		assert_false(result.ok, command)
		assert_true(String(result.text).contains("Keine Spielwelt") or String(result.text).contains("Spieler"), command + ": " + String(result.text))
	assert_false(_ok("camera ortho"), "no camera rig")


func test_debug_give() -> void:
	await _setup()
	assert_true(_ok("give wood 5"))
	assert_eq(inv.count(&"wood"), 7)
	assert_true(_ok("give LINEN"))
	assert_eq(inv.count(&"linen"), 2, "default 1, id case-insensitive")
	for bad: String in ["give", "give moss 1", "give wood 0", "give wood abc", "give wood 1000", "give wood 1 2"]:
		assert_false(_ok(bad), bad)
	assert_eq(inv.count(&"wood"), 7)
	assert_true(String(Debug.execute("give moss").text).contains("wooden_cross"), "lists the item ids")


func test_debug_spawn_corpse() -> void:
	await _setup()
	var dropoff := FakeDropoff.new()
	dropoff.add_to_group(&"dropoff")
	tree.root.add_child(dropoff)
	assert_true(_ok("spawn corpse"))
	assert_eq(corpses.spawned[0], [dropoff.slot_transform(), &"dropoff"])
	dropoff.free_slot = false
	assert_true(_ok("spawn corpse"))
	assert_eq(corpses.spawned[1], [player.drop_xform, &"ground"], "bier taken: next to the player")
	player.drop_xform = Transform3D()
	assert_false(_ok("spawn corpse"), "no room anywhere")
	assert_false(_ok("spawn ghost"))
	assert_eq(corpses.spawned.size(), 2)


func test_debug_npc_carter_here() -> void:
	await _setup()
	var npc := FakeNpc.new()
	npc.add_to_group(&"npc")
	tree.root.add_child(npc)
	npc.global_position = Vector3(3.0, 0.0, 10.0)
	var result := Debug.execute("npc carter here")
	assert_true(result.ok, String(result.text))
	assert_eq(TimeManager.minute_of_day, 460, "home at 06:30 → time set to his 07:40 arrival")
	assert_eq(TimeManager.day, 1)
	result = Debug.execute("npc carter here")
	assert_true(result.ok)
	assert_eq(player.global_position, Vector3(3.0, 0.0, 10.0 + DebugConsole.NPC_OFFSET), "present: player moved next to him")
	assert_eq(TimeManager.minute_of_day, 460, "no further time skip")
	assert_false(_ok("npc ghost here"))
	assert_false(_ok("npc carter"))


func test_debug_npc_prefers_its_own_teleport() -> void:
	await _setup()
	var npc := TeleportNpc.new()
	npc.add_to_group(&"npc")
	tree.root.add_child(npc)
	TimeManager.set_time(1, 470)
	assert_true(_ok("npc carter here"))
	assert_eq(npc.teleports.size(), 1, "the NPC's own debug_teleport is used")


class TeleportNpc extends Node3D:
	var npc_id: StringName = &"carter"
	var teleports: Array = []

	func debug_teleport(pos: Vector3) -> void:
		teleports.append(pos)


func test_debug_tp() -> void:
	await _setup()
	var world := FakeWorld.new()
	tree.root.add_child(world)
	var hut := Node3D.new()
	hut.name = "hut_door"
	world.add_child(hut)
	hut.global_position = Vector3(-4.0, 0.0, -6.0)
	assert_true(_ok("tp hut"))
	assert_eq(player.global_position, hut.global_position + DebugConsole.TP_ENTITY_OFFSET)
	assert_true(_ok("tp road"))
	assert_eq(player.global_position, Vector3(0.0, 0.0, 18.0))
	assert_false(_ok("tp table"), "entity missing in this world")
	assert_false(_ok("tp moon"))
	assert_false(_ok("tp"))


func test_debug_save_and_load_validation() -> void:
	await _setup()
	SaveManager.save_dir = TEST_SAVE_DIR
	player.busy = true
	assert_false(_ok("save"), "action running")
	player.busy = false
	assert_true(_ok("save"))
	assert_true(SaveManager.has_save(1))
	assert_true(_ok("save 2"))
	assert_true(SaveManager.has_save(2))
	assert_false(_ok("save -1"))
	assert_false(_ok("load 7"), "empty slot")
	assert_false(_ok("load x"))


func test_debug_camera() -> void:
	var rig := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	tree.root.add_child(rig)
	assert_true(_ok("camera ortho"))
	assert_true(rig.orthographic)
	assert_true(_ok("camera ortho"), "already ortho: stays")
	assert_true(rig.orthographic)
	assert_true(_ok("camera persp"))
	assert_false(rig.orthographic)
	assert_true(_ok("camera"))
	assert_true(rig.orthographic, "no argument toggles")
	assert_false(_ok("camera fish"))


func test_debug_flags_quality_fps_instant() -> void:
	await _setup()
	GameState.set_flag(&"met_carter")
	GameState.add_stat(&"burials", 2)
	var flags := Debug.execute("flags")
	assert_true(String(flags.text).contains("met_carter = true"))
	assert_true(String(flags.text).contains("burials = 2"))
	assert_true(_ok("flags clear"))
	assert_true(GameState.flags.is_empty())
	assert_eq(GameState.get_stat(&"burials"), 2, "stats stay")
	assert_false(_ok("flags wipe"))
	graveyard.list = [_grave("plot_01", GraveRecord.State.MARKED, 9), _grave("plot_02", GraveRecord.State.EMPTY, 0)]
	graveyard.list[0].marker_id = &"wooden_cross"
	var quality := String(Debug.execute("quality").text)
	assert_true(quality.contains("Friedhofsqualität 9 · Verwahrlost"), quality)
	assert_true(quality.contains("plot_01: MARKED Qualität 9 (Holzkreuz)"), quality)
	assert_true(quality.contains("plot_02: EMPTY"), quality)
	assert_true(_ok("fps"))
	assert_true(Debug.fps_panel.visible)
	assert_true(_ok("fps"))
	assert_false(Debug.fps_panel.visible)
	assert_true(_ok("instant on"))
	assert_true(player.instant_actions)
	assert_true(_ok("instant"))
	assert_false(player.instant_actions, "toggle")
	assert_false(_ok("instant maybe"))


func test_debug_help_and_unknown() -> void:
	var help := String(Debug.execute("help").text)
	for command: String in ["time HH:MM", "day +N", "pause", "give <item>", "spawn corpse", "npc carter here", "tp <gate|hut|road|workbench|table|east|north>",
			"save [slot]", "load [slot]", "camera ortho|persp", "flags clear", "quality", "fps", "instant on|off"]:
		assert_true(help.contains(command), command)
	var result := Debug.execute("dance")
	assert_false(result.ok)
	assert_true(String(result.text).contains("'help'"))
	assert_true(Debug.log_text().contains("> dance"), "commands are echoed in the log")
	assert_false(Debug.execute("   ").ok)


func test_debug_toggle_is_modal() -> void:
	await _setup()
	_press(&"debug_toggle")
	assert_true(Debug.is_open())
	assert_true(UIState.is_open(&"debug"))
	assert_true(Debug.panel.visible)
	_press(&"inventory")
	assert_eq(ui.open_ids(), [], "UI ignores keys while the console is on top")
	_press(&"pause")
	assert_false(Debug.is_open(), "Esc closes the console")
	assert_eq(ui.open_ids(), [], "… without opening the pause menu")
	assert_false(tree.paused)
	_press(&"debug_toggle")
	_press(&"debug_toggle")
	assert_false(Debug.is_open())
	assert_false(UIState.is_modal())


func test_debug_disabled_without_debug_flag() -> void:
	GameConfig.debug_enabled = false
	_press(&"debug_toggle")
	assert_false(Debug.is_open())
	assert_false(Debug.open())
	assert_false(UIState.is_modal())
	GameConfig.debug_enabled = true
	assert_true(Debug.open())
	EventBus.debug_mode_changed.emit(false)
	assert_false(Debug.is_open(), "switching debug off closes it")
	assert_false(UIState.is_modal())


func test_debug_follows_ui_state_clear() -> void:
	Debug.open()
	UIState.clear()
	assert_false(Debug.is_open())
	assert_false(Debug.panel.visible)


func test_debug_quick_buttons_run_commands() -> void:
	var buttons := Debug.panel.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), DebugConsole.QUICK_COMMANDS.size())
	for entry: Array in DebugConsole.QUICK_COMMANDS:
		assert_true(String(entry[1]).split(" ")[0] in ["time", "day", "pause", "spawn", "npc", "give", "instant", "save", "load", "camera", "flags", "quality", "fps", "help"], str(entry))
	(buttons[0] as Button).pressed.emit()
	assert_eq(TimeManager.minute_of_day, 450, "07:30 button")


# --- review fixes (cluster C) ---------------------------------------------------------------

## UI-09: one term for the cemetery value in HUD, summaries and debug.
func test_hud_uses_the_same_quality_term() -> void:
	await _setup()
	assert_eq(ui.hud.quality_caption_text(), DaySummaryPanel.TEXT_TOTAL)
	assert_eq(ui.hud.quality_caption_text(), "Friedhofsqualität")
	assert_eq(SliceSummaryPanel.TEXT_TOTAL, DaySummaryPanel.TEXT_TOTAL)
	EventBus.delivery_skipped.emit(1, "")
	assert_true(ui.hud.notice_text().begins_with("Heute keine Leiche"), ui.hud.notice_text())


## UI-08: linen and shroud chips differ by more than the (similar) cloth icons.
func test_hud_linen_and_shroud_are_distinguishable() -> void:
	await _setup()
	inv.add_item(&"shroud", 1)
	assert_eq(ui.hud.resource_text(&"linen"), "1")
	assert_eq(ui.hud.resource_text(&"shroud"), "1")
	assert_eq(ui.hud.resource_caption(&"shroud"), "Leichentuch", "crafted chips carry their name")
	assert_eq(ui.hud.resource_caption(&"wooden_cross"), "", "hidden chip: no caption")
	assert_ne(ui.hud.resource_caption(&"linen"), ui.hud.resource_caption(&"shroud"))
	inv.add_item(&"wooden_cross", 1)
	assert_eq(ui.hud.resource_caption(&"wooden_cross"), "Holzkreuz")
	await wait_frames(2)
	var resources := (ui.hud.get_node("ResourcePanel") as Control).get_global_rect()
	assert_true(resources.end.y < ui.notifications.get_global_rect().position.y, "captions keep the notifications free")


## UI-03: the reward card never covers a modal panel – it waits and shows afterwards.
func test_reward_card_waits_while_a_modal_is_open() -> void:
	await _setup()
	var ctx := _contexts()[&"slice_summary"]
	corpses.list = [_record(&"buried")]
	var card := ui.reward_card
	card.show_seconds = 0.1
	card.fade_time = 0.05
	var breakdown := [{"label": "Bestattet", "points": 2}]
	EventBus.grave_completed.emit("plot_06", "corpse_0001", 8, breakdown)
	assert_true(card.visible)
	ui.open_panel(&"slice_summary", ctx)
	assert_false(card.visible, "hidden while the modal is open")
	EventBus.payment_received.emit(7, "Bestattung")
	await tree.create_timer(0.4).timeout
	assert_false(card.visible)
	ui.close_panel(&"slice_summary")
	assert_true(card.visible, "shown again once the modal closed")
	assert_eq(card.payment_text(), "+7 Münzen", "payment kept while hidden")
	await tree.create_timer(0.4).timeout
	assert_false(card.visible, "then fades normally")
	# Completed while a modal is already open: shown only after it closed.
	ui.open_panel(&"pause", {})
	EventBus.grave_completed.emit("plot_05", "corpse_0001", 6, breakdown)
	assert_false(card.visible)
	ui.close_panel(&"pause")
	assert_true(card.visible)
	assert_eq(card.quality_text(), "6/10")


## UI-06: the reward card sits in a free screen area – not over the centred player and the
## grave above them, and not over the HUD panels or the notification column.
func test_reward_card_leaves_player_and_hud_free() -> void:
	# The headless window is not 16:9; lay the UI out at the base resolution of the game.
	var size_before := tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	await _check_reward_card_placement()
	tree.root.size = size_before


func _check_reward_card_placement() -> void:
	await _setup()
	corpses.list = [_record(&"buried")]
	EventBus.grave_completed.emit("plot_01", "corpse_0001", 9,
			[{"label": "Bestattet", "points": 2}, {"label": "Leichentuch", "points": 2}, {"label": "Grabstein", "points": 3},
			{"label": "Frisch", "points": 1}, {"label": "Untersucht", "points": 1}])
	EventBus.payment_received.emit(7, "Bestattung")
	await wait_frames(2)
	var card := ui.reward_card.get_global_rect()
	var screen := ui.root_control.get_global_rect()
	assert_true(screen.encloses(card), "on screen: %s in %s" % [card, screen])
	var centre := screen.get_center()
	# The camera centres the player; the plot being worked on is just above them on screen.
	var player_and_grave := Rect2(centre.x - 200.0, centre.y - 280.0, 400.0, 400.0)
	assert_false(card.intersects(player_and_grave), "card %s over the player/grave %s" % [card, player_and_grave])
	for panel_name: String in ["ClockPanel", "ResourcePanel"]:
		var hud_rect := (ui.hud.get_node(panel_name) as Control).get_global_rect()
		assert_false(card.intersects(hud_rect), "card over %s" % panel_name)
	var notes := ui.notifications.get_global_rect()
	notes.size.y = maxf(notes.size.y, 400.0)
	assert_false(card.intersects(notes), "card over the notification column")


## UI-05: after an action disables the focused button, focus moves to an enabled control.
func test_corpse_exam_focus_after_examine() -> void:
	await _setup()
	var record := _record(&"table")
	var panel := await _open_exam(record)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.examine_button)
	# Order as in Player._complete_action: timed_action_finished, then on_done.
	EventBus.timed_action_started.emit("Untersuchen", 1.5)
	EventBus.timed_action_finished.emit(true)
	record.examined = true
	EventBus.corpse_updated.emit(record.id)
	await wait_frames(2)
	var focused := ui.get_viewport().gui_get_focus_owner() as Button
	assert_not_null(focused, "focus kept inside the panel")
	if focused == null:
		return
	assert_true(panel.is_ancestor_of(focused))
	assert_false(focused.disabled, "focus on an enabled button, not '%s'" % focused.text)
	assert_ne(focused, panel.take_button, "never on the irreversible valuables buttons")
	assert_ne(focused, panel.leave_button)


## UI-05: crafting rebuilds its rows – focus returns to the same recipe (or a sensible control).
func test_crafting_focus_survives_the_rebuild() -> void:
	await _setup()
	inv.add_item(&"wood", 5)
	inv.add_item(&"linen", 1)
	ui.open_panel(&"crafting", _contexts()[&"crafting"])
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	assert_false(panel.craft_button(&"shroud").disabled, "an earlier enabled row exists")
	panel.craft_button(&"wooden_cross").grab_focus()
	panel.craft_button(&"wooden_cross").pressed.emit()
	EventBus.timed_action_started.emit("Holzkreuz herstellen", 1.5)
	EventBus.timed_action_finished.emit(true)
	inv.remove_item(&"wood", 3)
	inv.add_item(&"wooden_cross", 1)
	await wait_frames(2)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.craft_button(&"wooden_cross"), "same recipe again")
	inv.remove_item(&"wood", 4)
	await wait_frames(2)
	var focused := ui.get_viewport().gui_get_focus_owner() as Button
	assert_not_null(focused, "focus not lost")
	if focused == null:
		return
	assert_true(panel.is_ancestor_of(focused))
	assert_false(focused.disabled)


# --- helpers --------------------------------------------------------------------------------

func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.add_to_group(&"player")
	inv = Inventory.new()
	inv.name = "Inventory"
	player.add_child(inv)
	player.inventory = inv
	tree.root.add_child(player)
	inv.add_item(&"coin", 5)
	inv.add_item(&"wood", 2)
	inv.add_item(&"linen", 1)
	corpses = FakeCorpseManager.new()
	corpses.add_to_group(&"corpse_manager")
	tree.root.add_child(corpses)
	graveyard = FakeGraveyard.new()
	graveyard.add_to_group(&"graveyard")
	tree.root.add_child(graveyard)
	station = FakeStation.new()
	tree.root.add_child(station)
	ui = await add_scene(UI_SCENE) as UIRoot


func _contexts() -> Dictionary[StringName, Dictionary]:
	corpses.list = [_record(&"table")]
	return {
		&"inventory": {"inventory": inv},
		&"corpse_exam": {"corpse_id": "corpse_0001", "table": station, "player": player},
		&"crafting": {"station": &"workbench", "inventory": inv, "workbench": station, "player": player},
		&"marker_choice": {"grave_id": "plot_01", "plot": station, "options": [&"wooden_cross", "gravestone_simple"]},
		&"day_summary": {"day": 2, "burials_today": 1, "coins_today": 9, "total": 9, "rating": &"neglected"},
		&"slice_summary": {"days": 6, "burials": 6, "total": 48, "rating": &"dignified", "reputation": 0},
		&"pause": {},
	}


func _open_exam(record: CorpseRecord) -> CorpseExamPanel:
	corpses.list = [record]
	ui.open_panel(&"corpse_exam", {"corpse_id": record.id, "table": station, "player": player})
	await wait_frames(1)
	return ui.get_panel(&"corpse_exam") as CorpseExamPanel


func _record(location: StringName) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = "corpse_0001"
	r.display_name = "Hedwig Rabenstein"
	r.age = 67
	r.cause_id = &"drowned_millpond"
	r.traits = [&"valuables", &"letter"]
	r.valuables_coins = 6
	r.freshness = 0.81
	r.location = location
	return r


func _grave(id: String, state: GraveRecord.State, quality: int) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = id
	g.state = state
	g.quality = quality
	return g


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		tree.root.push_input(ev)


func _ok(command: String) -> bool:
	return bool(Debug.execute(command).ok)


func _on_dialogue_ended(dialogue_id: StringName) -> void:
	_events.append(dialogue_id)
