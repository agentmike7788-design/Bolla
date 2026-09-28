class_name CraftingPanel
extends UIPanel
## &"crafting" – context {station: StringName, inventory: Inventory, workbench: Workbench,
## player: Player}. One row per recipe of the station (Database.recipes(station)) with
## have/need per input; "Herstellen" is disabled with the reason, otherwise it calls
## workbench.request_craft(recipe_id).
## Phase 3 (docs/PHASE3_DESIGN.md §7): recipes grouped „Grab“ / „Zier“ / „Werkzeug“
## (RecipeData.category), decor recipes with „Zier +3 – zählt je Abschnitt bis zur Obergrenze“
## (also the row tooltip); the list scrolls once it is taller than max_list_height.
## Phase 5 (docs/PHASE5_DESIGN.md §7): one panel per station (mason has its own stone panel) –
## the title is StationData.display_name („Esse", „Webstuhl", „Werkbank"), groups Werkstoffe ·
## Werkzeug · Grab · Zier; a tool recipe shows the tool it replaces („ersetzt: Eisenschaufel") and
## its effect („Graben 50 → 35 Min"); the background recipe (the kiln) shows „läuft allein ·
## 8 Std." and, while its job runs, a progress bar with „fertig um 06:10 · noch 3 Std. 20 Min"
## (ready: „fertig – holen"). Station tabs do not exist: one always stands at exactly one station.
## Phase 6 (docs/PHASE6_DESIGN.md §2.5, §7): from shed 2 every input chip says „im Schuppen: n" and
## a recipe with something missing gets „Fehlendes holen (10 Min)" (workbench.request_fetch(inputs),
## dimmed with ShedSupply's reason); from shed 3 „Überschuss einlagern" (workbench.request_store()).

const TEXT_TITLE := "Werkbank"
const TEXT_OWNED := "im Besitz: %d"
const TEXT_INPUT := "%d× %s"
const TEXT_INPUT_OK := " ✓"
const TEXT_INPUT_HAVE := " (%d da)"
const TEXT_INPUT_SHED := "im Schuppen: %d"
const TEXT_TIME := "Dauer %s"
const TEXT_USE_MARKER := "Grabzeichen · %s Qualität"
const TEXT_USE_SHROUD := "Leichentuch · %s Qualität"
const TEXT_CRAFT := "Herstellen"
const TEXT_MISSING := "Fehlt: %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const TEXT_NO_RECIPES := "Hier lässt sich nichts herstellen."
const SHROUD_ITEM := &"shroud"
const DEFAULT_STATION := &"workbench"
const CATEGORY_ORDER: Array[StringName] = [&"material", &"tool", &"grave", &"decor"]
const WORKSHOP_GROUP := &"workshop"
const CATEGORY_LABELS: Dictionary[StringName, String] = {&"grave": "Grab", &"decor": "Zier", &"tool": "Werkzeug", &"material": "Werkstoffe"}

@export var panel_width: float = 900.0
@export var output_icon_edge: float = 60.0
@export var input_icon_edge: float = 30.0
@export var max_list_height: float = 780.0

var _list: VBoxContainer
var _scroll: ScrollContainer
var _inventory: Inventory
## recipe id -> {button: Button, reason: Label, fetch: Button (null without the shed)}
var _rows: Dictionary[StringName, Dictionary] = {}
## Recipe whose button had keyboard focus last (&"" = none since opening).
var _focus_recipe: StringName = &""
var title_label: Label
## Background job row of the station (kiln), rebuilt with the list; null without a job.
var job_bar: ProgressBar
var job_label: Label
## Bottom row: „Überschuss einlagern" (shed 3).
var shed_bar: ShedFetchBar


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	title_label = _make_header(box, TEXT_TITLE)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = UIKit.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_make_action_row(box)
	var bottom := UIKit.hbox(16)
	shed_bar = ShedFetchBar.new()
	shed_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shed_bar.store_pressed.connect(_on_store_pressed)
	bottom.add_child(shed_bar)
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
	job_bar = null
	job_label = null
	title_label.text = station_title()
	# Only „Überschuss einlagern" lives in the bottom row (fetching is per recipe).
	var store_state := Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, {}, _inventory)
	store_state["reason"] = ShedSupply.TEXT_NOTHING_MISSING
	shed_bar.show_state(store_state, action_running)
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
	if recipe.background:
		var shop := workshop()
		if shop != null and not shop.job_of(_station()).is_empty():
			return Workbench.TEXT_JOB_RUNNING
	var tool := Database.item(recipe.output_id) as ItemData if Database.has_item(recipe.output_id) else null
	if tool != null and tool.tool_kind != &"" and _inventory.tool_belt:
		var have := ToolRules.tier(_inventory, tool.tool_kind)
		if have == tool.tool_tier:
			return Phase5Texts.TOOL_HAVE
		if have > tool.tool_tier:
			return Phase5Texts.TOOL_HAVE_BETTER % ToolRules.tool_name(tool.tool_kind, have, Database.config(&"tool_config") as ToolConfig)
	var missing := CraftingSystem.missing(recipe, _inventory)
	if not missing.is_empty():
		return TEXT_MISSING % _missing_text(missing)
	if recipe.background:
		return ""  # the yield comes later (collect checks the room)
	if not CraftingSystem.can_craft(recipe, _inventory):
		return TEXT_NO_ROOM
	return ""


## Recipe ids in display order.
func recipe_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_rows.keys())
	return out


## The shed state of `recipe`'s inputs (Phase6Texts.shed_state_in; shown from shed 2).
func shed_state(recipe: RecipeData) -> Dictionary:
	return Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, recipe.inputs if recipe != null else {}, _inventory)


## „Fehlendes holen" of a recipe (null below shed 2 / nothing missing).
func fetch_button(recipe_id: StringName) -> Button:
	return _rows[recipe_id].get("fetch") as Button if _rows.has(recipe_id) else null


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
	var shed := shed_state(recipe)
	var shed_shown := bool(shed.get("shown", false))
	var in_shed: Dictionary = shed.get("available", {})
	for id: StringName in recipe.inputs:
		var need: int = recipe.inputs[id]
		var have := _inventory.count(id) if is_instance_valid(_inventory) else 0
		var chip := UIKit.hbox(6)
		chip.add_child(UIKit.icon(Database.icon(id), input_icon_edge))
		var text := TEXT_INPUT % [need, UIKit.item_name(id)]
		text += TEXT_INPUT_OK if have >= need else TEXT_INPUT_HAVE % have
		chip.add_child(UIKit.label(text, &"GoodLabel" if have >= need else &"WarningLabel"))
		if shed_shown:
			chip.add_child(UIKit.label(TEXT_INPUT_SHED % int(in_shed.get(id, 0)), &"DimLabel"))
		inputs.add_child(chip)
	info.add_child(inputs)
	var details := PackedStringArray([TEXT_TIME % UIKit.minutes(recipe.craft_minutes)])
	var use := _use_text(recipe.output_id)
	if use != "":
		details.append(use)
	details.append_array(phase5_details(recipe))
	var decor_hint := Phase3Texts.recipe_decor_hint(Database.decor(recipe.output_id) as DecorData) if Database.has_decor(recipe.output_id) else ""
	if decor_hint != "":
		details.append(decor_hint)
		section.tooltip_text = "%s\n%s" % [decor_hint, Phase3Texts.decor_tooltip(Database.decor(recipe.output_id) as DecorData)]
	info.add_child(UIKit.label(" · ".join(details), &"DimLabel"))
	if recipe.background:
		_add_job_row(info, recipe)
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
	var fetch: Button = null
	var fetch_reason := str(shed.get("reason", ""))
	if shed_shown and fetch_reason != ShedSupply.TEXT_NOTHING_MISSING:
		fetch = UIKit.button(Phase6Texts.fetch_button(int(shed.get("minutes", 0)), true))
		fetch.disabled = action_running or fetch_reason != ""
		fetch.tooltip_text = fetch_reason
		fetch.pressed.connect(_on_fetch_pressed.bind(recipe.id))
		action.add_child(fetch)
		if fetch_reason != "":
			var why := UIKit.label(fetch_reason, &"DimLabel")
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			action.add_child(why)
	row.add_child(action)
	_rows[recipe.id] = {"button": button, "reason": reason_label, "fetch": fetch}
	return section


## Title: StationData.display_name of the station („Esse"), else „Werkbank".
func station_title() -> String:
	var data := Database.station(_station()) as StationData
	return data.display_name if data != null and data.display_name != "" else TEXT_TITLE


## Phase-5 detail parts of a row: the replaced tool and its effect (tool recipes), „läuft allein ·
## 8 Std." (background recipe).
func phase5_details(recipe: RecipeData) -> PackedStringArray:
	var out := PackedStringArray()
	var tool := Database.item(recipe.output_id) as ItemData if Database.has_item(recipe.output_id) else null
	if tool != null and tool.tool_kind != &"":
		# The recipe consumes the lower tool of the kind: the effect counts from that one, else from the
		# tier on the belt (never from the tier being made).
		var from_tier := ToolRules.tier(_inventory, tool.tool_kind) if is_instance_valid(_inventory) else 0
		for id: StringName in recipe.inputs:
			var input := Database.item(id) as ItemData if Database.has_item(id) else null
			if input != null and input.tool_kind == tool.tool_kind:
				out.append(Phase5Texts.TOOL_REPLACES % input.display_name)
				from_tier = input.tool_tier
		var effect := Phase5Texts.tool_effect(tool.tool_kind, mini(from_tier, tool.tool_tier - 1), tool.tool_tier, _action_config())
		if effect != "":
			out.append(effect)
	if recipe.background:
		out.append(Phase5Texts.KILN_ALONE % Phase5Texts.duration(_background_minutes(recipe)))
	return out


## Job text of the station's background job: "fertig um 06:10 · noch 3 Std. 20 Min" / "fertig –
## holen" ("" without a job).
func job_text() -> String:
	return job_label.text if job_label != null else ""


## 0…1 of the running job (0 without one).
func job_ratio() -> float:
	return job_bar.value if job_bar != null else 0.0


func _add_job_row(info: VBoxContainer, recipe: RecipeData) -> void:
	var shop := workshop()
	var job := shop.job_of(_station()) if shop != null else {}
	if job.is_empty() or StringName(str(job.get("recipe", ""))) != recipe.id:
		return
	var box := UIKit.hbox(12)
	job_bar = UIKit.bar()
	job_bar.custom_minimum_size = Vector2(220.0, 16.0)
	job_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var total := maxi(_background_minutes(recipe), 1)
	var left := maxi(int(job.end_total) - TimeManager.total_minutes(), 0)
	job_bar.value = clampf(1.0 - float(left) / total, 0.0, 1.0)
	box.add_child(job_bar)
	var text := Phase5Texts.KILN_READY if bool(job.get("ready", false)) else "%s · %s" % [
			Phase5Texts.KILN_UNTIL % UIKit.clock(int(job.end_total)), Phase5Texts.KILN_LEFT % Phase5Texts.duration(left)]
	job_label = UIKit.label(text, &"GoodLabel" if bool(job.get("ready", false)) else &"AccentLabel")
	box.add_child(job_label)
	info.add_child(box)


func _background_minutes(recipe: RecipeData) -> int:
	var shop := workshop()
	var cfg := shop.workshop_config() if shop != null else (Database.config(&"workshop_config") as WorkshopConfig)
	return cfg.background_minutes if cfg != null and cfg.background_minutes > 0 else recipe.craft_minutes


## Systems/Workshop (group workshop), or the one given in the context ("workshop") – tests.
func workshop() -> Workshop:
	var given: Variant = context.get("workshop")
	if is_instance_valid(given) and given is Workshop:
		return given
	return get_tree().get_first_node_in_group(WORKSHOP_GROUP) as Workshop if is_inside_tree() else null


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


func _on_fetch_pressed(recipe_id: StringName) -> void:
	_focus_recipe = recipe_id
	var recipe := Database.recipe(recipe_id) as RecipeData
	var bench: Variant = context.get("workbench")
	if recipe == null or not is_instance_valid(bench) or not (bench as Object).has_method(&"request_fetch"):
		return
	(bench as Object).call(&"request_fetch", recipe.inputs)


func _on_store_pressed() -> void:
	var bench: Variant = context.get("workbench")
	if is_instance_valid(bench) and (bench as Object).has_method(&"request_store"):
		(bench as Object).call(&"request_store")
