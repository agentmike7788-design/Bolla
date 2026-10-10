class_name JournalPagesPhase7
extends RefCounted
## The two Phase-7 double pages of the Merkbuch (docs/PHASE7_DESIGN.md §7) and the death note additions,
## built for JournalPanel (static, read-only):
## - „Aufträge": left the running orders (checklist, deadline), right the completed (with the date of the
##   Phase-5 calendar when known) and the missed ones (grey).
## - „Hollerbrück": eight cards – portrait icon (villager_<id> from the icon renderer), name, role, the
##   relationship as a word and five dots, „Zuletzt gesprochen: heute", the shop hours, „mag: ?" until a
##   gift was accepted – and the reputation of the gravekeeper in the village. Piety stays hidden.
## - death note: the specimens of the dead with where they are now, the finding („laut Quast" for an
##   expertise), the deduced cause and the button „Ursache deuten" (Deductions.can_deduce).

const ORDERS_GROUP := &"orders"
const RELATIONSHIPS_GROUP := &"relationships"
const SPECIMENS_GROUP := &"specimens"
const DEDUCTIONS_GROUP := &"deductions"
const MANAGER_GROUP := &"corpse_manager"
const DEDUCTION_PANEL := &"deduction"
const PORTRAIT := 64.0


# --- orders -----------------------------------------------------------------------------------------

## {active: [card], done: [card], failed: [card]} – cards of Phase7Texts.order_card.
static func orders_page(tree: SceneTree, inv: Inventory) -> Dictionary:
	var out := {"active": [], "done": [], "failed": []}
	var orders := tree.get_first_node_in_group(ORDERS_GROUP) as Orders if tree != null else null
	if orders == null:
		return out
	for o: OrderData in orders.all_orders():
		var state := orders.state(o.id)
		match state:
			Orders.STATE_ACCEPTED:
				var left := Phase7Texts.days_left(orders.deadline_day(o.id), TimeManager.day)
				var card := Phase7Texts.order_card(o, state, inv, left)
				card["group"] = JournalPagesPhase8.order_group(o)
				(out.active as Array).append(card)
			Orders.STATE_COMPLETED:
				var c := Phase7Texts.order_card(o, state, inv, -1)
				var n := orders.completions(o.id)
				c["done_text"] = Phase7Texts.PAGE_ORDER_TIMES % n if n > 1 else Phase7Texts.PAGE_ORDER_DONE
				(out.done as Array).append(c)
			Orders.STATE_FAILED:
				(out.failed as Array).append(Phase7Texts.order_card(o, state, inv, -1))
			_:
				if orders.completions(o.id) > 0:
					var c2 := Phase7Texts.order_card(o, Orders.STATE_COMPLETED, inv, -1)
					c2["done_text"] = Phase7Texts.PAGE_ORDER_TIMES % orders.completions(o.id)
					(out.done as Array).append(c2)
	out["goal"] = Phase7Texts.PAGE_ORDER_GOAL % [orders.done_count(), orders.done_givers().size()]
	return out


static func build_orders(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, inv: Inventory, width: float) -> void:
	var page := orders_page(tree, inv)
	left.add_child(UIKit.label(Phase7Texts.PAGE_ORDERS_ACTIVE, &"InkHeaderLabel"))
	var active: Array = page.active
	if active.is_empty():
		left.add_child(UIKit.label(Phase7Texts.PAGE_ORDERS_NONE, &"InkDimLabel", true))
	# Phase 8 (§7.3, §7.4): the village's orders, then „Freundschaft", then „Was du schuldest".
	var grouped := active.any(func(c: Dictionary) -> bool: return StringName(str(c.get("group", "village"))) != &"village")
	var heads := {&"village": Phase8Texts.PAGE_ORDERS_VILLAGE, &"friend": Phase8Texts.PAGE_ORDERS_FRIEND,
			&"owed": Phase8Texts.PAGE_ORDERS_OWED}
	for group: StringName in [&"village", &"friend", &"owed"]:
		var cards := active.filter(func(c: Dictionary) -> bool: return StringName(str(c.get("group", "village"))) == group)
		if cards.is_empty():
			continue
		if grouped:
			left.add_child(UIKit.label(heads[group], &"LedgerHeadLabel"))
		for c: Dictionary in cards:
			left.add_child(_order_entry(c, width, false))
	right.add_child(UIKit.label(Phase7Texts.PAGE_ORDERS_DONE, &"InkHeaderLabel"))
	right.add_child(UIKit.label(str(page.get("goal", "")), &"InkDimLabel"))
	var done: Array = page.done
	if done.is_empty():
		right.add_child(UIKit.label(Phase7Texts.PAGE_ORDERS_NONE_DONE, &"InkDimLabel"))
	for c: Dictionary in done:
		var row := UIKit.hbox(8)
		var t := UIKit.label("%s – %s" % [str(c.title), Phase7Texts.short_name(StringName(str(c.giver)))], &"InkLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIKit.label(str(c.get("done_text", Phase7Texts.PAGE_ORDER_DONE)), &"InkStampLabel"))
		right.add_child(row)
	var failed: Array = page.failed
	if not failed.is_empty():
		right.add_child(LedgerOrnament.new())
		right.add_child(UIKit.label(Phase7Texts.PAGE_ORDERS_FAILED, &"InkDimLabel"))
		for c: Dictionary in failed:
			right.add_child(UIKit.label("%s – %s" % [str(c.title), Phase7Texts.short_name(StringName(str(c.giver)))], &"InkDimLabel"))


static func _order_entry(c: Dictionary, width: float, dim: bool) -> Control:
	var row := UIKit.panel(&"LedgerRowPanel")
	row.set_meta(&"order_id", c.get("id", &""))
	var col := UIKit.vbox(2)
	var head := UIKit.hbox(8)
	var t := UIKit.label(str(c.title), &"InkDimLabel" if dim else &"InkHeaderLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.label(str(c.deadline), &"InkStampLabel"))
	col.add_child(head)
	col.add_child(UIKit.label(Phase7Texts.ORDER_FROM % str(c.giver_name), &"InkDimLabel"))
	var checks := PackedStringArray()
	for raw: Variant in c.get("checks", []):
		var ch := raw as Dictionary
		checks.append("%s %s" % [str(ch.label), Phase7Texts.CHECK_ON if bool(ch.ok) else Phase7Texts.CHECK_OFF])
	if not checks.is_empty():
		var l := UIKit.label(Phase7Texts.SEP.join(checks), &"InkLabel", true)
		l.custom_minimum_size.x = width - 120.0
		col.add_child(l)
	row.add_child(col)
	return row


# --- Hollerbrück --------------------------------------------------------------------------------------

## One card per villager: {npc_id, name, role, met, value, tier, rel, talked, shop, likes, gone}.
static func village_cards(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rel := tree.get_first_node_in_group(RELATIONSHIPS_GROUP) as Relationships if tree != null else null
	for id: StringName in Phase7Texts.VILLAGER_ORDER:
		var data := Database.villager(id) as VillagerData
		if data == null:
			continue
		var met := rel != null and rel.met(id)
		var value := rel.value(id) if rel != null else 0
		var tier := rel.tier(id) if rel != null else &"stranger"
		var hours := Phase7Texts.shop_hours(Database.schedule(id) as NpcSchedule) if data.shop_id != &"" else ""
		var known := GiftPanel.liked_known(id)
		out.append({"npc_id": id, "name": data.display_name, "role": data.role, "met": met, "value": value, "tier": tier,
				"rel": Phase7Texts.rel_line(value, tier) if met else Phase7Texts.NOT_MET,
				"talked": Phase7Texts.PAGE_VILLAGE_TALKED_TODAY if rel != null and rel.talked_today(id) else Phase7Texts.PAGE_VILLAGE_TALKED,
				"shop": Phase7Texts.PAGE_VILLAGE_SHOP % hours if hours != "" else Phase7Texts.PAGE_VILLAGE_NO_SHOP,
				"likes": Phase7Texts.PAGE_VILLAGE_LIKES % Phase7Texts.likes_text(data.gifts_liked) if known else Phase7Texts.PAGE_VILLAGE_LIKES_UNKNOWN,
				"gone": id == &"oldwoman" and GameState.flag_on(&"hagedorn_dead"),
				"p8": JournalPagesPhase8.village_line(JournalPagesPhase8.village_extra(tree, id))})
	return out


static func build_village(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, width: float) -> void:
	var cards := village_cards(tree)
	left.add_child(UIKit.label(Phase7Texts.PAGE_VILLAGE_REP % GameState.reputation_label(), &"InkDimLabel", true))
	for i: int in cards.size():
		(left if i < 4 else right).add_child(_villager_card(cards[i], width))
	right.add_child(UIKit.spacer(false))
	var hint := UIKit.label(Phase7Texts.PAGE_VILLAGE_HINT, &"InkDimLabel", true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)


static func _villager_card(c: Dictionary, width: float) -> Control:
	var row := UIKit.panel(&"LedgerRowPanel")
	row.set_meta(&"npc_id", c.npc_id)
	var line := UIKit.hbox(12)
	line.add_child(UIKit.icon(Database.icon(StringName("villager_%s" % c.npc_id)), PORTRAIT))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(8)
	var name := UIKit.label(str(c.name), &"InkHeaderLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UIKit.label(str(c.rel), &"InkStampLabel" if bool(c.met) else &"InkDimLabel"))
	col.add_child(head)
	col.add_child(UIKit.label(str(c.role), &"InkDimLabel"))
	if bool(c.gone):
		col.add_child(UIKit.label(Phase7Texts.PAGE_VILLAGE_GONE, &"InkLabel"))
	else:
		var info := UIKit.label("%s%s%s" % [str(c.talked), Phase7Texts.SEP, str(c.shop)], &"InkLabel", true)
		info.custom_minimum_size.x = width - PORTRAIT - 100.0
		col.add_child(info)
		col.add_child(UIKit.label(str(c.likes), &"InkDimLabel"))
		# Phase 8 (§7.4): mood, the three story points with the next step, the favour.
		if str(c.get("p8", "")) != "":
			var p8 := UIKit.label(str(c.p8), &"InkStampLabel", true)
			p8.custom_minimum_size.x = width - PORTRAIT - 100.0
			col.add_child(p8)
	line.add_child(col)
	row.add_child(line)
	return row


# --- death note ---------------------------------------------------------------------------------------

## [{organ_label, container_word, where, finding, quast}] of the dead's specimens.
static func specimen_lines(tree: SceneTree, corpse_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var specimens := tree.get_first_node_in_group(SPECIMENS_GROUP) as Specimens if tree != null else null
	if specimens == null or corpse_id == "":
		return out
	for uid: String in specimens.of_corpse(corpse_id):
		var spec := specimens.get_record(uid)
		if spec == null:
			continue
		var finding := Database.finding(spec.finding_id) as SpecimenFindingData if spec.finding_id != &"" else null
		out.append({"uid": uid, "organ_label": Phase7Texts.organ_label(spec.organ), "where": CorpseExamOrgans.where(tree, specimens, corpse_id, spec.organ),
				"finding": finding.text if finding != null else "", "quast": spec.state == Specimens.STATE_RESEARCHED})
	return out


## Adds the specimens, the deduced cause and „Ursache deuten" to a death note body.
static func build_note(body: VBoxContainer, tree: SceneTree, corpse_id: String, width: float) -> Button:
	var lines := specimen_lines(tree, corpse_id)
	var manager := tree.get_first_node_in_group(MANAGER_GROUP) as CorpseManager if tree != null else null
	var record := manager.get_record(corpse_id) if manager != null else null
	if not lines.is_empty():
		body.add_child(UIKit.label(Phase7Texts.NOTE_SPECIMENS, &"LedgerHeadLabel"))
		for l: Dictionary in lines:
			body.add_child(UIKit.label("%s – %s" % [str(l.organ_label), str(l.where)], &"InkLabel", true))
			if str(l.finding) != "":
				var text := (Phase7Texts.NOTE_QUAST if bool(l.quast) else Phase7Texts.NOTE_FINDING) % str(l.finding)
				var f := UIKit.label(text, &"InkDimLabel", true)
				f.custom_minimum_size.x = width - 140.0
				body.add_child(f)
	if record != null and record.revealed_cause != &"":
		body.add_child(UIKit.label(Phase7Texts.NOTE_REVEALED % Phase7Texts.cause_label(record.revealed_cause), &"InkStampLabel"))
	var deductions := tree.get_first_node_in_group(DEDUCTIONS_GROUP) as Deductions if tree != null else null
	if deductions == null or not deductions.can_deduce(corpse_id):
		return null
	var b := UIKit.button(Phase7Texts.NOTE_DEDUCE, &"InkButton")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: EventBus.ui_panel_requested.emit(DEDUCTION_PANEL, {"corpse_id": corpse_id}))
	body.add_child(b)
	return b
