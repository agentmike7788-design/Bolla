class_name JournalPagesPhase9
extends RefCounted
## The Merkbuch's Phase-9 tabs (docs/PHASE9_DESIGN.md §7.1, §7.2, W-UI), built for JournalPanel:
## - „Vorhaben" (QuestLog.entries): left the groups (Hauptkette, Nebenketten, Große Bitten, Bitten, Aufträge,
##   Freundschaft, Was du schuldest) with their entries as focusable buttons (↑/↓, Enter, Tab to the right page), the
##   pinned one marked; right the chosen entry: title, giver, deadline, summary, the done steps as sentences in ink, the
##   current one in pencil with its hint, future ones as „…", choices as sentences, the ending with its closing line; a
##   large request's parts with ✓ / ○ and the stamp „halb"; „Verfolgen" / „Nicht mehr verfolgen" (Quests.pin – the only
##   change this tab makes).
## - „Die Liste" (JournalManager.list_page): the back of the ledger in two inks, six rows date · initial · name ·
##   witness (✓), the footer and the struck-out line; „Niemandem sagen" after H4 (Quests.choose q_who_knows h5
##   confide_none).
## - „Briefe" (JournalManager.letter_pages): left the letters in the bag with „Entscheiden …" (the letter card &"letter"),
##   right the copies of read letters and where every letter went.

const PANEL_LETTER := &"letter"
const MAIN_QUEST := &"q_who_knows"
const CONFIDE_STEP := &"h5"
const CONFIDE_NONE := &"confide_none"
const UI_GROUP := &"ui_root"


# --- „Vorhaben" ----------------------------------------------------------------------------------------------------

## Entries of QuestLog grouped: [{group, label, entries}] in the order of QuestLog.GROUPS (empty groups left out).
static func plan_groups(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_group := {}
	for e: Dictionary in QuestLog.entries(tree):
		(by_group.get_or_add(StringName(str(e.get("group", ""))), []) as Array).append(e)
	for g: StringName in QuestLog.GROUPS:
		var list: Array = by_group.get(g, [])
		if list.is_empty():
			continue
		out.append({"group": g, "label": Phase9Texts.GROUP_LABELS.get(g, String(g)), "entries": list})
	return out


## Builds the tab; returns {buttons: {id → Button}, pin: Button | null, shown: id}. `selected` = the chosen entry id.
static func build_plans(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, width: float, selected: StringName,
		on_select: Callable, on_pin: Callable) -> Dictionary:
	var result := {"buttons": {}, "pin": null, "shown": &""}
	var groups := plan_groups(tree)
	if groups.is_empty():
		left.add_child(_wrap(Phase9Texts.PLANS_EMPTY, &"InkDimLabel", width))
		right.add_child(UIKit.spacer(false))
		right.add_child(_wrap(Phase9Texts.QUOTE_PLANS, &"InkDimLabel", width))
		return result
	var chosen: Dictionary = {}
	for g: Dictionary in groups:
		for e: Dictionary in g.entries:
			if StringName(str(e.id)) == selected:
				chosen = e
	if chosen.is_empty():
		chosen = (groups[0].entries as Array)[0]
	result.shown = StringName(str(chosen.id))
	var scroll := _scroll(left)
	var list := UIKit.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var buttons: Dictionary = result.buttons
	for g: Dictionary in groups:
		list.add_child(UIKit.label(str(g.label), &"LedgerHeadLabel"))
		for e: Dictionary in g.entries:
			var id := StringName(str(e.id))
			var row := UIKit.hbox(8)
			var text := str(e.title)
			if bool(e.get("pinned", false)):
				text = Phase9Texts.PLANS_PINNED_MARK + " " + text
			var b := UIKit.button(text, &"JournalTabSelected" if id == result.shown else &"JournalTabButton")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.x = width - 260.0
			b.set_meta(&"entry_id", id)
			b.tooltip_text = str(e.get("line", ""))
			b.pressed.connect(on_select.bind(id))
			row.add_child(b)
			var stamp := UIKit.label(Phase9Texts.days_left(int(e.get("days_left", -1))), &"InkStampLabel")
			stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(stamp)
			list.add_child(row)
			buttons[id] = b
	result.pin = _plan_detail(right, tree, chosen, width, on_pin)
	return result


## The chosen entry on the right page; returns its „Verfolgen" button (null without Quests).
static func _plan_detail(right: VBoxContainer, tree: SceneTree, e: Dictionary, width: float, on_pin: Callable) -> Button:
	var group := StringName(str(e.get("group", "")))
	right.add_child(_wrap(str(e.title), &"LedgerTitleLabel", width))
	var meta := PackedStringArray()
	var giver := Phase9Texts.giver_name(group, StringName(str(e.get("giver", ""))))
	if giver != "":
		meta.append(Phase9Texts.PLANS_FROM % giver)
	var left := Phase9Texts.days_left(int(e.get("days_left", -1)))
	if left != "":
		meta.append(left)
	if bool(e.get("errand", false)):
		meta.append(Phase9Texts.PLANS_ERRAND)
	if bool(e.get("pinned", false)):
		meta.append(Phase9Texts.PLANS_PINNED)
	if not meta.is_empty():
		right.add_child(UIKit.label(Phase9Texts.SEP.join(meta), &"InkDimLabel", true))
	right.add_child(LedgerOrnament.new())
	var scroll := _scroll(right)
	var body := UIKit.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var summary := str(e.get("summary", ""))
	if group == &"large":
		summary = _large_text(tree, StringName(str(e.id)))
	if summary != "":
		body.add_child(_wrap(summary, &"InkLabel", width))
	if group == &"main" or group == &"side":
		_chain_steps(body, e, width)
	elif group == &"large":
		_large_parts(body, tree, e, width)
	else:
		var line := str(e.get("line", ""))
		if line != "" and line != str(e.title):
			body.add_child(_wrap(line, &"InkPencilLabel", width))
	var quests := tree.get_first_node_in_group(&"quests") as Quests if tree != null else null
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	var pin := UIKit.button(Phase9Texts.PLANS_UNPIN if bool(e.get("pinned", false)) else Phase9Texts.PLANS_PIN, &"InkButton")
	pin.disabled = quests == null
	pin.set_meta(&"entry_id", StringName(str(e.id)))
	pin.pressed.connect(on_pin.bind(StringName(str(e.id))))
	row.add_child(pin)
	right.add_child(row)
	return pin


static func _chain_steps(body: VBoxContainer, e: Dictionary, width: float) -> void:
	var steps: Array = e.get("steps", [])
	var future := false
	var any_done := false
	for raw: Variant in steps:
		var s := raw as Dictionary
		if s == null:
			continue
		match StringName(str(s.get("state", ""))):
			QuestLog.STEP_DONE:
				if not any_done:
					body.add_child(UIKit.label(Phase9Texts.PLANS_STEPS, &"LedgerHeadLabel"))
					any_done = true
				var line := _wrap(Phase9Texts.done_sentence(s), &"InkLabel", width)
				line.set_meta(&"step_id", StringName(str(s.get("id", ""))))
				body.add_child(line)
			QuestLog.STEP_CURRENT:
				body.add_child(UIKit.label(Phase9Texts.PLANS_NOW, &"LedgerHeadLabel"))
				var cur := _wrap(str(s.get("title", "")), &"InkPencilLabel", width)
				cur.set_meta(&"step_id", StringName(str(s.get("id", ""))))
				body.add_child(cur)
				var hint := str(s.get("hint", ""))
				if hint != "":
					body.add_child(_wrap(hint, &"InkPencilLabel", width))
				var progress: Vector2i = e.get("progress", Vector2i.ZERO) if e.get("progress") is Vector2i else Vector2i.ZERO
				var left := Phase9Texts.days_left(int(e.get("days_left", -1)))
				var extra := PackedStringArray()
				if progress.y > 1:
					extra.append("%d/%d" % [progress.x, progress.y])
				if left != "":
					extra.append(left)
				if not extra.is_empty():
					body.add_child(UIKit.label(Phase9Texts.SEP.join(extra), &"InkStampLabel"))
			_:
				future = true
	if future:
		body.add_child(UIKit.label(Phase9Texts.PLANS_FUTURE, &"InkDimLabel"))
	var ending := str(e.get("ending_title", ""))
	if ending != "":
		body.add_child(LedgerOrnament.new())
		var head := UIKit.hbox(8)
		var t := UIKit.label(Phase9Texts.PLANS_ENDED % ending, &"InkHeaderLabel", true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if StringName(str(e.get("state", ""))) == Quests.STATE_SETTLED:
			head.add_child(UIKit.label(Phase9Texts.PLANS_SETTLED, &"InkStampLabel"))
		body.add_child(head)
		var closing := str(e.get("closing_line", ""))
		if closing != "":
			body.add_child(_wrap(closing, &"InkDimLabel", width))


static func _large_parts(body: VBoxContainer, tree: SceneTree, e: Dictionary, width: float) -> void:
	var head := UIKit.hbox(8)
	var t := UIKit.label(Phase9Texts.PLANS_PARTS, &"LedgerHeadLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var hill := tree.get_first_node_in_group(&"hill_requests") as HillRequests if tree != null else null
	if hill != null and hill.half_done(StringName(str(e.id))):
		var stamp := UIKit.label(Phase9Texts.HALF_STAMP, &"InkStampLabel")
		stamp.set_meta(&"half", true)
		head.add_child(stamp)
	body.add_child(head)
	for raw: Variant in e.get("steps", []):
		var s := raw as Dictionary
		if s == null:
			continue
		var done := StringName(str(s.get("state", ""))) == QuestLog.STEP_DONE
		body.add_child(_wrap("%s  %s" % [Phase9Texts.PART_DONE if done else Phase9Texts.PART_OPEN, str(s.get("title", ""))],
				&"InkLabel" if done else &"InkPencilLabel", width))


static func _large_text(tree: SceneTree, id: StringName) -> String:
	var hill := tree.get_first_node_in_group(&"hill_requests") as HillRequests if tree != null else null
	if hill == null:
		return ""
	var card := hill.large_card(id)
	return str(card.get("text", ""))


## Pins / unpins `id` (Quests.pin; the same id again = „Nicht mehr verfolgen") and refreshes the HUD line.
static func toggle_pin(tree: SceneTree, id: StringName) -> bool:
	var quests := tree.get_first_node_in_group(&"quests") as Quests if tree != null else null
	if quests == null:
		return false
	quests.pin(&"" if quests.pinned() == id else id)
	var ui := tree.get_first_node_in_group(UI_GROUP)
	var hud: Variant = ui.get(&"hud") if ui != null else null
	if hud is GameHud:
		(hud as GameHud).refresh_objective()
	return true


# --- „Die Liste" -----------------------------------------------------------------------------------------------------

## Builds the tab from `page` (JournalManager.list_page); returns {rows: [[date, initial, name, witness labels]], confide:
## Button | null}.
static func build_list(left: VBoxContainer, right: VBoxContainer, page: Dictionary, width: float, on_confide: Callable) -> Dictionary:
	var result := {"rows": [], "confide": null}
	if not bool(page.get("known", false)):
		left.add_child(_wrap(Phase9Texts.LIST_UNKNOWN, &"InkDimLabel", width))
		return result
	left.add_child(UIKit.label(Phase9Texts.LIST_TITLE, &"LedgerHeadLabel"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 10)
	for head: String in [Phase9Texts.LIST_HEAD_DATE, Phase9Texts.LIST_HEAD_INITIAL, Phase9Texts.LIST_HEAD_NAME, Phase9Texts.LIST_HEAD_WITNESS]:
		grid.add_child(UIKit.label(head, &"InkDimLabel"))
	var matched := 0
	var asked := 0
	var dead := 0
	var witnesses := 0
	for raw: Variant in page.get("entries", []):
		var e := raw as Dictionary
		if e == null:
			continue
		var ink: StringName = &"InkFreshLabel" if StringName(str(e.get("ink", ""))) == LightEntryData.INK_FRESH else &"InkOldLabel"
		var date := UIKit.label(str(e.get("date", "")), ink)
		var initial := UIKit.label(str(e.get("initial", "")), ink)
		var name := UIKit.label(str(e.get("name", "")), &"InkLabel", true)
		name.custom_minimum_size.x = width * 0.36
		var witness := UIKit.label(Phase9Texts.LIST_WITNESS_YES if bool(e.get("witnessed", false)) else Phase9Texts.LIST_WITNESS_NO,
				&"InkStampLabel" if bool(e.get("witnessed", false)) else &"InkDimLabel")
		witness.tooltip_text = str(e.get("witness", ""))
		witness.mouse_filter = Control.MOUSE_FILTER_PASS
		for l: Label in [date, initial, name, witness]:
			grid.add_child(l)
		(result.rows as Array).append([date, initial, name, witness])
		if not bool(e.get("open", false)):
			dead += 1
			witnesses += 1
			if bool(e.get("matched", false)):
				matched += 1
			if bool(e.get("witnessed", false)):
				asked += 1
	left.add_child(grid)
	left.add_child(LedgerOrnament.new())
	var footer := str(page.get("footer", ""))
	if footer != "":
		left.add_child(UIKit.label(footer, &"InkFreshLabel"))
	var struck := str(page.get("struck", ""))
	if struck != "":
		left.add_child(StruckLabel.make(struck, &"InkFreshLabel"))
	right.add_child(UIKit.label(Phase9Texts.PAGE_LIST, &"InkHeaderLabel"))
	right.add_child(_wrap(Phase9Texts.LIST_COUNT % [matched, dead, asked, witnesses], &"InkLabel", width))
	right.add_child(_wrap(Phase9Texts.LIST_INK_NOTE, &"InkDimLabel", width))
	right.add_child(LedgerOrnament.new())
	right.add_child(UIKit.label(Phase9Texts.LIST_WITNESSES, &"LedgerHeadLabel"))
	for raw: Variant in page.get("entries", []):
		var e := raw as Dictionary
		if e == null or str(e.get("witness", "")) == "":
			continue
		var asked_one := bool(e.get("witnessed", false))
		right.add_child(UIKit.label(Phase9Texts.LIST_WITNESS_LINE % [str(e.get("initial", "")), str(e.get("witness", "")),
				Phase9Texts.LIST_ASKED if asked_one else Phase9Texts.LIST_NOT_ASKED], &"InkLabel" if asked_one else &"InkPencilLabel"))
	if bool(page.get("confide_none", false)):
		right.add_child(_wrap(Phase9Texts.LIST_CONFIDE_HINT, &"InkPencilLabel", width))
		var row := UIKit.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_END
		var b := UIKit.button(Phase9Texts.LIST_CONFIDE_NONE, &"InkButton")
		b.pressed.connect(on_confide)
		row.add_child(b)
		right.add_child(row)
		result.confide = b
	right.add_child(UIKit.spacer(false))
	var quote := _wrap(Phase9Texts.LIST_QUOTE, &"InkDimLabel", width)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(quote)
	return result


## „Niemandem sagen" (H5): Quests.choose(q_who_knows, h5, confide_none).
static func confide_none(tree: SceneTree) -> bool:
	var quests := tree.get_first_node_in_group(&"quests") as Quests if tree != null else null
	return quests != null and quests.choose(MAIN_QUEST, CONFIDE_STEP, CONFIDE_NONE)


# --- „Briefe" ---------------------------------------------------------------------------------------------------------

## Builds the tab; returns {decide: {uid → Button}, copies: [uid]}.
static func build_letters(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, journal: Node, inv: Inventory,
		width: float, on_decide: Callable) -> Dictionary:
	var result := {"decide": {}, "copies": []}
	var pages: Array[Dictionary] = []
	if journal != null and journal.has_method(&"letter_pages"):
		for p: Variant in journal.call(&"letter_pages"):
			if p is Dictionary:
				pages.append(p)
	var letters := Phase9Status.letters(tree)
	left.add_child(UIKit.label(Phase9Texts.LETTERS_OPEN, &"LedgerHeadLabel"))
	var open := Phase9Status.open_letters(tree, inv)
	if open.is_empty():
		left.add_child(_wrap(Phase9Texts.LETTERS_NO_OPEN if not pages.is_empty() else Phase9Texts.LETTERS_EMPTY, &"InkDimLabel", width))
	for uid: String in open:
		var data := letters.letter(uid) if letters != null else null
		if data == null:
			continue
		var card := UIKit.panel(&"LedgerRowPanel")
		var col := UIKit.vbox(2)
		card.add_child(col)
		col.add_child(_wrap(data.outside if data.outside != "" else String(data.id), &"InkLabel", width - 40.0))
		var meta := PackedStringArray([Phase9Texts.LETTERS_KIND.get(letters.kind_of(uid), String(letters.kind_of(uid)))])
		if data.sender != "" and (letters.is_opened(uid) or not data.sealed):
			meta.append(Phase9Texts.LETTERS_FROM % data.sender)
		var row := UIKit.hbox(8)
		var m := UIKit.label(Phase9Texts.SEP.join(meta), &"InkDimLabel")
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(m)
		var b := UIKit.button(Phase9Texts.LETTERS_DECIDE, &"InkButton")
		b.set_meta(&"uid", uid)
		b.pressed.connect(on_decide.bind(uid))
		row.add_child(b)
		col.add_child(row)
		left.add_child(card)
		(result.decide as Dictionary)[uid] = b
	right.add_child(UIKit.label(Phase9Texts.LETTERS_COPIES, &"LedgerHeadLabel"))
	var scroll := _scroll(right)
	var body := UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var any := false
	for p: Dictionary in pages:
		var uid := str(p.get("uid", ""))
		if uid in open:
			continue
		any = true
		body.add_child(_wrap(str(p.get("outside", "")), &"InkHeaderLabel", width))
		var meta := PackedStringArray([Phase9Texts.LETTERS_DAY % int(p.get("day", 0))])
		if str(p.get("sender", "")) != "" and str(p.get("text", "")) != "":
			meta.append(Phase9Texts.LETTERS_FROM % str(p.sender))
		body.add_child(UIKit.label(Phase9Texts.SEP.join(meta), &"InkDimLabel"))
		var text := str(p.get("text", ""))
		if text != "":
			body.add_child(_wrap("„%s“" % text, &"InkLabel", width))
		var line := str(p.get("line", ""))
		if line != "":
			body.add_child(_wrap(line, &"InkPencilLabel", width))
		body.add_child(LedgerOrnament.new())
		(result.copies as Array).append(uid)
	if not any:
		body.add_child(_wrap(Phase9Texts.LETTERS_EMPTY if pages.is_empty() else Phase9Texts.LETTERS_NO_OPEN, &"InkDimLabel", width))
	return result


## Opens the letter card for `uid` (over the Merkbuch).
static func open_letter(uid: String, inv: Inventory, player: Node) -> void:
	var ctx := {"uid": uid}
	if inv != null:
		ctx["inventory"] = inv
	if player != null:
		ctx["player"] = player
	EventBus.ui_panel_requested.emit(PANEL_LETTER, ctx)


# --- helpers ----------------------------------------------------------------------------------------------------------

static func _wrap(text: String, variation: StringName, width: float) -> Label:
	var l := UIKit.label(text, variation, true)
	l.custom_minimum_size.x = maxf(width - 90.0, 120.0)
	return l


static func _scroll(parent: VBoxContainer) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.follow_focus = true
	s.get_v_scroll_bar().theme_type_variation = &"LedgerScrollBar"
	parent.add_child(s)
	return s


## A label with a line through it (the struck-out sentence at the foot of the list).
class StruckLabel extends Label:
	static func make(text_value: String, variation: StringName) -> StruckLabel:
		var l := StruckLabel.new()
		l.text = text_value
		l.theme_type_variation = variation
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return l

	func _draw() -> void:
		var font := get_theme_font(&"font")
		var font_size := get_theme_font_size(&"font_size")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else size.x
		var y := size.y * 0.55
		draw_line(Vector2(-4.0, y), Vector2(minf(w, size.x) + 4.0, y), get_theme_color(&"font_color"), 2.0, true)
