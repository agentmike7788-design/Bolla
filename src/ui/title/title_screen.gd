class_name TitleScreen
extends Control
## Title screen (docs §7): Fortsetzen (SaveManager.newest_slot(), hidden without a save),
## Neues Spiel (SaveManager.new_game()), Beenden. Buttons lock after a choice; a failure
## notification from SaveManager unlocks them again and is shown below. Other notifications
## (e.g. F5/F9 without a world or quicksave, docs §5) appear as toasts top right – the title
## has no HUD.

const GAME_TITLE := "The Last Gravekeeper"
const TAGLINE := "Tod ist Handwerk, nicht Horror."
const TEXT_CONTINUE := "Fortsetzen"
const TEXT_CONTINUE_INFO := "Fortsetzen – %s"
const TEXT_NEW_GAME := "Neues Spiel"
const TEXT_QUIT := "Beenden"
const TEXT_VERSION := "v%s"
const SAVE_MANAGER := preload("res://src/systems/save/save_manager.gd")
const TEXT_STARTING := "Die Nacht senkt sich …"

## World scene for "Neues Spiel" (tests point it at a fixture).
@export_file("*.tscn") var world_scene: String = SAVE_MANAGER.WORLD_SCENE
@export var left_margin: float = 170.0
@export var button_width: float = 440.0
@export var toast_margin: float = 28.0
@export var toast_width: float = 460.0

## Called for "Beenden" (tests replace it).
var quit_handler: Callable = _quit_game
var continue_button: Button
var new_game_button: Button
var quit_button: Button
var status_label: Label
## Toasts for EventBus.notification_requested while no choice is running.
var notifications: NotificationStack
## Slot "Fortsetzen" loads (-1 = none).
var continue_slot: int = -1

var _busy: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var backdrop := TitleBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := UIKit.vbox(14)
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_left = left_margin
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)
	column.add_child(UIKit.label(GAME_TITLE, &"TitleLabel"))
	column.add_child(UIKit.label(TAGLINE, &"AccentLabel"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 36.0
	column.add_child(gap)
	var buttons := UIKit.vbox(12)
	buttons.custom_minimum_size.x = button_width
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	continue_button = _add_button(buttons, TEXT_CONTINUE, _on_continue_pressed, &"AccentButton")
	new_game_button = _add_button(buttons, TEXT_NEW_GAME, _on_new_game_pressed)
	quit_button = _add_button(buttons, TEXT_QUIT, _on_quit_pressed)
	column.add_child(buttons)
	status_label = UIKit.label("", &"DimLabel")
	column.add_child(status_label)
	var version := UIKit.label(TEXT_VERSION % GameConfig.version, &"DimLabel")
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -28.0
	version.offset_bottom = -20.0
	add_child(version)
	notifications = NotificationStack.new()
	notifications.name = "Notifications"
	notifications.entry_width = toast_width
	notifications.anchor_left = 1.0
	notifications.anchor_right = 1.0
	notifications.offset_left = -toast_margin - toast_width
	notifications.offset_right = -toast_margin
	notifications.offset_top = toast_margin
	notifications.offset_bottom = toast_margin
	notifications.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(notifications)


func _ready() -> void:
	# The title routes notifications itself (status line while busy, toast otherwise).
	if EventBus.notification_requested.is_connected(notifications.push):
		EventBus.notification_requested.disconnect(notifications.push)
	EventBus.notification_requested.connect(_on_notification)
	refresh()


## Re-reads the save slots (Fortsetzen visibility and info).
func refresh() -> void:
	continue_slot = SaveManager.newest_slot()
	continue_button.visible = continue_slot >= 0
	if continue_slot >= 0:
		continue_button.text = TEXT_CONTINUE_INFO % PauseMenu.slot_text(SaveManager.get_slot_info(continue_slot))
	_set_busy(false)
	var first := UIKit.first_focusable(self)
	if first != null:
		first.grab_focus.call_deferred()


func _add_button(parent: Container, text: String, callback: Callable, variation: StringName = &"") -> Button:
	var button := UIKit.button(text, variation)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _set_busy(value: bool) -> void:
	_busy = value
	for button: Button in [continue_button, new_game_button, quit_button]:
		button.disabled = value


func _on_continue_pressed() -> void:
	if _busy or continue_slot < 0:
		return
	_set_busy(true)
	status_label.text = TEXT_STARTING
	SaveManager.load_game(continue_slot)


func _on_new_game_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	status_label.text = TEXT_STARTING
	SaveManager.new_game(world_scene)


func _on_quit_pressed() -> void:
	if _busy:
		return
	quit_handler.call()


## Texts of the toasts currently shown (oldest first).
func notification_texts() -> PackedStringArray:
	return notifications.texts()


## SaveManager reports failures of a running choice as warnings: show them below the
## buttons and unlock them. Everything else becomes a toast.
func _on_notification(text: String, kind: StringName) -> void:
	if not is_inside_tree():
		return
	if _busy and kind == &"warning":
		status_label.text = text
		_set_busy(false)
	elif not _busy:
		notifications.push(text, kind)


func _quit_game() -> void:
	get_tree().quit()
