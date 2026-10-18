class_name LetterRules
extends RefCounted
## Pure letter rules (docs/PHASE9_DESIGN.md §2.4, §3.4; P3): the pool pick (deterministic from the corpse's seed and
## the day, never twice, pool conditions), why a choice is dimmed, the piety event of a choice (asked for / sealed / at
## the grave) – and the small action interpreter shared by Letters and Stranger (apply_actions).
##
## Pool conditions (LetterData.conditions / StrangerOfferData.conditions):
## - `story:<id>`        only for the corpse of that story (Letters.assign) – never a random pick.
## - `kin_house`         the dead has a mourning household (checked by the caller – Letters.assign filters the pool).
## - `robber_fate:<f>`   NightRobber.fate() == f (Lambert let go …).
## - `flag:<name>` / `not_flag:<name>`   GameState.
##
## The context of choice_block_reason (built by Letters.choices / decide):
##   state, opened, answered (bool), kind, npc (the speaker), recipient_npc (who takes it in person, &"" = nobody),
##   post (bool: goes by post), carrier, place (&"stove" | &"forge" | &"desk"), grave_id (where the player stands),
##   target_grave (read at this grave), bury_graves (PackedStringArray: lay it into these graves), burying (bool: the
##   sender is carried to its open grave right now), has_ink (bool), aschau (bool: L5).

const COND_STORY := "story"
const COND_KIN_HOUSE := "kin_house"
const COND_ROBBER_FATE := "robber_fate"
const COND_FLAG := "flag"
const COND_NOT_FLAG := "not_flag"
const ROBBER_GROUP := &"night_robber"

const CHOICE_DELIVER := &"deliver"
const CHOICE_READ := &"read"
const CHOICE_READ_GRAVE := &"read_grave"
const CHOICE_ANSWER := &"answer"
const CHOICE_BURN := &"burn"
const CHOICE_BURY := &"bury"

const STATE_FOUND := &"found"
const STATE_RECEIVED := &"received"
## letter_changed states of a decision (§2.4.2 „entschieden"). Reading it yourself (&"read") is no decision: the letter
## stays in the hand and can still be delivered, burned … (Benutzerentscheidung §14.6: the text stays in the Merkbuch).
const DECIDED: Array[StringName] = [&"posted", &"delivered", &"read_grave", &"answered", &"burned", &"buried"]
## States in which the letter is still in the gravekeeper's hand (undecided; carried = an errand letter).
const OPEN: Array[StringName] = [STATE_FOUND, STATE_RECEIVED, &"carried"]

const PLACES_BURN: Array[StringName] = [&"stove", &"forge"]
const PLACE_DESK := &"desk"

const TEXT_DECIDED := "Über diesen Brief ist schon entschieden."
const TEXT_ALREADY_READ := "Du hast ihn schon gelesen."
const TEXT_NOBODY := "An niemanden, den du hinbringen kannst."
const TEXT_TO_PERSON := "Bring ihn %s."
const TEXT_POST_ONLY := "Das geht nur mit der Post – Hanne oder Osric."
const TEXT_NOT_POSTED := "Der muss in die Hand, nicht zur Post."
const TEXT_NO_GRAVE := "Der, dem er gehört, liegt in keinem Grab."
const TEXT_AT_GRAVE := "Am Grab vorlesen – dort, wo er liegt."
const TEXT_NO_ANSWER := "Darauf kannst du nicht antworten."
const TEXT_ANSWERED := "Du hast schon geantwortet."
const TEXT_AT_DESK := "Antworten kannst du am Pult in der Hütte."
const TEXT_NO_INK := "Zum Antworten fehlt dir Tinte."
const TEXT_AT_FIRE := "Verbrennen – im Ofen der Hütte oder in der Esse."
const TEXT_BURY_WHEN := "Das geht nur am offenen Grab, wenn du ihn hineinlegst."
const TEXT_BURY_WHERE := "Der gehört auf ein bestimmtes Grab."
const TEXT_ASCHAU := "Dieser Brief ist an Lorenz. Den entscheidest du anders."
## W3 QA-Fix QA9-08: an errand letter whose order was missed (Orders failed) is not posted or handed over any more.
const TEXT_ERRAND_LATE := "Dafür ist es zu spät. Der Auftrag ist verstrichen – der Brief käme nicht mehr rechtzeitig an."


## A pocket letter of the pool for a corpse with the trait letter: the letters of `pool` (kind pocket, not in `used`,
## no story letter, conditions met) sorted by id, one of them by hash([seed, day]). &"" = none left.
static func pick(seed: int, day: int, used: Array[StringName], pool: Array[LetterData], tree: SceneTree) -> StringName:
	var cands: Array[LetterData] = []
	for l: LetterData in pool:
		if l == null or l.id == &"" or l.kind != LetterData.KIND_POCKET or used.has(l.id):
			continue
		if pool_ok(l.conditions, tree):
			cands.append(l)
	if cands.is_empty():
		return &""
	cands.sort_custom(func(a: LetterData, b: LetterData) -> bool: return String(a.id) < String(b.id))
	return cands[posmod(hash([seed, day, &"letter"]), cands.size())].id


## The pool conditions that do not need the corpse (story letters are never picked at random; kin_house is the
## caller's). Unknown keys → false.
static func pool_ok(conditions: PackedStringArray, tree: SceneTree) -> bool:
	for c: String in conditions:
		var key := c.get_slice(":", 0).strip_edges()
		var arg := c.substr(key.length() + 1).strip_edges() if c.contains(":") else ""
		match key:
			COND_STORY:
				return false
			COND_KIN_HOUSE:
				pass
			COND_ROBBER_FATE:
				if robber_fate(tree) != StringName(arg):
					return false
			COND_FLAG:
				if not GameState.flag_on(StringName(arg)):
					return false
			COND_NOT_FLAG:
				if GameState.flag_on(StringName(arg)):
					return false
			_:
				return false
	return true


## The story a letter belongs to (`story:<id>`), &"" = none.
static func story_of(letter: LetterData) -> StringName:
	if letter == null:
		return &""
	for c: String in letter.conditions:
		if c.begins_with(COND_STORY + ":"):
			return StringName(c.substr(COND_STORY.length() + 1).strip_edges())
	return &""


static func needs_kin_house(letter: LetterData) -> bool:
	return letter != null and letter.conditions.has(COND_KIN_HOUSE)


## Lambert's fate (NightRobber in the tree; &"" without one).
static func robber_fate(tree: SceneTree) -> StringName:
	var robber := tree.get_first_node_in_group(ROBBER_GROUP) if tree != null else null
	if robber != null and robber.has_method(&"fate"):
		return StringName(str(robber.call(&"fate")))
	return &""


## Why `choice` is dimmed for `letter` in `context` ("" = possible). Never a number (§7.3).
static func choice_block_reason(letter: LetterData, choice: StringName, context: Dictionary) -> String:
	if letter == null:
		return TEXT_NOBODY
	var state := StringName(str(context.get("state", STATE_FOUND)))
	if context.get("aschau", false) == true:
		return TEXT_ASCHAU
	match choice:
		CHOICE_READ:
			if context.get("opened", false) == true:
				return TEXT_ALREADY_READ
			if state in [&"burned", &"posted", &"delivered", &"buried"]:
				return TEXT_DECIDED
			return ""
		CHOICE_ANSWER:
			if not can_answer(letter):
				return TEXT_NO_ANSWER
			if context.get("answered", false) == true:
				return TEXT_ANSWERED
			if state in [&"burned", &"buried", &"delivered"]:
				return TEXT_DECIDED
			if StringName(str(context.get("place", ""))) != PLACE_DESK:
				return TEXT_AT_DESK
			if context.get("has_ink", false) != true:
				return TEXT_NO_INK
			return ""
	if not state in OPEN:
		return TEXT_DECIDED
	match choice:
		CHOICE_DELIVER:
			if context.get("errand_late", false) == true:
				return TEXT_ERRAND_LATE
			if context.get("post", false) == true:
				return "" if StringName(str(context.get("carrier", ""))) != &"" else TEXT_POST_ONLY
			var who := StringName(str(context.get("recipient_npc", "")))
			if who == &"":
				return TEXT_NOBODY
			if StringName(str(context.get("carrier", ""))) != &"":
				return TEXT_NOT_POSTED
			if StringName(str(context.get("npc", ""))) != who:
				return TEXT_TO_PERSON % str(context.get("recipient_name", "dem, dem er gehört"))
			return ""
		CHOICE_READ_GRAVE:
			var target := str(context.get("target_grave", ""))
			if target == "":
				return TEXT_NO_GRAVE
			return "" if str(context.get("grave_id", "")) == target else TEXT_AT_GRAVE
		CHOICE_BURN:
			return "" if StringName(str(context.get("place", ""))) in PLACES_BURN else TEXT_AT_FIRE
		CHOICE_BURY:
			var at := str(context.get("grave_id", ""))
			var graves: Variant = context.get("bury_graves", PackedStringArray())
			if at != "" and (graves is PackedStringArray or graves is Array) and at in graves:
				return ""
			if context.get("burying", false) == true:
				return ""
			return TEXT_BURY_WHERE if letter.asks == &"grave" and letter.recipient == &"grave" else TEXT_BURY_WHEN
	return TEXT_NOBODY


## Post for the dead can always be answered (to the sender); a pocket letter only when it carries a reply (L2).
## (A reply_text with reply_coins is the thanks of a counting house – nothing to answer.)
static func can_answer(letter: LetterData) -> bool:
	if letter == null or letter.recipient == &"none":
		return false
	return letter.kind == LetterData.KIND_POST or (letter.reply_text != "" and reply_coins(letter) == 0)


## reply_coins:<n> of the deliver actions (lg_town: the counting house thanks with coins on Hanne's next day).
static func reply_coins(letter: LetterData) -> int:
	if letter == null:
		return 0
	for a: String in letter.choice_actions.get(CHOICE_DELIVER, PackedStringArray()):
		if a.begins_with("reply_coins:"):
			return maxi(int(a.get_slice(":", 1)), 0)
	return 0


## The piety event of a choice (§2.4.2, §2.9; Benutzerentscheidung §14.6): opening a sealed letter that is not to you
## −1 unless it asks to be read; read at the grave +1; burning +1 when the letter asks for it, otherwise −1; laid into the
## grave +1; an answer +1 (when it is posted). &"" = none.
static func piety_event(letter: LetterData, choice: StringName) -> StringName:
	if letter == null:
		return &""
	match choice:
		CHOICE_READ:
			return &"letter_read_sealed" if letter.sealed and letter.asks != &"read" else &""
		CHOICE_READ_GRAVE:
			return &"letter_read_grave"
		CHOICE_BURN:
			return &"letter_burned_asked" if letter.asks == &"burn" else &"letter_burned_unasked"
		CHOICE_BURY:
			return &"letter_buried"
		CHOICE_ANSWER:
			return &"letter_answered"
	return &""


## Runs `actions` (DialogueActions syntax + a few own keys) for Letters / Stranger. Own keys, called directly on the
## systems (so they work before P6's dialogue actions exist): piety_event:<id> · piety_add:<n> · rep_event:<id> ·
## rel_add:<npc>:<n> · rel_gain:<npc>:<gain> · goodwill:<kin>:<n> (`kin` = context.kin) · set_flag:<f>[:<v>] ·
## add_clue:<id> · give_item:<id>:<n> (context.inventory) · note_event:<event>[:<npc>,…]. Keys handled by the caller
## (reply_coins, rumor) are skipped; anything else goes to DialogueActions.apply. `reason` is the change reason.
static func apply_actions(actions: PackedStringArray, context: Dictionary, tree: SceneTree, reason: String) -> void:
	for raw: String in actions:
		var text := raw.strip_edges()
		if text == "":
			continue
		var p := text.split(":")
		var key := p[0]
		match key:
			"piety_event":
				var piety := _node(tree, &"piety")
				if piety != null and p.size() > 1:
					piety.call(&"event", StringName(p[1]), reason)
			"piety_add":
				var piety := _node(tree, &"piety")
				if piety != null and p.size() > 1:
					piety.call(&"change", int(p[1]), reason)
			"rep_event":
				var rep := _node(tree, &"reputation")
				if rep != null and p.size() > 1:
					rep.call(&"event", StringName(p[1]), reason)
			"rel_add":
				var rel := _node(tree, &"relationships")
				if rel != null and p.size() > 2:
					rel.call(&"add", StringName(p[1]), int(p[2]), reason)
			"rel_gain":
				var rel := _node(tree, &"relationships")
				if rel != null and p.size() > 2:
					rel.call(&"add", StringName(p[1]), int(rel.call(&"gain", StringName(p[2]))), reason)
			"goodwill":
				var visitors := _node(tree, &"visitors")
				if visitors != null and p.size() > 2:
					var kin := StringName(p[1])
					if kin == &"kin":
						kin = StringName(str(context.get("kin", "")))
					if kin != &"":
						visitors.call(&"add_goodwill", kin, int(p[2]))
			"set_flag":
				if p.size() > 1 and p[1] != "":
					GameState.set_flag(StringName(p[1]), DialogueSyntax.parse_value(p[2]) if p.size() > 2 else true)
			"add_clue":
				var journal := _node(tree, &"journal")
				if journal != null and p.size() > 1:
					journal.call(&"add_clue", StringName(p[1]), str(context.get("corpse_id", "")), false)
			"give_item":
				var inv := context.get("inventory") as Inventory
				if inv != null and p.size() > 1:
					var n := int(p[2]) if p.size() > 2 else 1
					var left := inv.add_item(StringName(p[1]), n)
					if left < n:
						EventBus.notification_requested.emit(DialogueActions.REWARD_FORMAT % [n - left, _item_name(StringName(p[1]))], &"reward")
			"note_event":
				var life := _node(tree, &"npc_life")
				if life != null and p.size() > 1:
					var npcs: Array[StringName] = []
					if p.size() > 2:
						for n: String in p[2].split(","):
							if n.strip_edges() != "":
								npcs.append(StringName(n.strip_edges()))
					life.call(&"note_event", StringName(p[1]), npcs)
			"reply_coins", "rumor":
				pass
			_:
				DialogueActions.apply(text, context)


static func _node(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null


static func _item_name(id: StringName) -> String:
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)
