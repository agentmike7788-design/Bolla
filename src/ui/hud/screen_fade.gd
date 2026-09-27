class_name ScreenFade
extends ColorRect
## Full-screen black fade (docs §11 hut portal): EventBus.screen_fade_requested(duration) fades
## to black over the first half and back over the second (the portal teleports at the midpoint).
## Top of the UI, never takes the mouse; created by UIRoot.

const COLOR_BLACK := Color(0.0, 0.0, 0.0, 1.0)

var _tween: Tween


func _init() -> void:
	name = "ScreenFade"
	color = COLOR_BLACK
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	EventBus.screen_fade_requested.connect(play)


## Out and in again over `duration` seconds (<= 0: nothing to show).
func play(duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		modulate.a = 0.0
		visible = false
		return
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, duration * 0.5)
	_tween.tween_property(self, ^"modulate:a", 0.0, duration * 0.5)
	_tween.tween_callback(hide)


## Current opacity 0..1 (tests).
func opacity() -> float:
	return modulate.a if visible else 0.0
