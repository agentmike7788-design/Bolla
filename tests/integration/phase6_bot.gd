class_name Phase6Bot
extends Phase5Bot
## QA playthrough bot of Phase 6 (docs/PHASE6_DESIGN.md §10 "Playthrough-Bot", W3). Extends
## Phase5Bot (the Phase-3/4/5 day) by the Phase-6 day once buildings_open is set:
## - Osric through the real DialogueRunner (p6_intro, altar candles: take_item:coin:…:osric);
## - the building sites through the real BuildingPanel (BuildingSite.interact → panel &"building",
##   „Stufe n bauen" → the timed action → Buildings.upgrade; with shed ≥ 2 „Fehlendes aus dem
##   Schuppen holen" on the panel's ShedFetchBar);
## - bone boxes at the workbench, old graves lifted (GravePlot.interact → Ossuary.lift) and the
##   boxes reinterred at the OssuaryShelf in the crypt; the walled door / grille looked at;
## - the corpses: bier → carried through the real BuildingDoor into the crypt → crypt table
##   (examination / preparation like Phase 4/5) or a cool niche (CryptNiche) → out through the
##   RoomExit → (Kirchpforte, procession) → chapel → Catafalque → the real ChapelPanel („Aussegnung
##   halten") → back to the grave dug before → burial → designed stone (stele) or simple marker;
## - devotions through the real DevotionPanel at the altar;
## - the shed: surplus stored through the chest panel's ChestTransfer, fetched again on the
##   building panel (shed ≥ 2).
## Portals: the doors' and exits' own rules (can_interact: carrying only where allows_corpse),
## then HutPortal.arrive like Phase3Bot's bed trip (no 0.5 s fade – the bot advances the clock by
## walking minutes instead). The procession costs PROCESSION_MINUTES (§1.3: ≈ 45 m hinauf), the way
## back to the grave GRAVE_MINUTES (≈ 25 m).
## Coin ledger: Phase 5 + income "reinter" (Umbettgeld), "service" (Aussegnung); spending by
## coins_spent reason incl. &"building"; spent_p6 = everything spent after buildings_open.

const PROCESSION_MINUTES := 45
const GRAVE_MINUTES := 25
const CRYPT_WALK := 6
## The old graves in the order of arc A (§1.4: old_04, old_06, old_07, then old_02, old_05, old_03).
const LIFT_ORDER: PackedStringArray = ["old_04", "old_06", "old_07", "old_02", "old_05", "old_03"]
## Coins kept after a mandatory build / after an optional one (level 3, §2.8 "nie arm").
const RESERVE6_NEEDED := 3
const RESERVE6_OPTIONAL := 10
## The service starts at the latest at service_start_max: leave the crypt before this.
const SERVICE_LEAVE_LATEST := 1020 - PROCESSION_MINUTES
const OSRIC_CANDLE_PRICE := 2

## Phase-6 flags on top of the Phase-5 ones:
## "p6": plays Phase 6 · "order": the building upgrades in order (a building id per level) ·
## "optional": upgrades after the chapter when the purse allows (RESERVE6_OPTIONAL) · "service":
## holds services · "devote": &"none" | &"calm" (calm ghosts, after the chapter) | &"restless"
## (restless first, any time) | &"robbed" (every robbed soul) · "devotions": at most this many in
## the run · "niche_first": every new corpse waits in a niche until the next morning (mortician) ·
## "niche_visit": once a look into the crypt while a corpse waits in a niche · "save_in_crypt":
## save → load there (save_load6).
const P6_FLAGS := {"p6": true, "service": true, "devote": &"calm", "devotions": 2, "niche_first": false,
		"order": [&"crypt", &"chapel", &"shed", &"crypt", &"shed", &"chapel"], "optional": [&"crypt"],
		"strict": true, "save_in_crypt": false, "niche_visit": false, "restone": false, "master_tools": false, "gold": 0}

static var P6_STRATEGIES := {
	&"reverent6": _with6({}, {}, {"niche_visit": true}),
	&"mortician": _with6({}, {}, {"niche_first": true, "devote": &"none", "devotions": 0,
			"order": [&"crypt", &"crypt", &"crypt", &"chapel", &"shed", &"shed", &"chapel"], "optional": []}),
	&"mender6": _with6({}, {"robbed_first": true}, {"devote": &"restless", "devotions": 8, "tend6": &"full",
			"order": [&"chapel", &"crypt", &"shed", &"chapel", &"crypt", &"shed"], "optional": []}),
	&"harvester6": _with6({"take_valuables": true, "prep": false, "gown": false, "balm": false,
			"harvest": [&"hair", &"teeth"], "decor": false}, {"loom_gowns": false}, {"devote": &"robbed", "devotions": 14,
			"optional": [&"crypt", &"chapel", &"shed"]}),
	&"founder": _with6({}, {}, {"keep_p5": true}),
	&"save_load6": _with6({"save_load": true}, {}, {"save_in_crypt": true, "niche_visit": true}),
}

var buildings: Buildings
var ossuary: Ossuary
var rites: ChapelRites

## Phase-6 progress.
var open6_day: int = -1
var chapter6_day: int = -1
var spent_p6: int = 0
var lowest_morning_p6: int = 1 << 30
var level_days: Dictionary = {}
var services: Array[Dictionary] = []
var devotions: Array[Dictionary] = []
var lifted_days: Dictionary = {}
var reinterred_days: Dictionary = {}
var niche_stays: Array[Dictionary] = []
var fetched: Dictionary = {}
var stored: Dictionary = {}
var procession_walks: int = 0
var saved_in_crypt: bool = false
## Exam results of the mortician: {corpse_id: {"lay_minutes", "lost", "freshness", "expected"}}.
var mortician_checks: Array[Dictionary] = []
## "d<day> <clock> <what>" – the Phase-6 actions (printed by the playthrough test).
var trace6: PackedStringArray = []
var _income_day: Dictionary = {}
var _watching6: bool = false
var _pending_niche: Dictionary = {}
var _visit_pending: bool = false
var _tended_day: int = -1
var _exam_only: bool = false


static func _with6(p4_overrides: Dictionary, p5_overrides: Dictionary, p6_overrides: Dictionary) -> Dictionary:
	var out := _with5(p4_overrides, p5_overrides)
	if not p6_overrides.get("keep_p5", false):
		out.merge(P6_FLAGS.duplicate(true), true)
	else:
		var p6 := P6_FLAGS.duplicate(true)
		for key: String in ["restone", "master_tools", "gold"]:
			p6.erase(key)
		out.merge(p6, true)
	out.merge(p6_overrides, true)
	return out


func _init(p_strategy: StringName, p_tree: SceneTree) -> void:
	super(p_strategy, p_tree)
	flags = flags.duplicate(true)
	income.merge({"reinter": 0, "service": 0})


func strategies() -> Dictionary:
	return P6_STRATEGIES


func bind() -> void:
	super.bind()
	buildings = world.get_node("Systems/Buildings") as Buildings
	ossuary = world.get_node("Systems/Ossuary") as Ossuary
	rites = world.get_node("Systems/Chapel") as ChapelRites


func watch() -> void:
	super.watch()
	EventBus.building_upgraded.connect(_on_upgraded)
	EventBus.funeral_held.connect(_on_funeral)
	EventBus.devotion_held.connect(_on_devotion)
	EventBus.bones_lifted.connect(_on_lifted)
	EventBus.bones_reinterred.connect(_on_reinterred)
	EventBus.shed_supply_moved.connect(_on_shed_moved)
	_watching6 = true


func unwatch() -> void:
	super.unwatch()
	if _watching6:
		EventBus.building_upgraded.disconnect(_on_upgraded)
		EventBus.funeral_held.disconnect(_on_funeral)
		EventBus.devotion_held.disconnect(_on_devotion)
		EventBus.bones_lifted.disconnect(_on_lifted)
		EventBus.bones_reinterred.disconnect(_on_reinterred)
		EventBus.shed_supply_moved.disconnect(_on_shed_moved)
		_watching6 = false


func p6_open() -> bool:
	return flags.p6 and buildings != null and buildings.is_open()


func crypt_level() -> int:
	return buildings.level(&"crypt")


# --- one day ------------------------------------------------------------------------------

func run_day() -> void:
	_income_day = {}
	if p6_open():
		if open6_day < 0:
			open6_day = TimeManager.day
			# §2.8 / §2.9: the Phase-5 extras (re-set stones, master tools, gold) end with Phase 6 –
			# the purse goes into the buildings.
			flags.restone = false
			flags.master_tools = false
			flags.gold = 0
			_t("open: inventory %s · chest %s · tools %s" % [_stock_text(inv()), _stock_text(_hut_chest()), str(shop.tiers())])
		lowest_morning_p6 = mini(lowest_morning_p6, inv().count(&"coin"))
		_t("morning: %s · shed %s" % [_stock_text(inv()), _stock_text(ShedSupply.shed_inventory(tree))])
	await super.run_day()


## Phase 5's tasks, then the Phase-6 passes (both interleaved with gathering).
func _phase5() -> void:
	if not p6_open():
		await super._phase5()
		return
	for pass_i: int in 16:
		if not _time_left():
			break
		_t("pass %d" % pass_i)
		var did := false
		did = _open_church_gate() or did
		did = _collect_kiln() or did
		did = _forge_work() or did
		did = _gather_for_next() or did
		did = _forge_work() or did
		did = _build6() or did
		if flags.niche_visit and not saved_in_crypt:
			await _visit_niche()
		did = _handle_corpses6() or did
		did = _boxes6() or did
		did = _lift6() or did
		did = _reinter6() or did
		did = _look_at_passage() or did
		did = _devotions6() or did
		# Iron is the bottleneck of the plan (§2.1): the forge before the long gathering rounds.
		did = _forge_work() or did
		did = _start_kiln() or did
		did = _gather_quarry() or did
		did = _forge_work() or did
		did = _gather_bruch() or did
		did = _gather_schlag() or did
		did = _gather_elder() or did
		did = _workbench5() or did
		did = _loom_work() or did
		did = _forge_work() or did
		did = _start_kiln() or did
		did = (await _stones()) or did
		if not did:
			break
	_store_surplus6()
	_to_room(&"")


## Phase 6: the building days need the hours – while an upgrade is still planned, only the spots
## with weeds (level ≥ 2) and once a day; the full round again when the plan is done.
## The mortician examines yesterday's corpse first thing in the morning (before the cart) and puts
## it back into the cold; the burial follows after today's corpse went into a niche.
func _gather() -> void:
	if p6_open() and flags.niche_first and crypt_level() >= 1:
		_leave_hut()
		_exam_only = true
		_handle_corpses6()
		_exam_only = false
		_to_room(&"")
	super._gather()


func _tend() -> void:
	var t0 := TimeManager.total_minutes()
	if not p6_open() or _next_build().is_empty() or flags.get("tend6", &"weeds") == &"full":
		super._tend()
	elif _tended_day != TimeManager.day:
		_tended_day = TimeManager.day
		for id: String in clean.spot_ids():
			if not _time_left():
				break
			if clean.level(id) < 2:
				continue
			var spot := world.get_node("Entities/" + id) as DirtSpot
			if spot != null and spot.can_interact(player):
				_to_room(&"")
				_walk(2)
				spot.interact(player)
	if p6_open():
		_t("tend %d min" % (TimeManager.total_minutes() - t0))


func _clear_obstacles() -> void:
	var t0 := TimeManager.total_minutes()
	super._clear_obstacles()
	if p6_open() and TimeManager.total_minutes() > t0:
		_t("clear %d min" % (TimeManager.total_minutes() - t0))


func _upgrade_markers() -> void:
	var t0 := TimeManager.total_minutes()
	super._upgrade_markers()
	if p6_open() and TimeManager.total_minutes() > t0:
		_t("markers %d min" % (TimeManager.total_minutes() - t0))


func _craft_essentials() -> void:
	var t0 := TimeManager.total_minutes()
	super._craft_essentials()
	if p6_open() and TimeManager.total_minutes() > t0:
		_t("essentials %d min" % (TimeManager.total_minutes() - t0))


## A full pack (Phase 6 adds boxes and candles): surplus to the shed first, else the craft waits.
func _craft5(station: StringName, recipe_id: StringName) -> bool:
	var r := Database.recipe(recipe_id) as RecipeData
	if p6_open() and r != null and not r.background and not _room_for(r):
		_store_surplus6(true)
		if not _room_for(r):
			_note_wait(recipe_id, "pack full (%d slots)" % inv().slot_count)
			return false
	return super._craft5(station, recipe_id)


## Room for the output once the inputs are taken (a probe copy).
func _room_for(r: RecipeData) -> bool:
	var probe := inv().duplicate(Node.DUPLICATE_SCRIPTS) as Inventory
	probe.load_state(inv().save_state())
	for id: StringName in r.inputs:
		probe.remove_item(id, int(r.inputs[id]))
	var ok := probe.add_item(r.output_id, r.output_amount) == 0
	probe.free()
	return ok


func _sleep() -> void:
	_to_room(&"")
	await super._sleep()


# --- rooms ------------------------------------------------------------------------------------

func _room_node(id: StringName) -> InteriorRoom:
	return InteriorRoom.find(tree, id)


## Into room `id` (&"" = outside) through the real door / exit rules; false = refused.
func _to_room(id: StringName) -> bool:
	if player.interior_id == id:
		return true
	if player.interior_id != &"" and player.interior_id != &"hut":
		var here := _room_node(player.interior_id)
		var exits := here.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit) if here != null else []
		if exits.is_empty() or not (exits[0] as RoomExit).can_interact(player):
			problems.append("day %d: cannot leave %s (%s)" % [TimeManager.day, player.interior_id,
					(exits[0] as RoomExit).get_interaction_prompt(player) if not exits.is_empty() else "no exit"])
			return false
		var door_out := BuildingDoor.find(tree, (exits[0] as RoomExit).building_id)
		HutPortal.arrive(player, door_out.exit_transform(), false)
	elif player.interior_id == &"hut":
		_leave_hut()
	if id == &"":
		return true
	var door := BuildingDoor.find(tree, id)
	if door == null or not door.can_interact(player):
		problems.append("day %d: cannot enter %s (%s)" % [TimeManager.day, id, door.get_interaction_prompt(player) if door != null else "no door"])
		return false
	_go(&"hut")
	_walk(CRYPT_WALK if id == &"crypt" else WALK_MINUTES)
	var room := door.room()
	HutPortal.arrive(player, room.spawn_transform(), true, room.room_id)
	if not room.active:
		problems.append("day %d: room %s not active after entering" % [TimeManager.day, id])
	return true


# --- the table ----------------------------------------------------------------------------------

## The active morgue table: the old one in front of the hut until crypt 1, then the crypt table.
func _table() -> MorgueTable:
	if crypt_level() < 1:
		return super._table()
	return _room_node(&"crypt").get_node("Entities/MorgueTable") as MorgueTable


# --- corpses (crypt ≥ 1) ------------------------------------------------------------------------

func _handle_corpses() -> void:
	if not p6_open() or crypt_level() < 1:
		super._handle_corpses()
		return
	_handle_corpses6()
	_to_room(&"")


## Every unburied corpse, oldest first; true = something happened.
func _handle_corpses6() -> bool:
	if not p6_open() or crypt_level() < 1:
		return false
	var list := manager.records().filter(func(r: CorpseRecord) -> bool: return r.location != CorpseRecord.LOCATION_BURIED)
	list.sort_custom(func(a: CorpseRecord, b: CorpseRecord) -> bool: return a.arrival_total_minutes < b.arrival_total_minutes)
	if flags.niche_first:
		# The mortician: today's corpse into the cold first, then yesterday's on the table.
		list.reverse()
	var did := false
	for record: CorpseRecord in list:
		if not _time_left():
			break
		did = _process6(record) or did
	return did


## One corpse: down into the crypt, the table work, then the grave (with a service when the
## strategy holds one and the day allows it) – or a cool niche to wait.
func _process6(record: CorpseRecord) -> bool:
	var before := [record.location, record.room, record.slot_id, record.service_held]
	var start_loc := record.location
	var table := _table()
	# 1. Into the crypt (bier, ground outside).
	if record.location == CorpseRecord.LOCATION_DROPOFF or (record.location == CorpseRecord.LOCATION_GROUND and record.room == &""):
		if not _to_room(&""):
			return false
		_walk()
		manager.get_corpse_node(record.id).interact(player)
		if player.carried_id != record.id:
			problems.append("day %d: %s not picked up" % [TimeManager.day, record.id])
			return false
		if not _to_room(&"crypt"):
			return false
		var fresh_today := Phase4Bot._arrival_day(record) >= TimeManager.day
		if (flags.niche_first and fresh_today) or table.corpse_id != "":
			if not _into_niche(record):
				if table.corpse_id == "":
					table.interact(player)
		else:
			table.interact(player)
		if player.carried_id == record.id:
			problems.append("day %d: nowhere to put %s in the crypt" % [TimeManager.day, record.id])
			return false
	if record.location == CorpseRecord.LOCATION_NICHE:
		if _visit_pending:
			return false  # waits for the look round the crypt (_visit_niche)
		if flags.niche_first and (Phase4Bot._arrival_day(record) >= TimeManager.day or (record.examined and _exam_only)):
			return before != [record.location, record.room, record.slot_id, record.service_held]
		if table.corpse_id != "" or not _wants_today(record):
			return before != [record.location, record.room, record.slot_id, record.service_held]
		_out_of_niche(record)
		table.interact(player)
	if record.location == CorpseRecord.LOCATION_TABLE:
		if not _to_room(&"crypt"):
			return false
		_work_at_table(record, table)
		if _exam_only:
			table.interact(player)
			UIState.clear()
			table.request_pick_up()
			if not _into_niche(record):
				table.interact(player)
			return true
		if flags.niche_visit and not saved_in_crypt and not _visit_pending and _plot_for(record) != null:
			# reverent6 / save_load6: the corpse waits in a niche while the gravekeeper looks round the
			# crypt (save_load6 saves and loads there) – then on as usual.
			table.interact(player)
			UIState.clear()
			table.request_pick_up()
			if _into_niche(record):
				_visit_pending = true
				_t("%s waits in %s for the look round" % [record.id, record.slot_id])
				return true
			table.interact(player)
		if not _wants_today(record):
			# Cooler in the niche than on the table (§2.2), and the table is free for the next one.
			table.interact(player)
			UIState.clear()
			table.request_pick_up()
			if not _into_niche(record):
				table.interact(player)
			return true
		_bury6(record, table)
	elif record.location == CorpseRecord.LOCATION_CATAFALQUE:
		_bury6(record, table)
	if before != [record.location, record.room, record.slot_id, record.service_held]:
		_t("%s %s → %s %s (fresh %.2f, service %s)" % [record.id, start_loc, record.location, record.slot_id, record.freshness, record.service_held])
	return before != [record.location, record.room, record.slot_id, record.service_held]


## The Phase-4/5 table work (exam, valuables, harvest, preparation, dress); the mortician checks
## the decay loss against the cold formula first.
func _work_at_table(record: CorpseRecord, table: MorgueTable) -> void:
	table.interact(player)
	UIState.clear()
	var check := {}
	if flags.niche_first and not record.examined:
		check = _mortician_check(record)
	_on_table(record, table)
	UIState.clear()
	if not check.is_empty():
		check["lost"] = record.finds_lost.size()
		mortician_checks.append(check)


## Free hands → bury today: a plot to dig, and time for it (with the service when wanted).
func _wants_today(record: CorpseRecord) -> bool:
	if _plot_for(record) == null:
		return false
	var need := 35 + 20 + GRAVE_MINUTES + 2 * CRYPT_WALK + 60
	if flags.service and not record.service_held and (rites.level() >= 1 or _chapel_next()):
		if _service_wanted(record) and TimeManager.minute_of_day + 35 + 2 * CRYPT_WALK <= SERVICE_LEAVE_LATEST \
				and _fits(need + PROCESSION_MINUTES + rites.get_config().service_minutes):
			return true
		# A service later today (the chapel is built first) or tomorrow, while the corpse stays
		# fresh enough for one in the niche.
		if _fresh_enough_tomorrow(record):
			return false
	return _fits(need)


## Freshness tomorrow at 10:00 in a niche ≥ the service minimum (+ a margin).
func _fresh_enough_tomorrow(record: CorpseRecord) -> bool:
	var t := Database.corpse_tables() as CorpseTables
	manager.refresh_decay(record.id)
	var hours := float(1440 - TimeManager.minute_of_day + 600) / 60.0
	var factor := manager.cold_factor_for(CorpseRecord.LOCATION_NICHE, &"crypt")
	return record.freshness - CorpseDecay.decay_per_hour(record, t) * hours * factor >= rites.get_config().service_min_freshness + 0.05


func _service_wanted(record: CorpseRecord) -> bool:
	if not flags.service or record.service_held or rites.level() < 1:
		return false
	var cfg := rites.get_config()
	manager.refresh_decay(record.id)
	return inv().count(cfg.candle_item) >= cfg.candle_amount and ChapelRules.is_dressed(record) \
			and record.freshness >= cfg.service_min_freshness + 0.05


## A lifted (EMPTY / DUG) place for `record` (another unburied corpse may hold the dug one).
func _plot_for(_record: CorpseRecord) -> GravePlot:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.DUG:
			return world.get_node_by_layout_id(g.id) as GravePlot
	return _free_plot()


func _into_niche(record: CorpseRecord) -> bool:
	for i: int in range(1, 7):
		var niche := CryptNiche.find(tree, "niche_%d" % i)
		if niche != null and niche.is_open() and niche.occupant() == "" and niche.can_interact(player):
			niche.interact(player)
			if record.location == CorpseRecord.LOCATION_NICHE:
				_pending_niche[record.id] = TimeManager.total_minutes()
				return true
	return false


func _out_of_niche(record: CorpseRecord) -> void:
	_to_room(&"crypt")
	var niche := CryptNiche.find(tree, record.slot_id)
	if niche == null or not niche.can_interact(player):
		problems.append("day %d: niche %s refuses %s" % [TimeManager.day, record.slot_id, record.id])
		return
	niche.interact(player)
	if _pending_niche.has(record.id):
		niche_stays.append({"id": record.id, "minutes": TimeManager.total_minutes() - int(_pending_niche[record.id])})
		_pending_niche.erase(record.id)


## Dig (hands free) → corpse from the table → (procession + service) → bury → stone.
func _bury6(record: CorpseRecord, table: MorgueTable) -> void:
	var plot := _plot_for(record)
	if plot == null:
		problems.append("day %d: no plot for %s" % [TimeManager.day, record.id])
		return
	if inv().count(&"gravestone_simple") + inv().count(&"wooden_cross") == 0 and not _stele_possible():
		_craft_essentials()
	if graveyard.get_grave(plot.grave_id).state == GraveRecord.State.EMPTY:
		if player.carried_id != "":
			problems.append("day %d: carrying while digging" % TimeManager.day)
			return
		_to_room(&"")
		_walk()
		plot.interact(player)
		if graveyard.get_grave(plot.grave_id).state != GraveRecord.State.DUG:
			problems.append("day %d: could not dig %s (%s)" % [TimeManager.day, plot.grave_id, plot.get_interaction_prompt(player)])
			return
	if record.location == CorpseRecord.LOCATION_TABLE:
		_to_room(&"crypt")
		table.interact(player)
		UIState.clear()
		table.request_pick_up()
	elif record.location == CorpseRecord.LOCATION_NICHE:
		_out_of_niche(record)
	elif record.location == CorpseRecord.LOCATION_CATAFALQUE:
		_to_room(&"chapel")
		_catafalque().interact(player)
	if player.carried_id != record.id:
		problems.append("day %d: %s not carried to the grave (%s)" % [TimeManager.day, record.id, record.location])
		return
	if _service_wanted(record) and TimeManager.minute_of_day + CRYPT_WALK <= SERVICE_LEAVE_LATEST:
		_service6(record)
	if player.carried_id != record.id:
		return
	_to_room(&"")
	_walk(GRAVE_MINUTES if record.service_held else WALK_MINUTES)
	plot.interact(player)
	if graveyard.get_grave(plot.grave_id).state != GraveRecord.State.FILLED:
		problems.append("day %d: could not bury %s in %s" % [TimeManager.day, record.id, plot.grave_id])
		return
	_mark6(plot)


## Carried → out of the crypt → Kirchpforte → chapel → catafalque → the chapel panel → back in the arms.
func _service6(record: CorpseRecord) -> void:
	if not _to_room(&""):
		return
	_walk(PROCESSION_MINUTES)
	procession_walks += 1
	if not _to_room(&"chapel"):
		return
	var catafalque := _catafalque()
	if not catafalque.can_interact(player):
		problems.append("day %d: catafalque refuses (%s)" % [TimeManager.day, catafalque.get_interaction_prompt(player)])
		return
	catafalque.interact(player)
	if record.location != CorpseRecord.LOCATION_CATAFALQUE:
		problems.append("day %d: %s not on the catafalque" % [TimeManager.day, record.id])
		return
	var altar := _altar()
	var prompt := altar.get_interaction_prompt(player)
	if not prompt.begins_with("[E] Aussegnung halten"):
		problems.append("day %d: altar prompt %s" % [TimeManager.day, prompt])
	altar.interact(player)
	var panel := ui.get_panel(&"chapel") as ChapelPanel if ui != null else null
	if panel == null or not panel.is_open:
		problems.append("day %d: chapel panel did not open" % TimeManager.day)
	elif panel.block_reason() != "" or panel.service_button.disabled:
		problems.append("day %d: chapel panel refuses %s: %s" % [TimeManager.day, record.id, panel.block_reason()])
	else:
		panel.service_button.pressed.emit()
	UIState.clear()
	if not record.service_held:
		problems.append("day %d: no service for %s" % [TimeManager.day, record.id])
	catafalque.interact(player)


## Stele (with inscription when there is ink) through the stone panel, else the simple marker.
func _mark6(plot: GravePlot) -> void:
	var grave_id := plot.grave_id
	if _stele_possible() and _fits(60 + WALK_MINUTES):
		var d := _design_for(grave_id, &"stone_stele")
		if masonry.order_block_reason(grave_id, d, inv()) == "":
			var order := _carve_with_panel(grave_id, d)
			if order != "":
				_walk()
				plot.interact(player)
				UIState.clear()
	if graveyard.get_grave(grave_id).state == GraveRecord.State.FILLED:
		if inv().count(&"gravestone_simple") + inv().count(&"wooden_cross") == 0:
			_craft_essentials()
		if inv().count(&"gravestone_simple") > 0 and inv().count(&"wooden_cross") > 0:
			plot.interact(player)
			UIState.clear()
			plot.request_marker(&"gravestone_simple")
		else:
			plot.interact(player)
		UIState.clear()
	if graveyard.get_grave(grave_id).state != GraveRecord.State.MARKED:
		problems.append("day %d: no marker on %s" % [TimeManager.day, grave_id])


func _stele_possible() -> bool:
	return shop.is_built(&"mason") and inv().count(&"stone") >= 4 + _stone_keep6()


func _catafalque() -> Catafalque:
	return _room_node(&"chapel").get_node("Entities/Catafalque") as Catafalque


func _altar() -> ChapelAltar:
	return _room_node(&"chapel").get_node("Entities/ChapelAltar") as ChapelAltar


## The mortician examines the morning after: no find lost to decay after ≤ 20 h in the niche, and
## the freshness on the clock = the cold-window formula (§2.2).
func _mortician_check(record: CorpseRecord) -> Dictionary:
	var t := Database.corpse_tables() as CorpseTables
	var rate := CorpseDecay.decay_per_hour(record, t)
	var balm := (Database.config(&"prep_config") as PrepConfig).balm_factor
	manager.refresh_decay(record.id)
	var now := TimeManager.total_minutes()
	var expected := CorpseDecay.freshness_at(record, now, rate, balm)
	# The same by hand: Σ minutes × the cold factor of each window (no juniper on these corpses).
	var by_hand := float(now - record.arrival_total_minutes)
	var w := record.cold_windows
	for i: int in range(0, w.size() - 2, 3):
		var end := now if w[i + 1] < 0 else w[i + 1]
		by_hand -= (1.0 - float(w[i + 2]) / 1000.0) * float(end - w[i])
	var hand_fresh := maxf(0.0, CorpseDecay.START_FRESHNESS - rate * by_hand / 60.0)
	return {"id": record.id, "lay_minutes": now - record.arrival_total_minutes, "lost": 0, "balm": not record.balm_windows.is_empty(),
			"crypt": crypt_level(), "decay_mult": rate / t.base_decay_per_hour,
			"freshness": record.freshness, "expected": expected, "by_hand": hand_fresh}


# --- buildings ----------------------------------------------------------------------------------

## The upgrades the strategy wants next, in its order: per building the next planned level
## ({id, level, optional}); the optional ones (level 3) only after the chapter.
func _build_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var planned := {}
	var seen := {}
	for id: StringName in flags.order:
		planned[id] = int(planned.get(id, 0)) + 1
		if buildings.level(id) < int(planned[id]) and not seen.has(id):
			seen[id] = true
			out.append({"id": id, "level": buildings.level(id) + 1, "optional": false})
	if not out.is_empty() or not GameState.has_flag(&"roof_and_earth_complete"):
		return out
	for id: StringName in flags.optional:
		if buildings.level(id) < 3:
			out.append({"id": id, "level": buildings.level(id) + 1, "optional": true})
	return out


## The first wanted upgrade ({} = none left).
func _next_build() -> Dictionary:
	var c := _build_candidates()
	return c[0] if not c.is_empty() else {}


## Inputs (items) of the next planned upgrade ({} = none).
func _next_inputs() -> Dictionary:
	var nb := _next_build()
	if nb.is_empty():
		return {}
	var lvl := (buildings.building(nb.id) as BuildingData).level_data(int(nb.level))
	return lvl.inputs if lvl != null else {}


## The first wanted upgrade that the purse and the stock (or the shed) allow now – in the
## strategy's order; a later, cheaper one goes first while the earlier waits for its coins.
func _build6() -> bool:
	for nb: Dictionary in _build_candidates():
		if _try_build(nb):
			return true
		if flags.get("strict", false):
			break
	return false


## The items the first wanted upgrade still lacks, gathered first (before the long rounds), so the
## build fits into the day.
func _gather_for_next() -> bool:
	var nb := _next_build()
	if nb.is_empty():
		return false
	var lvl := (buildings.building(nb.id) as BuildingData).level_data(int(nb.level))
	if lvl == null or inv().count(&"coin") - lvl.coins < (RESERVE6_OPTIONAL if nb.optional else RESERVE6_NEEDED):
		return false
	var gaps := ShedSupply.shortfall(lvl.inputs, inv())
	var shed := ShedSupply.shed_inventory(tree)
	if shed != null and buildings.level(&"shed") >= 1:
		gaps = ShedSupply._shed_lacking(gaps, shed)
	if gaps.is_empty():
		return false
	var wanted := func(item: StringName) -> bool: return gaps.has(item) and inv().count(item) < int(lvl.inputs.get(item, 0))
	var did := false
	if expansion.is_unlocked(&"quarry"):
		did = _gather_at(QUARRY_NODES, &"bruch", wanted) or did
	if expansion.is_unlocked(&"bruch"):
		did = _gather_at(BRUCH_NODES, &"bruch", wanted) or did
	if player.tool_tier(&"axe") >= 1:
		did = _gather_at(SCHLAG_ALDERS, &"schlag", wanted) or did
	_t("gathered for %s %d: gaps %s → %s" % [nb.id, nb.level, str(gaps), str(ShedSupply.shortfall(lvl.inputs, inv()))])
	return did


func _try_build(nb: Dictionary) -> bool:
	var id: StringName = nb.id
	var site := world.get_node("Entities/site_" + String(id)) as BuildingSite
	var next := BuildingRules.next_level(site.building_data(), buildings.level(id))
	if next == null:
		return false
	var reserve := RESERVE6_OPTIONAL if nb.optional else RESERVE6_NEEDED
	if inv().count(&"coin") - next.coins < reserve:
		_note_wait(id, "coins %d < %d + %d" % [inv().count(&"coin"), next.coins, reserve])
		return false
	if not _fits(next.minutes + WALK_MINUTES):
		_note_wait(id, "no time")
		return false
	# Shed 1: take what is missing out of the shed by hand (chest panel); shed ≥ 2: the panel's fetch.
	var gaps := ShedSupply.shortfall(next.inputs, inv())
	if not gaps.is_empty() and buildings.level(&"shed") == 1:
		_withdraw(gaps)
		gaps = ShedSupply.shortfall(next.inputs, inv())
	var shed := ShedSupply.shed_inventory(tree)
	if not gaps.is_empty() and (buildings.level(&"shed") < 2 or shed == null or not ShedSupply._shed_lacking(gaps, shed).is_empty()):
		_note_wait(id, "lacks %s" % str(gaps))
		return false
	_to_room(&"")
	_go(&"hut")
	_walk()
	if not site.can_interact(player):
		problems.append("day %d: site %s refuses (%s)" % [TimeManager.day, id, site.get_interaction_prompt(player)])
		return false
	site.interact(player)
	var panel := ui.get_panel(&"building") as BuildingPanel if ui != null else null
	if panel == null or not panel.is_open:
		problems.append("day %d: building panel did not open" % TimeManager.day)
		UIState.clear()
		return false
	if not gaps.is_empty():
		if panel.shed_bar == null or not panel.shed_bar.visible or panel.shed_bar.fetch_button.disabled:
			problems.append("day %d: fetch for %s not offered (%s)" % [TimeManager.day, id, ShedSupply.fetch_reason_for(tree, player, next.inputs)])
			UIState.clear()
			return false
		panel.shed_bar.fetch_pressed.emit()
	if panel.block_reason() != "" or panel.build_button.disabled:
		problems.append("day %d: building panel refuses %s: %s" % [TimeManager.day, id, panel.block_reason()])
		UIState.clear()
		return false
	var before := buildings.level(id)
	panel.build_button.pressed.emit()
	UIState.clear()
	if buildings.level(id) != before + 1:
		problems.append("day %d: %s not upgraded" % [TimeManager.day, id])
		return false
	return true


func _on_upgraded(id: StringName, level: int) -> void:
	level_days["%s%d" % [id, level]] = TimeManager.day
	_t("built %s %d (coins %d)" % [id, level, inv().count(&"coin")])


func _stock_text(i: Inventory) -> String:
	if i == null:
		return "–"
	var parts := PackedStringArray()
	for id: StringName in ChestTransfer.item_ids(i):
		parts.append("%s %d" % [id, i.count(id)])
	return ", ".join(parts)


func _hut_chest() -> Inventory:
	var chest := tree.get_first_node_in_group(HutInterior.HUT_GROUP).get_node_or_null("Entities/chest") as Chest
	return chest.storage if chest != null else null


var _waits: Dictionary = {}


## One trace line per day and building why it waits.
func _note_wait(id: StringName, why: String) -> void:
	var key := "%d%s%s" % [TimeManager.day, id, why.substr(0, 5)]
	if not _waits.has(key):
		_waits[key] = true
		_t("waits %s: %s" % [id, why])


func _t(what: String) -> void:
	trace6.append("d%d %s %s" % [TimeManager.day, TimeManager.format_clock(), what])


# --- the shed -----------------------------------------------------------------------------------

## Evening: stone and wood beyond the next days' needs into the shed (chest panel, ChestTransfer).
func _store_surplus6(now: bool = false) -> void:
	if not p6_open() or buildings.level(&"shed") < 1 or not _fits(2 * WALK_MINUTES) or player.carried_id != "":
		return
	var moves := {}
	for id: StringName in [&"stone", &"wood", &"workstone", &"clay"]:
		var extra := inv().count(id) - _want(id) - 4
		if extra > 0:
			moves[id] = extra
	if moves.is_empty():
		return
	if not _to_room(&"shed"):
		return
	var store := ShedStore.find(tree)
	store.interact(player)
	for id: StringName in moves:
		ChestTransfer.move(inv(), store.store(), id, int(moves[id]))
		stored[id] = int(stored.get(id, 0)) + int(moves[id])
	UIState.clear()
	_to_room(&"")


## Shed 1 (no fetch yet): what a build lacks back out of the shed by hand.
func _withdraw(gaps: Dictionary) -> void:
	var store := ShedStore.find(tree)
	if store == null:
		return
	var any := false
	for id: Variant in gaps:
		if store.store().count(StringName(str(id))) > 0:
			any = true
	if not any or not _to_room(&"shed"):
		return
	store.interact(player)
	for id: Variant in gaps:
		ChestTransfer.move(store.store(), inv(), StringName(str(id)), int(gaps[id]))
	UIState.clear()
	_to_room(&"")


func _on_shed_moved(items: Dictionary, direction: StringName) -> void:
	if direction != ShedSupply.DIRECTION_FETCH:
		return
	for id: Variant in items:
		fetched[id] = int(fetched.get(id, 0)) + int(items[id])


# --- old graves and the ossuary -------------------------------------------------------------------

func _boxes6() -> bool:
	if crypt_level() < 1:
		return false
	var liftable := 0
	for id: String in LIFT_ORDER:
		if graveyard.get_grave(id).state == GraveRecord.State.OLD:
			liftable += 1
	var want := mini(ossuary.capacity() - ossuary.used(), liftable) - inv().count(&"bone_box")
	var did := false
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	for i: int in maxi(want, 0):
		if inv().count(&"wood") < 3 + 1 or not _fits(15 + WALK_MINUTES):
			break
		_to_room(&"")
		_go(&"hut")
		if not _craft(bench, &"bone_box"):
			problems.append("day %d: bone box not crafted" % TimeManager.day)
			break
		did = true
	return did


func _lift6() -> bool:
	if crypt_level() < 1:
		return false
	var did := false
	for id: String in LIFT_ORDER:
		if inv().count(&"bone_box") == 0:
			break
		if graveyard.get_grave(id).state != GraveRecord.State.OLD or ossuary.lift_block_reason(id, inv()) != "":
			continue
		if not _fits(ossuary.lift_minutes(inv()) + WALK_MINUTES):
			break
		var plot := world.get_node_by_layout_id(id) as GravePlot
		_to_room(&"")
		_go(&"hut")
		_walk()
		var prompt := plot.get_interaction_prompt(player)
		if not prompt.begins_with("[E] Altes Grab heben: "):
			problems.append("day %d: %s prompt %s" % [TimeManager.day, id, prompt])
		plot.interact(player)
		if graveyard.get_grave(id).state != GraveRecord.State.EMPTY:
			problems.append("day %d: %s not lifted" % [TimeManager.day, id])
			break
		did = true
	return did


func _reinter6() -> bool:
	if ossuary.pending().is_empty() or inv().count(&"bone_box_full") == 0:
		return false
	if not _fits(ossuary.rules().reinter_minutes + 2 * CRYPT_WALK) or player.carried_id != "":
		return false
	if not _to_room(&"crypt"):
		return false
	var shelf := _room_node(&"crypt").get_node("Entities/OssuaryShelf") as OssuaryShelf
	var did := false
	while shelf.can_interact(player) and _fits(ossuary.rules().reinter_minutes):
		var n := ossuary.reinterred().size()
		shelf.interact(player)
		UIState.clear()
		if ossuary.reinterred().size() != n + 1:
			problems.append("day %d: reinterment refused (%s)" % [TimeManager.day, shelf.get_interaction_prompt(player)])
			break
		did = true
	return did


func _look_at_passage() -> bool:
	if ossuary.passage_state() == Ossuary.PASSAGE_HIDDEN or GameState.has_flag(Ossuary.FLAG_PASSAGE_SEEN):
		return false
	if player.carried_id != "" or not _fits(2 * CRYPT_WALK) or not _to_room(&"crypt"):
		return false
	var passage := _room_node(&"crypt").get_node("Entities/SealedPassage") as SealedPassage
	if not passage.visible or not passage.can_interact(player):
		problems.append("day %d: passage not visible / usable at crypt %d" % [TimeManager.day, crypt_level()])
		return false
	passage.interact(player)
	if not GameState.has_flag(Ossuary.FLAG_PASSAGE_SEEN):
		problems.append("day %d: no clue from the passage" % TimeManager.day)
	return true


# --- the chapel gate and devotions --------------------------------------------------------------

func _open_church_gate() -> bool:
	var gate := world.get_node_or_null("Entities/obs_c_gate") as ClearableObstacle
	if gate == null or gate.cleared or rites.level() < 1 or not gate.can_interact(player) or not _fits(10 + WALK_MINUTES):
		return false
	_to_room(&"")
	_walk()
	gate.interact(player)
	if not gate.cleared:
		problems.append("day %d: Kirchpforte not opened" % TimeManager.day)
	return gate.cleared


func _devotions6() -> bool:
	if flags.devote == &"none" or rites.level() < 1 or devotions.size() >= int(flags.devotions):
		return false
	if flags.devote == &"calm" and not GameState.has_flag(&"roof_and_earth_complete"):
		return false
	if inv().count(rites.get_config().candle_item) == 0 or player.carried_id != "" or _catafalque().occupant() != "":
		_note_wait(&"devotion", "candles %d, carrying %s, catafalque %s" % [inv().count(&"altar_candle"), player.carried_id, _catafalque().occupant()])
		return false
	# The candles may not starve the plan: the next upgrade's coins (+ reserve) stay in the purse.
	var nb := _next_build()
	if not nb.is_empty() and not GameState.has_flag(&"roof_and_earth_complete"):
		var lvl := (buildings.building(nb.id) as BuildingData).level_data(int(nb.level))
		if lvl != null and inv().count(&"coin") < lvl.coins + RESERVE6_NEEDED + OSRIC_CANDLE_PRICE:
			_note_wait(&"devotion", "coins for %s %d first" % [nb.id, nb.level])
			return false
	var pick := _devotion_pick()
	if pick == "" or not _fits(rites.get_config().devotion_minutes + 2 * WALK_MINUTES):
		var moods := {}
		for row: Dictionary in rites.eligible_devotions():
			var key := "%s/%s" % [row.mood, row.block_reason]
			moods[key] = int(moods.get(key, 0)) + 1
		_note_wait(&"devotion", "pick '%s' (%d candles) %s" % [pick, inv().count(&"altar_candle"), str(moods)])
		return false
	if not _to_room(&"chapel"):
		return false
	var altar := _altar()
	altar.interact(player)
	var panel := ui.get_panel(&"devotion") as DevotionPanel if ui != null else null
	if panel == null or not panel.is_open:
		problems.append("day %d: devotion panel did not open" % TimeManager.day)
		UIState.clear()
		return false
	panel.select(pick)
	if panel.block_reason() != "" or panel.devotion_button.disabled:
		problems.append("day %d: devotion panel refuses %s: %s" % [TimeManager.day, pick, panel.block_reason()])
		UIState.clear()
		return false
	panel.devotion_button.pressed.emit()
	UIState.clear()
	if rites.devotion_level(pick) != rites.level():
		problems.append("day %d: devotion for %s not held" % [TimeManager.day, pick])
		return false
	return true


## The grave the strategy holds the next devotion for ("" = none).
func _devotion_pick() -> String:
	var best := ""
	var best_rank := 1 << 30
	for row: Dictionary in rites.eligible_devotions():
		if String(row.block_reason) != "" or int(row.held_level) > 0:
			continue
		var grave := graveyard.get_grave(String(row.grave_id))
		var corpse := manager.get_record(grave.corpse_id) if grave != null else null
		var robbed := corpse != null and not corpse.harvested.is_empty()
		var rank := -1
		match flags.devote:
			&"calm":
				rank = 0 if row.mood == GhostMood.CALM else -1
			&"restless":
				rank = 0 if row.mood == GhostMood.RESTLESS else (1 if row.mood == GhostMood.CALM else -1)
			&"robbed":
				rank = 0 if robbed else -1
		if rank >= 0 and rank < best_rank:
			best_rank = rank
			best = String(row.grave_id)
	return best


# --- Osric: candles ---------------------------------------------------------------------------

func _osric_wishes() -> Array[Dictionary]:
	var out := super._osric_wishes()
	if not p6_open() or rites.level() < 1 and not (_chapel_next() and _chapel_affordable()):
		return out
	var budget := inv().count(&"coin")
	for w: Dictionary in out:
		budget -= int(w.coins)
	var want := _candles_wanted() - inv().count(&"altar_candle")
	while want > 0:
		var take := 3 if want >= 3 else 1
		if budget - OSRIC_CANDLE_PRICE * take < RESERVE6_NEEDED:
			if take == 3:
				take = 1
				if budget - OSRIC_CANDLE_PRICE < RESERVE6_NEEDED:
					break
			else:
				break
		out.append({"item": &"altar_candle", "coins": OSRIC_CANDLE_PRICE * take, "amount": take})
		budget -= OSRIC_CANDLE_PRICE * take
		want -= take
	return out


func _chapel_affordable() -> bool:
	var next := BuildingRules.next_level(buildings.building(&"chapel"), buildings.level(&"chapel"))
	return next != null and inv().count(&"coin") - next.coins - OSRIC_CANDLE_PRICE >= RESERVE6_NEEDED \
			and ShedSupply.shortfall(next.inputs, inv()).is_empty()


func _chapel_next() -> bool:
	var nb := _next_build()
	return not nb.is_empty() and nb.id == &"chapel"


## Candles for the services ahead (unburied unserviced corpses + free places) and the devotions.
func _candles_wanted() -> int:
	var n := 0
	if flags.service:
		for r: CorpseRecord in manager.records():
			if r.location != CorpseRecord.LOCATION_BURIED and not r.service_held:
				n += 1
		n = mini(n + 1, 2)
	if flags.devote != &"none" and devotions.size() < int(flags.devotions):
		if flags.devote != &"calm" or GameState.has_flag(&"roof_and_earth_complete"):
			n += mini(int(flags.devotions) - devotions.size(), 2)
	return n


## Phase 5: always talk once a day after buildings_open (p6_intro, candles).
func _osric5() -> void:
	if not p6_open():
		await super._osric5()
		return
	var wishes := _osric_wishes()
	var trace := PackedStringArray()
	for talk: int in 4:
		if wishes.is_empty() and GameState.has_flag(&"p6_intro"):
			break
		var before := wishes.size()
		_talk_to_osric(wishes, trace)
		if wishes.size() == before and GameState.has_flag(&"p6_intro"):
			break
	UIState.clear()
	if not wishes.is_empty():
		problems.append("day %d: Osric – not bought %s (%s)" % [TimeManager.day, str(wishes), " ".join(trace)])


func _pick_osric(choices: Array[DialogueChoice], wishes: Array[Dictionary], visited: Dictionary) -> int:
	var candle := wishes.filter(func(w: Dictionary) -> bool: return w.item == &"altar_candle")
	var others := wishes.filter(func(w: Dictionary) -> bool: return w.item != &"altar_candle")
	if not others.is_empty():
		return super._pick_osric(choices, others, visited)
	if not candle.is_empty():
		var w: Dictionary = candle[0]
		for i: int in choices.size():
			if choices[i].actions.has("give_item:altar_candle:%d" % int(w.amount)):
				return i
		for i: int in choices.size():
			if choices[i].next == &"p6_candles" and int(visited.get(&"p6_candles", 0)) < 6:
				return i
		for i: int in choices.size():
			if choices[i].text == "Ich nehme noch eine.":
				return i
	return super._pick_osric(choices, [] as Array[Dictionary], visited)


# --- stock --------------------------------------------------------------------------------------

## Inputs of every planned upgrade not built yet (the mandatory order, then – after the chapter –
## the optional levels): the stock the bot gathers and forges towards.
func _plan_inputs() -> Dictionary:
	var out := {}
	var planned := {}
	var levels: Array = []
	for id: StringName in flags.order:
		planned[id] = int(planned.get(id, 0)) + 1
		if buildings.level(id) < int(planned[id]):
			levels.append([id, int(planned[id])])
	if levels.is_empty() and GameState.has_flag(&"roof_and_earth_complete"):
		for id: StringName in flags.optional:
			for lvl: int in range(buildings.level(id) + 1, 4):
				levels.append([id, lvl])
	for pair: Array in levels:
		var data := (buildings.building(pair[0]) as BuildingData).level_data(int(pair[1]))
		if data == null:
			continue
		for item: Variant in data.inputs:
			out[item] = int(out.get(item, 0)) + int(data.inputs[item])
	return out


## Bars still to forge for the plan (bars themselves + bars for the missing fittings).
func _bars_to_make() -> int:
	var plan := _plan_inputs()
	var shed := ShedSupply.shed_inventory(tree)
	var have_bars := inv().count(&"iron_bar") + (shed.count(&"iron_bar") if shed != null else 0)
	var have_fit := inv().count(&"iron_fittings") + (shed.count(&"iron_fittings") if shed != null else 0)
	var fit_missing := maxi(int(plan.get(&"iron_fittings", 0)) - have_fit, 0)
	return maxi(int(plan.get(&"iron_bar", 0)) - have_bars, 0) + ceili(fit_missing / 2.0)


## Phase 5's wants + the plan's inputs + bone boxes + steles (in the shed counts as stocked).
func _want(item: StringName) -> int:
	var base := super._want(item)
	if not p6_open():
		return base
	var need := int(_plan_inputs().get(item, 0))
	var shed := ShedSupply.shed_inventory(tree)
	if shed != null:
		need -= shed.count(item)
	match item:
		&"wood":
			need += 8  # bone boxes, a cross
		&"stone":
			need += 8  # two steles
		&"iron_ore":
			need = 2 * _bars_to_make()
	return maxi(base, need)


func _stone_keep6() -> int:
	return int(_next_inputs().get(&"stone", 0))


func _charcoal_need() -> int:
	return super._charcoal_need() + (_bars_to_make() if p6_open() else 0)


## Phase 5's forge goals, then bars / fittings: the next wanted upgrade first (its fittings from a
## bar in hand), then the rest of the plan.
func _forge_need() -> StringName:
	var need := super._forge_need()
	if need != &"" or not p6_open():
		return need
	for nb: Dictionary in _build_candidates():
		var lvl := (buildings.building(nb.id) as BuildingData).level_data(int(nb.level))
		if lvl == null:
			continue
		var fit := int(lvl.inputs.get(&"iron_fittings", 0))
		var bars := int(lvl.inputs.get(&"iron_bar", 0))
		if inv().count(&"iron_fittings") < fit:
			return &"fittings" if inv().count(&"iron_bar") > 0 else &"bars"
		if inv().count(&"iron_bar") < bars:
			return &"bars"
	if _bars_to_make() > 0:
		return &"bars"
	var plan := _plan_inputs()
	if inv().count(&"iron_fittings") < int(plan.get(&"iron_fittings", 0)) and inv().count(&"iron_bar") > int(plan.get(&"iron_bar", 0)):
		return &"fittings"
	return &""


func _material_left_for(shape: StringName) -> bool:
	if not super._material_left_for(shape):
		return false
	if not p6_open():
		return true
	var s := Database.stone_shape(shape) as StoneShapeData
	var inputs := _next_inputs()
	for id: StringName in s.inputs:
		if inv().count(id) - int(inputs.get(id, 0)) < int(s.inputs[id]):
			return false
	return true


# --- save → load in the crypt -------------------------------------------------------------------

## reverent6 / save_load6: once, a look into the crypt while a corpse waits in a niche – save_load6
## saves there, loads, rebinds and carries on (the same walk for both: the rows must match).
func _visit_niche() -> void:
	var in_niche := manager.records().any(func(r: CorpseRecord) -> bool: return r.location == CorpseRecord.LOCATION_NICHE)
	if not in_niche or player.carried_id != "" or not _fits(2 * CRYPT_WALK):
		return
	if not _to_room(&"crypt"):
		return
	saved_in_crypt = true
	_visit_pending = false
	_t("look round the crypt%s" % (" – save → load" if flags.save_in_crypt else ""))
	if flags.save_in_crypt:
		await _save_and_load_in_crypt()
	_to_room(&"")


func _save_and_load_in_crypt() -> void:
	var slot := 97
	if SaveManager.save_game(slot) != OK:
		problems.append("day %d: save in the crypt failed" % TimeManager.day)
		return
	var err: Error = await SaveManager.load_game(slot)
	if err != OK:
		problems.append("day %d: load in the crypt failed %s" % [TimeManager.day, error_string(err)])
		return
	bind()
	if player.interior_id != &"crypt" or not _room_node(&"crypt").active:
		problems.append("day %d: not in the crypt after the load (%s)" % [TimeManager.day, player.interior_id])


# --- record ---------------------------------------------------------------------------------------

func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	var lv := buildings.levels()
	r.merge({
		"levels": "%d/%d/%d" % [int(lv.get(&"crypt", 0)), int(lv.get(&"chapel", 0)), int(lv.get(&"shed", 0))],
		"services": GameState.get_stat(&"services_held"), "devotions": GameState.get_stat(&"devotions_held"),
		"lifted": ossuary.used(), "reinterred": ossuary.reinterred().size(), "niche_waits": GameState.get_stat(&"niche_waits"),
		"income_day": _income_day.duplicate(), "chapter6": GameState.has_flag(&"roof_and_earth_complete"),
		"open6": p6_open(), "free": graveyard_free_plots(),
	})


## "| day | … |" rows for docs/reviews/phase6_wip/qa_playthrough.md.
func table_p6() -> String:
	var lines := PackedStringArray(["| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Gruft/Kapelle/Schuppen | Aussegnungen | Andachten | gehoben/beigesetzt | Nischen-Wartende | Gräber | frei | Qualität | Ruf | zufrieden | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		var parts := PackedStringArray()
		var spent_day: Dictionary = r.get("spent_day", {})
		for reason: Variant in spent_day:
			parts.append("%s %d" % [reason, int(spent_day[reason])])
		var inc := PackedStringArray()
		var income_day: Dictionary = r.get("income_day", {})
		for source: Variant in income_day:
			inc.append("%s %d" % [source, int(income_day[source])])
		lines.append("| %d | %d | %s | %s | %d | %s | %d | %d | %d/%d | %d | %d | %d | %d | %d | %d | %s |" % [r.day, int(r.get("morning_coins", 0)),
				", ".join(parts) if not parts.is_empty() else "–", ", ".join(inc) if not inc.is_empty() else "–", r.coins,
				r.get("levels", "–"), int(r.get("services", 0)), int(r.get("devotions", 0)), int(r.get("lifted", 0)),
				int(r.get("reinterred", 0)), int(r.get("niche_waits", 0)), r.marked, int(r.get("free", 0)), r.quality, r.rep,
				int(r.get("content", 0)), "✓" if r.get("chapter6", false) else ("offen" if r.get("open6", false) else "–")])
	return "\n".join(lines)


func ledger_text() -> String:
	return super.ledger_text() + " · Phase 6 spent %d · lowest morning (Phase 6) %d" % [spent_p6, lowest_morning_p6]


func _on_coins_spent(amount: int, reason: StringName) -> void:
	super._on_coins_spent(amount, reason)
	if buildings != null and is_instance_valid(buildings) and buildings.is_open():
		spent_p6 += amount


func _on_payment(coins: int, reason: String) -> void:
	var source := ""
	if reason.begins_with(Ossuary.REASON_FEE.split("%")[0]):
		source = "reinter"
	elif reason == ChapelRites.fee_text(coins):
		source = "service"
	if source != "":
		income[source] = int(income.get(source, 0)) + coins
		_income_day[source] = int(_income_day.get(source, 0)) + coins
		return
	var before := income.duplicate()
	super._on_payment(coins, reason)
	for key: Variant in income:
		var d := int(income[key]) - int(before.get(key, 0))
		if d != 0:
			_income_day[key] = int(_income_day.get(key, 0)) + d


func _on_chapter(chapter_id: StringName) -> void:
	super._on_chapter(chapter_id)
	if chapter_id == &"roof_and_earth" and chapter6_day < 0:
		chapter6_day = TimeManager.day


func _on_funeral(corpse_id: String, chapel_level: int, fee: int) -> void:
	_t("service %s at chapel %d, fee %d" % [corpse_id, chapel_level, fee])
	services.append({"day": TimeManager.day, "corpse": corpse_id, "level": chapel_level, "fee": fee,
			"mourners": ChapelRules.mourners(chapel_level, rites.get_config())})


func _on_devotion(grave_id: String, bonus: int) -> void:
	_t("devotion %s +%d" % [grave_id, bonus])
	devotions.append({"day": TimeManager.day, "grave": grave_id, "bonus": bonus})


func _on_lifted(grave_id: String) -> void:
	_t("lifted " + grave_id)
	lifted_days[grave_id] = TimeManager.day


func _on_reinterred(grave_id: String, _count: int) -> void:
	_t("reinterred " + grave_id)
	reinterred_days[grave_id] = TimeManager.day
