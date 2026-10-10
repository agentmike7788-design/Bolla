class_name FestBanner
extends PanelContainer
## The festival banner (docs/PHASE8_DESIGN.md §2.7, §7.5): on a festival day at 06:00 and 15:00 for 4 s at the
## top of the screen – „Heute Abend: Lichtgang" / „Kathreintanz im Holderkrug (ab 19:00)". Festivals.today()
## decides the day (the shifted Lichtgang included); the clock reaching the minute (EventBus.time_tick) shows it
## once per minute and day – a skip over it shows nothing. Purely visual; created by UIRoot.

const FESTIVALS_GROUP := &"festivals"
const FADE := 0.4

var label: Label
var shown_text: String = ""
## "day:minute" of the last banner (once each).
var _last: String = ""
var _tween: Tween


func _init() -> void:
	name = "FestBanner"
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_top = 150.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	label = UIKit.label("", &"HeaderLabel")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


func _exit_tree() -> void:
	if EventBus.time_tick.is_connected(_on_time_tick):
		EventBus.time_tick.disconnect(_on_time_tick)


func _on_time_tick(day: int, minute: int) -> void:
	if not minute in Phase8Texts.FEST_BANNER_MINUTES:
		return
	var key := "%d:%d" % [day, minute]
	if key == _last:
		return
	var text := banner_text()
	if text == "":
		return
	_last = key
	show_text(text)


## The banner of today's festival ("" = none).
func banner_text() -> String:
	var fest := get_tree().get_first_node_in_group(FESTIVALS_GROUP) as Festivals if is_inside_tree() else null
	if fest == null:
		return ""
	var id := fest.today()
	var data := fest.festival(id) if id != &"" else null
	return Phase8Texts.fest_banner(id, data.window.x if data != null else 0)


func show_text(text: String) -> void:
	shown_text = text
	label.text = text
	visible = true
	reset_size()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, FADE)
	_tween.tween_interval(maxf(Phase8Texts.FEST_BANNER_SECONDS - 2.0 * FADE, 0.1))
	_tween.tween_property(self, ^"modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)


## QA screenshots: keep the banner on screen (no fade).
func _hold_for_shot() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	visible = shown_text != ""
