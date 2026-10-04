class_name MapPanel
extends UIPanel
## &"map" (G7 Änderungsrunde 1): key M (map_toggle), button in the pause menu. Context = MapState.context
## (UIRoot.open_map), optional "region" to force a sheet. Two sheets, „Friedhof" and „Hollerbrück"
## (from village_open), painted from the layout files by MapCanvas; it opens on the gravekeeper's region
## (a room shows its building). Tabs by click or [ / ] (journal_page_prev / _next), the legend on and
## off with its button. Read-only – no travel.

const TEXT_TITLE := "Karte"
const TEXT_LEGEND_ON := "Legende einblenden"
const TEXT_LEGEND_OFF := "Legende ausblenden"
const TEXT_HINT := "[ / ] Blatt wechseln · Maus über Orte zeigt Näheres · [M] oder [Esc] schließen"
const REGIONS: Array[StringName] = [&"graveyard", &"village"]

@export var sheet_size: Vector2 = Vector2(1440.0, 860.0)
@export var legend_width: float = 300.0

var config: MapConfig
var canvas: MapCanvas
var current_region: StringName = &"graveyard"
var tab_buttons: Dictionary[StringName, Button] = {}
var legend_button: Button
var legend: MapLegend


func _build() -> void:
	theme_type_variation = &"LedgerPanel"
	config = map_config()
	var box := UIKit.vbox(10)
	add_child(box)
	var head := UIKit.hbox(8)
	var title := UIKit.label(TEXT_TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for region: StringName in REGIONS:
		var b := UIKit.button(config.tab_titles.get(region, String(region)), &"JournalTabButton")
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_region.bind(region))
		head.add_child(b)
		tab_buttons[region] = b
	legend_button = UIKit.button(TEXT_LEGEND_OFF, &"JournalTabButton")
	legend_button.focus_mode = Control.FOCUS_NONE
	legend_button.pressed.connect(toggle_legend)
	head.add_child(legend_button)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var spread := UIKit.hbox(8)
	box.add_child(spread)
	canvas = MapCanvas.new()
	canvas.name = "MapCanvas"
	canvas.custom_minimum_size = sheet_size
	spread.add_child(canvas)
	legend = MapLegend.new()
	legend.name = "MapLegend"
	legend.cfg = config
	legend.custom_minimum_size = Vector2(legend_width, sheet_size.y)
	spread.add_child(legend)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _on_opened() -> void:
	var wanted := StringName(str(context.get("region_override", "")))
	if wanted == &"":
		wanted = StringName(str(context.get("region", "graveyard")))
	current_region = wanted if tab_allowed(wanted) else &"graveyard"


func _refresh() -> void:
	for region: StringName in tab_buttons:
		var b := tab_buttons[region]
		b.visible = tab_allowed(region)
		b.theme_type_variation = &"JournalTabSelected" if region == current_region else &"JournalTabButton"
	legend_button.text = TEXT_LEGEND_OFF if legend.visible else TEXT_LEGEND_ON
	canvas.show_region(current_region, MapLayout.of(current_region, config), context, config)


## The sheet of `region` can be shown: the graveyard always, the village from its tab flag (village_open)
## – or while the gravekeeper is there.
func tab_allowed(region: StringName) -> bool:
	if config == null or not config.layouts.has(region):
		return false
	if StringName(str(context.get("region", ""))) == region:
		return true
	var flag: StringName = config.tab_flags.get(region, &"")
	if flag == &"":
		return true
	var flags: Dictionary = context.get("flags", {})
	return bool(flags.get(flag, GameState.flag_on(flag)))


func show_region(region: StringName) -> void:
	if not tab_allowed(region):
		return
	current_region = region
	refresh()


func available_regions() -> Array[StringName]:
	return REGIONS.filter(func(r: StringName) -> bool: return tab_allowed(r))


func turn_sheet(step: int) -> void:
	var list := available_regions()
	if list.size() < 2:
		return
	var i := list.find(current_region)
	show_region(list[posmod(i + step, list.size())])


func toggle_legend() -> void:
	legend.visible = not legend.visible
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	if event.is_action_pressed(&"journal_page_prev"):
		turn_sheet(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal_page_next"):
		turn_sheet(1)
		get_viewport().set_input_as_handled()


## data/config/map_config.tres (defaults without it).
static func map_config() -> MapConfig:
	var cfg := Database.config(&"map_config") as MapConfig
	return cfg if cfg != null else MapConfig.new()
