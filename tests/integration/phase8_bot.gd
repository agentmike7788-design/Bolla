class_name Phase8Bot
extends Phase7Bot
## QA playthrough bot of Phase 8 (docs/PHASE8_DESIGN.md §10 "Playthrough-Bot", W3). Extends Phase7Bot by the
## Phase-8 day once p8_open is set (the Phase-7 day – corpses, building, gathering, the village trip through the
## real portals and DialogueRunner – stays as it is):
## - visitors: a waiting visitor is served between the tasks (the dialogue actions of the kin dialogue: tip_hand,
##   wish_offer, wish_accept with the visitor as the speaker); the accepted wishes are kept with the grave's real
##   care actions (GravePlot care menu: plant, water at the rain barrel, candle from 15:00, tend the care spots, a
##   line chiselled with ink); coins on a stone are taken (TipStone);
## - the apprentice: Rosine's story 1 hires Jakob (the villagers' dialogue through the runner), his rake from Esch
##   goes into his box, coins into the wage tin, the chalk board (ApprenticeBoard → set_board_lines), shown how to
##   rake and to weed („Schau zu" = apprentice_teach, then the job beside him);
## - friendship steps through the runner ([Geschichte] … step_accept) for the strategy's people; the steps' tasks:
##   flowers on Theres' graves, the register extract at the hut's desk (ink from the workbench), Esch's master's
##   grave tended, the parish archive with Lenz (16:00–18:00) or Fenner's key, meetings on the hill / in the inn;
## - Veit: alms at the gate or the bridge (dialogue action alms with him as the speaker), Hanne and the shops as
##   the strategy needs (seedlings, candles, a can, a rake, the mortsafe);
## - the festivals: the Kathreintanz in the Holderkrug (presence, two dances), the Lichtgang (Osric's twelve candles
##   and bought ones on the graves no family lights; on the hill from 15:00);
## - the nights: the watch spot at the sick light (real waiting, ≤ 12 m when the visitor comes out), night8 also at
##   the fresh grave (the robber notices him: flees, the second time he sits – reported / let go);
## - the third row (Fenner's grant through the runner, the obstacles cleared), the journal link i_underlined.
## Coin ledger: Phase 7 + income "tip", "peddler_sale"; spending reasons apprentice (the wage from the tin), alms,
## peddler. The coins of a day are purse + tin (the tin is the gravekeeper's money too).

const KIN_NPC := {&"kin_kehr": "npc_kin_kehr", &"kin_ott": "npc_kin_ott", &"kin_brandt": "npc_kin_brandt",
		&"kin_sieber": "npc_kin_sieber", &"kin_washer": "npc_washer_g", &"kin_smith": "npc_smith_g", &"kin_grocer": "npc_grocer_g"}
const WISH_KINDS: Array[StringName] = [&"flowers", &"tend", &"candle", &"line", &"vase"]
const VASE := &"decor_grave_vase"
const TIN_KEEP := 9
const TIN_FILL := 12
## Coins the purse keeps back from Phase-8 purchases (the next morning never below 5).
const RESERVE8 := 10
const ROW3 := &"linden_row3"
const GATE_STAND := Vector2(1.2, 8.3)
const LIGHTS_UP := 15 * 60
const KATHREIN_GO := 19 * 60 + 30
## The Phase-8 goods stay in the pack (never into the shed for room).
const P8_KEEP: Array[StringName] = [&"grave_candle", &"flower_seedlings", &"watering_can", &"mortsafe", &"register_extract",
		&"apprentice_rake", &"wax_wreath", &"lorenz_ledger_2", &"ink", &"seeds", &"decor_grave_vase"]

## Phase-8 flags on top of the Phase-7 ones:
## "p8": plays Phase 8 · "apprentice": takes Jakob · "wishes": accepts and keeps wishes · "tips": takes the tips
## (in the hand and on the stone) · "stories": the villagers whose friendship steps the bot takes · "alms": Veit ·
## "observe": the night visits it watches (path ids) · "robber": watches the fresh grave at night ("" = sleeps;
## "reported" / "let_go" = the outcome when he sits) · "mortsafe": a mortsafe on the freshest grave · "kathrein" ·
## "lights": candles at the Lichtgang · "save_p8": reloads once during a visit and once on the Lichtgang.
const P8_FLAGS := {"p8": true, "apprentice": true, "wishes": true, "tips": true,
		"stories": {&"mayor": 3, &"innkeeper": 1, &"smith": 1, &"priest": 2, &"grocer": 2}, "alms": true, "observe": [&"np_ott"],
		"robber": "", "mortsafe": true, "kathrein": true, "lights": true, "save_p8": false, "late": false}

static var P8_STRATEGIES := {
	&"kindly8": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {}),
	&"anatomist8": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {"anatomy": true, "collection": true, "lectures": false,
			"donations": false}, {"stories": {&"mayor": 3, &"innkeeper": 1, &"smith": 1, &"grocer": 2}, "mortsafe": false,
			"alms": true}),
	&"lazy8": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {"apprentice": false, "wishes": false, "stories": {},
			"mortsafe": false, "lights": false, "kathrein": false, "observe": []}),
	&"night8": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {"mortsafe": false, "lights": false,
			"observe": [&"np_ott", &"np_kehr"], "robber": "reported", "late": true,
			"save_robber": true}),
	&"night8b": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {"mortsafe": false, "lights": false,
			"observe": [&"np_ott", &"np_kehr"], "robber": "let_go", "late": true}),
	&"founder8": _with8({}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {}),
	&"save_load8": _with8({"save_load": true}, {}, {"optional": [&"crypt", &"chapel"]}, {}, {"save_p8": true}),
}

var visitors: Visitors
var gcare: GraveCare
var app: Apprentice
var friendship: Friendship
var life: NpcLife
var wanderers: Wanderers
var festivals: Festivals
var paths: NightPaths
var robber: NightRobber

## Phase-8 progress.
var open8_day: int = -1
var chapter8_day: int = -1
var lowest_morning_p8: int = 1 << 30
var start8_coins: int = -1
var spent_p8: int = 0
var served: Dictionary = {}
var visits_served: Array[Dictionary] = []
var wishes_taken: Array[Dictionary] = []
var tips_taken: int = 0
var jakob_days: Array[int] = []
var alms_days: Array[int] = []
var observed: Array[StringName] = []
var robber_log: PackedStringArray = []
## Planned visits of the day nobody talked to (counted in the evening, before the next plan).
var missed_visits: int = 0
var _missed_ids: Dictionary = {}
var dances: int = 0
var saved_moments: PackedStringArray = []
var trace8: PackedStringArray = []
var tin_deposited: int = 0
var _watching8: bool = false
var _refused8: Dictionary = {}
var _taught_day: int = 0
var _board_set: bool = false
var _kathrein_done: bool = false
var _lights_done: bool = false
var _evening_day: int = 0


static func _with8(p4: Dictionary, p5: Dictionary, p6: Dictionary, p7: Dictionary, p8: Dictionary) -> Dictionary:
	var out := _with7(p4, p5, p6, p7)
	# Phase 8 keeps the purse for the hill: no more rounds in the Holderkrug (Phase 7 bought its two).
	out["rounds"] = 0
	out.merge(P8_FLAGS.duplicate(true), true)
	out.merge(p8, true)
	return out


func _init(p_strategy: StringName, p_tree: SceneTree) -> void:
	super(p_strategy, p_tree)
	flags = flags.duplicate(true)
	income.merge({"tip": 0, "peddler_sale": 0})


func strategies() -> Dictionary:
	return P8_STRATEGIES


func bind() -> void:
	super.bind()
	visitors = world.get_node("Systems/Visitors") as Visitors
	gcare = world.get_node("Systems/GraveCare") as GraveCare
	app = world.get_node("Systems/Apprentice") as Apprentice
	friendship = world.get_node("Systems/Friendship") as Friendship
	life = world.get_node("Systems/NpcLife") as NpcLife
	wanderers = world.get_node("Systems/Wanderers") as Wanderers
	festivals = world.get_node("Systems/Festivals") as Festivals
	paths = world.get_node("Systems/NightPaths") as NightPaths
	robber = world.get_node("Systems/NightRobber") as NightRobber


func watch() -> void:
	super.watch()
	EventBus.wish_changed.connect(_on_wish)
	_watching8 = true


func unwatch() -> void:
	super.unwatch()
	if _watching8:
		EventBus.wish_changed.disconnect(_on_wish)
		_watching8 = false


func p8_open() -> bool:
	return flags.p8 and GameState.flag_on(&"p8_open")


## Purse + the wage tin.
func coins_total() -> int:
	return inv().count(&"coin") + _tin()


func _tin() -> int:
	var box := _box()
	return box.coins if box != null else 0


func _box() -> ApprenticeBox:
	return world.get_node_or_null("Entities/apprentice_box") as ApprenticeBox


# --- one day ------------------------------------------------------------------------------------

func run_day() -> void:
	if p8_open():
		if open8_day < 0:
			open8_day = TimeManager.day
			start8_coins = coins_total()
			_t8("open: coins %d · %s" % [coins_total(), _stock_text(inv())])
		lowest_morning_p8 = mini(lowest_morning_p8, coins_total())
		_t8("morning: coins %d (tin %d) · %s" % [coins_total(), _tin(), _stock_text(inv())])
	await super.run_day()


## Every walk between two tasks: a waiting visitor is served, coins on a stone are taken.
func _walk(minutes: int = WALK_MINUTES) -> void:
	super._walk(minutes)
	_serve()


## Phase 7's passes (with the village trip), then the Phase-8 evening (the dance, the night visits, the robber).
func _phase5() -> void:
	await super._phase5()
	if p8_open():
		await _p8_afternoon()
	# A night strategy (awake past midnight) has its evening at bedtime (_sleep) – here the rest of the day's
	# passes would run on into the next day.
	if p8_open() and _evening_day != TimeManager.day and not flags.late and String(flags.robber) == "":
		_evening_day = TimeManager.day
		await _p8_evening()


func _p7_tasks() -> void:
	await super._p7_tasks()
	if p8_open() and _time_left():
		await _p8_tasks()


## The Phase-8 work on the hill (morning and afternoon passes).
func _p8_tasks() -> void:
	if flags.lights and festivals.today() == Festivals.LIGHTS and not _lights_done and TimeManager.minute_of_day >= 14 * 60:
		_lights_done = true
		await _lights()
	await _visit_reload()
	_serve()
	_clear_row3()
	_jakob()
	_keep_wishes()
	_friend_tasks()
	_copy_extract()
	_close_disturbed()
	_take_stones()
	if flags.mortsafe:
		_mortsafe()
	if flags.alms:
		_alms_at_gate()
	_link()


## The work of the passes is done, but the afternoon still has Phase-8 business on the hill: visitors due later,
## a meeting on the hill (Fenner 2 at l_12, 15:55) – wait for it (serving on the way), then the tasks once more.
func _p8_afternoon() -> void:
	for i: int in 6:
		if not _time_left() or player.region_id != &"graveyard":
			return
		var until := maxi(_visits_due_before(_evening_cap()), _hill_meet_start())
		if until <= TimeManager.minute_of_day:
			return
		while TimeManager.minute_of_day < until and _time_left():
			TimeManager.advance(5)
			_serve()
		await _p8_tasks()


## The start (+2) of today's meeting on the hill that is still to come; 0 = none.
func _hill_meet_start() -> int:
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null or o.kind != &"meet" or not o.conditions.has("schedule_flag") \
				or int(GameState.get_flag(StringName(str(o.conditions.schedule_flag)), 0)) != TimeManager.day:
			continue
		var window: Array = o.conditions.get("window", [0, 0])
		if TimeManager.minute_of_day < int(window[1]):
			return int(window[0]) + 2
	return 0


## The day's work ends early for the evening's Phase-8 business: the Kathreintanz (19:20), a night visit to watch
## (50 minutes before it), the Lichtgang (14:00, the hill).
func _evening_cap() -> int:
	if not p8_open():
		return EVENING
	var cap := EVENING
	if flags.kathrein and festivals.today() == Festivals.KATHREIN and not _kathrein_done:
		cap = mini(cap, KATHREIN_GO - 10)
	for path_id: StringName in flags.observe:
		var visit := paths.next_visit(path_id, TimeManager.day, 0)
		if visit.is_empty():
			continue
		var enter := int(visit.enter) - (TimeManager.day - 1) * 1440
		if enter >= 600 and enter < 1440 and _observable(visit):
			cap = mini(cap, enter - 50)
	return cap


func _observable(visit: Dictionary) -> bool:
	var clue := StringName(str(visit.get("clue_id", "")))
	if clue != &"" and paths.observed(clue):
		return false
	var m := posmod(int(visit.enter), 1440)
	return bool(flags.late) or (m >= 20 * 60 and m < 23 * 60 + 30)


func _time_left() -> bool:
	return super._time_left() and TimeManager.minute_of_day < _evening_cap()


func _fits(minutes: int) -> bool:
	return super._fits(minutes) and TimeManager.minute_of_day + minutes <= _evening_cap()


## The village trip of Phase 7 – not on the Lichtgang (the hill from 15:00) nor on a day with a meeting on the hill.
func _village_today() -> bool:
	if p8_open():
		if flags.lights and festivals.fest_day(Festivals.LIGHTS) == TimeManager.day:
			return false
		if _hill_meeting_today():
			return false
	return super._village_today()


func _village_trip() -> void:
	if p8_open():
		# A visitor due before 16:00 is waited for on the hill (the wishes come from the talk at the grave).
		var until := _visits_due_before(16 * 60)
		while TimeManager.minute_of_day < until and _time_left():
			TimeManager.advance(5)
			_serve()
		if flags.alms:
			_alms_at_gate(true)
		if TimeManager.minute_of_day > LEAVE_VILLAGE - 90:
			return
	await super._village_trip()


## The latest minute (≤ `limit`) a planned visit of today is waiting at its grave; 0 = none due.
func _visits_due_before(limit: int) -> int:
	var latest := 0
	var vs := visitors.save_state()
	if int(vs.get("plan_day", -1)) != TimeManager.day:
		return 0
	for e: Variant in vs.get("plan", []):
		if not e is Dictionary or bool((e as Dictionary).get("ended", false)):
			continue
		var at := int((e as Dictionary).get("slot", 0)) + 8
		if at <= limit and at > TimeManager.minute_of_day:
			latest = maxi(latest, at)
	return latest


## Lenz is wanted for a friendship step too (Phase 7: first meeting, consecration, orders), or his step 3 read in the
## church after the Lichtgang.
func _priest_wanted() -> bool:
	if super._priest_wanted() or not p8_open():
		return super._priest_wanted()
	if _friend_ready(&"priest"):
		return true
	if orders.state(&"of_lenz_3") == &"accepted" and festivals.state(Festivals.LIGHTS) == Festivals.STATE_ENDED:
		return true
	return _wants_step(&"priest") and friendship.step_block_reason(&"priest") == "" and not rel.talked_today(&"priest")


## A friend order of `npc_id` can be turned in now (Phase 7 only looks at its own orders).
func _friend_ready(npc_id: StringName) -> bool:
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o != null and o.category == OrderData.CATEGORY_FRIEND and o.giver == npc_id \
				and DialogueConditions.order_ready(id, {"inventory": inv()}):
			return true
	return false


func _has_business(npc_id: StringName) -> bool:
	return super._has_business(npc_id) or (p8_open() and (_friend_ready(npc_id) or (_wants_step(npc_id) \
			and friendship.step_block_reason(npc_id) == "")))


## Room in the pack (Phase 7) – the Phase-8 goods stay in it.
func _free_slots(n: int) -> void:
	var empty := inv().get_slots().filter(func(sl: Dictionary) -> bool: return sl.is_empty() or String(sl.get("id", "")) == "").size()
	if empty >= n or buildings.level(&"shed") < 1 or player.carried_id != "" or player.region_id != &"graveyard":
		return
	var moves := {}
	for sl: Dictionary in inv().get_slots():
		if empty >= n:
			break
		if sl.is_empty() or String(sl.get("uid", "")) != "":
			continue
		var id := StringName(String(sl.get("id", "")))
		var item := Database.item(id) as ItemData
		if id == &"" or id in PACK_KEEP or id in P8_KEEP or item == null or item.category == ItemData.Category.TOOL or moves.has(id):
			continue
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
	_t8("shed: %s" % str(moves))


## Back up the hill – first the parish archive when Lenz' step 2 (16:00–18:00) or Fenner's key opens it.
func _travel(target: StringName) -> bool:
	if p8_open() and target == &"graveyard" and player.region_id == &"village":
		await _alms_in_village()
		await _archive()
		await _inn_meet()
	return await super._travel(target)


## Veit in the village (the church steps, the bridge, the well bench): the day's alms before going up.
func _alms_in_village() -> void:
	if not flags.alms or alms_days.has(TimeManager.day):
		return
	var place := wanderers.place(&"beggar", TimeManager.day, TimeManager.minute_of_day)
	if place == &"" or place == Wanderers.PLACE_GATE:
		return
	var veit := _vnpc(&"beggar")
	if veit == null:
		return
	await _leave_vroom()
	veit.refresh()
	if not veit.is_present():
		return
	player.global_position = veit.global_position + Vector3(1.0, 0, 0)
	_give_alms(veit)


## A meeting in the Holderkrug in the evening (Fenner 3: the table, 18:05–21:00): wait, go in, talk.
func _inn_meet() -> void:
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null or o.kind != &"meet" or not str(o.conditions.get("place", "")).begins_with("v_in_inn"):
			continue
		var window: Array = o.conditions.get("window", [0, 0])
		if TimeManager.minute_of_day > int(window[1]) - 30:
			continue
		await _leave_vroom()
		_wait_until(int(window[0]) + 2)
		var npc := _vnpc(o.giver)
		if npc == null:
			continue
		npc.refresh()
		if not await _enter_for(npc):
			continue
		_talk(npc)
		_t8("meet %s in the inn: %s" % [id, orders.state(id)])
		await _leave_vroom()


func _archive() -> void:
	if GameState.flag_on(&"archive_ledger_found") and orders.state(&"of_lenz_2") != &"accepted":
		return
	var with_lenz := orders.state(&"of_lenz_2") == &"accepted"
	if not with_lenz and not GameState.flag_on(&"archive_key"):
		return
	var m := TimeManager.minute_of_day
	if with_lenz and m < 960:
		if m < 900:
			return
		_wait_until(962)
	if TimeManager.minute_of_day > 1080 - 60:
		return
	await _leave_vroom()
	var door := HouseDoor.find(tree, &"door_church")
	player.global_transform = door.exit_transform()
	if not door.can_interact(player):
		problems.append("day %d: church shut for the archive (%s)" % [TimeManager.day, door.get_interaction_prompt(player)])
		return
	door.interact(player)
	await _until_arrived()
	var room := InteriorRoom.find(tree, &"church")
	var cabinet := room.get_node_or_null("Entities/ArchiveCabinet") as ArchiveCabinet if room != null else null
	if cabinet == null:
		problems.append("day %d: no archive cabinet" % TimeManager.day)
		return
	player.global_transform = Transform3D(Basis.IDENTITY, cabinet.to_global(Vector3(0, 0, 0.82)))
	if cabinet.can_interact(player):
		cabinet.interact(player)
		UIState.clear()
		_t8("archive (%s): ledger %s, clue %s" % [cabinet.access(), inv().has(&"lorenz_ledger_2"), journal.has_clue(&"c_n_kladde")])
	await _leave_vroom()


## An accepted meet order on the hill today (its giver comes up: Orders' schedule flag).
func _hill_meeting_today() -> bool:
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o != null and o.kind == &"meet" and o.conditions.has("schedule_flag") \
				and int(GameState.get_flag(StringName(str(o.conditions.schedule_flag)), 0)) == TimeManager.day:
			return true
	return false


# --- visitors -------------------------------------------------------------------------------------

func _on_hill() -> bool:
	return player.region_id == &"graveyard" and player.interior_id == &"" and not HutPortal.is_travelling(player) \
			and not is_instance_valid(player.carried) and not player.is_busy()


## Serves every waiting visitor once: the tip in the hand, a wish the strategy keeps. A visitor on the hill (coming up,
## laying flowers, mourning) is waited for – minute by minute, nothing skipped – until he waits at the grave (he only
## waits ten minutes for a word, VisitorConfig.wait_minutes).
## The slot (+1) of today's next planned visit not yet on its way and starting within `minutes`; 0 = none.
func _visit_starting_within(minutes: int) -> int:
	var vs := visitors.save_state()
	if int(vs.get("plan_day", -1)) != TimeManager.day:
		return 0
	var active := {}
	for v: Dictionary in visitors.active_visits():
		active[str(v.visit_id)] = true
	var best := 0
	for e: Variant in vs.get("plan", []):
		if not e is Dictionary:
			continue
		var d := e as Dictionary
		var id := str(d.get("visit_id", ""))
		var slot := int(d.get("slot", 0))
		if served.has(id) or active.has(id) or bool(d.get("ended", false)) or slot <= TimeManager.minute_of_day \
				or slot > TimeManager.minute_of_day + minutes:
			continue
		best = slot + 1 if best == 0 else mini(best, slot + 1)
	return best


## save_load8: once while a visitor is on the hill (on the way, mourning or waiting, not talked to yet) – saved,
## loaded, and the round trip must be identical (the visit then goes on as in kindly8).
func _visit_reload() -> void:
	if not flags.save_p8 or saved_moments.has("visit") or not _on_hill():
		return
	for v: Dictionary in visitors.active_visits():
		var ph := StringName(str(v.get("phase", "")))
		if not served.has(str(v.visit_id)) and ph != &"gone" and ph != &"leaving" and ph != &"":
			saved_moments.append("visit")
			await _reload_now("a visit (%s, %s)" % [v.kin_id, ph])
			return


func _serve() -> void:
	if not p8_open() or not _on_hill():
		return
	if flags.wishes or flags.tips:
		# A visitor due within half an hour is waited for (the talk window at the grave is ~40 minutes, §2.2).
		var due := _visit_starting_within(30)
		while due > 0 and TimeManager.minute_of_day < due and TimeManager.minute_of_day < EVENING:
			TimeManager.advance(1)
		for i: int in 90:
			var pending := false
			for v: Dictionary in visitors.active_visits():
				var ph := StringName(str(v.get("phase", "")))
				if not served.has(str(v.visit_id)) and ph != &"waiting" and ph != &"gone" and ph != &"leaving":
					pending = true
			if not pending:
				break
			TimeManager.advance(1)
	for v: Dictionary in visitors.active_visits():
		var id := str(v.visit_id)
		if StringName(str(v.get("phase", ""))) != &"waiting" or served.has(id):
			continue
		served[id] = true
		_serve_visit(v)
	if flags.tips:
		_take_stones()
	_jakob()


func _serve_visit(v: Dictionary) -> void:
	var kin := StringName(str(v.kin_id))
	var npc := world.get_node_by_layout_id(KIN_NPC.get(kin, "")) as Npc
	if npc == null:
		problems.append("day %d: no figure for %s" % [TimeManager.day, kin])
		return
	npc.refresh()
	player.global_position = npc.global_position + Vector3(1.2, 0, 0)
	var context := {"inventory": inv(), "speaker": npc, "player": player}
	var row := {"day": TimeManager.day, "kin": kin, "tip": 0, "wish": ""}
	if flags.tips and visitors.tip_of(str(v.visit_id)) > 0:
		var before := inv().count(&"coin")
		DialogueActions.run_all(["tip_hand"] as Array[String], context)
		row.tip = inv().count(&"coin") - before
	if flags.wishes:
		DialogueActions.run_all(["wish_offer"] as Array[String], context)
		var offer: Dictionary = context.get(DialogueActions.CONTEXT_WISH, {})
		if not offer.is_empty() and StringName(str(offer.kind)) in WISH_KINDS and _can_keep(offer):
			DialogueActions.run_all(["wish_accept"] as Array[String], context)
			row.wish = "%s@%s" % [offer.kind, offer.grave_id]
			wishes_taken.append({"day": TimeManager.day, "kin": kin, "kind": offer.kind, "grave": offer.grave_id})
		elif not offer.is_empty():
			_t8("wish declined: %s@%s" % [offer.get("kind", "?"), offer.get("grave_id", "?")])
	UIState.clear()
	visits_served.append(row)
	_t8("visit %s: tip %d, wish %s" % [kin, int(row.tip), row.wish])


## The strategy can keep the offered wish (ink for a line, a stone with room, seedlings or the coins for them).
func _can_keep(offer: Dictionary) -> bool:
	match StringName(str(offer.kind)):
		&"line":
			return inv().has(&"ink") or CraftingSystem.can_craft(Database.recipe(&"ink") as RecipeData, inv())
		&"flowers":
			return inv().has(&"flower_seedlings") or inv().count(&"coin") >= RESERVE8 + 2
		&"candle":
			return inv().has(&"grave_candle") or inv().count(&"coin") >= RESERVE8 + 1
		&"vase":
			# A grave vase from the workbench (1 stone, 1 seeds – Mangold sells the seeds).
			return inv().has(VASE) or (inv().count(&"stone") >= 1 and (inv().has(&"seeds") or inv().count(&"coin") >= RESERVE8 + 2))
	return true


## The accepted wishes: flowers set and watered, the care spots tended, a candle from 15:00, a line chiselled.
func _keep_wishes() -> void:
	if not _on_hill():
		return
	var targets: Array = []
	for w: Dictionary in visitors.open_wishes():
		if str(w.state) == "accepted":
			targets.append([StringName(str(w.kind)), str(w.grave_id)])
	for t: Array in targets:
		_keep_wish(t[0], t[1])


func _keep_wish(kind: StringName, grave_id: String) -> void:
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	if plot == null or not _time_left():
		return
	match kind:
		&"flowers":
			var state := gcare.flowers_state(grave_id)
			if state == &"":
				_care(plot, GravePlot.CARE_PLANT)
			elif state == GraveCare.FLOWERS_WILTED or (state == GraveCare.FLOWERS_FRESH and gcare.fresh_minutes_left(grave_id) <= 720):
				_care(plot, GravePlot.CARE_WATER)
		&"tend":
			for spot: DirtSpot in _spots_of(grave_id):
				_tend_spot(spot)
		&"candle":
			if TimeManager.minute_of_day >= gcare.get_config().candle_from_minute and not gcare.candle_lit(grave_id):
				_care(plot, GravePlot.CARE_CANDLE)
		&"line":
			if not inv().has(&"ink"):
				_craft5(&"workbench", &"ink")
			_care(plot, GravePlot.CARE_LINE)
		&"vase":
			if GraveView.has_vase(grave_id, tree):
				return
			if not inv().has(VASE):
				_craft(world.get_node_by_layout_id("workbench") as Workbench, VASE)
			if inv().has(VASE):
				var at := Vector2(plot.global_position.x, plot.global_position.z)
				var placed := _place_near(VASE, at, graveyard.section_of(grave_id))
				_t8("vase at %s: %s (%s)" % [grave_id, placed, GraveView.has_vase(grave_id, tree)])


## The grave's gcare action (the [E] choice of its gcare menu; instant timed action).
func _care(plot: GravePlot, action: StringName) -> bool:
	if action == GravePlot.CARE_WATER and not inv().has(gcare.get_config().can_item):
		return false
	_stand_at(plot)
	if action == GravePlot.CARE_WATER and gcare.can_fill() <= 0:
		_refill()
		_stand_at(plot)
	var state := plot._care_state(action, player)
	if state != 1:
		var key := "%s/%s" % [plot.grave_id, action]
		if not _refused8.has(key):
			_refused8[key] = true
			_t8("%s: %s not possible (%s)" % [plot.grave_id, action, plot.care_prompt(action, player)])
		return false
	_walk(2)
	plot._start_care(action, player)
	UIState.clear()
	return true


func _refill() -> void:
	var barrel := world.get_node_or_null("Entities/rain_barrel") as Node3D
	if barrel == null:
		problems.append("day %d: no rain barrel" % TimeManager.day)
		return
	player.global_position = barrel.global_position + barrel.global_basis.z * 0.9
	if barrel.call(&"can_interact", player):
		_walk(2)
		barrel.call(&"interact", player)
		UIState.clear()


func _stand_at(plot: Node3D) -> void:
	var p := plot.global_position + Vector3(0, 0, 1.6)
	player.global_position = Vector3(p.x, world.ground_height(Vector2(p.x, p.z)), p.z)


func _spots_of(grave_id: String) -> Array[DirtSpot]:
	var out: Array[DirtSpot] = []
	for n: Node in tree.get_nodes_in_group(&"dirt_spot"):
		if n is DirtSpot and (n as DirtSpot).grave_id == grave_id:
			out.append(n)
	return out


func _tend_spot(spot: DirtSpot) -> void:
	if clean.level(spot.spot_id) <= 0:
		return
	player.global_position = spot.global_position + Vector3(0.6, 0, 0)
	if spot.can_interact(player):
		_walk(2)
		spot.interact(player)
		UIState.clear()


## Coins on a stone (a visitor who did not wait): taken with [E] at the stone.
func _take_stones() -> void:
	if not flags.tips or not _on_hill():
		return
	for g: String in visitors.stones():
		var node := world.get_node_by_layout_id(g)
		var tip := node.get_node_or_null(^"TipStone") as TipStone if node != null else null
		if tip == null or not tip.can_interact(player):
			continue
		_stand_at(node as Node3D)
		var before := inv().count(&"coin")
		tip.interact(player)
		tips_taken += inv().count(&"coin") - before


func _close_disturbed() -> void:
	if not _on_hill():
		return
	for g: GraveRecord in graveyard.graves():
		if gcare.is_disturbed(g.id):
			if _care(world.get_node_by_layout_id(g.id) as GravePlot, GravePlot.CARE_CLOSE):
				_t8("closed the disturbed grave %s" % g.id)


# --- the third row ------------------------------------------------------------------------------------

func _clear_row3() -> void:
	if not GameState.flag_on(&"linden_row3_granted") or expansion.is_unlocked(ROW3) or not _on_hill():
		return
	for id: String in expansion.obstacle_ids(ROW3):
		if not _time_left():
			return
		if expansion.is_cleared(id):
			continue
		var node := expansion.obstacle(id)
		if node == null or not node.can_interact(player):
			if not _refused8.has(id):
				_refused8[id] = true
				_t8("row 3: %s refuses (%s %s)" % [id, expansion.missing_cost(id, inv()), expansion.tool_block_reason(id, inv())])
			continue
		_walk()
		node.interact(player)
		UIState.clear()
	if expansion.is_unlocked(ROW3):
		_t8("row 3 open")


# --- the apprentice -------------------------------------------------------------------------------------

func _jakob() -> void:
	if not flags.apprentice or not app.is_hired() or not _on_hill():
		return
	var box := _box()
	if box == null:
		problems.append("day %d: no apprentice box" % TimeManager.day)
		return
	# His tools into the box (the rake from Esch; a can when he waters).
	if inv().has(&"apprentice_rake") and not box.storage.has(&"apprentice_rake"):
		inv().remove_item(&"apprentice_rake", 1)
		box.storage.add_item(&"apprentice_rake", 1)
		_t8("the rake into Jakob's box")
	# The wage tin: three working days ahead, the purse keeps its reserve.
	if box.coins < TIN_KEEP:
		var n := mini(TIN_FILL - box.coins, inv().count(&"coin") - RESERVE8)
		if n > 0 and box.deposit(inv(), n):
			tin_deposited += n
			_t8("tin +%d → %d" % [n, box.coins])
	if not _board_set or app.board_lines().is_empty():
		var lines: Array[Dictionary] = [{"task": "rake", "area": "yard"}, {"task": "weed", "area": "linden"}]
		app.set_board_lines(lines)
		_board_set = true
		_t8("chalk board: rake yard · weed linden")
	if app.works_today(TimeManager.day) and not jakob_days.has(TimeManager.day):
		jakob_days.append(TimeManager.day)
	if _taught_day != TimeManager.day and app.on_graveyard():
		for task: StringName in [&"rake", &"weed"]:
			if app.level(task) == 0 and app.teach_block_reason(task, player) == "":
				_taught_day = TimeManager.day
				_teach(task)
				break


## „Schau zu": Jakob watches, the gravekeeper does the job at a place beside him.
func _teach(task: StringName) -> void:
	var kind := &"leaves" if task == &"rake" else &"weeds"
	var spot: DirtSpot = null
	var best := 1e9
	for n: Node in tree.get_nodes_in_group(&"dirt_spot"):
		var d := n as DirtSpot
		if d != null and d.kind == kind and clean.level(d.spot_id) > 0:
			var dist := Vector2(d.global_position.x - app.position_now().x, d.global_position.z - app.position_now().z).length()
			if dist < best:
				best = dist
				spot = d
	if spot == null:
		_t8("teach %s: no place" % task)
		return
	player.global_position = spot.global_position + Vector3(0.6, 0, 0)
	var jakob := world.get_node("Entities/npc_apprentice") as Npc
	DialogueActions.run_all(["apprentice_teach:" + String(task)] as Array[String], {"inventory": inv(), "speaker": jakob, "player": player})
	UIState.clear()
	if app.teaching() != task:
		_t8("teach %s refused (%s)" % [task, app.teach_block_reason(task, player)])
		return
	for i: int in 40:
		jakob.refresh()
		if Vector2(app.position_now().x - spot.global_position.x, app.position_now().z - spot.global_position.z).length() <= 2.5:
			break
		TimeManager.advance(1)
	jakob.refresh()
	if spot.can_interact(player):
		spot.interact(player)
		UIState.clear()
	_t8("taught %s → level %d" % [task, app.level(task)])


# --- friendship tasks ---------------------------------------------------------------------------------

## The tasks of the accepted friend orders the hill can do: flowers kept fresh, a grave tended.
func _friend_tasks() -> void:
	if not _on_hill():
		return
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null or o.category != OrderData.CATEGORY_FRIEND:
			continue
		match o.kind:
			&"tend":
				for g: String in _order_graves(o):
					_keep_wish(&"tend", g)
			&"task":
				if OrderRules.task_action(o) == &"flowers_fresh":
					for g: String in _order_graves(o):
						_keep_wish(&"flowers", g)
			&"meet":
				_hill_meet(o)


## The graves of a friend order: its target, or (kinless) the first graves without kin.
func _order_graves(o: OrderData) -> PackedStringArray:
	var out := PackedStringArray()
	if o.target != "" and graveyard.get_grave(o.target) != null:
		out.append(o.target)
		return out
	if bool(o.conditions.get("kinless", false)):
		var n := int(o.conditions.get("count", 3))
		for g: GraveRecord in graveyard.graves():
			if out.size() >= n:
				break
			if g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED] and visitors.kin_for_grave(g.id) == &"":
				out.append(g.id)
	return out


## A meeting on the hill: in its window the gravekeeper waits at the place and talks to the giver's figure.
func _hill_meet(o: OrderData) -> void:
	var flag := StringName(str(o.conditions.get("schedule_flag", "")))
	if flag == &"" or int(GameState.get_flag(flag, 0)) != TimeManager.day:
		return
	var window: Array = o.conditions.get("window", [0, 0])
	if TimeManager.minute_of_day > int(window[1]):
		_t8("meet %s on the hill missed (window %s)" % [o.id, str(window)])
		return
	_wait_until(int(window[0]) + 2)
	var npc_name := "npc_%s_g" % String(o.giver)
	var npc := world.get_node_or_null("Entities/" + npc_name) as Npc
	if npc == null:
		problems.append("day %d: no %s for %s" % [TimeManager.day, npc_name, o.id])
		return
	npc.refresh()
	if not npc.is_present():
		problems.append("day %d: %s not on the hill for %s" % [TimeManager.day, npc_name, o.id])
		return
	player.global_position = npc.global_position + Vector3(1.0, 0, 0)
	_talk(npc)
	_t8("meet %s on the hill: %s" % [o.id, orders.state(o.id)])


## The register extract for Lenz 1 / Theres 2 at the hut's desk (ink from the workbench).
func _copy_extract() -> void:
	var desk := world.find_child("desk", true, false) as Desk
	if desk == null or desk.extract_wanted_by(player) == "" or not _time_left():
		return
	if not inv().has(&"ink") and not _craft5(&"workbench", &"ink"):
		return
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var interior := tree.get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior
	_to_room(&"")
	if door.can_interact(player):
		HutPortal.arrive(player, interior.spawn_transform(), true)
	desk.interact(player)
	UIState.clear()
	_t8("register extract copied (%d)" % inv().count(&"register_extract"))
	_leave_hut()


# --- Veit, the mortsafe -------------------------------------------------------------------------------

## Veit at the gate (odd days 13:40–16:00): wait for him a few minutes before leaving for the village.
func _alms_at_gate(leaving: bool = false) -> void:
	if alms_days.has(TimeManager.day) or not _on_hill():
		return
	if wanderers.place(&"beggar", TimeManager.day, TimeManager.minute_of_day + (15 if leaving else 0)) != Wanderers.PLACE_GATE:
		return
	if leaving and not wanderers.present(&"beggar"):
		_wait_until(TimeManager.minute_of_day + 15)
	var veit := world.get_node_by_layout_id("npc_beggar_g") as Npc
	if veit == null or not wanderers.present(&"beggar"):
		return
	veit.refresh()
	player.global_position = veit.global_position + Vector3(1.0, 0, 0)
	_give_alms(veit)


func _give_alms(veit: Node) -> void:
	if wanderers.alms_block_reason(inv()) != "" or inv().count(&"coin") <= RESERVE8:
		return
	var before := wanderers.alms_count()
	DialogueActions.run_all(["alms"] as Array[String], {"inventory": inv(), "speaker": veit, "player": player})
	UIState.clear()
	if wanderers.alms_count() > before:
		alms_days.append(TimeManager.day)
		_t8("alms for Veit (%d)" % wanderers.alms_count())


## A mortsafe from Esch on the freshest grave without one (once the robber is known).
func _mortsafe() -> void:
	if not inv().has(gcare.get_config().mortsafe_item) or not _on_hill():
		return
	var best: GraveRecord = null
	for g: GraveRecord in graveyard.graves():
		if g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED] and not gcare.has_mortsafe(g.id):
			var r := manager.get_record(g.corpse_id) if g.corpse_id != "" else null
			if r != null and (best == null or r.buried_day > manager.get_record(best.corpse_id).buried_day):
				best = g
	if best != null and _care(world.get_node_by_layout_id(best.id) as GravePlot, GravePlot.CARE_MORTSAFE_ON):
		_t8("mortsafe on %s" % best.id)


# --- the village (Phase 7 trip + Phase 8) --------------------------------------------------------------

func _score(npc_id: StringName, c: DialogueChoice, visited: Dictionary) -> int:
	var best := super._score(npc_id, c, visited)
	if not p8_open():
		return best
	for a: String in c.actions:
		if visited.has("a:" + a):
			continue
		var key := a.get_slice(":", 0)
		var arg := StringName(a.get_slice(":", 1))
		match key:
			"step_accept":
				if _wants_step(arg) and friendship.step_block_reason(arg) == "":
					best = maxi(best, 88)
			"apprentice_hire":
				if flags.apprentice and not app.is_hired():
					best = maxi(best, 96)
			"meet", "task":
				best = maxi(best, 100)
			"set_flag":
				if arg == &"linden_row3_granted" and not GameState.flag_on(arg):
					best = maxi(best, 92)
			"alms":
				if flags.alms and not alms_days.has(TimeManager.day):
					best = maxi(best, 84)
			"listen":
				best = maxi(best, 40)
			"take_ware":
				best = maxi(best, 60)
	return best


## The strategy takes `npc`'s next friendship step (flags.stories: villager → how many steps).
func _wants_step(npc: StringName) -> bool:
	return (flags.stories as Dictionary).has(npc) and friendship.step_done(npc) < int(flags.stories[npc])


## Choices the strategy does not take (a friendship step of someone else, the apprentice for lazy8, a favour).
func _vetoed(c: DialogueChoice) -> bool:
	if not p8_open():
		return false
	for a: String in c.actions:
		var key := a.get_slice(":", 0)
		var arg := StringName(a.get_slice(":", 1))
		match key:
			"step_accept":
				if not _wants_step(arg):
					return true
			"buy_round":
				if _rounds >= int(flags.rounds):
					return true
			"order_accept":
				var o := orders.order_data(arg)
				if o != null and o.category == OrderData.CATEGORY_FRIEND:
					return true
			"apprentice_hire":
				if not flags.apprentice:
					return true
			"open_panel":
				if arg == &"favor":
					return true
			"favor_use", "robber_resolve":
				return true
	return false


func _pick7(dlg: DialogueData, npc_id: StringName, choices: Array[DialogueChoice], visited: Dictionary) -> int:
	var keep: Array[DialogueChoice] = []
	var index: Array[int] = []
	for i: int in choices.size():
		if not _vetoed(choices[i]):
			keep.append(choices[i])
			index.append(i)
	if keep.is_empty():
		return -1
	var k := super._pick7(dlg, npc_id, keep, visited)
	return index[k] if k >= 0 else -1


func _after_choice(npc_id: StringName, choice: DialogueChoice) -> void:
	super._after_choice(npc_id, choice)
	for a: String in choice.actions:
		var key := a.get_slice(":", 0)
		match key:
			"step_accept":
				_t8("step accepted: %s (%s)" % [a, friendship.step_order(StringName(a.get_slice(":", 1)))])
			"apprentice_hire":
				_t8("Jakob hired")
			"alms":
				if not alms_days.has(TimeManager.day):
					alms_days.append(TimeManager.day)


## What the strategy buys of a Phase-8 good now (Phase 7's needs first).
func _buy_need(item: StringName) -> int:
	var need := super._buy_need(item)
	if not p8_open():
		return need
	match item:
		&"apprentice_rake":
			if flags.apprentice and (app.is_hired() or (flags.stories as Dictionary).has(&"innkeeper")) and not inv().has(item) \
					and (_box() == null or not _box().storage.has(item)):
				need = maxi(need, 1)
		&"watering_can":
			if (flags.wishes or not (flags.stories as Dictionary).is_empty()) and not inv().has(item):
				need = maxi(need, 1)
		&"flower_seedlings":
			if flags.wishes or (flags.stories as Dictionary).has(&"grocer"):
				need = maxi(need, 4 - inv().count(item))
		&"seeds":
			var vases := visitors.open_wishes().filter(func(w: Dictionary) -> bool: return str(w.kind) == "vase").size()
			if flags.wishes and vases > 0:
				need = maxi(need, vases - inv().count(item) - inv().count(VASE))
		&"grave_candle":
			var want := 2 if flags.wishes else 0
			if flags.lights and festivals.fest_day(Festivals.LIGHTS) >= TimeManager.day:
				want = maxi(want, _lights_candles_needed())
			need = maxi(need, want - inv().count(item))
		&"mortsafe":
			if flags.mortsafe and GameState.flag_on(&"robber_known") and not inv().has(item) and inv().count(&"coin") >= RESERVE8 + 12:
				need = maxi(need, 1)
	return need


## Candles for every grave no family lights at the Lichtgang, less Osric's twelve.
func _lights_candles_needed() -> int:
	var family := {}
	for e: Dictionary in festivals.procession_plan():
		for gid: String in e.graves:
			family[gid] = true
	var n := 0
	for g: GraveRecord in graveyard.graves():
		if g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED] and not family.has(g.id):
			n += 1
	return maxi(0, n - 12)


# --- evening and night --------------------------------------------------------------------------------

func _night_at_the_wall() -> void:
	if p8_open() and _evening_day != TimeManager.day:
		_evening_day = TimeManager.day
		await _p8_evening()
	if TimeManager.minute_of_day >= 360 and TimeManager.minute_of_day < 23 * 60 + 20:
		await super._night_at_the_wall()


func _sleep() -> void:
	if p8_open() and _evening_day != TimeManager.day and TimeManager.minute_of_day >= 360:
		_evening_day = TimeManager.day
		await _p8_evening()
	if TimeManager.minute_of_day < 360:
		await _bed_after_midnight()
		return
	await super._sleep()


func _p8_evening() -> void:
	_t8("evening: fest %s, coins %d" % [festivals.today(), coins_total()])
	record_missed(TimeManager.day)
	if flags.lights and festivals.today() == Festivals.LIGHTS and not _lights_done:
		_lights_done = true
		await _lights()
	_keep_wishes()
	if flags.kathrein and festivals.today() == Festivals.KATHREIN and not _kathrein_done:
		_kathrein_done = true
		await _kathrein()
	for path_id: StringName in flags.observe:
		await _observe(path_id)
	if String(flags.robber) != "":
		await _robber_watch()
	# The later visits of the night (Liesel's Totenwache 02:40 – after the robber).
	for path_id: StringName in flags.observe:
		await _observe(path_id)


func _lights() -> void:
	_to_room(&"")
	_wait_until(LIGHTS_UP)
	var family := {}
	for e: Dictionary in festivals.procession_plan():
		for gid: String in e.graves:
			family[gid] = true
	for g: GraveRecord in graveyard.graves():
		if not inv().has(&"grave_candle"):
			break
		if g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED] and not family.has(g.id) and not gcare.candle_lit(g.id):
			_care(world.get_node_by_layout_id(g.id) as GravePlot, GravePlot.CARE_CANDLE)
	_t8("Lichtgang: lights %s" % festivals.lights_count())
	_wait_until(17 * 60 + 20)
	# Lenz 3: the names read beside him at the Kirchhof (17:40).
	if orders.state(&"of_lenz_3") == &"accepted":
		_wait_until(1061)
		var lenz := world.get_node_or_null("Entities/npc_priest") as Npc
		if lenz != null:
			lenz.refresh()
			player.global_position = lenz.global_position + Vector3(1.0, 0, 0)
			_talk(lenz)
			_t8("Lenz 3 at the Lichtgang: %s" % orders.state(&"of_lenz_3"))
	if flags.save_p8 and not saved_moments.has("lights"):
		saved_moments.append("lights")
		await _reload_now("the Lichtgang 17:20")
	_wait_until(18 * 60 + 40)
	_t8("Lichtgang result %s" % festivals.lights_result())


func _kathrein() -> void:
	if TimeManager.minute_of_day > 22 * 60:
		return
	_wait_until(KATHREIN_GO)
	if not await _travel(&"village"):
		return
	var door := HouseDoor.find(tree, &"door_inn")
	player.global_transform = door.exit_transform()
	if not door.can_interact(player):
		problems.append("day %d: the inn is shut at Kathrein" % TimeManager.day)
		await _travel(&"graveyard")
		return
	door.interact(player)
	await _until_arrived()
	for partner: StringName in [&"innkeeper", &"grocer"]:
		var npc := _vnpc(partner)
		if npc != null and festivals.dance_block_reason(partner) == "":
			DialogueActions.run_all(["dance:" + String(partner)] as Array[String], {"inventory": inv(), "speaker": npc, "player": player})
			UIState.clear()
			dances += 1
	# Presence counts per minute in the room (the festival ticks each minute).
	for i: int in 35:
		TimeManager.advance(1)
	_t8("Kathrein: danced %s, presence %s" % [str(festivals.danced()), festivals.presence_done()])
	await _leave_vroom()
	await _travel(&"graveyard")


## A night visit at the sick light: at the watch spot until the visitor comes out (real waiting, nothing skipped).
func _observe(path_id: StringName) -> void:
	var visit := paths.next_visit(path_id, TimeManager.day, TimeManager.minute_of_day)
	if visit.is_empty():
		return
	var clue := StringName(str(visit.get("clue_id", "")))
	if clue != &"" and paths.observed(clue):
		return
	var enter := int(visit.enter)
	# Only tonight (before 06:00 of the next day) and what the strategy stays up for.
	# After midnight "tonight" ends at 06:00 of this day (not of the next one).
	var night_end := TimeManager.day * 1440 + 360 if TimeManager.minute_of_day >= 360 else (TimeManager.day - 1) * 1440 + 360
	if enter > night_end or enter < TimeManager.total_minutes() or not _observable(visit):
		return
	var spot_id := &"watch_ott" if path_id == &"np_ott" else &"watch_kehr"
	var spot: WatchSpot = null
	for n: Node in world.find_children("*", "WatchSpot", true, false):
		if (n as WatchSpot).spot_id == spot_id:
			spot = n
	if spot == null:
		problems.append("day %d: no watch spot %s" % [TimeManager.day, spot_id])
		return
	while TimeManager.total_minutes() < enter - 40:
		TimeManager.advance(mini(20, enter - 40 - TimeManager.total_minutes()))
	if not await _travel(&"village"):
		return
	player.global_position = spot.global_position
	if not spot.can_interact(player):
		problems.append("day %d: watch spot refuses (%s)" % [TimeManager.day, spot.get_interaction_prompt(player)])
		await _travel(&"graveyard")
		return
	spot.interact(player)
	UIState.clear()
	while TimeManager.total_minutes() < int(visit.leave) + 1:
		TimeManager.advance(1)
	await tree.process_frame
	var seen: Array[StringName] = []
	for c: StringName in [&"c_n_quast_visit", &"c_n_lenz_visit", &"c_n_liesel_watch"]:
		if paths.observed(c) and not observed.has(c):
			observed.append(c)
			seen.append(c)
	_t8("watched %s (%s): %s" % [path_id, visit.npc_id, str(seen)])
	await _travel(&"graveyard")


## night8: at the fresh grave the robber comes for (decided at 00:00) – he notices the gravekeeper (≤ 10 m).
func _robber_watch() -> void:
	if robber.fate() != &"":
		return
	# After midnight already (a night visit watched): no waiting – _wait_until would run into the next night.
	if TimeManager.minute_of_day >= 360:
		_wait_until(23 * 60 + 50)
		TimeManager.advance(20)
	var night := TimeManager.day - 1
	var target := robber.tonight_target(night)
	if target == "":
		return
	var plot := world.get_node_by_layout_id(target) as Node3D
	_to_room(&"")
	player.global_position = plot.global_position + Vector3(3.0, 0, 2.0)
	for i: int in 300:
		var phase := robber.phase()
		if phase == &"fled" or phase == &"sitting" or (phase == &"" and i > 200):
			break
		# night8: saved and loaded once while Lambert is at the grave.
		if phase != &"" and flags.get("save_robber", false) and not saved_moments.has("robber"):
			saved_moments.append("robber")
			await _reload_now("the robber at %s (%s)" % [target, phase])
			plot = world.get_node_by_layout_id(target) as Node3D
			player.global_position = plot.global_position + Vector3(3.0, 0, 2.0)
		TimeManager.advance(1)
	robber_log.append("night %d: %s at %s (encounter %d)" % [night, robber.phase(), target, robber.encounters()])
	if robber.phase() == &"sitting":
		var npc := world.get_node_by_layout_id("npc_robber")
		DialogueActions.run_all(["robber_resolve:" + String(flags.robber)] as Array[String], {"inventory": inv(), "speaker": npc, "player": player})
		UIState.clear()
		robber_log.append("night %d: %s" % [night, robber.fate()])
	_t8(robber_log[robber_log.size() - 1])


## After midnight (a watch): straight to bed – the bed sleeps until 06:00.
func _bed_after_midnight() -> void:
	_to_room(&"")
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var interior := tree.get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior
	if door.can_interact(player):
		HutPortal.arrive(player, interior.spawn_transform(), true)
	var bed := interior.get_node("Entities/bed") as Bed
	var ended := TimeManager.day - 1
	if not bed.can_interact(player):
		problems.append("day %d: cannot sleep after midnight (%s)" % [ended, bed.get_interaction_prompt(player)])
		return
	bed.interact(player)
	UIState.clear()
	record_day(ended)
	if flags.save_load:
		var err: Error = await SaveManager.load_game(SaveManager.AUTOSAVE_SLOT)
		if err != OK:
			problems.append("day %d: autosave load failed %s" % [ended, error_string(err)])
		bind()


## save_load8: save, load, compare (bit-identical), bind again.
func _reload_now(moment: String) -> void:
	var before := SaveManager.collect_state()
	if SaveManager.save_game(SaveManager.AUTOSAVE_SLOT + 7) != OK:
		problems.append("day %d: cannot save at %s" % [TimeManager.day, moment])
		return
	var err: Error = await SaveManager.load_game(SaveManager.AUTOSAVE_SLOT + 7)
	if err != OK:
		problems.append("day %d: load at %s failed" % [TimeManager.day, moment])
		return
	bind()
	TimeManager.running = false
	UIState.clear()
	var after := SaveManager.collect_state()
	var diffs: PackedStringArray = []
	_diff(before, after, "", diffs)
	if not diffs.is_empty():
		problems.append("day %d: round trip at %s not identical: %s" % [TimeManager.day, moment, ", ".join(diffs.slice(0, 6))])
	_t8("saved and loaded at %s" % moment)


static func _diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if out.size() >= 6:
		return
	if a is Dictionary and b is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				out.append("%s/%s missing" % [path, str(k)])
			else:
				_diff(a[k], b[k], "%s/%s" % [path, str(k)], out)
		for k: Variant in b:
			if not (a as Dictionary).has(k):
				out.append("%s/%s new" % [path, str(k)])
		return
	if a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i: int in (a as Array).size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		return
	# Floats through the JSON save: equal up to the last bits.
	if a is float and b is float and absf(a - b) <= 1e-9 * maxf(1.0, absf(a)):
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("%s: %s → %s" % [path, str(a).left(60), str(b).left(60)])


# --- the journal --------------------------------------------------------------------------------------

## Phase 4's links, and i_underlined with its two of four (InsightData.any_clues).
func _link() -> void:
	for page: StringName in JournalManager.PAGES:
		EventBus.ui_panel_requested.emit(JournalManager.PANEL, journal.panel_context(page))
		UIState.clear()
	for insight: InsightData in journal.ready_insights():
		if insight.any_count > 0:
			continue
		var plain: Array[StringName] = []
		plain.assign(insight.requires)
		plain.reverse()  # order must not matter
		if journal.try_link(plain) != insight.id:
			problems.append("day %d: link %s refused" % [TimeManager.day, insight.id])
	var ins := journal.insight_by_id(&"i_underlined") as InsightData
	if ins == null or journal.has_insight(ins.id):
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
	if journal.try_link(ids) == ins.id:
		_t8("insight i_underlined (%s)" % str(ids))
	else:
		problems.append("day %d: i_underlined refused %s" % [TimeManager.day, str(ids)])


# --- the record ---------------------------------------------------------------------------------------

func _t8(what: String) -> void:
	trace8.append("d%d %s %s" % [TimeManager.day, TimeManager.format_clock(), what])


## The visits of `day` still planned and never talked to (evening; later visits of the day may still come).
func record_missed(day: int) -> void:
	var vs := visitors.save_state()
	if int(vs.get("plan_day", -1)) != day:
		return
	for e: Variant in vs.get("plan", []):
		if not e is Dictionary:
			continue
		var id := str((e as Dictionary).get("visit_id", ""))
		if served.has(id) or _missed_ids.has(id) or int((e as Dictionary).get("slot", 0)) + 60 > TimeManager.minute_of_day:
			continue
		_missed_ids[id] = true
		missed_visits += 1
		_t8("visit missed: %s at %s (%s)" % [(e as Dictionary).get("kin_id", ""), UIKit.clock(int((e as Dictionary).get("slot", 0))),
				str((e as Dictionary).get("graves", []))])


func record_day(day: int) -> void:
	if p8_open():
		var vs := visitors.save_state()
		# Only the plan of the recorded day (at 06:00 the new day's plan may already stand).
		if int(vs.get("plan_day", -1)) == day:
			for e: Variant in vs.get("plan", []):
				var vid := str((e as Dictionary).get("visit_id", "")) if e is Dictionary else ""
				if e is Dictionary and not served.has(vid) and not _missed_ids.has(vid):
					_missed_ids[vid] = true
					missed_visits += 1
					_t8("visit missed: %s at %s (%s)" % [(e as Dictionary).get("kin_id", ""), UIKit.clock(int((e as Dictionary).get("slot", 0))),
							str((e as Dictionary).get("graves", []))])
	super.record_day(day)
	var r: Dictionary = rows.back()
	r.merge({
		"coins8": coins_total(), "tin": _tin(), "open8": p8_open(), "chapter8": GameState.flag_on(&"who_comes_up_complete"),
		"visits": visits_served.filter(func(v: Dictionary) -> bool: return int(v.day) == day).size(),
		"wishes_done": visitors.done_wishes().size(), "wish_kin": visitors.done_kin_count(),
		"tips": int(income.get("tip", 0)), "steps": friendship.steps_total(), "full": friendship.full_stories(),
		"hired": app.is_hired(), "jlevels": {"rake": app.level(&"rake"), "weed": app.level(&"weed"), "water": app.level(&"water")},
		"jakob": app.works_today(day), "underlined": journal.has_insight(&"i_underlined"), "rep": rep.value(),
		"alms": wanderers.alms_count(),
	})


func table_p8() -> String:
	var lines := PackedStringArray(["| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends (Dose) | Besuche | Wünsche erf. (Angeh.) | Trinkgeld ges. | Schritte (voll) | Jakob (Rechen/Jäten) | Almosen | Erkenntnis | Ruf | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	var morning := start8_coins
	for r: Dictionary in rows:
		if not bool(r.get("open8", false)):
			continue
		var parts := PackedStringArray()
		var spent_day: Dictionary = r.get("spent_day", {})
		for reason: Variant in spent_day:
			parts.append("%s %d" % [reason, int(spent_day[reason])])
		var inc := PackedStringArray()
		var income_day: Dictionary = r.get("income_day", {})
		for source: Variant in income_day:
			inc.append("%s %d" % [source, int(income_day[source])])
		var lv: Dictionary = r.get("jlevels", {})
		lines.append("| %d | %d | %s | %s | %d (%d) | %d | %d (%d) | %d | %d (%d) | %s %d/%d | %d | %s | %d | %s |" % [r.day, morning,
				", ".join(parts) if not parts.is_empty() else "–", ", ".join(inc) if not inc.is_empty() else "–", int(r.coins8), int(r.tin),
				int(r.visits), int(r.wishes_done), int(r.wish_kin), int(r.tips), int(r.steps), int(r.full),
				"arbeitet" if bool(r.jakob) else ("frei" if bool(r.hired) else "–"), int(lv.get("rake", 0)), int(lv.get("weed", 0)),
				int(r.alms), "✓" if bool(r.underlined) else "–", int(r.rep), "✓" if bool(r.chapter8) else "offen"])
		morning = int(r.coins8)
	return "\n".join(lines)


func ledger_text() -> String:
	return super.ledger_text() + " · Phase 8: start %d (purse + tin), spent %d, tin deposited %d, tips %d (stone %d), lowest morning %d" % [
			start8_coins, spent_p8, tin_deposited, int(income.get("tip", 0)), tips_taken, lowest_morning_p8]


func _on_coins_spent(amount: int, reason: StringName) -> void:
	super._on_coins_spent(amount, reason)
	if p8_open():
		spent_p8 += amount


func _on_payment(coins: int, reason: String) -> void:
	var source := ""
	if reason == Visitors.PAYMENT_REASON:
		source = "tip"
	elif reason == VillageShops.PAYMENT_REASON_PEDDLER:
		source = "peddler_sale"
	if source != "":
		income[source] = int(income.get(source, 0)) + coins
		_income_day[source] = int(_income_day.get(source, 0)) + coins
		return
	super._on_payment(coins, reason)


func _on_chapter(chapter_id: StringName) -> void:
	super._on_chapter(chapter_id)
	if chapter_id == &"who_comes_up" and chapter8_day < 0:
		chapter8_day = TimeManager.day
		_t8("CHAPTER who_comes_up")


func _on_wish(wish_id: String, state: StringName) -> void:
	_t8("wish %s %s" % [wish_id, state])
