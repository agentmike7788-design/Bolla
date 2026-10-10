class_name DebugCommandsPhase8
extends RefCounted
## Phase-8 commands of the debug console (docs/PHASE8_DESIGN.md §6), dispatched by DebugCommands.run():
## p8 open · moods · mood · chatter · react · visits · visit · goodwill · wish · wishes · tip · flowers · candle ·
## mortsafe · disturb · apprentice <hire|level|plan|morale> · box coins · step · favor · fest · lights all · peddler ·
## alms · robber · nightpath · observe · underlined · d2 · vis8 · goal8. Every command goes through the system
## (found by its group) – its public API where there is one, else its own save_state()/load_state() round, so the
## system's rules and tolerance apply; without it: "Keine Spielwelt geladen.". Returns {ok, text}. Shortcuts for
## testing only.

const COMMANDS: PackedStringArray = ["p8", "moods", "mood", "chatter", "react", "visits", "visit", "goodwill", "wish", "wishes",
		"tip", "flowers", "candle", "mortsafe", "disturb", "apprentice", "box", "step", "favor", "fest", "lights", "peddler", "alms",
		"robber", "nightpath", "observe", "underlined", "d2", "vis8", "goal8"]
const HELP: PackedStringArray = [
	"p8 open – Phase 8 sofort öffnen · moods – Launen heute · mood <npc> <plain|cheerful|low|cross> · react <ereignis>",
	"chatter <id> – Begegnung jetzt abspielen (nur Blasen) · visits – Besuchsplan heute · visit <kin|npc> [grab] – Besuch jetzt",
	"goodwill <kin> <0-10> · wish <grab> <tend|flowers|candle|line|vase> · wishes · tip <grab> <n> – Münzen auf den Stein",
	"flowers <grab> [fresh|wilted|wreath] · candle <grab|all> · mortsafe <grab> – Gitter auf/ab · disturb <grab>",
	"apprentice hire · apprentice level <rake|weed|water|candle> <0-2> · apprentice plan · apprentice morale <0-5> · box coins <n>",
	"step <npc> <0-3> – Geschichtsschritte · favor <npc> – Abklingzeit zurücksetzen · fest <kathrein|lights> [today|now]",
	"lights all – Kerzen auf alle belegten Gräber · peddler – Hanne heute · alms <n> · observe <hinweis> · underlined <priest|surgeon|washer>",
	"robber <tonight|now|second|gone> · nightpath <ott|kehr> [now] · d2 – Ott morgen fällig · vis8 – Sichtprüfung · goal8 – Kapitel",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const MOODS: Array[StringName] = [&"plain", &"cheerful", &"low", &"cross"]
const WISH_TEMPLATES: Dictionary[StringName, StringName] = {&"tend": &"w_tend", &"flowers": &"w_flowers", &"candle": &"w_candle",
		&"line": &"w_line_1", &"vase": &"w_vase"}
const FESTS: Dictionary[String, StringName] = {"kathrein": &"fest_kathrein", "lights": &"fest_lights"}
const PATHS: Dictionary[String, StringName] = {"ott": &"np_ott", "kehr": &"np_kehr"}
const UNDERLINED: Array[StringName] = [&"priest", &"surgeon", &"washer"]
const VIS_HEIGHT := 1.4
const VIS_IDS: Array[StringName] = [&"apprentice", &"beggar", &"peddler", &"robber", &"kin_kehr", &"kin_brandt", &"kin_ott", &"kin_sieber"]

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"p8":
			return _cmd_p8(args)
		"moods":
			return _cmd_moods(args)
		"mood":
			return _cmd_mood(args)
		"chatter":
			return _cmd_chatter(args)
		"react":
			return _cmd_react(args)
		"visits":
			return _cmd_visits(args)
		"visit":
			return _cmd_visit(args)
		"goodwill":
			return _cmd_goodwill(args)
		"wish":
			return _cmd_wish(args)
		"wishes":
			return _cmd_wishes(args)
		"tip":
			return _cmd_tip(args)
		"flowers":
			return _cmd_flowers(args)
		"candle":
			return _cmd_candle(args)
		"mortsafe":
			return _cmd_mortsafe(args)
		"disturb":
			return _cmd_disturb(args)
		"apprentice":
			return _cmd_apprentice(args)
		"box":
			return _cmd_box(args)
		"step":
			return _cmd_step(args)
		"favor":
			return _cmd_favor(args)
		"fest":
			return _cmd_fest(args)
		"lights":
			return _cmd_lights(args)
		"peddler":
			return _cmd_peddler(args)
		"alms":
			return _cmd_alms(args)
		"robber":
			return _cmd_robber(args)
		"nightpath":
			return _cmd_nightpath(args)
		"observe":
			return _cmd_observe(args)
		"underlined":
			return _cmd_underlined(args)
		"d2":
			return _cmd_d2(args)
		"vis8":
			return _cmd_vis8(args)
		"goal8":
			return _cmd_goal8(args)
	return _error("?")


# --- village life ------------------------------------------------------------------------------------

func _cmd_p8(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "open":
		return _error("Format: p8 open")
	var life := _system(&"npc_life") as NpcLife
	if life == null:
		return _error(TEXT_NO_WORLD)
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"name_in_village_complete", true)
	life.open()
	return _ok("Phase 8 ist offen (p8_open_day %d)." % life.open_day())


func _cmd_moods(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: moods")
	var life := _system(&"npc_life") as NpcLife
	if life == null:
		return _error(TEXT_NO_WORLD)
	var parts := PackedStringArray()
	for id: StringName in Phase7Texts.VILLAGER_ORDER:
		parts.append("%s %s" % [Phase7Texts.short_name(id), Phase8Texts.mood_word(life.mood(id))])
	return _ok("Tag %d: %s" % [TimeManager.day, Phase8Texts.SEP.join(parts)])


func _cmd_mood(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not StringName(args[1].to_lower()) in MOODS:
		return _error("Format: mood <npc> <plain|cheerful|low|cross>")
	var life := _system(&"npc_life") as NpcLife
	if life == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	life.set_mood(id, StringName(args[1].to_lower()))
	return _ok("%s: %s" % [Phase8Texts.person_name(id), Phase8Texts.mood_word(life.mood(id))])


## Plays the chatter's lines as bubbles now (one every chatter_line_seconds; display only, no flag).
func _cmd_chatter(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: chatter <id>")
	var data := Database.chatter(StringName(args[0].to_lower())) as ChatterData
	if data == null:
		return _error("Keine Begegnung '%s'." % args[0])
	var tree := _tree()
	if tree == null:
		return _error(TEXT_NO_WORLD)
	var cfg := Database.config(&"npc_life_config") as NpcLifeConfig
	var seconds := cfg.chatter_line_seconds if cfg != null else 3.5
	for i: int in data.lines.size():
		var npc: StringName = data.npcs[i % 2] if data.npcs.size() >= 2 else &""
		var line := data.lines[i]
		if i == 0:
			EventBus.chatter_line.emit(data.id, npc, line)
		else:
			tree.create_timer(seconds * i).timeout.connect(func() -> void: EventBus.chatter_line.emit(data.id, npc, line))
	return _ok("Begegnung %s: %d Zeilen." % [data.id, data.lines.size()])


func _cmd_react(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: react <ereignis>")
	var life := _system(&"npc_life") as NpcLife
	if life == null:
		return _error(TEXT_NO_WORLD)
	life.note_event(StringName(args[0].to_lower()))
	return _ok("Ereignis %s vermerkt (Tag %d)." % [args[0].to_lower(), TimeManager.day])


# --- visitors & wishes ---------------------------------------------------------------------------------

func _cmd_visits(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: visits")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	for e: Dictionary in v.save_state().get("plan", []):
		var phase := v.phase_of(e)
		lines.append("%s %s %s → %s (%s)" % [str(e.get("visit_id", "")), UIKit.clock(int(e.get("start", e.get("slot", 0)))),
				Phase8Texts.person_name(StringName(str(e.get("kin_id", "")))), ", ".join(PackedStringArray(e.get("graves", []))),
				phase if phase != &"" else "später"])
	return _ok("\n".join(lines) if not lines.is_empty() else "Heute kommt niemand.")


## A visit now (from road_end, the real way): a plan entry of today starting this minute, waiting for a talk.
func _cmd_visit(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2:
		return _error("Format: visit <kin|npc> [grab]")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var kin_id := _kin_id(args[0].to_lower())
	if Database.kin(kin_id) == null:
		return _error("Keine Angehörigen '%s'." % args[0])
	var graves := PackedStringArray([args[1]]) if args.size() == 2 else v.graves_of(kin_id)
	if graves.is_empty():
		return _error("%s hat hier kein Grab." % Phase8Texts.person_name(kin_id))
	var state := v.save_state()
	var plan: Array = state.get("plan", []) if int(state.get("plan_day", -1)) == TimeManager.day else []
	var id := "v_%d_d%d" % [TimeManager.day, plan.size() + 1]
	plan.append({"visit_id": id, "kin_id": String(kin_id), "graves": Array(graves), "slot": TimeManager.minute_of_day,
			"start": TimeManager.minute_of_day, "travel": VisitRules.ROAD_MINUTES + VisitRules.DEFAULT_ROUTE_MINUTES, "day": TimeManager.day,
			"flowers": true, "laid": 0, "viewed": 0, "waits": true, "tip": 0, "ended": false, "noise": false, "offered": ""})
	state["plan"] = plan
	state["plan_day"] = TimeManager.day
	state["plan_open"] = true
	v.load_state(state)
	return _ok("%s kommt jetzt herauf (%s)." % [Phase8Texts.person_name(kin_id), ", ".join(graves)])


func _cmd_goodwill(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[1].is_valid_int():
		return _error("Format: goodwill <kin> <0-10>")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var kin_id := _kin_id(args[0].to_lower())
	v.add_goodwill(kin_id, clampi(args[1].to_int(), 0, 10) - v.goodwill(kin_id))
	return _ok("%s: %s (%d)" % [Phase8Texts.household(kin_id), Phase8Texts.goodwill_word(v.goodwill(kin_id)), v.goodwill(kin_id)])


func _cmd_wish(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not WISH_TEMPLATES.has(StringName(args[1].to_lower())):
		return _error("Format: wish <grab> <tend|flowers|candle|line|vase>")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var grave := args[0]
	var kind := StringName(args[1].to_lower())
	var kin := v.kin_for_grave(grave)
	var state := v.save_state()
	var wishes: Array = state.get("wishes", [])
	var next := int(state.get("next_wish", 1))
	var w := {"wish_id": "w_%04d" % next, "kind": String(kind), "grave_id": grave, "kin_id": String(kin if kin != &"" else &"kin_kehr"),
			"state": "accepted", "day": TimeManager.day, "candle_seen": false, "template": String(WISH_TEMPLATES[kind])}
	var data := Database.wish(WISH_TEMPLATES[kind]) as WishData
	if kind == &"line" and data != null:
		w["line"] = data.line_text
	wishes.append(w)
	state["wishes"] = wishes
	state["next_wish"] = next + 1
	v.load_state(state)
	EventBus.wish_changed.emit(str(w.wish_id), &"accepted")
	return _ok("Wunsch %s: %s an %s." % [w.wish_id, Phase8Texts.wish_kind_label(kind), grave])


func _cmd_wishes(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: wishes")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	for w: Dictionary in v.open_wishes():
		lines.append("%s %s %s (%s, %s)" % [str(w.wish_id), Phase8Texts.wish_kind_label(StringName(str(w.kind))), str(w.grave_id),
				Phase8Texts.household(StringName(str(w.kin_id))), str(w.state)])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine offenen Wünsche.")


func _cmd_tip(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[1].is_valid_int():
		return _error("Format: tip <grab> <n>")
	var v := _system(&"visitors") as Visitors
	if v == null:
		return _error(TEXT_NO_WORLD)
	var state := v.save_state()
	var stones: Dictionary = state.get("tips_on_stone", {})
	var kin := v.kin_for_grave(args[0])
	stones[args[0]] = [maxi(args[1].to_int(), 0), String(kin if kin != &"" else &"kin_kehr")]
	state["tips_on_stone"] = stones
	v.load_state(state)
	EventBus.grave_care_changed.emit(args[0], Visitors.KIND_TIP, true)
	return _ok("%d Münzen auf dem Stein von %s." % [maxi(args[1].to_int(), 0), args[0]])


# --- grave care ----------------------------------------------------------------------------------------

func _cmd_flowers(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2 or (args.size() == 2 and not args[1].to_lower() in ["fresh", "wilted", "wreath"]):
		return _error("Format: flowers <grab> [fresh|wilted|wreath]")
	var gc := _system(&"grave_care") as GraveCare
	if gc == null:
		return _error(TEXT_NO_WORLD)
	var kind := args[1].to_lower() if args.size() == 2 else "fresh"
	var cfg := gc.get_config()
	var now := TimeManager.total_minutes()
	var state := gc.save_state()
	var flowers: Dictionary = state.get("flowers", {})
	var at := now - cfg.flower_fresh_minutes if kind == "wilted" else now
	flowers[args[0]] = {"planted": at, "watered": at, "wreath": kind == "wreath"}
	state["flowers"] = flowers
	gc.load_state(state)
	EventBus.grave_care_changed.emit(args[0], GraveCare.KIND_FLOWERS, true)
	return _ok("Grabblumen an %s: %s" % [args[0], gc.flowers_state(args[0])])


func _cmd_candle(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: candle <grab|all>")
	var gc := _system(&"grave_care") as GraveCare
	if gc == null:
		return _error(TEXT_NO_WORLD)
	var graves := _occupied() if args[0].to_lower() == "all" else PackedStringArray([args[0]])
	var n := 0
	for g: String in graves:
		if gc.light_free(g):
			n += 1
	return _ok("%d Grabkerzen angezündet." % n)


func _cmd_mortsafe(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: mortsafe <grab>")
	var gc := _system(&"grave_care") as GraveCare
	var inv := _lookup.inventory()
	if gc == null or inv == null:
		return _error(TEXT_NO_WORLD)
	var on := not gc.has_mortsafe(args[0])
	if on and not inv.has(gc.get_config().mortsafe_item):
		inv.add_item(gc.get_config().mortsafe_item, 1)
	var state := gc.save_state()
	var ms: Dictionary = state.get("mortsafes", {})
	if on:
		ms[args[0]] = TimeManager.total_minutes()
		inv.remove_item(gc.get_config().mortsafe_item, 1)
	else:
		ms.erase(args[0])
		inv.add_item(gc.get_config().mortsafe_item, 1)
	state["mortsafes"] = ms
	gc.load_state(state)
	EventBus.grave_care_changed.emit(args[0], GraveCare.KIND_MORTSAFE, on)
	return _ok("Grabgitter an %s: %s" % [args[0], "auf" if on else "ab"])


func _cmd_disturb(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: disturb <grab>")
	var gc := _system(&"grave_care") as GraveCare
	if gc == null:
		return _error(TEXT_NO_WORLD)
	gc.set_disturbed(args[0])
	return _ok("%s ist aufgewühlt: %s" % [args[0], _yes(gc.is_disturbed(args[0]))])


# --- the apprentice ---------------------------------------------------------------------------------------

func _cmd_apprentice(args: PackedStringArray) -> Dictionary:
	var a := _system(&"apprentice") as Apprentice
	if a == null:
		return _error(TEXT_NO_WORLD)
	var sub := args[0].to_lower() if not args.is_empty() else ""
	match sub:
		"hire":
			a.hire()
			return _ok("Jakob ist eingestellt (ab morgen).")
		"level":
			if args.size() != 3 or not StringName(args[1].to_lower()) in Apprentice.TASKS or not args[2].is_valid_int():
				return _error("Format: apprentice level <rake|weed|water|candle> <0-2>")
			var state := a.save_state()
			var levels: Dictionary = state.get("levels", {})
			levels[args[1].to_lower()] = clampi(args[2].to_int(), 0, 2)
			state["levels"] = levels
			a.load_state(state)
			return _ok("%s: %s" % [Phase8Texts.task_label(StringName(args[1].to_lower())), Phase8Texts.level_word(a.level(StringName(args[1].to_lower())))])
		"plan":
			var lines := PackedStringArray()
			for e: Dictionary in a.today_plan():
				lines.append("%s–%s %s %s" % [UIKit.clock(int(e.get("start", 0))), UIKit.clock(int(e.get("end", 0))),
						Phase8Texts.task_label(StringName(str(e.get("task", "")))), str(e.get("grave_id", e.get("spot_id", "")))])
			return _ok("\n".join(lines) if not lines.is_empty() else "Heute kein Plan (Liste: %d Zeilen)." % a.board_lines().size())
		"morale":
			if args.size() != 2 or not args[1].is_valid_int():
				return _error("Format: apprentice morale <0-5>")
			var state := a.save_state()
			state["morale"] = clampi(args[1].to_int(), 0, Apprentice.MORALE_MAX)
			a.load_state(state)
			return _ok(Phase8Texts.morale_text(a.morale()))
	return _error("Format: apprentice <hire|level|plan|morale> …")


func _cmd_box(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or args[0].to_lower() != "coins" or not args[1].is_valid_int():
		return _error("Format: box coins <n>")
	var box := _system(&"apprentice_box") as ApprenticeBox
	if box == null:
		return _error(TEXT_NO_WORLD)
	box.coins = maxi(args[1].to_int(), 0)
	return _ok("Lohndose: %d Münzen." % box.coins)


# --- friendship & festivals ------------------------------------------------------------------------------

func _cmd_step(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[1].is_valid_int():
		return _error("Format: step <npc> <0-3>")
	var f := _system(&"friendship") as Friendship
	if f == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	var n := clampi(args[1].to_int(), 0, Friendship.STEPS)
	var state := f.save_state()
	var steps: Dictionary = state.get("steps", {})
	steps[String(id)] = n
	state["steps"] = steps
	f.load_state(state)
	for i: int in range(1, Friendship.STEPS + 1):
		var flag := StringName("friend_%s_%d" % [id, i])
		if i <= n:
			GameState.set_flag(flag, true)
	return _ok("%s: %s" % [Phase7Texts.short_name(id), Phase8Texts.story_points(f.step_done(id), false)])


func _cmd_favor(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: favor <npc>")
	var f := _system(&"friendship") as Friendship
	if f == null:
		return _error(TEXT_NO_WORLD)
	var id := String(args[0].to_lower())
	var state := f.save_state()
	for key: String in ["favor_day", "locked_until"]:
		var d: Dictionary = state.get(key, {})
		d.erase(id)
		state[key] = d
	f.load_state(state)
	var reason := f.favor_block_reason(StringName(id))
	return _ok("Gefallen %s: %s" % [Phase7Texts.short_name(StringName(id)), reason if reason != "" else Phase8Texts.FAVOR_READY])


func _cmd_fest(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2 or not FESTS.has(args[0].to_lower()) or (args.size() == 2 and not args[1].to_lower() in ["today", "now"]):
		return _error("Format: fest <kathrein|lights> [today|now]")
	var fest := _system(&"festivals") as Festivals
	if fest == null:
		return _error(TEXT_NO_WORLD)
	var id: StringName = FESTS[args[0].to_lower()]
	var data := fest.festival(id)
	var state := fest.save_state()
	var days: Dictionary = state.get("days", {})
	days[String(id)] = TimeManager.day
	state["days"] = days
	var states: Dictionary = state.get("state", {})
	states.erase(String(id))
	state["state"] = states
	fest.load_state(state)
	if data != null:
		GameState.set_flag(data.day_flag, TimeManager.day)
	if args.size() == 2 and args[1].to_lower() == "now" and data != null and TimeManager.minute_of_day < data.window.x:
		TimeManager.set_time(TimeManager.day, data.window.x)
	return _ok("%s heute (Tag %d)%s." % [Phase8Texts.fest_name(id), TimeManager.day, ", jetzt %s" % TimeManager.format_clock() if args.size() == 2 and args[1].to_lower() == "now" else ""])


func _cmd_lights(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "all":
		return _error("Format: lights all")
	return _cmd_candle(PackedStringArray(["all"]))


# --- wanderers & the night ---------------------------------------------------------------------------------

func _cmd_peddler(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: peddler")
	var w := _system(&"wanderers") as Wanderers
	if w == null:
		return _error(TEXT_NO_WORLD)
	var data := (w.wanderer_data.get(Wanderers.PEDDLER, Database.wanderer(Wanderers.PEDDLER)) as WandererData)
	if data == null:
		return _error("Keine Daten für Hanne.")
	var copy := data.duplicate() as WandererData
	copy.day_rest = posmod(TimeManager.day, maxi(copy.every_days, 1))
	w.wanderer_data[Wanderers.PEDDLER] = copy
	return _ok("Hanne kommt heute (Tag %d)." % TimeManager.day)


func _cmd_alms(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int():
		return _error("Format: alms <n>")
	var w := _system(&"wanderers") as Wanderers
	if w == null:
		return _error(TEXT_NO_WORLD)
	var state := w.save_state()
	state["alms"] = maxi(args[0].to_int(), 0)
	w.load_state(state)
	return _ok("Almosen gegeben: %d" % w.alms_count())


func _cmd_robber(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["tonight", "now", "second", "gone"]:
		return _error("Format: robber <tonight|now|second|gone>")
	var r := _system(&"night_robber") as NightRobber
	if r == null:
		return _error(TEXT_NO_WORLD)
	var state := r.save_state()
	match args[0].to_lower():
		"gone":
			state["fate"] = "caught_watch"
			state["target"] = ""
			r.load_state(state)
			return _ok("Der Nachtgräber kommt nicht mehr.")
		"second":
			state["encounters"] = maxi(1, int(state.get("encounters", 0)))
	var grave := _freshest()
	if grave == "":
		return _error("Kein belegtes Grab.")
	state["target_day"] = TimeManager.day
	state["target"] = grave
	state["state"] = ""
	r.load_state(state)
	if args[0].to_lower() == "now":
		var cfg := r.config if r.config != null else RobberConfig.new()
		TimeManager.set_time(TimeManager.day + 1, cfg.arrive_minute)
	return _ok("Nachtgräber heute Nacht an %s (Begegnungen %d)." % [grave, r.encounters()])


func _cmd_nightpath(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2 or not PATHS.has(args[0].to_lower()):
		return _error("Format: nightpath <ott|kehr> [now]")
	var data := Database.night_path(PATHS[args[0].to_lower()]) as NightPathData
	if data == null or data.visits.is_empty():
		return _error("Kein Nachtweg '%s'." % args[0])
	var first: NightVisitData = data.visits[0]
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", TimeManager.day - first.night_offset)
	if args.size() == 2 and args[1].to_lower() == "now":
		var day := TimeManager.day + (1 if first.enter_minute < 360 else 0)
		TimeManager.set_time(day, maxi(first.enter_minute - 10, 0))
	return _ok("Nachtweg %s heute Nacht (%s, %s)." % [data.id, Phase8Texts.house_label(data.house), UIKit.clock(first.enter_minute)])


func _cmd_observe(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: observe <hinweis>")
	var j := _system(&"journal")
	if j == null or not j.has_method(&"add_clue"):
		return _error(TEXT_NO_WORLD)
	var ok := bool(j.call(&"add_clue", StringName(args[0].to_lower())))
	return _ok("Hinweis %s: %s" % [args[0].to_lower(), "neu" if ok else "schon da / unbekannt"])


func _cmd_underlined(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not StringName(args[0].to_lower()) in UNDERLINED:
		return _error("Format: underlined <priest|surgeon|washer>")
	var cfg := Database.config(&"story_config") as StoryConfig
	if cfg == null:
		return _error("Keine story_config.")
	cfg.underlined = StringName(args[0].to_lower())
	return _ok("Unterstrichen (nur diese Sitzung): %s" % args[0].to_lower())


func _cmd_d2(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: d2")
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"ott_dead", TimeManager.day)
	return _ok("Gerhard Ott ist ab morgen fällig (ott_dead = Tag %d)." % TimeManager.day)


func _cmd_vis8(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: vis8")
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
		if not is_npc and not (node is ApprenticeBoard or node is ApprenticeBox or node is RainBarrel or node is WatchSpot or node is TipStone):
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


func _cmd_goal8(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: goal8")
	var life := _system(&"npc_life") as NpcLife
	if life == null:
		return _error(TEXT_NO_WORLD)
	var g := life.goal_progress()
	return _ok("Wer heraufkommt %d/%d · Jakob %s, Stufen %d/%d · Wünsche %d/%d (%d/%d Angehörige) · Schritte %d/%d, ganz %d/%d · „Der unterstrichene Name“ %s%s" % [
			int(g.done), int(g.total), _yes(bool(g.hired)), int(g.levels), int(g.levels_goal), int(g.wishes), int(g.wishes_goal),
			int(g.kin), int(g.kin_goal), int(g.steps), int(g.steps_goal), int(g.full), int(g.full_goal), _yes(bool(g.insight)),
			" · erreicht" if GameState.flag_on(&"who_comes_up_complete") else ""])


# --- helpers ---------------------------------------------------------------------------------------

func _system(group: StringName) -> Node:
	return _lookup.group_node(group)


func _tree() -> SceneTree:
	var p := _lookup.player()
	if p != null and p.is_inside_tree():
		return p.get_tree()
	var any := _lookup.group_node(&"npc_life")
	return any.get_tree() if any != null and any.is_inside_tree() else null


## kin_kehr / kehr / smith → the kin id.
static func _kin_id(raw: String) -> StringName:
	if Database.kin(StringName(raw)) != null:
		return StringName(raw)
	if Database.kin(StringName("kin_" + raw)) != null:
		return StringName("kin_" + raw)
	return StringName(raw)


func _occupied() -> PackedStringArray:
	var out := PackedStringArray()
	var g := _system(&"graveyard") as Graveyard
	if g == null:
		return out
	for r: GraveRecord in g.graves():
		if r.state == GraveRecord.State.FILLED or r.state == GraveRecord.State.MARKED:
			out.append(r.id)
	return out


## The most recently completed occupied grave ("" = none).
func _freshest() -> String:
	var g := _system(&"graveyard") as Graveyard
	if g == null:
		return ""
	var best := ""
	var day := -1
	for r: GraveRecord in g.graves():
		if (r.state == GraveRecord.State.FILLED or r.state == GraveRecord.State.MARKED) and r.completed_day > day:
			day = r.completed_day
			best = r.id
	return best


static func _yes(on: bool) -> String:
	return "ja" if on else "nein"


static func _ok(text: String) -> Dictionary:
	return DebugCommands.result(true, text)


static func _error(text: String) -> Dictionary:
	return DebugCommands.result(false, text)
