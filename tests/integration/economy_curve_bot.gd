class_name EconomyCurveBot
extends RefCounted
## Zielkurve curve10 (docs/PHASE10_DESIGN.md §2.3, §10.3) – W0 scaffold (Lead) of P1's tool: a new game played to day 91
## by the dignified founder bots of Phases 3–9 as one chain in one run, measuring the coins every morning. W0 uses it for
## the Ist-Messung of the old tariff (docs/reviews/phase10_wip/ist_kurve.md, tools/economy/ist_kurve.gd); P1 extends it
## for the new tariff (founder10, the wish list, the checkpoints of §2.3) and owns it from W1 on.
##
## Hand-overs (W0, fixed): Phase6Bot founder (the bot of slot_p6_day37_founder: Phase 3–6 from a new game) until
## roof_and_earth_complete → FounderBot7 founder7 (as make_v6_saves_driver.gd) until name_in_village_complete →
## Phase8Bot founder8 until who_comes_up_complete → Phase9Bot founder9 until `last_day` (founder10 joins in W3). Each
## switch happens on the morning after the chapter exactly as the fixture line did it (make_v5…v8_saves_driver.gd): out
## of the hut, 07:00, saved and loaded again (slot HANDOVER_SLOT in SaveManager.save_dir), then the next bot binds.
## Without the reload founder8 never takes a friendship step in the same session (W0 measurement: steps 0 from day 39 to
## 84, every step takeable) – a finding for W1/W3, see the W0 notes.
##
## Measured every morning (before the bot's day): the holdings (Reputation.holdings: purse + chests + Jakob's wage tin)
## and stats.coins_spent; income of a day = Δ holdings + Δ spending. Income by source through EventBus.payment_received
## (the prefix table of the W0 CashBookConfig fixture) and trader_trade (Ilse, „night"); what reaches the holdings without
## a booking (valuables in the hem …) is „untracked". Spending by purpose from GameState.coin_ledger().

## Rows of §2.3 („Abschnitt", first day, last day).
const SEGMENTS := [["P2–3 Ankunft & Friedhof", 1, 14], ["P4 Leichen", 15, 24], ["P5 Werkhof", 20, 30], ["P6 Gebäude", 30, 40],
		["P7 Dorf", 40, 53], ["P8 Leute", 53, 63], ["P9 Fragen", 63, 75], ["P10 Wirtschaft", 75, 91]]
## §2.3 checkpoints.
const CHECKPOINTS: PackedInt32Array = [14, 30, 45, 60, 75, 91]
## Zielkurve „gemütlich knapp" (§2.3 table, curve10 = new game on the Phase-10 tariff): per row of SEGMENTS the band
## of every morning's holdings [lo, hi], the band of Δ [lo, hi], the minimum spending quote, the lowest morning.
const BANDS := [[[5, 60], [25, 55], 0.60, 5], [[25, 100], [20, 50], 0.60, 5], [[10, 80], [-60, -20], 0.85, 10],
		[[10, 60], [0, 25], 0.85, 8], [[15, 70], [15, 40], 0.80, 8], [[25, 80], [0, 20], 0.80, 8], [[30, 85], [0, 20], 0.75, 8],
		[[30, 90], [-20, 15], 0.85, 8]]
## §2.3: day 14 holds 30–60; every bot ≥ 5 each morning, the dignified way ≥ 8 from day 7 on.
const DAY14_BAND := Vector2i(30, 60)
const FLOOR := 5
const FLOOR_DIGNIFIED := 8
const FLOOR_DIGNIFIED_FROM := 7
## Grundsatz 2: the open wish list costs ≥ 1.3 × the income of the next 14 days.
const WISH_FACTOR := 1.3
const STAGES := [[&"founder", &"roof_and_earth_complete"], [&"founder7", &"name_in_village_complete"],
		[&"founder8", &"who_comes_up_complete"], [&"founder9", &""]]
const MAX_STAGE_DAYS := 45
const HANDOVER_SLOT := 89


## Phase7Bot with founder7 (make_v6_saves_driver.gd: crafter + Phase 7, keep_p5, optional crypt / chapel).
class FounderBot7 extends Phase7Bot:
	func strategies() -> Dictionary:
		var out := Phase7Bot.P7_STRATEGIES.duplicate()
		out[&"founder7"] = Phase7Bot._with7({}, {}, {"keep_p5": true, "optional": [&"crypt", &"chapel"]}, {})
		return out

	## P1 W1 (W0 finding 12/2): the village menus offer the Phase-8 return favours („[Gegengefallen] …", category
	## friend) as plain orders through order_offerable – without an owed favour and before p8_open. On this line the
	## village opens at day 28, founder7 took of_quast_return_1 / of_mangold_return_2 (2 herb bundles, 4 yarn) that no
	## bot ever delivers; accepted that way they never lapse and fill Orders.max_active_friend (2), so every
	## step_accept of founder8 failed silently. founder7 leaves friend orders alone (as Phase8Bot does once p8 is open).
	func _score(npc_id: StringName, c: DialogueChoice, visited: Dictionary) -> int:
		for a: String in c.actions:
			if a.get_slice(":", 0) == "order_accept":
				var o := orders.order_data(StringName(a.get_slice(":", 1)))
				if o != null and o.category == OrderData.CATEGORY_FRIEND:
					return 0
		return super._score(npc_id, c, visited)


## Measurement only (P1, W1 – until P2's Treasury is merged; never part of a real world): the contract's Friedhofsgeld
## (§2.5.2 with the TreasuryConfig data) so the old bots and curve10 can be measured on the whole Phase-10 tariff.
## Schau on Sunday from schau_minute: tier = Graveyard.rating(), care share = occupied graves (FILLED / MARKED) whose dirt
## spots are at level ≤ 1, no wilted flowers, not disturbed (an approximation of TreasuryRules.care_share), disturbed
## graves, holdings (Reputation.holdings) → quality (≤ quality_cap) + need ⌈(60 − P)/4⌉ ≤ 15 + hardship (to 10, ≤ 8); the
## first week prorated (days seen / 7, rounded up). Paid on Monday from pay_minute (or later) into the pack as
## payment_received("Friedhofsgeld"). stipend_off: the reputation config of the run pays no Pflegegeld any more (E1).
## Lives under the SceneTree root, so it survives world reloads; open_day = the first day it sees.
class ParishEmu extends Node:
	var cfg: TreasuryConfig
	var stipend_off: bool = true
	var open_day: int = -1
	## {week, day, tier, care, disturbed, holdings, quality, need, hardship, total} of every Schau; paid ones carry paid_day.
	var schauen: Array[Dictionary] = []
	var _stipend_backup: PackedInt32Array = PackedInt32Array()
	var _cap_backup: int = 0

	func _init(p_stipend_off: bool = true) -> void:
		stipend_off = p_stipend_off
		cfg = load("res://data/config/treasury_config.tres") as TreasuryConfig

	func _ready() -> void:
		EventBus.time_tick.connect(_tick)
		if stipend_off:
			var rep := Database.config(&"reputation_config") as ReputationConfig
			_stipend_backup = rep.stipend.duplicate()
			_cap_backup = rep.stipend_purse_cap
			rep.stipend = PackedInt32Array([0, 0, 0, 0, 0])
			rep.stipend_purse_cap = 0

	func _exit_tree() -> void:
		if EventBus.time_tick.is_connected(_tick):
			EventBus.time_tick.disconnect(_tick)
		if stipend_off and not _stipend_backup.is_empty():
			var rep := Database.config(&"reputation_config") as ReputationConfig
			rep.stipend = _stipend_backup
			rep.stipend_purse_cap = _cap_backup

	func paid_total() -> int:
		var n := 0
		for s: Dictionary in schauen:
			if s.has("paid_day"):
				n += int(s.total)
		return n

	func _tick(day: int, minute: int) -> void:
		var world := get_tree().current_scene as WorldRoot
		if world == null or world.get_player() == null or world.get_node_or_null("Systems/Graveyard") == null:
			return
		if open_day < 0 or day < open_day:
			open_day = day
		var week := CalendarRules.week_of(day)
		if CalendarRules.weekday(day) == cfg.schau_weekday and minute >= cfg.schau_minute \
				and (schauen.is_empty() or int(schauen[-1].week) != week):
			schauen.append(_schau(world, day, week))
		for s: Dictionary in schauen:
			if s.has("paid_day"):
				continue
			var due := int(s.day) + 1
			if day > due or (day == due and minute >= cfg.pay_minute):
				s["paid_day"] = day
				if int(s.total) > 0:
					world.get_player().inventory.add_item(&"coin", int(s.total))
					EventBus.payment_received.emit(int(s.total), "Friedhofsgeld")

	func _schau(world: WorldRoot, day: int, week: int) -> Dictionary:
		var gy := world.get_node("Systems/Graveyard") as Graveyard
		var care := get_tree().get_first_node_in_group(&"grave_care")
		var clean := get_tree().get_first_node_in_group(&"cleanliness")
		var rep := world.get_node("Systems/Reputation") as Reputation
		var spots := {}
		for node: Node in get_tree().get_nodes_in_group(&"dirt_spot"):
			var gid := String(node.get(&"grave_id"))
			if gid != "":
				var lst: Array = spots.get(gid, [])
				lst.append(String(node.get(&"spot_id")))
				spots[gid] = lst
		var occupied := 0
		var tended := 0
		var disturbed := 0
		for g: GraveRecord in gy.graves():
			if not g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
				continue
			occupied += 1
			var bad := g.disturbed or (care != null and bool(care.call(&"is_disturbed", g.id)))
			if bad:
				disturbed += 1
			if care != null and StringName(care.call(&"flowers_state", g.id)) == &"wilted":
				bad = true
			for sid: String in spots.get(g.id, []):
				if clean != null and int(clean.call(&"level", sid)) > 1:
					bad = true
			if not bad:
				tended += 1
		var share := float(tended) / float(occupied) if occupied > 0 else 0.0
		var tier := gy.rating()
		var quality := int(cfg.tier_pay.get(tier, 0))
		for step: float in cfg.care_steps:
			if share >= step:
				quality += 1
		quality = clampi(quality - disturbed * cfg.disturbed_malus, 0, cfg.quality_cap)
		var holdings := rep.holdings(world.get_player().inventory)
		var need := 0
		if holdings < cfg.need_threshold:
			need = mini(ceili(float(cfg.need_threshold - holdings) / float(cfg.need_divisor)), cfg.need_cap)
		var hardship := 0
		if holdings + quality + need < cfg.hardship_floor:
			hardship = mini(cfg.hardship_floor - holdings - quality - need, cfg.hardship_cap)
		var total := quality + need + hardship
		var seen := day - open_day + 1
		if seen < 7:
			total = ceili(float(total) * float(seen) / 7.0)
		return {"week": week, "day": day, "tier": tier, "care": share, "disturbed": disturbed, "holdings": holdings,
				"quality": quality, "need": need, "hardship": hardship, "total": total}


var tree: SceneTree
var last_day: int = 91
## {day, holdings, spent, stage, chapters} per morning.
var rows: Array[Dictionary] = []
## day → {source: coins}
var income_by_day: Dictionary = {}
## day → {purpose: coins} (the ledger's change during the day).
var spent_by_day: Dictionary = {}
## stage → first morning
var stage_days: Dictionary = {}
var problems: PackedStringArray = []
## stage → the bot that played it (traces for diagnosis).
var bots: Dictionary = {}
## stage → {end_day, flags, goal} at the end of the stage (diagnosis of the hand-overs).
var stage_info: Dictionary = {}
## The fixture line's hand-over (07:00, save, load); false = the next bot binds to the running world.
var reload_at_handover: bool = true
## P1 W1: the Friedhofsgeld emulation (ParishEmu, stipend off) – true until P2's Treasury is in the world.
var parish_emu_on: bool = false
var emu: ParishEmu
var _sources: CashBookConfig
var _ledger_before: Dictionary = {}


func _init(p_tree: SceneTree, p_last_day: int = 91) -> void:
	tree = p_tree
	last_day = p_last_day
	_sources = load("res://tests/fixtures/phase10/cash_book_config_fixture.tres") as CashBookConfig


## A new game, the chain to `last_day` (the morning of last_day + 1 is the last row).
func run() -> void:
	if parish_emu_on:
		emu = ParishEmu.new(true)
		emu.name = "ParishEmu"
		tree.root.add_child(emu)
	await SaveManager.new_game()
	EventBus.payment_received.connect(_on_payment)
	EventBus.trader_trade.connect(_on_trader)
	for stage: Array in STAGES:
		if TimeManager.day > last_day:
			break
		var bot := _make(StringName(stage[0]))
		bots[stage[0]] = bot
		bot.flags = bot.flags.duplicate(true)
		bot.bind()
		bot.watch()
		stage_days[stage[0]] = TimeManager.day
		var stop := StringName(stage[1])
		for i: int in MAX_STAGE_DAYS:
			if TimeManager.day > last_day:
				break
			_record(bot, String(stage[0]))
			await bot.run_day()
			_close_day(TimeManager.day - 1)
			if stop != &"" and GameState.has_flag(stop):
				break
		bot.unwatch()
		stage_info[stage[0]] = _info()
		for p: String in bot.problems:
			problems.append("%s: %s" % [stage[0], p])
		if reload_at_handover and stop != &"" and TimeManager.day <= last_day:
			await _handover(bot)
	_record(null, "end")
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.trader_trade.disconnect(_on_trader)
	if emu != null:
		emu.queue_free()


func _handover(bot: Phase3Bot) -> void:
	var b6 := bot as Phase6Bot
	if b6 != null:
		b6._to_room(&"")
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	if SaveManager.save_game(HANDOVER_SLOT) != OK:
		problems.append("handover day %d: save failed" % TimeManager.day)
		return
	if await SaveManager.load_game(HANDOVER_SLOT) != OK:
		problems.append("handover day %d: load failed" % TimeManager.day)


func _info() -> Dictionary:
	var flags := {}
	for f: StringName in [&"workshop_open", &"buildings_open", &"village_open", &"p8_open", &"p9_open", &"roof_and_earth_complete",
			&"name_in_village_complete", &"who_comes_up_complete", &"who_knows_when_complete"]:
		flags[f] = GameState.get_flag(f)
	var life := tree.get_first_node_in_group(&"npc_life")
	var quests := tree.get_first_node_in_group(&"quests")
	var friends := {}
	var fr := tree.get_first_node_in_group(&"friendship")
	var rels := tree.get_first_node_in_group(&"relationships")
	for npc: StringName in [&"mayor", &"innkeeper", &"smith", &"priest", &"grocer"]:
		friends[npc] = [rels.call(&"value", npc) if rels != null else -1, fr.call(&"step_block_reason", npc) if fr != null else "?"]
	return {"end_day": TimeManager.day, "flags": flags, "friends": friends,
			"goal8": life.call(&"goal_progress") if life != null and life.has_method(&"goal_progress") else {},
			"goal9": quests.call(&"goal_progress") if quests != null and quests.has_method(&"goal_progress") else {}}


func _make(strategy: StringName) -> Phase3Bot:
	match strategy:
		&"founder":
			return Phase6Bot.new(strategy, tree)
		&"founder7":
			return FounderBot7.new(strategy, tree)
		&"founder8":
			return Phase8Bot.new(strategy, tree)
		_:
			return Phase9Bot.new(strategy, tree)


func _holdings() -> int:
	var world := tree.current_scene as WorldRoot
	var rep := world.get_node("Systems/Reputation") as Reputation
	return rep.holdings(world.get_player().inventory)


func _record(_bot: Phase3Bot, stage: String) -> void:
	_ledger_before = GameState.coin_ledger()
	var wish := Database.wishlist() as WishlistData
	rows.append({"day": TimeManager.day, "minute": TimeManager.minute_of_day, "holdings": _holdings(),
			"wish": WishlistProbe.open_cost(tree, wish) if wish != null else 0,
			"spent": GameState.get_stat(&"coins_spent"), "stage": stage,
			"chapters": ["cemetery_complete", "names_in_stone_complete", "roof_and_earth_complete", "name_in_village_complete",
				"who_comes_up_complete", "who_knows_when_complete"].filter(func(f: String) -> bool: return GameState.has_flag(StringName(f))).size()})


func _close_day(day: int) -> void:
	var now := GameState.coin_ledger()
	var out := {}
	for k: StringName in now:
		var d := int(now[k]) - int(_ledger_before.get(k, 0))
		if d != 0:
			out[k] = d
	spent_by_day[day] = out


func _source_of(reason: String) -> String:
	for source: StringName in _sources.sources:
		for prefix: String in (_sources.sources[source].get("prefixes", PackedStringArray()) as PackedStringArray):
			if reason.begins_with(prefix):
				return String(source)
	return "other"


func _book(source: String, coins: int) -> void:
	var day := TimeManager.day
	var d: Dictionary = income_by_day.get(day, {})
	d[source] = int(d.get(source, 0)) + coins
	income_by_day[day] = d


func _on_payment(coins: int, reason: String) -> void:
	_book(_source_of(reason), coins)


func _on_trader(coins: int, _sold: Dictionary, _bought: Dictionary) -> void:
	if coins > 0:
		_book("night", coins)


# --- evaluation ---------------------------------------------------------------------------------

## The morning row of `day` ({} if none).
func row(day: int) -> Dictionary:
	for r: Dictionary in rows:
		if int(r.day) == day:
			return r
	return {}


## {from, to, start, end, delta, income, spent, quote, min_morning, sources, purposes, untracked} of days from…to
## (start = the morning of `from`, end = the morning after `to`).
func segment(from: int, to: int) -> Dictionary:
	var a := row(from)
	var b := row(to + 1)
	if a.is_empty() or b.is_empty():
		return {}
	var spent := int(b.spent) - int(a.spent)
	var income := int(b.holdings) - int(a.holdings) + spent
	var lowest := 1 << 30
	var sources := {}
	var purposes := {}
	for d: int in range(from, to + 1):
		var r := row(d)
		if not r.is_empty():
			lowest = mini(lowest, int(r.holdings))
		var inc: Dictionary = income_by_day.get(d, {})
		for k: Variant in inc:
			sources[k] = int(sources.get(k, 0)) + int(inc[k])
		var sp: Dictionary = spent_by_day.get(d, {})
		for k: Variant in sp:
			purposes[k] = int(purposes.get(k, 0)) + int(sp[k])
	var booked := 0
	for k: Variant in sources:
		booked += int(sources[k])
	return {"from": from, "to": to, "start": int(a.holdings), "end": int(b.holdings), "delta": int(b.holdings) - int(a.holdings),
			"income": income, "spent": spent, "quote": float(spent) / float(income) if income > 0 else 0.0, "min_morning": lowest,
			"sources": sources, "purposes": purposes, "untracked": income - booked}


## The §2.3 checks of the curve: [{what, ok, value, band}] – segments (mornings, Δ, quote, lowest morning), day 14, the
## floors, the wish list at every checkpoint (open cost ≥ WISH_FACTOR × income of the next 14 days).
func checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in SEGMENTS.size():
		var s: Array = SEGMENTS[i]
		var seg := segment(int(s[1]), int(s[2]))
		if seg.is_empty():
			continue
		var band: Array = BANDS[i]
		var lo := 1 << 30
		var hi := -(1 << 30)
		for d: int in range(int(s[1]), int(s[2]) + 2):
			var r := row(d)
			if not r.is_empty():
				lo = mini(lo, int(r.holdings))
				hi = maxi(hi, int(r.holdings))
		out.append(_check("%s: Polster morgens" % s[0], lo >= int(band[0][0]) and hi <= int(band[0][1]), "%d…%d" % [lo, hi],
				"%d–%d" % [band[0][0], band[0][1]]))
		out.append(_check("%s: Δ" % s[0], int(seg.delta) >= int(band[1][0]) and int(seg.delta) <= int(band[1][1]),
				"%+d" % seg.delta, "%+d … %+d" % [band[1][0], band[1][1]]))
		out.append(_check("%s: Ausgabequote" % s[0], float(seg.quote) >= float(band[2]), "%d %%" % roundi(float(seg.quote) * 100.0),
				"≥ %d %%" % roundi(float(band[2]) * 100.0)))
		out.append(_check("%s: morgens min." % s[0], int(seg.min_morning) >= int(band[3]), str(seg.min_morning), "≥ %d" % band[3]))
	var d14 := row(14)
	if not d14.is_empty():
		out.append(_check("Tag 14", int(d14.holdings) >= DAY14_BAND.x and int(d14.holdings) <= DAY14_BAND.y, str(d14.holdings),
				"%d–%d" % [DAY14_BAND.x, DAY14_BAND.y]))
	var lowest := 1 << 30
	var lowest7 := 1 << 30
	for r: Dictionary in rows:
		lowest = mini(lowest, int(r.holdings))
		if int(r.day) >= FLOOR_DIGNIFIED_FROM:
			lowest7 = mini(lowest7, int(r.holdings))
	out.append(_check("morgens immer", lowest >= FLOOR, str(lowest), "≥ %d" % FLOOR))
	out.append(_check("würdevoll ab Tag %d" % FLOOR_DIGNIFIED_FROM, lowest7 >= FLOOR_DIGNIFIED, str(lowest7), "≥ %d" % FLOOR_DIGNIFIED))
	for d: int in CHECKPOINTS:
		var w := wish_check(d)
		if not w.is_empty():
			out.append(_check("Wunschliste Tag %d" % d, bool(w.ok), "%d / %d = %.1f×" % [w.wish, w.income, w.factor],
					"≥ %.1f×" % WISH_FACTOR))
	return out


## {wish, income, factor, ok} at checkpoint `day` (income of day … day + 13; fewer days measured → as far as measured).
func wish_check(day: int) -> Dictionary:
	var r := row(day)
	if r.is_empty():
		return {}
	var to := day + 13
	while to > day and row(to + 1).is_empty():
		to -= 1
	var seg := segment(day, to)
	var income := int(seg.get("income", 0))
	var factor := float(r.wish) / float(income) if income > 0 else 99.0
	return {"wish": int(r.wish), "income": income, "factor": factor, "ok": factor >= WISH_FACTOR}


func failed_checks() -> Array[Dictionary]:
	return checks().filter(func(c: Dictionary) -> bool: return not bool(c.ok))


static func _check(what: String, ok: bool, value: String, band: String) -> Dictionary:
	return {"what": what, "ok": ok, "value": value, "band": band}


## The measurement as Markdown (docs/reviews/phase10_wip/ist_kurve.md).
func report(head: String) -> String:
	var lines := PackedStringArray()
	lines.append(head)
	lines.append("")
	lines.append("| Abschnitt | Tage | Polster morgens Start → Ende (Δ) | Einnahmen | Ausgaben | Ausgabequote | morgens min. | Einnahmen nach Quelle | Ausgaben nach Zweck | ohne Buchung |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for s: Array in SEGMENTS:
		var seg := segment(int(s[1]), int(s[2]))
		if seg.is_empty():
			lines.append("| %s | %d–%d | – | | | | | | | |" % [s[0], s[1], s[2]])
			continue
		lines.append("| %s | %d–%d | %d → %d (%+d) | %d | %d | %d %% | %d | %s | %s | %d |" % [s[0], s[1], s[2], seg.start, seg.end,
				seg.delta, seg.income, seg.spent, roundi(float(seg.quote) * 100.0), seg.min_morning, _top(seg.sources),
				_top(seg.purposes), seg.untracked])
	lines.append("")
	lines.append("| Prüfpunkt (morgens) | Polster | Kapitel bis dahin | Bot |")
	lines.append("|---|---|---|---|")
	for d: int in CHECKPOINTS:
		var r := row(d)
		if r.is_empty():
			lines.append("| Tag %d | – | – | – |" % d)
		else:
			lines.append("| Tag %d | %d | %d | %s |" % [d, r.holdings, r.chapters, r.stage])
	lines.append("")
	var handovers := PackedStringArray()
	for k: Variant in stage_days:
		handovers.append("%s ab Tag %d" % [k, stage_days[k]])
	lines.append("Übergaben: " + " · ".join(handovers) + ".")
	lines.append("")
	lines.append("Polster je Morgen: " + ", ".join(rows.map(func(r: Dictionary) -> String: return "%d:%d" % [r.day, r.holdings])))
	lines.append("")
	lines.append("Bot-Probleme: " + ("keine" if problems.is_empty() else "; ".join(problems)))
	lines.append("")
	lines.append("| Prüfung (§2.3) | Ist | Ziel | |")
	lines.append("|---|---|---|---|")
	for c: Dictionary in checks():
		lines.append("| %s | %s | %s | %s |" % [c.what, c.value, c.band, "✓" if bool(c.ok) else "✗"])
	if emu != null:
		lines.append("")
		lines.append("Friedhofsgeld (Emulation P1, bis P2): " + " · ".join(emu.schauen.map(func(x: Dictionary) -> String:
				return "T%d %s %d%%→%d" % [x.day, x.tier, roundi(float(x.care) * 100.0), x.total])))
	lines.append("")
	for k: Variant in stage_info:
		lines.append("Stufe %s: %s" % [k, str(stage_info[k])])
	return "\n".join(lines) + "\n"


static func _top(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(d[a]) > int(d[b]))
	var parts := PackedStringArray()
	for k: Variant in keys:
		parts.append("%s %d" % [k, d[k]])
	return " · ".join(parts)
