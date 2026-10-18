class_name Letters
extends Node
## Systems/Letters (docs/PHASE9_DESIGN.md §2.4, §3.1, §3.3, §3.4, §5.1; P3), groups &"letters", &"saveable",
## save_id letters / 83: letters in the pockets of the dead, the post for the dead, errand letters and answers.
##
## - **Pockets (§2.4.2):** from p9_open on CorpseManager calls assign(record) at the delivery: a story letter of the
##   corpse (`story:<id>`, D3 „An Grete"), else the first forced_after_open deliveries carry L1–L3 (forced_ids), else a
##   corpse with the trait letter gets one of the pool (LetterRules.pick, never twice, `kin_house` only with a
##   household). The pockets step of the examination calls on_found → record {id, corpse, state found}, the unique item
##   `letter` (uid lt_0001 …) into the inventory. No room → the letter waits (held corpse) and comes at the next morning.
## - **Post for the dead (§2.4.3):** at the morning of p9_open_day + post_offsets the next post letter (POST_ORDER)
##   whose dead lies in a grave arrives (state received, Osric's note); the letter to L. Aschau with Hanne on her first
##   day after the first answer was posted (L5).
## - **Choices (§2.4.2, Benutzerentscheidung §14.6):** choices(uid, context) → {id, label, reason} (dimmed with a reason,
##   never a number); decide(uid, choice, context): deliver (in person – or read aloud to one who cannot read – or by
##   post with a carrier) · read (open it yourself: no decision, the text stays in the Merkbuch; sealed and not asking
##   for it: piety −1) · read_grave (10 min at the grave: piety +1, the ghost +1 tonight) · answer (desk, 1 ink → item
##   letter_reply; posted: piety +1, a counter-letter the day after) · burn (stove / forge: asked +1, else −1) · bury (into
##   the open grave of the sender, D3's letter onto Grete's grave: piety +1, the ghost +1 for good). A decision removes
##   the item; a letter is decided only once. Decisions note `pocket_decided` / `post_decided`, posted answers
##   `answer_posted` (Quests.note); the chain steps are P1's.
## - **Errands (§2.4.4):** errand_letter(order_id, inv) hands the letter of an accepted quest order (E1 Gesa → post,
##   E2 Fenner's sealed notice → Lenz); give_to_carrier / decide(deliver) completes the order (Orders.complete); opening
##   the sealed one costs its `seal_broken_rel`.
## - **Effects** are direct calls (Piety, Reputation, Relationships, Visitors, NpcLife, JournalManager, Orders, Quests)
##   – never from a signal listener. letter_changed(uid, id, state) for every change.
## - **Ghosts:** ghost_bonus(grave_id) / letter_tonight(grave_id) for GhostManager (GhostMood.letter_bonus,
##   GhostMood.letter_care_key – the wiring is the owner's of ghost_manager.gd).
## - Time-driven like the other Phase-9 systems: time_tick → apply_morning(day) at the first minute ≥ 06:00.

const GROUP := &"letters"
const UID_PREFIX := "lt_"
const UID_FORMAT := "lt_%04d"
const CARRIER_PEDDLER := &"peddler"
const CARRIER_CARTER := &"carter"
const CARRIERS: Array[StringName] = [CARRIER_PEDDLER, CARRIER_CARTER]
const ITEM_LETTER := &"letter"
const ITEM_REPLY := &"letter_reply"
const COIN_ITEM := &"coin"
const COIN_REASON := &"post"
const MORNING_MINUTE := 360
## letter_changed states that are a decision (§2.4.2 „entschieden").
const DECIDED_STATES: Array[StringName] = LetterRules.DECIDED
## „zugestellt": handed over in person or given to the post.
const DELIVERED_STATES: Array[StringName] = [&"posted", &"delivered"]
const KIND_REPLY := LetterData.KIND_REPLY
const KIND_ERRAND := LetterData.KIND_ERRAND
const STATE_FOUND := &"found"
const STATE_RECEIVED := &"received"
const STATE_WRITTEN := &"written"
const STATE_CARRIED := &"carried"
const STATE_POSTED := &"posted"
const STATE_DELIVERED := &"delivered"
const STATE_READ := &"read"
const STATE_READ_GRAVE := &"read_grave"
const STATE_ANSWERED := &"answered"
const STATE_BURNED := &"burned"
const STATE_BURIED := &"buried"
const STATE_RECEIVED_REPLY := &"received"
## Held by the gravekeeper / still in the pockets (no room at the find).
const HELD_PLAYER := "player"
const HELD_CORPSE := "corpse"
## The post for the dead in this order (§2.4.3: Prio A the first two); unknown post letters follow by id.
const POST_ORDER: Array[StringName] = [&"lpo_quendel", &"lpo_wernstein", &"lpo_ott", &"lpo_hagedorn"]
## They cannot read: reading the letter to them counts as delivering it (§2.4.2 b).
const ILLITERATE: Array[StringName] = [&"kin_sieber", &"beggar", &"kin_kehr"]
## Recipients that take the letter through someone else: Lambert's goes with Veit (§2.4.2 lg_lambert).
const CARRIED_BY: Dictionary[StringName, StringName] = {&"robber": &"beggar"}
## Where to find them (labels of the letter card, §7.3).
const PLACES: Dictionary[StringName, String] = {&"innkeeper": "im Holderkrug", &"grocer": "im Laden", &"priest": "in St. Gallus",
		&"smith": "in der Schmiede", &"mayor": "im Schultheißenhaus", &"surgeon": "in seinem Haus", &"washer": "im Holunderwinkel",
		&"oldwoman": "im Dorf", &"beggar": "an der Brunnenbank", &"apprentice": "auf dem Friedhof"}
## Quest notes (the step keys of q_letters, docs/PHASE9_DESIGN.md W0-Notizen 10).
const NOTE_POCKET := &"pocket_decided"
const NOTE_POST := &"post_decided"
const NOTE_ANSWER := &"answer_posted"
const QUEST_LETTERS := &"q_letters"
const STEP_ASCHAU := &"l5"
## L5 (§2.4.5): the four ways with the letter to L. Aschau = the choices of q_letters / l5.
const ASCHAU_CHOICES: Array[StringName] = [&"open", &"keep", &"liesel", &"burn"]
const ASCHAU_LABELS: Dictionary[StringName, String] = {&"open": "Öffnen", &"keep": "Versiegelt aufheben", &"liesel": "Liesel geben",
		&"burn": "Verbrennen"}
const STAT_FOUND := &"letters_found"
const STAT_DECIDED := &"letters_decided"
const STAT_DELIVERED := &"letters_delivered"
const STAT_READ := &"letters_read"
const STAT_BURNED := &"letters_burned"
const STAT_BURIED := &"letters_buried"
const STAT_ANSWERED := &"letters_answered"
const STAT_POST := &"post_received"
const REASON := "Ein Brief"
const REASON_POST := "Postgeld"
const REASON_ANSWER_COIN := "Botenlohn"
const EVENT_DELIVERED := &"letter_delivered"
const GAIN_DELIVERED := &"letter_delivered"
const GAIN_SEAL := &"seal_broken"
const GOODWILL_DELIVERED := 2

const TEXT_FOUND := "Ein Brief. Außen: %s"
const TEXT_FOUND_NO_ROOM := "Ein Brief in der Tasche – kein Platz. Er bleibt, bis du Platz hast."
const TEXT_POST := "Osric hat Post für %s. „Die Post weiß das nicht. Ich schon.“"
const TEXT_ASCHAU := "Hanne hat einen Brief dabei: „An L. Aschau, Totengräber zu Hollerbrück.“ Gesiegelt mit Anker und Schlange."
const TEXT_DELIVERED := "Du gibst den Brief ab."
const TEXT_READ_ALOUD := "Du liest den Brief vor. Er hört zu, bis zum Ende."
const TEXT_POSTED := "Der Brief geht mit der Post."
const TEXT_READ_GRAVE := "Du liest den Brief am Grab vor und lässt ihn unter dem Stein."
const TEXT_BURNED := "Das Papier rollt sich ein und ist fort."
const TEXT_BURIED := "Der Brief liegt jetzt bei ihm."
const TEXT_BURIED_GRAVE := "Du legst den Zettel aufs Grab und drückst ihn mit einem Stein fest."
const TEXT_ANSWER := "Du schreibst eine Antwort, kurz und so ehrlich, wie es geht."
const TEXT_REPLY_DEFAULT := "Ein Brief zurück: „Danke, dass Sie es mir geschrieben haben.“"
const TEXT_NO_COIN := "Für das Postgeld fehlt dir eine Münze."
const TEXT_SEAL := "Das Siegel bricht. Das sieht man."
const LABEL_DELIVER := "Zustellen – %s %s"
const LABEL_READ_TO := "Vorlesen – %s %s"
const LABEL_POST := "Mit der Post in die Stadt – Hanne oder Osric"
const LABEL_KIN := "Den Angehörigen geben – %s"
const LABEL_READ := "Öffnen und lesen"
const LABEL_READ_OPEN := "Lesen"
const LABEL_LOOK_INSIDE := "Hineinsehen"
const LABEL_READ_GRAVE := "Am Grab vorlesen – %s"
const LABEL_ANSWER := "Antwort schreiben – Pult in der Hütte"
const LABEL_BURN := "Verbrennen – Ofen in der Hütte"
const LABEL_BURY := "Mit ins Grab legen"
const LABEL_BURY_GRAVE := "Aufs Grab legen – %s"
## Errand letters (§2.4.4, texts P3): outside / text by order id.
const ERRAND_OUTSIDE: Dictionary[StringName, String] = {&"oq_gesa_brother": "An den Musketier Peter Ott, beim Regiment in Mainz",
		&"oq_fenner_seal": "An Herrn Pfarrer Lenz. Bekanntmachung der Gemeinde"}
const ERRAND_TEXT: Dictionary[StringName, String] = {
	&"oq_gesa_brother": "Lieber Peter. Vater ist tot. Er ist in der Nacht gegangen, ganz still, sagt der Totengräber. Die Kuh hat gekalbt, ein Stierkalb. Komm, wenn sie dich lassen. Deine Gesa.",
	&"oq_fenner_seal": "Bekanntmachung der Gemeinde Hollerbrück. Die Wege zum Friedhof sind bis Lichtmess von Laub und Schnee freizuhalten, jeder vor seinem Haus. Wer es nicht tut, zahlt einen Groschen in die Armenkasse. Fenner, Schultheiß."}
const TEXT_NOTICE_PUBLIC := "Bekanntmachung der Gemeinde Hollerbrück. Wer nachts in einem Haus ein Licht sieht, das keiner aus dem Haus angezündet hat, meldet es dem Schultheiß. Es wird aufgeschrieben. Fenner, Schultheiß."

@export var save_id: String = "letters"
@export var save_order: int = 83

## Rules; null = data/config/letters_config.tres (resolved lazily).
var config: LettersConfig
## Letters by id; empty = Database.letters() (tests inject fixtures).
var letter_table: Dictionary[StringName, LetterData] = {}
## q_letters for the L5 fallback (null = Database.quest).
var quest_data: QuestData

## uid → {id, corpse, state, day, kind?, opened?, answered?, src?, asked?, held?, order?}
var _records: Dictionary[String, Dictionary] = {}
var _next_uid: int = 1
var _forced_used: int = 0
## Offsets of post_offsets already handled.
var _post_done: Array[int] = []
## [{uid, due, coins?, peddler?}] – the counter-letters.
var _replies: Array[Dictionary] = []
## Day of the last reputation for a delivered letter (cap rep_cap_day).
var _rep_day: int = 0
## grave_id → night (day) a letter was read there.
var _read_night: Dictionary[String, int] = {}
## Graves holding a letter (laid into the grave).
var _buried_graves: PackedStringArray = []
var _morning_day: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- pockets ----------------------------------------------------------------------------------------

## At the delivery (forced / pool) – from p9_open on, only for a record without letter_id.
func assign(record: CorpseRecord) -> void:
	if record == null or record.letter_id != &"" or not GameState.flag_on(_cfg().open_flag):
		return
	var used := used_ids()
	if record.story_id != &"":
		for l: LetterData in _pocket_pool():
			if LetterRules.story_of(l) == record.story_id and not used.has(l.id):
				record.letter_id = l.id
				return
		return
	var cfg := _cfg()
	while _forced_used < cfg.forced_after_open and _forced_used < cfg.forced_ids.size():
		var id := cfg.forced_ids[_forced_used]
		_forced_used += 1
		if not used.has(id) and _data(id) != null:
			record.letter_id = id
			return
	if not record.traits.has(&"letter"):
		return
	var pool: Array[LetterData] = []
	var household := _has_household(record)
	for l: LetterData in _pocket_pool():
		if LetterRules.needs_kin_house(l) and not household:
			continue
		pool.append(l)
	var excluded := used.duplicate()
	for id: StringName in cfg.forced_ids:
		if not excluded.has(id):
			excluded.append(id)
	var picked := LetterRules.pick(record.seed, TimeManager.day, excluded, pool, get_tree() if is_inside_tree() else null)
	if picked != &"":
		record.letter_id = picked


## The letter ids already given out (corpse records + own records).
func used_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var manager := _first(&"corpse_manager")
	if manager != null and manager.has_method(&"records"):
		for r: CorpseRecord in manager.call(&"records"):
			if r.letter_id != &"" and not out.has(r.letter_id):
				out.append(r.letter_id)
	for uid: String in _records:
		var id := _id_of(uid)
		if id != &"" and not out.has(id):
			out.append(id)
	return out


## Pockets → uid ("" = no letter). Idempotent per corpse.
func on_found(corpse_id: String, inv: Inventory) -> String:
	var record := _corpse(corpse_id)
	if record == null or record.letter_id == &"":
		return ""
	for uid: String in _records:
		if str(_records[uid].get("corpse", "")) == corpse_id and _kind(uid) == LetterData.KIND_POCKET:
			return uid
	var letter_data := _data(record.letter_id)
	if letter_data == null:
		return ""
	var uid := _new_uid()
	_records[uid] = {"id": String(record.letter_id), "corpse": corpse_id, "state": String(STATE_FOUND), "day": TimeManager.day,
			"kind": String(LetterData.KIND_POCKET)}
	GameState.add_stat(STAT_FOUND, 1)
	_hand_over(uid, inv)
	EventBus.letter_changed.emit(uid, record.letter_id, STATE_FOUND)
	return uid


# --- reading --------------------------------------------------------------------------------------------

func letter(uid: String) -> LetterData:
	if not _records.has(uid):
		return null
	if _kind(uid) == KIND_ERRAND:
		return _errand_data(uid)
	return _data(_id_of(uid))


func state(uid: String) -> StringName:
	return StringName(str(_records[uid].get("state", ""))) if _records.has(uid) else &""


func corpse_of(uid: String) -> String:
	return str(_records[uid].get("corpse", "")) if _records.has(uid) else ""


## &"pocket" | &"post" | &"reply" | &"errand" (&"" = unknown uid).
func kind_of(uid: String) -> StringName:
	return _kind(uid) if _records.has(uid) else &""


func is_opened(uid: String) -> bool:
	return _records.has(uid) and _records[uid].get("opened", false) == true


## All uids (sorted).
func uids() -> PackedStringArray:
	var out := PackedStringArray(_records.keys())
	out.sort()
	return out


## Letters the gravekeeper holds and has not decided (pocket / post / errand / reply, in the hand), sorted.
func open_uids() -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in uids():
		if str(_records[uid].get("held", HELD_PLAYER)) != HELD_PLAYER:
			continue
		var s := state(uid)
		if s in [STATE_FOUND, STATE_RECEIVED, STATE_WRITTEN, STATE_CARRIED]:
			out.append(uid)
	return out


## The Merkbuch copies (§7.2 „Briefe"): uids whose text was read (opened, read at a grave or read aloud).
func read_uids() -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in uids():
		if is_opened(uid):
			out.append(uid)
	return out


## The text a card may show: the letter's text once opened (or unsealed), otherwise only the outside.
func visible_text(uid: String) -> String:
	var l := letter(uid)
	if l == null:
		return ""
	return l.text if is_opened(uid) or not l.sealed else ""


# --- choices --------------------------------------------------------------------------------------------

## {id, label, reason} – every choice this letter knows (reason "" = possible here and now).
## context: inventory, npc (speaker id) / speaker, carrier, place (&"stove" | &"forge" | &"desk"), grave_id, burying
## (corpse id carried to its open grave).
func choices(uid: String, context: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var l := letter(uid)
	if l == null:
		return out
	if _is_aschau(uid):
		for c: StringName in ASCHAU_CHOICES:
			out.append({"id": c, "label": ASCHAU_LABELS[c], "reason": "" if state(uid) == STATE_RECEIVED else LetterRules.TEXT_DECIDED})
		return out
	var ctx := _facts(uid, context)
	for c: StringName in _choice_ids(uid, l, ctx):
		out.append({"id": c, "label": _label(uid, l, c, ctx), "reason": LetterRules.choice_block_reason(l, c, ctx)})
	return out


func decide(uid: String, choice: StringName, context: Dictionary) -> bool:
	var l := letter(uid)
	if l == null:
		return false
	if _is_aschau(uid):
		return _decide_aschau(uid, choice, context)
	var ctx := _facts(uid, context)
	if not choice in _choice_ids(uid, l, ctx) or LetterRules.choice_block_reason(l, choice, ctx) != "":
		return false
	var inv := ctx.get("inventory") as Inventory
	match choice:
		LetterRules.CHOICE_DELIVER:
			if ctx.post == true:
				return give_to_carrier(uid, StringName(str(ctx.carrier)), inv)
			return _deliver(uid, l, ctx, inv)
		LetterRules.CHOICE_READ:
			_records[uid]["opened"] = true
			GameState.add_stat(STAT_READ, 1)
			if _kind(uid) == KIND_ERRAND:
				_seal_broken(uid)
			else:
				_piety(LetterRules.piety_event(l, choice))
			_actions(l, choice, ctx)
			EventBus.letter_changed.emit(uid, l.id, STATE_READ)
			return true
		LetterRules.CHOICE_READ_GRAVE:
			_records[uid]["opened"] = true
			GameState.add_stat(STAT_READ, 1)
			_read_night[str(ctx.target_grave)] = _night()
			_piety(LetterRules.piety_event(l, choice))
			_close(uid, l, STATE_READ_GRAVE, inv, ctx, TEXT_READ_GRAVE)
			return true
		LetterRules.CHOICE_ANSWER:
			return _answer(uid, l, ctx, inv)
		LetterRules.CHOICE_BURN:
			GameState.add_stat(STAT_BURNED, 1)
			_piety(LetterRules.piety_event(l, choice))
			_close(uid, l, STATE_BURNED, inv, ctx, TEXT_BURNED)
			return true
		LetterRules.CHOICE_BURY:
			GameState.add_stat(STAT_BURIED, 1)
			var grave := str(ctx.get("grave_id", ""))
			if grave != "" and not _buried_graves.has(grave):
				_buried_graves.append(grave)
			_piety(LetterRules.piety_event(l, choice))
			_close(uid, l, STATE_BURIED, inv, ctx, TEXT_BURIED_GRAVE if l.recipient == &"grave" and not ctx.burying else TEXT_BURIED)
			return true
	return false


## Post for the dead that arrived on `day` (Osric 07:40, Hanne) – uids.
func post_today(day: int) -> Array[String]:
	var out: Array[String] = []
	for uid: String in uids():
		if _kind(uid) == LetterData.KIND_POST and int(_records[uid].get("day", -1)) == day:
			out.append(uid)
	return out


## Gives a pocket letter to the town, an answer or an errand letter to Hanne / Osric: 1 coin postage (purpose &"post"),
## the item goes, state posted. &"peddler" | &"carter".
func give_to_carrier(uid: String, carrier: StringName, inv: Inventory) -> bool:
	if post_block_reason(uid, carrier, inv) != "":
		return false
	var l := letter(uid)
	var kind := _kind(uid)
	var cost := _cfg().postage
	if cost > 0:
		if not inv.remove_item(COIN_ITEM, cost):
			return false
		GameState.note_coins_spent(cost, COIN_REASON)
	_remove_item(uid, inv)
	_records[uid]["state"] = String(STATE_POSTED)
	_records[uid]["carrier"] = String(carrier)
	EventBus.notification_requested.emit(TEXT_POSTED, &"info")
	match kind:
		KIND_REPLY:
			GameState.add_stat(STAT_ANSWERED, 1)
			_piety(LetterRules.piety_event(l, LetterRules.CHOICE_ANSWER))
			var src := str(_records[uid].get("src", ""))
			_replies.append({"uid": uid, "due": TimeManager.day + _cfg().reply_after_days})
			_quest_note(NOTE_ANSWER, src)
		KIND_ERRAND:
			if _records[uid].get("asked", false) != true:
				_piety(&"postage_paid")
			_complete_order(uid)
		_:
			GameState.add_stat(STAT_DELIVERED, 1)
			GameState.add_stat(STAT_DECIDED, 1)
			_rep_once()
			var coins := _reply_coins(l)
			if coins > 0 or l.reply_text != "":
				_replies.append({"uid": uid, "due": TimeManager.day + _cfg().reply_after_days, "coins": coins, "peddler": coins > 0})
			_actions(l, LetterRules.CHOICE_DELIVER, {"inventory": inv, "corpse_id": corpse_of(uid)})
			_quest_note(NOTE_POCKET if kind == LetterData.KIND_POCKET else NOTE_POST, uid)
	EventBus.letter_changed.emit(uid, l.id if l != null else _id_of(uid), STATE_POSTED)
	return true


## Why `uid` cannot go with `carrier` now ("" = it can).
func post_block_reason(uid: String, carrier: StringName, inv: Inventory) -> String:
	if not _records.has(uid) or not carrier in CARRIERS:
		return LetterRules.TEXT_NOBODY
	var l := letter(uid)
	var kind := _kind(uid)
	match kind:
		KIND_REPLY:
			if state(uid) != STATE_WRITTEN:
				return LetterRules.TEXT_DECIDED
		KIND_ERRAND:
			var o := _order(uid)
			if state(uid) != STATE_CARRIED:
				return LetterRules.TEXT_DECIDED
			if o == null or not (o.conditions.get("carriers", []) as Array).has(String(carrier)):
				return LetterRules.TEXT_NOT_POSTED
		_:
			if l == null or l.recipient != &"town":
				return LetterRules.TEXT_NOT_POSTED
			if not state(uid) in LetterRules.OPEN:
				return LetterRules.TEXT_DECIDED
	if inv == null or not inv.has_uid(uid):
		return LetterRules.TEXT_NOBODY
	if _cfg().postage > 0 and inv.count(COIN_ITEM) < _cfg().postage:
		return TEXT_NO_COIN
	return ""


## Decided pocket and post letters (§1.5 „5 Briefe entschieden").
func decided_count() -> int:
	return _count(DECIDED_STATES)


func delivered_count() -> int:
	return _count(DELIVERED_STATES)


# --- errands ------------------------------------------------------------------------------------------

## E1 / E2: the letter of an accepted quest order into `inv` (record {kind errand, order}); "" = no room / unknown.
func errand_letter(order_id: StringName, inv: Inventory) -> String:
	if inv == null or order_id == &"":
		return ""
	for uid: String in _records:
		if _kind(uid) == KIND_ERRAND and str(_records[uid].get("order", "")) == String(order_id) and state(uid) == STATE_CARRIED:
			return uid
	var uid := _new_uid()
	_records[uid] = {"id": String(order_id), "corpse": "", "state": String(STATE_CARRIED), "day": TimeManager.day,
			"kind": String(KIND_ERRAND), "order": String(order_id)}
	if not inv.add_unique(ITEM_LETTER, uid):
		_records.erase(uid)
		return ""
	EventBus.letter_changed.emit(uid, order_id, STATE_FOUND)
	return uid


## E1: asking the giver for the postage – Gesa has no coin, she gives straw flowers (the order's `or_pay`); no piety
## for paying yourself then.
func ask_postage(uid: String, inv: Inventory) -> bool:
	var o := _order(uid)
	if o == null or _records[uid].get("asked", false) == true or state(uid) != STATE_CARRIED:
		return false
	var item := StringName(str(o.conditions.get("or_pay", "")))
	if item == &"" or inv == null or inv.add_item(item, 1) > 0:
		return false
	_records[uid]["asked"] = true
	return true


## The errand letter of `order_id` in the hand ("" = none).
func errand_uid(order_id: StringName) -> String:
	for uid: String in uids():
		if _kind(uid) == KIND_ERRAND and str(_records[uid].get("order", "")) == String(order_id):
			return uid
	return ""


# --- ghosts ----------------------------------------------------------------------------------------------

## A letter was read at `grave_id` tonight (the night of today, or of yesterday before 06:00).
func letter_tonight(grave_id: String) -> bool:
	return int(_read_night.get(grave_id, -99)) == _night()


## +1 tonight (read aloud) + 1 for good (laid into the grave) – GhostMood.letter_bonus.
func ghost_bonus(grave_id: String) -> int:
	return GhostMood.letter_bonus(letter_tonight(grave_id), _buried_graves.has(grave_id))


# --- prompts (Desk, Stove, GravePlot) -------------------------------------------------------------------

## The first letter in `inv` that can be decided with `choice` in `context` ("" = none).
func first_for(choice: StringName, inv: Inventory, context: Dictionary) -> String:
	if inv == null:
		return ""
	var ctx := context.duplicate()
	ctx["inventory"] = inv
	for uid: String in open_uids():
		if not inv.has_uid(uid) or _is_aschau(uid):
			continue
		for c: Dictionary in choices(uid, ctx):
			if c.id == choice and str(c.reason) == "":
				return uid
	return ""


## Dialogue helper (P6 letter_for:<npc> / post_for:<kin>, letter_deliver, letter_read_aloud): the first letter in
## `inv` that `npc_id` takes in person ("" = none).
func letter_for(npc_id: StringName, inv: Inventory) -> String:
	return first_for(LetterRules.CHOICE_DELIVER, inv, {"npc": npc_id})


## Dialogue helper (P6 letter_post:<carrier>): the letters in `inv` Hanne / Osric can take now (postage in the bag).
func postable(carrier: StringName, inv: Inventory) -> PackedStringArray:
	var out := PackedStringArray()
	if inv == null:
		return out
	for uid: String in open_uids():
		if inv.has_uid(uid) and post_block_reason(uid, carrier, inv) == "":
			out.append(uid)
	return out


## The letters in `inv` that could be answered at the desk ("" = none) – prompt helper (ink not checked).
func answerable(inv: Inventory) -> String:
	if inv == null:
		return ""
	for uid: String in uids():
		var l := letter(uid)
		if l == null or _is_aschau(uid) or not LetterRules.can_answer(l) or _records[uid].get("answered", false) == true:
			continue
		if _kind(uid) in [KIND_REPLY, KIND_ERRAND]:
			continue
		if state(uid) in [STATE_BURNED, STATE_BURIED, STATE_DELIVERED, &""]:
			continue
		if state(uid) in LetterRules.OPEN and not inv.has_uid(uid):
			continue
		return uid
	return ""


func label_of(uid: String) -> String:
	var l := letter(uid)
	if l == null:
		return ""
	return l.outside if l.outside != "" else String(l.id)


# --- time --------------------------------------------------------------------------------------------

## Post (offsets, Aschau), counter-letters, pending pocket letters – idempotent per day.
func apply_morning(day: int) -> void:
	if day <= _morning_day:
		return
	_morning_day = day
	if not GameState.flag_on(_cfg().open_flag):
		return
	var inv := _player_inventory()
	_hand_pending(inv)
	_counter_letters(day, inv)
	var open_day := int(GameState.get_flag(&"p9_open_day", -1))
	if open_day >= 0:
		for offset: int in _cfg().post_offsets:
			if _post_done.has(offset) or day < open_day + offset:
				continue
			_post_done.append(offset)
			_receive_post(day, inv)
	_aschau(day, inv)


# --- save --------------------------------------------------------------------------------------------

## §5.1 {next_uid, records, forced_used, post_done, replies, rep_day} + read_night, buried_graves, morning_day.
func save_state() -> Dictionary:
	var records := {}
	for uid: String in _records:
		records[uid] = _records[uid].duplicate(true)
	var post: Array = []
	post.assign(_post_done)
	var replies: Array = []
	for r: Dictionary in _replies:
		replies.append(r.duplicate())
	var nights := {}
	for g: String in _read_night:
		nights[g] = _read_night[g]
	return {"next_uid": _next_uid, "records": records, "forced_used": _forced_used, "post_done": post,
			"replies": replies, "rep_day": _rep_day, "read_night": nights,
			"buried_graves": Array(_buried_graves), "morning_day": _morning_day}


func load_state(data: Dictionary) -> void:
	_records.clear()
	var records: Variant = data.get("records", {})
	if records is Dictionary:
		for uid: Variant in records:
			var raw: Variant = (records as Dictionary)[uid]
			if not raw is Dictionary:
				continue
			var rec := (raw as Dictionary).duplicate(true)
			if str(rec.get("id", "")) == "":
				continue
			rec["id"] = str(rec.get("id", ""))
			rec["state"] = str(rec.get("state", ""))
			rec["corpse"] = str(rec.get("corpse", ""))
			rec["day"] = _int(rec.get("day"), 0)
			if rec.has("kind") and not StringName(str(rec.get("kind"))) in LetterData.KINDS:
				rec.erase("kind")  # unknown kind (fuzzer): the letter's own kind
			_records[str(uid)] = rec
	_next_uid = maxi(_int(data.get("next_uid"), 1), 1)
	for uid: String in _records:
		if uid.begins_with(UID_PREFIX) and uid.substr(UID_PREFIX.length()).is_valid_int():
			_next_uid = maxi(_next_uid, int(uid.substr(UID_PREFIX.length())) + 1)
	_forced_used = maxi(_int(data.get("forced_used"), 0), 0)
	_post_done.clear()
	var post: Variant = data.get("post_done", [])
	if post is Array:
		for v: Variant in post:
			if v is int or v is float:
				_post_done.append(int(v))
	_replies.clear()
	var replies: Variant = data.get("replies", [])
	if replies is Array:
		for r: Variant in replies:
			if r is Dictionary and _records.has(str((r as Dictionary).get("uid", ""))):
				var e := (r as Dictionary).duplicate()
				e["uid"] = str(e.get("uid", ""))
				e["due"] = _int(e.get("due"), 0)
				_replies.append(e)
	_rep_day = _int(data.get("rep_day"), 0)
	_read_night.clear()
	var nights: Variant = data.get("read_night", {})
	if nights is Dictionary:
		for g: Variant in nights:
			_read_night[str(g)] = _int((nights as Dictionary)[g], -99)
	_buried_graves = PackedStringArray()
	var buried: Variant = data.get("buried_graves", [])
	if buried is Array:
		for g: Variant in buried:
			if g is String and not _buried_graves.has(g):
				_buried_graves.append(g)
	_morning_day = _int(data.get("morning_day"), 0)


# --- internals ----------------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= MORNING_MINUTE and day > _morning_day:
		apply_morning(day)


## The facts of the letter for LetterRules.choice_block_reason.
func _facts(uid: String, context: Dictionary) -> Dictionary:
	var l := letter(uid)
	var ctx := context.duplicate()
	if not ctx.has("inventory"):
		ctx["inventory"] = _player_inventory()
	var inv := ctx.get("inventory") as Inventory
	var npc := StringName(str(ctx.get("npc", "")))
	if npc == &"":
		npc = DialogueActions.speaker_id(ctx)
	ctx["npc"] = npc
	ctx["state"] = state(uid)
	ctx["opened"] = is_opened(uid)
	ctx["answered"] = _records[uid].get("answered", false) == true
	ctx["kind"] = _kind(uid)
	ctx["has_ink"] = inv != null and inv.has(_cfg().answer_item)
	var record := _corpse(corpse_of(uid))
	ctx["kin"] = _kin_of(record)
	ctx["corpse_id"] = corpse_of(uid)
	var who := _recipient_npc(uid, l, record)
	ctx["recipient_npc"] = who
	ctx["recipient_name"] = Phase8Texts.person_name(who) if who != &"" else ""
	ctx["post"] = _by_post(uid, l)
	ctx["target_grave"] = _target_grave(uid, l, record)
	ctx["bury_graves"] = _bury_graves(uid, l, record)
	var burying := str(ctx.get("burying", ""))
	ctx["burying"] = burying != "" and burying == corpse_of(uid) and _kind(uid) == LetterData.KIND_POCKET
	return ctx


## The choice ids that make sense for this letter (the others are not shown).
func _choice_ids(uid: String, l: LetterData, ctx: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var kind := _kind(uid)
	if kind == KIND_REPLY:
		return out
	if ctx.recipient_npc != &"" or ctx.post == true:
		out.append(LetterRules.CHOICE_DELIVER)
	out.append(LetterRules.CHOICE_READ)
	if kind == KIND_ERRAND:
		return out
	if str(ctx.target_grave) != "":
		out.append(LetterRules.CHOICE_READ_GRAVE)
	if LetterRules.can_answer(l):
		out.append(LetterRules.CHOICE_ANSWER)
	out.append(LetterRules.CHOICE_BURN)
	if kind == LetterData.KIND_POCKET:
		out.append(LetterRules.CHOICE_BURY)
	return out


func _label(uid: String, l: LetterData, choice: StringName, ctx: Dictionary) -> String:
	match choice:
		LetterRules.CHOICE_DELIVER:
			if ctx.post == true:
				return LABEL_POST
			var who := StringName(str(ctx.recipient_npc))
			var name := Phase8Texts.short_name(who)
			if _kind(uid) == LetterData.KIND_POST:
				return LABEL_KIN % Phase8Texts.person_name(who)
			var place := PLACES.get(who, "am Grab") as String
			return (LABEL_READ_TO if who in ILLITERATE else LABEL_DELIVER) % [name, place]
		LetterRules.CHOICE_READ:
			if _kind(uid) == KIND_ERRAND:
				return LABEL_LOOK_INSIDE if l.sealed else LABEL_READ_OPEN
			return LABEL_READ if l.sealed else LABEL_READ_OPEN
		LetterRules.CHOICE_READ_GRAVE:
			return LABEL_READ_GRAVE % _grave_label(str(ctx.target_grave))
		LetterRules.CHOICE_ANSWER:
			return LABEL_ANSWER
		LetterRules.CHOICE_BURN:
			return LABEL_BURN
		LetterRules.CHOICE_BURY:
			var graves: PackedStringArray = ctx.bury_graves
			if not graves.is_empty():
				return LABEL_BURY_GRAVE % _grave_label(graves[0])
			return LABEL_BURY
	return String(choice)


## Who takes it in person: a villager / kin / Veit for Lambert; a household letter its kin; post: the kin of the
## grave (lpo_ott: kin_ott). &"" = nobody.
func _recipient_npc(uid: String, l: LetterData, record: CorpseRecord) -> StringName:
	if l == null:
		return &""
	var kind := _kind(uid)
	if kind == KIND_ERRAND:
		var o := _order(uid)
		return o.recipient if o != null else &""
	match l.recipient:
		&"", &"kin":
			return _kin_of(record) if LetterRules.needs_kin_house(l) or l.recipient == &"kin" else &""
		&"town", &"none":
			return &""
		&"grave":
			if kind == LetterData.KIND_POST:
				return _kin_of(record)
			return &""
	if CARRIED_BY.has(l.recipient):
		return CARRIED_BY[l.recipient]
	return l.recipient


func _by_post(uid: String, l: LetterData) -> bool:
	var kind := _kind(uid)
	if kind == KIND_ERRAND:
		var o := _order(uid)
		return o != null and not (o.conditions.get("carriers", []) as Array).is_empty()
	return l != null and l.recipient == &"town" and kind == LetterData.KIND_POCKET


## Read at this grave: the sender's (pocket) or the dead's (post); "" = not in a grave.
func _target_grave(uid: String, l: LetterData, record: CorpseRecord) -> String:
	if l == null or record == null or record.location != CorpseRecord.LOCATION_BURIED or record.grave_id == "":
		return ""
	if _kind(uid) in [LetterData.KIND_POCKET, LetterData.KIND_POST]:
		return record.grave_id
	return ""


## A letter to the grave (D3 „An Grete") goes onto the graves of the household's other dead.
func _bury_graves(uid: String, l: LetterData, record: CorpseRecord) -> PackedStringArray:
	var out := PackedStringArray()
	if l == null or _kind(uid) != LetterData.KIND_POCKET or l.recipient != &"grave":
		return out
	var kin := _kin_of(record)
	var visitors := _first(&"visitors")
	if kin == &"" or visitors == null or not visitors.has_method(&"graves_of"):
		return out
	for g: String in visitors.call(&"graves_of", kin):
		if record == null or g != record.grave_id:
			out.append(g)
	return out


func _deliver(uid: String, l: LetterData, ctx: Dictionary, inv: Inventory) -> bool:
	var who := StringName(str(ctx.recipient_npc))
	var kind := _kind(uid)
	if kind == KIND_ERRAND:
		_remove_item(uid, inv)
		_records[uid]["state"] = String(STATE_DELIVERED)
		EventBus.notification_requested.emit(TEXT_DELIVERED, &"info")
		_complete_order(uid)
		EventBus.letter_changed.emit(uid, _id_of(uid), STATE_DELIVERED)
		return true
	GameState.add_stat(STAT_DELIVERED, 1)
	if who in ILLITERATE:
		_records[uid]["opened"] = true
		GameState.add_stat(STAT_READ, 1)
	_rep_once()
	var has_own := false
	var acts: PackedStringArray = l.choice_actions.get(LetterRules.CHOICE_DELIVER, PackedStringArray())
	for a: String in acts:
		if a.begins_with("rel_add") or a.begins_with("rel_gain") or a.begins_with("goodwill"):
			has_own = true
	if not has_own:
		var rel := _first(&"relationships")
		if rel != null and Database.villager(who) != null:
			rel.call(&"add", who, int(rel.call(&"gain", GAIN_DELIVERED)), REASON)
		elif Database.kin(who) != null:
			_goodwill(who, GOODWILL_DELIVERED)
	var life := _first(&"npc_life")
	if life != null and life.has_method(&"note_event"):
		life.call(&"note_event", EVENT_DELIVERED, [who] as Array[StringName])
	_close(uid, l, STATE_DELIVERED, inv, ctx, TEXT_READ_ALOUD if who in ILLITERATE else TEXT_DELIVERED)
	return true


## A decision: remove the item, the state, the actions of the choice, stats, the quest note, letter_changed.
func _close(uid: String, l: LetterData, new_state: StringName, inv: Inventory, ctx: Dictionary, text: String) -> void:
	var was := state(uid)
	_remove_item(uid, inv)
	_records[uid]["state"] = String(new_state)
	_records[uid]["decided_day"] = TimeManager.day
	if was in LetterRules.OPEN:
		GameState.add_stat(STAT_DECIDED, 1)
	var choice: StringName = {STATE_DELIVERED: LetterRules.CHOICE_DELIVER, STATE_READ_GRAVE: LetterRules.CHOICE_READ_GRAVE,
			STATE_BURNED: LetterRules.CHOICE_BURN, STATE_BURIED: LetterRules.CHOICE_BURY, STATE_ANSWERED: LetterRules.CHOICE_ANSWER}.get(
			new_state, &"")
	if text != "":
		EventBus.notification_requested.emit(text, &"info")
	_actions(l, choice, ctx)
	_quest_note(NOTE_POCKET if _kind(uid) == LetterData.KIND_POCKET else NOTE_POST, uid)
	EventBus.letter_changed.emit(uid, l.id, new_state)


## At the desk: 1 ink → the item letter_reply (own record kind reply, state written); the letter itself is decided
## (answered) when it was still in the hand.
func _answer(uid: String, l: LetterData, ctx: Dictionary, inv: Inventory) -> bool:
	if inv == null or not inv.has(_cfg().answer_item):
		return false
	var reply := _new_uid()
	_records[reply] = {"id": String(l.id), "corpse": corpse_of(uid), "state": String(STATE_WRITTEN), "day": TimeManager.day,
			"kind": String(KIND_REPLY), "src": uid}
	if not inv.remove_item(_cfg().answer_item, 1):
		_records.erase(reply)
		return false
	if not inv.add_unique(ITEM_REPLY, reply):
		inv.add_item(_cfg().answer_item, 1)
		_records.erase(reply)
		return false
	_records[uid]["answered"] = true
	EventBus.notification_requested.emit(TEXT_ANSWER, &"info")
	if state(uid) in LetterRules.OPEN:
		_records[uid]["opened"] = true
		_close(uid, l, STATE_ANSWERED, inv, ctx, "")
	else:
		_actions(l, LetterRules.CHOICE_ANSWER, ctx)
		EventBus.letter_changed.emit(uid, l.id, STATE_ANSWERED)
	EventBus.letter_changed.emit(reply, l.id, STATE_WRITTEN)
	return true


## L5: the choice of q_letters / l5 (Quests.choose; without the chain the step's actions directly).
func _decide_aschau(uid: String, choice: StringName, context: Dictionary) -> bool:
	if not choice in ASCHAU_CHOICES or state(uid) != STATE_RECEIVED:
		return false
	var inv := context.get("inventory") as Inventory
	if inv == null:
		inv = _player_inventory()
	var quests := _first(&"quests")
	var chosen := quests != null and quests.has_method(&"choose") and bool(quests.call(&"choose", QUEST_LETTERS, STEP_ASCHAU, choice))
	if not chosen:
		var q := quest_data if quest_data != null else Database.quest(QUEST_LETTERS) as QuestData
		var actions := PackedStringArray()
		if q != null:
			for s: QuestStepData in q.steps:
				if s.id == STEP_ASCHAU:
					for c: QuestChoiceData in s.choices:
						if c.id == choice:
							actions = c.actions
		LetterRules.apply_actions(actions, {"inventory": inv}, _tree(), REASON)
	var new_state: StringName = {&"open": STATE_READ, &"keep": &"kept", &"liesel": STATE_DELIVERED, &"burn": STATE_BURNED}[choice]
	if choice == &"open":
		_records[uid]["opened"] = true
		GameState.add_stat(STAT_READ, 1)
	elif choice != &"keep":
		_remove_item(uid, inv)
	_records[uid]["state"] = String(new_state)
	_records[uid]["choice"] = String(choice)
	EventBus.letter_changed.emit(uid, _id_of(uid), new_state)
	return true


func _receive_post(day: int, inv: Inventory) -> void:
	var used := used_ids()
	for l: LetterData in _post_pool():
		if used.has(l.id) or l.id == _cfg().aschau_letter:
			continue
		var record := _story_record(l.story_id)
		if record == null or record.location != CorpseRecord.LOCATION_BURIED or record.grave_id == "":
			continue
		var uid := _new_uid()
		_records[uid] = {"id": String(l.id), "corpse": record.id, "state": String(STATE_RECEIVED), "day": day,
				"kind": String(LetterData.KIND_POST)}
		GameState.add_stat(STAT_POST, 1)
		EventBus.notification_requested.emit(TEXT_POST % record.display_name, &"info")
		_hand_over(uid, inv, false)
		EventBus.letter_changed.emit(uid, l.id, STATE_RECEIVED)
		return


## L5: Hanne brings the letter to L. Aschau on her first day after the first answer was posted (a day before).
func _aschau(day: int, inv: Inventory) -> void:
	var id := _cfg().aschau_letter
	if id == &"" or _data(id) == null or used_ids().has(id):
		return
	var answered := false
	for uid: String in _records:
		if _kind(uid) == KIND_REPLY and state(uid) == STATE_POSTED and int(_records[uid].get("day", day)) < day:
			answered = true
	if not answered:
		return
	var wanderers := _first(&"wanderers")
	if wanderers == null or not wanderers.has_method(&"peddler_day") or not bool(wanderers.call(&"peddler_day", day)):
		return
	var uid := _new_uid()
	_records[uid] = {"id": String(id), "corpse": "", "state": String(STATE_RECEIVED), "day": day, "kind": String(LetterData.KIND_POST)}
	GameState.add_stat(STAT_POST, 1)
	EventBus.notification_requested.emit(TEXT_ASCHAU, &"info")
	_hand_over(uid, inv, false)
	EventBus.letter_changed.emit(uid, id, STATE_RECEIVED)


func _counter_letters(day: int, inv: Inventory) -> void:
	var keep: Array[Dictionary] = []
	for r: Dictionary in _replies:
		var due := int(r.get("due", 0))
		var ready := day >= due
		if ready and r.get("peddler", false) == true:
			var wanderers := _first(&"wanderers")
			ready = wanderers == null or not wanderers.has_method(&"peddler_day") or bool(wanderers.call(&"peddler_day", day))
		if not ready:
			keep.append(r)
			continue
		var uid := str(r.get("uid", ""))
		var l := letter(uid)
		var text := l.reply_text if l != null and l.reply_text != "" else TEXT_REPLY_DEFAULT
		EventBus.notification_requested.emit(text, &"info")
		var coins := int(r.get("coins", 0))
		if coins > 0 and inv != null:
			inv.add_item(COIN_ITEM, coins)
			EventBus.payment_received.emit(coins, REASON_ANSWER_COIN)
		GameState.add_stat(STAT_POST, 1)
		_records[uid]["reply_day"] = day
		EventBus.letter_changed.emit(uid, _id_of(uid), STATE_RECEIVED_REPLY)
	_replies = keep


func _hand_pending(inv: Inventory) -> void:
	if inv == null:
		return
	for uid: String in uids():
		if str(_records[uid].get("held", HELD_PLAYER)) != HELD_PLAYER:
			if inv.add_unique(ITEM_LETTER, uid):
				_records[uid].erase("held")


## Into the inventory (item letter with the uid); no room → held by the corpse / the carrier until the next morning.
func _hand_over(uid: String, inv: Inventory, show: bool = true) -> void:
	var l := letter(uid)
	if inv != null and inv.add_unique(ITEM_LETTER, uid):
		if show and l != null:
			EventBus.notification_requested.emit(TEXT_FOUND % l.outside, &"info")
		return
	_records[uid]["held"] = HELD_CORPSE
	if show:
		EventBus.notification_requested.emit(TEXT_FOUND_NO_ROOM, &"warning")


func _remove_item(uid: String, inv: Inventory) -> void:
	if inv != null and inv.has_uid(uid):
		inv.remove_uid(uid)
		return
	var player_inv := _player_inventory()
	if player_inv != null and player_inv.has_uid(uid):
		player_inv.remove_uid(uid)


func _seal_broken(uid: String) -> void:
	var o := _order(uid)
	if o == null or o.conditions.get("sealed", false) != true or _records[uid].get("seal_broken", false) == true:
		return
	_records[uid]["seal_broken"] = true
	EventBus.notification_requested.emit(TEXT_SEAL, &"warning")
	var raw: Variant = o.conditions.get("seal_broken_rel", {})
	var rel := _first(&"relationships")
	if raw is Dictionary and rel != null:
		for npc: Variant in raw:
			rel.call(&"add", StringName(str(npc)), int((raw as Dictionary)[npc]), TEXT_SEAL)


func _complete_order(uid: String) -> void:
	var orders := _first(&"orders")
	var id := StringName(str(_records[uid].get("order", "")))
	if orders == null or id == &"" or not orders.has_method(&"complete"):
		return
	if orders.has_method(&"state") and StringName(str(orders.call(&"state", id))) != &"accepted":
		return
	orders.call(&"complete", id)
	GameState.add_stat(&"errands_done", 1)


func _rep_once() -> void:
	var day := TimeManager.day
	if _rep_day > 0 and day - _rep_day < _cfg().rep_cap_day:
		return
	var rep := _first(&"reputation")
	if rep == null:
		return
	_rep_day = day
	rep.call(&"event", EVENT_DELIVERED, REASON)


func _piety(event: StringName) -> void:
	if event == &"":
		return
	var piety := _first(&"piety")
	if piety != null:
		piety.call(&"event", event, REASON)


func _goodwill(kin: StringName, n: int) -> void:
	var visitors := _first(&"visitors")
	if visitors != null and kin != &"":
		visitors.call(&"add_goodwill", kin, n)


func _actions(l: LetterData, choice: StringName, ctx: Dictionary) -> void:
	if l == null or choice == &"" or not l.choice_actions.has(choice):
		return
	LetterRules.apply_actions(l.choice_actions[choice], ctx, _tree(), REASON)


static func _reply_coins(l: LetterData) -> int:
	return LetterRules.reply_coins(l)


func _quest_note(key: StringName, arg: String) -> void:
	var quests := _first(&"quests")
	if quests != null and quests.has_method(&"note"):
		quests.call(&"note", key, arg)


func _is_aschau(uid: String) -> bool:
	return _id_of(uid) == _cfg().aschau_letter and _cfg().aschau_letter != &""


func _night() -> int:
	return TimeManager.day if TimeManager.minute_of_day >= MORNING_MINUTE else TimeManager.day - 1


func _count(states: Array[StringName]) -> int:
	var n := 0
	for uid: String in _records:
		if _kind(uid) in [LetterData.KIND_POCKET, LetterData.KIND_POST] and state(uid) in states:
			n += 1
	return n


func _kind(uid: String) -> StringName:
	var k := StringName(str(_records[uid].get("kind", ""))) if _records.has(uid) else &""
	if k != &"":
		return k
	var l := _data(_id_of(uid))
	return l.kind if l != null else LetterData.KIND_POCKET


func _id_of(uid: String) -> StringName:
	return StringName(str(_records[uid].get("id", ""))) if _records.has(uid) else &""


func _data(id: StringName) -> LetterData:
	if id == &"":
		return null
	if not letter_table.is_empty():
		return letter_table.get(id) as LetterData
	return Database.letter(id) as LetterData


func _all_letters() -> Array[LetterData]:
	var out: Array[LetterData] = []
	if not letter_table.is_empty():
		var ids := letter_table.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for id: StringName in ids:
			out.append(letter_table[id])
		return out
	for res: Resource in Database.letters():
		if res is LetterData:
			out.append(res as LetterData)
	return out


func _pocket_pool() -> Array[LetterData]:
	return _all_letters().filter(func(l: LetterData) -> bool: return l.kind == LetterData.KIND_POCKET)


func _post_pool() -> Array[LetterData]:
	var posts := _all_letters().filter(func(l: LetterData) -> bool: return l.kind == LetterData.KIND_POST)
	var out: Array[LetterData] = []
	for id: StringName in POST_ORDER:
		for l: LetterData in posts:
			if l.id == id:
				out.append(l)
	for l: LetterData in posts:
		if not out.has(l):
			out.append(l)
	return out


## The errand's order (Orders in the tree, else Database).
func _order(uid: String) -> OrderData:
	if not _records.has(uid) or _kind(uid) != KIND_ERRAND:
		return null
	var id := StringName(str(_records[uid].get("order", "")))
	var orders := _first(&"orders")
	if orders != null and orders.has_method(&"order_data"):
		var o := orders.call(&"order_data", id) as OrderData
		if o != null:
			return o
	return Database.order_data(id) as OrderData


func _corpse(corpse_id: String) -> CorpseRecord:
	if corpse_id == "":
		return null
	var manager := _first(&"corpse_manager")
	if manager != null and manager.has_method(&"get_record"):
		return manager.call(&"get_record", corpse_id) as CorpseRecord
	return null


func _story_record(story_id: StringName) -> CorpseRecord:
	if story_id == &"":
		return null
	var manager := _first(&"corpse_manager")
	if manager == null or not manager.has_method(&"records"):
		return null
	for r: CorpseRecord in manager.call(&"records"):
		if r.story_id == story_id:
			return r
	return null


## The kin of the dead's household (CorpseRecord.kin_house → KinData without a villager).
func _kin_of(record: CorpseRecord) -> StringName:
	if record == null:
		return &""
	if record.kin_house != &"":
		for res: Resource in Database.kin_list():
			var kin := res as KinData
			if kin != null and kin.villager_id == &"" and kin.house == record.kin_house:
				return kin.kin_id
	if record.grave_id != "":
		var visitors := _first(&"visitors")
		if visitors != null and visitors.has_method(&"kin_for_grave"):
			return StringName(str(visitors.call(&"kin_for_grave", record.grave_id)))
	return &""


func _has_household(record: CorpseRecord) -> bool:
	if record == null or record.kin_house == &"":
		return false
	for res: Resource in Database.kin_list():
		var kin := res as KinData
		if kin != null and kin.villager_id == &"" and kin.house == record.kin_house:
			return true
	return false


func _grave_label(grave_id: String) -> String:
	var section := ""
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"section_of"):
		var id := StringName(str(graveyard.call(&"section_of", grave_id)))
		var data := Database.section(id) as SectionData if id != &"" else null
		section = data.display_name if data != null and data.display_name != "" else String(id)
	return grave_id if section == "" else "%s, %s" % [section, grave_id]


## The letter of an errand (no data file: the order carries it) – E1 Gesa's letter, E2 Fenner's sealed notice.
func _errand_data(uid: String) -> LetterData:
	var o := _order(uid)
	if o == null:
		return null
	var l := LetterData.new()
	l.id = o.id
	l.kind = KIND_ERRAND
	l.sealed = o.conditions.get("sealed", false) == true
	l.recipient = o.recipient if o.recipient != &"" else &"town"
	l.sender = Phase8Texts.person_name(o.giver)
	l.outside = ERRAND_OUTSIDE.get(o.id, o.title) as String
	l.text = ERRAND_TEXT.get(o.id, o.request_text) as String
	if o.id == &"oq_fenner_seal" and GameState.flag_on(&"q_end_public"):
		l.text = TEXT_NOTICE_PUBLIC
	return l


func _new_uid() -> String:
	var uid := UID_FORMAT % _next_uid
	while _records.has(uid):
		_next_uid += 1
		uid = UID_FORMAT % _next_uid
	_next_uid += 1
	return uid


func _player_inventory() -> Inventory:
	var player := _first(&"player")
	return player.get(&"inventory") as Inventory if player != null else null


func get_config() -> LettersConfig:
	return _cfg()


func _cfg() -> LettersConfig:
	if config == null:
		config = Database.config(&"letters_config") as LettersConfig
		if config == null:
			config = LettersConfig.new()
	return config


func _tree() -> SceneTree:
	return get_tree() if is_inside_tree() else null


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
