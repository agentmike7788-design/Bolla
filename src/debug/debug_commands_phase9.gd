class_name DebugCommandsPhase9
extends RefCounted
## Phase-9 commands of the debug console (docs/PHASE9_DESIGN.md §6, W1-Anschluss 11), dispatched by DebugCommands.run():
## p9 open · quest <id> [step] · quest choose <quest> <step> <choice> · ending <away|stay|public|silent> · kladde · witness
## <entry> · match <entry> · sieber <marked|leave|die|now> · lightday <n> · letter <id> [corpse] · letters · post <id> ·
## stranger <arrive|now|step <k>|gone> · large <id> · large part <id> <n> · large board · goal9 · vis9. Every command goes
## through the system (found by its group) – its public API where there is one, else its own save_state()/load_state()
## round, so the system's rules and tolerance apply; without it: "Keine Spielwelt geladen.". Returns {ok, text}.
## Shortcuts for testing only.

const COMMANDS: PackedStringArray = ["p9", "quest", "ending", "kladde", "witness", "match", "sieber", "lightday", "letter",
		"letters", "post", "stranger", "large", "goal9", "vis9"]
const HELP: PackedStringArray = [
	"p9 open – Phase 9 sofort öffnen · quest <kette> [schritt] – Schritt setzen · quest choose <kette> <schritt> <wahl>",
	"ending <away|stay|public|silent> – Hauptkette beenden · kladde – die Liste · witness <eintrag> · match <eintrag>",
	"sieber <marked|leave|die|now> · lightday <tag> – Licht bei den Siebers · letter <id> [leiche] – Brief in die Tasche",
	"letters – alle Briefe · post <id> – Post für den Hügel wartet · stranger <arrive|now|step <k>|gone>",
	"large <id> – große Bitte anheften · large part <id> <n> – Teil n erledigt · large board · goal9 – Kapitel · vis9",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const MAIN_QUEST := &"q_who_knows"
const DECIDE_STEP := &"h6"
const ENDINGS: Array[StringName] = [&"away", &"stay", &"public", &"silent"]
const CASE_QUEST := &"q_case"
const VIS_HEIGHT := 1.4
const VIS_IDS: Array[StringName] = [&"stranger", &"kin_sieber_v", &"beggar", &"peddler", &"carter"]
## The stranger's minute at the gate (14:10).
const STRANGER_MINUTE := 850

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"p9":
			return _cmd_p9(args)
		"quest":
			return _cmd_quest(args)
		"ending":
			return _cmd_ending(args)
		"kladde":
			return _cmd_kladde(args)
		"witness":
			return _cmd_witness(args)
		"match":
			return _cmd_match(args)
		"sieber":
			return _cmd_sieber(args)
		"lightday":
			return _cmd_lightday(args)
		"letter":
			return _cmd_letter(args, false)
		"post":
			return _cmd_letter(args, true)
		"letters":
			return _cmd_letters(args)
		"stranger":
			return _cmd_stranger(args)
		"large":
			return _cmd_large(args)
		"goal9":
			return _cmd_goal9(args)
		"vis9":
			return _cmd_vis9(args)
	return _error("?")


func _cmd_p9(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "open":
		return _error("Format: p9 open")
	var q := _system(&"quests") as Quests
	if q == null:
		return _error(TEXT_NO_WORLD)
	for flag: StringName in [&"village_open", &"name_in_village_complete", &"p8_open", &"who_comes_up_complete"]:
		GameState.set_flag(flag, true)
	q.open_now()
	return _ok("Phase 9 ist offen (p9_open_day %d)." % q.open_day())


func _cmd_quest(args: PackedStringArray) -> Dictionary:
	var q := _system(&"quests") as Quests
	if q == null:
		return _error(TEXT_NO_WORLD)
	if not args.is_empty() and args[0].to_lower() == "choose":
		if args.size() != 4:
			return _error("Format: quest choose <kette> <schritt> <wahl>")
		var id := StringName(args[1].to_lower())
		var step := StringName(args[2].to_lower())
		var choice := StringName(args[3].to_lower())
		if q.current_step(id) != step:
			_set_step(q, id, step)
		if not q.choose(id, step, choice):
			for c: Dictionary in q.choices(id):
				if StringName(str(c.id)) == choice and str(c.reason) != "":
					return _error("Nicht wählbar: %s" % str(c.reason))
			return _error("Wahl '%s' bei %s/%s nicht möglich." % [choice, id, step])
		return _ok("%s: %s gewählt (%s)." % [id, choice, q.state(id)])
	if args.is_empty() or args.size() > 2:
		return _error("Format: quest <kette> [schritt]")
	var quest_id := StringName(args[0].to_lower())
	var data := q.quest_data(quest_id)
	if data == null:
		return _error("Unbekannte Kette '%s'." % quest_id)
	var step_id := StringName(args[1].to_lower()) if args.size() == 2 else (data.steps[0].id if not data.steps.is_empty() else &"")
	if QuestRules.step(data, step_id) == null:
		return _error("Unbekannter Schritt '%s' (%s)." % [step_id, ", ".join(data.steps.map(func(s: QuestStepData) -> String: return String(s.id)))])
	_set_step(q, quest_id, step_id)
	return _ok("%s steht bei %s („%s“)." % [quest_id, step_id, QuestRules.step(data, step_id).title])


## Puts `quest_id` at `step_id` (the steps before it done) through Quests' own state round.
func _set_step(q: Quests, quest_id: StringName, step_id: StringName) -> void:
	var data := q.quest_data(quest_id)
	var state := q.save_state()
	var done: Array = []
	for s: QuestStepData in data.steps:
		if s.id == step_id:
			break
		done.append(String(s.id))
	var open: Array = state.get("open", [])
	if not String(quest_id) in open:
		open.append(String(quest_id))
	state["open"] = open
	(state.get_or_add("done", {}) as Dictionary)[String(quest_id)] = done
	(state.get_or_add("step", {}) as Dictionary)[String(quest_id)] = String(step_id)
	(state.get_or_add("ending", {}) as Dictionary).erase(String(quest_id))
	var settled: Array = state.get("settled", [])
	settled.erase(String(quest_id))
	(state.get_or_add("step_day", {}) as Dictionary)[String(quest_id)] = TimeManager.day
	q.load_state(state)


func _cmd_ending(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not StringName(args[0].to_lower()) in ENDINGS:
		return _error("Format: ending <away|stay|public|silent>")
	var q := _system(&"quests") as Quests
	if q == null:
		return _error(TEXT_NO_WORLD)
	var e := StringName(args[0].to_lower())
	if e == &"away":
		var w := _system(&"who_knows") as WhoKnows
		if w != null and not w.letter_posted():
			var state := w.save_state()
			state["letter_posted"] = true
			w.load_state(state)
	_set_step(q, MAIN_QUEST, DECIDE_STEP)
	if not q.choose(MAIN_QUEST, DECIDE_STEP, e):
		return _error("Ende '%s' nicht möglich." % e)
	return _ok("Hauptkette: Ende %s (%s)." % [e, q.state(MAIN_QUEST)])


func _cmd_kladde(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: kladde")
	var journal := _system(&"journal")
	if journal == null or not journal.has_method(&"list_page"):
		var w := _system(&"who_knows") as WhoKnows
		if w == null or w.light_list() == null:
			return _error(TEXT_NO_WORLD)
		var lines := PackedStringArray()
		for e: LightEntryData in w.light_list().entries:
			lines.append("%s %s %s%s" % [e.id, e.initial, "✓" if w.matched(e.id) else "–", " Zeuge" if e.id in w.witnessed() else ""])
		return _ok("\n".join(lines))
	var page: Dictionary = journal.call(&"list_page")
	var out := PackedStringArray(["Die Liste (%s):" % ("gelesen" if bool(page.get("known", false)) else "noch nicht gelesen")])
	for e: Variant in page.get("entries", []):
		var d := e as Dictionary
		out.append("%s · %s · %s · %s%s" % [str(d.get("id", "")), str(d.get("date", "")), str(d.get("initial", "")),
				str(d.get("name", "")) if str(d.get("name", "")) != "" else "–", " · Zeuge ✓" if bool(d.get("witnessed", false)) else ""])
	return _ok("\n".join(out))


func _cmd_witness(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: witness <eintrag>")
	var w := _system(&"who_knows") as WhoKnows
	if w == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	if w.entry(id) == null:
		return _error("Unbekannter Eintrag '%s'." % id)
	if not w.witness(id):
		var state := w.save_state()
		var list: Array = state.get("witnessed", [])
		if not String(id) in list:
			list.append(String(id))
		state["witnessed"] = list
		w.load_state(state)
	return _ok("Zeugen: %s" % ", ".join(w.witnessed().map(func(e: StringName) -> String: return String(e))))


func _cmd_match(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: match <eintrag>")
	var w := _system(&"who_knows") as WhoKnows
	if w == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	if w.entry(id) == null:
		return _error("Unbekannter Eintrag '%s'." % id)
	var state := w.save_state()
	var list: Array = state.get("matched", [])
	if not String(id) in list:
		list.append(String(id))
	state["matched"] = list
	w.load_state(state)
	var q := _system(&"quests") as Quests
	if q != null:
		q.note(WhoKnows.NOTE_GRAVE, String(id))
	EventBus.light_entry_changed.emit(id, WhoKnows.KIND_MATCHED)
	return _ok("Zugeordnet: %s" % id)


func _cmd_sieber(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["marked", "leave", "die", "now"]:
		return _error("Format: sieber <marked|leave|die|now>")
	var w := _system(&"who_knows") as WhoKnows
	if w == null:
		return _error(TEXT_NO_WORLD)
	match args[0].to_lower():
		"marked":
			GameState.set_flag(&"q_sieber_marked", true)
			var state := w.save_state()
			state["marked_seen"] = true
			w.load_state(state)
			return _ok("Johann ist gezeichnet (H4).")
		"leave":
			GameState.set_flag(&"sieber_gone", true)
			EventBus.light_entry_changed.emit(&"e_open", WhoKnows.KIND_DEPARTED)
			return _ok("Johann ist fort (sieber_gone).")
		"die":
			GameState.set_flag(&"sieber_dead", true)
			return _ok("Johann ist gestorben (sieber_dead) – D3 kommt.")
		_:
			var day := TimeManager.day - 20
			GameState.set_flag(&"q_light_day", day)
			var state := w.save_state()
			state["light_day"] = day
			w.load_state(state)
			return _ok("Licht bei den Siebers an Tag %d – heute Nacht ist die Todesnacht." % day)


func _cmd_lightday(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int():
		return _error("Format: lightday <tag>")
	var w := _system(&"who_knows") as WhoKnows
	if w == null:
		return _error(TEXT_NO_WORLD)
	var day := int(args[0])
	GameState.set_flag(&"q_light_day", day)
	var state := w.save_state()
	state["light_day"] = day
	w.load_state(state)
	return _ok("Licht bei den Siebers: Tag %d (%s)." % [day, LightRules.date_text(day)])


func _cmd_letter(args: PackedStringArray, post: bool) -> Dictionary:
	if args.is_empty() or args.size() > (1 if post else 2):
		return _error("Format: post <id>" if post else "Format: letter <id> [leiche]")
	var letters := _system(&"letters") as Letters
	var inv := _lookup.inventory()
	if letters == null or inv == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	var data := Database.letter(id) as LetterData
	if data == null:
		return _error("Unbekannter Brief '%s'." % id)
	var state := letters.save_state()
	var next := int(state.get("next_uid", 1))
	var uid := Letters.UID_FORMAT % next
	var records: Dictionary = state.get("records", {})
	records[uid] = {"id": String(id), "corpse": args[1] if args.size() == 2 else "", "state": "received" if post or data.kind == LetterData.KIND_POST else "found",
			"day": TimeManager.day}
	state["records"] = records
	state["next_uid"] = next + 1
	letters.load_state(state)
	if not inv.add_unique(Letters.ITEM_LETTER, uid):
		return _error("Kein Platz in der Tasche.")
	EventBus.letter_changed.emit(uid, id, &"received" if post else &"found")
	return _ok("%s: %s (%s)" % [uid, data.outside, id])


func _cmd_letters(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: letters")
	var letters := _system(&"letters") as Letters
	if letters == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	for uid: String in letters.uids():
		var data := letters.letter(uid)
		lines.append("%s · %s · %s · %s" % [uid, data.id if data != null else &"?", letters.state(uid), letters.kind_of(uid)])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine Briefe.")


func _cmd_stranger(args: PackedStringArray) -> Dictionary:
	var s := _system(&"stranger") as Stranger
	if s == null:
		return _error(TEXT_NO_WORLD)
	if args.is_empty():
		return _error("Format: stranger <arrive|now|step <k>|gone>")
	match args[0].to_lower():
		"arrive", "now":
			var days := s.visit_days()
			var day := TimeManager.day
			for d: int in days:
				if d >= TimeManager.day:
					day = d
					break
			if args[0].to_lower() == "now":
				TimeManager.set_time(day, STRANGER_MINUTE)
				s.apply_morning(day)
				s.apply_minute(day, STRANGER_MINUTE)
			else:
				TimeManager.set_time(day, 420)
				s.apply_morning(day)
			return _ok("Der Herr mit dem Koffer: Tag %d%s." % [day, " – er wartet am Tor" if s.present(&"graveyard") else ""])
		"step":
			if args.size() != 2:
				return _error("Format: stranger step <k1…k5>")
			var q := _system(&"quests") as Quests
			if q == null:
				return _error(TEXT_NO_WORLD)
			var step := StringName(args[1].to_lower() if args[1].begins_with("k") else "k" + args[1])
			if QuestRules.step(q.quest_data(CASE_QUEST), step) == null:
				return _error("Unbekannter Schritt '%s'." % step)
			_set_step(q, CASE_QUEST, step)
			return _ok("q_case steht bei %s." % step)
		"gone":
			var state := s.save_state()
			state["left"] = true
			s.load_state(state)
			EventBus.stranger_event.emit(&"left", "")
			return _ok("Der Herr mit dem Koffer ist abgereist.")
	return _error("Format: stranger <arrive|now|step <k>|gone>")


func _cmd_large(args: PackedStringArray) -> Dictionary:
	var hill := _system(&"hill_requests") as HillRequests
	if hill == null:
		return _error(TEXT_NO_WORLD)
	if args.is_empty():
		return _error("Format: large <id> · large part <id> <n> · large board")
	if args[0].to_lower() == "board":
		var parts := PackedStringArray()
		for place: StringName in [&"gate", &"village"]:
			var ids := PackedStringArray()
			for id: StringName in hill.large_board(place):
				var done := hill.parts_done(id)
				ids.append("%s (%s)" % [id, "%d/%d" % [HillRules.done_count(done), done.size()] if not done.is_empty() else "angeboten"])
			parts.append("%s: %s" % ["Tor" if place == &"gate" else "Gemeindetafel", ", ".join(ids) if not ids.is_empty() else "–"])
		return _ok(" · ".join(parts))
	if args[0].to_lower() == "part":
		if args.size() != 3 or not args[2].is_valid_int():
			return _error("Format: large part <id> <n>")
		var id := StringName(args[1].to_lower())
		if not hill.set_part(id, int(args[2]) - 1, true):
			return _error("Teil %s von '%s' nicht möglich (angenommen?)." % [args[2], id])
		return _ok("%s: %s" % [id, hill.large_line(id) if hill.large_line(id) != "" else "fertig"])
	if args.size() != 1:
		return _error("Format: large <id>")
	var large_id := StringName(args[0].to_lower())
	if hill.large_data(large_id) == null:
		return _error("Unbekannte große Bitte '%s'." % large_id)
	if not hill.pin_large(large_id):
		return _error("'%s' lässt sich nicht anheften (hängt schon, oder der Platz ist belegt)." % large_id)
	return _ok("Angeheftet: %s (%s)." % [large_id, hill.large_data(large_id).place])


func _cmd_goal9(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: goal9")
	var q := _system(&"quests") as Quests
	if q == null:
		return _error(TEXT_NO_WORLD)
	var g := q.goal_progress()
	return _ok("Wer weiß, wann? Hauptkette %s (%s) · Briefe Schritt 4 %s, entschieden %d/%d · Große Bitten %d/%d%s" % [
			_yes(bool(g.main)), str(g.get("main_ending", "")), _yes(bool(g.letters_step)), int(g.letters_decided),
			int(g.get("letters_goal", 5)), int(g.large), int(g.get("large_goal", 2)),
			" · erreicht" if GameState.flag_on(&"who_knows_when_complete") else ""])


func _cmd_vis9(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: vis9")
	var p := _lookup.player() as Node3D
	if p == null:
		return _error(TEXT_NO_WORLD)
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return _error("Keine Kamera.")
	var space := cam.get_world_3d().direct_space_state
	var lines := PackedStringArray()
	var free := 0
	for node: Node in p.get_tree().root.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		var is_npc := node is Npc and (node as Npc).npc_id in VIS_IDS and (node as Npc).is_present()
		if not is_npc and not (node is KnockDoor or node is WatchSpot):
			continue
		if not n3.is_visible_in_tree():
			continue
		var to := n3.global_position + Vector3(0.0, VIS_HEIGHT, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, to))
		var collider := hit.get("collider") as Node if not hit.is_empty() else null
		if collider == null or collider == n3 or n3.is_ancestor_of(collider):
			free += 1
		else:
			lines.append("verdeckt: %s (durch %s)" % [n3.name, collider.name])
	lines.insert(0, "frei: %d" % free)
	return _ok("\n".join(lines))


func _system(group: StringName) -> Node:
	return _lookup.group_node(group)


static func _yes(on: bool) -> String:
	return "ja" if on else "nein"


static func _ok(text: String) -> Dictionary:
	return {"ok": true, "text": text}


static func _error(text: String) -> Dictionary:
	return {"ok": false, "text": text}
