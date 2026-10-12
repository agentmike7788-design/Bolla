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
## G8 Runde 4: the panel hid for a running work (true) or came back (false) – UIRoot drops / restores the dim, the HUD
## shows its action bar meanwhile.
signal work_view_changed(hidden: bool)

const TEXT_CLOSE := "Schließen"
const TEXT_CLOSE_X := "✕"
const TEXT_ACTION_RUNNING := "%s …"
## Label when the panel opens while an action (started elsewhere) is still running.
const TEXT_BUSY := "Arbeit läuft …"
## G8 Runde 4: free margin (px) above and below a docked panel (UIRoot.DOCK_MARGIN) and the least height of its
## scrolling body (fit_dock_scroll).
const DOCK_MARGIN := 24.0
const DOCK_BODY_MIN := 160.0

var panel_id: StringName = &""
var context: Dictionary = {}
var is_open: bool = false
## True while a timed action runs (started from this panel or elsewhere).
var action_running: bool = false
## G8 Runde 4 (user: „das auswahl bild muss weg der verdekt den leichentisch"): a timed action started while the panel
## is open hides it until the action ends (the work stays visible, the HUD's action bar shows it), then it comes back
## with the focus on its first button. Set by the panel (CorpseExamPanel).
var hide_while_working: bool = false
## G8 Runde 4: UIRoot docks the panel at the right edge (UIKit.docked_right) and leaves the world undimmed.
## Set by the panel (CorpseExamPanel, CraftingPanel, PultPanel).
var dock_right: bool = false
## True while the panel is hidden for the running work (hide_while_working).
var work_hidden: bool = false

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
	_set_work_hidden(false)
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
	_set_work_hidden(false)
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
		reveal.call_deferred(target)


## G8 Runde 4: scrolls the panel's scrolling body so that `control` is in view – after a rebuild of the rows the focus
## can sit on a button outside it (ScrollContainer.follow_focus only follows a focus change).
func reveal(control: Control) -> void:
	if not is_instance_valid(control) or not is_ancestor_of(control):
		return
	var node := control.get_parent()
	while node != null and node != self and not node is ScrollContainer:
		node = node.get_parent()
	var scroll := node as ScrollContainer
	if scroll == null or not is_inside_tree():
		return
	# freshly built rows are laid out at the end of the frame – measure after that
	await get_tree().process_frame
	if is_instance_valid(control) and is_instance_valid(scroll) and scroll.is_ancestor_of(control) and control.is_visible_in_tree():
		scroll.ensure_control_visible(control)


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

## G8 Runde 4: a docked panel's scrolling body as tall as its `content`, at most what the screen leaves beside the
## panel's other rows (header, action row, buttons) and at most `cap` (> 0). Call it after the content changed.
func fit_dock_scroll(scroll: ScrollContainer, content: Control, cap: float = 0.0) -> void:
	if scroll == null or content == null or not is_inside_tree():
		return
	var chrome := get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	var avail := maxf(get_viewport_rect().size.y - 2.0 * DOCK_MARGIN - chrome, DOCK_BODY_MIN)
	if cap > 0.0:
		avail = minf(avail, cap)
	var want := minf(content.get_combined_minimum_size().y, avail)
	if not is_equal_approx(scroll.custom_minimum_size.y, want):
		scroll.custom_minimum_size.y = want


## G8 Runde 4: the scrolling body of a docked panel (no horizontal scroll, it follows the keyboard focus) with its
## content column; the panel calls fit_dock_scroll(scroll, content) when the content changes.
static func make_dock_scroll(parent: Container, separation: int) -> Array[Control]:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var content := UIKit.vbox(separation)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	parent.add_child(scroll)
	return [scroll, content]

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
	if is_open and hide_while_working:
		_set_work_hidden(true)


func _on_action_progress(ratio: float) -> void:
	if _action_bar != null:
		_action_bar.value = clampf(ratio, 0.0, 1.0)


func _on_action_finished(_completed: bool) -> void:
	action_running = false
	if _action_box != null:
		_action_box.visible = false
	_set_work_hidden(false)
	refresh()
	focus_default()


## Hides the open panel for the running work / shows it again (hide_while_working; work_view_changed for UIRoot).
func _set_work_hidden(on: bool) -> void:
	if on == work_hidden:
		return
	work_hidden = on
	if is_open:
		visible = not on
	work_view_changed.emit(on)


static func _economy() -> EconomyConfig:
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()


static func _action_config() -> ActionConfig:
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()
