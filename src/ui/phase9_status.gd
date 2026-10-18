class_name Phase9Status
extends RefCounted
## Read-only snapshots of the Phase-9 systems for the UI (docs/PHASE9_DESIGN.md §7, W-UI): the objective state
## (ObjectiveResolver world.p9 → objective()), the pinned „Vorhaben" entry (QuestLog.objective), the visibility of the
## Merkbuch tabs „Vorhaben" / „Die Liste" / „Briefe", the open letters in the gravekeeper's bag and the map's Phase-9
## markers. Every system is found by its group; a missing one leaves its part empty (headless tests, Phase-8 worlds).
## Never changes game state.

const QUESTS_GROUP := &"quests"
const WHO_KNOWS_GROUP := &"who_knows"
const LETTERS_GROUP := &"letters"
const STRANGER_GROUP := &"stranger"
const HILL_GROUP := &"hill_requests"
const JOURNAL_GROUP := &"journal"
const PLAYER_GROUP := &"player"
const OPEN_FLAG := &"p9_open"
const INTRO_FLAG := &"p9_intro"
const MAIN_QUEST := &"q_who_knows"
const LIGHT_INSIGHT := &"i_light_before"
const WITNESS_NEED := 3
const FLAG_DEAD := &"sieber_dead"
const FLAG_BURIED := &"sieber_buried"
const FLAG_GONE := &"sieber_gone"
const FLAG_GOAL := &"who_knows_when_complete"
const REGION_GATE := &"graveyard"


static func is_open() -> bool:
	return GameState.flag_on(OPEN_FLAG)


static func quests(tree: SceneTree) -> Quests:
	return _first(tree, QUESTS_GROUP) as Quests


static func letters(tree: SceneTree) -> Letters:
	return _first(tree, LETTERS_GROUP) as Letters


static func stranger(tree: SceneTree) -> Stranger:
	return _first(tree, STRANGER_GROUP) as Stranger


static func who_knows(tree: SceneTree) -> WhoKnows:
	return _first(tree, WHO_KNOWS_GROUP) as WhoKnows


static func hill(tree: SceneTree) -> HillRequests:
	return _first(tree, HILL_GROUP) as HillRequests


# --- Merkbuch tabs (§7.1, §7.2) ------------------------------------------------------------------------------------

## „Vorhaben" from the first large request (pinned at a board or in the log) – the chain groups from p9_open.
static func plans_shown(tree: SceneTree) -> bool:
	if is_open():
		return true
	var h := hill(tree)
	if h == null:
		return false
	if not h.large_ids().is_empty():
		return true
	for e: Dictionary in h.history():
		if h.is_large(StringName(str(e.get("id", "")))):
			return true
	return false


## „Die Liste" once the ledger was read (JournalManager.list_known).
static func list_shown(tree: SceneTree) -> bool:
	var j := _first(tree, JOURNAL_GROUP)
	return j != null and j.has_method(&"list_known") and bool(j.call(&"list_known"))


## „Briefe" from p9_open or as soon as Letters knows a letter.
static func letters_shown(tree: SceneTree) -> bool:
	if is_open():
		return true
	var l := letters(tree)
	return l != null and not l.uids().is_empty()


# --- letters -----------------------------------------------------------------------------------------------------------

## The letters the gravekeeper holds undecided (Letters.open_uids that are in `inv`; all open ones without `inv`).
static func open_letters(tree: SceneTree, inv: Inventory) -> PackedStringArray:
	var out := PackedStringArray()
	var l := letters(tree)
	if l == null:
		return out
	for uid: String in l.open_uids():
		if inv == null or inv.has_uid(uid):
			out.append(uid)
	return out


## „Rosine Wackernagel" from the outside „An Rosine Wackernagel, Holderkrug" (the address before the first comma).
static func addressee(outside: String) -> String:
	var text := outside.strip_edges()
	for prefix: String in ["An den ", "An die ", "An ", "an "]:
		if text.begins_with(prefix):
			text = text.trim_prefix(prefix)
			break
	for cut: String in [",", ". "]:
		var at := text.find(cut)
		if at > 0:
			text = text.substr(0, at)
	return text.strip_edges()


# --- the objective line (§7.5) ------------------------------------------------------------------------------------------

## {} before p9_open (and without Quests); else {open, intro, pinned, main_step, main_progress, main_days, witnessed,
## witness_need, stranger_gate, bury, letter, post, goal_parts, goal_done}.
static func objective_state(tree: SceneTree) -> Dictionary:
	if tree == null:
		return {}
	var out := {}
	var pinned := QuestLog.objective(tree)
	if not pinned.is_empty():
		out["pinned"] = pinned
	var q := quests(tree)
	if q == null or not q.is_open():
		return out
	out["open"] = true
	out["intro"] = GameState.flag_on(INTRO_FLAG)
	if q.state(MAIN_QUEST) == Quests.STATE_OPEN:
		var step := q.current_step(MAIN_QUEST)
		out["main_step"] = step
		out["main_progress"] = q.progress(MAIN_QUEST)
		var deadline := q.deadline(MAIN_QUEST)
		out["main_days"] = QuestLog.days_left_until(deadline, TimeManager.day)
	var w := who_knows(tree)
	if w != null:
		var n := 0
		for e: StringName in w.witnessed():
			var entry := w.entry(e)
			if entry != null and not entry.open:
				n += 1
		out["witnessed"] = n
	var insight := Database.insight(LIGHT_INSIGHT) as InsightData
	out["witness_need"] = insight.any_count if insight != null and insight.any_count > 0 else WITNESS_NEED
	var s := stranger(tree)
	var player := _first(tree, PLAYER_GROUP)
	var region := StringName(str(player.get(&"region_id"))) if player != null else REGION_GATE
	if s != null and not s.gone() and s.present(REGION_GATE) and region in [REGION_GATE, &""] and s.question() != "":
		out["stranger_gate"] = true
	out["bury"] = GameState.flag_on(FLAG_DEAD) and not GameState.flag_on(FLAG_BURIED) and not GameState.flag_on(FLAG_GONE)
	var l := letters(tree)
	var inv := player.get(&"inventory") as Inventory if player != null else null
	if l != null:
		for uid: String in open_letters(tree, inv):
			var data := l.letter(uid)
			if data == null:
				continue
			var name := addressee(data.outside)
			if l.kind_of(uid) == LetterData.KIND_POST:
				out["post"] = name
			elif name != "":
				out["letter"] = name
			break
	var g := q.goal_progress()
	var parts := 0
	if bool(g.get("main", false)):
		parts += 1
	if bool(g.get("letters_step", false)) and int(g.get("letters_decided", 0)) >= int(g.get("letters_goal", 5)):
		parts += 1
	if int(g.get("large", 0)) >= int(g.get("large_goal", 2)):
		parts += 1
	out["goal_parts"] = parts
	out["goal_done"] = GameState.flag_on(FLAG_GOAL)
	return out


## The Phase-9 line of the HUD ("" = nothing of Phase 9 to say; the pinned entry is ObjectiveResolver's own).
static func objective(world_state: Dictionary) -> String:
	var raw: Variant = world_state.get("p9", {})
	if not raw is Dictionary:
		return ""
	var world := raw as Dictionary
	if not bool(world.get("open", false)):
		return ""
	if not bool(world.get("intro", false)):
		return Phase9Texts.OBJ_OSRIC
	if bool(world.get("stranger_gate", false)):
		return Phase9Texts.OBJ_STRANGER
	if bool(world.get("bury", false)):
		return Phase9Texts.OBJ_BURY
	var progress: Vector2i = world.get("main_progress", Vector2i.ZERO) if world.get("main_progress") is Vector2i else Vector2i.ZERO
	match StringName(str(world.get("main_step", ""))):
		&"h1":
			return Phase9Texts.OBJ_KLADDE
		&"h2":
			return Phase9Texts.OBJ_LIST % [progress.x, maxi(progress.y, 5)]
		&"h3":
			return Phase9Texts.OBJ_WITNESS % [mini(int(world.get("witnessed", 0)), int(world.get("witness_need", WITNESS_NEED))),
					int(world.get("witness_need", WITNESS_NEED))]
		&"h4":
			return Phase9Texts.OBJ_WHO_S
		&"h5":
			return Phase9Texts.OBJ_CONFIDE
		&"h6":
			return Phase9Texts.OBJ_DECIDE % Phase9Texts.decide_words(int(world.get("main_days", -1)))
	var letter := str(world.get("letter", ""))
	if letter != "":
		return Phase9Texts.OBJ_LETTER % letter
	var post := str(world.get("post", ""))
	if post != "":
		return Phase9Texts.OBJ_LETTER_POST % post
	if not bool(world.get("goal_done", false)):
		return Phase9Texts.OBJ_GOAL % int(world.get("goal_parts", 0))
	return ""


## The pinned entry's line ("" = none pinned).
static func pinned_objective(world_state: Dictionary) -> String:
	var raw: Variant = world_state.get("p9", {})
	if not raw is Dictionary:
		return ""
	var pinned: Variant = (raw as Dictionary).get("pinned", {})
	if not pinned is Dictionary or (pinned as Dictionary).is_empty():
		return ""
	return Phase9Texts.pinned_line(pinned as Dictionary)


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
