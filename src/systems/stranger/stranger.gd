class_name Stranger
extends Node
## Systems/Stranger (docs/PHASE9_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1; P5), groups &"stranger", &"saveable",
## save_id stranger / 84: Cornelius Brenneisen, the gentleman with the case. Benutzerentscheidung §14.4: a buyer with
## moral offers – questions, grave soil, the register extract, specimens, a bribe, Lorenz' ledger for 40 coins; **never
## a corpse**; three endings Fenner / Handel / Ilse.
##
## - **Visits (§2.5.1):** first p9_open_day + arrive_offset, then every return_every days for stay_days days
##   (StrangerRules.visit_days, at most StrangerRules.MAX_VISITS), until his chain ends. Over the Holderbrücke on foot,
##   the Holderkrug, 14:10–15:30 outside the cemetery gate (one short ring of the gate bell: stranger_event arrived
##   "gate" + the HUD line) – he never enters the cemetery (present(&"graveyard") = his spot outside the gate).
## - **K1 questions:** question() – a new one each visit; answer(kind) once per visit: frank +question_coin, refuse
##   piety stranger_refused (once), evade nothing. Quests.note(stranger_answered).
## - **K2 offers:** offers(inv) {id, label, item, price, note, reason} while he is here (Quests.note
##   stranger_offers_seen); sell(offer, inv): soil (taken at a fresh grave with take_soil), the register extract (the
##   talk reaches Lenz and Fenner rumor_delay_days later), a specimen (Quast's price × specimen_factor – the Phase-7
##   consequences through Specimens.sell), the ledger (after the main chain). The offer's actions are its consequences.
## - **K3:** bribe(accept, inv) – 15 coins for the silence (piety case_bribe) or refused.
## - **K4 case:** on the second day of the second visit he forgets it at the Holderkrug (case_holder inn); take_case
##   (Rosine) → player · open_case (clue c_q_case_list, he will know) · give_case(&"stranger" | &"fenner").
## - **K5 resolve(choice):** fenner (he is taken over the bridge, never comes again) · deal (the card when the ledger was
##   not sold) · ilse (he goes to the west wall at night, gone in the morning). Through Quests.choose(q_case, k5, …);
##   without the chain the step's choice actions are run directly. gone() = his chain has ended (or he left after his
##   last visit).
## - Effects are direct calls (Piety, Reputation, Relationships, NpcLife, JournalManager, Orders, Specimens, Quests).

const GROUP := &"stranger"
const ANSWERS: Array[StringName] = [&"frank", &"evade", &"refuse"]
const ENDINGS: Array[StringName] = [&"fenner", &"deal", &"ilse"]
const CASE_HOLDERS: Array[StringName] = [&"inn", &"player", &"fenner", &"stranger"]
const ANSWER_FRANK := &"frank"
const ANSWER_REFUSE := &"refuse"
const CASE_INN := &"inn"
const CASE_PLAYER := &"player"
const CASE_FENNER := &"fenner"
const CASE_STRANGER := &"stranger"
const BRIBE_ACCEPTED := &"accepted"
const BRIBE_REFUSED := &"refused"
const COIN_ITEM := &"coin"
const CASE_ITEM := &"stranger_case"
const CARD_ITEM := &"case_card"
const SOIL_ITEM := &"soil_pouch"
const SOIL_OFFER := &"so_soil"
const SPECIMEN_OFFER := &"so_specimen"
const MORNING_MINUTE := 360
const QUEST_CASE := &"q_case"
const STEP_END := &"k5"
const MAIN_QUEST := &"q_who_knows"
const ORDER_CASE := &"oq_case_return"
const CLUE_LORENZ := &"c_q_case_lorenz"
const CLUE_LIST := &"c_q_case_list"
const CLUE_ROBBER := &"c_n_robber"
const FLAG_CONFIDE_QUAST := &"q_confide_surgeon"
const FLAG_VEIT_TOLD := &"stranger_veit_told"
const FLAG_OPENED := &"case_opened"
const FLAG_BRIBE := &"case_bribe"
const FLAG_KLADDE := &"kladde_sold"
const FLAG_TRADER := &"trader_known"
const NOTE_ANSWERED := &"stranger_answered"
const NOTE_OFFERS := &"stranger_offers_seen"
const PIETY_REFUSED := &"stranger_refused"
const PIETY_BRIBE := &"case_bribe"
## The case is forgotten on this day of the second visit (0 = first day).
const CASE_VISIT := 2
const CASE_DAY_OF_VISIT := 1
## The rumours of delayed actions (`rumor:<event>`): what reaches the village rumor_delay_days later.
const RUMORS: Dictionary[StringName, PackedStringArray] = {
	&"register_sold": ["rel_gain:priest:register_sold_lenz", "rel_gain:mayor:register_sold_fenner", "rep_event:register_sold_rumor",
			"note_event:register_sold"],
}
const STAT_TALKS := &"stranger_talks"
const STAT_COINS := &"stranger_coins"
const REASON := "Der Herr mit dem Koffer"
const REASON_SALE := "Verkauf an den Herrn mit dem Koffer"
const REASON_ANSWER := "Auskunft für den Herrn mit dem Koffer"
const REASON_TIP := "Botenlohn"
const TEXT_GATE := "Ein Herr in einem Stadtrock wartet am Tor."
const TEXT_CASE_INN := "Im Holderkrug steht ein Koffer, den keiner anfassen will."
const TEXT_CASE_OPEN := "Instrumente in Samt, Gläser, ein Brief von Quast: „Die beiden letzten, wie besprochen.“ Und ein Blatt: „Hollerbrück – Gezeichnete. Herzen still. Zahle das Doppelte.“"
const TEXT_CASE_BACK := "Er nimmt den Koffer, ohne hineinzusehen. „Sehr freundlich. Für den Weg.“"
const TEXT_CASE_BACK_OPEN := "Er nimmt den Koffer und sieht auf das Schloss. „Sie haben hineingesehen. Das ist Ihr gutes Recht. Es kostet nur etwas mehr.“"
const TEXT_CASE_FENNER := "Fenner nimmt den Koffer. „Das ist ein Beweis. Den behalte ich.“"
const TEXT_SOIL := "Eine Handvoll Erde, in ein Tuch geknotet. Sie ist noch kalt."
const TEXT_LEFT := "Der Herr mit dem Koffer ist abgereist."
const TEXT_FENNER := "Fenner und der Nachtwächter bringen den Herrn über die Brücke. „Ich gehe. Aber die Stadt bleibt, Herr Totengräber. Die Stadt bleibt immer.“"
const TEXT_DEAL_CARD := "Er lässt eine Karte da. „Falls Sie es sich überlegen.“"
const TEXT_DEAL := "Er tippt an den Hut. „Es war mir ein Vergnügen. Ein genaues.“"
const TEXT_ILSE := "„An der Westmauer? Nachts? Wie romantisch.“ Er notiert es."
const TEXT_SOIL_FRESH := "Hier liegt keiner, der noch keine Woche liegt."
const TEXT_SOIL_TAKEN := "Von diesem Grab hast du schon genommen."
const TEXT_SOIL_FULL := "Kein Platz im Beutel."
const TEXT_RESOLVE_ILSE := "Von einer Frau an der Westmauer weißt du nichts."
const TEXT_RESOLVE_GONE := "Er ist nicht mehr da."
const TEXT_RESOLVE_NOT_YET := "Noch nicht. Er ist noch nicht fertig mit seinen Fragen."

@export var save_id: String = "stranger"
@export var save_order: int = 84

## Rules; null = data/config/stranger_config.tres (resolved lazily).
var config: StrangerConfig
## Offers by id; empty = Database.stranger_offers() (tests inject fixtures).
var offer_table: Dictionary[StringName, StrangerOfferData] = {}
## q_case for the K5 fallback (null = Database.quest).
var quest_data: QuestData

## First days of the visits that began.
var _visits: Array[int] = []
## The answer kind per answered visit (§5.1 answers) and the visit numbers answered.
var _answers: Array[StringName] = []
var _asked: Array[int] = []
var _refused_once: bool = false
## offer key (id without „so_") → times sold.
var _sold: Dictionary[String, int] = {}
var _bribe: StringName = &""
var _case: StringName = &""
var _case_opened: bool = false
var _ending: StringName = &""
var _ending_day: int = -1
var _left: bool = false
## [{event, day}] – delayed talk (register sold).
var _rumors: Array[Dictionary] = []
var _offers_seen: bool = false
var _soil_graves: PackedStringArray = []
var _gate_day: int = -1
var _morning_day: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- presence ---------------------------------------------------------------------------------------

## Is he in `region` now (&"graveyard" = outside the gate, &"village", &"inn")?
func present(region: StringName) -> bool:
	return StrangerRules.present(TimeManager.day, TimeManager.minute_of_day, region, rule_state(), _cfg())


## Anywhere in Hollerbrück now (gate, village, inn).
func here() -> bool:
	return present(StrangerRules.REGION_GRAVEYARD) or present(StrangerRules.REGION_VILLAGE) or present(StrangerRules.REGION_INN)


## His chain has ended (K5) or he left after his last visit – he never comes again.
func gone() -> bool:
	return _ending != &"" or _left


func ending() -> StringName:
	return _ending


## {open_day, ending, ending_day, left} for StrangerRules.present.
func rule_state() -> Dictionary:
	return {"open_day": _open_day(), "ending": String(_ending), "ending_day": _ending_day, "left": _left}


## The days of this game (StrangerRules.visit_days of p9_open_day).
func visit_days() -> PackedInt32Array:
	return StrangerRules.visit_days(_open_day(), _cfg())


## The number of the current visit (0 = he is not in Hollerbrück today).
func visit_now() -> int:
	if gone() and TimeManager.day > _ending_day:
		return 0
	return StrangerRules.visit_of(TimeManager.day, _open_day(), _cfg())


# --- K1 ------------------------------------------------------------------------------------------

## Today's question ("" = none open: not here, or this visit's question was answered).
func question() -> String:
	var v := visit_now()
	if v == 0 or _asked.has(v) or gone():
		return ""
	return StrangerRules.question(v, _cfg())


## &"frank" | &"evade" | &"refuse" – once per visit.
func answer(kind: StringName) -> void:
	var v := visit_now()
	if not kind in ANSWERS or v == 0 or _asked.has(v) or gone():
		return
	_asked.append(v)
	_answers.append(kind)
	GameState.add_stat(STAT_TALKS, 1)
	if kind == ANSWER_FRANK:
		_pay(_cfg().question_coin, REASON_ANSWER, _player_inventory())
	elif kind == ANSWER_REFUSE and not _refused_once:
		_refused_once = true
		_piety(PIETY_REFUSED)
	_quest_note(NOTE_ANSWERED, String(kind))
	EventBus.stranger_event.emit(&"asked", String(kind))


func answers() -> Array[StringName]:
	return _answers.duplicate()


# --- K2 ------------------------------------------------------------------------------------------

## {id, label, item, price, note, reason} of what he wants to buy now (only while he is here; hidden: the offers whose
## flag / quest conditions do not hold). Opening them counts as K2 seen.
func offers(inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if gone() or not here():
		return out
	var ctx := _offer_context(inv)
	for o: StrangerOfferData in _all_offers():
		if not StrangerRules.offer_visible(o, ctx):
			continue
		out.append({"id": o.id, "label": o.label, "item": o.item, "price": _price(o, ctx), "note": o.note,
				"reason": StrangerRules.offer_block_reason(o, inv, ctx)})
	if not _offers_seen:
		_offers_seen = true
		_quest_note(NOTE_OFFERS, "")
	return out


func offers_seen() -> bool:
	return _offers_seen


func sell(offer_id: StringName, inv: Inventory) -> bool:
	var o := _offer(offer_id)
	if o == null or inv == null or gone() or not here():
		return false
	var ctx := _offer_context(inv)
	if not StrangerRules.offer_visible(o, ctx) or StrangerRules.offer_block_reason(o, inv, ctx) != "":
		return false
	var price := _price(o, ctx)
	if o.item == &"":
		var uid := str(ctx.get("specimen_uid", ""))
		var specimens := _first(&"specimens")
		if specimens == null or uid == "":
			return false
		var quast := int(specimens.call(&"sell", uid, inv))
		if quast <= 0:
			return false
		var extra := maxi(price - quast, 0)
		if extra > 0:
			inv.add_item(COIN_ITEM, extra)
		price = quast + extra
		EventBus.payment_received.emit(extra, REASON_SALE)
	else:
		var item := StrangerRules.SOIL_ITEM if _has_cond(o, StrangerRules.COND_FRESH) else o.item
		if not inv.remove_item(item, 1):
			return false
		inv.add_item(COIN_ITEM, price)
		EventBus.payment_received.emit(price, REASON_SALE)
	GameState.add_stat(STAT_COINS, price)
	var key := _key(o.id)
	_sold[key] = int(_sold.get(key, 0)) + 1
	for a: String in o.actions:
		if a.begins_with("rumor:"):
			_rumors.append({"event": a.get_slice(":", 1), "day": TimeManager.day})
	LetterRules.apply_actions(o.actions, {"inventory": inv}, _tree(), REASON_SALE)
	EventBus.stranger_event.emit(&"sold", String(o.id))
	return true


func sold(offer_id: StringName) -> int:
	return int(_sold.get(_key(offer_id), 0))


## Show „[E] Eine Handvoll Erde nehmen" at `grave_id`? (he has asked for soil – K2 seen, he still comes – and the dead
## there is fresh enough).
func soil_offered(grave_id: String) -> bool:
	if gone() or not _offers_seen or _offer(SOIL_OFFER) == null:
		return false
	return _fresh(grave_id)


## "" = a handful can be taken now.
func soil_block_reason(grave_id: String, inv: Inventory) -> String:
	if not _fresh(grave_id):
		return TEXT_SOIL_FRESH
	if _soil_graves.has(grave_id):
		return TEXT_SOIL_TAKEN
	if inv == null or not inv.can_add(SOIL_ITEM, 1):
		return TEXT_SOIL_FULL
	return ""


## K2: a handful of soil from a fresh grave (≤ fresh_grave_days) into a cloth – once per grave (the offer is open).
func take_soil(grave_id: String, inv: Inventory) -> bool:
	if not soil_offered(grave_id) or soil_block_reason(grave_id, inv) != "":
		return false
	if inv.add_item(SOIL_ITEM, 1) > 0:
		return false
	_soil_graves.append(grave_id)
	EventBus.notification_requested.emit(TEXT_SOIL, &"info")
	return true


# --- K3 ------------------------------------------------------------------------------------------

## The gravekeeper knows who he is (§2.5.2 K3): with c_n_robber (Phase 8, Lambert's „Wer zahlt dich?"), with Quast as
## the one he confided in (H5), or after Veit told him (flag stranger_veit_told – the dialogue sets it).
func recognized() -> bool:
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"has_clue") and bool(journal.call(&"has_clue", CLUE_ROBBER)):
		return true
	return GameState.flag_on(StringName("clue_" + String(CLUE_ROBBER))) or GameState.flag_on(FLAG_CONFIDE_QUAST) \
			or GameState.flag_on(FLAG_VEIT_TOLD)


## How Lambert's fate colours K3 (§2.5.2 Verbindungen): &"let_go" (Lambert greets through Veit: „der war's") ·
## &"reported" (Fenner knows the name from the record) · &"" (neither).
func k3_variant() -> StringName:
	var robber := _first(&"night_robber")
	var fate := StringName(str(robber.call(&"fate"))) if robber != null and robber.has_method(&"fate") else &""
	return fate if fate in [&"let_go", &"reported"] else &""


## The bribe for his silence: accept → bribe_coins, piety case_bribe, flag case_bribe; refuse → nothing. Once.
func bribe(accept: bool, inv: Inventory) -> void:
	if _bribe != &"" or gone():
		return
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"has_clue") and not bool(journal.call(&"has_clue", CLUE_LORENZ)):
		journal.call(&"add_clue", CLUE_LORENZ, "", false)
	if accept:
		_bribe = BRIBE_ACCEPTED
		_pay(_cfg().bribe_coins, REASON, inv if inv != null else _player_inventory())
		_piety(PIETY_BRIBE)
		GameState.set_flag(FLAG_BRIBE, true)
	else:
		_bribe = BRIBE_REFUSED
	EventBus.stranger_event.emit(&"bribed", "yes" if accept else "no")


func bribe_state() -> StringName:
	return _bribe


# --- K4 ------------------------------------------------------------------------------------------

## &"inn" | &"player" | &"fenner" | &"stranger" (&"" = no case yet).
func case_holder() -> StringName:
	return _case


func case_opened() -> bool:
	return _case_opened


## Rosine hands the forgotten case over (inn → player).
func take_case(inv: Inventory) -> bool:
	if _case != CASE_INN or inv == null or gone():
		return false
	if inv.add_item(CASE_ITEM, 1) > 0:
		return false
	_case = CASE_PLAYER
	EventBus.stranger_event.emit(&"case", String(_case))
	return true


## „[E] Hineinsehen": the clue c_q_case_list; he will see the lock was opened.
func open_case(inv: Inventory) -> bool:
	if _case != CASE_PLAYER or _case_opened or inv == null or not inv.has(CASE_ITEM):
		return false
	_case_opened = true
	GameState.set_flag(FLAG_OPENED, true)
	EventBus.notification_requested.emit(TEXT_CASE_OPEN, &"info")
	var journal := _first(&"journal")
	if journal != null:
		journal.call(&"add_clue", CLUE_LIST, "", false)
	EventBus.stranger_event.emit(&"case", "opened")
	return true


## Back to him (&"stranger": he is here; unopened → case_tip coins; the errand oq_case_return is done) or to Fenner
## (&"fenner": the proof – resolve(&"fenner") is open at once).
func give_case(to: StringName, inv: Inventory) -> bool:
	if _case != CASE_PLAYER or inv == null or not inv.has(CASE_ITEM) or not to in [CASE_STRANGER, CASE_FENNER]:
		return false
	if to == CASE_STRANGER and not here():
		return false
	inv.remove_item(CASE_ITEM, 1)
	_case = to
	if to == CASE_STRANGER:
		if _case_opened:
			EventBus.notification_requested.emit(TEXT_CASE_BACK_OPEN, &"info")
		else:
			EventBus.notification_requested.emit(TEXT_CASE_BACK, &"info")
			_pay(_cfg().case_tip, REASON_TIP, inv)
	else:
		EventBus.notification_requested.emit(TEXT_CASE_FENNER, &"info")
	_complete_order(ORDER_CASE)
	EventBus.stranger_event.emit(&"case", String(to))
	return true


# --- K5 ------------------------------------------------------------------------------------------

## "" = the ending can be chosen now: on the last day of his second visit, earlier once the case is out of the inn
## (K4), always with the case at Fenner's; Ilse only when the gravekeeper knows her.
func resolve_block_reason(choice: StringName) -> String:
	if not choice in ENDINGS:
		return TEXT_RESOLVE_GONE
	if gone():
		return TEXT_RESOLVE_GONE
	if choice == &"ilse" and not GameState.flag_on(FLAG_TRADER):
		return TEXT_RESOLVE_ILSE
	if _case == CASE_FENNER:
		return ""
	if _case in [CASE_PLAYER, CASE_STRANGER]:
		return ""
	var v := visit_now()
	var open_day := _open_day()
	if open_day < 0:
		return TEXT_RESOLVE_NOT_YET
	var second_last := StrangerRules.visit_start(open_day, 2, _cfg()) + maxi(_cfg().stay_days, 1) - 1
	if v >= 2 and TimeManager.day >= second_last:
		return ""
	return TEXT_RESOLVE_NOT_YET


## &"fenner" | &"deal" | &"ilse"
func resolve(choice: StringName) -> void:
	if resolve_block_reason(choice) != "":
		return
	_ending = choice
	_ending_day = TimeManager.day
	var quests := _first(&"quests")
	var chosen := quests != null and quests.has_method(&"choose") and bool(quests.call(&"choose", QUEST_CASE, STEP_END, choice))
	if not chosen:
		LetterRules.apply_actions(_choice_actions(choice), {"inventory": _player_inventory()}, _tree(), REASON)
	GameState.set_flag(StringName("case_end_" + String(choice)), true)
	match choice:
		&"fenner":
			EventBus.notification_requested.emit(TEXT_FENNER, &"info")
			EventBus.stranger_event.emit(&"expelled", "fenner")
		&"deal":
			if not GameState.flag_on(FLAG_KLADDE):
				var inv := _player_inventory()
				if inv != null:
					inv.add_item(CARD_ITEM, 1)
				EventBus.notification_requested.emit(TEXT_DEAL_CARD, &"info")
			else:
				EventBus.notification_requested.emit(TEXT_DEAL, &"info")
			EventBus.stranger_event.emit(&"left", "deal")
		&"ilse":
			EventBus.notification_requested.emit(TEXT_ILSE, &"info")
			EventBus.stranger_event.emit(&"left", "ilse")


# --- time --------------------------------------------------------------------------------------------

## Idempotent per day: the visit begins, the case stays at the inn, the delayed talk, he leaves after his last visit.
func apply_morning(day: int) -> void:
	if day <= _morning_day:
		return
	_morning_day = day
	var open_day := _open_day()
	if open_day < 0:
		return
	_apply_rumors(day)
	if gone():
		return
	var cfg := _cfg()
	if day > StrangerRules.last_day(open_day, cfg):
		_left = true
		EventBus.notification_requested.emit(TEXT_LEFT, &"info")
		EventBus.stranger_event.emit(&"left", "")
		return
	var v := StrangerRules.visit_of(day, open_day, cfg)
	if v == 0:
		return
	var start := StrangerRules.visit_start(open_day, v, cfg)
	if day == start and not _visits.has(start):
		_visits.append(start)
		EventBus.stranger_event.emit(&"arrived", "village")
	if v == CASE_VISIT and day == start + CASE_DAY_OF_VISIT and _case == &"":
		_case = CASE_INN
		EventBus.notification_requested.emit(TEXT_CASE_INN, &"info")
		EventBus.stranger_event.emit(&"case", String(CASE_INN))


## 14:10: he rings the gate bell once (HUD line) – once per day.
func apply_minute(day: int, minute: int) -> void:
	if _gate_day == day or gone():
		return
	if StrangerRules.present(day, minute, StrangerRules.REGION_GRAVEYARD, rule_state(), _cfg()):
		_gate_day = day
		EventBus.notification_requested.emit(TEXT_GATE, &"info")
		EventBus.stranger_event.emit(&"arrived", "gate")


# --- save --------------------------------------------------------------------------------------------

## §5.1 {visits, answers, sold, bribe, case, ending, rumors} + asked, refused_once, case_opened, ending_day, left,
## offers_seen, soil_graves, gate_day, morning_day.
func save_state() -> Dictionary:
	var sold_out := {}
	for k: String in _sold:
		sold_out[k] = _sold[k]
	var rumors: Array = []
	for r: Dictionary in _rumors:
		rumors.append(r.duplicate())
	return {"visits": Array(_visits), "answers": _answers.map(func(a: StringName) -> String: return String(a)), "sold": sold_out,
			"bribe": String(_bribe), "case": String(_case), "ending": String(_ending), "rumors": rumors, "asked": Array(_asked),
			"refused_once": _refused_once, "case_opened": _case_opened, "ending_day": _ending_day, "left": _left,
			"offers_seen": _offers_seen, "soil_graves": Array(_soil_graves), "gate_day": _gate_day, "morning_day": _morning_day}


func load_state(data: Dictionary) -> void:
	_visits = _ints(data.get("visits", []))
	_asked = _ints(data.get("asked", []))
	_answers.clear()
	var raw_answers: Variant = data.get("answers", [])
	if raw_answers is Array:
		for a: Variant in raw_answers:
			if StringName(str(a)) in ANSWERS:
				_answers.append(StringName(str(a)))
	_sold.clear()
	var raw_sold: Variant = data.get("sold", {})
	if raw_sold is Dictionary:
		for k: Variant in raw_sold:
			var n: Variant = (raw_sold as Dictionary)[k]
			if (n is int or n is float) and int(n) > 0:
				_sold[str(k)] = int(n)
	var b := StringName(str(data.get("bribe", "")))
	_bribe = b if b in [BRIBE_ACCEPTED, BRIBE_REFUSED] else &""
	var e := StringName(str(data.get("ending", "")))
	_ending = e if e in ENDINGS else &""
	var c := StringName(str(data.get("case", "")))
	_case = c if c in CASE_HOLDERS else &""
	_rumors.clear()
	var raw_rumors: Variant = data.get("rumors", [])
	if raw_rumors is Array:
		for r: Variant in raw_rumors:
			if r is Dictionary and RUMORS.has(StringName(str((r as Dictionary).get("event", "")))):
				_rumors.append({"event": str((r as Dictionary).get("event", "")), "day": _int((r as Dictionary).get("day"), 0)})
	_refused_once = data.get("refused_once", false) == true
	_case_opened = data.get("case_opened", false) == true
	_ending_day = _int(data.get("ending_day"), -1)
	if _ending != &"" and _ending_day < 0:
		_ending_day = TimeManager.day
	_left = data.get("left", false) == true
	_offers_seen = data.get("offers_seen", false) == true
	_soil_graves = PackedStringArray()
	var raw_soil: Variant = data.get("soil_graves", [])
	if raw_soil is Array:
		for g: Variant in raw_soil:
			if g is String:
				_soil_graves.append(g)
	_gate_day = _int(data.get("gate_day"), -1)
	_morning_day = _int(data.get("morning_day"), 0)


# --- internals ----------------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= MORNING_MINUTE and day > _morning_day:
		apply_morning(day)
	apply_minute(day, minute)


func _apply_rumors(day: int) -> void:
	var keep: Array[Dictionary] = []
	for r: Dictionary in _rumors:
		if day < int(r.get("day", 0)) + _cfg().rumor_delay_days:
			keep.append(r)
			continue
		var actions: PackedStringArray = RUMORS.get(StringName(str(r.get("event", ""))), PackedStringArray())
		LetterRules.apply_actions(actions, {}, _tree(), "Im Dorf redet man.")
	_rumors = keep


func _offer_context(inv: Inventory) -> Dictionary:
	var ended: Array[StringName] = []
	var quests := _first(&"quests")
	if quests != null and quests.has_method(&"ending"):
		for q: StringName in [MAIN_QUEST]:
			if StringName(str(quests.call(&"ending", q))) != &"":
				ended.append(q)
	return {"quest_ended": ended, "specimen_uid": _specimen_uid(inv), "soil_ready": _any_fresh(), "sold": _sold.duplicate()}


func _price(o: StrangerOfferData, ctx: Dictionary) -> int:
	if o.item == &"":
		var uid := str(ctx.get("specimen_uid", ""))
		var specimens := _first(&"specimens")
		if uid == "" or specimens == null:
			return 0
		return StrangerRules.specimen_price(int(specimens.call(&"sale_price", uid)), _cfg())
	if o.item == StrangerRules.LEDGER_ITEM:
		return _cfg().kladde_price
	return o.price


## The first specimen in `inv` Quast would take (held, not spoiled), "" = none.
func _specimen_uid(inv: Inventory) -> String:
	var specimens := _first(&"specimens")
	if inv == null or specimens == null or not specimens.has_method(&"held"):
		return ""
	for uid: String in specimens.call(&"held"):
		if inv.has_uid(uid) and str(specimens.call(&"sell_block_reason", uid, inv)) == "":
			return uid
	return ""


func _fresh(grave_id: String) -> bool:
	var record := _record_in(grave_id)
	if record == null or record.buried_day <= 0:
		return false
	return TimeManager.day - record.buried_day <= StrangerRules.fresh_days(_offer(SOIL_OFFER))


func _any_fresh() -> bool:
	var graveyard := _first(&"graveyard")
	if graveyard == null or not graveyard.has_method(&"graves"):
		return false
	for g: GraveRecord in graveyard.call(&"graves"):
		if g.corpse_id != "" and _fresh(g.id) and not _soil_graves.has(g.id):
			return true
	return false


func _record_in(grave_id: String) -> CorpseRecord:
	var graveyard := _first(&"graveyard")
	var manager := _first(&"corpse_manager")
	if graveyard == null or manager == null:
		return null
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord
	if grave == null or grave.corpse_id == "" or not grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
		return null
	return manager.call(&"get_record", grave.corpse_id) as CorpseRecord


func _choice_actions(choice: StringName) -> PackedStringArray:
	var q := quest_data if quest_data != null else Database.quest(QUEST_CASE) as QuestData
	if q == null:
		return PackedStringArray()
	for s: QuestStepData in q.steps:
		if s.id == STEP_END:
			for c: QuestChoiceData in s.choices:
				if c.id == choice:
					return c.actions
	return PackedStringArray()


func _pay(coins: int, reason: String, inv: Inventory) -> void:
	if coins <= 0 or inv == null:
		return
	inv.add_item(COIN_ITEM, coins)
	GameState.add_stat(STAT_COINS, coins)
	EventBus.payment_received.emit(coins, reason)


func _piety(event: StringName) -> void:
	var piety := _first(&"piety")
	if piety != null:
		piety.call(&"event", event, REASON)


func _quest_note(key: StringName, arg: String) -> void:
	var quests := _first(&"quests")
	if quests != null and quests.has_method(&"note"):
		quests.call(&"note", key, arg)


func _complete_order(id: StringName) -> void:
	var orders := _first(&"orders")
	if orders == null or not orders.has_method(&"complete"):
		return
	if orders.has_method(&"state") and StringName(str(orders.call(&"state", id))) != &"accepted":
		return
	orders.call(&"complete", id)
	GameState.add_stat(&"errands_done", 1)


func _offer(id: StringName) -> StrangerOfferData:
	if not offer_table.is_empty():
		return offer_table.get(id) as StrangerOfferData
	return Database.stranger_offer(id) as StrangerOfferData


func _all_offers() -> Array[StrangerOfferData]:
	var out: Array[StrangerOfferData] = []
	if not offer_table.is_empty():
		var ids := offer_table.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for id: StringName in ids:
			out.append(offer_table[id])
		return out
	for res: Resource in Database.stranger_offers():
		if res is StrangerOfferData:
			out.append(res as StrangerOfferData)
	return out


static func _has_cond(o: StrangerOfferData, key: String) -> bool:
	for c: String in o.conditions:
		if c.get_slice(":", 0) == key:
			return true
	return false


static func _key(offer_id: StringName) -> String:
	var s := String(offer_id)
	return s.substr(3) if s.begins_with("so_") else s


func _open_day() -> int:
	if not GameState.flag_on(&"p9_open"):
		return -1
	return int(GameState.get_flag(&"p9_open_day", -1))


func _player_inventory() -> Inventory:
	var player := _first(&"player")
	return player.get(&"inventory") as Inventory if player != null else null


func _cfg() -> StrangerConfig:
	if config == null:
		config = Database.config(&"stranger_config") as StrangerConfig
		if config == null:
			config = StrangerConfig.new()
	return config


func get_config() -> StrangerConfig:
	return _cfg()


func _tree() -> SceneTree:
	return get_tree() if is_inside_tree() else null


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _ints(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for v: Variant in raw:
			if (v is int or v is float) and not out.has(int(v)):
				out.append(int(v))
	return out


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
