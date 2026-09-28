class_name Phase4Bot
extends Phase3Bot
## QA playthrough bot of Phase 4 (docs/PHASE4_DESIGN.md §10 "Playthrough-Bot", W3). Extends
## Phase3Bot (same day: gather, deliveries, crafting, clearing, tending, decor, ghosts, bed) by
## the examination steps, the preparation (wash / shroud or gown / lay out), juniper, the
## harvest, the Holunderwinkel, linking clues in the journal and the night at the west wall:
## Ilse's dialogue runs through the real DialogueRunner on data/dialogue/trader.tres; selling
## and buying mirror her panel (NightTrade.sell / buy). Osric's juniper and linen mirror
## data/dialogue/carter.tres like Phase3Bot. Everything through the entities' request_*() /
## interact() and the systems' public API with Player.instant_actions.
## Strategies (flags, on top of the Phase-3 "diligent" flags): see P4_STRATEGIES.

## Ilse stands at the wall from 23:00; the bot comes at 23:05 and goes to bed afterwards.
const TRADE_MINUTE := 1385
const P4_PRICE := {&"linen": 3, &"iron_fittings": 3, &"seeds": 1, &"juniper": 2}
const GOODS: Array[StringName] = [&"hair_braid", &"teeth_pouch"]
const DIALOGUE_STEPS := 24

const BASE := {"tend": true, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
		"clear": true, "decor": true, "listen": true, "upgrade": true, "save_load": false, "sleep_minute": 1350,
		# Phase 4
		"exam": "full", "prep": true, "gown": true, "balm": true, "harvest": [], "harvest_odd": [],
		"delay": false, "link": true, "trade": true, "prep_on_harvest": false}

## "exam": "full" (Gründlich untersuchen) | "short" (clothing + pockets, the Phase-3 habit).
## "prep": wash + lay out (tools crafted); "gown": Totenhemd instead of the shroud when there
## is linen for it. "balm": juniper on a corpse that has to wait (no free plot) and on story
## corpses. "harvest": kinds taken from every corpse; "harvest_odd": only on odd days – such a
## day is a harvester's day (only the shroud, no wash / lay out / gown), the others reverent.
## "delay": works on a corpse only on the day after its arrival (procrastinator, no juniper).
## "prep_on_harvest" (Phase 5 §2.9, G4 finding B2): a harvester's day still washes and lays out
## (full preparation after the harvest, shroud) – the full_prep piety bonus no longer comes then.
## "trade": talks to Ilse every night (tools, questions, sells the goods, buys cheap linen).
static var P4_STRATEGIES := {
	&"reverent": _with({}),
	&"harvester": _with({"take_valuables": true, "prep": false, "gown": false, "balm": false,
			"harvest": [&"hair", &"teeth"], "decor": false}),
	&"procrastinator": _with({"exam": "full", "prep": false, "gown": false, "balm": false, "delay": true,
			"decor": false}),
	&"mixed": _with({"harvest_odd": [&"hair"], "prep_on_harvest": true}),
	&"save_load4": _with({"save_load": true}),
}

var care: CorpseCare
var journal: JournalManager
var trade: NightTrade
var piety: Piety
var ilse: Npc
## Coins from Ilse / spent at Ilse / valuables taken over the run.
var ilse_income: int = 0
var ilse_spent: int = 0
var valuables_income: int = 0
## Number of stench events at the gate and of story corpses that arrived.
var stench_events: int = 0
var key_fallback: bool = false
var chapter_day: int = -1
var arrived_stories: Array[StringName] = []
## Coins by source: burial payments (count), the daily stipend.
var burial_income: int = 0
var burials_paid: int = 0
var stipend_income: int = 0
var _last_rep_reason: String = ""


static func _with(overrides: Dictionary) -> Dictionary:
	var out := BASE.duplicate(true)
	out.merge(overrides, true)
	return out


func strategies() -> Dictionary:
	return P4_STRATEGIES


func bind() -> void:
	super.bind()
	care = world.get_node("Systems/CorpseCare") as CorpseCare
	journal = world.get_node("Systems/Journal") as JournalManager
	trade = world.get_node("Systems/NightTrade") as NightTrade
	piety = world.get_node("Systems/Piety") as Piety
	ilse = world.get_node_by_layout_id("npc_trader") as Npc


## Signal counters (stench, key fallback, chapter) – connect once per run, not per bind.
func watch() -> void:
	EventBus.reputation_changed.connect(_on_rep)
	EventBus.notification_requested.connect(_on_note)
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.story_corpse_arrived.connect(_on_story)
	EventBus.payment_received.connect(_on_payment)


func unwatch() -> void:
	EventBus.reputation_changed.disconnect(_on_rep)
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.story_corpse_arrived.disconnect(_on_story)
	EventBus.payment_received.disconnect(_on_payment)


# --- one day ------------------------------------------------------------------------------

func run_day() -> void:
	_leave_hut()
	_gather()
	var tables := Database.corpse_tables() as CorpseTables
	if TimeManager.minute_of_day < tables.delivery_minute + 10:
		_craft_essentials()
		_wait_until(tables.delivery_minute + 10)
	_buy_for_today()
	_handle_corpses()
	_craft_essentials()
	if flags.upgrade:
		_upgrade_markers()
	if flags.clear:
		_clear_obstacles()
	if flags.tend:
		_tend()
	if flags.decor:
		_decorate()
	if flags.tend:
		_tend()
	_handle_corpses()
	_balm_waiting()
	if flags.link:
		_link()
	if flags.listen:
		_listen_to_ghosts()
	if flags.trade:
		await _night_at_the_wall()
		if flags.link:
			_link()
	await _sleep()


## Phase 3 + the Phase-4 tools (brush, comb) and the gown.
func _craft_essentials() -> void:
	super._craft_essentials()
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	if flags.prep:
		# Wood for tomorrow's marker (1 with stone, else 3) stays.
		if not inv().has(&"scrub_brush") and inv().count(&"wood") >= 2 + 3:
			_craft(bench, &"scrub_brush")
		if not inv().has(&"comb") and inv().count(&"wood") >= 1 + 3:
			_craft(bench, &"comb")
	if flags.gown and inv().count(&"burial_gown") == 0 and inv().count(&"linen") >= 3:
		_craft(bench, &"burial_gown")


## Linen for tomorrow (gown: 3, shroud: 2) at Osric's cart; juniper for waiting corpses.
func _buy_for_today() -> void:
	if not flags.shroud:
		return
	var per := 3 if flags.gown else 2
	var dressed := 3 * inv().count(&"burial_gown") + 2 * inv().count(&"shroud")
	var want := per * (_waiting_corpses() + 1) - inv().count(&"linen") - dressed
	for i: int in maxi(want, 0):
		if inv().count(&"coin") < 3 + (2 if flags.balm else 0):
			break
		_buy(&"linen", 1)
	if flags.balm and inv().count(&"juniper") == 0 and inv().count(&"coin") >= RESERVE + 2:
		_buy(&"juniper", 1)


func _buy(item: StringName, amount: int) -> bool:
	var cost := int(P4_PRICE[item]) * amount
	if amount <= 0 or inv().count(&"coin") < cost or not inv().can_add(item, amount):
		return false
	inv().remove_item(&"coin", cost)
	inv().add_item(item, amount)
	spent += cost
	return true


func _waiting_corpses() -> int:
	var n := 0
	for r: CorpseRecord in manager.records():
		if r.location != CorpseRecord.LOCATION_BURIED and not r.is_dressed():
			n += 1
	return n


## Procrastinator: yesterday's corpses first (today's goes onto the table and waits).
func _handle_corpses() -> void:
	var list := manager.records()
	if flags.delay:
		list.sort_custom(func(a: CorpseRecord, b: CorpseRecord) -> bool: return a.arrival_total_minutes < b.arrival_total_minutes)
	for record: CorpseRecord in list:
		if record.location == CorpseRecord.LOCATION_BURIED or not _time_left():
			continue
		if flags.delay and _arrival_day(record) >= TimeManager.day:
			# Onto the table (the bier must be free tomorrow), examined tomorrow.
			if record.location == CorpseRecord.LOCATION_DROPOFF and _table().corpse_id == "":
				_to_table(record)
			continue
		if _free_plot() == null:
			# No plot today (reserved / full): onto the table and under juniper if possible.
			if record.location == CorpseRecord.LOCATION_DROPOFF and _table().corpse_id == "":
				_to_table(record)
			continue
		if record.location == CorpseRecord.LOCATION_DROPOFF and _table().corpse_id != "":
			continue  # the table is busy – the next pass
		_bury(record)


func _table() -> MorgueTable:
	return world.get_node_by_layout_id("morgue_table") as MorgueTable


static func _arrival_day(record: CorpseRecord) -> int:
	@warning_ignore("integer_division")
	return record.arrival_total_minutes / 1440 + 1


## Examination → valuables → harvest → juniper → preparation → dress.
func _on_table(record: CorpseRecord, table: MorgueTable) -> bool:
	if flags.examine:
		if flags.exam == "full":
			if not care.open_steps(record.id).is_empty():
				table.request_exam_all()
		else:
			for step: StringName in [CorpseRecord.STEP_CLOTHING, CorpseRecord.STEP_POCKETS]:
				if care.step_block_reason(record.id, step) == "":
					table.request_exam_step(step)
	if record.needs_valuables_decision():
		var before := inv().count(&"coin")
		table.decide_valuables(flags.take_valuables)
		valuables_income += inv().count(&"coin") - before
	var kinds: Array = flags.harvest.duplicate()
	var harvest_day := TimeManager.day % 2 == 1 and not (flags.harvest_odd as Array).is_empty()
	if harvest_day:
		kinds.append_array(flags.harvest_odd)
	for kind: StringName in kinds:
		if care.harvest_block_reason(record.id, kind, inv()) == "":
			table.request_harvest(kind)
			if not record.is_harvested(kind):
				problems.append("day %d: harvest %s refused" % [TimeManager.day, kind])
	if flags.balm and record.story_id != &"" and _balm_ok(record):
		table.request_balm()
	if flags.prep and (not harvest_day or flags.prep_on_harvest):
		if care.prep_block_reason(record.id, CorpsePrep.ACTION_WASH, inv()) == "":
			table.request_wash()
		if care.prep_block_reason(record.id, CorpsePrep.ACTION_LAY_OUT, inv()) == "":
			table.request_lay_out()
	if flags.shroud and not record.is_dressed():
		if flags.gown and inv().count(&"burial_gown") == 0 and inv().count(&"shroud") == 0:
			_craft_essentials()
		if inv().count(&"shroud") == 0 and inv().count(&"burial_gown") == 0:
			super._craft_essentials()
		var gown: bool = flags.gown and not harvest_day and inv().count(&"burial_gown") > 0
		if harvest_day and inv().count(&"shroud") == 0:
			super._craft_essentials()
		var kind := CorpseRecord.DRESS_GOWN if gown or inv().count(&"shroud") == 0 else CorpseRecord.DRESS_SHROUD
		if care.prep_block_reason(record.id, CorpsePrep.ACTION_DRESS, inv(), kind) == "":
			table.request_dress(kind)
	return true


func _balm_ok(record: CorpseRecord) -> bool:
	return care.prep_block_reason(record.id, CorpsePrep.ACTION_BALM, inv()) == ""


## A corpse left on the table (no plot) gets juniper when the strategy uses it.
func _balm_waiting() -> void:
	if not flags.balm:
		return
	var id := _table().corpse_id
	if id == "":
		return
	if inv().count(&"juniper") == 0 and inv().count(&"coin") >= 2:
		_buy(&"juniper", 1)
	if _balm_ok(manager.get_record(id)):
		_table().interact(player)
		UIState.clear()
		_table().request_balm()


## East, north (Phase 3) and the Holunderwinkel once the key is there: its gate first.
func _clear_obstacles() -> void:
	super._clear_obstacles()
	if expansion.is_unlocked(&"elder") or expansion.block_reason(&"elder") != "":
		return
	var ids := expansion.obstacle_ids(&"elder")
	ids.sort()
	for i: int in ids.size():
		if expansion.data_of(ids[i]).id == &"gate_small":
			var gate := ids[i]
			ids.remove_at(i)
			ids.insert(0, gate)
			break
	for id: String in ids:
		if not _time_left() or expansion.is_cleared(id):
			continue
		var node := expansion.obstacle(id)
		var data := expansion.data_of(id)
		if data.cost.has(&"iron_fittings") and inv().count(&"iron_fittings") < int(data.cost[&"iron_fittings"]):
			if inv().count(&"coin") - 3 < RESERVE:
				continue
			_buy(&"iron_fittings", int(data.cost[&"iron_fittings"]) - inv().count(&"iron_fittings"))
		if data.cost.has(&"wood") and inv().count(&"wood") - int(data.cost[&"wood"]) < 1:
			continue
		if node.can_interact(player):
			_walk()
			node.interact(player)


## Links every insight whose clues are all found (journal page "Hinweise", exact set). The
## journal panel is opened on its pages first (as a player reading it; UI warnings count).
func _link() -> void:
	for page: StringName in JournalManager.PAGES:
		EventBus.ui_panel_requested.emit(JournalManager.PANEL, journal.panel_context(page))
		UIState.clear()
	for insight: InsightData in journal.ready_insights():
		var ids: Array[StringName] = []
		ids.assign(insight.requires)
		ids.reverse()  # order must not matter
		if journal.try_link(ids) != insight.id:
			problems.append("day %d: link %s refused" % [TimeManager.day, insight.id])


# --- the night at the west wall ---------------------------------------------------------------

## From the note on: wait for Ilse (23:05), talk through her dialogue, sell the goods, buy
## linen (cheaper than Osric's) and juniper when needed.
func _night_at_the_wall() -> void:
	if not trade.is_known():
		return
	if TimeManager.minute_of_day < TRADE_MINUTE and TimeManager.minute_of_day >= 300:
		_wait_until(TRADE_MINUTE)
	await tree.process_frame
	await tree.process_frame
	if not trade.is_present():
		problems.append("day %d: Ilse not at the wall at %s" % [TimeManager.day, TimeManager.format_clock()])
		return
	var traded := _talk_to_ilse()
	if not traded:
		return
	for item: StringName in GOODS:
		var n := inv().count(item)
		if n > 0:
			var coins := trade.sell(item, n, inv())
			if coins <= 0:
				problems.append("day %d: Ilse did not buy %d %s" % [TimeManager.day, n, item])
			ilse_income += coins
	var linen := mini(trade.stock_left(&"linen"), maxi(0, _linen_wanted_at_the_wall() - inv().count(&"linen")))
	while linen > 0 and inv().count(&"coin") >= 2 * linen + RESERVE:
		if trade.buy(&"linen", linen, inv()):
			ilse_spent += 2 * linen
		break
	if flags.balm and inv().count(&"juniper") < 2 and trade.stock_left(&"juniper") > 0 and inv().count(&"coin") >= 1 + RESERVE:
		if trade.buy(&"juniper", 1, inv()):
			ilse_spent += 1
	UIState.clear()


## Linen the bot keeps in stock from Ilse's shop (Phase5Bot: none once the graves are full).
func _linen_wanted_at_the_wall() -> int:
	return 6


## Ilse's dialogue: take her tools, ask what can be asked tonight, then trade. true = the
## trade panel was opened ("Handeln" / "Zeig mir, was du hast.").
func _talk_to_ilse() -> bool:
	var runner := DialogueRunner.new()
	runner.start(Database.dialogue(&"trader") as DialogueData, {"inventory": inv(), "speaker": ilse})
	var asked := {}
	var traded := false
	for step: int in DIALOGUE_STEPS:
		if runner.is_finished():
			break
		var choices := runner.available_choices()
		if choices.is_empty():
			break
		var pick := _pick(choices, asked)
		var choice := choices[pick]
		asked[choice.next] = true
		if choice.actions.has("open_panel:trader"):
			traded = true
		runner.choose(pick)
		UIState.clear()
	return traded


## Tools first, then the questions not asked yet (Lorenz, the marked, the blossom), then the
## trade; "Gute Nacht" last.
func _pick(choices: Array[DialogueChoice], asked: Dictionary) -> int:
	for i: int in choices.size():
		if choices[i].actions.has("trader_tools"):
			return i
	for want: StringName in [&"ask_lorenz", &"ask_marked", &"ask_blossom", &"who", &"menu"]:
		for i: int in choices.size():
			if choices[i].next == want and not asked.has(want):
				return i
	for i: int in choices.size():
		if choices[i].actions.has("open_panel:trader"):
			return i
	for i: int in choices.size():
		if not asked.has(choices[i].next):
			return i
	return choices.size() - 1


# --- record ---------------------------------------------------------------------------------

func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	var lost := 0
	var prepared := 0
	for c: CorpseRecord in manager.records():
		lost += c.finds_lost.size()
	r.merge({
		"piety": piety.value(), "piety_tier": piety.tier(), "insights": journal.insights().size(),
		"clues": journal.clues().size(), "lost": lost, "utilized": GameState.get_stat(&"utilized"),
		"prepared": GameState.get_stat(&"prepared"), "sales": GameState.get_stat(&"trader_sales"),
		"elder": expansion.is_unlocked(&"elder"), "stories": manager.story_delivered().size(),
		"chapter": GameState.has_flag(&"six_pits_complete"), "stench": stench_events,
		"key": GameState.has_flag(&"has_elder_key"),
	})


## "| day | … |" rows for docs/reviews/phase4_wip/qa_playthrough.md.
func table_p4() -> String:
	var lines := PackedStringArray(["| Tag | Gräber | Qualität | Stufe | Ruf | Münzen | Pietät | Pietät-Stufe | Hinweise | Erk. | verloren | hergerichtet | verwertet | Ilse-Verk. | Gesch. | Holunder | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		lines.append("| %d | %d | %d | %s | %d | %d | %d | %s | %d | %d | %d | %d | %d | %d | %d | %s | %s |" % [r.day, r.marked,
				r.quality, CemeteryRating.label(r.rating), r.rep, r.coins, r.piety, PietyRules.label(r.piety_tier),
				r.clues, r.insights, r.lost, r.prepared, r.utilized, r.sales, r.stories,
				"✓" if r.elder else ("🔑" if r.key else "–"), "✓" if r.chapter else "–"])
	return "\n".join(lines)


func _on_rep(_v: int, _t: StringName, _d: int, reason: String) -> void:
	if reason == CorpseManager.REASON_STENCH:
		stench_events += 1


func _on_note(text: String, _kind: StringName) -> void:
	var cfg := Database.config(&"story_config") as StoryConfig
	if cfg != null and text == cfg.key_fallback_text:
		key_fallback = true


func _on_chapter(chapter_id: StringName) -> void:
	if chapter_id == &"six_pits" and chapter_day < 0:
		chapter_day = TimeManager.day


func _on_story(story_id: StringName, _corpse_id: String) -> void:
	arrived_stories.append(story_id)


func _on_payment(coins: int, reason: String) -> void:
	if reason == Reputation.REASON_STIPEND:
		stipend_income += coins
	elif reason.begins_with(Graveyard.PAYMENT_REASON.split("%")[0]):
		burial_income += coins
		burials_paid += 1
