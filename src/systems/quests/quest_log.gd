class_name QuestLog
extends RefCounted
## The reader of the journal tab „Vorhaben" and the HUD (docs/PHASE9_DESIGN.md §2.1, §7.1, §3.4): groups main chain,
## side chains, large requests, requests (G8 Runde 6), orders (Phase 7 + errands of category quest), friendship
## (Phase 8), „Was du schuldest"; reads states only (never changes one). A missing system = an empty group.
##
## Entry: {group, id, title, giver, line, days_left, steps, pinned} + summary, state, progress (Vector2i done/total of
## the current step or the parts; ZERO = none), ending, ending_title, closing_line (chains).
## steps: chains – [{id, title, hint, state: done | current | hidden, choice, choice_label}] (hidden = a future step,
## title "…"); large requests – [{id, title, state: done | open}]; else [].
## days_left: 1 = today is the last day, −1 = no deadline.

const GROUP_MAIN := &"main"
const GROUP_SIDE := &"side"
const GROUP_LARGE := &"large"
const GROUP_HILL := &"hill"
const GROUP_ORDERS := &"orders"
const GROUP_FRIEND := &"friend"
const GROUP_OWED := &"owed"
const GROUPS: Array[StringName] = [GROUP_MAIN, GROUP_SIDE, GROUP_LARGE, GROUP_HILL, GROUP_ORDERS, GROUP_FRIEND, GROUP_OWED]
const STEP_DONE := &"done"
const STEP_CURRENT := &"current"
const STEP_HIDDEN := &"hidden"
const PART_OPEN := &"open"
const HIDDEN_TITLE := "…"
const QUESTS_GROUP := &"quests"
const HILL_GROUP := &"hill_requests"
const ORDERS_GROUP := &"orders"
const PLACES: Array[StringName] = [&"gate", &"village"]
## Phase 8: a return favour is a friend order with „_return_" in its id (JournalPagesPhase8.order_group).
const RETURN_MARK := "_return_"


## {group, id, title, giver, line, days_left, steps, pinned} in the order of GROUPS.
static func entries(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tree == null:
		return out
	var quests := tree.get_first_node_in_group(QUESTS_GROUP) as Quests
	var pinned := quests.pinned() if quests != null else &""
	var by_group := {}
	for g: StringName in GROUPS:
		by_group[g] = [] as Array[Dictionary]
	if quests != null:
		for e: Dictionary in _chains(quests):
			(by_group[e.group] as Array).append(e)
	var hill := tree.get_first_node_in_group(HILL_GROUP)
	if hill != null:
		for e: Dictionary in _large(hill):
			(by_group[GROUP_LARGE] as Array).append(e)
		for e: Dictionary in _small(hill):
			(by_group[GROUP_HILL] as Array).append(e)
	var orders := tree.get_first_node_in_group(ORDERS_GROUP) as Orders
	if orders != null:
		for e: Dictionary in _orders(orders):
			(by_group[e.group] as Array).append(e)
	for g: StringName in GROUPS:
		for e: Dictionary in by_group[g]:
			e["pinned"] = pinned != &"" and StringName(str(e.id)) == pinned
			out.append(e)
	return out


## The pinned entry → HUD line: {id, group, title, line, days_left, progress} ({} = nothing pinned / it is gone).
static func objective(tree: SceneTree) -> Dictionary:
	for e: Dictionary in entries(tree):
		if bool(e.get("pinned", false)):
			return {"id": e.id, "group": e.group, "title": e.title, "line": e.line, "days_left": e.days_left,
					"progress": e.get("progress", Vector2i.ZERO)}
	return {}


## days_left from the last valid day (deadline day itself still counts): 1 = today.
static func days_left_until(last_day: int, today: int) -> int:
	if last_day < 0:
		return -1
	return maxi(last_day - today + 1, 0)


# --- groups -------------------------------------------------------------------------------------

static func _chains(quests: Quests) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: QuestData in quests.all_quests():
		var st := quests.state(q.id)
		if st == Quests.STATE_NONE:
			continue
		var current := quests.current_step(q.id)
		var cur_data := QuestRules.step(q, current)
		var e_data := QuestRules.ending_data(q, quests.ending(q.id))
		var line := ""
		if st == Quests.STATE_OPEN and cur_data != null:
			line = cur_data.title
		elif e_data != null:
			line = e_data.title
		out.append({"group": GROUP_MAIN if q.kind == QuestData.KIND_MAIN else GROUP_SIDE, "id": q.id, "title": q.title,
				"giver": q.giver, "line": line, "days_left": days_left_until(quests.deadline(q.id), TimeManager.day) if st == Quests.STATE_OPEN else -1,
				"steps": _chain_steps(quests, q), "pinned": false, "summary": q.summary, "state": st,
				"progress": quests.progress(q.id) if st == Quests.STATE_OPEN else Vector2i.ZERO,
				"hint": cur_data.hint if cur_data != null and st == Quests.STATE_OPEN else "",
				"ending": quests.ending(q.id), "ending_title": e_data.title if e_data != null else "",
				"closing_line": e_data.closing_line if e_data != null else ""})
	return out


static func _chain_steps(quests: Quests, q: QuestData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done := quests.steps_done(q.id)
	var current := quests.current_step(q.id)
	for s: QuestStepData in q.steps:
		if s == null:
			continue
		var choice_id := quests.choice_of(q.id, s.id)
		var c := QuestRules.choice(s, choice_id)
		var st := STEP_DONE if done.has(s.id) else (STEP_CURRENT if s.id == current else STEP_HIDDEN)
		out.append({"id": s.id, "title": s.title if st != STEP_HIDDEN else HIDDEN_TITLE, "hint": s.hint if st == STEP_CURRENT else "",
				"state": st, "choice": choice_id, "choice_label": c.label if c != null else ""})
	return out


## Running large requests: on a board of HillRequests with their parts (P2: parts_done non-empty).
static func _large(hill: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not hill.has_method(&"large_board") or not hill.has_method(&"parts_done"):
		return out
	for place: StringName in PLACES:
		for id: StringName in hill.call(&"large_board", place):
			var parts: Array[bool] = hill.call(&"parts_done", id)
			if parts.is_empty():
				continue
			var r := _large_data(hill, id)
			var steps: Array[Dictionary] = []
			var done := 0
			var line := ""
			for i: int in parts.size():
				var part := r.parts[i] as OrderData if r != null and i < r.parts.size() else null
				var title := part.title if part != null else ""
				steps.append({"id": StringName(str(i)), "title": title, "state": STEP_DONE if parts[i] else PART_OPEN})
				if parts[i]:
					done += 1
				elif line == "":
					line = title
			var left := int(hill.call(&"days_left", id)) if hill.has_method(&"days_left") else -1
			out.append({"group": GROUP_LARGE, "id": id, "title": r.title if r != null else String(id),
					"giver": r.giver if r != null else &"", "line": line, "days_left": left, "steps": steps, "pinned": false,
					"progress": Vector2i(done, parts.size()), "place": place})
	return out


static func _large_data(hill: Node, id: StringName) -> OrderData:
	var r := Database.large_request(id) as OrderData
	if r == null and hill.has_method(&"request_data"):
		var v: Variant = hill.call(&"request_data", id)
		r = v as OrderData if v is OrderData else null
	return r


## Accepted small requests of the gate's notice board (G8 Runde 6).
static func _small(hill: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not hill.has_method(&"active"):
		return out
	for id: StringName in hill.call(&"active"):
		var r: Variant = hill.call(&"request_data", id) if hill.has_method(&"request_data") else null
		var data := r as OrderData if r is OrderData else null
		if data != null and data.size == OrderData.SIZE_LARGE:
			continue
		var title := str(hill.call(&"title_of", id)) if hill.has_method(&"title_of") else String(id)
		out.append({"group": GROUP_HILL, "id": id, "title": title, "giver": data.giver if data != null else &"", "line": title,
				"days_left": int(hill.call(&"days_left", id)) if hill.has_method(&"days_left") else -1, "steps": [] as Array[Dictionary],
				"pinned": false, "progress": Vector2i.ZERO})
	return out


## Accepted orders: Phase 7 and errands (quest) → orders, friendship steps → friend, return favours → owed.
static func _orders(orders: Orders) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null:
			continue
		var group := GROUP_ORDERS
		if Orders.is_friend(o):
			group = GROUP_OWED if String(o.id).contains(RETURN_MARK) else GROUP_FRIEND
		var due := orders.deadline_day(id)
		out.append({"group": group, "id": id, "title": o.title, "giver": o.giver, "line": o.title,
				"days_left": days_left_until(due - 1, TimeManager.day) if due > 0 else -1, "steps": [] as Array[Dictionary],
				"pinned": false, "progress": Vector2i.ZERO, "errand": Orders.is_quest(o)})
	return out
