class_name UIPanel
extends PanelContainer
## Base of every modal panel (docs §7). UIRoot opens it with open(context) after
## UIState.push_modal(panel_id) and closes it on close_requested / Esc.
## Subclasses build their controls in _build() (once) and fill them in _refresh().
## Optional action row: a progress bar driven by EventBus.timed_action_* while a
## timed action started from this panel runs; `action_running` disables buttons.

signal close_requested
## A request UIRoot carries out: &"title" (back to the title screen), &"quit".
signal action_requested(action: StringName)

const TEXT_CLOSE := "Schließen"
const TEXT_CLOSE_X := "✕"
const TEXT_ACTION_RUNNING := "%s …"
## Label when the panel opens while an action (started elsewhere) is still running.
const TEXT_BUSY := "Arbeit läuft …"

var panel_id: StringName = &""
var context: Dictionary = {}
var is_open: bool = false
## True while a timed action runs (started from this panel or elsewhere).
var action_running: bool = false

var _built: bool = false
var _action_box: VBoxContainer
var _action_label: Label
var _action_bar: ProgressBar


func _init() -> void:
	theme_type_variation = &"WindowPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	EventBus.timed_action_started.connect(_on_action_started)
	EventBus.timed_action_progress.connect(_on_action_progress)
	EventBus.timed_action_finished.connect(_on_action_finished)


## Opens with `ctx`; an already open panel is re-opened with the new context.
func open(ctx: Dictionary) -> void:
	if is_open:
		_on_closed()
	context = ctx
	if not _built:
		_built = true
		_build()
	action_running = _player_busy()
	if _action_box != null:
		_action_box.visible = action_running
		if action_running:
			_action_label.text = TEXT_BUSY
	is_open = true
	visible = true
	_on_opened()
	_refresh()
	focus_default()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_on_closed()
	context = {}


## Re-reads the context objects and updates every control. If that disabled or removed
## the focused button, keyboard focus moves on to focus_default() (deferred).
func refresh() -> void:
	if is_open:
		_refresh()
		_ensure_focus.call_deferred()


## Gives keyboard focus to the first enabled button (only while the panel is shown).
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	var target := UIKit.first_focusable(self)
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


## Keeps keyboard focus usable: when nothing has focus or this panel's focused control is
## disabled / hidden, focus_default() picks the next sensible one. Focus elsewhere (e.g. the
## debug console) is left alone; while an action runs nothing moves (every action button is
## disabled then, and _on_action_finished() refocuses).
func _ensure_focus() -> void:
	if not is_open or action_running or not is_visible_in_tree():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		if not is_ancestor_of(focus_owner):
			return
		var button := focus_owner as BaseButton
		if focus_owner.is_visible_in_tree() and (button == null or not button.disabled):
			return
	focus_default()


## Emits close_requested (UIRoot pops the modal and calls close()).
func request_close() -> void:
	close_requested.emit()


# --- virtuals -----------------------------------------------------------------------------

func _build() -> void:
	pass


func _refresh() -> void:
	pass


func _on_opened() -> void:
	pass


func _on_closed() -> void:
	pass


# --- helpers for subclasses -----------------------------------------------------------------

## Header row: title (HeaderLabel) + optional close button. Returns the title label.
func _make_header(parent: Container, title: String, with_close: bool = true) -> Label:
	var row := UIKit.hbox(16)
	var l := UIKit.label(title, &"HeaderLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if with_close:
		var close_button := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
		close_button.tooltip_text = TEXT_CLOSE
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(request_close)
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(close_button)
	parent.add_child(row)
	return l


## Progress row for timed actions (hidden until one runs).
func _make_action_row(parent: Container) -> void:
	_action_box = UIKit.vbox(6)
	_action_label = UIKit.label("", &"AccentLabel")
	_action_box.add_child(_action_label)
	_action_bar = UIKit.bar()
	_action_bar.custom_minimum_size.y = 20.0
	_action_box.add_child(_action_bar)
	_action_box.visible = false
	parent.add_child(_action_box)


func _player() -> Node:
	var p: Variant = context.get("player")
	return p if is_instance_valid(p) else null


func _player_inventory() -> Inventory:
	var inv: Variant = context.get("inventory")
	if is_instance_valid(inv) and inv is Inventory:
		return inv
	var p := _player()
	if p != null:
		return p.get(&"inventory") as Inventory
	return null


func _player_busy() -> bool:
	var p := _player()
	return p != null and p.has_method(&"is_busy") and bool(p.call(&"is_busy"))


func _action_ratio() -> float:
	return _action_bar.value if _action_bar != null else 0.0


func _on_action_started(label: String, _duration_sec: float) -> void:
	action_running = true
	if _action_box != null:
		_action_label.text = TEXT_ACTION_RUNNING % label
		_action_bar.value = 0.0
		_action_box.visible = true
	refresh()


func _on_action_progress(ratio: float) -> void:
	if _action_bar != null:
		_action_bar.value = clampf(ratio, 0.0, 1.0)


func _on_action_finished(_completed: bool) -> void:
	action_running = false
	if _action_box != null:
		_action_box.visible = false
	refresh()
	focus_default()


static func _economy() -> EconomyConfig:
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()


static func _action_config() -> ActionConfig:
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()
