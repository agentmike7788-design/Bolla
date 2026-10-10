class_name JournalPagesPhase8
extends RefCounted
## The Phase-8 parts of the Merkbuch (docs/PHASE8_DESIGN.md §7.4), built for JournalPanel (static, read-only):
## - „Angehörige": one card per household and villager with dead up here – portrait, name, house, the graves,
##   the goodwill as one of five words (never the number), last and next visit („kommt in ≈ 2 Tagen") and the
##   open wishes with their state („Blumen ✓ · frisch bis morgen").
## - „Hollerbrück" additions to each villager card: today's mood as a word („heute bedrückt"), the three story
##   points (● done, ◎ possible now, ○ later) with the title of the next step, „Gefallen bereit" / „in 2 Tagen";
##   and the second sheet „Neue Gesichter": Jakob (levels per task, how he is as a sentence), Veit (alms given,
##   where he sits), Hanne (today here / next visit).
## - „Aufträge": friendship orders apart from the village's, the open return favours under „Was du schuldest".

const VISITORS_GROUP := &"visitors"
const GRAVE_CARE_GROUP := &"grave_care"
const NPC_LIFE_GROUP := &"npc_life"
const FRIENDSHIP_GROUP := &"friendship"
const APPRENTICE_GROUP := &"apprentice"
const WANDERERS_GROUP := &"wanderers"
const FESTIVALS_GROUP := &"festivals"
const RELATIONSHIPS_GROUP := &"relationships"
const FEST_PANEL := &"fest"
const PORTRAIT := 56.0
const CARDS_LEFT := 4


static func is_open() -> bool:
	return GameState.flag_on(&"p8_open")


# --- Angehörige -------------------------------------------------------------------------------------

## One card per kin with graves up here (households first): {kin_id, name, house, graves [names], goodwill,
## word, last, next, here, wishes [{kind, done, detail}]}.
static func kin_cards(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var visitors := tree.get_first_node_in_group(VISITORS_GROUP) as Visitors if tree != null else null
	if visitors == null:
		return out
	var care := tree.get_first_node_in_group(GRAVE_CARE_GROUP) as GraveCare
	var list: Array = visitors.kin_data if not visitors.kin_data.is_empty() else Database.kin_list()
	var households: Array[Dictionary] = []
	var villagers: Array[Dictionary] = []
	for raw: Variant in list:
		var kin := raw as KinData
		if kin == null:
			continue
		var graves := visitors.graves_of(kin.kin_id)
		if graves.is_empty():
			continue
		var names := PackedStringArray()
		for g: String in graves:
			names.append(Phase8Status.dead_name(tree, g))
		var today_visit := visitors.visit_of(kin.kin_id)
		var phase := StringName(str(today_visit.get("phase", "")))
		var here := phase != &"" and phase != &"gone"
		var gw := visitors.goodwill(kin.kin_id)
		var card := {"kin_id": kin.kin_id, "name": kin.display_name, "house": Phase8Texts.house_label(kin.house) if kin.house != &"" else "",
				"graves": names, "goodwill": gw, "word": Phase8Texts.goodwill_word(gw),
				"last": Phase8Status.last_visit_day(visitors, kin.kin_id), "next": Phase8Status.next_visit_day(tree, visitors, kin.kin_id),
				"here": here, "wishes": wish_lines(visitors, care, tree, kin.kin_id)}
		(villagers if kin.villager_id != &"" else households).append(card)
	out.append_array(households)
	out.append_array(villagers)
	return out


## [{kind, done, detail, text}] of the kin's open wishes.
static func wish_lines(visitors: Visitors, care: GraveCare, tree: SceneTree, kin_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in visitors.open_wishes():
		if StringName(str(w.get("kin_id", ""))) != kin_id:
			continue
		var kind := StringName(str(w.get("kind", "")))
		var done := WishRules.fulfilled(w, tree)
		var detail := Phase8Texts.PAGE_KIN_WISH_OPEN
		if str(w.get("state", "")) == "offered":
			detail = Phase8Texts.DAY_WISH_PARTS[&"offered"]
		elif done and kind == WishRules.KIND_FLOWERS and care != null and care.fresh_minutes_left(str(w.get("grave_id", ""))) > 0:
			detail = Phase8Texts.PAGE_KIN_FRESH_UNTIL % fresh_until(care.fresh_minutes_left(str(w.get("grave_id", ""))))
		elif done:
			detail = Phase8Texts.PAGE_KIN_WISH_DONE
		var text := Phase8Texts.PAGE_KIN_WISH % [Phase8Texts.wish_kind_label(kind), Phase8Texts.CHECK if done else Phase8Texts.NONE, detail]
		out.append({"kind": kind, "done": done, "detail": detail, "text": text, "grave": Phase8Status.dead_name(tree, str(w.get("grave_id", "")))})
	return out


## „heute Abend" / „morgen" / „Tag 57" – until when flowers with `left` fresh minutes stay fresh.
static func fresh_until(left: int) -> String:
	var end := TimeManager.minute_of_day + left
	if end < TimeManager.MINUTES_PER_DAY:
		return "heute Abend"
	if end < 2 * TimeManager.MINUTES_PER_DAY:
		return "morgen"
	return "Tag %d" % (TimeManager.day + floori(float(end) / float(TimeManager.MINUTES_PER_DAY)))


static func build_kin(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, width: float) -> void:
	var cards := kin_cards(tree)
	if cards.is_empty():
		left.add_child(UIKit.label(Phase8Texts.PAGE_KIN_NONE, &"InkDimLabel", true))
		return
	for i: int in cards.size():
		(left if i < CARDS_LEFT else right).add_child(_kin_card(cards[i], width))
	right.add_child(UIKit.spacer(false))
	var hint := UIKit.label(Phase8Texts.PAGE_KIN_HINT, &"InkDimLabel", true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)


static func _kin_card(c: Dictionary, width: float) -> Control:
	var row := UIKit.panel(&"LedgerRowPanel")
	row.set_meta(&"kin_id", c.kin_id)
	var line := UIKit.hbox(12)
	line.add_child(UIKit.icon(Database.icon(Phase8Texts.kin_portrait(c.kin_id)), PORTRAIT))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(8)
	var name := UIKit.label(str(c.name), &"InkHeaderLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UIKit.label(str(c.word), &"InkStampLabel"))
	col.add_child(head)
	var house := str(c.house)
	var graves := Phase8Texts.PAGE_KIN_GRAVES % ", ".join(c.graves as PackedStringArray)
	var g := UIKit.label(graves if house == "" else "%s%s%s" % [house, Phase8Texts.SEP, graves], &"InkDimLabel", true)
	g.custom_minimum_size.x = width - PORTRAIT - 110.0
	col.add_child(g)
	var last := int(c.last)
	var visit := "%s%s%s" % [Phase8Texts.PAGE_KIN_LAST % Phase8Texts.day_text(last, TimeManager.day) if last >= 0 else Phase8Texts.PAGE_KIN_LAST_NONE,
			Phase8Texts.SEP, Phase8Texts.next_visit_text(int(c.next), TimeManager.day, bool(c.here))]
	col.add_child(UIKit.label(visit, &"InkLabel"))
	for w: Dictionary in c.wishes:
		var wl := UIKit.label(str(w.text), &"InkStampLabel" if bool(w.done) else &"InkLabel", true)
		wl.custom_minimum_size.x = width - PORTRAIT - 110.0
		col.add_child(wl)
	line.add_child(col)
	row.add_child(line)
	return row


# --- Hollerbrück --------------------------------------------------------------------------------------

## The Phase-8 fields of a villager card: {mood, points, next_step, favor}. {} before p8_open.
static func village_extra(tree: SceneTree, npc_id: StringName) -> Dictionary:
	if tree == null or not is_open():
		return {}
	var out := {}
	var life := tree.get_first_node_in_group(NPC_LIFE_GROUP) as NpcLife
	if life != null and life.moods_active():
		out["mood"] = Phase8Texts.mood_word(life.mood(npc_id))
	var friendship := tree.get_first_node_in_group(FRIENDSHIP_GROUP) as Friendship
	var story := friendship.story(npc_id) if friendship != null else null
	if story != null:
		var done := friendship.step_done(npc_id)
		var offerable := friendship.offerable_step(npc_id) > 0
		out["points"] = Phase8Texts.story_points(done, offerable, Friendship.STEPS)
		if done < mini(Friendship.STEPS, story.steps.size()):
			out["next_step"] = story.steps[done].title
		else:
			out["next_step"] = Phase8Texts.PAGE_VILLAGE_STORY_DONE
		out["favor"] = Phase8Texts.favor_state(done, friendship.favor_block_reason(npc_id), friendship.favor_owed(npc_id) != &"")
	return out


## The line below a villager card: „heute bedrückt · ●◎○ Der Junge braucht Arbeit · Gefallen bereit".
static func village_line(extra: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in ["mood", "points", "next_step", "favor"]:
		var v := str(extra.get(key, ""))
		if v == "":
			continue
		if key == "next_step" and not parts.is_empty() and str(extra.get("points", "")) != "":
			parts[parts.size() - 1] = Phase8Texts.PAGE_VILLAGE_NEXT_STEP % [parts[parts.size() - 1], v]
		else:
			parts.append(v)
	return Phase8Texts.SEP.join(parts)


## The new faces' cards: Jakob, Veit, Hanne {id, name, role, lines: PackedStringArray, met}.
static func new_faces(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var app := tree.get_first_node_in_group(APPRENTICE_GROUP) as Apprentice if tree != null else null
	var lines := PackedStringArray()
	if app != null and app.is_hired():
		var lv := PackedStringArray()
		for task: StringName in Apprentice.TASKS:
			lv.append(Phase8Texts.PAGE_JAKOB_LEVELS % [Phase8Texts.task_label(task), Phase8Texts.level_marks(app.level(task)) if app.level(task) > 0 else Phase8Texts.NONE])
		lines.append(Phase8Texts.SEP.join(lv))
		lines.append(Phase8Texts.morale_text(app.morale()))
	else:
		lines.append(Phase8Texts.PAGE_JAKOB_NOT_HIRED)
	out.append(_face(Phase8Texts.APPRENTICE, lines, true))
	var wanderers := tree.get_first_node_in_group(WANDERERS_GROUP) as Wanderers if tree != null else null
	var veit := PackedStringArray()
	var veit_met := GameState.flag_on(&"p8_veit_met") or (wanderers != null and (wanderers.alms_count() > 0 or wanderers.talks(Wanderers.BEGGAR) > 0))
	if veit_met:
		veit.append(Phase8Texts.PAGE_VEIT_ALMS % (wanderers.alms_count() if wanderers != null else 0))
		var place := wanderers.place(Wanderers.BEGGAR, TimeManager.day, TimeManager.minute_of_day) if wanderers != null else &""
		if Phase8Texts.VEIT_PLACES.has(place):
			veit.append(Phase8Texts.PAGE_VEIT_PLACE % Phase8Texts.VEIT_PLACES[place])
	else:
		veit.append(Phase8Texts.PAGE_NOT_MET)
	out.append(_face(Phase8Texts.BEGGAR, veit, veit_met))
	var hanne := PackedStringArray()
	if wanderers != null:
		var place := wanderers.place(Wanderers.PEDDLER, TimeManager.day, TimeManager.minute_of_day)
		if wanderers.peddler_day(TimeManager.day) and place != &"":
			hanne.append(Phase8Texts.PAGE_HANNE_TODAY % Phase8Texts.PEDDLER_PLACES.get(place, "unterwegs"))
		else:
			var next := wanderers.next_peddler_day(TimeManager.day + 1 if wanderers.peddler_day(TimeManager.day) else TimeManager.day)
			var d := next - TimeManager.day
			hanne.append(Phase8Texts.PAGE_HANNE_TOMORROW if d == 1 else Phase8Texts.PAGE_HANNE_NEXT % [d, "Tag" if d == 1 else "Tagen"])
	out.append(_face(Phase8Texts.PEDDLER, hanne, true))
	return out


static func _face(id: StringName, lines: PackedStringArray, met: bool) -> Dictionary:
	return {"id": id, "name": Phase8Texts.person_name(id), "role": str(Phase8Texts.PEOPLE[id][2]), "lines": lines, "met": met}


static func build_new_faces(left: VBoxContainer, right: VBoxContainer, tree: SceneTree, width: float) -> void:
	var faces := new_faces(tree)
	for i: int in faces.size():
		var f: Dictionary = faces[i]
		var row := UIKit.panel(&"LedgerRowPanel")
		row.set_meta(&"npc_id", f.id)
		var line := UIKit.hbox(12)
		line.add_child(UIKit.icon(Database.icon(StringName("villager_%s" % f.id)), 64.0))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(f.name), &"InkHeaderLabel"))
		col.add_child(UIKit.label(str(f.role), &"InkDimLabel"))
		for t: String in f.lines:
			var l := UIKit.label(t, &"InkLabel", true)
			l.custom_minimum_size.x = width - 180.0
			col.add_child(l)
		line.add_child(col)
		row.add_child(line)
		(left if i < 2 else right).add_child(row)


## On a festival day: the button to the festival card (null otherwise).
static func fest_button(parent: VBoxContainer, tree: SceneTree) -> Button:
	var fest := tree.get_first_node_in_group(FESTIVALS_GROUP) as Festivals if tree != null else null
	if fest == null or fest.today() == &"":
		return null
	var id := fest.today()
	var b := UIKit.button("%s: %s" % [Phase8Texts.FEST_OPEN, Phase8Texts.fest_name(id)], &"InkButton")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: EventBus.ui_panel_requested.emit(FEST_PANEL, {"fest_id": id}))
	parent.add_child(b)
	return b


# --- Aufträge ---------------------------------------------------------------------------------------

## The group of an order card: &"village" (Phase 7), &"friend" (a story step), &"owed" (a return favour).
static func order_group(o: OrderData) -> StringName:
	if o == null or o.category != OrderData.CATEGORY_FRIEND:
		return &"village"
	return &"owed" if String(o.id).contains("_return_") else &"friend"
