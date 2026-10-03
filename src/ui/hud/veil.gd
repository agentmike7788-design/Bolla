class_name ScreenVeil
extends ColorRect
## The dark veil over the screen while a specimen is taken or a lecture is held (docs/PHASE7_DESIGN.md
## §2.6, §2.6.4, §7): ink blue #1F2A3A at 85 % (lecture 60 %), fading in and out over 0.6 s. Only its own
## line and an action bar stay readable on top – the bar follows EventBus.timed_action_*.
## EventBus.screen_veil_changed(active) (MorgueTable) shows / hides it with AnatomyConfig.veil_alpha and the
## current timed action's label as the line; the lecture panel calls open(alpha, line, lines) itself.
## Purely visual: it never changes game state and never takes the mouse. Created by UIRoot (group
## screen_veil).

const GROUP := &"screen_veil"
const INK := Color(0.122, 0.165, 0.227, 1.0)
const DEFAULT_ALPHA := 0.85
const DEFAULT_SECONDS := 0.6
const LINE_SECONDS := 5.0

var line_label: Label
var sub_label: Label
var bar: ProgressBar
var active: bool = false
var target_alpha: float = DEFAULT_ALPHA
## Extra lines shown one after another (the lecture's talk); empty = only the line.
var lines: PackedStringArray = []

var _tween: Tween
var _line_left: float = 0.0
var _line_index: int = 0


func _init() -> void:
	name = "ScreenVeil"
	color = Color(INK, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false
	add_to_group(GROUP)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	# A quiet band behind the line and the bar keeps them readable over a panel (lecture at 60 %).
	var band := UIKit.panel(&"HudPanel")
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(band)
	var box := UIKit.vbox(18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(box)
	line_label = UIKit.label("", &"VeilLabel", true)
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.custom_minimum_size.x = 980.0
	box.add_child(line_label)
	sub_label = UIKit.label("", &"WhisperLabel", true)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.custom_minimum_size.x = 980.0
	box.add_child(sub_label)
	bar = UIKit.bar()
	bar.custom_minimum_size = Vector2(440.0, 18.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)


func _ready() -> void:
	EventBus.screen_veil_changed.connect(_on_veil_changed)
	EventBus.timed_action_started.connect(_on_action_started)
	EventBus.timed_action_progress.connect(_on_action_progress)
	EventBus.game_loaded.connect(_on_game_reset.unbind(1))
	EventBus.new_game_started.connect(_on_game_reset)


func _exit_tree() -> void:
	for sig: Signal in [EventBus.game_loaded, EventBus.new_game_started]:
		for c: Dictionary in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)
	for pair: Array in [[EventBus.screen_veil_changed, _on_veil_changed], [EventBus.timed_action_started, _on_action_started],
			[EventBus.timed_action_progress, _on_action_progress]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


## Fades in to `alpha` with `line` (and `more` lines in turn, LINE_SECONDS each).
func open(alpha: float = DEFAULT_ALPHA, line: String = "", more: PackedStringArray = []) -> void:
	active = true
	target_alpha = clampf(alpha, 0.0, 1.0)
	color = Color(INK, target_alpha)
	line_label.text = line
	lines = more
	_line_index = 0
	_line_left = LINE_SECONDS
	sub_label.text = lines[0] if not lines.is_empty() else ""
	sub_label.visible = sub_label.text != ""
	bar.value = 0.0
	_fade(1.0)


## Fades out (no-op when not shown).
func close() -> void:
	if not active:
		return
	active = false
	lines = []
	_fade(0.0)


## Opacity of the ink now (tests): 0 hidden, else target_alpha × fade.
func opacity() -> float:
	return target_alpha * modulate.a if visible else 0.0


func _process(delta: float) -> void:
	if not active or lines.size() < 2:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_line_left = LINE_SECONDS
		_line_index = (_line_index + 1) % lines.size()
		sub_label.text = lines[_line_index]


func _fade(to: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var seconds := _seconds()
	if not is_inside_tree() or seconds <= 0.0:
		modulate.a = to
		visible = to > 0.0
		return
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", to, seconds)
	if to <= 0.0:
		_tween.tween_callback(hide)


func _seconds() -> float:
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	return cfg.veil_seconds if cfg != null else DEFAULT_SECONDS


func _alpha() -> float:
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	return cfg.veil_alpha if cfg != null else DEFAULT_ALPHA


func _on_veil_changed(on: bool) -> void:
	if on:
		open(_alpha(), line_label.text if active else "")
	else:
		close()


func _on_action_started(label: String, _duration: float) -> void:
	if active and line_label.text == "":
		line_label.text = label
	elif not active:
		line_label.text = label
	bar.value = 0.0


## A load or a new game never keeps a veil (the action it belonged to is gone).
func _on_game_reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	active = false
	lines = []
	modulate.a = 0.0
	visible = false


func _on_action_progress(ratio: float) -> void:
	bar.value = clampf(ratio, 0.0, 1.0)
