class_name Visitors
extends Node
## STUB (P2) – Systems/Visitors (docs/PHASE8_DESIGN.md §2.1.4, §2.2, §3.1, §3.3, §3.4, §5.1), groups
## &"visitors", &"saveable": the daily visit plan (06:00, deterministic, saved), the visible visit
## (runtime schedule of the kin Npc), the look at the grave (GraveView → Reputation, goodwill), wishes,
## tips (in the talk or on the stone – TipStone), noise at a mourner.
## W0: visit_of / active_visits / goodwill / open_wishes / tip_on_stone answer from load_state
## ({"plan_day", "plan": [{visit_id, kin_id, graves, slot, phase}], "goodwill", "wishes", "tips_on_stone"}
## – §5.1; "phase" is the W0 test key of Phase8Fixtures.visit_now, P2 may derive it from the clock
## instead); everything else is inert.
## W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"visitors"
const PHASES: Array[StringName] = [&"arriving", &"mourning", &"waiting", &"leaving", &"gone"]
const WISH_STATES: Array[StringName] = [&"offered", &"accepted", &"done", &"failed"]
const PAYMENT_REASON := "Trinkgeld"

@export var save_id: String = "visitors"
@export var save_order: int = 71

## Rules; null = data/config/visitor_config.tres (resolved lazily).
var config: VisitorConfig

## W0 stub store (P2 may rename it – the fixtures use load_state only).
var _plan: Array[Dictionary] = []
var _goodwill: Dictionary[StringName, int] = {}
var _wishes: Array[Dictionary] = []
var _stones: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## 06:00, deterministic; [{visit_id, kin_id, graves, slot}] saved.
func plan_day(_day: int) -> Array[Dictionary]:
	return []


## The visit of `kin_id` today ({} = none).
func visit_of(kin_id: StringName) -> Dictionary:
	for v: Dictionary in _plan:
		if StringName(str(v.get("kin_id", ""))) == kin_id:
			return v
	return {}


## Visits on the graveyard now (arriving … leaving).
func active_visits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _plan:
		var phase := StringName(str(v.get("phase", "")))
		if phase != &"" and phase != &"gone":
			out.append(v)
	return out


## 0…10 (start VisitorConfig.goodwill_start).
func goodwill(kin_id: StringName) -> int:
	return int(_goodwill.get(kin_id, 5))


func add_goodwill(_kin_id: StringName, _delta: int) -> void:
	pass


## The kin of the dead in `grave_id` (CorpseRecord.kin_house → KinData; fixed graves) or &"".
func kin_for_grave(_grave_id: String) -> StringName:
	return &""


## {} | {wish_id, kind, grave_id, text}.
func offer_wish(_visit_id: String) -> Dictionary:
	return {}


func accept_wish(_wish_id: String) -> bool:
	return false


## Offered or accepted wishes [{wish_id, kind, grave_id, kin_id, state, day, candle_seen}].
func open_wishes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in _wishes:
		if str(w.get("state", "")) in ["offered", "accepted"]:
			out.append(w)
	return out


## In the talk; otherwise TipStone. Returns the coins.
func hand_tip(_visit_id: String, _inv: Inventory) -> int:
	return 0


## (coins, kin index) or (0, -1). W0: the index is the position of the saved kin id in
## Database.kin_list() (-1 = unknown kin).
func tip_on_stone(grave_id: String) -> Vector2i:
	var t: Variant = _stones.get(grave_id)
	if not t is Array or (t as Array).size() < 2 or int((t as Array)[0]) <= 0:
		return Vector2i(0, -1)
	var kin_id := str((t as Array)[1])
	var index := -1
	var list := Database.kin_list()
	for i: int in list.size():
		if String(list[i].get(&"kin_id")) == kin_id:
			index = i
	return Vector2i(int((t as Array)[0]), index)


func take_tip(_grave_id: String, _inv: Inventory) -> int:
	return 0


## Player TimedAction with the keyword noisy (ActionConfig.noisy_actions).
func note_noise(_pos: Vector3, _action_id: StringName) -> void:
	pass


## From the Npc plan (the look, the end).
func on_visit_phase(_visit_id: String, _phase: StringName) -> void:
	pass


## {plan_day, plan, goodwill, last_visit, wishes, tips_today, tips_on_stone, pleased_today, noise_day,
## rumor_seen, next_wish} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_plan.clear()
	var plan: Variant = data.get("plan", [])
	if plan is Array:
		for v: Variant in plan:
			if v is Dictionary:
				_plan.append((v as Dictionary).duplicate(true))
	_goodwill.clear()
	var gw: Variant = data.get("goodwill", {})
	if gw is Dictionary:
		for key: Variant in gw:
			_goodwill[StringName(str(key))] = int(gw[key])
	_wishes.clear()
	var wishes: Variant = data.get("wishes", [])
	if wishes is Array:
		for w: Variant in wishes:
			if w is Dictionary:
				_wishes.append((w as Dictionary).duplicate(true))
	var stones: Variant = data.get("tips_on_stone", {})
	_stones = (stones as Dictionary).duplicate(true) if stones is Dictionary else {}
