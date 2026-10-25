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
var _sources: CashBookConfig
var _ledger_before: Dictionary = {}


func _init(p_tree: SceneTree, p_last_day: int = 91) -> void:
	tree = p_tree
	last_day = p_last_day
	_sources = load("res://tests/fixtures/phase10/cash_book_config_fixture.tres") as CashBookConfig


## A new game, the chain to `last_day` (the morning of last_day + 1 is the last row).
func run() -> void:
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
	rows.append({"day": TimeManager.day, "minute": TimeManager.minute_of_day, "holdings": _holdings(),
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
