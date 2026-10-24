class_name Phase9Bot
extends Phase8Bot
## QA playthrough bot of Phase 9 (docs/PHASE9_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5, §2.8, W3). Extends Phase8Bot
## by the Phase-9 day once p9_open is set (the Phase-8 day – corpses, visitors, Jakob, the village trip through the real
## portals and DialogueRunner, the evenings – stays as it is):
## - the main chain „Wer weiß, wann?" through the real entities and dialogues: the hut's Desk (Kladde, register, the
##   nameless letter, the answer), the GravePlots („Datum vergleichen"), the witnesses' dialogues (witness:<entry> –
##   Osric on the hill, Rosine, Theres, Liesel in the village, Veit at the gate / in the village, Gesa at her father's
##   grave), Johann's dialogue at Grete's grave or on his bench (mark_seen, the H5 / H6 choices), the confidant's dialogue
##   (H5), the KnockDoor of the Siebers at night (the nameless letter), the journal link i_light_before (3 of 5);
## - letters: the pocket letters of the deliveries and Osric's post for the dead by the strategy – handed over in the
##   dialogue (letter_deliver / letter_read_aloud), posted with Osric (letter_post:carter), read at the grave (GravePlot
##   „Brief am Grab vorlesen"), burned in the stove when the letter asks for it, opened and read on the letter card
##   (letters9: Letters.decide(uid, read) – what the card does), answered at the desk; Gesa's and Fenner's errands;
## - large requests at the gate: the sheet read in the morning, the parts worked (craft at the workbench, tend, decor,
##   clear, gather, the evening visit at its spot, ghosts at night, the hand-over in Osric's dialogue large_turn_in);
## - Brenneisen at the gate: his dialogue (answers, the offers panel – Stranger.sell as the panel does –, the bribe, the
##   case, K5), the soil at a fresh grave for the trader;
## - the fourth row (Fenner's dialogue set_flag:linden_row4_granted, the stump and the bramble cleared).
## W3 QA-Fix (QA9-01 … QA9-04): where a place offers a choice (&"action_choice": the stove, the forge, the open grave
## with the sender's letter, a grave with Phase-9 work and care) the bot answers it like the panel's button –
## target.request_action(id) on EventBus.ui_panel_requested (as request_marker for the marker choice): at the open grave
## „Bestatten" unless the letter shall go into the grave, at a grave the action it came for (else the order of the
## one-press grave: coins / closing, the date, the care, the letters), at the stove the letter it chose.
## Coin ledger: Phase 8 + income "hill_request" / "large_request" (Bitte: …), "errand" (Botenlohn), "stranger_sale",
## "stranger_answer"; spending reason post (Postgeld).

const MAIN := &"q_who_knows"
const LETTERS_Q := &"q_letters"
const CASE_Q := &"q_case"
const ROW4 := &"linden_row4"
const ROW4_PLOTS: PackedStringArray = ["l_13", "l_14", "l_15", "l_16"]
## The Phase-9 goods stay in the pack.
const P9_KEEP: Array[StringName] = [&"letter", &"letter_reply", &"nameless_letter", &"stranger_case", &"case_card", &"soil_pouch",
		&"lorenz_ledger_2", &"ink"]
## Large-request part kinds the bot can work.
## Not „gather": in the Phase-8 end states every wild section is cleared – ten wood „schlagen oder roden" has no source
## but the daily pile (HillBot plays new games, where it has).
const LARGE_HANDLED: Array[StringName] = [&"craft", &"tend", &"decor", &"clear", &"visit", &"ghost", &"ghosts",
		&"deliver", &"exam", &"marker"]
const LARGE_DECOR_ORDER: Array[StringName] = [&"decor_grave_vase", &"decor_flowerbed", &"decor_lantern", &"decor_bench_wood"]
const LARGE_KEEP_WOOD := 1
const OSRIC_EVENING9 := 1110
## The night of the nameless letter: at the Siebers' door after dark (TimeManager.is_night).
const DOOR_NIGHT := 21 * 60 + 10

## Phase-9 flags on top of the Phase-8 ones:
## "p9": plays Phase 9 · "chain": H1–H4 · "confide": the H5 choice (confide_washer / confide_priest / confide_surgeon /
## confide_none; "" = no H5) · "ending": the H6 choice (away / stay / public; "" = nothing until the deadline) ·
## "letters": deliver | grave (read at the grave where it can be) | read (open and read every letter first) | "" ·
## "answer": answers at the desk · "errands": Gesa's / Fenner's errands · "large": large requests ·
## "stranger": the K5 ending wanted ("" = Brenneisen is ignored) · "answer_kind": his questions (frank / evade / refuse) ·
## "sell": everything he buys · "bribe": "yes" / "no" · "save_p9": reloads at the departure, with Brenneisen at the
## gate and mid large request.
const P9_FLAGS := {"p9": true, "chain": true, "confide": "confide_washer", "ending": "away", "letters": "deliver",
		"answer": true, "errands": true, "large": true, "stranger": "fenner", "answer_kind": "refuse", "sell": false,
		"bribe": "no", "save_p9": false,
		# §2.8 rechnet ohne die Phase-8-Gewohnheiten des Bots: kein neues Grabgitter für jedes frische Grab (Lambert ist
		# gemeldet / fort), keine täglichen Honigkuchen, keine Spende an Fenners Armenkasse bei jedem Gespräch.
		"mortsafe": false, "gifts": false}

static var P9_STRATEGIES := {
	&"kindly9": _with9({}, {}, {}),
	&"stay9": _with9({}, {}, {"confide": "confide_priest", "ending": "stay", "letters": "grave"}),
	&"public9": _with9({}, {}, {"confide": "confide_none", "ending": "public"}),
	&"silent9": _with9({}, {}, {"confide": "", "ending": ""}),
	&"letters9": _with9({}, {}, {"letters": "read"}),
	&"trader9": _with9({}, {"anatomy": true, "collection": true, "lectures": false, "donations": false},
			{"stranger": "deal", "answer_kind": "frank", "sell": true, "bribe": "yes"},
			{"stories": {&"mayor": 3, &"innkeeper": 1, &"smith": 1, &"grocer": 2}, "mortsafe": false}),
	&"lazy9": _with9({}, {}, {"chain": false, "confide": "", "ending": "", "letters": "", "answer": false, "errands": false,
			"large": false, "stranger": ""}, {"apprentice": false, "wishes": false, "stories": {}, "mortsafe": false, "lights": false,
			"kathrein": false, "observe": []}),
	&"founder9": _with9({}, {}, {}),
	&"save_load9": _with9({"save_load": true}, {}, {"save_p9": true}),
}

var quests: Quests
var who: WhoKnows
var letters: Letters
var stranger: Stranger
var hill: HillRequests

## Phase-9 progress.
var open9_day: int = -1
var chapter9_day: int = -1
var start9_coins: int = -1
var start9_piety: int = 0
var start9_rel: Dictionary = {}
var lowest_morning_p9: int = 1 << 30
var spent_p9: int = 0
var trace9: PackedStringArray = []
## Findings the bot ran into (workarounds, stand-ins) – reported, not asserted.
var notes9: PackedStringArray = []
## Calls made where the contract's entity / dialogue was not reachable (kind → count).
var standins: Dictionary = {}
var letter_log: Array[Dictionary] = []
var large_log: PackedStringArray = []
var large_done_ids: Array[StringName] = []
var stranger_log: PackedStringArray = []
var ending_day: int = -1
var depart_seen: bool = false
var d3_grave: String = ""
var saved9: PackedStringArray = []
var _dlg_now: DialogueData = null
var _watching9: bool = false
var _osric_day: int = -1
var _stranger_day: int = -1
var _door_day: int = -1
var _veit_day: int = -1
var _johann_day: int = -1
var _listened9: int = -1
## The option the next &"action_choice" shall take (&"" = the default of _pick_choice).
var _want_choice: StringName = &""
## Choices answered (option id → count).
var choices9: Dictionary = {}
var _knock_day: int = -1
## Purse + wage tin when the bot started (the v7 end states hold Jakob's tin already).
var start_total: int = -1
## Relationship changes by the chain (witnesses, the endings): {day, npc, delta, reason}.
var ending_rel: Array[Dictionary] = []
var _speaker_now: StringName = &""
var _speaker_node: Node = null


static func _with9(p4: Dictionary, p7: Dictionary, p9: Dictionary, p8: Dictionary = {}) -> Dictionary:
	var out := _with8(p4, {}, {"optional": [&"crypt", &"chapel"]}, p7, p8)
	out.merge(P9_FLAGS.duplicate(true), true)
	out.merge(p9, true)
	return out


func _init(p_strategy: StringName, p_tree: SceneTree) -> void:
	super(p_strategy, p_tree)
	flags = flags.duplicate(true)
	income.merge({"hill_request": 0, "large_request": 0, "errand": 0, "stranger_sale": 0, "stranger_answer": 0})


func strategies() -> Dictionary:
	return P9_STRATEGIES


func bind() -> void:
	super.bind()
	quests = world.get_node("Systems/Quests") as Quests
	who = world.get_node("Systems/WhoKnows") as WhoKnows
	letters = world.get_node("Systems/Letters") as Letters
	stranger = world.get_node("Systems/Stranger") as Stranger
	hill = world.get_node("Systems/HillRequests") as HillRequests


func watch() -> void:
	super.watch()
	EventBus.quest_changed.connect(_on_quest)
	EventBus.letter_changed.connect(_on_letter)
	EventBus.hill_request_changed.connect(_on_hill9)
	EventBus.relationship_changed.connect(_on_rel9)
	EventBus.ui_panel_requested.connect(_on_choice_panel)
	_watching9 = true


func unwatch() -> void:
	super.unwatch()
	if _watching9:
		EventBus.quest_changed.disconnect(_on_quest)
		EventBus.letter_changed.disconnect(_on_letter)
		EventBus.hill_request_changed.disconnect(_on_hill9)
		EventBus.relationship_changed.disconnect(_on_rel9)
		EventBus.ui_panel_requested.disconnect(_on_choice_panel)
		_watching9 = false


func p9_open() -> bool:
	return flags.p9 and GameState.flag_on(Quests.OPEN_FLAG)


# --- one day ------------------------------------------------------------------------------------

func run_day() -> void:
	if start_total < 0:
		start_total = coins_total()
	if p9_open():
		if open9_day < 0:
			open9_day = quests.open_day()
			start9_coins = coins_total()
			start9_piety = piety.value()
			for npc: StringName in [&"priest", &"surgeon", &"washer", &"innkeeper", &"grocer", &"mayor"]:
				start9_rel[npc] = rel.value(npc)
			_t9("open (day %d): coins %d, piety %d · %s" % [open9_day, coins_total(), piety.value(), _stock_text(inv())])
		lowest_morning_p9 = mini(lowest_morning_p9, coins_total())
		var used := inv().get_slots().filter(func(sl: Dictionary) -> bool: return not sl.is_empty() and String(sl.get("id", "")) != "").size()
		_t9("morning: coins %d · step %s · letters %d decided · large %d · goal %s · pack %d/%d: %s" % [coins_total(),
				quests.current_step(MAIN), letters.decided_count(), int(quests.goal_progress().large), str(quests.goal_progress()), used,
				inv().get_slots().size(), _stock_text(inv())])
		# The chain needs Johann (the mark, „nobody", H6): the morning waits for his visit at Grete's grave (≈ 09:40) –
		# the corpse work of the morning keeps the gravekeeper in the crypt / at the table otherwise (Phase 8 B8-1).
		if TimeManager.minute_of_day < 9 * 60:
			_leave_hut()
			_wait_for_johann(600)
		# Ending A with Osric (10:00): the morning begins at the gate, seeing Johann off.
		var plan := who.depart_plan()
		if not plan.is_empty() and int(plan.get("day", -1)) == TimeManager.day and int(plan.get("minute", 0)) <= 12 * 60:
			await _p9_departure_reload()
	await super.run_day()


func _p8_tasks() -> void:
	await super._p8_tasks()
	if p9_open() and _time_left():
		await _p9_tasks()


## The Phase-9 work on the hill (every pass while there is time).
func _p9_tasks() -> void:
	if not _on_hill():
		return
	await _p9_departure_reload()
	_wait_for_johann()
	_clear_row4()
	await _p9_osric()
	await _p9_desk()
	await _p9_graves()
	await _p9_letters_now()
	await _p9_stranger_gate()
	await _p9_veit_gate()
	await _p9_large()
	_link9()


## The evening: the hand-over at Osric's cart (18:30), Phase 8's evening, then the nameless letter at the Siebers' door
## (after dark), a visit part with its window, the ghosts of a ghost part.
func _p8_evening(with_night: bool = true) -> void:
	if p9_open():
		if player.region_id == &"village":
			await _travel(&"graveyard")
		await _p9_letters_now()
		await _p9_desk()
		var for_osric := false
		for u: String in letters.postable(&"carter", inv()):
			if _letter_want(u) == LetterRules.CHOICE_DELIVER or letters.kind_of(u) in [LetterData.KIND_REPLY, LetterData.KIND_ERRAND]:
				for_osric = true
		if _on_hill() and ((flags.large and not hill.large_active().is_empty()) or for_osric):
			for id: StringName in hill.large_active():
				for i: int in hill.open_parts(id):
					var part := HillRules.parts_of(hill.large_data(id))[i]
					if part.kind == HillRules.KIND_DELIVER:
						_large_deliver_goods(part)
			_wait_until(OSRIC_EVENING9)
			await _p9_osric(true)
	await super._p8_evening(with_night)
	if p9_open() and TimeManager.minute_of_day >= 360:
		await _door_night()
		if flags.large:
			await _large_evening()


## Up from the village: Veit's well bench, Johann on his bench, the confidant – then Phase 8's archive / alms / inn.
func _travel(target: StringName) -> bool:
	if p9_open() and target == &"graveyard" and player.region_id == &"village":
		await _p9_village()
	return await super._travel(target)


## Ilse at the west wall (Phase 4, 23:05): after a trip to the village at night the hill's figures are placed again
## before she is looked for (the bot jumps the clock; a player walks back for minutes).
func _night_at_the_wall() -> void:
	if p9_open() and trade.is_known() and _door_day == TimeManager.day and TimeManager.minute_of_day >= 360:
		if TimeManager.minute_of_day < TRADE_MINUTE:
			_wait_until(TRADE_MINUTE)
		var npc := world.get_node_or_null("Entities/npc_trader") as Npc
		for i: int in 12:
			if npc != null:
				npc.refresh()
			await tree.process_frame
		_t9("Ilse after the night in the village: present %s (npc present %s, talkable %s, walking %s)" % [trade.is_present(),
				npc.is_present() if npc != null else false, npc.is_talkable() if npc != null else false, npc.is_walking() if npc != null else false])
	await super._night_at_the_wall()


## Every walk between two tasks (Phase 8 serves the visitors there): Johann's morning visit is waited for when due.
func _walk(minutes: int = WALK_MINUTES) -> void:
	super._walk(minutes)
	if p9_open() and not _in_wait:
		_in_wait = true
		_wait_for_johann(30)
		_in_wait = false


var _in_wait := false


## Lenz is wanted for H5 too (the strategy's confidant).
func _priest_wanted() -> bool:
	if super._priest_wanted():
		return true
	return p9_open() and String(flags.confide) == "confide_priest" and quests.current_step(MAIN) == WhoKnows.STEP_CONFIDE


## Johann at Grete's grave (Visitors, daily from H4, ≈ 09:40): the chain needs him (the mark, H5 „nobody", H6) – the
## gravekeeper waits for him on the hill when his visit is due within 90 minutes (Phase 8 waits 30 for any visitor).
func _wait_for_johann(ahead: int = 90) -> void:
	if not flags.chain or not _on_hill() or who.marked_seen() and not quests.current_step(MAIN) in [WhoKnows.STEP_CONFIDE, WhoKnows.STEP_DECIDE]:
		return
	if quests.current_step(MAIN) == &"h4" and not journal.has_clue(&"c_q_sieber"):
		return
	if quests.current_step(MAIN) == WhoKnows.STEP_CONFIDE and String(flags.confide) != "confide_none":
		return
	if quests.current_step(MAIN) == WhoKnows.STEP_DECIDE and String(flags.ending) == "":
		return
	if String(flags.ending) == "away" and quests.current_step(MAIN) == WhoKnows.STEP_DECIDE and not who.letter_posted():
		return
	var vs := visitors.save_state()
	if int(vs.get("plan_day", -1)) != TimeManager.day:
		return
	for e: Variant in vs.get("plan", []):
		if not e is Dictionary or StringName(str((e as Dictionary).get("kin_id", ""))) != &"kin_sieber":
			continue
		var id := str((e as Dictionary).get("visit_id", ""))
		var slot := int((e as Dictionary).get("slot", 0))
		if served.has(id) or bool((e as Dictionary).get("ended", false)) or slot - TimeManager.minute_of_day > ahead \
				or TimeManager.minute_of_day > slot + 60:
			continue
		_t9("waiting for Johann (%s)" % UIKit.clock(slot))
		while not served.has(id) and TimeManager.minute_of_day < slot + 70:
			TimeManager.advance(1)
			_serve()
		_t9("Johann: %s" % ("served" if served.has(id) else "not met"))


## Brenneisen's day: he rings at the gate 14:10 – the gravekeeper waits for him before going down (as Phase 8 waits for
## a visitor), when the strategy wants him.
func _village_trip() -> void:
	if p9_open():
		# Ending A with Hanne (16:20 up the forest way): seen off before going down.
		await _p9_departure_reload()
	if p9_open() and String(flags.stranger) != "" and _stranger_day != TimeManager.day and stranger.visit_now() > 0 and _on_hill():
		var w := stranger.get_config().gate_window
		if TimeManager.minute_of_day < w.y and w.x - TimeManager.minute_of_day <= 60:
			_wait_until(w.x + 5)
			await _p9_stranger_gate()
	await super._village_trip()


func _has_business(npc_id: StringName) -> bool:
	if super._has_business(npc_id):
		return true
	if not p9_open():
		return false
	var npc := _vnpc(npc_id)
	if npc == null or npc.entry == null:
		return false
	return _dialogue_offers(Database.dialogue(npc.entry.dialogue_id) as DialogueData, npc) > 0


## Phase 9 carries letters (one slot each, never into the shed) – when Phase 8's room is not enough, the slow goods of
## the pack (Phase 7's honey cakes, berries, herbs …) go into the shed too.
const P9_SPILL: Array[StringName] = [&"honey_cake", &"elderberries", &"herbs", &"juniper", &"beeswax", &"iron_ore", &"altar_candle",
		&"spirits"]


func _free_slots(n: int) -> void:
	super._free_slots(n)
	if not p9_open():
		return
	var empty := inv().get_slots().filter(func(sl: Dictionary) -> bool: return sl.is_empty() or String(sl.get("id", "")) == "").size()
	if empty >= n or buildings.level(&"shed") < 1 or player.carried_id != "" or player.region_id != &"graveyard":
		return
	var moves := {}
	for id: StringName in P9_SPILL:
		if empty >= n:
			break
		if inv().count(id) > 0:
			moves[id] = inv().count(id)
			empty += 1
	if moves.is_empty() or not _to_room(&"shed"):
		return
	var store := ShedStore.find(tree)
	store.interact(player)
	for id: StringName in moves:
		ChestTransfer.move(inv(), store.store(), id, int(moves[id]))
		stored[id] = int(stored.get(id, 0)) + int(moves[id])
	UIState.clear()
	_t9("shed (Phase 9 room): %s" % str(moves))


# --- the chain ------------------------------------------------------------------------------------

## The hut's desk: the Kladde (H1), the register (H2), the nameless letter (ending A), the answer – as the prompt says.
func _p9_desk() -> void:
	var desk := world.find_child("desk", true, false) as Desk
	if desk == null or not _on_hill() or not _time_left_late():
		return
	for i: int in 4:
		var action := desk.phase9_action(player)
		if action == &"":
			if not _desk_ink():
				return
			action = desk.phase9_action(player)
			if action == &"":
				return
		if not _wants_desk(action) or desk.extract_wanted_by(player) != "":
			return
		var prompt := desk.get_interaction_prompt(player)
		var door := world.get_node_by_layout_id("hut_door") as HutDoor
		var interior := tree.get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior
		_to_room(&"")
		if door.can_interact(player):
			HutPortal.arrive(player, interior.spawn_transform(), true)
		desk.interact(player)
		UIState.clear()
		_t9("desk: %s → step %s" % [prompt, quests.current_step(MAIN)])
		_leave_hut()


## Ink for the nameless letter / the answer when the desk would need it (the workbench, as Phase 8's extract).
func _desk_ink() -> bool:
	if inv().has(&"ink"):
		return false
	var need := false
	if String(flags.ending) == "away" and who.write_block_reason(inv()) == WhoKnows.TEXT_NO_INK:
		need = true
	if flags.answer and letters.answerable(inv()) != "":
		need = true
	if not need:
		return false
	if _bench(&"ink"):
		_t9("ink made at the workbench")
		return true
	return false


## Crafting at the hill's workbench (Phase 3's way: the bench's panel, request_craft).
func _bench(recipe_id: StringName) -> bool:
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	return bench != null and _craft(bench, recipe_id)


func _wants_desk(action: StringName) -> bool:
	match action:
		Desk.P9_KLADDE, Desk.P9_REGISTER:
			return flags.chain
		Desk.P9_NAMELESS:
			return String(flags.ending) == "away"
		Desk.P9_ANSWER:
			return flags.answer and _letter_want(letters.answerable(inv())) == LetterRules.CHOICE_ANSWER
	return false


## H2 at the graves (GravePlot „Datum vergleichen"), and the letters read or laid at a grave.
func _p9_graves() -> void:
	if not _on_hill():
		return
	for g: GraveRecord in graveyard.graves():
		if not _time_left_late():
			return
		if not g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED, GraveRecord.State.OLD]:
			continue
		var plot := world.get_node_by_layout_id(g.id) as GravePlot
		if plot == null:
			continue
		var want := false
		if flags.chain and who.can_compare(g.id):
			want = true
		var uid_read := letters.first_for(LetterRules.CHOICE_READ_GRAVE, inv(), {"grave_id": g.id})
		if uid_read != "" and _letter_want(uid_read) == LetterRules.CHOICE_READ_GRAVE:
			want = true
		var uid_lay := letters.first_for(LetterRules.CHOICE_BURY, inv(), {"grave_id": g.id})
		if uid_lay != "" and _letter_want(uid_lay) == LetterRules.CHOICE_BURY:
			want = true
		if not want:
			continue
		for k: int in 3:
			var action := plot.phase9_action(player)
			if action == &"":
				break
			var ok: bool = (action == GravePlot.P9_DATE and bool(flags.chain)) \
					or (action == GravePlot.P9_READ and _letter_want(uid_read) == LetterRules.CHOICE_READ_GRAVE) \
					or (action == GravePlot.P9_LAY and _letter_want(uid_lay) == LetterRules.CHOICE_BURY)
			if not ok:
				break
			_walk(2)
			player.global_position = plot.global_position + Vector3(0.0, 0.0, 1.4)
			var prompt := plot.get_interaction_prompt(player)
			if prompt != plot.phase9_prompt(action) and not plot.grave_actions(player).has(action):
				# QA9-04 fixed: every Phase-9 action is in the grave's choice – this would be a new finding.
				problems.append("day %d: %s hidden at %s (%s)" % [TimeManager.day, action, g.id, prompt])
				_grave_call(action, g.id, uid_read, uid_lay)
			else:
				_want_choice = action
				plot.interact(player)
				_want_choice = &""
			UIState.clear()
			_t9("grave %s: %s" % [g.id, prompt])
			uid_read = letters.first_for(LetterRules.CHOICE_READ_GRAVE, inv(), {"grave_id": g.id})
			uid_lay = letters.first_for(LetterRules.CHOICE_BURY, inv(), {"grave_id": g.id})


func _grave_call(action: StringName, grave_id: String, uid_read: String, uid_lay: String) -> void:
	match action:
		GravePlot.P9_DATE:
			who.compare_grave(grave_id)
		GravePlot.P9_READ:
			letters.decide(uid_read, LetterRules.CHOICE_READ_GRAVE, {"inventory": inv(), "grave_id": grave_id})
		GravePlot.P9_LAY:
			letters.decide(uid_lay, LetterRules.CHOICE_BURY, {"inventory": inv(), "grave_id": grave_id})


## The letters decided where the bag is: read on the card (letters9), burned in the stove (a letter that asks for it).
func _p9_letters_now() -> void:
	if String(flags.letters) == "":
		return
	for uid: String in letters.open_uids():
		if not inv().has_uid(uid):
			continue
		match _letter_want(uid):
			LetterRules.CHOICE_READ:
				if letters.decide(uid, LetterRules.CHOICE_READ, {"inventory": inv()}):
					_t9("letter %s opened and read (card)" % letters.letter(uid).id)
			LetterRules.CHOICE_BURN:
				_burn(uid)


func _burn(uid: String) -> void:
	if not _on_hill():
		return
	var stove: Stove = null
	for n: Node in world.find_children("*", "", true, false):
		if n is Stove:
			stove = n
	if stove == null:
		problems.append("day %d: no stove" % TimeManager.day)
		return
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var interior := tree.get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior
	_to_room(&"")
	if door.can_interact(player):
		HutPortal.arrive(player, interior.spawn_transform(), true)
	# QA9-03 fixed: [E] opens the choice at the stove, the bot picks this letter.
	_want_choice = StringName(LetterBurning.PREFIX + uid)
	stove.interact(player)
	_want_choice = &""
	UIState.clear()
	_t9("letter %s burned (%s)" % [letters.letter(uid).id if letters.letter(uid) != null else uid, letters.state(uid)])
	_leave_hut()


## What the strategy does with `uid` (a choice id; &"" = keep it / nothing now).
func _letter_want(uid: String) -> StringName:
	if uid == "" or String(flags.letters) == "":
		return &""
	var l := letters.letter(uid)
	if l == null or not letters.state(uid) in LetterRules.OPEN:
		return &""
	var ids: Array[StringName] = []
	for c: Dictionary in letters.choices(uid, {"inventory": inv()}):
		ids.append(StringName(str(c.id)))
	var kind := letters.kind_of(uid)
	if kind == LetterData.KIND_ERRAND:
		return LetterRules.CHOICE_DELIVER
	if String(flags.letters) == "read" and not letters.is_opened(uid) and ids.has(LetterRules.CHOICE_READ):
		return LetterRules.CHOICE_READ
	if kind == LetterData.KIND_POST:
		if ids.has(LetterRules.CHOICE_READ_GRAVE):
			return LetterRules.CHOICE_READ_GRAVE
		return LetterRules.CHOICE_DELIVER if ids.has(LetterRules.CHOICE_DELIVER) else &""
	if l.asks == &"burn" and ids.has(LetterRules.CHOICE_BURN):
		return LetterRules.CHOICE_BURN
	if l.asks == &"grave" and ids.has(LetterRules.CHOICE_BURY):
		return LetterRules.CHOICE_BURY
	# The chain „Briefe ohne Antwort" (L4) wants an answer – before reading at the grave.
	if flags.answer and ids.has(LetterRules.CHOICE_ANSWER) and LetterRules.can_answer(l) and letters.answerable(inv()) == uid:
		return LetterRules.CHOICE_ANSWER
	if String(flags.letters) == "grave" and ids.has(LetterRules.CHOICE_READ_GRAVE):
		return LetterRules.CHOICE_READ_GRAVE
	if ids.has(LetterRules.CHOICE_DELIVER):
		return LetterRules.CHOICE_DELIVER
	if ids.has(LetterRules.CHOICE_READ_GRAVE):
		return LetterRules.CHOICE_READ_GRAVE
	if l.recipient == &"grave" and ids.has(LetterRules.CHOICE_BURY):
		return LetterRules.CHOICE_BURY
	return &""


## The panel's button for the bot: the wanted option, else _pick_choice's default (QA9-02: at the open grave
## „Bestatten“, with the letter only when the strategy wants it in the grave).
func _on_choice_panel(id: StringName, ctx: Dictionary) -> void:
	if id != ActionChoicePanel.PANEL:
		return
	var target: Variant = ctx.get("target")
	var pick := _pick_choice(ctx)
	if pick == &"" or not is_instance_valid(target):
		problems.append("day %d: no pick in the choice %s" % [TimeManager.day, ctx.get("title", "")])
		return
	choices9[String(pick).get_slice(":", 0)] = int(choices9.get(String(pick).get_slice(":", 0), 0)) + 1
	(target as Object).call(ActionChoicePanel.DEFAULT_METHOD, pick)


func _pick_choice(ctx: Dictionary) -> StringName:
	var ids: Array[StringName] = []
	for o: Dictionary in ctx.get("options", []):
		if str(o.get("reason", "")) == "":
			ids.append(StringName(str(o.id)))
	if _want_choice != &"" and ids.has(_want_choice):
		return _want_choice
	var target: Variant = ctx.get("target")
	if ids.has(GravePlot.OPTION_BURY):
		var plot := target as GravePlot
		var uid := plot._bury_letter_uid(player) if plot != null else ""
		if uid != "" and _letter_want(uid) == LetterRules.CHOICE_BURY and ids.has(GravePlot.P9_BURY_LETTER):
			return GravePlot.P9_BURY_LETTER
		return GravePlot.OPTION_BURY
	if target is Stove:
		return Stove.OPTION_WARM
	# A grave: the order of the one-press grave (coins / closing, the date, the care, the letters last).
	for c: StringName in GravePlot.P9_DATE_AFTER:
		if ids.has(c):
			return c
	if ids.has(GravePlot.P9_DATE) and bool(flags.chain):
		return GravePlot.P9_DATE
	for c: StringName in ids:
		if not c in GravePlot.P9_ORDER:
			return c
	return ids[0] if not ids.is_empty() else &""


## Fenner's grant: the stump and the bramble of the fourth row cleared.
func _clear_row4() -> void:
	if not GameState.flag_on(&"linden_row4_granted") or expansion.is_unlocked(ROW4) or not _on_hill():
		return
	for id: String in expansion.obstacle_ids(ROW4):
		if not _time_left():
			return
		if expansion.is_cleared(id):
			continue
		var node := expansion.obstacle(id)
		if node == null or not node.can_interact(player):
			if not _refused8.has(id):
				_refused8[id] = true
				_t9("row 4: %s refuses (%s %s)" % [id, expansion.missing_cost(id, inv()), expansion.tool_block_reason(id, inv())])
			continue
		_walk()
		node.interact(player)
		UIState.clear()
	if expansion.is_unlocked(ROW4):
		_t9("row 4 open")


## i_light_before (3 of the 5 witness clues, InsightData.any_clues) once its two required clues are known.
func _link9() -> void:
	var ins := journal.insight_by_id(&"i_light_before") as InsightData
	if ins == null or journal.has_insight(ins.id) or not flags.chain:
		return
	var ids: Array[StringName] = []
	for c: StringName in ins.requires:
		if not journal.has_clue(c):
			return
		ids.append(c)
	var extra: Array[StringName] = []
	for c: StringName in ins.any_clues:
		if journal.has_clue(c):
			extra.append(c)
	if extra.size() < ins.any_count:
		return
	ids.append_array(extra.slice(0, ins.any_count))
	ids.reverse()
	if journal.try_link(ids) == ins.id:
		_t9("insight i_light_before (%s) → step %s" % [str(ids), quests.current_step(MAIN)])
	else:
		problems.append("day %d: i_light_before refused %s" % [TimeManager.day, str(ids)])


# --- the people -----------------------------------------------------------------------------------

## Osric on the hill (the morning delivery, the evening at the gate): his dialogue when it has Phase-9 business
## (witness e_quendel, a letter for the town, the large request's hand-over).
func _p9_osric(evening: bool = false) -> void:
	if _osric_day == TimeManager.day * 2 + int(evening) or not _on_hill():
		return
	var speaker := world.get_node_by_layout_id("npc_carter") as Npc
	if speaker == null:
		return
	speaker.refresh()
	if not speaker.is_present():
		return
	var dlg := Database.dialogue(&"carter") as DialogueData
	var offers := _dialogue_offers(dlg, speaker)
	if OS.get_environment("P9QA_DEBUG") != "":
		_t9("osric present (evening %s): offers %d, postable %s" % [evening, offers, str(letters.postable(&"carter", inv()))])
	if offers <= 0:
		return
	_osric_day = TimeManager.day * 2 + int(evening)
	player.global_position = speaker.global_position + Vector3(1.2, 0, 0)
	# A remark of the day may end the first talk (he says his piece and goes on) – [E] again, as a player would.
	for k: int in 3:
		var before := _dialogue_offers(dlg, speaker)
		_talk_with(dlg, speaker, &"carter")
		if _dialogue_offers(dlg, speaker) <= 0 or _dialogue_offers(dlg, speaker) < before:
			break


## Brenneisen outside the gate (his visit days, 14:10–): his dialogue for the strategy (save_load9: a round trip).
func _p9_stranger_gate() -> void:
	if String(flags.stranger) == "" or _stranger_day == TimeManager.day or not _on_hill() or not stranger.present(&"graveyard"):
		return
	var npc := world.get_node_or_null("Entities/npc_stranger_g") as Npc
	if npc == null:
		problems.append("day %d: Brenneisen present but no figure" % TimeManager.day)
		return
	npc.refresh()
	if not npc.is_present():
		_note("day %d %s: Stranger.present(graveyard) but npc_stranger_g hidden" % [TimeManager.day, TimeManager.format_clock()])
		return
	_stranger_day = TimeManager.day
	if flags.save_p9 and not saved9.has("stranger"):
		saved9.append("stranger")
		await _reload_now("Brenneisen at the gate")
		npc = world.get_node_or_null("Entities/npc_stranger_g") as Npc
	_walk()
	player.global_position = npc.global_position + Vector3(-1.0, 0, -0.6)
	for i: int in 3:
		if _dialogue_offers(Database.dialogue(&"stranger") as DialogueData, npc) <= 0:
			break
		_talk(npc)
	stranger_log.append("d%d: step %s, answers %s, sold %s, bribe %s, case %s, ending %s" % [TimeManager.day, quests.current_step(CASE_Q),
			str(stranger.answers()), str(stranger.rule_state().get("sold", {})), stranger.bribe_state(), stranger.case_holder(), stranger.ending()])
	_t9("Brenneisen: " + stranger_log[stranger_log.size() - 1])


## Veit at the gate with Phase-9 business (the witness of the open light, K3).
func _p9_veit_gate() -> void:
	if _veit_day == TimeManager.day or not _on_hill() or not wanderers.present(&"beggar"):
		return
	var veit := world.get_node_by_layout_id("npc_beggar_g") as Npc
	if veit == null:
		return
	veit.refresh()
	if not veit.is_present() or _dialogue_offers(Database.dialogue(veit.entry.dialogue_id) as DialogueData, veit) <= 0:
		return
	_veit_day = TimeManager.day
	player.global_position = veit.global_position + Vector3(1.0, 0, 0)
	_talk(veit)


## In the village before going up: Veit (well bench / bridge / church), Johann on his bench, the strategy's confidant.
func _p9_village() -> void:
	if OS.get_environment("P9QA_DEBUG") != "":
		var v := _vnpc(&"beggar")
		if v != null:
			v.refresh()
		_t9("village end %s: step %s, clue c_q_sieber %s, Veit %s (%s, offers %d, case step %s), knock %d" % [TimeManager.format_clock(),
				quests.current_step(MAIN), journal.has_clue(&"c_q_sieber"), v.is_present() if v != null else false,
				wanderers.place(&"beggar", TimeManager.day, TimeManager.minute_of_day),
				_dialogue_offers(Database.dialogue(v.entry.dialogue_id) as DialogueData, v) if v != null and v.entry != null else -1,
				quests.current_step(CASE_Q), _knock_day])
	if _veit_day != TimeManager.day:
		var veit := _vnpc(&"beggar")
		if veit != null:
			veit.refresh()
			if veit.is_present() and _dialogue_offers(Database.dialogue(veit.entry.dialogue_id) as DialogueData, veit) > 0:
				await _leave_vroom()
				_veit_day = TimeManager.day
				player.global_position = veit.global_position + Vector3(1.0, 0, 0)
				_talk(veit)
	# Brenneisen in the village (09:30–13:30, from 16:00; the inn's corner table in the evening) when not met at the gate.
	if String(flags.stranger) != "" and _stranger_day != TimeManager.day and stranger.visit_now() > 0:
		var sn := _vnpc(&"stranger")
		if sn != null:
			sn.refresh()
			# G9 Gehtempo: his ways to the gate and back take an hour now – on the way he is there but not to be spoken to.
			if sn.is_present() and sn.is_talkable() and _dialogue_offers(Database.dialogue(&"stranger") as DialogueData, sn) > 0 \
					and await _enter_for(sn):
				_stranger_day = TimeManager.day
				player.global_position = sn.global_position + Vector3(1.0, 0, 0)
				_talk(sn)
				stranger_log.append("d%d (village): step %s, answers %s, bribe %s, case %s, ending %s" % [TimeManager.day,
						quests.current_step(CASE_Q), str(stranger.answers()), stranger.bribe_state(), stranger.case_holder(), stranger.ending()])
				await _leave_vroom()
	var johann := world.get_node_or_null("Regions/Village/Entities/npc_kin_sieber_v") as Npc
	if johann != null:
		johann.refresh()
		if johann.is_present() and _dialogue_offers(Database.dialogue(&"kin_sieber_v") as DialogueData, johann) > 0:
			await _leave_vroom()
			player.global_position = johann.global_position + Vector3(1.0, 0, 0)
			_talk(johann)
			_t9("Johann on the bench: step %s" % quests.current_step(MAIN))
	# H4: Anna behind the door (sieber_door.tres „light": add_clue c_q_sieber) – once, while the clue is missing.
	var door := world.get_node_or_null("Regions/Village/Entities/door_sieber") as KnockDoor
	if door != null and flags.chain and _knock_day < 0 and quests.current_step(MAIN) == &"h4" and not journal.has_clue(&"c_q_sieber"):
		await _leave_vroom()
		player.global_transform = Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0, 1.0))
		if door.can_interact(player) and door.get_interaction_prompt(player) == KnockDoor.PROMPT_KNOCK:
			_knock_day = TimeManager.day
			var runner := DialogueRunner.new()
			runner.start(Database.dialogue(door.dialogue_id) as DialogueData, {"inventory": inv(), "speaker": door, "player": player})
			for step: int in 6:
				if runner.is_finished() or runner.available_choices().is_empty():
					break
				runner.choose(0)
			UIState.clear()
			_t9("knocked at the Siebers' (Anna): c_q_sieber %s" % journal.has_clue(&"c_q_sieber"))


## Ending A: the nameless letter at the Siebers' door after dark – down to the village and up again.
func _door_night() -> void:
	if String(flags.ending) != "away" or who.letter_posted() or not inv().has(WhoKnows.NAMELESS_ITEM) or _door_day == TimeManager.day:
		return
	_door_day = TimeManager.day
	_wait_until(DOOR_NIGHT)
	if not await _travel(&"village"):
		return
	var door := world.get_node_or_null("Regions/Village/Entities/door_sieber") as KnockDoor
	if door == null:
		problems.append("day %d: no door_sieber" % TimeManager.day)
	else:
		_walk(VILLAGE_WALK)
		player.global_transform = Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0, 1.0))
		if door.get_interaction_prompt(player) == KnockDoor.PROMPT_LETTER:
			door.interact(player)
		else:
			problems.append("day %d %s: the door does not take the letter (%s)" % [TimeManager.day, TimeManager.format_clock(),
					door.get_interaction_prompt(player)])
		_t9("nameless letter at the Siebers' door: %s" % who.letter_posted())
	await super._travel(&"graveyard")
	# Back on the hill at night: the figures there place themselves from their plans (Ilse at the wall).
	for n: Node in tree.get_nodes_in_group(&"npc"):
		if n is Npc and (n as Npc).is_inside_tree():
			(n as Npc).refresh()


## Kin visits: Phase 8's serving, then the kin's own dialogue for Johann (the mark, H5 / H6, a letter read aloud) and
## Gesa (her witness, the errand, her letter).
func _serve_visit(v: Dictionary) -> void:
	super._serve_visit(v)
	if not p9_open():
		return
	var kin := StringName(str(v.kin_id))
	var npc := world.get_node_by_layout_id(KIN_NPC.get(kin, "")) as Npc
	if npc == null or npc.entry == null:
		return
	var dlg := Database.dialogue(npc.entry.dialogue_id) as DialogueData
	for i: int in 2:
		if _dialogue_offers(dlg, npc) <= 0:
			break
		_talk(npc)
	if kin == &"kin_sieber":
		_t9("Johann at Grete's grave: step %s, ending %s" % [quests.current_step(MAIN), quests.ending(MAIN)])


# --- dialogues ------------------------------------------------------------------------------------

## A dialogue through the real DialogueRunner with Phase 7's picking (the speaker without an entry: Osric on the hill).
func _talk_with(dlg: DialogueData, speaker: Node, npc_id: StringName) -> void:
	if dlg == null:
		problems.append("day %d: no dialogue for %s" % [TimeManager.day, npc_id])
		return
	var prev := _dlg_now
	var prev_speaker := _speaker_now
	_dlg_now = dlg
	_speaker_now = npc_id
	var runner := DialogueRunner.new()
	_speaker_node = speaker
	runner.start(dlg, {"inventory": inv(), "speaker": speaker, "player": player})
	var visited := {}
	var path := PackedStringArray()
	for step: int in VILLAGE_STEPS:
		if runner.is_finished():
			break
		var choices := runner.available_choices()
		if choices.is_empty():
			break
		var pick := _pick9(choices, visited)
		if OS.get_environment("P9QA_DEBUG") != "":
			_t9("  %s @%s: %s → %d" % [npc_id, runner.current_node().id if runner.current_node() != null else &"?",
					str(choices.map(func(c: DialogueChoice) -> String: return "%s:%d/%d%s" % [c.next, _score9(c, visited),
					_ahead9(c.next, visited, 3), "v" if _vetoed(c) else ""])), pick])
		if pick < 0:
			break
		var choice := choices[pick]
		visited[choice.next] = int(visited.get(choice.next, 0)) + 1
		for a: String in choice.actions:
			visited["a:" + a] = true
		path.append(String(choice.next))
		runner.choose(pick)
		_after_choice(npc_id, choice)
		UIState.clear()
	UIState.clear()
	_dlg_now = prev
	_speaker_now = prev_speaker
	if path.size() > 1:
		_t9("talk %s: %s" % [npc_id, " ".join(path)])


## The node the runner would show for `n` (its fallback_next chain while the conditions fail), null = the end.
func _resolve(n: StringName) -> DialogueNode:
	if _dlg_now == null:
		return null
	var ctx := {"inventory": inv(), "player": player, "speaker": _speaker_node}
	for i: int in 64:
		if n == &"":
			return null
		var node := _dlg_now.get_node_by_id(n)
		if node == null:
			return null
		if DialogueConditions.all_met(node.conditions, ctx):
			return node
		n = node.fallback_next
	return null


## The best Phase-9 score behind node `n` within `depth` steps (the conditions of the choices checked).
func _ahead9(n: StringName, visited: Dictionary, depth: int, seen: Dictionary = {}) -> int:
	if _dlg_now == null or depth <= 0 or seen.has(n):
		return 0
	seen[n] = true
	var node := _resolve(n)
	if node == null:
		return 0
	var ctx := {"inventory": inv(), "player": player, "speaker": _speaker_node}
	var best := 0
	for c: DialogueChoice in node.choices:
		if _vetoed(c) or not DialogueConditions.all_met(c.conditions, ctx):
			continue
		best = maxi(best, _score9(c, visited))
		if c.next != &"" and c.next != n:
			best = maxi(best, _ahead9(c.next, visited, depth - 1, seen) - 5)
	return best


## Only the Phase-9 business (Osric's shop and remarks are Phase 5/6's own talk): the best Phase-9 choice (with one node
## of lookahead), else onwards through a plain line once, else leave.
func _pick9(choices: Array[DialogueChoice], visited: Dictionary) -> int:
	var best := -1
	var best_score := 0
	for i: int in choices.size():
		if _vetoed(choices[i]):
			continue
		var s := _score9(choices[i], visited)
		if s <= 0 and choices[i].next != &"" and int(visited.get(choices[i].next, 0)) < 3:
			s = _ahead9(choices[i].next, visited, 6) - 5
		if s > best_score:
			best_score = s
			best = i
	if best >= 0:
		return best
	# A remark with a single way on (Osric's greeting chain): onwards once, then towards the menu.
	if choices.size() == 1 and choices[0].next != &"" and int(visited.get(choices[0].next, 0)) == 0 and not _vetoed(choices[0]):
		return 0
	for i: int in choices.size():
		var n := choices[i].next
		if n == &"" or String(n).begins_with("bye") or String(n).begins_with("goodbye"):
			return i
	return -1


func _talk(npc: Npc) -> void:
	var prev := _dlg_now
	var prev_speaker := _speaker_now
	_dlg_now = Database.dialogue(npc.entry.dialogue_id if npc.entry != null else &"") as DialogueData
	_speaker_now = npc.npc_id
	_speaker_node = npc
	super._talk(npc)
	_dlg_now = prev
	_speaker_now = prev_speaker
	UIState.clear()


## The best Phase-9 score a dialogue offers now (its start / menu choices whose conditions hold) – 0 = nothing to do.
func _dialogue_offers(dlg: DialogueData, speaker: Node) -> int:
	if dlg == null:
		return 0
	var ctx := {"inventory": inv(), "speaker": speaker, "player": player}
	var best := 0
	var prev := _dlg_now
	var prev_speaker := _speaker_now
	_dlg_now = dlg
	_speaker_now = StringName(str(speaker.get(&"npc_id"))) if speaker is Npc else &""
	var prev_node := _speaker_node
	_speaker_node = speaker
	for n: DialogueNode in dlg.nodes:
		if n == null:
			continue
		for c: DialogueChoice in n.choices:
			if not DialogueConditions.all_met(c.conditions, ctx) or _vetoed(c):
				continue
			best = maxi(best, _score9(c, {}))
	_dlg_now = prev
	_speaker_now = prev_speaker
	_speaker_node = prev_node
	return best


func _score(npc_id: StringName, c: DialogueChoice, visited: Dictionary) -> int:
	var best := super._score(npc_id, c, visited)
	if not p9_open():
		return best
	return maxi(best, _score9(c, visited))


## Phase-9 actions of a choice and of the node it leads to (witness, give_item of the Kladde … are node actions).
func _score9(c: DialogueChoice, visited: Dictionary) -> int:
	var best := 0
	var acts: Array[String] = []
	acts.append_array(c.actions)
	if _dlg_now != null and c.next != &"" and int(visited.get(c.next, 0)) == 0:
		var node := _resolve(c.next)
		if node != null:
			acts.append_array(node.actions)
	for a: String in acts:
		if visited.has("a:" + a):
			continue
		var parts := a.split(":")
		var key := parts[0]
		var arg := StringName(parts[1]) if parts.size() > 1 else &""
		match key:
			"witness":
				if flags.chain and not who.witnessed().has(arg):
					best = maxi(best, 93)
			"mark_seen":
				if flags.chain and not who.marked_seen():
					best = maxi(best, 94)
			"give_item":
				if arg == &"lorenz_ledger_2" and flags.chain and not inv().has(arg):
					best = maxi(best, 92)
			"quest_choose":
				if parts.size() >= 4 and _wants_choice(StringName(parts[1]), StringName(parts[2]), StringName(parts[3])):
					best = maxi(best, 98)
			"letter_deliver", "letter_read_aloud":
				best = maxi(best, 91)
			"letter_post":
				if not letters.postable(arg, inv()).is_empty():
					best = maxi(best, 89)
			"letter_errand":
				if flags.errands:
					best = maxi(best, 86)
			"letter_ask_postage":
				pass
			"large_turn_in":
				best = maxi(best, 100)
			"hill_turn_in":
				# W3 QA-Fix QA9-05: the small line shows for small requests only; the large one has its own line
				# (large_turn_in above). Both hand over through HillRequests.turn_in.
				if flags.large and not hill.small_ready_for(arg, inv()).is_empty():
					best = maxi(best, 100)
			"stranger_answer":
				if String(arg) == String(flags.answer_kind):
					best = maxi(best, 90)
			"stranger_offers":
				if String(flags.stranger) != "" and (flags.sell or not stranger.offers_seen()):
					best = maxi(best, 72 if not flags.sell else 88)
			"stranger_bribe":
				if (String(arg) == "yes") == (String(flags.bribe) == "yes"):
					best = maxi(best, 90)
			"stranger_take_case", "stranger_case":
				if String(flags.stranger) != "":
					best = maxi(best, 84)
			"stranger_give_case":
				if String(flags.stranger) != "" and String(arg) == ("fenner" if String(flags.stranger) == "fenner" else "stranger"):
					best = maxi(best, 87)
			"stranger_resolve":
				if String(arg) == String(flags.stranger):
					best = maxi(best, 97)
			"add_clue":
				if (String(arg).begins_with("c_q_") or arg == &"c_n_robber") and not journal.has_clue(arg) and flags.chain:
					best = maxi(best, 80)
			"set_flag":
				if arg == &"linden_row4_granted" and not GameState.flag_on(arg):
					best = maxi(best, 92)
				elif arg == &"stranger_veit_told" and String(flags.stranger) != "" and not GameState.flag_on(arg):
					best = maxi(best, 82)
			"order_accept":
				var o := orders.order_data(arg)
				if o != null and o.category == OrderData.CATEGORY_QUEST and _wants_quest_order(arg):
					best = maxi(best, 85)
	return best


func _wants_choice(quest_id: StringName, step_id: StringName, choice_id: StringName) -> bool:
	if quest_id == MAIN:
		if step_id == WhoKnows.STEP_CONFIDE:
			return String(flags.confide) != "" and String(choice_id) == String(flags.confide)
		if step_id == WhoKnows.STEP_DECIDE:
			return String(flags.ending) != "" and String(choice_id) == String(flags.ending)
		return false
	if quest_id == LETTERS_Q:
		return String(choice_id) == "liesel"
	return false


func _wants_quest_order(id: StringName) -> bool:
	if not flags.errands:
		return false
	if id == &"oq_johann_evening":
		return String(flags.ending) == "stay"
	if id == &"oq_case_return":
		return String(flags.stranger) != ""
	return true


func _vetoed(c: DialogueChoice) -> bool:
	if super._vetoed(c):
		return true
	if not p9_open():
		return false
	for a: String in c.actions:
		var parts := a.split(":")
		var key := parts[0]
		var arg := StringName(parts[1]) if parts.size() > 1 else &""
		match key:
			"donate":
				return true
			"quest_choose":
				if parts.size() >= 4 and not _wants_choice(StringName(parts[1]), StringName(parts[2]), StringName(parts[3])):
					return true
			"witness", "mark_seen":
				if not flags.chain:
					return true
			"letter_deliver", "letter_read_aloud":
				var uid := letters.letter_for(_speaker_id(), inv())
				if String(flags.letters) == "" or (uid != "" and _letter_want(uid) != LetterRules.CHOICE_DELIVER):
					return true
			"letter_post":
				var ok := false
				for uid: String in letters.postable(arg, inv()):
					if _letter_want(uid) == LetterRules.CHOICE_DELIVER or letters.kind_of(uid) in [LetterData.KIND_REPLY, LetterData.KIND_ERRAND]:
						ok = true
				if not ok:
					return true
			"letter_errand", "letter_ask_postage":
				if not flags.errands:
					return true
			"stranger_answer":
				if String(arg) != String(flags.answer_kind):
					return true
			"stranger_bribe":
				if (String(arg) == "yes") != (String(flags.bribe) == "yes"):
					return true
			"stranger_resolve":
				if String(arg) != String(flags.stranger):
					return true
			"stranger_give_case":
				if String(arg) != ("fenner" if String(flags.stranger) == "fenner" else "stranger"):
					return true
			"stranger_offers", "stranger_take_case", "stranger_case":
				if String(flags.stranger) == "":
					return true
			"order_accept":
				var o := orders.order_data(arg)
				if o != null and o.category == OrderData.CATEGORY_QUEST and not _wants_quest_order(arg):
					return true
	return false


func _speaker_id() -> StringName:
	return _speaker_now


func _after_choice(npc_id: StringName, choice: DialogueChoice) -> void:
	super._after_choice(npc_id, choice)
	if not p9_open():
		return
	for a: String in choice.actions:
		var parts := a.split(":")
		match parts[0]:
			"stranger_offers":
				_use_stranger_offers()
			"quest_choose":
				_t9("chosen %s → step %s, ending %s" % [a, quests.current_step(MAIN), quests.ending(MAIN)])
			"letter_deliver", "letter_read_aloud", "letter_post", "letter_errand":
				_t9("%s with %s" % [a, npc_id])
			"large_turn_in":
				_t9("large hand-over with %s: %s" % [npc_id, str(hill.large_active())])


## The offers panel (Stranger.offers / sell – what the panel's buttons call): the trader sells what he buys.
func _use_stranger_offers() -> void:
	var offers := stranger.offers(inv())
	var shown := PackedStringArray()
	for o: Dictionary in offers:
		shown.append("%s %s" % [o.get("id", "?"), o.get("reason", "")])
	_t9("Brenneisen's offers: %s" % ", ".join(shown))
	if not flags.sell:
		UIState.clear()
		return
	for o: Dictionary in offers:
		var id := StringName(str(o.get("id", "")))
		for k: int in 4:
			if str(stranger.offers(inv()).filter(func(x: Dictionary) -> bool: return StringName(str(x.get("id", ""))) == id) \
					.map(func(x: Dictionary) -> String: return str(x.get("reason", "")))) != "[\"\"]":
				break
			if not stranger.sell(id, inv()):
				break
			_t9("sold to Brenneisen: %s" % id)
	UIState.clear()


# --- large requests (as HillBot, Phase 9 §2.3) -----------------------------------------------------

func _p9_large() -> void:
	if not flags.large or not _on_hill():
		return
	_large_board()
	for i: int in 3:
		if not await _large_work():
			break
		_large_board()


func _large_board() -> void:
	if not hill.large_active().is_empty() or not _time_left():
		return
	for id: StringName in hill.large_offered(OrderData.PLACE_GATE):
		if hill.accept_reason(id) != "" or not _large_doable(id):
			continue
		_walk()
		if hill.accept(id):
			large_log.append("d%d accepted %s" % [TimeManager.day, id])
			_t9("large request accepted at the gate: %s" % id)
		return


func _large_doable(id: StringName) -> bool:
	var r := hill.large_data(id)
	if r == null:
		return false
	var need := {}
	for p: OrderData in HillRules.parts_of(r):
		if not p.kind in LARGE_HANDLED:
			return false
		# The materials of the craft parts must be in the pack now (a large request runs only a few days).
		if p.kind == HillRules.KIND_CRAFT:
			var recipe := Database.recipe(HillRules.recipe_of(p)) as RecipeData
			if recipe == null:
				return false
			for item: StringName in recipe.inputs:
				need[item] = int(need.get(item, 0)) + int(recipe.inputs[item]) * HillRules.need(p)
	# Wood is the scarce one in the Phase-8 end states (no wild section left); stone comes from the daily pile.
	if need.has(&"wood") and inv().count(&"wood") < int(need[&"wood"]) + LARGE_KEEP_WOOD:
		return false
	return true


func _large_work() -> bool:
	var did := false
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		if flags.save_p9 and not saved9.has("large") and HillRules.done_count(hill.parts_done(id)) >= 1:
			saved9.append("large")
			await _reload_now("a large request at %d/%d" % [HillRules.done_count(hill.parts_done(id)), parts.size()])
		for i: int in hill.open_parts(id):
			if not _time_left() or not hill.large_active().has(id):
				return did
			var part := parts[i]
			var before := TimeManager.total_minutes()
			match part.kind:
				HillRules.KIND_CRAFT:
					_large_craft(id, i, part)
				HillRules.KIND_TEND:
					_large_tend(id, i)
				HillRules.KIND_DECOR:
					_large_decor(id, i, part)
				HillRules.KIND_CLEAR:
					_large_clear(part)
				HillRules.KIND_GATHER:
					_large_gather(id, i, part)
				HillRules.KIND_VISIT:
					if HillRules.visit_window(part).x < 0:
						_large_visit(id, part)
				HillRules.KIND_DELIVER:
					_large_deliver_goods(part)
					await _p9_osric()
			if TimeManager.total_minutes() > before:
				did = true
	return did


## The goods of a deliver part in the bag (the crafted crosses may have gone onto graves as markers meanwhile).
func _large_deliver_goods(part: OrderData) -> void:
	for item: StringName in part.items:
		var need := int(part.items[item])
		for k: int in 6:
			if inv().count(item) >= need or Database.recipe(item) == null or not _large_materials(item) or not _bench(item):
				break


func _large_craft(id: StringName, index: int, part: OrderData) -> void:
	var recipe_id := HillRules.recipe_of(part)
	var left := HillRules.need(part) - hill.part_progress(id, index)
	for k: int in maxi(left, 0):
		if not _large_materials(recipe_id) or not _bench(recipe_id):
			return


func _large_materials(recipe_id: StringName) -> bool:
	var r := Database.recipe(recipe_id) as RecipeData
	if r == null:
		return false
	for item: StringName in r.inputs:
		var need := int(r.inputs[item])
		var keep := LARGE_KEEP_WOOD if item == &"wood" else 0
		if inv().count(item) < need + keep:
			return false
	return true


func _large_gather(id: StringName, index: int, part: OrderData) -> void:
	var item := StringName(str(part.conditions.get("item", "")))
	for section: StringName in [&"east", &"north", &"elder"]:
		if expansion.is_unlocked(section) or expansion.block_reason(section) != "":
			continue
		var ids := expansion.obstacle_ids(section)
		ids.sort()
		for o: String in ids:
			if not _time_left() or not hill.large_active().has(id) or hill.part_progress(id, index) >= HillRules.need(part):
				return
			if expansion.is_cleared(o):
				continue
			var data := expansion.data_of(o)
			if not data.yield_items.has(item) or not data.cost.is_empty():
				continue
			var node := expansion.obstacle(o)
			if node != null and node.can_interact(player):
				_walk()
				node.interact(player)


func _large_tend(id: StringName, index: int) -> void:
	for spot_id: String in hill.part_targets(id, index):
		if clean.level(spot_id) < 1:
			continue
		var spot: DirtSpot = null
		for node: Node in tree.get_nodes_in_group(DirtSpot.GROUP):
			if (node as DirtSpot).spot_id == spot_id:
				spot = node
		if spot != null and spot.can_interact(player):
			_walk(2)
			spot.interact(player)


func _large_clear(part: OrderData) -> void:
	for section: String in HillRules.sections_of(part):
		var sid := StringName(section)
		if expansion.is_unlocked(sid) or expansion.block_reason(sid) != "":
			continue
		var ids := expansion.obstacle_ids(sid)
		ids.sort()
		for o: String in ids:
			if expansion.is_cleared(o):
				continue
			var node := expansion.obstacle(o)
			if node != null and node.can_interact(player):
				_walk()
				node.interact(player)
				return


func _large_decor(id: StringName, index: int, part: OrderData) -> void:
	var allowed: Array = part.conditions.get("decor", [])
	var left := HillRules.need(part) - hill.part_progress(id, index)
	for k: int in maxi(left, 0):
		var decor_id := &""
		for d: Variant in allowed:
			if inv().count(StringName(str(d))) > 0:
				decor_id = StringName(str(d))
				break
		if decor_id == &"":
			for d: StringName in LARGE_DECOR_ORDER:
				if (allowed.has(String(d)) or allowed.has(d)) and _large_materials(d) and _bench(d):
					decor_id = d
					break
		if decor_id == &"" or inv().count(decor_id) == 0:
			return
		if _large_place(decor_id, part) == "":
			problems.append("day %d: could not place %s for %s" % [TimeManager.day, decor_id, id])
			return


func _large_place(decor_id: StringName, part: OrderData) -> String:
	var section := StringName(str(part.conditions.get("section", "yard")))
	var targets: Array[Vector2] = []
	if str(part.conditions.get("near", "")) == "gate":
		var at := world.get_waypoint(&"gate_inside")
		for dz: float in [0.0, -1.5, -3.0, -4.5, -6.0]:
			for dx: float in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0]:
				if Vector2(dx, dz).length() <= HillRequests.NEAR_RADIUS - 2.0:
					targets.append(Vector2(at.x + dx, at.z + dz))
	else:
		for g: String in graveyard.plots_in_section(section):
			targets.append(_centre_of(g) + Vector2(0.0, 1.6))
	for t: Vector2 in targets:
		var uid := _place_near(decor_id, t, section)
		if uid != "":
			return uid
	return ""


func _large_visit(id: StringName, part: OrderData) -> void:
	_to_room(&"")
	_walk()
	var place := StringName(str(part.conditions.get("place", "")))
	var spot := world.get_node_or_null("Entities/visit_" + String(place)) as VisitSpot
	player.global_position = world.get_waypoint(place)
	if spot != null and spot.can_interact(player) and spot.request_here() == id:
		spot.interact(player)
		UIState.clear()
	else:
		var reason := hill.visit_block_reason(id, player)
		if reason != "":
			problems.append("day %d: visit %s refused: %s" % [TimeManager.day, id, reason])
			return
		_standin("visit spot")
		hill.start_visit(id)
	_t9("large visit %s at %s" % [id, place])


## After Osric's evening: the visit part with its window (the lantern evening at the gate), the ghosts of a ghost part.
func _large_evening() -> void:
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		for i: int in hill.open_parts(id):
			var part := parts[i]
			if part.kind != HillRules.KIND_VISIT:
				continue
			var w := HillRules.visit_window(part)
			if w.x < 0 or TimeManager.minute_of_day > w.y - HillRules.visit_minutes(part):
				continue
			_wait_until(w.x)
			_large_visit(id, part)
		if not hill.large_active().has(id):
			continue
		for i: int in hill.open_parts(id):
			if parts[i].kind in [HillRules.KIND_GHOST, HillRules.KIND_GHOSTS] and _listened9 != TimeManager.day:
				_listened9 = TimeManager.day
				_large_listen(parts[i])


func _large_listen(part: OrderData) -> void:
	_wait_until(LISTEN_MINUTE)
	var want := str(part.conditions.get("section", ""))
	var left := HillRules.need(part)
	for id: String in ghosts.eligible_graves():
		if left <= 0:
			break
		if want != "" and String(graveyard.section_of(id)) != want:
			continue
		var plot := world.get_node_by_layout_id(id) as Node3D
		player.global_position = plot.global_position + Vector3(0.0, 0.0, 1.5)
		ghosts.reselect()
		ghosts.update_visuals(TimeManager.get_minute_f())
		for g: Ghost in ghosts.active_ghosts():
			if g.grave_id == id and g.can_interact(player):
				var coins := inv().count(&"coin")
				g.interact(player)
				gifts += inv().count(&"coin") - coins
				left -= 1
				break


# --- the night / Phase 8 hooks -------------------------------------------------------------------------

## Ending A: the gravekeeper sees Johann off – at the gate when the departure (Hanne up the forest way at 16:20 / Osric's
## cart at 10:00) is due within 90 minutes; save_load9 saves and loads while he is on his way.
func _p9_departure_reload() -> void:
	var plan := who.depart_plan()
	if plan.is_empty() or int(plan.get("day", -1)) != TimeManager.day or depart_seen:
		return
	var m := int(plan.get("minute", -1))
	if m - TimeManager.minute_of_day > 600 or TimeManager.minute_of_day > m + 30:
		return
	depart_seen = true
	_leave_hut()
	_to_room(&"")
	_walk()
	player.global_position = world.get_waypoint(&"gate_inside")
	_wait_until(m + 10)
	_t9("Johann leaves with %s (%s): seen off at the gate" % [plan.get("with", "?"), UIKit.clock(m)])
	if flags.save_p9 and not saved9.has("departure"):
		saved9.append("departure")
		await _reload_now("the departure (%s)" % str(plan))
	_wait_until(m + 20)


func _time_left_late() -> bool:
	return TimeManager.minute_of_day >= 300 and TimeManager.minute_of_day < EVENING


# --- the record -----------------------------------------------------------------------------------

func _t9(what: String) -> void:
	trace9.append("d%d %s %s" % [TimeManager.day, TimeManager.format_clock(), what])


func _note(what: String) -> void:
	if not notes9.has(what):
		notes9.append(what)


func _standin(kind: String) -> void:
	standins[kind] = int(standins.get(kind, 0)) + 1


func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	if not p9_open():
		return
	var g := quests.goal_progress()
	r.merge({"open9": true, "coins9": coins_total(), "step": String(quests.current_step(MAIN)), "ending": String(quests.ending(MAIN)),
			"main_state": String(quests.state(MAIN)), "letters_step": String(quests.current_step(LETTERS_Q)),
			"decided": letters.decided_count(), "large": int(g.get("large", 0)), "chapter9": GameState.flag_on(&"who_knows_when_complete"),
			"case_step": String(quests.current_step(CASE_Q)), "stranger_ending": String(stranger.ending()), "gone": GameState.flag_on(&"sieber_gone"),
			"dead": GameState.flag_on(&"sieber_dead"), "buried": GameState.flag_on(&"sieber_buried"), "piety9": piety.value()})


func table_p9() -> String:
	var lines := PackedStringArray(["| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Hauptkette | Briefe entsch. | große Bitten | Koffer | Pietät | Ruf | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|"])
	var morning := start9_coins
	for r: Dictionary in rows:
		if not bool(r.get("open9", false)):
			continue
		var parts := PackedStringArray()
		var spent_day: Dictionary = r.get("spent_day", {})
		for reason: Variant in spent_day:
			parts.append("%s %d" % [reason, int(spent_day[reason])])
		var inc := PackedStringArray()
		var income_day: Dictionary = r.get("income_day", {})
		for source: Variant in income_day:
			inc.append("%s %d" % [source, int(income_day[source])])
		var chain := String(r.step) if String(r.ending) == "" else "Ende %s (%s)" % [r.ending, r.main_state]
		lines.append("| %d | %d | %s | %s | %d | %s | %d | %d | %s | %d | %d | %s |" % [r.day, morning,
				", ".join(parts) if not parts.is_empty() else "–", ", ".join(inc) if not inc.is_empty() else "–", int(r.coins9), chain,
				int(r.decided), int(r.large), String(r.case_step) if String(r.stranger_ending) == "" else String(r.stranger_ending),
				int(r.piety9), int(r.rep), "✓" if bool(r.chapter9) else "offen"])
		morning = int(r.coins9)
	return "\n".join(lines)


func ledger_text() -> String:
	return super.ledger_text() + " · Phase 9: start %d, spent %d, lowest morning %d" % [start9_coins, spent_p9, lowest_morning_p9]


func _on_coins_spent(amount: int, reason: StringName) -> void:
	super._on_coins_spent(amount, reason)
	if p9_open():
		spent_p9 += amount


func _on_payment(coins: int, reason: String) -> void:
	var source := ""
	if reason.begins_with(HillRules.REASON_PREFIX) or reason.begins_with(HillRules.REASON_HALF.split("%")[0]):
		var title := reason.get_slice(": ", 1)
		source = "hill_request"
		for r: Variant in Database.large_requests():
			if (r as OrderData).title == title:
				source = "large_request"
	elif reason == Letters.REASON_ANSWER_COIN or reason == Stranger.REASON_TIP:
		source = "errand"
	elif reason == Stranger.REASON_SALE:
		source = "stranger_sale"
	elif reason == Stranger.REASON_ANSWER:
		source = "stranger_answer"
	if source != "":
		income[source] = int(income.get(source, 0)) + coins
		_income_day[source] = int(_income_day.get(source, 0)) + coins
		return
	super._on_payment(coins, reason)


func _on_chapter(chapter_id: StringName) -> void:
	super._on_chapter(chapter_id)
	if chapter_id == &"who_knows_when" and chapter9_day < 0:
		chapter9_day = TimeManager.day
		_t9("CHAPTER who_knows_when")


func _on_quest(quest_id: StringName, step_id: StringName, state: StringName) -> void:
	_t9("quest %s %s %s" % [quest_id, state, step_id])
	if quest_id == MAIN and state == Quests.CHANGE_ENDED and ending_day < 0:
		ending_day = TimeManager.day


func _on_letter(uid: String, letter_id: StringName, state: StringName) -> void:
	letter_log.append({"day": TimeManager.day, "uid": uid, "id": letter_id, "state": state})
	_t9("letter %s (%s) %s" % [letter_id, uid, state])


## The relationship changes of the main chain's endings (WhoKnows: reason „Ende: <e>").
func _on_rel9(npc_id: StringName, _value: int, _tier: StringName, delta: int, reason: String) -> void:
	if reason.begins_with(WhoKnows.REASON_CONFIDED.split("%")[0]) or reason == WhoKnows.REASON_WITNESS:
		ending_rel.append({"day": TimeManager.day, "npc": npc_id, "delta": delta, "reason": reason})


func _on_hill9(id: StringName, state: StringName) -> void:
	if hill.is_large(id):
		large_log.append("d%d %s %s" % [TimeManager.day, id, state])
		if state == HillRequests.STATE_COMPLETED and not large_done_ids.has(id):
			large_done_ids.append(id)
