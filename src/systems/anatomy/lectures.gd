class_name Lectures
extends Node
## Systems/Lectures (docs/PHASE7_DESIGN.md §2.6.4, §2.6.5, §3.1, §3.4, §5.1), groups &"lectures",
## &"saveable": the invitation, tonight's lecture (HouseDoor asks door_open), hold after the TimedAction
## (Specimens.consume(lectured), the fee, the organ's teaching, piety −3, Quast +3, lecture_held), the
## known teachings (Lehrsätze), the rumour of the night on the next morning (once, from 06:00).
## The examination table stays empty under its cloth; only the sealed jar stands on the lectern.

const GROUP := &"lectures"
const SURGERY_DOOR := &"door_surgery"
const SURGEON := &"surgeon"
const PRIEST := &"priest"
const WASHER := &"washer"
const COIN_ITEM := &"coin"
const STAT_ATTENDED := &"lectures_attended"
const FLAG_PIETY_USED_DAY := &"piety_used_day"
const LECTURE_REL := 3
const MORNING_HOUR := 6
const REASON_FEE := "Honorar der Vorlesung"
const REASON_LECTURE := "Anatomie-Vorlesung"
const REASON_RUMOR := "Gerede: Licht bei Quast"
const TEXT_RUMOR := "Bei Quast brannte wieder Licht bis nach Mitternacht."
## Quast's line about the night (the chances are never shown, only the mood).
const TEXT_QUIET := "Der Nachtwächter ist heute bei seiner Schwester."
const TEXT_RISKY := "Der Nachtwächter macht heute seine Runde. Wir sprechen leise."
const TEXT_KNOWN := "Die Mitschrift kennst du schon. Du hörst trotzdem zu."

@export var save_id: String = "lectures"
@export var save_order: int = 55
## Seed of the rumour roll (deterministic from day and this seed).
@export var seed: int = 0

## Rules; null = data/config/anatomy_config.tres (resolved lazily).
var config: AnatomyConfig

var _invited: bool = false
var _teachings: PackedStringArray = []
## The lecture night (day) of the last lecture held (0 = never).
var _last_day: int = 0
var _attended: int = 0
## The morning (day) the rumour of a discovered night lands on (0 = none pending).
var _rumor_day: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)


func invited() -> bool:
	return _invited


## Quast's invitation (dialogue action lecture_invite, P6): from then on the surgery door opens on
## lecture nights. false = already invited.
func invite() -> bool:
	if _invited:
		return false
	_invited = true
	return true


## §2.6.4 Freigabe: anatomy_known, Quast at least „Bekannt", and a first specimen sold or researched.
func invite_ready() -> bool:
	if _invited or not GameState.flag_on(_cfg().known_flag):
		return false
	var rel := _first(&"relationships") as Relationships
	var tier := rel.tier(SURGEON) if rel != null else &"stranger"
	if RelationshipRules.TIERS.find(tier) < RelationshipRules.TIERS.find(&"acquainted"):
		return false
	return GameState.get_stat(&"specimens_sold") + GameState.get_stat(&"specimens_researched") > 0


## Today (incl. 00:00–00:30 of the next day) is a lecture night and the window is open.
func tonight() -> bool:
	return LectureRules.is_lecture_night(TimeManager.day, TimeManager.minute_of_day, _cfg())


## The night (day) of the lecture window open now; 0 = none.
func tonight_day() -> int:
	return LectureRules.night_of(TimeManager.day, TimeManager.minute_of_day, _cfg())


## A lecture was already held tonight.
func held_tonight() -> bool:
	var night := tonight_day()
	return night > 0 and _last_day == night


## HouseDoor (P1) asks through the group lectures: the surgery opens for the invited gravedigger on a
## lecture night.
func door_open(door_id: StringName) -> bool:
	return door_id == SURGERY_DOOR and _invited and tonight()


## Quast's line about tonight (the roll itself stays hidden).
func night_line() -> String:
	var night := tonight_day()
	if night <= 0:
		return ""
	return TEXT_RISKY if LectureRules.rumor(night, seed, _rep_tier(), _cfg()) else TEXT_QUIET


## "" = `uid` can go on the lectern now (tonight, invited, not held yet, a jar / bone / display).
func hold_block_reason(uid: String, inv: Inventory) -> String:
	if not tonight():
		return LectureRules.TEXT_NOT_TONIGHT
	var specimens := _first(&"specimens") as Specimens
	var spec := specimens.get_record(uid) if specimens != null else null
	var reason := LectureRules.block_reason(spec, TimeManager.total_minutes(), _invited, held_tonight(), _cfg())
	if reason != "":
		return reason
	if inv == null or not inv.has_uid(uid):
		return LectureRules.TEXT_GONE
	return ""


## The fee `uid` would earn now (0 = refused).
func fee_for(uid: String) -> int:
	var specimens := _first(&"specimens") as Specimens
	var spec := specimens.get_record(uid) if specimens != null else null
	return LectureRules.fee(spec.organ, _standing(), _cfg()) if spec != null else 0


## After the TimedAction: Specimens.consume(lectured) (the jar stays in the cabinet), the fee
## (payment_received), the organ's teaching, piety lecture.piety, Quast +3, stats.lectures_attended,
## piety_used_day, lecture_held; a discovered night lands as rumour on the next morning.
## {ok, fee, organ, teaching, learned, rumor} ({ok: false, reason} = refused).
func hold(uid: String, inv: Inventory) -> Dictionary:
	var reason := hold_block_reason(uid, inv)
	if reason != "":
		return {"ok": false, "reason": reason}
	var specimens := _first(&"specimens") as Specimens
	var spec := specimens.get_record(uid)
	var organ := spec.organ
	var night := tonight_day()
	var fee := LectureRules.fee(organ, _standing(), _cfg())
	if not specimens.consume(uid, inv, Specimens.STATE_LECTURED):
		return {"ok": false, "reason": LectureRules.TEXT_GONE}
	inv.add_item(COIN_ITEM, fee)
	EventBus.payment_received.emit(fee, REASON_FEE)
	var teaching := teaching_of(organ)
	var learned := learn(teaching) if teaching != &"" else false
	if not learned:
		EventBus.notification_requested.emit(TEXT_KNOWN, &"info")
	var piety := _first(&"piety") as Piety
	if piety != null:
		piety.change(int(_cfg().lecture.get("piety", -3)), REASON_LECTURE)
	GameState.set_flag(FLAG_PIETY_USED_DAY, TimeManager.day)
	var rel := _first(&"relationships") as Relationships
	if rel != null:
		rel.add(SURGEON, LECTURE_REL, REASON_LECTURE)
	GameState.add_stat(STAT_ATTENDED, 1)
	_attended += 1
	_last_day = night
	var rumor := LectureRules.rumor(night, seed, _rep_tier(), _cfg())
	if rumor:
		_rumor_day = night + 1
	EventBus.lecture_held.emit(night, organ, fee, rumor)
	return {"ok": true, "fee": fee, "organ": organ, "teaching": teaching, "learned": learned, "rumor": rumor}


## false = already known (or empty).
func learn(teaching_id: StringName) -> bool:
	if teaching_id == &"" or _teachings.has(String(teaching_id)):
		return false
	_teachings.append(String(teaching_id))
	return true


func known_teachings() -> PackedStringArray:
	return _teachings.duplicate()


func attended() -> int:
	return _attended


## The rumour of a discovered night, from 06:00 of its morning (once): reputation lecture_rumor,
## priest and washer (lecture.rumor_rel), the village's line.
func apply_morning(day: int) -> void:
	if _rumor_day <= 0 or day < _rumor_day:
		return
	_rumor_day = 0
	var rep := _first(&"reputation") as Reputation
	if rep != null:
		rep.change(int(_cfg().lecture.get("rumor_rep", -4)), REASON_RUMOR)
	var rel := _first(&"relationships") as Relationships
	if rel != null:
		var rels: Dictionary = _cfg().lecture.get("rumor_rel", {})
		for npc: Variant in rels:
			rel.add(StringName(str(npc)), int(rels[npc]), REASON_RUMOR)
	EventBus.notification_requested.emit(TEXT_RUMOR, &"info")


## The morning the rumour is due (0 = none).
func rumor_pending_day() -> int:
	return _rumor_day


## The teaching of an organ (TeachingData.organ in Database.teachings(), else "l_<organ>").
static func teaching_of(organ: StringName) -> StringName:
	if organ == &"":
		return &""
	for res: Resource in Database.teachings():
		var t := res as TeachingData
		if t != null and t.organ == organ:
			return t.id
	return StringName("l_" + String(organ))


## {invited, last_day, attended, teachings, rumor_day} (§5.1); {} while nothing happened.
func save_state() -> Dictionary:
	if not _invited and _teachings.is_empty() and _last_day == 0 and _attended == 0 and _rumor_day == 0:
		return {}
	return {"invited": _invited, "last_day": _last_day, "attended": _attended, "teachings": Array(_teachings),
			"rumor_day": _rumor_day}


func load_state(data: Dictionary) -> void:
	_invited = data.get("invited") is bool and bool(data.get("invited"))
	_teachings = PackedStringArray()
	var list: Variant = data.get("teachings")
	if list is Array or list is PackedStringArray:
		for id: Variant in list:
			if (id is String or id is StringName) and not _teachings.has(str(id)):
				_teachings.append(str(id))
	_last_day = maxi(_int(data.get("last_day")), 0)
	_attended = maxi(_int(data.get("attended")), 0)
	_rumor_day = maxi(_int(data.get("rumor_day")), 0)


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


func _standing() -> int:
	return clampi(GameState.get_stat(Specimens.STAT_STANDING), 0, 4)


func _rep_tier() -> StringName:
	var rep := _first(&"reputation") as Reputation
	if rep != null:
		return rep.tier()
	return ReputationRules.tier(GameState.get_stat(&"reputation"), null)


func _cfg() -> AnatomyConfig:
	if config == null:
		config = Database.config(&"anatomy_config") as AnatomyConfig
		if config == null:
			config = AnatomyConfig.new()
	return config


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _on_hour_changed(day: int, hour: int) -> void:
	if hour >= MORNING_HOUR:
		apply_morning(day)
