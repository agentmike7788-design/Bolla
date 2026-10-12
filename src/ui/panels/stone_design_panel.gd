class_name StoneDesignPanel
extends UIPanel
## &"stone_design" – the stonemason's bench (docs/PHASE5_DESIGN.md §2.5, §7): context {inventory,
## player, bench} (+ station, workbench from the Workbench; "stonemasonry" overrides the node of
## group &"stonemasonry" – tests). Parchment like the Merkbuch, three pages:
## - left „Gräber": FILLED / MARKED graves (Stonemasonry.eligible_graves) with section, current
##   marker and quality, „ohne Namen zuerst" as a toggle; dimmed with the reason when no better
##   stone is possible (or a stone already waits for it). [ / ] (journal_page_prev / _next) page
##   through the list. Below: the rack „Fertige Steine" – „bereit" or „passt nicht mehr" with
##   „Verwerfen" (two presses, like harvesting).
## - middle „Gestaltung": Form (3 cards: points, material, minutes) · Inschrift („ohne" + one row
##   per template with the real text of the chosen dead, badge „passt – …"; the switch „vergoldet"
##   with the gold leaf in the pack, only with an inscription) · Zierde („ohne" + 4 cards with
##   their meaning as tooltip).
## - right „Vorschau": StonePreview (own SubViewport, rendered on change only), „Grab 13 → 19",
##   the breakdown lines, material have / need, minutes and „Stein hauen (205 Min)" with the
##   block reason. Header: „Ablage: 2/3 fertig".
## Every number comes from Stonemasonry.preview – the panel never computes quality itself.
## Phase 6 (docs/PHASE6_DESIGN.md §2.5, §7): from shed 2 the material rows add „Schuppen: n" and
## „Fehlendes aus dem Schuppen holen (10 Min)" calls bench.request_fetch(design inputs); from shed 3
## „Überschuss einlagern" (bench.request_store()).
## Phase 8 (docs/PHASE8_DESIGN.md §2.11, W1-Anschlüsse 4): below the pages the bench's other work – the recipes of the
## station mason that CraftingPanel.offered() lets through (the memorial plate „Namenstafel" once Rosine's second
## step set friend_innkeeper_2): name, inputs have / need, minutes and „Herstellen" (bench.request_craft), dimmed with
## what is missing.
## G8 Runde 4 (Prüfung der Arbeits-Panels): while a work started from it runs („Stein hauen", „Fehlendes holen", an
## extra recipe) the panel is hidden (UIPanel.hide_while_working – the HUD's action bar shows the work, the
## gravekeeper chisels visibly) and comes back afterwards.
## G8 Runde 5 (user: „bitte die bekannten probleme mal fixen" – the three pages covered the world while designing):
## docked at the right edge like the other work panels (UIPanel.dock_right, no dim) in one parchment column of
## panel_width: on top the preview (the 3D stone, smaller, beside it „Grab 13 → 19", the points and the breakdown),
## then four tabs Grab · Form · Inschrift · Zierde (the former left and middle pages, the text of the inscription on its
## tab; one page shown, it scrolls in the height the screen leaves, as tall as the tallest page), below them material,
## minutes, the block reason, the
## shed row and „Stein hauen", then the bench's other work. Keyboard: Q / E (the actions drop / interact) switch the
## tab, the arrow keys move between the cards, Enter chooses, [ / ] page the graves (on the grave tab), Esc closes;
## every card, tab and button takes the focus (amber ink frame), the focus stays on a card when it is chosen.

const STONEMASONRY_GROUP := &"stonemasonry"
const MASON_STATION := &"mason"
const TEXT_EXTRA := "Weitere Arbeit:"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const ANIM := &"interact"
const GRAVES_PER_PAGE := 7

const TEXT_TITLE := "Steinmetzbank"
const TEXT_RACK := "Ablage: %d/%d fertig"
const TEXT_GRAVES := "Gräber"
const TEXT_NAMELESS_FIRST := "ohne Namen zuerst"
const TEXT_ALL_ORDER := "nach Lage"
const TEXT_PAGE := "Seite %d/%d · [ / ] blättern"
const TEXT_NO_GRAVES := "Noch liegt niemand in einem Grab, das einen Stein tragen könnte."
const TEXT_GRAVE_META := "%s · %s · Qualität %d"
const TEXT_NO_MARKER := "ohne Zeichen"
const TEXT_NAMED := " (mit Namen)"
const TEXT_WAITING := "Ein Stein liegt schon bereit."
const TEXT_DESIGN := "Gestaltung"
const TEXT_SHAPE := "Form"
const TEXT_SHAPE_META := "+%d · %s · %s"
const TEXT_INSCRIPTION := "Inschrift"
const TEXT_INSCRIPTION_FOR := "Inschrift für %s"
const TEXT_SHAPE_POINTS := "+%d · %s"
const TEXT_STONE_SUM := "Stein: %d von %d Punkten"
const TEXT_NO_INSCRIPTION := "ohne Inschrift"
const TEXT_NO_INSCRIPTION_META := "Der Stein bleibt namenlos."
const TEXT_FITS := "passt – %s"
const TEXT_FITS_STORY := "Geschichte"
const TEXT_FITS_CAUSE := "Todesursache"
const TEXT_FITS_AGE := "Alter"
const TEXT_FITS_TOOLTIP := "passt zu %s"
const TEXT_GILDED := "vergoldet · Blattgold: %d"
const TEXT_GILDED_NEEDS := "vergoldet (nur mit Inschrift)"
const TEXT_ORNAMENT := "Zierde"
const TEXT_NO_ORNAMENT := "ohne"
const TEXT_PREVIEW := "Vorschau"
const TEXT_PICK_GRAVE := "Wähle links ein Grab."
const TEXT_QUALITY := "Grab %d → %d"
const TEXT_LINE := "%s %s"
const TEXT_MATERIAL := "Material"
const TEXT_CARVE := "Stein hauen (%s)"
const TEXT_SHED := " · Schuppen %d"
const TEXT_CARVE_LABEL := "Stein hauen"
const TEXT_CARVED := "Der Stein für %s steht in der Ablage."
const TEXT_READY_STONES := "Fertige Steine"
const TEXT_RACK_EMPTY := "Die Ablage ist leer."
const TEXT_READY := "bereit"
const TEXT_STALE := "passt nicht mehr"
const TEXT_DISCARD := "Verwerfen"
const TEXT_DISCARD_CONFIRM := "Wirklich verwerfen?"
const TEXT_HINT := "Pfeile + Enter wählen · [ / ] Gräber blättern · [Esc] schließen"
## G8 Runde 5: the tabs of the docked column (the former left and middle pages).
const TAB_GRAVE := &"grave"
const TAB_SHAPE := &"shape"
const TAB_INSCRIPTION := &"inscription"
const TAB_ORNAMENT := &"ornament"
const TABS: Array[StringName] = [TAB_GRAVE, TAB_SHAPE, TAB_INSCRIPTION, TAB_ORNAMENT]
const TAB_LABELS: Dictionary[StringName, String] = {
	TAB_GRAVE: "Grab", TAB_SHAPE: "Form", TAB_INSCRIPTION: "Inschrift", TAB_ORNAMENT: "Zierde",
}
## The keys of the tab switch: the actions drop (Q) and interact (E) – no new input action (PHASE5_DESIGN §3.6).
const ACTION_TAB_PREV := &"drop"
const ACTION_TAB_NEXT := &"interact"
const KEY_TAB_PREV := "Q"
const KEY_TAB_NEXT := "E"
const TEXT_MATERIAL_ROW := "Material:"
## Meta of every rebuilt card: "<tab>:<id>" – the focus stays on the same card through a rebuild.
const META_KEY := &"focus_key"

## G8 Runde 5: one docked column (was three pages of 470 + 660 + 540 px in the middle).
@export var panel_width: float = 660.0
@export var preview_size: Vector2i = Vector2i(230, 210)
@export var grave_card_height: float = 62.0
@export var shape_card_height: float = 118.0
@export var inscription_card_height: float = 94.0
@export var ornament_card_height: float = 66.0

## Phase 8: the rows of the bench's other recipes and their buttons (recipe id → Button).
var extra_box: VBoxContainer
var extra_buttons: Dictionary[StringName, Button] = {}
var masonry: Node
var grave_id: String = ""
var shape: StringName = &""
var inscription: StringName = &""
var ornament: StringName = &""
var gilded: bool = false
var nameless_first: bool = true
var page: int = 0
## Order id waiting for the confirming second press of „Verwerfen" ("" = none).
var confirm_discard: String = ""
## Last Stonemasonry.preview() ({} = no grave chosen).
var current_preview: Dictionary = {}

var rack_label: Label
var preview: StonePreview
var carve_button: Button
## Phase 6: fetch / store row above the carve button.
var shed_bar: ShedFetchBar
var reason_label: Label
var quality_label: Label
var gilded_toggle: CheckBox
## grave id -> its card button
var grave_buttons: Dictionary[String, Button] = {}
var shape_buttons: Dictionary[StringName, Button] = {}
## inscription id (&"" = none) -> its row button
var inscription_buttons: Dictionary[StringName, Button] = {}
var ornament_buttons: Dictionary[StringName, Button] = {}
## order id -> its discard button
var discard_buttons: Dictionary[String, Button] = {}
## G8 Runde 5: the tab shown, its buttons and pages, the scrolling body of the pages.
var current_tab: StringName = TAB_GRAVE
var tab_buttons: Dictionary[StringName, Button] = {}
var pages: Dictionary[StringName, VBoxContainer] = {}
var body_scroll: ScrollContainer
var _pages_box: VBoxContainer
## focus key ("<tab>:<id>") -> the card button of the last rebuild
var _keyed: Dictionary[String, Button] = {}

var _graves_box: VBoxContainer
var _page_label: Label
var _filter_button: Button
var _rack_box: VBoxContainer
var _shape_row: HBoxContainer
var _ins_box: GridContainer
var _ins_title: Label
var _text_label: Label
var _orn_row: GridContainer
var _lines_box: GridContainer
var _minutes_label: Label
var _material_grid: HFlowContainer
var _sum_label: Label
var _inventory: Inventory


func _init() -> void:
	super._init()
	dock_right = true
	hide_while_working = true


func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_fit_body)


## G8 Runde 5: header · one parchment sheet (preview, tabs, the scrolling page, material and „Stein hauen", the bench's
## other work) · action row · hint.
func _build() -> void:
	theme_type_variation = &"LedgerPanel"
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(10)
	add_child(box)
	var head := UIKit.hbox(16)
	var title := UIKit.label(TEXT_TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	rack_label = UIKit.label("", &"SubheaderLabel")
	rack_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rack_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var sheet := UIKit.panel(&"LedgerColumnPanel")
	box.add_child(sheet)
	var col := UIKit.vbox(10)
	sheet.add_child(col)
	_build_preview(col)
	_build_tab_bar(col)
	var dock := make_dock_scroll(col, 0)
	body_scroll = dock[0] as ScrollContainer
	_pages_box = dock[1] as VBoxContainer
	_pages_box.minimum_size_changed.connect(_fit_body)
	_build_grave_page(_add_page(TAB_GRAVE))
	_build_shape_page(_add_page(TAB_SHAPE))
	_build_inscription_page(_add_page(TAB_INSCRIPTION))
	_build_ornament_page(_add_page(TAB_ORNAMENT))
	col.add_child(UIKit.separator())
	_build_footer(col)
	extra_box = UIKit.vbox(6)
	extra_box.visible = false
	col.add_child(extra_box)
	_make_action_row(box)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel", true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_show_tab()


## The preview strip: the 3D stone (preview_size), beside it the quality, the points and the breakdown lines; the text
## of the inscription under both (one line, it wraps).
func _build_preview(parent: Container) -> void:
	var strip := UIKit.hbox(16)
	parent.add_child(strip)
	preview = StonePreview.new()
	preview.name = "StonePreview"
	preview.view_size = preview_size
	preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip.add_child(preview)
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(info)
	quality_label = UIKit.label("", &"InkHeaderLabel", true)
	info.add_child(quality_label)
	_sum_label = UIKit.label("", &"InkDimLabel", true)
	info.add_child(_sum_label)
	_lines_box = _grid(1, 0, 0)
	info.add_child(_lines_box)


## Q · Grab · Form · Inschrift · Zierde · E
func _build_tab_bar(parent: Container) -> void:
	var bar := UIKit.hbox(4)
	parent.add_child(bar)
	var prev := UIKit.keycap(KEY_TAB_PREV)
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(prev)
	for tab: StringName in TABS:
		var b := UIKit.button(TAB_LABELS[tab], &"LedgerTabButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(select_tab.bind(tab))
		bar.add_child(b)
		tab_buttons[tab] = b
	var next := UIKit.keycap(KEY_TAB_NEXT)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(next)


func _add_page(tab: StringName) -> VBoxContainer:
	var page_box := UIKit.vbox(8)
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages_box.add_child(page_box)
	pages[tab] = page_box
	return page_box


func _build_grave_page(page_box: VBoxContainer) -> void:
	var head := UIKit.hbox(8)
	var t := UIKit.label(TEXT_GRAVES, &"LedgerHeadLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	_filter_button = UIKit.button("", &"LedgerTabButton")
	_filter_button.pressed.connect(toggle_filter)
	head.add_child(_filter_button)
	page_box.add_child(head)
	_graves_box = UIKit.vbox(6)
	page_box.add_child(_graves_box)
	_page_label = UIKit.label("", &"InkDimLabel")
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_box.add_child(_page_label)
	page_box.add_child(UIKit.label(TEXT_READY_STONES, &"LedgerHeadLabel"))
	_rack_box = UIKit.vbox(6)
	page_box.add_child(_rack_box)


func _build_shape_page(page_box: VBoxContainer) -> void:
	page_box.add_child(UIKit.label(TEXT_SHAPE, &"LedgerHeadLabel"))
	_shape_row = UIKit.hbox(8)
	page_box.add_child(_shape_row)


func _build_inscription_page(page_box: VBoxContainer) -> void:
	_ins_title = UIKit.label(TEXT_INSCRIPTION, &"LedgerHeadLabel", true)
	page_box.add_child(_ins_title)
	# the text of the chosen inscription (one line, it wraps; the 3D preview shows it on the stone)
	_text_label = UIKit.label("", &"InkDimLabel", true)
	page_box.add_child(_text_label)
	gilded_toggle = CheckBox.new()
	gilded_toggle.theme_type_variation = &"LedgerInkButton"
	gilded_toggle.focus_mode = Control.FOCUS_ALL
	gilded_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gilded_toggle.toggled.connect(set_gilded)
	page_box.add_child(gilded_toggle)
	_ins_box = _grid(2, 6, 6)
	page_box.add_child(_ins_box)


func _build_ornament_page(page_box: VBoxContainer) -> void:
	page_box.add_child(UIKit.label(TEXT_ORNAMENT, &"LedgerHeadLabel"))
	_orn_row = _grid(3, 6, 6)
	page_box.add_child(_orn_row)


## Material (one flowing row), minutes and „Stein hauen", the block reason, the shed row.
func _build_footer(parent: Container) -> void:
	var mat := HFlowContainer.new()
	mat.add_theme_constant_override(&"h_separation", 16)
	mat.add_theme_constant_override(&"v_separation", 2)
	parent.add_child(mat)
	_material_grid = mat
	var carve_row := UIKit.hbox(12)
	parent.add_child(carve_row)
	_minutes_label = UIKit.label("", &"InkDimLabel")
	_minutes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minutes_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carve_row.add_child(_minutes_label)
	carve_button = UIKit.button("", &"LedgerInkButton")
	carve_button.pressed.connect(carve)
	carve_row.add_child(carve_button)
	reason_label = UIKit.label("", &"LedgerWarnLabel", true)
	parent.add_child(reason_label)
	shed_bar = ShedFetchBar.new(true, true)
	# the narrow column: the shed's reason wraps instead of widening the panel
	shed_bar.reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shed_bar.fetch_pressed.connect(_on_fetch_pressed)
	shed_bar.store_pressed.connect(_on_store_pressed)
	parent.add_child(shed_bar)


func _on_opened() -> void:
	var m: Variant = context.get("stonemasonry")
	masonry = m if is_instance_valid(m) else (get_tree().get_first_node_in_group(STONEMASONRY_GROUP) if is_inside_tree() else null)
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)
	confirm_discard = ""
	page = 0
	# G8 Runde 5: every opening starts on the grave tab, at the top
	current_tab = TAB_GRAVE
	_show_tab()
	body_scroll.scroll_vertical = 0
	if grave_id != "" and _entry(grave_id).is_empty():
		grave_id = ""
	if grave_id == "":
		var first := _first_choice()
		if first != "":
			select_grave(first, false)
	if shape == &"":
		shape = _first_shape()


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	if event.is_action_pressed(&"journal_page_prev"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal_page_next"):
		turn_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_TAB_PREV):
		step_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_TAB_NEXT):
		step_tab(1)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	# the cards are rebuilt: the focused one keeps the focus (by its key)
	var focus_key := _focused_key()
	_keyed.clear()
	var slots := _ready_slots()
	var stones := ready_stones()
	rack_label.text = TEXT_RACK % [stones.size(), slots]
	_refresh_graves()
	_refresh_rack(stones)
	_refresh_design()
	_refresh_preview()
	_refresh_extra()
	_fit_body.call_deferred()
	if focus_key != "" and _keyed.has(focus_key) and _keyed[focus_key].is_visible_in_tree():
		_keyed[focus_key].grab_focus()
		# the new card is laid out at the end of the frame: scroll it into view then
		_reveal_card.call_deferred(_keyed[focus_key])


# --- tabs (G8 Runde 5) --------------------------------------------------------------------------

## Shows `tab` (one of TABS) with the focus on its chosen card.
func select_tab(tab: StringName) -> void:
	if not tab in TABS:
		return
	current_tab = tab
	_show_tab()
	body_scroll.scroll_vertical = 0
	focus_default()


## ±1 tab, wrapping (Q / E).
func step_tab(step: int) -> void:
	select_tab(TABS[posmod(TABS.find(current_tab) + step, TABS.size())])


func _show_tab() -> void:
	for tab: StringName in TABS:
		pages[tab].visible = tab == current_tab
		tab_buttons[tab].theme_type_variation = &"LedgerTabSelected" if tab == current_tab else &"LedgerTabButton"


## The default focus: the chosen card of the tab shown (else its first free button), else „Stein hauen", else the
## first free button of the panel.
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	var target: Control = chosen_card(current_tab)
	if target == null or not target.is_visible_in_tree():
		target = UIKit.first_focusable(pages[current_tab])
	if target == null and not carve_button.disabled:
		target = carve_button
	if target != null and target.is_visible_in_tree():
		target.grab_focus()
		_reveal_card.call_deferred(target)
		return
	super.focus_default()


## The chosen card of `tab` (null: none chosen / none shown).
func chosen_card(tab: StringName) -> Button:
	match tab:
		TAB_GRAVE:
			return grave_buttons.get(grave_id) as Button
		TAB_SHAPE:
			return shape_buttons.get(shape) as Button
		TAB_INSCRIPTION:
			return inscription_buttons.get(inscription) as Button
		TAB_ORNAMENT:
			return ornament_buttons.get(ornament) as Button
	return null


## The body as tall as the tallest tab page (the panel keeps its height when the tab changes), at most what the
## screen leaves beside preview, tabs and footer.
func _fit_body() -> void:
	if body_scroll == null:
		return
	var tallest := 0.0
	for tab: StringName in TABS:
		tallest = maxf(tallest, pages[tab].get_combined_minimum_size().y)
	fit_dock_scroll(body_scroll, null, 0.0, tallest)


func _fit_dock() -> void:
	_fit_body()


func _focused_key() -> String:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null and is_ancestor_of(owner) and owner.has_meta(META_KEY):
		return str(owner.get_meta(META_KEY))
	return ""


func _key(b: Button, tab: StringName, id: String) -> void:
	var key := "%s:%s" % [tab, id]
	b.set_meta(META_KEY, key)
	_keyed[key] = b


## The focused card in view after the layout of the frame (the pages are the direct rows of the body, so
## UIPanel.reveal would bring the whole page into view instead of the card).
func _reveal_card(card: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(card) and is_instance_valid(body_scroll) and body_scroll.is_ancestor_of(card) and card.is_visible_in_tree():
		body_scroll.ensure_control_visible(card)


## Phase 8: the mason's recipes that are offered now (the memorial plate).
func extra_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for r: Resource in Database.recipes(MASON_STATION):
		var recipe := r as RecipeData
		if recipe != null and recipe.requires_flag != &"" and CraftingPanel.offered(recipe):
			out.append(recipe)
	return out


## „Herstellen" of an extra recipe (Workbench.request_craft – the bench runs the timed action).
func craft_extra(recipe_id: StringName) -> void:
	var bench: Variant = context.get("bench", context.get("workbench"))
	if is_instance_valid(bench) and (bench as Object).has_method(&"request_craft"):
		(bench as Object).call(&"request_craft", recipe_id)


func _refresh_extra() -> void:
	UIKit.clear_children(extra_box)
	extra_buttons.clear()
	var list := extra_recipes()
	extra_box.visible = not list.is_empty()
	if list.is_empty():
		return
	extra_box.add_child(UIKit.separator())
	extra_box.add_child(UIKit.label(TEXT_EXTRA, &"LedgerHeadLabel"))
	for recipe: RecipeData in list:
		var row := UIKit.hbox(12)
		extra_box.add_child(row)
		row.add_child(UIKit.icon(Database.icon(recipe.output_id), 36.0))
		var name := recipe.display_name if recipe.display_name != "" else UIKit.item_name(recipe.output_id)
		var missing := CraftingSystem.missing(recipe, _inventory) if _inventory != null else recipe.inputs
		var l := UIKit.label("%s · %s · %s" % [name, _inputs_text(recipe.inputs), UIKit.minutes(recipe.craft_minutes)], &"InkLabel", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var b := UIKit.button(CraftingPanel.TEXT_CRAFT, &"LedgerInkButton")
		b.disabled = action_running or _inventory == null or not CraftingSystem.can_craft(recipe, _inventory)
		b.tooltip_text = CraftingPanel.TEXT_MISSING % _inputs_text(missing) if not missing.is_empty() else ""
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(craft_extra.bind(recipe.id))
		row.add_child(b)
		extra_buttons[recipe.id] = b
		_key(b, &"extra", String(recipe.id))


# --- state (public for tests and the screenshot director) ----------------------------------

## Chooses a grave; `keep_design` false starts with the first fitting inscription.
func select_grave(id: String, keep_design: bool = true) -> void:
	grave_id = id
	confirm_discard = ""
	if not keep_design or inscription == &"":
		inscription = _first_fitting(id)
	if inscription == &"":
		gilded = false
	refresh()


func select_shape(id: StringName) -> void:
	shape = id
	refresh()


## &"" = without an inscription (gilding goes with it).
func select_inscription(id: StringName) -> void:
	inscription = id
	if id == &"":
		gilded = false
	refresh()


func select_ornament(id: StringName) -> void:
	ornament = id
	refresh()


func set_gilded(on: bool) -> void:
	gilded = on and inscription != &""
	refresh()


func toggle_filter() -> void:
	nameless_first = not nameless_first
	page = 0
	refresh()


## ±1 page of the grave list, wrapping ([ / ]); G8 Runde 5: on the grave tab.
func turn_page(step: int) -> void:
	var count := page_count()
	page = posmod(page + step, count)
	if current_tab != TAB_GRAVE and body_scroll != null:
		current_tab = TAB_GRAVE
		_show_tab()
	refresh()
	focus_default.call_deferred()


func page_count() -> int:
	return maxi(1, ceili(float(graves().size()) / GRAVES_PER_PAGE))


## The design as chosen (without text – Stonemasonry fills it in).
func design() -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = shape
	d.inscription = inscription
	d.ornament = ornament
	d.gilded = gilded and inscription != &""
	return d


## Graves in display order: [{grave_id, name, section, marker, quality, ready, named, reason}].
func graves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if masonry == null or not masonry.has_method(&"eligible_graves"):
		return out
	var index := 0
	for raw: Dictionary in masonry.call(&"eligible_graves"):
		var e := raw.duplicate()
		e["named"] = _named(String(e.grave_id))
		e["reason"] = _grave_reason(e)
		e["index"] = index
		index += 1
		out.append(e)
	if nameless_first:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a.named) != bool(b.named):
				return not bool(a.named)
			return int(a.index) < int(b.index))
	return out


func ready_stones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if masonry != null and masonry.has_method(&"ready_stones"):
		out.assign(masonry.call(&"ready_stones"))
	return out


## Carves the chosen design: a timed action of the preview's minutes (not cancellable), then
## Stonemasonry.carve with the player's inventory. Refused while the preview has a block reason.
func carve() -> void:
	if current_preview.is_empty() or block_reason() != "":
		return
	var p := _player()
	var inv := _inventory
	var d := design()
	var id := grave_id
	var minutes := int(current_preview.get("minutes", 0))
	if p != null and p.has_method(&"start_timed_action"):
		p.call(&"start_timed_action", TEXT_CARVE_LABEL, minutes, _finish_carve.bind(id, d, inv), false,
				ToolAnimConfig.clip_for(&"stone_carve", ANIM))
	else:
		_finish_carve(id, d, inv)


## Two presses: the first asks („Wirklich verwerfen?"), the second throws the stone away.
func press_discard(order_id: String) -> void:
	if confirm_discard != order_id:
		confirm_discard = order_id
		refresh()
		return
	confirm_discard = ""
	if masonry != null and masonry.has_method(&"discard"):
		masonry.call(&"discard", order_id)
	refresh()


## "" = the stone can be carved now.
func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	if grave_id == "":
		return TEXT_PICK_GRAVE
	return str(current_preview.get("block_reason", Stonemasonry.TEXT_NO_GRAVE))


## „passt – Todesursache" for a fitting template of the chosen dead ("" = does not fit).
func fits_text(ins_id: StringName) -> String:
	var ins := Database.inscription(ins_id) as InscriptionData
	var corpse := _corpse_of(grave_id)
	if ins == null or corpse == null or not StoneDesignRules.fits(ins, corpse):
		return ""
	if corpse.story_id != &"" and ins.fits_story.has(corpse.story_id):
		return TEXT_FITS % TEXT_FITS_STORY
	if ins.fits_causes.has(corpse.cause_id):
		return TEXT_FITS % TEXT_FITS_CAUSE
	return TEXT_FITS % TEXT_FITS_AGE


## The real lines of a template for the chosen dead.
func inscription_lines(ins_id: StringName) -> PackedStringArray:
	var ins := Database.inscription(ins_id) as InscriptionData
	var corpse := _corpse_of(grave_id)
	if ins == null or corpse == null:
		return PackedStringArray()
	return StoneDesignRules.render_text(ins, corpse, _stone_config())


## The stone's own lines of the preview (shape, inscription, fitting, gilded, ornament – at most
## 9 points): the entries of Stonemasonry.preview().lines that StoneDesignRules names for the design.
func stone_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var corpse := _corpse_of(grave_id)
	if current_preview.is_empty() or corpse == null:
		return out
	var own := StoneDesignRules.breakdown_lines(design(), corpse, _economy_of_masonry(), _stone_config())
	var labels := {}
	for line: Dictionary in own:
		labels[str(line.label)] = true
	for line: Dictionary in current_preview.get("lines", []):
		if labels.has(str(line.get("label", ""))):
			out.append(line)
	return out


## [saying, dates] of a template for the chosen dead – its real lines without the name (the name
## is the same in every row and stands in the section title): the saying (or „Hier ruht") and the
## date line.
func row_parts(ins: InscriptionData, lines: PackedStringArray) -> PackedStringArray:
	var saying := PackedStringArray()
	var dates := ""
	var source := lines if not lines.is_empty() else ins.lines
	var corpse := _corpse_of(grave_id)
	var name_lines := StoneDesignRules.wrap_name(StoneDesignRules.carved_name(corpse)) if corpse != null else PackedStringArray()
	for i: int in source.size():
		var line := source[i]
		if line in name_lines or line.contains("{name}"):
			continue
		var template := ins.lines[i] if not lines.is_empty() and i < ins.lines.size() and ins.lines.size() == lines.size() else line
		if template.contains("{born}") or template.contains("{died}") or line.contains("†"):
			dates = line
		else:
			saying.append(line)
	return PackedStringArray([" ".join(saying), dates])


func _max_points() -> int:
	var eco := EconomyConfig.resolve(_economy_of_masonry())
	var sc := _stone_config()
	var best := 0
	for res: Resource in Database.stone_shapes():
		var s := res as StoneShapeData
		if s != null:
			best = maxi(best, int(eco.marker_quality.get(s.id, 0)))
	var orn := 0
	for res: Resource in Database.ornaments():
		orn = maxi(orn, (res as OrnamentData).points)
	return best + sc.inscription_points + sc.fitting_points + sc.gilded_points + orn


func breakdown_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in _lines_box.get_children():
		if not node.is_queued_for_deletion() and node is Label:
			out.append((node as Label).text)
	return out


# --- refresh --------------------------------------------------------------------------------

func _refresh_graves() -> void:
	_filter_button.text = TEXT_NAMELESS_FIRST if nameless_first else TEXT_ALL_ORDER
	UIKit.clear_children(_graves_box)
	grave_buttons.clear()
	var list := graves()
	page = clampi(page, 0, page_count() - 1)
	if list.is_empty():
		_graves_box.add_child(UIKit.label(TEXT_NO_GRAVES, &"InkDimLabel", true))
	for i: int in range(page * GRAVES_PER_PAGE, mini(list.size(), (page + 1) * GRAVES_PER_PAGE)):
		var e := list[i]
		var id := String(e.grave_id)
		var reason := str(e.reason)
		var meta := TEXT_GRAVE_META % [_section_name(StringName(str(e.section))), _marker_name(StringName(str(e.marker)), bool(e.named)),
				int(e.quality)]
		var b := _card(str(e.name), reason if reason != "" else meta, id == grave_id, Vector2(0.0, grave_card_height), reason != "")
		b.tooltip_text = meta + ("\n" + reason if reason != "" else "")
		b.pressed.connect(select_grave.bind(id, true))
		_graves_box.add_child(b)
		grave_buttons[id] = b
		_key(b, TAB_GRAVE, id)
	_page_label.text = TEXT_PAGE % [page + 1, page_count()]
	_page_label.visible = page_count() > 1


func _refresh_rack(stones: Array[Dictionary]) -> void:
	UIKit.clear_children(_rack_box)
	discard_buttons.clear()
	if stones.is_empty():
		_rack_box.add_child(UIKit.label(TEXT_RACK_EMPTY, &"InkDimLabel"))
		return
	for s: Dictionary in stones:
		var row := UIKit.hbox(8)
		var names := UIKit.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var who := UIKit.label(str(s.name), &"InkLabel")
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		names.add_child(who)
		var shape_data := Database.stone_shape(StringName(str(s.shape))) as StoneShapeData
		var ok := bool(s.get("fits_still", true))
		var state := UIKit.label("%s · %s" % [shape_data.display_name if shape_data != null else str(s.shape), TEXT_READY] if ok else TEXT_STALE,
				&"InkDimLabel" if ok else &"LedgerWarnLabel")
		state.clip_text = true
		state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		names.add_child(state)
		row.add_child(names)
		if not ok:
			var id := String(s.id)
			var b := UIKit.button(TEXT_DISCARD_CONFIRM if confirm_discard == id else TEXT_DISCARD, &"LedgerInkButton")
			b.pressed.connect(press_discard.bind(id))
			row.add_child(b)
			discard_buttons[id] = b
			_key(b, &"rack", id)
		_rack_box.add_child(row)


func _refresh_design() -> void:
	UIKit.clear_children(_shape_row)
	shape_buttons.clear()
	var eco := EconomyConfig.resolve(_economy_of_masonry())
	for res: Resource in Database.stone_shapes():
		var s := res as StoneShapeData
		if s == null:
			continue
		var points := int(eco.marker_quality.get(s.id, 0))
		var meta := TEXT_SHAPE_POINTS % [points, UIKit.minutes(s.minutes)]
		var b := _card(s.display_name, meta, s.id == shape, Vector2(0.0, shape_card_height), false, "", _inputs_text(s.inputs))
		b.tooltip_text = TEXT_SHAPE_META % [points, _inputs_text(s.inputs), UIKit.minutes(s.minutes)]
		b.pressed.connect(select_shape.bind(s.id))
		_shape_row.add_child(b)
		shape_buttons[s.id] = b
		_key(b, TAB_SHAPE, String(s.id))
	UIKit.clear_children(_ins_box)
	inscription_buttons.clear()
	var corpse := _corpse_of(grave_id)
	_ins_title.text = TEXT_INSCRIPTION_FOR % StoneDesignRules.carved_name(corpse) if corpse != null else TEXT_INSCRIPTION
	var ins_edge := Vector2(0.0, inscription_card_height)
	var none := _card(TEXT_NO_INSCRIPTION, TEXT_NO_INSCRIPTION_META, inscription == &"", ins_edge)
	none.pressed.connect(select_inscription.bind(&""))
	_ins_box.add_child(none)
	inscription_buttons[&""] = none
	_key(none, TAB_INSCRIPTION, "")
	for res: Resource in Database.inscriptions():
		var ins := res as InscriptionData
		if ins == null:
			continue
		var lines := inscription_lines(ins.id)
		var parts := row_parts(ins, lines)
		var fits := fits_text(ins.id)
		var b := _card(ins.title, parts[0], ins.id == inscription, ins_edge, false, "", fits if fits != "" else parts[1],
				&"InkStampLabel" if fits != "" else &"InkDimLabel")
		b.tooltip_text = "\n".join(lines)
		if fits_text(ins.id) != "" and corpse != null:
			b.tooltip_text += "\n" + TEXT_FITS_TOOLTIP % StoneDesignRules.carved_name(corpse)
		b.pressed.connect(select_inscription.bind(ins.id))
		_ins_box.add_child(b)
		inscription_buttons[ins.id] = b
		_key(b, TAB_INSCRIPTION, String(ins.id))
	var gold := _inventory.count(_stone_config().gold_item) if is_instance_valid(_inventory) else 0
	gilded_toggle.set_pressed_no_signal(gilded and inscription != &"")
	gilded_toggle.disabled = inscription == &""
	gilded_toggle.text = TEXT_GILDED % gold if inscription != &"" else TEXT_GILDED_NEEDS
	UIKit.clear_children(_orn_row)
	ornament_buttons.clear()
	var edge := Vector2(0.0, ornament_card_height)
	var no_orn := _card(TEXT_NO_ORNAMENT, "", ornament == &"", edge)
	no_orn.pressed.connect(select_ornament.bind(&""))
	_orn_row.add_child(no_orn)
	ornament_buttons[&""] = no_orn
	_key(no_orn, TAB_ORNAMENT, "")
	for res: Resource in Database.ornaments():
		var o := res as OrnamentData
		if o == null:
			continue
		var b := _card(o.display_name, "+%d · %s" % [o.points, UIKit.minutes(o.minutes)], o.id == ornament, edge)
		b.tooltip_text = o.tooltip
		b.pressed.connect(select_ornament.bind(o.id))
		_orn_row.add_child(b)
		ornament_buttons[o.id] = b
		_key(b, TAB_ORNAMENT, String(o.id))


func _refresh_preview() -> void:
	UIKit.clear_children(_lines_box)
	UIKit.clear_children(_material_grid)
	_material_grid.add_child(UIKit.label(TEXT_MATERIAL_ROW, &"LedgerHeadLabel"))
	current_preview = {}
	if masonry != null and masonry.has_method(&"preview") and grave_id != "":
		current_preview = masonry.call(&"preview", grave_id, design())
	if current_preview.is_empty():
		quality_label.text = TEXT_PICK_GRAVE
		_text_label.text = ""
		_sum_label.text = ""
		preview.show_design(null)
		_minutes_label.text = ""
		carve_button.text = TEXT_CARVE_LABEL
		carve_button.disabled = true
		reason_label.text = ""
		shed_bar.show_state({}, true)
		return
	var shown := design()
	shown.text = current_preview.get("text", PackedStringArray())
	preview.show_design(shown)
	_text_label.text = " · ".join(shown.text) if not shown.text.is_empty() else TEXT_NO_INSCRIPTION_META
	quality_label.text = TEXT_QUALITY % [int(current_preview.quality_before), int(current_preview.quality_after)]
	var stone_sum := 0
	for line: Dictionary in stone_lines():
		stone_sum += int(line.get("points", 0))
		_lines_box.add_child(UIKit.label(TEXT_LINE % [str(line.get("label", "")), UIKit.signed(int(line.get("points", 0)))], &"InkLabel"))
	_sum_label.text = TEXT_STONE_SUM % [stone_sum, _max_points()]
	var needed: Dictionary = current_preview.get("inputs", {})
	var missing: Dictionary = current_preview.get("missing", {})
	var shed := Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, needed, _inventory)
	var in_shed: Dictionary = shed.get("available", {})
	for id: Variant in needed:
		var need := int(needed[id])
		var item_id := StringName(str(id))
		var have := _inventory.count(item_id) if is_instance_valid(_inventory) else need - int(missing.get(id, 0))
		var row := UIKit.hbox(6)
		row.add_child(UIKit.icon(Database.icon(item_id), 24.0))
		var text := "%s %d/%d" % [UIKit.item_name(item_id), have, need]
		if bool(shed.get("shown", false)):
			text += TEXT_SHED % int(in_shed.get(item_id, 0))
		var l := UIKit.label(text, &"InkLabel" if not missing.has(id) else &"LedgerWarnLabel")
		row.add_child(l)
		_material_grid.add_child(row)
	var minutes := int(current_preview.get("minutes", 0))
	_minutes_label.text = "%s · %s" % [UIKit.minutes(minutes), Phase5Texts.duration(minutes)] if minutes >= 60 else UIKit.minutes(minutes)
	carve_button.text = TEXT_CARVE % UIKit.minutes(minutes)
	var reason := block_reason()
	carve_button.disabled = reason != ""
	carve_button.tooltip_text = reason
	reason_label.text = reason if reason != TEXT_BUSY else ""
	reason_label.visible = reason_label.text != ""
	shed_bar.show_state(shed, action_running)


# --- helpers ----------------------------------------------------------------------------------

## A selectable card on the parchment: title + meta line (+ badge on the right).
func _card(title: String, meta: String, chosen: bool, size: Vector2, dimmed: bool = false, badge: String = "", extra: String = "",
		extra_variation: StringName = &"InkDimLabel") -> Button:
	var b := Button.new()
	# G8 Runde 5: the cards take the keyboard focus (amber ink frame) and share the column's width
	b.theme_type_variation = &"LedgerCardSelected" if chosen else &"LedgerCardButton"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = size
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var box := UIKit.vbox(0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_right = -10.0
	box.offset_top = 5.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UIKit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UIKit.label(title, &"InkDimLabel" if dimmed else &"InkLabel")
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	if badge != "":
		var s := UIKit.label(badge, &"InkStampLabel")
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(s)
	box.add_child(head)
	if meta != "":
		var m := UIKit.label(meta, &"LedgerWarnLabel" if dimmed else &"InkDimLabel")
		m.clip_text = true
		m.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(m)
	if extra != "":
		var x := UIKit.label(extra, extra_variation, true)
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(x)
	b.add_child(box)
	b.set_meta(&"title", title)
	b.set_meta(&"meta", meta)
	b.set_meta(&"badge", badge)
	b.set_meta(&"dimmed", dimmed)
	return b


static func _grid(columns: int, h_sep: int, v_sep: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override(&"h_separation", h_sep)
	g.add_theme_constant_override(&"v_separation", v_sep)
	return g


func _finish_carve(id: String, d: StoneDesign, inv: Inventory) -> void:
	if masonry == null or not masonry.has_method(&"carve"):
		return
	var order := str(masonry.call(&"carve", id, d, inv))
	if order != "":
		var e := _entry(id)
		EventBus.notification_requested.emit(TEXT_CARVED % str(e.get("name", "")), &"reward")
	refresh()


## Why no better stone is possible for this grave ("" = it can get one). Tested with the best
## design (master stone, the best inscription, gold, ornament) against an empty order check.
func _grave_reason(e: Dictionary) -> String:
	if bool(e.get("ready", false)):
		return TEXT_WAITING
	var best := StoneDesign.new()
	best.shape = _best_shape()
	var ins := _first_fitting(String(e.grave_id))
	best.inscription = ins if ins != &"" else &"i_rest"
	best.gilded = true
	var orns := Database.ornaments()
	best.ornament = (orns[0] as OrnamentData).id if not orns.is_empty() else &""
	var p: Dictionary = masonry.call(&"preview", String(e.grave_id), best) if masonry.has_method(&"preview") else {}
	return Stonemasonry.TEXT_BETTER if str(p.get("block_reason", "")) == Stonemasonry.TEXT_BETTER else ""


func _entry(id: String) -> Dictionary:
	if masonry == null or not masonry.has_method(&"eligible_graves"):
		return {}
	for e: Dictionary in masonry.call(&"eligible_graves"):
		if String(e.grave_id) == id:
			return e
	return {}


## First grave that can get a better stone (in display order), else the first one.
func _first_choice() -> String:
	var list := graves()
	for e: Dictionary in list:
		if str(e.reason) == "":
			return String(e.grave_id)
	return String(list[0].grave_id) if not list.is_empty() else ""


func _first_fitting(id: String) -> StringName:
	var corpse := _corpse_of(id)
	var fallback := &""
	for res: Resource in Database.inscriptions():
		var ins := res as InscriptionData
		if ins == null:
			continue
		if fallback == &"":
			fallback = ins.id
		if corpse != null and StoneDesignRules.fits(ins, corpse):
			return ins.id
	return fallback


func _first_shape() -> StringName:
	var shapes := Database.stone_shapes()
	return (shapes[0] as StoneShapeData).id if not shapes.is_empty() else &""


func _best_shape() -> StringName:
	var eco := EconomyConfig.resolve(_economy_of_masonry())
	var best := &""
	var best_points := -1
	for res: Resource in Database.stone_shapes():
		var s := res as StoneShapeData
		if s != null and int(eco.marker_quality.get(s.id, 0)) > best_points:
			best_points = int(eco.marker_quality.get(s.id, 0))
			best = s.id
	return best


## The grave carries a designed stone with an inscription (its dead has a name in stone).
func _named(id: String) -> bool:
	var grave := _grave(id)
	return grave != null and not grave.design.is_empty() and StoneDesign.from_dict(grave.design).inscription != &""


func _grave(id: String) -> GraveRecord:
	var graveyard := get_tree().get_first_node_in_group(GRAVEYARD_GROUP) if is_inside_tree() else null
	return graveyard.call(&"get_grave", id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null


func _corpse_of(id: String) -> CorpseRecord:
	var grave := _grave(id)
	if grave == null or grave.corpse_id == "" or not is_inside_tree():
		return null
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP)
	return manager.call(&"get_record", grave.corpse_id) as CorpseRecord if manager != null and manager.has_method(&"get_record") else null


func _section_name(id: StringName) -> String:
	var s := Database.section(id) as SectionData if id != &"" else null
	return s.display_name if s != null and s.display_name != "" else String(id)


func _marker_name(id: StringName, named: bool) -> String:
	if id == &"":
		return TEXT_NO_MARKER
	var s := Database.stone_shape(id) as StoneShapeData
	if s != null:
		return s.display_name + (TEXT_NAMED if named else "")
	return UIKit.item_name(id)


func _inputs_text(inputs: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: Variant in inputs:
		parts.append("%d %s" % [int(inputs[id]), UIKit.item_name(StringName(str(id)))])
	return ", ".join(parts)


func _ready_slots() -> int:
	var cfg: Variant = masonry.get(&"workshop_config") if masonry != null else null
	if not cfg is WorkshopConfig:
		cfg = Database.config(&"workshop_config")
	return (cfg as WorkshopConfig).ready_slots if cfg is WorkshopConfig else 3


func _stone_config() -> StoneConfig:
	var cfg: Variant = masonry.get(&"config") if masonry != null else null
	if cfg is StoneConfig:
		return cfg
	var real := Database.config(&"stone_config") as StoneConfig
	return real if real != null else StoneConfig.new()


func _economy_of_masonry() -> EconomyConfig:
	if masonry != null and masonry.has_method(&"_economy"):
		return masonry.call(&"_economy") as EconomyConfig
	return null


func _on_fetch_pressed() -> void:
	var bench: Variant = context.get("bench", context.get("workbench"))
	var needed: Dictionary = current_preview.get("inputs", {})
	if is_instance_valid(bench) and (bench as Object).has_method(&"request_fetch") and not needed.is_empty():
		(bench as Object).call(&"request_fetch", needed.duplicate())


func _on_store_pressed() -> void:
	var bench: Variant = context.get("bench", context.get("workbench"))
	if is_instance_valid(bench) and (bench as Object).has_method(&"request_store"):
		(bench as Object).call(&"request_store")
