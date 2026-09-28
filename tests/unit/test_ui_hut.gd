extends TestCase
## Change round 2 (docs §11): the hut's chest panel (&"chest", ChestTransfer rules: atomic,
## partial fit, full target, coins stay, changed-signal counts) and the grave register
## (&"grave_register": entries, empty state, footer, scrolling), both opened through
## EventBus.ui_panel_requested in UIRoot with real Inventory nodes and Database items.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class FakePlayer extends Node3D:
	var inventory: Inventory

	func is_busy() -> bool:
		return false


class FakeChest extends Node3D:
	pass


var ui: UIRoot
var player: FakePlayer
var bag: Inventory
var storage: Inventory
var chest: FakeChest
var _notes: Array = []
var _changes: Dictionary = {}


func before_each() -> void:
	_notes.clear()
	_changes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	tree.paused = false


# --- ChestTransfer (pure rules) -------------------------------------------------------------

func test_transfer_moves_a_whole_stack_with_one_change_each() -> void:
	var a := _inv(&"a", 16, [[&"wood", 7], [&"stone", 3]])
	var b := _inv(&"b", 16, [])
	_count_changes(a)
	_count_changes(b)
	assert_eq(ChestTransfer.move_slot(a, b, 0), 7)
	assert_eq(a.count(&"wood"), 0)
	assert_eq(b.count(&"wood"), 7)
	assert_eq(a.count(&"stone"), 3, "other stacks untouched")
	assert_eq(_changes[&"a"], 1, "source changed exactly once")
	assert_eq(_changes[&"b"], 1, "target changed exactly once")


func test_transfer_partial_fit_leaves_the_rest_in_the_source() -> void:
	var a := _inv(&"a", 16, [[&"wood", 10]])
	var b := _inv(&"b", 1, [[&"wood", 45]])
	_count_changes(a)
	_count_changes(b)
	assert_eq(ChestTransfer.fit(b, &"wood", 10), 5)
	assert_eq(ChestTransfer.move(a, b, &"wood", 10), 5, "only what fits moves")
	assert_eq(a.count(&"wood"), 5, "the rest stays")
	assert_eq(b.count(&"wood"), 50)
	assert_eq(a.count(&"wood") + b.count(&"wood"), 55, "nothing lost")
	assert_eq(_changes[&"a"], 1)
	assert_eq(_changes[&"b"], 1)


func test_transfer_into_a_full_target_changes_nothing() -> void:
	var a := _inv(&"a", 16, [[&"wood", 10]])
	var b := _inv(&"b", 1, [[&"stone", 50]])
	_count_changes(a)
	_count_changes(b)
	assert_eq(ChestTransfer.fit(b, &"wood", 10), 0)
	assert_eq(ChestTransfer.move_slot(a, b, 0), 0)
	assert_eq(ChestTransfer.move_all(a, b), 0)
	assert_eq(a.count(&"wood"), 10)
	assert_eq(b.count(&"stone"), 50)
	assert_eq(_changes[&"a"], 0, "no signal for a refused move")
	assert_eq(_changes[&"b"], 0)
	assert_false(ChestTransfer.can_move_any(a, b))


func test_transfer_never_moves_currency() -> void:
	var a := _inv(&"a", 16, [[&"coin", 14], [&"linen", 2]])
	var b := _inv(&"b", 16, [])
	_count_changes(a)
	_count_changes(b)
	assert_false(ChestTransfer.is_transferable(&"coin"))
	assert_false(ChestTransfer.is_transferable(&"no_such_item"))
	assert_false(ChestTransfer.is_transferable(&""))
	assert_true(ChestTransfer.is_transferable(&"wood"))
	assert_eq(ChestTransfer.move(a, b, &"coin", 5), 0)
	assert_eq(ChestTransfer.item_ids(a), [&"linen"], "coins have no slot and are skipped")
	assert_eq(ChestTransfer.move_all(a, b), 2)
	assert_eq(a.count(&"coin"), 14, "coins stay with the player")
	assert_eq(b.count(&"coin"), 0)
	assert_eq(_changes[&"a"], 1, "only the linen move changed the source")


func test_transfer_single_item_and_bad_slots() -> void:
	var a := _inv(&"a", 4, [[&"stone", 3]])
	var b := _inv(&"b", 4, [])
	assert_eq(ChestTransfer.move_slot(a, b, 0, true), 1)
	assert_eq(a.count(&"stone"), 2)
	assert_eq(b.count(&"stone"), 1)
	assert_eq(ChestTransfer.move_slot(a, b, 3), 0, "empty slot")
	assert_eq(ChestTransfer.move_slot(a, b, 9), 0, "out of range")
	assert_eq(ChestTransfer.move_slot(a, b, -1), 0)
	assert_eq(ChestTransfer.slot_at(a, 0), {"id": &"stone", "amount": 2})
	assert_eq(ChestTransfer.slot_at(a, 7), {})


func test_transfer_clamps_to_what_the_source_holds() -> void:
	var a := _inv(&"a", 4, [[&"linen", 2]])
	var b := _inv(&"b", 4, [])
	assert_eq(ChestTransfer.move(a, b, &"linen", 99), 2)
	assert_eq(ChestTransfer.move(a, b, &"linen", 1), 0, "nothing left")
	assert_eq(ChestTransfer.move(a, b, &"linen", 0), 0)
	assert_eq(ChestTransfer.move(a, b, &"linen", -3), 0)
	assert_eq(b.count(&"linen"), 2)


func test_transfer_rejects_same_or_missing_inventories() -> void:
	var a := _inv(&"a", 4, [[&"wood", 5]])
	_count_changes(a)
	assert_eq(ChestTransfer.move(a, a, &"wood", 5), 0)
	assert_eq(ChestTransfer.move_all(a, a), 0)
	assert_eq(ChestTransfer.move(a, null, &"wood", 5), 0)
	assert_eq(ChestTransfer.move(null, a, &"wood", 5), 0)
	assert_eq(ChestTransfer.move_all(null, a), 0)
	assert_false(ChestTransfer.can_move_any(a, a))
	assert_eq(ChestTransfer.fit(null, &"wood", 5), 0)
	assert_eq(a.count(&"wood"), 5)
	assert_eq(_changes[&"a"], 0)


func test_transfer_move_all_takes_what_fits_in_slot_order() -> void:
	var a := _inv(&"a", 16, [[&"wood", 60], [&"stone", 5], [&"linen", 2]])
	var b := _inv(&"b", 2, [])
	_count_changes(a)
	_count_changes(b)
	assert_true(ChestTransfer.can_move_any(a, b))
	assert_eq(ChestTransfer.move_all(a, b), 60, "wood fills both chest slots (50 + 10)")
	assert_eq(b.count(&"wood"), 60)
	assert_eq(a.count(&"stone"), 5, "no room left – stone stays")
	assert_eq(a.count(&"linen"), 2)
	assert_eq(_changes[&"a"], 1, "one change per moved item kind")
	assert_eq(_changes[&"b"], 1)
	assert_false(ChestTransfer.can_move_any(a, b))


func test_transfer_fit_matches_can_add() -> void:
	var b := _inv(&"b", 3, [[&"wooden_cross", 3], [&"stone", 50]])
	# wooden_cross max_stack 5: 2 more in its stack + 5 in the free slot.
	assert_eq(ChestTransfer.fit(b, &"wooden_cross", 20), 7)
	assert_true(b.can_add(&"wooden_cross", 7))
	assert_false(b.can_add(&"wooden_cross", 8))
	assert_eq(ChestTransfer.fit(b, &"wooden_cross", 4), 4)


func test_transfer_works_with_the_fake_inventory() -> void:
	var fake := FakeInventory.new() as Inventory
	_keep(fake)
	var real := _inv(&"real", 16, [[&"wood", 4]])
	assert_eq(ChestTransfer.move_all(real, fake), 4)
	assert_eq(fake.count(&"wood"), 4)
	assert_eq(ChestTransfer.move_slot(fake, real, 0, true), 1)
	assert_eq(real.count(&"wood"), 1)
	assert_eq(fake.count(&"wood"), 3)


# --- chest panel ------------------------------------------------------------------------------

func test_panels_are_registered() -> void:
	assert_true(UIRoot.PANEL_SCRIPTS.has(&"chest"))
	assert_true(UIRoot.PANEL_SCRIPTS.has(&"grave_register"))


func test_chest_opens_via_event_bus_as_a_modal() -> void:
	await _setup()
	EventBus.ui_panel_requested.emit(&"chest", _chest_context())
	await wait_frames(1)
	var panel := _chest_panel()
	assert_eq(ui.top(), &"chest")
	assert_eq(UIState.top(), &"chest")
	assert_true(TimeManager.paused, "modal pauses the clock")
	assert_false(tree.paused, "no tree pause (only the pause menu)")
	assert_true(ui.dim.visible)
	assert_true(panel is ChestPanel and panel.is_visible_in_tree())
	assert_eq(panel.slot_button(ChestPanel.SIDE_CHEST, 15) != null, true, "16 chest slots")
	assert_null(panel.slot_button(ChestPanel.SIDE_CHEST, 16))
	assert_eq(panel.shown_slots(ChestPanel.SIDE_BAG).size(), 16, "16 bag slots")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_CHEST)[0], {"id": &"stone", "amount": 12})
	assert_eq(panel.shown_slots(ChestPanel.SIDE_BAG)[0], {"id": &"wood", "amount": 7})
	assert_eq(panel.coins_text(), "14", "coins only in the bag header")
	assert_eq(panel.used_text(), "2 / 16 belegt")
	var slot := panel.slot_button(ChestPanel.SIDE_BAG, 0)
	assert_true(slot.tooltip_text.begins_with("Holz\n"), "tooltip: name + description")
	assert_true(slot.tooltip_text.length() > "Holz\n".length())
	for s: Dictionary in panel.shown_slots(ChestPanel.SIDE_BAG):
		assert_ne(s.get("id", &""), &"coin", "coins never appear in a slot")


func test_chest_click_moves_the_stack_both_ways() -> void:
	await _open_chest()
	var panel := _chest_panel()
	panel.slot_button(ChestPanel.SIDE_BAG, 0).pressed.emit()
	assert_eq(bag.count(&"wood"), 0)
	assert_eq(storage.count(&"wood"), 7)
	assert_eq(panel.shown_slots(ChestPanel.SIDE_BAG)[0], {}, "refreshed on changed")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_BAG)[1], {"id": &"linen", "amount": 2}, "slots keep their place")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_CHEST)[2], {"id": &"wood", "amount": 7}, "first free chest slot")
	panel.slot_button(ChestPanel.SIDE_CHEST, 0).pressed.emit()
	assert_eq(storage.count(&"stone"), 0)
	assert_eq(bag.count(&"stone"), 12)
	assert_eq(panel.shown_slots(ChestPanel.SIDE_BAG)[0], {"id": &"stone", "amount": 12})
	assert_eq(panel.used_text(), "2 / 16 belegt")
	assert_eq(ui.top(), &"chest", "panel stays open")


func test_chest_shift_click_moves_one_item() -> void:
	await _open_chest()
	var panel := _chest_panel()
	var slot := panel.slot_button(ChestPanel.SIDE_CHEST, 0)
	var pressed := [0]
	slot.pressed.connect(func() -> void: pressed[0] += 1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.shift_pressed = true
	slot.gui_input.emit(ev)
	assert_eq(storage.count(&"stone"), 11)
	assert_eq(bag.count(&"stone"), 1)
	assert_eq(pressed[0], 0, "the shift click does not also move the stack")
	assert_eq(panel.click_slot(ChestPanel.SIDE_CHEST, 0, true), 1)
	assert_eq(storage.count(&"stone"), 10)
	var plain := InputEventMouseButton.new()
	plain.button_index = MOUSE_BUTTON_LEFT
	plain.pressed = true
	slot.gui_input.emit(plain)
	assert_eq(storage.count(&"stone"), 10, "a plain click is left to the button (pressed)")


func test_chest_bulk_buttons() -> void:
	await _open_chest()
	var panel := _chest_panel()
	assert_false(panel.store_all_button.disabled)
	assert_false(panel.take_all_button.disabled)
	panel.store_all_button.pressed.emit()
	assert_eq(bag.count(&"wood") + bag.count(&"linen") + bag.count(&"shroud"), 0, "bag emptied")
	assert_eq(bag.count(&"coin"), 14, "coins stay with the player")
	assert_eq(storage.count(&"wood"), 7)
	assert_eq(storage.count(&"linen"), 2)
	assert_eq(storage.count(&"shroud"), 1)
	assert_true(panel.store_all_button.disabled, "nothing left to store")
	for s: Dictionary in panel.shown_slots(ChestPanel.SIDE_BAG):
		assert_true(s.is_empty())
	panel.take_all_button.pressed.emit()
	assert_eq(storage.count(&"stone") + storage.count(&"wood"), 0, "chest emptied")
	assert_eq(bag.count(&"stone"), 12)
	assert_eq(bag.count(&"gravestone_simple"), 1)
	assert_true(panel.take_all_button.disabled)
	assert_eq(panel.used_text(), "0 / 16 belegt")
	assert_eq(_notes, [], "no warning when everything fitted")


func test_chest_bulk_move_counts_changes() -> void:
	await _open_chest()
	var panel := _chest_panel()
	var refreshes := [0]
	storage.changed.connect(func() -> void: refreshes[0] += 1)
	var moved := panel.store_all()
	assert_eq(moved, 10, "7 wood + 2 linen + 1 shroud")
	assert_eq(refreshes[0], 3, "one change per item kind on the chest")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_CHEST).filter(func(s: Dictionary) -> bool: return not s.is_empty()).size(), 5)


func test_chest_full_target_warns_and_keeps_items() -> void:
	await _setup()
	storage = _inv(&"storage", 2, [[&"stone", 100]])
	ui.open_panel(&"chest", _chest_context())
	await wait_frames(1)
	var panel := _chest_panel()
	assert_eq(panel.click_slot(ChestPanel.SIDE_BAG, 0), 0)
	assert_eq(bag.count(&"wood"), 7, "nothing lost")
	assert_eq(_notes.size(), 1)
	assert_eq(_notes[0], [ChestPanel.TEXT_CHEST_FULL, &"warning"])
	assert_true(panel.store_all_button.disabled, "no room for anything")
	assert_eq(panel.store_all(), 0)
	assert_eq(panel.used_text(), "2 / 2 belegt")


func test_chest_partial_bulk_move_warns() -> void:
	await _setup()
	storage = _inv(&"storage", 1, [])
	ui.open_panel(&"chest", _chest_context())
	await wait_frames(1)
	var panel := _chest_panel()
	assert_eq(panel.store_all(), 7, "only the wood fits into the single slot")
	assert_eq(bag.count(&"linen"), 2, "the rest stays in the bag")
	assert_eq(_notes, [[ChestPanel.TEXT_CHEST_FULL, &"warning"]])


func test_chest_keyboard_focus_and_navigation() -> void:
	await _open_chest()
	var panel := _chest_panel()
	var first_bag := panel.slot_button(ChestPanel.SIDE_BAG, 0)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), first_bag, "focus on the first filled bag slot")
	_press(&"ui_right")
	await wait_frames(1)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.slot_button(ChestPanel.SIDE_BAG, 1))
	_press(&"ui_left")
	_press(&"ui_left")
	await wait_frames(1)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.slot_button(ChestPanel.SIDE_CHEST, 3), "left of the bag is the chest")
	# Pressing the focused slot (ui_accept) moves its stack; focus stays on that slot.
	_press(&"ui_right")
	await wait_frames(1)
	_press(&"ui_accept")
	await wait_frames(2)
	assert_eq(bag.count(&"wood"), 0, "ui_accept moved the stack")
	assert_eq(ui.get_viewport().gui_get_focus_owner(), first_bag, "slot buttons survive the refresh")
	_press(&"ui_down")
	await wait_frames(1)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.slot_button(ChestPanel.SIDE_BAG, 4))


func test_chest_esc_closes_and_disconnects() -> void:
	await _open_chest()
	var panel := _chest_panel()
	_press(&"pause")
	await wait_frames(1)
	assert_eq(ui.open_ids(), [], "Esc closes the chest, no pause menu")
	assert_false(UIState.is_modal())
	assert_false(TimeManager.paused)
	assert_false(panel.visible)
	for inv: Inventory in [storage, bag]:
		for c: Dictionary in inv.changed.get_connections():
			assert_ne(c.callable.get_object(), panel, "changed disconnected on close")
	storage.add_item(&"wood", 1)
	assert_false(panel.is_open)


func test_chest_on_top_of_the_inventory_unwinds() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": bag})
	ui.open_panel(&"chest", _chest_context())
	await wait_frames(1)
	assert_eq(ui.open_ids(), [&"inventory", &"chest"])
	assert_false(ui.get_panel(&"inventory").is_visible_in_tree())
	_press(&"pause")
	assert_eq(ui.open_ids(), [&"inventory"])
	_press(&"pause")
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())


func test_chest_without_storage_is_harmless() -> void:
	await _setup()
	ui.open_panel(&"chest", {"inventory": bag})
	await wait_frames(1)
	var panel := _chest_panel()
	assert_true(panel.is_open)
	assert_eq(panel.click_slot(ChestPanel.SIDE_BAG, 0), 0)
	assert_eq(panel.click_slot(ChestPanel.SIDE_CHEST, 0), 0)
	assert_true(panel.store_all_button.disabled)
	assert_true(panel.take_all_button.disabled)
	assert_eq(bag.count(&"wood"), 7)
	ui.close_top_panel()
	assert_false(UIState.is_modal())


# --- grave register -------------------------------------------------------------------------

func test_register_opens_via_event_bus_and_renders_entries() -> void:
	await _setup()
	EventBus.ui_panel_requested.emit(&"grave_register", {"entries": _entries(), "total": 24, "rating": &"orderly"})
	await wait_frames(1)
	var panel := _register()
	assert_eq(ui.top(), &"grave_register")
	assert_eq(UIState.top(), &"grave_register")
	assert_true(TimeManager.paused)
	assert_false(tree.paused)
	assert_true(panel.is_visible_in_tree())
	assert_eq(panel.theme_type_variation, &"LedgerPanel", "book look")
	assert_eq(panel.title_label.text, "Grabregister des Friedhofs")
	assert_eq(panel.subtitle_label.text, "Verzeichnis der Bestatteten · 4 Einträge")
	assert_false(panel.empty_label.visible)
	var rows := panel.row_texts()
	assert_eq(rows.size(), 4)
	assert_eq(Array(rows[0]), ["1", "Hedwig Rabenstein (67)", "Ertrunken im Mühlteich", "Nr. 3", "Grabstein", "9/20", "–"])
	assert_eq(Array(rows[1]), ["2", "Egbert Kornblum (54)", "Fieber", "Nr. 1", "Holzkreuz", "6/20", "–"], "sorted by day")
	assert_eq(Array(rows[2]), ["3", "Margarete Eschenbach (31)", "Vom Pferd getreten", "Nr. 5", "Holzkreuz", "7/20", "–"])
	assert_eq(Array(rows[3]), ["3", "Anselm Grauwert (78)", "Altersschwäche", "Nr. 2", "–", "2/20", "–"], "same day keeps order")
	assert_eq(panel.footer_label.text, "Friedhofsqualität 24 · Ordentlich")
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.close_button, "focus on Schließen")


func test_register_empty_state_and_footer() -> void:
	await _setup()
	ui.open_panel(&"grave_register", {"entries": [] as Array[Dictionary], "total": 0, "rating": &"neglected"})
	await wait_frames(1)
	var panel := _register()
	assert_true(panel.empty_label.visible)
	assert_eq(panel.empty_label.text, "Noch ist niemand in deiner Obhut bestattet.")
	assert_eq(panel.row_texts().size(), 0)
	assert_eq(panel.footer_label.text, "Friedhofsqualität 0 · Verwahrlost")
	assert_eq(panel.subtitle_label.text, "Verzeichnis der Bestatteten · noch keine Einträge")
	# Re-open with one entry: the panel refreshes.
	ui.open_panel(&"grave_register", {"entries": [_entries()[1]], "total": 6, "rating": &"orderly"})
	await wait_frames(1)
	assert_false(panel.empty_label.visible)
	assert_eq(panel.row_texts().size(), 1)
	assert_eq(panel.subtitle_label.text, "Verzeichnis der Bestatteten · 1 Eintrag")
	assert_eq(ui.open_ids(), [&"grave_register"], "re-opening does not stack it twice")


func test_register_marks_poor_quality_and_formats_cells() -> void:
	await _setup()
	ui.open_panel(&"grave_register", {"entries": _entries(), "total": 24, "rating": &"orderly"})
	await wait_frames(1)
	assert_eq(GraveRegisterPanel.grave_label("plot_07"), "Nr. 7")
	assert_eq(GraveRegisterPanel.grave_label("plot_12"), "Nr. 12")
	assert_eq(GraveRegisterPanel.grave_label("north"), "north")
	assert_eq(GraveRegisterPanel.grave_label(""), "–")
	var cells := GraveRegisterPanel.cells({"name": "", "age": 0, "day_buried": 5, "quality": 0})
	assert_eq(Array(cells), ["5", "Unbekannt", "–", "–", "–", "0/20", "–"], "missing fields")
	assert_eq(GraveRegisterPanel.sorted_entries(null), [])
	assert_eq(GraveRegisterPanel.sorted_entries([1, "x"]), [], "non-dictionaries ignored")


func test_register_esc_and_close_button() -> void:
	await _setup()
	ui.open_panel(&"grave_register", {"entries": _entries(), "total": 24, "rating": &"orderly"})
	await wait_frames(1)
	_press(&"pause")
	assert_eq(ui.open_ids(), [], "Esc closes the register")
	assert_false(UIState.is_modal())
	ui.open_panel(&"grave_register", {"entries": _entries(), "total": 24, "rating": &"orderly"})
	await wait_frames(1)
	_register().close_button.pressed.emit()
	assert_eq(ui.open_ids(), [])
	assert_false(TimeManager.paused)


func test_register_long_list_scrolls() -> void:
	await _setup()
	var many: Array[Dictionary] = []
	for i: int in 30:
		many.append({"name": "Grabgast %d" % i, "age": 40 + i, "cause_label": "Fieber", "day_buried": 1 + floori(i / 5.0),
				"grave_id": "plot_%02d" % (i + 1), "quality": i % 11, "marker_label": "Holzkreuz"})
	ui.open_panel(&"grave_register", {"entries": many, "total": 150, "rating": &"dignified"})
	await wait_frames(3)
	var panel := _register()
	assert_eq(panel.row_texts().size(), 30)
	assert_eq(panel.scroll.scroll_vertical, 0)
	assert_true(panel.scroll.get_v_scroll_bar().max_value > panel.scroll.size.y, "content taller than the page")
	_press(&"ui_down")
	_press(&"ui_page_down")
	await wait_frames(1)
	assert_true(panel.scroll.scroll_vertical > 0, "keyboard scrolls the page")
	assert_eq(panel.footer_label.text, "Friedhofsqualität 150 · Würdevoll")


# --- helpers --------------------------------------------------------------------------------

func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.add_to_group(&"player")
	bag = Inventory.new()
	bag.name = "Inventory"
	player.add_child(bag)
	player.inventory = bag
	tree.root.add_child(player)
	for entry: Array in [[&"coin", 14], [&"wood", 7], [&"linen", 2], [&"shroud", 1]]:
		bag.add_item(entry[0], entry[1])
	storage = _inv(&"storage", 16, [[&"stone", 12], [&"gravestone_simple", 1]])
	chest = FakeChest.new()
	tree.root.add_child(chest)
	ui = await add_scene(UI_SCENE) as UIRoot


func _open_chest() -> void:
	await _setup()
	EventBus.ui_panel_requested.emit(&"chest", _chest_context())
	await wait_frames(1)


func _chest_context() -> Dictionary:
	return {"storage": storage, "inventory": bag, "chest": chest}


func _chest_panel() -> ChestPanel:
	return ui.get_panel(&"chest") as ChestPanel


func _register() -> GraveRegisterPanel:
	return ui.get_panel(&"grave_register") as GraveRegisterPanel


func _entries() -> Array[Dictionary]:
	return [
		{"name": "Egbert Kornblum", "age": 54, "cause_label": "Fieber", "day_buried": 2,
				"grave_id": "plot_01", "quality": 6, "marker_label": "Holzkreuz"},
		{"name": "Hedwig Rabenstein", "age": 67, "cause_label": "Ertrunken im Mühlteich", "day_buried": 1,
				"grave_id": "plot_03", "quality": 9, "marker_label": "Grabstein"},
		{"name": "Margarete Eschenbach", "age": 31, "cause_label": "Vom Pferd getreten", "day_buried": 3,
				"grave_id": "plot_05", "quality": 7, "marker_label": "Holzkreuz"},
		{"name": "Anselm Grauwert", "age": 78, "cause_label": "Altersschwäche", "day_buried": 3,
				"grave_id": "plot_02", "quality": 2, "marker_label": ""},
	]


## Real Inventory (under the root, freed after the test) with `slots` slots and contents.
func _inv(id: StringName, slots: int, contents: Array) -> Inventory:
	var inv := Inventory.new()
	inv.name = String(id).to_pascal_case()
	inv.slot_count = slots
	_keep(inv)
	for entry: Array in contents:
		inv.add_item(entry[0], entry[1])
	inv.set_meta(&"test_id", id)
	return inv


func _keep(node: Node) -> void:
	tree.root.add_child(node)


func _count_changes(inv: Inventory) -> void:
	var id: StringName = inv.get_meta(&"test_id")
	_changes[id] = 0
	inv.changed.connect(func() -> void: _changes[id] = int(_changes[id]) + 1)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		tree.root.push_input(ev)


func _on_note(text: String, kind: StringName) -> void:
	_notes.append([text, kind])
