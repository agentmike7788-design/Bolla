class_name RegionLabel
extends Label
## The place name for 3 s bottom left when the gravekeeper enters a region (docs/PHASE7_DESIGN.md §7):
## „Hollerbrück · Anger" (RegionConfig.arrive_text, else display_name) on EventBus.region_changed, faded in
## and out. Purely visual; created by UIRoot.

const FADE := 0.4

var shown_text: String = ""
var _tween: Tween


func _init() -> void:
	name = "RegionLabel"
	theme_type_variation = &"RegionLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 40.0
	offset_top = -110.0
	offset_bottom = -60.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	EventBus.region_changed.connect(show_region)


func _exit_tree() -> void:
	if EventBus.region_changed.is_connected(show_region):
		EventBus.region_changed.disconnect(show_region)


## Shows the region's arrive text for Phase7Texts.REGION_SECONDS.
func show_region(region_id: StringName) -> void:
	shown_text = region_text(region_id)
	text = shown_text
	if shown_text == "":
		visible = false
		return
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, FADE)
	_tween.tween_interval(maxf(Phase7Texts.REGION_SECONDS - 2.0 * FADE, 0.1))
	_tween.tween_property(self, ^"modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)


## RegionConfig.arrive_text (or display_name), the fallback names otherwise.
static func region_text(region_id: StringName) -> String:
	var cfg := Database.region_config(region_id) as RegionConfig
	if cfg != null:
		return cfg.arrive_text if cfg.arrive_text != "" else cfg.display_name
	return Phase7Texts.REGION_FALLBACK.get(region_id, "")
