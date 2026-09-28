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

const STONEMASONRY_GROUP := &"stonemasonry"
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
const TEXT_NO_INSCRIPTION := "ohne Inschrift"
const TEXT_NO_INSCRIPTION_META := "Der Stein bleibt namenlos."
const TEXT_FITS := "passt – %s"
const TEXT_FITS_STORY := "ihre Geschichte"
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
const TEXT_CARVE_LABEL := "Stein hauen"
const TEXT_CARVED := "Der Stein für %s steht in der Ablage."
const TEXT_READY_STONES := "Fertige Steine"
const TEXT_RACK_EMPTY := "Die Ablage ist leer."
const TEXT_READY := "bereit"
const TEXT_STALE := "passt nicht mehr"
const TEXT_DISCARD := "Verwerfen"
const TEXT_DISCARD_CONFIRM := "Wirklich verwerfen?"
const TEXT_HINT := "Klick wählt · [ / ] blättern · [Esc] schließen"

@export var page_height: float = 900.0
@export var left_width: float = 470.0
@export var middle_width: float = 660.0
@export var right_width: float = 540.0
@export var preview_size: Vector2i = Vector2i(500, 380)

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

var _graves_box: VBoxContainer
var _page_label: Label
var _filter_button: Button
var _rack_box: VBoxContainer
var _shape_row: HBoxContainer
var _ins_box: VBoxContainer
var _orn_row: HBoxContainer
var _lines_box: VBoxContainer
var _material_box: VBoxContainer
var _minutes_label: Label
var _inventory: Inventory


func _build() -> void:
	theme_type_variation = &"LedgerPanel"
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
	var spread := UIKit.hbox(6)
	box.add_child(spread)
	_build_left(_page(spread, left_width))
	_build_middle(_page(spread, middle_width))
	_build_right(_page(spread, right_width))
	_make_action_row(box)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _page(parent: Container, width: float) -> VBoxContainer:
	var sheet := UIKit.panel(&"LedgerPagePanel")
	sheet.custom_minimum_size = Vector2(width, page_height)
	parent.add_child(sheet)
	var inner := UIKit.vbox(8)
	sheet.add_child(inner)
	return inner


func _build_left(page_box: VBoxContainer) -> void:
	var head := UIKit.hbox(8)
	var t := UIKit.label(TEXT_GRAVES, &"InkHeaderLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_filter_button = UIKit.button("", &"JournalTabButton")
	_filter_button.focus_mode = Control.FOCUS_NONE
	_filter_button.pressed.connect(toggle_filter)
	head.add_child(_filter_button)
	page_box.add_child(head)
	_graves_box = UIKit.vbox(6)
	page_box.add_child(_graves_box)
	_page_label = UIKit.label("", &"InkDimLabel")
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_box.add_child(_page_label)
	page_box.add_child(UIKit.spacer(false))
	page_box.add_child(UIKit.label(TEXT_READY_STONES, &"LedgerHeadLabel"))
	_rack_box = UIKit.vbox(6)
	page_box.add_child(_rack_box)


func _build_middle(page_box: VBoxContainer) -> void:
	page_box.add_child(UIKit.label(TEXT_DESIGN, &"InkHeaderLabel"))
	page_box.add_child(UIKit.label(TEXT_SHAPE, &"LedgerHeadLabel"))
	_shape_row = UIKit.hbox(8)
	page_box.add_child(_shape_row)
	var ins_head := UIKit.hbox(8)
	var ins_t := UIKit.label(TEXT_INSCRIPTION, &"LedgerHeadLabel")
	ins_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ins_head.add_child(ins_t)
	gilded_toggle = CheckBox.new()
	gilded_toggle.theme_type_variation = &"InkButton"
	gilded_toggle.focus_mode = Control.FOCUS_NONE
	gilded_toggle.toggled.connect(set_gilded)
	ins_head.add_child(gilded_toggle)
	page_box.add_child(ins_head)
	_ins_box = UIKit.vbox(4)
	page_box.add_child(_ins_box)
	page_box.add_child(UIKit.label(TEXT_ORNAMENT, &"LedgerHeadLabel"))
	_orn_row = UIKit.hbox(6)
	page_box.add_child(_orn_row)


func _build_right(page_box: VBoxContainer) -> void:
	page_box.add_child(UIKit.label(TEXT_PREVIEW, &"InkHeaderLabel"))
	var frame := CenterContainer.new()
	preview = StonePreview.new()
	preview.name = "StonePreview"
	preview.view_size = preview_size
	frame.add_child(preview)
	page_box.add_child(frame)
	quality_label = UIKit.label("", &"InkHeaderLabel")
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_box.add_child(quality_label)
	_lines_box = UIKit.vbox(0)
	page_box.add_child(_lines_box)
	page_box.add_child(UIKit.label(TEXT_MATERIAL, &"LedgerHeadLabel"))
	_material_box = UIKit.vbox(2)
	page_box.add_child(_material_box)
	page_box.add_child(UIKit.spacer(false))
	_minutes_label = UIKit.label("", &"InkDimLabel")
	page_box.add_child(_minutes_label)
	reason_label = UIKit.label("", &"LedgerWarnLabel", true)
	reason_label.custom_minimum_size.x = right_width - 60.0
	page_box.add_child(reason_label)
	carve_button = UIKit.button("", &"InkButton")
	carve_button.pressed.connect(carve)
	page_box.add_child(carve_button)


func _on_opened() -> void:
	var m: Variant = context.get("stonemasonry")
	masonry = m if is_instance_valid(m) else (get_tree().get_first_node_in_group(STONEMASONRY_GROUP) if is_inside_tree() else null)
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)
	confirm_discard = ""
	page = 0
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


func _refresh() -> void:
	var slots := _ready_slots()
	var stones := ready_stones()
	rack_label.text = TEXT_RACK % [stones.size(), slots]
	_refresh_graves()
	_refresh_rack(stones)
	_refresh_design()
	_refresh_preview()


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


## ±1 page of the grave list, wrapping ([ / ]).
func turn_page(step: int) -> void:
	var pages := page_count()
	page = posmod(page + step, pages)
	refresh()


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
		p.call(&"start_timed_action", TEXT_CARVE_LABEL, minutes, _finish_carve.bind(id, d, inv), false, ANIM)
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
		var b := _card(str(e.name), reason if reason != "" else meta, id == grave_id, Vector2(left_width - 40.0, 62.0), reason != "")
		b.tooltip_text = meta + ("\n" + reason if reason != "" else "")
		b.pressed.connect(select_grave.bind(id, true))
		_graves_box.add_child(b)
		grave_buttons[id] = b
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
		names.add_child(UIKit.label(str(s.name), &"InkLabel"))
		var shape_data := Database.stone_shape(StringName(str(s.shape))) as StoneShapeData
		var ok := bool(s.get("fits_still", true))
		var state := UIKit.label("%s · %s" % [shape_data.display_name if shape_data != null else str(s.shape), TEXT_READY if ok else TEXT_STALE],
				&"InkDimLabel" if ok else &"LedgerWarnLabel")
		names.add_child(state)
		row.add_child(names)
		if not ok:
			var id := String(s.id)
			var b := UIKit.button(TEXT_DISCARD_CONFIRM if confirm_discard == id else TEXT_DISCARD, &"InkButton")
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(press_discard.bind(id))
			row.add_child(b)
			discard_buttons[id] = b
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
		var meta := TEXT_SHAPE_META % [points, _inputs_text(s.inputs), UIKit.minutes(s.minutes)]
		var b := _card(s.display_name, meta, s.id == shape, Vector2((middle_width - 60.0) / 3.0, 74.0))
		b.pressed.connect(select_shape.bind(s.id))
		_shape_row.add_child(b)
		shape_buttons[s.id] = b
	UIKit.clear_children(_ins_box)
	inscription_buttons.clear()
	var none := _card(TEXT_NO_INSCRIPTION, TEXT_NO_INSCRIPTION_META, inscription == &"", Vector2(middle_width - 40.0, 50.0))
	none.pressed.connect(select_inscription.bind(&""))
	_ins_box.add_child(none)
	inscription_buttons[&""] = none
	var corpse := _corpse_of(grave_id)
	for res: Resource in Database.inscriptions():
		var ins := res as InscriptionData
		if ins == null:
			continue
		var lines := inscription_lines(ins.id)
		var body := " · ".join(lines) if not lines.is_empty() else " · ".join(ins.lines)
		var fits := fits_text(ins.id)
		var b := _card(ins.title, body, ins.id == inscription, Vector2(middle_width - 40.0, 50.0), false, fits)
		if fits != "" and corpse != null:
			b.tooltip_text = TEXT_FITS_TOOLTIP % StoneDesignRules.carved_name(corpse)
		b.pressed.connect(select_inscription.bind(ins.id))
		_ins_box.add_child(b)
		inscription_buttons[ins.id] = b
	var gold := _inventory.count(_stone_config().gold_item) if is_instance_valid(_inventory) else 0
	gilded_toggle.set_pressed_no_signal(gilded and inscription != &"")
	gilded_toggle.disabled = inscription == &""
	gilded_toggle.text = TEXT_GILDED % gold if inscription != &"" else TEXT_GILDED_NEEDS
	UIKit.clear_children(_orn_row)
	ornament_buttons.clear()
	var edge := Vector2((middle_width - 70.0) / 5.0, 64.0)
	var no_orn := _card(TEXT_NO_ORNAMENT, "", ornament == &"", edge)
	no_orn.pressed.connect(select_ornament.bind(&""))
	_orn_row.add_child(no_orn)
	ornament_buttons[&""] = no_orn
	for res: Resource in Database.ornaments():
		var o := res as OrnamentData
		if o == null:
			continue
		var b := _card(o.display_name, "+%d · %s" % [o.points, UIKit.minutes(o.minutes)], o.id == ornament, edge)
		b.tooltip_text = o.tooltip
		b.pressed.connect(select_ornament.bind(o.id))
		_orn_row.add_child(b)
		ornament_buttons[o.id] = b


func _refresh_preview() -> void:
	UIKit.clear_children(_lines_box)
	UIKit.clear_children(_material_box)
	current_preview = {}
	if masonry != null and masonry.has_method(&"preview") and grave_id != "":
		current_preview = masonry.call(&"preview", grave_id, design())
	if current_preview.is_empty():
		quality_label.text = TEXT_PICK_GRAVE
		preview.show_design(null)
		_minutes_label.text = ""
		carve_button.text = TEXT_CARVE_LABEL
		carve_button.disabled = true
		reason_label.text = ""
		return
	var shown := design()
	shown.text = current_preview.get("text", PackedStringArray())
	preview.show_design(shown)
	quality_label.text = TEXT_QUALITY % [int(current_preview.quality_before), int(current_preview.quality_after)]
	for line: Dictionary in current_preview.get("lines", []):
		_lines_box.add_child(UIKit.label(TEXT_LINE % [str(line.get("label", "")), UIKit.signed(int(line.get("points", 0)))], &"InkLabel"))
	var needed: Dictionary = current_preview.get("inputs", {})
	var missing: Dictionary = current_preview.get("missing", {})
	for id: Variant in needed:
		var need := int(needed[id])
		var item_id := StringName(str(id))
		var have := _inventory.count(item_id) if is_instance_valid(_inventory) else need - int(missing.get(id, 0))
		var row := UIKit.hbox(8)
		row.add_child(UIKit.icon(Database.icon(item_id), 26.0))
		var l := UIKit.label("%d× %s" % [need, UIKit.item_name(item_id)], &"InkLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%d / %d" % [have, need], &"InkLabel" if not missing.has(id) else &"LedgerWarnLabel"))
		_material_box.add_child(row)
	var minutes := int(current_preview.get("minutes", 0))
	_minutes_label.text = "%s · %s" % [UIKit.minutes(minutes), Phase5Texts.duration(minutes)] if minutes >= 60 else UIKit.minutes(minutes)
	carve_button.text = TEXT_CARVE % UIKit.minutes(minutes)
	var reason := block_reason()
	carve_button.disabled = reason != ""
	carve_button.tooltip_text = reason
	reason_label.text = reason if reason != TEXT_BUSY else ""
	reason_label.visible = reason_label.text != ""


# --- helpers ----------------------------------------------------------------------------------

## A selectable card on the parchment: title + meta line (+ badge on the right).
func _card(title: String, meta: String, chosen: bool, size: Vector2, dimmed: bool = false, badge: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = &"JournalCardSelected" if chosen else &"JournalCardButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
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
	b.add_child(box)
	b.set_meta(&"title", title)
	b.set_meta(&"meta", meta)
	b.set_meta(&"badge", badge)
	b.set_meta(&"dimmed", dimmed)
	return b


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
