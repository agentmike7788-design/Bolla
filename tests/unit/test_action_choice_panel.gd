extends TestCase
## Phase 9 W3 QA-Fix (QA9-01 … QA9-04): the short choice &"action_choice" – one button per option in order, the first
## free one focused, dimmed options with their reason, choosing closes and calls target.request_action(id).

const UI_SCENE := "res://src/ui/ui_root.tscn"


class Target extends Node:
	var chosen: Array[StringName] = []

	func request_action(id: StringName) -> void:
		chosen.append(id)


var ui: UIRoot
var target: Target


func before_each() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	target = Target.new()
	tree.root.add_child(target)


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	UIState.clear()
	await wait_frames(2)


func _ctx() -> Dictionary:
	return {"title": "Am Ofen", "question": "Welcher Brief?", "target": target, "options": [
			{"id": &"warm", "label": "Am Ofen wärmen"},
			{"id": &"burn:lt_0001", "label": "Verbrennen: An Rosine (2 Min)"},
			{"id": &"burn:lt_0002", "label": "Verbrennen: An niemanden", "reason": "Geht hier nicht."}]}


func test_registered_and_shows_the_options_in_order() -> void:
	assert_true(UIRoot.PANEL_SCRIPTS.has(&"action_choice"))
	ui.open_panel(&"action_choice", _ctx())
	await wait_frames(2)
	var panel := ui.get_panel(&"action_choice") as ActionChoicePanel
	assert_not_null(panel)
	assert_eq(ui.top(), &"action_choice")
	assert_eq(panel.title_label.text, "Am Ofen")
	assert_eq(panel.option_button(&"warm").text, "Am Ofen wärmen")
	assert_true(panel.option_button(&"warm").has_focus(), "the first free option has the focus (the main action)")
	assert_true(panel.option_button(&"burn:lt_0002").disabled, "a dimmed option")
	assert_false(panel.choose(&"burn:lt_0002"), "a dimmed option does nothing")
	assert_eq(target.chosen, [] as Array[StringName])


func test_choosing_closes_and_calls_the_target() -> void:
	ui.open_panel(&"action_choice", _ctx())
	await wait_frames(1)
	var panel := ui.get_panel(&"action_choice") as ActionChoicePanel
	assert_true(panel.choose(&"burn:lt_0001"))
	await wait_frames(1)
	assert_eq(target.chosen, [&"burn:lt_0001"] as Array[StringName])
	assert_false(panel.is_open, "closed")
	assert_ne(ui.top(), &"action_choice")


func test_fits_at_1280_and_1920() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = size
		ui.open_panel(&"action_choice", _ctx())
		await wait_frames(2)
		var panel := ui.get_panel(&"action_choice") as ActionChoicePanel
		var rect := panel.get_global_rect()
		var view := panel.get_viewport_rect()
		assert_true(view.encloses(rect), "%s: inside the screen (%s in %s)" % [size, rect, view])
		ui.close_all()


## QA9-01: the forge's crafting panel shows „Brief verbrennen …" only with a letter to burn at its ForgeLetter.
class ForgeLetterDouble extends ForgeLetter:
	var letter := ""
	var opened := 0

	func burnable_letter(_p: Player) -> String:
		return letter

	func open_choice(_p: Player) -> bool:
		opened += 1
		return true


func test_crafting_panel_letter_button_at_the_forge() -> void:
	var station := Node3D.new()
	station.name = "station_forge"
	var fl := ForgeLetterDouble.new()
	fl.name = "ForgeLetter"
	station.add_child(fl)
	tree.root.add_child(station)
	var inv := Inventory.new()
	ui.open_panel(&"crafting", {"station": &"forge", "inventory": inv, "workbench": station})
	await wait_frames(1)
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	assert_false(panel.letter_button.visible, "no letter: no button")
	ui.close_all()
	fl.letter = "lt_0001"
	ui.open_panel(&"crafting", {"station": &"forge", "inventory": inv, "workbench": station})
	await wait_frames(1)
	assert_true(panel.letter_button.visible, "a letter to burn: „Brief verbrennen …“")
	assert_eq(panel.letter_button.text, CraftingPanel.TEXT_LETTER_BUTTON)
	panel.letter_button.pressed.emit()
	assert_eq(fl.opened, 1, "opens the choice of the ForgeLetter")
	ui.close_all()
	station.queue_free()
	inv.free()
