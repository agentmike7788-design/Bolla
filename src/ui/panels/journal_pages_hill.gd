class_name JournalPagesHill
extends RefCounted
## The Merkbuch's tab „Bitten" (G8 Runde 6 „Bitten vom Hügel", docs/PHASE8_DESIGN.md G8 Runde 6 §5), built for
## JournalPanel (static, read-only): left the accepted requests (giver, deadline, reward) and what still hangs at the
## gate, right the log of done and missed requests (with the day). Shown once Osric pinned the first request.

const HILL_GROUP := &"hill_requests"


static func hill(tree: SceneTree) -> HillRequests:
	return tree.get_first_node_in_group(HILL_GROUP) as HillRequests if tree != null else null


## True once the tab exists (HillRequests.any_posted).
static func shown(tree: SceneTree) -> bool:
	var h := hill(tree)
	return h != null and h.any_posted()


## {active: [{id, title, giver_name, deadline, reward}], offered: [...], log: [{title, day, state}]}.
static func page(tree: SceneTree) -> Dictionary:
	var out := {"active": [], "offered": [], "log": []}
	var h := hill(tree)
	if h == null:
		return out
	for id: StringName in h.board():
		var r := h.request_data(id)
		if r == null:
			continue
		var entry := {"id": id, "title": h.title_of(id), "giver_name": HillRules.giver_name(r.giver),
				"deadline": HillTexts.deadline(r.days_limit, h.days_left(id)),
				"reward": HillTexts.SEP.join(HillRules.reward_parts(r))}
		var key := "active" if h.state(id) == HillRequests.STATE_ACCEPTED else "offered"
		(out[key] as Array).append(entry)
	var log := h.history()
	log.reverse()
	out["log"] = log
	return out


static func build(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, width: float) -> void:
	var p := page(tree)
	left.add_child(UIKit.label(HillTexts.PAGE_ACTIVE, &"InkHeaderLabel"))
	var active: Array = p.active
	if active.is_empty():
		left.add_child(UIKit.label(HillTexts.PAGE_NONE, &"InkDimLabel", true))
	for e: Dictionary in active:
		left.add_child(_entry(e, width, false))
	left.add_child(LedgerOrnament.new())
	left.add_child(UIKit.label(HillTexts.PAGE_OFFERED, &"InkHeaderLabel"))
	var offered: Array = p.offered
	if offered.is_empty():
		left.add_child(UIKit.label(HillTexts.PAGE_NONE_OFFERED, &"InkDimLabel", true))
	for e: Dictionary in offered:
		left.add_child(_entry(e, width, true))
	right.add_child(UIKit.label(HillTexts.PAGE_DONE, &"InkHeaderLabel"))
	var log: Array = p.log
	if log.is_empty():
		right.add_child(UIKit.label(HillTexts.PAGE_NONE_DONE, &"InkDimLabel"))
	for e: Dictionary in log:
		var row := UIKit.hbox(8)
		var failed := StringName(str(e.get("state", ""))) == HillRequests.STATE_FAILED
		var t := UIKit.label(HillTexts.PAGE_DONE_ENTRY % [str(e.get("title", "")), int(e.get("day", 0))],
				&"InkDimLabel" if failed else &"InkLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIKit.label(HillTexts.PAGE_FAILED_STAMP if failed else HillTexts.PAGE_DONE_STAMP, &"InkStampLabel"))
		right.add_child(row)
	right.add_child(UIKit.spacer(false))
	var quote := UIKit.label(HillTexts.PAGE_QUOTE, &"InkDimLabel", true)
	quote.custom_minimum_size.x = width - 80.0
	right.add_child(quote)


static func _entry(e: Dictionary, width: float, dim: bool) -> Control:
	var row := UIKit.panel(&"LedgerRowPanel")
	row.set_meta(&"request_id", e.get("id", &""))
	var col := UIKit.vbox(2)
	var head := UIKit.hbox(8)
	var t := UIKit.label(str(e.title), &"InkDimLabel" if dim else &"InkHeaderLabel", true)
	t.custom_minimum_size.x = width - 300.0
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.label(str(e.deadline), &"InkStampLabel"))
	col.add_child(head)
	col.add_child(UIKit.label(HillTexts.PANEL_FROM % str(e.giver_name) + HillTexts.SEP + str(e.reward), &"InkDimLabel", true))
	row.add_child(col)
	return row
