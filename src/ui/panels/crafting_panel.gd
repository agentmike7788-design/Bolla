class_name CraftingPanel
extends UIPanel
## &"crafting" – context {station: StringName, inventory: Inventory, workbench: Workbench,
## player: Player}. One row per recipe of the station (Database.recipes(station)) with
## have/need per input; "Herstellen" is disabled with the reason, otherwise it calls
## workbench.request_craft(recipe_id).
## Phase 3 (docs/PHASE3_DESIGN.md §7): recipes grouped „Grab“ / „Zier“ / „Werkzeug“
## (RecipeData.category), decor recipes with „Zier +3 – zählt je Abschnitt bis zur Obergrenze“
## (also the row tooltip); the list scrolls once it is taller than max_list_height.

const TEXT_TITLE := "Werkbank"
const TEXT_OWNED := "im Besitz: %d"
const TEXT_INPUT := "%d× %s"
const TEXT_INPUT_OK := " ✓"
const TEXT_INPUT_HAVE := " (%d da)"
const TEXT_TIME := "Dauer %s"
const TEXT_USE_MARKER := "Grabzeichen · %s Qualität"
const TEXT_USE_SHROUD := "Leichentuch · %s Qualität"
const TEXT_CRAFT := "Herstellen"
const TEXT_MISSING := "Fehlt: %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const TEXT_NO_RECIPES := "Hier lässt sich nichts herstellen."
const SHROUD_ITEM := &"shroud"
const DEFAULT_STATION := &"workbench"
const CATEGORY_ORDER: Array[StringName] = [&"grave", &"decor", &"tool"]
const CATEGORY_LABELS: Dictionary[StringName, String] = {&"grave": "Grab", &"decor": "Zier", &"tool": "Werkzeug", &"material": "Werkstoffe"}

@export var panel_width: float = 900.0
@export var output_icon_edge: float = 72.0
@export var input_icon_edge: float = 30.0
@export var max_list_height: float = 700.0

var _list: VBoxContainer
var _scroll: ScrollContainer
var _inventory: Inventory
## recipe id -> {button: Button, reason: Label}
var _rows: Dictionary[StringName, Dictionary] = {}
## Recipe whose button had keyboard focus last (&"" = none since opening).
var _focus_recipe: StringName = &""


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	_make_header(box, TEXT_TITLE)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = UIKit.vbox(12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_make_action_row(box)
	var bottom := UIKit.hbox()
	bottom.add_child(UIKit.spacer())
	var close_button := UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	box.add_child(bottom)


func _on_opened() -> void:
	_focus_recipe = &""
	_inventory = _player_inventory()
	if _inventory != null:
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _refresh() -> void:
	# The rows are rebuilt: remember which recipe's button had keyboard focus.
	for id: StringName in _rows:
		var old_button: Button = _rows[id].button
		if is_instance_valid(old_button) and old_button.has_focus():
			_focus_recipe = id
	UIKit.clear_children(_list)
	_rows.clear()
	var recipes := Database.recipes(_station())
	# Quick to slow (shroud, cross, gravestone), then by id.
	recipes.sort_custom(func(a: Resource, b: Resource) -> bool:
		var ra := a as RecipeData
		var rb := b as RecipeData
		if ra == null or rb == null:
			return rb == null and ra != null
		if _category_rank(ra.category) != _category_rank(rb.category):
			return _category_rank(ra.category) < _category_rank(rb.category)
		if ra.craft_minutes != rb.craft_minutes:
			return ra.craft_minutes < rb.craft_minutes
		return String(ra.id) < String(rb.id))
	if recipes.is_empty():
		_list.add_child(UIKit.label(TEXT_NO_RECIPES, &"DimLabel"))
		_fit_scroll.call_deferred()
		return
	var categories := {}
	for res: Resource in recipes:
		var recipe := res as RecipeData
		if recipe != null:
			categories[recipe.category] = true
	var current := &"-"
	for res: Resource in recipes:
		var recipe := res as RecipeData
		if recipe == null:
			continue
		if categories.size() > 1 and recipe.category != current:
			current = recipe.category
			_list.add_child(UIKit.label(CATEGORY_LABELS.get(current, String(current)), &"AccentLabel"))
		_list.add_child(_make_row(recipe))
	_fit_scroll.call_deferred()


## Scroll height = list height, at most max_list_height.
func _fit_scroll() -> void:
	if _scroll == null or _list == null:
		return
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, max_list_height)


static func _category_rank(category: StringName) -> int:
	var i := CATEGORY_ORDER.find(category)
	return i if i >= 0 else CATEGORY_ORDER.size()


## After a rebuild (craft, inventory change) focus returns to the recipe used last, if it
## can still be crafted; otherwise the first enabled button.
func focus_default() -> void:
	var again := craft_button(_focus_recipe)
	if again != null and not again.disabled and again.is_visible_in_tree():
		again.grab_focus()
		return
	super.focus_default()


## Why `recipe` cannot be crafted right now ("" = it can).
func block_reason(recipe: RecipeData) -> String:
	if action_running:
		return TEXT_BUSY
	if not is_instance_valid(_inventory):
		return TEXT_MISSING % _missing_text(recipe.inputs)
	var missing := CraftingSystem.missing(recipe, _inventory)
	if not missing.is_empty():
		return TEXT_MISSING % _missing_text(missing)
	if not CraftingSystem.can_craft(recipe, _inventory):
		return TEXT_NO_ROOM
	return ""


## Recipe ids in display order.
func recipe_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_rows.keys())
	return out


func craft_button(recipe_id: StringName) -> Button:
	return _rows[recipe_id].button if _rows.has(recipe_id) else null


func reason_text(recipe_id: StringName) -> String:
	return (_rows[recipe_id].reason as Label).text if _rows.has(recipe_id) else ""


func _make_row(recipe: RecipeData) -> Control:
	var section := UIKit.panel(&"SectionPanel")
	var row := UIKit.hbox(18)
	section.add_child(row)
	row.add_child(UIKit.icon(Database.icon(recipe.output_id), output_icon_edge))
	var info := UIKit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := UIKit.hbox(12)
	title_row.add_child(UIKit.label(_recipe_name(recipe), &"SubheaderLabel"))
	var owned := _inventory.count(recipe.output_id) if is_instance_valid(_inventory) else 0
	title_row.add_child(UIKit.label(TEXT_OWNED % owned, &"DimLabel"))
	info.add_child(title_row)
	var inputs := UIKit.hbox(16)
	for id: StringName in recipe.inputs:
		var need: int = recipe.inputs[id]
		var have := _inventory.count(id) if is_instance_valid(_inventory) else 0
		var chip := UIKit.hbox(6)
		chip.add_child(UIKit.icon(Database.icon(id), input_icon_edge))
		var text := TEXT_INPUT % [need, UIKit.item_name(id)]
		text += TEXT_INPUT_OK if have >= need else TEXT_INPUT_HAVE % have
		chip.add_child(UIKit.label(text, &"GoodLabel" if have >= need else &"WarningLabel"))
		inputs.add_child(chip)
	info.add_child(inputs)
	var details := PackedStringArray([TEXT_TIME % UIKit.minutes(recipe.craft_minutes)])
	var use := _use_text(recipe.output_id)
	if use != "":
		details.append(use)
	var decor_hint := Phase3Texts.recipe_decor_hint(Database.decor(recipe.output_id) as DecorData) if Database.has_decor(recipe.output_id) else ""
	if decor_hint != "":
		details.append(decor_hint)
		section.tooltip_text = "%s\n%s" % [decor_hint, Phase3Texts.decor_tooltip(Database.decor(recipe.output_id) as DecorData)]
	info.add_child(UIKit.label(" · ".join(details), &"DimLabel"))
	row.add_child(info)
	var action := UIKit.vbox(4)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var button := UIKit.button(TEXT_CRAFT, &"AccentButton")
	var reason := block_reason(recipe)
	button.disabled = reason != ""
	button.tooltip_text = reason
	button.pressed.connect(_on_craft_pressed.bind(recipe.id))
	action.add_child(button)
	var reason_label := UIKit.label(reason, &"WarningLabel" if reason != TEXT_BUSY else &"DimLabel")
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.visible = reason != ""
	action.add_child(reason_label)
	row.add_child(action)
	_rows[recipe.id] = {"button": button, "reason": reason_label}
	return section


func _use_text(output_id: StringName) -> String:
	var economy := _economy()
	if economy.marker_quality.has(output_id):
		return TEXT_USE_MARKER % UIKit.signed(economy.marker_quality[output_id])
	if output_id == SHROUD_ITEM:
		return TEXT_USE_SHROUD % UIKit.signed(economy.quality_shroud)
	return ""


func _missing_text(missing: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: Variant in missing:
		parts.append("%d %s" % [int(missing[id]), UIKit.item_name(StringName(id))])
	return ", ".join(parts)


func _recipe_name(recipe: RecipeData) -> String:
	return recipe.display_name if recipe.display_name != "" else UIKit.item_name(recipe.output_id)


func _station() -> StringName:
	var station: Variant = context.get("station", DEFAULT_STATION)
	return StringName(station) if (station is String or station is StringName) and String(station) != "" else DEFAULT_STATION


func _on_craft_pressed(recipe_id: StringName) -> void:
	_focus_recipe = recipe_id
	var recipe := Database.recipe(recipe_id) as RecipeData
	if recipe == null or block_reason(recipe) != "":
		return
	var bench: Variant = context.get("workbench")
	if not is_instance_valid(bench) or not (bench as Object).has_method(&"request_craft"):
		push_warning("[CraftingPanel] workbench has no request_craft()")
		return
	(bench as Object).call(&"request_craft", recipe_id)
