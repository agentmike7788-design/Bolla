class_name Treasury
extends Node
## STUB (P2) – Systems/Treasury (docs/PHASE10_DESIGN.md §1.2, §1.5, §2.5, §3.1, §3.3, §3.4, §5.1), groups &"treasury",
## &"saveable", save_id treasury / 85: the parish treasury – the weekly cemetery inspection (Sunday 18:00: tier + care
## − disturbed graves, the need allowance below 60, the hardship floor of 10), the payout on Monday 07:40 through Osric
## (else the hut chest), the monthly settlement on the 1st 06:00 (rent from the lease letter, the tithe and the estimate
## from village_open, prorated in the first month), paying at Fenner or Osric until the 7th, the deferral on the 8th and
## the waiver after a month, the poor box at the gate, p10_open after who_knows_when_complete, the chapter
## „Soll und Haben" (debit_credit).
## Coins go in through Inventory.add + EventBus.payment_received, out through GameState.note_coins_spent(n, &"rent" |
## &"tax") (Münzbuch-Regel seit QA5-01); listeners never change foreign state (§3.3).
## W0: is_open()/open_day() read p10_open / p10_open_day; last_schau, pending_pay, settlement, open_settlement, due_day,
## poor_box_coins and goal_progress answer from load_state (§5.1 {book_start, schau, weeks, settlements, poor_box,
## rent_prepaid_until, goal_done}); everything else is inert. W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"treasury"
## settlement state (EventBus.settlement_changed): due → paid | deferred → paid | waived.
const STATE_DUE := &"due"
const STATE_PAID := &"paid"
const STATE_DEFERRED := &"deferred"
const STATE_WAIVED := &"waived"
const STATES: Array[StringName] = [STATE_DUE, STATE_PAID, STATE_DEFERRED, STATE_WAIVED]
## Who takes the dues: Fenner in the office, Osric at his cart.
const VIA: Array[StringName] = [&"mayor", &"carter"]

@export var save_id: String = "treasury"
@export var save_order: int = 85

## Rules; null = data/config/treasury_config.tres (resolved lazily).
var config: TreasuryConfig

## W0 stub store (P2 may rename it – the fixtures use load_state only).
var _schau: Dictionary = {}
var _settlements: Dictionary = {}
var _poor_box: int = 0
var _goal_done: bool = false


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func is_open() -> bool:
	return GameState.flag_on(_cfg().open_flag)


func open_day() -> int:
	var v: Variant = GameState.get_flag(_cfg().open_day_flag, -1)
	return int(v) if (v is int or v is float) else -1


## p10_open (idempotent), the 1st 06:00 settlement, the deferral on the 8th, the waiver.
func apply_morning(_day: int) -> void:
	pass


## Sunday 18:00 the inspection, Monday 07:40 the payout (Osric or the chest).
func apply_minute(_day: int, _minute: int) -> void:
	pass


## v8 with who_knows_when_complete → p10_open at once.
func post_load() -> void:
	pass


## {week, day, tier, care, disturbed, quality, need, hardship, paid}
func last_schau() -> Dictionary:
	return _schau.duplicate(true)


## The inspection evaluated and not yet paid out ({} = nothing pending).
func pending_pay() -> Dictionary:
	return _schau.duplicate(true) if not _schau.is_empty() and not bool(_schau.get("paid", false)) else {}


## {month, day, income, spent, parish, donations, rent, tithe, estimate, deferred_in, total, state, paid_day}
func settlement(month_key: String) -> Dictionary:
	var s: Variant = _settlements.get(month_key)
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


## Due or deferred; {} = nothing open.
func open_settlement() -> Dictionary:
	for key: String in _sorted_keys():
		var s: Dictionary = _settlements[key]
		if StringName(str(s.get("state", ""))) in [STATE_DUE, STATE_DEFERRED]:
			var out := s.duplicate(true)
			out["month"] = key
			return out
	return {}


## The last day to pay the open settlement (the 7th); -1 = nothing open.
func due_day() -> int:
	var s := open_settlement()
	if s.is_empty():
		return -1
	return int(s.get("day", 0)) + _cfg().due_days


## &"mayor" | &"carter"
func pay_dues(_inv: Inventory, _via: StringName) -> bool:
	return false


func defer_dues() -> void:
	pass


func poor_box_coins() -> int:
	return _poor_box


## A pleased visitor drops coins into the poor box (Visitors → Treasury, cap 2 a day, at most poor_box_max inside).
func drop_in_poor_box(_coins: int, _who: StringName) -> void:
	pass


## The coins of the poor box into `inv` (Spenden); returns how many.
func empty_poor_box(_inv: Inventory) -> int:
	return 0


## The gravekeeper puts one coin in (piety +1 once a week).
func give_to_poor_box(_inv: Inventory) -> bool:
	return false


func check_goal() -> bool:
	return false


## {settled, market_days, best_tier}
func goal_progress() -> Dictionary:
	return {"settled": false, "market_days": 0, "best_tier": &""}


## §5.1 {book_start, schau, weeks, settlements, poor_box, rent_prepaid_until, goal_done}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_schau = (data.get("schau") as Dictionary).duplicate(true) if data.get("schau") is Dictionary else {}
	_settlements.clear()
	var raw: Variant = data.get("settlements")
	if raw is Dictionary:
		for key: Variant in raw:
			if (raw as Dictionary)[key] is Dictionary:
				_settlements[str(key)] = ((raw as Dictionary)[key] as Dictionary).duplicate(true)
	var box: Variant = data.get("poor_box", 0)
	_poor_box = clampi(int(box), 0, _cfg().poor_box_max) if (box is int or box is float) else 0
	_goal_done = bool(data.get("goal_done", false)) if data.get("goal_done") is bool else false


func _cfg() -> TreasuryConfig:
	if config == null:
		config = Database.config(&"treasury_config") as TreasuryConfig
		if config == null:
			config = TreasuryConfig.new()
	return config


func _sorted_keys() -> Array:
	var keys := _settlements.keys()
	keys.sort()
	return keys
