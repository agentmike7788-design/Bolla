class_name UIKit
extends RefCounted
## Small factory for themed controls (theme: src/ui/theme/gravekeeper_theme.tres).
## Keeps panels and HUD consistent: every control gets its look from a theme type
## variation, never from inline colours.

const THEME_PATH := "res://src/ui/theme/gravekeeper_theme.tres"
const MINUTES_SUFFIX := " Min"
const PLUS_FORMAT := "+%d"
const MINUS := "−"


static func theme() -> Theme:
	return load(THEME_PATH) as Theme


static func label(text: String = "", variation: StringName = &"", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	return b


static func panel(variation: StringName) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func vbox(separation: int = -1) -> VBoxContainer:
	var box := VBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override(&"separation", separation)
	return box


static func hbox(separation: int = -1) -> HBoxContainer:
	var box := HBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override(&"separation", separation)
	return box


static func icon(texture: Texture2D, edge: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(edge, edge)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func bar(variation: StringName = &"") -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.show_percentage = false
	if variation != &"":
		b.theme_type_variation = variation
	return b


## Keycap badge, e.g. [E].
static func keycap(key: String) -> PanelContainer:
	var cap := panel(&"KeyCapPanel")
	var l := label(key, &"KeyLabel")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cap


static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func separator() -> HSeparator:
	return HSeparator.new()


## Centers `child` in a full-rect CenterContainer (for modal windows).
static func centered(child: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(child)
	return center


## "+2" / "−1" / "0" with a typographic minus.
static func signed(points: int) -> String:
	if points > 0:
		return PLUS_FORMAT % points
	if points < 0:
		return MINUS + str(-points)
	return "0"


static func minutes(game_minutes: int) -> String:
	return str(game_minutes) + MINUTES_SUFFIX


## "07:40" from a minute of day.
static func clock(minute_of_day: int) -> String:
	var m := posmod(minute_of_day, TimeManager.MINUTES_PER_DAY)
	return "%02d:%02d" % [floori(float(m) / TimeManager.MINUTES_PER_HOUR), m % TimeManager.MINUTES_PER_HOUR]


## Item display name from the Database, or the raw id.
static func item_name(id: StringName) -> String:
	if Database.has_item(id):
		var item := Database.item(id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	return String(id)


static func item_description(id: StringName) -> String:
	if Database.has_item(id):
		var item := Database.item(id) as ItemData
		if item != null:
			return item.description
	return ""


## Removes and frees all children of `node` right away (rebuilding lists).
static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## First focusable, visible and enabled button under `root` (depth first), or null.
static func first_focusable(root: Node) -> Control:
	for child: Node in root.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var b := c as BaseButton
		if b != null and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			return b
		var found := first_focusable(c)
		if found != null:
			return found
	return null
