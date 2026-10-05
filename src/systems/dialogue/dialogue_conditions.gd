class_name DialogueConditions
extends RefCounted
## Condition interpreter of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4),
## used by DialogueRunner – the syntax is documented in dialogue_runner.gd. Reads GameState,
## TimeManager and the context inventory; changes nothing. Stateless.
## Phase 3 adds: day_gte:<n> (TimeManager.day >= n) · day_odd · day_even (odd-day deliveries
## at "Verrufen", docs/PHASE3_DESIGN.md §2.7).
## Phase 4 (docs/PHASE4_DESIGN.md §3.4): piety_tier:<id> (tier of stats.piety equals id, §2.7) ·
## trader_talks_gte:<n> (nights talked with Ilse, NightTrade) · clue_known:<id> (journal clue,
## flag clue_<id>) · flag_night:<name> (flag value == the current night, a night starts 12:00).
## stat_gte / stat_lt take negative numbers (piety).
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P6): rel_gte:<npc>:<n> (relationship value) · rel_tier:<npc>:<tier>
## (the relationship is on <tier> or higher) · met:<npc> · rep_tier:<tier> (reputation tier equals) ·
## order:<id>:<state> (none = no state) · order_offerable:<id> · shop_open:<shop> · region:<id> ·
## specimens_held_gte:<n> · specimen_sold_any · alive:<npc> (its Npc's hide_flag is off; oldwoman →
## hagedorn_dead) · lecture_tonight · village_open_days_gte:<n> (days since village_open_day) ·
## flag_days_gte:<flag>:<n> (the flag holds a day; at least n days since) · order_ready:<id> (accepted and
## its items in the context inventory) · village_can:<round|donate|consecrate> (Village's block reason is "")
## · mourning_today (a mourning ribbon hangs today).
## Phase 8 (docs/PHASE8_DESIGN.md §3.4 + W0-Notizen 10, P6): p8_open (NpcLife.is_open / flag) · open_days_gte:<n>
## (days since p8_open_day) · mood:<npc>:<mood> (NpcLife.mood) · step_gte:<npc>:<n> · step_offerable:<npc> ·
## favor_ready:<npc> (Friendship.favor_block_reason "") · favor_owed:<npc> (a return favour is open) ·
## apprentice_hired · apprentice_level_gte:<task>:<n> (no task → any task) · apprentice_mistake_today ·
## wish_offerable / visit_waiting (the speaker's visit, see kin_of) · fest_today:<id> / fest_day:<id> ·
## fest_running:<id> · fest_eve:<id> (the fest is tomorrow) · fest_after:<id> (it was yesterday) – <id> with
## or without the prefix fest_ · alms_gte:<n> · robber_known · robber_fate:<none|reported|let_go|caught_watch> ·
## sick_light[:<house>] (NightPaths.sick_houses now) · observed:<clue> · underlined:<priest|surgeon|washer>
## (StoryConfig.underlined) · insight:<id> (the journal has it).

enum _Result { FALSE, TRUE, INVALID }

## Phase 7: hide flags known without an Npc node in the world (§2.2: Wiebke Hagedorn after her death).
const HIDE_FLAGS := {&"oldwoman": &"hagedorn_dead"}
# Phase 8
const P8_OPEN_FLAG := &"p8_open"
const P8_OPEN_DAY_FLAG := &"p8_open_day"
const ROBBER_KNOWN_FLAG := &"robber_known"
const APPRENTICE_FLAG := &"apprentice_hired"
const MOODS: Array[StringName] = [&"plain", &"cheerful", &"low", &"cross"]
const ROBBER_FATES: PackedStringArray = ["none", "reported", "let_go", "caught_watch"]
const APPRENTICE_TASKS: Array[StringName] = [&"rake", &"weed", &"water", &"candle"]


## True when every condition holds (an empty list holds).
static func all_met(conditions: Array[String], context: Dictionary) -> bool:
	for cond: String in conditions:
		if not check(cond, context):
			return false
	return true


static func check(cond: String, context: Dictionary) -> bool:
	var text := cond.strip_edges()
	var negate := false
	while text.begins_with("!"):
		negate = not negate
		text = text.substr(1).strip_edges()
	var result := _evaluate(text, context)
	if result == _Result.INVALID:
		push_warning("[DialogueRunner] invalid condition '%s' counts as false" % cond)
		return false
	return (result == _Result.TRUE) != negate


static func _evaluate(text: String, context: Dictionary) -> _Result:
	match DialogueSyntax.key(text):
		"has_item":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, 1)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var inv := DialogueSyntax.inventory(context, &"has")
			if inv == null:
				return _Result.FALSE
			return _bool(inv.call(&"has", StringName(p[0]), int(n)))
		"flag":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(GameState.get_flag(StringName(p[0])))
		"stat_gte", "stat_lt":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var value := GameState.get_stat(StringName(p[0]))
			return _bool(value >= int(n) if DialogueSyntax.key(text) == "stat_gte" else value < int(n))
		"time_between":
			var p := DialogueSyntax.parts(text, 2)
			var a: Variant = DialogueSyntax.int_arg(p, 0, null)
			var b: Variant = DialogueSyntax.int_arg(p, 1, null)
			if a == null or b == null:
				return _Result.INVALID
			return _bool(_in_window(TimeManager.minute_of_day, int(a), int(b)))
		"flag_eq":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "":
				return _Result.INVALID
			var flag := StringName(p[0])
			return _bool(GameState.has_flag(flag) and _value_matches(GameState.get_flag(flag), p[1]))
		"flag_today":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var value: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((value is int or value is float) and float(value) == float(TimeManager.day))
		# Phase 3 (docs/PHASE3_DESIGN.md §1.3, §2.7): day of the game.
		"day_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			return _bool(TimeManager.day >= int(n))
		"day_odd", "day_even":
			if text.contains(":"):
				return _Result.INVALID
			return _bool((TimeManager.day % 2 == 1) == (text == "day_odd"))
		# Phase 4 (docs/PHASE4_DESIGN.md §2.6, §2.7, §3.4).
		"piety_tier":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not StringName(p[0]) in JournalRules.PIETY_TIERS:
				return _Result.INVALID
			return _bool(piety_tier() == StringName(p[0]))
		"trader_talks_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			return _bool(trader_talks() >= int(n))
		"clue_known":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(GameState.get_flag(StringName(JournalManager.CLUE_FLAG_PREFIX + p[0])))
		"flag_night":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var value: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((value is int or value is float) and int(value) == night_id())
		# Phase 7 (docs/PHASE7_DESIGN.md §3.4).
		"rel_gte":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			return _bool(rel_value(StringName(p[0])) >= int(n))
		"rel_tier":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "" or OrderRules.tier_index(StringName(p[1])) < 0:
				return _Result.INVALID
			return _bool(OrderRules.tier_index(rel_tier(StringName(p[0]))) >= OrderRules.tier_index(StringName(p[1])))
		"met":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var rel := DialogueSyntax.system(&"relationships")
			return _bool(rel != null and rel.has_method(&"met") and bool(rel.call(&"met", StringName(p[0]))))
		"rep_tier":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not StringName(p[0]) in ReputationRules.TIERS:
				return _Result.INVALID
			return _bool(rep_tier() == StringName(p[0]))
		"order":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "":
				return _Result.INVALID
			var orders := DialogueSyntax.system(&"orders")
			var state: StringName = orders.call(&"state", StringName(p[0])) if orders != null and orders.has_method(&"state") else &""
			return _bool(String(state) == (p[1] if p[1] != "none" else ""))
		"order_offerable":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var orders := DialogueSyntax.system(&"orders")
			return _bool(orders != null and orders.has_method(&"block_reason") and str(orders.call(&"block_reason", StringName(p[0]))) == "")
		"order_ready":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(order_ready(StringName(p[0]), context))
		"shop_open":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var shops := DialogueSyntax.system(&"village_shops")
			return _bool(shops != null and shops.has_method(&"is_open") and bool(shops.call(&"is_open", StringName(p[0]))))
		"region":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(RegionRoot.current(Engine.get_main_loop() as SceneTree) == StringName(p[0]))
		"specimens_held_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var specimens := DialogueSyntax.system(&"specimens")
			var held: Variant = specimens.call(&"held") if specimens != null and specimens.has_method(&"held") else PackedStringArray()
			return _bool((held as PackedStringArray).size() >= int(n) if held is PackedStringArray else false)
		"specimen_sold_any":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(GameState.get_stat(&"specimens_sold") > 0)
		"alive":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(is_alive(StringName(p[0])))
		"lecture_tonight":
			if text.contains(":"):
				return _Result.INVALID
			var lectures := DialogueSyntax.system(&"lectures")
			return _bool(lectures != null and lectures.has_method(&"tonight") and bool(lectures.call(&"tonight")))
		"flag_days_gte":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.size() < 2 or p[0] == "" or n == null:
				return _Result.INVALID
			var since: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((since is int or since is float) and TimeManager.day - int(since) >= int(n))
		"village_can":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not p[0] in ["round", "donate", "consecrate"]:
				return _Result.INVALID
			var village := DialogueSyntax.system(&"village")
			if village == null:
				return _Result.FALSE
			var method: StringName = {"round": &"round_block_reason", "donate": &"donation_block_reason", "consecrate": &"consecration_block_reason"}[p[0]]
			var inv: Variant = context.get("inventory")
			return _bool(village.has_method(method) and str(village.call(method, inv if inv is Inventory else null)) == "")
		"mourning_today":
			if text.contains(":"):
				return _Result.INVALID
			var village := DialogueSyntax.system(&"village")
			return _bool(village != null and village.has_method(&"mourning_house") and village.call(&"mourning_house", TimeManager.day) != &"")
		"village_open_days_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var since: Variant = GameState.get_flag(&"village_open_day")
			return _bool((since is int or since is float) and TimeManager.day - int(since) >= int(n))
		# Phase 8 (docs/PHASE8_DESIGN.md §3.4, W0-Notizen 10).
		"p8_open":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(p8_open())
		"open_days_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var since: Variant = GameState.get_flag(P8_OPEN_DAY_FLAG)
			return _bool(p8_open() and (since is int or since is float) and TimeManager.day - int(since) >= int(n))
		"mood":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "" or not StringName(p[1]) in MOODS:
				return _Result.INVALID
			return _bool(mood_of(StringName(p[0])) == StringName(p[1]))
		"step_gte":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var friendship := DialogueSyntax.system(&"friendship")
			return _bool(friendship != null and friendship.has_method(&"step_done") and int(friendship.call(&"step_done", StringName(p[0]))) >= int(n))
		"step_offerable":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var friendship := DialogueSyntax.system(&"friendship")
			return _bool(friendship != null and friendship.has_method(&"offerable_step") and int(friendship.call(&"offerable_step", StringName(p[0]))) > 0)
		"favor_ready":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var friendship := DialogueSyntax.system(&"friendship")
			return _bool(friendship != null and friendship.has_method(&"favor_block_reason") and str(friendship.call(&"favor_block_reason", StringName(p[0]))) == "")
		"favor_owed":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(favor_owed(StringName(p[0])))
		"apprentice_hired":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(apprentice_hired())
		"apprentice_level_gte":
			var p := DialogueSyntax.parts(text, 2)
			if p.is_empty():
				return _Result.INVALID
			# apprentice_level_gte:<n> (any task, FriendStepData) or apprentice_level_gte:<task>:<n>.
			var task := &""
			var n: Variant = null
			if p.size() == 1:
				n = DialogueSyntax.int_arg(p, 0, null)
			else:
				task = StringName(p[0])
				n = DialogueSyntax.int_arg(p, 1, null)
			if n == null or (p.size() > 1 and p[0] == ""):
				return _Result.INVALID
			return _bool(apprentice_level(task) >= int(n))
		"apprentice_mistake_today":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(apprentice_mistakes_today() > 0)
		"wish_offerable":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(wish_offerable(context))
		"visit_waiting":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(StringName(str(visit_of_speaker(context).get("phase", ""))) == &"waiting")
		"fest_today", "fest_day", "fest_running", "fest_eve", "fest_after":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(fest_check(DialogueSyntax.key(text), fest_id(p[0])))
		"alms_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var wanderers := DialogueSyntax.system(&"wanderers")
			return _bool(wanderers != null and wanderers.has_method(&"alms_count") and int(wanderers.call(&"alms_count")) >= int(n))
		"robber_known":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(GameState.flag_on(ROBBER_KNOWN_FLAG))
		"robber_fate":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not p[0] in ROBBER_FATES:
				return _Result.INVALID
			var robber := DialogueSyntax.system(&"night_robber")
			var fate: StringName = robber.call(&"fate") if robber != null and robber.has_method(&"fate") else &""
			return _bool(String(fate) == ("" if p[0] == "none" else p[0]))
		"sick_light":
			var p := DialogueSyntax.parts(text, 1)
			var houses := sick_houses_now()
			if p.is_empty():
				return _bool(not houses.is_empty())
			if p[0] == "":
				return _Result.INVALID
			return _bool(houses.has(p[0]))
		"observed":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var paths := DialogueSyntax.system(&"night_paths")
			var seen := paths != null and paths.has_method(&"observed") and bool(paths.call(&"observed", StringName(p[0])))
			return _bool(seen or GameState.flag_on(StringName(JournalManager.CLUE_FLAG_PREFIX + p[0])))
		"underlined":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not StringName(p[0]) in JournalManager.UNDERLINED_CHOICES:
				return _Result.INVALID
			return _bool(JournalManager.underlined_choice() == StringName(p[0]))
		"insight":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var journal := DialogueSyntax.system(&"journal")
			return _bool(journal != null and journal.has_method(&"has_insight") and bool(journal.call(&"has_insight", StringName(p[0]))))
	return _Result.INVALID


# --- Phase 8 -----------------------------------------------------------------------------------

## Phase 8 (§1.2): NpcLife.is_open() in the running world, else the flag p8_open.
static func p8_open() -> bool:
	var life := DialogueSyntax.system(&"npc_life")
	if life != null and life.has_method(&"is_open"):
		return bool(life.call(&"is_open"))
	return GameState.flag_on(P8_OPEN_FLAG)


## Phase 8 (§2.1.1): today's mood of `npc_id` (plain without NpcLife).
static func mood_of(npc_id: StringName) -> StringName:
	var life := DialogueSyntax.system(&"npc_life")
	if life != null and life.has_method(&"mood"):
		return StringName(str(life.call(&"mood", npc_id)))
	return &"plain"


## Phase 8 (§2.4): a return favour of `npc_id` is open (Friendship state "owed").
static func favor_owed(npc_id: StringName) -> bool:
	var friendship := DialogueSyntax.system(&"friendship")
	if friendship == null or not friendship.has_method(&"save_state"):
		return false
	var state: Variant = friendship.call(&"save_state")
	var owed: Variant = (state as Dictionary).get("owed", {}) if state is Dictionary else {}
	if not owed is Dictionary:
		return false
	var value: Variant = (owed as Dictionary).get(String(npc_id), (owed as Dictionary).get(npc_id, ""))
	return (value is String or value is StringName) and str(value) != ""


## Phase 8 (§2.5): Jakob is hired (Apprentice, else the hire flag).
static func apprentice_hired() -> bool:
	var apprentice := DialogueSyntax.system(&"apprentice")
	if apprentice != null and apprentice.has_method(&"is_hired"):
		return bool(apprentice.call(&"is_hired"))
	return GameState.flag_on(APPRENTICE_FLAG)


## Phase 8: Jakob's level in `task` (0…2); task &"" = his best task.
static func apprentice_level(task: StringName) -> int:
	var apprentice := DialogueSyntax.system(&"apprentice")
	if apprentice == null or not apprentice.has_method(&"level"):
		return 0
	if task != &"":
		return int(apprentice.call(&"level", task))
	var best := 0
	for t: StringName in APPRENTICE_TASKS:
		best = maxi(best, int(apprentice.call(&"level", t)))
	return best


## Phase 8: Jakob's mistakes today (Apprentice state mistakes_today of today's plan).
static func apprentice_mistakes_today() -> int:
	var apprentice := DialogueSyntax.system(&"apprentice")
	if apprentice == null or not apprentice.has_method(&"save_state"):
		return 0
	var state: Variant = apprentice.call(&"save_state")
	if not state is Dictionary:
		return 0
	var d := state as Dictionary
	var day: Variant = d.get("plan_day", TimeManager.day)
	var n: Variant = d.get("mistakes_today", 0)
	if not (day is int or day is float) or int(day) != TimeManager.day or not (n is int or n is float):
		return 0
	return int(n)


## Phase 8 (§2.2): the KinData id of the speaker – context.kin_id, else the speaker's npc_id when it is a
## kin id (kin_kehr …), else the kin whose villager_id or npc_path_id is the speaker's (Esch → kin_smith).
static func kin_of(context: Dictionary) -> StringName:
	var given: Variant = context.get("kin_id")
	if (given is String or given is StringName) and str(given) != "":
		return StringName(str(given))
	var speaker: Variant = context.get("speaker")
	if not is_instance_valid(speaker):
		return &""
	var npc_id := StringName(str((speaker as Object).get(&"npc_id")))
	var node_name := StringName(str((speaker as Node).name)) if speaker is Node else &""
	if npc_id != &"" and Database.has_method(&"kin") and Database.kin(npc_id) != null:
		return npc_id
	if Database.has_method(&"kin_list"):
		for k: Resource in Database.kin_list():
			if not k is KinData:
				continue
			var kin := k as KinData
			if (kin.villager_id != &"" and kin.villager_id == npc_id) or (kin.npc_path_id != &"" and (kin.npc_path_id == npc_id or kin.npc_path_id == node_name)):
				return kin.kin_id
	return &""


## Phase 8: the planned visit of the speaker's kin today ({} = none).
static func visit_of_speaker(context: Dictionary) -> Dictionary:
	var kin := kin_of(context)
	var visitors := DialogueSyntax.system(&"visitors")
	if kin == &"" or visitors == null or not visitors.has_method(&"visit_of"):
		return {}
	var visit: Variant = visitors.call(&"visit_of", kin)
	return visit if visit is Dictionary else {}


## Phase 8 (§2.2.5): the speaker's visit could take a wish – a visit today, goodwill ≥ goodwill_wish_min,
## fewer than max_open open wishes and none on its graves (Visitors.offer_wish decides the kind).
static func wish_offerable(context: Dictionary) -> bool:
	var visit := visit_of_speaker(context)
	if visit.is_empty():
		return false
	var visitors := DialogueSyntax.system(&"visitors")
	var cfg: VisitorConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"visitor_config") as VisitorConfig
	if cfg == null:
		cfg = VisitorConfig.new()
	var kin := kin_of(context)
	if visitors.has_method(&"goodwill") and int(visitors.call(&"goodwill", kin)) < cfg.goodwill_wish_min:
		return false
	var graves: Variant = visit.get("graves", [])
	var open: Variant = visitors.call(&"open_wishes") if visitors.has_method(&"open_wishes") else []
	var count := 0
	for w: Variant in open:
		if not w is Dictionary:
			continue
		var state := str((w as Dictionary).get("state", ""))
		if state in ["done", "failed"]:
			continue
		count += 1
		if graves is Array and (graves as Array).has(str((w as Dictionary).get("grave_id", ""))):
			return false
	return count < cfg.max_open


## Phase 8: "lights" → &"fest_lights" (the prefix is optional in the data).
static func fest_id(text: String) -> StringName:
	return StringName(text if text.begins_with("fest_") else "fest_" + text)


## Phase 8 (§2.7): fest_today / fest_day / fest_running / fest_eve / fest_after for `fest`.
static func fest_check(key: String, fest: StringName) -> bool:
	var festivals := DialogueSyntax.system(&"festivals")
	if festivals == null:
		return false
	match key:
		"fest_running":
			return festivals.has_method(&"running") and StringName(str(festivals.call(&"running"))) == fest
		"fest_eve", "fest_after":
			if not festivals.has_method(&"fest_day"):
				return false
			var day := int(festivals.call(&"fest_day", fest))
			return day > 0 and day == TimeManager.day + (1 if key == "fest_eve" else -1)
	return festivals.has_method(&"today") and StringName(str(festivals.call(&"today"))) == fest


## Phase 8 (§1.6): the houses with a sick light right now (NightPaths).
static func sick_houses_now() -> PackedStringArray:
	var paths := DialogueSyntax.system(&"night_paths")
	if paths == null or not paths.has_method(&"sick_houses"):
		return PackedStringArray()
	var houses: Variant = paths.call(&"sick_houses", TimeManager.day, TimeManager.minute_of_day)
	return houses if houses is PackedStringArray else PackedStringArray()


## Phase 7: the relationship value with `npc_id` (0 without Relationships).
static func rel_value(npc_id: StringName) -> int:
	var rel := DialogueSyntax.system(&"relationships")
	return int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0


## Phase 7: the relationship tier with `npc_id` (thresholds of data/config/relationship_config.tres).
static func rel_tier(npc_id: StringName) -> StringName:
	var cfg: RelationshipConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"relationship_config") as RelationshipConfig
	return OrderRules.rel_tier(rel_value(npc_id), cfg)


## Phase 7: the tier of GameState.stats.reputation.
static func rep_tier() -> StringName:
	var cfg: ReputationConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"reputation_config") as ReputationConfig
	return ReputationRules.tier(GameState.get_stat(&"reputation"), cfg)


## Phase 7: the order is accepted and its items are in the context inventory.
static func order_ready(order_id: StringName, context: Dictionary) -> bool:
	var orders := DialogueSyntax.system(&"orders")
	if orders == null or not orders.has_method(&"state") or orders.call(&"state", order_id) != &"accepted":
		return false
	var data: OrderData = orders.call(&"order_data", order_id) if orders.has_method(&"order_data") else null
	var inv: Variant = context.get("inventory")
	return data != null and inv is Inventory and OrderRules.deliver_ready(data, inv as Inventory)


## Phase 7: no Npc of `npc_id` hides behind its hide_flag (Wiebke Hagedorn: hagedorn_dead).
static func is_alive(npc_id: StringName) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"npc"):
			if node.get(&"npc_id") == npc_id:
				var flag: Variant = node.get(&"hide_flag")
				if flag is StringName and flag != &"" and GameState.flag_on(flag):
					return false
	return not (HIDE_FLAGS.has(npc_id) and GameState.flag_on(HIDE_FLAGS[npc_id]))


## Tier of GameState.stats.piety (§2.7 thresholds from data/config/piety_config.tres).
static func piety_tier() -> StringName:
	var cfg: PietyConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"piety_config") as PietyConfig
	return JournalRules.piety_tier(GameState.get_stat(&"piety"), cfg)


## Nights talked with Ilse (NightTrade state "talks"); 0 without the system.
static func trader_talks() -> int:
	var trade := DialogueSyntax.system(&"night_trade")
	if trade == null or not trade.has_method(&"save_state"):
		return 0
	var state: Variant = trade.call(&"save_state")
	var talks: Variant = (state as Dictionary).get("talks", 0) if state is Dictionary else 0
	return int(talks) if (talks is int or talks is float) else 0


## The current night (GhostManager.night_index: a night starts at 12:00).
static func night_id() -> int:
	return GhostManager.night_index(TimeManager.day, TimeManager.minute_of_day)


## a <= t < b; a > b wraps over midnight; a == b is an empty window.
static func _in_window(t: int, a: int, b: int) -> bool:
	if a <= b:
		return t >= a and t < b
	return t >= a or t < b


## Compares a stored flag value with its text form from the data.
static func _value_matches(value: Variant, text: String) -> bool:
	match typeof(value):
		TYPE_BOOL:
			var lower := text.to_lower()
			return (lower == "true" and value) or (lower == "false" and not value)
		TYPE_INT:
			if text.is_valid_int():
				return int(value) == text.to_int()
			return text.is_valid_float() and is_equal_approx(float(value), text.to_float())
		TYPE_FLOAT:
			return text.is_valid_float() and is_equal_approx(float(value), text.to_float())
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value) == text
	return str(value) == text


static func _bool(value: Variant) -> _Result:
	return _Result.TRUE if value else _Result.FALSE
