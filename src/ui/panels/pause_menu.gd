class_name PauseMenu
extends UIPanel
## &"pause" – context {}. UIRoot pauses the SceneTree while it is open.
## Fortsetzen · Speichern (slot 1, only if SaveManager.can_save()) · Laden (slot 0 Autosave /
## slot 1 Schnellspeicher with "Tag 2, 06:00") · Ton (volume sliders, AudioVolumeBox – user
## settings, not the save) · Zum Titel · Beenden (both confirm once).

const TEXT_TITLE := "Pause"
const TEXT_RESUME := "Fortsetzen"
const TEXT_SAVE := "Speichern (Schnellspeicher)"
const TEXT_LOAD := "Laden …"
const TEXT_SOUND := "Ton …"
const TEXT_BACK := "Zurück"
const TEXT_TITLE_SCREEN := "Zum Titel"
const TEXT_QUIT := "Beenden"
const TEXT_CONFIRM := "%s – wirklich? Ungespeichertes geht verloren."
const TEXT_SAVED := "Gespeichert (Schnellspeicher)."
const TEXT_SAVE_FAILED := "Speichern fehlgeschlagen."
const TEXT_CANNOT_SAVE := "Speichern gerade nicht möglich."
const TEXT_SLOT := "%s – %s"
const TEXT_SLOT_INFO := "Tag %d, %s"
const TEXT_SLOT_EMPTY := "leer"
const TEXT_LOADING := "Lade …"
const SLOT_NAMES: Dictionary[int, String] = {0: "Autosave", 1: "Schnellspeicher"}
const SAVE_SLOT := 1
const ACTION_TITLE := &"title"
const ACTION_QUIT := &"quit"
## G7 Änderungsrunde 1: „Karte" opens the map in place of the pause menu (UIRoot, action &"map").
const TEXT_MAP := "Karte [M]"
const ACTION_MAP := &"map"

@export var panel_width: float = 520.0

var resume_button: Button
var save_button: Button
var load_button: Button
var sound_button: Button
var volume_box: AudioVolumeBox
var title_button: Button
var quit_button: Button
var map_button: Button
var status_label: Label
## slot -> Button
var slot_buttons: Dictionary[int, Button] = {}

var _main_box: VBoxContainer
var _load_box: VBoxContainer
var _sound_box: VBoxContainer
## Action waiting for its confirming second press (&"" = none).
var _confirm: StringName = &""


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	_make_header(box, TEXT_TITLE, false)
	_main_box = UIKit.vbox(10)
	resume_button = _add_button(_main_box, TEXT_RESUME, request_close, &"AccentButton")
	map_button = _add_button(_main_box, TEXT_MAP, action_requested.emit.bind(ACTION_MAP))
	save_button = _add_button(_main_box, TEXT_SAVE, _on_save_pressed)
	load_button = _add_button(_main_box, TEXT_LOAD, _show_load.bind(true))
	sound_button = _add_button(_main_box, TEXT_SOUND, _show_sound.bind(true))
	title_button = _add_button(_main_box, TEXT_TITLE_SCREEN, _on_confirmable.bind(ACTION_TITLE))
	quit_button = _add_button(_main_box, TEXT_QUIT, _on_confirmable.bind(ACTION_QUIT))
	box.add_child(_main_box)
	_load_box = UIKit.vbox(10)
	for slot: int in SLOT_NAMES:
		slot_buttons[slot] = _add_button(_load_box, "", _on_load_pressed.bind(slot))
	_add_button(_load_box, TEXT_BACK, _show_load.bind(false))
	_load_box.visible = false
	box.add_child(_load_box)
	_sound_box = UIKit.vbox(10)
	volume_box = AudioVolumeBox.new()
	_sound_box.add_child(volume_box)
	_add_button(_sound_box, TEXT_BACK, _show_sound.bind(false))
	_sound_box.visible = false
	box.add_child(_sound_box)
	status_label = UIKit.label("", &"DimLabel", true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.x = panel_width - 80.0
	status_label.visible = false
	box.add_child(status_label)


func _on_opened() -> void:
	_confirm = &""
	_set_status("")
	_load_box.visible = false
	_sound_box.visible = false
	_main_box.visible = true


func _refresh() -> void:
	var can_save := SaveManager.can_save()
	save_button.disabled = not can_save
	save_button.tooltip_text = "" if can_save else TEXT_CANNOT_SAVE
	for slot: int in slot_buttons:
		var info := SaveManager.get_slot_info(slot)
		var button := slot_buttons[slot]
		button.text = TEXT_SLOT % [SLOT_NAMES[slot], slot_text(info)]
		button.disabled = not bool(info.get("exists", false))
	load_button.disabled = SaveManager.newest_slot() < 0
	title_button.text = TEXT_CONFIRM % TEXT_TITLE_SCREEN if _confirm == ACTION_TITLE else TEXT_TITLE_SCREEN
	quit_button.text = TEXT_CONFIRM % TEXT_QUIT if _confirm == ACTION_QUIT else TEXT_QUIT


## "Tag 2, 06:00" for an existing slot, else "leer".
static func slot_text(info: Dictionary) -> String:
	if not bool(info.get("exists", false)):
		return TEXT_SLOT_EMPTY
	return TEXT_SLOT_INFO % [int(info.get("day", 0)), UIKit.clock(int(info.get("minute_of_day", 0)))]


func _set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = text != ""


func _add_button(parent: Container, text: String, callback: Callable, variation: StringName = &"") -> Button:
	var button := UIKit.button(text, variation)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _show_load(show_slots: bool) -> void:
	_confirm = &""
	_load_box.visible = show_slots
	_main_box.visible = not show_slots
	refresh()
	focus_default()


func _show_sound(show_sliders: bool) -> void:
	_confirm = &""
	_sound_box.visible = show_sliders
	_main_box.visible = not show_sliders
	if show_sliders:
		volume_box.refresh()
	refresh()
	focus_default()


func _on_save_pressed() -> void:
	_confirm = &""
	if not SaveManager.can_save():
		_set_status(TEXT_CANNOT_SAVE)
		refresh()
		return
	var err := SaveManager.save_game(SAVE_SLOT)
	_set_status(TEXT_SAVED if err == OK else TEXT_SAVE_FAILED)
	refresh()


func _on_load_pressed(slot: int) -> void:
	if not SaveManager.has_save(slot):
		refresh()
		return
	_set_status(TEXT_LOADING)
	# load_game clears UIState and unpauses; UIRoot closes its panels on ui_modal_changed.
	SaveManager.load_game(slot)


## Zum Titel / Beenden: first press asks, the second one carries it out.
func _on_confirmable(action: StringName) -> void:
	if _confirm != action:
		_confirm = action
		refresh()
		return
	_confirm = &""
	action_requested.emit(action)
